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

Combat: **R** restarts the encounter.
**Left-click a monster** to select, approach, and auto-attack. **WASD** or a ground click cancels.
Hits reduce the existing health bars, flash red, and disable defeated characters.
Incoming attacks resolve through a combat resolver: stage-one accuracy/MISS, then evasion, block (halves damage), and crit (×1.5); popups show MISS/EVADE/BLOCK.
See [Combat prototype](docs/code/combat-prototype.md).

Progression: **C** toggles the status window (STR/AGI/VIT/INT/DEX/LUK, +5 points per level; see [Status point allocation](docs/code/status-points.md)). **I** toggles the 20-slot inventory; every item consumes one slot and can be dragged to an empty slot or onto another item to swap. Click a floating item-name label to path to and collect that monster drop—walking over it does not loot it (see [Inventory](docs/code/inventory.md)). Each Poring awards 2 Base EXP on kill; leveling uses the classic RO 1–99 table (see [Base leveling](docs/code/leveling-system.md)). Player death charges 5% of the current level's Base EXP and respawns at the spawn point (see [Player death and respawn](docs/code/player-respawn.md)). Monsters are data-driven by `MonsterDefinition` resources (`Poring`, green-tinted `Poporing` — see [Monster prototype](docs/code/monster-prototype.md)). The roadmap lives in [docs/code/roadmap.md](docs/code/roadmap.md).

```sh
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/combat_test.gd
godot --headless --path . --script res://tests/targeting_test.gd
godot --headless --path . --script res://tests/status_points_test.gd
godot --headless --path . --script res://tests/experience_test.gd
godot --headless --path . --script res://tests/death_respawn_test.gd
godot --headless --path . --script res://tests/combat_math_test.gd
godot --headless --path . --script res://tests/monster_diversity_test.gd
godot --headless --path . --script res://tests/inventory_test.gd
godot --headless --path . --script res://tests/loot_test.gd
# Movement/camera/navmesh flaky in some environments; still useful signal:
godot --headless --path . --script res://tests/prototype_test.gd
godot --headless --path . --script res://tests/click_movement_test.gd
godot --headless --path . --script res://tests/aggro_test.gd
```

The eleven feature tests (combat, targeting, status_points, experience, death_respawn, combat_math, monster_diversity, hotbar, spells, inventory, loot) pass cleanly. prototype/click_movement/aggro are known-flaky timing checks for movement, camera, input, animation, assets, and navmesh code.

The integration checks cover physical WASD/Q/E bindings, all eight directions, consistent movement speed, retained idle facing, floor contact, obstacle/boundary collisions, camera-free physics with movement recovery, camera orbit/reversal, movement/facing after rotation, and persistent map-facing direction through full camera orbits. Mouse-wheel checks cover zoom direction, limits, reversal, UI input blocking, and inactive cameras. Follow checks cover render-frame centering during movement, reversal and stopping, independence from player rotation, and missing/restored targets.

Animation checks cover atlas bounds and padded frame sizes, all eight direction/mirroring combinations, idle/walk transitions, blocked movement, a complete looping walk cycle, and preserved frame progress when turning or rotating the camera.

Click checks cover navmesh bake synchronization, ground picking and marker feedback, obstacle detours, arrival stopping, destination replacement, WASD cancellation, invalid/UI/out-of-floor clicks, rotated and zoomed picking, and stuck-route timeout with a new physical barrier.
