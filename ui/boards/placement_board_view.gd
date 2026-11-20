class_name TabletopPlacementBoardView
extends TabletopGridBoardView
## Placement maps one intersection to a complete move.

func _activate_cell(cell: int) -> void:
	if board.blocked:
		return
	var command: Dictionary = layout.command.duplicate(true)
	command[layout.cell_field] = cell
	for action in _legal:
		if action.command == command:
			request_command(command)
			return
