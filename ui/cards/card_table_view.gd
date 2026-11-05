class_name TabletopCardTableView
extends TabletopGameView
## Conventional card-table UX from reusable components and game resources.

const SelectionHand = preload("res://ui/selection_hand.gd")
const FACTORY = preload("res://ui/card_factory.tscn")
var layout: TabletopCardTableLayout
var hand: TabletopSelectionHand
var manager: TabletopCardManager
var seats: Array[Label] = []
var seat_badges: Array[TabletopSeatBadge] = []
var status: Label
var table_label: Label
var detail: Label
var selection_label: Label
var feedback: Label
var action_buttons: Dictionary = {}
var public_rows: Dictionary = {}
var surface: TabletopSurface
var clock: TabletopTurnClock
var effect: TabletopTableEffect
var settlement: PanelContainer
var result_title: Label
var result_detail: Label
var skip_button: Button
var busy := false
var _specs: Dictionary = {}
var _options: Dictionary = {}
var _legal_signatures: Dictionary = {}
var _cycles: Dictionary = {}
var _context: Dictionary
var _keys := PackedStringArray()
var _motion_tweens: Array[Tween] = []
var _motion_layer: Control
var _drag_ghost: TabletopCardRow
var _drop_hint: ReferenceRect
var _last_token := -1
var _counts: Array[int] = []
var _deactivated := false
var _restored_clock: Dictionary = {}
var _clock_can_run := false
var _action_row: HFlowContainer
var _visible_seat := -1

func _ready() -> void:
	super._ready()
	layout = configuration as TabletopCardTableLayout
	assert(layout != null and layout.seat_anchors.size() == layout.seat_order.size())
	assert(not layout.interaction.drag_to_play or not layout.interaction.drop_action.is_empty())
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
	_motion_layer = Control.new()
	_motion_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_motion_layer.z_index = 180
	add_child(_motion_layer)
	_drag_ghost = TabletopCardRow.new()
	_drag_ghost.media = layout.media
	_drag_ghost.card_size = layout.card_size * 0.72
	_drag_ghost.visible = false
	_drag_ghost.z_index = 200
	add_child(_drag_ghost)
	_build_settlement()
	resized.connect(_place_settlement)

func _build_table(column: VBoxContainer) -> void:
	surface = TabletopSurface.new()
	surface.texture = layout.media.table_texture
	surface.custom_minimum_size.y = layout.table_height
	surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	surface.add_theme_stylebox_override("panel", TabletopUI.panel(layout.table_color, 22))
	column.add_child(surface)
	# Plain controls inside a container-owned surface retain explicit seat anchors.
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(stage)
	for seat in layout.seat_order:
		var badge := TabletopSeatBadge.new()
		badge.media = layout.media
		badge.seat = seat
		stage.add_child(badge)
		seat_badges.append(badge)
		seats.append(badge.label)
	status = TabletopUI.label("", 21)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(status)
	table_label = TabletopUI.label("", 20)
	table_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	table_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage.add_child(table_label)
	detail = TabletopUI.label("", 13)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage.add_child(detail)
	for zone in layout.public_zones:
		var row := TabletopCardRow.new()
		row.media = layout.media
		row.card_size = zone.card_size
		stage.add_child(row)
		public_rows[zone.id] = row
	clock = TabletopTurnClock.new()
	clock.visible = layout.clock_seconds > 0
	clock.expired.connect(_clock_expired)
	stage.add_child(clock)
	_drop_hint = ReferenceRect.new()
	_drop_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_hint.editor_only = false
	_drop_hint.border_width = 3
	_drop_hint.visible = false
	stage.add_child(_drop_hint)
	effect = TabletopTableEffect.new()
	stage.add_child(effect)
	surface.resized.connect(_place_table_items)
	_place_table_items.call_deferred()

