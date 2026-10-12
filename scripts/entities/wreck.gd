class_name Wreck
extends Node2D
## Floating wreck left by a sunk pirate (spec §7.6). Sail over it within 20 s to loot.

const LIFETIME := 20.0

var gold := 0
var fish: Array = []
var life := LIFETIME
var pickup_radius := 2.0 * Data.U


func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	visible = life > 5.0 or fmod(life, 0.4) > 0.2
	queue_redraw()


func _draw() -> void:
	var t := Art.tex("wreck")
	var bob := sin(Time.get_ticks_msec() / 400.0) * 2.0
	if t != null:
		Art.draw_tex(self, t, Vector2(0, bob), 2.0 * Data.U)
	else:
		var wood := Color(0.42, 0.28, 0.16)
		draw_set_transform(Vector2(0, bob), 0.3, Vector2.ONE)
		draw_rect(Rect2(-24, -6, 48, 10), wood)
		draw_set_transform(Vector2(6, bob + 8), -0.5, Vector2.ONE)
		draw_rect(Rect2(-16, -4, 32, 8), wood.darkened(0.2))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		draw_rect(Rect2(-8, bob - 14, 14, 12), Color(0.55, 0.38, 0.2))
	var glint := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
	draw_circle(Vector2(-2, bob - 8), 3.0 + glint * 2.0, Color(1.0, 0.85, 0.2, 0.6 + glint * 0.4))
	draw_arc(Vector2.ZERO, pickup_radius, 0, TAU, 32, Color(1, 0.85, 0.3, 0.25), 2.0)
