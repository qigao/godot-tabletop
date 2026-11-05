class_name TabletopInputScope
extends RefCounted
## One interaction scope per rendered card table, without static ownership.

var hovered: Card = null
signal hover_changed(card: Card)

func enter_hover(card: Card) -> void:
	if hovered != null and hovered != card:
		hovered.change_state(DraggableObject.DraggableState.IDLE)
	hovered = card
	hover_changed.emit(card)

func exit_hover(card: Card) -> void:
	if hovered == card:
		hovered = null
		hover_changed.emit(null)

func release() -> void:
	if hovered != null:
		hovered.change_state(DraggableObject.DraggableState.IDLE)
