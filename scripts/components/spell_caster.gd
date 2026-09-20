class_name SpellCaster
extends Node
## Owns the spellbook, POE-style tag-scaled power, mana costs, and the shared
## 1s global cooldown plus each spell's own longer cooldown. Spells execute on
## the existing melee damage pipeline (same popups, aggro, and EXP credit).

const GLOBAL_COOLDOWN: float = 1.0

signal spell_cast(spell: SpellDefinition)
signal cast_denied(spell: SpellDefinition, reason: StringName)
signal healed(amount: float)
signal cooldowns_changed

@export var stats: CharacterStats
@export var combat: MeleeCombat
@export var targeting: Targeting
@export var body: CharacterBody3D
@export var spells: Array[SpellDefinition] = []

var _global_cooldown_remaining: float = 0.0
var _cooldowns: Dictionary[SpellDefinition, float] = {}
var _increases: Dictionary[int, float] = {}

func _ready() -> void:
	assert(stats != null, "SpellCaster requires character stats.")
	assert(combat != null, "SpellCaster requires the player's MeleeCombat for spell credit and hit rolls.")

## POE-style increased power: bonuses add across sources and matching tags.
## Pass the opposite percentage to undo a previously added bonus.
func add_increase(tag: int, percent: float) -> void:
	_increases[tag] = _increases.get(tag, 0.0) + percent

func get_total_power(spell: SpellDefinition) -> float:
	var increase: float = 0.0
	# Iterate modifier keys so duplicate authored tags cannot double-count.
	for tag: int in _increases:
		if tag in spell.tags:
			increase += _increases[tag]
	return spell.power * maxf(0.0, 1.0 + increase / 100.0)

func get_spell(id: StringName) -> SpellDefinition:
	for spell: SpellDefinition in spells:
		if spell.id == id:
			return spell
	return null

func get_global_cooldown_remaining() -> float:
	return _global_cooldown_remaining

## What a hotbar pie should show: the global cooldown plus this spell's own
## (possibly longer) cooldown, whichever is still running.
func get_cooldown_remaining(spell: SpellDefinition) -> float:
	return maxf(_global_cooldown_remaining, _cooldowns.get(spell, 0.0))

## The duration a pie divides by: while the spell's own (longer) cooldown runs,
## that duration; otherwise the 1s global cooldown. Without this, a spell locked
## only by the global cooldown would draw gcd/own_cooldown (e.g. 1/3 for the AoE)
## instead of sweeping a full rotation across the 1s global cooldown.
func get_cooldown_total(spell: SpellDefinition) -> float:
	if _cooldowns.get(spell, 0.0) > 0.0:
		return maxf(GLOBAL_COOLDOWN, spell.cooldown)
	return GLOBAL_COOLDOWN

func can_cast(spell: SpellDefinition) -> bool:
	return spells.has(spell) \
		and _global_cooldown_remaining <= 0.0 \
		and _cooldowns.get(spell, 0.0) <= 0.0 \
		and stats.mana >= spell.mana_cost

func try_cast(spell: SpellDefinition) -> bool:
	if not spells.has(spell):
		cast_denied.emit(spell, &"unknown")
		return false
	if _global_cooldown_remaining > 0.0:
		cast_denied.emit(spell, &"global_cooldown")
		return false
	if _cooldowns.get(spell, 0.0) > 0.0:
		cast_denied.emit(spell, &"cooldown")
		return false
	if stats.mana < spell.mana_cost:
		cast_denied.emit(spell, &"mana")
		return false
	stats.mana = maxf(0.0, stats.mana - spell.mana_cost)
	var power := get_total_power(spell)
	match spell.behavior:
		SpellDefinition.Behavior.AREA_DAMAGE:
			_cast_area_damage(spell, power)
		SpellDefinition.Behavior.HEAL:
			_cast_heal(power)
	_global_cooldown_remaining = GLOBAL_COOLDOWN
	_cooldowns[spell] = maxf(GLOBAL_COOLDOWN, spell.cooldown)
	spell_cast.emit(spell)
	cooldowns_changed.emit()
	return true

func _process(delta: float) -> void:
	if _global_cooldown_remaining <= 0.0 and _cooldowns.is_empty():
		return
	_global_cooldown_remaining = maxf(0.0, _global_cooldown_remaining - delta)
	for spell: SpellDefinition in _cooldowns.keys():
		var remaining := _cooldowns[spell] - delta
		if remaining <= 0.0:
			_cooldowns.erase(spell)
		else:
			_cooldowns[spell] = remaining
	# Emit even on the frame a timer hits zero so pies clear.
	cooldowns_changed.emit()

## AREA_DAMAGE targets the currently selected monster, falling back to the
## caster's own position.
func get_cast_point() -> Vector3:
	if targeting != null and targeting.has_target():
		return targeting.target.body.global_position
	return body.global_position

func _cast_area_damage(spell: SpellDefinition, power: float) -> void:
	var center := get_cast_point()
	for monster: Node in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(monster):
			continue
		var monster_combat := monster.get_node_or_null("Combat") as MeleeCombat
		if monster_combat == null or not monster_combat.damage_enabled or monster_combat.stats.current_health <= 0.0:
			continue
		var offset := monster_combat.body.global_position - center
		offset.y = 0.0
		if offset.length() > spell.radius:
			continue
		var data := DamageData.new()
		data.amount = power
		data.source = body
		monster_combat.take_damage(data, combat)

func _cast_heal(power: float) -> void:
	var previous := stats.current_health
	stats.current_health = minf(stats.max_health, stats.current_health + power)
	healed.emit(stats.current_health - previous)
