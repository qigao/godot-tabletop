class_name TabletopCardRow
extends Control

var media: TabletopMediaPack
var cards: Array = []
var hidden_count := 0
var card_size := Vector2(48, 73)
var caption := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func positions() -> Array[Vector2]:
	var count := cards.size() + hidden_count
	var result: Array[Vector2] = []
	var step := minf(card_size.x + 4, maxf(8, (size.x - card_size.x) / maxi(1, count - 1)))
	var width := card_size.x + step * maxi(0, count - 1)
	for i in range(count):
		result.append(Vector2((size.x - width) / 2 + step * i, 20))
	return result

func _draw() -> void:
	if media == null:
		return
	var font := ThemeDB.fallback_font
	var text_width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, Vector2((size.x - text_width) / 2, 14), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e5edf4"))
	var points := positions()
	for i in range(cards.size()):
		TabletopCardFace.draw(self, Rect2(points[i], card_size), TabletopCardFace.info_for(media, str(cards[i])))
	for i in range(hidden_count):
		draw_texture_rect(media.card_back, Rect2(points[cards.size() + i], card_size), false)
