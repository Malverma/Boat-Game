class_name Projectile
extends Node2D
## A fish (player) or cannonball (pirate) flying in an arc. Collision is checked on
## the water plane; the arc height is visual only (spec §7.3).

var world: Node
var from_player := true
var fish_id := ""          # empty for pirate cannonballs
var damage := 0.0
var effect := "none"
var dir := Vector2.RIGHT
var speed := 9.0 * Data.U
var max_dist := 8.0 * Data.U
var traveled := 0.0
var pierce := 1
var small := false
var shooter: Node = null
var _hit := {}


func _process(delta: float) -> void:
	var step := speed * delta
	position += dir * step
	traveled += step
	var r := (0.25 if small else 0.4) * Data.U
	var targets: Array = world.get_pirates() if from_player else [world.boat]
	for t in targets:
		if t.dead or _hit.has(t.get_instance_id()) or (t is Pirate and t.submerged):
			continue
		if position.distance_to(t.position) < t.radius + r:
			_hit[t.get_instance_id()] = true
			world.combat.on_hit(self, t)
			pierce -= 1
			if pierce <= 0:
				queue_free()
				return
	if traveled >= max_dist:
		world.combat.on_land(self)
		queue_free()
		return
	queue_redraw()


func height() -> float:
	return sin(PI * clampf(traveled / max_dist, 0.0, 1.0)) * 0.9 * Data.U


func _draw() -> void:
	var h := height()
	var s := 1.0 + h / Data.U * 0.35
	draw_circle(Vector2.ZERO, (0.18 if small else 0.28) * Data.U, Color(0, 0, 0, 0.25))
	if fish_id == "":
		var t := Art.tex("cannonball")
		if t != null:
			Art.draw_tex(self, t, Vector2(0, -h), 0.45 * Data.U * s)
		else:
			draw_circle(Vector2(0, -h), 0.2 * Data.U * s, Color(0.12, 0.12, 0.14))
			draw_circle(Vector2(-2, -h - 2), 0.07 * Data.U * s, Color(0.5, 0.5, 0.55))
	else:
		var length: float = Data.FISH[fish_id].len * Data.U * (0.7 if small else 1.1) * s
		var spin := traveled * 0.02 if fish_id == "old_boot" else dir.angle()
		Art.draw_fish(self, fish_id, Vector2(0, -h), length, spin)
