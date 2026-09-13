class_name PlayerInput
extends Node
## Produces screen-relative movement intent without owning movement or visuals.

signal destination_requested(screen_position: Vector2)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"click_move"):
		var click := event as InputEventMouseButton
		var screen_position := click.position if click != null else get_viewport().get_mouse_position()
		destination_requested.emit(screen_position)
		get_viewport().set_input_as_handled()

func get_movement_intent() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")
