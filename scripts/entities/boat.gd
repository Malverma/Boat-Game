class_name Boat
extends Ship
## The player's boat: joystick steering, currents, hazards and the fish cannon.

const PROJ_SPEED := 9.0   # units/s, must match Combat.FISH_SPEED

var throttle := 0.0
var reload_left := 0.0
var reload_total := 3.0
var aim_dir := Vector2.RIGHT      # last cannon direction (world space)
var auto_reload := false          # set by firing: reload from the hold when the timer ends
var _hazard_cd := 0.0
var _fling_cd := 0.0
var _storm_cd := 0.0


func _ready() -> void:
	radius = 0.9 * Data.U
	max_hp = Game.max_hp()
	hp = clampf(Game.hp, 1.0, max_hp)
	Game.upgrades_changed.connect(_on_upgrades)


func _on_upgrades() -> void:
	max_hp = Game.max_hp()
	hp = minf(Game.hp if Game.hp > hp else hp, max_hp)
	queue_redraw()


func _process(delta: float) -> void:
	if dead:
		return
	tick_ship(delta)
	_move(delta)
	_hazards()
	reload_left = maxf(0.0, reload_left - delta)
	if auto_reload and reload_left <= 0.0:
		_auto_load()
	_fling_cd -= delta
	_hazard_cd -= delta
	_storm_cd -= delta
	Game.hp = hp
	queue_redraw()


func steer_input() -> Vector2:
	var v: Vector2 = world.hud.joystick_vector()
	if v == Vector2.ZERO:
		v = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return v


func _move(delta: float) -> void:
	var steer := steer_input()
	var forward := 0.0
	throttle = minf(steer.length(), 1.0)
	if throttle > 0.0:
		rotation = wrapf(rotate_toward(rotation, steer.angle(), deg_to_rad(Game.turn_rate()) * delta), -PI, PI)
		var align := maxf(0.25, heading().dot(steer.normalized()))
		forward = throttle * align * Game.top_speed()
	var h := heading()
	# Currents (spec §3.3): engine upgrades reduce the opposing component.
	var cur: Vector2 = world.currents.sample(position)
	var along := cur.dot(h)
	if along < 0.0 and throttle > 0.05:
		cur -= h * along * minf(Game.current_resist(), 0.9)
	var target: Vector2 = h * forward + cur + world.currents.whirl_force(position) + _storm_push()
	velocity = velocity.lerp(target * Data.U, 1.0 - exp(-2.0 * delta))
	position += (velocity + impulse) * delta
	world.push_off_islands(self)
	position = position.clamp(Vector2(-Data.U, -Data.U), Vector2(Data.WORLD_PX + Data.U, Data.WORLD_PX + Data.U))


## Storm wall at the map edge pushes the boat back toward open water (spec §3.1).
func _storm_push() -> Vector2:
	var p := position / Data.U
	var w := Data.WORLD_PX / Data.U
	var edge := 4.0
	var push := Vector2.ZERO
	if p.x < edge: push.x += (edge - p.x) * 2.5
	if p.x > w - edge: push.x -= (p.x - (w - edge)) * 2.5
	if p.y < edge: push.y += (edge - p.y) * 2.5
	if p.y > w - edge: push.y -= (p.y - (w - edge)) * 2.5
	if push != Vector2.ZERO and _storm_cd <= 0.0:
		_storm_cd = 6.0
		Game.say("The storm wall drives you back!", Color(0.8, 0.85, 1.0))
	return push


func _hazards() -> void:
	var hz: String = Data.BIOMES[world.current_biome].hazard
	var delta := get_process_delta_time()
	if (hz == "ice" and Game.lvl("reinforced_hull") == 0) or (hz == "heat" and Game.lvl("heat_plating") == 0):
		take_damage(3.0 * delta, false)
		if _hazard_cd <= 0.0:
			_hazard_cd = 5.0
			hit_flash = 0.2
			if hz == "ice":
				Game.say("Ice grinds your hull! (Reinforced Hull needed)", Color(0.7, 0.9, 1.0))
			else:
				Game.say("The heat scorches your hull! (Heat Plating needed)", Color(1.0, 0.55, 0.3))
	if _fling_cd <= 0.0 and world.currents.in_core(position):
		_fling_cd = 1.5
		take_damage(15.0)
		impulse = Vector2.RIGHT.rotated(randf() * TAU) * 16.0 * Data.U
		Game.say("The whirlpool spits you out!", Color(0.7, 0.8, 1.0))
		Game.haptic(120)


func _on_damaged(_amount: float) -> void:
	Game.hp = hp


func _on_died() -> void:
	world.on_player_died()


func _damage_color() -> Color:
	return Color(1.0, 0.35, 0.35)


# --- Cannon (spec §7.2–7.3) -----------------------------------------------------

func is_loaded() -> bool:
	return not Game.cannon.is_empty()


## LOAD button: moves the active ammo fish from the hold into the cannon.
## Pressing it while loaded unloads the fish back into the hold.
func load_cannon() -> void:
	if dead:
		return
	if is_loaded():
		if Game.add_fish(Game.cannon):
			Game.cannon = {}
			auto_reload = false   # unloading by hand stops the automatic reloads
		else:
			Game.say("Hold full — can't unload", Color(1, 0.6, 0.5))
		return
	if reload_left > 0.0:
		return
	var idx := Game.next_ammo_index()
	if idx < 0:
		world.hud.flash_no_ammo()
		Sfx.play("no_ammo")
		return
	Game.cannon = Game.remove_fish(idx)
	Sfx.play("load")
	Game.haptic(30)


