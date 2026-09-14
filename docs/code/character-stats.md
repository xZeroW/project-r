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
| Maximum health | 100 | 100 |
| Health | 100 | 100 |
| Mana | 100 | 100 |
| Movement speed | 4.0 | 2.5 |
| Attack speed | 1.0 | 1.0 |
| Attack damage | 20 | 10 |
| Armour | 0 | 0 |
| Evasion | 0 | 0 |
| Block | 0 | 0 |

Player and monster movement read `movement_speed` from their assigned stats.
Combat reads `attack_damage`, `attack_speed`, and flat `armour`, and reduces
`current_health`. Health UI displays `current_health / max_health`.
Mana, evasion, and block remain data-only. See [Combat prototype](combat-prototype.md).

## Decision history

| Date | Status | Decision | Source |
| --- | --- | --- | --- |
| 2026-09-13 | Confirmed | Player and monster share the same initial stat set through per-instance resources. | Project owner's brief. |
