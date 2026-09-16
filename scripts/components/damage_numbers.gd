class_name DamageNumbers
extends CanvasLayer
## Screen-space feedback anchored to the world location where damage occurred.

@export var combat_path: NodePath = NodePath("../Combat")
@export var world_offset: Vector3 = Vector3(0, 1.5, 0)
@export var text_color: Color = Color(1.0, 0.85, 0.25)

const LIFETIME: float = 0.85
const RISE: float = 48.0
const CRIT_COLOR: Color = Color(1.0, 0.5, 0.1)
const MISS_COLOR: Color = Color(0.6, 0.6, 0.65)
const EVADE_COLOR: Color = Color(0.72, 0.72, 0.78)
const BLOCK_COLOR: Color = Color(0.55, 0.7, 0.9)

class DamageEntry:
	var label: Label
	var world_position: Vector3
	var age: float = 0.0
	var side: float = 0.0

var _popups: Array[DamageEntry] = []
var _sequence: int = 0
@onready var _combat: MeleeCombat = get_node(combat_path) as MeleeCombat

func _ready() -> void:
	layer = 12
	process_priority = 100
	_combat.damaged.connect(_on_damaged)
	_combat.missed.connect(_on_missed)
	_combat.evaded.connect(_on_evaded)
	_combat.blocked.connect(_on_blocked)

func _on_damaged(data: DamageData) -> void:
	if data.applied_amount <= 0.0:
		return
	var color := CRIT_COLOR if data.is_crit else text_color
	_spawn_popup(String.num(data.applied_amount, 1).trim_suffix(".0"), color)

func _on_missed() -> void:
	_spawn_popup("MISS", MISS_COLOR)

func _on_evaded() -> void:
	_spawn_popup("EVADE", EVADE_COLOR)

func _on_blocked() -> void:
	_spawn_popup("BLOCK", BLOCK_COLOR)

func _spawn_popup(text: String, color: Color) -> void:
	var popup := DamageEntry.new()
	popup.world_position = _combat.body.get_global_transform_interpolated().origin + world_offset
	popup.side = -1.0 if _sequence % 2 == 0 else 1.0
	_sequence += 1
	popup.label = Label.new()
	popup.label.text = text
	popup.label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.label.add_theme_font_size_override("font_size", 24)
	popup.label.add_theme_color_override("font_color", color)
	popup.label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
	popup.label.add_theme_constant_override("outline_size", 5)
	popup.label.hide()
	add_child(popup.label)
	_popups.append(popup)

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	for index: int in range(_popups.size() - 1, -1, -1):
		var popup := _popups[index]
		popup.age += delta
		if popup.age >= LIFETIME:
			popup.label.queue_free()
			_popups.remove_at(index)
			continue
		popup.label.visible = camera != null and not camera.is_position_behind(popup.world_position)
		if not popup.label.visible:
			continue
		var progress := popup.age / LIFETIME
		var screen_offset := Vector2(popup.side * 14.0 * progress, -RISE * progress)
		popup.label.position = camera.unproject_position(popup.world_position) + screen_offset - popup.label.size * 0.5
		popup.label.modulate.a = 1.0 - clampf((progress - 0.4) / 0.6, 0.0, 1.0)
