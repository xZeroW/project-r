extends Node
## Moves the supplied physics body along the camera's ground-plane axes.

@export var speed: float = 4.0
@export var gravity: float = 20.0

func move(body: CharacterBody3D, camera: Camera3D, intent: Vector2, delta: float) -> void:
	var right := camera.global_basis.x
	var backward := camera.global_basis.z
	right.y = 0.0
	backward.y = 0.0
	var direction := right.normalized() * intent.x + backward.normalized() * intent.y
	var horizontal_velocity := direction.limit_length() * speed
	body.velocity.x = horizontal_velocity.x
	body.velocity.z = horizontal_velocity.z
	if body.is_on_floor():
		body.velocity.y = 0.0
	else:
		body.velocity.y -= gravity * delta
	body.move_and_slide()
