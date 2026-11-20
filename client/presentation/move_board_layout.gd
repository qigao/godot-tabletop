class_name TabletopMoveBoardLayout
extends TabletopBoardLayout
## A grid with an origin and destination for each move.

@export var origin_field := "from"
@export var destination_field := "to"
@export var last_origin_binding: Dictionary
@export var checked_cell_binding: Dictionary
@export var split_after_row := -1
@export var split_labels := PackedStringArray()
@export var guide_lines: Array[Vector2i] = []
@export var board_font: Font
@export var board_color := Color("c8a776")
