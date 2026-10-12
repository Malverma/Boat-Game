class_name TentacleSlam
extends Node2D
## Kraken attack: a telegraphed circle on the water, then a tentacle slams down.
## Art hook: "kraken_tentacle" (authored with its base on the left, tip pointing right).

const WARN := 1.1
const LINGER := 0.6

var world: Node
var damage := 18.0
var radius := 2.2 * Data.U
var from := Vector2.ZERO    # kraken position, sets the tentacle's angle
var _t := 0.0
var _struck := false


func _process(delta: float) -> void:
	_t += delta
	if not _struck and _t >= WARN:
		_struck = true
		_strike()
	if _t >= WARN + LINGER:
		queue_free()
		return
	queue_redraw()


func _strike() -> void:
	var boat: Boat = world.boat
	world.spawn_fx("splash", position, radius * 1.3, Color.WHITE)
	world.spawn_fx("slam", position, radius, Color(0.66, 0.19, 0.31))
	Sfx.play("tentacle_slam")
	if boat.dead:
		return
	var d := boat.position - position
	if d.length() < radius + boat.radius:
		boat.take_damage(damage)
		boat.impulse += (d.normalized() if d != Vector2.ZERO else Vector2.RIGHT) * 10.0 * Data.U
		Game.haptic(150)


func _draw() -> void:
	if not _struck:
		var k := _t / WARN
		draw_circle(Vector2.ZERO, radius * k, Color(0.9, 0.15, 0.2, 0.18 + 0.2 * k))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(1.0, 0.3, 0.3, 0.5 + 0.5 * k), 3.0)
		return
	var a := 1.0 - (_t - WARN) / LINGER
	var angle := (position - from).angle()
	var length := 3.4 * Data.U
	var t := Art.tex("kraken_tentacle")
	# Centered on the impact point, reaching in from the kraken's side.
	var center := -Vector2.RIGHT.rotated(angle) * length * 0.2
	if t != null:
		Art.draw_tex(self, t, center, length, angle, Color(1, 1, 1, a))
	else:
		var dir := Vector2.RIGHT.rotated(angle)
		draw_line(center - dir * length * 0.5, center + dir * length * 0.5, Color(0.37, 0.09, 0.19, a), 22.0)
		draw_line(center - dir * length * 0.5, center + dir * length * 0.5, Color(0.66, 0.19, 0.31, a), 14.0)
