local ADDON_NAME, FU = ...
FU = _G.ForeverUpgrade or FU

local max = math.max
local abs = math.abs

local SLOT = {
    HEAD = 1, NECK = 2, SHOULDER = 3, SHIRT = 4, CHEST = 5, WAIST = 6,
    LEGS = 7, FEET = 8, WRIST = 9, HANDS = 10,
    FINGER1 = 11, FINGER2 = 12, TRINKET1 = 13, TRINKET2 = 14,
    BACK = 15, MAINHAND = 16, OFFHAND = 17, RANGED = 18, TABARD = 19,
}

local EQUIP_SLOTS = {
    INVTYPE_HEAD = { SLOT.HEAD },
    INVTYPE_NECK = { SLOT.NECK },
    INVTYPE_SHOULDER = { SLOT.SHOULDER },
    INVTYPE_BODY = { SLOT.SHIRT },
    INVTYPE_CHEST = { SLOT.CHEST },
    INVTYPE_ROBE = { SLOT.CHEST },
    INVTYPE_WAIST = { SLOT.WAIST },
    INVTYPE_LEGS = { SLOT.LEGS },
    INVTYPE_FEET = { SLOT.FEET },
    INVTYPE_WRIST = { SLOT.WRIST },
    INVTYPE_HAND = { SLOT.HANDS },
    INVTYPE_FINGER = { SLOT.FINGER1, SLOT.FINGER2 },
    INVTYPE_TRINKET = { SLOT.TRINKET1, SLOT.TRINKET2 },
    INVTYPE_CLOAK = { SLOT.BACK },
    INVTYPE_WEAPON = { SLOT.MAINHAND, SLOT.OFFHAND },
    INVTYPE_WEAPONMAINHAND = { SLOT.MAINHAND },
    INVTYPE_WEAPONOFFHAND = { SLOT.OFFHAND },
    INVTYPE_SHIELD = { SLOT.OFFHAND },
    INVTYPE_HOLDABLE = { SLOT.OFFHAND },
    INVTYPE_2HWEAPON = { SLOT.MAINHAND },
    INVTYPE_RANGED = { SLOT.RANGED },
    INVTYPE_THROWN = { SLOT.RANGED },
    INVTYPE_RANGEDRIGHT = { SLOT.RANGED },
    INVTYPE_TABARD = { SLOT.TABARD },
}

local function copyTable(src)
    local out = {}
    for k, v in pairs(src or {}) do out[k] = v end
    return out
end

function FU:GetDetectedSpec()
    local override = ForeverUpgradeDB and ForeverUpgradeDB.spec or "auto"
    if override and override ~= "auto" and FU.PROFILES[override] then
        return override
    end

    -- WoW: Forever is a Classic-style talent game. A modern specialization
    -- metadata API usually returns a role/class name, NOT points invested in
    -- Arms/Fury/Protection. Read the actual talent tab points instead.
    local bestIndex, bestPoints = 1, -1
    local sawRealPoints = false

    if type(GetNumTalentTabs) == "function" and
        type(GetTalentTabInfo) == "function" then
        local ok, count = pcall(GetNumTalentTabs)
        if ok and type(count) == "number" and count >= 3 then
            for index = 1, 3 do
                local okTab, name, icon, points = pcall(GetTalentTabInfo, index)
                if okTab and type(points) == "number" then
                    sawRealPoints = true
                    if points > bestPoints then
                        bestIndex, bestPoints = index, points
                    end
                end
            end
        end
    end

    -- On hybrid clients without Classic talent-tab APIs, only use the
    -- specialization API when it *actually* exposes a numeric points value.
    if not sawRealPoints and C_SpecializationInfo and
        type(C_SpecializationInfo.GetSpecializationInfo) == "function" then
        for index = 1, 3 do
            local ok, _, _, _, _, _, _, pointsSpent =
                pcall(C_SpecializationInfo.GetSpecializationInfo, index)
            if ok and type(pointsSpent) == "number" then
                sawRealPoints = true
                if pointsSpent > bestPoints then
                    bestIndex, bestPoints = index, pointsSpent
                end
            end
        end
    end

    if sawRealPoints then
        if bestIndex == 2 then return "fury" end
        if bestIndex == 3 then return "prot" end
        return "arms"
    end

    -- A real active specialization is a better fallback than a hard-coded
    -- Arms assignment when this client does not expose points to addons.
    if type(GetSpecialization) == "function" then
        local ok, index = pcall(GetSpecialization)
        if ok and index == 2 then return "fury" end
        if ok and index == 3 then return "prot" end
    end
    return "arms"
