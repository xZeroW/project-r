# rag-clone

A Godot 4.7 prototype with a 2D directional knight in an untextured 3D map.

## Run

Open `project.godot` in Godot and press **F5**, or run:

```sh
godot --path .
```

Use **WASD** for camera-relative movement; combine keys for diagonals. Hold **Q / E** to rotate the camera left / right around the map center. The isometric tilt and zoom remain fixed, and WASD follows the rotated view. The knight retains its map-facing direction when stopped; rotating the camera changes which of its eight sides is visible. A 180-degree orbit changes a front view into a back view. The map includes a floor, boundary walls, and three collision obstacles.

Input, physics movement, and sprite presentation are separate GDScript components assembled in `scenes/player.tscn`.

See [Map and player prototype](docs/code/map-player-prototype.md) for implementation details and [asset notes](assets/characters/knight/README.md) for the supplied sprite sheet.

## Validate

```sh
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/prototype_test.gd
```

The integration checks cover physical WASD/Q/E bindings, all eight directions, consistent movement speed, retained idle facing, floor contact, obstacle/boundary collisions, camera-free physics with movement recovery, camera orbit/reversal, movement/facing after rotation, and persistent map-facing direction through full camera orbits.
