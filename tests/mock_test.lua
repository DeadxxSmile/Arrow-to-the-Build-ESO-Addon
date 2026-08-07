-- Minimal ESO API mock for the ATTB exporter.
local addonRoot = arg[1]

EVENT_ADD_ON_LOADED = 1
EVENT_PLAYER_ACTIVATED = 2
EVENT_PLAYER_DEACTIVATED = 3
EVENT_LEVEL_UPDATE = 4
EVENT_SKILL_POINTS_CHANGED = 5
EVENT_ACTION_SLOT_UPDATED = 6
EVENT_INVENTORY_SINGLE_SLOT_UPDATE = 7
EVENT_CHAMPION_POINT_UPDATE = 8
EVENT_ATTRIBUTE_UPGRADE_UPDATED = 9

ATTRIBUTE_MAGICKA = 1
ATTRIBUTE_HEALTH = 2
ATTRIBUTE_STAMINA = 3
POWERTYPE_MAGICKA = 1
POWERTYPE_HEALTH = 2
POWERTYPE_STAMINA = 3

HOTBAR_CATEGORY_PRIMARY = 1
HOTBAR_CATEGORY_BACKUP = 2
HOTBAR_CATEGORY_CHAMPION = 3
ACTION_BAR_FIRST_NORMAL_SLOT_INDEX = 2
ACTION_BAR_ULTIMATE_SLOT_INDEX = 7
ACTION_TYPE_CRAFTED_ABILITY = 99
CHAMPION_BAR_NUM_SLOTS = 4
CHAMPION_SKILL_TYPE_NORMAL = 0
GENDER_FEMALE = 1
GENDER_MALE = 2

BAG_WORN = 1
LINK_STYLE_DEFAULT = 0
EQUIP_SLOT_HEAD = 1
EQUIP_SLOT_SHOULDERS = 2
EQUIP_SLOT_CHEST = 3
EQUIP_SLOT_HAND = 4
EQUIP_SLOT_WAIST = 5
EQUIP_SLOT_LEGS = 6
EQUIP_SLOT_FEET = 7
EQUIP_SLOT_NECK = 8
EQUIP_SLOT_RING1 = 9
EQUIP_SLOT_RING2 = 10
EQUIP_SLOT_MAIN_HAND = 11
EQUIP_SLOT_OFF_HAND = 12
EQUIP_SLOT_POISON = 13
EQUIP_SLOT_BACKUP_MAIN = 14
EQUIP_SLOT_BACKUP_OFF = 15
EQUIP_SLOT_BACKUP_POISON = 16
EQUIP_SLOT_COSTUME = 17

SLASH_COMMANDS = {}

EVENT_MANAGER = {
  events = {},
  updates = {},
  RegisterForEvent = function(self, name, code, callback) self.events[name] = {code=code, callback=callback} end,
  UnregisterForEvent = function(self, name, code) self.events[name] = nil end,
  RegisterForUpdate = function(self, name, delay, callback) self.updates[name] = callback; callback() end,
  UnregisterForUpdate = function(self, name) self.updates[name] = nil end,
}

function d(message) print(message) end
function zo_strformat(_, value) return value end
function GetString(prefix, value)
  if prefix == "SI_GENDER" then
    return value == GENDER_FEMALE and "Female" or "Male"
  end
  return tostring(prefix) .. " " .. tostring(value)
end
local mockNow = 1786069200
function GetTimeStamp() return mockNow end
function GetAPIVersion() return 101050 end
function GetDisplayName() return "@Tester" end
function GetWorldName() return "NA Megaserver" end
function GetCurrentCharacterId() return 123456789 end
function Id64ToString(value) return tostring(value) end
function GetRawUnitName() return "Test^Mx" end
function GetUnitName() return "Test Character" end
function GetUnitClass() return "Arcanist" end
function GetUnitClassId() return 117 end
function GetClassName() return "Arcanist" end
function GetUnitRace() return "Dark Elf" end
function GetUnitRaceId() return 3 end
function GetRaceName() return "Dark Elf" end
function GetUnitAlliance() return 3 end
function GetAllianceName() return "Ebonheart Pact" end
function GetUnitGender() return 1 end
function GetUnitLevel() return 25 end
function GetUnitChampionPoints() return 200 end
function GetPlayerChampionPointsEarned() return 200 end
function GetUnitZone() return "Vivec City" end
function GetUnitZoneIndex() return 42 end
function GetAvailableSkillPoints() return 4 end
function GetAvailableAttributePoints() return 2 end
function GetAttributeSpentPoints(attribute) return attribute * 10 end
function GetUnitPower(_, powerType) return 1000 * powerType, 2000 * powerType, 2100 * powerType end

