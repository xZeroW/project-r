class_name InventorySlot
extends Control
## A single native drag-and-drop target. The parent Inventory still owns swaps.

var inventory: Inventory
var equipment: Equipment
var slot_index: int = -1
var item: ItemDefinition
var _is_drag_source: bool = false

var _background: StyleBoxFlat

signal drag_ended(index: int, succeeded: bool, screen_position: Vector2)

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_background = StyleBoxFlat.new()
	_background.bg_color = Color(0.055, 0.07, 0.11, 0.96)
	_background.border_color = Color(0.24, 0.31, 0.43, 1.0)
	_background.set_border_width_all(1)
	_background.set_corner_radius_all(4)

func configure(owner_inventory: Inventory, index: int, slot_item: ItemDefinition, owner_equipment: Equipment = null) -> void:
	inventory = owner_inventory
	equipment = owner_equipment
	slot_index = index
	item = slot_item
	tooltip_text = item.tooltip() if item != null else "Empty slot"
	queue_redraw()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item == null:
		return null
	# Godot sends DRAG_END to every Control; record the sole source before the
	# preview is created so only it can ever turn an outside release into a drop.
	_is_drag_source = true
	var preview := InventorySlot.new()
	preview.custom_minimum_size = Vector2(56, 56)
	preview.size = Vector2(56, 56)
	preview.configure(inventory, slot_index, item)
	preview.modulate = Color(1, 1, 1, 0.88)
	set_drag_preview(preview)
	return {"inventory": inventory, "slot_index": slot_index}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.get("equipment") == equipment:
		return int(data.get("slot", ItemDefinition.EquipmentSlot.NONE)) != ItemDefinition.EquipmentSlot.NONE
	return data.get("inventory") == inventory and int(data.get("slot_index", -1)) != slot_index

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_at_position, data):
		if data.has("equipment"):
			equipment.unequip_to_inventory(inventory, slot_index, data["slot"])
		else:
			inventory.move_slot(int(data["slot_index"]), slot_index)

func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END or not _is_drag_source:
		return
	_is_drag_source = false
	drag_ended.emit(slot_index, is_drag_successful(), get_viewport().get_mouse_position())

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(_background, rect)
	if item != null and item.icon != null:
		draw_texture_rect(item.icon, rect.grow(-4), false, Color.WHITE)
	var font := get_theme_default_font()
	var label := str(slot_index + 1)
	draw_string_outline(font, Vector2(5, size.y - 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 2, Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(5, size.y - 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.68, 0.75, 0.88, 0.9))
