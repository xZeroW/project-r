class_name MeleeCombat
extends Node
## Shared single-target melee resolution. Called only during physics updates.

signal damaged(data: DamageData)
signal died

@export var stats: CharacterStats
@export var reach: float = 1.8
@export var visual_path: NodePath

@onready var body: CharacterBody3D = get_parent() as CharacterBody3D
@onready var visual: AnimatedSprite3D = get_node(visual_path) as AnimatedSprite3D

var cooldown: float = 0.0
var invulnerability: float = 0.0

func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	if stats.current_health > 0.0:
		visual.modulate = Color(1, 0.35, 0.35) if invulnerability > 0.0 else Color.WHITE

func can_reach(other: MeleeCombat) -> bool:
	if not is_instance_valid(other) or stats.current_health <= 0.0 or other.stats.current_health <= 0.0:
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
	other.take_damage(data)
	return true

func take_damage(data: DamageData) -> void:
	if stats.current_health <= 0.0 or invulnerability > 0.0 or data.amount <= 0.0:
		return
	var previous_health := stats.current_health
	stats.current_health = maxf(0.0, stats.current_health - maxf(0.0, data.amount - stats.armour))
	var resolved := DamageData.new()
	resolved.amount = data.amount
	resolved.source = data.source
	resolved.applied_amount = previous_health - stats.current_health
	invulnerability = 0.15
	damaged.emit(resolved)
	if stats.current_health <= 0.0:
		body.velocity = Vector3.ZERO
		(body.get_node("CollisionShape3D") as CollisionShape3D).set_deferred("disabled", true)
		visual.stop()
		visual.modulate = Color(0.35, 0.35, 0.35)
		died.emit()
