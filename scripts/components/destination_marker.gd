class_name DestinationMarker
extends MeshInstance3D
## Presentation-only marker placed in world space by navigation events.

func show_destination(destination: Vector3) -> void:
	global_position = destination + Vector3.UP * 0.06
	show()

func clear_destination() -> void:
	hide()
