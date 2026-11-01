local ADDON_NAME, FU = ...

FU = FU or {}
_G.ForeverUpgrade = FU

FU.VERSION = "0.1.1"

-- Internal stat names are deliberately Pawn-like. Rating stats are weighted per
-- ONE POINT OF RATING because C_Item.GetItemStats returns the raw rating value.
-- Forever's currently documented conversion seeds are:
--   10 hit = 1%, 14 crit = 1%, 10 haste = 1%, 10 expertise = 1%,
--   12 dodge = 1%, 15 parry = 1%, 5 block = 1%.
--
-- Endgame baselines are adapted from publicly documented Forever mechanics and
-- the independently derived Forever++ Warrior profiles. Leveling profiles keep
-- weapon damage primary, slightly value survivability/downtime more, and reduce
-- the value of raid-oriented secondary ratings.

FU.PROFILES = {
    arms = {
        label = "Arms",
        leveling = {
            STR = 1.00, AGI = 0.57, STA = 0.40, SPI = 0.35,
            AP = 0.50, HIT = 0.75, CRIT = 0.60, HASTE = 0.45, EXPERTISE = 0.60,
            ARMOR = 0.01, DPS = 8.00, DPS_OFF = 0.00, DPS_RANGED = 0.10,
            DEF = 0.00, DODGE = 0.00, PARRY = 0.00, BLOCK = 0.00, BLOCKVALUE = 0.00,
        },
        endgame = {
            STR = 1.00, AGI = 0.57, STA = 0.30, SPI = 0.00,
            AP = 0.50, HIT = 1.00, CRIT = 11 / 14, HASTE = 0.70, EXPERTISE = 0.80,
            ARMOR = 0.01, DPS = 8.00, DPS_OFF = 0.00, DPS_RANGED = 0.10,
            DEF = 0.00, DODGE = 0.00, PARRY = 0.00, BLOCK = 0.00, BLOCKVALUE = 0.00,
        },
    },
    fury = {
        label = "Fury",
        leveling = {
            STR = 1.00, AGI = 0.52, STA = 0.40, SPI = 0.35,
            AP = 0.50, HIT = 0.85, CRIT = 0.55, HASTE = 0.45, EXPERTISE = 0.60,
            ARMOR = 0.01, DPS = 7.00, DPS_OFF = 4.50, DPS_RANGED = 0.10,
            DEF = 0.00, DODGE = 0.00, PARRY = 0.00, BLOCK = 0.00, BLOCKVALUE = 0.00,
        },
        endgame = {
            STR = 1.00, AGI = 0.52, STA = 0.30, SPI = 0.00,
            AP = 0.50, HIT = 1.10, CRIT = 10 / 14, HASTE = 0.70, EXPERTISE = 0.80,
            ARMOR = 0.01, DPS = 7.00, DPS_OFF = 4.50, DPS_RANGED = 0.10,
            DEF = 0.00, DODGE = 0.00, PARRY = 0.00, BLOCK = 0.00, BLOCKVALUE = 0.00,
        },
    },
    prot = {
        label = "Protection",
        leveling = {
            STR = 0.60, AGI = 0.65, STA = 1.00, SPI = 0.20,
            AP = 0.25, HIT = 0.45, CRIT = 0.18, HASTE = 0.15, EXPERTISE = 0.30,
            ARMOR = 0.05, DPS = 2.25, DPS_OFF = 0.00, DPS_RANGED = 0.05,
            DEF = 1.50, DODGE = 8 / 12, PARRY = 7 / 15, BLOCK = 3 / 5, BLOCKVALUE = 0.30,
        },
        endgame = {
            STR = 0.52, AGI = 0.63, STA = 1.00, SPI = 0.00,
            AP = 0.25, HIT = 0.60, CRIT = 3 / 14, HASTE = 0.00, EXPERTISE = 0.40,
            ARMOR = 0.04, DPS = 2.00, DPS_OFF = 0.00, DPS_RANGED = 0.05,
            DEF = 1.50, DODGE = 8 / 12, PARRY = 7 / 15, BLOCK = 3 / 5, BLOCKVALUE = 0.30,
        },
    },
}

FU.STAT_ORDER = {
    "STR", "AGI", "STA", "SPI", "AP", "HIT", "CRIT", "HASTE", "EXPERTISE",
    "ARMOR", "DEF", "DODGE", "PARRY", "BLOCK", "BLOCKVALUE", "DPS", "DPS_OFF", "DPS_RANGED",
}

FU.PAWN_TO_INTERNAL = {
    Strength = "STR", Str = "STR",
    Agility = "AGI", Agi = "AGI",
    Stamina = "STA", Sta = "STA",
    Spirit = "SPI", Spi = "SPI",
    Ap = "AP", AttackPower = "AP",
    HitRating = "HIT", Hit = "HIT",
    CritRating = "CRIT", Crit = "CRIT",
    HasteRating = "HASTE", Haste = "HASTE",
    ExpertiseRating = "EXPERTISE", Expertise = "EXPERTISE",
    Armor = "ARMOR",
    DefenseRating = "DEF", Defense = "DEF",
    DodgeRating = "DODGE", Dodge = "DODGE",
    ParryRating = "PARRY", Parry = "PARRY",
    BlockRating = "BLOCK", Block = "BLOCK",
    BlockValue = "BLOCKVALUE",
    Dps = "DPS", MainHandDps = "DPS",
    OffHandDps = "DPS_OFF", DpsOff = "DPS_OFF",
    RangedDps = "DPS_RANGED",
}

FU.INTERNAL_TO_PAWN = {
    STR = "Strength", AGI = "Agility", STA = "Stamina", SPI = "Spirit",
    AP = "Ap", HIT = "HitRating", CRIT = "CritRating", HASTE = "HasteRating",
    EXPERTISE = "ExpertiseRating", ARMOR = "Armor", DEF = "DefenseRating",
    DODGE = "DodgeRating", PARRY = "ParryRating", BLOCK = "BlockRating",
    BLOCKVALUE = "BlockValue", DPS = "Dps", DPS_OFF = "OffHandDps", DPS_RANGED = "RangedDps",
}

FU.ITEM_STAT_KEYS = {
    ITEM_MOD_STRENGTH_SHORT = "STR",
    ITEM_MOD_AGILITY_SHORT = "AGI",
    ITEM_MOD_STAMINA_SHORT = "STA",
    ITEM_MOD_SPIRIT_SHORT = "SPI",
    ITEM_MOD_ATTACK_POWER_SHORT = "AP",
    ITEM_MOD_HIT_RATING_SHORT = "HIT",
    ITEM_MOD_CRIT_RATING_SHORT = "CRIT",
    ITEM_MOD_HASTE_RATING_SHORT = "HASTE",
    ITEM_MOD_EXPERTISE_RATING_SHORT = "EXPERTISE",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEF",
    ITEM_MOD_DODGE_RATING_SHORT = "DODGE",
    ITEM_MOD_PARRY_RATING_SHORT = "PARRY",
    ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK",
    ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVALUE",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS",
    ITEM_MOD_ARMOR_SHORT = "ARMOR",
    RESISTANCE0_NAME = "ARMOR",
}
