class_name Fx
extends Node2D
## Short-lived impact effect. Art hook: a sprite "fx_<kind>" replaces the vector
## drawing (scaled to the radius, fading out).
## Kinds: splash, boom, spines, ice, ink, lightning, sparkle, slam.

var kind := "splash"
var radius := 16.0
var color := Color.WHITE
var to := Vector2.ZERO     # lightning end point (local)
var life := 0.5
var _t := 0.0
var _seed := 0


func _ready() -> void:
	_seed = randi()
	if kind == "ink":
		life = 1.2


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / life
	var a := 1.0 - k
	var tex := Art.tex("fx_" + kind)
	if tex != null:
		Art.draw_tex(self, tex, Vector2.ZERO, radius * 2.0 * (0.6 + k * 0.6), 0.0, Color(1, 1, 1, a))
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	match kind:
		"splash":
			draw_arc(Vector2.ZERO, radius * (0.3 + k), 0, TAU, 24, Color(0.85, 0.95, 1.0, a), 3.0)
			draw_arc(Vector2.ZERO, radius * (0.1 + k * 0.6), 0, TAU, 16, Color(0.85, 0.95, 1.0, a * 0.6), 2.0)
		"boom", "slam":
			draw_circle(Vector2.ZERO, radius * (0.4 + k * 0.6), Color(color, a * 0.6))
			draw_circle(Vector2.ZERO, radius * (0.2 + k * 0.4), Color(1.0, 0.95, 0.6, a * 0.8))
			draw_arc(Vector2.ZERO, radius * (0.5 + k * 0.7), 0, TAU, 32, Color(color, a), 3.0)
		"spines":
			for i in 12:
				var d := Vector2.RIGHT.rotated(TAU * i / 12.0)
				draw_line(d * radius * k * 0.5, d * radius * (0.3 + k), Color(color, a), 2.0)
		"ice":
			for i in 8:
				var d := Vector2.RIGHT.rotated(rng.randf() * TAU)
				var r := radius * (0.3 + rng.randf() * 0.7)
				draw_line(d * r * k * 0.3, d * r, Color(0.8, 0.95, 1.0, a), 3.0)
			draw_circle(Vector2.ZERO, radius * 0.5, Color(0.7, 0.9, 1.0, a * 0.3))
		"ink":
			for i in 9:
				var p := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * radius * 0.6
				draw_circle(p, radius * (0.25 + rng.randf() * 0.25) * (0.6 + k * 0.5), Color(0.06, 0.04, 0.1, a * 0.8))
		"lightning":
			var pts := PackedVector2Array([Vector2.ZERO])
			for i in range(1, 7):
				var p := to * (i / 7.0)
				pts.append(p + to.orthogonal().normalized() * rng.randf_range(-10, 10))
			pts.append(to)
			draw_polyline(pts, Color(1.0, 1.0, 0.5, a), 3.0)
			draw_polyline(pts, Color(1, 1, 1, a), 1.0)
		"sparkle":
			for i in 8:
				var d := Vector2.RIGHT.rotated(rng.randf() * TAU) * radius * (0.3 + k)
				draw_circle(d, 3.0 * a, Color(color, a))
