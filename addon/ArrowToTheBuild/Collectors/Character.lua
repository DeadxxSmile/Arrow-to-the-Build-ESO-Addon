local ATTB = ArrowToTheBuild
local Util = ATTB.Util
local Collector = {}
ATTB.Collectors.Character = Collector

local function getClassInfo()
    local classId = Util.Value("GetUnitClassId", 0, "player")
    local className = Util.Value("GetUnitClass", nil, "player")
    if not className or className == "" then
        className = Util.Value(
            "GetClassName",
            "Unknown",
            Util.Value("GetUnitGender", 1, "player"),
            classId
        )
    end
    return {
        id = classId or 0,
        name = Util.CleanName(className or "Unknown"),
    }
end

local function getRaceInfo()
    local raceId = Util.Value("GetUnitRaceId", 0, "player")
    local raceName = Util.Value("GetUnitRace", nil, "player")
    if not raceName or raceName == "" then
        raceName = Util.Value(
            "GetRaceName",
            "Unknown",
            Util.Value("GetUnitGender", 1, "player"),
            raceId
        )
    end
    return {
        id = raceId or 0,
        name = Util.CleanName(raceName or "Unknown"),
    }
end

local function getAllianceInfo()
    local allianceId = Util.Value("GetUnitAlliance", 0, "player")
    local allianceName = Util.Value("GetAllianceName", nil, allianceId)
    return {
        id = allianceId or 0,
        name = Util.CleanName(allianceName or "Unknown"),
    }
end

local function getGenderInfo()
    local genderId = Util.Value("GetUnitGender", 0, "player")
    local fallbackNames = {
        [GENDER_FEMALE or 1] = "Female",
        [GENDER_MALE or 2] = "Male",
    }
    local genderName = Util.GetStringForEnum("SI_GENDER", genderId, fallbackNames[genderId])
    return {
        id = genderId or 0,
        name = Util.CleanName(genderName or "Unknown"),
    }
end

local function getPower(powerType)
    if powerType == nil then
        return { current = nil, maximum = nil, effectiveMaximum = nil }
    end

    local succeeded, current, maximum, effectiveMaximum = Util.SafeCall("GetUnitPower", "player", powerType)
    if not succeeded then
        return { current = nil, maximum = nil, effectiveMaximum = nil }
    end

    return {
        current = current,
        maximum = maximum,
        effectiveMaximum = effectiveMaximum,
    }
end

local function getSpentAttributePoints(attributeType)
    if attributeType == nil then
        return nil
    end
    local succeeded, points = Util.SafeCall("GetAttributeSpentPoints", attributeType)
    if succeeded then
        return points
    end
    return nil
end

local function getAvailableAttributePoints()
    local candidates = {
        "GetAvailableAttributePoints",
        "GetAttributeUnspentPoints",
        "GetNumAvailableAttributePoints",
    }

    for _, functionName in ipairs(candidates) do
        local succeeded, points = Util.SafeCall(functionName)
        if succeeded and points ~= nil then
            return points
        end
    end
    return nil
end

function Collector.Collect()
    local accountName = Util.GetAccountName()
    local worldName = Util.GetWorldName()
    local characterId = Util.GetCharacterId()
    local rawName = Util.Value("GetRawUnitName", nil, "player")
    local displayName = Util.Value("GetUnitName", rawName or "Unknown Character", "player")
    local level = Util.Value("GetUnitLevel", 0, "player")
    local championPoints = Util.Value("GetUnitChampionPoints", 0, "player")
    local championPointsEarned = Util.Value("GetPlayerChampionPointsEarned", championPoints)

    return {
        accountName = accountName,
        worldName = worldName,
        characterId = characterId,
        characterKey = Util.GetCharacterKey(accountName, worldName, characterId),
        name = Util.CleanName(displayName or "Unknown Character"),
        rawName = rawName,
        class = getClassInfo(),
        race = getRaceInfo(),
        alliance = getAllianceInfo(),
        gender = getGenderInfo(),
        level = level,
        championPoints = championPoints,
        championPointsEarned = championPointsEarned,
        zone = {
            name = Util.CleanName(Util.Value("GetUnitZone", "Unknown", "player")),
            index = Util.Value("GetUnitZoneIndex", nil, "player"),
        },
        progression = {
            availableSkillPoints = Util.Value("GetAvailableSkillPoints", nil),
            availableAttributePoints = getAvailableAttributePoints(),
        },
        attributes = {
            magicka = {
                attributeId = ATTRIBUTE_MAGICKA,
                spentPoints = getSpentAttributePoints(ATTRIBUTE_MAGICKA),
                power = getPower(POWERTYPE_MAGICKA),
            },
            health = {
                attributeId = ATTRIBUTE_HEALTH,
                spentPoints = getSpentAttributePoints(ATTRIBUTE_HEALTH),
                power = getPower(POWERTYPE_HEALTH),
            },
            stamina = {
                attributeId = ATTRIBUTE_STAMINA,
                spentPoints = getSpentAttributePoints(ATTRIBUTE_STAMINA),
                power = getPower(POWERTYPE_STAMINA),
            },
        },
    }
end