func _place_table_items() -> void:
	var area := surface.size - Vector2(28, 28)
	for index in range(seat_badges.size()):
		seat_badges[index].position = layout.seat_anchors[index] * area - seat_badges[index].size / 2
	status.position = Vector2(area.x * 0.25, area.y * 0.32)
	status.size = Vector2(area.x * 0.5, 30)
	table_label.position = Vector2(area.x * 0.25, area.y * 0.53)
	table_label.size = Vector2(area.x * 0.5, 55)
	detail.position = Vector2(area.x * 0.25, area.y - 22)
	detail.size = Vector2(area.x * 0.7, 22)
	for zone in layout.public_zones:
		var row: TabletopCardRow = public_rows[zone.id]
		row.size = zone.size
		row.position = zone.anchor * area - row.size / 2
		row.queue_redraw()
	clock.position = Vector2(area.x * 0.74, area.y * 0.42) - clock.size / 2
	_drop_hint.position = Vector2(area.x * 0.26, area.y * 0.46)
	_drop_hint.size = Vector2(area.x * 0.48, area.y * 0.44)
	effect.size = area

func _build_hand(column: VBoxContainer) -> void:
	manager = TabletopCardManager.new()
	manager.card_factory_scene = FACTORY
	manager.card_size = layout.card_size
	manager.custom_minimum_size.y = layout.hand_height
	column.add_child(manager)
	hand = SelectionHand.new()
	hand.interaction = layout.interaction
	hand.enable_drop_zone = false
	hand.align_drop_zone_size_with_current_hand_size = false
	hand.max_hand_size = layout.max_hand_size
	hand.hand_rotation_curve = Curve.new()
	hand.hand_rotation_curve.min_value = -maxf(1, layout.fan_rotation)
	hand.hand_rotation_curve.max_value = maxf(1, layout.fan_rotation)
	hand.hand_rotation_curve.add_point(Vector2(0, -layout.fan_rotation))
	hand.hand_rotation_curve.add_point(Vector2(1, layout.fan_rotation))
	hand.hand_vertical_curve = Curve.new()
	hand.hand_vertical_curve.max_value = maxf(1, layout.fan_lift)
	hand.hand_vertical_curve.add_point(Vector2(0, 0))
	hand.hand_vertical_curve.add_point(Vector2(0.5, layout.fan_lift))
	hand.hand_vertical_curve.add_point(Vector2(1, 0))
	manager.add_child(hand)
	manager.mouse_filter = Control.MOUSE_FILTER_STOP
	manager.gui_input.connect(hand.route_input)
	manager.mouse_exited.connect(hand.pointer_left)
	manager.resized.connect(_layout_hand)
	hand.selection_changed.connect(_selection_changed)
	hand.drag_preview.connect(_preview_drag)
	hand.drop_requested.connect(_drop_cards)
	hand.gesture_finished.connect(_end_drag)
	_layout_hand.call_deferred()

func _build_actions(column: VBoxContainer) -> void:
	var controls := HFlowContainer.new()
	_action_row = controls
	controls.add_theme_constant_override("h_separation", 10)
	column.add_child(controls)
	for spec in layout.actions:
		assert(not _specs.has(spec.id))
		_specs[spec.id] = spec
		_cycles[spec.id] = 0
		action_buttons[spec.id] = TabletopUI.button(controls, spec.label, activate.bind(spec.id))
	skip_button = TabletopUI.button(controls, "Skip motion", skip_animation)
	skip_button.visible = false
	TabletopUI.button(controls, "Clear", func() -> void: hand.clear_selection())
	selection_label = TabletopUI.label("", 14)
	controls.add_child(selection_label)
	feedback = TabletopUI.label("", 13)
	feedback.modulate = Color("f7c66b")
	controls.add_child(feedback)

