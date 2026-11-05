extends SceneTree

const APP = preload("res://ui/tabletop_app.tscn")

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var app := APP.instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	await process_frame
	_check(app.hand.get_card_count() == 17, "Real addon hand receives opening cards")
	app._on_bid(3)
	await process_frame
	_check(app.hand.get_card_count() == 20, "Landlord hand rendered")
	var card: Card = app.hand.cards_node.get_child(0)
	card._handle_mouse_pressed()
	_check(app.hand.selected_ids.size() == 1, "Card selection uses addon callback")
	app._on_play()
	await process_frame
	_check(app.session.revision == 2 and app.session.observe(0).hands[0].size() == 19, "UI submits play to authority")
	_check(app.hand.get_card_count() == 17, "Next seat hand displayed")
	card = app.hand.cards_node.get_child(0)
	card.change_state(DraggableObject.DraggableState.HOVERING)
	app._new_game()
	await process_frame
	await process_frame
	_check(Card.hovering_card_count == 0, "Replacing a hovered hand releases shared hover count")
	app.queue_free()
	await process_frame
	await process_frame
	print("UI smoke: %d failures" % failures)
	quit(1 if failures > 0 else 0)
