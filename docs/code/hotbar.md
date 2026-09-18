---
status: confirmed
---

# Code — Hotbar (Phase B shell)

## Confirmed — Component

`scripts/components/hotbar.gd` (`Hotbar`, a `CanvasLayer`) renders a centered
Ragnarok-style skill hotbar: **10 slots bound to the physical 1–0 keys**,
anchored to the bottom center of the screen. It is composed into
`scenes/player.tscn` (layer 15, above the health/EXP HUD, below the `StatusUI`
popup) and currently holds no skills — it is the input shell Phase B's bolt/heal
will populate.

Layout is programmatic containers (matching `StatusUI`/`ExperienceUI`): a
`MarginContainer` (`PRESET_CENTER_BOTTOM`, 20px bottom margin) hosts a dark
rounded `PanelContainer` around an `HBoxContainer` of ten 48×48 `Button` slots
(6px separation). Only the slots may capture mouse events; the surrounding band
is `MOUSE_FILTER_IGNORE` so the bar never blocks clicks near the bottom of the
screen.

## Confirmed — Input routing

- `project.godot` registers ten actions, `hotbar_1`…`hotbar_9` and `hotbar_0`,
  bound to physical keycodes 49–57 and 48 (the 1–0 row).
- `Hotbar._unhandled_input` scans those actions in order and emits
  `slot_activated(index)` for the matched slot, marking input handled. Keys
  ignore fill state entirely — a key press always reports the slot and the
  consuming skill system owns "slot is empty" semantics.
- `slot_activated(index)` is the single signal consumers subscribe to (key or
  click). No skill caster exists yet; `player.gd` wiring is Phase B follow-up.

## Confirmed — Slot state

- All slots start empty. Empty slots render the `Button` disabled (dimmed) with
  `MOUSE_FILTER_IGNORE`, so clicking one passes straight through to
  click-to-move/combat.
- `Hotbar.set_slot_filled(index, filled)` flips a slot to interactive:
  `MOUSE_FILTER_STOP`, enabled, and clickable — a filled-slot click emits
  `slot_activated` and never leaks into world input.
- `get_slot_count()` / `is_slot_filled(index)` expose the state for tests and
  the future skill system.

## Verification

`godot --headless --path . --script res://tests/hotbar_test.gd` covers: ten
slots labelled 1–0, horizontal centering and ~20px bottom lift, key activation
for 1/2/0 → slots 0/1/9, empty-slot click passthrough to click-to-move, and
filled-slot click capture — all with the SceneTree/push-input pattern.

## Decision history

| Date | Status | Decision | Source |
| --- | --- | --- | --- |
| 2026-09-17 | Confirmed | Phase B starts with a centered 10-slot hotbar bound to physical keys 1–0. Empty slots are dimmed and transparent to clicks (never block click-to-move); keys always emit `slot_activated` regardless of fill; filled slots are interactive and stop clicks. Slots hold no skills yet — bolt/heal wiring is the next step. | Owner's hotbar brief. |