func render(observation: Dictionary, legal: Array[Dictionary]) -> void:
	var new_token := frame_token != _last_token
	var old_positions: Dictionary = {}
	for card in hand.cards_node.get_children():
		old_positions[card.card_name] = card.global_position
	if new_token or blocked:
		feedback.text = ""
		_cancel_motion()
		hand.cancel_pointer()
		manager.input_scope.release()
		effect.stop()
		for badge in seat_badges:
			badge.callout = ""
	_context = binding_context(observation)
	var active := int(TabletopBinding.read(layout.active_seat_binding, _context))
	_counts.clear()
	for index in range(layout.seat_order.size()):
		var seat: int = (layout.seat_order[index] + active) % layout.seat_order.size() if layout.relative_seats else layout.seat_order[index]
		var local := _context.duplicate()
		local.seat = seat
		local.seat_number = seat + 1
		var badge := seat_badges[index]
		badge.seat = seat
		badge.active = seat == active
		badge.label.text = str(TabletopBinding.read(layout.seat_text, local))
		badge.role.text = "" if layout.role_binding.is_empty() else str(TabletopBinding.read(layout.role_binding, local))
		badge.label.modulate = layout.accent_color if badge.active else Color.WHITE
		badge.count = 0 if layout.count_binding.is_empty() else int(TabletopBinding.read(layout.count_binding, local))
		badge.concealed = not badge.active and badge.count > 0
		_counts.append(badge.count)
		badge.queue_redraw()
	status.text = str(TabletopBinding.read(layout.status_text, _context))
	table_label.text = str(TabletopBinding.read(layout.table_text, _context))
	table_label.visible = layout.public_zones.is_empty()
	detail.text = str(TabletopBinding.read(layout.detail_text, _context))
	for zone in layout.public_zones:
		var row: TabletopCardRow = public_rows[zone.id]
		row.cards = TabletopBinding.read(zone.cards, _context).duplicate()
		row.hidden_count = int(TabletopBinding.read(zone.hidden_count, _context))
		row.caption = str(TabletopBinding.read(zone.caption, _context))
		row.queue_redraw()
	for id in _specs:
		var spec: Dictionary = _specs[id]
		action_buttons[id].visible = TabletopBinding.read(spec.when, _context)
		_options[id] = []
		_legal_signatures[id] = {}
		if new_token:
			_cycles[id] = 0
		for action in legal:
			if _matches(action.command, spec.command):
				_options[id].append(action)
				if not spec.selection_field.is_empty():
					_legal_signatures[id][JSON.stringify(_signature(action.command[spec.selection_field]))] = true
	var keys := PackedStringArray()
	for value in TabletopBinding.read(layout.hand_binding, _context):
		keys.append(str(value))
	if keys != _keys:
		manager.input_scope.release()
		hand.selected_keys.clear()
		var factory := manager.card_factory as TabletopCardFactory
		factory.definitions.clear()
		for key in keys:
			factory.definitions[key] = TabletopCardFace.info_for(layout.media, key)
		var origin := surface.global_position + surface.size * layout.motion.origin
		hand.sync_cards(keys, factory, origin, active == _visible_seat and client_frame.transition == "live" and not reduced_motion)
		_keys = keys
	elif new_token and client_frame.transition in ["reset", "review", "import"]:
		hand.selected_keys.clear()
	hand.client_token = frame_token
	settlement.visible = bool(TabletopBinding.read(layout.settlement_when, _context))
	_action_row.visible = not settlement.visible
	if settlement.visible:
		result_title.text = status.text
		result_detail.text = detail.text
	_place_table_items()
	if new_token:
		_update_clock(legal)
		if not blocked and not reduced_motion and layout.motion.enabled:
			if client_frame.transition in ["created", "reset"]:
				_start_deal()
			elif client_frame.transition == "live":
				_animate_events(client_frame.events, old_positions)
		if client_frame.transition == "live" and not blocked and not settlement.visible:
			_show_event_feedback(client_frame.events)
		if settlement.visible and not reduced_motion and layout.motion.enabled:
			settlement.modulate.a = 0
			var tween := create_tween()
			_motion_tweens.append(tween)
			tween.tween_property(settlement, "modulate:a", 1.0, layout.motion.settlement_seconds)
	_last_token = frame_token
	_visible_seat = active
	_selection_changed(hand.selected_keys)
	clock.suspended = busy or blocked or settlement.visible

