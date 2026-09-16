class_name MeleeCombat
extends Node
## Shared single-target melee resolution. Called only during physics updates.

signal damaged(data: DamageData)
signal died
signal defeated_enemy(enemy: MeleeCombat)
signal missed
signal evaded
signal blocked

@export var stats: CharacterStats
@export var reach: float = 1.8
@export var visual_path: NodePath
@export_range(0, 1000000000, 1) var base_experience_reward: int = 0

@onready var body: CharacterBody3D = get_parent() as CharacterBody3D
@onready var visual: AnimatedSprite3D = get_node(visual_path) as AnimatedSprite3D

var resolver: CombatResolver
var cooldown: float = 0.0
var invulnerability: float = 0.0
var damage_enabled: bool = true
## The sprite color a monster returns to after the damage flash; a definition
## tint can set this, letting the flash run on visual.modulate without erasing it.
var base_modulate: Color = Color.WHITE

func _ready() -> void:
	resolver = CombatResolver.new()

func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	if stats.current_health > 0.0:
		visual.modulate = Color(1, 0.35, 0.35) if invulnerability > 0.0 else base_modulate

func can_reach(other: MeleeCombat) -> bool:
	if not is_instance_valid(other) or not damage_enabled or not other.damage_enabled or stats.current_health <= 0.0 or other.stats.current_health <= 0.0:
		return false
	var offset := other.body.global_position - body.global_position
	if Vector2(offset.x, offset.z).length() > reach or absf(offset.y) > 1.5:
		return false
	# Use collider centers so differing sprite/root offsets do not aim below ground.
	var from := (body.get_node("CollisionShape3D") as Node3D).global_position
	var to := (other.body.get_node("CollisionShape3D") as Node3D).global_position
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [body.get_rid(), other.body.get_rid()])
	return body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func attack(other: MeleeCombat) -> bool:
	if cooldown > 0.0 or stats.attack_speed <= 0.0 or not can_reach(other):
		return false
	cooldown = 1.0 / stats.attack_speed
	var data := DamageData.new()
	data.amount = stats.attack_damage
	data.source = body
	other.take_damage(data, self)
	return true

func take_damage(data: DamageData, attacker: MeleeCombat) -> void:
	if not damage_enabled or stats.current_health <= 0.0 or invulnerability > 0.0 or data.amount <= 0.0:
		return
	var result := resolver.resolve_incoming(attacker.stats if attacker != null else null, stats)
	match result.kind:
		CombatResolver.ResultKind.MISS:
			missed.emit()
			return
		CombatResolver.ResultKind.EVADED:
			evaded.emit()
			return
		CombatResolver.ResultKind.BLOCKED:
			blocked.emit()
	var damage_amount := data.amount
	if result.kind == CombatResolver.ResultKind.BLOCKED:
		damage_amount *= CombatResolver.BLOCK_DAMAGE_MULTIPLIER
	if result.is_crit:
		damage_amount *= CombatResolver.CRIT_DAMAGE_MULTIPLIER
	var previous_health := stats.current_health
	stats.current_health = maxf(0.0, stats.current_health - maxf(0.0, damage_amount - stats.armour))
	var resolved := DamageData.new()
	resolved.amount = data.amount
	resolved.is_crit = result.is_crit
	resolved.source = data.source
	resolved.applied_amount = previous_health - stats.current_health
	invulnerability = 0.15
	damaged.emit(resolved)
	if stats.current_health <= 0.0:
		body.velocity = Vector3.ZERO
		(body.get_node("CollisionShape3D") as CollisionShape3D).set_deferred("disabled", true)
		visual.stop()
		visual.modulate = Color(0.35, 0.35, 0.35)
		# Credit the lethal hit only; rejected hits and already-dead bodies never reach here.
		if attacker != null and attacker != self:
			attacker.defeated_enemy.emit(self)
		died.emit()
