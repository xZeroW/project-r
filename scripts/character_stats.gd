class_name CharacterStats
extends Resource
## Mutable gameplay stats owned independently by each character instance.
## Emits `stat_changed(property)` whenever any stat is written so UIs can react
## instead of polling.

signal stat_changed(property: StringName)

# --- Health & mana -----------------------------------------------------------

var _max_health: float = 100.0
@export var max_health: float:
	get:
		return _max_health
	set(value):
		_max_health = value
		stat_changed.emit(&"max_health")

var _current_health: float = 100.0
@export var current_health: float:
	get:
		return _current_health
	set(value):
		_current_health = value
		stat_changed.emit(&"current_health")

var _max_mana: float = 100.0
@export var max_mana: float:
	get:
		return _max_mana
	set(value):
		_max_mana = value
		stat_changed.emit(&"max_mana")

var _mana: float = 100.0
@export var mana: float:
	get:
		return _mana
	set(value):
		_mana = value
		stat_changed.emit(&"mana")

# --- Level -------------------------------------------------------------------

var _level: int = 1
@export var level: int:
	get:
		return _level
	set(value):
		_level = value
		stat_changed.emit(&"level")

# --- Derived / combat --------------------------------------------------------

var _movement_speed: float = 4.0
@export var movement_speed: float:
	get:
		return _movement_speed
	set(value):
		_movement_speed = value
		stat_changed.emit(&"movement_speed")

var _attack_speed: float = 1.0
@export var attack_speed: float:
	get:
		return _attack_speed
	set(value):
		_attack_speed = value
		stat_changed.emit(&"attack_speed")

var _attack_damage: float = 20.0
@export var attack_damage: float:
	get:
		return _attack_damage
	set(value):
		_attack_damage = value
		stat_changed.emit(&"attack_damage")

## Deterministic midpoint of classic RO's INT-derived MATK range.
var _magic_attack: float = 0.0
@export var magic_attack: float:
	get:
		return _magic_attack
	set(value):
		_magic_attack = maxf(0.0, value)
		stat_changed.emit(&"magic_attack")

var _armour: float = 0.0
@export var armour: float:
	get:
		return _armour
	set(value):
		_armour = value
		stat_changed.emit(&"armour")

var _block: float = 0.0
@export var block: float:
	get:
		return _block
	set(value):
		_block = value
		stat_changed.emit(&"block")

## Attacker accuracy contribution to the contested RO hit roll (HIT ≈ DEX).
## `hit% = clamp(95 + acc + level − evasion, 5, 95)`: each acc point raises
## the attacker's chance, cancelled 1-for-1 by the defender's evasion.
var _acc: float = 0.0
@export var acc: float:
	get:
		return _acc
	set(value):
		_acc = value
		stat_changed.emit(&"acc")

## Defender evasion contribution that competes with the attacker's accuracy in
## the same single contested roll (FLEE ≈ AGI). A failed roll reads EVADED when
## evasion outscores accuracy, MISS otherwise.
var _evasion: float = 0.0
@export var evasion: float:
	get:
		return _evasion
	set(value):
		_evasion = value
		stat_changed.emit(&"evasion")

## Attacker critical chance in percent (e.g. 0.3 = 0.3% on a landed hit).
var _crit: float = 0.0
@export var crit: float:
	get:
		return _crit
	set(value):
		_crit = value
		stat_changed.emit(&"crit")

func _init() -> void:
	resource_local_to_scene = true
