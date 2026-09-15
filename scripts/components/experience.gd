class_name Experience
extends Node
## Owns per-character, session-local Base Level and EXP.

signal experience_gained(amount: int)
signal experience_lost(amount: int)
signal leveled_up(level: int)
signal progression_changed

@export var curve: ExperienceCurve

var level: int = 1
var current_experience: int = 0

func _ready() -> void:
	assert(curve != null, "Experience requires a level curve.")
	for requirement: int in curve.requirements:
		assert(requirement > 0, "EXP requirements must be positive.")

func is_max_level() -> bool:
	return level >= curve.get_max_level()

func get_required_experience() -> int:
	return curve.get_required_experience(level)

func add_experience(amount: int) -> void:
	if amount <= 0 or is_max_level():
		return
	experience_gained.emit(amount)
	# Consume the award a level at a time, retaining overflow without integer addition overflow.
	var remaining := amount
	while remaining > 0 and not is_max_level():
		var needed := get_required_experience() - current_experience
		if remaining < needed:
			current_experience += remaining
			break
		remaining -= needed
		current_experience = 0
		level += 1
		leveled_up.emit(level)
	progression_changed.emit()

## Loses up to [amount] current-level EXP without ever de-leveling.
func lose_experience(amount: int) -> void:
	if amount <= 0 or is_max_level():
		return
	var applied := mini(amount, current_experience)
	if applied <= 0:
		return
	current_experience -= applied
	experience_lost.emit(applied)
	progression_changed.emit()
