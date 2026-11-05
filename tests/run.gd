extends SceneTree

const Session = preload("res://core/game_session.gd")
const Rules = preload("res://games/doudizhu/rules.gd")
const Cards = preload("res://games/doudizhu/cards.gd")
const Patterns = preload("res://games/doudizhu/patterns.gd")
const GridRules = preload("res://tests/fixtures/grid_rules.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	_patterns()
	_bidding_and_privacy()
	_atomic_rejections_and_passes()
	_scoring()
	_isolation_and_board_contract()
	_complete_games_and_json_replay()
	print("Rules: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _cards(ranks: Array) -> Array:
	var counts := {}
	var result: Array = []
	for rank_value in ranks:
		var offset: int = counts.get(rank_value, 0)
		result.append((rank_value - 3) * 4 + offset if rank_value < 16 else rank_value + 36)
		counts[rank_value] = offset + 1
	return result

func _patterns() -> void:
	var cases := {
		"single": [3], "pair": [4, 4], "triple": [5, 5, 5],
		"triple_single": [6, 6, 6, 7], "triple_pair": [7, 7, 7, 8, 8],
		"straight": [3, 4, 5, 6, 7], "pair_straight": [3, 3, 4, 4, 5, 5],
		"airplane": [3, 3, 3, 4, 4, 4],
		"airplane_single": [3, 3, 3, 4, 4, 4, 5, 6],
		"airplane_pair": [3, 3, 3, 4, 4, 4, 5, 5, 6, 6],
		"four_two_single": [3, 3, 3, 3, 4, 5],
		"four_two_pair": [3, 3, 3, 3, 4, 4, 5, 5],
		"bomb": [15, 15, 15, 15], "rocket": [16, 17],
	}
	for kind in cases:
		var pattern := Patterns.classify(_cards(cases[kind]))
		_check(pattern.get("kind") == kind, "Recognize " + kind)
	for ranks in [[], [3, 4], [3, 3, 4], [11, 12, 13, 14, 15],
			[14, 14, 14, 15, 15, 15], [3, 3, 3, 4, 4, 4, 16, 17],
			[3, 3, 3, 3, 16, 17], [3, 3, 3, 3, 4, 4, 4, 4]]:
		_check(Patterns.classify(_cards(ranks)).is_empty(), "Reject pattern: " + str(ranks))
	for cards in [[0, 0], [-1], [54], [1.5], ["0"]]:
		_check(Patterns.classify(cards).is_empty(), "Reject invalid card IDs")
	_check(Patterns.classify(_cards([3, 3, 3, 4, 4, 4, 5, 5])).kind == "airplane_single", "Pair as two single wings")
	var single := Patterns.classify(_cards([3]))
	var pair := Patterns.classify(_cards([4, 4]))
	var bomb := Patterns.classify(_cards([3, 3, 3, 3]))
	var rocket := Patterns.classify([52, 53])
	_check(not Patterns.beats(pair, single), "Different types cannot beat one another")
	_check(Patterns.beats(bomb, pair), "Bomb beats ordinary type")
	_check(Patterns.beats(rocket, bomb), "Rocket beats bomb")
	_check(not Patterns.beats(rocket, rocket), "Rocket cannot beat itself")
	_check(not Patterns.beats(single, single), "Equal rank cannot beat")
	_check(Patterns.beats(Patterns.classify(_cards([4])), single), "Higher single beats")
	_check(not Patterns.beats(Patterns.classify(_cards([4, 5, 6, 7, 8, 9])),
			Patterns.classify(_cards([3, 4, 5, 6, 7]))), "Chains require equal length")

func _bidding_and_privacy() -> void:
	var session := Session.new(Rules.new(), 42)
	var initial := session.authoritative_snapshot()
	_check(initial.hands.map(func(hand: Array) -> int: return hand.size()) == [17, 17, 17], "Deal 17 per seat")
	_check(initial.bottom.size() == 3, "Three bottom cards")
	_check(session.observe(0).hands[0] == initial.hands[0], "Own hand visible")
	_check(session.observe(0).hands[1].is_empty(), "Opponent hand hidden")
	_check(session.observe(-1).hands.all(func(hand: Array) -> bool: return hand.is_empty()), "Spectator sees no hands")
	_check(session.observe(0).bottom.is_empty(), "Bottom hidden during bidding")
	_check(not session.observe(0).has("deal_seed"), "Shuffle seed hidden from player view")
	_check(session.submit(0, {"type": "bid", "value": 1}, 0).ok, "Opening bid")
	_check(not session.submit(1, {"type": "bid", "value": 1}, 1).ok, "Bid must increase")
	_check(not session.submit(1, {"type": "bid", "value": 2.5}, 1).ok, "No fractional bid")
	_check(session.submit(1, {"type": "bid", "value": 2}, 1).ok, "Higher bid")
	_check(session.submit(2, {"type": "bid", "value": 0}, 2).ok, "Bidding ends after three seats")
	var view := session.observe(1)
	_check(view.phase == "playing" and view.turn == 1 and view.landlord == 1, "Highest bidder leads")
	_check(view.hand_counts == [17, 20, 17], "Landlord receives bottom")
	_check(view.bottom == initial.bottom, "Bottom becomes public")
	var passed := Session.new(Rules.new(), 42)
	for seat in range(3):
		_check(passed.submit(seat, {"type": "bid", "value": 0}, passed.revision).ok, "Pass bidding")
	_check(passed.authoritative_snapshot().deal_seed == 43 and passed.observe(-1).turn == 1, "Redeal changes seed and first bidder")
	var maximum := Session.new(Rules.new(), 42)
	_check(maximum.submit(0, {"type": "bid", "value": 3}, 0).ok, "Bid three")
	_check(maximum.observe(-1).phase == "playing", "Bid three ends bidding immediately")

func _atomic_rejections_and_passes() -> void:
	var session := Session.new(Rules.new(), 42)
	session.submit(0, {"type": "bid", "value": 3}, 0)
	var state := session.authoritative_snapshot()
	var replay := session.export_replay()
	var held: int = state.hands[0][0]
	var foreign: int = state.hands[1][0]
	var commands := [
		{"type": "pass"}, {"type": "play", "cards": [foreign]},
		{"type": "play", "cards": [held, held]}, {"type": "play", "cards": []},
		{"type": "play", "cards": "bad"}, {"type": "bid", "value": 3}, {"type": "unknown"}, {},
	]
	for command in commands:
		_check(not session.submit(0, command, 1).ok, "Reject illegal action")
		_check(session.authoritative_snapshot() == state and session.export_replay() == replay,
				"Rejection is atomic")
	_check(session.submit(1, {"type": "play", "cards": [foreign]}, 1).error == "wrong_turn", "Turn enforced")
	_check(session.submit(0, {"type": "play", "cards": [held]}, 0).error == "stale_revision", "Revision enforced")
	var accepted := session.submit(0, {"type": "play", "cards": [held]}, 1)
	_check(accepted.ok and not accepted.has("state"), "Submit does not return authoritative state")
	_check(session.submit(1, {"type": "pass"}, 2).ok, "First pass")
	_check(session.submit(2, {"type": "pass"}, 3).ok, "Second pass")
	_check(session.observe(-1).turn == 0 and session.observe(-1).last_pattern.is_empty(), "Two passes reset trick")
	_check(not session.submit(0, {"type": "pass"}, 4).ok, "New leader cannot pass")
	var view := session.observe(0)
	view.hands[0].clear()
	_check(session.observe(0).hands[0].size() == 19, "Observation cannot mutate live state")

func _scoring() -> void:
	var rules := Rules.new()
	var state := rules.initial_state(7)
	state.phase = "playing"
	state.landlord = 0
	state.hands = [[0, 1, 2, 3], [4], [8]]
	state.bottom = []
	state.multiplier = 1
	var result := rules.apply(state, 0, {"type": "play", "cards": [0, 1, 2, 3]})
	_check(result.ok and result.state.phase == "finished", "Last card ends game")
	_check(result.state.scores == [8, -4, -4], "Bomb and landlord spring multiply")
	_check(state.phase == "playing" and state.hands[0].size() == 4, "Apply does not mutate input")
	_check(not rules.apply(result.state, 0, {"type": "pass"}).ok, "Finished game rejects actions")
	state.turn = 1
	state.hands = [[0], [4], [8]]
	state.plays = [1, 0, 0]
	result = rules.apply(state, 1, {"type": "play", "cards": [4]})
	_check(result.state.scores == [-4, 2, 2], "Farmer reverse spring scoring")
	state.plays = [2, 0, 0]
	result = rules.apply(state, 1, {"type": "play", "cards": [4]})
	_check(result.state.scores == [-2, 1, 1], "Farmer normal scoring")

func _isolation_and_board_contract() -> void:
	var shared_rules := Rules.new()
	var first := Session.new(shared_rules, 100)
	var second := Session.new(shared_rules, 100)
	var unchanged := second.authoritative_snapshot()
	first.submit(0, {"type": "bid", "value": 3}, 0)
	_check(second.authoritative_snapshot() == unchanged and second.revision == 0, "Tables are isolated")
	var grid := Session.new(GridRules.new(), 0)
	_check(grid.submit(0, {"type": "place", "cell": 4}, 0).ok, "Board rules use same session")
	_check(grid.submit(1, {"type": "place", "cell": 4}, 1).error == "occupied", "Board rejection")
	_check(grid.submit(1, {"type": "place", "cell": 0}, 1).ok, "Board turn advances")
	var restored := Session.from_replay(GridRules.new(), JSON.parse_string(JSON.stringify(grid.export_replay())))
	_check(restored.ok and restored.session.authoritative_snapshot() == grid.authoritative_snapshot(), "Board replay uses same session")

func _complete_games_and_json_replay() -> void:
	for seed_value in range(32):
		var session := Session.new(Rules.new(), seed_value)
		session.submit(0, {"type": "bid", "value": 3}, 0)
		var moves := 0
		while session.observe(-1).phase != "finished" and moves < 200:
			var public_view := session.observe(-1)
			var seat: int = public_view.turn
			var view := session.observe(seat)
			var chosen := -1
			for id in view.hands[seat]:
				if Patterns.beats(Patterns.classify([id]), view.last_pattern):
					chosen = id
					break
			# This is a test driver, not a production AI or trained policy.
			var command := {"type": "pass"} if chosen == -1 else {"type": "play", "cards": [chosen]}
			_check(session.submit(seat, command, session.revision).ok, "Simulation uses legal moves")
			var state := session.authoritative_snapshot()
			var all_cards: Array = []
			for player in range(3):
				all_cards.append_array(state.hands[player])
				all_cards.append_array(state.played[player])
			all_cards.sort()
			_check(all_cards == range(54), "54 cards conserved after every move")
			moves += 1
		_check(session.observe(-1).phase == "finished", "Complete game terminates")
		var scores: Array = session.observe(-1).scores
		_check(scores[0] + scores[1] + scores[2] == 0, "Scores sum to zero")
		var replay: Dictionary = JSON.parse_string(JSON.stringify(session.export_replay()))
		var restored := Session.from_replay(Rules.new(), replay)
		_check(restored.ok and restored.session.authoritative_snapshot() == session.authoritative_snapshot(), "JSON replay reproduces full match")
		replay.rules_revision = "unknown"
		_check(not Session.from_replay(Rules.new(), replay).ok, "Reject incompatible rules revision")
