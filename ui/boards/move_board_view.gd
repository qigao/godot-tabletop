class_name TabletopMoveBoardView
extends TabletopGridBoardView
## Select an origin, then submit a destination supplied by the active rules.

var move_layout: TabletopMoveBoardLayout
var _destinations: Dictionary = {}
var _selection_token := -1

func _ready() -> void:
	super._ready()
	move_layout = configuration as TabletopMoveBoardLayout
	assert(move_layout != null, "Move board view requires a move board layout")
	board.uniform_spacing = true
	board.split_after_row = move_layout.split_after_row
	board.split_labels = move_layout.split_labels
	board.guide_lines = move_layout.guide_lines
	board.board_font = move_layout.board_font
	board.board_color = move_layout.board_color
	board.selection_cancelled.connect(_select.bind(-1))

func render(observation: Dictionary, legal: Array[Dictionary]) -> void:
	super.render(observation, legal)
	var context := binding_context(observation)
	board.last_origin = TabletopBinding.read(move_layout.last_origin_binding, context)
	board.checked_cell = TabletopBinding.read(move_layout.checked_cell_binding, context)
	_destinations.clear()
	for action in legal:
		var command: Dictionary = action.command
		var origin: int = command[move_layout.origin_field]
		var destination: int = command[move_layout.destination_field]
		if not _destinations.has(origin):
			_destinations[origin] = {}
		assert(not _destinations[origin].has(destination), "Move board requires one command per origin and destination")
		_destinations[origin][destination] = command
	if _selection_token != frame_token or board.blocked:
		_select(-1)
	_selection_token = frame_token

func _activate_cell(cell: int) -> void:
	if board.blocked:
		return
	if cell == board.selected_cell:
		_select(-1)
		return
	if board.selected_cell >= 0:
		var targets: Dictionary = _destinations[board.selected_cell]
		if targets.has(cell):
			request_command(targets[cell].duplicate(true))
			return
	if _destinations.has(cell):
		_select(cell)

func _select(cell: int) -> void:
	board.selected_cell = cell
	var targets: Dictionary = _destinations.get(cell, {})
	board.move_targets = PackedInt32Array(targets.keys())
	board.queue_redraw()

func deactivate() -> void:
	_select(-1)
	super.deactivate()
