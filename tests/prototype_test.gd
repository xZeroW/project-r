extends SceneTree
## Integration checks against the actual playable scene and physics world.

var failures: int = 0
var walk_loops: int = 0

class CameraFollowProbe:
	extends Node
	var player: Node3D
	var camera: Camera3D
	var samples: int = 0
	var max_center_error: float = 0.0

	func _process(_delta: float) -> void:
		var rendered_position := player.get_global_transform_interpolated().origin
		var center := get_viewport().get_visible_rect().get_center()
		max_center_error = maxf(max_center_error, camera.unproject_position(rendered_position).distance_to(center))
		samples += 1

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _has_facing(sprite: DirectionalSprite, direction: int) -> bool:
	var source_directions: Array[String] = ["west", "southwest", "south", "southwest", "west", "northwest", "north", "northwest"]
	return sprite.facing_index == direction and String(sprite.animation).get_slice("_", 1) == source_directions[direction] and sprite.flip_h == (direction in [0, 1, 7])

func _check_animation_frames(sprite: DirectionalSprite) -> void:
	var frames := sprite.sprite_frames
	_check(frames.get_animation_names().size() == 10, "The sheet must provide five idle and five walking clips.")
	for animation_name in frames.get_animation_names():
		var expected_count := 8 if animation_name.begins_with("walk_") else 1
		_check(frames.get_frame_count(animation_name) == expected_count, "Incorrect source frame count: " + animation_name)
		for index in range(frames.get_frame_count(animation_name)):
			var atlas := frames.get_frame_texture(animation_name, index) as AtlasTexture
			_check(atlas != null, "Animation frames must reference atlas regions.")
			if atlas == null:
				continue
			_check(atlas.atlas.get_size() == Vector2(1200, 1310), "Animation must use the new example.png sheet.")
			_check(atlas.get_size() == Vector2(96, 128), "Every frame must have the same padded canvas.")
			_check(Rect2(Vector2.ZERO, atlas.atlas.get_size()).encloses(atlas.region), "Atlas regions must stay inside the source image.")

func _on_walk_looped() -> void:
	walk_loops += 1

func _check_animation_playback(player: CharacterBody3D, sprite: DirectionalSprite, camera: Camera3D) -> void:
	_release_input()
	_teleport_player(player, Vector3(0, 0.02, 5))
	await _tick(5)
	walk_loops = 0
	sprite.animation_looped.connect(_on_walk_looped)
	Input.action_press("move_right")
	var seen_frames: Dictionary[int, bool] = {}
	for tick in range(60):
		await _tick()
		seen_frames[sprite.frame] = true
	sprite.animation_looped.disconnect(_on_walk_looped)
	_check(sprite.animation == &"walk_west" and sprite.flip_h, "Moving east must play mirrored west walking frames.")
	_check(seen_frames.size() == 8 and walk_loops > 0, "Walking must advance through all eight frames and loop without restarting each tick.")
	# Exercise a clip change and a mirrored turn synchronously, mid-stride.
	sprite.set_frame_and_progress(3, 0.45)
	var south := camera.global_basis.z
	south.y = 0.0
	sprite.update_facing(south.normalized(), camera.global_basis, true)
	_check(sprite.animation == &"walk_south" and not sprite.flip_h, "Turning south must select the unmirrored south clip.")
	_check(sprite.frame == 3 and is_equal_approx(sprite.frame_progress, 0.45), "Turning must preserve the walking frame and fractional progress.")
	var east := camera.global_basis.x
	east.y = 0.0
	sprite.update_facing(east.normalized(), Basis(Vector3.UP, PI) * camera.global_basis, true)
	_check(sprite.animation == &"walk_west" and not sprite.flip_h, "A half-turn camera view must reveal the unmirrored opposite side mid-stride.")
	_check(sprite.frame == 3 and is_equal_approx(sprite.frame_progress, 0.45), "Camera-driven direction changes must preserve the walking phase.")
	_release_input()
	await _tick(3)
	_check(String(sprite.animation).begins_with("idle_") and sprite.frame == 0, "Stopping must return to the single-frame idle pose.")
	await _tick(15)
	_check(sprite.frame == 0, "Idle must hold its pose rather than cycling through directions.")

func _tick(count: int = 1) -> void:
	for index in range(count):
		await physics_frame
		await process_frame

func _release_input() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "rotate_camera_left", "rotate_camera_right"]:
		Input.action_release(action)

func _teleport_player(player: CharacterBody3D, destination: Vector3, velocity: Vector3 = Vector3.ZERO) -> void:
	player.position = destination
	player.velocity = velocity
	player.reset_physics_interpolation()

