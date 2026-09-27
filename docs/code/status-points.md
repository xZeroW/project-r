---
status: confirmed
---

# Code — Status point allocation

## Confirmed — Component set

`scripts/components/status_points.gd` (`StatusPoints`, a `Node`) owns the six
classic Ragnarok base stats — STR, AGI, VIT, INT, DEX, LUK — each starting at 0,
plus an unspent pool. `scripts/components/attribute_ui.gd` (`AttributeUI`, a
`CanvasLayer`) renders a toggleable allocation panel. Both are composed into
`scenes/player.tscn`; `scripts/player.gd` wires levels to points, so composition
mirrors the existing `Experience` / `ExperienceUI` split.

- Each player spawns with **0 unspent points**.
- `StatusPoints.allocate(stat)` spends one point, denies the claim at 0 points,
  and pushes recomputed derived values into the shared `CharacterStats`.
- On `Experience.leveled_up` the player grants **+5 points** (prototype rule),
  connected in `player.gd` in addition to the existing HP/mana restore. A fresh
  character stays at 0 points until the first level-up.
- Allocation is session-local: encounter restart (`R`) or relaunch resets it.
  Monsters keep flat stats and never run `StatusPoints`.

## Confirmed — Derived stat mapping (proposed defaults)

`StatusPoints.recompute()` derives combat values into the player's shared
`CharacterStats` from the base stats. Values below are the current prototype
defaults.

| Base stat | Derived | Formula |
| --- | --- | --- |
| STR | physical attack damage | `20 + STR + (floor(STR / 7)² + floor(STR / 5)²) / 2` — same attribute contribution as INT, plus prototype base damage |
| AGI | attack speed | Eternal-Love hits/sec curve: `1.0 × panel(AGI) / panel(0)` where `panel(agi) = 50 / (200 − stat_aspd)` and `stat_aspd(agi) = 156 − (√205 − √AGI)/7.15 + √(9.9999·AGI)·0.76`. Square-root returns: 1.0 at 0 AGI, ≈1.21 at 10, ≈2.22 at 99 — the gain per point diminishes as AGI grows. |
| AGI | evasion | `1·AGI` points contested 1-for-1 against the attacker's accuracy in the RO hit roll |
| VIT | max health | `100 + 10·VIT` |
| INT | max mana | `100 + 5·INT` |
| INT | magic attack | `INT + (floor(INT / 7)² + floor(INT / 5)²) / 2`, the deterministic midpoint of classic RO's base MATK range |
| DEX | accuracy | `1·DEX` points contested 1-for-1 against evasion; `hit% = clamp(95 + acc − evasion, 5%, 95%)` |
| LUK | crit chance | `0.3·LUK` percent chance on a landed hit for 150% damage |

With all base stats at 0 a fresh player has 100 max/current health, 100
max/current mana, 20 attack damage, 1.0 attack speed, 0 accuracy, 0 crit, and 0
evasion. Accuracy and evasion resolve together through a single RO-contested
combat roll (`hit% = clamp(95 + acc − evasion, 5%, 95%)`); crit rolls on landed
hits; see [Combat prototype](combat-prototype.md). `block` stays at 0 until
shields exist.

STR and INT use the same `attribute_attack_power(value)` function. STR adds the
result to the 20 base physical attack; INT supplies the result as MATK.
Examples: 0 STR → 20 ATK, 10 → 32.5, 20 → 50, 50 → 144.5, 99 → 397.5.
Equal attribute investment provides equal physical/magical contributions before
base attack, skill coefficients, and modifiers. This intentionally applies the
INT midpoint curve to STR rather than reproducing classic RO's physical formula.
It supersedes both the former +2/STR rule and the short-lived tens-threshold
curve; it is not a blanket damage reduction at high attributes.

MATK is 0 at zero INT, 30 at 20 INT, and 124.5 at 50 INT. Damaging spells add
MATK times their own `magic_attack_coefficient` (default 1.0) to base power,
then apply matching tag increases. Heal retains its separate tag-scaled power.
This is an RO-inspired deterministic adaptation, not a random MATK roll or a
full port of RO stat allocation costs. Recomputing replaces MATK rather than
accumulating it. `CharacterStats.magic_attack` emits `stat_changed` on writes.

## Confirmed — Health accounting on max growth

