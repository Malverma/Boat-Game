class_name Island
extends Node2D
## A rare small island (Data.ISLANDS). Its land is solid: World.push_off_islands
## keeps ships on the water. Inside the landing ring the HUD offers Go Ashore,
## which opens IslandUI. Persistent state lives in Game.island_state(index).
## Art hook: sprite "island_<kind>" (falls back to "island", then placeholder).

const FIND_RADIUS := 18.0     # units: sailing this close reveals the island
const LAGOON_POOL := 0.55     # lagoon: inner water, as a fraction of land_radius
const LAGOON_REACH := 6.0     # lagoon: fish-rich water beyond the shore, in units

var index := 0
var kind := ""
var island_name := ""
var biome := ""
var land_radius := 2.5 * Data.U
var dock_radius := 3.0 * Data.U
var _coast := PackedVector2Array()
var _palms := []      # [{"p": Vector2, "a": float}]
var _houses := []     # port: [{"p": Vector2, "w": float, "roof": Color}]


func setup(i: int, k: String, pos: Vector2, rng: RandomNumberGenerator) -> void:
	index = i
	kind = k
	position = pos
	biome = Data.biome_at(pos)
	var names: Array = Data.ISLANDS[k].names
	island_name = names[rng.randi() % names.size()]
	var sizes := {"lagoon": Vector2(3.0, 3.4), "port": Vector2(3.6, 4.0)}
	var sz: Vector2 = sizes.get(k, Vector2(2.2, 2.9))
	land_radius = rng.randf_range(sz.x, sz.y) * Data.U
	dock_radius = land_radius + 2.8 * Data.U
	var n := 22
	for j in n:
		var r := land_radius * rng.randf_range(0.9, 1.0)
		_coast.append(Vector2.RIGHT.rotated(TAU * j / n) * r)
	var count: int = {"coconut": 4, "treasure": 2, "castaway": 1, "lagoon": 3}.get(k, 0)
	for j in count:
		var a := TAU * j / float(count) + rng.randf_range(-0.4, 0.4)
		var d := land_radius * (0.75 if k == "lagoon" else rng.randf_range(0.25, 0.5))
		_palms.append({"p": Vector2.RIGHT.rotated(a) * d, "a": rng.randf() * TAU})
	if k == "port":   # own rng, so the shared placement rng isn't disturbed
		var hr := RandomNumberGenerator.new()
		hr.seed = Game.island_seed + index * 131
		var roofs := [Color(0.72, 0.25, 0.18), Color(0.25, 0.4, 0.62), Color(0.78, 0.55, 0.2)]
		for j in 9:
			var p := Vector2.RIGHT.rotated(hr.randf() * TAU) * land_radius * hr.randf_range(0.0, 0.5)
			_houses.append({"p": p, "w": hr.randf_range(9.0, 15.0), "roof": roofs[hr.randi() % roofs.size()]})
	if k == "castaway" and state().want == "":
		state().want = Data.roll_loot_fish(biome, "uncommon" if rng.randf() < 0.6 else "rare")


func state() -> Dictionary:
	return Game.island_state(index)


func found() -> bool:
	return bool(state().found)


func done() -> bool:
	return bool(state().done)


## Seconds until a repeatable action (coconuts, tide pools, shrine) is ready.
func ready_in() -> float:
	return maxf(0.0, float(state().ready) - Game.play_time)


## Port City: where the shore battery stands (world space), on the seaward
## side of town. Fixed per island without using the placement rng.
func battery_pos() -> Vector2:
	return position + Vector2.RIGHT.rotated(fposmod(index * 2.39996, TAU)) * land_radius * 0.68


func title() -> String:
	return Data.ISLANDS[kind].title


## "Name (Kind)", or just the name when they match.
func full_name() -> String:
	return island_name if island_name == title() else "%s (%s)" % [island_name, title()]


## True on dry land. A lagoon's inner pool counts as water (you can cast into it).
func is_land(p: Vector2) -> bool:
	var d := p.distance_to(position)
	if kind == "lagoon" and d < land_radius * LAGOON_POOL:
		return false
	return d < land_radius


## Fishing luck bonus at `p`: the lagoon pool is richest, its outer waters less so.
func luck_at(p: Vector2) -> float:
	if kind != "lagoon":
		return 0.0
	var d := p.distance_to(position)
	if d < land_radius * LAGOON_POOL:
		return 0.8
	if d > land_radius and d < land_radius + LAGOON_REACH * Data.U:
		return 0.3
	return 0.0


func _process(_delta: float) -> void:
	queue_redraw()


# --- Drawing ------------------------------------------------------------------------

func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# Surf ring
	var foam := 1.0 + 0.04 * sin(now * 1.6 + index)
	var ring := PackedVector2Array()
	for p in _coast:
		ring.append(p * (1.12 * foam))
	draw_colored_polygon(ring, Color(1, 1, 1, 0.22))
	if kind == "lagoon":
		draw_circle(Vector2.ZERO, land_radius + LAGOON_REACH * Data.U, Color(1, 1, 1, 0.03))
	var t := Art.tex("island_" + kind)
	if t == null:
		t = Art.tex("island")
	if t != null:
		Art.draw_tex(self, t, Vector2.ZERO, land_radius * 2.2)
	else:
		_draw_land(now)
		_draw_feature(now)
	if found():
		_label()


