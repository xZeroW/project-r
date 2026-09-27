class_name ItemDefinition
extends Resource
## Immutable blueprint for one inventory item. Every item occupies one bag slot.

enum EquipmentSlot { NONE, HEAD, BODY, GLOVES, BOOTS, WEAPON, OFF_HAND, AMULET, RING_LEFT, RING_RIGHT, BELT, CLOAK }

@export var id: StringName = &"item"
@export var display_name: String = "Item"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export_group("Equipment")
@export var equipment_slot: EquipmentSlot = EquipmentSlot.NONE
@export_group("Modifiers")
@export var attack_damage: float = 0.0
@export var magic_attack: float = 0.0
@export var armour: float = 0.0
@export var block: float = 0.0
@export var max_health: float = 0.0
@export var max_mana: float = 0.0
@export var attack_speed: float = 0.0
@export var acc: float = 0.0
@export var evasion: float = 0.0
@export var crit: float = 0.0

func tooltip() -> String:
	var lines: PackedStringArray = [display_name]
	if not description.is_empty():
		lines.append(description)
	for property: StringName in [&"attack_damage", &"magic_attack", &"armour", &"block", &"max_health", &"max_mana", &"attack_speed", &"acc", &"evasion", &"crit"]:
		var value: float = get(property)
		if not is_zero_approx(value):
			lines.append("+%s %s" % ["%.1f" % value, property.capitalize().replace("_", " ")])
	return "\n".join(lines)
