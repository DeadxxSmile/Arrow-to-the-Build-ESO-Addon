local ATTB = ArrowToTheBuild
local Util = ATTB.Util
local Collector = {}
ATTB.Collectors.Equipment = Collector

local EQUIPMENT_SLOTS = {
    { constantName = "EQUIP_SLOT_HEAD", label = "Head" },
    { constantName = "EQUIP_SLOT_SHOULDERS", label = "Shoulders" },
    { constantName = "EQUIP_SLOT_CHEST", label = "Chest" },
    { constantName = "EQUIP_SLOT_HAND", label = "Hands" },
    { constantName = "EQUIP_SLOT_WAIST", label = "Waist" },
    { constantName = "EQUIP_SLOT_LEGS", label = "Legs" },
    { constantName = "EQUIP_SLOT_FEET", label = "Feet" },
    { constantName = "EQUIP_SLOT_NECK", label = "Neck" },
    { constantName = "EQUIP_SLOT_RING1", label = "Ring 1" },
    { constantName = "EQUIP_SLOT_RING2", label = "Ring 2" },
    { constantName = "EQUIP_SLOT_MAIN_HAND", label = "Front Main Hand" },
    { constantName = "EQUIP_SLOT_OFF_HAND", label = "Front Off Hand" },
    { constantName = "EQUIP_SLOT_POISON", label = "Front Poison" },
    { constantName = "EQUIP_SLOT_BACKUP_MAIN", label = "Back Main Hand" },
    { constantName = "EQUIP_SLOT_BACKUP_OFF", label = "Back Off Hand" },
    { constantName = "EQUIP_SLOT_BACKUP_POISON", label = "Back Poison" },
    { constantName = "EQUIP_SLOT_COSTUME", label = "Costume" },
}

local function enumName(prefix, value)
    if value == nil then
        return nil
    end
    return Util.GetStringForEnum(prefix, value, tostring(value))
end

local function collectItem(slotId, slotLabel)
    local bagId = BAG_WORN
    if bagId == nil or slotId == nil then
        return nil
    end

    local itemLink = Util.Value("GetItemLink", "", bagId, slotId, LINK_STYLE_DEFAULT or 0)
    if not itemLink or itemLink == "" then
        return nil
    end

    local infoSucceeded, icon, stack, sellPrice, meetsUsageRequirement, locked, equipType, itemStyleId, quality =
        Util.SafeCall("GetItemInfo", bagId, slotId)
    local itemName = Util.Value("GetItemName", nil, bagId, slotId)
    local itemId = Util.Value("GetItemLinkItemId", nil, itemLink)
    local traitType = Util.Value("GetItemTrait", nil, bagId, slotId)

    local setSucceeded, hasSet, setName, numBonuses, numNormalEquipped, maxEquipped, setId, numPerfectedEquipped =
        Util.SafeCall("GetItemLinkSetInfo", itemLink, true)

    local enchantSucceeded, hasCharges, enchantHeader, enchantDescription =
        Util.SafeCall("GetItemLinkEnchantInfo", itemLink)

    local armorType = Util.Value("GetItemLinkArmorType", nil, itemLink)
    local weaponType = Util.Value("GetItemLinkWeaponType", nil, itemLink)
    local itemType = Util.Value("GetItemLinkItemType", nil, itemLink)
    local linkEquipType = Util.Value("GetItemLinkEquipType", equipType, itemLink)

    return {
        equipSlot = slotId,
        slotName = slotLabel,
        itemId = itemId,
        name = Util.CleanName(itemName or "Unknown Item"),
        itemLink = itemLink,
        icon = infoSucceeded and icon or nil,
        quality = quality or Util.Value("GetItemLinkQuality", nil, itemLink),
        requiredLevel = Util.Value("GetItemLinkRequiredLevel", nil, itemLink),
        requiredChampionPoints = Util.Value("GetItemLinkRequiredChampionPoints", nil, itemLink),
        equipType = linkEquipType,
        equipTypeName = enumName("SI_EQUIPTYPE", linkEquipType),
        itemType = itemType,
        itemTypeName = enumName("SI_ITEMTYPE", itemType),
        armorType = armorType,
        armorTypeName = enumName("SI_ARMORTYPE", armorType),
        weaponType = weaponType,
        weaponTypeName = weaponType and weaponType > 0 and enumName("SI_WEAPONTYPE", weaponType) or "None",
        trait = {
            id = traitType,
            name = enumName("SI_ITEMTRAITTYPE", traitType),
        },
        set = setSucceeded and {
            hasSet = hasSet == true,
            id = setId,
            name = Util.CleanName(setName),
            bonusCount = numBonuses,
            equippedCount = numNormalEquipped,
            maximumEquipped = maxEquipped,
            perfectedEquippedCount = numPerfectedEquipped,
        } or {
            hasSet = false,
        },
        enchantment = enchantSucceeded and {
            hasCharges = hasCharges == true,
            name = Util.CleanName(enchantHeader or enchantDescription),
            description = enchantDescription,
        } or nil,
        metadata = {
            stack = stack,
            sellPrice = sellPrice,
            meetsUsageRequirement = meetsUsageRequirement,
            locked = locked,
            itemStyleId = itemStyleId,
        },
    }
end

function Collector.Collect()
    local result = {
        items = {},
    }

    for _, slotDefinition in ipairs(EQUIPMENT_SLOTS) do
        local slotId = _G[slotDefinition.constantName]
        if slotId ~= nil then
            local item = collectItem(slotId, slotDefinition.label)
            if item then
                table.insert(result.items, item)
            end
        end
    end

    return result
end
