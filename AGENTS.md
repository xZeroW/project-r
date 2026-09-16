# AGENTS.md

Godot 4.7.2 GDScript prototype: a 2D animated knight on an untextured 3D map, Ragnarok-Online-style (2D characters in 3D worlds). Composition-first: gameplay is assembled from small `class_name` components, not inheritance hierarchies. Engine binary is `godot` (installed via gdvm, 4.7.2.stable); project.godot declares features "4.7".

## Commands

All verified working from the repo root:

```sh
# Run the game (main scene: scenes/world.tscn)
godot --path .

# Reimport assets (run after adding new assets)
godot --headless --editor --path . --import

# Validation: SceneTree test scripts, run individually (exit 0 = pass, 1 = failures).
# Seven feature tests pass cleanly:
godot --headless --path . --script res://tests/combat_test.gd
godot --headless --path . --script res://tests/targeting_test.gd
godot --headless --path . --script res://tests/status_points_test.gd
godot --headless --path . --script res://tests/experience_test.gd
godot --headless --path . --script res://tests/death_respawn_test.gd
godot --headless --path . --script res://tests/combat_math_test.gd
godot --headless --path . --script res://tests/monster_diversity_test.gd
# Known-flaky in this environment (pre-existing nav/camera timing flakes; still a useful signal):
godot --headless --path . --script res://tests/prototype_test.gd
godot --headless --path . --script res://tests/click_movement_test.gd
godot --headless --path . --script res://tests/aggro_test.gd
```

There is no aggregate runner or lint setup. These ten scripts are the entire test suite; each is a `SceneTree` script that instantiates the full world and ticks physics, so a complete run takes several minutes. Tests print `PASS: ...` on success; failures appear as `push_error` lines and a nonzero exit. Budget ~30–60s per test. Run the seven green feature tests after touching combat, stats, status points, leveling, respawn, monster definitions, or targeting; treat prototype/click_movement/aggro as a flaky signal after movement, camera, input, animation, assets, or navmesh code.

## Architecture

- `scenes/world.tscn` is the entrypoint. `scenes/player.tscn` composes a `CharacterBody3D` from components accessed via `%SceneUniqueName` refs in `scripts/player.gd` (`scripts/player.gd:7`).
- Components live in `scripts/components/`:
  - **Movement/presentation**: `player_input` (intent vector, click forwarding), `character_movement` (camera-relative ground physics), `click_movement` (ray picking + navmesh path following), `destination_marker` (teal torus), `directional_sprite` (AtlasTexture/facing presentation).
  - **Combat**: `melee_combat` (shared damage/cooldown/EXP-credit component), `combat_resolver` (RefCounted RO-contested roll: hit% = clamp(80 + acc + level mod − evasion, 5%, 95%) → block → crit, injectable `dice`), `targeting` (click-to-attack pursuit), `target_indicator` (target ring), `damage_numbers` (screen-space popups incl. MISS/EVADE/BLOCK/crit), `health_bar_ui`.
  - **Progression**: `status_points` (STR/AGI/VIT/INT/DEX/LUK + derived stats), `status_ui` (C-toggle panel), `experience`, `experience_ui`, `death_respawn` (player death EXP penalty + respawn).
  - **Data**: `monster_definition` (Resource blueprint); plus `scripts/character_stats.gd` (per-instance stat resource), `scripts/damage_data.gd`, and `scripts/experience_curve.gd` (RO classic 1–99 EXP table). Each node has a `class_name` used as a type; `scripts/player.gd` and `scripts/monster.gd` are the root orchestrators that wire them.
- `scripts/prototype_map.gd` is a `@tool` `NavigationRegion3D` that generates all map geometry (floor, walls, 3 obstacles) procedurally at runtime and bakes the navmesh. No map scene files exist — geometry is code only.
- `scripts/orbit_camera.gd`: orthographic camera following the player's *interpolated render position* in `_process`; it must stay in `PHYSICS_INTERPOLATION_MODE_OFF` (see quirks).
- Full implementation details live in `docs/code/map-player-prototype.md`; decisions are recorded in `docs/code/architecture.md`, `docs/graphics/visual-direction.md`, and `assets/characters/knight/README.md`.

## Quirks and conventions (hard-earned)

- **Physics interpolation is on** (`physics/common/physics_interpolation=true`). Teleports MUST call `reset_physics_interpolation()` after repositioning or the body interpolates across the map. The camera reads `get_global_transform_interpolated()` and sets its own interpolation mode off — do not "fix" this into a spring/lerp.
- **Static typing is enforced by warning**: `project.godot` sets `gdscript/warnings/untyped_declaration=1`. All project code is fully typed. Match it.
- **Movement**: 4 units/sec, camera-relative; diagonal speed equals cardinal speed. `player.gd` owns the persistent world-facing direction; the visual component projects it onto camera axes each physics tick (idle facing survives camera orbit). Facing mapping: south/north unmirrored; east/west/NE/SE are mirrored from west/southwest/northwest clips.
- **Sprite scheme**: `assets/characters/knight/example.png` is an unevenly packed 1200×1310 sheet. `example_frames.tres` holds 10 `SpriteFrames` clips (`idle_*` = 1 frame, `walk_*` = 8 frames @ 10 FPS) over 45 padded 96×128 `AtlasTexture` regions. Do not regenerate/re-slice these by hand — see `assets/characters/knight/README.md` for region tables. Preserve walking phase across turns with `set_frame_and_progress()`.
- **Presentation collision illusion**: the knight sprite is ~1.92 units tall while the physics capsule is 1.2 tall with a 0.5 radius. The capsule radius matches the navigation agent radius so WASD and click-to-move keep the same clearance. Boundary colliders and visual meshes stay aligned at 0.5 thick and 0.8 tall so the full billboard remains visible at north/west faces. When adding buildings/fences/obstacles, keep their occluders aligned with the intended sprite presentation and give them a foreground visual face only where needed.
- **Navmesh bake race**: the runtime bake is deferred (`_start_navmesh_bake.call_deferred()`) and runs synchronously via `bake_navigation_mesh(false)`. Baking in `_ready`, or async on a worker thread, can silently publish an empty mesh. Tests poll for map sync + valid closest-point owner before relying on paths.
- **Click-to-move**: the screen ray is captured at click time but the physics query is deferred to the next physics tick; it filters layer 1, skips the player, and only accepts hits in the `walkable_ground` group that validate against the baked navmesh (0.75 horizontal / 0.75 vertical tolerance; the baked surface floats ~0.5 above the floor). WASD cancels any active route. Route times out (1s zero motion) instead of grinding.
- **Tests** extend `SceneTree` and inject mouse/scroll via `root.push_input(event, true)` (not `Input.action_press`), and assert against `physical_keycode` bindings. Keep that pattern when writing new integration checks.
- `docs/` files use a status front-matter (`confirmed` / `proposed` / `open`) and a decision-history table. Record new architecture/gfx decisions there rather than only in commit messages.

## Non-game code to ignore

- `.opencode/skills/godot-master/` is a vendored Godot skill library (dozens of example GDScript files). Reference material only — none of it is part of the game; don't treat its `class_name` scripts as project code.
- `.godot/` and `export/` are gitignored (`export/rag-clone.x86_64` is a stale local build). `export_presets.cfg` defines the Linux desktop preset. There is no CI.
