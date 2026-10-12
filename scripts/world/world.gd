class_name World
extends Node2D
## Gameplay root: builds the ocean, entities, systems and UI layers, and handles
## docking, biomes, loot, death/respawn and menus.

signal quit_to_menu

const HOTSPOT_COUNT := 16

var currents := CurrentField.new()
var ocean: Ocean
var boat: Boat
var camera: Camera2D
var combat: Combat
var fishing: FishingSystem
var fish_shadows: FishShadows
var director: SpawnDirector
var hud: HUD
var menu: UILayer

var shops_layer: Node2D
var hotspots_layer: Node2D
var islands_layer: Node2D
var traps_layer: Node2D
var lairs_layer: Node2D
var wrecks: Node2D
var ships: Node2D
var projectiles: Node2D
var fx_layer: Node2D

var shops: Array = []
var islands: Array = []
var current_biome := ""
var docked_shop: Shop = null   # shop whose dock ring the boat is inside (shows Enter Shop)
var docked_island: Island = null   # island whose landing ring the boat is inside (shows Go Ashore)
var near_trap: Trap = null     # deployed trap within haul range (shows Haul Trap)


func _ready() -> void:
	Game.world = self
	ocean = Ocean.new()
	ocean.world = self
	add_child(ocean)
	shops_layer = _layer()
	hotspots_layer = _layer()
	traps_layer = _layer()
	lairs_layer = _layer()
	wrecks = _layer()
	fish_shadows = FishShadows.new()
	fish_shadows.world = self
	add_child(fish_shadows)
	islands_layer = _layer()   # above fish shadows, so none show through the land
	fishing = FishingSystem.new()
	fishing.world = self
	add_child(fishing)
	ships = _layer()
	projectiles = _layer()
	fx_layer = _layer()

	for d in Data.SHOPS:
		var s := Shop.new()
		s.setup_fixed(d)
		add_shop(s)
	_place_islands()
	for i in HOTSPOT_COUNT:
		hotspots_layer.add_child(HotSpot.new())
	for d in Game.deployed:
		_spawn_trap(d)
	for m in Game.treasure_maps:
		add_lair(m)

	boat = Boat.new()
	boat.world = self
	boat.position = Game.boat_pos
	boat.rotation = Game.boat_rot
	ships.add_child(boat)

	camera = Camera2D.new()
	camera.position = boat.position
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	add_child(camera)
	camera.make_current()

	combat = Combat.new()
	combat.world = self
	add_child(combat)
	director = SpawnDirector.new()
	director.world = self
	add_child(director)

	hud = HUD.new()
	hud.world = self
	add_child(hud)
	menu = UILayer.new(10)
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu)

	current_biome = Data.biome_at(boat.position)
	_discover()
	hud.show_banner(current_biome)
	Sfx.play_ambient("ambient_" + current_biome)


func _exit_tree() -> void:
	if Game.world == self:
		Game.world = null


func _layer() -> Node2D:
	var n := Node2D.new()
	add_child(n)
	return n


func _process(delta: float) -> void:
	currents.update(delta)
	camera.position = boat.position
	_check_biome()
	_check_docking()
	_check_traps()
	_check_wrecks()
	_check_hotspot_discovery()
	_check_islands()


