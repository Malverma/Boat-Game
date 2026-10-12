class_name HotSpot
extends Node2D
## Bubbling fishing hot spot (spec §4.2): better rarity odds; relocates over time.

var radius := 3.0 * Data.U
var discovered := false
var _move_t := 0.0
var _bubbles := []


func _ready() -> void:
	relocate()
	for i in 10:
		_bubbles.append({"p": Vector2(randf_range(-1, 1), randf_range(-1, 1)) * radius * 0.7, "t": randf()})


func relocate() -> void:
	var margin := 8.0 * Data.U
	for attempt in 10:   # keep clear of island shores
		position = Vector2(randf_range(margin, Data.WORLD_PX - margin), randf_range(margin, Data.WORLD_PX - margin))
		if Game.world == null or not Game.world.near_island(position, radius + Data.U):
			break
	_move_t = randf_range(100.0, 160.0)
	discovered = false


func _process(delta: float) -> void:
	_move_t -= delta
	if _move_t <= 0.0:
		relocate()
	for b in _bubbles:
		b.t += delta * 0.8
		if b.t > 1.0:
			b.t = 0.0
			b.p = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * radius * 0.7
	queue_redraw()


func _draw() -> void:
	var t := Art.tex("hotspot")
	if t != null:
		Art.draw_tex(self, t, Vector2.ZERO, radius * 2.0)
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 500.0)
	draw_circle(Vector2.ZERO, radius, Color(1, 1, 1, 0.06 + pulse * 0.04))
	draw_arc(Vector2.ZERO, radius * (0.6 + pulse * 0.3), 0, TAU, 32, Color(1, 1, 1, 0.2), 2.0)
	for b in _bubbles:
		draw_arc(b.p, 3.0 + b.t * 6.0, 0, TAU, 12, Color(1, 1, 1, 0.7 * (1.0 - b.t)), 1.5)
