class_name HealthBarUI
extends CanvasLayer
## Projects a character health bar into screen-space UI.

@export var stats: CharacterStats
@export var target_path: NodePath
@export var world_offset: Vector3

@onready var _target: Node3D = get_node(target_path)
@onready var _bar: Control = get_node_or_null("%Bar") as Control
@onready var _fill: ColorRect = %Fill
@onready var _mana_bar: Control = get_node_or_null("%ManaBar") as Control
@onready var _mana_fill: ColorRect = get_node_or_null("%ManaFill") as ColorRect

var _mana_relative := Vector2.ZERO

const BAR_FILL_WIDTH := 60.0

func _ready() -> void:
	assert(stats != null, "HealthBarUI requires character stats.")
	if _bar == null:
		_bar = get_node("%HealthBar") as Control
	assert(_bar != null, "HealthBarUI requires a health-bar anchor (%Bar or %HealthBar).")
	if _mana_bar != null:
		_mana_relative = _mana_bar.position - _bar.position
	stats.stat_changed.connect(_on_stats_changed)
	_update_fill()
	_update_mana_fill()

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not is_instance_valid(_target):
		_bar.visible = false
		if _mana_bar != null:
			_mana_bar.visible = false
		return

	var render_position := _target.get_global_transform_interpolated().origin + world_offset
	var behind := camera.is_position_behind(render_position)
	_bar.visible = not behind
	if _mana_bar != null:
		_mana_bar.visible = not behind
	if not behind:
		var anchor := camera.unproject_position(render_position) - _bar.size * 0.5
		_bar.position = anchor
		if _mana_bar != null:
			_mana_bar.position = anchor + _mana_relative

func _on_stats_changed(property: StringName) -> void:
	if property == &"current_health" or property == &"max_health":
		_update_fill()
	elif property == &"mana" or property == &"max_mana":
		_update_mana_fill()

func _update_fill() -> void:
	var health_ratio := 0.0 if stats.max_health <= 0.0 else clampf(stats.current_health / stats.max_health, 0.0, 1.0)
	_fill.size.x = BAR_FILL_WIDTH * health_ratio

func _update_mana_fill() -> void:
	if _mana_fill == null:
		return
	var mana_ratio := 0.0 if stats.max_mana <= 0.0 else clampf(stats.mana / stats.max_mana, 0.0, 1.0)
	_mana_fill.size.x = BAR_FILL_WIDTH * mana_ratio
