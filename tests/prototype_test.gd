extends SceneTree
## Integration checks against the actual playable scene and physics world.

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _tick(count: int = 1) -> void:
	for index in range(count):
		await physics_frame
		await process_frame

func _release_input() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "rotate_camera_left", "rotate_camera_right"]:
		Input.action_release(action)

func _check_camera_rotation(player: CharacterBody3D, sprite: Sprite3D, camera: Camera3D) -> void:
	_release_input()
	await _tick(2)
	var initial_transform := camera.transform
	var initial_size := camera.size
	var player_start := player.position
	Input.action_press("rotate_camera_left")
	await _tick(60)
	_release_input()
	_check(initial_transform.basis.z.signed_angle_to(camera.basis.z, Vector3.UP) > 0.5, "Q must orbit the camera left.")
	_check(is_equal_approx(camera.position.length(), initial_transform.origin.length()), "Orbit must retain camera distance.")
	_check(is_equal_approx(camera.position.y, initial_transform.origin.y), "Orbit must retain camera height.")
	_check(is_equal_approx(camera.basis.z.y, initial_transform.basis.z.y) and is_equal_approx(camera.size, initial_size), "Orbit must retain tilt and zoom.")
	_check(camera.basis.z.normalized().dot(camera.position.normalized()) > 0.999, "Camera must keep looking toward the map center.")
	_check(player.position.distance_to(player_start) < 0.01, "Orbit alone must not move the player.")
	var stopped_transform := camera.transform
	await _tick(3)
	_check(camera.transform.is_equal_approx(stopped_transform), "Camera rotation must stop when input is released.")
	Input.action_press("rotate_camera_left")
	Input.action_press("rotate_camera_right")
	await _tick(3)
	_release_input()
	_check(camera.transform.is_equal_approx(stopped_transform), "Opposing camera inputs must cancel.")
	var directions: Array[Vector2] = [Vector2.RIGHT, Vector2(1, 1), Vector2.DOWN, Vector2(-1, 1), Vector2.LEFT, Vector2(-1, -1), Vector2.UP, Vector2(1, -1)]
	for row in range(directions.size()):
		player.position = Vector3(0, 0.02, 0)
		player.velocity = Vector3.ZERO
		await _tick(5)
		var intent := directions[row]
		if intent.x != 0:
			Input.action_press("move_right" if intent.x > 0 else "move_left")
		if intent.y != 0:
			Input.action_press("move_down" if intent.y > 0 else "move_up")
		var start := player.position
		await _tick(8)
		var projected := camera.unproject_position(player.position) - camera.unproject_position(start)
		_check(absf(projected.x) < 0.1 if intent.x == 0 else projected.x * intent.x > 0.0, "Rotated-camera horizontal movement disagrees with input.")
		_check(absf(projected.y) < 0.1 if intent.y == 0 else projected.y * intent.y > 0.0, "Rotated-camera vertical movement disagrees with input.")
		_check(is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), 4.0), "Rotated-camera movement must retain speed.")
		_check(sprite.frame == row, "Rotated-camera facing must agree with input.")
		_release_input()
	Input.action_press("rotate_camera_right")
	await _tick(60)
	_release_input()
	_check(camera.position.distance_to(initial_transform.origin) < 0.1, "E must reverse the Q orbit back to its starting position.")
	_check(camera.basis.z.dot(initial_transform.basis.z) > 0.999, "Reversing the orbit must restore the starting orientation.")

func _check_world_facing(player: CharacterBody3D, sprite: Sprite3D) -> void:
	_release_input()
	player.position = Vector3(0, 0.02, 0)
	player.velocity = Vector3.ZERO
	Input.action_press("move_down")
	await _tick(8)
	_release_input()
	await _tick(2)
	_check(sprite.frame == 2, "Moving down must establish a south-facing sprite.")
	var stopped := player.position
	# At 90 degrees/second, each half-second orbit crosses one 45-degree sector.
	var sector_ticks := roundi(Engine.physics_ticks_per_second * 0.5)
	Input.action_press("rotate_camera_left")
	for sector in range(1, 9):
		await _tick(sector_ticks)
		_check(sprite.frame == posmod(2 + sector, 8), "Idle world-facing sprite must advance one sector per 45-degree orbit (sector %d)." % sector)
		_check(player.position.distance_to(stopped) < 0.01, "Changing the visible side must not move the idle character.")
	_release_input()
	_check(sprite.frame == 2, "A full camera orbit must restore the original front view.")
	Input.action_press("rotate_camera_right")
	await _tick(sector_ticks * 4)
	_release_input()
	_check(sprite.frame == 6, "A reverse 180-degree orbit must show the idle character's back.")
	await _tick(3)
	_check(sprite.frame == 6, "The back view must remain after camera rotation stops.")
	# New movement changes the map-facing direction, even after the camera turns.
	Input.action_press("move_down")
	await _tick(8)
	_release_input()
	_check(sprite.frame == 2, "New movement must face screen-down from the rotated view.")
	Input.action_press("rotate_camera_left")
	await _tick(sector_ticks * 4)
	_release_input()
	_check(sprite.frame == 6, "Orbit must preserve the newly established world-facing direction.")

