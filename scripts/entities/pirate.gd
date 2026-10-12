class_name Pirate
extends Ship
## Pirate ship AI (spec §7.4–7.5): Chase → Attack → Leave (leash / safe zone).

enum State { CHASE, ATTACK, LEAVE }

const BALL_SPEED := 8.0     # units/s
const BALL_RANGE := 10.0    # units
const LEASH := 25.0
const ENGAGE := 18.0

var type := "dinghy"
var data: Dictionary
var biome := "shallows"
var state := State.CHASE
var engaged := false
var relentless := false   # test spawns: never leash, time out or respect safe zones
var age := 0.0
var fire_cd := 2.0
var ram_cd := 0.0
var orbit_sign := 1.0
var wander_dir := Vector2.RIGHT
var invisible := false
var _ghost_t := 4.0
var _summon_t := 10.0
var lunge_t := 0.0     # shark: time left in the current lunge
var lunge_cd := 2.0
var midas := false   # set by Golden Koi hits; triples loot if this hit kills
var level := 0.0     # Game.enemy_level() at spawn: scales hp, damage, speed and loot
var dmg_scale := 1.0
var island_index := -1   # shore battery: index of the Port City it defends
var lair_uid := 0    # treasure-map boss: Game.treasure_maps uid whose bounty it carries
var submerged := false   # serpent: diving (untargetable, shots pass over)
var _dive_t := 0.0
var _dive_cd := 6.0
var _trail: Array[Vector2] = []   # serpent body points, world space, head first


func setup(t: String, from_biome: String) -> void:
	type = t
	data = Data.PIRATES[t]
	biome = from_biome
	level = Game.enemy_level(from_biome)
	dmg_scale = 1.0 + 0.6 * level
	max_hp = Data.enemy_hp(t, from_biome)   # level scales damage/speed/loot, not hp
	hp = max_hp
	radius = float(data.radius) * Data.U
	orbit_sign = 1.0 if randf() < 0.5 else -1.0
	fire_cd = randf_range(1.0, float(data.fire_cd) + 0.5)
	add_to_group("pirates")


func is_targetable() -> bool:
	return not dead and not invisible


func _process(delta: float) -> void:
	if dead:
		return
	age += delta
	tick_ship(delta)
	if dead:
		return
	fire_cd -= delta
	ram_cd -= delta
	if data.behavior == "fort":   # stationary on land: no steering, island push or rams
		_fort_update(delta)
		return
	if data.get("invisible", false):
		_ghost_cycle(delta)
	var boat: Boat = world.boat
	var to_p := boat.position - position
	var dist := to_p.length() / Data.U
	var desired := Vector2.ZERO
	var speed := float(data.speed) * (1.0 + 0.12 * minf(level, 1.0))

	if state != State.LEAVE:
		if dist < ENGAGE:
			engaged = true
		if boat.dead:
			state = State.LEAVE
		elif relentless:
			engaged = true
			state = State.ATTACK
		elif world.player_in_safe_zone() or (engaged and dist > LEASH) or (not engaged and age > 45.0):
			state = State.LEAVE
		elif engaged:
			state = State.ATTACK

	if status.is_stunned():
		desired = Vector2.ZERO
	elif state == State.LEAVE:
		desired = -to_p.normalized()
		if dist > 45.0:
			world.despawn_pirate(self)
			return
	elif status.has("blind"):
		if randf() < delta * 0.5:
			wander_dir = Vector2.RIGHT.rotated(randf() * TAU)
		desired = wander_dir
	else:
		desired = _attack_steer(to_p, dist, boat)

	desired += _avoid_safe_zones() + _avoid_islands()
	if desired != Vector2.ZERO:
		rotation = wrapf(rotate_toward(rotation, desired.angle(), deg_to_rad(float(data.turn)) * delta), -PI, PI)
	var move := speed * status.speed_mult() * (1.0 if desired != Vector2.ZERO else 0.0)
	if type == "lord" and hp < max_hp * 0.33:
		move *= 1.3
	if lunge_t > 0.0 or submerged:
		move *= 1.8
	velocity = velocity.lerp(heading() * move * Data.U, 1.0 - exp(-2.0 * delta))
	position += (velocity + impulse) * delta
	world.push_off_islands(self)
	_collide_with_player(boat)
	queue_redraw()


