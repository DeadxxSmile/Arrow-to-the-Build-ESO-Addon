local ATTB = ArrowToTheBuild
local Util = ATTB.Util

local ALL_SECTIONS = {
    identity = true,
    skills = true,
    equipment = true,
    champion = true,
}

local function tableCopy(source)
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
    return #values > 0 and table.concat(values, ",") or (fallback or "unspecified")
end

local function initializeSavedVariables()
    if type(ArrowToTheBuildSavedVariables) ~= "table" then
        ArrowToTheBuildSavedVariables = {}
    end

    local saved = ArrowToTheBuildSavedVariables

    saved.schemaVersion = ATTB.savedVariablesSchemaVersion
    saved.addonVersion = ATTB.version
    saved.apiVersion = GetAPIVersion()
    saved.characters = saved.characters or {}
    saved.revision = tonumber(saved.revision or 0) or 0
    saved.createdAt = saved.createdAt or Util.Now()
    saved.lastUpdatedAt = saved.lastUpdatedAt or 0

    ATTB.savedVariables = saved
end

function ATTB.CaptureSnapshot(reason, options)
    options = options or {}
    if not ATTB.savedVariables then
        initializeSavedVariables()
    end

    local identity = ATTB.Collectors.Character.Collect()
    if not identity.characterId or identity.characterId == "" then
        return false, "character-id-unavailable"
    end

    local now = Util.Now()
    local characterKey = identity.characterKey
    local previous = ATTB.savedVariables.characters[characterKey]
    local sections = tableCopy(options.sections)
    if options.forceFull or not previous then
        sections = tableCopy(ALL_SECTIONS)
    end
    sections.identity = true

    local snapshot = {
        snapshotSchemaVersion = ATTB.snapshotSchemaVersion,
        dataProfile = ATTB.snapshotDataProfile,
        addonVersion = ATTB.version,
        apiVersion = GetAPIVersion(),
        capturedAt = now,
        captureReason = reason or "unspecified",
        identity = identity,
        skills = sections.skills and ATTB.Collectors.Skills.Collect() or (previous and previous.skills),
        equipment = sections.equipment and ATTB.Collectors.Equipment.Collect() or (previous and previous.equipment),
        champion = sections.champion and ATTB.Collectors.Champion.Collect() or (previous and previous.champion),
        metadata = {
            firstSeenAt = previous and previous.metadata and previous.metadata.firstSeenAt or now,
            lastSeenAt = now,
            captureCount = previous and previous.metadata and ((previous.metadata.captureCount or 0) + 1) or 1,
            capturedSections = sortedSetValues(sections),
        },
    }
    local saved = ATTB.savedVariables
    saved.schemaVersion = ATTB.savedVariablesSchemaVersion
    saved.addonVersion = ATTB.version
    saved.apiVersion = GetAPIVersion()
    saved.revision = saved.revision + 1
    saved.lastUpdatedAt = now
    saved.lastCharacterKey = characterKey
    saved.characters[characterKey] = snapshot

    ATTB.runtime.lastSnapshotAt = now
    if options.automatic then
        ATTB.runtime.lastAutomaticCaptureAt = now
    end

    return true, snapshot
end

local function markPending(reason, sections, options)
    if reason then
        ATTB.runtime.pendingReasons[tostring(reason)] = true
    end
    for section in pairs(tableCopy(sections)) do
        ATTB.runtime.pendingSections[section] = true
    end
    if options and options.forceFull then
        ATTB.runtime.pendingForceFull = true
    end
    if options and options.bypassCooldown then
        ATTB.runtime.pendingBypassCooldown = true
    end
end

local function clearPending()
    ATTB.runtime.pendingReasons = {}
    ATTB.runtime.pendingSections = {}
    ATTB.runtime.pendingForceFull = false
    ATTB.runtime.pendingBypassCooldown = false
end

local function registerPendingUpdate(delayMilliseconds)
    EVENT_MANAGER:UnregisterForUpdate(ATTB.updateRegistrationName)
    EVENT_MANAGER:RegisterForUpdate(ATTB.updateRegistrationName, delayMilliseconds, function()
        EVENT_MANAGER:UnregisterForUpdate(ATTB.updateRegistrationName)
        ATTB.FlushScheduledSnapshot()
    end)
end

function ATTB.FlushScheduledSnapshot()
    local elapsed = Util.Now() - (ATTB.runtime.lastAutomaticCaptureAt or 0)
    if not ATTB.runtime.pendingBypassCooldown
        and ATTB.runtime.lastAutomaticCaptureAt > 0
        and elapsed < ATTB.minimumAutomaticCaptureIntervalSeconds then
        registerPendingUpdate(math.max((ATTB.minimumAutomaticCaptureIntervalSeconds - elapsed) * 1000, 250))
        return false, "cooldown"
    end

    local reasons = ATTB.runtime.pendingReasons
    local sections = ATTB.runtime.pendingSections
    local forceFull = ATTB.runtime.pendingForceFull == true
    clearPending()

    return ATTB.CaptureSnapshot(captureReasonText(reasons, "event"), {
        sections = sections,
        forceFull = forceFull,
        automatic = true,
    })
