class_name ItemPickupSpawner
extends Node
## World-owned factory for all loot pickups. Producers emit intent; this single
## component owns scene creation, placement, and Inventory injection.

@export var inventory: Inventory
@export var spawn_root: Node3D

func _ready() -> void:
	assert(inventory != null, "ItemPickupSpawner requires an Inventory.")
	assert(spawn_root != null, "ItemPickupSpawner requires a world spawn root.")

func spawn_item(item: ItemDefinition, world_position: Vector3) -> ItemPickup:
	if item == null:
		return null
	var pickup := ItemPickup.new()
	pickup.item = item
	pickup.inventory = inventory
	spawn_root.add_child(pickup)
	pickup.global_position = world_position
	return pickup

func spawn_items(items: Array[ItemDefinition], world_position: Vector3) -> void:
	for index: int in items.size():
		var angle := TAU * float(index) / float(maxi(1, items.size()))
		spawn_item(items[index], world_position + Vector3(cos(angle), 0.02, sin(angle)) * 0.38)
