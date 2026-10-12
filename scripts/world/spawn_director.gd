class_name SpawnDirector
extends Node
## Pirate / shark / Kraken encounters and roaming merchants (spec §7.5, §6.1).

const CHECK_INTERVAL := 20.0
const FIRST_CHECK := 30.0     # seconds into a session before the first roll
const GRACE := 40.0           # quiet time after an encounter ends
const QUIET_RAMP := 150.0     # seconds of quiet (past GRACE) until an encounter is near-certain
const MERCHANT_LIFETIME := 180.0

var world: Node
var check_t := FIRST_CHECK
var in_encounter := false
var last_encounter_end := 0.0
var merchant_t := 150.0


func _ready() -> void:
	last_encounter_end = Game.play_time - GRACE


func _process(delta: float) -> void:
	var t := Game.play_time
	var pirates: Array = world.get_pirates()
	if in_encounter and pirates.is_empty():
		in_encounter = false
		last_encounter_end = t
		Sfx.set_combat(false)
	check_t -= delta
	if check_t <= 0.0:
		check_t = CHECK_INTERVAL
		if not in_encounter and not world.player_in_safe_zone() and t >= last_encounter_end + GRACE and not world.boat.dead:
			_roll_encounter(t)
	_merchants(delta)


## Chance scales with biome threat and time since the last fight; long quiet
## stretches ramp toward a guaranteed encounter in any biome. A full hold draws
## sharks and a heavy purse draws pirates, both in how often and which comes.
func _roll_encounter(t: float) -> void:
	var b: Dictionary = Data.BIOMES[world.current_biome]
	var threat := float(b.threat)
	var quiet := clampf((t - last_encounter_end - GRACE) / QUIET_RAMP, 0.0, 1.0)
	var fill := float(Game.hold.size()) / float(maxi(Game.hold_capacity(), 1))
	var rich := clampf(Game.gold / 2500.0, 0.0, 1.0)
	var shark_w := float(b.get("shark_chance", 0.0)) * (1.0 + 3.0 * fill * fill)
	var pirate_w := (1.0 - float(b.get("shark_chance", 0.0))) * (1.0 + 2.0 * rich)
	var chance := threat + (1.0 - threat) * quiet * quiet
	if shark_w > 0.0:
		chance += 0.3 * fill * fill
	chance += 0.25 * rich
	if world.at_hotspot(world.boat.position):
		chance += 0.15 * threat
	if world.current_biome in Data.KRAKEN_BIOMES and randf() < Data.KRAKEN_CHANCE * (1.0 + quiet):
		spawn_kraken()
	elif randf() < clampf(chance, 0.0, 0.95):
		if randf() * (shark_w + pirate_w) < shark_w:
			spawn_sharks(world.current_biome)
		else:
			spawn_encounter(world.current_biome)


func _spawn_pos() -> Vector2:
	var dist := (Game.detect_radius() + randf_range(2.0, 6.0)) * Data.U
	return world.boat.position + Vector2.RIGHT.rotated(randf() * TAU) * dist


## A pack of 1–3 sharks (more in deeper water) circles in. The first shark
## encounter of a save is always a lone shark.
func spawn_sharks(biome: String) -> void:
	var count := randi_range(1, 2 if int(Data.BIOMES[biome].stars) <= 1 else 3)
	if not Game.met_sharks:
		count = 1
		Game.met_sharks = true
	var center := _spawn_pos()
	for i in count:
		spawn_pirate("shark", biome, center + Vector2.RIGHT.rotated(randf() * TAU) * 2.0 * Data.U)
	Game.say("A shark is circling!" if count == 1 else "Sharks are circling!", Color(1.0, 0.4, 0.35))


func spawn_encounter(biome: String) -> void:
	var b: Dictionary = Data.BIOMES[biome]
	var count := randi_range(1, int(b.max_pirates))
	var types: Array = b.pirates
	for i in count:
		var type: String = types.pick_random()
		if type == "lord":
			if randf() > 0.25:
				type = "ghost"
		spawn_pirate(type, biome, _spawn_pos())
		if type == "lord":
			Game.say("A PIRATE LORD approaches!", Color(1.0, 0.3, 0.3))
			break
	Game.say("Pirates spotted!", Color(1.0, 0.4, 0.35))