func _scroll_camera(button: MouseButton, notches: int = 1) -> void:
	for notch in range(notches):
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.device = InputEvent.DEVICE_ID_MOUSE
			event.button_index = button
			event.pressed = pressed
			event.position = root.get_visible_rect().size * 0.5
			# Local viewport coordinates avoid headless window/stretch conversions.
			root.push_input(event, true)

func _check_camera_zoom(player: CharacterBody3D, sprite: DirectionalSprite, camera: Camera3D) -> void:
	_release_input()
	await _tick(90)
	var initial_size := camera.size
	var initial_transform := camera.transform
	var initial_facing := sprite.facing_index
	var initial_position := player.position
	var minimum: float = camera.get(&"min_zoom_size")
	var maximum: float = camera.get(&"max_zoom_size")
	_scroll_camera(MOUSE_BUTTON_WHEEL_UP)
	_check(is_equal_approx(camera.size, initial_size), "Wheel input must set a smooth zoom target rather than snapping the view.")
	await _tick(60)
	_check(camera.size < initial_size, "Wheel up must zoom in by reducing orthographic size.")
	_scroll_camera(MOUSE_BUTTON_WHEEL_DOWN)
	await _tick(60)
	_check(absf(camera.size - initial_size) < 0.01, "Opposite wheel steps must restore the previous zoom.")
	# UI gets first chance at scrolling; gameplay must not consume it behind a panel.
	var panel := Panel.new()
	panel.size = root.get_visible_rect().size
	panel.mouse_force_pass_scroll_events = false
	root.add_child(panel)
	await _tick(2)
	_scroll_camera(MOUSE_BUTTON_WHEEL_UP)
	await _tick(30)
	_check(absf(camera.size - initial_size) < 0.01, "Scrolling over blocking UI must not zoom the camera.")
	panel.queue_free()
	await _tick(2)
	_scroll_camera(MOUSE_BUTTON_WHEEL_UP, 40)
	await _tick(90)
	_check(is_equal_approx(camera.size, minimum), "Repeated wheel-up input must clamp at the minimum size.")
	_scroll_camera(MOUSE_BUTTON_WHEEL_DOWN)
	await _tick(60)
	_check(camera.size > minimum, "Zoom must reverse immediately away from its lower limit.")
	_scroll_camera(MOUSE_BUTTON_WHEEL_DOWN, 40)
	await _tick(90)
	_check(is_equal_approx(camera.size, maximum), "Repeated wheel-down input must clamp at the maximum size.")
	camera.clear_current(false)
	_scroll_camera(MOUSE_BUTTON_WHEEL_UP)
	await _tick(3)
	camera.make_current()
	await _tick(30)
	_check(is_equal_approx(camera.size, maximum), "An inactive camera must ignore wheel input.")
	_check(camera.transform.is_equal_approx(initial_transform), "Zoom must preserve the camera's orbit position and tilt.")
	_check(_has_facing(sprite, initial_facing) and player.position.distance_to(initial_position) < 0.01, "Zoom must not change character position or facing.")

func _check_camera_rotation(player: CharacterBody3D, sprite: DirectionalSprite, camera: Camera3D) -> void:
	_release_input()
	await _tick(90)
	var initial_transform := camera.transform
	var initial_size := camera.size
	var player_start := player.position
	var initial_offset := camera.global_position - player.global_position
	Input.action_press("rotate_camera_left")
	await _tick(60)
	_release_input()
	_check(initial_transform.basis.z.signed_angle_to(camera.basis.z, Vector3.UP) > 0.5, "Q must orbit the camera left.")
	var orbit_offset := camera.global_position - player.global_position
	_check(is_equal_approx(orbit_offset.length(), initial_offset.length()), "Orbit must retain camera distance from the player.")
	_check(is_equal_approx(orbit_offset.y, initial_offset.y), "Orbit must retain camera height above the player.")
	_check(is_equal_approx(camera.basis.z.y, initial_transform.basis.z.y) and is_equal_approx(camera.size, initial_size), "Orbit must retain tilt and zoom.")
	_check(camera.global_basis.z.normalized().dot(orbit_offset.normalized()) > 0.999, "Camera must keep looking toward the player.")
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
		_teleport_player(player, Vector3(0, 0.02, 0))
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
		_check(_has_facing(sprite, row), "Rotated-camera facing and mirroring must agree with input.")
		_release_input()
	Input.action_press("rotate_camera_right")
	await _tick(60)
	_release_input()
	await _tick(60)
	_check((camera.global_position - player.global_position).distance_to(initial_offset) < 0.01, "Reversing the orbit must restore its offset around the player's new position.")
	_check(camera.basis.z.dot(initial_transform.basis.z) > 0.999, "Reversing the orbit must restore the starting orientation.")

