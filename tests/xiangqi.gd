extends SceneTree
## Rule boundaries and actual input dispatch through the configured client.

const APP = preload("res://ui/tabletop_app.tscn")
const Piece = XiangqiRules.Piece
const QUIET_CYCLE := [Vector2i(82, 65), Vector2i(1, 20), Vector2i(65, 82), Vector2i(20, 1)]
var rules := XiangqiRules.new()
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_opening()
	_pieces()
	_outcomes()
	await _client()
	print("Xiangqi: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _move(origin: int, destination: int) -> Dictionary:
	return {"type": "move", "from": origin, "to": destination}

func _position(pieces: Dictionary) -> Dictionary:
	var state := rules.initial_state(0)
	state.board.fill(Piece.EMPTY)
	state.board[4] = -Piece.GENERAL
	state.board[85] = Piece.GENERAL
	for cell in pieces:
		state.board[cell] = pieces[cell]
	state.position_history[0].key = rules._position_key(state.board, 0)
	return state

func _opening() -> void:
	var session := TabletopSession.new(rules, 42)
	var opening := session.authoritative_snapshot()
	var actions := session.legal_actions(0)
	_check(opening.board.count(0) == 58 and opening.turn == 0, "Standard 32-piece opening, red moves first")
	_check(actions.size() == 44 and session.legal_actions(1).is_empty(), "Opening legal move count and turn scope")
	var replies := 0
	for action in actions:
		var result := rules.apply(opening, 0, action.command)
		_check(result.ok, "Enumerated opening command is accepted")
		if result.ok:
			replies += rules.legal_actions(result.state, 1).size()
	_check(replies == 1920, "Independent Xiangqi opening positions at depth two")
	_check(session.submit_action(0, "move:54:45", 0).ok, "Move through stable legal action ID")
	var before := session.authoritative_snapshot()
	for command in [_move(27, 90), _move(27, 37), _move(27, 27), _move(45, 36),
			{"type": "move", "from": 27.25, "to": 36}, {"type": "move", "from": 27, "to": true}, {"type": "move"}]:
		_check(not session.submit(1, command, 1).ok, "Illegal or malformed move is rejected")
		_check(session.authoritative_snapshot() == before and session.revision == 1, "Rejection preserves board and revision")
	_check(session.submit(0, _move(54, 45), 1).error == "wrong_turn", "Seat authority rejects out-of-turn move")
	var observation := session.observe(1)
	observation.board[36] = Piece.ROOK
	_check(session.authoritative_snapshot() == before and not observation.has("position_history"), "Observation owns detached board values")

func _pieces() -> void:
	var clear := _position({58: Piece.PAWN, 83: Piece.ELEPHANT, 84: Piece.ADVISOR, 82: Piece.HORSE})
	_check(rules.apply(clear, 0, _move(85, 76)).ok, "General moves one orthogonal step within palace")
	_check(not rules.apply(clear, 0, _move(85, 75)).ok, "General cannot move diagonally")
	_check(rules.apply(clear, 0, _move(84, 76)).ok and not rules.apply(clear, 0, _move(84, 75)).ok, "Advisor moves along palace diagonals")
	_check(rules.apply(clear, 0, _move(83, 63)).ok, "Elephant moves exactly two diagonally")
	_check(rules.apply(clear, 0, _move(82, 65)).ok, "Horse moves when its leg is clear")
	var blocked := _position({58: Piece.PAWN, 83: Piece.ELEPHANT, 82: Piece.HORSE, 73: -Piece.PAWN})
	_check(not rules.apply(blocked, 0, _move(83, 63)).ok, "Elephant eye can be blocked by an enemy piece")
	_check(not rules.apply(blocked, 0, _move(82, 65)).ok, "Horse leg can be blocked by an enemy piece")
	var river := _position({58: Piece.PAWN, 47: Piece.ELEPHANT, 46: Piece.PAWN, 39: Piece.PAWN, 55: Piece.PAWN, 67: Piece.ADVISOR})
	_check(not rules.apply(river, 0, _move(47, 63)).ok, "Elephant eye can be blocked by a friendly piece")
	_check(not rules.apply(river, 0, _move(47, 27)).ok, "Elephant cannot cross the river")
	_check(not rules.apply(river, 0, _move(46, 45)).ok and rules.apply(river, 0, _move(46, 37)).ok, "Soldier advances straight before crossing")
	_check(rules.apply(river, 0, _move(39, 40)).ok and not rules.apply(river, 0, _move(39, 48)).ok, "Crossed soldier can move sideways but not backward")
	_check(rules.apply(river, 0, _move(67, 75)).ok and not rules.apply(river, 0, _move(67, 57)).ok, "Palace boundary constrains advisor")
	var cannon := _position({58: Piece.PAWN, 55: Piece.CANNON, 37: Piece.PAWN, 10: -Piece.ROOK})
	_check(rules.apply(cannon, 0, _move(55, 46)).ok and not rules.apply(cannon, 0, _move(55, 28)).ok, "Cannon cannot jump into an empty square")
	var capture := rules.apply(cannon, 0, _move(55, 10))
	_check(capture.ok and capture.events[0].captured == -Piece.ROOK and capture.state.board[10] == Piece.CANNON, "Cannon captures over one screen")
	cannon.board[28] = -Piece.PAWN
	_check(not rules.apply(cannon, 0, _move(55, 10)).ok, "Cannon cannot capture across two screens")
	cannon.board[28] = Piece.EMPTY
	cannon.board[37] = Piece.EMPTY
	_check(not rules.apply(cannon, 0, _move(55, 10)).ok, "Cannon cannot capture without a screen")
	var facing := _position({40: Piece.PAWN})
	_check(not rules.apply(facing, 0, _move(40, 39)).ok and rules.apply(facing, 0, _move(40, 31)).ok, "A move cannot reveal facing generals")
	var checked := _position({13: -Piece.ROOK, 81: Piece.ROOK})
	_check(not rules.apply(checked, 0, _move(81, 72)).ok and rules.apply(checked, 0, _move(85, 84)).ok, "Move must resolve check")

func _outcomes() -> void:
	# Two horses control the side exits. The soldier controls the forward exit.
	var mate := _position({20: Piece.HORSE, 24: Piece.HORSE, 22: Piece.PAWN, 9: Piece.ROOK})
	var result := rules.apply(mate, 0, _move(9, 13))
	_check(result.ok and result.state.outcome == "checkmate" and result.state.winner == 0 and result.state.check_cell == 4, "Checkmate ends with mover winning")
	_check(rules.legal_actions(result.state, 1).is_empty() and not rules.apply(result.state, 1, _move(4, 3)).ok, "Mate closes legal commands")
	var stalemate := _position({20: Piece.HORSE, 24: Piece.HORSE, 22: Piece.PAWN, 27: Piece.ROOK})
	result = rules.apply(stalemate, 0, _move(27, 36))
	_check(result.ok and result.state.outcome == "stalemate" and result.state.winner == 0 and result.state.check_cell == -1, "Stalemated side loses")
	var checks_position := _position({12: Piece.ROOK, 58: Piece.PAWN})
	for _cycle in range(2):
		for step in [Vector2i(12, 13), Vector2i(4, 3), Vector2i(13, 12), Vector2i(3, 4)]:
			result = rules.apply(checks_position, checks_position.turn, _move(step.x, step.y))
			_check(result.ok, "Perpetual-check sequence is legal until adjudication")
			checks_position = result.state
	_check(checks_position.outcome == "perpetual_check" and checks_position.winner == 1, "Only side giving continuous check loses on third occurrence")

func _frames() -> void:
	for _index in range(3):
		await process_frame

func _point(board: TabletopBoardCanvas, cell: int) -> Vector2:
	return board.get_global_transform_with_canvas() * board.cell_position(cell)

func _click(board: TabletopBoardCanvas, cell: int, button: MouseButton = MOUSE_BUTTON_LEFT, device: int = 0) -> void:
	var event := InputEventMouseButton.new()
	event.position = _point(board, cell)
	event.global_position = event.position
	event.button_index = button
	event.device = device
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)