end

function ATTB.ScheduleSnapshot(reason, sections, delayMilliseconds, options)
    markPending(reason, sections, options)
    registerPendingUpdate(delayMilliseconds or ATTB.debounceMilliseconds)
end

local function onPlayerLevelChanged(_, unitTag)
    if unitTag == "player" then
        ATTB.ScheduleSnapshot("level-changed", { "identity" })
    end
end

local function onChampionPointsChanged(_, unitTag)
    if unitTag == "player" then
        ATTB.ScheduleSnapshot("champion-points-changed", { "identity", "champion" })
    end
end

local function onSkillsChanged()
    ATTB.ScheduleSnapshot("skills-changed", { "identity", "skills" })
end

local function onHotbarSlotUpdated(_, _, hotbarCategory)
    if hotbarCategory == HOTBAR_CATEGORY_CHAMPION then
        ATTB.ScheduleSnapshot("champion-bar-changed", { "champion" })
    elseif hotbarCategory == HOTBAR_CATEGORY_PRIMARY or hotbarCategory == HOTBAR_CATEGORY_BACKUP then
        ATTB.ScheduleSnapshot("action-bar-changed", { "skills" })
    end
end

local function onAllHotbarsUpdated()
    ATTB.ScheduleSnapshot("hotbars-changed", { "skills", "champion" })
end

local function onEquipmentChanged(_, bagId)
    if bagId == BAG_WORN then
        ATTB.ScheduleSnapshot("equipment-changed", { "equipment" })
    end
end

local function onPlayerDeactivated()
    EVENT_MANAGER:UnregisterForUpdate(ATTB.updateRegistrationName)
    clearPending()
    ATTB.CaptureSnapshot("player-deactivated", { forceFull = true })
end

function ATTB.RegisterRefreshEvents()
    if ATTB.runtime.eventsRegistered then
        return
    end
    ATTB.runtime.eventsRegistered = true

    EVENT_MANAGER:RegisterForEvent(ATTB.eventNamespacePrefix .. "Level", EVENT_LEVEL_UPDATE, onPlayerLevelChanged)
    EVENT_MANAGER:RegisterForEvent(ATTB.eventNamespacePrefix .. "ChampionPoints", EVENT_CHAMPION_POINT_UPDATE, onChampionPointsChanged)
    EVENT_MANAGER:RegisterForEvent(ATTB.eventNamespacePrefix .. "ChampionPurchase", EVENT_CHAMPION_PURCHASE_RESULT, function()
        ATTB.ScheduleSnapshot("champion-purchase", { "identity", "champion" })
    end)
    EVENT_MANAGER:RegisterForEvent(ATTB.eventNamespacePrefix .. "SkillPoints", EVENT_SKILL_POINTS_CHANGED, onSkillsChanged)
    EVENT_MANAGER:RegisterForEvent(ATTB.eventNamespacePrefix .. "SkillRank", EVENT_SKILL_RANK_UPDATE, onSkillsChanged)
    EVENT_MANAGER:RegisterForEvent(ATTB.eventNamespacePrefix .. "SkillLineAdded", EVENT_SKILL_LINE_ADDED, onSkillsChanged)
    EVENT_MANAGER:RegisterForEvent(ATTB.eventNamespacePrefix .. "SkillsFull", EVENT_SKILLS_FULL_UPDATE, onSkillsChanged)
    EVENT_MANAGER:RegisterForEvent(ATTB.eventNamespacePrefix .. "AbilityRank", EVENT_ABILITY_PROGRESSION_RANK_UPDATE, onSkillsChanged)
    EVENT_MANAGER:RegisterForEvent(ATTB.eventNamespacePrefix .. "AbilityResult", EVENT_ABILITY_PROGRESSION_RESULT, onSkillsChanged)
    EVENT_MANAGER:RegisterForEvent(ATTB.eventNamespacePrefix .. "HotbarSlot", EVENT_HOTBAR_SLOT_UPDATED, onHotbarSlotUpdated)
    EVENT_MANAGER:RegisterForEvent(ATTB.eventNamespacePrefix .. "AllHotbars", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, onAllHotbarsUpdated)
    EVENT_MANAGER:RegisterForEvent(ATTB.eventNamespacePrefix .. "WeaponPair", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function()
        ATTB.ScheduleSnapshot("weapon-pair-changed", { "skills" })
    end)
    EVENT_MANAGER:RegisterForEvent(ATTB.eventNamespacePrefix .. "Attributes", EVENT_ATTRIBUTE_UPGRADE_UPDATED, function()
        ATTB.ScheduleSnapshot("attributes-changed", { "identity" })
    end)

    local equipmentEventName = ATTB.eventNamespacePrefix .. "Equipment"
    EVENT_MANAGER:RegisterForEvent(equipmentEventName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, onEquipmentChanged)
    EVENT_MANAGER:AddFilterForEvent(
        equipmentEventName,
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID,
        BAG_WORN
    )
    EVENT_MANAGER:AddFilterForEvent(
        equipmentEventName,
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_INVENTORY_UPDATE_REASON,
        INVENTORY_UPDATE_REASON_DEFAULT
    )

    EVENT_MANAGER:RegisterForEvent(ATTB.eventNamespacePrefix .. "Deactivated", EVENT_PLAYER_DEACTIVATED, onPlayerDeactivated)
