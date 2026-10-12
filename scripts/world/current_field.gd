class_name CurrentField
extends RefCounted
## Ocean current vector field (spec §3.3). One base vector per sector, smoothly
## interpolated, with per-biome local behavior, timed reversals and whirlpools.
## Calm pockets (low-frequency noise) cut the current to zero over roughly half
## the sea so there is always still water nearby to stop and fish in. A slow
## warp noise bends the flow so open water swirls instead of running straight.
## Every biome also has at least one narrow jet stream lane to ride for a speed
## boost: too thin to disrupt fishing or docking, strong enough to be worth
## seeking out. All returned vectors are in units/s.

const REVERSE_CHANCE := 0.3
const CALM_FREQ := 1.0 / 900.0       # noise frequency in 1/px (pockets ~15–30 units across)
const CALM_EDGE := Vector2(-0.05, 0.25)  # noise below x = still water, above y = full current
const LANE_CORE := 1.3       # units from the lane center at full strength
const LANE_HALF := 2.6       # units from the center where the lane fades out
const LANE_TAPER := 4.0      # units over which each end ramps up
const LANE_WIGGLE := 3.5     # units of side-to-side meander between waypoints
const LANE_WAVE := 36.0      # units per meander wavelength (roughly)
const LANE_STEP := 3.0       # units between generated lane points
const WARP_FREQ := 1.0 / 1300.0   # bend noise frequency in 1/px (~1 sector per swirl)
const WARP_ANGLE := 1.2      # bend per unit of noise (noise stays within ~±0.6, so ≤ ~40°)
const WARP_DRIFT := 0.02     # noise units/s the bend pattern shifts over time
# Jet stream lanes as polylines in sector coordinates, routed clear of docks
# and whirlpools. strength in units/s (base top speed is 5).
const LANES := [
	{"biome": "shallows", "strength": 3.0, "pts": [Vector2(3.25, 4.75), Vector2(3.25, 3.25), Vector2(4.75, 3.25)]},
	{"biome": "reef", "strength": 3.0, "pts": [Vector2(2.2, 4.9), Vector2(2.75, 4.05)]},
	{"biome": "reef", "strength": 3.0, "pts": [Vector2(5.5, 3.1), Vector2(5.5, 4.0)]},
	{"biome": "kelp", "strength": 3.2, "pts": [Vector2(2.1, 2.2), Vector2(5.9, 2.2)]},
	{"biome": "kelp", "strength": 3.2, "pts": [Vector2(5.9, 5.8), Vector2(2.1, 5.8)]},
	{"biome": "deep", "strength": 3.5, "pts": [Vector2(0.9, 1.3), Vector2(0.9, 6.7)]},
	{"biome": "deep", "strength": 3.5, "pts": [Vector2(7.1, 6.7), Vector2(7.1, 1.3)]},
	{"biome": "frozen", "strength": 3.5, "pts": [Vector2(1.2, 1.6), Vector2(5.8, 1.6)]},
	{"biome": "volcanic", "strength": 3.5, "pts": [Vector2(5.9, 7.0), Vector2(2.6, 7.0)]},
	{"biome": "abyss", "strength": 3.8, "pts": [Vector2(7.8, 0.92), Vector2(7.08, 0.92), Vector2(7.08, 0.2)]},
	{"biome": "abyss", "strength": 3.8, "pts": [Vector2(0.2, 7.08), Vector2(0.92, 7.08), Vector2(0.92, 7.8)]},
]

