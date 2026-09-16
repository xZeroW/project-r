class_name StatusPoints
extends Node
## Owns the six Ragnarok base stats and derives combat values into a shared CharacterStats.

enum Stat { STR, AGI, VIT, INT, DEX, LUK }

signal allocated(stat: Stat)
signal points_remaining_changed(remaining: int)

const BASE_POINTS_PER_LEVEL := 5
const BASE_MAX_HEALTH := 100.0
const BASE_MAX_MANA := 100.0
const BASE_ATTACK_DAMAGE := 20.0
const BASE_ATTACK_SPEED := 1.0
const HEALTH_PER_VIT := 10.0
const MANA_PER_INT := 5.0
const DAMAGE_PER_STR := 2.0
const ATTACK_SPEED_PER_AGI := 0.03
const EVASION_PER_AGI := 2.0
const BASE_ACC := 90.0
const ACC_PER_DEX := 2.0
const CRIT_PER_LUK := 0.3

@export var stats: CharacterStats

var points_remaining: int = 0

var _values: Dictionary[Stat, int] = {
	Stat.STR: 0,
	Stat.AGI: 0,
	Stat.VIT: 0,
	Stat.INT: 0,
	Stat.DEX: 0,
	Stat.LUK: 0,
}

func _ready() -> void:
	assert(stats != null, "StatusPoints requires character stats.")
	recompute()

func get_value(stat: Stat) -> int:
	return _values[stat]

func get_points_remaining() -> int:
	return points_remaining

func stat_name(stat: Stat) -> String:
	match stat:
		Stat.STR:
			return "STR"
		Stat.AGI:
			return "AGI"
		Stat.VIT:
			return "VIT"
		Stat.INT:
			return "INT"
		Stat.DEX:
			return "DEX"
		Stat.LUK:
			return "LUK"
	return ""

## Spends one point into [stat]. Returns false when no points remain.
func allocate(stat: Stat) -> bool:
	if points_remaining <= 0 or not _values.has(stat):
		return false
	_values[stat] += 1
	points_remaining -= 1
	recompute()
	allocated.emit(stat)
	points_remaining_changed.emit(points_remaining)
	return true

## RO classic: each Base level adds 5 stat points. A fresh spawn has zero points;
## the first level-up (wired by the player orchestrator) grants the first batch.
func grant_level_up_points() -> void:
	points_remaining += BASE_POINTS_PER_LEVEL
	points_remaining_changed.emit(points_remaining)

## Pushes derived values into the shared CharacterStats. Accuracy (DEX) and crit
## (LUK) feed the shared combat resolver; evasion (AGI) becomes a dodge roll that
## runs only after a stage-one hit succeeds.
func recompute() -> void:
	var previous_max_health := stats.max_health
	var previous_max_mana := stats.max_mana
	stats.attack_damage = BASE_ATTACK_DAMAGE + DAMAGE_PER_STR * _values[Stat.STR]
	stats.attack_speed = BASE_ATTACK_SPEED + ATTACK_SPEED_PER_AGI * _values[Stat.AGI]
	stats.evasion = EVASION_PER_AGI * _values[Stat.AGI]
	stats.acc = BASE_ACC + ACC_PER_DEX * _values[Stat.DEX]
	stats.crit = CRIT_PER_LUK * _values[Stat.LUK]
	var new_max_health := BASE_MAX_HEALTH + HEALTH_PER_VIT * _values[Stat.VIT]
	var new_max_mana := BASE_MAX_MANA + MANA_PER_INT * _values[Stat.INT]
	# RO behavior: raising a maximum raises the current value by the same delta, so
	# spending VIT/INT heals the difference. Current values clamp to the new maximum.
	if new_max_health > previous_max_health:
		stats.current_health += new_max_health - previous_max_health
	if new_max_mana > previous_max_mana:
		stats.mana += new_max_mana - previous_max_mana
	stats.max_health = new_max_health
	stats.max_mana = new_max_mana
	stats.current_health = minf(stats.current_health, stats.max_health)
	stats.mana = minf(stats.mana, stats.max_mana)
