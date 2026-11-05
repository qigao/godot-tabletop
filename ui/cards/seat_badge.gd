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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(180, 94)
	label = TabletopUI.label("", 15)
	label.position = Vector2(47, 0)
	label.size = Vector2(133, 50)
	add_child(label)
	role = TabletopUI.label("", 12)
	role.position = Vector2(47, 53)
	role.size = Vector2(133, 25)
	add_child(role)

func _draw() -> void:
	var accent := Color("f7c66b") if active else Color("587580")
	draw_circle(Vector2(20, 22), 21, accent)
	if media.portraits.has(str(seat)):
		draw_texture_rect(media.portraits[str(seat)], Rect2(Vector2(1, 3), Vector2(38, 38)), false)
	else:
		draw_circle(Vector2(20, 17), 7, Color("142d37"))
		draw_arc(Vector2(20, 33), 11, PI, TAU, 16, Color("142d37"), 6, true)
	if concealed and count > 0:
		for i in range(mini(3, count)):
			draw_texture_rect(media.card_back, Rect2(Vector2(1 + i * 7, 53), Vector2(19, 29)), false)
	if callout != "":
		draw_string(ThemeDB.fallback_font, Vector2(47, 91), callout, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f7c66b"))
