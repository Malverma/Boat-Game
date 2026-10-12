class_name FishShadows
extends Node2D
## Fish shadows roaming the water around the boat while sailing. Each one is a
## pre-rolled fish (species + size) drawn at its real length, so a big shadow
## is a big catch. Casting onto one hooks that fish and it bites sooner; rare+
## fish give off an occasional glint. Fast boats scare them off.

const COUNT := 6
const SPAWN_MIN := 7.0        # units from the boat
const SPAWN_MAX := 12.0
const DESPAWN := 16.0
const CLAIM_RADIUS := 2.5     # bobber within this of a shadow hooks that fish
const LUCK := 0.15            # roaming fish lean slightly rarer than blind casts
const RARE := ["rare", "epic", "legendary"]
const DRAW_SCALE := 1.6       # drawn larger than bobber shadows so they read while sailing

var world: Node
var _shadows := []


func _process(delta: float) -> void:
	var boat: Boat = world.boat
	for s in _shadows:
		s.age += delta
		s.glint -= delta
		if s.glint <= 0.0:
			s.glint = randf_range(2.5, 5.0)
		var away: Vector2 = s.p - boat.position
		if boat.throttle > 0.6 and away.length() < 3.5 * Data.U:
			s.v = s.v.lerp(away.normalized(), 0.3)
			s.age = maxf(s.age, s.life - 1.0)   # spooked: fade out
		else:
			s.v = s.v.rotated(randf_range(-1.2, 1.2) * delta)
		s.p += (s.v * Data.U * 0.7 + world.currents.sample(s.p) * Data.U) * delta
	_shadows = _shadows.filter(func(s): return s.age < s.life and s.p.distance_to(boat.position) < DESPAWN * Data.U and world.island_at(s.p) == null)
	if not boat.dead and not world.player_in_safe_zone():
		while _shadows.size() < COUNT:
			_spawn(boat.position)
	queue_redraw()


func _spawn(center: Vector2) -> void:
	var p := center + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(SPAWN_MIN, SPAWN_MAX) * Data.U
	var luck := LUCK + (0.4 if world.at_hotspot(p) else 0.0)
	var id := Data.roll_fish(Data.biome_at(p), luck)
	var size := Data.roll_size()
	_shadows.append({"p": p, "v": Vector2.RIGHT.rotated(randf() * TAU), "id": id, "size": size,
		"s": FishingSystem.shadow_scale(id, size), "age": 0.0, "life": randf_range(25.0, 45.0),
		"glint": randf_range(0.0, 4.0), "rare": Data.FISH[id].rarity in RARE})


## Removes and returns the shadow nearest `pos` within CLAIM_RADIUS, or {}.
func take_near(pos: Vector2) -> Dictionary:
	var best := {}
	var best_d := CLAIM_RADIUS * Data.U
	for s in _shadows:
		var d: float = s.p.distance_to(pos)
		if d < best_d:
			best_d = d
			best = s
	if not best.is_empty():
		_shadows.erase(best)
	return best


func _draw() -> void:
	var t := Art.tex("fish_shadow")
	for s in _shadows:
		var a := clampf(minf(s.age, s.life - s.age), 0.0, 1.0)
		var len: float = Data.U * s.s * DRAW_SCALE
		if t != null:
			Art.draw_tex(self, t, s.p, len, s.v.angle(), Color(1, 1, 1, a))
		else:
			var c := Color(0.02, 0.06, 0.1, 0.32 * a)
			draw_set_transform(s.p, s.v.angle(), Vector2.ONE)
			var tail := PackedVector2Array([Vector2(-len * 0.3, 0), Vector2(-len * 0.55, -len * 0.18), Vector2(-len * 0.55, len * 0.18)])
			draw_colored_polygon(tail, c)
			draw_set_transform(s.p, s.v.angle(), Vector2(1.0, 0.4))
			draw_circle(Vector2(len * 0.05, 0), len * 0.38, c)
			draw_set_transform_matrix(Transform2D.IDENTITY)
		if s.rare and s.glint < 0.35:
			var k: float = s.glint / 0.35
			var r: float = (2.0 + 4.0 * (1.0 - k)) * s.s * DRAW_SCALE
			var c := Color(1, 1, 1, 0.8 * k * a)
			draw_line(s.p + Vector2(-r, 0), s.p + Vector2(r, 0), c, 1.5)
			draw_line(s.p + Vector2(0, -r), s.p + Vector2(0, r), c, 1.5)
