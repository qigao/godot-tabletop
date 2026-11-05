extends CardFactory

const CARD_SCENE = preload("res://ui/playing_card.tscn")

func create_card(id_text: String, target: CardContainer) -> Card:
	var card := CARD_SCENE.instantiate() as TabletopPlayingCard
	card.card_name = id_text
	card.card_info = {"id": int(id_text)}
	card.card_size = card_size
	card.size = card_size
	target.add_card(card)
	return card
