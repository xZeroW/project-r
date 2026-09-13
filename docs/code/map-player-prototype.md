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
updated: 2026-09-13
---

# Code — Map and Player Prototype

## Confirmed — Prototype requirements

Build a map and player in Godot with WASD movement. Map textures are unnecessary. Use only the first column of the supplied knight `Idle.png`: eight rows of 128 × 128 pixels, ordered clockwise from east through northeast.

**Source:** Project owner's map-and-player brief, recorded on 2026-09-12. The supplied source path and extracted asset details are recorded in the [asset notes](../../assets/characters/knight/README.md).

**Updated character requirement:** The owner subsequently supplied `example.png` for idle and walking. The first five poses are idle directions south → southwest → west → northwest → north. The next five rows contain the matching walking loops. Missing eastern views are mirrored. This supersedes the original static-knight presentation; the earlier asset is retained.

## Current implementation — Scene and controls

The following are implemented prototype choices, not approved long-term specifications:

- Godot 4.7 project using the existing Forward Plus renderer and Jolt physics configuration.
- `scenes/world.tscn` is the entry point, with an orthographic camera initially tilted approximately 35.26 degrees downward and rotated 45 degrees around the vertical axis.
- The camera follows the player's interpolated render position directly, without a trailing spring or catch-up delay. Project physics interpolation smooths the player between physics ticks; the camera reads `get_global_transform_interpolated()` in `_process()` and disables its own automatic interpolation to avoid applying it twice. `follow_target` is an exported `Node3D` reference wired in the world scene. The camera remains outside the player's hierarchy, so player rotation and scale do not affect it. A missing/freed target leaves the last follow center in place. Teleports must call `reset_physics_interpolation()` after repositioning to avoid interpolating across the map.
- Hold Q / E to orbit left / right around the followed player at 90 degrees per second. Tilt, height relative to the follow center, orbit distance, and zoom remain fixed during orbit. `scripts/orbit_camera.gd` uses InputMap actions and reconstructs the transform from a wrapped angle to avoid accumulated transform drift. Camera orientation updates before player physics so movement uses the current view basis; position tracking and zoom smooth during render updates.
- Mouse wheel up / down zooms in / out by changing orthographic size, independently of orbit. The current size limits are 8 and 18 units; the authored size of 32 is clamped to 18 on startup. Zoom uses a 1.15 step factor and frame-rate-independent exponential smoothing. These settings are exported on the camera. Zoom actions use `_unhandled_input` so UI can consume scrolling first; inactive cameras ignore them.
- A 24 × 24 unit untextured map has colored box geometry, collision walls, and three obstacles. `scripts/prototype_map.gd` generates the same geometry in editor preview and at runtime.
- WASD uses physical key bindings. W moves toward screen-up, S toward screen-down, A toward screen-left, and D toward screen-right on the ground plane.
- Diagonal movement has the same world-space speed as cardinal movement: 4 units per second.
- The player collides with map geometry and uses gravity to remain grounded.
- Left-click on the floor requests a click-to-move destination. A screen-space ray is captured when the click is received, the physics query is deferred to the next physics tick, and the ground hit (group `walkable_ground`) is validated against the baked navigation mesh before a route is accepted. The player walks the cached path at the same 4 units/second speed; WASD cancels movement and any pending click. A teal torus marker tracks the accepted destination and is cleared on arrival or cancellation. See the click-movement section below.

## Current implementation — Player composition

| File | Responsibility |
| --- | --- |
| `scenes/player.tscn` | Reusable physics body, collider, and component assembly. |
| `scripts/player.gd` | Coordinates components during physics updates and owns the persistent world-facing direction. |
| `scripts/components/player_input.gd` | Reads movement actions into a 2D intent vector and forwards ground clicks as screen-space destination requests. |
| `scripts/components/character_movement.gd` | Converts intent into camera-relative ground movement and applies physics. |
| `scripts/components/click_movement.gd` | Resolves deferred screen clicks against physics and the navigation map, follows one cached world-space path, detects arrival and stuck states. |
| `scripts/components/destination_marker.gd` | Shows a teal torus at the accepted destination and clears it on arrival or cancellation. |
| `scripts/components/directional_sprite.gd` | Projects world facing onto camera ground-plane axes, chooses the source clip/mirroring, and preserves walking phase when turning. |

Components have named script types and are cached through scene-unique references. The movement component converts input and the camera basis into a world-space direction. The player uses that direction for both movement and facing, retaining the last nonzero facing while idle. Physics receives the world-space direction, and presentation receives the retained facing and camera basis. If no camera is active, directional input pauses and facing is retained, while gravity and collision handling continue. Movement resumes when a camera becomes active again.

The visual component is a camera-facing `AnimatedSprite3D` with depth testing, alpha scissor, nearest filtering, and a foot-aligned offset. Its shared `example_frames.tres` references individually cropped regions of the unevenly packed 1200 × 1310 `example.png`. All 45 regions have a padded 96 × 128 canvas and a consistent foot baseline. No runtime image slicing or mirrored texture copies are needed.

## Current implementation — Direction mapping

| Input | Screen-facing direction | Source idle/walk direction | Mirrored |
| --- | --- | --- | --- |
| D | East | West | Yes |
| S + D | Southeast | Southwest | Yes |
| S | South | South | No |
| S + A | Southwest | Southwest | No |
| A | West | West | No |
| W + A | Northwest | Northwest | No |
| W | North | North | No |
| W + D | Northeast | Northwest | Yes |

