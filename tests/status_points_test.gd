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

func _click_at(position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.device = InputEvent.DEVICE_ID_MOUSE
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		root.push_input(event, true)

func run() -> void:
	var scene: PackedScene = load("res://scenes/player.tscn")
	var player_actor := scene.instantiate() as CharacterBody3D
	root.add_child(player_actor)
	await process_frame
	await process_frame
	var stats := player_actor.stats as CharacterStats
	var points := player_actor.get_node("StatusPoints") as StatusPoints
	var ui := player_actor.get_node("StatusUI") as StatusUI
	var experience := player_actor.get_node("Experience") as Experience
	var player_input := player_actor.get_node("PlayerInput") as PlayerInput

	check(points.get_points_remaining() == 5, "Players must spawn with 5 unspent points.")
	for stat: StatusPoints.Stat in StatusPoints.Stat.values():
		check(points.get_value(stat) == 1, "All six base stats must start at 1.")
	check(stats.attack_damage == 22.0, "Base STR must yield 20 + 2 attack damage.")
	check(is_equal_approx(stats.attack_speed, 1.03) and stats.evasion == 2.0, "Base AGI must yield attack speed and evasion.")
	check(stats.max_health == 110.0 and stats.max_mana == 105.0, "Base VIT/INT must yield 110 max health and 105 max mana.")
	check(stats.current_health == 110.0 and stats.mana == 105.0, "Raising a max at spawn must raise the current value to match.")

	check(points.allocate(StatusPoints.Stat.STR), "Allocation must succeed while points remain.")
	check(points.get_value(StatusPoints.Stat.STR) == 2 and points.get_points_remaining() == 4, "STR allocation must spend one point.")
	check(stats.attack_damage == 24.0, "Each STR point must add 2 attack damage.")
	check(points.allocate(StatusPoints.Stat.AGI) and is_equal_approx(stats.attack_speed, 1.06) and stats.evasion == 4.0, "Each AGI point must add attack speed and evasion.")

	stats.current_health = 50.0
	check(points.allocate(StatusPoints.Stat.VIT) and stats.max_health == 120.0, "Each VIT point must raise max health by 10.")
	check(stats.current_health == 60.0, "VIT must raise current health by the same delta.")
	stats.mana = 60.0
	check(points.allocate(StatusPoints.Stat.INT) and stats.max_mana == 110.0, "Each INT point must raise max mana by 5.")
	check(stats.mana == 65.0, "INT must raise current mana by the same delta.")

	check(points.allocate(StatusPoints.Stat.DEX) and stats.attack_damage == 24.0 and stats.max_health == 120.0, "DEX must stay data-only.")
	check(points.get_points_remaining() == 0, "Spending the last point must reach zero.")

	var damage_before := stats.attack_damage
	check(not points.allocate(StatusPoints.Stat.STR) and stats.attack_damage == damage_before, "Over-spending must be denied.")

	experience.add_experience(9)
	check(experience.level == 2 and points.get_points_remaining() == 5, "Level up must grant 5 status points.")
	check(ui._points_label.text.contains("5 points"), "Panel must show the granted point total.")

	check(not ui.is_open(), "Status panel must start hidden.")
	_push_key(KEY_C)
	check(ui.is_open(), "C must open the status panel.")
	_push_key(KEY_C)
	check(not ui.is_open(), "C must close the status panel.")
	_push_key(KEY_C)
	check(ui.is_open(), "C must reopen the status panel.")
	await process_frame
	await process_frame

	var move_requests: Array[int] = [0]
	player_input.destination_requested.connect(func(_position: Vector2) -> void: move_requests[0] += 1)
	var panel_rect := ui._panel.get_global_rect()
	_click_at(panel_rect.position + Vector2(60, 12))
	check(move_requests[0] == 0, "A click on the open panel must not reach click-to-move.")
	_click_at(Vector2(40, root.get_visible_rect().size.y - 40))
	check(move_requests[0] == 1, "A click outside the panel must still reach click-to-move.")

	var dex_button := ui._buttons[StatusPoints.Stat.DEX] as Button
	check(not dex_button.disabled, "Plus buttons must start enabled.")
	_click_at(dex_button.get_global_rect().get_center())
	check(points.get_value(StatusPoints.Stat.DEX) == 3 and points.get_points_remaining() == 4, "The plus button must spend a point.")
	check(move_requests[0] == 1, "Clicking a plus button must not leak into click-to-move.")

	points.allocate(StatusPoints.Stat.STR)
	points.allocate(StatusPoints.Stat.AGI)
	points.allocate(StatusPoints.Stat.VIT)
	check(points.allocate(StatusPoints.Stat.INT), "Four more allocation must drain the level-up grant.")
	check(points.get_points_remaining() == 0, "Draining the last point must leave zero.")
	for stat: StatusPoints.Stat in StatusPoints.Stat.values():
		check((ui._buttons[stat] as Button).disabled, "All plus buttons must disable at zero points.")
	check(not points.allocate(StatusPoints.Stat.INT), "Zero points must deny further allocation.")

	var second_actor := scene.instantiate() as CharacterBody3D
	root.add_child(second_actor)
	await process_frame
	var second_points := second_actor.get_node("StatusPoints") as StatusPoints
	check(stats != second_actor.stats, "Two player instances must own separate stats.")
	check(second_points.get_points_remaining() == 5 and second_points.get_value(StatusPoints.Stat.STR) == 1, "The second player must start fresh.")
	points.allocate(StatusPoints.Stat.STR)
	check(second_points.get_points_remaining() == 5 and second_points.get_value(StatusPoints.Stat.STR) == 1, "Allocation on one player must not leak to another.")
	second_actor.queue_free()
	player_actor.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: status base stats, derived mapping, health deltas, over-spend denial, level-up grants, UI toggle/plus/disable, click blocking, and instance independence")
	quit(0 if failures == 0 else 1)