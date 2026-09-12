class_name CharacterMovement
extends Node
## Converts camera-relative intent to world direction and applies body physics.

@export var speed: float = 4.0
@export var gravity: float = 20.0

func get_world_direction(movement_basis: Basis, intent: Vector2) -> Vector3:
	var right := movement_basis.x
	var backward := movement_basis.z
	right.y = 0.0
	backward.y = 0.0
	var direction := right.normalized() * intent.x + backward.normalized() * intent.y
	return direction.limit_length()

func move(body: CharacterBody3D, direction: Vector3, delta: float) -> void:
	var horizontal_velocity := direction.limit_length() * speed
	body.velocity.x = horizontal_velocity.x
	body.velocity.z = horizontal_velocity.z
	if body.is_on_floor():
		body.velocity.y = 0.0
	else:
		body.velocity.y -= gravity * delta
	body.move_and_slide()
