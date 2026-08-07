local ATTB = ArrowToTheBuild
local Util = ATTB.Util

local ALL_SECTIONS = {
    identity = true,
    skills = true,
    equipment = true,
    champion = true,
}

local function initializeSavedVariables()
    local savedRootPresent = type(ArrowToTheBuildSavedVariables) == "table"
    if not savedRootPresent then
        ArrowToTheBuildSavedVariables = {}
    end
    local saved = ArrowToTheBuildSavedVariables

    -- Record exactly what ESO supplied from disk before this addon changes or
    -- migrates anything. These values make path/profile problems visible in
    -- /attbstatus without exposing the SavedVariables file itself.
    ATTB.runtime.savedRootPresentAtLoad = savedRootPresent
    ATTB.runtime.loadedCharacterCount = Util.TableCount(saved.characters)
    ATTB.runtime.loadedRevision = tonumber(saved.revision or 0) or 0
    ATTB.runtime.loadedAddonVersion = tostring(saved.addonVersion or "none")
    ATTB.runtime.loadedSchemaVersion = tonumber(saved.schemaVersion or 0) or 0
    ATTB.runtime.loadedCreatedAt = tonumber(saved.createdAt or 0) or 0

    saved.schemaVersion = ATTB.savedVariablesSchemaVersion
    saved.addonVersion = ATTB.version
    saved.apiVersion = Util.GetApiVersion()
    saved.characters = saved.characters or {}
    saved.revision = saved.revision or 0
    saved.createdAt = saved.createdAt or Util.Now()
    saved.lastUpdatedAt = saved.lastUpdatedAt or 0

    ATTB.savedVariables = saved
    ATTB.runtime.lastPrioritySaveRequestAt = saved.lastPrioritySaveRequestedAt or 0
    ATTB.runtime.migratedCharacterCount = ATTB.Schema.MigrateSavedCharacters(saved)
end

local function createDiagnostics()
    return { warnings = {}, errors = {} }
end

local function getSnapshotCompleteness(snapshot)
    local sections = {
        identity = snapshot.identity ~= nil,
        attributes = snapshot.identity and snapshot.identity.attributes ~= nil,
        skills = snapshot.skills ~= nil,
        equipment = snapshot.equipment ~= nil,
        champion = snapshot.champion ~= nil,
    }
    local completeCount = 0
    local totalCount = 0
    for _, complete in pairs(sections) do
        totalCount = totalCount + 1
        if complete then
            completeCount = completeCount + 1
        end
    end
    return {
        sections = sections,
        completeCount = completeCount,
        totalCount = totalCount,
        isComplete = completeCount == totalCount,
    }
end

local function copySectionSet(source)
    local result = {}
    if type(source) == "string" then
        result[source] = true
    elseif type(source) == "table" then
        for key, value in pairs(source) do
            if type(key) == "number" then
                result[tostring(value)] = true
            elseif value == true then
                result[tostring(key)] = true
            end
        end
    end
    return result
end

local function sortedSetValues(values)
    local result = {}
    for key, enabled in pairs(values or {}) do
        if enabled then
            table.insert(result, tostring(key))
        end
    end
    table.sort(result)
    return result
end

local function captureReasonText(reasons, fallback)
    local values = sortedSetValues(reasons)
    if #values == 0 then
        return fallback or "unspecified"
    end
    return table.concat(values, ",")
end

local function getLatestStoredSnapshot(saved)
    if type(saved) ~= "table" or type(saved.characters) ~= "table" then
        return nil
    end

    local preferred = saved.lastCharacterKey and saved.characters[saved.lastCharacterKey] or nil
    local latest = type(preferred) == "table" and preferred or nil
    local latestCapturedAt = latest and tonumber(latest.capturedAt or 0) or 0

    for _, snapshot in pairs(saved.characters) do
        if type(snapshot) == "table" then
            local capturedAt = tonumber(snapshot.capturedAt or 0) or 0
            if not latest or capturedAt > latestCapturedAt then
                latest = snapshot
                latestCapturedAt = capturedAt
            end
        end
    end

    return latest
