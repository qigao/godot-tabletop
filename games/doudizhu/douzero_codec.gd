class_name DouZeroActionCodec
extends RefCounted
## Action encoding only. This does not run a model or construct network requests.

const Cards = preload("res://games/doudizhu/cards.gd")
const Patterns = preload("res://games/doudizhu/patterns.gd")
const Actions = preload("res://games/doudizhu/actions.gd")
const TO_DOUZERO = [0, 0, 0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 17, 20, 30]
const FROM_DOUZERO = {3: 3, 4: 4, 5: 5, 6: 6, 7: 7, 8: 8, 9: 9,
		10: 10, 11: 11, 12: 12, 13: 13, 14: 14, 17: 15, 20: 16, 30: 17}

static func encode(command: Dictionary) -> Array:
	if command.type == "pass":
		return []
	assert(command.type == "play", "DouZero action encoding requires play phase")
	var encoded: Array = []
	for id in command.cards:
		encoded.append(TO_DOUZERO[Cards.rank_of(int(id))])
	encoded.sort()
	return encoded

static func decode(encoded: Array, legal: Array[Dictionary]) -> Dictionary:
	var ranks: Array = []
	for value in encoded:
		if not Patterns.is_integer(value) or not FROM_DOUZERO.has(int(value)):
			return {"ok": false, "error": "invalid_douzero_rank"}
		ranks.append(FROM_DOUZERO[int(value)])
	var id := "pass" if ranks.is_empty() else Actions.id_for_ranks(ranks)
	for action in legal:
		if action.id == id:
			return {"ok": true, "action_id": id, "command": action.command.duplicate(true)}
	return {"ok": false, "error": "illegal_douzero_action"}