## The Kraken surfaces ahead of the boat (rare; see Data.KRAKEN_CHANCE).
func spawn_kraken() -> void:
	var boat: Boat = world.boat
	var pos := boat.position + boat.heading().rotated(randf_range(-0.6, 0.6)) * 13.0 * Data.U
	var k := spawn_pirate("kraken", world.current_biome, pos)
	k.engaged = true
	world.spawn_fx("splash", k.position, 4.0 * Data.U, Color.WHITE)
	world.spawn_fx("ink", k.position, 3.5 * Data.U, Color.BLACK)
	Game.say("THE KRAKEN RISES!", Color(1.0, 0.3, 0.45))
	Game.haptic(400)
	Sfx.play("kraken_roar")


## A treasure-map boss rises at its lair (see Lair). Sinking it pays the map's bounty.
func spawn_lair_boss(lair: Lair) -> Pirate:
	var m: Dictionary = lair.map_data()
	var p := spawn_pirate(String(m.boss), Data.biome_at(lair.position), lair.position)
	p.lair_uid = lair.uid
	p.engaged = true
	world.spawn_fx("splash", p.position, 4.5 * Data.U, Color.WHITE)
	if p.data.behavior == "kraken":
		world.spawn_fx("ink", p.position, 3.5 * Data.U, Color.BLACK)
	Game.say("THE %s RISES!" % String(p.data.name).to_upper(), Color(1.0, 0.3, 0.45))
	Game.haptic(400)
	Sfx.play("kraken_roar")
	return p


func spawn_pirate(type: String, biome: String, pos: Vector2) -> Pirate:
	var p := Pirate.new()
	p.world = world
	p.setup(type, biome)
	p.position = pos.clamp(Vector2.ONE * 4.0 * Data.U, Vector2.ONE * (Data.WORLD_PX - 4.0 * Data.U))
	p.rotation = (world.boat.position - p.position).angle()
	world.ships.add_child(p)
	in_encounter = true
	Sfx.set_combat(true)
	return p


## Pirates guarding an island hideout: 2–3 of the local types, already engaged.
func spawn_hideout_guards(isl: Island) -> void:
	var types: Array = Data.BIOMES[isl.biome].pirates
	for i in randi_range(2, 3):
		var type: String = types.pick_random()
		if type == "lord":
			type = "ghost"
		var pos := isl.position + Vector2.RIGHT.rotated(randf() * TAU) * (isl.land_radius + 4.0 * Data.U)
		spawn_pirate(type, isl.biome, pos).engaged = true
	Game.say("Pirates guard the hideout!", Color(1.0, 0.4, 0.35))


## A Port City's shore battery opens up as the boat comes in range.
func spawn_fort(isl: Island) -> Pirate:
	var f := spawn_pirate("fort_cannon", isl.biome, isl.battery_pos())
	f.island_index = isl.index
	f.engaged = true
	Game.say("%s's battery opens fire!" % isl.island_name, Color(1.0, 0.4, 0.35))
	return f


func fort_for(isl: Island) -> Pirate:
	for p in world.get_pirates():
		if p.type == "fort_cannon" and p.island_index == isl.index and not p.dead:
			return p
	return null


func summon_dinghies(pos: Vector2, n: int) -> void:
	var alive := 0
	for p in world.get_pirates():
		if p.type == "dinghy":
			alive += 1
	for i in mini(n, 4 - alive):
		var d := spawn_pirate("dinghy", world.current_biome, pos + Vector2.RIGHT.rotated(randf() * TAU) * 2.5 * Data.U)
		d.engaged = true


func _merchants(delta: float) -> void:
	for s in world.shops.duplicate():
		if s.merchant and s.life <= 0.0 and world.docked_shop != s:
			world.remove_shop(s)
	var has_merchant := false
	for s in world.shops:
		if s.merchant:
			has_merchant = true
	if has_merchant:
		return
	merchant_t -= delta
	if merchant_t > 0.0:
		return
	merchant_t = randf_range(150.0, 260.0)
	for attempt in 10:
		var pos: Vector2 = world.boat.position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(18.0, 40.0) * Data.U
		pos = pos.clamp(Vector2.ONE * 6.0 * Data.U, Vector2.ONE * (Data.WORLD_PX - 6.0 * Data.U))
		var ok: bool = not world.near_island(pos, 6.0 * Data.U)
		for s in world.shops:
			if s.position.distance_to(pos) < 20.0 * Data.U:
				ok = false
		if ok:
			var m := Shop.new()
			m.setup_merchant(pos, MERCHANT_LIFETIME)
			world.add_shop(m)
			Game.say("A roaming merchant has appeared nearby!", Color(0.8, 0.55, 1.0))
			return
