---
status: confirmed
---

# Code — Status point allocation

## Confirmed — Component set

`scripts/components/status_points.gd` (`StatusPoints`, a `Node`) owns the six
classic Ragnarok base stats — STR, AGI, VIT, INT, DEX, LUK — each starting at 1,
plus an unspent pool. `scripts/components/status_ui.gd` (`StatusUI`, a
`CanvasLayer`) renders a toggleable allocation panel. Both are composed into
`scenes/player.tscn`; `scripts/player.gd` wires levels to points, so composition
mirrors the existing `Experience` / `ExperienceUI` split.

- Each player spawns with **5 unspent points**.
- `StatusPoints.allocate(stat)` spends one point, denies the claim at 0 points,
  and pushes recomputed derived values into the shared `CharacterStats`.
- On `Experience.leveled_up` the player grants **+5 points** (RO classic),
  connected in `player.gd` in addition to the existing HP/mana restore.
- Allocation is session-local: encounter restart (`R`) or relaunch resets it.
  Monsters keep flat stats and never run `StatusPoints`.

## Confirmed — Derived stat mapping (proposed defaults)

`StatusPoints.recompute()` derives combat values into the player's shared
`CharacterStats` from the base stats. Values below are the current prototype
defaults.

| Base stat | Derived | Formula |
| --- | --- | --- |
| STR | attack damage | `20 + 2·STR` |
| AGI | attack speed | `1.0 + 0.03·AGI` (data-only) |
| AGI | evasion | `2·AGI` (data-only) |
| VIT | max health | `100 + 10·VIT` |
| INT | max mana | `100 + 5·INT` |
| DEX | — | kept, data-only until hit/crit exist |
| LUK | — | kept, data-only until hit/crit exist |

With all base stats at 1 a fresh player has 110 max/current health, 105
max/current mana, 22 attack damage, 1.03 attack speed, and 2 evasion.

## Confirmed — Health accounting on max growth

Raising a maximum raises the corresponding current value by the same delta, so
spending VIT heals current health and spending INT heals mana (RO behavior);
current values clamp to the new maximum. Leveling up already restores the player
to full health and mana (`player.gd`), independent of this delta.

## Confirmed — StatusUI

- Panel is hidden on spawn; the `toggle_status` action (proposed **C** key)
  toggles it. The action is registered in `project.godot`.
- Lists every stat, its current value, and a **+** button; buttons disable at 0
  remaining points. Updates are signal-driven from `StatusPoints`
  (`allocated`, `points_remaining_changed`).
- The panel background uses `MOUSE_FILTER_STOP` so clicks on the panel do not
  leak into click-to-move/combat; buttons consume clicks via normal GUI
  handling. Clicks outside the panel keep working while it is open.

## Verification

`godot --headless --path . --script res://tests/status_points_test.gd` covers
base stats/points, derived mapping, VIT/INT health deltas, over-spend denial,
level-up +5 grants, panel toggle, plus-button spending, zero-point disabling,
panel click blocking, and per-instance independence.

## Decision history

| Date | Status | Decision | Source |
| --- | --- | --- | --- |
| 2026-09-15 | Confirmed | Stat allocation is a composition of `StatusPoints` + `StatusUI`, mirroring Experience. | Project owner's brief. |
| 2026-09-15 | Proposed | Base starts at 1 with 5 points; +5 per Base level; derived mapping table above. | RO classic defaults; owner's brief. |
| 2026-09-15 | Proposed | Status window toggled on C; session-local allocation that resets on restart. | Owner's brief; prototype lifecycle. |