func _layout_hand() -> void:
	hand.max_hand_spread = minf(layout.max_hand_spread, maxf(0, manager.size.x - manager.card_size.x - 32))
	hand.position = Vector2(manager.size.x / 2, 58)
	hand.update_card_ui()

func _process(_delta: float) -> void:
	clock.suspended = busy or blocked or settlement.visible

func _selection_changed(keys: PackedStringArray) -> void:
	hand.refresh_selection_visuals()
	var legal_count := 0
	for id in _specs:
		var spec: Dictionary = _specs[id]
		var available: bool = not _options[id].is_empty()
		if not spec.selection_field.is_empty():
			legal_count = maxi(legal_count, _options[id].size())
			if not spec.browse:
				available = not keys.is_empty() and _legal_signatures[id].has(JSON.stringify(_signature(keys)))
		action_buttons[id].disabled = blocked or busy or settlement.visible or not available
	hand.input_enabled = not blocked and not busy and not settlement.visible
	hand._update_card_states()
	var local := _context.duplicate()
	local.selection_count = keys.size()
	local.legal_count = legal_count
	selection_label.text = str(TabletopBinding.read(layout.selection_text, local))

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
		var keys := PackedStringArray()
		for value in action.command[spec.selection_field]:
			keys.append(str(value))
		hand.set_selection(keys)
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

func _preview_drag(keys: PackedStringArray, point: Vector2) -> void:
	_drag_ghost.cards = Array(keys)
	_drag_ghost.size = Vector2(minf(manager.size.x, 340), 116)
	_drag_ghost.global_position = point - Vector2(_drag_ghost.size.x / 2, 36)
	_drag_ghost.visible = true
	_drag_ghost.queue_redraw()
	_drop_hint.visible = true
	_drop_hint.border_color = Color("58c89d") if not action_buttons[layout.interaction.drop_action].disabled else Color("ed846b")
	feedback.text = "Release in the highlighted area" if not action_buttons[layout.interaction.drop_action].disabled else "Choose a legal combination"

func _drop_cards(keys: PackedStringArray, point: Vector2, ticket: int) -> void:
	if _deactivated or ticket != frame_token or blocked or busy:
		return
	var inside := _drop_hint.get_global_rect().has_point(point)
	if inside and not action_buttons[layout.interaction.drop_action].disabled:
		hand.set_selection(keys)
		activate(layout.interaction.drop_action)
	else:
		feedback.text = "Selection kept — drop on the table to play" if not inside else "This selection is not a legal play"

func _end_drag() -> void:
	if feedback != null and feedback.text == "Release in the highlighted area":
		feedback.text = ""
	if _drag_ghost != null:
		_drag_ghost.visible = false
	if _drop_hint != null:
		_drop_hint.visible = false

func _start_deal() -> void:
	busy = true
	skip_button.visible = true
	for card in hand.cards_node.get_children():
		card.modulate.a = 0
	_deal_after_layout.call_deferred(frame_token)

