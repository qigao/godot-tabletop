extends Control

const Session = preload("res://core/game_session.gd")
const Catalog = preload("res://core/game_catalog.gd")
const Cards = preload("res://games/doudizhu/cards.gd")
const Patterns = preload("res://games/doudizhu/patterns.gd")
const SelectionHand = preload("res://ui/selection_hand.gd")
const FACTORY = preload("res://ui/card_factory.tscn")

var session: TabletopSession
var hand: SelectionHand
var manager: CardManager
var seed_input: SpinBox
var status_label: Label
var last_label: Label
var pattern_label: Label
var turn_label: Label
var selection_label: Label
var seats: Array[Label] = []
var bid_buttons: Array[Button] = []
var play_button: Button
var pass_button: Button

func _ready() -> void:
	_build_ui()
	_new_game()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)
	var title := _label("TABLETOP  /  DOUDIZHU", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_label("DEAL SEED", 13))
	seed_input = SpinBox.new()
	seed_input.min_value = 0
	seed_input.max_value = 2147483647
	seed_input.value = 42
	seed_input.custom_minimum_size.x = 120
	header.add_child(seed_input)
	_button(header, "New match", _new_game)
	_button(header, "Save replay", _save_replay)
	column.add_child(_label("Local hotseat  |  Three seats, one device  |  Click cards, then play", 15))
	var table := PanelContainer.new()
	table.custom_minimum_size.y = 300
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("112e36")
	style.border_color = Color("31545c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(24)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 22
	style.content_margin_bottom = 20
	table.add_theme_stylebox_override("panel", style)
	column.add_child(table)
	var board := VBoxContainer.new()
	board.add_theme_constant_override("separation", 16)
	table.add_child(board)
	var players := HBoxContainer.new()
	board.add_child(players)
	for seat in range(3):
		var info := _label("", 20)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		players.add_child(info)
		seats.append(info)
	turn_label = _label("", 26)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(turn_label)
	last_label = _label("", 24)
	last_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	last_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	last_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	last_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	board.add_child(last_label)
	pattern_label = _label("", 16)
	pattern_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(pattern_label)
	manager = CardManager.new()
	manager.card_factory_scene = FACTORY
	manager.card_size = Vector2(82, 126)
	manager.custom_minimum_size.y = 185
	column.add_child(manager)
	hand = SelectionHand.new()
	hand.enable_drop_zone = false
	hand.align_drop_zone_size_with_current_hand_size = false
	hand.max_hand_size = 20
	hand.max_hand_spread = 1030
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
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	column.add_child(controls)
	for bid in range(4):
		bid_buttons.append(_button(controls, "No bid" if bid == 0 else "Bid %d" % bid, _on_bid.bind(bid)))
	play_button = _button(controls, "Play selected", _on_play)
	pass_button = _button(controls, "Pass", _on_pass)
	selection_label = _label("", 14)
	selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(selection_label)
	status_label = _label("", 15)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status_label)
	column.add_child(_label("M0  /  Offline rules and replay  /  S Spades · H Hearts · C Clubs · D Diamonds · SJ/BJ Jokers", 12))

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e5edf4"))
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _layout_hand() -> void:
	hand.position = Vector2(manager.size.x / 2, 24)
	hand.update_card_ui()

func _new_game() -> void:
	session = Session.new(Catalog.create_rules("doudizhu"), int(seed_input.value))
	status_label.text = "Bid 1, 2, or 3 to become landlord. Three passes redeal automatically."
	_refresh()

func _refresh() -> void:
	var public_view := session.observe(-1)
	var view := session.observe(public_view.turn)
	for seat in range(3):
		var role := "Landlord" if view.landlord == seat else "Farmer"
		if view.phase == "bidding":
			role = "Bid: %s" % ("-" if view.bids[seat] == -1 else str(view.bids[seat]))
		seats[seat].text = "Seat %d   ·   %s\n%d cards" % [seat + 1, role, view.hand_counts[seat]]
		seats[seat].modulate = Color("f7c66b") if seat == view.turn else Color.WHITE
	turn_label.text = "Seat %d to %s" % [view.turn + 1, "bid" if view.phase == "bidding" else "play"]
	if view.phase == "finished":
		turn_label.text = "Landlord wins" if view.winner == view.landlord else "Farmers win"
		status_label.text = "Scores: %s   |   Multiplier: x%d" % [str(view.scores), view.multiplier]
	last_label.text = "A new trick" if view.last_cards.is_empty() else _card_labels(view.last_cards)
	pattern_label.text = "Multiplier x%d" % view.multiplier
	if not view.last_pattern.is_empty():
		pattern_label.text += "   /   " + view.last_pattern.kind.replace("_", " ")
	if view.phase != "bidding":
		pattern_label.text += "   /   Bottom: " + _card_labels(view.bottom)
	for value in range(4):
		bid_buttons[value].visible = view.phase == "bidding"
		bid_buttons[value].disabled = value > 0 and value <= view.highest_bid
	play_button.visible = view.phase == "playing"
	pass_button.visible = view.phase == "playing"
	pass_button.disabled = view.last_pattern.is_empty()
	hand.selected_ids.clear()
	hand.clear_cards()
	for id in view.hands[view.turn]:
		manager.card_factory.create_card(str(id), hand)
	_selection_changed([])

func _selection_changed(ids: Array[int]) -> void:
	var pattern := Patterns.classify(ids)
	selection_label.text = "%d selected" % ids.size()
	if not pattern.is_empty():
		selection_label.text += " · " + pattern.kind.replace("_", " ")
	play_button.disabled = pattern.is_empty()

func _on_bid(value: int) -> void:
	_submit({"type": "bid", "value": value})

func _on_play() -> void:
	_submit({"type": "play", "cards": hand.selected_ids.duplicate()})

func _on_pass() -> void:
	_submit({"type": "pass"})

func _submit(command: Dictionary) -> void:
	var seat: int = session.observe(-1).turn
	var result := session.submit(seat, command, session.revision)
	if not result.ok:
		status_label.text = "Move rejected: " + result.error.replace("_", " ")
		return
	status_label.text = "Seat %d: %s. Pass the device to the highlighted seat." % [seat + 1, command.type]
	_refresh()

func _save_replay() -> void:
	var file := FileAccess.open("user://last-replay.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(session.export_replay(), "\t"))
	status_label.text = "Replay saved: " + ProjectSettings.globalize_path("user://last-replay.json")

func _card_labels(ids: Array) -> String:
	var labels: PackedStringArray = []
	for id in ids:
		labels.append(Cards.label(int(id)))
	return "  ".join(labels)
