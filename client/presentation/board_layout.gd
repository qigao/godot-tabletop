class_name TabletopBoardLayout
extends TabletopPresentation
## Independent board-family placement configuration.

@export var columns := 15
@export var rows := 15
@export var minimum_height := 380.0
@export var empty_piece := -1
@export var cells_binding: Dictionary
@export var last_cell_binding: Dictionary
@export var highlight_binding: Dictionary
@export var blocked_binding: Dictionary
@export var status_text: Dictionary
@export var detail_text: Dictionary
@export var help_text: String
@export var command: Dictionary
@export var cell_field := "cell"
