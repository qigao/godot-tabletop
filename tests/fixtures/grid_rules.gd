extends TabletopRules
## A board-game contract fixture; it is not a second shipped game.

func game_id() -> String:
	return "grid-fixture"

func rules_revision() -> String:
	return "grid-v1"

func active_seat(state: Dictionary) -> int:
	return int(state.turn)

func initial_state(_seed_value: int) -> Dictionary:
	return {"turn": 0, "cells": [-1, -1, -1, -1, -1, -1, -1, -1, -1]}

func apply(state: Dictionary, seat: int, command: Dictionary) -> Dictionary:
	if seat != state.turn:
		return {"ok": false, "error": "wrong_turn"}
	if command.type != "place" or command.cell < 0 or command.cell > 8:
		return {"ok": false, "error": "invalid_placement"}
	if state.cells[command.cell] != -1:
		return {"ok": false, "error": "occupied"}
	var next := state.duplicate(true)
	next.cells[command.cell] = seat
	next.turn = 1 - seat
	return {"ok": true, "state": next, "events": [{"type": "placed", "seat": seat, "cell": command.cell}]}

func observe(state: Dictionary, _seat: int) -> Dictionary:
	return state.duplicate(true)

func legal_actions(state: Dictionary, seat: int) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if seat == state.turn:
		for cell in range(9):
			if state.cells[cell] == -1:
				actions.append({"id": "place:%d" % cell, "command": {"type": "place", "cell": cell}})
	return actions