end

function FU:GetMode()
    local configured = ForeverUpgradeDB and ForeverUpgradeDB.mode or "auto"
    if configured == "leveling" or configured == "endgame" then
        return configured
    end
    local level = UnitLevel and UnitLevel("player") or 1
    return level >= 60 and "endgame" or "leveling"
end

function FU:GetWeights()
    local spec = self:GetDetectedSpec()
    local mode = self:GetMode()
    local base = copyTable(FU.PROFILES[spec][mode])

    local custom = ForeverUpgradeDB and ForeverUpgradeDB.customWeights
    if custom and custom[spec] and custom[spec][mode] then
        for k, v in pairs(custom[spec][mode]) do
            base[k] = v
        end
    end

    return base, spec, mode
end

local function itemInfo(link)
    if not (link and C_Item and C_Item.GetItemInfo) then return nil end
    local ok, name, itemLink, quality, itemLevel, requiredLevel, itemType, itemSubType, maxStack, equipLoc, icon, sellPrice, classID, subclassID = pcall(C_Item.GetItemInfo, link)
    if not ok or not name then return nil end
    return {
        name = name, link = itemLink or link, quality = quality, itemLevel = itemLevel,
        requiredLevel = requiredLevel, itemType = itemType, itemSubType = itemSubType,
        equipLoc = equipLoc, icon = icon, sellPrice = sellPrice, classID = classID, subclassID = subclassID,
    }
end

local function itemIDFromLink(link)
    if not link then return nil end
    local id = tonumber(string.match(link, "item:(%d+)"))
    if id then return id end
    if C_Item and C_Item.GetItemInfoInstant then
        local ok, itemID = pcall(C_Item.GetItemInfoInstant, link)
        if ok then return itemID end
    end
    return nil
end

-- These are primary armor slots, not cloaks, jewelry or weapon off-hands.
-- Forever Warriors start with mail proficiency and learn plate at level 40.
-- A technically wearable cloth caster robe is not an Arms gear recommendation.
local PRIMARY_ARMOR = {
    INVTYPE_HEAD = true, INVTYPE_SHOULDER = true,
    INVTYPE_CHEST = true, INVTYPE_ROBE = true,
    INVTYPE_WAIST = true, INVTYPE_LEGS = true,
    INVTYPE_FEET = true, INVTYPE_WRIST = true, INVTYPE_HAND = true,
}

function FU:IsUsable(link)
    local info = itemInfo(link)
    if not info then return false end
    local level = UnitLevel and tonumber(UnitLevel("player")) or 1

    -- CanUseItem alone doesn't reliably apply the character-level requirement
    -- on every Forever client/build.
    if tonumber(info.requiredLevel) and tonumber(info.requiredLevel) > level then
        return false
    end

    local _, classToken = UnitClass and UnitClass("player")
    if classToken == "WARRIOR" and PRIMARY_ARMOR[info.equipLoc] and
        tonumber(info.classID) == 4 then
        local armorType = tonumber(info.subclassID)
        -- Armor subclass IDs: 1 cloth, 2 leather, 3 mail, 4 plate.
        -- Warrior-first recommendation policy favors mail/plate for core armor;
        -- lower armor tiers can still be worn manually, just not auto-flagged.
        if armorType == 1 or armorType == 2 then return false end
        if armorType == 4 and level < 40 then return false end
    end

    local itemID = itemIDFromLink(link)
    if itemID and C_PlayerInfo and C_PlayerInfo.CanUseItem then
        local ok, canUse = pcall(C_PlayerInfo.CanUseItem, itemID)
        if ok and canUse == false then return false end
    end
    return true
