class_name TabletopCardTableView
extends TabletopGameView
## Configured card family. No imports from a game's rules or card model.

const SelectionHand = preload("res://ui/selection_hand.gd")
const FACTORY = preload("res://ui/card_factory.tscn")

var layout: TabletopCardTableLayout
var hand: SelectionHand
var manager: TabletopCardManager
var seats: Array[Label] = []
var status: Label
var table_label: Label
var detail: Label
var selection_label: Label
var action_buttons: Dictionary = {}
var _specs: Dictionary = {}
var _options: Dictionary = {}
var _cycles: Dictionary = {}
var _context: Dictionary

func _ready() -> void:
	super._ready()
	layout = configuration as TabletopCardTableLayout
	assert(layout != null, "Card view requires a card layout")
	custom_minimum_size.y = layout.minimum_height
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	for section in layout.sections:
		match section:
			"table": _build_table(column)
			"hand": _build_hand(column)
			"actions": _build_actions(column)
			"help":
				var help := TabletopUI.label(layout.help_text, 12)
				help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				column.add_child(help)
			_: assert(false, "Unknown card table section: " + section)
	assert(hand != null and action_buttons.size() == layout.actions.size())

func _build_table(column: VBoxContainer) -> void:
	var table := TabletopSurface.new()
	table.texture = layout.media.table_texture
	table.custom_minimum_size.y = layout.table_height
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.add_theme_stylebox_override("panel", TabletopUI.panel(layout.table_color, 22))
	column.add_child(table)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	table.add_child(content)
	var players := HBoxContainer.new()
	content.add_child(players)
	for _seat in layout.seat_order:
		var label := TabletopUI.label("", 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		players.add_child(label)
		seats.append(label)
	status = TabletopUI.label("", 24)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(status)
	table_label = TabletopUI.label("", 22)
	table_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	table_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	table_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	table_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(table_label)
	detail = TabletopUI.label("", 14)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(detail)

func _build_hand(column: VBoxContainer) -> void:
	manager = TabletopCardManager.new()
	manager.card_factory_scene = FACTORY
	manager.card_size = layout.card_size
	manager.custom_minimum_size.y = layout.hand_height
	column.add_child(manager)
	hand = SelectionHand.new()
	hand.enable_drop_zone = false
	hand.align_drop_zone_size_with_current_hand_size = false
	hand.max_hand_size = layout.max_hand_size
	hand.hand_rotation_curve = Curve.new()
	hand.hand_rotation_curve.add_point(Vector2(0, 0))
	hand.hand_rotation_curve.add_point(Vector2(1, 0))
	hand.hand_vertical_curve = Curve.new()
	hand.hand_vertical_curve.add_point(Vector2(0, 0))
	hand.hand_vertical_curve.add_point(Vector2(1, 0))
	manager.add_child(hand)
	manager.resized.connect(_layout_hand)
	hand.selection_changed.connect(_selection_changed)
	_layout_hand.call_deferred()

func _build_actions(column: VBoxContainer) -> void:
	var controls := HFlowContainer.new()
	controls.add_theme_constant_override("h_separation", 10)
	column.add_child(controls)
	for spec in layout.actions:
		assert(not _specs.has(spec.id), "Duplicate configured action")
		_specs[spec.id] = spec
		_cycles[spec.id] = 0
		action_buttons[spec.id] = TabletopUI.button(controls, spec.label, activate.bind(spec.id))
	selection_label = TabletopUI.label("", 14)
	controls.add_child(selection_label)

func render(observation: Dictionary, legal: Array[Dictionary]) -> void:
	_context = binding_context(observation)
	for index in range(layout.seat_order.size()):
		var seat: int = layout.seat_order[index]
		var local := _context.duplicate()
		local.seat = seat
		local.seat_number = seat + 1
		seats[index].text = str(TabletopBinding.read(layout.seat_text, local))
		seats[index].modulate = layout.accent_color if seat == TabletopBinding.read(layout.active_seat_binding, _context) else Color.WHITE
	status.text = str(TabletopBinding.read(layout.status_text, _context))
	table_label.text = str(TabletopBinding.read(layout.table_text, _context))
	detail.text = str(TabletopBinding.read(layout.detail_text, _context))
	for id in _specs:
		var spec: Dictionary = _specs[id]
		action_buttons[id].visible = TabletopBinding.read(spec.when, _context)
		_options[id] = []
		_cycles[id] = 0
		for action in legal:
			if _matches(action.command, spec.command):
				_options[id].append(action)
	hand.selected_keys.clear()
	hand.input_enabled = not blocked
	manager.input_scope.release()
	hand.clear_cards()
	var factory := manager.card_factory as TabletopCardFactory
	factory.definitions.clear()
	for value in TabletopBinding.read(layout.hand_binding, _context):
		var key := str(value)
		var face: Dictionary = layout.media.cards[key].duplicate(true)
		face.face_texture = layout.media.card_face
		face.artwork = layout.media.card_artwork.get(key)
		factory.definitions[key] = face
		var card := factory.create_card(key, hand)
		card.can_be_interacted_with = not blocked
	_selection_changed([])

func _layout_hand() -> void:
	hand.max_hand_spread = minf(layout.max_hand_spread, maxf(0, manager.size.x - manager.card_size.x - 24))
	hand.position = Vector2(manager.size.x / 2, 14)
	hand.update_card_ui()

func _selection_changed(keys: PackedStringArray) -> void:
	var legal_count := 0
	for id in _specs:
		var spec: Dictionary = _specs[id]
		var available: bool = not _options[id].is_empty()
		if not spec.selection_field.is_empty():
			legal_count = maxi(legal_count, _options[id].size())
			if not spec.browse:
				available = _selection_is_legal(keys, _options[id], spec.selection_field)
		action_buttons[id].disabled = blocked or not available
	var local := _context.duplicate()
	local.selection_count = keys.size()
	local.legal_count = legal_count
	selection_label.text = str(TabletopBinding.read(layout.selection_text, local))

func _selection_is_legal(keys: PackedStringArray, options: Array, field: String) -> bool:
	if keys.is_empty():
		return false
	var signature := _signature(keys)
	for action in options:
		if signature == _signature(action.command[field]):
			return true
	return false

func _signature(values: Variant) -> Array:
	var result: Array = []
	for value in values:
		var key := str(value)
		result.append(key if layout.selection_equivalence.is_empty() else str(layout.media.cards[key][layout.selection_equivalence]))
	result.sort()
	return result

func activate(id: String) -> void:
	if action_buttons[id].disabled:
		return
	var spec: Dictionary = _specs[id]
	if spec.browse:
		var options: Array = _options[id]
		var action: Dictionary = options[_cycles[id] % options.size()]
		_cycles[id] += 1
		hand.selected_keys.clear()
		for value in action.command[spec.selection_field]:
			hand.selected_keys.append(str(value))
		for card in hand.cards_node.get_children():
			(card as TabletopPlayingCard).selected = hand.selected_keys.has(card.card_name)
		hand.selection_changed.emit(hand.selected_keys.duplicate())
		return
	var command: Dictionary = spec.command.duplicate(true)
	if not spec.selection_field.is_empty():
		var values: Array = []
		for key in hand.selected_keys:
			values.append(int(key) if layout.numeric_card_keys else key)
		command[spec.selection_field] = values
	request_command(command)

func _matches(command: Dictionary, required: Dictionary) -> bool:
	for key in required:
		if not command.has(key) or command[key] != required[key]:
			return false
	return true

func deactivate() -> void:
	manager.input_scope.release()
	hand.selected_keys.clear()
	cues.stop()
