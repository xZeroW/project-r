extends SceneTree
## Click input, physics picking, navigation, and feedback against the playable map.

var failures: int = 0
var world: Node3D
var player: CharacterBody3D
var camera: Camera3D
var navigation: ClickMovement
var marker: DestinationMarker
var sprite: DirectionalSprite

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _tick(count: int = 1) -> void:
	for tick in range(count):
		await physics_frame
		await process_frame

func _click_screen(position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.device = InputEvent.DEVICE_ID_MOUSE
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		root.push_input(event, true)

func _click_ground(destination: Vector3) -> void:
	_click_screen(camera.unproject_position(destination))

func _horizontal_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x - second.x, first.z - second.z).length()

func _reset_player(position: Vector3) -> void:
	navigation.cancel()
	for action in [&"move_left", &"move_right", &"move_up", &"move_down", &"rotate_camera_left", &"rotate_camera_right"]:
		Input.action_release(action)
	player.position = position
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	await _tick(20)

func _wait_for_arrival(destination: Vector3, max_ticks: int = 300) -> void:
	for tick in range(max_ticks):
		if not navigation.has_destination():
			break
		await _tick()
	await _tick(3)
	_check(not navigation.has_destination(), "The player must clear its destination on arrival.")
	_check(_horizontal_distance(player.global_position, destination) < 0.15, "The player must reach the selected destination.")
	_check(not marker.visible, "The destination marker must disappear on arrival.")
	_check(Vector2(player.velocity.x, player.velocity.z).is_zero_approx(), "The player must stop at the destination.")
	_check(String(sprite.animation).begins_with("idle_"), "Arrival must restore the idle animation.")

func _check_obstacle_detour() -> void:
	await _reset_player(Vector3(-7, 0.02, -3))
	var destination := Vector3(-1, 0, -3)
	_click_ground(destination)
	await _tick(2)
	_check(navigation.has_destination() and marker.visible, "A ground click must start a route and show its marker.")
	_check(_horizontal_distance(marker.global_position, destination) < 0.1, "The marker must identify the selected ground point.")
	var marker_position := marker.global_position
	var largest_detour: float = 0.0
	var walked: bool = false
	for tick in range(300):
		if not navigation.has_destination():
			break
		await _tick()
		largest_detour = maxf(largest_detour, absf(player.position.z + 3.0))
		walked = walked or String(sprite.animation).begins_with("walk_")
		_check(marker.global_position.is_equal_approx(marker_position), "The destination marker must stay fixed while the player and camera move.")
	_check(largest_detour > 1.3, "The route must go around the tall block instead of walking straight into it.")
	_check(walked, "Following a click route must play the walking animation.")
	await _wait_for_arrival(destination)

func _check_replacement_and_manual_override() -> void:
	await _reset_player(Vector3(0, 0.02, 4))
	_click_ground(Vector3(4, 0, 5))
	await _tick(5)
	var replacement := Vector3(-4, 0, 5)
	_click_ground(replacement)
	await _tick(2)
	_check(_horizontal_distance(marker.global_position, replacement) < 0.1, "A second click must replace the previous destination.")
	await _wait_for_arrival(replacement)
	_click_ground(Vector3(2, 0, 5))
	await _tick(5)
	Input.action_press("move_left")
	await _tick(3)
	_check(not navigation.has_destination() and not marker.visible, "WASD must cancel the click route and marker.")
	Input.action_release("move_left")
	await _tick(3)
	var stopped := player.global_position
	await _tick(15)
	_check(player.global_position.distance_to(stopped) < 0.01, "Releasing WASD must not resume the canceled route.")

