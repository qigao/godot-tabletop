extends SceneTree

const Catalog = preload("res://core/game_catalog.gd")
const ColorRules = preload("res://tests/fixtures/color_cards.gd")
const CARD_VIEW = preload("res://ui/cards/card_table_view.tscn")
const Cards = preload("res://games/doudizhu/cards.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var media := Catalog.module_for("doudizhu").presentation.media
	for id in range(54):
		_check(media.cards[str(id)].label == Cards.label(id), "Configured labels match rule card identities")
		_check(media.cards[str(id)].group == Cards.rank_of(id), "Configured equivalence preserves physical-card ranks")
	await _configured_second_engine()
	await _live_cues()
	await _complete_doudizhu()
	_check(Card.hovering_card_count == 0 and Card.holding_card_count == 0, "Configured scenes release upstream state")
	print("Presentation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _configured_second_engine() -> void:
	var module := TabletopGameModule.new()
	module.id = "color_cards_fixture"
	module.title = "Fixture"
	module.kind = "card"
	module.seat_count = 2
	module.rules_script = ColorRules
	module.view_scene = CARD_VIEW
	var layout := TabletopCardTableLayout.new()
	layout.media = TabletopMediaPack.new()
	layout.sections = ["table", "actions", "hand", "help"]
	layout.seat_order = [1, 0]
	layout.seat_anchors = PackedVector2Array([Vector2(0.25, 0.25), Vector2(0.75, 0.25)])
	layout.relative_seats = false
	layout.card_size = Vector2(90, 130)
	layout.table_color = Color.PURPLE
	layout.numeric_card_keys = false
	layout.selection_equivalence = "color"
	layout.active_seat_binding = {"get": "observation.actor"}
	layout.hand_binding = {"at": [{"get": "observation.stock"}, {"get": "observation.actor"}]}
	layout.seat_text = {"format": ["Player %d", {"get": "seat_number"}]}
	layout.status_text = {"if": [{"get": "observation.done"}, "Done", "Playing"]}
	layout.table_text = {"format": ["Actor %d", {"get": "observation.actor"}]}
	layout.detail_text = {"format": ["%s", "Independent string-card engine"]}
	layout.selection_text = {"format": ["Selected %d", {"get": "selection_count"}]}
	layout.help_text = "Different component order, seats, keys and command schema"
	layout.actions = [{"id": "discard", "label": "Discard", "when": true,
			"command": {"action": "discard"}, "selection_field": "pieces", "browse": false}]
	for key in ["red-a", "red-b", "blue-a", "blue-b"]:
		layout.media.cards[key] = {"title": key, "symbol": "", "label": key,
				"color": key.split("-")[0], "ink": Color.BLACK}
	module.presentation = layout
	var table := TabletopLocalTable.new(module, 0)
	var view := module.create_view() as TabletopCardTableView
	root.add_child(view)
	view.set_reduced_motion(true)
	view.present(table.frame())
	var requests: Array[Dictionary] = []
	view.command_requested.connect(func(command: Dictionary, token: int) -> void:
		requests.append(command)
		_check(table.submit(command, token).ok, "Configured string-card command accepted")
		view.present(table.frame()))
	await process_frame
	_check(view.seats[0].text == "Player 2" and view.seats[1].text == "Player 1", "Seat order comes from config")
	_check(view.get_child(1).get_child(1) is HFlowContainer, "Card component order comes from config")
	_check(view.hand.get_card_count() == 2 and view.manager.card_size == Vector2(90, 130), "Alternate hand binding and card size")
	_check(view.action_buttons.discard.disabled, "Empty selection disables configured action")
	var card := view.hand.cards_node.get_child(1) as Card
	view.hand.on_card_pressed(card)
	_check(not view.action_buttons.discard.disabled, "Equivalent noncanonical string card remains legal")
	view.activate("discard")
	_check(requests[0] == {"action": "discard", "pieces": ["red-b"]}, "Action field names and string IDs remain engine-owned")
	_check(table.snapshot().stock[0] == ["red-a"] and table.frame().seat == 1, "Actual second engine advances")
	view.hand.on_card_pressed(view.hand.cards_node.get_child(0))
	view.activate("discard")
	view.hand.on_card_pressed(view.hand.cards_node.get_child(0))
	view.activate("discard")
	_check(view.status.text == "Done" and view.action_buttons.discard.disabled, "Same renderer reaches another engine's outcome")
	var replay := TabletopSession.from_replay(ColorRules.new(), table.export_replay())
	_check(replay.ok and replay.session.authoritative_snapshot() == table.snapshot(), "Configured game retains authority replay")
	view.deactivate()
	view.queue_free()
	await process_frame

func _live_cues() -> void:
	var workspace := TabletopWorkspace.new()
	var id := workspace.create_table("doudizhu", 42)
	var view := Catalog.module_for("doudizhu").create_view() as TabletopCardTableView
	root.add_child(view)
	view.set_reduced_motion(true)
	view.present(workspace.frame(id))
	var heard: Array[String] = []
	view.cues.cue_started.connect(func(cue: String) -> void: heard.append(cue))
	view.command_requested.connect(func(command: Dictionary, token: int) -> void:
		_check(workspace.submit(id, command, token).ok, "Configured live command accepted")
		view.present(workspace.frame(id)))
	view.activate("bid_3")
	_check(heard.has("bid_3") and heard.has("deal"), "Rule events bind separately to voice and effect channels")
	_check(view.cues._players.voice.stream.get_length() > 0 and view.cues._players.effect.stream.get_length() > 0,
			"Actual imported streams reach audio players")
	var count := heard.size()
	view.present(workspace.frame(id))
	_check(heard.size() == count, "Repeated render cannot duplicate live audio")
	view.activate("browse")
	_check(heard.size() == count, "Legal-play selection produces no rule-event audio")
	view.activate("play")
	_check(heard.has("card"), "Accepted play produces configured effect")
	view.activate("pass")
	_check(heard.has("pass"), "Accepted pass produces configured voice")
	count = heard.size()
	workspace.set_paused(id, true)
	view.present(workspace.frame(id))
	_check(not view.cues._players.voice.playing and not view.cues._players.effect.playing, "Pause cancels audio and queues")
	workspace.set_paused(id, false)
	view.present(workspace.frame(id))
	workspace.seek(id, 0)
	view.present(workspace.frame(id))
	workspace.seek(id, 3)
	view.present(workspace.frame(id))
	_check(heard.size() == count, "Undo/redo/seek and resume do not announce old moves")
	workspace.reset_table(id, 42)
	view.present(workspace.frame(id))
	view.cues.muted = true
	view.activate("bid_3")
	_check(heard.size() == count, "Mute suppresses new live cues")
	view.cues.muted = false
	view.present(workspace.frame(id))
	_check(heard.size() == count, "Unmute cannot replay suppressed cues")
	var archived := JSON.stringify(workspace.export_replay(id))
	workspace.load_replay(archived)
	_check(workspace.frame(workspace.active_id).events.is_empty(), "Imported archives have no live cue events")
	workspace.select_table(id)
	_check(workspace.frame(id).events.is_empty(), "Returning to an old table clears announcement events")
	view.cues.present({"token": 100, "transition": "live", "observation": {"hand_counts": [10, 10, 10]}, "paused": false, "events": [{"type": "played", "seat": 0, "pattern": {"kind": "bomb"}}]})
	_check(heard.has("bomb"), "Nested event field chooses bomb voice")
	_check(view.cues._players.music.stream.resource_path.ends_with("tension-music.wav"), "Configured bomb changes background independently of voice")
	view.cues.present({"token": 101, "transition": "live", "observation": {"hand_counts": [10, 10, 10]}, "paused": false, "events": [{"type": "played", "seat": 0, "pattern": {"kind": "rocket"}}]})
	_check(heard.has("rocket"), "Nested event field chooses rocket voice")
	view.deactivate()
	view.queue_free()
	await process_frame

func _complete_doudizhu() -> void:
	for seed_value in [7, 42, 2026]:
		var table := TabletopLocalTable.new(Catalog.module_for("doudizhu"), seed_value)
		var view := Catalog.module_for("doudizhu").create_view() as TabletopCardTableView
		root.add_child(view)
		view.set_reduced_motion(true)
		view.cues.muted = true
		view.present(table.frame())
		view.command_requested.connect(func(command: Dictionary, token: int) -> void:
			_check(table.submit(command, token).ok, "Configured full-match command accepted")
			view.present(table.frame()))
		view.activate("bid_3")
		_check(view.hand.get_card_count() == 20 and not view.action_buttons.bid_3.visible, "Configured bidding-to-play transition")
		var moves := 0
		while table.snapshot().phase != "finished" and moves < 500:
			var legal: Array = table.frame().legal_actions
			var action: Dictionary = legal[-1]
			for candidate in legal:
				if candidate.command.type == "play" and (action.command.type != "play" or candidate.command.cards.size() > action.command.cards.size()):
					action = candidate
			if action.command.type == "pass":
				view.activate("pass")
			else:
				view.hand.selected_keys.clear()
				for card in action.command.cards:
					view.hand.selected_keys.append(str(card))
				view.hand.selection_changed.emit(view.hand.selected_keys.duplicate())
				_check(not view.action_buttons.play.disabled, "Configured selector enables every accepted play")
				view.activate("play")
			moves += 1
			if moves % 16 == 0:
				await process_frame
		var final := table.snapshot()
		_check(final.phase == "finished" and view.detail.text.contains(str(final.scores)), "Complete configured match displays actual scores")
		_check(view.status.text == ("Landlord wins" if final.winner == final.landlord else "Farmers win"), "Configured outcome binding")
		_check(not view.action_buttons.play.visible and not view.action_buttons.pass.visible, "Finished phase hides gameplay controls")
		var replayed := TabletopSession.from_replay(Catalog.create_rules("doudizhu"), JSON.parse_string(JSON.stringify(table.export_replay())))
		_check(replayed.ok and replayed.session.authoritative_snapshot() == final, "Complete configured game JSON replay")
		view.deactivate()
		view.queue_free()
		await process_frame