end

function ATTB.RequestPrioritySave(force)
    local now = Util.Now()
    local elapsed = now - (ATTB.runtime.lastPrioritySaveRequestAt or 0)
    if not force and elapsed < ATTB.minimumPrioritySaveIntervalSeconds then
        return false, "throttled"
    end

    local succeeded = false
    if type(GetAddOnManager) == "function" then
        local managerSucceeded, manager = pcall(GetAddOnManager)
        if managerSucceeded and manager and type(manager.RequestAddOnSavedVariablesPrioritySave) == "function" then
            local callSucceeded, result = pcall(function()
                return manager:RequestAddOnSavedVariablesPrioritySave(ATTB.name)
            end)
            succeeded = callSucceeded and result ~= false
        end
    end
    if not succeeded and type(RequestAddOnSavedVariablesPrioritySave) == "function" then
        local callSucceeded, result = pcall(RequestAddOnSavedVariablesPrioritySave, ATTB.name)
        succeeded = callSucceeded and result ~= false
    end

    if succeeded then
        ATTB.runtime.lastPrioritySaveRequestAt = now
        if ATTB.savedVariables then
            ATTB.savedVariables.lastPrioritySaveRequestedAt = now
            ATTB.savedVariables.lastPrioritySaveCharacterKey = ATTB.savedVariables.lastCharacterKey
            ATTB.savedVariables.lastPrioritySaveWasForced = force == true
        end
        return true, "requested"
    end
    return false, "unavailable"
end

function ATTB.CaptureSnapshot(reason, forcePrioritySave, options)
    options = options or {}
    if not ATTB.savedVariables then
        initializeSavedVariables()
    end

    local diagnostics = createDiagnostics()
    ATTB.runtime.currentDiagnostics = diagnostics
    local identity = ATTB.Collectors.Character.Collect()
    if not identity.characterId or identity.characterId == "" then
        Util.AddError("The active character ID was unavailable; snapshot was not stored.")
        ATTB.runtime.currentDiagnostics = nil
        return false, "character-id-unavailable"
    end

    local now = Util.Now()
    local characterKey = identity.characterKey
    local previous = ATTB.savedVariables.characters[characterKey]
    local sections = copySectionSet(options.sections)
    if options.forceFull or not previous then
        sections = copySectionSet(ALL_SECTIONS)
    end
    sections.identity = true

    local snapshot = {
        snapshotSchemaVersion = ATTB.snapshotSchemaVersion,
        dataProfile = ATTB.snapshotDataProfile,
        addonVersion = ATTB.version,
        apiVersion = Util.GetApiVersion(),
        capturedAt = now,
        captureReason = reason or "unspecified",
        identity = identity,
        skills = sections.skills and ATTB.Collectors.Skills.Collect() or (previous and previous.skills),
        equipment = sections.equipment and ATTB.Collectors.Equipment.Collect() or (previous and previous.equipment),
        champion = sections.champion and ATTB.Collectors.Champion.Collect() or (previous and previous.champion),
        diagnostics = diagnostics,
        metadata = {
            firstSeenAt = previous and previous.metadata and previous.metadata.firstSeenAt or now,
            lastSeenAt = now,
            captureCount = previous and previous.metadata and ((previous.metadata.captureCount or 0) + 1) or 1,
            capturedSections = sortedSetValues(sections),
        },
    }
    snapshot.completeness = getSnapshotCompleteness(snapshot)

    ATTB.savedVariables.schemaVersion = ATTB.savedVariablesSchemaVersion
    ATTB.savedVariables.addonVersion = ATTB.version
    ATTB.savedVariables.apiVersion = Util.GetApiVersion()
    ATTB.savedVariables.revision = (ATTB.savedVariables.revision or 0) + 1
    ATTB.savedVariables.lastUpdatedAt = now
    ATTB.savedVariables.lastCharacterKey = characterKey
    ATTB.savedVariables.characters[characterKey] = snapshot

    ATTB.runtime.currentDiagnostics = nil
    ATTB.runtime.lastSnapshotAt = now
    ATTB.runtime.lastCaptureSections = snapshot.metadata.capturedSections
    if options.automatic then
        ATTB.runtime.lastAutomaticCaptureAt = now
    end

    -- Publish the same complete in-memory snapshot to the separate, deliberately
    -- tiny SavedVariables bridge when it is installed. The bridge keeps only the
    -- current character and uses packed records so ESO can write it during normal
    -- play instead of waiting for the much larger multi-character archive.
    ATTB.runtime.lastBridgePublishStatus = "not-installed"
    local bridgePriorityRequested = false
    local bridgePriorityStatus = "not-installed"
    if type(ArrowToTheBuildBridge) == "table" and type(ArrowToTheBuildBridge.PublishSnapshot) == "function" then
        local bridgeCallSucceeded, bridgePublished, _, requested, status = pcall(
            ArrowToTheBuildBridge.PublishSnapshot,
            snapshot,
            forcePrioritySave == true
        )
        bridgePriorityRequested = requested == true
        bridgePriorityStatus = tostring(status or "normal")
        if bridgeCallSucceeded and bridgePublished then
            ATTB.runtime.lastBridgePublishStatus = bridgePriorityRequested
                and "published; priority requested"
                or ("published; priority " .. bridgePriorityStatus)
        elseif bridgeCallSucceeded then
            ATTB.runtime.lastBridgePublishStatus = "publish skipped"
        else
            ATTB.runtime.lastBridgePublishStatus = "publish failed"
            bridgePriorityStatus = "publish-failed"
            Util.AddWarning("ATTB sync bridge publish failed: " .. tostring(bridgePublished))
        end
    end

    -- The durable archive deliberately does not request a normal-play priority
    -- save. It is normally too large for ESO's between-loading-screen save path
    -- and would only compete with the small bridge for the save opportunity.
    return true, snapshot, bridgePriorityRequested, bridgePriorityStatus
