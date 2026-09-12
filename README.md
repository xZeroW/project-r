# rag-clone

A Godot 4.7 prototype with a 2D directional knight in an untextured 3D map.

## Run

Open `project.godot` in Godot and press **F5**, or run:

```sh
godot --path .
```

Use **WASD** for camera-relative movement; combine keys for diagonals. The knight displays one of eight static facing frames and retains its facing when stopped. The map includes a floor, boundary walls, and three collision obstacles, viewed through a fixed isometric camera.

Input, physics movement, and sprite presentation are separate GDScript components assembled in `scenes/player.tscn`.

See [Map and player prototype](docs/code/map-player-prototype.md) for implementation details and [asset notes](assets/characters/knight/README.md) for the supplied sprite sheet.

## Validate

```sh
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/prototype_test.gd
```

The integration checks cover physical WASD bindings, all eight directions, consistent movement speed, retained idle facing, floor contact, and obstacle/boundary collisions.
