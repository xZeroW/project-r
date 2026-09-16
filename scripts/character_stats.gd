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
## Attacker accuracy contribution to the contested RO hit roll (HIT ≈ DEX).
## `hit% = clamp(95 + acc + level − evasion, 5, 95)`: each acc point raises
## the attacker's chance, cancelled 1-for-1 by the defender's evasion.
@export var acc: float = 0.0
## Defender evasion contribution that competes with the attacker's accuracy in
## the same single contested roll (FLEE ≈ AGI). A failed roll reads EVADED when
## evasion outscores accuracy, MISS otherwise.
@export var evasion: float = 0.0
## Attacker critical chance in percent (e.g. 0.3 = 0.3% on a landed hit).
@export var crit: float = 0.0

func _init() -> void:
	resource_local_to_scene = true