end

local function markPending(reason, sections, options)
    ATTB.runtime.pendingReasons = ATTB.runtime.pendingReasons or {}
    ATTB.runtime.pendingSections = ATTB.runtime.pendingSections or {}
    if reason then
        ATTB.runtime.pendingReasons[tostring(reason)] = true
    end
    for section in pairs(copySectionSet(sections)) do
        ATTB.runtime.pendingSections[section] = true
    end
    if options and options.forceFull then
        ATTB.runtime.pendingForceFull = true
    end
    if options and options.bypassCooldown then
        ATTB.runtime.pendingBypassCooldown = true
    end
end

local function registerPendingUpdate(delayMilliseconds)
    Util.SafeUnregisterUpdate()
    if EVENT_MANAGER == nil or type(EVENT_MANAGER.RegisterForUpdate) ~= "function" then
        return ATTB.FlushScheduledSnapshot()
    end
    EVENT_MANAGER:RegisterForUpdate(ATTB.updateRegistrationName, delayMilliseconds, function()
        Util.SafeUnregisterUpdate()
        ATTB.FlushScheduledSnapshot()
    end)
end

function ATTB.FlushScheduledSnapshot()
    local now = Util.Now()
    local elapsed = now - (ATTB.runtime.lastAutomaticCaptureAt or 0)
    if not ATTB.runtime.pendingBypassCooldown
        and ATTB.runtime.lastAutomaticCaptureAt > 0
        and elapsed < ATTB.minimumAutomaticCaptureIntervalSeconds then
        local remaining = (ATTB.minimumAutomaticCaptureIntervalSeconds - elapsed) * 1000
        registerPendingUpdate(math.max(remaining, 250))
        return false, "cooldown"
    end

    local reasons = ATTB.runtime.pendingReasons or {}
    local sections = ATTB.runtime.pendingSections or {}
    local forceFull = ATTB.runtime.pendingForceFull == true
    ATTB.runtime.pendingReasons = {}
    ATTB.runtime.pendingSections = {}
    ATTB.runtime.pendingForceFull = false
    ATTB.runtime.pendingBypassCooldown = false

    return ATTB.CaptureSnapshot(captureReasonText(reasons, "event"), false, {
        sections = sections,
        forceFull = forceFull,
        automatic = true,
    })
