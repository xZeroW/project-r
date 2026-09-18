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

func _click_at(position: Vector2, with_shift: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.device = InputEvent.DEVICE_ID_MOUSE
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.shift_pressed = with_shift
		root.push_input(event, true)

func _drag(from: Vector2, to: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.device = InputEvent.DEVICE_ID_MOUSE
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	press.global_position = from
	press.shift_pressed = true
	root.push_input(press, true)
	var motion := InputEventMouseMotion.new()
	motion.device = InputEvent.DEVICE_ID_MOUSE
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = to
	motion.global_position = to
	root.push_input(motion, true)
	var release := InputEventMouseButton.new()
	release.device = InputEvent.DEVICE_ID_MOUSE
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	release.global_position = to
	root.push_input(release, true)
	await process_frame

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
	for slot: HotbarSlot in hotbar._slots:
		labels.append(slot.key_label)
	check(labels == ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"], "Slot labels must read 1 through 0.")

	var half := Vector2(10, 10)
	var east := HotbarSlot.square_edge_offset(half, 0.0)
	var corner := HotbarSlot.square_edge_offset(half, PI / 4.0)
	check(east.is_equal_approx(Vector2(10, 0)), "The cooldown pie must reach the slot's edge, not stop at an inscribed circle.")
	check(corner.is_equal_approx(Vector2(10, 10)), "The cooldown pie must reach the slot's corner, covering the whole square.")

	var visible_rect := root.get_visible_rect()
	var panel_rect := hotbar._panel.get_global_rect()
	check(absf(panel_rect.get_center().x - visible_rect.size.x * 0.5) < 4.0, "The bar must center horizontally.")
	check(absf((visible_rect.size.y - panel_rect.end.y) - 20.0) < 2.0, "The bar must sit ~20px above the bottom edge.")

	check(hotbar.get_slot_spell(0) != null and hotbar.get_slot_spell(0).id == &"aoe_damage", "Slot 1 must start bound to the AoE spell.")
	check(hotbar.get_slot_spell(1) != null and hotbar.get_slot_spell(1).id == &"heal", "Slot 2 must start bound to the heal spell.")
	for index: int in [2, 3, 4, 5, 6, 7, 8, 9]:
		check(hotbar.get_slot_spell(index) == null, "Slots 3–0 must start empty.")
		check((hotbar._slots[index] as HotbarSlot).mouse_filter == Control.MOUSE_FILTER_IGNORE, "Empty slots must be click-through when nothing is picked.")
	check((hotbar._slots[0] as HotbarSlot).mouse_filter == Control.MOUSE_FILTER_STOP, "Filled slots must stop clicks.")

	var activated: Array[int] = []
	hotbar.slot_activated.connect(activated.append)
	_push_key(KEY_1)
	_push_key(KEY_2)
	_push_key(KEY_0)
	check(activated == [0, 1, 9], "Keys 1, 2, and 0 must activate slots 0, 1, and 9.")

	var move_requests: Array[int] = [0]
	player_input.destination_requested.connect(func(_position: Vector2) -> void: move_requests[0] += 1)
	var empty_rect := (hotbar._slots[2] as HotbarSlot).get_global_rect()
	_click_at(empty_rect.get_center())
	await process_frame
	check(move_requests[0] == 1, "A click on an empty slot must fall through to click-to-move.")
	check(activated == [0, 1, 9], "A plain click on an empty slot must not activate it.")

	var filled_rect := (hotbar._slots[0] as HotbarSlot).get_global_rect()
	_click_at(filled_rect.get_center())
	await process_frame
	check(move_requests[0] == 1, "A click on a filled slot must not reach click-to-move.")
	check(activated == [0, 1, 9, 0], "A plain click on a filled slot must cast it.")

	_click_at(filled_rect.get_center(), true)
	await process_frame
	check(activated == [0, 1, 9, 0], "A Shift-click on a filled slot must not cast.")
	check(hotbar._picked == 0, "A short Shift-click must pick the slot's spell.")
	_click_at(empty_rect.get_center(), true)
	await process_frame
	check((hotbar._slots[2] as HotbarSlot).mouse_filter == Control.MOUSE_FILTER_STOP, "Empty slots must stop clicks while a spell is picked.")
	check(hotbar.get_slot_spell(0) == null and hotbar.get_slot_spell(2) != null and hotbar.get_slot_spell(2).id == &"aoe_damage", "Shift-clicking an empty slot must move the picked spell there.")
	check(hotbar._picked == -1, "Placing must clear the pick.")
	check((hotbar._slots[0] as HotbarSlot).mouse_filter == Control.MOUSE_FILTER_IGNORE, "The emptied slot must become click-through again.")
	check(move_requests[0] == 1, "Shift rearrangement must keep clicks swallowed, not leaking into click-to-move.")

	var aoe_slot := 2
	var heal_slot := 1
	_click_at((hotbar._slots[aoe_slot] as HotbarSlot).get_global_rect().get_center(), true)
	await process_frame
	_click_at((hotbar._slots[heal_slot] as HotbarSlot).get_global_rect().get_center(), true)
	await process_frame
	check(hotbar.get_slot_spell(heal_slot) != null and hotbar.get_slot_spell(heal_slot).id == &"aoe_damage" \
		and hotbar.get_slot_spell(aoe_slot) != null and hotbar.get_slot_spell(aoe_slot).id == &"heal", "Shift-clicking a filled slot must swap the two bindings.")

	_click_at((hotbar._slots[heal_slot] as HotbarSlot).get_global_rect().get_center(), true)
	await process_frame
	check(hotbar._picked == heal_slot, "Shift-clicking again must pick the spell.")
	_click_at((hotbar._slots[heal_slot] as HotbarSlot).get_global_rect().get_center(), true)
	await process_frame
	check(hotbar._picked == -1 and hotbar.get_slot_spell(heal_slot) != null and hotbar.get_slot_spell(heal_slot).id == &"aoe_damage", "Shift-clicking the picked slot again must cancel the pick.")

	_click_at((hotbar._slots[heal_slot] as HotbarSlot).get_global_rect().get_center())
	await process_frame
	check(activated == [0, 1, 9, 0, 1], "A plain click on a filled slot must keep casting.")
	_push_key(KEY_1)
	check(activated == [0, 1, 9, 0, 1, 0], "Hotbar keys must keep activating slots.")

	var drag_to := 5
	await _drag((hotbar._slots[heal_slot] as HotbarSlot).get_global_rect().get_center(), (hotbar._slots[drag_to] as HotbarSlot).get_global_rect().get_center())
	check(hotbar.get_slot_spell(heal_slot) == null and hotbar.get_slot_spell(drag_to) != null and hotbar.get_slot_spell(drag_to).id == &"aoe_damage", "Shift-dragging a spell onto an empty slot must move it.")
	check(hotbar._drag_preview == null, "The drag ghost must be freed once the drop resolves.")

	await _drag((hotbar._slots[drag_to] as HotbarSlot).get_global_rect().get_center(), (hotbar._slots[aoe_slot] as HotbarSlot).get_global_rect().get_center())
	check(hotbar.get_slot_spell(aoe_slot) != null and hotbar.get_slot_spell(aoe_slot).id == &"aoe_damage" \
		and hotbar.get_slot_spell(drag_to) != null and hotbar.get_slot_spell(drag_to).id == &"heal", "Shift-dragging onto a filled slot must swap the two bindings.")

	await _drag((hotbar._slots[aoe_slot] as HotbarSlot).get_global_rect().get_center(), Vector2(8, 8))
	check(hotbar.get_slot_spell(aoe_slot) != null and hotbar.get_slot_spell(aoe_slot).id == &"aoe_damage", "Releasing a drag off the bar must cancel without moving the spell.")
	check(hotbar._drag_preview == null, "A cancelled drag must still free the ghost.")
	check(move_requests[0] == 1, "Dragging must not leak into click-to-move.")

	_click_at((hotbar._slots[3] as HotbarSlot).get_global_rect().get_center())
	await process_frame
	check(move_requests[0] == 2, "Clicks must still fall through to click-to-move after rearranging.")

	player_actor.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: centered 10-slot hotbar, default spell bindings, 1–0 key activation, plain-click cast, Shift-click pick/place/swap/cancel, Shift-drag move/swap/cancel, click-through")
	quit(0 if failures == 0 else 1)