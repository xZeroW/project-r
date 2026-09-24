---
status: confirmed
---

# Inventory — Phase C, slot bag foundation

## Scope

Press **I** (`toggle_inventory`) to open a centered 20-slot bag. An item takes
exactly one slot: no stacking, quantities, pickups, equipment effects, or saves
are part of this first pass. Drag an item to an empty cell to move it, or over a
filled cell to swap the two items. A drop outside the bag is cancelled.

## Ownership

- `ItemDefinition` is the immutable item blueprint Resource (id, name,
  description, square atlas icon).
- `Inventory` owns its fixed slot array and all moves, emitting one
  `inventory_changed` signal after a successful mutation.
- `InventoryUI` is a projection over that data: it creates the slot Controls
  once, listens to the signal, and refreshes their contents in place.
- `InventorySlot` uses Godot's native Control drag-and-drop callbacks but calls
  the owning `Inventory` for the actual swap; it never edits the slot array.

The starter Red Potion, Iron Sword, and Blue Gem use regions from the supplied
Raven Fantasy 64×64 atlas at `assets/items/raven_fantasy_icons.png`.

## Next inventory passes

1. World loot/pickups that call a capacity-aware `add_item` API.
2. Equipment slots and stat modifiers.
3. Consumables, stack quantities, then save serialization as item ids.

## Decision history

| Date | Status | Decision | Source |
| --- | --- | --- | --- |
| 2026-09-24 | Confirmed | Phase C opens with a fixed 20-slot, non-stacking bag: every item occupies one slot and native drag-and-drop moves or swaps items. Item Resources are immutable blueprints; the Inventory component owns mutations and UI only projects state. | Owner's inventory-first request. |
