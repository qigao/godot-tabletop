extends SceneTree
## Input routing and observable client behavior, not direct gesture method calls.

const APP = preload("res://ui/tabletop_app.tscn")
var app
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _frames(count: int = 3) -> void:
	for _i in range(count):
		await process_frame

func _mouse(point: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)

func _motion(point: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event, true)

func _click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	_motion(point)
	_mouse(point, true)
	_mouse(point, false)

func _card_point(view: TabletopCardTableView, index: int) -> Vector2:
	var card: Card = view.hand.cards_node.get_child(index)
	# The exposed left strip stays accessible even with overlapping hand cards.
	return card.get_global_transform_with_canvas() * Vector2(8, 36)

func _touch(point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.index = 0
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)

func _run() -> void:
	root.size = Vector2i(1280, 800)
	app = APP.instantiate()
	root.add_child(app)
	current_scene = app
	await _frames()
	var view := app.current_view as TabletopCardTableView
	var heard: Array[String] = []
	view.cues.cue_started.connect(func(cue: String) -> void: heard.append(cue))
	var id: int = app.workspace.active_id
	_check(view.busy and not view.hand.input_enabled, "Sequential dealing blocks gameplay input")
	var opening: Dictionary = app.workspace.snapshot(id)
	_click(view.action_buttons.bid_3)
	_check(app.workspace.frame(id).cursor == 0 and app.workspace.snapshot(id) == opening, "Clicks during dealing cannot commit")
	await create_timer(1.6).timeout
	_check(not view.busy and view.hand.input_enabled, "Deal animation completes and returns control")
	_check(view.public_rows.bottom.hidden_count == 3 and view.public_rows.bottom.cards.is_empty(), "Bidding shows three hidden bottom cards")
	_check(view.seat_badges[1].concealed and view.seat_badges[2].count == 17, "Relative opponents show hidden cards/counts")
	_click(view.action_buttons.bid_3)
	_check(app.workspace.frame(id).cursor == 1 and view.busy, "Viewport bid starts bottom reveal")
	await create_timer(0.4).timeout
	_check(view.public_rows.bottom.cards.size() == 3 and view.public_rows.bottom.hidden_count == 0, "Bottom reveal exposes exactly the public cards")
	_check(view.hand.get_card_count() == 20 and not view.busy, "Landlord hand and controls settle")
	_check(view.cues._players.music.playing and view.cues._players.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Active view plays the configured looping background")
	_check(view.clock.running and view.clock.remaining > 55, "Active turn shows a running local clock")
	view.set_reduced_motion(true)
	await _frames()
	var point := _card_point(view, 2)
	var card := view.hand.cards_node.get_child(2) as TabletopPlayingCard
	_motion(point)
	await _frames()
	_check(view.manager.input_scope.hovered == card, "Actual viewport hover targets the exposed card")
	var before := card.global_position
	_mouse(point, true)
	_mouse(point, false)
	await _frames()
	_check(view.hand.selected_keys.has(card.card_name) and card.global_position.y < before.y, "Click selection stays visibly lifted")
	app._refresh()
	_check(view.hand.selected_keys.has(card.card_name), "A repeated workspace render preserves selection")
	var right := _card_point(view, 2)
	_mouse(right, true, MOUSE_BUTTON_RIGHT)
	_mouse(right, false, MOUSE_BUTTON_RIGHT)
	_check(view.hand.selected_keys.is_empty(), "Right click clears selection")
	# Keyboard focus follows the clicked card; Shift+arrow extends a range.
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_RIGHT
	key.shift_pressed = true
	root.push_input(key, true)
	_check(view.hand.selected_keys.size() == 2, "Keyboard range selection shares the same hand controller")
	key.keycode = KEY_ESCAPE
	key.shift_pressed = false
	root.push_input(key, true)
	_check(view.hand.selected_keys.is_empty(), "Escape clears keyboard selection")
	await _frames()
	# High-speed range selection crosses intermediate cards in one motion event.
	point = _card_point(view, 0)
	_motion(point)
	_mouse(point, true)
	_motion(_card_point(view, 5), true)
	_mouse(_card_point(view, 5), false)
	_check(view.hand.selected_keys.size() == 6, "Mouse sweep selects all crossed cards")
	point = _card_point(view, 0)
	_mouse(point, true)
	_motion(_card_point(view, 5), true)
	_mouse(_card_point(view, 5), false)
	_check(view.hand.selected_keys.is_empty(), "Sweep across selected cards deselects the range once")
	point = _card_point(view, 1)
	_touch(point, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = _card_point(view, 4)
	root.push_input(drag, true)
	_touch(drag.position, false)
	_check(view.hand.selected_keys.size() == 4, "Real touch drag selects a range")
	var kept := view.hand.selected_keys.duplicate()
	point = _card_point(view, 8)
	_touch(point, true)
	_touch(point, false, true)
	_check(view.hand.selected_keys == kept, "Canceled touch restores the prior selection")
	view.hand.clear_selection()
	# Drag a known legal single; authority sees one physical card and one commit.
	_click(view.action_buttons.browse)
	var selected: String = view.hand.selected_keys[0]
	var selected_index := 0
	for i in range(view.hand.get_card_count()):
		if view.hand.cards_node.get_child(i).card_name == selected:
			selected_index = i
	point = _card_point(view, selected_index)
	_mouse(point, true)
	_motion(point - Vector2(0, 40), true)
	_check(view._drag_ghost.visible and view._drop_hint.visible, "Dragging a selected group shows target feedback")
	var target := view._drop_hint.get_global_rect().get_center()
	_motion(target, true)
	_mouse(target, false)
	_check(app.workspace.frame(id).cursor == 2 and app.workspace.snapshot(id).hands[0].size() == 19, "Drop commits exactly one legal play through authority")
	_check(view.public_rows.last_play.cards.size() == 1, "Actual played cards render on the table")
	_check(not heard.has("low_1") and not heard.has("low_2"), "Normal hand counts do not announce low-card warnings")
	_check(view.seat_badges[0].seat == 1 and view.seat_badges[0].active, "Next hotseat player occupies the local anchor")
	# Invalid multi-card groups stay in the hand, preserving state and history.
	view.hand.set_selection(PackedStringArray([view.hand.cards_node.get_child(0).card_name, view.hand.cards_node.get_child(4).card_name]))
	var prior: Dictionary = app.workspace.snapshot(id)
	var revision: int = app.workspace.frame(id).cursor
	point = _card_point(view, 0)
	_mouse(point, true)
	_motion(point - Vector2(0, 45), true)
	_motion(view._drop_hint.get_global_rect().get_center(), true)
	_mouse(view._drop_hint.get_global_rect().get_center(), false)
	_check(app.workspace.snapshot(id) == prior and app.workspace.frame(id).cursor == revision, "Illegal drop cannot change game state/history")
	_check(not view._drag_ghost.visible and not view._drop_hint.visible, "Rejected drop releases the pointer preview")
	# An open gesture is invalidated by pause and cannot leak into the restored frame.
	point = _card_point(view, 0)
	_mouse(point, true)
	_motion(point - Vector2(0, 40), true)
	app._toggle_pause()
	_mouse(target, false)
	_check(view.hand._pointer == -1 and app.workspace.frame(id).cursor == revision, "Pause cancels an active pointer without submitting")
	var remaining := view.clock.remaining
	await create_timer(0.15).timeout
	_check(view.clock.remaining == remaining and not view.clock.running, "Pause suspends countdown")
	_check(view.cues._players.music.stream_paused, "Pause suspends background music")
	app._toggle_pause()
	_check(not view.cues._players.music.stream_paused, "Resume releases the music pause")
	app._on_seek(1)
	view.clock.remaining = 0.01
	await create_timer(0.05).timeout
	_check(app.workspace.frame(id).cursor == 1 and not view.clock.running, "History inspection cannot time out into a new command")
	app._toggle_pause()
	app._toggle_pause()
	view.clock.remaining = 0.01
	await create_timer(0.05).timeout
	_check(app.workspace.frame(id).cursor == 1 and not view.clock.running, "Pause/resume cannot arm a historical clock")
	app._restart()
	view.skip_animation()
	view.clock.remaining = 0.01
	await create_timer(0.05).timeout
	_check(app.workspace.frame(id).cursor == 1 and app.workspace.snapshot(id).bids[0] == 0, "Configured timeout submits only an available legal bid")
	# A physical two-card group follows the same drop path, retaining exact IDs.
	app._restart()
	view.skip_animation()
	view.activate("bid_3")
	var group: Dictionary = {}
	for candidate in app.workspace.frame(id).legal_actions:
		if candidate.command.type == "play" and candidate.command.cards.size() > 1:
			group = candidate
			break
	assert(not group.is_empty())
	for value in group.command.cards:
		for i in range(view.hand.get_card_count()):
			if view.hand.cards_node.get_child(i).card_name == str(value):
				var point_on_card := _card_point(view, i)
				_motion(point_on_card)
				_mouse(point_on_card, true)
				_mouse(point_on_card, false)
	_check(view.hand.selected_keys.size() == group.command.cards.size(), "Viewport clicks form a legal multi-card selection")
	var group_index := 0
	for i in range(view.hand.get_card_count()):
		if view.hand.cards_node.get_child(i).card_name == str(group.command.cards[0]):
			group_index = i
	point = _card_point(view, group_index)
	_mouse(point, true)
	_motion(point - Vector2(0, 45), true)
	var group_target := view._drop_hint.get_global_rect().get_center()
	_motion(group_target, true)
	_mouse(group_target, false)
	_check(app.workspace.frame(id).cursor == 2 and app.workspace.snapshot(id).hands[0].size() == 20 - group.command.cards.size(), "Selected-group drop commits the exact multi-card play once")
	# Retired timers and motion callbacks cannot mutate another table.
	app._restart()
	view.set_reduced_motion(false)
	app._restart()
	_check(view.busy, "Restart begins a fresh deal")
	app.game_picker.select(1)
	app._new_table()
	await _frames()
	var board_id: int = app.workspace.active_id
	var board: Dictionary = app.workspace.snapshot(board_id)
	await create_timer(1.4).timeout
	_check(app.workspace.snapshot(board_id) == board and app.workspace.frame(id).cursor == 0, "Switching during deal leaves both engines unchanged")
	app.workspace.select_table(id)
	await _frames()
	view = app.current_view
	view.set_reduced_motion(true)
	view.activate("bid_3")
	# One complete configured game ends in the visible result controls.
	var steps := 0
	while app.workspace.snapshot(id).phase != "finished" and steps < 500:
		var actions: Array = app.workspace.frame(id).legal_actions
		var action: Dictionary = actions[-1]
		for candidate in actions:
			if candidate.command.type == "play" and (action.command.type != "play" or candidate.command.cards.size() > action.command.cards.size()):
				action = candidate
		if action.command.type == "pass":
			view.activate("pass")
		else:
			var keys := PackedStringArray()
			for value in action.command.cards:
				keys.append(str(value))
			view.hand.set_selection(keys)
			view.activate("play")
		steps += 1
		if steps % 16 == 0:
			await process_frame
	_check(view.settlement.visible and view.result_title.text.contains("wins"), "A complete game presents the settlement overlay")
	_check(view.result_detail.text.contains(str(app.workspace.snapshot(id).scores)), "Settlement shows actual rule scores")
	await _frames()
	var result_token: int = app.workspace.frame(id).token
	var buttons: HBoxContainer = view.settlement.get_child(0).get_child(2)
	_click(buttons.get_child(0))
	_check(app.workspace.snapshot(id).phase == "bidding" and app.workspace.frame(id).cursor == 0, "Settlement new-round control resets through host lifecycle")
	var reset_seed: int = app.workspace.frame(id).seed
	app._on_view_lifecycle("new_round", result_token, id)
	_check(app.workspace.frame(id).seed == reset_seed, "Stale settlement callbacks cannot restart the new round")
	# Exercise conditional streams in the packaged client as well as source runs.
	heard.clear()
	view.cues.cue_started.connect(func(cue: String) -> void: heard.append(cue))
	view.cues.present({"token": 100001, "transition": "live", "paused": false,
			"observation": {"hand_counts": [1, 10, 10]},
			"events": [{"type": "played", "seat": 0, "pattern": {"kind": "single"}}]})
	_check(heard.has("low_1") and not heard.has("low_2"), "One-card warning follows its configured condition")
	heard.clear()
	view.cues.present({"token": 100002, "transition": "live", "paused": false,
			"observation": {"hand_counts": [10, 2, 10]},
			"events": [{"type": "played", "seat": 1, "pattern": {"kind": "pair"}}]})
	_check(heard.has("low_2") and not heard.has("low_1"), "Two-card warning follows the event seat")
	app._close()
	await _frames()
	app.queue_free()
	await _frames()
	await create_timer(0.15).timeout
	_check(Card.hovering_card_count == 0 and Card.holding_card_count == 0, "Interaction teardown releases scoped input")
	print("Interaction UX: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
