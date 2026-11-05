class_name TabletopCardTableLayout
extends TabletopPresentation
## Card-table components and interaction. No board fields or game transitions.

@export var sections := PackedStringArray(["table", "hand", "actions", "help"])
@export var seat_order := PackedInt32Array()
@export var card_size := Vector2(76, 116)
@export var max_hand_size := 20
@export var max_hand_spread := 1030.0
@export var hand_height := 155.0
@export var table_height := 190.0
@export var minimum_height := 440.0
@export var table_color := Color("112e36")
@export var accent_color := Color("f7c66b")
@export var hand_binding: Dictionary
@export var active_seat_binding: Dictionary
@export var seat_text: Dictionary
@export var status_text: Dictionary
@export var table_text: Dictionary
@export var detail_text: Dictionary
@export var selection_text: Dictionary
@export var help_text: String
@export var actions: Array[Dictionary] = []
@export var numeric_card_keys := true
@export var selection_equivalence: String
