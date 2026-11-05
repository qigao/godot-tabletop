class_name TabletopCardFactory
extends CardFactory

const CARD_SCENE = preload("res://ui/playing_card.tscn")

var input_scope: TabletopInputScope
var definitions: Dictionary = {}

func create_card(id_text: String, target: CardContainer) -> Card:
	var card := CARD_SCENE.instantiate() as TabletopPlayingCard
	card.card_name = id_text
	card.card_info = definitions[id_text].duplicate(true)
	card.input_scope = input_scope
	card.card_size = card_size
	card.size = card_size
	target.add_card(card)
	return card
