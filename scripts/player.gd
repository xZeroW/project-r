extends CharacterBody3D
## Coordinates independently replaceable input, movement, and visual components.

# Faces screen-south in the map's initial 45-degree camera view.
var _facing_direction: Vector3 = Vector3(1, 0, 1).normalized()

@onready var input_component: PlayerInput = %PlayerInput
@onready var movement_component: CharacterMovement = %CharacterMovement
@onready var visual_component: DirectionalSprite = %DirectionalSprite

func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var direction := Vector3.ZERO
	# Without a camera, pause directional input but keep gravity and collisions active.
	if camera != null:
		direction = movement_component.get_world_direction(camera.global_basis, input_component.get_movement_intent())
		if not direction.is_zero_approx():
			_facing_direction = direction.normalized()
	var previous_position := global_position
	movement_component.move(self, direction, delta)
	var displacement := global_position - previous_position
	var is_moving := Vector2(displacement.x, displacement.z).length_squared() > 0.000001
	if camera != null:
		visual_component.update_facing(_facing_direction, camera.global_basis, is_moving)
	else:
		visual_component.idle()
