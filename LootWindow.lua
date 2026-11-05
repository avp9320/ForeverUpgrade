local ADDON_NAME, FU = ...
FU = _G.ForeverUpgrade or FU
if not FU then return end

-- Normal corpse/chest loot is the modern LootFrame.ScrollBox UI in Forever.
-- This is separate from GroupLootFrame (Need/Greed), handled by LootRolls.lua.
-- Read-only decoration: never loot, roll, or change Blizzard click handlers.
local hookedScrollBox

local function clearMarker(row)
    if not row then return end
    row.ForeverUpgradeLootPending = nil
    if row.ForeverUpgradeLootArrow then row.ForeverUpgradeLootArrow:Hide() end
    if row.ForeverUpgradeLootPercent then row.ForeverUpgradeLootPercent:Hide() end
end

local function ensureMarker(row)
    if row.ForeverUpgradeLootArrow then
        return row.ForeverUpgradeLootArrow, row.ForeverUpgradeLootPercent
    end
    if not row.CreateTexture or not row.CreateFontString then return nil end

    local icon = row.Item and (row.Item.icon or row.Item.Icon)
    local anchor = (icon and icon.GetObjectType and icon) or row.Item or row

    local arrow = row:CreateTexture(nil, "OVERLAY", nil, 7)
    arrow:SetAtlas("bags-greenarrow", false)
    arrow:SetSize(16, 16)
    arrow:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -1, -1)
    arrow:Hide()
    row.ForeverUpgradeLootArrow = arrow

    -- The item name is left aligned and "Poor"/rarity is at the upper right.
    -- Put the optional upgrade percent in the otherwise empty lower-right.
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -9, 5)
    text:SetWidth(95)
    text:SetJustifyH("RIGHT")
    text:SetTextColor(0.35, 1, 0.35)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
    text:Hide()
    row.ForeverUpgradeLootPercent = text
    return arrow, text
end

local function getSlot(row)
    if not (row and row.GetSlotIndex) then return nil end
    local ok, slot = pcall(row.GetSlotIndex, row)
    if ok and type(slot) == "number" then return slot end
    return nil
end

local function sameLootSlot(row, slot, link)
    if not (LootFrame and LootFrame.IsShown and LootFrame:IsShown()) then return false end
    if not (row and row.IsShown and row:IsShown()) then return false end
    if getSlot(row) ~= slot then return false end
    if type(GetLootSlotLink) ~= "function" then return false end
    local ok, current = pcall(GetLootSlotLink, slot)
    return ok and current == link
end

local function markRow(row)
    clearMarker(row)
    if not (ForeverUpgradeDB and ForeverUpgradeDB.arrows) then return end
    if not (LootFrame and LootFrame.IsShown and LootFrame:IsShown()) then return end
    if not (row and row.Item and row.IsShown and row:IsShown()) then return end

    local slot = getSlot(row)
    if not slot or type(GetLootSlotType) ~= "function" or type(GetLootSlotLink) ~= "function" then return end
    local okType, kind = pcall(GetLootSlotType, slot)
    local itemKind = Enum and Enum.LootSlotType and Enum.LootSlotType.Item or 1
    if not okType or kind ~= itemKind then return end  -- skip money/currency

    local ok, link = pcall(GetLootSlotLink, slot)
    if not ok or not link then return end

    local upgrade, result = FU:IsUpgrade(link)
    if upgrade and result then
        local arrow, text = ensureMarker(row)
        if arrow then arrow:Show() end
        if text and ForeverUpgradeDB.showPercent then
            local pct, newSlot = FU:UpgradePercent(result)
            text:SetText(newSlot and "NEW" or string.format("+%.0f%%", pct or 0))
            text:Show()
        end
        return
    end

    -- An item may appear before its stats are cached. Re-evaluate when loaded.
    -- The row and loot slot are checked again to avoid decorating a reused row.
    if Item and Item.CreateFromItemLink then
        local item = Item:CreateFromItemLink(link)
        if item and item.IsItemDataCached and not item:IsItemDataCached()
            and item.ContinueOnItemLoad then
            row.ForeverUpgradeLootPending = link
            item:ContinueOnItemLoad(function()
                if sameLootSlot(row, slot, link) and row.ForeverUpgradeLootPending == link then
                    markRow(row)
                end
            end)
        end
    end
end

function FU:UpdateLootWindow()
    local loot = LootFrame
    local box = loot and loot.ScrollBox
    if not (loot and loot.IsShown and loot:IsShown() and box and box.ForEachFrame) then return end
    box:ForEachFrame(function(row)
        markRow(row)
    end)
end

function FU:HookLootWindow()
    local loot = LootFrame
    local box = loot and loot.ScrollBox
    if not (box and ScrollUtil and ScrollUtil.AddInitializedFrameCallback) then return end
    if hookedScrollBox == box then return end
    hookedScrollBox = box

    -- Runs whenever Blizzard creates/reuses a visible loot entry.
    ScrollUtil.AddInitializedFrameCallback(box, function(_, row)
        markRow(row)
    end, FU, false)

    -- Pooled ScrollBox rows must not carry an old arrow into a different item.
    if ScrollUtil.AddReleasedFrameCallback then
        ScrollUtil.AddReleasedFrameCallback(box, function(_, row)
            clearMarker(row)
        end, FU)
    end

    if loot.HookScript then
        loot:HookScript("OnShow", function()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function() FU:UpdateLootWindow() end)
            else
                FU:UpdateLootWindow()
            end
        end)
        loot:HookScript("OnHide", function()
            if box.ForEachFrame then box:ForEachFrame(clearMarker) end
        end)
    end
    self:UpdateLootWindow()
end

local function queueRefresh()
    FU:HookLootWindow()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function() FU:UpdateLootWindow() end)
    else
        FU:UpdateLootWindow()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
for _, name in ipairs({
    "LOOT_READY", "LOOT_OPENED", "LOOT_SLOT_CHANGED", "LOOT_SLOT_CLEARED",
    "LOOT_CLOSED", "GET_ITEM_INFO_RECEIVED",
    "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP",
}) do
    pcall(events.RegisterEvent, events, name)
end

events:SetScript("OnEvent", function(_, event)
    if event == "LOOT_CLOSED" then
        if hookedScrollBox and hookedScrollBox.ForEachFrame then
            hookedScrollBox:ForEachFrame(clearMarker)
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" or event == "PLAYER_EQUIPMENT_CHANGED"
        or event == "PLAYER_LEVEL_UP" then
        if LootFrame and LootFrame.IsShown and LootFrame:IsShown() then
            queueRefresh()
        end
    else
        queueRefresh()
    end
end)