func _unhandled_input(event: InputEvent) -> void:
	# Taps that no button or the joystick claimed fire the loaded cannon toward
	# the tapped point (spec §7.3). Mouse clicks arrive here as emulated touches.
	if event is InputEventScreenTouch and event.pressed:
		if boat.is_loaded() and not has_overlay():
			var target: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
			boat.fire(target - boat.position)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("cast"):
		fishing.cast_pressed()
	elif event.is_action_released("cast"):
		fishing.cast_released()
	elif event.is_action_pressed("fire"):   # keyboard: load, or fire at the auto-aim target
		if boat.is_loaded():
			boat.fire(boat.auto_aim_dir())
		else:
			boat.load_cannon()
	elif event.is_action_pressed("ammo_cycle"):
		Game.active_slot = (Game.active_slot + 1) % Game.rack_size()
		Game.hold_changed.emit()
	elif event.is_action_pressed("ammo_menu"):
		open_ammo_menu()
	elif event.is_action_pressed("enter_shop"):
		if docked_shop != null:
			enter_shop()
		elif near_trap == null and docked_island != null:
			go_ashore()
		else:
			haul_trap()
	elif event.is_action_pressed("deploy_trap"):
		open_deploy_menu()
	elif event.is_action_pressed("open_map"):
		open_map()
	elif event.is_action_pressed("open_hold"):
		open_hold()
	elif event.is_action_pressed("pause"):
		open_map()
	elif OS.is_debug_build() and event.is_action_pressed("debug_pirates"):
		director.spawn_encounter(current_biome if current_biome != "shallows" else "kelp")
	elif OS.is_debug_build() and event.is_action_pressed("debug_kraken"):
		director.spawn_kraken()
	elif OS.is_debug_build() and event.is_action_pressed("debug_gold"):
		Game.add_gold(500)
	else:
		return
	get_viewport().set_input_as_handled()


# --- Queries -------------------------------------------------------------------

func get_pirates() -> Array:
	var out := []
	for p in get_tree().get_nodes_in_group("pirates"):
		if not p.dead:
			out.append(p)
	return out


func player_in_safe_zone() -> bool:
	for s in shops:
		if s.position.distance_to(boat.position) < s.safe_radius:
			return true
	return false


func at_hotspot(pos: Vector2) -> bool:
	for h in hotspots_layer.get_children():
		if h.position.distance_to(pos) < h.radius:
			return true
	return false


func hotspots() -> Array:
	return hotspots_layer.get_children()


## The island whose land covers `pos` (a lagoon's pool counts as water), or null.
func island_at(pos: Vector2) -> Island:
	for isl in islands:
		if isl.is_land(pos):
			return isl
	return null


## Extra fishing luck at `pos` from lagoon waters.
func island_luck(pos: Vector2) -> float:
	var best := 0.0
	for isl in islands:
		best = maxf(best, isl.luck_at(pos))
	return best


## True if `pos` is within `margin` px of any island's shore.
func near_island(pos: Vector2, margin: float) -> bool:
	for isl in islands:
		if isl.position.distance_to(pos) < isl.land_radius + margin:
			return true
	return false


## Keeps a ship off island shores, cancelling its motion into the land.
func push_off_islands(s: Ship) -> void:
	for isl in islands:
		var d: Vector2 = s.position - isl.position
		var min_d: float = isl.land_radius + s.radius * 0.8
		if d.length() >= min_d:
			continue
		var n := d.normalized() if d != Vector2.ZERO else Vector2.RIGHT
		s.position = isl.position + n * min_d
		s.velocity -= n * minf(s.velocity.dot(n), 0.0)
		s.impulse -= n * minf(s.impulse.dot(n), 0.0)


func view_rect() -> Rect2:
	var size := get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - size * 0.5, size)


# --- Spawning helpers ----------------------------------------------------------

func float_text(pos: Vector2, text: String, color: Color, size := 20) -> void:
	var f := FloatText.new()
	f.position = pos
	f.text = text
	f.color = color
	f.size = size
	fx_layer.add_child(f)


func spawn_fx(kind: String, pos: Vector2, radius: float, color: Color) -> Fx:
	var f := Fx.new()
	f.kind = kind
	f.position = pos
	f.radius = radius
	f.color = color
	fx_layer.add_child(f)
	return f


func spawn_wreck(pos: Vector2, gold: int, fish: Array) -> void:
	var w := Wreck.new()
	w.position = pos
	w.gold = gold
	w.fish = fish
	wrecks.add_child(w)


func despawn_pirate(p: Pirate) -> void:
	p.remove_from_group("pirates")
	p.queue_free()


func add_shop(s: Shop) -> void:
	shops.append(s)
	shops_layer.add_child(s)


func remove_shop(s: Shop) -> void:
	shops.erase(s)
	s.queue_free()


