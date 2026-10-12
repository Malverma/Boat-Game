class_name TouchButton
extends Control
## Multi-touch on-screen button (round or rectangular). Tracks its own touch
## index so it works alongside the joystick. Art hook: sprite "ui_btn_<icon_key>".

signal pressed
signal released(drag: Vector2)
signal dragged(drag: Vector2)

var text := ""
var round_shape := true
var color := Color(0.12, 0.22, 0.32, 0.72)
var icon_key := ""
var fish_id := ""          # draws a fish icon instead of an icon sprite
var sub_text := ""
var progress := 1.0        # < 1 draws a reload ring
var highlight := false
var font_size := 20
var text_on_art := true    # draw the label over the icon sprite (under the icon, like the Penpot design)
var _touch := -1
var _start := Vector2.ZERO


func _init(label := "", round_btn := true) -> void:
	text = label
	round_shape = round_btn
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_down() -> bool:
	return _touch != -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_VISIBILITY_CHANGED:
		_touch = -1


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var local := make_input_local(event) as InputEventScreenTouch
		if event.pressed and _touch == -1 and _hit(local.position):
			_touch = event.index
			_start = local.position
			pressed.emit()
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch:
			_touch = -1
			released.emit(local.position - _start)
			queue_redraw()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _touch:
		var local := make_input_local(event) as InputEventScreenDrag
		dragged.emit(local.position - _start)
		get_viewport().set_input_as_handled()


func _hit(p: Vector2) -> bool:
	if round_shape:
		return p.distance_to(size * 0.5) <= size.x * 0.5
	return Rect2(Vector2.ZERO, size).has_point(p)


func _draw() -> void:
	var c := color.lightened(0.25) if is_down() else color
	var center := size * 0.5
	var tex := Art.tex("ui_btn_" + icon_key) if icon_key != "" else null
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, 0.6 if is_down() else 1.0))
		if highlight:
			var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 160.0)
			draw_arc(center, size.x * 0.5 + 3.0, 0, TAU, 48, Color(UIKit.GOLD, pulse), 4.0)
	elif round_shape:
		draw_circle(center, size.x * 0.5, c)
		draw_arc(center, size.x * 0.5 - 1.5, 0, TAU, 48, Color(UIKit.BRASS, 0.9 if highlight else 0.5), 3.0 if highlight else 2.0)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), c)
		draw_rect(Rect2(Vector2.ZERO, size), Color(UIKit.BRASS, 0.95 if highlight else 0.45), false, 3.0 if highlight else 2.0)
	if progress < 1.0:
		var r := size.x * 0.5 - 5.0 if round_shape else minf(size.x, size.y) * 0.4
		draw_arc(center, r, -PI / 2, -PI / 2 + TAU * progress, 48, Color(1, 1, 1, 0.8), 5.0)
		draw_circle(center, r - 3.0, Color(0, 0, 0, 0.35))
	var font := ThemeDB.fallback_font
	var text_y := center.y + font_size * 0.35
	if tex != null:
		text_y = size.y * 0.8   # below the sprite's icon
	if fish_id != "":
		Art.draw_fish(self, fish_id, center + Vector2(0, -size.y * 0.12), minf(size.x, size.y) * 0.7, 0.0, Color.WHITE, true)
		text_y = size.y - 6.0
	if text != "" and (tex == null or text_on_art):
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string_outline(font, Vector2(center.x - w / 2, text_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(center.x - w / 2, text_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UIKit.TEXT)
	if sub_text != "":
		var fs := 14
		var w2 := font.get_string_size(sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(size.x - w2 - 4, fs + 2), sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.GOLD)
