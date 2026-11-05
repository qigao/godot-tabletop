class_name DouDiZhuRules
extends TabletopRules

const Cards = preload("res://games/doudizhu/cards.gd")
const Patterns = preload("res://games/doudizhu/patterns.gd")

func game_id() -> String:
	return "doudizhu"

func rules_revision() -> String:
	return "ddz-classic-v1"

func initial_state(seed_value: int) -> Dictionary:
	return _deal(seed_value, 0)

func _deal(seed_value: int, first: int) -> Dictionary:
	var deck := Cards.shuffled(seed_value)
	var hands: Array = [[], [], []]
	for i in range(51):
		hands[i % 3].append(deck[i])
	for hand in hands:
		hand.sort()
	return {
		"phase": "bidding", "turn": first, "first_bidder": first, "deal_seed": seed_value,
		"hands": hands, "bottom": deck.slice(51), "bids": [-1, -1, -1],
		"highest_bid": 0, "landlord": -1, "last_cards": [], "last_pattern": {},
		"last_player": -1, "passes": 0, "played": [[], [], []], "plays": [0, 0, 0],
		"multiplier": 1, "winner": -1, "scores": [0, 0, 0],
	}

func apply(state: Dictionary, seat: int, command: Dictionary) -> Dictionary:
	if state.phase == "finished":
		return _reject("game_finished")
	if seat != state.turn:
		return _reject("wrong_turn")
	if not command.has("type"):
		return _reject("missing_command_type")
	match command.type:
		"bid":
			return _bid(state, seat, command)
		"play":
			return _play(state, seat, command)
		"pass":
			return _pass(state, seat)
	return _reject("unknown_command")

func _bid(state: Dictionary, seat: int, command: Dictionary) -> Dictionary:
	if state.phase != "bidding":
		return _reject("not_bidding")
	if not command.has("value") or not Patterns.is_integer(command.value):
		return _reject("invalid_bid")
	var value := int(command.value)
	if value < 0 or value > 3 or (value != 0 and value <= state.highest_bid):
		return _reject("bid_must_increase")
	var next := state.duplicate(true)
	next.bids[seat] = value
	var events: Array = [{"type": "bid", "seat": seat, "value": value}]
	if value > next.highest_bid:
		next.highest_bid = value
		next.landlord = seat
	if value == 3 or not next.bids.has(-1):
		if next.highest_bid == 0:
			next = _deal((int(state.deal_seed) + 1) & 0xffffffff, (state.first_bidder + 1) % 3)
			events.append({"type": "redealt", "first_bidder": next.turn})
		else:
			next.phase = "playing"
			next.turn = next.landlord
			next.multiplier = next.highest_bid
			next.hands[next.landlord].append_array(next.bottom)
			next.hands[next.landlord].sort()
			events.append({"type": "landlord", "seat": next.landlord, "bottom": next.bottom.duplicate()})
	else:
		next.turn = (seat + 1) % 3
	return _accept(next, events)

func _play(state: Dictionary, seat: int, command: Dictionary) -> Dictionary:
	if state.phase != "playing":
		return _reject("not_playing")
	if not command.has("cards") or not command.cards is Array:
		return _reject("invalid_cards")
	var pattern := Patterns.classify(command.cards)
	if pattern.is_empty():
		return _reject("invalid_pattern")
	var cards: Array = []
	for value in command.cards:
		var id := int(value)
		if not state.hands[seat].has(id):
			return _reject("card_not_owned")
		cards.append(id)
	if not Patterns.beats(pattern, state.last_pattern):
		return _reject("does_not_beat_previous")
	var next := state.duplicate(true)
	for card in cards:
		next.hands[seat].erase(card)
		next.played[seat].append(card)
	next.plays[seat] += 1
	next.last_cards = cards
	next.last_pattern = pattern
	next.last_player = seat
	next.passes = 0
	if pattern.kind in ["bomb", "rocket"]:
		next.multiplier *= 2
	var events: Array = [{"type": "played", "seat": seat, "cards": cards.duplicate(), "pattern": pattern.duplicate()}]
	if next.hands[seat].is_empty():
		_finish(next, seat)
		events.append({"type": "finished", "winner": seat, "scores": next.scores.duplicate()})
	else:
		next.turn = (seat + 1) % 3
	return _accept(next, events)

func _pass(state: Dictionary, seat: int) -> Dictionary:
	if state.phase != "playing":
		return _reject("not_playing")
	if state.last_pattern.is_empty():
		return _reject("leader_cannot_pass")
	var next := state.duplicate(true)
	next.passes += 1
	var events: Array = [{"type": "passed", "seat": seat}]
	if next.passes == 2:
		next.turn = next.last_player
		next.last_cards = []
		next.last_pattern = {}
		next.passes = 0
		events.append({"type": "trick_reset", "seat": next.turn})
	else:
		next.turn = (seat + 1) % 3
	return _accept(next, events)

func _finish(state: Dictionary, winner: int) -> void:
	state.phase = "finished"
	state.winner = winner
	var landlord_won: bool = winner == state.landlord
	var spring: bool = state.plays[state.landlord] == 1
	if landlord_won:
		spring = true
		for seat in range(3):
			if seat != state.landlord and state.plays[seat] > 0:
				spring = false
	if spring:
		state.multiplier *= 2
	for seat in range(3):
		var points: int = state.multiplier * (2 if seat == state.landlord else -1)
		state.scores[seat] = points if landlord_won else -points

func observe(state: Dictionary, seat: int) -> Dictionary:
	var view := state.duplicate(true)
	view.erase("deal_seed")
	view.hands = []
	view["hand_counts"] = []
	for player in range(3):
		view.hands.append(state.hands[player].duplicate() if player == seat else [])
		view.hand_counts.append(state.hands[player].size())
	if state.phase == "bidding":
		view.bottom = []
	return view

func _reject(error: String) -> Dictionary:
	return {"ok": false, "error": error}

func _accept(state: Dictionary, events: Array) -> Dictionary:
	return {"ok": true, "state": state, "events": events}