Raising a maximum raises the corresponding current value by the same delta, so
spending VIT heals current health and spending INT heals mana (RO behavior);
current values clamp to the new maximum. Leveling up already restores the player
to full health and mana (`player.gd`), independent of this delta.

## Confirmed — AttributeUI

- Panel is hidden on spawn; the `toggle_attributes` action (**P** key) toggles it. The action is registered in `project.godot`.
- Lists every stat, its current value, and a **+** button; buttons disable at 0
  remaining points. Updates are signal-driven from `StatusPoints`
  (`allocated`, `points_remaining_changed`).
- Derived combat values live on the separate **C** character equipment sheet;
  this panel is intentionally only for distributing base attributes.
- The panel background uses `MOUSE_FILTER_STOP` so clicks on the panel do not
  leak into click-to-move/combat; buttons consume clicks via normal GUI
  handling. Clicks outside the panel keep working while it is open.

## Verification

`godot --headless --path . --script res://tests/status_points_test.gd` covers
base stats/points, derived mapping, VIT/INT health deltas, over-spend denial,
level-up +5 grants, P-panel toggle, plus-button spending, zero-point disabling,
panel click blocking, and per-instance independence.

## Decision history

| Date | Status | Decision | Source |
| --- | --- | --- | --- |
| 2026-09-19 | Confirmed | STR uses the same midpoint curve as INT, contributing physical attack above the 20 base. Supersedes the STR-specific tens-threshold formula below. | Owner's request for STR to follow INT's logic but give physical damage. |
| 2026-09-19 | Confirmed | Replace flat +2 ATK/STR with `20 + STR + floor(STR / 10)²`, reducing early STR strength and adding classic RO-style tens thresholds. | Owner's STR balance request following the INT/MATK implementation. |
| 2026-09-19 | Confirmed | INT supplies base MATK before PoE-style tag bonuses. Prototype uses the midpoint of classic RO's INT MATK range; damaging skills have a tunable MATK coefficient and the status panel displays MATK. | Owner's approval of RO-style magic attack feeding tag-scaled spells; deterministic midpoint is the prototype implementation choice. |
| 2026-09-16 | Confirmed | Hit-roll base raised from 80 to 95: equal DEX/AGI investment now cancels 1-for-1 to the 95% base (`hit% = clamp(95 + acc − evasion, 5%, 95%)`). | Owner's accuracy-base request. |
| 2026-09-15 | Confirmed | Stat allocation is a composition of `StatusPoints` + `StatusUI`, mirroring Experience. | Project owner's brief. |
| 2026-09-16 | Confirmed | Fresh players spawn with all base stats at 0 and 0 unspent points (20 ATK / 1.0 ASPD / 0 acc / 100 HP); the first +5 grant arrives on level-up. | Owner's correction to the starting loadout. |
| 2026-09-15 | Confirmed | Status window toggled on the physical C key; allocation is session-local and resets on restart/`R`. | Owner's brief; prototype lifecycle. |
| 2026-09-27 | Confirmed | Base-attribute allocation moved to the separate `AttributeUI` on physical P. C remains the read-only equipment and derived-stat sheet. | Owner's character-sheet separation request. |
| 2026-09-16 | Confirmed | DEX drives accuracy (`1·DEX`, contested 1-for-1 with AGI evasion), LUK drives crit (`0.3·LUK` percent, ×1.5 on landed hits). Accuracy and evasion merged into RO's single contested roll. | Owner's AGI balance pass. |
| 2026-09-16 | Confirmed | Rebalanced AGI to RO-faithful scaling: attack speed `+0.004`/point (the `4·AGI/1000` delay reduction) and evasion `+1`/point; the old `0.03` ASPD and `2·AGI` evasion were deemed overpowered. | Owner's AGI balance pass. |
| 2026-09-16 | Confirmed | Attack speed ported to Ragnarok M: Eternal Love's square-root model (`panel = 50/(200 − stat_aspd)` with `stat_aspd = 156 − (√205 − √AGI)/7.15 + √(9.9999·AGI)·0.76`) — diminishing returns per AGI instead of classic RO's linear `4·AGI/1000`. Evasion stays `1·AGI`, which ET also uses (`1 AGI = +1 闪避`). | Owner's choice after Eternal-Love research. |
