extends Node
## Persistent player state, derived stats, economy helpers, settings and saving.

signal gold_changed
signal hold_changed
signal upgrades_changed
signal settings_changed
signal toast(text: String, color: Color)

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const DEFAULT_SETTINGS := {
	"joystick_side": "right", "joystick_mode": "floating", "dead_zone": 0.10,
	"reel_input": "hold", "ui_scale": 1.0, "haptics": true,
	"music": 70, "sfx": 80, "show_currents": true, "language": "system",
}
const HOLD_SIZES := [10, 16, 22, 30, 40]
const WANTED_ROTATION := 300.0

var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var gold := 0
var upgrades := {}
var hold: Array = []
var cannon := {}              # fish loaded in the cannon, {} when empty
var ammo_slots: Array = ["", "", "", ""]
var active_slot := 0
var fire_priority: Array = []  # species ids, highest first: what auto-reload loads next
var bait := 0
var golden_bait := 0
var traps := {}               # trap kind -> count carried (not deployed)
var trap_bait := {}           # trap bait id -> count
## Traps soaking in the sea: {"kind", "bait", "pos": [x, y], "timer", "catch": [{"id", "size"}]}.
## Trap nodes edit these dicts in place, so saving just writes the array.
var deployed: Array = []
var discovered := {}          # "x,y" -> true
var last_shop := "driftwood"
var fishpedia := {}           # species -> {"count": int, "best": float}
var play_time := 0.0
var met_sharks := false        # first shark encounter of a save is a lone shark
var island_seed := 0          # where this save's islands are (World._place_islands)
var islands := {}             # island index (String) -> {"found", "done", "ready", "want", "guard"}
var buffs := {}               # blessing id -> play_time it wears off
## Boss treasure maps carried: {"uid": int, "kind": Data.BOSS_MAPS key, "pos": [x, y] px}.
## A map is used up when its lair's boss is sunk.
var treasure_maps: Array = []
var next_map_uid := 1
var hp := 100.0
var boat_pos := Vector2.ZERO
var boat_rot := 0.0
var world: Node = null        # active World, set while playing
var _wanted := {}             # shop id -> {"until": float, "fish": {id: mult}}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_settings()


func _process(delta: float) -> void:
	if world != null and not get_tree().paused:
		play_time += delta


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if world != null:
			save_game()


# --- Derived stats (spec §6.3, §7.1) -----------------------------------------

func lvl(id: String) -> int:
	return int(upgrades.get(id, 0))

func max_hp() -> float: return 100.0 + 25.0 * lvl("hull")
func top_speed() -> float: return (5.0 + 0.6 * lvl("engine")) * (1.2 if buff("tailwind") else 1.0)
func current_resist() -> float: return 0.12 * lvl("engine")
func turn_rate() -> float: return 90.0 + 20.0 * lvl("rudder")
func hold_capacity() -> int: return HOLD_SIZES[mini(lvl("cargo"), HOLD_SIZES.size() - 1)]
func reload_time() -> float: return 1.5 - 0.2 * lvl("loader")
func dmg_mult() -> float: return (1.0 + 0.15 * lvl("barrel")) * (1.3 if buff("fury") else 1.0)


## How much tougher enemies spawning now should be: grows slowly with the
## biome's star rating, total upgrade levels, gold on hand and fish in the hold.
## 0 for a fresh boat in the Shallows; ~1.3 for a maxed, rich captain in the Abyss.
## Scales enemy damage, speed and loot only; hp comes from Data.enemy_hp.
func enemy_level(biome: String) -> float:
	var ups := 0
	for id in upgrades:
		ups += int(upgrades[id])
	var fill := float(hold.size()) / float(maxi(hold_capacity(), 1))
	return 0.1 * (int(Data.BIOMES[biome].stars) - 1) + 0.012 * ups + 0.2 * clampf(gold / 3000.0, 0.0, 1.0) + 0.15 * fill
func cannon_range() -> float: return 8.0 + 0.8 * lvl("barrel")
func rack_size() -> int: return mini(1 + lvl("ammo_rack"), 4)
func aim_half_arc() -> float: return deg_to_rad(120.0 + 30.0 * lvl("swivel"))
func detect_radius() -> float: return 26.0 + 7.0 * lvl("spyglass")


func buff(id: String) -> bool:
	return float(buffs.get(id, 0.0)) > play_time


