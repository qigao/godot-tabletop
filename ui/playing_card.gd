class_name TabletopPlayingCard
extends Card

var input_scope: TabletopInputScope

var selected := false:
	set(value):
		selected = value
		queue_redraw()

func _ready() -> void:
	super._ready()
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(func() -> void: change_state(DraggableState.HOVERING))
	focus_exited.connect(func() -> void: change_state(DraggableState.IDLE))

func _draw() -> void:
	var shape := StyleBoxFlat.new()
	shape.bg_color = Color("fffaf0")
	shape.border_color = Color("f7c66b") if selected else Color("cad1da")
	shape.set_border_width_all(4 if selected else 1)
	shape.set_corner_radius_all(9)
	draw_style_box(shape, Rect2(Vector2.ZERO, card_size))
	if card_info.face_texture != null:
		draw_texture_rect(card_info.face_texture, Rect2(Vector2.ZERO, card_size), false)
		shape.bg_color = Color.TRANSPARENT
		draw_style_box(shape, Rect2(Vector2.ZERO, card_size))
	if card_info.artwork != null:
		draw_texture_rect(card_info.artwork, Rect2(Vector2(8, 55), card_size - Vector2(16, 65)), false)
	var ink: Color = card_info.ink
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(7, 25), card_info.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, ink)
	draw_string(font, Vector2(7, 48), card_info.symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, ink)
	if selected:
		draw_circle(Vector2(card_size.x - 13, 14), 5, Color("d49a37"))

func _handle_mouse_pressed() -> void:
	card_container.on_card_pressed(self)

func _on_gui_input(event: InputEvent) -> void:
	if not can_be_interacted_with:
		return
	# Buttons use emulated mouse input; cards handle the original touch once.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch and event.pressed:
		card_container.on_card_pressed(self)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_SPACE]:
			card_container.on_card_pressed(self)
			accept_event()
		elif event.keycode in [KEY_LEFT, KEY_RIGHT]:
			card_container.focus_neighbour(self, -1 if event.keycode == KEY_LEFT else 1)
			accept_event()
	else:
		super._on_gui_input(event)

func _can_start_hovering() -> bool:
	return true

func _enter_state(state: DraggableState, from_state: DraggableState) -> void:
	if state == DraggableState.HOVERING:
		input_scope.enter_hover(self)
	super._enter_state(state, from_state)

func _exit_state(state: DraggableState) -> void:
	if state == DraggableState.HOVERING:
		input_scope.exit_hover(self)
	super._exit_state(state)

func _exit_tree() -> void:
	# Upstream's hover counters are static; balance state when a hand is replaced.
	change_state(DraggableState.IDLE)
