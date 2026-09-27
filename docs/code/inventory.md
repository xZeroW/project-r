---
status: confirmed
---

# Inventory — Phase C, slot bag foundation

## Scope

Press **I** (`toggle_inventory`) to open a centered 20-slot bag. An item takes
exactly one slot: no stacking, quantities, or saves are part of this pass. Drag
an item to an empty cell to move it, or over a filled cell to swap the two items.
A drop outside the bag is cancelled.

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

## Equipment pass

Press **C** (`toggle_status`) for the combined character sheet. Its paper doll
has head, body, gloves, boots, weapon, off-hand, amulet, two ring, belt, and
cloak slots. Drag an item whose immutable `ItemDefinition.equipment_slot`
matches a paper-doll slot to equip it. Drag equipped items back to any bag cell
to unequip (or swap directly with that bag item). `Equipment` owns equipped
placement, while `Inventory` owns its bag mutations; both emit one change signal
per completed exchange.

`StatusPoints` remains the only writer of shared `CharacterStats`: it adds the
active equipment modifiers while recomputing base-stat derivations. The C panel
projects those live values in **Offence**, **Defence**, and **Misc** tabs. The
starter Iron Sword now occupies the weapon slot and grants +8 physical damage.

The **I**, **C**, and **P** windows have a thin drag grip at their top edge. A
window keeps its last session position when closed and restores it when reopened;
the combat hotbar remains fixed.

## Next inventory passes

1. Consumables, stack quantities, then save serialization as item ids.

## Decision history

| Date | Status | Decision | Source |
| --- | --- | --- | --- |
| 2026-09-24 | Confirmed | Phase C opens with a fixed 20-slot, non-stacking bag: every item occupies one slot and native drag-and-drop moves or swaps items. Item Resources are immutable blueprints; the Inventory component owns mutations and UI only projects state. | Owner's inventory-first request. |
| 2026-09-24 | Superseded | Monster definitions provide deterministic item drops. A killed monster spawns persistent `Area3D` pickups that collect on player contact only if Inventory has a vacant slot. | Superseded by click-to-loot correction. |
| 2026-09-24 | Confirmed | Dragging an inventory item outside its window discards it as a recoverable pickup at the player's feet; drops inside the window cancel safely. | Owner's discard correction. |
| 2026-09-27 | Confirmed | Equipment is a separate component with fixed typed paper-doll slots. Item blueprints own immutable slot/modifier data; StatusPoints remains the sole CharacterStats writer and folds equipped bonuses into its reactive derivation. | Owner's character-sheet request. |
| 2026-09-27 | Confirmed | Inventory, character, and attribute windows use a slim drag grip and retain their in-session position across close/reopen. The combat hotbar remains fixed. | Owner's movable-UI request. |
