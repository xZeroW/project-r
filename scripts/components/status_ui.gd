class_name StatusUI
extends CanvasLayer
## Toggleable stat-allocation panel, signal-driven from StatusPoints.

@export var status_points: StatusPoints

var _panel: PanelContainer
var _points_label: Label
var _labels: Dictionary[StatusPoints.Stat, Label] = {}
var _buttons: Dictionary[StatusPoints.Stat, Button] = {}

func _ready() -> void:
	assert(status_points != null, "StatusUI requires a StatusPoints component.")
	_build_panel()
	_panel.visible = false
	status_points.points_remaining_changed.connect(_refresh.unbind(1))
	status_points.allocated.connect(_refresh.unbind(1))
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_status") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	_panel.visible = not _panel.visible

func is_open() -> bool:
	return _panel.visible

func _build_panel() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margin.grow_vertical = Control.GROW_DIRECTION_END
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	add_child(margin)
	var panel := PanelContainer.new()
	# STOP keeps clicks inside the panel from leaking into click-to-move/combat.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.94)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	_points_label = _add_label(column, Color(0.85, 0.9, 1))
	_points_label.add_theme_font_size_override("font_size", 18)
	for stat: StatusPoints.Stat in StatusPoints.Stat.values():
		column.add_child(_build_stat_row(stat))
	_panel = panel

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
	button.pressed.connect(_allocate.bind(stat))
	_buttons[stat] = button
	row.add_child(button)
	return row

func _allocate(stat: StatusPoints.Stat) -> void:
	status_points.allocate(stat)

func _add_label(parent: Control, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label

func _refresh() -> void:
	_points_label.text = "STATUS  —  %d points  (C toggle)" % status_points.get_points_remaining()
	for stat: StatusPoints.Stat in StatusPoints.Stat.values():
		_labels[stat].text = "%s  %d" % [status_points.stat_name(stat), status_points.get_value(stat)]
		_buttons[stat].disabled = status_points.get_points_remaining() <= 0