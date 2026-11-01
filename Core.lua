local ADDON_NAME, FU = ...
FU = _G.ForeverUpgrade or FU

local DEFAULTS = {
    spec = "auto",
    mode = "auto",
    threshold = 1.0,
    tooltips = true,
    arrows = true,
    questArrows = true,
    showPercent = true,
    details = false,
    customWeights = {},
}

local function applyDefaults(db, defaults)
    for key, value in pairs(defaults) do
        if db[key] == nil then
            if type(value) == "table" then
                db[key] = {}
                applyDefaults(db[key], value)
            else
                db[key] = value
            end
        end
    end
end

local function msg(text)
    print("|cffd8b45bForever Upgrade:|r " .. tostring(text))
end

local function boolText(v) return v and "on" or "off" end

local function getSource()
    local _, spec, mode = FU:GetWeights()
    return FU.WEIGHT_SOURCES and FU.WEIGHT_SOURCES[spec] and FU.WEIGHT_SOURCES[spec][mode] or "Unknown"
end

local function currentSummary()
    local _, spec, mode = FU:GetWeights()
    return string.format("spec=%s (%s), mode=%s, threshold=%.1f%%, tooltips=%s, arrows=%s, quest=%s",
        ForeverUpgradeDB.spec,
        FU.PROFILES[spec].label,
        mode,
        tonumber(ForeverUpgradeDB.threshold) or 0,
        boolText(ForeverUpgradeDB.tooltips), boolText(ForeverUpgradeDB.arrows), boolText(ForeverUpgradeDB.questArrows))
end

local function showHelp()
    msg("/fu status")
    msg("/fu source            (show active weight source)")
    msg("/fu spec auto|arms|fury|prot")
    msg("/fu mode auto|leveling|endgame")
    msg("/fu threshold <percent>   (default 1)")
    msg("/fu tooltips on|off   /fu arrows on|off   /fu quest on|off")
    msg("/fu percent on|off    /fu details on|off")
    msg("/fu weights            (show current profile weights)")
    msg("/fu set <STAT> <value> (example: /fu set STR 1.1)")
    msg("/fu reset              (reset current profile/mode custom weights)")
    msg("/fu export             (Pawn-style scale string)")
    msg("/fu import <Pawn string>")
end

local function setToggle(field, arg)
    arg = string.lower(arg or "")
    if arg ~= "on" and arg ~= "off" then
        msg(field .. " is " .. boolText(ForeverUpgradeDB[field]))
        return
    end
    ForeverUpgradeDB[field] = arg == "on"
    msg(field .. " " .. boolText(ForeverUpgradeDB[field]))
    FU:UpdateBagArrows()
    FU:UpdateQuestArrows()
end

local function weightContainer(create)
    local spec = FU:GetDetectedSpec()
    local mode = FU:GetMode()
    ForeverUpgradeDB.customWeights[spec] = ForeverUpgradeDB.customWeights[spec] or {}
    if create then
        ForeverUpgradeDB.customWeights[spec][mode] = ForeverUpgradeDB.customWeights[spec][mode] or {}
    end
    return ForeverUpgradeDB.customWeights[spec][mode], spec, mode
end

