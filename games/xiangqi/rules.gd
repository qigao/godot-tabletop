class_name XiangqiRules
extends TabletopRules
## Local Chinese chess. The board stores signed piece kinds; red moves first.

enum Piece { EMPTY, GENERAL, ADVISOR, ELEPHANT, HORSE, ROOK, CANNON, PAWN }

const COLUMNS := 9
const ROWS := 10
const BACK_RANK := [Piece.ROOK, Piece.HORSE, Piece.ELEPHANT, Piece.ADVISOR, Piece.GENERAL,
		Piece.ADVISOR, Piece.ELEPHANT, Piece.HORSE, Piece.ROOK]

func game_id() -> String:
	return "xiangqi"

func rules_revision() -> String:
	return "xiangqi-local-v1"

func active_seat(state: Dictionary) -> int:
	return state.turn

func initial_state(_seed: int) -> Dictionary:
	var board: Array[int] = []
	board.resize(COLUMNS * ROWS)
	board.fill(Piece.EMPTY)
	for column in range(COLUMNS):
		board[column] = -BACK_RANK[column]
		board[(ROWS - 1) * COLUMNS + column] = BACK_RANK[column]
	for column in [1, 7]:
		board[2 * COLUMNS + column] = -Piece.CANNON
		board[7 * COLUMNS + column] = Piece.CANNON
	for column in range(0, COLUMNS, 2):
		board[3 * COLUMNS + column] = -Piece.PAWN
		board[6 * COLUMNS + column] = Piece.PAWN
	return {"phase": "playing", "turn": 0, "board": board, "moves": 0,
			"last_from": -1, "last_to": -1, "check_cell": -1, "winner": -1, "outcome": "",
			"position_history": [{"key": _position_key(board, 0), "seat": -1, "check": false}]}

func apply(state: Dictionary, seat: int, command: Dictionary) -> Dictionary:
	if state.phase == "finished":
		return {"ok": false, "error": "game_finished"}
	if seat != state.turn:
		return {"ok": false, "error": "wrong_turn"}
	if command.get("type") != "move" or not _valid_cell(command.get("from")) or not _valid_cell(command.get("to")):
		return {"ok": false, "error": "invalid_move"}
	var origin := int(command["from"])
	var destination := int(command["to"])
	var side := 1 if seat == 0 else -1
	var board: Array = state.board.duplicate()
	var general := board.find(side * Piece.GENERAL)
	if board[origin] * side <= 0 or not _legal_move(board, origin, destination, side, general):
		return {"ok": false, "error": "illegal_move"}
	var moved: int = board[origin]
	var captured: int = board[destination]
	board[origin] = Piece.EMPTY
	board[destination] = moved
	var next := state.duplicate(true)
	next.board = board
	next.turn = 1 - seat
	next.moves += 1
	next.last_from = origin
	next.last_to = destination
	var opponent_general := board.find(-side * Piece.GENERAL)
	var gives_check := _in_check(board, opponent_general, -side)
	next.check_cell = opponent_general if gives_check else -1
	var events: Array = [{"type": "moved", "seat": seat, "from": origin, "to": destination,
			"piece": moved, "captured": captured}]
	if gives_check:
		events.append({"type": "check", "seat": next.turn, "cell": opponent_general})
	if _moves(board, next.turn, true).is_empty():
		_finish(next, events, seat, "checkmate" if gives_check else "stalemate")
	else:
		_adjudicate_repetition(next, events, seat, gives_check)
	return {"ok": true, "state": next, "events": events}

func observe(state: Dictionary, _seat: int) -> Dictionary:
	var view := state.duplicate()
	view.erase("position_history")
	view.board = state.board.duplicate()
	return view

func legal_actions(state: Dictionary, seat: int) -> Array[Dictionary]:
	if state.phase != "playing" or seat != state.turn:
		return []
	return _moves(state.board.duplicate(), seat, false)

func _moves(board: Array, seat: int, first_only: bool) -> Array[Dictionary]:
	var side := 1 if seat == 0 else -1
	var general := board.find(side * Piece.GENERAL)
	var result: Array[Dictionary] = []
	for origin in range(board.size()):
		if board[origin] * side <= 0:
			continue
		for destination in range(board.size()):
			if _legal_move(board, origin, destination, side, general):
				result.append({"id": "move:%d:%d" % [origin, destination],
						"command": {"type": "move", "from": origin, "to": destination}})
				if first_only:
					return result
	return result

