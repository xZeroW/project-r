---
status: confirmed
---

# Combat prototype

## Current implementation

- Press **Space** to attack the nearest living, unobstructed monster within 1.8 ground units. One press requests one attack on the next physics tick; UI-consumed input does not attack.
- Player damage defaults to 20, with a `1 / attack_speed` second cooldown (one second initially).
- Poring damage defaults to 10. Its existing movement-locked windup lasts `attack_duration / attack_speed` (two seconds initially). Range (1.5 units), target life, and obstruction are checked again when it finishes; leaving range dodges the attack.
- Both entities compose `MeleeCombat`, sharing their own local `CharacterStats` resource with the UI. `DamageData` carries damage and source. Damage subtracts flat armour, floors at zero, and clamps `current_health` to zero. A 0.15-second invulnerability window prevents rapid duplicate hits.
- Successful damage flashes the sprite red. Defeated entities turn dark, stop moving/attacking, and disable their collider. The monster stops attacking a defeated player.
- **R** reloads the encounter, restoring the scene's initial health and positions.
- Mana, evasion, and block remain data-only. Attack/death sprite clips are not part of this pass.

## Verification

`godot --headless --path . --script res://tests/combat_test.gd` checks damage in both directions, Space input, armour, cooldown, range, windup/dodge, independent health, and death collision cleanup.

## Decision history

| Date | Status | Decision | Source |
| --- | --- | --- | --- |
| 2026-09-13 | Confirmed | Implement the first player/monster combat loop using existing stats and health UI. | Owner's combat-loop request. |
| 2026-09-13 | Proposed | Space nearest-target melee, flat armour, initial damage values, and R encounter reset are prototype defaults for playtesting. | Implementation choices. |
