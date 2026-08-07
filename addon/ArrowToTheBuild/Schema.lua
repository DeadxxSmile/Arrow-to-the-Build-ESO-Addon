local ATTB = ArrowToTheBuild
local Util = ATTB.Util
local Schema = ATTB.Schema

local function shallowCopy(value)
    local result = {}
    if type(value) ~= "table" then
        return result
    end
    for key, item in pairs(value) do
        result[key] = item
    end
    return result
end

local function addAbilityLookup(byId, byName, ability, line)
    if type(ability) ~= "table" then
        return
    end

    local entry = {
        abilityId = ability.abilityId,
        baseAbilityId = ability.baseAbilityId,
        progressionId = ability.progressionId,
        name = ability.name,
        currentRank = ability.currentRank,
        currentMorph = ability.currentMorph,
        skillLineId = ability.skillLineId or (line and line.skillLineId),
    }

    for _, value in ipairs({
        ability.abilityId,
        ability.baseAbilityId,
        ability.morphAbilityId,
        ability.rankedAbilityId,
    }) do
        if value and value ~= 0 then
            byId[tostring(value)] = entry
        end
    end

    local nameKey = Util.NormalizeName(ability.name)
    if nameKey then
        if byName[nameKey] == nil then
            byName[nameKey] = entry
        else
            byName[nameKey] = false
        end
    end
end

local function buildAbilityLookup(lines)
    local byId = {}
    local byName = {}
    if type(lines) ~= "table" then
        return byId, byName
    end

    for _, line in ipairs(lines) do
        for _, ability in ipairs(line.abilities or {}) do
            addAbilityLookup(byId, byName, ability, line)
        end
    end
    return byId, byName
end

local function compactAbility(ability)
    return {
        abilityId = ability.abilityId,
        baseAbilityId = ability.baseAbilityId,
        progressionId = ability.progressionId,
        name = Util.CleanName(ability.name),
        currentRank = ability.currentRank or 0,
        currentMorph = ability.currentMorph or 0,
        passiveRank = ability.passiveRank,
        passiveMaxRank = ability.passiveMaxRank,
        isPassive = ability.isPassive == true,
        isUltimate = ability.isUltimate == true,
    }
end

local function compactSkills(skills)
    if type(skills) ~= "table" then
        return nil
    end

    local result = {
        lines = {},
        actionBars = {},
        activeWeaponPair = skills.activeWeaponPair and shallowCopy(skills.activeWeaponPair) or nil,
    }

    for _, line in ipairs(skills.lines or {}) do
        local compactLine = {
            skillType = line.skillType,
            skillTypeName = Util.CleanName(line.skillTypeName),
            skillLineId = line.skillLineId,
            name = Util.CleanName(line.name),
            rank = line.rank or 0,
            abilities = {},
        }
        if type(line.xp) == "table" then
            compactLine.xp = {
                current = line.xp.current,
                nextRank = line.xp.nextRank,
            }
        end
        for _, ability in ipairs(line.abilities or {}) do
            table.insert(compactLine.abilities, compactAbility(ability))
        end
        table.insert(result.lines, compactLine)
    end

    local byId, byName = buildAbilityLookup(skills.lines)
    for _, bar in ipairs(skills.actionBars or {}) do
        local compactBar = {
            category = bar.category,
            label = Util.CleanName(bar.label),
            slots = {},
        }
        for _, slot in ipairs(bar.slots or {}) do
            local match = nil
            local matchMethod = nil
            if slot.abilityId and slot.abilityId ~= 0 then
                match = byId[tostring(slot.abilityId)]
                if match then
                    matchMethod = "ability-id"
                end
            end
            if not match then
                local nameKey = Util.NormalizeName(slot.name)
                if nameKey and byName[nameKey] then
                    match = byName[nameKey]
                    matchMethod = "name"
                end
            end

            local compactSlot = {
                position = slot.position,
                abilityId = slot.abilityId or 0,
                name = Util.CleanName(slot.name or "Empty"),
                slotType = slot.slotType,
                isUltimate = slot.isUltimate == true,
            }
            if match then
                compactSlot.skillAbilityId = match.abilityId
                compactSlot.progressionId = match.progressionId
                compactSlot.skillLineId = match.skillLineId
                compactSlot.currentMorph = match.currentMorph or 0
                compactSlot.currentRank = match.currentRank or 0
                compactSlot.matchMethod = matchMethod
            end
            table.insert(compactBar.slots, compactSlot)
        end
        table.insert(result.actionBars, compactBar)
    end

    return result
