class_name Hotbar
extends CanvasLayer
## Centered Ragnarok-style skill hotbar: 10 slots bound to the 1–0 keys.
## The bar only routes input; whether a slot holds a skill is decided by the
## consuming skill system. Empty slots render dimmed and are transparent to
## mouse clicks so they never block click-to-move; filled slots stop clicks and
## report them through the same `slot_activated` signal as the hotbar keys.

signal slot_activated(index: int)

const SLOT_COUNT := 10
const KEY_LABELS: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
const HOTBAR_ACTIONS: Array[StringName] = [
	&"hotbar_1", &"hotbar_2", &"hotbar_3", &"hotbar_4", &"hotbar_5",
	&"hotbar_6", &"hotbar_7", &"hotbar_8", &"hotbar_9", &"hotbar_0",
]

var _panel: PanelContainer
var _slots: Array[Button] = []
var _filled: Array[bool] = []

func _ready() -> void:
	_build_bar()
	for index: int in SLOT_COUNT:
		_filled.append(false)
	_refresh_slots()

func get_slot_count() -> int:
	return SLOT_COUNT

func is_slot_filled(index: int) -> bool:
	return _filled[index]

## Marks a slot as holding a skill. Empty slots are dimmed and pass clicks
## through to the world; filled slots become interactive and report clicks.
## Key presses ignore the fill state entirely — the skill system owns that rule.
func set_slot_filled(index: int, filled: bool) -> void:
	_filled[index] = filled
	_refresh_slots()

func _unhandled_input(event: InputEvent) -> void:
	for index: int in SLOT_COUNT:
		if event.is_action_pressed(HOTBAR_ACTIONS[index]) and not event.is_echo():
			_activate(index)
			get_viewport().set_input_as_handled()
			return

func _build_bar() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	margin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_bottom", 20)
	# Only the slots themselves may capture clicks; the surrounding band stays
	# click-through so the bar never blocks movement near the bottom of the screen.
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.85)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)
	_panel = panel

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	for index: int in SLOT_COUNT:
		var button := Button.new()
		button.custom_minimum_size = Vector2(48, 48)
		button.text = KEY_LABELS[index]
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_activate.bind(index))
		row.add_child(button)
		_slots.append(button)

func _activate(index: int) -> void:
	slot_activated.emit(index)

func _refresh_slots() -> void:
	for index: int in SLOT_COUNT:
		var button := _slots[index]
		button.disabled = not _filled[index]
		button.mouse_filter = Control.MOUSE_FILTER_STOP if _filled[index] else Control.MOUSE_FILTER_IGNORE