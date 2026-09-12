extends CharacterBody3D
## Coordinates independently replaceable input, movement, and visual components.

@onready var input_component = $PlayerInput
@onready var movement_component = $CharacterMovement
@onready var visual_component = $DirectionalSprite

func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var intent: Vector2 = input_component.get_movement_intent()
	movement_component.move(self, camera, intent, delta)
	visual_component.update_facing(intent)
