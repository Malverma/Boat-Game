class_name Combat
extends Node
## Spawns projectiles and resolves fish cannon effects (spec §5, §7).

const FISH_SPEED := 9.0
const BALL_SPEED := 8.0
const BALL_RANGE := 10.0

var world: Node


func fire_fish(shooter: Boat, item: Dictionary, dir: Vector2) -> void:
	var f: Dictionary = Data.FISH[item.id]
	var dmg := Data.fish_damage(item)
	if f.effect == "scatter":
		for a in [-0.2, 0.0, 0.2]:
			var p := _spawn(shooter, dir.rotated(a), dmg, item.id, f.effect)
			p.small = true
	else:
		var p := _spawn(shooter, dir, dmg, item.id, f.effect)
		if f.effect == "pierce":
			p.pierce = 3
	Sfx.play("cannon")
	Game.haptic(30)
	world.spawn_fx("splash", shooter.position + dir * shooter.radius, 14.0, Color.WHITE)


func _spawn(shooter: Node2D, dir: Vector2, dmg: float, fish_id: String, effect: String) -> Projectile:
	var p := Projectile.new()
	p.world = world
	p.shooter = shooter
	p.from_player = true
	p.fish_id = fish_id
	p.damage = dmg
	p.effect = effect
	p.dir = dir
	p.speed = FISH_SPEED * Data.U
	p.max_dist = Game.cannon_range() * Data.U
	p.position = shooter.position + dir * shooter.radius
	world.projectiles.add_child(p)
	return p


func spawn_cannonball(shooter: Pirate, dir: Vector2, dmg: float, range_u := BALL_RANGE) -> void:
	var p := Projectile.new()
	p.world = world
	p.shooter = shooter
	p.from_player = false
	p.damage = dmg
	p.dir = dir
	p.speed = BALL_SPEED * Data.U
	p.max_dist = range_u * Data.U
	p.position = shooter.position + dir * shooter.radius
	world.projectiles.add_child(p)


func on_hit(p: Projectile, target: Ship) -> void:
	if not p.from_player:
		target.take_damage(p.damage)
		world.spawn_fx("boom", p.position, 14.0, Color(1.0, 0.6, 0.2))
		Sfx.play("hit_player")
		Game.haptic(60)
		return
	_fish_hit(p, target)


## A projectile reached max range without hitting: area effects still go off.
func on_land(p: Projectile) -> void:
	if not p.from_player:
		world.spawn_fx("splash", p.position, 16.0, Color.WHITE)
		return
	match p.effect:
		"spike", "explosive", "lure", "ink":
			_area_effect(p, null)
		_:
			world.spawn_fx("splash", p.position, 16.0, Color.WHITE)
			Sfx.play("splash")


func _fish_hit(p: Projectile, target: Ship) -> void:
	var dmg := p.damage
	# Combo interactions (spec §5.1).
	if p.effect == "heavy" and target.status.has("freeze"):
		dmg *= 2.0
		world.float_text(target.position + Vector2(0, -target.radius - 24), "SHATTER!", Color(0.7, 0.95, 1.0))
	if p.effect == "pierce" and target.status.has("entangle"):
		dmg *= 2.0
		world.float_text(target.position + Vector2(0, -target.radius - 24), "CRITICAL!", Color(1.0, 0.9, 0.3))
	_damage(target, dmg, p.effect == "impale", p.effect == "midas")
	Sfx.play("hit_" + p.fish_id)
	match p.effect:
		"dazzle":
			target.status.apply("dazzle", 4.0)
			world.spawn_fx("sparkle", p.position, 24.0, Color(1.0, 0.6, 0.9))
		"shock":
			target.status.apply("stun", 2.0)
			var other := _nearest_other(target, 6.0 * Data.U)
			if other != null:
				var fx: Fx = world.spawn_fx("lightning", target.position, 10.0, Color.YELLOW)
				fx.to = other.position - target.position
				_damage(other, dmg * 0.5, false, false)
				other.status.apply("stun", 2.0)
		"entangle":
			target.status.apply("entangle", 3.0)
		"heavy":
			target.impulse += p.dir * 9.0 * Data.U
		"bleed":
			target.status.apply("bleed", 6.0, dmg * 0.09)   # DoTs scale with the hit
		"freeze":
			target.status.apply("freeze", 3.0)
			world.spawn_fx("ice", p.position, 28.0, Color.WHITE)
		"burn":
			target.status.apply("burn", 5.0, dmg * 0.2)
			for s in _ships_near(p.position, 3.0 * Data.U, target):
				s.status.apply("burn", 5.0, dmg * 0.2)
			world.spawn_fx("boom", p.position, 20.0, Color(1.0, 0.4, 0.1))
		"spike", "explosive", "lure", "ink":
			_area_effect(p, target)
		_:
			world.spawn_fx("boom", p.position, 14.0, Color(1.0, 0.9, 0.7))


func _area_effect(p: Projectile, direct: Ship) -> void:
	var pos := p.position
	match p.effect:
		"spike":
			for s in _ships_near(pos, 2.2 * Data.U, direct):
				_damage(s, p.damage * 0.6, false, false)
			world.spawn_fx("spines", pos, 2.2 * Data.U, Color(0.95, 0.9, 0.6))
		"explosive":
			var r := 4.0 * Data.U
			if direct != null and direct.status.has("burn"):
				r *= 1.6
				world.float_text(pos + Vector2(0, -40), "INFERNO!", Color(1.0, 0.45, 0.1))
			for s in _ships_near(pos, r, direct):
				_damage(s, p.damage * 0.7, false, false)
			world.spawn_fx("boom", pos, r, Color(1.0, 0.45, 0.1))
			Game.haptic(80)
		"lure":
			for s in _ships_near(pos, 6.0 * Data.U, null):
				s.impulse += (pos - s.position).normalized() * 7.0 * Data.U
			world.spawn_fx("sparkle", pos, 6.0 * Data.U, Color(1.0, 1.0, 0.6))
		"ink":
			for s in _ships_near(pos, 5.0 * Data.U, null):
				s.status.apply("blind", 5.0)
			world.spawn_fx("ink", pos, 5.0 * Data.U, Color.BLACK)
			if direct != null:
				_tentacle_slams(direct, p.damage * 0.4)


func _tentacle_slams(target: Ship, dmg: float) -> void:
	for i in 2:
		await get_tree().create_timer(0.35 * (i + 1), false).timeout
		if is_instance_valid(target) and not target.dead:
			_damage(target, dmg, false, false)
			world.spawn_fx("slam", target.position, 24.0, Color(0.76, 0.25, 0.35))


func _damage(target: Ship, dmg: float, ignore_armor: bool, midas: bool) -> void:
	if target is Pirate:
		if not ignore_armor:
			dmg *= 1.0 - float(target.data.armor)
		target.midas = midas
	target.take_damage(dmg)
	if target is Pirate and not target.dead:
		target.midas = false


func _ships_near(pos: Vector2, r: float, exclude: Ship) -> Array:
	var out := []
	for s in world.get_pirates():
		if s != exclude and s.position.distance_to(pos) < r + s.radius:
			out.append(s)
	return out


func _nearest_other(target: Ship, r: float) -> Ship:
	var best: Ship = null
	var best_d := r
	for s in world.get_pirates():
		if s == target:
			continue
		var d: float = s.position.distance_to(target.position)
		if d < best_d:
			best_d = d
			best = s
	return best
