class_name DeathRespawn
extends Node
## Owns the death → respawn cycle for the owning character body.

signal respawned

@export_range(0.7, 60.0, 0.1, "or_greater") var respawn_delay: float = 3.0
@export_range(0.0, 100.0, 0.5) var exp_loss_percent: float = 5.0

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D
@onready var combat: MeleeCombat = %Combat
@onready var stats: CharacterStats = %Combat.stats
@onready var experience: Experience = %Experience
@onready var visual: DirectionalSprite = %DirectionalSprite
@onready var _resource_bar: CanvasLayer = %ResourceBar
@onready var _shadow: MeshInstance3D = %ContactShadow

var _dead: bool = false
var _dead_time: float = 0.0
var _spawn_position: Vector3

func _ready() -> void:
	assert(combat != null, "DeathRespawn requires a Combat component.")
	assert(experience != null, "DeathRespawn requires an Experience component.")
	assert(stats != null, "DeathRespawn requires character stats.")
	_spawn_position = _body.global_position
	combat.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	if not _dead:
		return
	_dead_time += delta
	if _dead_time >= maxf(0.7, respawn_delay):
		_respawn()

func _on_died() -> void:
	if _dead:
		return
	_dead = true
	_dead_time = 0.0
	combat.damage_enabled = false
	_resource_bar.hide()
	_shadow.hide()
	_apply_death_exp_penalty()

func _apply_death_exp_penalty() -> void:
	if experience.is_max_level() or exp_loss_percent <= 0.0:
		return
	var loss := ceili(experience.get_required_experience() * exp_loss_percent / 100.0)
	experience.lose_experience(loss)

func _respawn() -> void:
	_dead = false
	_body.global_position = _spawn_position
	_body.reset_physics_interpolation()
	stats.current_health = stats.max_health
	stats.mana = stats.max_mana
	combat.damage_enabled = true
	combat.cooldown = 0.0
	combat.invulnerability = 0.0
	(_body.get_node("CollisionShape3D") as CollisionShape3D).set_deferred("disabled", false)
	combat.visual.modulate = Color.WHITE
	visual.idle()
	_resource_bar.show()
	_shadow.show()
	respawned.emit()
