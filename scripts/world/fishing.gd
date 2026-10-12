class_name FishingSystem
extends Node2D
## Cast → wait → bite → tension-bar reel minigame (spec §4.1).
## Draws the line, bobber and fish shadows in the world; the HUD reads the
## public state to draw the power meter and tension bar.

enum State { IDLE, CHARGE, FLY, WAIT, BITE, REEL }

const MAX_THROTTLE := 0.25
const CANCEL_THROTTLE := 0.45
const BITE_WINDOW := 0.75
const THRASH := {   # rarity -> [strength, interval, seconds in green to land]
	"junk": [0.1, 2.0, 1.5], "common": [0.18, 1.6, 2.5], "uncommon": [0.24, 1.3, 3.5],
	"rare": [0.3, 1.1, 4.5], "epic": [0.36, 0.95, 5.5], "legendary": [0.42, 0.8, 7.0],
}

var world: Node
var state := State.IDLE
var power := 0.0
var bobber := Vector2.ZERO
var tension := 0.0
var progress := 0.0
var reel_held := false
var fish_id := ""
var fish_size := 1.0

var _charge_t := 0.0
var _fly_t := 0.0
var _fly_from := Vector2.ZERO
var _bite_t := 0.0
var _window := 0.0
var _luck := 0.0
var _bite_mult := 1.0
var _thrash_t := 0.0
var _thrash_pattern := "spike"
var _double_t := -1.0
var _surge_t := 0.0
var _snap_t := 0.0
var _slack_t := 0.0
var _shadows := []


func is_active() -> bool:
	return state != State.IDLE


func button_label() -> String:
	match state:
		State.CHARGE: return "Release!"
		State.FLY, State.WAIT: return "Reel In"
		State.BITE: return "HOOK!"
		State.REEL: return "Reel" if Game.settings.reel_input == "hold" else "Tap!"
	return "Cast"


func green_zone() -> Vector2:
	var w := 0.025 * Game.lvl("rod")
	return Vector2(0.35 - w, 0.72 + w)


func cast_pressed() -> void:
	var boat: Boat = world.boat
	if boat.dead:
		return
	match state:
		State.IDLE:
			if boat.throttle >= MAX_THROTTLE:
				Game.say("Slow down to cast (throttle under 25%)", Color(1, 0.9, 0.6))
				return
			if world.current_biome == "abyss" and Game.lvl("deep_line") == 0:
				Game.say("Your line can't reach the Abyss depths. (Deep-Sea Line needed)", Color(0.7, 0.8, 1.0))
				return
			state = State.CHARGE
			_charge_t = 0.0
			power = 0.0
		State.FLY, State.WAIT:
			_end("Line reeled in.")
		State.BITE:
			_hook()
		State.REEL:
			reel_held = true
			if Game.settings.reel_input == "tap":
				tension += 0.11


func cast_released() -> void:
	match state:
		State.CHARGE:
			_cast()
		State.REEL:
			reel_held = false


func cancel() -> void:
	if state != State.IDLE:
		_end("")


func _cast() -> void:
	var boat: Boat = world.boat
	_luck = 0.06 * Game.lvl("rod")
	_bite_mult = 1.0 - 0.06 * Game.lvl("rod")
	if Game.golden_bait > 0:
		Game.golden_bait -= 1
		_luck += 1.0
		_bite_mult *= 0.5
		Game.say("Golden Bait used!", Color(1, 0.85, 0.3))
	elif Game.bait > 0:
		Game.bait -= 1
		_luck += 0.25
		_bite_mult *= 0.6
	Game.hold_changed.emit()
	_fly_from = boat.position
	bobber = boat.position + boat.heading() * (1.5 + power * 4.5) * Data.U
	_fly_t = 0.0
	state = State.FLY
	Sfx.play("cast")