func _client() -> void:
	root.size = Vector2i(1280, 800)
	var app := APP.instantiate()
	root.add_child(app)
	current_scene = app
	await _frames()
	app._toggle_motion()
	var card_id: int = app.workspace.active_id
	var card_state: Dictionary = app.workspace.snapshot(card_id)
	for index in range(app.game_picker.item_count):
		if app.game_picker.get_item_metadata(index) == "xiangqi":
			app.game_picker.select(index)
	app._new_table()
	await _frames()
	var id: int = app.workspace.active_id
	var view := app.current_view as TabletopMoveBoardView
	var board := view.board
	_check(view.client_frame.game_id == "xiangqi" and board.pieces.size() == 32 and board.split_after_row == 4, "Game picker mounts the configured Xiangqi board")
	_check(board.guide_lines.size() == 4 and board.board_font.has_char(0x5e25) and board.board_font.has_char(0x754c), "Palaces and packaged CJK glyphs load")
	var sound: Array[String] = []
	view.cues.cue_started.connect(func(cue: String) -> void: sound.append(cue))
	_click(board, 4)
	_check(board.selected_cell == -1, "Opponent piece does not select")
	_click(board, 64)
	_check(board.selected_cell == 64 and board.move_targets.has(1), "Cannon selection shows legal capture")
	_click(board, 74)
	_check(board.selected_cell == 64 and app.workspace.frame(id).cursor == 0, "Illegal destination preserves the selection and history")
	_click(board, 64, MOUSE_BUTTON_RIGHT)
	_check(board.selected_cell == -1 and board.move_targets.is_empty(), "Right-click clears selected origin and targets")
	_click(board, 54)
	_key(KEY_ESCAPE)
	_check(board.selected_cell == -1, "Escape clears selection from focused board")
	var touch := InputEventScreenTouch.new()
	touch.position = _point(board, 54)
	touch.pressed = true
	root.push_input(touch, true)
	touch.pressed = false
	root.push_input(touch, true)
	_click(board, 54, MOUSE_BUTTON_LEFT, InputEvent.DEVICE_ID_EMULATION)
	_check(board.selected_cell == 54 and board.move_targets == PackedInt32Array([45]), "Touch and synthetic mouse select only once")
	_click(board, 45)
	_check(app.workspace.frame(id).cursor == 1 and board.last_origin == 54 and board.last_cell == 45, "Click submits the complete move and marks both ends")
	_check(view.status.text == "Black to move" and sound == ["piece"], "Accepted move advances turn and plays a cue once")
	await create_timer(0.2).timeout
	_click(board, 1)
	_key(KEY_RIGHT)
	_key(KEY_DOWN)
	_key(KEY_DOWN)
	_key(KEY_ENTER)
	var after: Dictionary = app.workspace.snapshot(id)
	_check(after.moves == 2 and after.board[20] == -Piece.HORSE, "Keyboard selects a legal destination")
	await create_timer(0.2).timeout
	_click(board, 56)
	app._toggle_pause()
	_check(board.blocked and board.selected_cell == -1, "Pause cancels pending move selection")
	_click(board, 47)
	_check(app.workspace.snapshot(id) == after, "Paused input cannot move a piece")
	app._toggle_pause()
	app._undo()
	_check(app.workspace.snapshot(id).moves == 1 and board.last_cell == 45, "Undo restores exact move marker")
	app._redo()
	_check(app.workspace.snapshot(id) == after and sound.size() == 2, "Redo restores exact board and suppresses historical sound")
	var replay: Dictionary = app.workspace.load_replay(JSON.stringify(app.workspace.export_replay(id)))
	_check(replay.ok and replay.table_id != id and app.workspace.snapshot(replay.table_id) == after, "JSON replay restores an independent Xiangqi table")
	_check(app.workspace.snapshot(card_id) == card_state, "The card table retains its state during board play")
	app._toggle_sound()
	app.workspace.select_table(id)
	app._restart()
	await _frames()
	view = app.current_view as TabletopMoveBoardView
	board = view.board
	root.size = Vector2i(800, 600)
	await _frames()
	for cell in [0, 8, 40, 49, 81, 89]:
		_check(board.cell_at(board.cell_position(cell)) == cell, "Compact rectangular grid hits the same intersections")
	for _cycle in range(2):
		for step in QUIET_CYCLE:
			_click(board, step.x)
			_click(board, step.y)
			await _frames()
	var finished: Dictionary = app.workspace.snapshot(id)
	_check(finished.moves == 8 and finished.outcome == "repetition" and finished.winner == -1, "A complete repeated game ends in a draw")
	_check(board.blocked and view.status.text == "Draw" and view.detail.text.contains("Threefold repetition"), "Actual settlement view locks moves and displays result")
	_click(board, 54)
	_click(board, 45)
	_check(app.workspace.snapshot(id) == finished, "Finished view cannot continue playing")
	var completed: Dictionary = app.workspace.load_replay(JSON.stringify(app.workspace.export_replay(id)))
	_check(completed.ok and app.workspace.snapshot(completed.table_id) == finished, "Terminal result survives full replay")
	app.queue_free()
	await _frames()
