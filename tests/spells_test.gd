extends SceneTree

var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _push_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)

## Cooldowns tick in SpellCaster._process and i-frames/invulnerability tick in
## MeleeCombat._physics_process, both from the engine's real frame delta, which
## this environment paces erratically in headless runs. Driving those same
## methods with explicit deltas keeps the test deterministic and mirrors the
## time a real "simulated second" would advance.
func _advance(caster: SpellCaster, seconds: float) -> void:
	caster._process(seconds)

func _tick_mobs(seconds: float) -> void:
	for monster: Node in get_nodes_in_group("monsters"):
		var mob_combat := monster.get_node("Combat") as MeleeCombat
		mob_combat._physics_process(seconds)

func run() -> void:
	var scene: PackedScene = load("res://scenes/player.tscn")
	var player_actor := scene.instantiate() as CharacterBody3D
	root.add_child(player_actor)
	await process_frame
	await process_frame
	var caster := player_actor.get_node("SpellCaster") as SpellCaster
	var hotbar := player_actor.get_node("Hotbar") as Hotbar
	var combat := player_actor.get_node("Combat") as MeleeCombat
	var popups := player_actor.get_node("DamageNumbers") as DamageNumbers
	var mana_fill := player_actor.get_node("%ManaFill") as ColorRect
	var stats := player_actor.stats as CharacterStats
	var experience := player_actor.get_node("Experience") as Experience
	# Deterministic spells: force every contested roll to land.
	combat.resolver.dice = func() -> float: return 0.0

	var aoe_spell := caster.get_spell(&"aoe_damage") as SpellDefinition
	var heal_spell := caster.get_spell(&"heal") as SpellDefinition
	check(aoe_spell != null and heal_spell != null, "The spellbook must contain the AoE and heal definitions.")

	# Spawn monsters: one near (in AoE radius), one far, one weak (to credit EXP).
	var monster_scene: PackedScene = load("res://scenes/monster.tscn")
	var near := monster_scene.instantiate() as Monster
	near.target = player_actor
	near.target_combat = combat
	root.add_child(near)
	near.global_position = Vector3(2.5, 0.5, 0)
	var far := monster_scene.instantiate() as Monster
	far.target = player_actor
	far.target_combat = combat
	root.add_child(far)
	far.global_position = Vector3(12, 0.5, 8)
	var weak := monster_scene.instantiate() as Monster
	weak.target = player_actor
	weak.target_combat = combat
	weak.stats.current_health = 10.0
	root.add_child(weak)
	weak.global_position = Vector3(3.0, 0.5, 0.2)
	await process_frame
	await process_frame

	check(get_nodes_in_group("monsters").size() >= 3, "Monster fixtures must join the monsters group.")
	# Incoming hit rolls belong to each defender, not the attacking caster.
	for monster: Node in get_nodes_in_group("monsters"):
		var defender := monster.get_node("Combat") as MeleeCombat
		defender.resolver.dice = func() -> float: return 0.0

	# Phase A — hotbar-key wiring, AoE damage, EXP credit, mana, and global cooldown.
	var spell_cast_count: Array[int] = [0]
	caster.spell_cast.connect(func(_spell: SpellDefinition) -> void: spell_cast_count[0] += 1)
	var denied: Array[StringName] = []
	caster.cast_denied.connect(func(_spell: SpellDefinition, reason: StringName) -> void: denied.append(reason))

	_push_key(KEY_1)
	check(spell_cast_count[0] == 1, "Hotbar key 1 must cast the AoE spell through the player wiring.")
	check(is_equal_approx(stats.current_health, 100.0), "AoE must not touch the caster's health.")
	check(is_equal_approx(near.stats.current_health, 75.0), "AoE must damage a monster inside its radius.")
	check(is_equal_approx(far.stats.current_health, 100.0), "AoE must ignore monsters outside its radius.")
	check(is_equal_approx(experience.current_experience, weak.combat.base_experience_reward), "A spell kill must credit the player with EXP.")
	check(is_equal_approx(stats.mana, 90.0), "Casting must spend the spell's mana cost.")
	check(absf(mana_fill.size.x - 54.0) < 0.1, "The mana bar fill must drop with the spent mana.")
	check(caster.get_global_cooldown_remaining() > 0.0, "Casting must start the 1s global cooldown.")
	check(caster.get_cooldown_remaining(heal_spell) > 0.0, "Every spell must enter the global cooldown, even uncast ones.")
	check(not caster.try_cast(aoe_spell) and denied.has(&"global_cooldown"), "A cast inside the global cooldown must be denied.")
	check(hotbar.get_slot_cooldown_fraction(0) > 0.9, "The cast spell's hotbar slot must show a near-full cooldown pie.")
	check(hotbar.get_slot_cooldown_fraction(1) > 0.9, "An uncast spell must share the pie while the global cooldown runs.")
	check(not caster.try_cast(heal_spell), "Uncast spells must also be blocked while the global cooldown runs.")

	# Phase B — cooldown lifecycle: the 1s global cooldown clears first, then the
	# AoE's own 3s cooldown continues on its own.
	stats.current_health = 50.0
	_advance(caster, 1.0)
	_tick_mobs(1.0)
	check(caster.get_global_cooldown_remaining() <= 0.0, "The global cooldown must clear after 1s.")
	check(caster.get_cooldown_remaining(aoe_spell) > 1.5, "The AoE's own 3s cooldown must still be running after the gcd clears.")
	check(hotbar.get_slot_cooldown_fraction(0) < 0.9 and hotbar.get_slot_cooldown_fraction(0) > 0.3, "The pie must shrink as the spell's own cooldown drains.")
	check(hotbar.get_slot_cooldown_fraction(1) == 0.0, "An uncast spell must show no pie once the global cooldown clears.")
	check(caster.can_cast(heal_spell), "A spell whose own cooldown has never run must clear with the global cooldown.")
	check(caster.try_cast(heal_spell), "Heal must be castable once the global cooldown clears.")
	check(is_equal_approx(stats.current_health, 75.0), "Heal must restore its power worth of health.")
	check(is_equal_approx(stats.mana, 80.0), "Heal must spend its own mana cost.")
	check(absf(mana_fill.size.x - 48.0) < 0.1, "The mana bar fill must keep tracking spent mana.")
	check(popups._popups.size() > 0 and popups._popups[popups._popups.size() - 1].label.text == "+25", "Healing must spawn a floating +25 number.")
	check(popups._popups.size() > 0 and popups._popups[popups._popups.size() - 1].label.get_theme_color("font_color") == DamageNumbers.HEAL_COLOR, "The healing number must be tinted green.")
	_advance(caster, 2.1)
	_tick_mobs(2.1)
	check(caster.can_cast(aoe_spell), "The AoE spell must come off its own cooldown after 3s total.")
	check(caster.can_cast(heal_spell), "The heal spell must come off its 1s cooldown.")
	check(caster.try_cast(aoe_spell), "The AoE spell must be castable again.")
	check(is_equal_approx(near.stats.current_health, 50.0), "A second AoE cast must keep dealing its base damage.")

	_advance(caster, 3.0)
	stats.mana = 5.0
	check(not caster.try_cast(heal_spell) and denied.has(&"mana"), "Insufficient mana must deny a cast.")

	# The pie denominator must follow the timer actually running: casting heal
	# with the AoE's own cooldown clear locks the AoE slot on the 1s global
	# cooldown, which must show a full rotation — not gcd/own_cooldown (1/3).
	stats.mana = 100.0
	_advance(caster, 3.1)
	_tick_mobs(3.1)
	check(caster.try_cast(heal_spell), "Heal must cast once cooldowns are clear.")
	check(hotbar.get_slot_cooldown_fraction(0) > 0.9, "A spell locked only by the global cooldown must show a full pie, not a fraction of its own cooldown.")
	_advance(caster, 0.5)
	_tick_mobs(0.5)
	check(hotbar.get_slot_cooldown_fraction(0) > 0.3 and hotbar.get_slot_cooldown_fraction(0) < 0.7, "The global-cooldown pie must drain across the full 1s rotation.")
	_advance(caster, 0.6)
	_tick_mobs(0.6)
	check(hotbar.get_slot_cooldown_fraction(0) == 0.0, "The pie must clear once the global cooldown ends.")

	# Phase C — POE-style tag increases scale only matching spells.
	caster.add_increase(SpellDefinition.SpellTag.AOE, 100.0)
	check(is_equal_approx(caster.get_total_power(aoe_spell), 50.0), "A 100% AOE-tag increase must double AoE spell power.")
	check(is_equal_approx(caster.get_total_power(heal_spell), 25.0), "A heal-tagged spell must ignore an AOE increase.")
	caster.add_increase(SpellDefinition.SpellTag.HEAL, 50.0)
	check(is_equal_approx(caster.get_total_power(heal_spell), 37.5), "A heal-tagged increase must scale the heal spell.")
	check(is_equal_approx(aoe_spell.power, 25.0), "Definition power must not be mutated by tag increases.")
	check(aoe_spell.has_tag(SpellDefinition.SpellTag.AOE) and not aoe_spell.has_tag(SpellDefinition.SpellTag.HEAL), "The AoE spell must carry only the AOE tag.")
	check(heal_spell.has_tag(SpellDefinition.SpellTag.HEAL) and not heal_spell.has_tag(SpellDefinition.SpellTag.AOE), "The heal must carry only the HEAL tag.")

	# Simulated equipment bonuses on a multi-tag skill; no item system needed.
	caster.add_increase(SpellDefinition.SpellTag.AOE, -100.0)
	var fire_aoe := aoe_spell.duplicate(true) as SpellDefinition
	fire_aoe.tags = [SpellDefinition.SpellTag.AOE, SpellDefinition.SpellTag.FIRE]
	var fire_only := SpellDefinition.new()
	fire_only.power = 100.0
	fire_only.tags = [SpellDefinition.SpellTag.FIRE]
	var untagged := SpellDefinition.new()
	untagged.power = 100.0
	caster.add_increase(SpellDefinition.SpellTag.FIRE, 20.0)
	caster.add_increase(SpellDefinition.SpellTag.FIRE, 10.0)
	caster.add_increase(SpellDefinition.SpellTag.AOE, 30.0)
	check(is_equal_approx(caster.get_total_power(fire_aoe), 40.0), "Two fire sources and an AoE bonus must add to +60%, not multiply.")
	check(is_equal_approx(caster.get_total_power(fire_only), 130.0), "Every FIRE skill must receive fire bonuses, even without AOE.")
	check(is_equal_approx(caster.get_total_power(aoe_spell), 32.5), "Non-fire AoE must receive only the AoE bonus.")
	check(is_equal_approx(caster.get_total_power(heal_spell), 37.5), "Fire and AoE bonuses must not change HEAL power.")
	check(is_equal_approx(caster.get_total_power(untagged), 100.0), "Untagged skills must ignore tag bonuses.")
	check(fire_aoe.tag_label() == "AOE / FIRE", "Tooltips must display multiple tags, including FIRE.")
	fire_aoe.tags.append(SpellDefinition.SpellTag.FIRE)
	check(is_equal_approx(caster.get_total_power(fire_aoe), 40.0), "Duplicate tags must not apply a bonus twice.")
	fire_aoe.tags.reverse()
	check(is_equal_approx(caster.get_total_power(fire_aoe), 40.0), "Tag order must not affect power.")
	var other_caster := SpellCaster.new()
	other_caster.stats = CharacterStats.new()
	check(is_equal_approx(other_caster.get_total_power(fire_aoe), 25.0), "Bonuses must belong to the caster, not the shared skill.")
	other_caster.free()
	caster.spells.append(fire_aoe)
	_advance(caster, 3.0)
	_tick_mobs(3.0)
	var health_before := near.stats.current_health
	check(caster.try_cast(fire_aoe), "The multi-tag fire skill must cast successfully.")
	check(is_equal_approx(health_before - near.stats.current_health, 40.0), "An actual cast must deal the tag-scaled 40 damage.")
	check(is_equal_approx(fire_aoe.power, 25.0), "Simulated bonuses must preserve base skill power.")
	caster.add_increase(SpellDefinition.SpellTag.FIRE, -20.0)
	check(is_equal_approx(caster.get_total_power(fire_aoe), 35.0), "Removing one simulated source must preserve the other bonuses.")
	caster.add_increase(SpellDefinition.SpellTag.FIRE, -10.0)
	caster.add_increase(SpellDefinition.SpellTag.AOE, -30.0)
	check(is_equal_approx(caster.get_total_power(fire_aoe), 25.0), "Removing all matching bonuses must restore base power.")
	caster.add_increase(SpellDefinition.SpellTag.FIRE, -150.0)
	check(is_zero_approx(caster.get_total_power(fire_aoe)), "Reductions beyond 100% must not produce negative damage.")

	# INT supplies base magic attack; tag bonuses scale the combined damage.
	caster.add_increase(SpellDefinition.SpellTag.FIRE, 170.0)
	var points := player_actor.get_node("StatusPoints") as StatusPoints
	for _level: int in range(4):
		points.grant_level_up_points()
	for _point: int in range(20):
		check(points.allocate(StatusPoints.Stat.INT), "The INT fixture must spend real status points.")
	check(is_equal_approx(stats.magic_attack, 30.0), "20 INT must produce 30 midpoint MATK.")
	check(is_equal_approx(caster.get_total_power(fire_aoe), 66.0), "Fire bonus must scale both 25 base damage and 30 MATK by 20%.")
	check(is_equal_approx(caster.get_total_power(heal_spell), 37.5), "Healing must retain its separate tag-only scaling.")
	check(is_equal_approx(stats.attack_damage, 20.0), "INT must not increase physical attack.")
	fire_aoe.magic_attack_coefficient = 0.5
	check(is_equal_approx(caster.get_total_power(fire_aoe), 48.0), "Per-skill coefficient must scale MATK before tag bonuses.")
	fire_aoe.magic_attack_coefficient = 0.0
	check(is_equal_approx(caster.get_total_power(fire_aoe), 30.0), "Zero coefficient must opt out of MATK scaling.")
	fire_aoe.magic_attack_coefficient = 1.0
	points.recompute()
	points.recompute()
	check(is_equal_approx(caster.get_total_power(fire_aoe), 66.0), "Recomputing stats must not accumulate MATK or bonuses.")
	near.stats.current_health = 100.0
	_advance(caster, 3.0)
	_tick_mobs(3.0)
	check(caster.try_cast(fire_aoe), "INT-scaled skill must cast successfully.")
	check(is_equal_approx(near.stats.current_health, 34.0), "Actual damage must include INT-derived MATK and fire scaling.")
	check(is_equal_approx(fire_aoe.power, 25.0), "MATK must not mutate the shared skill base power.")

	near.queue_free()
	far.queue_free()
	weak.queue_free()
	player_actor.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: AoE damage + radius + EXP credit, heal, mana costs, 1s global cooldown with longer spell cooldowns, pizza pie fraction, POE tag increases")
	quit(0 if failures == 0 else 1)
