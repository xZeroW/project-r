extends Camera3D
## Follows a target independently of its rotation, with orbit and orthographic zoom.

@export var follow_target: Node3D
# World-space fallback center, also used to measure the authored orbit offset.
@export var orbit_center: Vector3 = Vector3.ZERO
@export_range(0.0, 360.0, 1.0) var rotation_speed_degrees: float = 90.0
@export_range(1.0, 128.0, 1.0) var min_zoom_size: float = 8.0
@export_range(1.0, 128.0, 1.0) var max_zoom_size: float = 18.0
@export_range(1.01, 2.0, 0.01) var zoom_step_factor: float = 1.15
@export_range(1.0, 30.0, 0.5) var zoom_response: float = 12.0

var _initial_transform: Transform3D
var _orbit_angle: float = 0.0
var _target_size: float = 32.0
var _follow_center: Vector3

func _ready() -> void:
	# Follow the rendered target ourselves; interpolating the camera again adds lag.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_initial_transform = global_transform
	_follow_center = follow_target.global_position if is_instance_valid(follow_target) else orbit_center
	_target_size = clampf(size, min_zoom_size, maxf(min_zoom_size, max_zoom_size))
	size = _target_size
	_update_orbit_transform()

func _unhandled_input(event: InputEvent) -> void:
	if not is_current():
		return
	var direction: float = 0.0
	if event.is_action_pressed(&"camera_zoom_in"):
		direction = -1.0
	elif event.is_action_pressed(&"camera_zoom_out"):
		direction = 1.0
	else:
		return
	var steps: float = 1.0
	var wheel := event as InputEventMouseButton
	if wheel != null and wheel.factor > 0.0:
		steps = wheel.factor
	_target_size = clampf(
		_target_size * pow(zoom_step_factor, direction * steps),
		min_zoom_size, maxf(min_zoom_size, max_zoom_size)
	)
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_current():
		return
	if is_instance_valid(follow_target):
		_follow_center = follow_target.get_global_transform_interpolated().origin
	_update_orbit_transform()
	if size != _target_size:
		size = lerpf(size, _target_size, 1.0 - exp(-zoom_response * delta))
		if absf(size - _target_size) < 0.001:
			size = _target_size

func _physics_process(delta: float) -> void:
	if not is_current():
		return
	var intent := Input.get_axis(&"rotate_camera_left", &"rotate_camera_right")
	if is_zero_approx(intent):
		return
	_orbit_angle = wrapf(_orbit_angle - intent * deg_to_rad(rotation_speed_degrees) * delta, -PI, PI)
	_update_orbit_transform()

func _update_orbit_transform() -> void:
	var orbit_basis := Basis(Vector3.UP, _orbit_angle)
	global_transform = Transform3D(
		orbit_basis * _initial_transform.basis,
		_follow_center + orbit_basis * (_initial_transform.origin - orbit_center)
	)