func _legal_move(board: Array, origin: int, destination: int, side: int, general: int) -> bool:
	var target: int = board[destination]
	if origin == destination or target * side > 0 or target == -side * Piece.GENERAL \
			or not _reaches(board, origin, destination, side):
		return false
	var piece: int = board[origin]
	board[origin] = Piece.EMPTY
	board[destination] = piece
	var safe := not _in_check(board, destination if origin == general else general, side)
	board[origin] = piece
	board[destination] = target
	return safe

func _in_check(board: Array, general: int, side: int) -> bool:
	assert(general >= 0 and board[general] == side * Piece.GENERAL)
	for origin in range(board.size()):
		if board[origin] * side < 0 and _reaches(board, origin, general, -side):
			return true
	return false

func _reaches(board: Array, origin: int, destination: int, side: int) -> bool:
	var point := Vector2i(origin % COLUMNS, origin / COLUMNS)
	var target := Vector2i(destination % COLUMNS, destination / COLUMNS)
	var delta := target - point
	var distance := delta.abs()
	var straight := delta.x == 0 or delta.y == 0
	match absi(board[origin]):
		Piece.GENERAL:
			if delta.x == 0 and board[destination] == -side * Piece.GENERAL:
				return _screens_between(board, point, target) == 0
			return distance.x + distance.y == 1 and _in_palace(target, side)
		Piece.ADVISOR:
			return distance == Vector2i.ONE and _in_palace(target, side)
		Piece.ELEPHANT:
			return distance == Vector2i(2, 2) and not _across_river(target.y, side) \
					and board[origin + (delta.y / 2) * COLUMNS + delta.x / 2] == Piece.EMPTY
		Piece.HORSE:
			if distance.x == 2 and distance.y == 1:
				return board[origin + signi(delta.x)] == Piece.EMPTY
			if distance.x == 1 and distance.y == 2:
				return board[origin + signi(delta.y) * COLUMNS] == Piece.EMPTY
			return false
		Piece.ROOK:
			return straight and _screens_between(board, point, target) == 0
		Piece.CANNON:
			var screens := 0 if board[destination] == Piece.EMPTY else 1
			return straight and _screens_between(board, point, target) == screens
		Piece.PAWN:
			return delta == Vector2i(0, -side) or (_across_river(point.y, side) and distance.x == 1 and delta.y == 0)
	return false

func _in_palace(point: Vector2i, side: int) -> bool:
	return point.x >= 3 and point.x <= 5 and (point.y >= 7 if side == 1 else point.y <= 2)

func _across_river(row: int, side: int) -> bool:
	return row <= 4 if side == 1 else row >= 5

func _screens_between(board: Array, origin: Vector2i, destination: Vector2i) -> int:
	var step := (destination - origin).sign()
	var point := origin + step
	var count := 0
	while point != destination:
		if board[point.y * COLUMNS + point.x] != Piece.EMPTY:
			count += 1
		point += step
	return count

func _position_key(board: Array, turn: int) -> String:
	var key := str(turn)
	for piece: int in board:
		key += String.chr(72 + piece)
	return key

func _adjudicate_repetition(state: Dictionary, events: Array, mover: int, gives_check: bool) -> void:
	var key := _position_key(state.board, state.turn)
	var history: Array = state.position_history
	var occurrences := 0
	var cycle_start := -1
	for index in range(history.size() - 1, -1, -1):
		if history[index].key == key:
			occurrences += 1
			if occurrences == 2:
				cycle_start = index
				break
	history.append({"key": key, "seat": mover, "check": gives_check})
	if cycle_start == -1:
		return
	var checks_every_move := [true, true]
	for index in range(cycle_start + 1, history.size()):
		var entry: Dictionary = history[index]
		if not entry.check:
			checks_every_move[entry.seat] = false
	if checks_every_move[0] != checks_every_move[1]:
		_finish(state, events, 1 if checks_every_move[0] else 0, "perpetual_check")
	else:
		_finish(state, events, -1, "repetition")

func _finish(state: Dictionary, events: Array, winner: int, outcome: String) -> void:
	state.phase = "finished"
	state.winner = winner
	state.outcome = outcome
	events.append({"type": "finished", "winner": winner, "outcome": outcome})

func _valid_cell(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and value >= 0 and value < COLUMNS * ROWS and value == int(value)
