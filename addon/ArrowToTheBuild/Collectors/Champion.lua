local ATTB = ArrowToTheBuild
local Util = ATTB.Util
local Collector = {}
ATTB.Collectors.Champion = Collector

local function collectChampionBar()
    local result = {
        supported = HOTBAR_CATEGORY_CHAMPION ~= nil and type(GetSlotBoundId) == "function",
        slots = {},
    }
    if not result.supported then
        return result
    end

    local startSlot = 1
    local endSlot = CHAMPION_BAR_NUM_SLOTS or 4
    local rangeSucceeded, assignableStart, assignableEnd = Util.SafeCall("GetAssignableChampionBarStartAndEndSlots")
    if rangeSucceeded and assignableStart and assignableEnd and assignableEnd >= assignableStart then
        startSlot = assignableStart
        endSlot = assignableEnd
    end

    for slotIndex = startSlot, endSlot do
        local skillId = Util.Value("GetSlotBoundId", 0, slotIndex, HOTBAR_CATEGORY_CHAMPION)
        local disciplineId = Util.Value("GetRequiredChampionDisciplineIdForSlot", nil, slotIndex, HOTBAR_CATEGORY_CHAMPION)
        local disciplineName = disciplineId and Util.Value("GetChampionDisciplineName", nil, disciplineId) or nil
        table.insert(result.slots, {
            position = slotIndex - startSlot + 1,
            disciplineId = disciplineId,
            disciplineName = Util.CleanName(disciplineName),
            skillId = skillId or 0,
            name = skillId and skillId > 0 and Util.CleanName(Util.Value("GetChampionSkillName", "Unknown", skillId)) or "Empty",
        })
    end
    return result
end

function Collector.Collect()
    local result = {
        totalEarned = Util.Value("GetPlayerChampionPointsEarned", 0),
        disciplines = {},
        slotted = collectChampionBar(),
    }

    local disciplineCount = Util.Value("GetNumChampionDisciplines", 0)
    for disciplineIndex = 1, disciplineCount do
        local disciplineId = Util.Value("GetChampionDisciplineId", nil, disciplineIndex)
        local disciplineName = disciplineId and Util.Value("GetChampionDisciplineName", nil, disciplineId) or nil
        local discipline = {
            disciplineId = disciplineId,
            name = Util.CleanName(disciplineName or ("Discipline " .. tostring(disciplineIndex))),
            spent = disciplineId and Util.Value("GetNumSpentChampionPoints", 0, disciplineId) or 0,
            unspent = disciplineId and Util.Value("GetNumUnspentChampionPoints", 0, disciplineId) or 0,
            stars = {},
        }

        local skillCount = Util.Value("GetNumChampionDisciplineSkills", 0, disciplineIndex)
        for skillIndex = 1, skillCount do
            local skillId = Util.Value("GetChampionSkillId", nil, disciplineIndex, skillIndex)
            if skillId then
                local points = Util.Value("GetNumPointsSpentOnChampionSkill", 0, skillId)
                if points and points > 0 then
                    local skillType = Util.Value("GetChampionSkillType", nil, skillId)
                    local normalType = CHAMPION_SKILL_TYPE_NORMAL or 0
                    local slottable = Util.Value("IsChampionSkillSlottable", nil, skillId)
                    if slottable == nil then
                        slottable = skillType ~= nil and skillType ~= normalType
                    end
                    local maximumPoints = Util.Value("GetChampionSkillMaxPoints", nil, skillId)
                    if maximumPoints == nil then
                        maximumPoints = Util.Value("GetMaxPossiblePointsInChampionSkill", nil, skillId)
                    end
                    table.insert(discipline.stars, {
                        skillId = skillId,
                        name = Util.CleanName(Util.Value("GetChampionSkillName", "Unknown", skillId)),
                        points = points,
                        maximumPoints = maximumPoints,
                        skillType = skillType,
                        slottable = slottable == true,
                    })
                end
            end
        end
        table.insert(result.disciplines, discipline)
    end
    return result
end
