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

local function collectAbility(skillType, lineIndex, abilityIndex, lineId, lineName)
    local succeeded, abilityName, icon, earnedRank, passive, ultimate, purchased, progressionIndex, rankIndex =
        Util.SafeCall("GetSkillAbilityInfo", skillType, lineIndex, abilityIndex)

    if not succeeded or not abilityName then
        return nil
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
    if passive and purchased then
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

    return {
        abilityId = ids.abilityId,
        baseAbilityId = ids.baseAbilityId,
        morphAbilityId = ids.morphAbilityId,
        rankedAbilityId = ids.rankedAbilityId,
        progressionId = ids.progressionId,
        progressionIndex = progressionIndex,
        name = Util.CleanName(abilityName),
        icon = icon,
        skillType = skillType,
        skillLineId = lineId,
        skillLineName = lineName,
        abilityIndex = abilityIndex,
        earnedRank = earnedRank or 0,
        currentRank = currentRank or 0,
        currentMorph = currentMorph or 0,
        passiveRank = passiveRank,
        passiveMaxRank = passiveMaxRank,
        isPassive = passive == true,
        isUltimate = ultimate == true,
        purchased = purchased == true,
    }
end

local function collectActionBar(hotbarCategory, label)
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

        table.insert(slots, {
            position = slotIndex - firstSlot + 1,
            actionSlotIndex = slotIndex,
            abilityId = abilityId or 0,
            name = Util.CleanName(name or "Empty"),
            slotType = slotType,
            isUltimate = slotIndex == ultimateSlot,
        })
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

    local maxSkillType = Util.Value("GetNumSkillTypes", 9)
    if not maxSkillType or maxSkillType < 9 then
        maxSkillType = 9
    end

    for skillType = 1, maxSkillType do
        local lineCount = Util.Value("GetNumSkillLines", 0, skillType)
        for lineIndex = 1, lineCount do
            local dynamicSucceeded, rank, advised, active, discovered =
                Util.SafeCall("GetSkillLineDynamicInfo", skillType, lineIndex)
            local lineId = Util.Value("GetSkillLineId", nil, skillType, lineIndex)
            local lineName = nil
            if lineId then
                lineName = Util.Value("GetSkillLineNameById", nil, lineId)
            end

            if dynamicSucceeded and discovered and lineName and lineName ~= "" then
                local xpSucceeded, lastRankXp, nextRankXp, currentXp =
                    Util.SafeCall("GetSkillLineXPInfo", skillType, lineIndex)
                local lineEntry = {
                    skillType = skillType,
                    skillTypeName = getSkillTypeName(skillType),
                    skillLineId = lineId,
                    lineIndex = lineIndex,
                    name = Util.CleanName(lineName),
                    rank = rank or 0,
                    advised = advised == true,
                    active = active == true,
                    discovered = true,
                    xp = xpSucceeded and {
                        previousRank = lastRankXp or 0,
                        nextRank = nextRankXp or 0,
                        current = currentXp or 0,
                    } or nil,
                    abilities = {},
                }

                local abilityCount = Util.Value("GetNumSkillAbilities", 0, skillType, lineIndex)
                for abilityIndex = 1, abilityCount do
                    local ability = collectAbility(skillType, lineIndex, abilityIndex, lineId, lineEntry.name)
                    if ability and ability.purchased then
                        table.insert(lineEntry.abilities, ability)
                    end
                end

                table.insert(result.lines, lineEntry)
            end
        end
    end

    local primaryCategory = HOTBAR_CATEGORY_PRIMARY or 0
    local backupCategory = HOTBAR_CATEGORY_BACKUP or 1
    table.insert(result.actionBars, collectActionBar(primaryCategory, "Primary"))
    table.insert(result.actionBars, collectActionBar(backupCategory, "Backup"))

    local weaponPairSucceeded, activePair, locked = Util.SafeCall("GetActiveWeaponPairInfo")
    if weaponPairSucceeded then
        result.activeWeaponPair = {
            pair = activePair,
            locked = locked == true,
        }
    end

    return result
end
