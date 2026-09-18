extends SceneTree

var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var player := world.get_node("Player") as CharacterBody3D
	var monster := world.get_node("Poring") as Monster
	var targeting := player.get_node("Targeting") as Targeting
	var clicks := player.get_node("ClickMovement") as ClickMovement
	var combat := player.get_node("Combat") as MeleeCombat
	var enemy := monster.get_node("Combat") as MeleeCombat
	combat.stats.crit = 0.0
	enemy.stats.crit = 0.0
	var force_hit := func() -> float: return 0.0
	combat.resolver.dice = force_hit
	enemy.resolver.dice = force_hit
	var camera := world.get_node("Camera3D") as Camera3D
	player.set_physics_process(false)
	monster.set_physics_process(false)
	player.global_position = Vector3(0, 2, 0)
	monster.global_position = Vector3(1.3, 2, 0)
	player.reset_physics_interpolation()
	monster.reset_physics_interpolation()
	await physics_frame
	await physics_frame
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = camera.unproject_position((monster.get_node("CollisionShape3D") as Node3D).global_position)
	root.push_input(click, true)
	check(not targeting.has_target(), "Picking must wait for physics.")
	await physics_frame
	clicks.get_direction(player, 4.0, 0.016)
	check(targeting.target == enemy, "Monster click must select that enemy.")
	check(not clicks.has_destination(), "Selecting enemy must clear ground route.")
	targeting.get_direction(combat, 4.0, 0.016)
	check(enemy.stats.current_health == 80.0, "Selected nearby enemy must receive an auto-attack.")
	targeting.get_direction(combat, 4.0, 0.016)
	check(enemy.stats.current_health == 80.0, "Auto-attack must respect cooldown.")
	combat.cooldown = 0.0
	enemy.invulnerability = 0.0
	targeting.get_direction(combat, 4.0, 0.016)
	check(enemy.stats.current_health == 60.0, "Auto-attack must repeat without another click.")
	# Accepted ground movement cancels selection through the same signal as ray picking.
	clicks.destination_changed.emit(Vector3.ZERO)
	check(not targeting.has_target(), "Accepted ground click must cancel targeting.")
	targeting.select(enemy)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	root.push_input(key, true)
	player.call("_physics_process", 0.016)
	check(not targeting.has_target(), "WASD must cancel auto-attack.")
	key.pressed = false
	root.push_input(key, true)
	# Navigation must be synchronized before a distant enemy can be pursued.
	for tick: int in range(120):
		var map := player.get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(map) > 0 and NavigationServer3D.map_get_closest_point_owner(map, Vector3.ZERO).is_valid():
			break
		await physics_frame
	monster.global_position = Vector3(0, 2, -7)
	monster.reset_physics_interpolation()
	targeting.select(enemy)
	var chase := targeting.get_direction(combat, 4.0, 0.016)
	check(not chase.is_zero_approx(), "Distant selected enemy must produce a navigation pursuit direction.")
	check(enemy.stats.current_health == 60.0, "Pursuit must not deal out-of-range damage.")
	targeting.record_motion(Vector3.ZERO, 1.1)
	check(not targeting.has_target(), "Blocked pursuit must time out.")
	targeting.select(enemy)
	enemy.stats.current_health = 0.0
	targeting.get_direction(combat, 4.0, 0.016)
	check(targeting.target == null, "Dead target must clear selection.")
	world.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: click selection, auto-attack, cooldown, cancellation, and dead target cleanup")
	quit(0 if failures == 0 else 1)
