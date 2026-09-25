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
	var poring := world.get_node("Poring") as Monster
	var player_combat := player.get_node("Combat") as MeleeCombat
	var inventory := player.get_node("Inventory") as Inventory
	var click_movement := player.get_node("ClickMovement") as ClickMovement
	player.set_physics_process(false)
	poring.set_physics_process(false)
	var navigation_map := player.get_world_3d().navigation_map
	var navigation_ready: bool = false
	for tick: int in 300:
		await physics_frame
		if NavigationServer3D.map_get_iteration_id(navigation_map) > 0 and NavigationServer3D.map_get_closest_point_owner(navigation_map, Vector3.ZERO).is_valid():
			navigation_ready = true
			break
	check(navigation_ready, "Loot routes require the baked navigation map.")
	if not navigation_ready:
		world.queue_free()
		quit(1)
		return

	check(poring.definition.loot_items.size() == 1 and poring.definition.loot_items[0].id == &"red_potion", "Poring must define its Red Potion drop in data.")
	var force_hit := func() -> float: return 0.0
	poring.combat.resolver.dice = force_hit
	var lethal_hit := DamageData.new()
	lethal_hit.source = player
	lethal_hit.amount = 1000.0
	poring.combat.take_damage(lethal_hit, player_combat)
	await process_frame

	var pickup: ItemPickup
	for child: Node in world.get_children():
		if child is ItemPickup:
			pickup = child as ItemPickup
			break
	check(pickup != null, "A defeated monster must create a world pickup.")
	if pickup != null:
		check(pickup.item.id == &"red_potion", "The spawned pickup must carry the monster's defined item.")
		check(inventory.get_item(3) == null, "Drops must remain in the world before collection.")
		# Moving through a pickup is intentionally inert; only an explicit loot route
		# may collect it.
		player.global_position = pickup.global_position
		await physics_frame
		check(inventory.get_item(3) == null, "Proximity alone must not collect a pickup.")
		player.global_position = Vector3(0, 1.15, 0)
		player.reset_physics_interpolation()
		click_movement.request_loot_destination(player, pickup)
	check(click_movement.has_destination(), "Selecting loot must route the player to its navigation point.")
	if click_movement.has_destination():
		for step: int in 20:
			if not click_movement.has_destination():
				break
			player.global_position = click_movement._path[click_movement._path_index]
			click_movement.get_direction(player, 4.0, 0.1)
		await process_frame
		check(inventory.get_item(3) != null and inventory.get_item(3).id == &"red_potion", "Arriving at selected loot must add it to the first empty inventory slot.")
		check(not is_instance_valid(pickup), "A collected pickup must be freed.")
		inventory.drop_slot(3)
		await process_frame
		var discarded_pickup: ItemPickup
		for child: Node in world.get_children():
			if child is ItemPickup:
				discarded_pickup = child as ItemPickup
				break
		check(discarded_pickup != null and discarded_pickup.item.id == &"red_potion", "World orchestration must turn a discarded inventory item into a matching pickup.")
		if discarded_pickup != null:
			check(discarded_pickup.global_position.distance_to(player.global_position + Vector3(0, 0.02, 0)) < 0.01, "Discarded items must spawn at the player's feet.")

	var full_inventory := Inventory.new()
	full_inventory.slot_count = 1
	full_inventory.initial_items = [load("res://resources/items/red_potion.tres") as ItemDefinition]
	root.add_child(full_inventory)
	await process_frame
	check(full_inventory.is_full(), "A bag with every slot occupied must report full.")
	check(not full_inventory.try_add_item(load("res://resources/items/blue_gem.tres") as ItemDefinition), "Adding to a full non-stacking bag must fail without overwriting an item.")
	full_inventory.queue_free()
	world.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: data-defined monster drops, persistent world pickup, collection, inventory capacity")
	quit(0 if failures == 0 else 1)
