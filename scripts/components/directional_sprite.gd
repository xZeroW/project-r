extends Sprite3D
## Rows: E, SE, S, SW, W, NW, N, NE. One static frame per direction.

func update_facing(intent: Vector2) -> void:
	if intent.is_zero_approx():
		return
	# Screen Y points down, so atan2 advances clockwise from east.
	frame = posmod(roundi(intent.angle() / (PI / 4.0)), 8)