func _check_camera_follow(player: CharacterBody3D, camera: Camera3D) -> void:
	_release_input()
	_teleport_player(player, Vector3(0, 0.02, 0))
	await _tick(90)
	_check(camera.get(&"follow_target") == player, "The world camera must be wired to follow the player.")
	_check(ProjectSettings.get_setting("physics/common/physics_interpolation"), "Player rendering must use physics interpolation.")
	_check(camera.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "The manually positioned camera must not be interpolated twice.")
	var probe := CameraFollowProbe.new()
	probe.player = player
	probe.camera = camera
	probe.process_priority = 100
	root.add_child(probe)
	var initial_offset := camera.global_position - player.global_position
	var initial_basis := camera.global_basis
	var initial_size := camera.size
	var player_start := player.global_position
	var camera_start := camera.global_position
	Input.action_press("move_right")
	await _tick(30)
	_release_input()
	var player_delta := player.global_position - player_start
	var camera_delta := camera.global_position - camera_start
	_check(camera_delta.dot(player_delta) > 0.5, "Camera must translate with the moving player.")
	var follow_lag := (camera.global_position - player.global_position).distance_to(initial_offset)
	_check(follow_lag < 0.15, "Camera must not add a trailing delay beyond the physics/render interpolation interval.")
	Input.action_press("move_left")
	await _tick(15)
	_release_input()
	await _tick(3)
	_check(probe.samples > 0 and probe.max_center_error < 0.1, "Rendered player must stay centered through movement, reversal, and stopping.")
	probe.queue_free()
	_check((camera.global_position - player.global_position).distance_to(initial_offset) < 0.01, "Camera must stop with the player without a catch-up tail.")
	_check(camera.global_basis.is_equal_approx(initial_basis) and is_equal_approx(camera.size, initial_size), "Following must retain camera orientation and zoom.")
	var viewport_center := root.get_visible_rect().get_center()
	_check(camera.unproject_position(player.global_position).distance_to(viewport_center) < 1.0, "The stopped player must be centered in the viewport.")
	var initial_rotation := player.rotation
	player.rotation.y += PI / 2.0
	player.reset_physics_interpolation()
	await _tick(3)
	_check(camera.global_basis.is_equal_approx(initial_basis), "Player rotation must not rotate the camera.")
	player.rotation = initial_rotation
	player.reset_physics_interpolation()
	# A missing target leaves the camera at its last center rather than jumping home.
	camera.set(&"follow_target", null)
	var detached_position := camera.global_position
	Input.action_press("move_right")
	await _tick(15)
	_release_input()
	_check(camera.global_position.is_equal_approx(detached_position), "Camera must retain its center when its follow target is removed.")
	camera.set(&"follow_target", player)
	await _tick(90)
	_check((camera.global_position - player.global_position).distance_to(initial_offset) < 0.01, "Camera must resume following after its target is restored.")

func _check_world_facing(player: CharacterBody3D, sprite: DirectionalSprite) -> void:
	_release_input()
	_teleport_player(player, Vector3(0, 0.02, 0))
	Input.action_press("move_down")
	await _tick(8)
	_release_input()
	await _tick(2)
	_check(_has_facing(sprite, 2), "Moving down must establish a south-facing sprite.")
	var stopped := player.position
	# At 90 degrees/second, each half-second orbit crosses one 45-degree sector.
	var sector_ticks := roundi(Engine.physics_ticks_per_second * 0.5)
	Input.action_press("rotate_camera_left")
	for sector in range(1, 9):
		await _tick(sector_ticks)
		_check(_has_facing(sprite, posmod(2 + sector, 8)), "Idle world-facing sprite must advance one sector per 45-degree orbit (sector %d)." % sector)
		_check(player.position.distance_to(stopped) < 0.01, "Changing the visible side must not move the idle character.")
	_release_input()
	_check(_has_facing(sprite, 2), "A full camera orbit must restore the original front view.")
	Input.action_press("rotate_camera_right")
	await _tick(sector_ticks * 4)
	_release_input()
	_check(_has_facing(sprite, 6), "A reverse 180-degree orbit must show the idle character's back.")
	await _tick(3)
	_check(_has_facing(sprite, 6), "The back view must remain after camera rotation stops.")
	# New movement changes the map-facing direction, even after the camera turns.
	Input.action_press("move_down")
	await _tick(8)
	_release_input()
	_check(_has_facing(sprite, 2), "New movement must face screen-down from the rotated view.")
	Input.action_press("rotate_camera_left")
	await _tick(sector_ticks * 4)
	_release_input()
	_check(_has_facing(sprite, 6), "Orbit must preserve the newly established world-facing direction.")