# --- Per-frame checks ----------------------------------------------------------

func _check_biome() -> void:
	_discover()
	var b := Data.biome_at(boat.position)
	if b != current_biome:
		current_biome = b
		hud.show_banner(b)
		Sfx.play_ambient("ambient_" + b)
		Game.save_game()


## Reveals sectors around the boat for the map's fog of war.
func _discover() -> void:
	var r := 20.0 * Data.U
	for off in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		var s := Data.sector_of(boat.position + off)
		Game.discovered["%d,%d" % [s.x, s.y]] = true


## Tracks the nearest shop whose dock ring the boat is inside. The HUD shows an
## Enter Shop button while it's set; nothing opens automatically.
func _check_docking() -> void:
	docked_shop = null
	if boat.dead:
		return
	var best := INF
	for s in shops:
		var d := boat.position.distance_to(s.position)
		if d < s.dock_radius and d < best:
			best = d
			docked_shop = s


func enter_shop() -> void:
	if docked_shop == null or not is_instance_valid(docked_shop) or has_overlay() or boat.dead:
		return
	fishing.cancel()
	open_shop(docked_shop)


func go_ashore() -> void:
	if docked_island == null or docked_shop != null or has_overlay() or boat.dead:
		return
	fishing.cancel()
	open_overlay(IslandUI.new(docked_island, self))


# --- Islands -------------------------------------------------------------------

## Scatters Data.ISLAND_COUNT islands (at most one per sector) from the save's
## seed, so they stay put between sessions. Spots keep clear of shops,
## whirlpools, current lanes, the storm wall and each other.
func _place_islands() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.island_seed
	var sectors := []
	for y in Data.GRID:
		for x in Data.GRID:
			sectors.append(Vector2i(x, y))
	for i in range(sectors.size() - 1, 0, -1):   # seeded shuffle
		var j := rng.randi_range(0, i)
		var tmp = sectors[i]
		sectors[i] = sectors[j]
		sectors[j] = tmp
	var used := {}
	for s in sectors:
		if islands.size() >= Data.ISLAND_COUNT:
			break
		var kind := _pick_island_kind(Data.biome_at_sector(s.x, s.y), used, rng)
		for attempt in 8:
			var pos := (Vector2(s) + Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8))) * Data.SECTOR_PX
			if not _island_spot_ok(pos):
				continue
			var isl := Island.new()
			isl.setup(islands.size(), kind, pos, rng)
			islands.append(isl)
			islands_layer.add_child(isl)
			used[kind] = int(used.get(kind, 0)) + 1
			break
	_place_ports()


## Port Cities: Data.PORT_COUNT extra islands from their own seed, appended
## after the others so existing saves keep their island indices.
func _place_ports() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.island_seed + 7919
	var biomes: Array = Data.ISLANDS.port.biomes
	var placed := 0
	for attempt in 200:
		if placed >= Data.PORT_COUNT:
			break
		var s := Vector2i(rng.randi_range(0, Data.GRID - 1), rng.randi_range(0, Data.GRID - 1))
		if not Data.biome_at_sector(s.x, s.y) in biomes:
			continue
		var pos := (Vector2(s) + Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8))) * Data.SECTOR_PX
		if not _island_spot_ok(pos):
			continue
		var isl := Island.new()
		isl.setup(islands.size(), "port", pos, rng)
		islands.append(isl)
		islands_layer.add_child(isl)
		placed += 1


## Weighted pick among kinds allowed in `biome`; kinds already placed are
## less likely, so a save gets a good mix.
func _pick_island_kind(biome: String, used: Dictionary, rng: RandomNumberGenerator) -> String:
	var kinds := []
	var weights := []
	var total := 0.0
	for k in Data.ISLANDS:
		var d: Dictionary = Data.ISLANDS[k]
		if d.get("extra", false) or not ("any" in d.biomes or biome in d.biomes):
			continue
		var w := float(d.w) / (1.0 + 1.5 * int(used.get(k, 0)))
		kinds.append(k)
		weights.append(w)
		total += w
	var r := rng.randf() * total
	for i in kinds.size():
		r -= weights[i]
		if r <= 0.0:
			return kinds[i]
	return kinds[-1]


