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
	var monster := world.get_node("Monster") as Monster
	var player_combat := player.get_node("Combat") as MeleeCombat
	player.set_physics_process(false)
	monster.set_physics_process(false)
	player.global_position = Vector3(0, 2, 0)
	monster.global_position = Vector3(1.3, 2, 0)
	player.reset_physics_interpolation()
	monster.reset_physics_interpolation()
	await physics_frame
	await physics_frame
	monster.aggressive = false
	monster._physics_process(0.016)
	monster._physics_process(3.0)
	check(not monster._is_attacking and monster.velocity.is_zero_approx(), "Non-aggressive monster must remain idle even in attack range.")
	check(player_combat.stats.current_health == 100.0, "Non-aggressive monster must not damage player.")
	monster.aggressive = true
	monster.aggro_radius = 1.0
	monster._physics_process(0.016)
	check(not monster._is_attacking, "Aggro radius must gate attacks even within melee range.")
	monster.aggro_radius = 1.3
	monster._physics_process(0.016)
	check(monster._is_attacking, "Entering aggro radius must start an in-range attack.")
	monster.aggressive = false
	monster._physics_process(3.0)
	check(not monster._is_attacking and player_combat.stats.current_health == 100.0, "Disabling aggression must cancel pending damage.")
	monster.aggressive = true
	monster._physics_process(0.016)
	monster.aggro_radius = 1.0
	monster._physics_process(3.0)
	check(player_combat.stats.current_health == 100.0, "Leaving aggro radius during windup must cancel damage.")
	monster.aggro_radius = 6.0
	monster._physics_process(0.016)
	monster._physics_process(2.1)
	check(player_combat.stats.current_health == 90.0, "Re-entering radius must allow a fresh attack.")
	monster.aggro_radius = 0.0
	monster._physics_process(0.016)
	check(not monster._is_attacking and monster.velocity.is_zero_approx(), "Zero aggro radius must disable engagement.")
	world.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: aggression toggle, radius boundary, windup cancellation, and re-entry")
	quit(0 if failures == 0 else 1)
