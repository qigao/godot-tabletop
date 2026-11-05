extends SceneTree

const Session = preload("res://core/game_session.gd")
const Rules = preload("res://games/doudizhu/rules.gd")
const Cards = preload("res://games/doudizhu/cards.gd")
const Patterns = preload("res://games/doudizhu/patterns.gd")
const Actions = preload("res://games/doudizhu/actions.gd")
const Codec = preload("res://games/doudizhu/douzero_codec.gd")
const GridRules = preload("res://tests/fixtures/grid_rules.gd")

var checks := 0
var failures := 0
var mixed_kinds := {}
var oracle_actions := 0

func _initialize() -> void:
	_command_contract()
	_douzero_oracle()
	_exhaustive_subsets()
	_mixed_matches()
	print("Legal actions: %d checks, %d failures; %d upstream oracle actions; %d mixed-game kinds" %
			[checks, failures, oracle_actions, mixed_kinds.size()])
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _key(ranks: Array) -> String:
	var values := ranks.duplicate()
	values.sort()
	var text: PackedStringArray = []
	for rank_value in values:
		text.append(str(int(rank_value)))
	return "play:" + ",".join(text)

func _cards(ranks: Array) -> Array:
	var counts := {}
	var cards: Array = []
	for rank_value in ranks:
		var offset: int = counts.get(rank_value, 0)
		cards.append((rank_value - 3) * 4 + offset if rank_value < 16 else rank_value + 36)
		counts[rank_value] = offset + 1
	return cards

func _ranks(cards: Array) -> Array:
	return cards.map(func(id: int) -> int: return Cards.rank_of(id))

func _local_ranks(encoded: Array) -> Array:
	var result: Array = []
	for code in encoded:
		match int(code):
			17: result.append(15)
			20: result.append(16)
			30: result.append(17)
			_: result.append(int(code))
	return result

func _command_contract() -> void:
	var session := Session.new(Rules.new(), 42)
	_check(session.legal_actions(0).map(func(a: Dictionary) -> String: return a.id) ==
			["bid:0", "bid:1", "bid:2", "bid:3"], "Opening bid actions")
	_check(session.legal_actions(1).is_empty(), "Inactive seat gets no action list")
	_check(session.submit_action(0, "bid:1", 0).ok, "Resolve bid action ID")
	_check(session.legal_actions(1).map(func(a: Dictionary) -> String: return a.id) ==
			["bid:0", "bid:2", "bid:3"], "No repeated/lower bid actions")
	_check(session.submit_action(1, "bid:3", 1).ok, "Resolve maximum bid")
	var state := session.authoritative_snapshot()
	_check(session.submit_action(1, "play:99", 2).error == "unknown_legal_action", "Reject unknown action ID")
	_check(session.submit_action(1, "play:99", 1).error == "stale_revision", "Revision checked before resolution")
	_check(session.revision == 2 and session.authoritative_snapshot() == state, "Action rejection atomic")
	var legal := session.legal_actions(1)
	_check(legal.all(func(a: Dictionary) -> bool: return a.id != "pass"), "Leader cannot pass")
	var action: Dictionary = legal[0].duplicate(true)
	legal[0].command.cards.clear()
	_check(session.legal_actions(1)[0].command == action.command, "Returned actions do not mutate authority")
	_check(session.submit_action(1, action.id, 2).ok, "Action ID resolves to owned physical cards")
	_check(session.legal_actions(2).back().id == "pass", "Follower can pass")
	_check(Codec.encode({"type": "play", "cards": [48, 52, 53]}) == [17, 20, 30], "DouZero two/joker rank codes")
	for encoded in [[15], [16], [1.5], ["3"], [true], [99]]:
		_check(not Codec.decode(encoded, session.legal_actions(2)).ok, "Reject invalid model rank code")
	_check(not Codec.decode([], session.legal_actions(1)).ok, "Model cannot invent a pass")
	var grid := Session.new(GridRules.new(), 0)
	_check(grid.legal_actions(0).size() == 9, "Board actions share session interface")
	_check(grid.submit_action(0, "place:4", 0).ok and grid.legal_actions(1).size() == 8, "Board action ID dispatch")
	_check(grid.submit_action(1, "place:4", 1).error == "unknown_legal_action", "Occupied placement absent")

func _douzero_oracle() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/douzero_actions.json"))
	_check(fixture.commit == "718a5c920bf3361e34178a38f3b80458e176b351", "Pinned upstream oracle")
	for case in fixture.cases:
		var hand := _cards(_local_ranks(case.hand))
		var actual := {}
		for action in Actions.enumerate(hand, {}):
			actual[action.id] = true
			var encoded := Codec.encode(action.command)
			_check(_key(_local_ranks(encoded)) == action.id, "Rank codec preserves stable ID")
		var expected := {}
		for encoded in case.actions:
			expected[_key(_local_ranks(encoded))] = true
			oracle_actions += 1
		for encoded in case.excluded_by_profile:
			var id := _key(_local_ranks(encoded))
			_check(expected.has(id) and not actual.has(id), "Explicit profile exclusion: " + case.name)
			expected.erase(id)
		_check(actual == expected, "Exact upstream action set minus named profile exclusions: " + case.name)
		var reversed := hand.duplicate()
		reversed.reverse()
		_check(Actions.enumerate(hand, {}) == Actions.enumerate(reversed, {}), "Hand order cannot change IDs/representatives")
	var hand := _cards([3, 3, 3, 4, 4])
	var all := Actions.enumerate(hand, {})
	var same_ranks := hand.map(func(id: int) -> int: return id + 1)
	_check(Actions.enumerate(same_ranks, {}).map(func(a: Dictionary) -> String: return a.id) ==
			all.map(func(a: Dictionary) -> String: return a.id), "Equivalent suits keep action IDs")

