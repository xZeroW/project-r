class_name Monster
extends CharacterBody3D

signal attack_started
signal attack_finished

@export var target: CharacterBody3D
@export var stats: CharacterStats
@export var attack_range: float = 1.5
@export var attack_duration: float = 2.0

@onready var _navigation_agent: NavigationAgent3D = %NavigationAgent3D
@onready var combat: MeleeCombat = %Combat

var _retarget_time: float = 0.0
var _navigation_ready: bool = false
var _is_attacking: bool = false
var _attack_time_remaining: float = 0.0

func _ready() -> void:
	assert(target != null, "Monster requires a player target.")
	assert(stats != null, "Monster requires character stats.")
	# The navmesh surface sits above the CharacterBody origin, so this must
	# exceed the vertical offset before the agent advances to a horizontal point.
	_navigation_agent.path_desired_distance = 0.5
	_navigation_agent.target_desired_distance = attack_range
	_set_target_when_navigation_is_ready.call_deferred()

func _physics_process(delta: float) -> void:
	if stats.current_health <= 0.0 or not is_instance_valid(target):
		velocity = Vector3.ZERO
		return
	var target_combat := target.get_node_or_null("Combat") as MeleeCombat
	if target_combat == null or target_combat.stats.current_health <= 0.0:
		_is_attacking = false
		velocity = Vector3.ZERO
		return
	if not _navigation_ready:
		velocity = Vector3.ZERO
		return

	if _is_attacking:
		_attack_time_remaining -= delta
		velocity = Vector3.ZERO
		if _attack_time_remaining <= 0.0:
			_is_attacking = false
			combat.reach = attack_range
			combat.attack(target_combat)
			attack_finished.emit()
		return

	if _horizontal_distance_to_target() <= attack_range:
		_start_attack()
		return

	_retarget_time -= delta
	if _retarget_time <= 0.0:
		_navigation_agent.target_position = target.global_position
		_retarget_time = 0.2

	if _navigation_agent.is_navigation_finished() or not _navigation_agent.is_target_reachable():
		velocity = Vector3.ZERO
		return

	var next_position := _navigation_agent.get_next_path_position()
	var direction := global_position.direction_to(next_position)
	velocity = Vector3(direction.x, 0.0, direction.z) * stats.movement_speed
	move_and_slide()

func _set_target_when_navigation_is_ready() -> void:
	await get_tree().physics_frame
	_navigation_agent.target_position = target.global_position
	_navigation_ready = true

func _horizontal_distance_to_target() -> float:
	var offset := target.global_position - global_position
	offset.y = 0.0
	return offset.length()

func _start_attack() -> void:
	# Future presentation can connect attack_started to play its attack clip.
	velocity = Vector3.ZERO
	_is_attacking = true
	_attack_time_remaining = attack_duration / maxf(stats.attack_speed, 0.01)
	attack_started.emit()
