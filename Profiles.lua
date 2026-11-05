local ADDON_NAME, FU = ...

FU = FU or {}
_G.ForeverUpgrade = FU

FU.VERSION = "0.2.6"

-- Internal stat names are Pawn-like. Rating stats are weighted per ONE POINT OF
-- RATING because C_Item.GetItemStats returns raw rating values.
--
-- LEVELING (1-59): practical estimates based on WoW: Forever mechanics and
-- Icy Veins' Warrior leveling priorities. These are intentionally not presented
-- as simulation-derived values.
--
-- ENDGAME (60): offensive weights use MythicSim WoW: Forever EP values where
-- the simulator actually measured that stat. MythicSim EP is normalized to
-- Strength = 1 on the reference build.
--
-- Important exceptions:
--   * Arms/Protection reference builds are already Hit-capped, so their simmed
--     Hit EP is exactly 0 for those reference characters. HIT below is therefore
--     a pre-cap fallback, not a MythicSim measurement.
--   * Weapon DPS is not included in MythicSim's published EP table. DPS weights
--     remain practical weapon-value fallbacks until we can import character-
--     specific sim output that includes weapon deltas.
--   * Protection is still one hybrid score in v0.2.0. Threat-oriented offensive
--     stats use MythicSim threat EP; survival stats remain conservative tank
--     heuristics. A future release should split Survival and Threat scores.
--
-- MythicSim source snapshots used for v0.2.0:
--   Arms 39/10/2: engine a667dce84, client 1.60.1.70425, 10,000 iterations.
--   Fury 18/31/2: engine a667dce84, client 1.60.1.70707, 10,000 iterations.
--   Prot 0/20/31: engine a667dce84, client 1.60.1.70425, 10,000 iterations.

FU.WEIGHT_SOURCES = {
    arms = {
        leveling = "Icy Veins leveling priority + Forever mechanics (estimated)",
        endgame = "MythicSim Arms 39/10/2 EP; engine a667dce84; client 1.60.1.70425; 10k iterations",
    },
    fury = {
        leveling = "Icy Veins leveling priority + Forever mechanics (estimated)",
        endgame = "MythicSim Fury 18/31/2 EP; engine a667dce84; client 1.60.1.70707; 10k iterations",
    },
    prot = {
        leveling = "Forever tank leveling heuristics (estimated)",
        endgame = "MythicSim Prot 0/20/31 threat EP + survival heuristics; engine a667dce84; 10k iterations",
    },
}

FU.PROFILES = {
    arms = {
        label = "Arms",
        leveling = {
            STR = 1.00, AGI = 0.57, STA = 0.40, SPI = 0.35,
            AP = 0.50, HIT = 0.75, CRIT = 0.60, HASTE = 0.45, EXPERTISE = 0.60, ARP = 0.10,
            ARMOR = 0.01, DPS = 8.00, DPS_OFF = 0.00, DPS_RANGED = 0.10,
            DEF = 0.00, DODGE = 0.00, PARRY = 0.00, BLOCK = 0.00, BLOCKVALUE = 0.00,
        },
        endgame = {
            -- MythicSim measured: Crit 1.19, Haste 1.03, Str 1.00,
            -- Expertise 0.98, Agi 0.91, AP 0.45, Armor Pen 0.21.
            -- Hit is a below-cap fallback because the reference build is at cap.
            STR = 1.00, AGI = 0.91, STA = 0.20, SPI = 0.00,
            AP = 0.45, HIT = 1.20, CRIT = 1.19, HASTE = 1.03, EXPERTISE = 0.98, ARP = 0.21,
            ARMOR = 0.00, DPS = 8.00, DPS_OFF = 0.00, DPS_RANGED = 0.05,
            DEF = 0.00, DODGE = 0.00, PARRY = 0.00, BLOCK = 0.00, BLOCKVALUE = 0.00,
        },
    },
    fury = {
        label = "Fury",
        leveling = {
            STR = 1.00, AGI = 0.52, STA = 0.40, SPI = 0.35,
            AP = 0.50, HIT = 0.85, CRIT = 0.55, HASTE = 0.45, EXPERTISE = 0.60, ARP = 0.10,
            ARMOR = 0.01, DPS = 7.00, DPS_OFF = 4.50, DPS_RANGED = 0.10,
            DEF = 0.00, DODGE = 0.00, PARRY = 0.00, BLOCK = 0.00, BLOCKVALUE = 0.00,
        },
        endgame = {
            -- MythicSim measured: Crit 1.28, Str 1.00, Agi 0.94, Haste 0.92,
            -- Hit 0.88, Expertise 0.80, AP 0.45, Armor Pen 0.20.
            STR = 1.00, AGI = 0.94, STA = 0.20, SPI = 0.00,
            AP = 0.45, HIT = 0.88, CRIT = 1.28, HASTE = 0.92, EXPERTISE = 0.80, ARP = 0.20,
            ARMOR = 0.00, DPS = 7.00, DPS_OFF = 4.50, DPS_RANGED = 0.05,
            DEF = 0.00, DODGE = 0.00, PARRY = 0.00, BLOCK = 0.00, BLOCKVALUE = 0.00,
        },
    },
    prot = {
        label = "Protection",
        leveling = {
            STR = 0.60, AGI = 0.65, STA = 1.00, SPI = 0.20,
            AP = 0.25, HIT = 0.45, CRIT = 0.18, HASTE = 0.15, EXPERTISE = 0.30, ARP = 0.05,
            ARMOR = 0.05, DPS = 2.25, DPS_OFF = 0.00, DPS_RANGED = 0.05,
            DEF = 1.50, DODGE = 8 / 12, PARRY = 7 / 15, BLOCK = 3 / 5, BLOCKVALUE = 0.30,
        },
        endgame = {
            -- Offensive/threat values use MythicSim's Protection threat EP where
            -- measured: Expertise 4.17, Str 1.00, Crit 0.84, Haste 0.56,
            -- Agi 0.54, AP 0.45, Block Value 0.28, Armor Pen 0.20.
            -- Survival values remain heuristics until we expose a separate score.
            STR = 1.00, AGI = 0.54, STA = 1.00, SPI = 0.00,
            AP = 0.45, HIT = 0.75, CRIT = 0.84, HASTE = 0.56, EXPERTISE = 4.17, ARP = 0.20,
            ARMOR = 0.04, DPS = 2.00, DPS_OFF = 0.00, DPS_RANGED = 0.05,
            DEF = 1.50, DODGE = 8 / 12, PARRY = 7 / 15, BLOCK = 0.60, BLOCKVALUE = 0.28,
        },
    },
}

FU.STAT_ORDER = {
    "STR", "AGI", "STA", "SPI", "AP", "HIT", "CRIT", "HASTE", "EXPERTISE", "ARP",
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
    ArmorPenetration = "ARP", ArmorPenetrationRating = "ARP", ArP = "ARP",
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
    EXPERTISE = "ExpertiseRating", ARP = "ArmorPenetrationRating", ARMOR = "Armor", DEF = "DefenseRating",
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
    ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "ARP",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEF",
    ITEM_MOD_DODGE_RATING_SHORT = "DODGE",
    ITEM_MOD_PARRY_RATING_SHORT = "PARRY",
    ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK",
    ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVALUE",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS",
    ITEM_MOD_ARMOR_SHORT = "ARMOR",
    RESISTANCE0_NAME = "ARMOR",
}
