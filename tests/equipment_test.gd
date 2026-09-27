extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var scene: PackedScene = load("res://scenes/player.tscn")
	var player_actor := scene.instantiate() as CharacterBody3D
	root.add_child(player_actor)
	await process_frame
	await process_frame
	var inventory := player_actor.get_node("Inventory") as Inventory
	var equipment := player_actor.get_node("Equipment") as Equipment
	var status_points := player_actor.get_node("StatusPoints") as StatusPoints
	var status_ui := player_actor.get_node("StatusUI") as StatusUI
	var stats := player_actor.get("stats") as CharacterStats
	var weapon_slot := ItemDefinition.EquipmentSlot.WEAPON

	check(inventory.get_item(1).equipment_slot == weapon_slot, "The starter Iron Sword must declare itself as a weapon.")
	check(is_equal_approx(stats.attack_damage, 20.0), "Unequipped gear must not alter the base physical damage.")
	check(equipment.equip_from_inventory(inventory, 1, weapon_slot), "A matching bag item must equip into its typed paper-doll slot.")
	check(equipment.get_item(weapon_slot).id == &"iron_sword" and inventory.get_item(1) == null, "Equipping must move the item out of its source bag cell.")
	check(is_equal_approx(stats.attack_damage, 28.0), "The equipped sword modifier must be folded into derived physical damage.")
	check(status_ui._derived_label.text.contains("ATK 28.0"), "The Offence panel must react to an equipped weapon modifier.")
	check(status_ui._equipment_slots.size() == 11, "The character sheet must retain its eleven paper-doll slot controls, including two rings.")
	var weapon_control: EquipmentSlotControl = status_ui._equipment_slots.filter(func(slot: EquipmentSlotControl) -> bool: return slot.slot == weapon_slot)[0]
	check(weapon_control.item == equipment.get_item(weapon_slot), "Paper-doll controls must refresh when equipment changes.")
	check(not equipment.equip_from_inventory(inventory, 0, weapon_slot), "Consumables must not equip into a weapon slot.")
	check(equipment.unequip_to_inventory(inventory, 1, weapon_slot), "Dragging an equipped item onto a bag cell must unequip it.")
	check(inventory.get_item(1).id == &"iron_sword" and equipment.get_item(weapon_slot) == null, "Unequipping into an empty cell must clear the equipment slot.")
	check(is_equal_approx(stats.attack_damage, 20.0), "Removing the weapon must restore the derived base damage.")
	check(status_points.equipment == equipment, "StatusPoints must read equipment bonuses through the equipment component.")

	player_actor.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: typed equipment slots, bag exchanges, reactive paper doll, and stat modifiers")
	quit(0 if failures == 0 else 1)
