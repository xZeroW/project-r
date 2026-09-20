class_name SpellDefinition
extends Resource
## Data-driven spell blueprint (Phase B). Tags route tag-keyed "increases" the
## way Path of Exile routes modifiers: an increase keyed to a tag scales every
## spell carrying that tag. Spell icons are authored square and always presented
## square by the HotbarSlot so no non-square art can leak in.

enum SpellTag { AOE, HEAL, FIRE }
enum Behavior { AREA_DAMAGE, HEAL }

@export var id: StringName = &"spell"
@export var display_name: String = "Spell"
@export_multiline var description: String = ""
@export var behavior: Behavior = Behavior.AREA_DAMAGE
## POE-style tag list (SpellTag values). The caster adds increases across all
## matching tags, then scales `power` once. Each tag counts only once.
@export var tags: Array[int] = []
## Square icon texture. When null a square placeholder is generated from
## `icon_color` so the slot always has square art to draw.
@export var icon: Texture2D
@export var icon_color: Color = Color.WHITE
## Base magnitude: damage for AREA_DAMAGE, healing for HEAL.
@export var power: float = 20.0
## AREA_DAMAGE only: horizontal radius around the cast point.
@export var radius: float = 4.0
@export var mana_cost: float = 10.0
## This spell's own cooldown. The 1s global cooldown always applies on cast;
## this timer continues past it when larger (RO behavior).
@export_range(1.0, 300.0, 0.5) var cooldown: float = 3.0

var _placeholder_icon: Texture2D

func has_tag(tag: SpellTag) -> bool:
	return int(tag) in tags

func tag_label() -> String:
	var names: PackedStringArray = PackedStringArray()
	for tag: int in tags:
		match tag:
			int(SpellTag.AOE):
				names.append("AOE")
			int(SpellTag.HEAL):
				names.append("HEAL")
			int(SpellTag.FIRE):
				names.append("FIRE")
	return " / ".join(names)

func get_icon() -> Texture2D:
	if icon != null:
		return icon
	if _placeholder_icon == null:
		_placeholder_icon = _make_square_placeholder(icon_color)
	return _placeholder_icon

func hotbar_tooltip() -> String:
	var effect := "%.0f dmg in %.1f-unit radius" % [power, radius] if behavior == Behavior.AREA_DAMAGE else "Restores %.0f health" % power
	var meta := "%.0f MP · %.1fs cd  (%s)" % [mana_cost, cooldown, tag_label()]
	return "%s\n%s\n%s" % [display_name, meta, effect]

## Spells ship square icons; the placeholder keeps that contract until real art
## exists so the slot never distorts a non-square texture.
func _make_square_placeholder(color: Color) -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
