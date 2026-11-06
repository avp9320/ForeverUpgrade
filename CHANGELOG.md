# Changelog

## 0.2.7 - 2026-11-05
- Do not flag higher-required-level items as current upgrades.
- Warrior-first policy skips cloth/leather for primary armor slots; mail and plate remain eligible, with plate requiring level 40.
- Keep missing equipped-item stat data unscorable instead of treating worn gear as zero-score/empty.
- Show STRONG instead of absurd multi-hundred-percent ratios in bags, quests, loot windows and rolls; clarify the percent is item-score based, not actual DPS.


## 0.2.4 - 2026-11-04
- Add upgrade arrows and optional estimated percentages to the **regular corpse/chest loot window**, not just bags and Need/Greed roll popups.
- Hook Forever's modern `LootFrame.ScrollBox` initialized/recycled rows and query each item with `GetLootSlotLink`.
- Clear markers as loot slots change/close; retry uncached items when item data loads.
- Reuse the existing bag-arrow toggle, threshold, and scoring; no auto-loot or altered click behavior.
- Centralize the addon runtime version in `Profiles.lua` instead of overwriting it in the loot-roll module.


## 0.2.2 - 2026-11-01
- Added compact group-loot upgrade verdicts directly to Blizzard's existing loot-roll popup.
- Verdicts are BIG UPGRADE, UPGRADE, SIDEGRADE, DOWNGRADE, or NOT FOR YOU.
- Uses the same ForeverUpgrade scoring/profile logic as bags, tooltips, quest rewards, and ForeverDungeon.
- Does not auto-roll Need/Greed/Pass; the addon only gives the recommendation and leaves the click to the player.
- Added item-cache retries so a loot popup can be scored after item data finishes loading.

## 0.2.0 - 2026-11-01
- Replaced the old hand-tuned **level-60 Arms and Fury secondary-stat baselines** with MythicSim WoW: Forever EP values where the simulator directly measures the stat.
- Arms endgame now uses MythicSim's 39/10/2 reference EP values for Crit, Haste, Strength, Expertise, Agility, Attack Power, and Armor Penetration.
- Fury endgame now uses MythicSim's 18/31/2 reference EP values for Crit, Strength, Agility, Haste, Hit, Expertise, Attack Power, and Armor Penetration.
- Protection offensive/threat stats now use MythicSim's Protection threat EP values while existing survival weights remain conservative heuristics; a future release will split Threat and Survival into separate scores.
- Added Armor Penetration support to the internal stat model/Pawn imports.
- Added source metadata and `/fu source`; `/fu status` and `/fu weights` now report the active weight source.
- Leveling profiles remain clearly labeled estimates based on Forever mechanics and leveling priorities rather than raid sims.
- Arms/Protection Hit and weapon-DPS values remain explicit fallbacks where the published reference sim cannot provide a directly usable generic value.

## 0.1.1
- Retry bag, quest, and tooltip hooks when Blizzard creates UI frames after login.
- Added quest/talent events to refresh comparisons more reliably.

## 0.1.0 - 2026-11-01
- Initial Warrior-first release.
- Arms, Fury, Protection leveling/endgame profiles.
- Tooltip estimated upgrade percentages.
- Blizzard bag upgrade arrows.
- Best quest-choice upgrade marker.
- Two-slot, dual-wield, and two-hander comparison handling.
- Pawn-style weight import/export and manual overrides.
