-- Arrow to the Build - SavedVariables sync bridge.
--
-- ESO controls when SavedVariables reach disk. The durable ArrowToTheBuild addon
-- keeps the multi-character archive; this companion addon keeps only one bounded,
-- ID-first current-character payload so ESO can evaluate it independently for
-- normal-play SavedVariables writes.
--
-- Schema 2 intentionally stores the large repeating datasets as packed row blobs
-- (tab-separated fields, newline-separated rows). That avoids hundreds of Lua
-- table wrappers/keys in ESO's serialized file and gives the bridge a predictable
-- size ceiling while remaining a data-only SavedVariables document.

ArrowToTheBuildBridge = ArrowToTheBuildBridge or {}
local Bridge = ArrowToTheBuildBridge
local ATTB = ArrowToTheBuild
local Util = ATTB and ATTB.Util

Bridge.name = "ArrowToTheBuildBridge"
Bridge.version = "1.0.0"
Bridge.schemaVersion = 2
Bridge.minimumPrioritySaveIntervalSeconds = 900
Bridge.budgetBytes = 32768
Bridge.nearBudgetBytes = 28672
Bridge.savedVariables = nil
Bridge.runtime = Bridge.runtime or {
    initialized = false,
    loadedRevision = 0,
    lastPrioritySaveRequestAt = 0,
    lastPrioritySaveStatus = "never",
    lastPublishAt = 0,
    priorityDeferred = false,
    priorityDeferredUntil = 0,
    priorityDirty = false,
}


Bridge.deferredPriorityUpdateName = "ArrowToTheBuildBridgePriorityRetry"

local function clearDeferredPriorityRetry()
    if EVENT_MANAGER and type(EVENT_MANAGER.UnregisterForUpdate) == "function" then
        EVENT_MANAGER:UnregisterForUpdate(Bridge.deferredPriorityUpdateName)
    end
    Bridge.runtime.priorityDeferred = false
    Bridge.runtime.priorityDeferredUntil = 0
end

local function scheduleDeferredPriorityRetry()
    if not Bridge.runtime.priorityDirty then
        clearDeferredPriorityRetry()
        return false
    end
    local now = Util and Util.Now() or 0
    local eligibleAt = (Bridge.runtime.lastPrioritySaveRequestAt or 0) + Bridge.minimumPrioritySaveIntervalSeconds
    local remainingSeconds = math.max(1, eligibleAt - now)
    Bridge.runtime.priorityDeferred = true
    Bridge.runtime.priorityDeferredUntil = eligibleAt
    Bridge.runtime.lastPrioritySaveStatus = "deferred"

    if EVENT_MANAGER and type(EVENT_MANAGER.RegisterForUpdate) == "function" then
        if type(EVENT_MANAGER.UnregisterForUpdate) == "function" then
            EVENT_MANAGER:UnregisterForUpdate(Bridge.deferredPriorityUpdateName)
        end
        EVENT_MANAGER:RegisterForUpdate(Bridge.deferredPriorityUpdateName, math.max(250, (remainingSeconds * 1000) + 100), function()
            if type(EVENT_MANAGER.UnregisterForUpdate) == "function" then
                EVENT_MANAGER:UnregisterForUpdate(Bridge.deferredPriorityUpdateName)
            end
            Bridge.runtime.priorityDeferred = false
            Bridge.runtime.priorityDeferredUntil = 0
            if not Bridge.runtime.priorityDirty then
                return
            end
            local requested, status = Bridge.RequestPrioritySave(false)
            if not requested and status == "throttled" then
                scheduleDeferredPriorityRetry()
            end
        end)
        return true
    end
    return false
end

local function cleanField(value)
    if value == nil then
        return ""
    end
    local text = tostring(value)
    -- Tabs/newlines are structural delimiters in schema 2. ESO display strings
    -- are sanitized before packing so one localized/item name cannot corrupt a row.
    text = string.gsub(text, "[\t\r\n]", " ")
    return text
end

local function pack(...)
    local count = select("#", ...)
    local result = {}
    for index = 1, count do
        result[index] = cleanField(select(index, ...))
    end
    return table.concat(result, "\t")
end

local function rowsBlob(rows)
    return table.concat(rows or {}, "\n")
end

local function boolNumber(value)
    return value == true and 1 or 0
end