end

function ATTB.ScheduleSnapshot(reason, sections, delayMilliseconds, options)
    markPending(reason, sections, options)
    return registerPendingUpdate(delayMilliseconds or ATTB.debounceMilliseconds)
end

local function registerGenericRefreshEvent(eventConstantName, reason, sections)
    return Util.SafeRegisterEvent(eventConstantName, eventConstantName, function()
        ATTB.ScheduleSnapshot(reason or eventConstantName, sections)
    end)
end

local function registerInventoryEvent()
    return Util.SafeRegisterEvent("InventorySingleSlotUpdate", "EVENT_INVENTORY_SINGLE_SLOT_UPDATE", function(_, bagId)
        if BAG_WORN == nil or bagId == BAG_WORN then
            ATTB.ScheduleSnapshot("equipment-changed", { "equipment" })
        end
    end)
end

local function registerPlayerDeactivatedEvent()
    return Util.SafeRegisterEvent("PlayerDeactivated", "EVENT_PLAYER_DEACTIVATED", function()
        Util.SafeUnregisterUpdate()
        ATTB.runtime.pendingReasons = {}
        ATTB.runtime.pendingSections = {}
        ATTB.runtime.pendingForceFull = false
        ATTB.runtime.pendingBypassCooldown = false
        ATTB.CaptureSnapshot("player-deactivated", true, { forceFull = true })
    end)
end

function ATTB.RegisterRefreshEvents()
    if ATTB.runtime.eventListenersRegistered then
        return
    end

    local genericEvents = {
        { "EVENT_LEVEL_UPDATE", "level-changed", { "identity" } },
        { "EVENT_CHAMPION_POINT_UPDATE", "champion-points-changed", { "identity", "champion" } },
        { "EVENT_CHAMPION_POINTS_CHANGED", "champion-points-changed", { "identity", "champion" } },
        { "EVENT_SKILL_POINTS_CHANGED", "skill-points-changed", { "identity" } },
        { "EVENT_SKILL_RANK_UPDATE", "skill-rank-changed", { "skills" } },
        { "EVENT_SKILL_LINE_ADDED", "skill-line-added", { "skills" } },
        { "EVENT_SKILL_LINE_LEVELED_UP", "skill-line-leveled", { "skills" } },
        { "EVENT_SKILL_ABILITY_PROGRESSIONS_UPDATED", "skill-progression-changed", { "skills" } },
        { "EVENT_ACTION_SLOT_UPDATED", "action-bar-changed", { "skills" } },
        { "EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED", "action-bars-changed", { "skills" } },
        { "EVENT_HOTBAR_SLOT_UPDATED", "hotbar-slot-changed", { "skills" } },
        { "EVENT_ACTIVE_WEAPON_PAIR_CHANGED", "active-weapon-pair-changed", { "skills" } },
        { "EVENT_ATTRIBUTE_UPGRADE_UPDATED", "attributes-changed", { "identity" } },
        { "EVENT_ATTRIBUTE_POINTS_CHANGED", "attributes-changed", { "identity" } },
        { "EVENT_CHAMPION_PURCHASE_RESULT", "champion-purchase-changed", { "identity", "champion" } },
        { "EVENT_CHAMPION_SLOT_SKILL", "champion-bar-changed", { "champion" } },
        { "EVENT_CHAMPION_UNSLOT_SKILL", "champion-bar-changed", { "champion" } },
    }

    for _, eventDefinition in ipairs(genericEvents) do
        registerGenericRefreshEvent(eventDefinition[1], eventDefinition[2], eventDefinition[3])
    end
    registerInventoryEvent()
    registerPlayerDeactivatedEvent()
    ATTB.runtime.eventListenersRegistered = true
