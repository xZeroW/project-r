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
	var enemy_combat := monster.get_node("Combat") as MeleeCombat
	player.set_physics_process(false)
	monster.set_physics_process(false)
	player.global_position = Vector3(0, 2, 0)
	monster.global_position = Vector3(1.3, 2, 0)
	player.reset_physics_interpolation()
	monster.reset_physics_interpolation()
	await physics_frame
	await physics_frame
	check(player_combat.stats != enemy_combat.stats, "Actors must own separate stats.")
	check(player_combat.attack(enemy_combat), "Nearby melee attack must succeed.")
	check(enemy_combat.stats.current_health == 80.0, "Player must deal 20 damage.")
	var enemy_numbers := monster.get_node("DamageNumbers") as DamageNumbers
	check(enemy_numbers.get_child_count() == 1, "A hit must spawn a damage number.")
	var first_number := enemy_numbers.get_child(0) as Label
	check(first_number.text == "20", "Damage number must show health lost.")
	check(first_number.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Damage numbers must not intercept clicks.")
	check(not player_combat.attack(enemy_combat), "Cooldown must prevent repeated hits.")
	check(enemy_combat.attack(player_combat), "Monster must damage player.")
	check(player_combat.stats.current_health == 90.0, "Monster must deal 10 damage.")
	player_combat.invulnerability = 0.0
	enemy_combat.cooldown = 0.0
	monster._physics_process(0.016)
	check(player_combat.stats.current_health == 90.0, "Monster windup must not deal immediate damage.")
	monster._physics_process(2.1)
	check(player_combat.stats.current_health == 80.0, "Monster must resolve damage at windup completion.")
	player_combat.invulnerability = 0.0
	enemy_combat.cooldown = 0.0
	monster._physics_process(0.016)
	player_combat.cooldown = 0.0
	monster.global_position = Vector3(8, 2, 0)
	monster.reset_physics_interpolation()
	check(not player_combat.attack(enemy_combat), "Out-of-range attacks must miss.")
	monster._physics_process(2.1)
	check(player_combat.stats.current_health == 80.0, "Leaving range during windup must dodge damage.")
	monster.global_position = Vector3(1.3, 2, 0)
	monster.reset_physics_interpolation()
	enemy_combat.invulnerability = 0.0
	enemy_combat.stats.armour = 5.0
	check(player_combat.attack(enemy_combat), "Melee attack against armour must succeed.")
	check(enemy_combat.stats.current_health == 65.0, "Armour must reduce melee damage.")
	check((enemy_numbers.get_child(enemy_numbers.get_child_count() - 1) as Label).text == "15", "Popup must reflect armour-reduced damage.")
	var data := DamageData.new()
	data.amount = 1000.0
	data.source = player
	enemy_combat.invulnerability = 0.0
	enemy_combat.take_damage(data)
	check(enemy_combat.stats.current_health == 0.0, "Lethal damage must clamp health to zero.")
	check((enemy_numbers.get_child(enemy_numbers.get_child_count() - 1) as Label).text == "65", "Lethal popup must show actual remaining health lost.")
	check(not enemy_combat.attack(player_combat), "Dead actors cannot attack.")
	await process_frame
	check((monster.get_node("CollisionShape3D") as CollisionShape3D).disabled, "Death must disable collision.")
	enemy_numbers._process(1.0)
	await process_frame
	check(enemy_numbers.get_child_count() == 0, "Expired damage numbers must be freed.")
	world.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: combat damage, range, cooldown, independent health, and death")
	quit(0 if failures == 0 else 1)
