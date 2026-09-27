class_name Equipment
extends Node
## Owns equipped item placement. Inventory owns bag slots; equipment only asks it
## to replace a source bag slot during an equip swap.

signal equipment_changed

var _items: Dictionary[ItemDefinition.EquipmentSlot, ItemDefinition] = {}

func get_item(slot: ItemDefinition.EquipmentSlot) -> ItemDefinition:
	return _items.get(slot)

func can_equip(item: ItemDefinition, slot: ItemDefinition.EquipmentSlot) -> bool:
	return item != null and item.equipment_slot == slot and slot != ItemDefinition.EquipmentSlot.NONE

func equip_from_inventory(inventory: Inventory, inventory_index: int, slot: ItemDefinition.EquipmentSlot) -> bool:
	var item := inventory.get_item(inventory_index)
	if not can_equip(item, slot):
		return false
	var replaced_item := get_item(slot)
	inventory.replace_slot(inventory_index, replaced_item)
	_items[slot] = item
	equipment_changed.emit()
	return true

func unequip_to_inventory(inventory: Inventory, inventory_index: int, slot: ItemDefinition.EquipmentSlot) -> bool:
	var item := get_item(slot)
	if item == null:
		return false
	var replaced_item := inventory.replace_slot(inventory_index, item)
	if replaced_item == null:
		_items.erase(slot)
	else:
		_items[slot] = replaced_item
	equipment_changed.emit()
	return true

## A single read-only stat query keeps item Resources immutable and lets the
## StatusPoints component remain the sole writer of CharacterStats.
func get_bonus(property: StringName) -> float:
	var total := 0.0
	for item: ItemDefinition in _items.values():
		total += float(item.get(property))
	return total