function GetNumSkillTypes() return 9 end
function GetNumSkillLines(skillType) if skillType == 1 then return 1 else return 0 end end
function GetSkillLineDynamicInfo() return 12, false, true, true end
function GetSkillLineId() return 5001 end
function GetSkillLineNameById() return "Herald of the Tome" end
function GetSkillLineXPInfo() return 100, 200, 150 end
function GetNumSkillAbilities() return 2 end
function GetSkillAbilityInfo(_, _, abilityIndex)
  if abilityIndex == 1 then return "Fatecarver", "icon.dds", 4, false, false, true, 7001, 4 end
  return "Harnessed Quintessence", "passive.dds", 1, true, false, true, nil, 1
end
function GetAbilityProgressionInfo() return "Fatecarver", 1, 4 end
function GetAbilityProgressionAbilityId(_, morph, rank) return 8000 + morph * 10 + rank end
function GetSkillAbilityId(_, _, abilityIndex) return 6000 + abilityIndex end
function GetProgressionSkillProgressionId(_, _, abilityIndex)
  if abilityIndex == 1 then return 77001 end
  return nil
end
function GetProgressionSkillMorphSlotAbilityId(progressionId, morphSlot)
  assert(progressionId == 77001)
  return 88000 + morphSlot
end
function GetSkillAbilityUpgradeInfo() return 2, 2 end
function GetSlotBoundId(slot, category)
  if category == HOTBAR_CATEGORY_CHAMPION then
    if slot == 1 then return 9001 end
    if slot == 5 then return 9002 end
    if slot == 9 then return 9003 end
    return 0
  end
  if slot == 3 then return category == HOTBAR_CATEGORY_PRIMARY and 8014 or 6002 end
  if slot == 8 then return 8999 end
  return 0
end
function GetSlotType() return 1 end
function GetAbilityName(id) return "Ability " .. tostring(id) end
function GetActiveWeaponPairInfo() return 1, false end

function GetItemLink(_, slot)
  if slot == EQUIP_SLOT_HEAD then return "|H1:item:12345|h[Test Helm]|h" end
  return ""
end
function GetItemInfo() return "helm.dds", 1, 100, true, false, 1, 0, 4 end
function GetItemName() return "Test Helm" end
function GetItemLinkItemId() return 12345 end
function GetItemTrait() return 1 end
function GetItemLinkSetInfo() return true, "Test Set", 5, 1, 5, 555, 0 end
function GetItemLinkEnchantInfo() return true, "Maximum Magicka", "Adds Magicka" end
function GetItemLinkArmorType() return 1 end
function GetItemLinkWeaponType() return 0 end
function GetItemLinkItemType() return 2 end
function GetItemLinkEquipType() return 1 end
function GetItemLinkQuality() return 4 end
function GetItemLinkRequiredLevel() return 50 end
function GetItemLinkRequiredChampionPoints() return 160 end

function GetNumChampionDisciplines() return 3 end
function GetChampionDisciplineId(index) return index end
function GetChampionDisciplineName(id) return "Discipline " .. tostring(id) end
function GetNumSpentChampionPoints(id) return id == 1 and 50 or 0 end
function GetNumUnspentChampionPoints() return 0 end
function GetNumChampionDisciplineSkills(index) return index == 1 and 1 or 0 end
function GetChampionSkillId() return 9001 end
function GetNumPointsSpentOnChampionSkill() return 50 end
function GetChampionSkillName(id)
  local names = { [9001] = "Steed's Blessing", [9002] = "Master-at-Arms", [9003] = "Bloody Renewal" }
  return names[id] or "Unknown Champion Skill"
end
function GetChampionSkillMaxPoints() return 50 end
function GetChampionSkillType() return 1 end
function GetAssignableChampionBarStartAndEndSlots() return 1, 12 end
function GetRequiredChampionDisciplineIdForSlot(slot)
  if slot <= 4 then return 3 end
  if slot <= 8 then return 1 end
  return 2
end

local prioritySaveRequests = 0
local addOnManager = {
  RequestAddOnSavedVariablesPrioritySave = function(self, addonName)
    assert(addonName == "ArrowToTheBuild")
    prioritySaveRequests = prioritySaveRequests + 1
    return true
  end,
}
function GetAddOnManager() return addOnManager end
function RequestAddOnSavedVariablesPrioritySave(addonName) assert(addonName == "ArrowToTheBuild"); return true end

local ordered = {
  "Namespace.lua",
  "Util.lua",
  "Collectors/Character.lua",
  "Collectors/Skills.lua",
  "Collectors/Equipment.lua",
  "Collectors/Champion.lua",
  "Core.lua",
}
for _, relative in ipairs(ordered) do
  assert(loadfile(addonRoot .. "/" .. relative))()
end

ArrowToTheBuild.OnAddonLoaded(EVENT_ADD_ON_LOADED, "ArrowToTheBuild")
assert(ArrowToTheBuild.runtime.loadedCharacterCount == 0)
ArrowToTheBuild.OnPlayerActivated()
local requestsAfterAutomaticCapture = prioritySaveRequests
assert(requestsAfterAutomaticCapture == 1)