func _island_spot_ok(pos: Vector2) -> bool:
	var edge := 10.0 * Data.U
	if pos.x < edge or pos.y < edge or pos.x > Data.WORLD_PX - edge or pos.y > Data.WORLD_PX - edge:
		return false
	for s in shops:
		if s.position.distance_to(pos) < 16.0 * Data.U:
			return false
	for w in currents.whirlpools:
		if w.pos.distance_to(pos) < w.radius + 6.0 * Data.U:
			return false
	for l in currents.lanes:
		if not l.rect.grow(5.0 * Data.U).has_point(pos):
			continue
		for i in range(1, l.pts.size()):
			var c := Geometry2D.get_closest_point_to_segment(pos, l.pts[i - 1], l.pts[i])
			if c.distance_to(pos) < (CurrentField.LANE_HALF + 5.0) * Data.U:
				return false
	for isl in islands:
		if isl.position.distance_to(pos) < 25.0 * Data.U:
			return false
	return true


## Marks an island found (map, HUD arrow) and reveals its sector. Public hook
## for anything that charts islands (castaways, lookouts, treasure maps).
func reveal_island(isl: Island) -> void:
	if isl.found():
		return
	isl.state().found = true
	var s := Data.sector_of(isl.position)
	Game.discovered["%d,%d" % [s.x, s.y]] = true
	Game.save_game()


## Reveals the closest island to `from` not yet found; returns it, or null.
func reveal_nearest_island(from: Island) -> Island:
	var best: Island = null
	var best_d := INF
	for isl in islands:
		var d: float = isl.position.distance_to(from.position)
		if isl != from and not isl.found() and d < best_d:
			best_d = d
			best = isl
	if best != null:
		reveal_island(best)
	return best


## Lookout tower: reveals sectors, hot spots and islands within `radius` px of
## `pos`. Returns (new sectors, hot spots, islands) revealed.
func lookout_reveal(pos: Vector2, radius: float) -> Vector3i:
	var out := Vector3i.ZERO
	for y in Data.GRID:
		for x in Data.GRID:
			var c := (Vector2(x, y) + Vector2(0.5, 0.5)) * Data.SECTOR_PX
			var key := "%d,%d" % [x, y]
			if c.distance_to(pos) < radius and not Game.discovered.has(key):
				Game.discovered[key] = true
				out.x += 1
	for h in hotspots():
		if not h.discovered and h.position.distance_to(pos) < radius:
			h.discovered = true
			out.y += 1
	for isl in islands:
		if not isl.found() and isl.position.distance_to(pos) < radius:
			reveal_island(isl)
			out.z += 1
	Game.save_game()
	return out


## Discovery, hideout guards and the landing ring.
func _check_islands() -> void:
	docked_island = null
	if boat.dead:
		return
	var find_r := Island.FIND_RADIUS * Data.U
	for isl in islands:
		var d := boat.position.distance_to(isl.position)
		if d < find_r and not isl.found():
			reveal_island(isl)
			Game.say("Land ho! You found %s." % isl.full_name(), Color(0.6, 1.0, 0.7))
			Sfx.play("loot")
		if isl.kind == "hideout" and not isl.done() and d < 16.0 * Data.U and Game.play_time >= float(isl.state().guard):
			isl.state().guard = Game.play_time + Data.HIDEOUT_GUARD_CD
			director.spawn_hideout_guards(isl)
		if isl.kind == "port" and not isl.done() and d < Data.FORT_WAKE * Data.U and director.fort_for(isl) == null:
			director.spawn_fort(isl)
		if d < isl.dock_radius:
			docked_island = isl


# --- Traps -------------------------------------------------------------------------

# --- Treasure-map lairs (Lair, Data.BOSS_MAPS) -------------------------------------------

func add_lair(m: Dictionary) -> Lair:
	var l := Lair.new()
	l.setup(m)
	lairs_layer.add_child(l)
	return l


