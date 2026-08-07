local ATTB = ArrowToTheBuild
local Util = ATTB.Util

local function initializeSavedVariables()
    ArrowToTheBuildSavedVariables = ArrowToTheBuildSavedVariables or {}
    local saved = ArrowToTheBuildSavedVariables

    saved.schemaVersion = ATTB.savedVariablesSchemaVersion
    saved.addonVersion = ATTB.version
    saved.apiVersion = Util.GetApiVersion()
    saved.characters = saved.characters or {}
    saved.revision = saved.revision or 0
    saved.createdAt = saved.createdAt or Util.Now()
    saved.lastUpdatedAt = saved.lastUpdatedAt or 0

    ATTB.savedVariables = saved
    ATTB.runtime.loadedCharacterCount = Util.TableCount(saved.characters)
end

local function createDiagnostics()
    return {
        warnings = {},
        errors = {},
    }
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

function ATTB.RequestPrioritySave(force)
    local now = Util.Now()
    local elapsed = now - (ATTB.runtime.lastPrioritySaveRequestAt or 0)

    -- Automatic event-driven captures are throttled so normal gameplay cannot repeatedly
    -- request disk writes. Deliberate requests from /attbexport and player deactivation
    -- bypass the addon-side throttle; ESO still controls when the file is actually written.
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

function ATTB.CaptureSnapshot(reason, forcePrioritySave)
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

    local snapshot = {
        snapshotSchemaVersion = ATTB.snapshotSchemaVersion,
        addonVersion = ATTB.version,
        apiVersion = Util.GetApiVersion(),
        capturedAt = now,
        captureReason = reason or "unspecified",
        identity = identity,
        skills = ATTB.Collectors.Skills.Collect(),
        equipment = ATTB.Collectors.Equipment.Collect(),
        champion = ATTB.Collectors.Champion.Collect(),
        diagnostics = diagnostics,
        metadata = {
            firstSeenAt = previous and previous.metadata and previous.metadata.firstSeenAt or now,
            lastSeenAt = now,
            captureCount = previous and previous.metadata and ((previous.metadata.captureCount or 0) + 1) or 1,
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

    local prioritySaveRequested, prioritySaveStatus = ATTB.RequestPrioritySave(forcePrioritySave == true)
    return true, snapshot, prioritySaveRequested, prioritySaveStatus
end

function ATTB.ScheduleSnapshot(reason, delayMilliseconds)
    ATTB.runtime.pendingReason = reason or ATTB.runtime.pendingReason or "event"
    Util.SafeUnregisterUpdate()

    if EVENT_MANAGER == nil or type(EVENT_MANAGER.RegisterForUpdate) ~= "function" then
        return ATTB.CaptureSnapshot(ATTB.runtime.pendingReason, false)
    end

    EVENT_MANAGER:RegisterForUpdate(
        ATTB.updateRegistrationName,
        delayMilliseconds or ATTB.debounceMilliseconds,
        function()
            Util.SafeUnregisterUpdate()
            local pendingReason = ATTB.runtime.pendingReason or "event"
            ATTB.runtime.pendingReason = nil
            ATTB.CaptureSnapshot(pendingReason, false)
        end
    )
end

local function registerGenericRefreshEvent(eventConstantName, reason)
    return Util.SafeRegisterEvent(eventConstantName, eventConstantName, function()
        ATTB.ScheduleSnapshot(reason or eventConstantName)
    end)
end

local function registerInventoryEvent()
    return Util.SafeRegisterEvent("InventorySingleSlotUpdate", "EVENT_INVENTORY_SINGLE_SLOT_UPDATE", function(_, bagId)
        if BAG_WORN == nil or bagId == BAG_WORN then
            ATTB.ScheduleSnapshot("equipment-changed")
        end
    end)
end

local function registerPlayerDeactivatedEvent()
    return Util.SafeRegisterEvent("PlayerDeactivated", "EVENT_PLAYER_DEACTIVATED", function()
        ATTB.CaptureSnapshot("player-deactivated", true)
    end)
end

function ATTB.RegisterRefreshEvents()
    if ATTB.runtime.eventListenersRegistered then
        return
    end

    local genericEvents = {
        { "EVENT_LEVEL_UPDATE", "level-changed" },
        { "EVENT_CHAMPION_POINT_UPDATE", "champion-points-changed" },
        { "EVENT_CHAMPION_POINTS_CHANGED", "champion-points-changed" },
        { "EVENT_SKILL_POINTS_CHANGED", "skill-points-changed" },
        { "EVENT_SKILL_RANK_UPDATE", "skill-rank-changed" },
        { "EVENT_SKILL_LINE_ADDED", "skill-line-added" },
        { "EVENT_SKILL_LINE_LEVELED_UP", "skill-line-leveled" },
        { "EVENT_SKILL_ABILITY_PROGRESSIONS_UPDATED", "skill-progression-changed" },
        { "EVENT_ACTION_SLOT_UPDATED", "action-bar-changed" },
        { "EVENT_ACTIVE_WEAPON_PAIR_CHANGED", "active-weapon-pair-changed" },
        { "EVENT_ATTRIBUTE_UPGRADE_UPDATED", "attributes-changed" },
        { "EVENT_ATTRIBUTE_POINTS_CHANGED", "attributes-changed" },
        { "EVENT_CHAMPION_PURCHASE_RESULT", "champion-purchase-changed" },
        { "EVENT_CHAMPION_SLOT_SKILL", "champion-bar-changed" },
        { "EVENT_CHAMPION_UNSLOT_SKILL", "champion-bar-changed" },
    }

    for _, eventDefinition in ipairs(genericEvents) do
        registerGenericRefreshEvent(eventDefinition[1], eventDefinition[2])
    end

    registerInventoryEvent()
    registerPlayerDeactivatedEvent()
    ATTB.runtime.eventListenersRegistered = true
end

function ATTB.OnPlayerActivated()
    ATTB.runtime.playerActivated = true
    ATTB.RegisterRefreshEvents()
    ATTB.ScheduleSnapshot("player-activated", 500)
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
        local succeeded, snapshotOrReason, priorityRequested, priorityStatus =
            ATTB.CaptureSnapshot("manual-command", true)
        if succeeded then
            local characterName = snapshotOrReason.identity and snapshotOrReason.identity.name or "current character"
            local characterCount = Util.TableCount((ATTB.savedVariables or {}).characters)
            local saveMessage = priorityRequested
                and "Priority save requested."
                or ("Priority save " .. tostring(priorityStatus or "not requested") .. "; ESO will use its next normal save opportunity.")
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
        Util.Print(string.format(
            "Version %s | schema %s | loaded at UI start %d | stored now %d | revision %s | %s",
            ATTB.version,
            tostring(saved.schemaVersion or "?"),
            tonumber(ATTB.runtime.loadedCharacterCount or 0),
            characterCount,
            tostring(saved.revision or 0),
            Util.GetWorldName()
        ))
    end
end

if EVENT_MANAGER ~= nil and type(EVENT_MANAGER.RegisterForEvent) == "function" then
    EVENT_MANAGER:RegisterForEvent(ATTB.name, EVENT_ADD_ON_LOADED, ATTB.OnAddonLoaded)
end