-- A forced manual capture must bypass the addon's 15-minute automatic-save throttle.
local ok, snapshot, priorityRequested, priorityStatus = ArrowToTheBuild.CaptureSnapshot("mock-test", true)
assert(ok, snapshot)
assert(priorityRequested == true)
assert(priorityStatus == "requested")
assert(prioritySaveRequests == requestsAfterAutomaticCapture + 1)
assert(ArrowToTheBuildSavedVariables.lastPrioritySaveWasForced == true)
assert(ArrowToTheBuildSavedVariables.lastPrioritySaveCharacterKey == snapshot.identity.characterKey)
assert(ArrowToTheBuildSavedVariables.schemaVersion == 1)
assert(ArrowToTheBuildSavedVariables.revision >= 1)
assert(snapshot.identity.name == "Test Character")
assert(snapshot.identity.characterId == "123456789")
assert(snapshot.identity.class.id == 117)
assert(snapshot.identity.race.id == 3)
assert(snapshot.identity.gender.name == "Female")
assert(#snapshot.skills.lines == 1)
assert(#snapshot.skills.lines[1].abilities == 2)
assert(snapshot.skills.lines[1].abilities[1].baseAbilityId == 6001)
assert(snapshot.skills.lines[1].abilities[1].progressionId == 77001)
assert(snapshot.skills.lines[1].abilities[1].morphAbilityId == 88001)
assert(snapshot.skills.lines[1].abilities[1].abilityId == 88001)
assert(snapshot.skills.lines[1].abilities[1].rankedAbilityId == 8014)
assert(#snapshot.skills.actionBars == 2)
assert(#snapshot.equipment.items == 1)
assert(snapshot.equipment.items[1].weaponTypeName == "None")
assert(#snapshot.champion.disciplines[1].stars == 1)
assert(#snapshot.champion.slotted.slots == 12)
assert(snapshot.champion.slotted.slots[1].skillId == 9001)
assert(snapshot.champion.slotted.slots[1].disciplineId == 3)
assert(snapshot.champion.slotted.slots[5].skillId == 9002)
assert(snapshot.champion.slotted.slots[5].disciplineId == 1)
assert(snapshot.champion.slotted.slots[9].skillId == 9003)
assert(snapshot.champion.slotted.slots[9].disciplineId == 2)
assert(SLASH_COMMANDS["/attbexport"])
assert(SLASH_COMMANDS["/attbstatus"])

-- Simulate ESO reloading the UI for a second character while retaining the serialized
-- SavedVariables global. The first record must load before the second is appended.
local preservedSavedVariables = ArrowToTheBuildSavedVariables
ArrowToTheBuild = nil
SLASH_COMMANDS = {}
EVENT_MANAGER.events = {}
EVENT_MANAGER.updates = {}
mockNow = mockNow + 60
function GetCurrentCharacterId() return 987654321 end
function GetRawUnitName() return "Second^Fx" end
function GetUnitName() return "Second Character" end

for _, relative in ipairs(ordered) do
  assert(loadfile(addonRoot .. "/" .. relative))()
end

assert(ArrowToTheBuildSavedVariables == preservedSavedVariables)
ArrowToTheBuild.OnAddonLoaded(EVENT_ADD_ON_LOADED, "ArrowToTheBuild")
assert(ArrowToTheBuild.runtime.loadedCharacterCount == 1)
ArrowToTheBuild.OnPlayerActivated()
assert(ArrowToTheBuild.Util.TableCount(ArrowToTheBuildSavedVariables.characters) == 2)
local secondKey = ArrowToTheBuild.Util.GetCharacterKey("@Tester", "NA Megaserver", "987654321")
local secondSnapshot = ArrowToTheBuildSavedVariables.characters[secondKey]
assert(secondSnapshot)
assert(secondSnapshot.identity.name == "Second Character")

-- Renaming the first character updates its stable-ID record rather than adding a third.
mockNow = mockNow + 60
function GetCurrentCharacterId() return 123456789 end
function GetRawUnitName() return "Renamed^Mx" end
function GetUnitName() return "Renamed Character" end
local renameOk, renamedSnapshot = ArrowToTheBuild.CaptureSnapshot("mock-rename", true)
assert(renameOk, renamedSnapshot)
assert(ArrowToTheBuild.Util.TableCount(ArrowToTheBuildSavedVariables.characters) == 2)
assert(renamedSnapshot.identity.name == "Renamed Character")

print("MOCK TEST PASS")
print("characterKey=" .. snapshot.identity.characterKey)
print("revision=" .. tostring(ArrowToTheBuildSavedVariables.revision))
print("prioritySaveRequests=" .. tostring(prioritySaveRequests))
print("loadedCharacterCount=" .. tostring(ArrowToTheBuild.runtime.loadedCharacterCount))
print("storedCharacterCount=" .. tostring(ArrowToTheBuild.Util.TableCount(ArrowToTheBuildSavedVariables.characters)))
print("warnings=" .. tostring(#snapshot.diagnostics.warnings))
print("errors=" .. tostring(#snapshot.diagnostics.errors))
