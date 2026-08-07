local ATTB = ArrowToTheBuild
local Util = ATTB.Util
local Collector = {}
ATTB.Collectors.Skills = Collector

local SKILL_TYPE_FALLBACK_NAMES = {
    [1] = "Class",
    [2] = "Weapon",
    [3] = "Armor",
    [4] = "World",
    [5] = "Guild",
    [6] = "Alliance War",
    [7] = "Racial",
    [8] = "Craft",
    [9] = "Companion",
}

local function getSkillTypeName(skillType)
    local apiName = Util.GetStringForEnum("SI_SKILLTYPE", skillType, nil)
    return apiName or SKILL_TYPE_FALLBACK_NAMES[skillType] or ("Skill Type " .. tostring(skillType))
end

local function getCurrentAbilityIds(skillType, lineIndex, abilityIndex, progressionIndex, currentMorph, currentRank)
    local baseAbilityId = Util.Value(
        "GetSkillAbilityId",
        nil,
        skillType,
        lineIndex,
        abilityIndex,
        false
    )

    local progressionId = Util.Value(
        "GetProgressionSkillProgressionId",
        nil,
        skillType,
        lineIndex,
        abilityIndex
    )

    local morphAbilityId = nil
    if currentMorph and currentMorph > 0 and progressionId then
        morphAbilityId = Util.Value(
            "GetProgressionSkillMorphSlotAbilityId",
            nil,
            progressionId,
            currentMorph
        )
    end

    local rankedAbilityId = nil
    if progressionIndex and progressionIndex > 0 and type(GetAbilityProgressionAbilityId) == "function" then
        local morph = currentMorph or 0
        local rank = currentRank or 1
        if rank < 1 then
            rank = 1
        end
        rankedAbilityId = Util.Value(
            "GetAbilityProgressionAbilityId",
            nil,
            progressionIndex,
            morph,
            rank
        )
    end

    return {
        abilityId = morphAbilityId or rankedAbilityId or baseAbilityId,
        baseAbilityId = baseAbilityId,
        morphAbilityId = morphAbilityId,
        rankedAbilityId = rankedAbilityId,
        progressionId = progressionId,
    }
end

local function collectAbility(skillType, lineIndex, abilityIndex, lineId)
    local succeeded, abilityName, _, _, passive, ultimate, purchased, progressionIndex, rankIndex =
        Util.SafeCall("GetSkillAbilityInfo", skillType, lineIndex, abilityIndex)

    if not succeeded or not abilityName or purchased ~= true then
        return nil, nil
    end

    local currentMorph = 0
    local currentRank = rankIndex or 0
    if progressionIndex and progressionIndex > 0 then
        local progressionSucceeded, _, morph, rank = Util.SafeCall("GetAbilityProgressionInfo", progressionIndex)
        if progressionSucceeded then
            currentMorph = morph or 0
            currentRank = rank or currentRank
        end
    end

    local passiveRank = nil
    local passiveMaxRank = nil
    if passive then
        local upgradeSucceeded, currentUpgradeRank, maximumUpgradeRank =
            Util.SafeCall("GetSkillAbilityUpgradeInfo", skillType, lineIndex, abilityIndex)
        if upgradeSucceeded then
            passiveRank = currentUpgradeRank
            passiveMaxRank = maximumUpgradeRank
        end
    end

    local ids = getCurrentAbilityIds(
        skillType,
        lineIndex,
        abilityIndex,
        progressionIndex,
        currentMorph,
        currentRank
    )

    local compact = {
        abilityId = ids.abilityId,
        baseAbilityId = ids.baseAbilityId,
        progressionId = ids.progressionId,
        name = Util.CleanName(abilityName),
        currentRank = currentRank or 0,
        currentMorph = currentMorph or 0,
        passiveRank = passiveRank,
        passiveMaxRank = passiveMaxRank,
        isPassive = passive == true,
        isUltimate = ultimate == true,
    }

    local lookup = {
        ability = compact,
        skillLineId = lineId,
        ids = {
            ids.abilityId,
            ids.baseAbilityId,
            ids.morphAbilityId,
            ids.rankedAbilityId,
        },
    }
    return compact, lookup
end

local function addLookup(byId, byName, lookup)
    if not lookup then
        return
    end
    for _, value in ipairs(lookup.ids or {}) do
        if value and value ~= 0 then
            byId[tostring(value)] = lookup
        end
    end
    local nameKey = Util.NormalizeName(lookup.ability and lookup.ability.name)
    if nameKey then
        if byName[nameKey] == nil then
            byName[nameKey] = lookup
        else
            byName[nameKey] = false
        end
    end
