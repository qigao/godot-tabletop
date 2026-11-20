class_name TabletopCardFace
extends RefCounted
## The same configured face is used by the hand, public rows and motion ghosts.

const HEART := [
	Vector2(0, 0.95), Vector2(-0.76, 0.23), Vector2(-0.98, -0.15),
	Vector2(-0.93, -0.46), Vector2(-0.72, -0.71), Vector2(-0.39, -0.78),
	Vector2(0, -0.52), Vector2(0.39, -0.78), Vector2(0.72, -0.71),
	Vector2(0.93, -0.46), Vector2(0.98, -0.15), Vector2(0.76, 0.23),
]
const DIAMOND := [Vector2(0, -1), Vector2(0.82, 0), Vector2(0, 1), Vector2(-0.82, 0)]
const STEM := [Vector2(-0.19, 0.35), Vector2(0.19, 0.35), Vector2(0.43, 0.97), Vector2(-0.43, 0.97)]

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
	if info.pip.is_empty():
		canvas.draw_string(font, Vector2(7, 48), info.symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, info.ink)
	else:
		_draw_pip(canvas, info.pip, Vector2(13, 39), 7, info.ink)
		_draw_pip(canvas, info.pip, Vector2(38, 72), 14, info.ink)
	if selected:
		canvas.draw_circle(Vector2(63, 14), 5, Color("d49a37"))
	canvas.draw_set_transform(Vector2.ZERO)

static func _draw_pip(canvas: CanvasItem, shape: String, center: Vector2, radius: float, ink: Color) -> void:
	match shape:
		"diamond":
			_draw_pip_polygon(canvas, DIAMOND, center, radius, ink)
		"heart":
			_draw_pip_polygon(canvas, HEART, center, radius, ink)
		"spade":
			_draw_pip_polygon(canvas, HEART, center, radius, ink, true)
			_draw_pip_polygon(canvas, STEM, center, radius, ink)
		"club":
			for lobe in [Vector2(0, -0.51), Vector2(-0.5, 0.14), Vector2(0.5, 0.14)]:
				canvas.draw_circle(center + lobe * radius, 0.48 * radius, ink, true, -1, true)
			_draw_pip_polygon(canvas, STEM, center, radius, ink)
		_:
			assert(false, "Unknown suit pip: " + shape)

static func _draw_pip_polygon(canvas: CanvasItem, outline: Array, center: Vector2, radius: float, ink: Color, flip_y: bool = false) -> void:
	var polygon := PackedVector2Array()
	var scale := Vector2(radius, -radius if flip_y else radius)
	for point: Vector2 in outline:
		polygon.append(center + point * scale)
	canvas.draw_colored_polygon(polygon, ink)

static func info_for(media: TabletopMediaPack, key: String) -> Dictionary:
	var info: Dictionary = media.cards[key].duplicate()
	info.face_texture = media.card_face
	info.artwork = media.card_artwork.get(key)
	info.pip = media.suit_pips.get(info.symbol, "")
	return info