func lair_for(uid: int) -> Lair:
	for l in lairs_layer.get_children():
		if l.uid == uid and not l.is_queued_for_deletion():
			return l
	return null


func traps() -> Array:
	return traps_layer.get_children()


func _spawn_trap(d: Dictionary) -> Trap:
	var t := Trap.new()
	t.setup(d)
	traps_layer.add_child(t)
	return t


func _check_traps() -> void:
	near_trap = null
	if boat.dead:
		return
	var best := Data.TRAP_HAUL_RADIUS * Data.U
	for t in traps():
		var d := boat.position.distance_to(t.position)
		if d < best and not t.is_queued_for_deletion():
			best = d
			near_trap = t


## Drops a carried trap of `kind` just astern, baited with `bait` ("" = none).
func deploy_trap(kind: String, bait: String) -> bool:
	if int(Game.traps.get(kind, 0)) <= 0 or boat.dead:
		return false
	var pos := boat.position - boat.heading() * 1.6 * Data.U
	for t in traps():
		if t.position.distance_to(pos) < Data.TRAP_HAUL_RADIUS * 2.0 * Data.U:
			Game.say("Too close to another trap.", Color(1, 0.7, 0.5))
			return false
	if bait != "":
		if int(Game.trap_bait.get(bait, 0)) <= 0:
			return false
		Game.trap_bait[bait] = int(Game.trap_bait[bait]) - 1
	Game.traps[kind] = int(Game.traps[kind]) - 1
	var d := {"kind": kind, "bait": bait, "pos": [pos.x, pos.y], "timer": 0.0, "catch": []}
	Game.deployed.append(d)
	_spawn_trap(d)
	Sfx.play("splash")
	Game.say("%s dropped%s." % [Data.TRAPS[kind].name, (" with " + Data.TRAP_BAITS[bait].name) if bait != "" else ""], Color(0.6, 1.0, 0.9))
	Game.hold_changed.emit()
	return true


## Moves the nearby trap's catch into the hold. Picks the trap back up when
## everything fit; otherwise leftovers stay in the trap.
func haul_trap() -> void:
	var t := near_trap
	if t == null or not is_instance_valid(t) or has_overlay() or boat.dead:
		return
	var best := {}
	var added := 0
	while not t.data.catch.is_empty() and not Game.hold_full():
		var c: Dictionary = t.data.catch.pop_front()
		var item := Data.make_fish(c.id, float(c.size), Data.biome_at(t.position))
		var first := Game.record_catch(item)
		Game.add_fish(item)
		added += 1
		var f: Dictionary = Data.FISH[item.id]
		float_text(t.position + Vector2(0, -26 - added * 22), "+ " + f.name, Data.RARITY_COLORS[f.rarity])
		if best.is_empty() or Data.rarity_index(f.rarity) > Data.rarity_index(Data.FISH[best.item.id].rarity) or first:
			best = {"item": item, "first": first}
	if not best.is_empty():
		hud.show_catch(best.item, best.first)
		Sfx.play("catch")
	if not t.data.catch.is_empty():
		Game.say("Hold full — %d left in the trap." % t.data.catch.size(), Color(1, 0.7, 0.5))
		return
	Game.deployed.erase(t.data)
	Game.traps[t.data.kind] = int(Game.traps.get(t.data.kind, 0)) + 1
	if added == 0:
		Game.say("Trap was empty — picked it back up.", Color(0.9, 0.9, 0.9))
	Sfx.play("loot")
	t.queue_free()
	near_trap = null
	Game.hold_changed.emit()


func open_deploy_menu() -> void:
	if not has_overlay() and not boat.dead and Game.traps_carried() > 0:
		open_overlay(DeployUI.new(self))


