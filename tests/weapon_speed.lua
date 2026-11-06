-- Lightweight API-mock test for the conservative weapon-speed model.
-- Run from the repository root: lua5.4 tests/weapon_speed.lua
local items = {
    ["item:slow2h"] = { loc="INVTYPE_2HWEAPON", dps=20, speed=3.8, str=4 },
    ["item:fast2h"] = { loc="INVTYPE_2HWEAPON", dps=20, speed=2.6, str=4 },
    ["item:slow1h"] = { loc="INVTYPE_WEAPON", dps=20, speed=2.8, str=4 },
    ["item:fast1h"] = { loc="INVTYPE_WEAPON", dps=20, speed=1.5, str=4 },
    ["item:fast1hstrong"] = { loc="INVTYPE_WEAPON", dps=23, speed=1.5, str=4 },
    ["item:unknown"] = { loc="INVTYPE_WEAPON", dps=20, str=4 },
}

ForeverUpgradeDB = {spec="arms", mode="leveling", customWeights={}}
C_Item = {
    GetItemInfo = function(link)
        local item=items[link]
        if not item then return nil end
        return link, link, 2, 20, 1, "Weapon", "Axe", 1, item.loc, 0, 0, 2, 0
    end,
    GetItemStats = function(link)
        local item=items[link]
        if not item then return nil end
        return {ITEM_MOD_DAMAGE_PER_SECOND_SHORT=item.dps, ITEM_MOD_STRENGTH_SHORT=item.str}
    end,
}
C_TooltipInfo = {
    GetHyperlink = function(link)
        local item=items[link]
        if not item or not item.speed then return nil end
        return {lines={{leftText="One-Hand", rightText=string.format("Speed %.2f", item.speed)}}}
    end,
}
UnitLevel = function() return 30 end
UnitClass = function() return "Warrior", "WARRIOR" end
GetInventoryItemLink = function() return nil end

local profiles=assert(loadfile("Profiles.lua"))
profiles("ForeverUpgrade", {})
local scoring=assert(loadfile("Scoring.lua"))
scoring("ForeverUpgrade", _G.ForeverUpgrade)
local FU=assert(_G.ForeverUpgrade)

local function score(link, slot)
    local result=FU:ScoreItem(link, slot)
    assert(type(result) == "number", "Item should be scored: "..link)
    return result
end
local function approximately(a, b, epsilon)
    assert(math.abs(a-b) <= (epsilon or 0.00001), "expected "..tostring(a).." ~= "..tostring(b))
end

-- Arms 2H: slower at equal DPS/stats gets a SMALL estimated tie-break.
local slow, fast = score("item:slow2h", 16), score("item:fast2h", 16)
assert(slow > fast, "slower Arms 2H should win a close tie")
assert((slow-fast) < 0.065 * 20 * 8, "2H speed preference must remain bounded")
assert(FU:GetWeaponSpeed("item:slow2h") == 3.8, "read weapon speed from modern tooltip")

-- Fury main hand: never impose a universal slow-speed penalty on quick 1H.
ForeverUpgradeDB.spec = "fury"
approximately(score("item:slow1h",16), score("item:fast1h",16))
assert(score("item:fast1hstrong",16) > score("item:slow1h",16),
    "faster 1H with better DPS must win")
-- Fury offhand: a fast 1H can earn a very small cadence bonus.
assert(score("item:fast1h",17) > score("item:slow1h",17),
    "fast Fury offhand should edge slow offhand at identical DPS")
assert(score("item:fast1h",17) - score("item:slow1h",17) < 0.04 * 20 * 4.5,
    "offhand speed bias must remain bounded")

-- Arms using a 1H: no speed preference without an actual modeled rotation.
ForeverUpgradeDB.spec="arms"
approximately(score("item:fast1h",16), score("item:slow1h",16))
-- Missing tooltip speed means neutral, not a guessed speed.
assert(FU:GetWeaponSpeed("item:unknown") == nil)
approximately(score("item:unknown",16), 20*8 + 4)
print("ForeverUpgrade speed-model tests passed")
