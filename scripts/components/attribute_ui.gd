class_name AttributeUI
extends CanvasLayer
## Dedicated base-stat distribution panel. The character sheet remains a read-only
## equipment/derived-stat projection; this panel owns only allocation input.

@export var status_points: StatusPoints

var _panel: PanelContainer
var _window: Control
var _saved_position := Vector2.ZERO
var _has_saved_position := false
var _points_label: Label
var _labels: Dictionary[StatusPoints.Stat, Label] = {}
var _buttons: Dictionary[StatusPoints.Stat, Button] = {}

func _ready() -> void:
	assert(status_points != null, "AttributeUI requires a StatusPoints component.")
	_build_panel()
	_panel.visible = false
	status_points.points_remaining_changed.connect(_refresh)
	status_points.allocated.connect(_refresh.unbind(1))
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_attributes") and not event.is_echo():
		if _panel.visible:
			_save_window_position()
			_has_saved_position = true
			_panel.visible = false
		else:
			_panel.visible = true
			if _has_saved_position:
				_restore_window_position()
		get_viewport().set_input_as_handled()

func is_open() -> bool:
	return _panel.visible

func close() -> void:
	if _panel.visible:
		_save_window_position()
		_has_saved_position = true
		_panel.visible = false

func _save_window_position() -> void:
	_saved_position = _panel.get_global_rect().position

func _restore_window_position() -> void:
	# This window starts top-right anchored, so assigning its saved layout
	# origin directly would align the right edge to its former left edge.
	_window.global_position += _saved_position - _panel.get_global_rect().position

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.96)
	style.border_color = Color(0.42, 0.53, 0.7, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	_window = _panel
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)
	var drag_handle := WindowDragHandle.new()
	drag_handle.configure(_window)
	column.add_child(drag_handle)
	_points_label = _add_label(column, Color(0.85, 0.9, 1.0))
	_points_label.add_theme_font_size_override("font_size", 18)
	for stat: StatusPoints.Stat in StatusPoints.Stat.values():
		column.add_child(_build_stat_row(stat))
	_place_initial_window.call_deferred()

func _place_initial_window() -> void:
	# Use a stable top-left coordinate system after content has established the
	# panel size. The former top-right-anchored wrapper changed coordinate edges
	# whenever it was shown again.
	var viewport_size := get_viewport().get_visible_rect().size
	_panel.position = Vector2(viewport_size.x - _panel.size.x - 24.0, 24.0)

func _build_stat_row(stat: StatusPoints.Stat) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := _add_label(row, Color.WHITE)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_labels[stat] = label
	var button := Button.new()
	button.text = "+"
	button.custom_minimum_size = Vector2(34, 30)
	button.focus_mode = Control.FOCUS_NONE
	button.gui_input.connect(_on_stat_button_input.bind(stat))
	_buttons[stat] = button
	row.add_child(button)
	return row

func _on_stat_button_input(event: InputEvent, stat: StatusPoints.Stat) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var amount := 5 if mouse_event.ctrl_pressed else status_points.get_points_remaining() if mouse_event.shift_pressed else 1
			for _index in amount:
				if not status_points.allocate(stat):
					break

func _add_label(parent: Control, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label

func _refresh(_remaining: int = 0) -> void:
	_points_label.text = "ATTRIBUTES  —  %d points  (P toggle)" % status_points.get_points_remaining()
	for stat: StatusPoints.Stat in StatusPoints.Stat.values():
		_labels[stat].text = "%s  %d" % [status_points.stat_name(stat), status_points.get_value(stat)]
		_buttons[stat].disabled = status_points.get_points_remaining() <= 0
