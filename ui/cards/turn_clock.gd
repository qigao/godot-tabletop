class_name TabletopTurnClock
extends Control
## Local active-view policy. The callback always carries its original UI token.

signal expired(token: int)
var remaining := 0.0
var running := false
var suspended := false
var token := 0
var total := 60.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(60, 60)

func start(seconds: float, ticket: int) -> void:
	total = seconds
	remaining = seconds
	token = ticket
	running = true
	queue_redraw()

func _process(delta: float) -> void:
	if not running or suspended:
		return
	remaining = maxf(0, remaining - delta)
	queue_redraw()
	if remaining == 0:
		running = false
		expired.emit(token)

func _draw() -> void:
	var color := Color("eb775e") if remaining <= 10 else Color("e8cb8f")
	if not running:
		color = Color("8196a0")
	draw_circle(Vector2(30, 30), 27, Color("0b2029"))
	draw_arc(Vector2(30, 30), 27, -PI / 2, -PI / 2 + TAU * remaining / maxf(1, total), 48, color, 3, true)
	var text := str(ceili(remaining))
	var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(ThemeDB.fallback_font, Vector2(30 - width / 2, 37), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)
