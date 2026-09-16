---
status: confirmed
---

# Code — Character Stats

## Confirmed — Shared Initial Stat Set

`scripts/character_stats.gd` defines the mutable, per-character stat resource used
by both the player and monster. Each scene owns a local resource instance so later
health or mana changes never leak to another character.

| Stat | Player | Monster |
| --- | ---: | ---: |
| Base level | 1 | 1 |
| Maximum health | 100 | 100 |
| Health | 100 | 100 |
| Mana | 100 | 100 |
| Movement speed | 4.0 | 2.5 |
| Attack speed | 1.0 | 1.0 |
| Attack damage | 20 | 10 |
| Armour | 0 | 0 |
| Evasion | 0 | 0 |
| Accuracy | 0 | 0 |
| Crit chance | 0 | 0 |
| Block | 0 | 0 |

Player values are the derived results of base stats at 0. `StatusPoints`
recomputes them into the shared stats whenever a stat point is spent. See
[Status point allocation](status-points.md).

Player and monster movement read `movement_speed` from their assigned stats.
Combat reads `attack_damage`, `attack_speed`, `acc`, `crit`, and flat `armour`,
reduces `current_health`, and resolves with a single RO-contested accuracy roll
(`hit% = clamp(80 + acc + level modifier − evasion, 5, 95)`); a failed roll is
`MISS` or `EVADED` (when evasion outscores accuracy), and a landed hit then
rolls block (halving damage) and attacker crit (×1.5). The status panel's
derived line shows the live `ATK / ASPD / Acc / Crit / Eva` values. The
player syncs `level` from `Experience`; monsters read it from their definition and
never gain EXP. Health UI displays `current_health / max_health`.
Mana (until spendable) remains data-only. See
[Combat prototype](combat-prototype.md).

Within one character, every component that reads a stat — root orchestrator,
`MeleeCombat`, `HealthBarUI` — references the same per-instance resource so death
detection, damage, and the displayed bar agree (the player scene shares a single
`PlayerStats` sub-resource; see [Player death and respawn](player-respawn.md)).

## Decision history

| Date | Status | Decision | Source |
| --- | --- | --- | --- |
| 2026-09-16 | Confirmed | `acc` and `crit` join the stat set; evasion, accuracy, and crit are now live combat rolls. Block stays 0 until shields. | Combat-math pass (Phase A). |
| 2026-09-16 | Confirmed | Accuracy default dropped from 90 to 0 and the resolver merged accuracy/evasion into one RO-contested roll; DEX and AGI now give 1 point each so they cancel 1-for-1. | Owner's AGI balance pass. |
| 2026-09-15 | Confirmed | Stat allocation recomputes player derived stats (attack damage, attack speed, evasion, max health/mana) into the shared stat resource. | Owner's status-points request. |
| 2026-09-15 | Confirmed | One stat resource instance is shared by all of a character's components so death, combat, and UI agree. | Bug found while implementing player death gating. |
| 2026-09-13 | Confirmed | Player and monster share the same initial stat set through per-instance resources. | Project owner's brief. |
