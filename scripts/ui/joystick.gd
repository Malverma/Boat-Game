class_name Joystick
extends Control
## Virtual analog joystick (spec §2.1). Direction = heading, magnitude = throttle.
## Fixed or floating base; configurable dead zone. Art hooks: "ui_joystick_base",
## "ui_joystick_knob".

var radius := 85.0
const CLAIM := 1.6              # touches farther than radius × CLAIM from home are left for cannon taps
var home := Vector2.ZERO        # default base center (local)
var output := Vector2.ZERO
var _base := Vector2.ZERO
var _knob := Vector2.ZERO
var _touch := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func reset() -> void:
	_touch = -1
	_knob = Vector2.ZERO
	output = Vector2.ZERO
	_base = home
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		reset()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var local := make_input_local(event) as InputEventScreenTouch
		if event.pressed and _touch == -1 and _claims(local.position):
			_touch = event.index
			_base = local.position if Game.settings.joystick_mode == "floating" else home
			_update(local.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch:
			reset()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _touch:
		_update((make_input_local(event) as InputEventScreenDrag).position)
		get_viewport().set_input_as_handled()


## Only touches near the stick's home spot steer, so taps elsewhere on the
## joystick's side of the screen still reach the world and fire the cannon.
func _claims(p: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(p) and p.distance_to(home) <= radius * CLAIM


func _update(p: Vector2) -> void:
	_knob = (p - _base).limit_length(radius)
	var m := _knob.length() / radius
	var dz := clampf(float(Game.settings.dead_zone), 0.0, 0.25)
	output = Vector2.ZERO if m <= dz else _knob.normalized() * (m - dz) / (1.0 - dz)
	queue_redraw()


func _draw() -> void:
	var active := _touch != -1
	var c := _base if active else home
	var bt := Art.tex("ui_joystick_base")
	if bt != null:
		draw_texture_rect(bt, Rect2(c - Vector2.ONE * radius, Vector2.ONE * radius * 2), false, Color(1, 1, 1, 0.9 if active else 0.5))
	else:
		draw_circle(c, radius, Color(0, 0, 0, 0.25 if active else 0.15))
		draw_arc(c, radius, 0, TAU, 48, Color(1, 1, 1, 0.5 if active else 0.25), 3.0)
	var kt := Art.tex("ui_joystick_knob")
	var kr := radius * 0.42
	if kt != null:
		draw_texture_rect(kt, Rect2(c + _knob - Vector2.ONE * kr, Vector2.ONE * kr * 2), false)
	else:
		draw_circle(c + _knob, kr, Color(1, 1, 1, 0.55 if active else 0.3))
