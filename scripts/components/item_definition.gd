class_name ItemDefinition
extends Resource
## Immutable blueprint for one inventory item. Every item occupies one bag slot.

@export var id: StringName = &"item"
@export var display_name: String = "Item"
@export_multiline var description: String = ""
@export var icon: Texture2D

func tooltip() -> String:
	return "%s\n%s" % [display_name, description]
