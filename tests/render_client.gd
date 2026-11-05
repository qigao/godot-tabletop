extends SceneTree
## Render the real client for visual acceptance; run with an actual display driver.

const APP = preload("res://ui/tabletop_app.tscn")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var app := APP.instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	app.current_view._on_bid(3)
	app.current_view._on_cycle()
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/images")
	root.get_texture().get_image().save_png("res://docs/images/client-doudizhu.png")
	app.game_picker.select(1)
	app._new_table()
	for cell in [112,113,97,127,82,98]:
		app.current_view.board.cell_activated.emit(cell)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/images/client-gomoku.png")
	root.size = Vector2i(800, 600)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/images/client-compact.png")
	app.queue_free()
	await process_frame
	quit()
