class_name WindowDragHandle
extends Control
## A slim, non-titlebar grip that moves a persistent window wrapper. The wrapper
## stays alive while hidden, so each panel restores its last session position.

var window: Control
var _dragging := false

func configure(owner_window: Control) -> void:
	window = owner_window

func _ready() -> void:
	custom_minimum_size = Vector2(0, 10)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mouse_event.pressed
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion_event := event as InputEventMouseMotion
		move_window_by(motion_event.relative)
		accept_event()

func move_window_by(delta: Vector2) -> void:
	if window != null:
		window.position += delta

func _draw() -> void:
	var line_y := size.y * 0.5
	draw_line(Vector2(8, line_y), Vector2(size.x - 8, line_y), Color(0.7, 0.52, 0.25, 0.7), 1.0)
