extends Hand
## A presentation adapter: selecting cards does not mutate match state.

signal selection_changed(keys: PackedStringArray)

var selected_keys: PackedStringArray = []
var input_enabled := true

func _update_card_states() -> void:
	super._update_card_states()
	for card in _held_cards:
		card.can_be_interacted_with = input_enabled

func _find_and_register_card_manager() -> void:
	# The scene contract is explicit, with one owning manager per hand.
	card_manager = get_parent() as CardManager
	assert(card_manager != null)
	card_manager._add_card_container(unique_id, self)

func on_card_pressed(card: Card) -> void:
	var key: String = card.card_name
	if selected_keys.has(key):
		selected_keys.remove_at(selected_keys.find(key))
	else:
		selected_keys.append(key)
	(card as TabletopPlayingCard).selected = selected_keys.has(key)
	selection_changed.emit(selected_keys.duplicate())

func focus_neighbour(card: Card, direction: int) -> void:
	var index := _held_cards.find(card)
	_held_cards[posmod(index + direction, _held_cards.size())].grab_focus()

func _card_can_be_added(_cards: Array) -> bool:
	# Dragging must never bypass rules by moving visual cards between seats.
	return false
