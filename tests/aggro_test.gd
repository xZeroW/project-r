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
	var force_hit := func() -> float: return 0.0
	player_combat.resolver.dice = force_hit
	monster.combat.resolver.dice = force_hit
	var targeting := player.get_node("Targeting") as Targeting
	var spawn := monster.global_position
	player.set_physics_process(false)
	monster.set_physics_process(false)
	player.global_position = spawn + Vector3(1.3, 2, 0)
	monster.global_position = spawn + Vector3(0, 2, 0)
	player.reset_physics_interpolation()
	monster.reset_physics_interpolation()
	await physics_frame
	await physics_frame
	monster.aggressive = false
	monster._physics_process(0.016)
	monster._physics_process(3.0)
	check(monster.state == Monster.State.IDLE, "Passive monster must not acquire nearby player.")
	var hit := DamageData.new()
	hit.amount = 20.0
	hit.source = player
	monster.combat.take_damage(hit, player_combat)
	check(monster.state == Monster.State.ENGAGED, "Passive monster must retaliate when attacked.")
	monster._physics_process(0.016)
	check(monster._is_attacking, "Retaliating monster must attack within range.")
	monster._physics_process(2.1)
	check(player_combat.stats.current_health == 90.0, "Retaliation must deal damage.")
	monster.aggressive = true
	monster.aggro_radius = 1.0
	monster._physics_process(0.016)
	check(monster.state == Monster.State.ENGAGED, "Leaving acquisition radius must not cancel engagement.")
	# Crossing the spawn-based leash cancels the current windup.
	player.global_position = spawn + Vector3(monster.leash_distance + 1.0, 2, 0)
	player.reset_physics_interpolation()
	monster._physics_process(0.016)
	check(monster.state == Monster.State.RETURNING and not monster._is_attacking, "Crossing leash must cancel combat and return home.")
	check(not monster.combat.damage_enabled, "Returning monster must not be attackable.")
	var returning_health := monster.stats.current_health
	monster.combat.invulnerability = 0.0
	monster.combat.take_damage(hit, player_combat)
	check(monster.stats.current_health == returning_health, "Return-home damage must be ignored.")
	targeting.select(monster.combat)
	check(not targeting.has_target(), "Returning monsters must not be selectable.")
	monster._physics_process(0.016)
	check(monster.state == Monster.State.IDLE and monster.global_position.is_equal_approx(spawn), "Home arrival must restore idle spawn position.")
	check(monster.stats.current_health == monster.stats.max_health, "Home arrival must restore health.")
	# Exercise an actual return path above the baked floor, before arrival/reset.
	for tick: int in range(120):
		var map := monster.get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(map) > 0 and NavigationServer3D.map_get_closest_point_owner(map, spawn).is_valid():
			break
		await physics_frame
	monster.global_position = spawn + Vector3(2, 1, 0)
	monster.reset_physics_interpolation()
	await physics_frame
	monster._begin_return()
	var before_return := monster.global_position
	monster._physics_process(0.016)
	check(monster.global_position.distance_to(spawn) < before_return.distance_to(spawn), "Return path must move toward home, not rely on recovery teleport.")
	monster._finish_return()
	# Aggressive acquisition after returning still uses the aggro radius.
	player.global_position = spawn + Vector3(2, 0, 0)
	monster._physics_process(0.016)
	check(monster.state == Monster.State.IDLE, "Outside aggro radius must remain idle.")
	monster.aggro_radius = 6.0
	monster._physics_process(0.016)
	check(monster.state == Monster.State.ENGAGED, "Aggressive monster must acquire inside aggro radius.")
	# Death and respawn keep the same entity but reset all combat state.
	targeting.select(monster.combat)
	monster.combat.invulnerability = 0.0
	hit.amount = 1000.0
	monster.combat.take_damage(hit, player_combat)
	check(monster.state == Monster.State.DEAD, "Lethal damage must enter dead state.")
	check(not targeting.has_target(), "Death must invalidate player selection.")
	monster._physics_process(0.3)
	check(monster.combat.visual.modulate.a > 0.0 and monster.combat.visual.modulate.a < 1.0, "Death must fade out the sprite.")
	await process_frame
	check((monster.get_node("CollisionShape3D") as CollisionShape3D).disabled, "Dead monster must have no collision.")
	monster._physics_process(monster.respawn_delay)
	await process_frame
	check(monster.state == Monster.State.IDLE and monster.global_position.is_equal_approx(spawn), "Respawn must restore the home position.")
	check(monster.stats.current_health == monster.stats.max_health and monster.combat.damage_enabled, "Respawn must restore full health and damage reception.")
	check(not (monster.get_node("CollisionShape3D") as CollisionShape3D).disabled, "Respawn must restore collision.")
	check(monster.combat.visual.modulate == Color.WHITE and monster.combat.visual.is_playing(), "Respawn must restore idle presentation.")
	world.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: passive retaliation, aggro acquisition, leash, return immunity/healing, death fade, and respawn")
	quit(0 if failures == 0 else 1)
