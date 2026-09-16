class_name CharacterStats
extends Resource
## Mutable gameplay stats owned independently by each character instance.

@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var max_mana: float = 100.0
@export var mana: float = 100.0
## Base level. Drives the hit-chance level modifier; the player syncs it from
## `Experience`, monsters read it from their definition and never gain EXP.
@export var level: int = 1
@export var movement_speed: float = 4.0
@export var attack_speed: float = 1.0
@export var attack_damage: float = 20.0
@export var armour: float = 0.0
@export var block: float = 0.0
## Attacker accuracy in percent (e.g. 90 = 90% stage-one hit chance before the
## level modifier). A failed stage-one roll is a plain miss; evasion rolls after it.
@export var acc: float = 90.0
## Defender's percent chance to dodge a successful stage-one hit.
@export var evasion: float = 0.0
## Attacker critical chance in percent (e.g. 0.3 = 0.3% on a landed hit).
@export var crit: float = 0.0

func _init() -> void:
	resource_local_to_scene = true