## Persistent state of island `i` (created on first use).
func island_state(i: int) -> Dictionary:
	var k := str(i)
	if not islands.has(k):
		islands[k] = {"found": false, "done": false, "ready": 0.0, "want": "", "guard": 0.0}
	return islands[k]


# --- Gold ----------------------------------------------------------------------

func add_gold(n: int) -> void:
	gold = maxi(gold + n, 0)
	gold_changed.emit()


func spend(n: int) -> bool:
	if gold < n:
		return false
	gold -= n
	gold_changed.emit()
	return true


# --- Hold ------------------------------------------------------------------------

func hold_full() -> bool:
	return hold.size() >= hold_capacity()


func add_fish(item: Dictionary) -> bool:
	if hold_full():
		return false
	hold.append(item)
	hold_changed.emit()
	return true


func remove_fish(index: int) -> Dictionary:
	var item: Dictionary = hold[index]
	hold.remove_at(index)
	hold_changed.emit()
	return item


func count_species(id: String) -> int:
	var n := 0
	for f in hold:
		if f.id == id:
			n += 1
	return n


## Freshness multiplier (spec §6.4): −1%/min down to 50% without an Ice Box.
func freshness(item: Dictionary) -> float:
	if lvl("ice_box") > 0:
		return 1.0
	return maxf(0.5, 1.0 - 0.01 * (play_time - float(item.t)) / 60.0)


func fish_value(item: Dictionary, demand := 1.0) -> int:
	return int(round(Data.FISH[item.id].gold * float(item.size) * demand * freshness(item)))


func hold_value() -> int:
	var v := 0
	for f in hold:
		v += fish_value(f)
	return v


func record_catch(item: Dictionary) -> bool:
	var first := not fishpedia.has(item.id)
	var e: Dictionary = fishpedia.get(item.id, {"count": 0, "best": 0.0})
	e.count = int(e.count) + 1
	e.best = maxf(float(e.best), float(item.size))
	fishpedia[item.id] = e
	return first


# --- Ammo (spec §7.2) ------------------------------------------------------------

## Index into `hold` of the fish the cannon fires next, or -1 when the hold is empty.
## Uses the active rack slot, rolls to the next stocked slot, and otherwise falls
## back to "Keep for ammo" fish, then the cheapest fish aboard.
func next_ammo_index() -> int:
	var n := rack_size()
	for k in n:
		var slot := (active_slot + k) % n
		var sp: String = ammo_slots[slot]
		if sp != "" and count_species(sp) > 0:
			active_slot = slot
			return _best_of(sp)
	if hold.is_empty():
		return -1
	var best := -1
	var best_score := INF
	for i in hold.size():
		var f: Dictionary = hold[i]
		var score := float(fish_value(f)) - (100000.0 if f.keep else 0.0)
		if score < best_score:
			best_score = score
			best = i
	return best


func _best_of(species: String) -> int:
	var best := -1
	var best_score := INF
	for i in hold.size():
		var f: Dictionary = hold[i]
		if f.id != species:
			continue
		var score := float(fish_value(f)) - (100000.0 if f.keep else 0.0)
		if score < best_score:
			best_score = score
			best = i
	return best


## Index into `hold` of the fish auto-reload loads: the highest fire-priority
## species aboard, otherwise the same pick as a manual load.
func auto_ammo_index() -> int:
	for sp in fire_priority:
		if count_species(sp) > 0:
			return _best_of(sp)
	return next_ammo_index()


func next_ammo_species() -> String:
	var i := next_ammo_index()
	return "" if i < 0 else String(hold[i].id)


# --- Shops & demand (spec §6.2) --------------------------------------------------

func wanted_for(shop_id: String, merchant := false) -> Dictionary:
	var w = _wanted.get(shop_id)
	if w == null or play_time >= float(w.until):
		var pool := Data.FISH.keys()
		pool.erase("old_boot")
		pool.erase("tin_can")
		pool.shuffle()
		var fish := {}
		for i in 3:
			fish[pool[i]] = snappedf(randf_range(2.0, 2.5) if merchant else randf_range(1.5, 2.0), 0.1)
		w = {"until": play_time + WANTED_ROTATION, "fish": fish}
		_wanted[shop_id] = w
	return w.fish


func sell_price(item: Dictionary, shop_id: String, shop_biome: String, merchant := false) -> int:
	var wanted := wanted_for(shop_id, merchant)
	var demand: float = wanted[item.id] if wanted.has(item.id) else Data.biome_relation(item.id, shop_biome)
	return fish_value(item, demand)


