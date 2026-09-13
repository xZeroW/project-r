# rag-clone

A Godot 4.7 prototype with a 2D directional knight in an untextured 3D map.

## Run

Open `project.godot` in Godot and press **F5**, or run:

```sh
godot --path .
```

Use **WASD** for camera-relative movement; combine keys for diagonals. The camera tracks the player's interpolated render position without a catch-up delay. Hold **Q / E** to rotate the camera left / right around the player. Scroll the **mouse wheel up / down** to smoothly zoom in / out. The isometric tilt stays fixed, and WASD follows the rotated view. **Left-click** on the visible floor to walk there: a teal torus marks the destination, the player follows a baked navigation path around the three obstacles, WASD cancels at any time, and a physically blocked route times out. The character plays an eight-frame walking loop while moving and holds an idle pose when stopped or blocked. Its map-facing direction is retained when stopped; rotating the camera changes which side is visible, using mirrored poses for the missing eastern views. A 180-degree orbit changes a front view into a back view. The map includes a floor, boundary walls, and three collision obstacles.

Input, physics movement, and sprite presentation are separate GDScript components assembled in `scenes/player.tscn`.

See [Map and player prototype](docs/code/map-player-prototype.md) for implementation details and [asset notes](assets/characters/knight/README.md) for the supplied sprite sheet.

## Validate

```sh
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/prototype_test.gd
godot --headless --path . --script res://tests/click_movement_test.gd
```

The integration checks cover physical WASD/Q/E bindings, all eight directions, consistent movement speed, retained idle facing, floor contact, obstacle/boundary collisions, camera-free physics with movement recovery, camera orbit/reversal, movement/facing after rotation, and persistent map-facing direction through full camera orbits. Mouse-wheel checks cover zoom direction, limits, reversal, UI input blocking, and inactive cameras. Follow checks cover render-frame centering during movement, reversal and stopping, independence from player rotation, and missing/restored targets.

Animation checks cover atlas bounds and padded frame sizes, all eight direction/mirroring combinations, idle/walk transitions, blocked movement, a complete looping walk cycle, and preserved frame progress when turning or rotating the camera.

Click checks cover navmesh bake synchronization, ground picking and marker feedback, obstacle detours, arrival stopping, destination replacement, WASD cancellation, invalid/UI/out-of-floor clicks, rotated and zoomed picking, and stuck-route timeout with a new physical barrier.
