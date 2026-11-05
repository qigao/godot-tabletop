class_name DouDiZhuCards
extends RefCounted
## Stable IDs: four suits per rank, 3..A..2, then small/big joker.

static func rank_of(card: int) -> int:
	return card / 4 + 3 if card < 52 else card - 36

static func label(card: int) -> String:
	if card == 52:
		return "SJ"
	if card == 53:
		return "BJ"
	var rank_value := rank_of(card)
	var rank_text: String = {11: "J", 12: "Q", 13: "K", 14: "A", 15: "2"}.get(rank_value, str(rank_value))
	return rank_text + ["S", "H", "C", "D"][card % 4]

static func shuffled(seed_value: int) -> Array:
	# Fixed 32-bit generator makes replay independent of Godot RNG changes.
	var deck: Array = range(54)
	var value: int = seed_value & 0xffffffff
	for i in range(53, 0, -1):
		value = (1664525 * value + 1013904223) & 0xffffffff
		var j: int = value % (i + 1)
		var card: int = deck[i]
		deck[i] = deck[j]
		deck[j] = card
	return deck
