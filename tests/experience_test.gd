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
	check(curve.get_max_level() == 99, "Classic normal Base Level must cap at 99.")
	var total: int = 0
	for requirement: int in curve.requirements:
		total += requirement
	check(total == 405234427, "Full classic table must total 405,234,427 EXP.")
	var progression := Experience.new()
	progression.curve = curve
	root.add_child(progression)
	progression.add_experience(-10)
	progression.add_experience(0)
	check(progression.current_experience == 0 and progression.level == 1, "Nonpositive awards must be ignored.")
	progression.add_experience(8)
	check(progression.level == 1 and progression.current_experience == 8, "Four Porings must leave 8/9 EXP.")
	progression.add_experience(2)
	check(progression.level == 2 and progression.current_experience == 1, "Fifth Poring must reach level 2 with 1/16 EXP.")
	progression.add_experience(40)
	check(progression.level == 4 and progression.current_experience == 0, "One award must support multiple exact-threshold levels.")
	progression.add_experience(9223372036854775807)
	check(progression.level == 99 and progression.current_experience == 0, "Huge awards must cap safely without overflow.")
	progression.add_experience(2)
	check(progression.get_required_experience() == 0 and progression.current_experience == 0, "Capped progression must ignore further EXP.")
	progression.queue_free()

	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var player := world.get_node("Player") as CharacterBody3D
	var monster := world.get_node("Monster") as Monster
	var other := world.get_node("Monster2") as Monster
	player.set_physics_process(false)
	monster.set_physics_process(false)
	other.set_physics_process(false)
	var experience := player.get_node("Experience") as Experience
	var player_combat := player.get_node("Combat") as MeleeCombat
	var hud := player.get_node("ExperienceUI") as ExperienceUI
	var force_hit := func() -> float: return 0.0
	monster.combat.resolver.dice = force_hit
	other.combat.resolver.dice = force_hit
	var data := DamageData.new()
	data.source = player
	data.amount = 20
	monster.combat.take_damage(data, player_combat)
	check(experience.current_experience == 0, "Nonlethal damage must not award EXP.")
	data.amount = 1000
	monster.combat.take_damage(data, player_combat)
	check(experience.current_experience == 0, "Invulnerable hits must not award EXP.")
	monster.combat.invulnerability = 0
	monster.combat.take_damage(data, player_combat)
	check(experience.current_experience == 2, "Player's lethal hit must award Poring EXP.")
	monster.combat.take_damage(data, player_combat)
	check(experience.current_experience == 2, "Repeated corpse hits must not award EXP.")
	for kill: int in range(4):
		monster._physics_process(monster.respawn_delay + 0.1)
		monster.combat.take_damage(data, player_combat)
	check(experience.level == 2 and experience.current_experience == 1, "Respawned Porings must award once per life.")
	check(hud._level_label.text == "Base Lv. 2" and hud._exp_label.text == "Base EXP  1 / 16", "HUD must refresh level and overflow EXP.")
	check(hud._notice.text.contains("LEVEL UP!"), "Level-up feedback must be visible.")
	check(hud._bar.value == 1 and hud._bar.max_value == 16, "EXP bar must reflect the next level threshold.")
	data.source = null
	other.combat.take_damage(data, null)
	check(experience.current_experience == 1, "Unattributed deaths must not grant player EXP.")
	other._physics_process(other.respawn_delay + 0.1)
	data.source = monster
	other.combat.take_damage(data, monster.combat)
	check(experience.current_experience == 1, "Another actor's kill must not grant player EXP.")
	var second_player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(second_player)
	var second_experience := second_player.get_node("Experience") as Experience
	check(second_experience.level == 1 and second_experience.current_experience == 0, "New player instances must start with independent progression.")
	await process_frame
	await process_frame
	var panel := hud.get_child(0) as Control
	check(panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= root.get_visible_rect().size.y, "EXP HUD must fit inside the viewport.")
	check(panel.mouse_filter == Control.MOUSE_FILTER_IGNORE and hud._bar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "EXP HUD must allow world clicks through.")
	second_player.queue_free()
	world.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: classic EXP curve, overflow, cap, kill credit, respawn rewards, independent progression, and HUD")
	quit(0 if failures == 0 else 1)
