class_name Trap
extends Node2D
## A deployed crab pot / lobster cage, marked by a buoy. It soaks in place and
## rolls a catch every interval until full; sail close and haul it to collect.
## `data` is the matching dict in Game.deployed, edited in place so it saves.
## Art hook: sprite "trap_<kind>" (buoy seen from above), else a vector buoy.

var data: Dictionary
var biome := ""


func setup(d: Dictionary) -> void:
	data = d
	position = Vector2(float(d.pos[0]), float(d.pos[1]))
	biome = Data.biome_at(position)


func kind() -> Dictionary:
	return Data.TRAPS[data.kind]


func capacity() -> int:
	return int(kind().capacity)


func is_full() -> bool:
	return data.catch.size() >= capacity()


func luck() -> float:
	var l := float(kind().luck)
	if data.bait != "":
		l += float(Data.TRAP_BAITS[data.bait].luck)
	return l


func interval() -> float:
	var speed := 1.0
	if data.bait != "":
		speed = float(Data.TRAP_BAITS[data.bait].speed)
	return float(kind().interval) / speed


func _process(delta: float) -> void:
	if not is_full():
		data.timer = float(data.timer) + delta
		if data.timer >= interval():
			data.timer = 0.0
			var id := Data.roll_trap_catch(biome, luck(), data.bait == "glow")
			data.catch.append({"id": id, "size": Data.roll_size()})
	queue_redraw()


func _draw() -> void:
	var t_ms := Time.get_ticks_msec()
	var bob := sin(t_ms / 450.0 + position.x) * 2.5
	var r := Data.TRAP_HAUL_RADIUS * Data.U
	var full := is_full()
	# Rope ripple + haul ring
	draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(0.55, 0.95, 0.9, 0.35 if full else 0.18), 2.0)
	var ripple := fmod(t_ms / 1400.0, 1.0)
	draw_arc(Vector2(0, bob), 10.0 + ripple * 18.0, 0, TAU, 24, Color(1, 1, 1, 0.35 * (1.0 - ripple)), 1.5)
	var tex := Art.tex("trap_" + String(data.kind))
	if tex != null:
		Art.draw_tex(self, tex, Vector2(0, bob), 1.2 * Data.U)
	else:
		_draw_buoy(Vector2(0, bob), data.kind == "lobster_cage")
	# Fill pips
	var n := capacity()
	for i in n:
		var p := Vector2((i - (n - 1) * 0.5) * 9.0, bob + 20.0)
		var filled: bool = i < data.catch.size()
		draw_circle(p, 3.5, Color(0, 0, 0, 0.5))
		draw_circle(p, 2.5, Color(0.55, 1.0, 0.8) if filled else Color(1, 1, 1, 0.25))
	if full:
		var pulse := 0.5 + 0.5 * sin(t_ms / 180.0)
		draw_circle(Vector2(0, bob - 26), 4.0 + pulse * 2.0, Color(0.55, 1.0, 0.8, 0.5 + pulse * 0.5))


## Placeholder buoy: striped float with a little flag; cages get a yellow float.
func _draw_buoy(c: Vector2, cage: bool) -> void:
	var main := Color(1.0, 0.82, 0.2) if cage else Color(0.9, 0.2, 0.15)
	draw_circle(c + Vector2(2, 3), 10.0, Color(0, 0, 0, 0.25))
	draw_circle(c, 10.0, main)
	draw_rect(Rect2(c + Vector2(-10, -3), Vector2(20, 6)), Color(0.97, 0.97, 0.95))
	draw_arc(c, 10.0, 0, TAU, 24, main.darkened(0.45), 2.0)
	draw_line(c, c + Vector2(0, -22), Color(0.25, 0.2, 0.15), 2.0)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -22), c + Vector2(11, -18), c + Vector2(0, -14)]), main)