func _exhaustive_subsets() -> void:
	var hands: Array = [
		_cards([3, 3, 3, 4, 4, 4, 5, 5, 6, 6, 16, 17]),
		_cards([3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 6, 6]),
		_cards([3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 17]),
		_cards([3, 3, 3, 4, 4, 4, 5, 5, 5, 9, 9, 9]),
	]
	for seed_value in range(8):
		hands.append(Cards.shuffled(seed_value + 1000).slice(0, 12))
	var rivals: Array = [[], [7], [7, 7], [7, 7, 7], [7, 7, 7, 8], [7, 7, 7, 8, 8],
			[7, 8, 9, 10, 11], [7, 7, 8, 8, 9, 9], [7, 7, 7, 8, 8, 8],
			[7, 7, 7, 8, 8, 8, 9, 10], [7, 7, 7, 8, 8, 8, 9, 9, 10, 10],
			[7, 7, 7, 7, 8, 9], [7, 7, 7, 7, 8, 8, 9, 9], [7, 7, 7, 7], [16, 17]]
	var rules := Rules.new()
	for hand in hands:
		var state := rules.initial_state(0)
		state.phase = "playing"
		state.landlord = 0
		state.hands[0] = hand
		var exhaustive := {}
		# Independent physical-subset scan through the actual command validator.
		for mask in range(1, 1 << hand.size()):
			var subset: Array = []
			for index in range(hand.size()):
				if mask & (1 << index):
					subset.append(hand[index])
			var result := rules.apply(state, 0, {"type": "play", "cards": subset})
			if result.ok:
				exhaustive[_key(_ranks(subset))] = {"type": "play", "cards": subset}
		for rival in rivals:
			state.last_pattern = Patterns.classify(_cards(rival))
			var expected := {}
			for id in exhaustive:
				if rules.apply(state, 0, exhaustive[id]).ok:
					expected[id] = true
			if not rival.is_empty():
				expected["pass"] = true
			var actual := {}
			for action in rules.legal_actions(state, 0):
				actual[action.id] = true
				_check(rules.apply(state, 0, action.command).ok, "Every enumerated response is accepted")
			_check(actual == expected, "Subset completeness for hand/rival: " + str(hand) + "/" + str(rival))

func _mixed_matches() -> void:
	for seed_value in range(96):
		var session := Session.new(Rules.new(), seed_value)
		session.submit_action(0, "bid:3", 0)
		var moves := 0
		while session.observe(-1).phase != "finished" and moves < 200:
			var seat: int = session.observe(-1).turn
			var legal := session.legal_actions(seat)
			var index: int = (seed_value * 1664525 + moves * 1013904223) % legal.size()
			for candidate in range(legal.size()):
				if legal[candidate].has("pattern") and not mixed_kinds.has(legal[candidate].pattern.kind):
					index = candidate
					break
			var action: Dictionary = legal[index]
			if action.has("pattern"):
				mixed_kinds[action.pattern.kind] = true
			var decoded := Codec.decode(Codec.encode(action.command), legal)
			_check(decoded.ok and decoded.action_id == action.id, "Model action maps to legal representative")
			_check(session.submit_action(seat, decoded.action_id, session.revision).ok, "Mixed match action accepted")
			var state := session.authoritative_snapshot()
			var deck: Array = []
			for player in range(3):
				deck.append_array(state.hands[player])
				deck.append_array(state.played[player])
			deck.sort()
			_check(deck == range(54), "Mixed match conserves every card")
			moves += 1
		_check(session.observe(-1).phase == "finished", "Mixed match finishes")
		_check(session.legal_actions(0).is_empty() and session.legal_actions(1).is_empty() \
				and session.legal_actions(2).is_empty(), "Finished round has no legal actions")
		var replay: Dictionary = JSON.parse_string(JSON.stringify(session.export_replay()))
		var restored := Session.from_replay(Rules.new(), replay)
		_check(restored.ok and restored.session.authoritative_snapshot() == session.authoritative_snapshot(), "Mixed match JSON replay")
	var expected: Array = ["single", "pair", "triple", "triple_single", "triple_pair", "straight",
			"pair_straight", "airplane", "airplane_single", "airplane_pair", "four_two_single",
			"four_two_pair", "bomb", "rocket"]
	expected.sort()
	var actual: Array = mixed_kinds.keys()
	actual.sort()
	_check(actual == expected, "Real seeded mixed matches play all fourteen kinds")
	print("Mixed kinds: " + str(mixed_kinds.keys()))
