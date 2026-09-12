class_name DirectionalSprite
extends Sprite3D
## Rows: E, SE, S, SW, W, NW, N, NE. One static frame per direction.

func update_facing(world_direction: Vector3, camera_basis: Basis) -> void:
	if world_direction.is_zero_approx():
		return
	var right := camera_basis.x
	var backward := camera_basis.z
	right.y = 0.0
	backward.y = 0.0
	# Use ground-plane axes so the camera tilt does not bias the eight sectors.
	var screen_direction := Vector2(
		world_direction.dot(right.normalized()),
		world_direction.dot(backward.normalized())
	)
	# Screen Y points down, so atan2 advances clockwise from east.
	frame = posmod(roundi(screen_direction.angle() / (PI / 4.0)), 8)
