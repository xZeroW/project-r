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
const EVASION_PER_AGI := 1.0
const BASE_ACC := 0.0
const ACC_PER_DEX := 1.0
const CRIT_PER_LUK := 0.3
# Ragnarok M: Eternal Love attack-speed model (port). ET shows attack speed as
# hits-per-second percent: panel = 50 / (200 − stat_aspd), and AGI feeds a
# square-root curve with diminishing returns instead of classic RO's linear
# `4·AGI/1000`. gain_per_point therefore collapses as AGI grows.
const ET_JOB_BASE_ASPD := 156.0              # ET physical-job base (unarmed)
const ET_AGI_ASPD_WEIGHT := 9.9999           # ET's √(10·AGI) term; 9.9999 dodges exact squares
const ET_ASPD_CORRECTION_FACTOR := 7.15      # ET's (√205 − √AGI) correction scale
const ET_ASPD_CAP := 189.583333333333        # final-ASPD ceiling (the 480% panel cap)

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

## Prototype rule: each Base level adds 5 stat points. A fresh spawn has zero points;
## the first level-up (wired by the player orchestrator) grants the first batch.
func grant_level_up_points() -> void:
	points_remaining += BASE_POINTS_PER_LEVEL
	points_remaining_changed.emit(points_remaining)

## ET native 200-scale (delay) attack speed for [agi]. Skill and equipment ASPD
## are absent from the prototype, so the stat term is:
##   job base − (√205 − √AGI) / 7.15 + √(9.9999·AGI) · penalty
## where a fast job base (>145) weights AGI with `1 − (base − 144) / 50`.
func et_stat_aspd(agi: int) -> float:
	var penalty := 0.96 if ET_JOB_BASE_ASPD <= 145.0 else 1.0 - (ET_JOB_BASE_ASPD - 144.0) / 50.0
	var value := ET_JOB_BASE_ASPD
	value -= (sqrt(205.0) - sqrt(float(agi))) / ET_ASPD_CORRECTION_FACTOR
	value += sqrt(ET_AGI_ASPD_WEIGHT * float(agi)) * penalty
	value = roundf(value * 1000.0) / 1000.0
	return minf(value, ET_ASPD_CAP)

## ET panel attack speed: attacks per second as `50 / (200 − stat_aspd)`.
func et_panel_aspd(agi: int) -> float:
	return 50.0 / (200.0 - et_stat_aspd(agi))

## Shared physical/magical contribution, using the classic INT MATK midpoint.
## STR feeds physical attack; INT feeds magic attack with identical scaling.
func attribute_attack_power(value: int) -> float:
	var attribute := float(value)
	var minimum_bonus := floorf(attribute / 7.0)
	var maximum_bonus := floorf(attribute / 5.0)
	return attribute + (minimum_bonus * minimum_bonus + maximum_bonus * maximum_bonus) / 2.0

## Pushes derived values into the shared CharacterStats. Accuracy (DEX) and
## evasion (AGI) feed the shared combat resolver's single RO-contested roll at
## 1 point each, so they cancel 1-for-1; crit (LUK) rolls on landed hits.
## Attack speed keeps `BASE_ATTACK_SPEED` at zero AGI and scales with the ET
## square-root curve, plateauing as AGI grows.
func recompute() -> void:
	var previous_max_health := stats.max_health
	var previous_max_mana := stats.max_mana
	stats.attack_damage = BASE_ATTACK_DAMAGE + attribute_attack_power(_values[Stat.STR])
	stats.magic_attack = attribute_attack_power(_values[Stat.INT])
	stats.attack_speed = BASE_ATTACK_SPEED * et_panel_aspd(_values[Stat.AGI]) / et_panel_aspd(0)
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
