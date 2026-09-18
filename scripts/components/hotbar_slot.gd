class_name HotbarSlot
extends Control
## One 48px-square hotbar cell. Draws a square spell icon (never distorted), a
## key badge, a selection highlight while picked for moving, and a
## Ragnarok-style "pizza" cooldown shadow that sweeps clockwise from 12 o'clock
## and stretches to the slot's edges so the whole square darkens, not just an
## inscribed circle.

const COOLDOWN_COLOR := Color(0, 0, 0, 0.72)

var index: int = 0
var spell: SpellDefinition
var key_label: String = ""
var picked: bool = false
var highlight: bool = false
var cooldown_fraction: float = 0.0
var cooldown_seconds: float = 0.0

var _bg: StyleBoxFlat

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	_bg = StyleBoxFlat.new()
	_bg.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	_bg.set_corner_radius_all(5)
	_bg.set_border_width_all(1)
	_bg.border_color = Color(0.25, 0.3, 0.42, 1)

func configure(slot_index: int, slot_spell: SpellDefinition, label: String) -> void:
	index = slot_index
	spell = slot_spell
	key_label = label
	tooltip_text = spell.hotbar_tooltip() if spell != null else ""
	queue_redraw()

func set_cooldown(fraction: float, seconds: float) -> void:
	cooldown_fraction = clampf(fraction, 0.0, 1.0)
	cooldown_seconds = seconds
	queue_redraw()

func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	draw_style_box(_bg, full)
	var font := get_theme_default_font()
	if spell == null:
		_draw_key_label(font, Color(0.65, 0.7, 0.8, 0.95), 14)
		return
	# Icons are square; grow(-3) keeps the painted box square too.
	draw_texture_rect(spell.get_icon(), full.grow(-3), false, Color.WHITE)
	if cooldown_fraction > 0.001:
		_draw_cooldown_pie(full)
		_draw_seconds(font, full)
	if picked:
		draw_rect(full, Color(1, 0.85, 0.3, 1), false, 3.0)
	elif highlight:
		draw_rect(full, Color(1, 1, 1, 0.9), false, 2.0)
	_draw_key_label(font, Color.WHITE, 13)

func _draw_key_label(font: Font, color: Color, font_size: int) -> void:
	var label_origin := Vector2(6, size.y - 7)
	draw_string_outline(font, label_origin, key_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0, 0, 0, 0.9))
	draw_string(font, label_origin, key_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_seconds(font: Font, full: Rect2) -> void:
	var seconds := String.num(ceili(cooldown_seconds))
	var center := full.get_center() + Vector2(0, 7)
	draw_string_outline(font, center, seconds, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, 3, Color(0, 0, 0, 0.95))
	draw_string(font, center, seconds, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color.WHITE)

func _draw_cooldown_pie(full: Rect2) -> void:
	if cooldown_fraction >= 0.999:
		draw_rect(full, COOLDOWN_COLOR)
		return
	var center := full.get_center()
	var half := full.size * 0.5 + Vector2.ONE
	var start_angle := -PI / 2.0
	var sweep := TAU * cooldown_fraction
	var segments := maxi(8, ceili(96.0 * cooldown_fraction))
	var points := PackedVector2Array([center])
	for i in segments + 1:
		var angle := start_angle + sweep * float(i) / float(segments)
		points.append(center + square_edge_offset(half, angle))
	draw_colored_polygon(points, COOLDOWN_COLOR)

## Offset from the slot center to the rectangle boundary (size [param half] per
## axis) in direction [param angle]. Used as the pie's outer edge so the sweep
## covers the entire square, reaching its corners at 45° strides.
static func square_edge_offset(half: Vector2, angle: float) -> Vector2:
	var direction := Vector2(cos(angle), sin(angle))
	var stretch := 1.0 / maxf(absf(direction.x) / half.x, absf(direction.y) / half.y)
	return direction * stretch
