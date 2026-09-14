---
status: confirmed
---

# Combat prototype

## Current implementation

- **Left-click a monster** to select it, approach on the navmesh, and auto-attack until it dies. A gold UI label identifies the current target and health. Clicking another living monster switches targets.
- WASD or an accepted ground click cancels pursuit and auto-attacking. Death, a removed target, missing camera, unreachable path, or one second of blocked pursuit clears selection.
- `ClickMovement` uses its click-time camera ray in the next physics tick to distinguish monsters from ground. `Targeting` refreshes a pursuit path at most five times per second and calls the shared melee component only within range and clear line of sight. Cooldowns do not clear selection. Moving targets are followed again when they leave reach.

- Player melee range is 1.8 ground units. Attacks are initiated by clicking a monster; UI-consumed clicks do not select or attack.
- Player damage defaults to 20, with a `1 / attack_speed` second cooldown (one second initially).
- Poring damage defaults to 10. Its existing movement-locked windup lasts `attack_duration / attack_speed` (two seconds initially). Range (1.5 units), target life, and obstruction are checked again when it finishes; leaving range dodges the attack.
- Both entities compose `MeleeCombat`, sharing their own local `CharacterStats` resource with the UI. `DamageData` carries damage and source. Damage subtracts flat armour, floors at zero, and clamps `current_health` to zero. A 0.15-second invulnerability window prevents rapid duplicate hits.
- Successful damage flashes the sprite red. Defeated entities turn dark, stop moving/attacking, and disable their collider. The monster stops attacking a defeated player.
- **R** reloads the encounter, restoring the scene's initial health and positions.
- Mana, evasion, and block remain data-only. Attack/death sprite clips are not part of this pass.

## Verification

### Floating damage numbers

Both actors compose `DamageNumbers`, a screen-space CanvasLayer listening to
`MeleeCombat.damaged`. The resolved `DamageData.applied_amount` reports actual health
lost after armour and remaining-health clamping, without mutating the incoming payload.
Positive damage creates an outlined label above the hit location (gold on monsters,
red on the player). It rises 48 UI pixels with a slight alternating sideways drift,
fades out, and is freed after 0.85 seconds. Zero damage and rejected hits show no number.
Labels ignore mouse input and project after the camera updates, using an interpolated
world position captured at impact. They remain at that hit location if the victim moves.

Combat tests cover displayed damage, armour mitigation, lethal clamping, click-through,
and popup cleanup alongside existing damage checks.

`godot --headless --path . --script res://tests/combat_test.gd` checks damage in both directions, armour, cooldown, range, windup/dodge, independent health, and death collision cleanup. `tests/targeting_test.gd` checks click-to-attack.

## Decision history

| Date | Status | Decision | Source |
| --- | --- | --- | --- |
| 2026-09-14 | Confirmed | Show floating UI damage numbers for actual health lost on player and monsters. | Owner's damage-number request; color/timing are prototype defaults. |
| 2026-09-14 | Confirmed | Remove the Space nearby-attack shortcut; use click-to-attack. | Owner's request after testing targeting. |
| 2026-09-14 | Confirmed | Clicking selects, approaches, and repeats attacks; WASD/ground clicks cancel. | Owner's chosen approach-and-auto-attack behavior. |
| 2026-09-13 | Confirmed | Implement the first player/monster combat loop using existing stats and health UI. | Owner's combat-loop request. |
| 2026-09-13 | Proposed | Space nearest-target melee, flat armour, initial damage values, and R encounter reset are prototype defaults for playtesting. | Implementation choices. |