local function abilityFlags(ability)
    local flags = 0
    if ability and ability.isPassive == true then flags = flags + 1 end
    if ability and ability.isUltimate == true then flags = flags + 2 end
    return flags
end

-- Estimate the eventual ESO SavedVariables representation rather than merely the
-- in-memory Lua payload. The packed-blob schema has very few table wrappers, so a
-- 1.5x multiplier plus fixed headroom is deliberately conservative in fixtures
-- while still allowing a realistic fully-developed character under the 32 KiB
-- internal budget. The real on-disk size is also shown by the desktop after ESO
-- writes the file and remains the final authority.
local function estimateValue(value, seen)
    local valueType = type(value)
    if valueType == "nil" then
        return 4
    end
    if valueType == "boolean" then
        return value and 4 or 5
    end
    if valueType == "number" then
        return string.len(tostring(value)) + 2
    end
    if valueType == "string" then
        local escaped = string.gsub(value, "[\\\"\n\r\t]", "xx")
        return string.len(escaped) + 6
    end
    if valueType ~= "table" then
        return string.len(tostring(value)) + 8
    end

    seen = seen or {}
    if seen[value] then
        return 8
    end
    seen[value] = true
    local total = 8
    for key, item in pairs(value) do
        total = total + estimateValue(key, seen) + estimateValue(item, seen) + 10
    end
    seen[value] = nil
    return total
end

local function estimateSerializedBytes(root)
    return math.ceil((estimateValue(root) * 1.5) + 512)
end

local function compactIdentity(identity)
    identity = identity or {}
    local progression = identity.progression or {}
    local attributes = identity.attributes or {}
    -- Character/class/race/alliance names are intentionally retained. They are
    -- tiny identity data and allow first discovery before the full archive saves.
    return pack(
        identity.accountName,
        identity.worldName,
        identity.characterId,
        identity.name,
        identity.class and identity.class.id,
        identity.class and identity.class.name,
        identity.race and identity.race.id,
        identity.race and identity.race.name,
        identity.alliance and identity.alliance.id,
        identity.alliance and identity.alliance.name,
        identity.level,
        identity.championPoints,
        identity.championPointsEarned,
        progression.availableAttributePoints,
        progression.availableSkillPoints,
        attributes.magicka and attributes.magicka.spentPoints,
        attributes.health and attributes.health.spentPoints,
        attributes.stamina and attributes.stamina.spentPoints
    )
end

local function compactSkills(skills, options)
    skills = skills or {}
    options = options or {}
    local lineRows = {}
    local abilityRows = {}
    local actionBarRows = {}

    if not options.dropSkills then
        for _, line in ipairs(skills.lines or {}) do
            -- ID-first: names are resolved/enriched on desktop from the durable
            -- archive. Each ability carries its line ID so the arrays stay flat.
            table.insert(lineRows, pack(line.skillType, line.skillLineId, line.rank))
            for _, ability in ipairs(line.abilities or {}) do
                table.insert(abilityRows, pack(
                    line.skillLineId,
                    ability.abilityId,
                    ability.progressionId,
                    ability.currentRank,
                    ability.currentMorph,
                    ability.passiveRank,
                    abilityFlags(ability)
                ))
            end
        end

        for _, bar in ipairs(skills.actionBars or {}) do
            for _, slot in ipairs(bar.slots or {}) do
                table.insert(actionBarRows, pack(
                    bar.category,
                    slot.position,
                    slot.abilityId,
                    slot.slotType,
                    boolNumber(slot.isUltimate),
                    slot.skillAbilityId,
                    slot.progressionId,
                    slot.skillLineId,
                    slot.currentMorph,
                    slot.currentRank
                ))
            end
        end
    end

    return {
        activeWeaponPair = pack(
            skills.activeWeaponPair and skills.activeWeaponPair.pair,
            boolNumber(skills.activeWeaponPair and skills.activeWeaponPair.locked)
        ),
        lines = rowsBlob(lineRows),
        abilities = rowsBlob(abilityRows),
        actionBars = rowsBlob(actionBarRows),
    }
end

