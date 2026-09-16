extends SceneTree

var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _test_derivation() -> void:
	var scene: PackedScene = load("res://scenes/player.tscn")
	var player_actor := scene.instantiate() as CharacterBody3D
	root.add_child(player_actor)
	await process_frame
	await process_frame
	var stats := player_actor.stats as CharacterStats
	var points := player_actor.get_node("StatusPoints") as StatusPoints
	check(is_equal_approx(stats.acc, 0.0), "Zero DEX must derive no accuracy.")
	check(stats.crit == 0.0, "Zero LUK must derive no crit chance.")
	points.grant_level_up_points()
	check(points.allocate(StatusPoints.Stat.DEX) and stats.acc == 1.0, "Each DEX point must add 1 accuracy (RO parity).")
	check(points.allocate(StatusPoints.Stat.LUK) and stats.crit == 0.3, "Each LUK point must add 0.3 crit.")
	player_actor.queue_free()
	await process_frame

func _test_resolver() -> void:
	var resolver := CombatResolver.new()
	var attacker := CharacterStats.new()
	var defender := CharacterStats.new()
	attacker.acc = 0.0
	defender.evasion = 0.0
	resolver.dice = func() -> float: return 0.42
	var result := resolver.resolve_incoming(attacker, defender)
	check(result.kind == CombatResolver.ResultKind.HIT, "A roll below the base chance must land a hit.")
	check(not result.is_crit, "Attacker with zero crit must never crit.")
	check(absf(result.hit_chance - 0.80) < 0.001, "Zero accuracy and evasion must yield the RO 80% base chance.")
	attacker.acc = 25.0
	defender.evasion = 25.0
	check(absf(resolver.resolve_incoming(attacker, defender).hit_chance - 0.80) < 0.001, "Equal AGI and DEX investment must cancel to the 80% base.")
	attacker.acc = 95.0
	defender.evasion = 0.0
	check(absf(resolver.resolve_incoming(attacker, defender).hit_chance - 0.95) < 0.001, "Overwhelming accuracy must clamp at the 95% cap.")
	attacker.acc = 5.0
	defender.evasion = 100.0
	check(absf(resolver.resolve_incoming(attacker, defender).hit_chance - 0.05) < 0.001, "Overwhelming evasion must clamp at the 5% floor.")
	attacker.acc = 0.0
	defender.evasion = 0.0
	attacker.level = 80
	defender.level = 80
	check(absf(resolver.resolve_incoming(attacker, defender).hit_chance - 0.80) < 0.001, "Same level must keep the 80% base chance.")
	attacker.level = 79
	check(absf(resolver.resolve_incoming(attacker, defender).hit_chance - 0.795) < 0.001, "One level above the attacker must cost 0.5%.")
	attacker.level = 78
	check(absf(resolver.resolve_incoming(attacker, defender).hit_chance - 0.79) < 0.001, "Two levels above the attacker must cost 1.0%.")
	attacker.level = 77
	check(absf(resolver.resolve_incoming(attacker, defender).hit_chance - 0.77) < 0.001, "Three levels above the attacker must escalate to a 3.0% penalty.")
	attacker.level = 81
	defender.level = 80
	check(absf(resolver.resolve_incoming(attacker, defender).hit_chance - 0.805) < 0.001, "A target below the attacker must grant the 0.5% bonus per level.")
	attacker.level = 1
	attacker.acc = 1000.0
	defender.evasion = 0.0
	result = resolver.resolve_incoming(attacker, defender)
	check(absf(result.hit_chance - CombatResolver.MAX_HIT_CHANCE) < 0.001, "Hit chance must clamp at the high cap.")
	attacker.acc = 0.0
	defender.evasion = 1000.0
	result = resolver.resolve_incoming(attacker, defender)
	check(absf(result.hit_chance - CombatResolver.MIN_HIT_CHANCE) < 0.001, "Hit chance must clamp at the low cap.")
	resolver.dice = func() -> float: return 0.99
	result = resolver.resolve_incoming(attacker, defender)
	check(result.kind == CombatResolver.ResultKind.EVADED, "Evasion that outscores accuracy must mark a failed hit EVADED.")
	attacker.acc = 95.0
	defender.evasion = 0.0
	result = resolver.resolve_incoming(attacker, defender)
	check(result.kind == CombatResolver.ResultKind.MISS, "A failed roll against no evasion must be a plain MISS.")
	defender.block = 100.0
	resolver.dice = func() -> float: return 0.0
	result = resolver.resolve_incoming(attacker, defender)
	check(result.kind == CombatResolver.ResultKind.BLOCKED, "A blocked defender must halve the incoming damage.")
	defender.block = 0.0
	attacker.crit = 100.0
	var rolls: Array[float] = [0.0, 0.0, 0.0, 1.0]
	var queue := func() -> float:
		return rolls.pop_front()
	resolver.dice = queue
	result = resolver.resolve_incoming(attacker, defender)
	check(result.is_crit, "A crit roll below attacker crit chance must crit after a hit.")
	result = resolver.resolve_incoming(attacker, defender)
	check(not result.is_crit, "A crit roll above the chance must not crit.")

