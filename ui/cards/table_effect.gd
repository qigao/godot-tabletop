class_name TabletopTableEffect
extends Control
## Original vector feedback; event mappings and timing live in the game resource.

var message := ""
var tint := Color("f7c66b")
var burst := false
var progress := 0.0
var _tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func show_message(text: String, color: Color, explosive: bool, seconds: float, reduced: bool) -> void:
	stop()
	message = text
	tint = color
	burst = explosive and not reduced
	progress = 0
	modulate.a = 1
	visible = true
	_tween = create_tween()
	_tween.tween_method(func(value: float) -> void: progress = value; queue_redraw(), 0.0, 1.0, seconds)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, seconds * 0.4).set_delay(seconds * 0.6)
	_tween.tween_callback(hide)

func stop() -> void:
	if _tween != null:
		_tween.kill()
	visible = false

func _draw() -> void:
	var center := size / 2
	if burst:
		for i in range(16):
			var direction := Vector2.from_angle(TAU * i / 16)
			draw_line(center + direction * (25 + progress * 35), center + direction * (55 + progress * 65), tint, 3, true)
	var box := Rect2(center - Vector2(180, 28), Vector2(360, 56))
	draw_style_box(TabletopUI.panel(Color("142d37"), 14), box)
	var width := ThemeDB.fallback_font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	draw_string(ThemeDB.fallback_font, center + Vector2(-width / 2, 9), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, tint)