func _colors() -> Array:
	match biome:
		"frozen": return [Color(0.72, 0.78, 0.84), Color(0.93, 0.96, 1.0)]
		"volcanic": return [Color(0.24, 0.19, 0.18), Color(0.36, 0.27, 0.22)]
		"abyss": return [Color(0.28, 0.3, 0.36), Color(0.17, 0.19, 0.25)]
		"kelp": return [Color(0.82, 0.75, 0.55), Color(0.24, 0.5, 0.25)]
	return [Color(0.93, 0.85, 0.6), Color(0.36, 0.68, 0.3)]


func _draw_land(now: float) -> void:
	var cols := _colors()
	draw_colored_polygon(_coast, cols[0])
	var inner := PackedVector2Array()
	for p in _coast:
		inner.append(p * 0.72)
	if kind == "lagoon":
		var pool: Color = Data.BIOMES[biome].light
		draw_circle(Vector2.ZERO, land_radius * LAGOON_POOL, pool.darkened(0.15))
		draw_circle(Vector2.ZERO, land_radius * LAGOON_POOL * 0.75, pool)
		for i in 4:
			var a := now * 0.4 + i * TAU / 4.0
			var p := Vector2.RIGHT.rotated(a) * land_radius * 0.3
			draw_circle(p, 2.0 + sin(now * 3.0 + i), Color(1, 1, 1, 0.7))
	else:
		draw_colored_polygon(inner, cols[1])


func _draw_feature(now: float) -> void:
	for palm in _palms:
		_palm(palm.p, palm.a, kind == "coconut" and ready_in() <= 0.0)
	match kind:
		"treasure":
			var p := Vector2(land_radius * 0.15, land_radius * 0.2)
			if done():
				draw_circle(p, 9.0, Color(0.3, 0.22, 0.12))
				draw_rect(Rect2(p + Vector2(10, -6), Vector2(14, 10)), Color(0.5, 0.32, 0.15))
			else:
				var c := Color(0.8, 0.12, 0.1)
				draw_line(p + Vector2(-8, -8), p + Vector2(8, 8), c, 4.0)
				draw_line(p + Vector2(-8, 8), p + Vector2(8, -8), c, 4.0)
		"castaway":
			var fire := Vector2(land_radius * 0.3, land_radius * 0.15)
			draw_circle(fire, 6.0, Color(0.3, 0.2, 0.1))
			if not done():
				draw_circle(fire, 4.0 + sin(now * 9.0), Color(1.0, 0.55, 0.15))
				for i in 3:   # smoke
					var k := fmod(now * 0.5 + i / 3.0, 1.0)
					draw_circle(fire + Vector2(k * 14.0, -k * 40.0), 4.0 + k * 8.0, Color(0.85, 0.85, 0.85, 0.5 * (1.0 - k)))
				var guy := Vector2(-land_radius * 0.15, land_radius * 0.3)
				var wave := sin(now * 6.0) * 4.0
				draw_rect(Rect2(guy + Vector2(-4, -2), Vector2(8, 12)), Color(0.7, 0.55, 0.4))
				draw_circle(guy + Vector2(0, -7), 5.0, Color(0.95, 0.75, 0.6))
				draw_line(guy + Vector2(4, 0), guy + Vector2(11, -10 + wave), Color(0.95, 0.75, 0.6), 2.5)
		"lookout":
			var base := Vector2(-6, 6)
			draw_rect(Rect2(base + Vector2(-12, -12), Vector2(24, 24)), Color(0.5, 0.5, 0.52))
			draw_rect(Rect2(base + Vector2(-12, -12), Vector2(24, 24)), Color(0.3, 0.3, 0.32), false, 2.0)
			draw_circle(base, 7.0, Color(0.38, 0.38, 0.4))
			draw_line(base, base + Vector2(0, -28), Color(0.3, 0.2, 0.1), 2.0)
			var flap := sin(now * 5.0) * 3.0
			draw_colored_polygon(PackedVector2Array([base + Vector2(0, -28), base + Vector2(16, -24 + flap), base + Vector2(0, -20)]), Color(0.9, 0.85, 0.3))
		"hideout":
			var hut := Vector2(-land_radius * 0.2, 0)
			draw_rect(Rect2(hut + Vector2(-14, -10), Vector2(28, 20)), Color(0.45, 0.3, 0.18))
			draw_colored_polygon(PackedVector2Array([hut + Vector2(-18, -10), hut + Vector2(0, -24), hut + Vector2(18, -10)]), Color(0.3, 0.2, 0.12))
			for i in 2:
				draw_rect(Rect2(hut + Vector2(20 + i * 11, 4), Vector2(9, 9)), Color(0.6, 0.42, 0.2))
			if not done():
				var pole := hut + Vector2(land_radius * 0.45, -4)
				draw_line(pole, pole + Vector2(0, -34), Color(0.25, 0.18, 0.1), 2.0)
				var flap := sin(now * 5.0) * 3.0
				draw_rect(Rect2(pole + Vector2(0, -34 + flap * 0.3), Vector2(18, 12)), Color(0.08, 0.08, 0.08))
				draw_circle(pole + Vector2(9, -28 + flap * 0.3), 3.0, Color(0.9, 0.9, 0.9))
		"port":
			_draw_port(now)
		"shrine":
			var glow := ready_in() <= 0.0
			for i in 5:
				var p := Vector2.RIGHT.rotated(TAU * i / 5.0 + 0.3) * land_radius * 0.45
				draw_rect(Rect2(p - Vector2(4, 7), Vector2(8, 14)), Color(0.55, 0.55, 0.6))
			var pulse := 0.5 + 0.5 * sin(now * 2.5)
			if glow:
				draw_circle(Vector2.ZERO, 14.0 + pulse * 6.0, Color(0.6, 0.85, 1.0, 0.25))
			draw_circle(Vector2.ZERO, 7.0, Color(0.75, 0.9, 1.0) if glow else Color(0.4, 0.45, 0.5))


