class_name ExperienceUI
extends CanvasLayer
## Signal-driven, click-through Base Level HUD.

@export var experience: Experience

var _level_label: Label
var _exp_label: Label
var _bar: ProgressBar
var _notice: Label
var _notice_timer: Timer

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 280
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	_notice = _add_label(column, Color(1, 0.85, 0.35))
	_level_label = _add_label(column, Color.WHITE)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size.y = 12
	_bar.show_percentage = false
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_bar)
	_exp_label = _add_label(column, Color(0.75, 0.9, 1))
	_notice_timer = Timer.new()
	_notice_timer.one_shot = true
	_notice_timer.wait_time = 2.5
	_notice_timer.timeout.connect(func() -> void: _notice.text = "")
	add_child(_notice_timer)
	experience.progression_changed.connect(_refresh)
	experience.experience_gained.connect(_on_experience_gained)
	experience.leveled_up.connect(_on_leveled_up)
	_refresh()

func _add_label(parent: Control, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label

func _refresh() -> void:
	_level_label.text = "Base Lv. %d" % experience.level
	_bar.max_value = maxi(1, experience.get_required_experience())
	_bar.value = _bar.max_value if experience.is_max_level() else experience.current_experience
	_exp_label.text = "MAX LEVEL" if experience.is_max_level() else "Base EXP  %d / %d" % [experience.current_experience, experience.get_required_experience()]

func _on_experience_gained(amount: int) -> void:
	_notice.text = "+%d Base EXP" % amount
	_notice_timer.start()

func _on_leveled_up(level: int) -> void:
	_notice.text = "LEVEL UP!  Base Lv. %d" % level
	_notice_timer.start()
