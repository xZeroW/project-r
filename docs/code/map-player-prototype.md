---
id: code-map-player-prototype
title: Code — Map and Player Prototype
status: active
tags:
  - godot
  - prototype
  - movement
  - sprites
created: 2026-09-12
updated: 2026-09-12
---

# Code — Map and Player Prototype

## Confirmed — Prototype requirements

Build a map and player in Godot with WASD movement. Map textures are unnecessary. Use only the first column of the supplied knight `Idle.png`: eight rows of 128 × 128 pixels, ordered clockwise from east through northeast.

**Source:** Project owner's map-and-player brief, recorded on 2026-09-12. The supplied source path and extracted asset details are recorded in the [asset notes](../../assets/characters/knight/README.md).

## Current implementation — Scene and controls

The following are implemented prototype choices, not approved long-term specifications:

- Godot 4.7 project using the existing Forward Plus renderer and Jolt physics configuration.
- `scenes/world.tscn` is the entry point, with an orthographic camera initially tilted approximately 35.26 degrees downward and rotated 45 degrees around the vertical axis.
- Hold Q / E to orbit left / right around the map center at 90 degrees per second. Tilt, height, orbit distance, and zoom remain fixed. `scripts/orbit_camera.gd` uses InputMap actions and reconstructs the transform from a wrapped angle to avoid accumulated transform drift. The camera updates before player physics so movement uses the current view basis.
- A 24 × 24 unit untextured map has colored box geometry, collision walls, and three obstacles. `scripts/prototype_map.gd` generates the same geometry in editor preview and at runtime.
- WASD uses physical key bindings. W moves toward screen-up, S toward screen-down, A toward screen-left, and D toward screen-right on the ground plane.
- Diagonal movement has the same world-space speed as cardinal movement: 4 units per second.
- The player collides with map geometry and uses gravity to remain grounded.

## Current implementation — Player composition

| File | Responsibility |
| --- | --- |
| `scenes/player.tscn` | Reusable physics body, collider, and component assembly. |
| `scripts/player.gd` | Coordinates components during physics updates and owns the persistent world-facing direction. |
| `scripts/components/player_input.gd` | Reads movement actions into a 2D intent vector. |
| `scripts/components/character_movement.gd` | Converts intent into camera-relative ground movement and applies physics. |
| `scripts/components/directional_sprite.gd` | Projects the world-facing direction onto camera ground-plane axes and selects the visible sprite frame. |

Components have named script types and are cached through scene-unique references. The movement component converts input and the camera basis into a world-space direction. The player uses that direction for both movement and facing, retaining the last nonzero facing while idle. Physics receives the world-space direction, and presentation receives the retained facing and camera basis. If no camera is active, directional input pauses and facing is retained, while gravity and collision handling continue. Movement resumes when a camera becomes active again.

The visual component is a camera-facing `Sprite3D` with transparency, depth testing, and an offset positioning the sprite's feet near the physics body's ground contact. The supplied embedded shadows are retained. The first column is extracted into a local 128 × 1024 PNG, so the project does not depend on the original Downloads path at runtime.

## Current implementation — Direction mapping

| Input | Screen-facing direction | Sprite row (zero-based) |
| --- | --- | --- |
| D | East | 0 |
| S + D | Southeast | 1 |
| S | South | 2 |
| S + A | Southwest | 3 |
| A | West | 4 |
| W + A | Northwest | 5 |
| W | North | 6 |
| W + D | Northeast | 7 |

Facing follows the intended world-space movement direction even when an obstacle blocks movement. Idle retains that direction relative to the map. The sprite frame is recalculated against the camera every physics tick, so a 180-degree orbit changes a front view into a back view without turning the character. Camera axes are flattened and normalized before selecting one of eight sectors, avoiding tilt-induced directional bias. Only one static frame per direction is used; animation is deferred.

## Verification

`tests/prototype_test.gd` checks scene startup, the extracted texture dimensions, physical WASD bindings, all eight movement/facing combinations, equal diagonal speed, retained idle facing, floor contact, obstacle collision, and boundary collision. It also verifies gravity and floor collision without an active camera, paused horizontal movement with retained facing, and recovery when the camera becomes active again.

See the [project README](../../README.md) for run and test commands.

Camera checks additionally cover physical Q/E bindings, orbit direction and reversal, fixed distance/height/tilt/zoom, aiming at the map center, opposing inputs, stopping on release, and all eight movement/facing directions after rotation. World-facing checks exercise every 45-degree sector through a full idle orbit, the front/back swap after a reverse half-turn, and retention of a new movement-established heading.
