class_name HealthBarUI
extends CanvasLayer
## Projects a character health bar into screen-space UI.

@export var stats: CharacterStats
@export var target_path: NodePath
@export var world_offset: Vector3

@onready var _target: Node3D = get_node(target_path)
@onready var _bar: Control = %Bar
@onready var _fill: ColorRect = %Fill

var _last_health: float = -1.0

func _ready() -> void:
	assert(stats != null, "HealthBarUI requires character stats.")
	_update_fill()

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not is_instance_valid(_target):
		_bar.visible = false
		return

	var render_position := _target.get_global_transform_interpolated().origin + world_offset
	_bar.visible = not camera.is_position_behind(render_position)
	if _bar.visible:
		_bar.position = camera.unproject_position(render_position)
		_bar.position -= _bar.size * 0.5
	if not is_equal_approx(stats.current_health, _last_health):
		_update_fill()

func _update_fill() -> void:
	_last_health = stats.current_health
	var health_ratio := 0.0 if stats.max_health <= 0.0 else clampf(stats.current_health / stats.max_health, 0.0, 1.0)
	_fill.size.x = 60.0 * health_ratio