end

local function collectActionBar(hotbarCategory, label, byId, byName)
    local firstSlot = (ACTION_BAR_FIRST_NORMAL_SLOT_INDEX or 2) + 1
    local ultimateSlot = (ACTION_BAR_ULTIMATE_SLOT_INDEX or 7) + 1
    local slots = {}

    for slotIndex = firstSlot, ultimateSlot do
        local abilityId = Util.Value("GetSlotBoundId", 0, slotIndex, hotbarCategory)
        local slotType = Util.Value("GetSlotType", nil, slotIndex, hotbarCategory)
        local name = nil
        if abilityId and abilityId > 0 then
            name = Util.Value("GetAbilityName", nil, abilityId, "player")
            if (not name or name == "") and slotType == ACTION_TYPE_CRAFTED_ABILITY then
                name = Util.Value("GetCraftedAbilityDisplayName", nil, abilityId)
            end
        end

        local match = nil
        local matchMethod = nil
        if abilityId and abilityId > 0 then
            match = byId[tostring(abilityId)]
            if match then
                matchMethod = "ability-id"
            end
        end
        if not match then
            local nameKey = Util.NormalizeName(name)
            if nameKey and byName[nameKey] then
                match = byName[nameKey]
                matchMethod = "name"
            end
        end

        local slot = {
            position = slotIndex - firstSlot + 1,
            abilityId = abilityId or 0,
            name = Util.CleanName(name or "Empty"),
            slotType = slotType,
            isUltimate = slotIndex == ultimateSlot,
        }
        if match and match.ability then
            slot.skillAbilityId = match.ability.abilityId
            slot.progressionId = match.ability.progressionId
            slot.skillLineId = match.skillLineId
            slot.currentMorph = match.ability.currentMorph or 0
            slot.currentRank = match.ability.currentRank or 0
            slot.matchMethod = matchMethod
        end
        table.insert(slots, slot)
    end

    return {
        category = hotbarCategory,
        label = label,
        slots = slots,
    }
end

function Collector.Collect()
    local result = {
        lines = {},
        actionBars = {},
        activeWeaponPair = nil,
    }
    local byId = {}
    local byName = {}

    local maxSkillType = Util.Value("GetNumSkillTypes", 9)
    if not maxSkillType or maxSkillType < 9 then
        maxSkillType = 9
    end

    for skillType = 1, maxSkillType do
        local lineCount = Util.Value("GetNumSkillLines", 0, skillType)
        for lineIndex = 1, lineCount do
            local dynamicSucceeded, rank, _, _, discovered =
                Util.SafeCall("GetSkillLineDynamicInfo", skillType, lineIndex)
            local lineId = Util.Value("GetSkillLineId", nil, skillType, lineIndex)
            local lineName = lineId and Util.Value("GetSkillLineNameById", nil, lineId) or nil

            if dynamicSucceeded and discovered and lineName and lineName ~= "" then
                local xpSucceeded, _, nextRankXp, currentXp =
                    Util.SafeCall("GetSkillLineXPInfo", skillType, lineIndex)
                local lineEntry = {
                    skillType = skillType,
                    skillTypeName = getSkillTypeName(skillType),
                    skillLineId = lineId,
                    name = Util.CleanName(lineName),
                    rank = rank or 0,
                    xp = xpSucceeded and {
                        nextRank = nextRankXp or 0,
                        current = currentXp or 0,
                    } or nil,
                    abilities = {},
                }

                local abilityCount = Util.Value("GetNumSkillAbilities", 0, skillType, lineIndex)
                for abilityIndex = 1, abilityCount do
                    local ability, lookup = collectAbility(skillType, lineIndex, abilityIndex, lineId)
                    if ability then
                        table.insert(lineEntry.abilities, ability)
                        addLookup(byId, byName, lookup)
                    end
                end

                table.insert(result.lines, lineEntry)
            end
        end
    end

    local primaryCategory = HOTBAR_CATEGORY_PRIMARY or 0
    local backupCategory = HOTBAR_CATEGORY_BACKUP or 1
    table.insert(result.actionBars, collectActionBar(primaryCategory, "Primary", byId, byName))
    table.insert(result.actionBars, collectActionBar(backupCategory, "Backup", byId, byName))

    local weaponPairSucceeded, activePair, locked = Util.SafeCall("GetActiveWeaponPairInfo")
    if weaponPairSucceeded then
        result.activeWeaponPair = {
            pair = activePair,
            locked = locked == true,
        }
    end

    return result
end
