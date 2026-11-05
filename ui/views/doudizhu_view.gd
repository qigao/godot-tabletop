extends TabletopGameView

const Cards = preload("res://games/doudizhu/cards.gd")
const Patterns = preload("res://games/doudizhu/patterns.gd")
const SelectionHand = preload("res://ui/selection_hand.gd")
const FACTORY = preload("res://ui/card_factory.tscn")

var hand: SelectionHand
var manager: TabletopCardManager
var seats: Array[Label] = []
var turn_label: Label
var last_label: Label
var detail_label: Label
var selection_label: Label
var bid_buttons: Array[Button] = []
var play_button: Button
var pass_button: Button
var cycle_button: Button
var legal_plays: Array[Dictionary] = []
var _cycle_index := 0
var _observation: Dictionary

func _ready() -> void:
	custom_minimum_size.y = 440
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var table := PanelContainer.new()
	table.custom_minimum_size.y = 190
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.add_theme_stylebox_override("panel", TabletopUI.panel(Color("112e36"), 22))
	column.add_child(table)
	var board := VBoxContainer.new()
	board.add_theme_constant_override("separation", 10)
	table.add_child(board)
	var players := HBoxContainer.new()
	board.add_child(players)
	for _seat in range(3):
		var label := TabletopUI.label("", 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		players.add_child(label)
		seats.append(label)
	turn_label = TabletopUI.label("", 24)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(turn_label)
	last_label = TabletopUI.label("", 22)
	last_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	last_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	last_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	last_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.add_child(last_label)
	detail_label = TabletopUI.label("", 14)
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board.add_child(detail_label)
	manager = TabletopCardManager.new()
	manager.card_factory_scene = FACTORY
	manager.card_size = Vector2(76, 116)
	manager.custom_minimum_size.y = 155
	column.add_child(manager)
	hand = SelectionHand.new()
	hand.enable_drop_zone = false
	hand.align_drop_zone_size_with_current_hand_size = false
	hand.max_hand_size = 20
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
	var controls := HFlowContainer.new()
	controls.add_theme_constant_override("h_separation", 10)
	column.add_child(controls)
	for bid in range(4):
		bid_buttons.append(TabletopUI.button(controls, "No bid" if bid == 0 else "Bid %d" % bid, _on_bid.bind(bid)))
	play_button = TabletopUI.button(controls, "Play selected", _on_play)
	pass_button = TabletopUI.button(controls, "Pass", func() -> void: request_command({"type": "pass"}))
	cycle_button = TabletopUI.button(controls, "Next legal play", _on_cycle)
	selection_label = TabletopUI.label("", 14)
	controls.add_child(selection_label)
	column.add_child(TabletopUI.label("Click / tap / Space: select  |  Arrow keys: next card  |  Local hotseat: pass the device", 12))

func render(view: Dictionary, legal: Array[Dictionary]) -> void:
	_observation = view
	for seat in range(3):
		var role := "Landlord" if view.landlord == seat else "Farmer"
		if view.phase == "bidding":
			role = "Bid: %s" % ("-" if view.bids[seat] == -1 else str(view.bids[seat]))
		seats[seat].text = "Seat %d  /  %s\n%d cards" % [seat + 1, role, view.hand_counts[seat]]
		seats[seat].modulate = Color("f7c66b") if seat == view.turn else Color.WHITE
	turn_label.text = "Seat %d to %s" % [view.turn + 1, "bid" if view.phase == "bidding" else "play"]
	if view.phase == "finished":
		turn_label.text = "Landlord wins" if view.winner == view.landlord else "Farmers win"
	last_label.text = "A new trick" if view.last_cards.is_empty() else _card_labels(view.last_cards)
	detail_label.text = "Multiplier x%d" % view.multiplier
	if not view.last_pattern.is_empty():
		detail_label.text += "  /  " + view.last_pattern.kind.replace("_", " ")
	if view.phase != "bidding":
		detail_label.text += "  /  Bottom: " + _card_labels(view.bottom)
	if view.phase == "finished":
		detail_label.text += "  /  Scores: " + str(view.scores)
	for value in range(4):
		bid_buttons[value].visible = view.phase == "bidding"
		bid_buttons[value].disabled = blocked or (value > 0 and value <= view.highest_bid)
	play_button.visible = view.phase == "playing"
	pass_button.visible = view.phase == "playing"
	pass_button.disabled = blocked or view.last_pattern.is_empty()
	cycle_button.visible = view.phase == "playing"
	legal_plays.clear()
	for action in legal:
		if action.command.type == "play":
			legal_plays.append(action)
	_cycle_index = 0
	cycle_button.disabled = blocked or legal_plays.is_empty()
	hand.selected_keys.clear()
	hand.input_enabled = not blocked
	manager.input_scope.release()
	hand.clear_cards()
	var factory := manager.card_factory as TabletopCardFactory
	factory.definitions.clear()
	for id in view.hands[view.turn]:
		var label := Cards.label(int(id))
		factory.definitions[str(id)] = {"title": label.left(-1), "symbol": label.right(1),
				"ink": Color("b93446") if int(id) % 4 in [1, 3] or int(id) == 53 else Color("17263b")}
		if int(id) >= 52:
			factory.definitions[str(id)].title = label
			factory.definitions[str(id)].symbol = "JOKER"
		var card := factory.create_card(str(id), hand)
		card.can_be_interacted_with = not blocked
	_selection_changed([])

func _layout_hand() -> void:
	hand.max_hand_spread = minf(1030, maxf(0, manager.size.x - manager.card_size.x - 24))
	hand.position = Vector2(manager.size.x / 2, 14)
	hand.update_card_ui()

func _selection_changed(keys: PackedStringArray) -> void:
	var pattern := Patterns.classify(_ids(keys))
	selection_label.text = "%d selected / %d legal plays" % [keys.size(), legal_plays.size()]
	if not pattern.is_empty():
		selection_label.text += " / " + pattern.kind.replace("_", " ")
	play_button.disabled = blocked or not Patterns.beats(pattern, _observation.last_pattern)

func _on_cycle() -> void:
	var action: Dictionary = legal_plays[_cycle_index % legal_plays.size()]
	_cycle_index += 1
	hand.selected_keys.clear()
	for id in action.command.cards:
		hand.selected_keys.append(str(id))
	for card in hand.cards_node.get_children():
		(card as TabletopPlayingCard).selected = hand.selected_keys.has(card.card_name)
	hand.selection_changed.emit(hand.selected_keys.duplicate())

func _on_bid(value: int) -> void:
	request_command({"type": "bid", "value": value})

func _on_play() -> void:
	request_command({"type": "play", "cards": _ids(hand.selected_keys)})

func deactivate() -> void:
	manager.input_scope.release()
	hand.selected_keys.clear()

func _ids(keys: PackedStringArray) -> Array:
	var result: Array = []
	for key in keys:
		result.append(int(key))
	return result

func _card_labels(ids: Array) -> String:
	var labels: PackedStringArray = []
	for id in ids:
		labels.append(Cards.label(int(id)))
	return "  ".join(labels)
