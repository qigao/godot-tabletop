class_name TabletopSurface
extends PanelContainer

var texture: Texture2D
var cover_texture := false

func _draw() -> void:
	if texture == null or size.x <= 0 or size.y <= 0:
		return
	var destination := Rect2(Vector2.ZERO, size)
	if cover_texture:
		var image_size := texture.get_size()
		var scale_factor := maxf(size.x / image_size.x, size.y / image_size.y)
		var crop_size := size / scale_factor
		draw_texture_rect_region(texture, destination, Rect2((image_size - crop_size) / 2, crop_size))
	else:
		draw_texture_rect(texture, destination, false)
