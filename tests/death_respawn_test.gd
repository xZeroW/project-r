extends SceneTree

var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var curve := ExperienceCurve.new()
	var progression := Experience.new()
	progression.curve = curve
	root.add_child(progression)
	progression.add_experience(9)
	check(progression.level == 2 and progression.current_experience == 0, "Setup must reach a known level.")
	progression.current_experience = 0
	progression.level = 2
	progression.lose_experience(0)
	progression.lose_experience(-5)
	check(progression.level == 2 and progression.current_experience == 0, "Nonpositive EXP loss must be ignored.")
	progression.lose_experience(1000)
	check(progression.level == 2 and progression.current_experience == 0, "Excess EXP loss must floor at zero without de-leveling.")
	progression.queue_free()

	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var player := world.get_node("Player") as CharacterBody3D
	var monster := world.get_node("Monster") as Monster
	var other := world.get_node("Monster2") as Monster
	player.set_physics_process(false)
	monster.set_physics_process(false)
	other.set_physics_process(false)
	var combat := player.get_node("Combat") as MeleeCombat
	var death_respawn := player.get_node("DeathRespawn") as DeathRespawn
	var experience := player.get_node("Experience") as Experience
	var health_bar := player.get_node("HealthBar") as CanvasLayer
	var collision := player.get_node("CollisionShape3D") as CollisionShape3D
	var spawn_position := player.global_position
	check(player.stats == combat.stats and combat.stats == health_bar.stats, "Root, combat, and health bar must share one stats instance.")
	experience.add_experience(7)
	check(experience.current_experience == 7 and experience.level == 1, "Player must start at level 1 with banked EXP.")
	var data := DamageData.new()
	data.source = monster
	data.amount = 1000.0
	combat.take_damage(data)
	await process_frame
	check(player.stats.current_health == 0.0, "Lethal damage must zero the shared player stats.")
	check(combat.stats.current_health == 0.0 and health_bar.stats.current_health == 0.0, "Death must be visible to combat and health bar.")
	check(collision.disabled, "Death must disable the player collider.")
	check(not combat.damage_enabled, "Death must disable damage intake.")
	check(not health_bar.visible, "Death must hide the health bar.")
	check(combat.visual.modulate != Color.WHITE, "Death must darken the sprite.")
	check(experience.level == 1 and experience.current_experience == 6, "Death must charge 5% of level-1 EXP (1) without de-leveling.")
	death_respawn._physics_process(death_respawn.respawn_delay * 0.5)
	check(not health_bar.visible, "Half the delay must not respawn the player yet.")
	death_respawn._physics_process(death_respawn.respawn_delay + 0.1)
	await process_frame
	check(player.global_position.is_equal_approx(spawn_position), "Respawn must return to the player's spawn point.")
	check(player.stats.current_health == player.stats.max_health, "Respawn must restore full health.")
	check(combat.damage_enabled, "Respawn must re-enable damage.")
	check(not collision.disabled, "Respawn must re-enable collision.")
	check(health_bar.visible, "Respawn must restore the health bar.")
	check(combat.visual.modulate == Color.WHITE, "Respawn must restore the sprite color.")
	check(experience.level == 1 and experience.current_experience == 6, "Respawn must not grant or remove extra EXP.")
	experience.current_experience = 0
	combat.take_damage(data)
	await process_frame
	check(experience.current_experience == 0 and experience.level == 1, "A zero-EXP death at level 1 must cost nothing and never de-level.")
	death_respawn._physics_process(death_respawn.respawn_delay + 0.1)
	await process_frame
	player.stats.current_health = 40.0
	player.stats.mana = 30.0
	experience.add_experience(9)
	check(experience.level == 2 and experience.current_experience == 0, "Nine EXP must reach level 2.")
	check(player.stats.current_health == player.stats.max_health, "Level up must restore full health.")
	check(player.stats.mana == player.stats.max_mana, "Level up must restore full mana.")
	world.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: player death, EXP penalty, no de-level, and spawn-point respawn")
	quit(0 if failures == 0 else 1)