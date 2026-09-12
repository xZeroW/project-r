class_name PlayerInput
extends Node
## Produces screen-relative movement intent without owning movement or visuals.

func get_movement_intent() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")
