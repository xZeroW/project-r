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
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)

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
	var bindings := {"move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_W, "move_down": KEY_S}
	for action in bindings:
		var events := InputMap.action_get_events(action)
		_check(events.size() == 1 and events[0] is InputEventKey and events[0].physical_keycode == bindings[action], "Incorrect physical key binding: " + action)
	var directions := [Vector2.RIGHT, Vector2(1, 1), Vector2.DOWN, Vector2(-1, 1), Vector2.LEFT, Vector2(-1, -1), Vector2.UP, Vector2(1, -1)]
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
	if failures == 0:
		print("PASS: bindings, eight directions, speed, idle, grounding, obstacles, and boundaries.")
	quit(0 if failures == 0 else 1)
