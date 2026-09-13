class_name DirectionalSprite
extends AnimatedSprite3D
## Five source directions provide eight views by mirroring the eastern poses.

const IDLE_ANIMATIONS: Array[StringName] = [
	&"idle_west", &"idle_southwest", &"idle_south", &"idle_southwest",
	&"idle_west", &"idle_northwest", &"idle_north", &"idle_northwest",
]
const WALK_ANIMATIONS: Array[StringName] = [
	&"walk_west", &"walk_southwest", &"walk_south", &"walk_southwest",
	&"walk_west", &"walk_northwest", &"walk_north", &"walk_northwest",
]

# Screen sectors: E, SE, S, SW, W, NW, N, NE. Separate from animation frame.
var facing_index: int = 2
var _is_walking: bool = false

func update_facing(world_direction: Vector3, camera_basis: Basis, is_moving: bool) -> void:
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
	facing_index = posmod(roundi(screen_direction.angle() / (PI / 4.0)), 8)
	flip_h = facing_index == 0 or facing_index == 1 or facing_index == 7
	_update_animation(is_moving)

func idle() -> void:
	_update_animation(false)

func _update_animation(is_moving: bool) -> void:
	var next_animation := WALK_ANIMATIONS[facing_index] if is_moving else IDLE_ANIMATIONS[facing_index]
	var preserve_phase := _is_walking and is_moving
	_is_walking = is_moving
	if animation == next_animation:
		return
	var previous_frame := frame
	var previous_progress := frame_progress
	play(next_animation)
	# Turning or orbiting mid-stride must not restart the walk cycle.
	if preserve_phase:
		set_frame_and_progress(previous_frame, previous_progress)
