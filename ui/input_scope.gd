class_name TabletopInputScope
extends RefCounted
## One interaction scope per rendered card table, without static ownership.

var hovered: Card = null

func enter_hover(card: Card) -> void:
	if hovered != null and hovered != card:
		hovered.change_state(DraggableObject.DraggableState.IDLE)
	hovered = card

func exit_hover(card: Card) -> void:
	if hovered == card:
		hovered = null

func release() -> void:
	if hovered != null:
		hovered.change_state(DraggableObject.DraggableState.IDLE)