var base: Array[Vector2] = []
var reversing := {}          # sector index -> {"period": float, "offset": float}
var phase: Array[float] = []
var whirlpools := []         # [{"pos": Vector2 px, "radius": px, "strength": u/s, "core": px}]
var time := 0.0
var calm_noise := FastNoiseLite.new()
var warp_noise := FastNoiseLite.new()
var lanes := []              # [{"pts": PackedVector2Array px, "strength": u/s, "len": px, "rect": Rect2}]


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	calm_noise.seed = 4242
	calm_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	calm_noise.frequency = CALM_FREQ
	warp_noise.seed = 9917
	warp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	warp_noise.frequency = WARP_FREQ
	var center := Vector2(Data.GRID, Data.GRID) * 0.5
	for y in Data.GRID:
		for x in Data.GRID:
			var b: Dictionary = Data.BIOMES[Data.biome_at_sector(x, y)]
			var c := Vector2(x + 0.5, y + 0.5)
			var dir := Vector2.RIGHT.rotated(rng.randf() * TAU)
			match b.style:
				"stream":   # long streams circulating around the map
					dir = (c - center).orthogonal().normalized()
				"drift":    # alternating cold bands
					dir = Vector2(1.0 if y % 2 == 0 else -1.0, 0.3).normalized()
				"steady":
					dir = Vector2.RIGHT.rotated(rng.randf_range(-0.6, 0.6) + (PI if x < 4 else 0.0))
			base.append(dir * float(b.current) * rng.randf_range(0.75, 1.15))
			phase.append(rng.randf() * TAU)
			if b.style in ["steady", "stream", "drift"] and rng.randf() < REVERSE_CHANCE:
				reversing[y * Data.GRID + x] = {"period": rng.randf_range(180.0, 300.0), "offset": rng.randf() * 300.0}
	for l in LANES:
		var pts := _meander(l.pts, rng)
		var length := 0.0
		for i in range(1, pts.size()):
			length += pts[i].distance_to(pts[i - 1])
		var rect := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			rect = rect.expand(p)
		lanes.append({"pts": pts, "strength": float(l.strength), "len": length, "rect": rect.grow(LANE_HALF * Data.U)})
	for s in [Vector2i(0, 0), Vector2i(7, 0), Vector2i(0, 7), Vector2i(7, 7), Vector2i(2, 6), Vector2i(5, 7), Vector2i(3, 6)]:
		var p := (Vector2(s) + Vector2(0.5, 0.5)) * Data.SECTOR_PX + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8)) * Data.U
		whirlpools.append({"pos": p, "radius": 8.0 * Data.U, "strength": 4.5, "core": 0.9 * Data.U})


## Turns an authored lane polyline (sector coords) into a winding pixel path:
## each leg snakes side to side, pinned to its waypoints so the route stays
## clear of docks, and corners are rounded off.
func _meander(src: Array, rng: RandomNumberGenerator) -> PackedVector2Array:
	var pts := PackedVector2Array([src[0] * Data.SECTOR_PX])
	for i in range(1, src.size()):
		var a: Vector2 = src[i - 1] * Data.SECTOR_PX
		var b: Vector2 = src[i] * Data.SECTOR_PX
		var leg := b - a
		var len_u := leg.length() / Data.U
		var side := leg.normalized().orthogonal()
		var waves := maxf(1.0, round(len_u / LANE_WAVE))   # whole half-waves pin both ends
		var sgn := 1.0 if rng.randf() < 0.5 else -1.0
		var steps := maxi(2, int(len_u / LANE_STEP))
		for j in range(1, steps + 1):
			var t := float(j) / steps
			var off := sin(t * PI * waves) * LANE_WIGGLE * sgn
			pts.append(a + leg * t + side * off * Data.U)
	# One Chaikin pass softens the corners between legs; endpoints stay put.
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size()):
		out.append(pts[i - 1].lerp(pts[i], 0.25))
		out.append(pts[i - 1].lerp(pts[i], 0.75))
	out.append(pts[-1])
	return out


func update(delta: float) -> void:
	time += delta


func sector_vector(x: int, y: int) -> Vector2:
	x = clampi(x, 0, Data.GRID - 1)
	y = clampi(y, 0, Data.GRID - 1)
	var i := y * Data.GRID + x
	var v := base[i]
	if reversing.has(i):
		var r: Dictionary = reversing[i]
		if int(floor((time + float(r.offset)) / float(r.period))) % 2 == 1:
			v = -v
	return v


