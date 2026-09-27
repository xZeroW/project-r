class_name EscapeMenu
extends CanvasLayer
## Handles the multiplayer-safe Escape flow: close open windows first, then show
## a local menu. It intentionally never changes SceneTree.paused.

@export var status_ui: StatusUI
@export var attribute_ui: AttributeUI
@export var inventory_ui: InventoryUI

var _root: Control
var _resume_button: Button

func _ready() -> void:
	assert(status_ui != null, "EscapeMenu requires StatusUI.")
	assert(attribute_ui != null, "EscapeMenu requires AttributeUI.")
	assert(inventory_ui != null, "EscapeMenu requires InventoryUI.")
	_build_menu()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not _is_escape_pressed(event):
		return
	if _close_open_windows():
		get_viewport().set_input_as_handled()
		return
	if visible:
		close()
	else:
		open()
	get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	_resume_button.grab_focus()

func close() -> void:
	visible = false

func is_open() -> bool:
	return visible

func _is_escape_pressed(event: InputEvent) -> bool:
	if event is not InputEventKey:
		return false
	var key_event := event as InputEventKey
	return key_event.pressed and not key_event.echo and (key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE)

func _close_open_windows() -> bool:
	var closed_any := false
	if status_ui.is_open():
		status_ui.close()
		closed_any = true
	if attribute_ui.is_open():
		attribute_ui.close()
		closed_any = true
	if inventory_ui.is_open():
		inventory_ui.close()
		closed_any = true
	return closed_any

func _build_menu() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.02, 0.04, 0.38)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.075, 0.98)
	style.border_color = Color(0.42, 0.53, 0.7, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var title := Label.new()
	title.text = "MENU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)

	_resume_button = _make_button("Resume")
	_resume_button.pressed.connect(close)
	content.add_child(_resume_button)
	var settings_button := _make_button("Settings")
	settings_button.disabled = true
	settings_button.tooltip_text = "Settings are not available yet."
	content.add_child(settings_button)
	var quit_button := _make_button("Quit")
	quit_button.pressed.connect(_quit)
	content.add_child(quit_button)

func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 42)
	return button

func _quit() -> void:
	get_tree().quit()
