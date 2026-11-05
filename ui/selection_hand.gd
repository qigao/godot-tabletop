class_name TabletopSelectionHand
extends Hand
## Local gesture state never changes a match or moves cards between owners.

signal selection_changed(keys: PackedStringArray)
signal drag_preview(keys: PackedStringArray, point: Vector2)
signal drop_requested(keys: PackedStringArray, point: Vector2, token: int)
signal gesture_finished

enum Gesture { TAP, SWEEP, DRAG }
var selected_keys: PackedStringArray = []
var interaction := TabletopCardInteraction.new()
var reduced_motion := false
var client_token := 0
var input_enabled := true
var _hover_key := ""
var _pointer := -1
var _origin := Vector2.ZERO
var _start_key := ""
var _baseline: PackedStringArray = []
var _gesture := Gesture.TAP
var _ticket := 0
var _scope: TabletopInputScope
var _active := true
var _sticky_key := ""
var _hover_rect := Rect2()

func _ready() -> void:
	super._ready()
	_scope = (card_manager as TabletopCardManager).input_scope
	_scope.hover_changed.connect(_hover_changed)

func _hover_changed(card: Card) -> void:
	_hover_key = "" if card == null else card.card_name
	if card == null:
		_sticky_key = ""
	if _active:
		update_card_ui()

func _compute_pose(index: int, count: int, spacing: float, anchor: float) -> Dictionary:
	var pose := super._compute_pose(index, count, spacing, anchor)
	var card: Card = _held_cards[index]
	if selected_keys.has(card.card_name):
		pose.position.y -= interaction.selection_lift
	var hovered := -1
	for i in range(_held_cards.size()):
		if _held_cards[i].card_name == _hover_key:
			hovered = i
	if hovered >= 0:
		if index == hovered:
			pose.position.y -= interaction.hover_lift
			pose.rotation = 0.0
		else:
			pose.position.x += signi(index - hovered) * interaction.hover_spread * (1.0 - float(abs(index - hovered)) / maxi(1, count))
	return pose

func _update_card_states() -> void:
	super._update_card_states()
	for card in _held_cards:
		card.can_be_interacted_with = input_enabled
		card.focus_mode = Control.FOCUS_ALL if input_enabled else Control.FOCUS_NONE

func _find_and_register_card_manager() -> void:
	card_manager = get_parent() as CardManager
	assert(card_manager != null)
	card_manager._add_card_container(unique_id, self)

func on_card_pressed(card: Card) -> void:
	var keys := selected_keys.duplicate()
	if keys.has(card.card_name):
		keys.remove_at(keys.find(card.card_name))
	else:
		keys.append(card.card_name)
	set_selection(keys)

func set_selection(keys: PackedStringArray) -> void:
	selected_keys = keys.duplicate()
	refresh_selection_visuals()
	selection_changed.emit(selected_keys.duplicate())

func refresh_selection_visuals() -> void:
	for card in _held_cards:
		(card as TabletopPlayingCard).selected = selected_keys.has(card.card_name)
	update_card_ui()

func sync_cards(keys: PackedStringArray, factory: TabletopCardFactory, origin: Vector2, animate_new: bool) -> void:
	var existing: Dictionary = {}
	for card in _held_cards.duplicate():
		if keys.has(card.card_name):
			existing[card.card_name] = card
		else:
			_held_cards.erase(card)
			cards_node.remove_child(card)
			card.queue_free()
	for key in keys:
		if not existing.has(key):
			var card := factory.create_card(key, self) as TabletopPlayingCard
			card.snap_to(origin)
	_held_cards.sort_custom(func(a: Card, b: Card) -> bool: return keys.find(a.card_name) < keys.find(b.card_name))
	update_card_ui()
	if not animate_new:
		for card in _held_cards:
			(card as TabletopPlayingCard).snap_to(get_target_pose_for(card).position)

func clear_selection() -> void:
	cancel_pointer()
	set_selection([])

func focus_neighbour(card: Card, direction: int, extend: bool = false) -> void:
	var index := _held_cards.find(card)
	var target: Card = _held_cards[posmod(index + direction, _held_cards.size())]
	if extend and interaction.keyboard_range:
		var keys := selected_keys.duplicate()
		for item in [card, target]:
			if not keys.has(item.card_name):
				keys.append(item.card_name)
		set_selection(keys)
	target.grab_focus()

func begin_pointer(card: Card, point: Vector2, pointer: int) -> void:
	if not input_enabled or _pointer != -1:
		return
	_pointer = pointer
	card.grab_focus()
	_origin = point
	_start_key = card.card_name
	_baseline = selected_keys.duplicate()
	_ticket = client_token
	_gesture = Gesture.TAP
	on_card_pressed(card)

