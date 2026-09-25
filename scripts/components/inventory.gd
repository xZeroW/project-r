class_name Inventory
extends Node
## Fixed-size, non-stacking slot bag. It owns every slot mutation; UI only asks
## it to move items and redraws after the resulting signal.

signal inventory_changed
signal item_dropped(item: ItemDefinition)

@export_range(1, 60, 1) var slot_count: int = 20
@export var initial_items: Array[ItemDefinition] = []

var _slots: Array[ItemDefinition] = []

func _ready() -> void:
	_slots.resize(slot_count)
	for index: int in mini(initial_items.size(), slot_count):
		_slots[index] = initial_items[index]
	inventory_changed.emit()

func get_slot_count() -> int:
	return _slots.size()

func get_item(index: int) -> ItemDefinition:
	return _slots[index] if _is_valid_index(index) else null

func move_slot(from: int, to: int) -> void:
	if not _is_valid_index(from) or not _is_valid_index(to) or from == to or _slots[from] == null:
		return
	var moved_item := _slots[from]
	_slots[from] = _slots[to]
	_slots[to] = moved_item
	inventory_changed.emit()

## Adds one non-stacking item to the first vacant slot. Returns false without
## changing state when the bag is full, so a world pickup can remain available.
func try_add_item(item: ItemDefinition) -> bool:
	if item == null:
		return false
	for index: int in _slots.size():
		if _slots[index] == null:
			_slots[index] = item
			inventory_changed.emit()
			return true
	return false

func is_full() -> bool:
	return not _slots.has(null)

## Removes one item for a deliberate world drop. The player orchestrator listens
## for the item payload and creates the pickup; Inventory never needs a world ref.
func drop_slot(index: int) -> void:
	if not _is_valid_index(index) or _slots[index] == null:
		return
	var dropped_item := _slots[index]
	_slots[index] = null
	inventory_changed.emit()
	item_dropped.emit(dropped_item)

func _is_valid_index(index: int) -> bool:
	return index >= 0 and index < _slots.size()