func _attack_steer(to_p: Vector2, dist: float, boat: Boat) -> Vector2:
	var radial := to_p.normalized()
	match data.behavior:
		"ram":
			if ram_cd > 0.0:
				return (-radial).rotated(0.7 * orbit_sign)
			var t := dist / float(data.speed)
			return ((boat.position + boat.velocity * t * 0.5) - position).normalized()
		"lord":
			_lord_actions()
			return _orbit(radial, dist)
		"shark":
			return _shark_steer(radial, dist, boat)
		"kraken":
			_kraken_actions(dist, boat)
			return _orbit(radial, dist)
		"serpent":
			return _serpent_steer(radial, dist, boat)
		_:
			if dist < BALL_RANGE and fire_cd <= 0.0 and not invisible:
				_fire(int(data.shots), boat)
				fire_cd = float(data.fire_cd)
			return _orbit(radial, dist)


func _orbit(radial: Vector2, dist: float) -> Vector2:
	var orbit := float(data.orbit)
	if dist > orbit + 6.0:
		return radial
	var tangent := radial.orthogonal() * orbit_sign
	return (tangent + radial * clampf((dist - orbit) / 3.0, -1.0, 1.0) * 1.2).normalized()


## Pirate Lord phases: broadsides, then summons Dinghies, then rapid wide volleys.
func _lord_actions() -> void:
	var boat: Boat = world.boat
	var dist := position.distance_to(boat.position) / Data.U
	var phase := 1 if hp > max_hp * 0.66 else (2 if hp > max_hp * 0.33 else 3)
	if dist < BALL_RANGE + 2.0 and fire_cd <= 0.0:
		_fire(3 if phase < 3 else 5, boat)
		fire_cd = float(data.fire_cd) * (0.75 if phase == 3 else 1.0)
	if phase >= 2:
		_summon_t -= get_process_delta_time()
		if _summon_t <= 0.0:
			_summon_t = 14.0
			world.director.summon_dinghies(position, 2)


## Shark: circles the boat, then lunges straight in for a bite and peels away.
func _shark_steer(radial: Vector2, dist: float, boat: Boat) -> Vector2:
	var delta := get_process_delta_time()
	lunge_cd -= delta
	if lunge_t > 0.0:
		lunge_t -= delta
		if ram_cd > 0.0:   # already bit: break off
			lunge_t = 0.0
		var t := dist / (float(data.speed) * 1.8)
		return ((boat.position + boat.velocity * t * 0.6) - position).normalized()
	if ram_cd > 0.0:
		return (-radial).rotated(0.9 * orbit_sign)
	if lunge_cd <= 0.0 and dist < 9.0:
		lunge_t = 0.9
		lunge_cd = randf_range(2.5, 4.0)
		Sfx.play("shark_lunge")
	return _orbit(radial, dist)


## Kraken: drifts toward the boat, drags it closer, and slams tentacles at it.
## More tentacles and faster slams as it loses HP.
func _kraken_actions(dist: float, boat: Boat) -> void:
	if dist < 9.0 and not boat.dead:
		boat.impulse += (position - boat.position).normalized() * 6.0 * Data.U * get_process_delta_time()
	if fire_cd > 0.0 or dist > 18.0:
		return
	var frac := hp / max_hp
	var slams := 1 if frac > 0.5 else (2 if frac > 0.25 else 3)
	fire_cd = float(data.fire_cd) * (1.0 if frac > 0.5 else 0.7)
	for i in slams:
		var s := TentacleSlam.new()
		s.world = world
		s.damage = float(data.shot_dmg) * dmg_scale
		s.from = position
		var lead := boat.velocity * 0.9
		var jitter := Vector2.ZERO if i == 0 else Vector2.RIGHT.rotated(randf() * TAU) * randf_range(2.0, 3.5) * Data.U
		s.position = boat.position + lead + jitter
		world.fx_layer.add_child(s)


