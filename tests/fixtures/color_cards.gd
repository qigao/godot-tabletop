extends TabletopRules
## Small second card engine: string IDs, alternate observation and command names.

func game_id() -> String: return "color_cards_fixture"
func rules_revision() -> String: return "v1"
func active_seat(state: Dictionary) -> int: return state.actor

func initial_state(_seed: int) -> Dictionary:
	return {"stock": [["red-a", "red-b"], ["blue-a", "blue-b"]], "actor": 0, "done": false}

func apply(state: Dictionary, seat: int, command: Dictionary) -> Dictionary:
	if state.done or seat != state.actor or command.get("action") != "discard":
		return {"ok": false, "error": "invalid_action"}
	if not command.has("pieces") or not command.pieces is Array or command.pieces.size() != 1 \
			or not state.stock[seat].has(command.pieces[0]):
		return {"ok": false, "error": "invalid_selection"}
	var next := state.duplicate(true)
	next.stock[seat].erase(command.pieces[0])
	next.done = next.stock[seat].is_empty()
	if not next.done:
		next.actor = 1 - seat
	return {"ok": true, "state": next, "events": [{"type": "discarded"}]}

func observe(state: Dictionary, _seat: int) -> Dictionary:
	return state.duplicate(true)

func legal_actions(state: Dictionary, seat: int) -> Array[Dictionary]:
	if state.done or seat != state.actor:
		return []
	# One canonical representative; the other physical card is equivalent.
	return [{"id": "discard", "command": {"action": "discard", "pieces": [state.stock[seat][0]]}}]
