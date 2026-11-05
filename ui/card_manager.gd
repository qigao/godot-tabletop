class_name TabletopCardManager
extends CardManager
## Explicit client ownership, independent of the upstream scene-root metadata.

var input_scope := TabletopInputScope.new()

func _ready() -> void:
	card_factory = card_factory_scene.instantiate() as TabletopCardFactory
	(card_factory as TabletopCardFactory).input_scope = input_scope
	card_factory.card_size = card_size
	add_child(card_factory)
	card_factory.preload_card_data()

func _exit_tree() -> void:
	input_scope.release()
