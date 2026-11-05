class_name TabletopSurface
extends PanelContainer

var texture: Texture2D

func _draw() -> void:
	if texture != null:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
