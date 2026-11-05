class_name TabletopPlayingCard
extends Card

var input_scope: TabletopInputScope
var selected := false:
	set(value):
		selected = value
		queue_redraw()
var _pose_tween: Tween

func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(func() -> void: change_state(DraggableState.HOVERING); queue_redraw())
	focus_exited.connect(func() -> void: change_state(DraggableState.IDLE); queue_redraw())

func _draw() -> void:
	TabletopCardFace.draw(self, Rect2(Vector2.ZERO, card_size), card_info, selected, has_focus())

func _on_gui_input(event: InputEvent) -> void:
	if not can_be_interacted_with:
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var hand := card_container as TabletopSelectionHand
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if hand.interaction.clear_with_right_click:
				hand.clear_selection()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				hand.begin_pointer(self, get_global_transform_with_canvas() * event.position, -2)
			else:
				hand.end_pointer(get_global_transform_with_canvas() * event.position, -2)
			accept_event()
	elif event is InputEventScreenTouch:
		if event.canceled:
			hand.cancel_pointer()
		elif event.pressed:
			hand.begin_pointer(self, get_global_transform_with_canvas() * event.position, event.index)
		else:
			hand.end_pointer(get_global_transform_with_canvas() * event.position, event.index)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed or event.meta_pressed or event.alt_pressed:
			return
		match event.keycode:
			KEY_ENTER, KEY_SPACE: hand.on_card_pressed(self)
			KEY_LEFT, KEY_RIGHT:
				hand.focus_neighbour(self, -1 if event.keycode == KEY_LEFT else 1, event.shift_pressed)
			KEY_ESCAPE: hand.clear_selection()
			_: return
		accept_event()

func move(target: Vector2, degree: float) -> void:
	# Presentation motion does not put cards into the addon's unclickable MOVING state.
	# This keeps fast clicks, range selection and hover expansion responsive.
	if _pose_tween != null:
		_pose_tween.kill()
	original_destination = target
	original_rotation = degree
	var hand := card_container as TabletopSelectionHand
	var hovered := input_scope.hovered == self
	z_index = stored_z_index + (100 if hovered else (30 if selected else 0))
	var target_scale := Vector2.ONE * (hand.interaction.hover_scale if hovered else 1.0)
	var seconds := 0.0 if hand.reduced_motion else hand.interaction.move_seconds
	if seconds == 0:
		global_position = target
		rotation = degree
		scale = target_scale
		return
	_pose_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(self, "global_position", target, seconds)
	_pose_tween.tween_property(self, "rotation", degree, seconds)
	_pose_tween.tween_property(self, "scale", target_scale, seconds)

func snap_to(point: Vector2) -> void:
	if _pose_tween != null:
		_pose_tween.kill()
	global_position = point

func _start_hover_animation() -> void:
	pass # The owning hand composes fan, hover and selection in one pose.

func _stop_hover_animation() -> void:
	pass

func _can_start_hovering() -> bool:
	return true

func _enter_state(state: DraggableState, from_state: DraggableState) -> void:
	if state == DraggableState.HOVERING:
		input_scope.enter_hover(self)
	super._enter_state(state, from_state)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _exit_state(state: DraggableState) -> void:
	if state == DraggableState.HOVERING:
		input_scope.exit_hover(self)
	super._exit_state(state)

func _exit_tree() -> void:
	if _pose_tween != null:
		_pose_tween.kill()
	change_state(DraggableState.IDLE)
