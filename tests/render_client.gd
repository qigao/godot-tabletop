extends SceneTree
## Native frames of real input and animation, plus stable desktop/compact layouts.

const APP = preload("res://ui/tabletop_app.tscn")
var _capture_index := 0

func _initialize() -> void:
	_run.call_deferred()

func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)

func _motion(point: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event, true)

func _record(frames: int) -> void:
	for _i in range(frames):
		await create_timer(0.1).timeout
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://build/interaction-frames/%03d.png" % _capture_index) == OK)
		_capture_index += 1

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/images/" + name) == OK)

func _run() -> void:
	root.size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute("res://build/interaction-frames")
	DirAccess.make_dir_recursive_absolute("res://docs/images")
	var app := APP.instantiate()
	root.add_child(app)
	current_scene = app
	await _record(15)
	var view := app.current_view as TabletopCardTableView
	view.activate("bid_3")
	await _record(4)
	view.activate("browse")
	var card: Card = view.hand.cards_node.get_child(0)
	for candidate in view.hand.cards_node.get_children():
		if view.hand.selected_keys.has(candidate.card_name):
			card = candidate
	var point := card.get_global_transform_with_canvas() * Vector2(10, 35)
	_motion(point)
	await _record(8)
	await _save("client-doudizhu.png")
	_mouse(point, true)
	_motion(point - Vector2(0, 45), true)
	await _record(3)
	var target := view._drop_hint.get_global_rect().get_center()
	_motion(target, true)
	await _record(2)
	_mouse(target, false)
	await _record(5)
	# A compact card-table capture, with real seats, public zones and controls.
	root.size = Vector2i(800, 600)
	await create_timer(0.25).timeout
	await _save("client-doudizhu-compact.png")
	root.size = Vector2i(1280, 800)
	app.current_view.set_reduced_motion(true)
	var id: int = app.workspace.active_id
	var steps := 0
	while app.workspace.snapshot(id).phase != "finished" and steps < 500:
		var actions: Array = app.workspace.frame(id).legal_actions
		var action: Dictionary = actions[-1]
		for candidate in actions:
			if candidate.command.type == "play" and (action.command.type != "play" or candidate.command.cards.size() > action.command.cards.size()):
				action = candidate
		if action.command.type == "pass":
			app.current_view.activate("pass")
		else:
			var keys := PackedStringArray()
			for value in action.command.cards:
				keys.append(str(value))
			app.current_view.hand.set_selection(keys)
			app.current_view.activate("play")
		steps += 1
		if steps % 16 == 0:
			await process_frame
	assert(app.workspace.snapshot(id).phase == "finished")
	await create_timer(0.2).timeout
	await _save("client-doudizhu-result.png")
	app.game_picker.select(1)
	app._new_table()
	for cell in [112,113,97,127,82,98]:
		app.current_view.board.cell_activated.emit(cell)
	await create_timer(0.2).timeout
	await _save("client-gomoku.png")
	root.size = Vector2i(800, 600)
	await create_timer(0.2).timeout
	await _save("client-compact.png")
	app.queue_free()
	await process_frame
	quit()
