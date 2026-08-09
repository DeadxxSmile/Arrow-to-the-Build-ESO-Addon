local ATTB = ArrowToTheBuild
local Util = ATTB.Util
local Collector = {}
ATTB.Collectors.Character = Collector

local function getClassInfo(gender)
    local classId = GetUnitClassId("player")
    local className = GetUnitClass("player")
    if className == "" then
        className = GetClassName(gender, classId)
    end
    return { id = classId, name = Util.CleanName(className) }
end

local function getRaceInfo(gender)
    local raceId = GetUnitRaceId("player")
    local raceName = GetUnitRace("player")
    if raceName == "" then
        raceName = GetRaceName(gender, raceId)
    end
    return { id = raceId, name = Util.CleanName(raceName) }
end

local function getAllianceInfo()
    local allianceId = GetUnitAlliance("player")
    return { id = allianceId, name = Util.CleanName(GetAllianceName(allianceId)) }
end

local function getPower(powerType)
    local current, maximum, effectiveMaximum = GetUnitPower("player", powerType)
    return {
        current = current,
        maximum = maximum,
        effectiveMaximum = effectiveMaximum,
    }
end

function Collector.Collect()
    local accountName = GetDisplayName()
    local worldName = GetWorldName()
    local characterId = GetCurrentCharacterId()
    local rawName = GetRawUnitName("player")
    local gender = GetUnitGender("player")

    return {
        accountName = accountName,
        worldName = worldName,
        characterId = characterId,
        characterKey = Util.GetCharacterKey(accountName, worldName, characterId),
        name = Util.CleanName(GetUnitName("player")),
        rawName = rawName,
        class = getClassInfo(gender),
        race = getRaceInfo(gender),
        alliance = getAllianceInfo(),
        gender = {
            id = gender,
            name = Util.EnumName("SI_GENDER", gender, "Unknown"),
        },
        level = GetUnitLevel("player"),
        championPoints = GetUnitChampionPoints("player"),
        championPointsEarned = GetPlayerChampionPointsEarned(),
        zone = {
            name = Util.CleanName(GetUnitZone("player")),
            index = GetUnitZoneIndex("player"),
        },
        progression = {
            availableSkillPoints = GetAvailableSkillPoints(),
            availableAttributePoints = GetAttributeUnspentPoints(),
        },
        attributes = {
            magicka = {
                attributeId = ATTRIBUTE_MAGICKA,
                spentPoints = GetAttributeSpentPoints(ATTRIBUTE_MAGICKA),
                power = getPower(POWERTYPE_MAGICKA),
            },
            health = {
                attributeId = ATTRIBUTE_HEALTH,
                spentPoints = GetAttributeSpentPoints(ATTRIBUTE_HEALTH),
                power = getPower(POWERTYPE_HEALTH),
            },
            stamina = {
                attributeId = ATTRIBUTE_STAMINA,
                spentPoints = GetAttributeSpentPoints(ATTRIBUTE_STAMINA),
                power = getPower(POWERTYPE_STAMINA),
            },
        },
    }
end
