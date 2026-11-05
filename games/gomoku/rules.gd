class_name GomokuRules
extends TabletopRules
## Freestyle 15x15: five or more connected stones win; no forbidden moves.

const SIZE := 15
const DIRECTIONS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]

func game_id() -> String:
	return "gomoku"

func rules_revision() -> String:
	return "gomoku-freestyle-15-v1"

func active_seat(state: Dictionary) -> int:
	return int(state.turn)

func initial_state(_seed: int) -> Dictionary:
	var board: Array = []
	board.resize(SIZE * SIZE)
	board.fill(-1)
	return {"phase": "playing", "turn": 0, "board": board,
			"moves": 0, "last_cell": -1, "winner": -1, "winning_cells": []}

func apply(state: Dictionary, seat: int, command: Dictionary) -> Dictionary:
	if state.phase == "finished":
		return {"ok": false, "error": "game_finished"}
	if seat != state.turn:
		return {"ok": false, "error": "wrong_turn"}
	if not command.has("type") or command.type != "place" or not command.has("cell") \
			or not typeof(command.cell) in [TYPE_INT, TYPE_FLOAT] or command.cell != int(command.cell) \
			or command.cell < 0 or command.cell >= SIZE * SIZE:
		return {"ok": false, "error": "invalid_placement"}
	var cell := int(command.cell)
	if state.board[cell] != -1:
		return {"ok": false, "error": "occupied"}
	var next := state.duplicate(true)
	next.board[cell] = seat
	next.moves += 1
	next.last_cell = cell
	var events: Array = [{"type": "placed", "seat": seat, "cell": cell}]
	for direction in DIRECTIONS:
		var line := _line(next.board, cell, seat, direction)
		if line.size() >= 5:
			next.winner = seat
			next.winning_cells = line
			break
	if next.winner != -1 or next.moves == SIZE * SIZE:
		next.phase = "finished"
		events.append({"type": "finished", "winner": next.winner})
	else:
		next.turn = 1 - seat
	return {"ok": true, "state": next, "events": events}

func _line(board: Array, cell: int, seat: int, direction: Vector2i) -> Array:
	var origin := Vector2i(cell % SIZE, cell / SIZE)
	var line: Array = [cell]
	for sign_value in [-1, 1]:
		var point: Vector2i = origin + direction * sign_value
		while point.x >= 0 and point.x < SIZE and point.y >= 0 and point.y < SIZE:
			var index := point.y * SIZE + point.x
			if board[index] != seat:
				break
			line.append(index)
			point += direction * sign_value
	line.sort()
	return line

func observe(state: Dictionary, _seat: int) -> Dictionary:
	return state.duplicate(true)

func legal_actions(state: Dictionary, seat: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state.phase != "playing" or seat != state.turn:
		return result
	for cell in range(SIZE * SIZE):
		if state.board[cell] == -1:
			result.append({"id": "place:%d" % cell, "command": {"type": "place", "cell": cell}})
	return result
