class_name Hotbar
extends CanvasLayer
## Centered Ragnarok-style skill hotbar: 10 slots bound to the 1–0 keys.
## Slots hold SpellDefinitions. A plain click casts the slot's spell; holding
## Shift turns the click into rearrange mode — press a filled slot and drop it
## on another to move (empty) or swap (filled), with a cursor-following ghost.
## A short Shift-click (no drag) picks the spell; another Shift-click places or
## cancels it. Hotbar keys always emit `slot_activated(index)` — the caller
## decides empty-slot rules.

signal slot_activated(index: int)

const SLOT_COUNT := 10
const KEY_LABELS: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
const HOTBAR_ACTIONS: Array[StringName] = [
	&"hotbar_1", &"hotbar_2", &"hotbar_3", &"hotbar_4", &"hotbar_5",
	&"hotbar_6", &"hotbar_7", &"hotbar_8", &"hotbar_9", &"hotbar_0",
]
const DRAG_THRESHOLD := 6.0

@export var caster: SpellCaster

var _panel: PanelContainer
var _slots: Array[HotbarSlot] = []
var _bindings: Array[SpellDefinition] = []
var _picked: int = -1
var _drag_from: int = -1
var _dragging: bool = false
var _drag_origin: Vector2
var _drag_preview: HotbarSlot

func _ready() -> void:
	assert(caster != null, "Hotbar requires a SpellCaster.")
	_build_bar()
	for index: int in SLOT_COUNT:
		_bindings.append(null)
	caster.cooldowns_changed.connect(_refresh_cooldowns)
	_refresh_slots()

func get_slot_count() -> int:
	return SLOT_COUNT

func get_slot_spell(index: int) -> SpellDefinition:
	return _bindings[index]

func is_slot_filled(index: int) -> bool:
	return _bindings[index] != null

func find_slot(spell: SpellDefinition) -> int:
	for index: int in SLOT_COUNT:
		if _bindings[index] == spell:
			return index
	return -1

func bind_spell(index: int, spell: SpellDefinition) -> void:
	_bindings[index] = spell
	_refresh_slots()
	_refresh_cooldowns()

func unbind_slot(index: int) -> void:
	bind_spell(index, null)

func swap_slots(first: int, second: int) -> void:
	var temporary := _bindings[first]
	_bindings[first] = _bindings[second]
	_bindings[second] = temporary
	_refresh_slots()
	_refresh_cooldowns()

func get_slot_cooldown_fraction(index: int) -> float:
	return (_slots[index] as HotbarSlot).cooldown_fraction

func _unhandled_input(event: InputEvent) -> void:
	for index: int in SLOT_COUNT:
		if event.is_action_pressed(HOTBAR_ACTIONS[index]) and not event.is_echo():
			_activate(index)
			get_viewport().set_input_as_handled()
			return

## Drag tracking runs globally (before GUI) so the cursor can leave the source
## slot: motion past the threshold spawns the ghost preview, and the release
## drops on whichever slot sits under the cursor.
func _input(event: InputEvent) -> void:
	if _drag_from < 0:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_update_drag(motion.global_position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
			_finish_drag(button.global_position)
			get_viewport().set_input_as_handled()

func _build_bar() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	margin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_bottom", 20)
	# Only the slots (and the lock button) may capture clicks; the band around
	# them stays click-through so the bar never blocks clicks near the bottom.
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.85)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)
	_panel = panel

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	for index: int in SLOT_COUNT:
		var slot := HotbarSlot.new()
		slot.custom_minimum_size = Vector2(48, 48)
		slot.configure(index, null, KEY_LABELS[index])
		slot.gui_input.connect(_on_slot_gui_input.bind(index))
		row.add_child(slot)
		_slots.append(slot)

func _activate(index: int) -> void:
	slot_activated.emit(index)

func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if mouse_event.shift_pressed:
		_handle_rearrange_press(index, mouse_event.global_position)
	elif is_slot_filled(index):
		if _picked >= 0:
			_picked = -1
			_refresh_slots()
		_activate(index)

## Shift-click flow. With nothing picked, pressing a filled slot arms a drag
## (a release without motion falls back to the click-pick). With a spell already
## picked, pressing a slot places it there (swap if filled, move if empty) or
## cancels when pressing the same slot. Drop handling lives in `_finish_drag`.
func _handle_rearrange_press(index: int, global_pos: Vector2) -> void:
	if _picked >= 0:
		var from := _picked
		_picked = -1
		if index != from:
			_place(from, index)
		else:
			_refresh_slots()
		return
	if is_slot_filled(index):
		_drag_from = index
		_drag_origin = global_pos

func _place(from: int, to: int) -> void:
	if from == to or from < 0 or to < 0:
		return
	if is_slot_filled(to):
		swap_slots(from, to)
	else:
		_bindings[to] = _bindings[from]
		_bindings[from] = null
		_refresh_slots()
		_refresh_cooldowns()

func _update_drag(global_pos: Vector2) -> void:
	if not _dragging:
		if global_pos.distance_to(_drag_origin) < DRAG_THRESHOLD:
			return
		_dragging = true
		_spawn_preview()
	_drag_preview.global_position = global_pos - _drag_preview.size * 0.5
	_set_drop_highlight(_slot_at(global_pos))

func _finish_drag(global_pos: Vector2) -> void:
	var source := _drag_from
	_drag_from = -1
	if _dragging:
		_dragging = false
		_clear_preview()
		var target := _slot_at(global_pos)
		if target >= 0 and target != source:
			_place(source, target)
		else:
			_set_drop_highlight(-1)
		return
	# No motion: treat the press/release as a click-pick so click-place still works.
	_picked = source
	_refresh_slots()

func _slot_at(global_pos: Vector2) -> int:
	for index: int in SLOT_COUNT:
		if (_slots[index] as HotbarSlot).get_global_rect().has_point(global_pos):
			return index
	return -1

func _spawn_preview() -> void:
	if _drag_preview != null:
		return
	_drag_preview = HotbarSlot.new()
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview.custom_minimum_size = Vector2(48, 48)
	add_child(_drag_preview)
	_drag_preview.size = Vector2(48, 48)
	_drag_preview.configure(_drag_from, _bindings[_drag_from], "")
	_drag_preview.modulate = Color(1, 1, 1, 0.85)

func _clear_preview() -> void:
	if _drag_preview != null:
		_drag_preview.queue_free()
		_drag_preview = null
	_set_drop_highlight(-1)

func _cancel_drag() -> void:
	_drag_from = -1
	_dragging = false
	_clear_preview()

func _set_drop_highlight(target: int) -> void:
	for index: int in SLOT_COUNT:
		var slot := _slots[index]
		slot.highlight = index == target
		slot.queue_redraw()

func _refresh_slots() -> void:
	for index: int in SLOT_COUNT:
		var slot := _slots[index]
		slot.configure(index, _bindings[index], KEY_LABELS[index])
		slot.picked = _picked == index
		slot.mouse_filter = Control.MOUSE_FILTER_STOP if is_slot_filled(index) or _picked >= 0 else Control.MOUSE_FILTER_IGNORE
		slot.queue_redraw()

func _refresh_cooldowns() -> void:
	for index: int in SLOT_COUNT:
		var spell := _bindings[index]
		var fraction := 0.0
		var seconds := 0.0
		if spell != null:
			seconds = caster.get_cooldown_remaining(spell)
			fraction = seconds / maxf(0.001, caster.get_cooldown_total(spell))
		(_slots[index] as HotbarSlot).set_cooldown(fraction, seconds)