func _draw_port(now: float) -> void:
	var gun := to_local(battery_pos())
	var away := -gun.normalized()
	# Pier out to sea on the side away from the battery.
	var pier := away * land_radius * 0.8
	draw_line(pier, away * (land_radius + 1.6 * Data.U), Color(0.45, 0.32, 0.2), 9.0)
	for i in 3:
		var p := away * (land_radius + (0.4 + i * 0.5) * Data.U)
		draw_circle(p + away.orthogonal() * 6.0, 2.5, Color(0.3, 0.2, 0.12))
		draw_circle(p - away.orthogonal() * 6.0, 2.5, Color(0.3, 0.2, 0.12))
	# Town wall ring with a gap at the pier.
	var gate := away.angle()
	draw_arc(Vector2.ZERO, land_radius * 0.62, gate + 0.35, gate + TAU - 0.35, 28, Color(0.55, 0.52, 0.48), 6.0)
	for h in _houses:
		var w: float = h.w
		draw_rect(Rect2(h.p - Vector2(w, w * 0.8) * 0.5, Vector2(w, w * 0.8)), Color(0.88, 0.82, 0.7))
		draw_colored_polygon(PackedVector2Array([h.p + Vector2(-w * 0.6, -w * 0.4), h.p + Vector2(0, -w * 0.95), h.p + Vector2(w * 0.6, -w * 0.4)]), h.roof)
	# Bell tower with the town flag: red while the battery stands, white once it falls.
	var tower := Vector2(-6, -4)
	draw_rect(Rect2(tower + Vector2(-6, -10), Vector2(12, 20)), Color(0.6, 0.58, 0.55))
	draw_line(tower + Vector2(0, -10), tower + Vector2(0, -34), Color(0.3, 0.22, 0.15), 2.0)
	var flap := sin(now * 5.0) * 3.0
	draw_rect(Rect2(tower + Vector2(0, -34 + flap * 0.3), Vector2(16, 10)), Color(0.95, 0.95, 0.92) if done() else Color(0.75, 0.12, 0.1))
	# The battery's bastion (its live barrel is the Pirate "fort_cannon"); rubble once silenced.
	var r := 1.0 * Data.U
	if done():
		for i in 6:
			var a := TAU * i / 6.0 + index
			draw_circle(gun + Vector2.RIGHT.rotated(a) * r * 0.6, r * 0.3, Color(0.4, 0.38, 0.36))
		draw_circle(gun, r * 0.35, Color(0.18, 0.16, 0.15))
	else:
		var wall := PackedVector2Array()
		for i in 8:
			wall.append(gun + Vector2.RIGHT.rotated(TAU * (i + 0.5) / 8.0) * r * 1.35)
		draw_colored_polygon(wall, Color(0.38, 0.36, 0.34))


func _palm(p: Vector2, a: float, fruit: bool) -> void:
	var top := p + Vector2(6, -16)
	draw_line(p, top, Color(0.5, 0.35, 0.2), 4.0)
	for i in 5:
		var d := Vector2.RIGHT.rotated(a + TAU * i / 5.0)
		draw_line(top, top + d * 16.0, Color(0.18, 0.5, 0.2), 5.0)
	if fruit:
		for i in 3:
			draw_circle(top + Vector2.RIGHT.rotated(TAU * i / 3.0) * 4.0, 2.5, Color(0.45, 0.3, 0.15))


func _label() -> void:
	var font := ThemeDB.fallback_font
	var label := island_name if not done() else "%s (%s)" % [island_name, "friendly" if kind == "port" else "explored"]
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 18).x
	var y := -land_radius - 0.6 * Data.U
	draw_string_outline(font, Vector2(-w / 2, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(-w / 2, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.75, 1.0, 0.8))
