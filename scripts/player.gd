extends CharacterBody3D
## Coordinates independently replaceable input, movement, and visual components.

# Faces screen-south in the map's initial 45-degree camera view.
var _facing_direction: Vector3 = Vector3(1, 0, 1).normalized()

@export var stats: CharacterStats
@onready var combat: MeleeCombat = %Combat
@onready var targeting: Targeting = %Targeting
@onready var experience: Experience = %Experience

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right") or event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		targeting.cancel()
		click_movement.cancel()
	if event.is_action_pressed("restart_encounter") and not event.is_echo():
		get_tree().reload_current_scene.call_deferred()
		get_viewport().set_input_as_handled()

@onready var input_component: PlayerInput = %PlayerInput
@onready var movement_component: CharacterMovement = %CharacterMovement
@onready var visual_component: DirectionalSprite = %DirectionalSprite
@onready var click_movement: ClickMovement = %ClickMovement
@onready var destination_marker: DestinationMarker = %DestinationMarker
@onready var status_points: StatusPoints = %StatusPoints

func _ready() -> void:
	assert(stats != null, "Player requires character stats.")
	combat.defeated_enemy.connect(_on_defeated_enemy)
	experience.leveled_up.connect(_on_leveled_up)
	experience.leveled_up.connect(status_points.grant_level_up_points.unbind(1))
	movement_component.speed = stats.movement_speed
	input_component.destination_requested.connect(_on_destination_requested)
	click_movement.destination_changed.connect(destination_marker.show_destination)
	click_movement.destination_cleared.connect(destination_marker.clear_destination)
	click_movement.enemy_selected.connect(targeting.select)
	click_movement.destination_changed.connect(func(_position: Vector3) -> void: targeting.cancel())

func _on_defeated_enemy(enemy: MeleeCombat) -> void:
	experience.add_experience(enemy.base_experience_reward)

func _on_leveled_up(_level: int) -> void:
	stats.current_health = stats.max_health
	stats.mana = stats.max_mana

func _on_destination_requested(screen_position: Vector2) -> void:
	if stats.current_health <= 0.0:
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		click_movement.request_destination(screen_position, camera)

func _physics_process(delta: float) -> void:
	if stats.current_health <= 0.0:
		targeting.cancel()
		click_movement.cancel()
		velocity = Vector3.ZERO
		return
	var camera := get_viewport().get_camera_3d()
	var direction := Vector3.ZERO
	# Without a camera, pause directional input but keep gravity and collisions active.
	if camera != null:
		var intent := input_component.get_movement_intent()
		if not intent.is_zero_approx():
			targeting.cancel()
			click_movement.cancel()
			direction = movement_component.get_world_direction(camera.global_basis, intent)
		else:
			direction = click_movement.get_direction(self, movement_component.speed, delta)
			if targeting.has_target():
				_facing_direction = (targeting.target.body.global_position - global_position) * Vector3(1, 0, 1)
				direction = targeting.get_direction(combat, movement_component.speed, delta)
		if not direction.is_zero_approx():
			_facing_direction = direction.normalized()
	else:
		click_movement.cancel()
		targeting.cancel()
	var previous_position := global_position
	movement_component.move(self, direction, delta)
	var displacement := global_position - previous_position
	click_movement.record_motion(displacement, delta)
	targeting.record_motion(displacement, delta)
	var is_moving := Vector2(displacement.x, displacement.z).length_squared() > 0.000001
	if camera != null:
		visual_component.update_facing(_facing_direction, camera.global_basis, is_moving)
	else:
		visual_component.idle()
