class_name FishIcon
extends Control
## Small fish picture for lists (sprite "fish_<id>" or placeholder).

var fish_id := ""
var tint := Color.WHITE
var frame_color := Color(0, 0, 0, 0)


func _init(id := "", s := Vector2(72, 44)) -> void:
	fish_id = id
	custom_minimum_size = s
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if frame_color.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))
		draw_rect(Rect2(Vector2.ZERO, size), frame_color, false, 2.0)
	if fish_id != "":
		Art.draw_fish(self, fish_id, size * 0.5, minf(size.x * 0.85, size.y * 1.6), 0.0, tint, true)
