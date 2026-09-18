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
	var hotbar := player_actor.get_node("Hotbar") as Hotbar
	var player_input := player_actor.get_node("PlayerInput") as PlayerInput

	check(hotbar.get_slot_count() == 10, "Hotbar must expose ten slots.")
	var labels: Array[String] = []
	for button: Button in hotbar._slots:
		labels.append(button.text)
	check(labels == ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"], "Slot labels must read 1 through 0.")

	var visible_rect := root.get_visible_rect()
	var panel_rect := hotbar._panel.get_global_rect()
	check(absf(panel_rect.get_center().x - visible_rect.size.x * 0.5) < 4.0, "The bar must center horizontally.")
	check(absf((visible_rect.size.y - panel_rect.end.y) - 20.0) < 2.0, "The bar must sit ~20px above the bottom edge.")

	var activated: Array[int] = []
	hotbar.slot_activated.connect(activated.append)
	_push_key(KEY_1)
	_push_key(KEY_2)
	_push_key(KEY_0)
	check(activated == [0, 1, 9], "Keys 1, 2, and 0 must activate slots 0, 1, and 9.")

	for index: int in hotbar.get_slot_count():
		check(not hotbar.is_slot_filled(index), "All slots must start empty.")
		check((hotbar._slots[index] as Button).mouse_filter == Control.MOUSE_FILTER_IGNORE, "Empty slots must not intercept mouse clicks.")

	var move_requests: Array[int] = [0]
	player_input.destination_requested.connect(func(_position: Vector2) -> void: move_requests[0] += 1)
	var first_rect := (hotbar._slots[0] as Button).get_global_rect()
	_click_at(first_rect.get_center())
	await process_frame
	check(move_requests[0] == 1, "A click on an empty slot must fall through to click-to-move.")
	check(activated == [0, 1, 9], "Clicking an empty slot must not activate it.")

	hotbar.set_slot_filled(0, true)
	check(hotbar.is_slot_filled(0), "Slot 0 must report filled.")
	check(not (hotbar._slots[0] as Button).disabled, "A filled slot must be enabled.")
	check((hotbar._slots[0] as Button).mouse_filter == Control.MOUSE_FILTER_STOP, "A filled slot must intercept mouse clicks.")
	check((hotbar._slots[1] as Button).disabled and (hotbar._slots[1] as Button).mouse_filter == Control.MOUSE_FILTER_IGNORE, "Unfilled neighbors must stay dimmed and click-through.")

	_click_at(first_rect.get_center())
	await process_frame
	check(move_requests[0] == 1, "A click on a filled slot must not reach click-to-move.")
	check(activated == [0, 1, 9, 0], "Clicking a filled slot must activate it.")

	player_actor.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: centered 10-slot hotbar, 1–0 key activation, empty-slot click-through, filled-slot click capture")
	quit(0 if failures == 0 else 1)