end

function ATTB.OnPlayerActivated()
    ATTB.runtime.playerActivated = true
    ATTB.RegisterRefreshEvents()
    ATTB.ScheduleSnapshot("player-activated", ALL_SECTIONS, 500, {
        forceFull = true,
        bypassCooldown = true,
    })
end

function ATTB.OnAddonLoaded(_, addonName)
    if addonName ~= ATTB.name then
        return
    end

    initializeSavedVariables()
    ATTB.runtime.initialized = true
    if EVENT_MANAGER ~= nil and type(EVENT_MANAGER.UnregisterForEvent) == "function" then
        EVENT_MANAGER:UnregisterForEvent(ATTB.name, EVENT_ADD_ON_LOADED)
    end
    Util.SafeRegisterEvent("PlayerActivated", "EVENT_PLAYER_ACTIVATED", ATTB.OnPlayerActivated)

    SLASH_COMMANDS = SLASH_COMMANDS or {}
    SLASH_COMMANDS[ATTB.slashCommandExport] = function()
        Util.SafeUnregisterUpdate()
        ATTB.runtime.pendingReasons = {}
        ATTB.runtime.pendingSections = {}
        ATTB.runtime.pendingForceFull = false
        ATTB.runtime.pendingBypassCooldown = false
        local succeeded, snapshotOrReason, priorityRequested, priorityStatus =
            ATTB.CaptureSnapshot("manual-command", true, { forceFull = true })
        if succeeded then
            local characterName = snapshotOrReason.identity and snapshotOrReason.identity.name or "current character"
            local characterCount = Util.TableCount((ATTB.savedVariables or {}).characters)
            local saveMessage = priorityRequested
                and "Bridge priority save requested; full archive remains queued for ESO's normal loading-screen save."
                or ("Bridge priority " .. tostring(priorityStatus or "not requested") .. "; full archive will save on a loading screen, reload, logout, or exit.")
            Util.Print(string.format(
                "Captured %s. %d character(s) stored in memory. %s",
                characterName,
                characterCount,
                saveMessage
            ))
        else
            Util.Print("Snapshot failed: " .. tostring(snapshotOrReason))
        end
    end

    SLASH_COMMANDS[ATTB.slashCommandStatus] = function()
        local saved = ATTB.savedVariables or {}
        local characterCount = Util.TableCount(saved.characters)
        local pendingSections = table.concat(sortedSetValues(ATTB.runtime.pendingSections), ",")
        if pendingSections == "" then
            pendingSections = "none"
        end

        local latestSnapshot = getLatestStoredSnapshot(saved)
        local latestMetadata = latestSnapshot and latestSnapshot.metadata or nil
        local lastSections = latestMetadata and table.concat(latestMetadata.capturedSections or {}, ",") or ""
        if lastSections == "" then
            lastSections = table.concat(ATTB.runtime.lastCaptureSections or {}, ",")
        end
        if lastSections == "" then
            lastSections = "none"
        end

        local lastReason = latestSnapshot and tostring(latestSnapshot.captureReason or "unknown") or "none"
        local lastCapturedAt = latestSnapshot and Util.FormatTimestamp(latestSnapshot.capturedAt) or "unknown"
        local rootStatus = ATTB.runtime.savedRootPresentAtLoad and "yes" or "no"

        -- Do not use the pipe character here. ESO treats it as markup and
        -- mangles the rest of the chat line. Multiple short lines are easier
        -- to read and preserve every diagnostic value.
        Util.Print(string.format(
            "Version %s; snapshot %s/%s; world %s",
            ATTB.version,
            tostring(ATTB.snapshotSchemaVersion),
            ATTB.snapshotDataProfile,
            Util.GetWorldName()
        ))
        Util.Print(string.format(
            "Startup root %s; loaded from disk %d; revision %d; addon %s; schema %d; migrated %d",
            rootStatus,
            tonumber(ATTB.runtime.loadedCharacterCount or 0),
            tonumber(ATTB.runtime.loadedRevision or 0),
            tostring(ATTB.runtime.loadedAddonVersion or "none"),
            tonumber(ATTB.runtime.loadedSchemaVersion or 0),
            tonumber(ATTB.runtime.migratedCharacterCount or 0)
        ))
        Util.Print(string.format(
            "Current stored %d; revision %s; pending %s",
            characterCount,
            tostring(saved.revision or 0),
            pendingSections
        ))
        Util.Print(string.format(
            "Last capture %s; %s; sections %s",
            lastReason,
            lastCapturedAt,
            lastSections
        ))
        if type(ArrowToTheBuildBridge) == "table" and type(ArrowToTheBuildBridge.GetStatus) == "function" then
            local bridge = ArrowToTheBuildBridge.GetStatus()
            Util.Print(string.format(
                "Sync bridge %s; revision %d; disk-loaded %d; %s",
                tostring(bridge.version or "unknown"),
                tonumber(bridge.revision or 0),
                tonumber(bridge.loadedRevision or 0),
                tostring(ATTB.runtime.lastBridgePublishStatus or bridge.lastPrioritySaveStatus or "ready")
            ))
            Util.Print(string.format(
                "Bridge budget %d/%d bytes; %s%s",
                tonumber(bridge.estimatedBytes or 0),
                tonumber(bridge.budgetBytes or 0),
                tostring(bridge.budgetStatus or "unknown"),
                bridge.truncated and "; partial sync" or ""
            ))
            if bridge.priorityDeferred then
                Util.Print(string.format(
                    "Bridge priority deferred; newest snapshot queued; retry in about %d second(s)",
                    math.ceil(tonumber(bridge.priorityRetrySeconds or 0) or 0)
                ))
            elseif bridge.priorityDirty then
                Util.Print("Bridge has newer in-memory data awaiting its next save opportunity.")
            end
        else
            Util.Print("Sync bridge not installed; desktop updates may wait for a loading screen, reload, logout, or exit.")
        end
    end

    SLASH_COMMANDS[ATTB.slashCommandCharacters] = function()
        local saved = ATTB.savedVariables or {}
        local entries = {}
        for _, snapshot in pairs(saved.characters or {}) do
            local identity = type(snapshot) == "table" and snapshot.identity or nil
            local metadata = type(snapshot) == "table" and snapshot.metadata or nil
            table.insert(entries, {
                name = identity and tostring(identity.name or "Unknown") or "Unknown",
                level = identity and tonumber(identity.level or 0) or 0,
                championPoints = identity and tonumber(identity.championPoints or 0) or 0,
                accountName = identity and tostring(identity.accountName or "Unknown Account") or "Unknown Account",
                worldName = identity and tostring(identity.worldName or "Unknown World") or "Unknown World",
                characterId = identity and tostring(identity.characterId or "Unknown") or "Unknown",
                captureCount = metadata and tonumber(metadata.captureCount or 0) or 0,
            })
        end
        table.sort(entries, function(left, right)
            return left.name < right.name
        end)

        if #entries == 0 then
            Util.Print("No character snapshots are currently stored.")
            return
        end

        Util.Print(string.format("%d character snapshot(s) stored in memory:", #entries))
        for _, entry in ipairs(entries) do
            local progression = entry.championPoints > 0
                and string.format("CP %d", entry.championPoints)
                or string.format("Level %d", entry.level)
            Util.Print(string.format(
                "%s; %s; %s; %s; ID %s; captures %d",
                entry.name,
                progression,
                entry.accountName,
                entry.worldName,
                entry.characterId,
                entry.captureCount
            ))
        end
    end
end

if EVENT_MANAGER ~= nil and type(EVENT_MANAGER.RegisterForEvent) == "function" then
    EVENT_MANAGER:RegisterForEvent(ATTB.name, EVENT_ADD_ON_LOADED, ATTB.OnAddonLoaded)
end