func _deal_after_layout(ticket: int) -> void:
	await get_tree().process_frame
	if ticket != frame_token or not busy:
		return
	_layout_hand()
	var origin := surface.global_position + surface.size * layout.motion.origin
	var duration := layout.motion.deal_seconds
	var interval := layout.motion.deal_interval
	var count := hand.get_card_count()
	var tween := create_tween().set_parallel(true)
	_motion_tweens.append(tween)
	var seat_count := maxi(1, seat_badges.size())
	var active_slot := 0
	for i in range(seat_badges.size()):
		if seat_badges[i].active:
			active_slot = i
		seat_badges[i].count = 0
		seat_badges[i].queue_redraw()
	for i in range(count):
		var card := hand.cards_node.get_child(i) as TabletopPlayingCard
		var target: Dictionary = hand.get_target_pose_for(card)
		card.snap_to(origin)
		card.rotation = 0
		var delay := (i * seat_count + active_slot) * interval
		tween.tween_property(card, "modulate:a", 1.0, 0.03).set_delay(delay)
		tween.tween_property(card, "global_position", target.position, duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "rotation", target.rotation, duration).set_delay(delay)
	for index in range(seat_badges.size()):
		if seat_badges[index].active:
			continue
		for i in range(_counts[index]):
			var ghost := TabletopCardRow.new()
			ghost.media = layout.media
			ghost.hidden_count = 1
			ghost.card_size = Vector2(25, 38)
			ghost.size = Vector2(25, 58)
			_motion_layer.add_child(ghost)
			ghost.global_position = origin
			ghost.modulate.a = 0
			var delay := (i * seat_count + index) * interval
			tween.tween_property(ghost, "modulate:a", 1.0, 0.02).set_delay(delay)
			tween.tween_property(ghost, "global_position", seat_badges[index].get_global_rect().get_center(), duration).set_delay(delay)
			tween.tween_property(ghost, "modulate:a", 0.0, 0.02).set_delay(delay + duration)
			tween.tween_callback(_set_dealt_count.bind(index, i + 1, ticket)).set_delay(delay + duration)
	tween.chain().tween_callback(_finish_motion.bind(ticket))

func _set_dealt_count(index: int, value: int, ticket: int) -> void:
	if not _deactivated and ticket == frame_token:
		seat_badges[index].count = value
		seat_badges[index].queue_redraw()