## Seconds until this sector's current flips, or -1 if it never does.
func reversal_eta(x: int, y: int) -> float:
	var i := y * Data.GRID + x
	if not reversing.has(i):
		return -1.0
	var r: Dictionary = reversing[i]
	var p := float(r.period)
	return p - fmod(time + float(r.offset), p)


func sample(pos: Vector2) -> Vector2:
	var s := pos / Data.SECTOR_PX - Vector2(0.5, 0.5)
	var x0 := int(floor(s.x))
	var y0 := int(floor(s.y))
	var f := s - Vector2(x0, y0)
	var v := sector_vector(x0, y0).lerp(sector_vector(x0 + 1, y0), f.x).lerp(
			sector_vector(x0, y0 + 1).lerp(sector_vector(x0 + 1, y0 + 1), f.x), f.y)
	var sec := Data.sector_of(pos)
	var b: Dictionary = Data.BIOMES[Data.biome_at_sector(sec.x, sec.y)]
	var ph: float = phase[sec.y * Data.GRID + sec.x]
	match b.style:
		"eddy":     # gentle swirl around the sector center
			var c := (Vector2(sec) + Vector2(0.5, 0.5)) * Data.SECTOR_PX
			var d := pos - c
			if d.length() > 1.0:
				v += d.orthogonal().normalized() * float(b.current) * 0.7 * sin(time * 0.1 + ph)
		"burst":    # erratic pulses
			v *= 1.0 + 1.6 * pow(maxf(0.0, sin(time * 0.7 + ph)), 8.0)
		"chaotic":
			v = v.rotated(sin(time * 0.3 + ph + pos.x * 0.0008) * 1.4)
	v = v.rotated(warp_noise.get_noise_3d(pos.x, pos.y, time * WARP_DRIFT / WARP_FREQ) * WARP_ANGLE)
	var lane := lane_flow(pos)
	return v * strength_at(pos) * (1.0 - lane.z) + Vector2(lane.x, lane.y)


## Jet stream flow at pos: xy = velocity (u/s), z = lane weight 0–1 (how far
## inside a lane pos is; the lane replaces the ambient current by that much).
func lane_flow(pos: Vector2) -> Vector3:
	var out := Vector3.ZERO
	for l in lanes:
		if not l.rect.has_point(pos):
			continue
		var pts: PackedVector2Array = l.pts
		var along := 0.0
		for i in range(1, pts.size()):
			var a := pts[i - 1]
			var seg := pts[i] - a
			var seg_len := seg.length()
			var f := clampf((pos - a).dot(seg) / (seg_len * seg_len), 0.0, 1.0)
			var d := pos.distance_to(a + seg * f) / Data.U
			if d < LANE_HALF:
				var at := (along + f * seg_len) / Data.U
				var k := 1.0 - smoothstep(LANE_CORE, LANE_HALF, d)
				k *= smoothstep(0.0, LANE_TAPER, minf(at, float(l.len) / Data.U - at))
				if k > out.z:
					var v: Vector2 = seg / seg_len * float(l.strength) * k
					out = Vector3(v.x, v.y, k)
			along += seg_len
	return out


## 0 inside a calm pocket, 1 in open current, smooth in between.
func strength_at(pos: Vector2) -> float:
	return smoothstep(CALM_EDGE.x, CALM_EDGE.y, calm_noise.get_noise_2dv(pos))


func whirl_force(pos: Vector2) -> Vector2:
	var out := Vector2.ZERO
	for w in whirlpools:
		var d: Vector2 = w.pos - pos
		var dist := d.length()
		if dist < w.radius and dist > 1.0:
			var t: float = 1.0 - dist / w.radius
			var n := d / dist
			out += n * float(w.strength) * pow(t, 0.7) + n.orthogonal() * float(w.strength) * 0.6 * t
	return out


func in_core(pos: Vector2) -> bool:
	for w in whirlpools:
		if pos.distance_to(w.pos) < w.core:
			return true
	return false
