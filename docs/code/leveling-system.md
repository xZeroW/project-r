---
status: confirmed
---

# Base leveling

## Current implementation

- Players begin each encounter at **Base Level 1, 0 / 9 EXP**.
- The baseline is **classic/pre-Renewal RO's normal, non-transcendent Base EXP table**, levels 1–99, at 1× rewards. `ExperienceCurve` contains the complete 98 next-level requirements as an Inspector-editable resource. The total to level 99 is 405,234,427 EXP.
- Each Poring awards **2 Base EXP** to the source of its lethal hit. Five Porings reach level 2 with 1 / 16 EXP carried over.
- `MeleeCombat.defeated_enemy` reports a credited kill. The player orchestrator forwards the victim's `base_experience_reward` to its `Experience` component. Unattributed deaths, nonlethal/rejected hits, and corpse hits award nothing. Respawned monsters can award EXP again once killed.
- `Experience` owns session-local integer level/EXP, carries excess EXP across levels, supports multiple levels in one award, and discards excess at level 99. Nonpositive awards are ignored. Shared curve data is read-only at runtime; each player owns independent progress.
- The bottom-left click-through HUD shows Base Level, an EXP bar, current/required EXP, brief gain notices, and level-up notices. At level 99 it shows a full bar and MAX LEVEL. Updates are signal-driven.
- Each Base level grants **5 stat points** (`StatusPoints`), spent through the C-toggled status window; see [Status point allocation](status-points.md).
- **R restarts the entire encounter, including level/EXP**. Relaunching also starts fresh.

## Scope and baseline choices

This pass implements Base leveling and stat-point awards. RO's separate Job
EXP/class progression, automatic stat growth, party sharing, and save
persistence are not implemented. Combat stats are derived from spent stat points
via `StatusPoints`; these are future design decisions rather than implied RO rules.

Leveling up restores the player to full health and full mana. Dying charges a 5%
Base EXP penalty from the current level's requirement without de-leveling; see
[Player death and respawn](player-respawn.md).

Classic versus Renewal was unspecified in the request; classic normal progression is the prototype default. The Poring reference also lists 1 Job EXP, which is not awarded because there is no Job progression yet.

## Sources

- [iRO Wiki Classic — Base EXP Chart](https://irowiki.org/classic/Base_EXP_Chart), **Normal** table, accessed 2026-09-14.
- [RateMyServer — Poring, pre-Renewal, monster 1002](https://ratemyserver.net/index.php?page=mob_db&mob_id=1002), 1× Base EXP **2**, accessed 2026-09-14.

## Verification

`godot --headless --path . --script res://tests/experience_test.gd` checks thresholds, full-table total, multi-level overflow, the cap, large/invalid awards, real combat kill attribution, duplicate prevention, respawn rewards, independent player instances, and HUD updates/layout/click-through.

## Decision history

| Date | Status | Decision | Source |
| --- | --- | --- | --- |
| 2026-09-15 | Confirmed | Stat-point allocation is implemented and each level grants +5 points. | Owner's status-points request. |
| 2026-09-15 | Confirmed | Leveling up restores the player to full health and mana. | Owner's level-up restore request. |
| 2026-09-14 | Confirmed | Add leveling based on Ragnarok EXP requirements and Poring rewards. | Owner's request. |
| 2026-09-14 | Proposed | Use classic normal Base Level 1–99 and 2 EXP per Poring at 1×; defer Job progression and stat benefits. | Implementation baseline; RO version and class rules unspecified. |
| 2026-09-14 | Proposed | Preserve overflow, credit lethal hits, and reset progression with encounter reload. | Prototype defaults consistent with current combat/session lifecycle. |
