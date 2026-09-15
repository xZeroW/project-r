---
status: confirmed
---

# Code — Player death and respawn

## Current implementation

- `scenes/player.tscn` composes a new `DeathRespawn` component listening to its
  own `%Combat.died` signal. On death the shared combat visual darkens and stops,
  the collider is disabled, movement freezes, and `DeathRespawn` hides the health
  bar and contact shadow and immediately charges a Base EXP penalty.
- After a `respawn_delay` of **3 seconds** the player teleports to their **initial
  spawn position** (captured in `_ready`), calls `reset_physics_interpolation()`
  after repositioning (required because physics interpolation is on), restores
  full health, re-enables damage intake and the collider, restores the sprite to
  white/idle, and shows the health bar and contact shadow again. It emits `respawned`.
- **Death penalty:** the player loses **5% of the current level's Base EXP
  requirement** (`Experience.lose_experience`), which can never de-level — only
  current-level EXP is reduced and it floors at zero. At level 99 no penalty is
  charged. The EXP HUD flashes a red `-N Base EXP` notice on loss.
- The monster already returns home and fully heals when its target dies (see
  [Monster lifecycle](monster-prototype.md)); aggressive monsters re-engage the
  respawned player when they re-enter the aggro radius. No monster change was needed.
- **R** still restarts the whole encounter, including level/EXP.

## Fix — unified per-character stats instances

`scenes/world.tscn` previously overrode only the root `Player.stats`, so the scene
held three independent resources: root, `%Combat.stats`, and `%HealthBar.stats`.
Because combat and the health bar wrote and read their own copies while the player
orchestrator death-gated against the root copy, a defeated player's root stats never
reached zero and WASD/click movement kept working. The world override was removed so
the whole player scene shares the single per-instance `PlayerStats` sub-resource;
death detection, damage, and the displayed bar now agree.

## Verification

`godot --headless --path . --script res://tests/death_respawn_test.gd` checks shared
stat instances, death state (zero HP, collider off, bar hidden), the exact 5% EXP
penalty with no de-level, the zero-EXP floor at level 1, damage rejection while dead,
and the full spawn-point respawn reset. EXP bracket behavior is covered further in
`tests/experience_test.gd`.

## Decision history

| Date | Status | Decision | Source |
| --- | --- | --- | --- |
| 2026-09-15 | Confirmed | Players respawn at their initial spawn point instead of losing the encounter. | Owner's player death/respawn request. |
| 2026-09-15 | Confirmed | Death charges 5% of the current level's Base EXP requirement and never de-levels. | Owner's "we do not lose level" penalty choice. |
| 2026-09-15 | Confirmed | All player components share one stat resource instance per scene. | Bug found while implementing death gating. |
| 2026-09-15 | Proposed | 3-second respawn delay, full-health restore, and no EXP at level 99 are prototype defaults. | Implementation choices. |