func buy_upgrade(id: String) -> bool:
	var level := lvl(id)
	if level >= int(Data.UPGRADES[id].max):
		return false
	if not spend(Data.upgrade_cost(id, level)):
		return false
	upgrades[id] = level + 1
	if id == "hull":
		hp += 25.0
	upgrades_changed.emit()
	return true


# --- Traps (deployables) ------------------------------------------------------------

func traps_owned() -> int:
	var n := deployed.size()
	for k in traps:
		n += int(traps[k])
	return n


func traps_carried() -> int:
	var n := 0
	for k in traps:
		n += int(traps[k])
	return n


func buy_trap(kind: String) -> bool:
	if traps_owned() >= Data.MAX_TRAPS or not spend(int(Data.TRAPS[kind].price)):
		return false
	traps[kind] = int(traps.get(kind, 0)) + 1
	return true


func buy_trap_bait(id: String) -> bool:
	if not spend(int(Data.TRAP_BAITS[id].price)):
		return false
	trap_bait[id] = int(trap_bait.get(id, 0)) + 5
	return true


# --- Treasure maps (Data.BOSS_MAPS) ---------------------------------------------------

## Buys a boss map whose lair is at `pos` (picked by Lair.pick_spot).
func buy_boss_map(kind: String, pos: Vector2) -> bool:
	if treasure_maps.size() >= Data.MAX_BOSS_MAPS or not spend(int(Data.BOSS_MAPS[kind].price)):
		return false
	treasure_maps.append({"uid": next_map_uid, "kind": kind, "pos": [pos.x, pos.y]})
	next_map_uid += 1
	return true


func boss_map(uid: int) -> Dictionary:
	for m in treasure_maps:
		if int(m.uid) == uid:
			return m
	return {}


## The lair's boss was sunk: the map is used up. Returns it ({} if unknown).
func complete_boss_map(uid: int) -> Dictionary:
	var m := boss_map(uid)
	treasure_maps.erase(m)
	return m


# --- Game lifecycle ---------------------------------------------------------------

func new_game() -> void:
	gold = 30
	upgrades = {}
	hold = []
	for i in 3:
		hold.append(Data.make_fish("mackerel", 1.0))
	hold.append(Data.make_fish("sardine", 1.0))
	cannon = {}
	ammo_slots = ["mackerel", "", "", ""]
	active_slot = 0
	fire_priority = []
	bait = 0
	golden_bait = 0
	traps = {}
	trap_bait = {}
	deployed = []
	discovered = {}
	last_shop = "driftwood"
	fishpedia = {}
	met_sharks = false
	island_seed = randi()
	islands = {}
	buffs = {}
	treasure_maps = []
	next_map_uid = 1
	play_time = 0.0
	hp = max_hp()
	boat_pos = Data.shop_pos(Data.shop_by_id(last_shop)) + Vector2(0, 6.0 * Data.U)
	boat_rot = -PI / 2.0
	_wanted = {}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	if world != null and world.has_method("write_state"):
		world.write_state()
	var d := {
		"version": 1, "gold": gold, "upgrades": upgrades, "hold": hold, "cannon": cannon, "ammo_slots": ammo_slots,
		"active_slot": active_slot, "fire_priority": fire_priority, "bait": bait, "golden_bait": golden_bait,
		"traps": traps, "trap_bait": trap_bait, "deployed": deployed,
		"discovered": discovered.keys(), "last_shop": last_shop, "fishpedia": fishpedia, "met_sharks": met_sharks,
		"island_seed": island_seed, "islands": islands, "buffs": buffs,
		"treasure_maps": treasure_maps, "next_map_uid": next_map_uid,
		"play_time": play_time, "hp": hp, "boat_pos": [boat_pos.x, boat_pos.y], "boat_rot": boat_rot,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(d))


