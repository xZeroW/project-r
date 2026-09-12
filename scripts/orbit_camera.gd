extends Camera3D
## Orbits a fixed center in parent space while retaining the authored tilt and zoom.

@export var orbit_center: Vector3 = Vector3.ZERO
@export_range(0.0, 360.0, 1.0) var rotation_speed_degrees: float = 90.0

var _initial_transform: Transform3D
var _orbit_angle: float = 0.0

func _ready() -> void:
	_initial_transform = transform

func _physics_process(delta: float) -> void:
	if not is_current():
		return
	var intent := Input.get_axis(&"rotate_camera_left", &"rotate_camera_right")
	if is_zero_approx(intent):
		return
	_orbit_angle = wrapf(_orbit_angle - intent * deg_to_rad(rotation_speed_degrees) * delta, -PI, PI)
	var orbit_basis := Basis(Vector3.UP, _orbit_angle)
	transform = Transform3D(
		orbit_basis * _initial_transform.basis,
		orbit_center + orbit_basis * (_initial_transform.origin - orbit_center)
	)
