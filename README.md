# Forever Upgrade v0.2.5

Warrior-first item upgrade scoring for **World of Warcraft: Forever**.

## What it does

- Automatically detects the Warrior tree with the most points (Arms / Fury / Protection), or lets you force a profile. Reads Classic-style invested talent points first instead of mistaking Retail specialization metadata for points; falls back conservatively when the live client hides that data.
- Uses separate **Leveling** and **Endgame** weight sets. Auto mode switches to Endgame at level 60.
- Adds an **estimated upgrade/downgrade percentage** to item tooltips.
- Adds green arrows and optional percentages to upgrades in Blizzard's bags and in **the ordinary corpse/chest loot window**, before you pick an item up.
- Marks the **best gear upgrade among quest reward choices**.
- Also labels **Need/Greed group-loot rolls**; these use a separate UI from ordinary corpse/chest loot.
- Correctly treats rings/trinkets as two-slot items, Fury one-handers as possible main/off-hand upgrades once Dual Wield is available, and two-handers as replacing both hands.
- Supports editable weights and Pawn-style import/export.
- Reports the source of the active weights with `/fu source`.

## Weight model

### Levels 1-59

Leveling profiles are deliberately practical estimates. They use WoW: Forever mechanics plus Warrior leveling priorities rather than pretending a level-60 raid sim is mathematically correct for a level-27 character.

### Level 60

Arms and Fury offensive secondary-stat values are now based on **MythicSim WoW: Forever EP measurements** where the simulator directly publishes a usable value.

Current v0.2.0 snapshots:

- **Arms 39/10/2** — MythicSim engine `a667dce84`, client `1.60.1.70425`, 10,000 iterations. Published EP: Crit 1.19, Haste 1.03, Strength 1.00, Expertise 0.98, Agility 0.91, Attack Power 0.45, Armor Penetration 0.21.
- **Fury 18/31/2** — MythicSim engine `a667dce84`, client `1.60.1.70707`, 10,000 iterations. Published EP: Crit 1.28, Strength 1.00, Agility 0.94, Haste 0.92, Hit 0.88, Expertise 0.80, Attack Power 0.45, Armor Penetration 0.20.
- **Protection 0/20/31** — MythicSim threat EP is used for offensive/threat stats; survival stats still use conservative heuristics until Forever Upgrade gains separate Threat and Survival scores.

Two important exceptions are intentionally not disguised as sim data:

- MythicSim's published Arms and Protection reference builds are already Hit-capped, so their published Hit value is zero for those exact reference characters. Forever Upgrade therefore keeps a clearly documented **pre-cap fallback** instead of declaring Hit worthless for every Warrior.
- MythicSim's public EP tables do not publish a generic weapon-DPS EP value, so weapon DPS remains a practical fallback weight for now.

Use `/fu source` or `/fu weights` in-game to see exactly which source/profile is active.

## Install

### Recommended: WowUp

Install this repository through **WowUp → Get Addons → Install from URL** using:

`https://github.com/avp9320/ForeverUpgrade`

Future tagged releases can then be picked up by WowUp automatically.

### Manual

1. Download the latest release ZIP.
2. Extract the `ForeverUpgrade` folder into your WoW: Forever AddOns directory.
3. The final path should contain `ForeverUpgrade_Camelot.toc` and the Lua files directly inside the `ForeverUpgrade` folder.
4. Launch/reload WoW: Forever and enable **Forever Upgrade** in the AddOns list.

Forever currently reports Interface `16001`; both standard and `_Camelot.toc` manifests are included for compatibility.

## Commands

- `/fu status`
- `/fu source`
- `/fu spec auto|arms|fury|prot`
- `/fu mode auto|leveling|endgame`
- `/fu threshold 1`
- `/fu tooltips on|off`
- `/fu arrows on|off`
- `/fu quest on|off`
- `/fu percent on|off`
- `/fu details on|off`
- `/fu weights`
- `/fu set STR 1.1`
- `/fu reset`
- `/fu export`
- `/fu import <Pawn-style scale>`

## Loot-window upgrade arrows

The ordinary Forever loot panel uses Blizzard's `LootFrame.ScrollBox`. v0.2.4 adds a small green arrow on the item icon and, when enabled, a percentage at the bottom-right of an upgrade's row. Loot-window arrows use the same estimated score and `/fu arrows on|off` setting as bag arrows. This **does not** auto-loot or alter click actions. The separate group-loot (Need/Greed) indicator is unchanged.

## Important limitations

- **Weapon speed is not scored yet.** A slow weapon can have extra Arms value at equal DPS.
- **Proc/on-use effects and set bonuses are not fully simulated in-game.** They may be partially invisible to `C_Item.GetItemStats`.
- **Stat caps are not fully dynamic yet.** Hit/Expertise are still represented by profile weights rather than character-specific marginal EP at every breakpoint.
- Protection tooltips now show **separate estimated Threat and Survival deltas** alongside the legacy hybrid upgrade recommendation. The split uses existing threat EP and survival heuristic weights, not a validated survival simulator; arrows still use the hybrid score.
- Bag arrows are written for Blizzard's modern Forever bag UI. Third-party bag addons are not supported yet.
- The quest-arrow code marks only the best *choosable* gear reward. Mandatory rewards still get tooltip comparisons.
- Forever launches on 2026-11-04 and the client/API can still change.

## Next targets

- Dynamic Hit/Expertise cap handling.
- Weapon-speed modeling for Arms.
- Character-specific MythicSim weight import.
- Validate Protection Threat/Survival estimates in the live client and choose an explicit priority for upgrade arrows.
- Better proc/set-bonus handling.
- Third-party bag addon support.
