class_name DouDiZhuActions
extends RefCounted
## One action per rank multiset, using the lowest owned card IDs as its representative.
## Construct by pattern family; never scan all 2^N physical-card subsets at runtime.

const Cards = preload("res://games/doudizhu/cards.gd")
const Patterns = preload("res://games/doudizhu/patterns.gd")

var _groups: Dictionary = {}
var _moves: Dictionary = {}

func _init(hand: Array) -> void:
	var ordered := hand.duplicate()
	ordered.sort()
	for id in ordered:
		var rank_value := Cards.rank_of(int(id))
		if not _groups.has(rank_value):
			_groups[rank_value] = []
		_groups[rank_value].append(int(id))

static func enumerate(hand: Array, previous: Dictionary) -> Array[Dictionary]:
	var builder := DouDiZhuActions.new(hand)
	builder._generate()
	var ids: Array = builder._moves.keys()
	ids.sort()
	var result: Array[Dictionary] = []
	for id in ids:
		var action: Dictionary = builder._moves[id]
		if Patterns.beats(action.pattern, previous):
			result.append(action)
	return result

static func id_for_ranks(ranks: Array) -> String:
	var ordered := ranks.duplicate()
	ordered.sort()
	var parts: PackedStringArray = []
	for rank_value in ordered:
		parts.append(str(int(rank_value)))
	return "play:" + ",".join(parts)

func _generate() -> void:
	var ranks: Array = _groups.keys()
	ranks.sort()
	for rank_value in ranks:
		for copies in range(1, _groups[rank_value].size() + 1):
			_add(_repeat([rank_value], copies))
		if _groups[rank_value].size() >= 3:
			for other in ranks:
				if other == rank_value:
					continue
				_add([rank_value, rank_value, rank_value, other])
				if _groups[other].size() >= 2:
					_add([rank_value, rank_value, rank_value, other, other])
		if _groups[rank_value].size() == 4:
			_wings(_repeat([rank_value], 4), [rank_value], 2, false)
			_wings(_repeat([rank_value], 4), [rank_value], 2, true)
	if _groups.has(16) and _groups.has(17):
		_add([16, 17])
	_chains(1, 5)
	_chains(2, 3)
	_chains(3, 2)

func _chains(copies: int, minimum: int) -> void:
	for first in range(3, 15):
		var body_ranks: Array = []
		for last in range(first, 15):
			if not _groups.has(last) or _groups[last].size() < copies:
				break
			body_ranks.append(last)
			if body_ranks.size() < minimum:
				continue
			var body := _repeat(body_ranks, copies)
			_add(body)
			if copies == 3:
				_wings(body, body_ranks, body_ranks.size(), false)
				_wings(body, body_ranks, body_ranks.size(), true)

func _wings(body: Array, body_ranks: Array, count: int, pairs: bool) -> void:
	var ranks: Array = _groups.keys()
	ranks.sort()
	for rank_value in body_ranks:
		ranks.erase(rank_value)
	_choose_wings(body, ranks, 0, count, pairs, [])

func _choose_wings(body: Array, ranks: Array, index: int, remaining: int,
		pairs: bool, chosen: Array) -> void:
	if remaining == 0:
		if not (chosen.has(16) and chosen.has(17)):
			_add(body + chosen)
		return
	if index == ranks.size():
		return
	var rank_value: int = ranks[index]
	var available: int = mini(1, _groups[rank_value].size() / 2) if pairs \
			else mini(2, _groups[rank_value].size())
	var original_size := chosen.size()
	for amount in range(mini(available, remaining) + 1):
		chosen.resize(original_size)
		chosen.append_array(_repeat([rank_value], amount * (2 if pairs else 1)))
		_choose_wings(body, ranks, index + 1, remaining - amount, pairs, chosen)
	chosen.resize(original_size)

func _add(ranks: Array) -> void:
	var id := id_for_ranks(ranks)
	if _moves.has(id):
		return
	var ordered := ranks.duplicate()
	ordered.sort()
	var used := {}
	var cards: Array = []
	for rank_value in ordered:
		var index: int = used.get(rank_value, 0)
		cards.append(_groups[rank_value][index])
		used[rank_value] = index + 1
	var pattern := Patterns.classify(cards)
	assert(not pattern.is_empty(), "Generator produced an invalid pattern: " + str(ranks))
	_moves[id] = {"id": id, "command": {"type": "play", "cards": cards},
			"ranks": ordered, "pattern": pattern}

func _repeat(ranks: Array, copies: int) -> Array:
	var result: Array = []
	for rank_value in ranks:
		for _copy in range(copies):
			result.append(rank_value)
	return result