## Reloads after a shot using the fire priority; stays empty if the hold is.
func _auto_load() -> void:
	auto_reload = false
	if is_loaded():
		return
	var idx := Game.auto_ammo_index()
	if idx < 0:
		return
	Game.cannon = Game.remove_fish(idx)
	Sfx.play("load")


## Fires the loaded fish in `dir` (any direction; the player taps where to shoot).
func fire(dir: Vector2) -> void:
	if dead or not is_loaded() or dir == Vector2.ZERO:
		return
	dir = dir.normalized()
	var item: Dictionary = Game.cannon
	Game.cannon = {}
	world.combat.fire_fish(self, item, dir)
	aim_dir = dir
	reload_total = Game.reload_time() + float(Data.FISH[item.id].get("reload_extra", 0.0))
	reload_left = reload_total
	auto_reload = true
	Game.hold_changed.emit()


## Nearest visible pirate in range and arc, with lead; otherwise straight ahead.
func auto_aim_dir() -> Vector2:
	var best: Ship = null
	var best_d := INF
	var max_d := (Game.cannon_range() + 2.0) * Data.U
	for p in world.get_pirates():
		if not p.is_targetable():
			continue
		var to: Vector2 = p.position - position
		var d := to.length()
		if d > max_d or d >= best_d:
			continue
		if absf(angle_difference(rotation, to.angle())) > Game.aim_half_arc():
			continue
		best = p
		best_d = d
	if best == null:
		return heading()
	var t := best_d / (PROJ_SPEED * Data.U)
	return (best.position + (best.velocity + best.impulse) * t) - position


# --- Drawing ------------------------------------------------------------------------

func _draw() -> void:
	var mod := Color(1, 0.5, 0.5) if hit_flash > 0.0 else Color.WHITE
	var t := Art.tex("boat")
	if t != null:
		Art.draw_tex(self, t, Vector2.ZERO, 2.6 * Data.U, 0.0, mod)
	else:
		_draw_placeholder(mod)
	# Cannon, pointing at the last aim direction.
	var cannon_angle := aim_dir.angle() - rotation
	var ct := Art.tex("boat_cannon")
	if ct != null:
		Art.draw_tex(self, ct, Vector2(0.35 * Data.U, 0), 0.9 * Data.U, cannon_angle, mod)
	else:
		draw_set_transform(Vector2(0.35 * Data.U, 0), cannon_angle, Vector2.ONE)
		var barrel := 16.0 + 3.0 * Game.lvl("barrel")
		draw_rect(Rect2(-4, -4, barrel, 8), Color(0.15, 0.15, 0.17) * mod)
		draw_circle(Vector2.ZERO, 6.0, Color(0.25, 0.25, 0.28) * mod)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	if is_loaded():   # loaded fish peeking out of the muzzle
		var muzzle := Vector2(0.35 * Data.U, 0) + Vector2.RIGHT.rotated(cannon_angle) * 0.55 * Data.U
		Art.draw_fish(self, Game.cannon.id, muzzle, 0.7 * Data.U, cannon_angle, mod)
	draw_bars(hp < max_hp)


func _draw_placeholder(mod: Color) -> void:
	var L := 1.2 * Data.U
	var W := 0.5 * Data.U
	var wood := Color(0.55, 0.35, 0.18)
	if Game.lvl("heat_plating") > 0:
		wood = Color(0.72, 0.42, 0.25)
	wood = wood.lerp(Color(0.5, 0.5, 0.55), Game.lvl("hull") * 0.08)
	var hull := PackedVector2Array([Vector2(L, 0), Vector2(L * 0.4, -W), Vector2(-L * 0.9, -W * 0.85),
		Vector2(-L * 0.9, W * 0.85), Vector2(L * 0.4, W)])
	draw_colored_polygon(hull, wood * mod)
	var outline := hull.duplicate()
	outline.append(hull[0])
	draw_polyline(outline, wood.darkened(0.5) * mod, 2.0)
	var deck := PackedVector2Array()
	for p in hull:
		deck.append(p * 0.75 + Vector2(-L * 0.05, 0))
	draw_colored_polygon(deck, wood.lightened(0.25) * mod)
	if Game.lvl("reinforced_hull") > 0:
		draw_polyline(PackedVector2Array([Vector2(L * 0.4, -W), Vector2(L, 0), Vector2(L * 0.4, W)]), Color(0.85, 0.92, 1.0) * mod, 4.0)
	for i in Game.lvl("hull"):
		var x := -L * 0.7 + i * L * 0.25
		draw_line(Vector2(x, -W * 0.85), Vector2(x, W * 0.85), Color(0.45, 0.47, 0.5, 0.8) * mod, 2.0)
	for i in Game.lvl("cargo"):
		draw_rect(Rect2(-L * 0.75 + (i % 2) * 11, -W * 0.5 + (i / 2) * 11, 9, 9), Color(0.7, 0.5, 0.25) * mod)
	# Mast and sail (sail widens with engine level).
	var sail_w := W * (1.15 + 0.06 * Game.lvl("engine"))
	draw_rect(Rect2(-L * 0.12, -sail_w, L * 0.14, sail_w * 2), Color(0.95, 0.92, 0.85) * mod)
	draw_circle(Vector2(-L * 0.05, 0), 4.0, Color(0.35, 0.22, 0.1) * mod)