end

local function normalizedStats(link)
    if not (link and C_Item and C_Item.GetItemStats) then return nil end
    local ok, raw = pcall(C_Item.GetItemStats, link)
    if not ok or type(raw) ~= "table" then return nil end

    local stats = {}
    for key, value in pairs(raw) do
        local internal = FU.ITEM_STAT_KEYS[key]
        if internal and type(value) == "number" then
            stats[internal] = (stats[internal] or 0) + value
        end
    end
    -- No recognized stats is missing scoring evidence, not a 0-point item.
    if not next(stats) then return nil end
    return stats
end

local function weaponRole(equipLoc, slot)
    if slot == SLOT.RANGED then return "ranged" end
    if slot == SLOT.OFFHAND and (equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONOFFHAND") then
        return "offhand"
    end
    return "mainhand"
end

function FU:ScoreItem(link, slotOverride)
    local info = itemInfo(link)
    if not info or not info.equipLoc or info.equipLoc == "" then return nil end

    local stats = normalizedStats(link)
    if not stats then return nil end

    local weights = self:GetWeights()
    local slot = slotOverride
    local role = weaponRole(info.equipLoc, slot)
    local total = 0

    for stat, value in pairs(stats) do
        local weightKey = stat
        if stat == "DPS" then
            if role == "offhand" then
                weightKey = "DPS_OFF"
            elseif role == "ranged" then
                weightKey = "DPS_RANGED"
            else
                weightKey = "DPS"
            end
        end
        total = total + value * (weights[weightKey] or 0)
    end

    return total, stats, info
end

local function equippedLink(slot)
    if not GetInventoryItemLink then return nil end
    local ok, link = pcall(GetInventoryItemLink, "player", slot)
    if ok then return link end
    return nil
end

local function compareSingle(self, candidate, slot)
    local candidateScore = self:ScoreItem(candidate, slot)
    if not candidateScore then return nil end
    local worn = equippedLink(slot)
    local wornScore = 0
    if worn then
        wornScore = self:ScoreItem(worn, slot)
        -- Never pretend a worn but uncached item is an empty slot: doing so
        -- produced extreme "upgrade" percentages and phantom new slots.
        if wornScore == nil then return nil, nil, nil, slot, worn, "unscorable" end
    end
    return candidateScore - wornScore, candidateScore, wornScore, slot, worn
end

function FU:CompareItem(link)
    if not self:IsUsable(link) then return nil, "unusable" end
    local _, _, info = self:ScoreItem(link, SLOT.MAINHAND)
    if not info then
        local basic = itemInfo(link)
        if basic and basic.equipLoc and basic.equipLoc ~= "" then
            return nil, "unscorable"
        end
        return nil, "not_equippable"
    end

    local equipLoc = info.equipLoc
    local slots = EQUIP_SLOTS[equipLoc]
    if not slots then return nil, "unsupported_slot" end

    local spec = self:GetDetectedSpec()

    -- Keep recommendations aligned with the active Warrior role rather than
    -- suggesting technically equippable but nonsensical off-spec hand setups.
    if equipLoc == "INVTYPE_SHIELD" and spec ~= "prot" then
        return nil, "offspec_item"
    elseif equipLoc == "INVTYPE_WEAPONOFFHAND" and spec ~= "fury" then
        return nil, "offspec_item"
    elseif equipLoc == "INVTYPE_WEAPON" then
        local canDual = false
        if spec == "fury" and CanDualWield then
            local ok, value = pcall(CanDualWield)
            canDual = ok and value and true or false
        end
        slots = canDual and { SLOT.MAINHAND, SLOT.OFFHAND } or { SLOT.MAINHAND }
    end

    -- Two-handers replace both hands. This matters a lot when Fury is currently dual-wielding
    -- or Protection is holding a shield.
    if equipLoc == "INVTYPE_2HWEAPON" then
        local candidateScore = self:ScoreItem(link, SLOT.MAINHAND)
        local main = equippedLink(SLOT.MAINHAND)
        local off = equippedLink(SLOT.OFFHAND)
        local wornScore = 0
        if main then
            local mainScore = self:ScoreItem(main, SLOT.MAINHAND)
            if mainScore == nil then return nil, "unscorable" end
            wornScore = wornScore + mainScore
        end
        if off then
            local offScore = self:ScoreItem(off, SLOT.OFFHAND)
            if offScore == nil then return nil, "unscorable" end
            wornScore = wornScore + offScore
        end
        local delta = candidateScore - wornScore
        return {
            delta = delta, candidate = candidateScore, equipped = wornScore,
            slot = SLOT.MAINHAND, replaced = { main, off }, info = info,
        }
    end

    local best
    -- A one-handed weapon cannot be placed in the off hand while a two-hander
    -- occupies the main hand. Do not suggest a phantom off-hand upgrade that
    -- would require removing the equipped two-hander first.
    local mainLink = equippedLink(SLOT.MAINHAND)
    local mainInfo = mainLink and itemInfo(mainLink)
    local mainIsTwoHanded = mainInfo and mainInfo.equipLoc == "INVTYPE_2HWEAPON"
    local unscorable = false
    for _, slot in ipairs(slots) do
        if not (slot == SLOT.OFFHAND and mainIsTwoHanded) then
            local delta, candidateScore, wornScore, comparedSlot, worn, reason = compareSingle(self, link, slot)
            if reason == "unscorable" then unscorable = true end
            if delta and (not best or delta > best.delta) then
                best = {
                    delta = delta, candidate = candidateScore, equipped = wornScore,
                    slot = comparedSlot, replaced = { worn }, info = info,
                }
            end
        end
    end

    if not best then return nil, unscorable and "unscorable" or "no_comparison" end
    return best
end

-- Protection has two distinct priorities. These estimates deliberately use the
-- existing sourced/heuristic profile weights rather than inventing new sim EP.
-- Keep the legacy hybrid delta for arrows and other API consumers.
local PROT_SURVIVAL = { STA = true, ARMOR = true, DEF = true, DODGE = true,
    PARRY = true, BLOCK = true, BLOCKVALUE = true, AGI = true }
local PROT_THREAT = { STR = true, AP = true, HIT = true, CRIT = true,
    HASTE = true, EXPERTISE = true, ARP = true, DPS = true }

function FU:ProtectionComparison(link)
    if self:GetDetectedSpec() ~= "prot" then return nil end
    local result = self:CompareItem(link)
    if not result then return nil end
    local weights = self:GetWeights()
    local function component(itemLink, slot, group)
        if not itemLink then return 0 end
        local _, stats, info = self:ScoreItem(itemLink, slot)
        if not stats then return 0 end
        local score = 0
        for stat, value in pairs(stats) do
            if group[stat] then
                local key = stat
                if stat == "DPS" and info then
                    local role = weaponRole(info.equipLoc, slot)
                    key = role == "offhand" and "DPS_OFF" or (role == "ranged" and "DPS_RANGED" or "DPS")
                end
                score = score + value * (weights[key] or 0)
            end
        end
        return score
    end
    local threat = component(link, result.slot, PROT_THREAT)
    local survival = component(link, result.slot, PROT_SURVIVAL)
    local wornThreat, wornSurvival = 0, 0
    for index = 1, (result.info.equipLoc == "INVTYPE_2HWEAPON" and 2 or 1) do
        local worn = result.replaced and result.replaced[index]
        local slot = result.slot
        if result.info.equipLoc == "INVTYPE_2HWEAPON" then
            slot = index == 1 and SLOT.MAINHAND or SLOT.OFFHAND
        end
        wornThreat = wornThreat + component(worn, slot, PROT_THREAT)
        wornSurvival = wornSurvival + component(worn, slot, PROT_SURVIVAL)
    end
    return { threat = threat - wornThreat, survival = survival - wornSurvival,
        threatCandidate = threat, survivalCandidate = survival,
        threatEquipped = wornThreat, survivalEquipped = wornSurvival }
end

function FU:UpgradePercent(result)
    if not result then return nil end
    if result.equipped <= 0 then
        if result.candidate > 0 then return nil, true end
        return 0, false
    end
    return (result.delta / result.equipped) * 100, false
end

-- Selection policy for Protection arrows. Hybrid remains the default for
-- existing installations; threat/survival use their own baseline and threshold.
function FU:RecommendationComparison(link, result)
    result = result or self:CompareItem(link)
    if not result then return nil end
    local policy = ForeverUpgradeDB and ForeverUpgradeDB.protPriority or "hybrid"
    if self:GetDetectedSpec() ~= "prot" or (policy ~= "threat" and policy ~= "survival") then
        return result
    end
    local split = self:ProtectionComparison(link)
    if not split then return result end
    local chosen = policy == "threat" and split.threat or split.survival
    local candidate = policy == "threat" and split.threatCandidate or split.survivalCandidate
    local equipped = policy == "threat" and split.threatEquipped or split.survivalEquipped
    return { delta = chosen, candidate = candidate, equipped = equipped,
        slot = result.slot, replaced = result.replaced, info = result.info,
        priority = policy }
end

function FU:IsUpgrade(link)
    local result = self:RecommendationComparison(link)
    if not result then return false, nil end
    local threshold = ForeverUpgradeDB and tonumber(ForeverUpgradeDB.threshold) or 0
    local pct, isNew = self:UpgradePercent(result)
    if isNew then return result.delta > 0, result end
    return pct and pct >= threshold and result.delta > 0, result
end

function FU:GetItemLinkFromTooltipData(data)
    if not data then return nil end
    if data.hyperlink then return data.hyperlink end
    if data.guid and C_Item and C_Item.GetItemLinkByGUID then
        local ok, link = pcall(C_Item.GetItemLinkByGUID, data.guid)
        if ok and link then return link end
    end
    if data.id then return "item:" .. tostring(data.id) end
    return nil
end

function FU:FormatComparison(result)
    if not result then return nil end
    local pct, isNew = self:UpgradePercent(result)
    local _, spec, mode = self:GetWeights()
    local label = FU.PROFILES[spec].label

    if isNew and result.delta > 0 then
        return "|cff20ff20▲ New slot|r", label, mode
    end

    pct = pct or 0
    if result.delta > 0 then
        -- A near-zero worn item score creates absurd ratios (e.g. +2781%).
        -- This is a weighted item-score comparison, not a DPS/survival gain.
        if pct >= 100 then
            return "|cff20ff20▲ Strong gear-score upgrade|r", label, mode
        end
        return string.format("|cff20ff20▲ +%.1f%% item score|r", pct), label, mode
    elseif result.delta < 0 then
        return string.format("|cffff5050▼ %.1f%% estimated|r", pct), label, mode
    else
        return "|cffffff80≈ Sidegrade|r", label, mode
    end
end

function FU:GetBreakdown(link, slot)
    local score, stats = self:ScoreItem(link, slot)
    if not score or not stats then return nil end
    local weights = self:GetWeights()
    local parts = {}
    for _, stat in ipairs(FU.STAT_ORDER) do
        local value = stats[stat]
        if value and value ~= 0 then
            local key = stat
            if stat == "DPS" then
                local _, _, info = self:ScoreItem(link, slot)
                local role = info and weaponRole(info.equipLoc, slot) or "mainhand"
                key = role == "offhand" and "DPS_OFF" or (role == "ranged" and "DPS_RANGED" or "DPS")
            end
            local weight = weights[key] or 0
            if weight ~= 0 then
                parts[#parts + 1] = string.format("%s %.2f×%.2f", stat, value, weight)
            end
        end
    end
    return score, parts
end
