class_name EquipmentSlotControl
extends Control
## Native drag target for a fixed paper-doll equipment position.

var inventory: Inventory
var equipment: Equipment
var slot: ItemDefinition.EquipmentSlot = ItemDefinition.EquipmentSlot.NONE
var item: ItemDefinition
var _is_drag_source := false
var _background: StyleBoxFlat

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_background = StyleBoxFlat.new()
	_background.bg_color = Color(0.07, 0.055, 0.035, 0.96)
	_background.border_color = Color(0.55, 0.42, 0.22, 1.0)
	_background.set_border_width_all(2)
	_background.set_corner_radius_all(4)

func configure(owner_equipment: Equipment, owner_inventory: Inventory, equipment_slot: ItemDefinition.EquipmentSlot) -> void:
	equipment = owner_equipment
	inventory = owner_inventory
	slot = equipment_slot
	item = equipment.get_item(slot)
	tooltip_text = item.tooltip() if item != null else "%s slot" % slot_name()
	queue_redraw()

func slot_name() -> String:
	return ItemDefinition.EquipmentSlot.keys()[slot].capitalize().replace("_", " ")

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item == null:
		return null
	_is_drag_source = true
	var preview := EquipmentSlotControl.new()
	preview.custom_minimum_size = custom_minimum_size
	preview.size = custom_minimum_size
	preview.configure(equipment, inventory, slot)
	preview.modulate = Color(1, 1, 1, 0.88)
	set_drag_preview(preview)
	return {"equipment": equipment, "slot": slot}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.get("inventory") == inventory:
		var source_item := inventory.get_item(int(data.get("slot_index", -1)))
		return equipment.can_equip(source_item, slot)
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_at_position, data):
		equipment.equip_from_inventory(inventory, int(data["slot_index"]), slot)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _is_drag_source:
		_is_drag_source = false

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(_background, rect)
	if item != null and item.icon != null:
		draw_texture_rect(item.icon, rect.grow(-4), false, Color.WHITE)
	else:
		var font := get_theme_default_font()
		draw_string(font, Vector2(4, size.y * 0.56), slot_name().left(3).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, 10, Color(0.74, 0.62, 0.42, 0.9))
