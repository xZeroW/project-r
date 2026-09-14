class_name CharacterStats
extends Resource
## Mutable gameplay stats owned independently by each character instance.

@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var mana: float = 100.0
@export var movement_speed: float = 4.0
@export var attack_speed: float = 1.0
@export var armour: float = 0.0
@export var evasion: float = 0.0
@export var block: float = 0.0

func _init() -> void:
	resource_local_to_scene = true
