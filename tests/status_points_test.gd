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

func _click_at(position: Vector2, shift: bool = false, ctrl: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.device = InputEvent.DEVICE_ID_MOUSE
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.shift_pressed = shift
		event.ctrl_pressed = ctrl
		event.position = position
		root.push_input(event, true)

## Mirrors StatusPoints.et_stat_aspd so the diminishing shape is checked against
## the documented ET constants while endpoint values below assert the live node.
func _et_stat_aspd(agi: float) -> float:
	var penalty := 0.96 if StatusPoints.ET_JOB_BASE_ASPD <= 145.0 else 1.0 - (StatusPoints.ET_JOB_BASE_ASPD - 144.0) / 50.0
	var value := StatusPoints.ET_JOB_BASE_ASPD - (sqrt(205.0) - sqrt(agi)) / StatusPoints.ET_ASPD_CORRECTION_FACTOR \
		+ sqrt(StatusPoints.ET_AGI_ASPD_WEIGHT * agi) * penalty
	value = roundf(value * 1000.0) / 1000.0
	return minf(value, StatusPoints.ET_ASPD_CAP)

func _et_marginal_gain(from: int, to: int) -> float:
	var panel_range := func(agi: float) -> float:
		return 50.0 / (200.0 - _et_stat_aspd(agi))
	return (panel_range.call(to) - panel_range.call(from)) / float(to - from)

func run() -> void:
	var scene: PackedScene = load("res://scenes/player.tscn")
	var player_actor := scene.instantiate() as CharacterBody3D
	root.add_child(player_actor)
	await process_frame
	await process_frame
	var stats := player_actor.stats as CharacterStats
	var points := player_actor.get_node("StatusPoints") as StatusPoints
	var ui := player_actor.get_node("StatusUI") as StatusUI
	var attribute_ui := player_actor.get_node("AttributeUI") as AttributeUI
	var experience := player_actor.get_node("Experience") as Experience
	var player_input := player_actor.get_node("PlayerInput") as PlayerInput

	check(points.get_points_remaining() == 0, "Players must spawn with zero unspent points.")
	for stat: StatusPoints.Stat in StatusPoints.Stat.values():
		check(points.get_value(stat) == 0, "All six base stats must start at 0.")
	check(stats.attack_damage == 20.0, "Zero STR must yield the 20 base attack damage.")
	check(is_zero_approx(stats.magic_attack), "Zero INT must yield zero bonus MATK.")
	check(is_equal_approx(stats.attack_speed, 1.0) and stats.evasion == 0.0, "Zero AGI must yield base attack speed and no evasion.")
	check(stats.max_health == 100.0 and stats.max_mana == 100.0, "Zero VIT/INT must yield base 100 max health/mana.")
	check(stats.current_health == 100.0 and stats.mana == 100.0, "Spawn must match current values to the base max.")
	check(stats.acc == 0.0 and stats.crit == 0.0, "Zero DEX/LUK must yield no accuracy or crit.")

	check(not points.allocate(StatusPoints.Stat.STR), "Allocation must be denied with zero points.")
	points.grant_level_up_points()
	check(points.get_points_remaining() == 5, "A level-up grant must add 5 points.")
	check(points.allocate(StatusPoints.Stat.STR), "Allocation must succeed while points remain.")
	check(points.get_value(StatusPoints.Stat.STR) == 1 and points.get_points_remaining() == 4, "STR allocation must spend one point.")
	check(stats.attack_damage == 21.0, "One STR must grant one attack damage before threshold bonuses.")
	check(ui._derived_label.text.contains("ATK 21.0"), "The panel must show STR-derived attack damage.")
	check(points.allocate(StatusPoints.Stat.AGI) and absf(stats.attack_speed - 1.05851) < 0.0005 and stats.evasion == 1.0, "Each AGI point must grow ET attack speed and add 1 evasion.")

	stats.current_health = 50.0
	check(points.allocate(StatusPoints.Stat.VIT) and stats.max_health == 110.0, "Each VIT point must raise max health by 10.")
	check(stats.current_health == 60.0, "VIT must raise current health by the same delta.")
	stats.mana = 60.0
	check(points.allocate(StatusPoints.Stat.INT) and stats.max_mana == 105.0, "Each INT point must raise max mana by 5.")
	check(stats.mana == 65.0, "INT must raise current mana by the same delta.")
	check(is_equal_approx(stats.magic_attack, 1.0), "One INT must grant one MATK.")
	check(ui._derived_label.text.contains("MATK 1.0"), "The status panel must show updated MATK after allocation.")

	check(points.allocate(StatusPoints.Stat.DEX) and stats.acc == 1.0, "Each DEX point must add 1 accuracy (RO parity).")
	check(stats.attack_damage == 21.0 and stats.max_health == 110.0, "DEX must not change damage or health.")
	check(points.get_points_remaining() == 0, "Spending the last point must reach zero.")

	var damage_before := stats.attack_damage
	check(not points.allocate(StatusPoints.Stat.STR) and stats.attack_damage == damage_before, "Over-spending must be denied.")

	experience.add_experience(9)
	check(experience.level == 2 and points.get_points_remaining() == 5, "Level up must grant 5 status points.")

	check(not ui.is_open(), "Status panel must start hidden.")
	_push_key(KEY_C)
	check(ui.is_open(), "C must open the status panel.")
	_push_key(KEY_C)
	check(not ui.is_open(), "C must close the status panel.")
	_push_key(KEY_C)
	check(ui.is_open(), "C must reopen the status panel.")
	check(not attribute_ui.is_open(), "The attribute distribution panel must start hidden.")
	_push_key(KEY_P)
	check(attribute_ui.is_open(), "P must open the attribute distribution panel.")
	_push_key(KEY_P)
	check(not attribute_ui.is_open(), "P must close the attribute distribution panel.")
	_push_key(KEY_P)
	attribute_ui._window.position += Vector2(-80, 45)
	var attribute_position := attribute_ui._panel.get_global_rect().position
	_push_key(KEY_P)
	await process_frame
	_push_key(KEY_P)
	await process_frame
	check(attribute_ui._panel.get_global_rect().position.is_equal_approx(attribute_position), "Reopening a dragged attribute window must preserve its visible top-left position.")
	ui._window.position += Vector2(70, -35)
	var status_position := ui._panel.get_global_rect().position
	_push_key(KEY_C)
	await process_frame
	_push_key(KEY_C)
	await process_frame
	check(ui._panel.get_global_rect().position.is_equal_approx(status_position), "Reopening a dragged character window must preserve its visible top-left position.")
	await process_frame
	await process_frame

	var move_requests: Array[int] = [0]
	player_input.destination_requested.connect(func(_position: Vector2) -> void: move_requests[0] += 1)
	var panel_rect := ui._panel.get_global_rect()
	_click_at(panel_rect.position + Vector2(60, 12))
	check(move_requests[0] == 0, "A click on the open panel must not reach click-to-move.")
	_click_at(Vector2(40, root.get_visible_rect().size.y - 40))
	check(move_requests[0] == 1, "A click outside the panel must still reach click-to-move.")

	check(ui._equipment_slots.size() == 11, "The character panel must contain paper-doll equipment slots, not stat allocation controls.")
	check(points.allocate(StatusPoints.Stat.DEX), "Base stat allocation remains available to progression logic outside the character panel.")
	check(points.get_value(StatusPoints.Stat.DEX) == 2 and points.get_points_remaining() == 4, "Direct allocation must keep its existing semantics.")

	points.allocate(StatusPoints.Stat.STR)
	points.allocate(StatusPoints.Stat.AGI)
	points.allocate(StatusPoints.Stat.VIT)
	check(points.allocate(StatusPoints.Stat.INT), "Four more allocation must drain the level-up grant.")
	check(points.get_points_remaining() == 0, "Draining the last point must leave zero.")
	check(not points.allocate(StatusPoints.Stat.INT), "Zero points must deny further allocation.")

	# Batch allocation remains a data-level concern; the character sheet only
	# projects derived values and intentionally contains no plus controls.
	points.grant_level_up_points()
	points.grant_level_up_points()
	for _index in 5:
		points.allocate(StatusPoints.Stat.LUK)
	check(points.get_value(StatusPoints.Stat.LUK) == 5 and points.get_points_remaining() == 5, "A five-point batch must spend five points.")
	while points.allocate(StatusPoints.Stat.LUK):
		pass
	check(points.get_value(StatusPoints.Stat.LUK) == 10 and points.get_points_remaining() == 0, "A full batch must spend all remaining points.")

	var curve_actor := scene.instantiate() as CharacterBody3D
	root.add_child(curve_actor)
	await process_frame
	var curve_points := curve_actor.get_node("StatusPoints") as StatusPoints
	var curve_stats := curve_actor.stats as CharacterStats
	while curve_points.get_value(StatusPoints.Stat.AGI) < 10:
		curve_points.grant_level_up_points()
		check(curve_points.allocate(StatusPoints.Stat.AGI), "The curve grant must fund each AGI point.")
	check(absf(curve_stats.attack_speed - 1.21185) < 0.0005, "Ten ET AGI points must reach the early square-root value.")
	while curve_points.get_value(StatusPoints.Stat.AGI) < 99:
		curve_points.grant_level_up_points()
		check(curve_points.allocate(StatusPoints.Stat.AGI), "The curve grant must fund each AGI point to the cap.")
	check(absf(curve_stats.attack_speed - 2.22253) < 0.0005, "Full ET AGI must plateau at the expected square-root value.")
	check(_et_marginal_gain(1, 10) > _et_marginal_gain(90, 99), "Attack speed gain per AGI must diminish as AGI grows.")
	var matk_changed: Array[StringName] = []
	curve_stats.stat_changed.connect(func(property: StringName) -> void: matk_changed.append(property))
	var matk_examples: Dictionary[int, float] = {4: 4.0, 5: 5.5, 6: 6.5, 7: 8.0, 20: 30.0, 50: 124.5, 80: 268.5}
	for intelligence: int in matk_examples:
		while curve_points.get_value(StatusPoints.Stat.INT) < intelligence:
			if curve_points.get_points_remaining() == 0:
				curve_points.grant_level_up_points()
			curve_points.allocate(StatusPoints.Stat.INT)
		check(is_equal_approx(curve_stats.magic_attack, matk_examples[intelligence]), "MATK must follow the classic midpoint at INT %d." % intelligence)
	check(matk_changed.has(&"magic_attack"), "MATK changes must emit the shared stat notification.")
	var strength_examples: Dictionary[int, float] = {1: 21.0, 4: 24.0, 5: 25.5, 6: 26.5, 7: 28.0, 10: 32.5, 20: 50.0, 50: 144.5, 80: 288.5, 99: 397.5}
	for strength: int in strength_examples:
		while curve_points.get_value(StatusPoints.Stat.STR) < strength:
			if curve_points.get_points_remaining() == 0:
				curve_points.grant_level_up_points()
			curve_points.allocate(StatusPoints.Stat.STR)
		check(is_equal_approx(curve_stats.attack_damage, strength_examples[strength]), "STR physical attack must follow the shared midpoint curve at %d STR." % strength)
		if strength == 80:
			check(is_equal_approx(curve_stats.attack_damage - StatusPoints.BASE_ATTACK_DAMAGE, curve_stats.magic_attack), "Equal STR and INT must contribute equal physical and magical power.")
	curve_points.recompute()
	curve_points.recompute()
	check(is_equal_approx(curve_stats.attack_damage, 397.5), "Recomputation must not accumulate STR bonuses.")
	check(is_equal_approx(curve_stats.magic_attack, 268.5), "STR allocation must not alter INT-derived MATK.")
	curve_actor.queue_free()

	var second_actor := scene.instantiate() as CharacterBody3D
	root.add_child(second_actor)
	await process_frame
	var second_points := second_actor.get_node("StatusPoints") as StatusPoints
	check(stats != second_actor.stats, "Two player instances must own separate stats.")
	check(is_zero_approx(second_actor.stats.magic_attack), "MATK investment must not leak between players.")
	check(is_equal_approx(second_actor.stats.attack_damage, 20.0), "STR investment must not leak between players.")
	check(second_points.get_points_remaining() == 0 and second_points.get_value(StatusPoints.Stat.STR) == 0, "The second player must start fresh.")
	points.allocate(StatusPoints.Stat.STR)
	check(second_points.get_points_remaining() == 0 and second_points.get_value(StatusPoints.Stat.STR) == 0, "Allocation on one player must not leak to another.")
	second_actor.queue_free()
	player_actor.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: zero-point spawn, derived mapping, health deltas, over-spend denial, level-up grants, ET attack-speed curve, character panel toggle, click blocking, and instance independence")
	quit(0 if failures == 0 else 1)