func load_game() -> bool:
	if not has_save():
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return false
	gold = int(d.get("gold", 0))
	upgrades = {}
	for k in d.get("upgrades", {}):
		upgrades[k] = int(d.upgrades[k])
	hold = []
	for f in d.get("hold", []):
		if Data.FISH.has(f.get("id", "")):
			hold.append(_fish_from_save(f))
	var c = d.get("cannon", {})
	cannon = _fish_from_save(c) if typeof(c) == TYPE_DICTIONARY and Data.FISH.has(c.get("id", "")) else {}
	ammo_slots = ["", "", "", ""]
	var slots: Array = d.get("ammo_slots", [])
	for i in mini(slots.size(), 4):
		ammo_slots[i] = String(slots[i])
	active_slot = int(d.get("active_slot", 0))
	fire_priority = []
	for sp in d.get("fire_priority", []):
		if Data.FISH.has(String(sp)) and not fire_priority.has(String(sp)):
			fire_priority.append(String(sp))
	bait = int(d.get("bait", 0))
	golden_bait = int(d.get("golden_bait", 0))
	traps = {}
	for k in d.get("traps", {}):
		if Data.TRAPS.has(k):
			traps[k] = int(d.traps[k])
	trap_bait = {}
	for k in d.get("trap_bait", {}):
		if Data.TRAP_BAITS.has(k):
			trap_bait[k] = int(d.trap_bait[k])
	deployed = []
	for t in d.get("deployed", []):
		if typeof(t) != TYPE_DICTIONARY or not Data.TRAPS.has(t.get("kind", "")):
			continue
		var catch := []
		for c2 in t.get("catch", []):
			if Data.FISH.has(c2.get("id", "")):
				catch.append({"id": String(c2.id), "size": float(c2.get("size", 1.0))})
		var pos: Array = t.get("pos", [0, 0])
		deployed.append({"kind": String(t.kind), "bait": String(t.get("bait", "")), "pos": [float(pos[0]), float(pos[1])],
			"timer": float(t.get("timer", 0.0)), "catch": catch})
	discovered = {}
	for k in d.get("discovered", []):
		discovered[k] = true
	last_shop = String(d.get("last_shop", "driftwood"))
	fishpedia = d.get("fishpedia", {})
	met_sharks = bool(d.get("met_sharks", false))
	island_seed = int(d.get("island_seed", randi()))   # older saves get islands now
	islands = d.get("islands", {})
	buffs = d.get("buffs", {})
	treasure_maps = []
	for m in d.get("treasure_maps", []):
		if typeof(m) == TYPE_DICTIONARY and Data.BOSS_MAPS.has(m.get("kind", "")):
			var mp: Array = m.get("pos", [0, 0])
			treasure_maps.append({"uid": int(m.get("uid", 0)), "kind": String(m.kind), "pos": [float(mp[0]), float(mp[1])]})
	next_map_uid = int(d.get("next_map_uid", treasure_maps.size() + 1))
	play_time = float(d.get("play_time", 0.0))
	hp = float(d.get("hp", max_hp()))
	var bp: Array = d.get("boat_pos", [0, 0])
	boat_pos = Vector2(float(bp[0]), float(bp[1]))
	boat_rot = float(d.get("boat_rot", 0.0))
	_wanted = {}
	return true


func _fish_from_save(f: Dictionary) -> Dictionary:
	return {"id": f.id, "size": float(f.size), "t": float(f.get("t", 0.0)), "keep": bool(f.get("keep", false)),
		"tier": int(f.get("tier", Data.home_tier(f.id)))}


# --- Settings ----------------------------------------------------------------------

func load_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate()
	if FileAccess.file_exists(SETTINGS_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if typeof(d) == TYPE_DICTIONARY:
			for k in d:
				if settings.has(k):
					settings[k] = d[k]
	_apply_settings()


func set_setting(key: String, value) -> void:
	settings[key] = value
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(settings))
	_apply_settings()
	settings_changed.emit()


func _apply_settings() -> void:
	Sfx.apply_volumes(float(settings.music), float(settings.sfx))


func haptic(ms: int) -> void:
	if settings.haptics:
		Input.vibrate_handheld(ms)


func say(text: String, color := Color(1, 1, 1)) -> void:
	toast.emit(text, color)


# --- Input --------------------------------------------------------------------------

func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("cast", [KEY_SPACE, KEY_E])
	_add_action("fire", [KEY_F, KEY_ENTER])
	_add_action("ammo_cycle", [KEY_Q])
	_add_action("ammo_menu", [KEY_R])
	_add_action("enter_shop", [KEY_C])   # also hauls a nearby trap
	_add_action("deploy_trap", [KEY_T])
	_add_action("open_map", [KEY_M])
	_add_action("open_hold", [KEY_I, KEY_TAB])
	_add_action("pause", [KEY_ESCAPE, KEY_P])
	_add_action("debug_pirates", [KEY_F9])
	_add_action("debug_gold", [KEY_F10])
	_add_action("debug_kraken", [KEY_F8])


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
