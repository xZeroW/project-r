---
status: confirmed
---

# Code — Basic Monster Prototype

## Current implementation — Monster lifecycle

`Monster.State` explicitly tracks **IDLE**, **ENGAGED**, **RETURNING**, and **DEAD**.
A `MonsterDefinition` Resource drives every instance. When a `definition` is
assigned, `_ready` derives the monster's stats, `MeleeCombat` EXP reward, the
behavior settings below, and its presentation tint from that definition; when it
is absent the scene's default `stats` and exports apply. Monster definitions
live in `resources/monsters/*.tres` (`Poring`: Lv 1, 100 HP, 10 damage, 2 EXP,
white; `Poporing`: Lv 2, 180 HP, 16 damage, 8 EXP, wider aggro/leash, green tint —
no new art). The Inspector exposes:

| Setting | Default | Meaning |
| --- | --- | --- |
| `level` | 1 | Static base level from the definition; feeds the hit-chance level modifier in combat. Monsters never gain EXP. |
| `aggressive` | true | Automatically acquire the assigned living player nearby. |
| `aggro_radius` | 6.0 | Horizontal distance from monster to player for initial acquisition only; zero disables automatic acquisition. |
| `leash_distance` | 10.0 | Maximum horizontal distance from spawn for both monster and engaged player. |
| `respawn_delay` | 5.0 | Seconds from death until respawn (minimum 0.7). |

Each instance owns independent stats; `combat.stats` is unified with the
monster root's `CharacterStats` resource. The definition tint becomes
`MeleeCombat.base_modulate`, so the damage flash returns the sprite to its
variant color (`visual.modulate` never hard-codes white).

Passive monsters remain idle until the assigned player hits them. A valid hit starts
engagement regardless of aggression, provided the attacker is inside the spawn leash.
Changing aggression or leaving the aggro radius does not cancel an existing engagement.
Crossing the spawn leash, losing the target, or target death cancels windup and starts
returning home. Return navigation refreshes at most five times per second. Returning
monsters cannot attack, receive damage, or be selected. Arrival restores full health
and resets cooldowns; a blocked/unreachable return snaps home after three seconds of
no movement so the monster cannot remain permanently invulnerable.

Death disables collision and combat, hides health UI and contact shadow, and fades the
current sprite over 0.6 seconds. This is procedural death feedback, not a sliced death
clip. After the respawn delay, the same entity resets to its original world spawn with
full health, idle sprite playback, collision, shadow, and health UI restored. Teleport
resets call `reset_physics_interpolation()` to avoid streaking across the map.

Damage is implemented by the shared melee component; see [Combat prototype](combat-prototype.md).
`tests/aggro_test.gd` verifies passive retaliation, acquisition vs engagement,
leash cancellation, return immunity/healing, death fade, and full respawn reset.
`tests/monster_diversity_test.gd` verifies per-instance definitions, independent
stats/health, per-instance EXP, distinct aggro radii, variant tints, and the
tint-preserving respawn.

## Confirmed — Poring sprite presentation

`scenes/monster.tscn` is a reusable monster scene with a `CharacterBody3D` root in the
`monsters` group and a visual child. Its camera-facing `AnimatedSprite3D` uses the
one standing frame from the first row of `assets/enemies/poring/poring.png`.
`scenes/world.tscn` hosts two instances: a Poring near the player at `(3, 0, -1)`
and a green-tinted Poporing at `(0.53, 0, -1)`.

The monster's capsule collision shape blocks the player on physics layer 1.
`scripts/monster.gd` follows the assigned player through the baked navigation mesh,
retargeting at most five times per second. Its 0.5-unit waypoint tolerance accounts
for the navigation surface sitting above the monster body's origin. It stops within
1.5 units of the player and enters a two-second attack windup. The monster cannot
move during an attack; when its timer ends, it attacks again if the player remains in
range or resumes following. `attack_started` and `attack_finished` signals are hooks
for animation; damage is resolved through `MeleeCombat` at completion.

The poring walking, attack, hurt, and dying regions remain available in the source sheet
but are not yet mapped to gameplay states.

Both the player and monster also show a screen-space UI health bar anchored to the
character's projected world position. Its green fill follows the owning character's
`CharacterStats.current_health` value relative to its `max_health`.

## Decision history

| Date | Status | Decision | Source |
| --- | --- | --- | --- |
| 2026-09-16 | Confirmed | Monster instances are data-driven by `MonsterDefinition` resources; tint lives on `MeleeCombat.base_modulate` (not `visual.modulate`) so the damage flash preserves it. | Phase D (monster diversity) implementation. |
| 2026-09-14 | Confirmed | Passive retaliation, separate spawn leash, return home, and death/respawn lifecycle supersede radius-based disengagement. | Owner's approval of the next monster behavior loop. |
| 2026-09-14 | Proposed | Leash 10 units, respawn 5 seconds, return immunity/full heal, three-second blocked return recovery, and death fade are prototype defaults. | Implementation choices. |
| 2026-09-14 | Confirmed | Add configurable aggression and aggro radius; aggressive monsters engage players entering the radius. | Owner's aggro request. |
| 2026-09-14 | Proposed | Default radius 6; disengage outside radius, and passive monsters do not retaliate. | Initial implementation behavior for playtesting. |
| 2026-09-13 | Confirmed | Add a basic monster represented by a blue square without animations. | Project owner's brief. |
| 2026-09-13 | Confirmed | Replace the placeholder with the imported poring sheet's eight-frame standing animation. | Project owner's imported enemy asset. |
| 2026-09-13 | Confirmed | Enable the existing capsule collider using a physics body. | Project owner's collision request. |
| 2026-09-13 | Confirmed | Follow the player via navigation and stop at attack range. | Project owner's brief. |
| 2026-09-13 | Confirmed | Simulate a two-second attack that locks movement and repeats only while in range. | Project owner's brief. |
