# v1.0 acceptance checklist

This is a release gate, not a claim of implementation. README claims and static code inspection do not substitute for live-client evidence. Check a box only after its behavior is verified; record test date/client and evidence in this file.

- [ ] Verify Arms/Fury/Protection scoring, gear slots, loot window, quest rewards and group-roll overlays in live client
- [ ] Dynamic hit/expertise cap behavior and Arms weapon speed
- [ ] Separate Protection threat and survival scoring; clarify proc/set bonus limits
- [ ] Test changes in bags, loot, talent tree, equipment and combat protected data
- [ ] Verify release and backwards-compatible settings

## Evidence

- Code review: pending
- Automated/static tests: pending
- Live WoW: Forever client verification: pending
- Release ZIP and WoWUp installation: pending

## Status

Pre-1.0. Features described in README may be implemented but are not accepted as verified here until tested. Avoid declaring v1.0 solely on version metadata.

## Phase 1 implementation (2026-11-05)

- [x] Protection item tooltips now expose separate threat and survival weighted deltas (`Scoring.lua` `ProtectionComparison`, `UI.lua` tooltip hook; commits `66dc5df`, `d51951b`, `2b4cc3b`). Existing hybrid score and SavedVariables remain unchanged. Survival uses heuristic stats and threat uses existing weights; these are **not** separate simulation-derived EP scales.
- [ ] Choose and implement explicit Protection recommendation priority for bag/loot/quest arrows; currently hybrid score remains the selection policy.
- [ ] Execute Lua smoke tests and live-client tests for Protection, especially two-hand replacement with an empty main hand, tooltip refresh and unavailable item stats. No live test evidence yet.