func route_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseMotion and _pointer == -1:
		var card := card_at((card_manager as Control).get_global_transform_with_canvas() * event.position)
		if card != null:
			var entry := _painted_rect(card)
			card.change_state(DraggableObject.DraggableState.HOVERING)
			_sticky_key = card.card_name
			_hover_rect = entry.merge(_painted_rect(card))
		else:
			_scope.release()
	elif event is InputEventMouseButton:
		var point: Vector2 = (card_manager as Control).get_global_transform_with_canvas() * event.position
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and interaction.clear_with_right_click:
			clear_selection()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var card := card_at(point)
			if card != null:
				begin_pointer(card, point, -2)
		(card_manager as Control).accept_event()
	elif event is InputEventScreenTouch:
		var point: Vector2 = (card_manager as Control).get_global_transform_with_canvas() * event.position
		if event.pressed:
			var card := card_at(point)
			if card != null:
				begin_pointer(card, point, event.index)
		(card_manager as Control).accept_event()

func card_at(point: Vector2) -> Card:
	# Keep a hover target anchored while expansion animates it away from the
	# original pointer. Other hits follow the actual painted order and transforms,
	# including raised selections; fixed unexpanded slots cannot do that correctly.
	if _scope.hovered != null and _scope.hovered.card_name == _sticky_key \
			and _hover_rect.merge(_painted_rect(_scope.hovered)).has_point(point):
		return _scope.hovered
	var ordered := _held_cards.duplicate()
	ordered.sort_custom(func(a: Card, b: Card) -> bool: return a.z_index > b.z_index)
	for card in ordered:
		var local: Vector2 = card.get_global_transform_with_canvas().affine_inverse() * point
		if Rect2(Vector2.ZERO, card.card_size).has_point(local):
			return card
	return null

func _painted_rect(card: Card) -> Rect2:
	var transform := card.get_global_transform_with_canvas()
	var rect := Rect2(transform * Vector2.ZERO, Vector2.ZERO)
	for corner in [Vector2(card.card_size.x, 0), card.card_size, Vector2(0, card.card_size.y)]:
		rect = rect.expand(transform * corner)
	return rect

func pointer_left() -> void:
	if _pointer == -1:
		_scope.release()

func move_pointer(point: Vector2, pointer: int) -> void:
	if pointer != _pointer or _pointer == -1:
		return
	var delta := point - _origin
	if _gesture == Gesture.TAP and delta.length() >= interaction.pointer_threshold:
		if interaction.drag_to_play and delta.y < -interaction.pointer_threshold and abs(delta.y) > abs(delta.x):
			_gesture = Gesture.DRAG
			set_selection(_baseline if _baseline.has(_start_key) else PackedStringArray([_start_key]))
		elif interaction.sweep_selection:
			_gesture = Gesture.SWEEP
	if _gesture == Gesture.SWEEP:
		var first := _index_of(_start_key)
		var last := _index_at_x(point.x)
		var keys := _baseline.duplicate()
		for i in range(mini(first, last), maxi(first, last) + 1):
			var key: String = _held_cards[i].card_name
			if _baseline.has(_start_key):
				if keys.has(key):
					keys.remove_at(keys.find(key))
			elif not keys.has(key):
				keys.append(key)
		set_selection(keys)
		if interaction.drag_to_play and delta.y < -card_manager.card_size.y * 0.65:
			_gesture = Gesture.DRAG
	if _gesture == Gesture.DRAG:
		drag_preview.emit(selected_keys.duplicate(), point)

func end_pointer(point: Vector2, pointer: int) -> void:
	if pointer != _pointer or _pointer == -1:
		return
	var drag := _gesture == Gesture.DRAG
	var keys := selected_keys.duplicate()
	var ticket := _ticket
	_pointer = -1
	_gesture = Gesture.TAP
	if drag:
		drop_requested.emit(keys, point, ticket)
	gesture_finished.emit()

func cancel_pointer() -> void:
	if _pointer != -1:
		_pointer = -1
		_gesture = Gesture.TAP
		set_selection(_baseline)
	gesture_finished.emit()

func _input(event: InputEvent) -> void:
	if _pointer == -1:
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseMotion and _pointer == -2:
		move_pointer(event.position, -2)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and interaction.clear_with_right_click:
		clear_selection()
	elif event is InputEventMouseButton and _pointer == -2 and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		end_pointer(event.position, -2)
	elif event is InputEventScreenDrag:
		move_pointer(event.position, event.index)
	elif event is InputEventScreenTouch and not event.pressed:
		if event.canceled and event.index == _pointer:
			cancel_pointer()
		else:
			end_pointer(event.position, event.index)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		clear_selection()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_pointer()

func _index_of(key: String) -> int:
	for i in range(_held_cards.size()):
		if _held_cards[i].card_name == key:
			return i
	assert(false, "Pointer card must remain in its owning hand")
	return -1

func _index_at_x(x: float) -> int:
	# Partition by exposed left edges, rather than card centers: cards overlap.
	var best := 0
	for i in range(_held_cards.size()):
		var pose := get_target_pose_for(_held_cards[i])
		if x >= pose.position.x:
			best = i
	return best

func deactivate() -> void:
	if not _active:
		return
	cancel_pointer()
	_active = false
	_scope.hover_changed.disconnect(_hover_changed)

func _card_can_be_added(_cards: Array) -> bool:
	return false
