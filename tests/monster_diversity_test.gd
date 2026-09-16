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
	var poring := world.get_node("Monster") as Monster
	var poporing := world.get_node("Monster2") as Monster
	var player := world.get_node("Player") as CharacterBody3D
	var player_combat := player.get_node("Combat") as MeleeCombat
	var experience := player.get_node("Experience") as Experience
	# Freeze everyone until positions are set so no monster engages the spawn player.
	player.set_physics_process(false)
	poring.set_physics_process(false)
	poporing.set_physics_process(false)
	for tick: int in range(2):
		await physics_frame
	# Definitions are real data resources read into each instance.
	check(poring.definition is MonsterDefinition and poring.definition.display_name == "Poring", "Poring must read the Poring definition resource.")
	check(poporing.definition is MonsterDefinition and poporing.definition.display_name == "Poporing", "Poporing must read the Poporing definition resource.")
	# Per-instance stats come from each definition, distinct and independent.
	check(poring.stats.max_health == 100.0 and poring.stats.attack_damage == 10.0 and poring.stats.movement_speed == 2.5, "Poring must derive its definition stats.")
	check(poporing.stats.max_health == 180.0 and poporing.stats.attack_damage == 16.0 and poporing.stats.movement_speed == 2.4, "Poporing must derive its stronger definition stats.")
	check(poring.stats.level == 1 and poporing.stats.level == 2, "Monster level must come from the definition and never gain EXP.")
	check(poring.combat.stats == poring.stats and poporing.combat.stats == poporing.stats, "Combat must read the same stats resource as the monster root.")
	# Per-instance EXP rewards and behavior settings.
	check(poring.combat.base_experience_reward == 2, "Poring must reward its definition EXP.")
	check(poporing.combat.base_experience_reward == 8, "Poporing must reward its definition EXP.")
	check(poring.aggressive and poring.aggro_radius == 6.0 and poring.leash_distance == 10.0, "Poring must use its definition aggro/leash settings.")
	check(poporing.aggressive and poporing.aggro_radius == 7.0 and poporing.leash_distance == 12.0, "Poporing must use its definition aggro/leash settings.")
	# Presentation tint differs per variant; it lives on MeleeCombat.base_modulate
	# so the damage flash on visual.modulate restores it instead of erasing it.
	check(poring.combat.base_modulate == Color.WHITE, "Poring must keep its white tint.")
	check(poporing.combat.base_modulate == Color(0.75, 1, 0.8, 1), "Poporing must show its green tint.")
	# Aggro is per instance: a spot within Poporing's wider radius but outside
	# Poring's radius engages only the Poporing.
	player.global_position = poring.global_position + Vector3(-9, 0, 0)
	player.reset_physics_interpolation()
	await physics_frame
	poring.set_physics_process(true)
	poporing.set_physics_process(true)
	for tick: int in range(5):
		await physics_frame
	check(poring.state == Monster.State.IDLE, "Poring must stay idle when the player is outside its 6-unit radius.")
	check(poporing.state == Monster.State.ENGAGED, "Poporing must engage when the player is inside its 7-unit radius.")
	poring.set_physics_process(false)
	poporing.set_physics_process(false)
	# Damaging one monster must not touch the other's health.
	var force_hit := func() -> float: return 0.0
	poring.combat.resolver.dice = force_hit
	poporing.combat.resolver.dice = force_hit
	var data := DamageData.new()
	data.source = player
	data.amount = 30.0
	poring.combat.invulnerability = 0.0
	poring.combat.take_damage(data, player_combat)
	check(poring.stats.current_health == 70.0, "A hit on Poring must reduce only Poring's health.")
	check(poporing.stats.current_health == 180.0, "Poring damage must not affect Poporing health.")
	# Kill credit and rewards are independent per instance.
	data.amount = 1000.0
	poring.combat.invulnerability = 0.0
	poring.combat.take_damage(data, player_combat)
	check(experience.current_experience == 2, "Poring's lethal hit must award exactly its definition EXP.")
	data.amount = 1000.0
	poporing.combat.invulnerability = 0.0
	poporing.combat.take_damage(data, player_combat)
	check(experience.level == 2 and experience.current_experience == 1, "Poporing's lethal hit must stack its own 8 EXP onto Poring's 2, crossing into level 2.")
	# Respawn restores the specific variant's tint, not a shared white.
	poporing._physics_process(poporing.respawn_delay)
	await process_frame
	check(poporing.state == Monster.State.IDLE and poporing.stats.current_health == 180.0, "Poporing respawn must restore full health.")
	check(poporing.combat.visual.modulate == Color(0.75, 1, 0.8, 1), "Poporing respawn must restore its green tint.")
	world.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: per-instance definitions, independent stats/EXP/aggro, tints, and respawn")
	quit(0 if failures == 0 else 1)