func _check_camera_free_physics(player: CharacterBody3D, sprite: DirectionalSprite, camera: Camera3D) -> void:
	camera.clear_current(false)
	_check(root.get_camera_3d() == null, "Regression check requires no active camera.")
	_teleport_player(player, Vector3(0, 5, 0), Vector3(4, 0, 0))
	var previous_facing := sprite.facing_index
	Input.action_press("move_right")
	await _tick(10)
	_check(player.position.y < 5.0 and player.velocity.y < 0.0, "Gravity must continue without a camera.")
	_check(Vector2(player.position.x, player.position.z).is_zero_approx(), "Without a camera, horizontal motion must stop despite held input.")
	_check(_has_facing(sprite, previous_facing) and String(sprite.animation).begins_with("idle_"), "Without a camera, the player must idle and retain its facing.")
	await _tick(90)
	_check(player.is_on_floor(), "Without a camera, the player must still collide with the floor.")
	camera.make_current()
	var start := player.position
	await _tick(8)
	_check(player.position.distance_to(start) > 0.1 and _has_facing(sprite, 0), "Movement and facing must resume when a camera becomes active.")
	_release_input()

func _run() -> void:
	var scene: PackedScene = load("res://scenes/world.tscn")
	var world := scene.instantiate()
	root.add_child(world)
	current_scene = world
	await _tick(20)
	var player := world.get_node("Player") as CharacterBody3D
	var sprite := player.get_node("DirectionalSprite") as DirectionalSprite
	var camera := world.get_node("Camera3D") as Camera3D
	_check(player.is_on_floor(), "Player must settle on the floor.")
	_check_animation_frames(sprite)
	var bindings: Dictionary[String, Key] = {"move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_W, "move_down": KEY_S, "rotate_camera_left": KEY_Q, "rotate_camera_right": KEY_E}
	for action in bindings:
		var events := InputMap.action_get_events(action)
		_check(events.size() == 1 and events[0] is InputEventKey and events[0].physical_keycode == bindings[action], "Incorrect physical key binding: " + action)
	var directions: Array[Vector2] = [Vector2.RIGHT, Vector2(1, 1), Vector2.DOWN, Vector2(-1, 1), Vector2.LEFT, Vector2(-1, -1), Vector2.UP, Vector2(1, -1)]
	for row in range(8):
		_release_input()
		_teleport_player(player, Vector3(0, 0.02, 0))
		await _tick(5)
		var intent: Vector2 = directions[row]
		if intent.x != 0:
			Input.action_press("move_right" if intent.x > 0 else "move_left")
		if intent.y != 0:
			Input.action_press("move_down" if intent.y > 0 else "move_up")
		var start := player.position
		await _tick(8)
		_check(_has_facing(sprite, row), "Incorrect facing or mirroring for direction %d." % row)
		_check(String(sprite.animation).begins_with("walk_"), "Movement must play the walking animation.")
		var horizontal := Vector2(player.velocity.x, player.velocity.z)
		_check(is_equal_approx(horizontal.length(), 4.0), "Cardinal and diagonal speed must both be 4.")
		var projected := camera.unproject_position(player.position) - camera.unproject_position(start)
		_check(absf(projected.x) < 0.1 if intent.x == 0 else projected.x * intent.x > 0.0, "Horizontal screen movement disagrees with input.")
		_check(absf(projected.y) < 0.1 if intent.y == 0 else projected.y * intent.y > 0.0, "Vertical screen movement disagrees with input.")
		_release_input()
		var stopped := player.position
		await _tick(3)
		_check(_has_facing(sprite, row), "Idle must retain the last facing.")
		_check(String(sprite.animation).begins_with("idle_"), "Releasing movement must switch to idle.")
		_check(player.position.distance_to(stopped) < 0.01, "Player must stop when input is released.")
	# W + D moves along world -Z at this camera angle, into the tall block.
	_teleport_player(player, Vector3(-4, 0.02, 0))
	Input.action_press("move_up")
	Input.action_press("move_right")
	await _tick(90)
	_check(player.position.z > -1.8 and player.position.z < -1.6, "Tall block must stop the player at its near face.")
	_check(String(sprite.animation).begins_with("idle_"), "A fully blocked character must not walk in place.")
	_release_input()
	# S + D moves along world +X toward the map boundary.
	_teleport_player(player, Vector3(10, 0.02, 0))
	Input.action_press("move_down")
	Input.action_press("move_right")
	await _tick(90)
	_check(player.position.x > 11.3 and player.position.x < 11.6, "Boundary wall must keep the player on the map.")
	_check(player.is_on_floor(), "Player must remain grounded after collision.")
	_release_input()
	await _check_camera_free_physics(player, sprite, camera)
	await _check_camera_zoom(player, sprite, camera)
	await _check_camera_rotation(player, sprite, camera)
	await _check_world_facing(player, sprite)
	await _check_camera_follow(player, camera)
	await _check_animation_playback(player, sprite, camera)
	if failures == 0:
		print("PASS: movement, collisions, camera controls/following, world facing, five-direction atlas, mirroring, idle/walk playback, and preserved animation phase.")
	quit(0 if failures == 0 else 1)
