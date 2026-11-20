class_name TabletopBoardCanvas
extends Control
## A reusable intersection grid. Adapters decide what a cell click means.

signal cell_activated(cell: int)
signal selection_cancelled()

var columns := 15
var rows := 15
var pieces: Dictionary = {}
var highlighted: Array = []
var last_cell := -1
var last_origin := -1
var selected_cell := -1
var checked_cell := -1
var move_targets := PackedInt32Array()
var focused_cell := -1
var blocked := false
var table_texture: Texture2D
var board_color := Color("c8a776")
var board_font: Font
var uniform_spacing := false
var split_after_row := -1
var split_labels := PackedStringArray()
var guide_lines: Array[Vector2i] = []

func _ready() -> void:
	focused_cell = int(rows / 2) * columns + int(columns / 2)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(280, 280)
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func board_rect() -> Rect2:
	if uniform_spacing:
		var grid := Vector2(columns - 1, rows - 1)
		var margins := grid + Vector2(1.25, 1.25)
		var spacing := minf(size.x / margins.x, size.y / margins.y)
		var extent := grid * spacing
		return Rect2((size - extent) / 2, extent)
	var edge := minf(size.x, size.y) - 40
	return Rect2((size - Vector2(edge, edge)) / 2, Vector2(edge, edge))

func cell_position(cell: int) -> Vector2:
	var rect := board_rect()
	return rect.position + Vector2(float(cell % columns) / (columns - 1),
			float(cell / columns) / (rows - 1)) * rect.size

func cell_at(point: Vector2) -> int:
	var rect := board_rect()
	var step := rect.size / Vector2(columns - 1, rows - 1)
	if not rect.grow(minf(step.x, step.y) * 0.45).has_point(point):
		return -1
	var offset := (point - rect.position) / step
	var column := roundi(offset.x)
	var row := roundi(offset.y)
	if column < 0 or column >= columns or row < 0 or row >= rows:
		return -1
	return row * columns + column

func _draw() -> void:
	var rect := board_rect()
	var step := minf(rect.size.x / (columns - 1), rect.size.y / (rows - 1))
	var radius := step * 0.42
	var margin := step * 0.58 if uniform_spacing else 14.0
	draw_style_box(TabletopUI.panel(board_color, 12), rect.grow(margin))
	if table_texture != null:
		draw_texture_rect(table_texture, rect.grow(margin), false)
	_draw_grid(rect, step)
	for cell in pieces:
		var piece: Dictionary = pieces[cell]
		var point := cell_position(int(cell))
		draw_circle(point + Vector2(1, 2), radius, Color(0, 0, 0, 0.2))
		if piece.mode == "image":
			draw_texture_rect(piece.texture, Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2), false)
		else:
			assert(piece.mode == "disc")
			draw_circle(point, radius, piece.fill)
		draw_arc(point, radius, 0, TAU, 32, piece.outline, 1.2, true)
		if piece.text != "":
			if board_font != null:
				draw_arc(point, radius * 0.82, 0, TAU, 32, Color(piece.outline, 0.55), 0.9, true)
				_draw_centered(piece.text, point, int(radius * 1.42), piece.outline)
			else:
				draw_string(ThemeDB.fallback_font, point + Vector2(-radius * 0.5, radius * 0.5),
						piece.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(radius * 1.4), piece.outline)
		if int(cell) == last_cell and last_origin < 0:
			draw_circle(point, maxf(2, radius * 0.15), Color("da8c38"))
	for cell in highlighted:
		draw_arc(cell_position(cell), radius + 3, 0, TAU, 32, Color("3f9f7b"), 2, true)
	if last_origin >= 0:
		draw_arc(cell_position(last_origin), radius * 0.55, 0, TAU, 32, Color("a66b29"), 1.8, true)
		draw_arc(cell_position(last_cell), radius + 2, 0, TAU, 32, Color("a66b29"), 2, true)
	if checked_cell >= 0:
		draw_arc(cell_position(checked_cell), radius + 3, 0, TAU, 32, Color("a0241c"), 3, true)
	if selected_cell >= 0:
		draw_arc(cell_position(selected_cell), radius + 3, 0, TAU, 32, Color("17684e"), 3, true)
	for cell in move_targets:
		var point := cell_position(cell)
		if pieces.has(cell):
			draw_arc(point, radius + 3, 0, TAU, 32, Color("17684e"), 2.5, true)
		else:
			draw_circle(point, maxf(3, radius * 0.22), Color("17684e"), true, -1, true)
	if has_focus() and not blocked:
		draw_rect(Rect2(cell_position(focused_cell) - Vector2.ONE * radius,
				Vector2.ONE * radius * 2), Color("b56823"), false, 2)

func _draw_grid(rect: Rect2, step: float) -> void:
	var ink := Color("60492f")
	var width := 1.6 if uniform_spacing else 1.0
	for column in range(columns):
		var top := cell_position(column)
		var bottom := cell_position((rows - 1) * columns + column)
		if split_after_row >= 0 and column > 0 and column < columns - 1:
			draw_line(top, cell_position(split_after_row * columns + column), ink, width, uniform_spacing)
			draw_line(cell_position((split_after_row + 1) * columns + column), bottom, ink, width, uniform_spacing)
		else:
			draw_line(top, bottom, ink, width, uniform_spacing)
	for row in range(rows):
		draw_line(cell_position(row * columns), cell_position(row * columns + columns - 1), ink, width, uniform_spacing)
	for line in guide_lines:
		draw_line(cell_position(line.x), cell_position(line.y), ink, width, true)
	if not split_labels.is_empty():
		var y := cell_position(split_after_row * columns).y + step * 0.5
		_draw_centered(split_labels[0], Vector2(rect.position.x + rect.size.x * 0.25, y), int(step * 0.45), ink)
		_draw_centered(split_labels[1], Vector2(rect.position.x + rect.size.x * 0.75, y), int(step * 0.45), ink)

func _draw_centered(text: String, point: Vector2, font_size: int, ink: Color) -> void:
	var font := board_font if board_font != null else ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := font.get_ascent(font_size) - font.get_height(font_size) * 0.5
	draw_string(font, point + Vector2(-width / 2, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)

func _gui_input(event: InputEvent) -> void:
	if blocked:
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if selected_cell >= 0 and event.is_pressed() and ((event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT)
			or (event is InputEventKey and event.keycode == KEY_ESCAPE and not event.echo)):
		selection_cancelled.emit()
		accept_event()
		return
	var point: Vector2
	var pointer_pressed := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = event.position
		pointer_pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		point = event.position
		pointer_pressed = true
	if pointer_pressed:
		var cell := cell_at(point)
		if cell >= 0:
			focused_cell = cell
			grab_focus()
			cell_activated.emit(cell)
			queue_redraw()
			accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed or event.meta_pressed or event.alt_pressed:
			return
		var column := focused_cell % columns
		var row: int = focused_cell / columns
		match event.keycode:
			KEY_LEFT: column = maxi(0, column - 1)
			KEY_RIGHT: column = mini(columns - 1, column + 1)
			KEY_UP: row = maxi(0, row - 1)
			KEY_DOWN: row = mini(rows - 1, row + 1)
			KEY_ENTER, KEY_SPACE: cell_activated.emit(focused_cell)
			_: return
		focused_cell = row * columns + column
		queue_redraw()
		accept_event()
