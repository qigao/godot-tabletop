extends Control
## Generic local client host. All game-specific behavior arrives through modules.

const Catalog = preload("res://core/game_catalog.gd")

var workspace := TabletopWorkspace.new()
var current_view: TabletopGameView
var _view_table_id := -1
var game_picker: OptionButton
var seed_input: SpinBox
var tabs: TabBar
var view_slot: ScrollContainer
var pause_mask: ColorRect
var undo_button: Button
var redo_button: Button
var reset_button: Button
var pause_button: Button
var close_button: Button
var save_button: Button
var sound_button: Button
var sound_enabled := true
var motion_button: Button
var reduced_motion := false
var history: HSlider
var history_label: Label
var status_label: Label
var save_dialog: FileDialog
var load_dialog: FileDialog
var _save_table_id := -1

func _ready() -> void:
	_build_ui()
	workspace.changed.connect(_refresh)
	_new_table()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var title := TabletopUI.label("TABLETOP", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	game_picker = OptionButton.new()
	game_picker.custom_minimum_size.x = 125
	for game in Catalog.games():
		game_picker.add_item(game.title)
		game_picker.set_item_metadata(game_picker.item_count - 1, game.id)
	header.add_child(game_picker)
	seed_input = SpinBox.new()
	seed_input.min_value = 0
	seed_input.max_value = 2147483647
	seed_input.value = 42
	seed_input.custom_minimum_size.x = 105
	header.add_child(seed_input)
	TabletopUI.button(header, "New table", _new_table)
	tabs = TabBar.new()
	tabs.tab_changed.connect(_on_tab_changed)
	column.add_child(tabs)
	var toolbar := HFlowContainer.new()
	toolbar.add_theme_constant_override("h_separation", 10)
	column.add_child(toolbar)
	undo_button = TabletopUI.button(toolbar, "Undo", _undo)
	redo_button = TabletopUI.button(toolbar, "Redo", _redo)
	reset_button = TabletopUI.button(toolbar, "Restart", _restart)
	pause_button = TabletopUI.button(toolbar, "Pause", _toggle_pause)
	close_button = TabletopUI.button(toolbar, "Close table", _close)
	save_button = TabletopUI.button(toolbar, "Save replay", _save_replay)
	TabletopUI.button(toolbar, "Load replay", func() -> void: load_dialog.popup_centered_ratio(0.8))
	sound_button = TabletopUI.button(toolbar, "Sound on", _toggle_sound)
	motion_button = TabletopUI.button(toolbar, "Motion on", _toggle_motion)
	var timeline := HBoxContainer.new()
	column.add_child(timeline)
	history_label = TabletopUI.label("", 14)
	history_label.custom_minimum_size.x = 145
	timeline.add_child(history_label)
	history = HSlider.new()
	history.step = 1
	history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history.value_changed.connect(_on_seek)
	timeline.add_child(history)
	var view_frame := Control.new()
	view_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(view_frame)
	view_slot = ScrollContainer.new()
	view_slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_slot.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	view_frame.add_child(view_slot)
	pause_mask = ColorRect.new()
	pause_mask.color = Color(0.035, 0.055, 0.09, 0.85)
	pause_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_frame.add_child(pause_mask)
	var paused := TabletopUI.label("Paused  /  Resume to continue", 26)
	paused.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paused.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paused.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_mask.add_child(paused)
	status_label = TabletopUI.label("Local tables  /  Independent games and replay", 14)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status_label)
	save_dialog = FileDialog.new()
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.filters = PackedStringArray(["*.json ; Tabletop replay"])
	save_dialog.file_selected.connect(_save_file)
	add_child(save_dialog)
	load_dialog = FileDialog.new()
	load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	load_dialog.filters = PackedStringArray(["*.json ; Tabletop replay"])
	load_dialog.file_selected.connect(_load_file)
	add_child(load_dialog)

func _new_table() -> void:
	var id: String = game_picker.get_item_metadata(game_picker.selected)
	workspace.create_table(id, int(seed_input.value))