func _check_wrecks() -> void:
	for w in wrecks.get_children():
		if w.is_queued_for_deletion() or boat.dead:
			continue
		if w.position.distance_to(boat.position) < w.pickup_radius:
			if w.gold > 0:
				Game.add_gold(w.gold)
				float_text(w.position, "+%d Gold" % w.gold, Color(1.0, 0.85, 0.25), 24)
			var lost := 0
			for f in w.fish:
				if Game.add_fish(f):
					float_text(w.position + Vector2(0, -26), "+ " + Data.FISH[f.id].name, Data.RARITY_COLORS[Data.FISH[f.id].rarity])
				else:
					lost += 1
			if lost > 0:
				Game.say("Hold full — %d fish lost to the sea." % lost, Color(1, 0.7, 0.5))
			Sfx.play("loot")
			w.queue_free()


func _check_hotspot_discovery() -> void:
	for h in hotspots_layer.get_children():
		if not h.discovered and h.position.distance_to(boat.position) < 22.0 * Data.U:
			h.discovered = true


# --- Death & saving (spec §9) ---------------------------------------------------

func on_player_died() -> void:
	fishing.cancel()
	spawn_fx("boom", boat.position, 2.0 * Data.U, Color(1.0, 0.5, 0.2))
	Sfx.play("player_sink")
	Game.haptic(300)
	boat.visible = false
	await get_tree().create_timer(1.2, false).timeout
	var lost_gold := int(floor(Game.gold * 0.1))
	var lost_fish := Game.hold.size() + (1 if boat.is_loaded() else 0)
	open_overlay(DeathUI.new(lost_gold, lost_fish))


func respawn() -> void:
	Game.gold -= int(floor(Game.gold * 0.1))
	Game.hold.clear()
	Game.cannon = {}
	Game.gold_changed.emit()
	Game.hold_changed.emit()
	for p in get_tree().get_nodes_in_group("pirates"):
		despawn_pirate(p)
	for n in projectiles.get_children():
		n.queue_free()
	for n in wrecks.get_children():
		n.queue_free()
	var shop := Data.shop_by_id(Game.last_shop)
	boat.position = Data.shop_pos(shop) + Vector2(0, 5.0 * Data.U)
	boat.velocity = Vector2.ZERO
	boat.impulse = Vector2.ZERO
	boat.status.clear()
	boat.max_hp = Game.max_hp()
	boat.hp = boat.max_hp
	boat.dead = false
	boat.visible = true
	boat.reload_left = 0.0
	boat.auto_reload = false
	Game.hp = boat.hp
	camera.position = boat.position
	camera.reset_smoothing()
	director.in_encounter = false
	director.last_encounter_end = Game.play_time
	Sfx.set_combat(false)
	Game.save_game()


## Called by Game.save_game() to capture world state.
func write_state() -> void:
	Game.boat_pos = boat.position
	Game.boat_rot = boat.rotation
	Game.hp = boat.hp


# --- Overlays ------------------------------------------------------------------------

func open_overlay(o: Overlay) -> void:
	menu.root.add_child(o)
	o.closed.connect(_on_overlay_closed.bind(o))
	get_tree().paused = true


func _on_overlay_closed(o: Overlay) -> void:
	for c in menu.root.get_children():
		if c != o and c is Overlay and not c.is_queued_for_deletion():
			return
	get_tree().paused = false


func has_overlay() -> bool:
	for c in menu.root.get_children():
		if c is Overlay and not c.is_queued_for_deletion():
			return true
	return false


func open_shop(s: Shop) -> void:
	if not s.merchant:
		Game.last_shop = s.id
		Game.save_game()
	Sfx.play("shop_jingle")
	open_overlay(ShopUI.new(s))


## Map doubles as the pause menu (one top-corner button, M or Esc/P).
func open_map() -> void:
	if has_overlay():
		return
	var m := MapUI.new(self)
	m.quit_requested.connect(_quit)
	open_overlay(m)


func open_hold() -> void:
	if not has_overlay():
		open_overlay(HoldUI.new())


func open_hold_full(pending: Dictionary) -> void:
	open_overlay(HoldUI.new(pending))


func open_ammo_menu() -> void:
	if not has_overlay():
		open_overlay(AmmoMenu.new())


func _quit() -> void:
	Game.save_game()
	get_tree().paused = false
	quit_to_menu.emit()
