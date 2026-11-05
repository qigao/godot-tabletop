class_name TabletopCardInteraction
extends Resource
## Conventional hand interactions, independently configurable per card game.

@export var sweep_selection := true
@export var drag_to_play := false
@export var drop_action: String
@export var pointer_threshold := 12.0
@export var selection_lift := 22.0
@export var hover_lift := 16.0
@export var hover_spread := 40.0
@export var hover_scale := 1.05
@export var move_seconds := 0.14
@export var clear_with_right_click := true
@export var keyboard_range := true