## Serpent: circles and spits, then dives and resurfaces under the boat to bite.
## Dives come faster and volleys quicker once it is badly hurt.
func _serpent_steer(radial: Vector2, dist: float, boat: Boat) -> Vector2:
	var delta := get_process_delta_time()
	var hurt := hp < max_hp * 0.4
	_dive_cd -= delta
	if submerged:
		_dive_t -= delta
		if _dive_t <= 0.0:
			_surface(boat)
		var t := dist / (float(data.speed) * 1.8)
		return ((boat.position + boat.velocity * t * 0.8) - position).normalized()
	if _dive_cd <= 0.0 and dist < 16.0:
		submerged = true
		invisible = true
		_dive_t = 2.4
		world.spawn_fx("splash", position, radius * 2.0, Color.WHITE)
		Sfx.play("shark_lunge")
		return radial
	if dist < BALL_RANGE + 3.0 and fire_cd <= 0.0:
		_fire(int(data.shots) + (1 if hurt else 0), boat)
		fire_cd = float(data.fire_cd) * (0.75 if hurt else 1.0)
	return _orbit(radial, dist)


func _surface(boat: Boat) -> void:
	submerged = false
	invisible = false
	_dive_cd = randf_range(5.0, 7.0) if hp < max_hp * 0.4 else randf_range(7.0, 10.0)
	world.spawn_fx("splash", position, radius * 2.5, Color.WHITE)
	var d := boat.position - position
	if not boat.dead and d.length() < radius + boat.radius + 2.0 * Data.U:
		boat.take_damage(float(data.ram_dmg) * dmg_scale * 1.25)
		boat.impulse += d.normalized() * 8.0 * Data.U
		ram_cd = 1.5
		Game.haptic(120)
		Sfx.play("shark_bite")


## Shore battery: swings its barrel toward the boat and fires long-range,
## leading volleys; faster and wider once badly damaged.
func _fort_update(delta: float) -> void:
	var boat: Boat = world.boat
	var to_p := boat.position - position
	var dist := to_p.length() / Data.U
	if dist > 45.0:
		world.despawn_pirate(self)
		return
	var stunned := status.is_stunned()
	if not stunned:
		rotation = rotate_toward(rotation, to_p.angle(), deg_to_rad(float(data.turn)) * delta)
	if not stunned and not status.has("blind") and not boat.dead and not world.player_in_safe_zone() \
			and dist < Data.FORT_RANGE and fire_cd <= 0.0:
		var hurt := hp < max_hp * 0.5
		var shots := int(data.shots) + (1 if hurt else 0)
		var t := to_p.length() / (Combat.BALL_SPEED * Data.U)
		var aim := ((boat.position + boat.velocity * t) - position).angle()
		var spread := deg_to_rad(5.0) * status.spread_mult()
		for i in shots:
			var a := aim + (i - (shots - 1) * 0.5) * deg_to_rad(6.0) + randf_range(-spread, spread)
			world.combat.spawn_cannonball(self, Vector2.RIGHT.rotated(a), float(data.shot_dmg) * dmg_scale, Data.FORT_RANGE + 1.0)
		world.spawn_fx("boom", position + Vector2.RIGHT.rotated(rotation) * radius * 1.4, radius * 0.6, Color(1.0, 0.7, 0.3))
		Sfx.play("pirate_fire")
		fire_cd = float(data.fire_cd) * (0.75 if hurt else 1.0)
	queue_redraw()


## Shore battery destroyed: pays out directly (it stands on land, so no wreck)
## and silences its port for good.
func _fort_destroyed() -> void:
	var gold := int(randi_range(int(data.gold[0]), int(data.gold[1])) * (1.0 + 0.5 * level))
	Game.add_gold(gold)
	world.float_text(position + Vector2(0, -radius - 20), "+%d Gold" % gold, Color(1, 0.85, 0.2), 24)
	world.spawn_fx("boom", position, radius * 2.5, Color(1.0, 0.6, 0.2))
	Sfx.play("ship_sink")
	Game.haptic(200)
	if island_index >= 0:
		Game.island_state(island_index).done = true
		var town := "The port"
		for isl in world.islands:
			if isl.index == island_index:
				town = isl.island_name
		Game.say("Battery silenced! %s will trade with you now." % town, Color(1.0, 0.85, 0.3))
		Game.save_game()
	world.despawn_pirate(self)