end

local function latestStoredSnapshot(saved)
    local latest = nil
    local latestCapturedAt = 0
    for _, snapshot in pairs(saved.characters or {}) do
        local capturedAt = type(snapshot) == "table" and tonumber(snapshot.capturedAt or 0) or 0
        if capturedAt > latestCapturedAt then
            latest = snapshot
            latestCapturedAt = capturedAt
        end
    end
    return latest
end

local function registerSlashCommands()
    SLASH_COMMANDS[ATTB.slashCommandExport] = function()
        local ok, snapshot = ATTB.CaptureSnapshot("manual-export", { forceFull = true })
        if ok then
            Util.Print(string.format(
                "Snapshot refreshed for %s. Run /reloadui when you want the desktop app to read it immediately.",
                snapshot.identity.name or "current character"
            ))
        else
            Util.Print("Snapshot refresh failed. Enable Lua errors and report the error shown by ESO.")
        end
    end

    SLASH_COMMANDS[ATTB.slashCommandStatus] = function()
        local saved = ATTB.savedVariables or {}
        local latest = latestStoredSnapshot(saved)
        local pending = sortedSetValues(ATTB.runtime.pendingSections)
        Util.Print(string.format("Addon v%s; ESO API %d; world %s", ATTB.version, GetAPIVersion(), GetWorldName()))
        Util.Print(string.format(
            "Stored snapshots: %d character(s); revision %d",
            Util.TableCount(saved.characters),
            tonumber(saved.revision or 0) or 0
        ))
        if latest then
            local identity = latest.identity or {}
            Util.Print(string.format(
                "Latest: %s; %s; %s",
                identity.name or "Unknown",
                latest.captureReason or "unknown reason",
                Util.FormatAge(latest.capturedAt)
            ))
        end
        if #pending > 0 then
            Util.Print("Pending in-memory refresh: " .. table.concat(pending, ", "))
        end
        Util.Print("ESO controls SavedVariables disk writes. Use /reloadui for an immediate desktop refresh.")
    end

    SLASH_COMMANDS[ATTB.slashCommandCharacters] = function()
        local entries = {}
        for _, snapshot in pairs((ATTB.savedVariables and ATTB.savedVariables.characters) or {}) do
            local identity = type(snapshot) == "table" and snapshot.identity or nil
            local metadata = type(snapshot) == "table" and snapshot.metadata or nil
            table.insert(entries, {
                name = identity and tostring(identity.name or "Unknown") or "Unknown",
                level = identity and tonumber(identity.level or 0) or 0,
                championPoints = identity and tonumber(identity.championPoints or 0) or 0,
                characterId = identity and tostring(identity.characterId or "Unknown") or "Unknown",
                captureCount = metadata and tonumber(metadata.captureCount or 0) or 0,
            })
        end
        table.sort(entries, function(left, right) return left.name < right.name end)

        if #entries == 0 then
            Util.Print("No character snapshots are currently stored.")
            return
        end

        Util.Print(string.format("%d character snapshot(s) stored:", #entries))
        for _, entry in ipairs(entries) do
            local progression = entry.championPoints > 0
                and string.format("CP %d", entry.championPoints)
                or string.format("Level %d", entry.level)
            Util.Print(string.format(
                "%s; %s; ID %s; captures %d",
                entry.name,
                progression,
                entry.characterId,
                entry.captureCount
            ))
        end
    end
end

function ATTB.OnPlayerActivated()
    ATTB.ScheduleSnapshot("player-activated", ALL_SECTIONS, 500, { forceFull = true, bypassCooldown = true })
end

function ATTB.OnAddonLoaded(_, addonName)
    if addonName ~= ATTB.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ATTB.name, EVENT_ADD_ON_LOADED)
    initializeSavedVariables()
    ATTB.RegisterRefreshEvents()
    registerSlashCommands()
    ATTB.runtime.initialized = true

    EVENT_MANAGER:RegisterForEvent(ATTB.eventNamespacePrefix .. "Activated", EVENT_PLAYER_ACTIVATED, ATTB.OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(ATTB.name, EVENT_ADD_ON_LOADED, ATTB.OnAddonLoaded)
