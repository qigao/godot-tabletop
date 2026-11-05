class_name TabletopBoardCanvas
extends Control
## A reusable intersection grid. Adapters decide what a cell click means.

signal cell_activated(cell: int)

var columns := 15
var rows := 15
var pieces: Dictionary = {}
var highlighted: Array = []
var last_cell := -1
var focused_cell := -1
var blocked := false
var table_texture: Texture2D

func _ready() -> void:
	focused_cell = int(rows / 2) * columns + int(columns / 2)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(280, 280)
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func board_rect() -> Rect2:
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
	draw_style_box(TabletopUI.panel(Color("c8a776"), 12), rect.grow(14))
	if table_texture != null:
		draw_texture_rect(table_texture, rect.grow(14), false)
	for column in range(columns):
		draw_line(cell_position(column), cell_position((rows - 1) * columns + column), Color("60492f"), 1)
	for row in range(rows):
		draw_line(cell_position(row * columns), cell_position(row * columns + columns - 1), Color("60492f"), 1)
	var radius := minf(rect.size.x / (columns - 1), rect.size.y / (rows - 1)) * 0.42
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
			draw_string(ThemeDB.fallback_font, point + Vector2(-radius * 0.5, radius * 0.5),
					piece.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(radius * 1.4), piece.outline)
		if int(cell) == last_cell:
			draw_circle(point, maxf(2, radius * 0.15), Color("da8c38"))
	for cell in highlighted:
		draw_arc(cell_position(cell), radius + 3, 0, TAU, 32, Color("3f9f7b"), 2, true)
	if has_focus() and not blocked:
		draw_rect(Rect2(cell_position(focused_cell) - Vector2.ONE * radius,
				Vector2.ONE * radius * 2), Color("b56823"), false, 2)

func _gui_input(event: InputEvent) -> void:
	if blocked:
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
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
