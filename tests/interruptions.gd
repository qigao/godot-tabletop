extends SceneTree
## Modal/window signals and viewport input. Physical OS/device checks remain #2.

const APP = preload("res://ui/tabletop_app.tscn")
var app
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _frames() -> void:
	for _i in range(3):
		await process_frame

func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)

func _motion(point: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event, true)

func _click(point: Vector2) -> void:
	_motion(point)
	_mouse(point, true)
	_mouse(point, false)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.ctrl_pressed = true
	event.keycode = code
	root.push_input(event, true)

func _touch(point: Vector2, pressed: bool, index: int, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.index = index
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)

func _touch_move(point: Vector2, index: int) -> void:
	var event := InputEventScreenDrag.new()
	event.position = point
	event.index = index
	root.push_input(event, true)

func _card_point(card: Card) -> Vector2:
	return card.get_global_transform_with_canvas() * Vector2(8, 36)

func _focus(value: bool) -> void:
	if value:
		root.focus_entered.emit()
		app.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	else:
		app.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		root.focus_exited.emit()

func _run() -> void:
	root.size = Vector2i(1280, 800)
	app = APP.instantiate()
	root.add_child(app)
	current_scene = app
	await _frames()
	await _modal_clock()
	await _moving_gestures()
	await _snapshot_and_board()
	_key(KEY_S)
	_check(app.save_dialog.visible and app.current_view.suspended, "Client teardown can start with an open modal")
	app.queue_free()
	await _frames()
	await create_timer(0.15).timeout
	_check(Card.hovering_card_count == 0 and Card.holding_card_count == 0, "Interrupted views release all scoped card state")
	print("Interruptions: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _modal_clock() -> void:
	var id: int = app.workspace.active_id
	var view := app.current_view as TabletopCardTableView
	var original: Dictionary = app.workspace.snapshot(id)
	var archive: Dictionary = app.workspace.export_replay(id)
	var token: int = app.workspace.frame(id).token
	_check(view.busy, "Opening view starts a real sequential deal")
	_focus(false)
	_check(view.blocked and not view.busy and not view.hand.input_enabled, "Focus loss finishes motion and disables input")
	_check(app.workspace.frame(id).token > token and app.workspace.snapshot(id) == original and app.workspace.export_replay(id) == archive, "Interruption invalidates UI lease without changing rules/history")
	_focus(true)
	_check(not view.blocked and view.hand.get_card_count() == 17, "Focus return presents the completed hand without redealing")
	root.focus_exited.emit()
	_check(view.suspended, "Main-window focus independently suspends interaction")
	root.focus_entered.emit()
	_check(not view.suspended, "Main-window focus independently releases its own suspension")
	view.clock.remaining = 0.02
	var ticket: int = view.frame_token
	_key(KEY_S)
	_check(app.save_dialog.visible and view.suspended, "Save shortcut opens a suspending dialog")
	var remaining := view.clock.remaining
	await create_timer(0.08).timeout
	_check(app.workspace.frame(id).cursor == 0 and view.clock.remaining == remaining, "An open file dialog cannot consume time or append a timeout bid")
	_check(view.cues._players.music.stream_paused, "Dialog suspends the background stream")
	_focus(false)
	app.save_dialog.hide()
	_check(view.blocked and view.clock.suspended, "Closing a dialog cannot resume an unfocused window")
	_focus(true)
	_check(not view.blocked and view.clock.remaining == remaining and not app.workspace.frame(id).paused, "Resume retains remaining time without changing user pause state")
	app._on_view_command({"type": "bid", "value": 3}, ticket, id)
	_check(app.workspace.frame(id).cursor == 0, "Pre-dialog command lease remains stale after resume")
	await create_timer(0.06).timeout
	_check(app.workspace.frame(id).cursor == 1 and app.workspace.snapshot(id).bids[0] == 0, "The suspended legal timeout resumes with its remaining time")
	app._restart()
	view.skip_animation()
	app._toggle_pause()
	_focus(false)
	app.load_dialog.popup_centered_ratio(0.8)
	_focus(true)
	_check(view.blocked, "Focus return cannot bypass an open modal")
	app.load_dialog.hide()
	_check(app.workspace.frame(id).paused and view.blocked and not view.clock.running, "Modal/focus resume preserves explicit user pause")
	app._toggle_pause()
	view.set_reduced_motion(true)
	view.activate("bid_3")
	app._on_seek(0)
	_key(KEY_O)
	_focus(false)
	app.load_dialog.hide()
	_focus(true)
	view.clock.remaining = 0.01
	await create_timer(0.04).timeout
	_check(not view.clock.running and app.workspace.frame(id).cursor == 0, "Interruptions cannot arm a historical clock")

func _moving_gestures() -> void:
	var id: int = app.workspace.active_id
	var view := app.current_view as TabletopCardTableView
	app._restart()
	view.set_reduced_motion(true)
	view.activate("bid_3")
	view.set_reduced_motion(false)
	await create_timer(0.18).timeout
	var heard: Array[String] = []
	view.cues.cue_started.connect(func(cue: String) -> void: heard.append(cue))
	var keys := PackedStringArray()
	for i in [0, 4, 8]:
		var card: Card = view.hand._held_cards[i]
		keys.append(card.card_name)
		_click(_card_point(card))
		await create_timer(0.02).timeout
	_check(view.hand.selected_keys.size() == keys.size() and Array(keys).all(func(key: String) -> bool: return view.hand.selected_keys.has(key)), "Rapid clicks remain accurate while hover/selection poses animate")
	var card: Card = view.hand._held_cards[8]
	var point := _card_point(card)
	_touch(point, true, 7)
	_touch_move(point - Vector2(0, 45), 7)
	_check(view.hand._pointer == 7 and view._drag_ghost.visible, "A touch owns the animated selected-group preview")
	_touch(_card_point(view.hand._held_cards[4]), true, 8)
	_touch_move(Vector2(10, 10), 8)
	_touch(Vector2(10, 10), false, 8, true)
	_check(view.hand._pointer == 7 and view.hand.selected_keys.size() == keys.size(), "Secondary touch/cancellation cannot take over the owning gesture")
	var target := view._drop_hint.get_global_rect().get_center()
	_touch_move(target, 7)
	var ticket: int = view.frame_token
	_focus(false)
	_check(view.hand._pointer == -1 and not view._drag_ghost.visible and not view._drop_hint.visible, "Focus loss cancels touch and its drop overlays")
	_check(view.hand.selected_keys.size() == keys.size(), "Focus cancellation preserves the pre-gesture selection")
	var remaining := view.clock.remaining
	await create_timer(0.08).timeout
	_check(view.clock.remaining == remaining, "Unfocused window freezes an armed clock")
	_focus(true)
	_touch(target, false, 7)
	_check(app.workspace.frame(id).cursor == 1 and view.frame_token != ticket, "Late touch release cannot commit after focus returns")
	_check(heard.is_empty() and not view.cues._players.voice.playing, "Focus return never replays old announcements")
	view.hand.clear_selection()
	_click(view.action_buttons.browse.get_global_rect().get_center())
	var chosen: Card
	for item in view.hand._held_cards:
		if view.hand.selected_keys.has(item.card_name):
			chosen = item
	assert(chosen != null)
	point = _card_point(chosen)
	_mouse(point, true)
	_motion(point - Vector2(0, 45), true)
	target = view._drop_hint.get_global_rect().get_center()
	_motion(target, true)
	_mouse(target, false)
	_check(app.workspace.frame(id).cursor == 2 and view.busy, "Motion-enabled legal drop commits and animates once")
	var played: Dictionary = app.workspace.snapshot(id)
	var archived: Dictionary = app.workspace.export_replay(id)
	_key(KEY_S)
	_check(app.save_dialog.visible and not view.busy and view._motion_layer.get_child_count() == 0, "Opening a dialog cancels in-flight play motion")
	_check(not view.cues._players.voice.playing and not view.cues._players.effect.playing and view.cues._players.music.stream_paused, "Dialog stops foreground queues and suspends music")
	var count := heard.size()
	app.save_dialog.hide()
	await create_timer(0.35).timeout
	_check(app.workspace.snapshot(id) == played and app.workspace.export_replay(id) == archived and heard.size() == count, "Canceled motion/audio callbacks cannot replay or mutate the accepted move")

func _snapshot_and_board() -> void:
	var card_id: int = app.workspace.active_id
	var frozen: Dictionary = app.workspace.export_replay(card_id)
	_key(KEY_S)
	_check(app.save_dialog.visible, "Snapshot save opens through the normal shortcut")
	app.workspace.close_table(card_id)
	var board_id: int = app.workspace.create_table("gomoku", 7)
	await _frames()
	var board_view := app.current_view as TabletopPlacementBoardView
	_check(board_view.suspended and board_view.board.blocked, "A newly mounted board inherits the open modal boundary")
	board_view.board.cell_activated.emit(112)
	_check(app.workspace.snapshot(board_id).moves == 0, "Queued board input cannot bypass the modal host boundary")
	var path := "user://interruption-replay.json"
	app.save_dialog.file_selected.emit(path)
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(saved == JSON.parse_string(JSON.stringify(frozen)), "Save writes the captured replay after its original table closes")
	app.save_dialog.hide()
	await _frames()
	var point := board_view.board.get_global_transform_with_canvas() * board_view.board.cell_position(112)
	_click(point)
	_check(app.workspace.snapshot(board_id).moves == 1, "Actual board pointer input resumes after the modal closes")
	var ticket: int = board_view.frame_token
	_focus(false)
	point = board_view.board.get_global_transform_with_canvas() * board_view.board.cell_position(113)
	_click(point)
	_check(app.workspace.snapshot(board_id).moves == 1 and board_view.board.blocked, "Window focus boundary also blocks actual board input")
	_focus(true)
	app._on_view_command({"type": "place", "cell": 113}, ticket, board_id)
	_check(app.workspace.snapshot(board_id).moves == 1, "Pre-interruption board callbacks remain stale")
	_click(point)
	_check(app.workspace.snapshot(board_id).moves == 2, "Board interaction recovers after focus return")
	_key(KEY_Z)
	_check(app.workspace.snapshot(board_id).moves == 1, "Common undo shortcut recovers with the focused board")
	app._toggle_pause()
	_key(KEY_O)
	_check(app.load_dialog.visible, "Load dialog remains available while a table is explicitly paused")
	app.load_dialog.file_selected.emit(path)
	await _frames()
	var imported_id: int = app.workspace.active_id
	var imported := app.current_view as TabletopCardTableView
	_check(imported_id != board_id and imported.suspended and not imported.hand.input_enabled, "Imported card view inherits the still-open dialog")
	app.load_dialog.hide()
	imported.clock.remaining = 0.01
	await create_timer(0.04).timeout
	_check(not imported.blocked and not imported.clock.running and app.workspace.frame(imported_id).cursor == frozen.commands.size(), "Closing load does not auto-play an imported replay")
	_check(app.workspace.frame(board_id).paused, "Import never resumes the previous user's paused table")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
