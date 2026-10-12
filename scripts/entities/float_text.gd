class_name FloatText
extends Node2D
## Rising, fading text (damage numbers, pickups).

var text := ""
var color := Color.WHITE
var size := 20
var life := 0.9
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	position.y -= 40.0 * delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var a := clampf(1.0 - (_t / life) * (_t / life), 0.0, 1.0)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(font, Vector2(-w / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, a * 0.8))
	draw_string(font, Vector2(-w / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, a))
