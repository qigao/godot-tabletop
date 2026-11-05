class_name TabletopCardFace
extends RefCounted
## The same configured face is used by the hand, public rows and motion ghosts.

static func draw(canvas: CanvasItem, rect: Rect2, info: Dictionary, selected: bool = false, focused: bool = false) -> void:
	canvas.draw_set_transform(rect.position, 0, rect.size / Vector2(76, 116))
	var box := StyleBoxFlat.new()
	box.bg_color = Color("fffaf0")
	box.border_color = Color("f7c66b") if selected else Color("cad1da")
	if focused and not selected:
		box.border_color = Color("76c5df")
	box.set_border_width_all(3 if selected or focused else 1)
	box.set_corner_radius_all(7)
	canvas.draw_style_box(box, Rect2(Vector2.ZERO, Vector2(76, 116)))
	if info.face_texture != null:
		canvas.draw_texture_rect(info.face_texture, Rect2(Vector2.ZERO, Vector2(76, 116)), false)
		box.bg_color = Color.TRANSPARENT
		canvas.draw_style_box(box, Rect2(Vector2.ZERO, Vector2(76, 116)))
	if info.artwork != null:
		canvas.draw_texture_rect(info.artwork, Rect2(Vector2(8, 55), Vector2(60, 51)), false)
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(7, 25), info.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, info.ink)
	canvas.draw_string(font, Vector2(7, 48), info.symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, info.ink)
	if selected:
		canvas.draw_circle(Vector2(63, 14), 5, Color("d49a37"))
	canvas.draw_set_transform(Vector2.ZERO)

static func info_for(media: TabletopMediaPack, key: String) -> Dictionary:
	var info: Dictionary = media.cards[key].duplicate()
	info.face_texture = media.card_face
	info.artwork = media.card_artwork.get(key)
	return info
