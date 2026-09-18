---
status: confirmed
---

# Code — Hotbar (Phase B)

## Confirmed — Component

`scripts/components/hotbar.gd` (`Hotbar`, a `CanvasLayer`) renders a centered
Ragnarok-style skill hotbar: **10 slots bound to the physical 1–0 keys**,
anchored to the bottom center of the screen. It is composed into
`scenes/player.tscn` (layer 15, above the health/EXP HUD, below the `StatusUI`
popup) and holds `SpellDefinition` bindings (see `docs/code/spells-mana.md`).

Layout is programmatic containers (matching `StatusUI`/`ExperienceUI`): a
`MarginContainer` (`PRESET_CENTER_BOTTOM`, 20px bottom margin) hosts a dark
rounded `PanelContainer` around an `HBoxContainer` of ten 48×48 `HotbarSlot`
controls (6px separation). Only the slots may capture mouse events; the
surrounding band is `MOUSE_FILTER_IGNORE` so the bar never blocks clicks near
the bottom of the screen. Each slot is a custom-drawn `Control`
(`scripts/components/hotbar_slot.gd`) that paints the square icon, its 1–0 key
badge, the picked highlight, and the cooldown pie.

## Confirmed — Input routing

- `project.godot` registers ten actions, `hotbar_1`…`hotbar_9` and `hotbar_0`,
  bound to physical keycodes 49–57 and 48 (the 1–0 row).
- `Hotbar._unhandled_input` scans those actions in order and emits
  `slot_activated(index)` for the matched slot, marking input handled. Keys
  ignore fill state entirely — a key press always reports the slot and the
  consuming spell caster owns "slot is empty" semantics.
- `slot_activated(index)` is the single signal consumers subscribe to (key or
  click). `player.gd` casts the bound spell via `SpellCaster.try_cast`.

## Confirmed — Casting vs Shift rearrangement

- `bind_spell(index, spell)` / `unbind_slot(index)` / `get_slot_spell(index)` /
  `is_slot_filled(index)` manage the ten-slot bindings; `swap_slots(a, b)` swaps.
- **A plain click casts:** a click on a filled slot emits `slot_activated(index)`
  and stops there (no leak into click-to-move). An empty slot is
  `MOUSE_FILTER_IGNORE` and click-through.
- **Shift is the rearrange modifier** — no lock button exists. Holding Shift on
  the press turns the click into rearrange mode: press a filled slot and drag it
  onto another — the spell icon follows the cursor as a translucent ghost and
  the hovered destination slot gets a white highlight. Dropping on an empty slot
  moves the binding; dropping on a filled slot swaps the two; releasing off the
  bar cancels. A short Shift-click (no drag) picks the spell (yellow border),
  and another Shift-click places it (empty = move, filled = swap) or cancels
  when it targets the picked slot again. Click casts clear the pick.
- Drag tracking runs in `Hotbar._input` (before GUI) so the cursor may leave the
  source slot; `_slot_at(global_pos)` resolves the drop target from slot rects.
  While a pick is active every slot becomes `MOUSE_FILTER_STOP` so Shift-clicks
  on empty targets reach the bar.

## Confirmed — Cooldown pie

`HotbarSlot.set_cooldown(fraction, seconds)` paints a dark Ragnarok-style pie
slice clockwise from 12 o'clock plus the remaining seconds. The slice's outer
edge follows the square slot's perimeter rather than an inscribed circle, so the
whole square icon darkens (reaching its corners). `Hotbar` recomputes
it on `SpellCaster.cooldowns_changed` using
`get_cooldown_remaining(spell) / get_cooldown_total(spell)`, so a short spell's
slice matches the shared global cooldown and a longer spell's slice keeps
draining after the global cooldown clears. The denominator follows whichever
timer is actually running: while a spell's own (longer) cooldown runs the slice
drains over that duration, and once only the 1s global cooldown remains the
slice sweeps a **full rotation** over the global cooldown — a spell locked only
by the global cooldown must not draw a fraction of its own longer cooldown.

## Verification

`godot --headless --path . --script res://tests/hotbar_test.gd` covers: ten
slots labelled 1–0, horizontal centering and ~20px bottom lift, default spell
bindings, key activation for 1/2/0 → slots 0/1/9, plain-click cast, empty-slot
click passthrough to click-to-move, filled-slot click capture, Shift-click
pick/place/swap/cancel (including empty slots going click-through again after
placement), and Shift-drag move / swap / off-bar cancel (asserting the ghost is
freed and no input leaks to click-to-move) — all with the SceneTree/push-input
pattern.

## Decision history

| Date | Status | Decision | Source |
| --- | --- | --- | --- |
| 2026-09-17 | Confirmed | Phase B starts with a centered 10-slot hotbar bound to physical keys 1–0. Empty slots are dimmed and transparent to clicks (never block click-to-move); keys always emit `slot_activated` regardless of fill. | Owner's hotbar brief. |
| 2026-09-17 | Confirmed | Slots hold `SpellDefinition`s and a lock button (default locked) gates rearrangement: locked = click casts, unlocked = pickup + move/swap. Cooldowns render as a clockwise pizza-slice shadow with remaining seconds. | Owner's hotbar spell/move/pie brief. |
| 2026-09-17 | Confirmed | A slot locked only by the global cooldown sweeps a full pie rotation; the pie divides by the active timer (own cooldown while it runs, otherwise the 1s global cooldown). | Owner's bug report during playtesting. |
| 2026-09-17 | Confirmed | The pizza slice's outer edge follows the square slot's perimeter (reaching the corners) rather than an inscribed circle, so the whole square icon receives the cooldown shadow. | Owner's "whole square" request. |
| 2026-09-17 | Confirmed | While unlocked, spells are drag-and-droppable between slots: a translucent ghost follows the cursor, the drop target highlights, empty = move, filled = swap, off-bar = cancel; a short click still does click-pick/place. | Owner's "draggable, drag and drop to the slot" request. |
| 2026-09-17 | Confirmed | The hotbar has no lock button. Shift is the rearrange modifier: Shift+click / Shift+drag moves, swaps, or cancels spells; a plain click always casts. | Owner's "remove the lock, shift + click to move spells" request. |
