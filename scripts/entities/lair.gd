class_name Lair
extends Node2D
## A boss lair marked by a treasure map (Data.BOSS_MAPS, Game.treasure_maps).
## Drawn as a red X over dark, churning water. Sailing within Data.LAIR_TRIGGER
## raises the map's boss; sinking it pays the bounty and uses up the map. If the
## boss gives up the chase instead, it can be raised again after a short wait.
## Art hook: sprite "lair_x" (falls back to the placeholder X).

const RETRY := 20.0          # seconds after a boss leaves before the lair stirs again

var uid := 0
var kind := ""
var boss: Pirate = null
var _cooldown := 0.0
var _t := 0.0


func setup(m: Dictionary) -> void:
	uid = int(m.uid)
	kind = String(m.kind)
	position = Vector2(float(m.pos[0]), float(m.pos[1]))


func map_data() -> Dictionary:
	return Data.BOSS_MAPS[kind]


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if boss != null:
		if is_instance_valid(boss) and not boss.dead:
			return
		boss = null            # left without being sunk (the kill frees the lair itself)
		_cooldown = RETRY
	_cooldown -= delta
	var world := Game.world
	if world == null or _cooldown > 0.0 or world.boat.dead:
		return
	if world.boat.position.distance_to(position) < Data.LAIR_TRIGGER * Data.U and not world.player_in_safe_zone():
		boss = world.director.spawn_lair_boss(self)


## Picks a lair spot for a `kind` map bought at `from`: a random point in one of
## the map's biomes (nearer sectors more likely), clear of docks, islands,
## whirlpools and other lairs. Returns Vector2.INF if nothing fits.
static func pick_spot(world: Node, kind: String, from: Vector2) -> Vector2:
	var biomes: Array = Data.BOSS_MAPS[kind].biomes
	var sectors := []
	var weights := []
	for y in Data.GRID:
		for x in Data.GRID:
			if Data.biome_at_sector(x, y) in biomes:
				var c := (Vector2(x, y) + Vector2(0.5, 0.5)) * Data.SECTOR_PX
				sectors.append(Vector2i(x, y))
				weights.append(1.0 / (1.0 + c.distance_to(from) / Data.SECTOR_PX))
	if sectors.is_empty():
		return Vector2.INF
	var margin := 7.0 * Data.U
	for attempt in 40:
		var r := randf() * _sum(weights)
		var s: Vector2i = sectors[-1]
		for i in sectors.size():
			r -= weights[i]
			if r <= 0.0:
				s = sectors[i]
				break
		var p := Vector2(s) * Data.SECTOR_PX + Vector2(randf_range(margin, Data.SECTOR_PX - margin), randf_range(margin, Data.SECTOR_PX - margin))
		if _clear(world, p):
			return p
	return Vector2.INF


static func _sum(a: Array) -> float:
	var t := 0.0
	for v in a:
		t += v
	return t


static func _clear(world: Node, p: Vector2) -> bool:
	for s in Data.SHOPS:
		if Data.shop_pos(s).distance_to(p) < 22.0 * Data.U:
			return false
	for w in world.currents.whirlpools:
		if w.pos.distance_to(p) < w.radius + 8.0 * Data.U:
			return false
	if world.has_method("near_island") and world.near_island(p, 14.0 * Data.U):
		return false
	for m in Game.treasure_maps:
		if Vector2(float(m.pos[0]), float(m.pos[1])).distance_to(p) < 30.0 * Data.U:
			return false
	return true


func _draw() -> void:
	var col: Color = Data.RARITY_COLORS[map_data().rarity]
	var r := 4.0 * Data.U
	# Dark churning water and a slow ring of bubbles.
	draw_circle(Vector2.ZERO, r * 1.5, Color(0.0, 0.02, 0.06, 0.28))
	for i in 9:
		var a := TAU * i / 9.0 + _t * 0.4
		var rr := r * (1.0 + 0.15 * sin(_t * 1.7 + i * 1.3))
		draw_arc(Vector2.RIGHT.rotated(a) * rr, 3.0 + 2.0 * sin(_t * 3.0 + i), 0, TAU, 8, Color(1, 1, 1, 0.35), 1.5)
	draw_arc(Vector2.ZERO, r * 1.5, 0, TAU, 40, Color(col, 0.35), 2.0)
	var t := Art.tex("lair_x")
	if t != null:
		Art.draw_tex(self, t, Vector2.ZERO, r * 1.4, 0.0, Color.WHITE)
	else:
		var x := r * 0.55
		var pulse := 0.85 + 0.15 * sin(_t * 2.5)
		for d in [Vector2(x, x), Vector2(x, -x)]:
			draw_line(-d, d, Color(0.1, 0.0, 0.0, 0.6), 11.0)
			draw_line(-d, d, Color(0.85, 0.1, 0.1, pulse), 7.0)
	var font := ThemeDB.fallback_font
	var label: String = map_data().name
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(font, Vector2(-w * 0.5, r * 1.5 + 22.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(col, 0.9))
