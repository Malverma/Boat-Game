class_name MapUI
extends Overlay
## Map + pause menu (spec §8.2): opening it pauses the game. Shows fog of war,
## biomes, shops, hot spots, whirlpools and the current overlay beside the menu
## (resume, hold, Fishpedia, settings, save & quit). The Navigator's Chart adds
## reversal forecasts and all hot spots.

signal quit_requested

var world: Node
var _map: Control


func _init(w: Node) -> void:
	world = w


func build() -> void:
	header("Paused · Sea Chart", false)
	var h := UIKit.hbox(16)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(h)
	_map = Control.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.draw.connect(_draw_map)
	h.add_child(_map)
	var legend := UIKit.vbox(4)
	legend.custom_minimum_size = Vector2(260, 0)
	legend.add_child(UIKit.button("Resume", close, 22))
	legend.add_child(UIKit.button("Hold", _sub.bind(func(): return HoldUI.new()), 22))
	legend.add_child(UIKit.button("Fishpedia", _sub.bind(func(): return FishpediaUI.new()), 22))
	legend.add_child(UIKit.button("Settings", _sub.bind(func(): return SettingsUI.new()), 22))
	legend.add_child(UIKit.button("Save & Quit to Title", _quit, 22))
	legend.add_child(UIKit.label("Played %d min · %d species found" % [int(Game.play_time / 60.0), Game.fishpedia.size()], 14, UIKit.DIM))
	legend.add_child(UIKit.label("", 8))
	for b in ["shallows", "reef", "kelp", "deep", "frozen", "volcanic", "abyss"]:
		var d: Dictionary = Data.BIOMES[b]
		var l := UIKit.label("%s  %s" % [d.name, "*".repeat(int(d.stars))], 17, d.light.lerp(Color.WHITE, 0.4))
		legend.add_child(l)
	legend.add_child(UIKit.label("", 10))
	legend.add_child(UIKit.label("Gold square: shop", 15, UIKit.GOLD))
	legend.add_child(UIKit.label("Purple: merchant", 15, Color(0.8, 0.55, 1.0)))
	legend.add_child(UIKit.label("Bubbles: hot spot", 15, Color.WHITE))
	legend.add_child(UIKit.label("Spiral: whirlpool", 15, Color(0.7, 0.85, 1.0)))
	legend.add_child(UIKit.label("Green: island", 15, Color(0.5, 0.95, 0.55)))
	legend.add_child(UIKit.label("Teal pin: your trap", 15, Color(0.45, 1.0, 0.85)))
	if not Game.treasure_maps.is_empty():
		legend.add_child(UIKit.label("Red X: boss lair (map)", 15, Color(1.0, 0.4, 0.35)))
	if Game.lvl("chart") > 0:
		legend.add_child(UIKit.label("Timers: current flips in", 15, Color(1.0, 0.9, 0.5)))
	else:
		legend.add_child(UIKit.label("Buy a Navigator's Chart\nfor current forecasts.", 15, UIKit.DIM))
	h.add_child(legend)


func _sub(make: Callable) -> void:
	var o: Overlay = make.call()
	get_parent().add_child(o)
	o.closed.connect(func(): visible = true)
	visible = false


func _quit() -> void:
	close()
	quit_requested.emit()