local function compactEquipment(equipment, options)
    options = options or {}
    if options.dropEquipment then
        return ""
    end

    local rows = {}
    for _, item in ipairs((equipment and equipment.items) or {}) do
        local itemName = options.dropEquipmentNames and "" or item.name
        local setName = options.dropEquipmentNames and "" or (item.set and item.set.name)
        local enchantmentName = options.dropEnchantments and "" or (item.enchantment and item.enchantment.name)
        table.insert(rows, pack(
            item.equipSlot,
            item.itemId,
            itemName,
            item.quality,
            item.requiredLevel,
            item.requiredChampionPoints,
            item.equipType,
            item.itemType,
            item.armorType,
            item.weaponType,
            item.trait and item.trait.id,
            item.set and item.set.id,
            setName,
            enchantmentName
        ))
    end
    return rowsBlob(rows)
end

local function compactChampion(champion, options)
    champion = champion or {}
    options = options or {}
    local disciplineRows = {}
    local starRows = {}
    local slotRows = {}

    -- Discipline totals are tiny and remain even when detailed CP rows must be
    -- dropped, because tree totals are useful core character progression data.
    for _, discipline in ipairs(champion.disciplines or {}) do
        table.insert(disciplineRows, pack(discipline.disciplineId, discipline.spent, discipline.unspent))
        if not options.dropChampionDetails then
            for _, star in ipairs(discipline.stars or {}) do
                table.insert(starRows, pack(
                    discipline.disciplineId,
                    star.skillId,
                    star.points,
                    star.maximumPoints,
                    star.skillType,
                    boolNumber(star.slottable)
                ))
            end
        end
    end

    if not options.dropChampionDetails then
        for _, slot in ipairs((champion.slotted and champion.slotted.slots) or {}) do
            table.insert(slotRows, pack(slot.position, slot.disciplineId, slot.skillId))
        end
    end

    return {
        totalEarned = champion.totalEarned or 0,
        disciplines = rowsBlob(disciplineRows),
        stars = rowsBlob(starRows),
        slots = rowsBlob(slotRows),
    }
end

local function buildCharacter(snapshot, options)
    return {
        identity = compactIdentity(snapshot.identity),
        skills = compactSkills(snapshot.skills, options),
        equipment = compactEquipment(snapshot.equipment, options),
        champion = compactChampion(snapshot.champion, options),
    }
end

local function copyList(values)
    local result = {}
    for _, value in ipairs(values or {}) do
        table.insert(result, value)
    end
    return result
end

local function buildRoot(snapshot, revision, createdAt, priorityAt, options, reducedFields, droppedSections)
    local now = tonumber(snapshot.capturedAt or 0) or (Util and Util.Now() or 0)
    return {
        schemaVersion = Bridge.schemaVersion,
        addonVersion = Bridge.version,
        apiVersion = snapshot.apiVersion or (Util and Util.GetApiVersion() or 0),
        revision = revision,
        createdAt = createdAt,
        capturedAt = now,
        captureReason = snapshot.captureReason or "unspecified",
        characterKey = tostring(snapshot.identity.characterKey or ""),
        capturedSections = snapshot.metadata and snapshot.metadata.capturedSections or {},
        estimatedBytes = 0,
        budgetBytes = Bridge.budgetBytes,
        budgetStatus = "ok",
        truncated = #droppedSections > 0,
        reducedFields = copyList(reducedFields),
        droppedSections = copyList(droppedSections),
        lastPrioritySaveRequestedAt = priorityAt,
        character = buildCharacter(snapshot, options),
    }
end

local function finalizeEstimate(root)
    -- estimatedBytes changes the serialized root slightly, so settle twice.
    root.estimatedBytes = estimateSerializedBytes(root)
    root.estimatedBytes = estimateSerializedBytes(root)
    local estimated = root.estimatedBytes
    if root.truncated then
        root.budgetStatus = estimated <= Bridge.budgetBytes and "truncated" or "over-budget"
    elseif estimated >= Bridge.nearBudgetBytes then
        root.budgetStatus = estimated <= Bridge.budgetBytes and "near" or "over-budget"
    else
        root.budgetStatus = "ok"
    end
    root.estimatedBytes = estimateSerializedBytes(root)
    return root.estimatedBytes
end

