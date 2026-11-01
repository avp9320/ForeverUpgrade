local ADDON_NAME, FU = ...
FU = _G.ForeverUpgrade or FU

local function ensureOverlay(button)
    if not button or not button.CreateTexture then return nil end
    if not button.ForeverUpgradeArrow then
        local tex = button:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetAtlas("bags-greenarrow", true)
        tex:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        tex:Hide()
        button.ForeverUpgradeArrow = tex

        local text = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        text:SetPoint("TOP", button, "TOP", 0, -2)
        text:SetTextColor(0.2, 1, 0.2)
        text:SetShadowOffset(1, -1)
        text:Hide()
        button.ForeverUpgradePercent = text
    end
    return button.ForeverUpgradeArrow, button.ForeverUpgradePercent
end

function FU:ClearButton(button)
    if button and button.ForeverUpgradeArrow then button.ForeverUpgradeArrow:Hide() end
    if button and button.ForeverUpgradePercent then button.ForeverUpgradePercent:Hide() end
end

function FU:MarkButton(button, link)
    if not button then return end
    self:ClearButton(button)
    if not (ForeverUpgradeDB and ForeverUpgradeDB.arrows) then return end
    if not link then return end

    local isUpgrade, result = self:IsUpgrade(link)
    if not isUpgrade or not result then return end

    local arrow, text = ensureOverlay(button)
    if not arrow then return end
    arrow:Show()

    if ForeverUpgradeDB.showPercent and text then
        local pct, isNew = self:UpgradePercent(result)
        text:SetText(isNew and "NEW" or string.format("+%.0f%%", pct or 0))
        text:Show()
    end
end

local function updateContainerButton(button, bag, slot)
    if not button then return end
    slot = slot or (button.GetID and button:GetID())
    if bag == nil and button.GetBagID then bag = button:GetBagID() end
    if bag == nil and button.GetSlotAndBagID then
        local s, b = button:GetSlotAndBagID()
        slot, bag = s, b
    end
    if bag == nil or slot == nil then return end
    if not (C_Container and C_Container.GetContainerItemLink) then return end
    local ok, link = pcall(C_Container.GetContainerItemLink, bag, slot)
    if ok then FU:MarkButton(button, link) end
end

function FU:UpdateBagArrows()
    if not (ForeverUpgradeDB and ForeverUpgradeDB.arrows) then return end

    local function updateFrame(frame)
        if not (frame and frame.EnumerateValidItems) then return end
        for _, itemButton in frame:EnumerateValidItems() do
            if itemButton then
                updateContainerButton(itemButton, itemButton.GetBagID and itemButton:GetBagID() or nil, itemButton.GetID and itemButton:GetID() or nil)
            end
        end
    end

    if ContainerFrameCombinedBags and ContainerFrameCombinedBags.IsShown and ContainerFrameCombinedBags:IsShown() then
        updateFrame(ContainerFrameCombinedBags)
    end

    if ContainerFrameContainer and ContainerFrameContainer.ContainerFrames then
        for _, frame in ipairs(ContainerFrameContainer.ContainerFrames) do
            if frame and frame.IsShown and frame:IsShown() then updateFrame(frame) end
        end
    end
end

local hookedBagFrames = setmetatable({}, { __mode = "k" })

function FU:HookBags()
    local function hookFrame(frame)
        if not (frame and frame.UpdateItems) or hookedBagFrames[frame] then return end
        hookedBagFrames[frame] = true
        hooksecurefunc(frame, "UpdateItems", function(f)
            if not (ForeverUpgradeDB and ForeverUpgradeDB.arrows) then return end
            if f and f.EnumerateValidItems then
                for _, itemButton in f:EnumerateValidItems() do
                    updateContainerButton(itemButton, itemButton.GetBagID and itemButton:GetBagID() or nil, itemButton.GetID and itemButton:GetID() or nil)
                end
            end
        end)
    end

    hookFrame(ContainerFrameCombinedBags)
    if ContainerFrameContainer and ContainerFrameContainer.ContainerFrames then
        for _, frame in ipairs(ContainerFrameContainer.ContainerFrames) do hookFrame(frame) end
    end
end

local function questRewardLink(button)
    if not button or button.objectType ~= "item" or not button.type then return nil end
    local index = button.GetID and button:GetID()
    if not index then return nil end

    if QuestInfoFrame and QuestInfoFrame.questLog and GetQuestLogItemLink then
        local ok, link = pcall(GetQuestLogItemLink, button.type, index)
        if ok and link then return link end
    elseif GetQuestItemLink then
        local ok, link = pcall(GetQuestItemLink, button.type, index)
        if ok and link then return link end
    end
    return nil
end

function FU:UpdateQuestArrows()
    if not (ForeverUpgradeDB and ForeverUpgradeDB.questArrows) then return end
    if not (QuestInfoFrame and QuestInfoFrame.rewardsFrame) then return end
    local rewards = QuestInfoFrame.rewardsFrame
    if not rewards.RewardButtons then return end

    local bestButton, bestResult
    for _, button in ipairs(rewards.RewardButtons) do
        self:ClearButton(button)
        if button and button.IsShown and button:IsShown() and button.type == "choice" and button.objectType == "item" then
            local link = questRewardLink(button)
            if link then
                local isUpgrade, result = self:IsUpgrade(link)
                if isUpgrade and result and (not bestResult or result.delta > bestResult.delta) then
                    bestButton, bestResult = button, result
                end
            end
        end
    end

    -- Deliberately mark only the best choosable reward. Mandatory rewards still
    -- receive normal tooltip scoring, but don't need a "pick me" arrow.
    if bestButton and bestResult then
        local arrow, text = ensureOverlay(bestButton)
        if arrow then arrow:Show() end
        if ForeverUpgradeDB.showPercent and text then
            local pct, isNew = self:UpgradePercent(bestResult)
            text:SetText(isNew and "NEW" or string.format("+%.0f%%", pct or 0))
            text:Show()
        end
    end
end

function FU:HookQuestRewards()
    if self.questHooked then return end
    if type(QuestInfo_ShowRewards) ~= "function" then return end
    self.questHooked = true
    hooksecurefunc("QuestInfo_ShowRewards", function()
        C_Timer.After(0, function() FU:UpdateQuestArrows() end)
    end)
end

function FU:HookTooltips()
    if self.tooltipsHooked then return end
    if not (TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item) then return end
    self.tooltipsHooked = true

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if not (ForeverUpgradeDB and ForeverUpgradeDB.tooltips) then return end
        if not (tooltip and tooltip.AddDoubleLine) then return end

        local link = FU:GetItemLinkFromTooltipData(data)
        if not link then return end
        local result = FU:CompareItem(link)
        if not result then return end

        local text, specLabel, mode = FU:FormatComparison(result)
        if not text then return end

        tooltip:AddDoubleLine("Forever Upgrade", text, 0.95, 0.82, 0.25, 1, 1, 1)
        tooltip:AddDoubleLine("Profile", string.format("%s / %s", specLabel, mode == "leveling" and "Leveling" or "Endgame"), 0.55, 0.55, 0.55, 0.75, 0.75, 0.75)

        if ForeverUpgradeDB.details then
            tooltip:AddDoubleLine("Weighted score", string.format("%.1f → %.1f", result.equipped or 0, result.candidate or 0), 0.55, 0.55, 0.55, 0.75, 0.75, 0.75)
        end
    end)
end
