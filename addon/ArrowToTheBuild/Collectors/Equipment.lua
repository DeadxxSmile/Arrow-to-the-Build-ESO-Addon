local ATTB = ArrowToTheBuild
local Util = ATTB.Util
local Collector = {}
ATTB.Collectors.Equipment = Collector

local EQUIPMENT_SLOTS = {
    { EQUIP_SLOT_HEAD, "Head" },
    { EQUIP_SLOT_SHOULDERS, "Shoulders" },
    { EQUIP_SLOT_CHEST, "Chest" },
    { EQUIP_SLOT_HAND, "Hands" },
    { EQUIP_SLOT_WAIST, "Waist" },
    { EQUIP_SLOT_LEGS, "Legs" },
    { EQUIP_SLOT_FEET, "Feet" },
    { EQUIP_SLOT_NECK, "Neck" },
    { EQUIP_SLOT_RING1, "Ring 1" },
    { EQUIP_SLOT_RING2, "Ring 2" },
    { EQUIP_SLOT_MAIN_HAND, "Front Main Hand" },
    { EQUIP_SLOT_OFF_HAND, "Front Off Hand" },
    { EQUIP_SLOT_POISON, "Front Poison" },
    { EQUIP_SLOT_BACKUP_MAIN, "Back Main Hand" },
    { EQUIP_SLOT_BACKUP_OFF, "Back Off Hand" },
    { EQUIP_SLOT_BACKUP_POISON, "Back Poison" },
}

local function collectItem(slotId, slotLabel)
    local itemLink = GetItemLink(BAG_WORN, slotId, LINK_STYLE_DEFAULT)
    if itemLink == "" then
        return nil
    end

    local equipType = GetItemEquipType(BAG_WORN, slotId)
    local itemType = GetItemType(BAG_WORN, slotId)
    local armorType = GetItemArmorType(BAG_WORN, slotId)
    local weaponType = GetItemWeaponType(BAG_WORN, slotId)
    local traitType = GetItemTrait(BAG_WORN, slotId)
    local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(itemLink, true)
    local _, enchantHeader, enchantDescription = GetItemLinkEnchantInfo(itemLink)

    return {
        equipSlot = slotId,
        slotName = slotLabel,
        itemId = GetItemId(BAG_WORN, slotId),
        name = Util.CleanName(GetItemName(BAG_WORN, slotId)),
        quality = GetItemFunctionalQuality(BAG_WORN, slotId),
        requiredLevel = GetItemRequiredLevel(BAG_WORN, slotId),
        requiredChampionPoints = GetItemRequiredChampionPoints(BAG_WORN, slotId),
        equipType = equipType,
        equipTypeName = Util.EnumName("SI_EQUIPTYPE", equipType, "Unknown"),
        itemType = itemType,
        itemTypeName = Util.EnumName("SI_ITEMTYPE", itemType, "Unknown"),
        armorType = armorType,
        armorTypeName = armorType and armorType > 0 and Util.EnumName("SI_ARMORTYPE", armorType, "Unknown") or "",
        weaponType = weaponType,
        weaponTypeName = weaponType and weaponType > 0 and Util.EnumName("SI_WEAPONTYPE", weaponType, "Unknown") or "None",
        trait = {
            id = traitType,
            name = traitType and traitType > 0 and Util.EnumName("SI_ITEMTRAITTYPE", traitType, "Unknown") or "",
        },
        set = {
            hasSet = hasSet == true,
            id = setId,
            name = Util.CleanName(setName),
        },
        enchantment = enchantHeader and enchantHeader ~= "" and {
            name = Util.CleanName(enchantHeader or enchantDescription),
        } or nil,
    }
end

function Collector.Collect()
    local result = { items = {} }
    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        local item = collectItem(slot[1], slot[2])
        if item then
            table.insert(result.items, item)
        end
    end
    return result
end