local function buildBudgetedRoot(snapshot, revision, createdAt, priorityAt)
    -- Deterministic degradation order. Identity and core numeric progression are
    -- never discarded. Display metadata goes first; only then can whole detail
    -- sections become partial, with that fact explicitly encoded for desktop UI.
    local stages = {
        { options = {}, reduced = {}, dropped = {} },
        { options = { dropEnchantments = true }, reduced = { "equipment-enchantments" }, dropped = {} },
        { options = { dropEnchantments = true, dropEquipmentNames = true }, reduced = { "equipment-enchantments", "equipment-display-names" }, dropped = {} },
        { options = { dropEnchantments = true, dropEquipmentNames = true, dropChampionDetails = true }, reduced = { "equipment-enchantments", "equipment-display-names" }, dropped = { "champion-details" } },
        { options = { dropEnchantments = true, dropEquipmentNames = true, dropChampionDetails = true, dropEquipment = true }, reduced = { "equipment-enchantments", "equipment-display-names" }, dropped = { "champion-details", "equipment" } },
        { options = { dropEnchantments = true, dropEquipmentNames = true, dropChampionDetails = true, dropEquipment = true, dropSkills = true }, reduced = { "equipment-enchantments", "equipment-display-names" }, dropped = { "champion-details", "equipment", "skills" } },
    }

    local lastRoot = nil
    for _, stage in ipairs(stages) do
        local root = buildRoot(snapshot, revision, createdAt, priorityAt, stage.options, stage.reduced, stage.dropped)
        local estimated = finalizeEstimate(root)
        lastRoot = root
        if estimated <= Bridge.budgetBytes then
            return root
        end
    end
    return lastRoot
end

local function initializeSavedVariables()
    if type(ArrowToTheBuildBridgeSavedVariables) ~= "table" then
        ArrowToTheBuildBridgeSavedVariables = {}
    end
    local saved = ArrowToTheBuildBridgeSavedVariables
    Bridge.runtime.loadedRevision = tonumber(saved.revision or 0) or 0
    Bridge.runtime.lastPrioritySaveRequestAt = tonumber(saved.lastPrioritySaveRequestedAt or 0) or 0
    -- Preserve an older on-disk bridge contract exactly as ESO loaded it. The
    -- first real PublishSnapshot replaces the whole root with schema 2. This
    -- avoids an older bridge payload being saved while falsely advertising schema 2.
    if saved.schemaVersion == nil then
        saved.schemaVersion = Bridge.schemaVersion
        saved.addonVersion = Bridge.version
        saved.apiVersion = Util and Util.GetApiVersion() or 0
        saved.revision = saved.revision or 0
        saved.createdAt = saved.createdAt or (Util and Util.Now() or 0)
        saved.budgetBytes = Bridge.budgetBytes
    end
    Bridge.savedVariables = saved
end

function Bridge.RequestPrioritySave(force)
    if not Bridge.savedVariables then
        initializeSavedVariables()
    end
    if tonumber(Bridge.savedVariables.estimatedBytes or 0) > Bridge.budgetBytes then
        Bridge.runtime.lastPrioritySaveStatus = "over-budget"
        return false, "over-budget"
    end

    local now = Util and Util.Now() or 0
    local elapsed = now - (Bridge.runtime.lastPrioritySaveRequestAt or 0)
    if not force and elapsed < Bridge.minimumPrioritySaveIntervalSeconds then
        Bridge.runtime.lastPrioritySaveStatus = "throttled"
        scheduleDeferredPriorityRetry()
        return false, "throttled"
    end

    local succeeded = false
    if type(GetAddOnManager) == "function" then
        local managerSucceeded, manager = pcall(GetAddOnManager)
        if managerSucceeded and manager and type(manager.RequestAddOnSavedVariablesPrioritySave) == "function" then
            local callSucceeded, result = pcall(function()
                return manager:RequestAddOnSavedVariablesPrioritySave(Bridge.name)
            end)
            succeeded = callSucceeded and result ~= false
        end
    end
    if not succeeded and type(RequestAddOnSavedVariablesPrioritySave) == "function" then
        local callSucceeded, result = pcall(RequestAddOnSavedVariablesPrioritySave, Bridge.name)
        succeeded = callSucceeded and result ~= false
    end

    if succeeded then
        Bridge.runtime.lastPrioritySaveRequestAt = now
        Bridge.runtime.lastPrioritySaveStatus = "requested"
        Bridge.runtime.priorityDirty = false
        clearDeferredPriorityRetry()
        Bridge.savedVariables.lastPrioritySaveRequestedAt = now
        Bridge.savedVariables.lastPrioritySaveWasForced = force == true
        return true, "requested"
    end
    Bridge.runtime.lastPrioritySaveStatus = "unavailable"
    return false, "unavailable"
end

