class_name Monster
extends CharacterBody3D

signal attack_started
signal attack_finished

enum State { IDLE, ENGAGED, RETURNING, DEAD }

@export var target: CharacterBody3D
@export var stats: CharacterStats
@export var aggressive: bool = true
@export_range(0.0, 50.0, 0.1, "or_greater") var aggro_radius: float = 6.0
@export_range(0.1, 100.0, 0.1, "or_greater") var leash_distance: float = 10.0
@export_range(0.7, 60.0, 0.1, "or_greater") var respawn_delay: float = 5.0
@export var attack_range: float = 1.5
@export var attack_duration: float = 2.0

@onready var _navigation_agent: NavigationAgent3D = %NavigationAgent3D
@onready var combat: MeleeCombat = %Combat

var _retarget_time: float = 0.0
var _navigation_ready: bool = false
var _is_attacking: bool = false
var _attack_time_remaining: float = 0.0
var state: State = State.IDLE
var _spawn_position: Vector3
var _dead_time: float = 0.0
var _stuck_time: float = 0.0
@onready var _health_bar: CanvasLayer = $HealthBar
@onready var _shadow: MeshInstance3D = $CollisionShape3D/ContactShadow

func _ready() -> void:
	assert(target != null, "Monster requires a player target.")
	assert(stats != null, "Monster requires character stats.")
	_spawn_position = global_position
	combat.damaged.connect(_on_damaged)
	combat.died.connect(_on_died)
	# The navmesh surface sits above the CharacterBody origin, so this must
	# exceed the vertical offset before the agent advances to a horizontal point.
	_navigation_agent.path_desired_distance = 0.5
	_navigation_agent.target_desired_distance = attack_range
	_set_target_when_navigation_is_ready.call_deferred()

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_dead_time += delta
		combat.visual.modulate.a = maxf(0.0, 1.0 - _dead_time / 0.6)
		if _dead_time >= maxf(0.7, respawn_delay):
			_respawn()
		return
	if stats.current_health <= 0.0:
		_on_died()
		return
	if not _navigation_ready:
		velocity = Vector3.ZERO
		return
	if state == State.RETURNING:
		_return_home(delta)
		return
	if not is_instance_valid(target):
		if state == State.ENGAGED:
			_begin_return()
		_stop_engagement()
		return
	var target_combat := target.get_node_or_null("Combat") as MeleeCombat
	if target_combat == null or target_combat.stats.current_health <= 0.0:
		if state == State.ENGAGED:
			_begin_return()
		_stop_engagement()
		return
	if state == State.IDLE:
		if aggressive and aggro_radius > 0.0 and _horizontal_distance_to_target() <= aggro_radius and _inside_leash(target.global_position):
			state = State.ENGAGED
		else:
			_stop_engagement()
			return
	if not _inside_leash(global_position) or not _inside_leash(target.global_position):
		_begin_return()
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

	_navigate_to(target.global_position, attack_range, delta)

func _navigate_to(destination: Vector3, stopping_distance: float, delta: float) -> void:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0 or not NavigationServer3D.map_get_closest_point_owner(map, destination).is_valid():
		velocity = Vector3.ZERO
		return
	_retarget_time -= delta
	if _retarget_time <= 0.0:
		_navigation_agent.target_desired_distance = stopping_distance
		# The baked surface floats above actor roots. Snap the destination so the
		# small home-arrival tolerance does not classify a valid return as unreachable.
		_navigation_agent.target_position = NavigationServer3D.map_get_closest_point(map, destination)
		_retarget_time = 0.2

	var next_position := _navigation_agent.get_next_path_position()
	if _navigation_agent.is_navigation_finished() or not _navigation_agent.is_target_reachable():
		velocity = Vector3.ZERO
		return

	var offset := (next_position - global_position) * Vector3(1, 0, 1)
	velocity = offset.normalized() * minf(stats.movement_speed, offset.length() / maxf(delta, 0.001))
	move_and_slide()

func _set_target_when_navigation_is_ready() -> void:
	await get_tree().physics_frame
	_navigation_agent.target_position = _spawn_position
	_navigation_ready = true

func _inside_leash(world_position: Vector3) -> bool:
	return Vector2(world_position.x - _spawn_position.x, world_position.z - _spawn_position.z).length() <= leash_distance

func _on_damaged(data: DamageData) -> void:
	if state == State.DEAD or state == State.RETURNING or stats.current_health <= 0.0:
		return
	if is_instance_valid(target) and data.source == target and _inside_leash(target.global_position):
		state = State.ENGAGED
		_retarget_time = 0.0

func _begin_return() -> void:
	_stop_engagement()
	state = State.RETURNING
	combat.damage_enabled = false
	_stuck_time = 0.0

func _return_home(delta: float) -> void:
	var home_offset := (_spawn_position - global_position) * Vector3(1, 0, 1)
	if home_offset.length() <= 0.15:
		_finish_return()
		return
	var previous_position := global_position
	_navigate_to(_spawn_position, 0.1, delta)
	_stuck_time = _stuck_time + delta if global_position.distance_squared_to(previous_position) < 0.000001 else 0.0
	# A physically blocked or unreachable return cannot leave a monster invulnerable forever.
	if _stuck_time >= 3.0:
		_finish_return()

func _finish_return() -> void:
	global_position = _spawn_position
	reset_physics_interpolation()
	_stop_engagement()
	state = State.IDLE
	stats.current_health = stats.max_health
	combat.cooldown = 0.0
	combat.invulnerability = 0.0
	combat.damage_enabled = true

func _on_died() -> void:
	if state == State.DEAD:
		return
	_stop_engagement()
	state = State.DEAD
	_dead_time = 0.0
	combat.damage_enabled = false
	_health_bar.hide()
	_shadow.hide()

func _respawn() -> void:
	_finish_return()
	combat.visual.modulate = Color.WHITE
	combat.visual.play(&"idle")
	($CollisionShape3D as CollisionShape3D).set_deferred("disabled", false)
	_health_bar.show()
	_shadow.show()

func _stop_engagement() -> void:
	velocity = Vector3.ZERO
	_is_attacking = false
	_attack_time_remaining = 0.0
	# Re-entry must immediately refresh the route rather than follow a stale one.
	_retarget_time = 0.0

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