## Each shadow is a pre-rolled fish; its drawn size is that fish's real length
## (species length × size roll), so a big shadow is a big catch. _shadows[0] bites.
## Casting onto a roaming shadow (FishShadows) makes that fish the biter, sooner.
func _start_wait() -> void:
	if world.island_at(bobber) != null:
		_end("Your line snags on the shore.")
		return
	state = State.WAIT
	var hot: bool = world.at_hotspot(bobber)
	_bite_t = randf_range(2.0, 8.0) * _bite_mult * (0.7 if hot else 1.0)
	_shadows.clear()
	var target: Dictionary = world.fish_shadows.take_near(bobber)
	if not target.is_empty():
		_bite_t *= 0.5
		_shadows.append({"p": target.p, "v": target.v, "id": target.id, "size": target.size, "s": target.s})
	var biome := Data.biome_at(bobber)
	var luck: float = _luck + (0.4 if hot else 0.0) + world.island_luck(bobber) + (0.6 if Game.buff("fortune") else 0.0)
	for i in randi_range(2, 4) - _shadows.size():
		var id := Data.roll_fish(biome, luck)
		var size := Data.roll_size()
		_shadows.append({"p": bobber + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 3.0 * Data.U,
			"v": Vector2.RIGHT.rotated(randf() * TAU), "id": id, "size": size,
			"s": shadow_scale(id, size)})


## Shadow width in units for a fish: tiny sardines read small, squid read huge.
static func shadow_scale(id: String, size: float) -> float:
	return clampf(float(Data.FISH[id].len) * size * 1.3, 0.4, 2.6)


func _bite() -> void:
	state = State.BITE
	fish_id = _shadows[0].id
	fish_size = _shadows[0].size
	_window = BITE_WINDOW + 0.05 * Game.lvl("rod")
	Game.haptic(70)
	Sfx.play("bite")


func _hook() -> void:
	state = State.REEL
	tension = 0.45
	progress = 0.15
	reel_held = Game.settings.reel_input == "hold"
	_snap_t = 0.0
	_slack_t = 0.0
	_thrash_pattern = ["spike", "double", "surge"][absi(hash(fish_id)) % 3]
	_thrash_t = 1.0
	Sfx.play("hook")


func _process(delta: float) -> void:
	var boat: Boat = world.boat
	match state:
		State.CHARGE:
			_charge_t += delta
			power = 1.0 - absf(fmod(_charge_t * 1.2, 2.0) - 1.0)
		State.FLY:
			_fly_t += delta / 0.4
			if _fly_t >= 1.0:
				_start_wait()
		State.WAIT:
			_drift(delta)
			if not _line_ok(boat):
				return
			_bite_t -= delta
			_move_shadows(delta)
			if _bite_t <= 0.0:
				_bite()
		State.BITE:
			_drift(delta)
			if not _line_ok(boat):
				return
			_window -= delta
			if _window <= 0.0:
				Game.say("It got away...", Color(0.8, 0.8, 0.8))
				_start_wait()
		State.REEL:
			_reel(delta)
	queue_redraw()


## The bobber and the fish around it ride the same current as the boat, so a
## drifting boat doesn't drag itself off its own line.
func _drift(delta: float) -> void:
	var d: Vector2 = world.currents.sample(bobber) * Data.U * delta
	bobber += d
	for s in _shadows:
		s.p += d


func _line_ok(boat: Boat) -> bool:
	if boat.dead:
		_end("")
		return false
	if boat.throttle > CANCEL_THROTTLE or boat.position.distance_to(bobber) > 10.0 * Data.U:
		_end("You moved too fast — line reeled in.")
		return false
	return true


func _reel(delta: float) -> void:
	var line_lvl := Game.lvl("line")
	var rod := Game.lvl("rod")
	var params: Array = THRASH[Data.FISH[fish_id].rarity]
	var strength: float = params[0] * fish_size
	var rise := 0.6 / (1.0 + 0.1 * line_lvl)
	if Game.settings.reel_input == "hold" and reel_held:
		tension += rise * delta
	else:
		tension -= 0.5 * delta
	# Fish thrash pattern spikes tension.
	_thrash_t -= delta
	if _thrash_t <= 0.0:
		_thrash_t = float(params[1]) * randf_range(0.7, 1.3)
		match _thrash_pattern:
			"spike": tension += strength
			"double":
				tension += strength * 0.6
				_double_t = 0.25
			"surge": _surge_t = 0.6
		Game.haptic(25)
	if _double_t > 0.0:
		_double_t -= delta
		if _double_t <= 0.0:
			tension += strength * 0.6
	if _surge_t > 0.0:
		_surge_t -= delta
		tension += strength / 0.6 * delta
	tension = clampf(tension, 0.0, 1.05)
	var gz := green_zone()
	if tension >= gz.x and tension <= gz.y:
		progress += delta / float(params[2]) * (1.0 + 0.1 * rod)
	else:
		progress -= delta * 0.06
	progress = clampf(progress, 0.0, 1.0)
	if tension >= 1.0:
		_snap_t += delta
		if _snap_t > 0.12 + 0.12 * line_lvl:
			Sfx.play("line_snap")
			_end("The line snapped!")
			return
	else:
		_snap_t = 0.0
	if tension <= 0.03:
		_slack_t += delta
		if _slack_t > 1.6:
			_end("The fish slipped the hook.")
			return
	else:
		_slack_t = 0.0
	if progress >= 1.0:
		_catch()