func _check_camera_free_physics(player: CharacterBody3D, sprite: Sprite3D, camera: Camera3D) -> void:
	camera.clear_current(false)
	_check(root.get_camera_3d() == null, "Regression check requires no active camera.")
	player.position = Vector3(0, 5, 0)
	player.velocity = Vector3(4, 0, 0)
	var previous_frame := sprite.frame
	Input.action_press("move_right")
	await _tick(10)
	_check(player.position.y < 5.0 and player.velocity.y < 0.0, "Gravity must continue without a camera.")
	_check(Vector2(player.position.x, player.position.z).is_zero_approx(), "Without a camera, horizontal motion must stop despite held input.")
	_check(sprite.frame == previous_frame, "Without a camera, the player must retain its facing.")
	await _tick(90)
	_check(player.is_on_floor(), "Without a camera, the player must still collide with the floor.")
	camera.make_current()
	var start := player.position
	await _tick(8)
	_check(player.position.distance_to(start) > 0.1 and sprite.frame == 0, "Movement and facing must resume when a camera becomes active.")
	_release_input()

func _run() -> void:
	var scene: PackedScene = load("res://scenes/world.tscn")
	var world := scene.instantiate()
	root.add_child(world)
	current_scene = world
	await _tick(20)
	var player := world.get_node("Player") as CharacterBody3D
	var sprite := player.get_node("DirectionalSprite") as Sprite3D
	var camera := world.get_node("Camera3D") as Camera3D
	_check(player.is_on_floor(), "Player must settle on the floor.")
	_check(sprite.texture.get_size() == Vector2(128, 1024), "Only the first sprite column should be imported.")
	var bindings: Dictionary[String, Key] = {"move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_W, "move_down": KEY_S, "rotate_camera_left": KEY_Q, "rotate_camera_right": KEY_E}
	for action in bindings:
		var events := InputMap.action_get_events(action)
		_check(events.size() == 1 and events[0] is InputEventKey and events[0].physical_keycode == bindings[action], "Incorrect physical key binding: " + action)
	var directions: Array[Vector2] = [Vector2.RIGHT, Vector2(1, 1), Vector2.DOWN, Vector2(-1, 1), Vector2.LEFT, Vector2(-1, -1), Vector2.UP, Vector2(1, -1)]
	for row in range(8):
		_release_input()
		player.position = Vector3(0, 0.02, 0)
		player.velocity = Vector3.ZERO
		await _tick(5)
		var intent: Vector2 = directions[row]
		if intent.x != 0:
			Input.action_press("move_right" if intent.x > 0 else "move_left")
		if intent.y != 0:
			Input.action_press("move_down" if intent.y > 0 else "move_up")
		var start := player.position
		await _tick(8)
		_check(sprite.frame == row, "Incorrect facing for direction %d." % row)
		var horizontal := Vector2(player.velocity.x, player.velocity.z)
		_check(is_equal_approx(horizontal.length(), 4.0), "Cardinal and diagonal speed must both be 4.")
		var projected := camera.unproject_position(player.position) - camera.unproject_position(start)
		_check(absf(projected.x) < 0.1 if intent.x == 0 else projected.x * intent.x > 0.0, "Horizontal screen movement disagrees with input.")
		_check(absf(projected.y) < 0.1 if intent.y == 0 else projected.y * intent.y > 0.0, "Vertical screen movement disagrees with input.")
		_release_input()
		var stopped := player.position
		await _tick(3)
		_check(sprite.frame == row, "Idle must retain the last facing.")
		_check(player.position.distance_to(stopped) < 0.01, "Player must stop when input is released.")
	# W + D moves along world -Z at this camera angle, into the tall block.
	player.position = Vector3(-4, 0.02, 0)
	player.velocity = Vector3.ZERO
	Input.action_press("move_up")
	Input.action_press("move_right")
	await _tick(90)
	_check(player.position.z > -1.8 and player.position.z < -1.6, "Tall block must stop the player at its near face.")
	_release_input()
	# S + D moves along world +X toward the map boundary.
	player.position = Vector3(10, 0.02, 0)
	player.velocity = Vector3.ZERO
	Input.action_press("move_down")
	Input.action_press("move_right")
	await _tick(90)
	_check(player.position.x > 11.3 and player.position.x < 11.6, "Boundary wall must keep the player on the map.")
	_check(player.is_on_floor(), "Player must remain grounded after collision.")
	_release_input()
	await _check_camera_free_physics(player, sprite, camera)
	await _check_camera_rotation(player, sprite, camera)
	await _check_world_facing(player, sprite)
	if failures == 0:
		print("PASS: bindings, eight directions, speed, idle, grounding, obstacles, boundaries, camera-free physics/recovery, camera rotation/movement, and persistent world facing.")
	quit(0 if failures == 0 else 1)