func _test_integration() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var player := world.get_node("Player") as CharacterBody3D
	var monster := world.get_node("Monster") as Monster
	var player_combat := player.get_node("Combat") as MeleeCombat
	var enemy_combat := monster.get_node("Combat") as MeleeCombat
	player.set_physics_process(false)
	monster.set_physics_process(false)
	player.global_position = Vector3(0, 2, 0)
	monster.global_position = Vector3(1.3, 2, 0)
	player.reset_physics_interpolation()
	monster.reset_physics_interpolation()
	await physics_frame
	await physics_frame
	var numbers := monster.get_node("DamageNumbers") as DamageNumbers
	var evades := [0]
	var misses := [0]
	var blocks := [0]
	enemy_combat.evaded.connect(func() -> void: evades[0] += 1)
	enemy_combat.missed.connect(func() -> void: misses[0] += 1)
	enemy_combat.blocked.connect(func() -> void: blocks[0] += 1)
	player_combat.stats.crit = 0.0
	player_combat.stats.acc = 1000.0
	enemy_combat.stats.crit = 0.0
	enemy_combat.stats.evasion = 0.0
	var always_roll := func() -> float: return 0.0
	enemy_combat.resolver.dice = always_roll
	enemy_combat.stats.current_health = 100.0
	check(player_combat.attack(enemy_combat), "Melee attack must succeed.")
	check(enemy_combat.stats.current_health == 80.0, "Hit must land full 20 damage.")
	player_combat.cooldown = 0.0
	enemy_combat.invulnerability = 0.0
	enemy_combat.stats.current_health = 100.0
	enemy_combat.resolver.dice = func() -> float: return 0.99
	check(player_combat.attack(enemy_combat), "An attack attempt must still run even when it misses.")
	check(misses[0] == 1, "A failed contested roll without an evasion edge must emit the missed signal.")
	check(enemy_combat.stats.current_health == 100.0, "A missed hit must deal no damage.")
	player_combat.cooldown = 0.0
	enemy_combat.stats.block = 100.0
	enemy_combat.resolver.dice = always_roll
	check(player_combat.attack(enemy_combat), "An attack against a blocker must still run.")
	check(blocks[0] == 1, "A blocked hit must emit the blocked signal.")
	check(enemy_combat.stats.current_health == 90.0, "A blocked hit must halve the 20 damage.")
	player_combat.cooldown = 0.0
	enemy_combat.stats.block = 0.0
	enemy_combat.invulnerability = 0.0
	enemy_combat.stats.current_health = 100.0
	player_combat.stats.crit = 100.0
	check(player_combat.attack(enemy_combat), "A critical attack must still succeed.")
	check(enemy_combat.stats.current_health == 70.0, "Critical hits must deal 150% damage.")
	var crit_popup := numbers.get_child(numbers.get_child_count() - 1) as Label
	check(crit_popup.text == "30", "Critical popup must show the multiplied damage.")
	check(crit_popup.get_theme_color("font_color") == DamageNumbers.CRIT_COLOR, "Critical popup must use the crit color.")
	player_combat.cooldown = 0.0
	enemy_combat.invulnerability = 0.0
	enemy_combat.stats.current_health = 100.0
	player_combat.stats.crit = 0.0
	player_combat.stats.acc = 5.0
	enemy_combat.stats.evasion = 100.0
	enemy_combat.resolver.dice = func() -> float: return 0.99
	check(player_combat.attack(enemy_combat), "An evasive defender must still be attackable.")
	check(evades[0] == 1, "Evasion that outscores the attacker's accuracy must produce an EVADE.")
	var evade_popup := numbers.get_child(numbers.get_child_count() - 1) as Label
	check(evade_popup.text == "EVADE", "An evasion must spawn an EVADE popup.")
	check(evade_popup.get_theme_color("font_color") == DamageNumbers.EVADE_COLOR, "Evade popup must use the evade color.")
	world.queue_free()
	await process_frame

func run() -> void:
	await _test_derivation()
	_test_resolver()
	await _test_integration()
	if failures == 0:
		print("PASS: accuracy/evasion/crit/block derivation, resolver caps, and popup feedback")
	quit(0 if failures == 0 else 1)