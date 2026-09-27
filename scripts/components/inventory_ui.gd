class_name InventoryUI
extends CanvasLayer
## Toggleable fixed-slot bag window. Slot widgets are built once and updated in
## place when Inventory emits its one batch-safe change signal.

const COLUMNS := 5
const SLOT_SIZE := Vector2(56, 56)

@export var inventory: Inventory
@export var equipment: Equipment

var _panel: PanelContainer
var _window: MarginContainer
var _saved_position := Vector2.ZERO
var _has_saved_position := false
var _slots: Array[InventorySlot] = []

func _ready() -> void:
	assert(inventory != null, "InventoryUI requires an Inventory.")
	_build_window()
	inventory.inventory_changed.connect(_refresh_slots)
	_refresh_slots()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_inventory") and not event.is_echo():
		if visible:
			_saved_position = _window.global_position
			_has_saved_position = true
			visible = false
		else:
			visible = true
			if _has_saved_position:
				_window.global_position = _saved_position
		get_viewport().set_input_as_handled()

func is_open() -> bool:
	return visible

func close() -> void:
	if visible:
		_saved_position = _window.global_position
		_has_saved_position = true
		visible = false

func _build_window() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	margin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	margin.grow_vertical = Control.GROW_DIRECTION_BOTH
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	_window = margin

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.075, 0.96)
	style.border_color = Color(0.42, 0.53, 0.7, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	margin.add_child(_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_panel.add_child(content)
	var drag_handle := WindowDragHandle.new()
	drag_handle.configure(_window)
	content.add_child(drag_handle)
	var title := Label.new()
	title.text = "INVENTORY"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	content.add_child(grid)
	for index: int in inventory.get_slot_count():
		var slot := InventorySlot.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.drag_ended.connect(_on_slot_drag_ended)
		grid.add_child(slot)
		_slots.append(slot)

func _refresh_slots() -> void:
	for index: int in _slots.size():
		_slots[index].configure(inventory, index, inventory.get_item(index), equipment)

func _on_slot_drag_ended(index: int, succeeded: bool, screen_position: Vector2) -> void:
	if not succeeded and not _panel.get_global_rect().has_point(screen_position):
		inventory.drop_slot(index)
