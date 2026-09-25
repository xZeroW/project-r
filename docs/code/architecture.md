---
id: code-architecture
title: Code — Architecture
status: active
tags:
  - code
  - architecture
  - godot
  - gdscript
  - composition
  - rust
  - bevy
created: 2026-09-12
updated: 2026-09-24
---

# Code — Architecture

## Confirmed — Initial technology direction

The game will use **Godot with GDScript**, with **composition as the guiding code-design approach**.

Develop the initial game systems in GDScript. Build behavior by combining focused pieces rather than organizing the game primarily around deep inheritance hierarchies.

**Source:** Project owner's code-direction brief, recorded on 2026-09-12: “first we are going to use gdscript with composition in mind,” followed by possible future Rust or Bevy integration for Godot.

## Confirmed — Conditional future technology options

Rust may be evaluated later if needed. A Bevy plugin or integration for Godot is also a possible future experiment.

These are conditional options, not scheduled migrations or initial dependencies. The need for either option, its scope, and its integration mechanism remain undecided. No particular Bevy–Godot plugin has been selected or validated.

**Source:** Project owner's code-direction brief, recorded on 2026-09-12: “later on, if needed, we can try Rust or even Bevy plugin for godot.”

## Proposed — Composition in Godot

The following conventions are recommendations for implementing the confirmed composition-first direction:

- **Compose entities from focused behaviors.** Use child nodes or reusable scenes for behaviors that need scene-tree participation, such as movement or visual presentation.
- **Keep lightweight logic lightweight.** Use plain GDScript objects for logic that does not need node lifecycle callbacks or scene-tree access.
- **Separate configuration from runtime state.** Use Resources for reusable definitions where appropriate, while keeping per-entity mutable state isolated. Shared Resources should not accidentally share an entity's changing state.
- **Make dependencies explicit.** Let an owning scene or coordinator connect its components through references and small, clear APIs.
- **Use signals for event notifications.** Prefer direct method calls for explicit commands; use signals when a component announces something that happened.
- **Keep gameplay and presentation distinct.** Gameplay state should not depend on a particular sprite sheet, allowing the initial free sprites to be replaced later.
- **Use inheritance selectively.** Extending Godot's built-in classes is normal; prefer composition for combining reusable gameplay capabilities.

Composition does not require a custom entity-component-system framework. Godot nodes, scenes, Resources, and GDScript objects are candidate building blocks; their exact organization remains to be established through implementation.

## Confirmed — Runtime ownership boundaries

- Entity roots orchestrate their own components through typed references and
  signals. Components do not depend on parent scripts or mutate sibling state.
- `WorldInteraction` owns physics-safe click classification; `ClickMovement`
  owns navigation paths only, while `Targeting` owns combat pursuit.
- Monsters emit loot intent without knowing the player's inventory or world
  hierarchy. The world composition root connects those events to one
  `ItemPickupSpawner`, which owns pickup creation and dependency injection.
- Inventory slot Controls emit drag lifecycle events. `InventoryUI` owns window
  boundary policy, and `Inventory` alone mutates slot contents.
- The existing `scripts/components`, `resources/<domain>`, and `scenes` layout
  remains the project convention until a larger feature-folder migration has a
  concrete benefit; isolated churn is avoided.

## Proposed — Example responsibility split

A first controllable character could combine these responsibilities:

| Piece | Responsibility |
| --- | --- |
| Character root / coordinator | Connect components and own the character's scene-level lifecycle. |
| Input component | Translate player input into movement intent. |
| Movement component | Apply movement intent through the character's physics body. |
| Visual component | Display the selected free sprites and update facing and animation from character state. |

This is an illustrative design, not a committed scene tree or class API. Choose concrete node types when the movement and physics requirements are known.

## Proposed — Evaluating Rust or Bevy later

1. Identify a concrete need, such as a measured performance bottleneck or a capability that is difficult to support in the current implementation.
2. Evaluate whether a focused GDScript or Godot-side change addresses it.
3. If native code is justified, prototype a small Rust module behind a defined interface. GDExtension with suitable Rust bindings is one candidate, subject to the selected Godot version and target platforms.
4. If Bevy is relevant, separately investigate a specific Godot integration and validate compatibility, maintenance, data exchange, and ownership of simulation updates.
5. Record the results and an explicit adoption decision before expanding the integration.

Bevy is a Rust engine/framework, not a drop-in GDScript replacement. Its use inside a Godot project would require an integration layer. Rust adoption alone does not require Bevy.

## Open — Implementation decisions

| Topic | Decision needed |
| --- | --- |
| Godot version | Which version will the project target? |
| Renderer | Which Godot renderer and rendering features will support the visual direction and target platforms? |
| GDScript conventions | What typing, naming, formatting, and static-checking rules will be used? |
| Project organization | How will scenes, components, resources, and feature code be arranged? |
| Component contracts | How will dependencies, initialization, and cleanup be handled? |
| Verification | Which automated checks and gameplay tests will support the initial systems? |
| Native integration | What concrete need would justify Rust or Bevy, and which integration would satisfy it? |

## Related documentation

- [Graphics — Visual Direction](../graphics/visual-direction.md): 2D characters, 3D maps, and the initial use of free sprites.

## Decision history

| Date | Status | Decision | Source |
| --- | --- | --- | --- |
| 2026-09-12 | Confirmed | Start with Godot and GDScript, using composition as the guiding design approach. | Project owner's code-direction brief. |
| 2026-09-12 | Confirmed | Keep Rust and a possible Bevy integration as conditional future options. | Project owner's code-direction brief. |
| 2026-09-24 | Confirmed | Separate click classification from path following; centralize pickup construction in a world-owned spawner; use signals for monster loot and inventory drag boundaries. | Code-organization audit and remediation. |
