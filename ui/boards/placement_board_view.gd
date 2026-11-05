class_name TabletopPlacementBoardView
extends TabletopGameView
## Board-family placement view. Card hand/action layout is a separate component.

var layout: TabletopBoardLayout
var board: TabletopBoardCanvas
var status: Label
var detail: Label
var _legal: Array[Dictionary] = []

func _ready() -> void:
	super._ready()
	layout = configuration as TabletopBoardLayout
	assert(layout != null, "Board view requires a board layout")
	custom_minimum_size.y = layout.minimum_height
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	status = TabletopUI.label("", 24)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(status)
	board = TabletopBoardCanvas.new()
	board.columns = layout.columns
	board.rows = layout.rows
	board.table_texture = layout.media.table_texture
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.cell_activated.connect(_activate_cell)
	column.add_child(board)
	detail = TabletopUI.label("", 14)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(detail)
	var help := TabletopUI.label(layout.help_text, 12)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)

func render(observation: Dictionary, legal: Array[Dictionary]) -> void:
	_legal = legal
	var context := binding_context(observation)
	status.text = str(TabletopBinding.read(layout.status_text, context))
	detail.text = str(TabletopBinding.read(layout.detail_text, context))
	var cells: Array = TabletopBinding.read(layout.cells_binding, context)
	assert(cells.size() == layout.columns * layout.rows)
	board.pieces.clear()
	for cell in range(cells.size()):
		if cells[cell] != layout.empty_piece:
			board.pieces[cell] = layout.media.pieces[str(cells[cell])].duplicate()
	board.last_cell = TabletopBinding.read(layout.last_cell_binding, context)
	board.highlighted = TabletopBinding.read(layout.highlight_binding, context).duplicate()
	board.blocked = blocked or TabletopBinding.read(layout.blocked_binding, context)
	board.queue_redraw()

func _activate_cell(cell: int) -> void:
	var command: Dictionary = layout.command.duplicate(true)
	command[layout.cell_field] = cell
	for action in _legal:
		if action.command == command:
			request_command(command)
			return

func deactivate() -> void:
	board.blocked = true
	cues.stop()