func _refresh() -> void:
	tabs.set_block_signals(true)
	tabs.clear_tabs()
	for table in workspace.table_list():
		tabs.add_tab("%s #%d" % [table.title, table.id])
		tabs.set_tab_metadata(tabs.tab_count - 1, table.id)
		if table.id == workspace.active_id:
			tabs.current_tab = tabs.tab_count - 1
	tabs.set_block_signals(false)
	var exists := workspace.active_id != -1
	for control in [undo_button, redo_button, reset_button, pause_button, close_button, save_button]:
		control.disabled = not exists
	history.editable = exists
	if not exists:
		_unmount()
		pause_mask.visible = false
		history_label.text = "No open tables"
		return
	var frame := workspace.frame(workspace.active_id)
	if _view_table_id != workspace.active_id:
		_unmount()
		current_view = Catalog.module_for(frame.game_id).create_view()
		current_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		current_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		current_view.command_requested.connect(_on_view_command.bind(workspace.active_id))
		current_view.lifecycle_requested.connect(_on_view_lifecycle.bind(workspace.active_id))
		view_slot.add_child(current_view)
		current_view.cues.muted = not sound_enabled
		current_view.set_reduced_motion(reduced_motion)
		current_view.restore_ui_state(workspace.view_state(workspace.active_id))
		_view_table_id = workspace.active_id
	current_view.present(frame)
	pause_mask.visible = frame.paused
	pause_button.text = "Resume" if frame.paused else "Pause"
	undo_button.disabled = frame.cursor == 0
	redo_button.disabled = frame.cursor == frame.length
	history.set_block_signals(true)
	history.max_value = frame.length
	history.value = frame.cursor
	history.set_block_signals(false)
	history_label.text = "Move %d / %d" % [frame.cursor, frame.length]

func _unmount() -> void:
	if current_view != null:
		if workspace.table_ids().has(_view_table_id):
			workspace.save_view_state(_view_table_id, current_view.capture_ui_state())
		current_view.deactivate()
		view_slot.remove_child(current_view)
		current_view.queue_free()
		current_view = null
	_view_table_id = -1

func _on_view_command(command: Dictionary, token: int, table_id: int) -> void:
	var result := workspace.submit(table_id, command, token)
	status_label.text = "Move accepted" if result.ok else "Move rejected: " + result.error.replace("_", " ")

func _on_view_lifecycle(action: String, token: int, table_id: int) -> void:
	if table_id != workspace.active_id or table_id == -1 or workspace.frame(table_id).token != token:
		return
	match action:
		"new_round": workspace.reset_table(table_id, (int(workspace.frame(table_id).seed) + 1) & 0xffffffff)
		"close": workspace.close_table(table_id)
		_: assert(false, "Unknown view lifecycle request")

func _on_tab_changed(index: int) -> void:
	workspace.select_table(int(tabs.get_tab_metadata(index)))

func _undo() -> void:
	workspace.seek(workspace.active_id, int(workspace.frame(workspace.active_id).cursor) - 1)

func _redo() -> void:
	workspace.seek(workspace.active_id, int(workspace.frame(workspace.active_id).cursor) + 1)

func _on_seek(position: float) -> void:
	workspace.seek(workspace.active_id, int(position))

func _restart() -> void:
	workspace.reset_table(workspace.active_id, int(seed_input.value))

func _toggle_pause() -> void:
	workspace.set_paused(workspace.active_id, not workspace.frame(workspace.active_id).paused)

func _close() -> void:
	workspace.close_table(workspace.active_id)

func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	sound_button.text = "Sound on" if sound_enabled else "Sound off"
	if current_view != null:
		current_view.cues.muted = not sound_enabled

func _toggle_motion() -> void:
	reduced_motion = not reduced_motion
	motion_button.text = "Motion off" if reduced_motion else "Motion on"
	if current_view != null:
		current_view.set_reduced_motion(reduced_motion)

func _save_replay() -> void:
	_save_table_id = workspace.active_id
	save_dialog.current_file = "%s-table-%d.json" % [workspace.frame(_save_table_id).game_id, _save_table_id]
	save_dialog.popup_centered_ratio(0.8)

func _save_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		status_label.text = "Cannot write replay: " + error_string(FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(workspace.export_replay(_save_table_id), "\t"))
	status_label.text = "Replay saved: " + path.get_file()

func _load_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		status_label.text = "Cannot read replay: " + error_string(FileAccess.get_open_error())
		return
	var result := workspace.load_replay(file.get_as_text())
	status_label.text = "Replay loaded into a new table" if result.ok else "Replay rejected: " + result.error.replace("_", " ")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.ctrl_pressed or event.meta_pressed):
		match event.keycode:
			KEY_Z:
				if event.shift_pressed and not redo_button.disabled:
					_redo()
				elif not event.shift_pressed and not undo_button.disabled:
					_undo()
			KEY_Y:
				if not redo_button.disabled:
					_redo()
			KEY_S:
				if not save_button.disabled:
					_save_replay()
			KEY_O: load_dialog.popup_centered_ratio(0.8)
