# Knight character sprites

## Current character: `example.png`

The project owner supplied this **1200 × 1310 RGBA** sheet for the animated character. Its poses are unevenly packed, not arranged in a regular 64 × 128 grid.

- First row, first five poses: **south, southwest, west, northwest, north**. These are five directions of a single idle pose, not a five-frame idle loop.
- Next five rows, first eight poses per row: eight-frame walking loops in the same direction order.
- Southeast mirrors southwest; east mirrors west; northeast mirrors northwest. South and north are not mirrored.
- Additional poses elsewhere on the sheet are not used by the current idle/walk controller.

`example_frames.tres` stores 45 individual `AtlasTexture` regions referencing the original image and ten `SpriteFrames` clips: `idle_*` and `walk_*` for each of the five source directions. Walking runs at **10 FPS**, adjustable in the SpriteFrames editor. Idle holds one frame.

### Frame alignment

Every atlas region is padded through its `margin` to a **96 × 128 virtual canvas**. The width accommodates the widest walking stance without clipping. Horizontal padding aligns the torso near x = 48; the shared foot baseline is y = 120. Source-region Y starts are:

| Pose row | Region Y | Height | Frames |
| --- | ---: | ---: | ---: |
| Idle | 0 | 128 | 5 |
| Walk south | 146 | 128 | 8 |
| Walk southwest | 293 | 128 | 8 |
| Walk west | 438 | 128 | 8 |
| Walk northwest | 584 | 128 | 8 |
| Walk north | 731 | 128 | 8 |

Individual X coordinates and widths are recorded in the resource; keep them when editing frame timing. The player uses a 0.015 world-unit pixel size and a vertical sprite offset of 56 pixels to place this baseline at the physics body's feet. Nearest filtering and alpha scissor retain crisp pixels and discard low-alpha fringe pixels already in the source.

The source image is not modified or duplicated for mirroring. All players can share the immutable SpriteFrames resource while playback and horizontal flipping remain per-node state.

## Previous prototype: `idle_directions.png`

`idle_directions.png` contains only the first column of the user-provided sprite sheet:

`/home/xzerow/Downloads/2D HD Character Knight/Spritesheets/With shadows/Idle.png`

- Extracted rectangle: x = 0, y = 0, width = 128, height = 1024.
- Eight 128 × 128 frames, top to bottom: east, southeast, south, southwest, west, northwest, north, northeast.
- One static frame per facing direction; this asset is retained as the previous prototype and is no longer used by the player scene.
- Original transparency and embedded shadows are preserved.

Asset supplied by the project owner for the free-sprite prototype. Author and license metadata have not yet been supplied.
