extends CharacterBody3D
## Coordinates independently replaceable input, movement, and visual components.

# Faces screen-south in the map's initial 45-degree camera view.
var _facing_direction: Vector3 = Vector3(1, 0, 1).normalized()

@export var stats: CharacterStats
var _attack_requested: bool = false
@onready var combat: MeleeCombat = %Combat

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and not event.is_echo():
		_attack_requested = true
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("restart_encounter") and not event.is_echo():
		get_tree().reload_current_scene.call_deferred()
		get_viewport().set_input_as_handled()

@onready var input_component: PlayerInput = %PlayerInput
@onready var movement_component: CharacterMovement = %CharacterMovement
@onready var visual_component: DirectionalSprite = %DirectionalSprite
@onready var click_movement: ClickMovement = %ClickMovement
@onready var destination_marker: DestinationMarker = %DestinationMarker

func _ready() -> void:
	assert(stats != null, "Player requires character stats.")
	movement_component.speed = stats.movement_speed
	input_component.destination_requested.connect(_on_destination_requested)
	click_movement.destination_changed.connect(destination_marker.show_destination)
	click_movement.destination_cleared.connect(destination_marker.clear_destination)

func _on_destination_requested(screen_position: Vector2) -> void:
	if stats.current_health <= 0.0:
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		click_movement.request_destination(screen_position, camera)

func _physics_process(delta: float) -> void:
	if stats.current_health <= 0.0:
		_attack_requested = false
		click_movement.cancel()
		velocity = Vector3.ZERO
		return
	if _attack_requested:
		_attack_requested = false
		var nearest: MeleeCombat
		var distance: float = INF
		for node: Node in get_tree().get_nodes_in_group("monsters"):
			var candidate := node.get_node_or_null("Combat") as MeleeCombat
			if candidate != null and combat.can_reach(candidate):
				var candidate_distance := global_position.distance_squared_to(candidate.body.global_position)
				if candidate_distance < distance:
					nearest = candidate
					distance = candidate_distance
		if nearest != null and combat.attack(nearest):
			click_movement.cancel()
			_facing_direction = (nearest.body.global_position - global_position) * Vector3(1, 0, 1)
	var camera := get_viewport().get_camera_3d()
	var direction := Vector3.ZERO
	# Without a camera, pause directional input but keep gravity and collisions active.
	if camera != null:
		var intent := input_component.get_movement_intent()
		if not intent.is_zero_approx():
			click_movement.cancel()
			direction = movement_component.get_world_direction(camera.global_basis, intent)
		else:
			direction = click_movement.get_direction(self, movement_component.speed, delta)
		if not direction.is_zero_approx():
			_facing_direction = direction.normalized()
	else:
		click_movement.cancel()
	var previous_position := global_position
	movement_component.move(self, direction, delta)
	var displacement := global_position - previous_position
	click_movement.record_motion(displacement, delta)
	var is_moving := Vector2(displacement.x, displacement.z).length_squared() > 0.000001
	if camera != null:
		visual_component.update_facing(_facing_direction, camera.global_basis, is_moving)
	else:
		visual_component.idle()