func _draw_map() -> void:
	var c := _map
	var font := ThemeDB.fallback_font
	var side := minf(c.size.x, c.size.y)
	var origin := Vector2((c.size.x - side) * 0.5, (c.size.y - side) * 0.5)
	var cell := side / Data.GRID
	var k := side / Data.WORLD_PX
	var chart := Game.lvl("chart") > 0
	for y in Data.GRID:
		for x in Data.GRID:
			var r := Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell))
			if not Game.discovered.has("%d,%d" % [x, y]):
				c.draw_rect(r, Color(0.07, 0.08, 0.1))
				c.draw_string(font, r.get_center() + Vector2(-5, 7), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.3, 0.3, 0.35))
				continue
			var b: Dictionary = Data.BIOMES[Data.biome_at_sector(x, y)]
			c.draw_rect(r, b.deep.lerp(b.light, 0.35))
			var v: Vector2 = world.currents.sector_vector(x, y)
			if v.length() > 0.1:
				var d := v.normalized()
				var tip := r.get_center() + d * cell * 0.3
				c.draw_line(r.get_center() - d * cell * 0.3, tip, Color(1, 1, 1, 0.55), 2.0)
				c.draw_colored_polygon(PackedVector2Array([tip + d * 3, tip - d * 7 + d.orthogonal() * 5, tip - d * 7 - d.orthogonal() * 5]), Color(1, 1, 1, 0.55))
			if chart:
				var eta: float = world.currents.reversal_eta(x, y)
				if eta >= 0.0:
					c.draw_string(font, r.position + Vector2(4, 16), "flip %d:%02d" % [int(eta) / 60, int(eta) % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.9, 0.5))
	for x in Data.GRID + 1:
		c.draw_line(origin + Vector2(x * cell, 0), origin + Vector2(x * cell, side), Color(0, 0, 0, 0.35), 1.0)
		c.draw_line(origin + Vector2(0, x * cell), origin + Vector2(side, x * cell), Color(0, 0, 0, 0.35), 1.0)
	for l in world.currents.lanes:
		var pts := PackedVector2Array()
		var seen := false
		for p in l.pts:
			pts.append(origin + p * k)
			seen = seen or _seen(p)
		if not seen:
			continue
		c.draw_polyline(pts, Color(0.55, 0.9, 1.0, 0.85), 3.0, true)
		var d: Vector2 = (pts[-1] - pts[-2]).normalized()
		var tip: Vector2 = pts[-1]
		c.draw_colored_polygon(PackedVector2Array([tip + d * 4, tip - d * 7 + d.orthogonal() * 6, tip - d * 7 - d.orthogonal() * 6]), Color(0.55, 0.9, 1.0, 0.85))
	for w in world.currents.whirlpools:
		if _seen(w.pos):
			var p: Vector2 = origin + w.pos * k
			c.draw_arc(p, 7, 0, TAU * 0.8, 16, Color(0.7, 0.85, 1.0), 2.0)
			c.draw_arc(p, 3, PI, TAU * 1.2, 10, Color(0.7, 0.85, 1.0), 2.0)
	for isl in world.islands:
		if not isl.found():
			continue
		var ip: Vector2 = origin + isl.position * k
		var ic := Color(0.5, 0.95, 0.55) if not isl.done() else Color(0.5, 0.6, 0.5)
		c.draw_circle(ip, 5.0, Color(0.93, 0.85, 0.6))
		c.draw_circle(ip, 3.0, ic)
		c.draw_string(font, ip + Vector2(7, 4), isl.island_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ic)
	for h in world.hotspots():
		if chart or h.discovered:
			var p: Vector2 = origin + h.position * k
			c.draw_arc(p, 5, 0, TAU, 12, Color.WHITE, 1.5)
			c.draw_arc(p + Vector2(5, -4), 3, 0, TAU, 8, Color.WHITE, 1.5)
	for s in world.shops:
		if not _seen(s.position):
			continue
		var p: Vector2 = origin + s.position * k
		var col := Color(0.8, 0.55, 1.0) if s.merchant else UIKit.GOLD
		c.draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), col)
		c.draw_string(font, p + Vector2(8, 4), s.shop_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
	for t in world.traps():
		var p: Vector2 = origin + t.position * k
		var tc := Color(0.45, 1.0, 0.85)
		c.draw_circle(p, 4.5, tc)
		c.draw_line(p, p + Vector2(0, -9), tc, 1.5)
		c.draw_string(font, p + Vector2(7, 4), "%d/%d" % [t.data.catch.size(), t.capacity()], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tc)
	# Treasure-map lairs show even through fog: that's what the map is for.
	for m in Game.treasure_maps:
		var bm: Dictionary = Data.BOSS_MAPS[m.kind]
		var p: Vector2 = origin + Vector2(float(m.pos[0]), float(m.pos[1])) * k
		for dx in [Vector2(6, 6), Vector2(6, -6)]:
			c.draw_line(p - dx, p + dx, Color(0.1, 0, 0), 5.0)
			c.draw_line(p - dx, p + dx, Color(1.0, 0.25, 0.2), 3.0)
		c.draw_string(font, p + Vector2(9, 4), Data.PIRATES[bm.boss].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Data.RARITY_COLORS[bm.rarity])
	var boat: Boat = world.boat
	var bp := origin + boat.position * k
	var d := boat.heading()
	c.draw_colored_polygon(PackedVector2Array([bp + d * 10, bp - d * 6 + d.orthogonal() * 6, bp - d * 6 - d.orthogonal() * 6]), Color(1, 0.3, 0.3))
	c.draw_arc(bp, 12, 0, TAU, 20, Color(1, 1, 1, 0.8), 1.5)


func _seen(pos: Vector2) -> bool:
	var s := Data.sector_of(pos)
	return Game.discovered.has("%d,%d" % [s.x, s.y])