func _check_invalid_and_ui_clicks() -> void:
	await _reset_player(Vector3(0, 0.02, 4))
	var start := player.global_position
	_click_ground(Vector3(4, 1, 2))
	await _tick(3)
	_check(not navigation.has_destination() and not marker.visible, "Clicking an obstacle must not create a ground destination.")
	_click_ground(Vector3(30, 0, 30))
	await _tick(3)
	_check(not navigation.has_destination(), "Clicking outside the floor must not create a route.")
	var panel := Panel.new()
	panel.size = root.get_visible_rect().size
	root.add_child(panel)
	await _tick(2)
	_click_ground(Vector3(3, 0, 5))
	await _tick(3)
	_check(not navigation.has_destination() and not marker.visible, "A UI-consumed click must not move the player.")
	_check(player.global_position.distance_to(start) < 0.01, "Invalid/UI clicks must leave the player still.")
	panel.queue_free()
	await _tick(2)
	_click_ground(player.global_position)
	await _tick(3)
	_check(not navigation.has_destination() and not marker.visible, "Clicking under the player must stop cleanly without oscillation.")

func _check_rotated_zoomed_clicks() -> void:
	await _reset_player(Vector3(0, 0.02, 4))
	var destination := Vector3(5, 0, 6)
	_click_ground(destination)
	await _tick(2)
	var fixed_destination := marker.global_position
	Input.action_press("rotate_camera_left")
	var zoom_event := InputEventMouseButton.new()
	zoom_event.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom_event.pressed = true
	zoom_event.position = root.get_visible_rect().get_center()
	root.push_input(zoom_event, true)
	await _tick(20)
	Input.action_release("rotate_camera_left")
	_check(marker.global_position.is_equal_approx(fixed_destination), "Rotation/zoom must not change an active world-space destination.")
	await _wait_for_arrival(destination)
	var next_destination := Vector3(0, 0, 7)
	_click_ground(next_destination)
	await _tick(2)
	_check(_horizontal_distance(marker.global_position, next_destination) < 0.1, "Picking must use the rotated and zoomed camera.")
	await _wait_for_arrival(next_destination)

func _check_stuck_cancellation() -> void:
	await _reset_player(Vector3(0, 0.02, 4))
	_click_ground(Vector3(0, 0, 8))
	await _tick(2)
	_check(navigation.has_destination(), "The stuck check must start with a valid route.")
	# Introduce a new physical obstruction after the static route has been planned.
	var barrier := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(12, 1.2, 0.5)
	collision.shape = shape
	barrier.add_child(collision)
	barrier.position = Vector3(0, 0.6, 6)
	world.add_child(barrier)
	await _tick(180)
	_check(not navigation.has_destination() and not marker.visible, "A physically blocked route must time out and clear its marker.")
	_check(player.position.z < 5.55, "Stuck handling must not teleport through the obstruction.")
	_check(String(sprite.animation).begins_with("idle_"), "A stuck player must return to idle.")
	barrier.queue_free()
	await _tick(3)

func _run() -> void:
	var scene: PackedScene = load("res://scenes/world.tscn")
	world = scene.instantiate() as Node3D
	root.add_child(world)
	current_scene = world
	player = world.get_node("Player") as CharacterBody3D
	camera = world.get_node("Camera3D") as Camera3D
	navigation = player.get_node("ClickMovement") as ClickMovement
	marker = player.get_node("DestinationMarker") as DestinationMarker
	sprite = player.get_node("DirectionalSprite") as DirectionalSprite
	var navigation_map := player.get_world_3d().navigation_map
	var ready: bool = false
	for tick in range(300):
		await _tick()
		if NavigationServer3D.map_get_iteration_id(navigation_map) > 0 and NavigationServer3D.map_get_closest_point_owner(navigation_map, Vector3.ZERO).is_valid():
			ready = true
			break
	_check(ready, "The procedural map must bake and synchronize a navigation mesh.")
	if not ready:
		quit(1)
		return
	await _check_obstacle_detour()
	await _check_replacement_and_manual_override()
	await _check_invalid_and_ui_clicks()
	await _check_rotated_zoomed_clicks()
	await _check_stuck_cancellation()
	if failures == 0:
		print("PASS: click picking, obstacle detours, destination feedback, arrival, replacement, WASD cancellation, UI/invalid clicks, rotated zoomed picking, and stuck recovery.")
	quit(0 if failures == 0 else 1)
