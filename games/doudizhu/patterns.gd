class_name DouDiZhuPatterns
extends RefCounted

const Cards = preload("res://games/doudizhu/cards.gd")

static func classify(cards: Array) -> Dictionary:
	if cards.is_empty() or cards.size() > 20:
		return {}
	var seen := {}
	var counts := {}
	for value in cards:
		if not is_integer(value) or value < 0 or value > 53 or seen.has(int(value)):
			return {}
		var id := int(value)
		seen[id] = true
		var rank_value := Cards.rank_of(id)
		counts[rank_value] = int(counts.get(rank_value, 0)) + 1
	var ranks: Array = counts.keys()
	ranks.sort()
	var n := cards.size()
	if n == 1:
		return _pattern("single", ranks[0], n)
	if n == 2 and ranks == [16, 17]:
		return _pattern("rocket", 17, n)
	if ranks.size() == 1:
		return _pattern({2: "pair", 3: "triple", 4: "bomb"}[n], ranks[0], n)
	if n == 4 or n == 5:
		for rank_value in ranks:
			if counts[rank_value] == 3 and (n == 4 or counts.values().has(2)):
				return _pattern("triple_single" if n == 4 else "triple_pair", rank_value, n)
	if n >= 5 and _uniform(counts, 1) and _chain(ranks):
		return _pattern("straight", ranks.back(), n)
	if n >= 6 and _uniform(counts, 2) and _chain(ranks):
		return _pattern("pair_straight", ranks.back(), n)
	if n >= 6 and _uniform(counts, 3) and _chain(ranks):
		return _pattern("airplane", ranks.back(), n)
	for wing_size in [1, 2]:
		if n % (3 + wing_size) != 0:
			continue
		var body_size: int = n / (3 + wing_size)
		if body_size < 2:
			continue
		var triples: Array = []
		for rank_value in ranks:
			if counts[rank_value] == 3:
				triples.append(rank_value)
		if triples.size() != body_size or not _chain(triples):
			continue
		var wings := counts.duplicate()
		for rank_value in triples:
			wings.erase(rank_value)
		if wing_size == 1 and _single_wings(wings):
			return _pattern("airplane_single", triples.back(), n)
		if wing_size == 2 and wings.size() == body_size and _uniform(wings, 2):
			return _pattern("airplane_pair", triples.back(), n)
	if n == 6 or n == 8:
		for rank_value in ranks:
			if counts[rank_value] != 4:
				continue
			var wings := counts.duplicate()
			wings.erase(rank_value)
			if n == 6 and _single_wings(wings):
				return _pattern("four_two_single", rank_value, n)
			if n == 8 and wings.size() == 2 and _uniform(wings, 2):
				return _pattern("four_two_pair", rank_value, n)
	return {}

static func beats(candidate: Dictionary, previous: Dictionary) -> bool:
	if candidate.is_empty():
		return false
	if previous.is_empty():
		return true
	if previous.kind == "rocket":
		return false
	if candidate.kind == "rocket":
		return true
	if candidate.kind == "bomb" and previous.kind != "bomb":
		return true
	return candidate.kind == previous.kind and candidate.count == previous.count \
			and candidate.rank > previous.rank

static func is_integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and value == int(value)

static func _pattern(kind: String, rank_value: int, count: int) -> Dictionary:
	return {"kind": kind, "rank": rank_value, "count": count}

static func _uniform(counts: Dictionary, count: int) -> bool:
	for value in counts.values():
		if value != count:
			return false
	return true

static func _chain(ranks: Array) -> bool:
	return ranks.back() <= 14 and ranks.back() - ranks[0] + 1 == ranks.size()

static func _single_wings(counts: Dictionary) -> bool:
	# This profile allows pair wings, but no triple wing or rocket as two wings.
	return not (counts.has(16) and counts.has(17)) \
			and counts.values().all(func(value: int) -> bool: return value <= 2)
