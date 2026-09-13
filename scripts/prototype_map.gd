@tool
extends NavigationRegion3D
## Plain colored geometry, shared by editor preview and runtime.

func _ready() -> void:
	var ground := _add_block("Ground", Vector3(0, -0.25, 0), Vector3(24, 0.5, 24), Color("687a70"))
	ground.add_to_group(&"walkable_ground")
	_add_block("NorthWall", Vector3(0, 0.4, -12), Vector3(24.5, 0.8, 0.5), Color("3c5056"))
	_add_block("SouthWall", Vector3(0, 0.4, 12), Vector3(24.5, 0.8, 0.5), Color("3c5056"))
	_add_block("WestWall", Vector3(-12, 0.4, 0), Vector3(0.5, 0.8, 24), Color("3c5056"))
	_add_block("EastWall", Vector3(12, 0.4, 0), Vector3(0.5, 0.8, 24), Color("3c5056"))
	_add_block("TallBlock", Vector3(-4, 1.5, -3), Vector3(2, 3, 2), Color("9cabb8"))
	_add_block("LowBlock", Vector3(4, 0.5, 2), Vector3(3, 1, 2), Color("b39a78"))
	_add_block("LongBlock", Vector3(2, 0.75, -5), Vector3(4, 1.5, 1), Color("8799ab"))
	if not Engine.is_editor_hint():
		navigation_mesh = NavigationMesh.new()
		navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
		navigation_mesh.agent_radius = 0.5
		navigation_mesh.agent_height = 1.25
		navigation_mesh.agent_max_climb = 0.25
		# Bake after the whole tree is ready: baking inside _ready races with the
		# region registering on the navigation map and can leave an empty mesh.
		_start_navmesh_bake.call_deferred()

func _start_navmesh_bake() -> void:
	# The map is tiny: bake synchronously to avoid the async worker-thread race
	# where baked polygons sometimes never reach the navigation server map.
	bake_navigation_mesh(false)

func _add_block(block_name: String, center: Vector3, dimensions: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = block_name
	body.position = center
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	box.material = material
	mesh.mesh = box
	body.add_child(mesh)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	return body
