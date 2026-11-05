extends TabletopGameView

var board: TabletopBoardCanvas
var status: Label
var detail: Label

func _ready() -> void:
	custom_minimum_size.y = 380
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	status = TabletopUI.label("", 24)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(status)
	board = TabletopBoardCanvas.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.cell_activated.connect(func(cell: int) -> void: request_command({"type": "place", "cell": cell}))
	column.add_child(board)
	detail = TabletopUI.label("", 14)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(detail)
	var help := TabletopUI.label("Click / tap an intersection  |  Arrow keys + Enter  |  Freestyle: five or more wins", 12)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(help)

func render(view: Dictionary, _legal: Array[Dictionary]) -> void:
	status.text = "%s to move" % ("Black" if view.turn == 0 else "White")
	if view.phase == "finished":
		status.text = "Draw" if view.winner == -1 else ("Black wins" if view.winner == 0 else "White wins")
	detail.text = "%d moves  /  15 x 15  /  Local hotseat" % view.moves
	board.pieces.clear()
	for cell in range(view.board.size()):
		if view.board[cell] != -1:
			board.pieces[cell] = {"fill": Color("202936") if view.board[cell] == 0 else Color("fffaf0"),
					"outline": Color("111925") if view.board[cell] == 0 else Color("8a775e"), "text": ""}
	board.last_cell = view.last_cell
	board.highlighted = view.winning_cells.duplicate()
	board.blocked = blocked or view.phase == "finished"
	board.queue_redraw()

func deactivate() -> void:
	board.blocked = true
