class_name Targeting
extends Node
## Owns a selected enemy and a periodically refreshed pursuit path.

var target: MeleeCombat
var _path: PackedVector3Array = PackedVector3Array()
var _index: int = 0
var _refresh: float = 0.0
var _stuck: float = 0.0
var _pursuing: bool = false
var _label: Label
var _indicator: TargetIndicator

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 11
	add_child(layer)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.hide()
	layer.add_child(_label)
	_indicator = TargetIndicator.new()
	_indicator.name = "TargetIndicator"
	_indicator.hide()
	add_child(_indicator)
	# Project after the follow camera has updated for this render frame.
	process_priority = 100

func select(enemy: MeleeCombat) -> void:
	cancel()
	if is_instance_valid(enemy) and enemy.damage_enabled and enemy.stats.current_health > 0.0:
		target = enemy

func cancel() -> void:
	target = null
	_path.clear()
	_index = 0
	_refresh = 0.0
	_stuck = 0.0
	_pursuing = false
	if is_instance_valid(_label):
		_label.hide()
	if is_instance_valid(_indicator):
		_indicator.hide()

func has_target() -> bool:
	return is_instance_valid(target) and target.damage_enabled and target.stats.current_health > 0.0

func _process(_delta: float) -> void:
	if not has_target():
		cancel()
		return
	var camera := get_viewport().get_camera_3d()
	var position := target.body.get_global_transform_interpolated().origin + Vector3.UP * 1.4
	_label.visible = camera != null and not camera.is_position_behind(position)
	_indicator.visible = _label.visible
	if _label.visible:
		var ground_position := target.body.get_global_transform_interpolated().origin
		var shadow := target.body.get_node_or_null("CollisionShape3D/ContactShadow") as Node3D
		if shadow != null:
			ground_position = shadow.get_global_transform_interpolated().origin
		_indicator.place_at(ground_position)
		_label.text = "TARGET  %d / %d" % [target.stats.current_health, target.stats.max_health]
		_label.position = camera.unproject_position(position) - Vector2(_label.size.x * 0.5, 0)

func get_direction(combat: MeleeCombat, speed: float, delta: float) -> Vector3:
	_pursuing = false
	if not has_target() or combat.stats.current_health <= 0.0:
		cancel()
		return Vector3.ZERO
	if combat.can_reach(target):
		_stuck = 0.0
		_refresh = 0.0
		combat.attack(target)
		if not has_target():
			cancel()
		return Vector3.ZERO
	_pursuing = true
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.2
		var map := combat.body.get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(map) == 0:
			return Vector3.ZERO
		var destination := NavigationServer3D.map_get_closest_point(map, target.body.global_position)
		if not NavigationServer3D.map_get_closest_point_owner(map, destination).is_valid():
			cancel()
			return Vector3.ZERO
		_path = NavigationServer3D.map_get_path(map, combat.body.global_position, destination, true)
		_index = 0
		if _path.is_empty() or _path[_path.size() - 1].distance_to(destination) > 0.1:
			cancel()
			return Vector3.ZERO
	while _index < _path.size():
		var offset := (_path[_index] - combat.body.global_position) * Vector3(1, 0, 1)
		if offset.length() < 0.1:
			_index += 1
		else:
			return offset.normalized() * minf(1.0, offset.length() / maxf(speed * delta, 0.001))
	return Vector3.ZERO

func record_motion(displacement: Vector3, delta: float) -> void:
	if not _pursuing:
		return
	_stuck = _stuck + delta if Vector2(displacement.x, displacement.z).length_squared() < 0.000001 else 0.0
	if _stuck >= 1.0:
		cancel()
