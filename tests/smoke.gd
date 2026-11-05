extends SceneTree

const APP = preload("res://ui/tabletop_app.tscn")
const Catalog = preload("res://core/game_catalog.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _frames() -> void:
	await process_frame
	await process_frame
	await process_frame

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var app := APP.instantiate()
	root.add_child(app)
	current_scene = app
	await _frames()
	var id: int = app.workspace.active_id
	var view = app.current_view
	_check(view.hand.get_card_count() == 17, "Card module mounted through catalog")
	_check(view is TabletopCardTableView and view.configuration is TabletopCardTableLayout, "Card module uses configured family renderer")
	_check(view.hand.cards_node.get_child(0).card_info.face_texture.get_width() > 0, "Configured card artwork imported, including in PCK")
	_check(view.configuration.media.cues.size() > 0 and view.configuration.media.cues[0].stream.get_length() > 0, "Configured audio imported, including in PCK")
	view.activate("bid_3")
	await _frames()
	_check(view.hand.get_card_count() == 20, "Bidding uses client command path")
	var before: Dictionary = app.workspace.snapshot(id)
	view.activate("browse")
	_check(not view.hand.selected_keys.is_empty() and not view.action_buttons.play.disabled, "Cycle selects legal play")
	_check(app.workspace.snapshot(id) == before, "Cycling does not mutate game")
	app._restart()
	view.activate("bid_3")
	await _frames()
	var card: Card = view.hand.cards_node.get_child(0)
	card.change_state(DraggableObject.DraggableState.IDLE)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	card.gui_input.emit(mouse)
	_check(view.hand.selected_keys.size() == 1, "Card mouse signal selects")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	card.gui_input.emit(touch)
	_check(view.hand.selected_keys.is_empty(), "Card touch signal toggles selection once")
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	card.gui_input.emit(mouse)
	_check(view.hand.selected_keys.is_empty(), "Touch emulated mouse cannot toggle card twice")
	mouse.device = 0
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_SPACE
	card.gui_input.emit(key)
	_check(view.hand.selected_keys.size() == 1, "Card keyboard signal selects")
	view.activate("play")
	await _frames()
	_check(app.workspace.frame(id).cursor == 2 and app.workspace.snapshot(id).hands[0].size() == 19, "Selected card goes through client authority")
	var scope = view.manager.input_scope
	var hovered: Card = view.hand.cards_node.get_child(0)
	hovered.change_state(DraggableObject.DraggableState.IDLE)
	hovered.change_state(DraggableObject.DraggableState.HOVERING)
	var independent = Catalog.module_for("doudizhu").create_view()
	root.add_child(independent)
	var isolated := TabletopLocalTable.new(Catalog.module_for("doudizhu"), 123)
	independent.present(isolated.frame())
	await _frames()
	var second: Card = independent.hand.cards_node.get_child(0)
	second.change_state(DraggableObject.DraggableState.IDLE)
	second.change_state(DraggableObject.DraggableState.HOVERING)
	_check(scope.hovered == hovered and independent.manager.input_scope.hovered == second, "Two real views have independent hover ownership")
	_check(not app.has_meta("card_manager"), "Managers do not register a global scene owner")
	independent.deactivate()
	independent.queue_free()
	await _frames()
	_check(scope.hovered == hovered, "Destroying second view preserves first input scope")
	app.game_picker.select(1)
	app._new_table()
	await _frames()
	_check(scope.hovered == null and Card.hovering_card_count == 0, "Switch releases detached card input")
	var board_view = app.current_view
	var board_id: int = app.workspace.active_id
	var board: TabletopBoardCanvas = board_view.board
	_check(board.columns == 15 and board.rows == 15, "Playable board module mounted")
	_check(board_view is TabletopPlacementBoardView and board_view.configuration is TabletopBoardLayout, "Board module uses separate configured renderer")
	app._toggle_sound()
	_check(app.current_view.cues.muted, "Common sound control mutes active view")
	mouse.position = board.cell_position(112)
	board._gui_input(mouse)
	_check(app.workspace.snapshot(board_id).board[112] == 0, "Board mouse hit maps to cell command")
	touch.position = board.cell_position(113)
	board._gui_input(touch)
	_check(app.workspace.snapshot(board_id).board[113] == 1, "Board touch maps to cell command")
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.position = board.cell_position(114)
	board._gui_input(mouse)
	_check(app.workspace.snapshot(board_id).moves == 2, "Emulated mouse cannot duplicate a board touch")
	mouse.device = 0
	key.keycode = KEY_DOWN
	board._gui_input(key)
	key.keycode = KEY_ENTER
	board._gui_input(key)
	_check(app.workspace.snapshot(board_id).board[128] == 0, "Board keyboard navigation and enter")
	board.grab_focus()
	key.keycode = KEY_Z
	key.ctrl_pressed = true
	root.push_input(key)
	await _frames()
	_check(app.workspace.snapshot(board_id).moves == 2, "Focused board passes common undo shortcut")
	key.keycode = KEY_Y
	root.push_input(key)
	await _frames()
	_check(app.workspace.snapshot(board_id).moves == 3, "Focused board passes common redo shortcut")
	key.ctrl_pressed = false
	app._on_seek(0)
	_check(app.workspace.snapshot(board_id).moves == 0 and app.history_label.text == "Move 0 / 3", "Common replay slider")
	app._save_table_id = board_id
	app._save_file("user://client-scene-replay.json")
	app._load_file("user://client-scene-replay.json")
	await _frames()
	_check(app.workspace.active_id != board_id and app.workspace.snapshot(app.workspace.active_id).moves == 3, "Real replay file loads a new table at end")
	var imported_id: int = app.workspace.active_id
	var old_token: int = app.workspace.frame(imported_id).token
	# Inject touch through the real Input router so stock toolbar buttons are covered.
	touch.position = app.pause_button.get_global_rect().get_center()
	Input.parse_input_event(touch)
	await _frames()
	touch.pressed = false
	Input.parse_input_event(touch)
	await _frames()
	_check(app.pause_mask.visible, "Touch activates stock client toolbar")
	_check(app.pause_mask.visible, "Common pause overlay")
	app.current_view.board._gui_input(mouse)
	_check(app.workspace.snapshot(imported_id).moves == 3, "Paused board input blocked")
	app._on_view_command({"type":"place","cell":114}, old_token, imported_id)
	_check(app.status_label.text.contains("stale client frame"), "Queued view event rejected after pause")
	app._toggle_pause()
	root.size = Vector2i(800, 600)
	await _frames()
	_check(app.game_picker.get_global_rect().end.x <= app.size.x, "Header fits smaller window")
	_check(app.current_view.board.cell_at(Vector2(-100,-100)) == -1, "Off-board pointer rejected")
	for cell in [0,14,112,210,224]:
		_check(app.current_view.board.cell_at(app.current_view.board.cell_position(cell)) == cell, "Resize retains intersection mapping")
	app.workspace.select_table(id)
	await _frames()
	_check(app.current_view.hand.get_card_count() == 17 and app.workspace.frame(id).cursor == 2, "Switch restores card table progress")
	_check(app.current_view.cues.muted, "Sound setting persists across game families")
	for card_node in app.current_view.hand.cards_node.get_children():
		_check(card_node.global_position.x >= 0 and card_node.global_position.x + card_node.card_size.x <= app.size.x, "Hand fits smaller window")
	while app.workspace.active_id != -1:
		app._close()
	await _frames()
	_check(app.current_view == null and app.undo_button.disabled, "All tables can be closed")
	app._new_table()
	await _frames()
	_check(app.current_view != null, "Create after all closed")
	app.queue_free()
	await _frames()
	_check(Card.hovering_card_count == 0 and Card.holding_card_count == 0, "Client shutdown releases shared upstream counters")
	print("UI client: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
