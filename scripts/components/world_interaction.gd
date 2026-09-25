class_name WorldInteraction
extends Node
## Physics-safe screen-ray picker. It classifies clicks only; movement,
## targeting, and looting remain owned by their dedicated components.

signal ground_selected(position: Vector3)
signal enemy_selected(enemy: MeleeCombat)
signal loot_selected(pickup: ItemPickup)

## Ground/monsters use layer 1; non-blocking pickups use layer 5.
@export_flags_3d_physics var pick_mask: int = 17
@export var body: CharacterBody3D

var _pending_click: bool = false
var _ray_origin: Vector3
var _ray_end: Vector3

func _ready() -> void:
	assert(body != null, "WorldInteraction requires its physics body.")

func request_interaction(screen_position: Vector2, camera: Camera3D) -> void:
	_ray_origin = camera.project_ray_origin(screen_position)
	_ray_end = _ray_origin + camera.project_ray_normal(screen_position) * camera.far
	_pending_click = true

func cancel() -> void:
	_pending_click = false

func _physics_process(_delta: float) -> void:
	if not _pending_click:
		return
	_pending_click = false
	var query := PhysicsRayQueryParameters3D.create(_ray_origin, _ray_end, pick_mask, [body.get_rid()])
	query.collide_with_areas = true
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	var collider := hit.get("collider") as Node
	var pickup := collider as ItemPickup
	if pickup != null:
		loot_selected.emit(pickup)
		return
	if collider != null and collider.is_in_group(&"monsters"):
		var enemy := collider as Monster
		if enemy != null and enemy.combat.damage_enabled and enemy.combat.stats.current_health > 0.0:
			enemy_selected.emit(enemy.combat)
		return
	if collider != null and collider.is_in_group(&"walkable_ground"):
		ground_selected.emit(hit["position"] as Vector3)
