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

func run() -> void:
	var scene: PackedScene = load("res://scenes/player.tscn")
	var player_actor := scene.instantiate() as CharacterBody3D
	root.add_child(player_actor)
	await process_frame
	await process_frame
	var inventory := player_actor.get_node("Inventory") as Inventory
	var inventory_ui := player_actor.get_node("InventoryUI") as InventoryUI

	check(inventory.get_slot_count() == 20, "The starter bag must contain twenty fixed slots.")
	check(inventory.get_item(0).id == &"red_potion", "Slot one must contain the Red Potion.")
	check(inventory.get_item(1).id == &"iron_sword", "Slot two must contain the Iron Sword.")
	check(inventory.get_item(2).id == &"blue_gem", "Slot three must contain the Blue Gem.")
	check(inventory.get_item(3) == null, "Remaining starter bag slots must be empty.")
	check(inventory_ui._slots.size() == 20, "The UI must build and retain one Control per bag slot.")
	check(not inventory_ui.is_open(), "The inventory must start closed.")

	_push_key(KEY_I)
	await process_frame
	check(inventory_ui.is_open(), "I must open the inventory.")
	_push_key(KEY_I)
	await process_frame
	check(not inventory_ui.is_open(), "I must close the inventory.")

	var changes: Array[int] = [0]
	inventory.inventory_changed.connect(func() -> void: changes[0] += 1)
	inventory.move_slot(0, 5)
	check(inventory.get_item(0) == null and inventory.get_item(5).id == &"red_potion", "Moving to an empty slot must clear the source and fill the target.")
	check(changes[0] == 1, "A successful move must publish one inventory change.")
	inventory.move_slot(5, 1)
	check(inventory.get_item(1).id == &"red_potion" and inventory.get_item(5).id == &"iron_sword", "Moving onto a filled slot must swap the items.")
	check(changes[0] == 2, "A successful swap must publish one inventory change.")
	inventory.move_slot(3, 4)
	check(changes[0] == 2, "Moving from an empty source must be ignored.")
	check(inventory_ui._slots[1].item == inventory.get_item(1), "The UI must refresh its existing slot widgets after changes.")
	var target_slot := inventory_ui._slots[2]
	var drag_data: Dictionary = {"inventory": inventory, "slot_index": 1}
	check(target_slot._can_drop_data(Vector2.ZERO, drag_data), "A slot must accept native drag data from another slot in its bag.")
	target_slot._drop_data(Vector2.ZERO, drag_data)
	check(inventory.get_item(2).id == &"red_potion" and inventory.get_item(1).id == &"blue_gem", "Native slot drop must delegate a swap to Inventory.")
	check(not target_slot._can_drop_data(Vector2.ZERO, {"inventory": null, "slot_index": 1}), "A slot must reject drag data from another inventory.")
	var dropped: Array[ItemDefinition] = []
	inventory.item_dropped.connect(dropped.append)
	inventory_ui._on_slot_drag_ended(2, false, Vector2.ZERO)
	await process_frame
	check(inventory.get_item(2) == null and dropped.size() == 1 and dropped[0].id == &"red_potion", "Dropping outside the inventory must remove and publish the selected item.")

	player_actor.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: 20-slot inventory, I toggle, item resources, data-owned move/swap/drop, reactive reusable UI")
	quit(0 if failures == 0 else 1)
