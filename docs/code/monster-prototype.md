---
status: confirmed
---

# Code — Basic Monster Prototype

## Confirmed — Blue square placeholder

`scenes/monster.tscn` is a reusable monster scene with a `CharacterBody3D` root in the
`monsters` group and a visual child. Its unlit blue 1.5 × 1.5 quad faces the
camera. One instance stands near the player at `(3, 0, -1)` in `scenes/world.tscn`.

The monster's capsule collision shape blocks the player on physics layer 1.
`scripts/monster.gd` follows the assigned player through the baked navigation mesh,
retargeting at most five times per second. Its 0.5-unit waypoint tolerance accounts
for the navigation surface sitting above the monster body's origin. It stops within
1.5 units of the player and enters a two-second simulated attack. The monster cannot
move during an attack; when its timer ends, it attacks again if the player remains in
range or resumes following. `attack_started` and `attack_finished` signals are hooks
for future animation and damage. This placeholder has no animations or damage.

## Decision history

| Date | Status | Decision | Source |
| --- | --- | --- | --- |
| 2026-09-13 | Confirmed | Add a basic monster represented by a blue square without animations. | Project owner's brief. |
| 2026-09-13 | Confirmed | Enable the existing capsule collider using a physics body. | Project owner's collision request. |
| 2026-09-13 | Confirmed | Follow the player via navigation and stop at attack range. | Project owner's brief. |
| 2026-09-13 | Confirmed | Simulate a two-second attack that locks movement and repeats only while in range. | Project owner's brief. |
