extends Node3D
## Scene-level composition root for systems shared by player and monsters.

@export var player: CharacterBody3D
@export var inventory: Inventory
@export var pickup_spawner: ItemPickupSpawner
@export var poring: Monster
@export var poporing: Monster

func _ready() -> void:
	assert(player != null and inventory != null and pickup_spawner != null, "World requires player inventory and pickup spawner wiring.")
	assert(poring != null and poporing != null, "World requires its monster wiring.")
	inventory.item_dropped.connect(_on_player_item_dropped)
	poring.loot_dropped.connect(pickup_spawner.spawn_items)
	poporing.loot_dropped.connect(pickup_spawner.spawn_items)

func _on_player_item_dropped(item: ItemDefinition) -> void:
	pickup_spawner.spawn_item(item, player.global_position + Vector3(0, 0.02, 0))