func _animate_events(events: Array, old_positions: Dictionary) -> void:
	for event in events:
		for spec in layout.motion_events:
			if event.type != spec.event_type:
				continue
			busy = true
			var row: TabletopCardRow = public_rows[spec.zone]
			var tween := create_tween()
			_motion_tweens.append(tween)
			match spec.kind:
				"reveal":
					row.pivot_offset = row.size / 2
					row.scale.x = 0.05
					tween.tween_property(row, "scale:x", 1.0, layout.motion.play_seconds)
				"play":
					var local := _context.duplicate()
					local.event = event
					var cards: Array = TabletopBinding.read(spec.cards, local)
					var ghost := TabletopCardRow.new()
					ghost.media = layout.media
					ghost.cards = cards.duplicate()
					ghost.card_size = row.card_size
					ghost.size = row.size
					_motion_layer.add_child(ghost)
					assert(old_positions.has(str(cards[0])), "Live played cards originate in the previous hand")
					ghost.global_position = old_positions[str(cards[0])] - Vector2(120, 0)
					tween.tween_property(ghost, "global_position", row.global_position, layout.motion.play_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
					tween.tween_property(ghost, "modulate:a", 0.0, 0.06)
				_: assert(false, "Unknown card motion")
			tween.tween_callback(_finish_motion.bind(frame_token))

func _finish_motion(ticket: int) -> void:
	if _deactivated or ticket != frame_token:
		return
	_cancel_motion()
	_selection_changed(hand.selected_keys)

func _cancel_motion() -> void:
	for tween in _motion_tweens:
		tween.kill()
	_motion_tweens.clear()
	if _motion_layer != null:
		for child in _motion_layer.get_children():
			_motion_layer.remove_child(child)
			child.queue_free()
	busy = false
	for i in range(_counts.size()):
		seat_badges[i].count = _counts[i]
		seat_badges[i].queue_redraw()
	if skip_button != null:
		skip_button.visible = false
	if hand != null:
		for card in hand.cards_node.get_children():
			card.modulate.a = 1
		for row in public_rows.values():
			row.scale = Vector2.ONE
		hand.update_card_ui()
	if settlement != null:
		settlement.modulate.a = 1

func skip_animation() -> void:
	_cancel_motion()
	if not _context.is_empty():
		_selection_changed(hand.selected_keys)

func set_reduced_motion(value: bool) -> void:
	super.set_reduced_motion(value)
	hand.reduced_motion = value
	if value:
		skip_animation()

func _update_clock(legal: Array[Dictionary]) -> void:
	clock.token = frame_token
	var restored: bool = not _restored_clock.is_empty() and _restored_clock.cursor == client_frame.cursor and _restored_clock.seed == client_frame.seed
	if restored:
		clock.remaining = _restored_clock.remaining
		clock.total = layout.clock_seconds
		clock.running = _restored_clock.running
		_clock_can_run = _restored_clock.eligible
	_restored_clock.clear()
	match client_frame.transition:
		"created", "reset", "live":
			_clock_can_run = true
			clock.start(layout.clock_seconds, frame_token)
		"resume": clock.running = _clock_can_run and clock.remaining > 0
		"pause": clock.running = false
		"review", "import":
			_clock_can_run = false
			clock.remaining = layout.clock_seconds
			clock.total = layout.clock_seconds
			clock.running = false
		"switch":
			if not restored:
				_clock_can_run = false
				clock.remaining = layout.clock_seconds
				clock.total = layout.clock_seconds
				clock.running = false
	clock.visible = layout.clock_seconds > 0 and not legal.is_empty() and not settlement.visible
	if layout.clock_seconds <= 0 or legal.is_empty() or client_frame.paused or settlement.visible:
		clock.running = false
	clock.queue_redraw()

func capture_ui_state() -> Dictionary:
	return {"cursor": client_frame.cursor, "seed": client_frame.seed,
			"remaining": clock.remaining, "running": clock.running, "eligible": _clock_can_run}

func restore_ui_state(state: Dictionary) -> void:
	_restored_clock = state.duplicate()

func _clock_expired(ticket: int) -> void:
	if _deactivated or ticket != frame_token or blocked or busy or settlement.visible:
		return
	for id in layout.timeout_actions:
		if not action_buttons[id].disabled and action_buttons[id].visible:
			activate(id)
			return
	feedback.text = "Time is up — choose a legal play"

func _show_event_feedback(events: Array) -> void:
	for event in events:
		for spec in layout.visual_events:
			if event.type != spec.event_type:
				continue
			var local := _context.duplicate()
			local.event = event
			if not TabletopBinding.read(spec.when, local):
				continue
			var text := str(TabletopBinding.read(spec.text, local))
			if spec.target == "seat":
				for badge in seat_badges:
					if badge.seat == int(event.seat):
						badge.callout = text
						badge.queue_redraw()
			else:
				effect.show_message(text, spec.color, spec.burst, layout.motion.feedback_seconds, reduced_motion)

func _build_settlement() -> void:
	settlement = PanelContainer.new()
	settlement.add_theme_stylebox_override("panel", TabletopUI.panel(Color("183740"), 20))
	settlement.z_index = 240
	settlement.visible = false
	add_child(settlement)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	settlement.add_child(content)
	result_title = TabletopUI.label("", 27)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(result_title)
	result_detail = TabletopUI.label("", 16)
	result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(result_detail)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(buttons)
	TabletopUI.button(buttons, "New round", func() -> void: lifecycle_requested.emit("new_round", frame_token))
	TabletopUI.button(buttons, "Close table", func() -> void: lifecycle_requested.emit("close", frame_token))
	_place_settlement.call_deferred()

func _place_settlement() -> void:
	settlement.size = Vector2(minf(460, size.x - 32), 200)
	settlement.position = (size - settlement.size) / 2

func deactivate() -> void:
	if _deactivated:
		return
	_deactivated = true
	clock.running = false
	effect.stop()
	hand.deactivate()
	manager.input_scope.release()
	_cancel_motion()
	cues.stop()

func _exit_tree() -> void:
	deactivate()