function Bridge.PublishSnapshot(snapshot, forcePrioritySave)
    if type(snapshot) ~= "table" or type(snapshot.identity) ~= "table" then
        return false, "invalid-snapshot"
    end
    if not Bridge.savedVariables then
        initializeSavedVariables()
    end

    local characterKey = snapshot.identity.characterKey
    if not characterKey or characterKey == "" then
        return false, "character-key-unavailable"
    end

    -- Replace the complete root every publish. Nothing accumulates across a play
    -- session, which gives the bridge a natural maximum size.
    local previous = Bridge.savedVariables or {}
    local revision = (tonumber(previous.revision or 0) or 0) + 1
    local createdAt = tonumber(previous.createdAt or 0) or (Util and Util.Now() or 0)
    local priorityAt = tonumber(previous.lastPrioritySaveRequestedAt or Bridge.runtime.lastPrioritySaveRequestAt or 0) or 0
    local saved = buildBudgetedRoot(snapshot, revision, createdAt, priorityAt)
    ArrowToTheBuildBridgeSavedVariables = saved
    Bridge.savedVariables = saved
    Bridge.runtime.lastPublishAt = tonumber(saved.capturedAt or 0) or 0

    -- Every meaningful normal-play publish makes the bridge dirty until a priority
    -- request is successfully issued. Multiple changes during the 15-minute API
    -- window coalesce into this single newest root and one deferred retry.
    Bridge.runtime.priorityDirty = snapshot.captureReason ~= "player-activated" and snapshot.captureReason ~= "player-deactivated"

    -- Logout/reload deactivation is already a natural SavedVariables flush point.
    -- Do not burn the bridge's scarce priority request immediately before that
    -- guaranteed save, or the persisted 15-minute throttle would carry into the
    -- next login and make the first gameplay changes less responsive.
    if snapshot.captureReason == "player-deactivated" then
        Bridge.runtime.priorityDirty = false
        clearDeferredPriorityRetry()
        Bridge.runtime.lastPrioritySaveStatus = "natural-save"
        return true, saved, false, "natural-save"
    end

    -- EVENT_PLAYER_ACTIVATED fires after a loading screen. Publish the fresh
    -- post-load snapshot but preserve the scarce priority request for the first
    -- actual gameplay change rather than immediately entering our cooldown.
    if snapshot.captureReason == "player-activated" then
        Bridge.runtime.lastPrioritySaveStatus = "normal-cycle"
        return true, saved, false, "normal-cycle"
    end

    local requested, status = Bridge.RequestPrioritySave(forcePrioritySave == true)
    return true, saved, requested, status
end

function Bridge.GetStatus()
    local saved = Bridge.savedVariables or {}
    return {
        version = Bridge.version,
        revision = tonumber(saved.revision or 0) or 0,
        loadedRevision = tonumber(Bridge.runtime.loadedRevision or 0) or 0,
        lastPublishAt = tonumber(Bridge.runtime.lastPublishAt or saved.capturedAt or 0) or 0,
        lastPrioritySaveStatus = Bridge.runtime.lastPrioritySaveStatus or "never",
        priorityDirty = Bridge.runtime.priorityDirty == true,
        priorityDeferred = Bridge.runtime.priorityDeferred == true,
        priorityDeferredUntil = tonumber(Bridge.runtime.priorityDeferredUntil or 0) or 0,
        priorityRetrySeconds = math.max(0, (tonumber(Bridge.runtime.priorityDeferredUntil or 0) or 0) - (Util and Util.Now() or 0)),
        estimatedBytes = tonumber(saved.estimatedBytes or 0) or 0,
        budgetBytes = tonumber(saved.budgetBytes or Bridge.budgetBytes) or Bridge.budgetBytes,
        budgetStatus = tostring(saved.budgetStatus or "unknown"),
        truncated = saved.truncated == true,
    }
end

function Bridge.OnAddonLoaded(_, addonName)
    if addonName ~= Bridge.name then
        return
    end
    initializeSavedVariables()
    Bridge.runtime.initialized = true
    if EVENT_MANAGER and type(EVENT_MANAGER.UnregisterForEvent) == "function" then
        EVENT_MANAGER:UnregisterForEvent(Bridge.name, EVENT_ADD_ON_LOADED)
    end
end

if EVENT_MANAGER and type(EVENT_MANAGER.RegisterForEvent) == "function" then
    EVENT_MANAGER:RegisterForEvent(Bridge.name, EVENT_ADD_ON_LOADED, Bridge.OnAddonLoaded)
end