Facing follows the intended world-space movement direction even when an obstacle blocks movement. Idle retains that direction relative to the map. The visible direction and mirroring are recalculated against the camera every physics tick, so a 180-degree orbit changes a front view into a back view without turning the character. Camera axes are flattened and normalized before selecting one of eight sectors, avoiding tilt-induced directional bias.

Actual horizontal displacement after `move_and_slide()` selects idle versus walking: a fully blocked character idles rather than walking in place, while sliding movement continues animating. Each walking clip loops through eight frames at 10 FPS; each idle clip holds its single pose. Direction changes during walking retain both the frame and fractional progress through `set_frame_and_progress()`. The same clip is not restarted each physics tick. `facing_index` represents the viewing sector independently of the animated sprite's temporal `frame`.

## Current implementation — Click to move

- A **left-click** (InputMap action `click_move`) requests a destination. `scripts/components/player_input.gd` emits the screen position without deferring; the player passes it to `scripts/components/click_movement.gd`, which captures the camera's ray origin and direction at click time so later camera motion cannot shift the picked point. The physics ray itself is resolved on the next physics tick.
- The deferred ray filters physics layer `1` (bit one) and skips the player's own body. A route is only accepted when the ray hits a collider in the `walkable_ground` group (currently the floor box), the navigation map has finished at least one synchronization, the clicked point has a valid owner on the map, the navmesh's snapped point is within 0.75 units horizontally and 0.75 vertically of the picked surface (the baked walkable surface floats roughly half a unit above the floor, so the vertical tolerance swallows that offset rather than conflating it with off-floor snaps), and a path from the player to the snapped target exists and ends within 0.1 units of it. Any failure silently ignores the click.
- Because the floor is 24 × 24 while the orthographic camera only shows part of it, only on-screen floor pixels can currently be picked. Off-screen clicks cannot create a route, which also makes invalid clicks (obstacles, walls, outside the floor, UI-consumed clicks, clicking directly under the player) safely no-ops.
- On acceptance, `click_movement.gd` caches the world-space path, emits `destination_changed`, and walks the path segment-to-segment at the movement component's 4 units/second speed. Waypoints that fall inside `arrival_distance` (0.08) are skipped without overshooting, the final step is shortened to avoid circling a waypoint, and arrival clears the destination (`destination_cleared`). A player that keeps `record_motion` reporting zero displacement for `stuck_timeout` (1 second) cancels the route, so a physically blocked path times out instead of grinding forever.
- `player.gd` wires clicking and movement so that any non-zero WASD intent first calls `click_movement.cancel()`: keyboard input overrides and clears the click route, its marker, and any queued unprocessed click.
- `scripts/components/destination_marker.gd` shows a teal emissive torus raised slightly above the accepted destination and hides it on arrival or cancellation. Because the destination is stored in world space relative to the marker's parent, orbit/zoom and player motion do not shift it.

## Verification

`tests/prototype_test.gd` checks scene startup, atlas dimensions/bounds and padding, physical WASD bindings, all eight movement/facing/mirroring combinations, equal diagonal speed, retained idle facing, floor contact, obstacle collision, and boundary collision. It also verifies gravity and floor collision without an active camera, paused horizontal movement with retained facing, and recovery when the camera becomes active again. Animation checks exercise all eight walking frames, looping, idle transitions, blocked movement, and frame/progress preservation when changing direction or camera-relative view.

See the [project README](../../README.md) for run and test commands.

Camera checks additionally cover physical Q/E bindings, orbit direction and reversal, fixed distance/height relative to the player, fixed tilt/zoom, aiming at the player, opposing inputs, stopping on release, and all eight movement/facing directions after rotation. World-facing checks exercise every 45-degree sector through a full idle orbit, the front/back swap after a reverse half-turn, and retention of a new movement-established heading.

Zoom checks inject mouse-wheel events through the input pipeline and verify direction, reversal, both size limits, blocked UI scrolling, and inactive-camera behavior. Zoom also preserves camera transform and character position/facing; rotation and movement checks then run at the new zoom level.

Follow checks verify scene wiring and interpolation configuration, and sample after the camera's render update to assert that the rendered player stays centered during movement, direction reversal, and stopping. They also cover retained orientation/zoom, independence from player rotation, and safe handling of removed/restored targets. Test teleports reset interpolation history.

`tests/click_movement_test.gd` waits for the procedurally baked navigation mesh to synchronize (map iteration past the initial sync with a valid owner), then checks: a click on the floor produces a destination and marker; obstacle detours walk around the collision box; arrival stops the player, clears the marker and destination, and returns to idle; a second click replaces the previous route and marker; WASD cancel during movement clears the route and marker and does not resume after key release; clicks on an obstacle, outside the floor, and through a UI panel are ignored and leave the player still; picking uses the rotated and zoomed camera; and a newly added physical barrier causes a blocked route to time out without teleporting through it.

The navmesh in `scripts/prototype_map.gd` is baked at runtime over the floor and obstacle static colliders. The bake is deferred with `call_deferred` and runs synchronously on the main thread: baking synchronously inside `_ready`, or asynchronously on a worker thread, can race the `NavigationRegion3D` against its navigation-server map registration and silently publish an empty mesh even though the source navigation mesh resource reports polygons. After the bake, the test polls the map iteration and a valid `map_get_closest_point_owner` before exercising clicks, mirroring the documented requirement to wait a full map synchronization after a bake.
