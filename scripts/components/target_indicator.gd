class_name TargetIndicator
extends MeshInstance3D
## Ground-plane selection ring, rendered behind the sprite like its contact shadow.

func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_material := ShaderMaterial.new()
	ring_material.shader = preload("res://scripts/target_ring.gdshader")
	# Contact shadow is -1; ring is 0; character sprite is 1.
	ring_material.render_priority = 0
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.87, 1.87)
	plane.material = ring_material
	mesh = plane

func place_at(ground_position: Vector3) -> void:
	global_position = ground_position + Vector3.UP * 0.002
