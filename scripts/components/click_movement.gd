class_name ClickMovement
extends Node
## Resolves queued ground clicks in physics and follows one cached world-space path.

signal destination_changed(position: Vector3)
signal destination_cleared

@export_range(0.01, 0.5, 0.01) var arrival_distance: float = 0.08
@export_range(0.1, 5.0, 0.1) var stuck_timeout: float = 1.0
@export_flags_3d_physics var ground_pick_mask: int = 1

var _path: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _pending_click: bool = false
var _ray_origin: Vector3
var _ray_end: Vector3
var _stuck_time: float = 0.0

func request_destination(screen_position: Vector2, camera: Camera3D) -> void:
	# Capture the rendered view at click time; only the physics query is deferred.
	_ray_origin = camera.project_ray_origin(screen_position)
	_ray_end = _ray_origin + camera.project_ray_normal(screen_position) * camera.far
	_pending_click = true

func has_destination() -> bool:
	return not _path.is_empty()

func cancel() -> void:
	_pending_click = false
	_stuck_time = 0.0
	if not has_destination():
		return
	_path.clear()
	_path_index = 0
	destination_cleared.emit()

func get_direction(body: CharacterBody3D, speed: float, delta: float) -> Vector3:
	if _pending_click:
		_resolve_click(body)
	while _path_index < _path.size():
		var offset := _path[_path_index] - body.global_position
		offset.y = 0.0
		if offset.length() <= arrival_distance:
			_path_index += 1
			continue
		# Shorten the final step rather than overshooting and circling a waypoint.
		return offset.normalized() * minf(1.0, offset.length() / maxf(speed * delta, 0.001))
	cancel()
	return Vector3.ZERO

func record_motion(displacement: Vector3, delta: float) -> void:
	if not has_destination():
		return
	if Vector2(displacement.x, displacement.z).length_squared() < 0.000001:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	if _stuck_time >= stuck_timeout:
		cancel()

func _resolve_click(body: CharacterBody3D) -> void:
	_pending_click = false
	var query := PhysicsRayQueryParameters3D.create(_ray_origin, _ray_end, ground_pick_mask, [body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	var collider := hit.get("collider") as Node
	if collider == null or not collider.is_in_group(&"walkable_ground"):
		return
	var clicked_position: Vector3 = hit["position"]
	var navigation_map := body.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(navigation_map) == 0:
		return
	if not NavigationServer3D.map_get_closest_point_owner(navigation_map, clicked_position).is_valid():
		return
	var target := NavigationServer3D.map_get_closest_point(navigation_map, clicked_position)
	# Permit small edge adjustments for body clearance, not distant/off-floor snaps.
	# The baked walkable surface sits about half a unit above the floor, so the
	# vertical tolerance must swallow that floor offset separately from horizontal snap.
	var horizontal_gap := Vector2(target.x - clicked_position.x, target.z - clicked_position.z).length()
	if horizontal_gap > 0.75 or absf(target.y - clicked_position.y) > 0.75:
		return
	var path := NavigationServer3D.map_get_path(navigation_map, body.global_position, target, true)
	if path.is_empty() or path[path.size() - 1].distance_to(target) > 0.1:
		return
	_path = path
	_path_index = 0
	_stuck_time = 0.0
	destination_changed.emit(Vector3(target.x, clicked_position.y, target.z))
