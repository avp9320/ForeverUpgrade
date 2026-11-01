# Forever Upgrade v0.1.1

Warrior-first item upgrade scoring for **World of Warcraft: Forever**.

## What v0.1 does

- Automatically detects the Warrior tree with the most points (Arms / Fury / Protection), or lets you force a profile.
- Uses separate **Leveling** and **Endgame** weight sets. Auto mode switches to Endgame at level 60.
- Adds an **estimated upgrade/downgrade percentage** to item tooltips.
- Adds green arrows and optional percentages to upgrades in Blizzard's bags.
- Marks the **best gear upgrade among quest reward choices**.
- Correctly treats rings/trinkets as two-slot items, Fury one-handers as possible main/off-hand upgrades once Dual Wield is available, and two-handers as replacing both hands.
- Supports editable weights and Pawn-style import/export.
- Labels results as **estimated**. Static weights cannot model every proc, set bonus, cap, or rotation interaction.

## Install

### Recommended: WowUp

Once a GitHub release exists, install this repository through **WowUp → Get Addons → Install from URL** using:

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

## Important v0.1 limitations

- **Weapon speed is not scored yet.** Weapon DPS is strongly weighted, but a slow weapon can have extra value for some Arms abilities even at equal DPS.
- **Proc/on-use effects and set bonuses are not simulated.** They may be partially invisible to `C_Item.GetItemStats`.
- **Stat caps are linear.** The addon does not yet reduce Hit/Expertise value when you reach a cap.
- Bag arrows are written for Blizzard's modern Forever bag UI. Third-party bag addons are not supported yet.
- The quest-arrow code marks only the best *choosable* gear reward. Mandatory rewards still get tooltip comparisons.
- Forever launches on 2026-11-04 and the client/API can still change. If a launch build changes the Interface number, the TOCs will need updating.

## Weight model

The Endgame Warrior starting points use currently documented Forever mechanics and the same basic scale as independently derived Forever Warrior profiles:

- Warrior Strength: 2 AP per point; AP weight = 0.5, so Strength starts near 1.0 for DPS specs.
- 14 AP is approximately 1 weapon DPS, so weapon DPS receives a large weight.
- Rating stats are stored internally **per rating point**, because `C_Item.GetItemStats` returns rating values rather than displayed percentages.
- Protection centers Stamina, Defense, avoidance, Armor, Block, and threat stats.

Leveling mode deliberately values Stamina/Spirit a little more and raid-oriented secondary ratings a little less. These are practical starting weights, not simulations.

## Next targets

- Dynamic Hit/Expertise cap handling.
- Weapon-speed modeling for Arms.
- Optional external sim import profile generated from a character export.
- Better proc/set-bonus handling.
- Third-party bag addon support.
- A proper in-game settings panel once the core math has been tested on launch.
