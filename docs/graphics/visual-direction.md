---
id: graphics-visual-direction
title: Graphics — Visual Direction
status: active
tags:
  - graphics
  - art-direction
  - 2d-characters
  - 3d-maps
  - ragnarok-online-reference
created: 2026-09-12
updated: 2026-09-12
---

# Graphics — Visual Direction

## Confirmed — Combined references

The owner clarified that the game mixes **Ragnarok Online (2002)** and **Tree of Savior**.
The existing 2D-character/3D-map foundation remains; Tree of Savior also informs the
requested targeting/click-to-attack direction. Specific mechanics are recorded as
project decisions rather than assumed from either reference game.

| Date | Status | Decision | Source |
| --- | --- | --- | --- |
| 2026-09-14 | Confirmed | Combine Ragnarok Online (2002) and Tree of Savior as project references. | Owner's targeting brief. |

## Confirmed — Visual foundation

The game will use **2D characters in 3D maps**, with **Ragnarok Online (2002)** as its visual reference.

This hybrid 2D/3D presentation is the initial graphics requirement. The reference establishes a visual direction; it does not by itself establish the game's combat, classes, progression, networking, or other gameplay systems.

**Source:** Project owner's initial brief, recorded on 2026-09-12: “a game like ragnarok online 2002 (visual wise, 2d character & 3d map).”

## Confirmed — Character and map dimensionality

| Element | Confirmed requirement |
| --- | --- |
| Characters | Presented as 2D within the game world. |
| Maps | Built and presented as 3D environments. |
| Overall appearance | Visually inspired by Ragnarok Online (2002). |

The rendering technique and the treatment of other asset categories are open decisions.

## Confirmed — Initial sprite sourcing

Use existing free sprites for the initial development stage. Custom sprite creation is deferred; no future custom-art production method or schedule has been selected.

The specific sprite packs remain unselected. Initial animation and presentation experiments will use the available assets.

**Source:** Project owner's follow-up brief, recorded on 2026-09-12: “we are not going to do our sprites right now, im going to use free ones.”

## Proposed — Art-direction interpretation

The following points are recommendations for developing the confirmed visual foundation. They are not yet approved requirements or claims about the reference game's exact implementation.

### Proposed — Character readability

- Use animated character sprites with silhouettes that remain legible at the intended gameplay camera distance.
- Favor stylized proportions and clear color groupings so characters stand out against the map.
- Use directional animation sets to communicate facing and movement. Determine the number of directions after camera behavior is chosen.
- Test characters against both light and dark map surfaces before establishing palette and contrast rules.

### Proposed — Environment treatment

- Begin with relatively simple 3D forms and stylized textures, aiming for a cohesive early-2000s-inspired appearance.
- Use geometry to convey terrain height, buildings, depth, and landmarks while keeping navigable space visually readable.
- Establish a consistent relationship between character scale, doors, paths, and environmental props.
- Keep background detail subordinate to character readability at the gameplay camera distance.

### Proposed — Integrating 2D characters with 3D maps

- Prototype textured planes or billboards for displaying 2D characters in the 3D world. Choose their orientation rules alongside the camera.
- Anchor each character image at its ground-contact point so movement, elevation changes, and animation do not make the character appear to slide or float.
- Evaluate depth testing and transparency together so characters appear correctly in front of and behind map geometry.
- Try a simple contact shadow to visually connect characters to the ground.
- Evaluate character shading against map lighting before choosing unlit, lit, or hybrid sprite rendering.

## Open — Graphics decisions

| Topic | Decision needed |
| --- | --- |
| Reference fidelity | How closely should the game match the 2002 reference, and which aspects may be modernized? |
| Reference material | Which screenshots or clips best represent the desired characters, maps, palette, and camera? |
| Camera | Fixed or rotatable? Orthographic or perspective? What angle and zoom range? |
| Initial sprite assets | Which existing free sprite packs will be used, and what animations and facing directions do they provide? |
| Sprite specification | What frame dimensions, world scale, facing directions, animation timing, and filtering rules? |
| Asset coverage | Should monsters, NPCs, vegetation, props, and effects be 2D, 3D, or mixed? |
| Environment style | What palette, texture density, geometric detail, and degree of stylization? |
| Lighting and shadows | How should characters and maps respond to lighting and cast or receive shadows? |
| Occlusion | What happens when buildings or terrain hide a character? |
| Target hardware | Which platforms, display resolutions, and performance targets should guide graphics budgets? |
| UI and effects | What visual language should interface elements and gameplay effects use? |

## Proposed — First visual prototype

Build a small graphics test scene once the camera and initial sprite approach are selected:

1. A compact 3D map with flat ground, an elevation change, and an object that can occlude a character.
2. One animated 2D character using existing free sprites, with movement and facing changes supported by the selected assets.
3. A candidate gameplay camera, representative map textures, and a simple lighting setup.
4. Light and dark background areas to evaluate character contrast.

Use the prototype to review:

- Whether the combination of 2D characters and 3D maps communicates the intended visual direction.
- Whether characters remain readable at the intended camera distance.
- Whether ground contact, facing changes, transparency, and occlusion behave coherently.
- Whether sprite detail and environment detail feel consistent.

Record approved outcomes in this document before turning them into asset-production specifications. This prototype is a proposed next step, not an implemented feature.

## Decision history

### Confirmed — Player contact shadow

The player uses a soft, circular black contact shadow instead of casting the
knight silhouette. `ContactShadow` is a horizontal, one-unit-wide plane under
the player's collision shape, 0.015 units above the current capsule bottom
(local Y = -0.9098047 for the 1.8496094-unit-tall capsule). Update this placement
if the capsule height changes. The unlit radial shader fades to transparent at
the edge; both the plane and the character sprite have shadow casting disabled.
The plane follows the character and is intended for the current flat-ground
prototype.

| Date | Status | Decision | Source |
| --- | --- | --- | --- |
| 2026-09-12 | Confirmed | Use Ragnarok Online (2002) as the visual reference, with 2D characters in 3D maps. | Project owner's initial brief. |
| 2026-09-12 | Confirmed | Use existing free sprites initially; defer custom sprite creation. | Project owner's follow-up brief. |
| 2026-09-13 | Confirmed | Replace the player's silhouette shadow with a soft circular contact shadow at its feet. | Project owner's grounding/shadow request. |
| 2026-09-13 | Confirmed | Occlusion: boundary walls use 2.2-unit-tall visual meshes with a 0.75-unit interior overhang. The overhang places a foreground wall face over the billboard at north/west faces without changing the 0.5-unit collision boundary. | Reported prototype defect + rendered visible-versus-hidden comparison. |
