local ADDON_NAME, FU = ...
FU = _G.ForeverUpgrade or FU
if not FU then return end

-- Keep the runtime version in sync with the packaged release. Profiles.lua owns
-- the original version declaration, but this feature ships in v0.2.2.
FU.VERSION = "0.2.2"

local BIG_UPGRADE_PERCENT = 10
local MAX_GROUP_LOOT_FRAMES = 4
local hookedFrames = setmetatable({}, { __mode = "k" })

FU.LootRollDebug = FU.LootRollDebug or {
    lastRollID = nil,
    lastItem = nil,
    lastVerdict = nil,
    lastReason = nil,
}

local VERDICT_COLORS = {
    BIG_UPGRADE = { 0.20, 1.00, 0.20 },
    UPGRADE = { 0.45, 1.00, 0.45 },
    SIDEGRADE = { 1.00, 0.82, 0.20 },
    DOWNGRADE = { 0.75, 0.75, 0.75 },
    NOT_FOR_YOU = { 1.00, 0.35, 0.35 },
}

local function ensureHint(frame)
    if not frame or not frame.CreateFontString then return nil end
    if frame.ForeverUpgradeRollHint then return frame.ForeverUpgradeRollHint end

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 54, 9)
    text:SetWidth(145)
    text:SetJustifyH("LEFT")
    text:SetShadowOffset(1, -1)
    text:Hide()

    frame.ForeverUpgradeRollHint = text
    return text
end

local function clearHint(frame)
    if not frame then return end
    frame.ForeverUpgradePendingRollID = nil
    if frame.ForeverUpgradeRollHint then
        frame.ForeverUpgradeRollHint:SetText("")
        frame.ForeverUpgradeRollHint:Hide()
    end
end

function FU:GetLootRollVerdict(link)
    if not link then return nil, nil, "no_link" end

    local result, reason = self:CompareItem(link)
    if not result then
        if reason == "unusable" or reason == "offspec_item" then
            return "NOT FOR YOU", "NOT_FOR_YOU", reason
        end
        return nil, nil, reason or "no_comparison"
    end

    local pct, isNew = self:UpgradePercent(result)
    local threshold = ForeverUpgradeDB and tonumber(ForeverUpgradeDB.threshold) or 1
    threshold = math.max(0, threshold or 1)

    if isNew and result.delta > 0 then
        return "BIG UPGRADE", "BIG_UPGRADE", "empty_slot"
    end

    pct = pct or 0
    if result.delta > 0 and pct >= math.max(BIG_UPGRADE_PERCENT, threshold) then
        return "BIG UPGRADE", "BIG_UPGRADE", string.format("%+.1f%%", pct)
    elseif result.delta > 0 and pct >= threshold then
        return "UPGRADE", "UPGRADE", string.format("%+.1f%%", pct)
    elseif result.delta == 0 or math.abs(pct) < threshold then
        return "SIDEGRADE", "SIDEGRADE", string.format("%+.1f%%", pct)
    else
        return "DOWNGRADE", "DOWNGRADE", string.format("%+.1f%%", pct)
    end
end

local function applyVerdict(frame, rollID, link)
    if not frame or frame.rollID ~= rollID or not frame.IsShown or not frame:IsShown() then return false end

    local verdict, key, reason = FU:GetLootRollVerdict(link)
    FU.LootRollDebug.lastRollID = rollID
    FU.LootRollDebug.lastItem = link
    FU.LootRollDebug.lastVerdict = verdict
    FU.LootRollDebug.lastReason = reason

    if not verdict then return false end

    local text = ensureHint(frame)
    if not text then return false end

    local color = VERDICT_COLORS[key] or VERDICT_COLORS.SIDEGRADE
    text:SetText(verdict)
    text:SetTextColor(color[1], color[2], color[3])
    text:Show()
    frame.ForeverUpgradePendingRollID = nil
    return true
end

local function updateRollFrame(frame, attempt)
    if not frame or not frame.rollID or not frame.IsShown or not frame:IsShown() then return end
    if type(GetLootRollItemLink) ~= "function" then return end

    local rollID = frame.rollID
    local ok, link = pcall(GetLootRollItemLink, rollID)
    if not ok or not link then
        if (attempt or 0) < 4 and C_Timer and C_Timer.After then
            C_Timer.After(0.15, function() updateRollFrame(frame, (attempt or 0) + 1) end)
        end
        return
    end

    if applyVerdict(frame, rollID, link) then return end

    -- Item stats can briefly be uncached as a roll appears. Prefer the Item API
    -- callback when available, then fall back to a few tiny delayed retries.
    if frame.ForeverUpgradePendingRollID ~= rollID and Item and Item.CreateFromItemLink then
        local item = Item:CreateFromItemLink(link)
        if item and item.ContinueOnItemLoad then
            frame.ForeverUpgradePendingRollID = rollID
            item:ContinueOnItemLoad(function()
                if frame.rollID == rollID and frame.IsShown and frame:IsShown() then
                    applyVerdict(frame, rollID, link)
                end
            end)
        end
    end

    if (attempt or 0) < 4 and C_Timer and C_Timer.After then
        C_Timer.After(0.20, function() updateRollFrame(frame, (attempt or 0) + 1) end)
    end
end

function FU:UpdateLootRollFrames()
    for i = 1, MAX_GROUP_LOOT_FRAMES do
        local frame = _G["GroupLootFrame" .. i]
        if frame and frame.IsShown and frame:IsShown() then
            updateRollFrame(frame, 0)
        end
    end
end

function FU:HookLootRollFrames()
    for i = 1, MAX_GROUP_LOOT_FRAMES do
        local frame = _G["GroupLootFrame" .. i]
        if frame and frame.HookScript and not hookedFrames[frame] then
            hookedFrames[frame] = true
            frame:HookScript("OnShow", function(self)
                clearHint(self)
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function() updateRollFrame(self, 0) end)
                else
                    updateRollFrame(self, 0)
                end
            end)
            frame:HookScript("OnHide", clearHint)
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("ADDON_LOADED")
pcall(eventFrame.RegisterEvent, eventFrame, "START_LOOT_ROLL")
pcall(eventFrame.RegisterEvent, eventFrame, "GET_ITEM_INFO_RECEIVED")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "ADDON_LOADED" then
        FU:HookLootRollFrames()
    elseif event == "START_LOOT_ROLL" then
        FU:HookLootRollFrames()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() FU:UpdateLootRollFrames() end)
        else
            FU:UpdateLootRollFrames()
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        FU:UpdateLootRollFrames()
    end
end)
