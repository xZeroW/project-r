class_name StatusUI
extends CanvasLayer
## Combined character sheet: paper-doll equipment above and live PoE-style
## derived stats below. It is only a projection layer; allocation stays gameplay.

const EQUIPMENT_SLOTS: Array[ItemDefinition.EquipmentSlot] = [
	ItemDefinition.EquipmentSlot.HEAD,
	ItemDefinition.EquipmentSlot.BODY,
	ItemDefinition.EquipmentSlot.GLOVES,
	ItemDefinition.EquipmentSlot.BOOTS,
	ItemDefinition.EquipmentSlot.WEAPON,
	ItemDefinition.EquipmentSlot.OFF_HAND,
	ItemDefinition.EquipmentSlot.AMULET,
	ItemDefinition.EquipmentSlot.RING_LEFT,
	ItemDefinition.EquipmentSlot.RING_RIGHT,
	ItemDefinition.EquipmentSlot.BELT,
	ItemDefinition.EquipmentSlot.CLOAK,
]
const KNIGHT_TEXTURE := preload("res://assets/characters/knight/example.png")

@export var status_points: StatusPoints
@export var equipment: Equipment
@export var inventory: Inventory

var _panel: PanelContainer
var _window: MarginContainer
var _saved_position := Vector2.ZERO
var _has_saved_position := false
var _derived_label: Label
var _defence_label: Label
var _misc_label: Label
var _equipment_slots: Array[EquipmentSlotControl] = []

func _ready() -> void:
	assert(status_points != null, "StatusUI requires a StatusPoints component.")
	assert(equipment != null, "StatusUI requires an Equipment component.")
	assert(inventory != null, "StatusUI requires an Inventory component.")
	_build_panel()
	_panel.visible = false
	status_points.allocated.connect(_refresh.unbind(1))
	status_points.stats.stat_changed.connect(_refresh)
	equipment.equipment_changed.connect(_refresh)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_status") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if _panel.visible:
		_saved_position = _window.global_position
		_has_saved_position = true
		_panel.visible = false
	else:
		_panel.visible = true
		if _has_saved_position:
			_window.global_position = _saved_position

func is_open() -> bool:
	return _panel.visible

func _build_panel() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	margin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	margin.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(margin)
	_window = margin
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(480, 510)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.04, 0.025, 0.975)
	style.border_color = Color(0.7, 0.47, 0.2, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", style)
	margin.add_child(_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_panel.add_child(content)
	var drag_handle := WindowDragHandle.new()
	drag_handle.configure(_window)
	content.add_child(drag_handle)
	content.add_child(_build_paper_doll())
	var stats_scroll := ScrollContainer.new()
	stats_scroll.custom_minimum_size = Vector2(0, 210)
	stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(stats_scroll)
	stats_scroll.add_child(_build_stat_tabs())

func _build_paper_doll() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 254)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.add_child(_build_equipment_column([0, 1, 2, 3, 9]))
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(150, 238)
	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = Color(0.11, 0.08, 0.045, 1.0)
	portrait_style.border_color = Color(0.48, 0.32, 0.15, 1.0)
	portrait_style.set_border_width_all(1)
	portrait_frame.add_theme_stylebox_override("panel", portrait_style)
	row.add_child(portrait_frame)
	var portrait := TextureRect.new()
	var idle_south := AtlasTexture.new()
	idle_south.atlas = KNIGHT_TEXTURE
	idle_south.region = Rect2(17, 0, 59, 128)
	idle_south.margin = Rect2(17, 0, 37, 0)
	portrait.texture = idle_south
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait)
	row.add_child(_build_equipment_column([6, 4, 5, 7, 8, 9]))
	return row

func _build_equipment_column(indices: Array[int]) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	for index: int in indices:
		var slot := EquipmentSlotControl.new()
		slot.custom_minimum_size = Vector2(62, 44)
		slot.configure(equipment, inventory, EQUIPMENT_SLOTS[index])
		column.add_child(slot)
		_equipment_slots.append(slot)
	return column

func _build_stat_tabs() -> TabContainer:
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 250)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var offence := VBoxContainer.new()
	offence.name = "Offence"
	_derived_label = _add_label(offence, Color(0.95, 0.74, 0.4))
	tabs.add_child(offence)
	var defence := VBoxContainer.new()
	defence.name = "Defence"
	_defence_label = _add_label(defence, Color(0.62, 0.8, 0.96))
	tabs.add_child(defence)
	var misc := VBoxContainer.new()
	misc.name = "Misc"
	_misc_label = _add_label(misc, Color(0.74, 0.82, 0.7))
	tabs.add_child(misc)
	return tabs

func _add_label(parent: Control, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label

func _refresh(_property: StringName = &"") -> void:
	for slot: EquipmentSlotControl in _equipment_slots:
		slot.configure(equipment, inventory, slot.slot)
	_derived_label.text = "ATK %.1f  MATK %.1f\nPhysical Damage      %.1f\nAttack Speed           %.2f\nAccuracy Rating        %.1f\nCritical Chance        %.1f%%" % [status_points.stats.attack_damage, status_points.stats.magic_attack, status_points.stats.attack_damage, status_points.stats.attack_speed, status_points.stats.acc, status_points.stats.crit]
	_defence_label.text = "Armour              %.1f\nAttack Block        %.1f%%\nMaximum Life        %.0f\nMaximum Mana        %.0f\nEvasion Rating      %.1f" % [status_points.stats.armour, status_points.stats.block, status_points.stats.max_health, status_points.stats.max_mana, status_points.stats.evasion]
	_misc_label.text = "Level %d\nMove Speed %.1f\nCurrent Life %.0f / %.0f\nCurrent Mana %.0f / %.0f" % [status_points.stats.level, status_points.stats.movement_speed, status_points.stats.current_health, status_points.stats.max_health, status_points.stats.mana, status_points.stats.max_mana]
