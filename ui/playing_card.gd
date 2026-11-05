class_name TabletopPlayingCard
extends Card

const Cards = preload("res://games/doudizhu/cards.gd")

var selected := false:
	set(value):
		selected = value
		queue_redraw()

func _draw() -> void:
	var shape := StyleBoxFlat.new()
	shape.bg_color = Color("fffaf0")
	shape.border_color = Color("f7c66b") if selected else Color("cad1da")
	shape.set_border_width_all(4 if selected else 1)
	shape.set_corner_radius_all(9)
	draw_style_box(shape, Rect2(Vector2.ZERO, card_size))
	var id := int(card_info.id)
	var ink := Color("b93446") if id % 4 in [1, 3] or id == 53 else Color("17263b")
	var text := Cards.label(id)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(8, 30), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
	draw_string(font, Vector2(8, card_size.y - 12), "SELECTED" if selected else "TABLETOP",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, ink)
	if selected:
		draw_circle(Vector2(card_size.x - 13, 14), 5, Color("d49a37"))

func _handle_mouse_pressed() -> void:
	card_container.on_card_pressed(self)

func _exit_tree() -> void:
	# Upstream's hover counters are static; balance state when a hand is replaced.
	change_state(DraggableState.IDLE)
