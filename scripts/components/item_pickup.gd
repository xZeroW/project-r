class_name ItemPickup
extends Area3D
## A persistent click-to-loot world item. It only frees itself once Inventory
## accepts the item; walking through its collection shape does nothing.

@export var item: ItemDefinition
@export var inventory: Inventory

var _sprite: Sprite3D
var _label: Label3D
var _rest_height: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	assert(item != null, "ItemPickup requires an item.")
	assert(inventory != null, "ItemPickup requires an inventory.")
	# Layer 5 is reserved for click picking. This Area deliberately has no body
	# mask or body-entered handler: physical proximity never collects loot.
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	monitorable = false
	_rest_height = global_position.y
	_build_presentation()
	_build_collection_shape()

func _physics_process(delta: float) -> void:
	_time += delta
	global_position.y = _rest_height + sin(_time * 3.0) * 0.06

func _build_presentation() -> void:
	_sprite = Sprite3D.new()
	_sprite.texture = item.icon
	_sprite.pixel_size = 0.014
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.no_depth_test = true
	_sprite.position.y = 0.38
	add_child(_sprite)
	_label = Label3D.new()
	_label.text = item.display_name
	_label.pixel_size = 0.006
	_label.font_size = 32
	_label.outline_size = 5
	_label.modulate = Color(1.0, 0.88, 0.42, 1.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position.y = 0.93
	add_child(_label)

func _build_collection_shape() -> void:
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.72
	collider.shape = shape
	collider.position.y = 0.35
	add_child(collider)

func try_collect() -> bool:
	if inventory.try_add_item(item):
		queue_free()
		return true
	return false