func _fire(shots: int, boat: Boat) -> void:
	var to := boat.position - position
	var t := to.length() / (BALL_SPEED * Data.U)
	var aim := ((boat.position + boat.velocity * t) - position).angle()
	var spread := deg_to_rad(6.0) * status.spread_mult()
	var fan := deg_to_rad(7.0)
	for i in shots:
		var a := aim + (i - (shots - 1) * 0.5) * fan + randf_range(-spread, spread)
		world.combat.spawn_cannonball(self, Vector2.RIGHT.rotated(a), float(data.shot_dmg) * dmg_scale)
	Sfx.play("pirate_fire")


func _ghost_cycle(delta: float) -> void:
	_ghost_t -= delta
	if _ghost_t <= 0.0:
		invisible = not invisible
		_ghost_t = 3.0 if invisible else 4.0


## Steers away from island shores before bumping into them.
func _avoid_islands() -> Vector2:
	var push := Vector2.ZERO
	for isl in world.islands:
		var d: Vector2 = position - isl.position
		if d.length() < isl.land_radius + radius + 2.0 * Data.U:
			push += d.normalized() * 1.5
	return push


func _avoid_safe_zones() -> Vector2:
	var push := Vector2.ZERO
	for s in world.shops:
		var d: Vector2 = position - s.position
		var r: float = s.safe_radius + radius
		if d.length() < r:
			push += d.normalized() * 3.0
			position = s.position + d.normalized() * r   # pirates cannot enter the dock radius
	return push


func _collide_with_player(boat: Boat) -> void:
	if boat.dead or submerged:
		return
	var d := position - boat.position
	var min_d := radius + boat.radius
	if d.length() >= min_d or d == Vector2.ZERO:
		return
	var n := d.normalized()
	position = boat.position + n * min_d
	if ram_cd <= 0.0:
		ram_cd = 1.5
		boat.take_damage(float(data.ram_dmg) * dmg_scale)
		if type == "shark":
			boat.status.apply("bleed", 3.0, 3.0)
			Sfx.play("shark_bite")
		boat.impulse -= n * 6.0 * Data.U
		impulse += n * 6.0 * Data.U
		Game.haptic(80)
		Sfx.play("ram")


func _on_died() -> void:
	if data.behavior == "fort":
		_fort_destroyed()
		return
	var gold := int(randi_range(int(data.gold[0]), int(data.gold[1])) * (1.0 + 0.5 * level))
	if midas:
		gold *= 3
		world.float_text(position + Vector2(0, -radius - 20), "MIDAS ×3!", Color(1, 0.85, 0.2))
	var fish := []
	if randf() < float(data.fish_chance):
		fish.append(Data.make_fish(Data.roll_loot_fish(biome, data.fish_rarity), -1.0, biome))
	if data.get("boss", false):
		fish.append(Data.make_fish(Data.roll_loot_fish(biome, "epic"), -1.0, biome))
	if lair_uid > 0:
		var m := Game.complete_boss_map(lair_uid)
		if not m.is_empty():
			var bm: Dictionary = Data.BOSS_MAPS[m.kind]
			var bounty := randi_range(int(bm.bounty[0]), int(bm.bounty[1]))
			gold += bounty
			fish.append(Data.make_fish(Data.roll_loot_fish(biome, bm.loot), -1.0, biome))
			world.float_text(position + Vector2(0, -radius - 44), "BOUNTY +%d" % bounty, Color(1, 0.85, 0.2), 26)
			Game.say("Treasure map complete: %s!" % bm.name, Color(1.0, 0.85, 0.3))
		var lair: Lair = world.lair_for(lair_uid)
		if lair != null:
			lair.queue_free()
	if data.get("creature", false):
		world.spawn_fx("splash", position, radius * 2.0, Color.WHITE)
		world.spawn_fx("boom", position, radius * 1.5, Color(0.6, 0.05, 0.1))
		Sfx.play("creature_die")
		if type == "kraken":
			Game.say("The Kraken sinks into the deep!", Color(1.0, 0.85, 0.3))
		elif data.get("boss", false):
			Game.say("The %s is slain!" % data.name, Color(1.0, 0.85, 0.3))
	else:
		world.spawn_fx("boom", position, radius * 2.0, Color(1.0, 0.6, 0.2))
		Sfx.play("ship_sink")
	if gold > 0 or not fish.is_empty():
		world.spawn_wreck(position, gold, fish)
	world.despawn_pirate(self)


