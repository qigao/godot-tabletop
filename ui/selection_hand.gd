extends Hand
## A presentation adapter: selecting cards does not mutate match state.

signal selection_changed(ids: Array[int])

var selected_ids: Array[int] = []

func _find_and_register_card_manager() -> void:
	# The scene contract is explicit, with one owning manager per hand.
	card_manager = get_parent() as CardManager
	assert(card_manager != null)
	card_manager._add_card_container(unique_id, self)

func on_card_pressed(card: Card) -> void:
	var id := int(card.card_info.id)
	if selected_ids.has(id):
		selected_ids.erase(id)
	else:
		selected_ids.append(id)
	(card as TabletopPlayingCard).selected = selected_ids.has(id)
	selection_changed.emit(selected_ids.duplicate())

func _card_can_be_added(_cards: Array) -> bool:
	# Dragging must never bypass rules by moving visual cards between seats.
	return false