local function printWeights()
    local weights, spec, mode = FU:GetWeights()
    msg(FU.PROFILES[spec].label .. " / " .. mode .. " weights (rating stats are per 1 rating):")
    msg("source: " .. getSource())
    local line = {}
    for _, stat in ipairs(FU.STAT_ORDER) do
        if weights[stat] and weights[stat] ~= 0 then
            line[#line + 1] = string.format("%s=%.3f", stat, weights[stat])
            if #line == 5 then
                msg(table.concat(line, "  "))
                line = {}
            end
        end
    end
    if #line > 0 then msg(table.concat(line, "  ")) end
end

local function exportPawn()
    local weights, spec, mode = FU:GetWeights()
    local fields = {}
    for _, stat in ipairs(FU.STAT_ORDER) do
        local pawn = FU.INTERNAL_TO_PAWN[stat]
        local value = weights[stat]
        if pawn and value and value ~= 0 then
            fields[#fields + 1] = string.format("%s=%.4f", pawn, value)
        end
    end
    local name = string.format("Forever %s %s", FU.PROFILES[spec].label, mode)
    local scale = string.format("( Pawn: v1: \"%s\": %s )", name, table.concat(fields, ", "))
    msg(scale)
end

local function importPawn(text)
    if not text or text == "" then
        msg("Paste a Pawn-style scale after /fu import")
        return
    end

    local custom, spec, mode = weightContainer(true)
    local imported = 0
    for key, rawValue in string.gmatch(text, "([%a_][%w_]*)%s*=%s*([%-%.%d]+)") do
        local internal = FU.PAWN_TO_INTERNAL[key] or string.upper(key)
        local value = tonumber(rawValue)
        if value and FU.INTERNAL_TO_PAWN[internal] then
            custom[internal] = value
            imported = imported + 1
        end
    end

    msg(string.format("Imported %d weights into %s / %s.", imported, FU.PROFILES[spec].label, mode))
end

local function slash(input)
    input = input or ""
    local command, rest = string.match(input, "^(%S+)%s*(.-)%s*$")
    command = string.lower(command or "")

    if command == "" or command == "help" then
        showHelp()
    elseif command == "status" then
        msg(currentSummary())
        msg("source: " .. getSource())
    elseif command == "source" then
        msg(getSource())
    elseif command == "spec" then
        local value = string.lower(rest or "")
        if value == "protection" then value = "prot" end
        if value == "auto" or FU.PROFILES[value] then
            ForeverUpgradeDB.spec = value
            msg("spec set to " .. value .. " (active: " .. FU.PROFILES[FU:GetDetectedSpec()].label .. ")")
            FU:UpdateBagArrows(); FU:UpdateQuestArrows()
        else
            msg("spec must be auto, arms, fury, or prot")
        end
    elseif command == "mode" then
        local value = string.lower(rest or "")
        if value == "auto" or value == "leveling" or value == "endgame" then
            ForeverUpgradeDB.mode = value
            msg("mode set to " .. value .. " (active: " .. FU:GetMode() .. ")")
            FU:UpdateBagArrows(); FU:UpdateQuestArrows()
        else
            msg("mode must be auto, leveling, or endgame")
        end
    elseif command == "threshold" then
        local value = tonumber(rest)
        if value then
            ForeverUpgradeDB.threshold = math.max(0, value)
            msg(string.format("upgrade arrow threshold set to %.1f%%", ForeverUpgradeDB.threshold))
            FU:UpdateBagArrows(); FU:UpdateQuestArrows()
        else
            msg(string.format("threshold is %.1f%%", ForeverUpgradeDB.threshold))
        end
    elseif command == "tooltips" then
        setToggle("tooltips", rest)
    elseif command == "arrows" then
        setToggle("arrows", rest)
    elseif command == "quest" then
        setToggle("questArrows", rest)
    elseif command == "percent" then
        setToggle("showPercent", rest)
    elseif command == "details" then
        setToggle("details", rest)
    elseif command == "weights" then
        printWeights()
    elseif command == "set" then
        local stat, rawValue = string.match(rest, "^(%S+)%s+(%S+)$")
        stat = stat and string.upper(stat) or nil
        local value = tonumber(rawValue)
        if stat and value and FU.INTERNAL_TO_PAWN[stat] then
            local custom, spec, mode = weightContainer(true)
            custom[stat] = value
            msg(string.format("%s / %s: %s = %.4f", FU.PROFILES[spec].label, mode, stat, value))
            FU:UpdateBagArrows(); FU:UpdateQuestArrows()
        else
            msg("usage: /fu set <STAT> <value>  (try /fu weights)")
        end
    elseif command == "reset" then
        local _, spec, mode = weightContainer(false)
        if ForeverUpgradeDB.customWeights[spec] then
            ForeverUpgradeDB.customWeights[spec][mode] = nil
        end
        msg("reset custom weights for " .. FU.PROFILES[spec].label .. " / " .. mode)
        FU:UpdateBagArrows(); FU:UpdateQuestArrows()
    elseif command == "export" then
        exportPawn()
    elseif command == "import" then
        importPawn(rest)
        FU:UpdateBagArrows(); FU:UpdateQuestArrows()
    else
        showHelp()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LEVEL_UP")
pcall(frame.RegisterEvent, frame, "TRAIT_CONFIG_UPDATED")
pcall(frame.RegisterEvent, frame, "PLAYER_EQUIPMENT_CHANGED")
pcall(frame.RegisterEvent, frame, "BAG_UPDATE_DELAYED")
pcall(frame.RegisterEvent, frame, "QUEST_DETAIL")
pcall(frame.RegisterEvent, frame, "QUEST_COMPLETE")
pcall(frame.RegisterEvent, frame, "QUEST_FINISHED")
pcall(frame.RegisterEvent, frame, "PLAYER_TALENT_UPDATE")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        ForeverUpgradeDB = ForeverUpgradeDB or {}
        applyDefaults(ForeverUpgradeDB, DEFAULTS)
        SLASH_FOREVERUPGRADE1 = "/fu"
        SLASH_FOREVERUPGRADE2 = "/fup"
        SlashCmdList.FOREVERUPGRADE = slash
    elseif event == "PLAYER_LOGIN" then
        FU:HookTooltips()
        FU:HookBags()
        FU:HookQuestRewards()
        C_Timer.After(1, function()
            FU:UpdateBagArrows()
            msg("v" .. FU.VERSION .. " loaded. " .. currentSummary())
        end)
    elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_LEVEL_UP" or event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_TALENT_UPDATE" or event == "QUEST_DETAIL" or event == "QUEST_COMPLETE" or event == "QUEST_FINISHED" then
        FU:HookBags()
        FU:HookQuestRewards()
        FU:HookTooltips()
        C_Timer.After(0, function()
            FU:UpdateBagArrows()
            FU:UpdateQuestArrows()
        end)
    end
end)