end

local function compactEquipment(equipment)
    if type(equipment) ~= "table" then
        return nil
    end

    local result = { items = {} }
    for _, item in ipairs(equipment.items or {}) do
        local compactItem = {
            equipSlot = item.equipSlot,
            slotName = Util.CleanName(item.slotName),
            itemId = item.itemId,
            name = Util.CleanName(item.name),
            quality = item.quality,
            requiredLevel = item.requiredLevel,
            requiredChampionPoints = item.requiredChampionPoints,
            equipType = item.equipType,
            equipTypeName = Util.CleanName(item.equipTypeName),
            itemType = item.itemType,
            itemTypeName = Util.CleanName(item.itemTypeName),
            armorType = item.armorType,
            armorTypeName = Util.CleanName(item.armorTypeName),
            weaponType = item.weaponType,
            weaponTypeName = Util.CleanName(item.weaponTypeName or "None"),
        }
        if type(item.trait) == "table" then
            compactItem.trait = {
                id = item.trait.id,
                name = Util.CleanName(item.trait.name),
            }
        end
        if type(item.set) == "table" then
            compactItem.set = {
                hasSet = item.set.hasSet == true,
                id = item.set.id,
                name = Util.CleanName(item.set.name),
            }
        end
        if type(item.enchantment) == "table" then
            compactItem.enchantment = {
                name = Util.CleanName(item.enchantment.name),
            }
        end
        table.insert(result.items, compactItem)
    end
    return result
end

local function compactChampion(champion)
    if type(champion) ~= "table" then
        return nil
    end

    local result = {
        totalEarned = champion.totalEarned or 0,
        disciplines = {},
        slotted = {
            supported = champion.slotted and champion.slotted.supported == true or false,
            slots = {},
        },
    }

    for _, discipline in ipairs(champion.disciplines or {}) do
        local compactDiscipline = {
            disciplineId = discipline.disciplineId,
            name = Util.CleanName(discipline.name),
            spent = discipline.spent or 0,
            unspent = discipline.unspent or 0,
            stars = {},
        }
        for _, star in ipairs(discipline.stars or {}) do
            table.insert(compactDiscipline.stars, {
                skillId = star.skillId,
                name = Util.CleanName(star.name),
                points = star.points or 0,
                maximumPoints = star.maximumPoints,
                skillType = star.skillType,
                slottable = star.slottable == true,
            })
        end
        table.insert(result.disciplines, compactDiscipline)
    end

    for _, slot in ipairs((champion.slotted and champion.slotted.slots) or {}) do
        table.insert(result.slotted.slots, {
            position = slot.position,
            disciplineId = slot.disciplineId,
            disciplineName = Util.CleanName(slot.disciplineName),
            skillId = slot.skillId or 0,
            name = Util.CleanName(slot.name or "Empty"),
        })
    end

    return result
end

function Schema.CompactSnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return snapshot
    end

    return {
        snapshotSchemaVersion = ATTB.snapshotSchemaVersion,
        dataProfile = ATTB.snapshotDataProfile,
        addonVersion = ATTB.version,
        apiVersion = snapshot.apiVersion,
        capturedAt = snapshot.capturedAt,
        captureReason = snapshot.captureReason,
        identity = snapshot.identity,
        skills = compactSkills(snapshot.skills),
        equipment = compactEquipment(snapshot.equipment),
        champion = compactChampion(snapshot.champion),
        diagnostics = snapshot.diagnostics or { warnings = {}, errors = {} },
        metadata = snapshot.metadata,
        completeness = snapshot.completeness,
    }
end

function Schema.MigrateSavedCharacters(saved)
    if type(saved) ~= "table" or type(saved.characters) ~= "table" then
        return 0
    end

    local migrated = 0
    for characterKey, snapshot in pairs(saved.characters) do
        if type(snapshot) == "table" and (
            snapshot.snapshotSchemaVersion ~= ATTB.snapshotSchemaVersion
            or snapshot.dataProfile ~= ATTB.snapshotDataProfile
        ) then
            saved.characters[characterKey] = Schema.CompactSnapshot(snapshot)
            migrated = migrated + 1
        end
    end

    if migrated > 0 then
        saved.revision = (saved.revision or 0) + 1
        saved.lastMigrationAt = Util.Now()
        saved.lastMigrationVersion = ATTB.version
        saved.lastMigratedCharacterCount = migrated
    end
    return migrated
end