func _damage_color() -> Color:
	return Color(1.0, 0.95, 0.5)


func _draw() -> void:
	if data.behavior == "fort":
		_draw_fort()
		draw_bars(true)
		return
	var alpha := 0.15 if invisible else (0.75 if type == "ghost" else 1.0)
	var mod := Color(1, 1, 1, alpha)
	if hit_flash > 0.0:
		mod = Color(1, 0.6, 0.6, alpha)
	var t := Art.tex("pirate_" + type)
	var w := radius * float(data.get("art_scale", 2.8))
	var wiggle := 0.0
	if type == "shark":
		wiggle = sin(age * (14.0 if lunge_t > 0.0 else 7.0)) * 0.08
	elif data.behavior == "kraken":
		w *= 1.0 + sin(age * 2.0) * 0.03
	elif data.behavior == "serpent":
		_draw_serpent_body(mod)
		wiggle = sin(age * 5.0) * 0.12
	if t == null and type == "elder_kraken":
		t = Art.tex("pirate_kraken")
		mod *= Color(0.75, 0.6, 1.0)
	if t != null:
		Art.draw_tex(self, t, Vector2.ZERO, w, wiggle, mod)
	else:
		_draw_placeholder(mod)
	if not invisible:
		draw_bars(hp < max_hp or data.get("boss", false))


func _draw_placeholder(mod: Color) -> void:
	if data.get("creature", false):
		_draw_creature_placeholder(mod)
		return
	var L := radius * 1.35
	var W := radius * 0.6
	var hull_c: Color = data.hull
	var sail_c: Color = data.sail
	var hull := PackedVector2Array([Vector2(L, 0), Vector2(L * 0.35, -W), Vector2(-L * 0.9, -W * 0.85),
		Vector2(-L * 0.9, W * 0.85), Vector2(L * 0.35, W)])
	draw_colored_polygon(hull, hull_c * mod)
	var outline := hull.duplicate()
	outline.append(hull[0])
	draw_polyline(outline, hull_c.darkened(0.6) * mod, 2.0)
	var masts := 1 if radius < 1.0 * Data.U else (2 if radius < 1.6 * Data.U else 3)
	for m in masts:
		var x := L * 0.25 - m * L * 0.5
		draw_rect(Rect2(x - L * 0.07, -W * 1.25, L * 0.14, W * 2.5), sail_c * mod)
		if type != "ironclad":
			draw_circle(Vector2(x, 0), W * 0.25, Color(0.95, 0.95, 0.9, mod.a))   # skull dot
	if type == "ironclad":
		draw_rect(Rect2(-L * 0.6, -W * 0.5, L * 1.0, W), Color(0.25, 0.27, 0.3) * mod)
	if type == "lord":
		draw_polyline(outline, Color(1.0, 0.8, 0.2, mod.a), 3.0)


