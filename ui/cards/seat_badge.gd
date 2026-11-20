class_name TabletopSeatBadge
extends Control

var label: Label
var role: Label
var active := false
var count := 0
var concealed := false
var media: TabletopMediaPack
var seat := 0
var callout := ""
var accent_color := Color("f7c66b")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(180, 94)
	label = TabletopUI.label("", 15)
	label.position = Vector2(57, 3)
	label.size = Vector2(117, 49)
	add_child(label)
	role = TabletopUI.label("", 12)
	role.position = Vector2(57, 52)
	role.size = Vector2(117, 25)
	add_child(role)

func _draw() -> void:
	var accent := accent_color if active else Color("708479")
	var plate := &"active" if active else &"idle"
	if has_theme_stylebox(plate, &"TabletopSeatBadge"):
		draw_style_box(get_theme_stylebox(plate, &"TabletopSeatBadge"), Rect2(Vector2.ZERO, size))
	if media.portraits.has(str(seat)):
		draw_rect(Rect2(Vector2(7, 7), Vector2(44, 44)), accent)
		draw_texture_rect(media.portraits[str(seat)], Rect2(Vector2(9, 9), Vector2(40, 40)), false)
	else:
		draw_circle(Vector2(29, 29), 21, accent)
		draw_circle(Vector2(29, 24), 7, Color("142d37"))
		draw_arc(Vector2(29, 40), 11, PI, TAU, 16, Color("142d37"), 6, true)
	if concealed and count > 0:
		for i in range(mini(3, count)):
			draw_texture_rect(media.card_back, Rect2(Vector2(8 + i * 7, 57), Vector2(19, 29)), false)
	if callout != "":
		draw_string(ThemeDB.fallback_font, Vector2(57, 86), callout, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, accent_color)
