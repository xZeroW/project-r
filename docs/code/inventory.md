---
status: confirmed
---

# Inventory — Phase C, slot bag foundation

## Scope

Press **I** (`toggle_inventory`) to open a centered 20-slot bag. An item takes
exactly one slot: no stacking, quantities, equipment effects, or saves are part
of this pass. Drag an item to an empty cell to move it, or over a filled cell to
swap the two items. A drop outside the bag is cancelled.

Monster definitions now list deterministic `loot_items`: every listed item
becomes a floating `ItemPickup` with a Path-of-Exile-style billboard name label
at the death position. **Click its label/icon** to path to the drop; it is added
to the first vacant inventory slot only on arrival. Simply walking over a drop
never collects it. If the bag is full, the click does nothing and the pickup
remains in the world. Poring drops a Red Potion; Poporing drops a Blue Gem.

To discard an item, drag it **outside the inventory window**. The item leaves
that slot and becomes a labelled world pickup at the player's feet, so it is
never silently destroyed and can be clicked to recover later. Releasing in the
window but outside a slot safely cancels the drag.

## Ownership

- `ItemDefinition` is the immutable item blueprint Resource (id, name,
  description, square atlas icon).
- `Inventory` owns its fixed slot array and all moves/additions, emitting one
  `inventory_changed` signal after a successful mutation.
- `InventoryUI` is a projection over that data: it creates the slot Controls
  once, listens to the signal, and refreshes their contents in place.
- `InventorySlot` uses Godot's native Control drag-and-drop callbacks but calls
  the owning `Inventory` for the actual swap; it never edits the slot array.
- `InventorySlot` detects an unsuccessful drag released outside the inventory
  panel and reports the drag lifecycle without referencing `InventoryUI`.
  `InventoryUI` applies the outside-window policy and requests
  `Inventory.drop_slot`; the world-owned `ItemPickupSpawner` turns that signal
  into a world pickup.

The starter Red Potion, Iron Sword, and Blue Gem use regions from the supplied
Raven Fantasy 64×64 atlas at `assets/items/raven_fantasy_icons.png`.

## Next inventory passes

1. Equipment slots and stat modifiers.
2. Consumables, stack quantities, then save serialization as item ids.

## Decision history

| Date | Status | Decision | Source |
| --- | --- | --- | --- |
| 2026-09-24 | Confirmed | Phase C opens with a fixed 20-slot, non-stacking bag: every item occupies one slot and native drag-and-drop moves or swaps items. Item Resources are immutable blueprints; the Inventory component owns mutations and UI only projects state. | Owner's inventory-first request. |
| 2026-09-24 | Superseded | Monster definitions provide deterministic item drops. A killed monster spawns persistent `Area3D` pickups that collect on player contact only if Inventory has a vacant slot. | Superseded by click-to-loot correction. |
| 2026-09-24 | Confirmed | Dragging an inventory item outside its window discards it as a recoverable pickup at the player's feet; drops inside the window cancel safely. | Owner's discard correction. |
