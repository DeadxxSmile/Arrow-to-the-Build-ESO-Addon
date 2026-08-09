local ATTB = ArrowToTheBuild
local Util = ATTB.Util
local Collector = {}
ATTB.Collectors.Champion = Collector

local function collectChampionBar()
    local startSlot, endSlot = GetAssignableChampionBarStartAndEndSlots()
    local result = { supported = true, slots = {} }

    for slotIndex = startSlot, endSlot do
        local skillId = GetSlotBoundId(slotIndex, HOTBAR_CATEGORY_CHAMPION)
        local disciplineId = GetRequiredChampionDisciplineIdForSlot(slotIndex, HOTBAR_CATEGORY_CHAMPION)
        table.insert(result.slots, {
            position = slotIndex - startSlot + 1,
            disciplineId = disciplineId,
            disciplineName = Util.CleanName(GetChampionDisciplineName(disciplineId)),
            skillId = skillId,
            name = skillId > 0 and Util.CleanName(GetChampionSkillName(skillId)) or "Empty",
        })
    end
    return result
end

function Collector.Collect()
    local result = {
        totalEarned = GetPlayerChampionPointsEarned(),
        disciplines = {},
        slotted = collectChampionBar(),
    }

    for disciplineIndex = 1, GetNumChampionDisciplines() do
        local disciplineId = GetChampionDisciplineId(disciplineIndex)
        local discipline = {
            disciplineId = disciplineId,
            name = Util.CleanName(GetChampionDisciplineName(disciplineId)),
            spent = GetNumSpentChampionPoints(disciplineId),
            unspent = GetNumUnspentChampionPoints(disciplineId),
            stars = {},
        }

        for skillIndex = 1, GetNumChampionDisciplineSkills(disciplineIndex) do
            local skillId = GetChampionSkillId(disciplineIndex, skillIndex)
            local points = GetNumPointsSpentOnChampionSkill(skillId)
            if points > 0 then
                local skillType = GetChampionSkillType(skillId)
                table.insert(discipline.stars, {
                    skillId = skillId,
                    name = Util.CleanName(GetChampionSkillName(skillId)),
                    points = points,
                    maximumPoints = GetChampionSkillMaxPoints(skillId),
                    skillType = skillType,
                    slottable = CanChampionSkillTypeBeSlotted(skillType),
                })
            end
        end
        table.insert(result.disciplines, discipline)
    end
    return result
end