func _catch() -> void:
	var item := Data.make_fish(fish_id, fish_size, Data.biome_at(bobber))
	var first := Game.record_catch(item)
	state = State.IDLE
	reel_held = false
	Sfx.play("catch")
	Game.haptic(50)
	world.hud.show_catch(item, first)
	if not Game.add_fish(item):
		world.open_hold_full(item)


func _end(msg: String) -> void:
	state = State.IDLE
	reel_held = false
	tension = 0.0
	progress = 0.0
	if msg != "":
		Game.say(msg, Color(0.9, 0.9, 0.9))


func _move_shadows(delta: float) -> void:
	for s in _shadows:
		s.v = s.v.rotated(randf_range(-1.5, 1.5) * delta)
		var to: Vector2 = bobber - s.p
		if to.length() > 3.5 * Data.U:
			s.v = s.v.lerp(to.normalized(), 0.05)
		if _bite_t < 1.2 and s == _shadows[0]:
			s.v = s.v.lerp(to.normalized(), 0.2)
		s.p += s.v * Data.U * 0.8 * delta


func bobber_draw_pos() -> Vector2:
	var boat: Boat = world.boat
	match state:
		State.FLY:
			return _fly_from.lerp(bobber, _fly_t) + Vector2(0, -sin(_fly_t * PI) * 40.0)
		State.REEL:
			var p := bobber.lerp(boat.position, progress * 0.7)
			return p + Vector2(randf_range(-2, 2), randf_range(-2, 2)) * tension * 3.0
	return bobber


func _draw() -> void:
	if state == State.IDLE or state == State.CHARGE:
		return
	var boat: Boat = world.boat
	var b := bobber_draw_pos()
	if state == State.WAIT or state == State.BITE:
		for s in _shadows:
			var t := Art.tex("fish_shadow")
			if t != null:
				Art.draw_tex(self, t, s.p, Data.U * s.s, s.v.angle())
			else:
				draw_set_transform(s.p, s.v.angle(), Vector2(1.0, 0.45))
				draw_circle(Vector2.ZERO, 0.5 * Data.U * s.s, Color(0, 0, 0, 0.22))
				draw_set_transform_matrix(Transform2D.IDENTITY)
	var start := boat.position + boat.heading().orthogonal() * 0.4 * Data.U
	var mid := (start + b) * 0.5 + Vector2(0, 12.0 * (1.0 - tension))
	var pts := PackedVector2Array()
	for i in 13:
		var k := i / 12.0
		pts.append(start.lerp(mid, k).lerp(mid.lerp(b, k), k))
	var line_c := Color(1, 1, 1, 0.8).lerp(Color(1, 0.3, 0.3, 0.9), tension if state == State.REEL else 0.0)
	draw_polyline(pts, line_c, 1.5)
	var bob := sin(Time.get_ticks_msec() / 250.0) * 2.0
	if state == State.BITE:
		bob = sin(Time.get_ticks_msec() / 40.0) * 4.0
		draw_arc(b, 14.0 + fmod(Time.get_ticks_msec() / 8.0, 20.0), 0, TAU, 20, Color(1, 1, 1, 0.6), 2.0)
	var bt := Art.tex("bobber")
	if bt != null:
		Art.draw_tex(self, bt, b + Vector2(0, bob), 0.5 * Data.U)
	else:
		draw_circle(b + Vector2(0, bob), 7.0, Color(0.95, 0.95, 0.95))
		draw_circle(b + Vector2(0, bob - 2), 5.0, Color(0.9, 0.15, 0.15))
	if state == State.REEL:
		Art.draw_fish(self, fish_id, b + Vector2(0, 10), shadow_scale(fish_id, fish_size) * Data.U, (boat.position - b).angle() + PI + sin(Time.get_ticks_msec() / 90.0) * 0.4, Color(0, 0, 0, 0.35))
