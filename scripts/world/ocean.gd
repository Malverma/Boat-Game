class_name Ocean
extends Node2D
## Animated water background (biome-tinted shader), current streaks, whirlpools
## and the boat's wake (spec §3.1, §3.3).

const MARGIN := 30.0 * Data.U
const STREAKS := 110
const LANE_STREAKS := 45

var world: Node
var _water: ColorRect
var _overlay: Node2D
var _streaks := []
var _lane_streaks := []
var _wake := []
var _wake_t := 0.0


func _ready() -> void:
	_water = ColorRect.new()
	_water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_water.position = Vector2(-MARGIN, -MARGIN)
	_water.size = Vector2.ONE * (Data.WORLD_PX + MARGIN * 2.0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ocean.gdshader")
	mat.set_shader_parameter("deep_tex", _biome_texture("deep", false))
	mat.set_shader_parameter("light_tex", _biome_texture("light", true))
	mat.set_shader_parameter("world_size", Vector2.ONE * Data.WORLD_PX)
	mat.set_shader_parameter("origin", Vector2(-MARGIN, -MARGIN))
	mat.set_shader_parameter("grid", float(Data.GRID))
	_water.material = mat
	add_child(_water)
	_overlay = Node2D.new()
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


func _biome_texture(key: String, sparkle_alpha: bool) -> ImageTexture:
	var img := Image.create(Data.GRID, Data.GRID, false, Image.FORMAT_RGBA8)
	for y in Data.GRID:
		for x in Data.GRID:
			var b: Dictionary = Data.BIOMES[Data.biome_at_sector(x, y)]
			var c: Color = b[key]
			c.a = float(b.sparkle) if sparkle_alpha else 1.0
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	var view: Rect2 = world.view_rect().grow(2.0 * Data.U)
	if _streaks.is_empty():
		for i in STREAKS:
			_streaks.append(_new_streak(view, randf()))
	for i in _streaks.size():
		var s: Dictionary = _streaks[i]
		s.life -= delta
		var v: Vector2 = world.currents.sample(s.pos) + world.currents.whirl_force(s.pos)
		s.vel = v
		s.pos += v * Data.U * delta
		if s.life <= 0.0 or not view.has_point(s.pos):
			_streaks[i] = _new_streak(view, 0.0)
	_update_lane_streaks(delta, view)
	# Wake behind the player.
	_wake_t -= delta
	var boat: Node2D = world.boat
	if _wake_t <= 0.0 and boat != null and not boat.dead and boat.velocity.length() > 0.8 * Data.U:
		_wake_t = 0.06
		_wake.append({"pos": boat.position - boat.heading() * 1.0 * Data.U, "t": 0.0})
	for w in _wake:
		w.t += delta
	while not _wake.is_empty() and _wake[0].t > 1.6:
		_wake.pop_front()
	_overlay.queue_redraw()


## Extra streaks seeded inside on-screen jet stream lanes so they read clearly.
func _update_lane_streaks(delta: float, view: Rect2) -> void:
	var visible := []
	for l in world.currents.lanes:
		if view.intersects(l.rect):
			visible.append(l)
	if visible.is_empty():
		_lane_streaks.clear()
		return
	while _lane_streaks.size() < LANE_STREAKS:
		_lane_streaks.append({"life": 0.0})
	for i in _lane_streaks.size():
		var s: Dictionary = _lane_streaks[i]
		s.life -= delta
		if s.life <= 0.0 or not view.has_point(s.pos):
			s = _new_lane_streak(visible.pick_random(), view)
			_lane_streaks[i] = s
		if s.has("hide"):
			continue
		var v: Vector2 = world.currents.sample(s.pos)
		s.vel = v
		s.pos += v * Data.U * delta


func _new_lane_streak(lane: Dictionary, view: Rect2) -> Dictionary:
	var pts: PackedVector2Array = lane.pts
	for attempt in 4:
		var i := randi_range(1, pts.size() - 1)
		var across := (pts[i] - pts[i - 1]).normalized().orthogonal()
		var p := pts[i - 1].lerp(pts[i], randf()) + across * randf_range(-1.6, 1.6) * Data.U
		if view.has_point(p):
			var life := randf_range(1.0, 2.2)
			return {"pos": p, "life": life, "max": life, "vel": Vector2.ZERO}
	# Lane mostly off-screen: sit out briefly (not moved or drawn), then retry.
	return {"pos": view.get_center(), "life": 0.2, "max": 1.0, "vel": Vector2.ZERO, "hide": true}


func _new_streak(view: Rect2, age: float) -> Dictionary:
	var life := randf_range(1.5, 3.5)
	return {"pos": view.position + Vector2(randf() * view.size.x, randf() * view.size.y),
		"life": life * (1.0 - age), "max": life, "vel": Vector2.ZERO}


func _draw_overlay() -> void:
	for w in _wake:
		var k: float = w.t / 1.6
		_overlay.draw_arc(w.pos, 6.0 + k * 22.0, 0, TAU, 16, Color(1, 1, 1, 0.35 * (1.0 - k)), 2.0)
	# Jet stream lanes: a faint band, always shown since they're a route feature.
	var lane_view: Rect2 = world.view_rect().grow(4.0 * Data.U)
	for l in world.currents.lanes:
		if lane_view.intersects(l.rect):
			_overlay.draw_polyline(l.pts, Color(0.75, 0.95, 1.0, 0.07), world.currents.LANE_HALF * 1.6 * Data.U, true)
			_overlay.draw_polyline(l.pts, Color(0.75, 0.95, 1.0, 0.06), world.currents.LANE_CORE * 1.6 * Data.U, true)
	if not Game.settings.show_currents:
		return
	for s in _streaks + _lane_streaks:
		var v: Vector2 = s.vel
		var strength := v.length()
		if strength < 0.15:
			continue
		var k: float = clampf(s.life / s.max, 0.0, 1.0)
		var a := sin(k * PI) * clampf(strength / 2.5, 0.25, 0.8) * 0.5
		var tail: Vector2 = s.pos - v.normalized() * (10.0 + strength * 8.0)
		_overlay.draw_line(tail, s.pos, Color(1, 1, 1, a), 2.0)
	var view: Rect2 = world.view_rect().grow(10.0 * Data.U)
	var t := Time.get_ticks_msec() / 1000.0
	for w in world.currents.whirlpools:
		if not view.has_point(w.pos):
			continue
		var tex := Art.tex("whirlpool")
		if tex != null:
			Art.draw_tex(_overlay, tex, w.pos, w.radius * 1.4, -t * 1.5)
			continue
		for arm in 4:
			var pts := PackedVector2Array()
			for i in 24:
				var f := i / 23.0
				var ang := -t * 1.5 + arm * TAU / 4.0 + f * 4.0
				pts.append(w.pos + Vector2.RIGHT.rotated(ang) * lerpf(w.core, w.radius * 0.8, f))
			_overlay.draw_polyline(pts, Color(0.85, 0.95, 1.0, 0.35), 3.0)
		_overlay.draw_circle(w.pos, w.core, Color(0.02, 0.03, 0.08, 0.8))