func _draw_creature_placeholder(mod: Color) -> void:
	var body: Color = data.hull
	var dark: Color = data.sail
	if data.behavior == "serpent":   # head only; the body is drawn by _draw_serpent_body
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
		draw_circle(Vector2(radius * 0.2, 0), radius * 0.9, body * mod)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		draw_colored_polygon(PackedVector2Array([Vector2(radius * 0.9, -radius * 0.25), Vector2(radius * 1.35, 0), Vector2(radius * 0.9, radius * 0.25)]), body.darkened(0.3) * mod)
		for sy in [-1.0, 1.0]:
			draw_line(Vector2(-radius * 0.3, sy * radius * 0.35), Vector2(-radius * 0.9, sy * radius * 0.8), dark * mod, radius * 0.18)
			draw_circle(Vector2(radius * 0.55, sy * radius * 0.3), radius * 0.13, Color(1.0, 0.85, 0.2, mod.a))
		return
	if type == "shark":
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, radius * 1.3, body * mod)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		draw_colored_polygon(PackedVector2Array([Vector2(-radius, 0), Vector2(-radius * 1.8, -radius * 0.6), Vector2(-radius * 1.8, radius * 0.6)]), dark * mod)
		for sy in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(radius * 0.3, 0), Vector2(-radius * 0.2, sy * radius * 0.95), Vector2(-radius * 0.1, 0)]), dark * mod)
		return
	for i in 8:
		var a := PI * 0.55 + PI * 0.9 * i / 7.0 + sin(age * 2.0 + i) * 0.15
		draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(a) * radius * 1.4, dark * mod, radius * 0.25)
	draw_circle(Vector2(radius * 0.3, 0), radius * 0.75, body * mod)
	for sy in [-1.0, 1.0]:
		draw_circle(Vector2(radius * 0.7, sy * radius * 0.3), radius * 0.12, Color(1.0, 0.82, 0.25, mod.a))


## Serpent body: segments trailing along the path the head swam, shrinking
## toward the tail, with a fin ridge. Records the path as it draws.
func _draw_serpent_body(mod: Color) -> void:
	var segs := int(data.get("segments", 8))
	var gap := radius * 0.75
	if _trail.is_empty() or position.distance_to(_trail[0]) > gap:
		_trail.push_front(position)
		if _trail.size() > segs + 1:
			_trail.resize(segs + 1)
	var body: Color = data.hull
	var fin: Color = data.sail
	for i in range(_trail.size() - 1, 0, -1):
		var p := to_local(_trail[i])
		var k := float(i) / segs
		var r := radius * lerpf(0.85, 0.3, k)
		draw_circle(p, r, (body if i % 2 == 0 else body.darkened(0.15)) * mod)
		var ahead := to_local(_trail[i - 1]) - p
		if ahead.length() > 0.1 and i % 2 == 1:
			var n := ahead.normalized()
			draw_colored_polygon(PackedVector2Array([p + n * r * 0.6, p - n * r * 0.6, p + n.orthogonal() * r * 0.2 - n * r * 0.1]), fin * mod)


## Shore battery: a stone bastion (drawn unrotated) with a barrel that tracks
## the boat. Art hook: "pirate_fort_cannon" (the barrel, pointing right).
func _draw_fort() -> void:
	var flash := Color(1, 0.6, 0.6) if hit_flash > 0.0 else Color.WHITE
	var stone: Color = data.hull
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	var wall := PackedVector2Array()
	for i in 8:
		wall.append(Vector2.RIGHT.rotated(TAU * (i + 0.5) / 8.0) * radius * 1.35)
	draw_colored_polygon(wall, stone.darkened(0.25) * flash)
	var top := PackedVector2Array()
	for p in wall:
		top.append(p * 0.82)
	draw_colored_polygon(top, stone * flash)
	for i in 8:   # crenellations
		var p := Vector2.RIGHT.rotated(TAU * i / 8.0) * radius * 1.2
		draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), stone.lightened(0.15) * flash)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var t := Art.tex("pirate_fort_cannon")
	if t != null:
		Art.draw_tex(self, t, Vector2(radius * 0.4, 0), radius * 2.0, 0.0, flash)
	else:
		var barrel: Color = data.sail
		draw_rect(Rect2(Vector2(0, -radius * 0.22), Vector2(radius * 1.5, radius * 0.44)), barrel * flash)
		draw_rect(Rect2(Vector2(radius * 1.3, -radius * 0.28), Vector2(radius * 0.25, radius * 0.56)), barrel.lightened(0.2) * flash)
		draw_circle(Vector2.ZERO, radius * 0.45, barrel.lightened(0.1) * flash)
