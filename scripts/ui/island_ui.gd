class_name IslandUI
extends Overlay
## Go Ashore screen for an Island: one interaction per island kind (Data.ISLANDS).
##   treasure  dig up the buried chest (once)
##   castaway  trade the fish they ask for; they mark another island on your chart (once)
##   coconut   heal 40% HP (cooldown)
##   lookout   reveal the sea chart, hot spots and islands nearby
##   lagoon    gather bait from the tide pools (cooldown); the pool itself fishes rare
##   hideout   sink the guards, then raid the smugglers' cache (once)
##   shrine    offer an uncommon+ fish for a timed blessing (cooldown)
##   port      silence its shore battery first; then tribute (once), cheap repairs and a fish market

const GUARD_RANGE := 25.0     # units: living pirates this close block a hideout raid

var island: Island
var world: Node
var _gold: Label
var _list: VBoxContainer
var _msg := ""


func _init(i: Island, w: Node) -> void:
	island = i
	world = w
	panel_frac = Vector2(0.62, 0.66)


func build() -> void:
	var h := header(island.island_name, false)
	_gold = UIKit.label("", 26, UIKit.GOLD)
	h.add_child(_gold)
	h.add_child(UIKit.button("Leave", close))
	body.add_child(UIKit.label("%s  ·  %s" % [island.title(), Data.BIOMES[island.biome].name], 17, UIKit.DIM))
	body.add_child(_wrap(Data.ISLANDS[island.kind].desc, 19, UIKit.TEXT))
	_list = scroll_list()
	Game.gold_changed.connect(_refresh_gold)
	_refresh_gold()
	_refresh()


func _refresh_gold() -> void:
	_gold.text = "%d gold" % Game.gold


func _wrap(text: String, size: int, color: Color) -> Label:
	var l := UIKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(200, 0)
	return l


func _note(text: String, color := UIKit.DIM) -> void:
	_list.add_child(_wrap(text, 18, color))


func _action(text: String, cb: Callable, enabled := true) -> void:
	var b := UIKit.button(text, cb, 22)
	b.disabled = not enabled
	_list.add_child(b)


func _clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


func _refresh() -> void:
	clear(_list)
	if _msg != "":
		_note(_msg, Color(1.0, 0.9, 0.55))
	match island.kind:
		"treasure": _build_treasure()
		"castaway": _build_castaway()
		"coconut": _build_coconut()
		"lookout": _build_lookout()
		"lagoon": _build_lagoon()
		"hideout": _build_hideout()
		"shrine": _build_shrine()
		"port": _build_port()


func _done(msg: String) -> void:
	_msg = msg
	Game.save_game()
	_refresh()


func _stars() -> int:
	return int(Data.BIOMES[island.biome].stars)


func _cooldown() -> void:
	island.state().ready = Game.play_time + float(Data.ISLAND_COOLDOWN[island.kind])


## Index into the hold of the cheapest fish matching `ok`, preferring ones not
## marked "Keep for ammo"; -1 if none.
func _cheapest(ok: Callable) -> int:
	var best := -1
	var best_score := INF
	for i in Game.hold.size():
		var f: Dictionary = Game.hold[i]
		if not ok.call(f):
			continue
		var score := float(Game.fish_value(f)) + (100000.0 if f.keep else 0.0)
		if score < best_score:
			best_score = score
			best = i
	return best


func _give_fish(item: Dictionary) -> bool:
	if Game.add_fish(item):
		world.float_text(world.boat.position + Vector2(0, -40), "+ " + Data.FISH[item.id].name, Data.RARITY_COLORS[Data.FISH[item.id].rarity])
		return true
	return false


# --- Kinds ------------------------------------------------------------------------------

func _build_treasure() -> void:
	if island.done():
		_note("Only an empty hole and a splintered chest remain.")
		return
	_action("Dig at the X", _dig)


func _dig() -> void:
	var gold := randi_range(100, 180) * _stars()
	Game.add_gold(gold)
	var extra := ""
	if randf() < 0.35:
		Game.golden_bait += 1
		extra = " and a Golden Bait"
	else:
		Game.bait += 5
		extra = " and 5 bait"
	Game.hold_changed.emit()
	island.state().done = true
	Sfx.play("loot")
	world.float_text(world.boat.position, "+%d Gold" % gold, UIKit.GOLD, 26)
	_done("The chest held %d gold%s!" % [gold, extra])


func _build_castaway() -> void:
	if island.done():
		_note("The camp is cold. The castaway made it home, thanks to you.")
		return
	var want: String = island.state().want
	var f: Dictionary = Data.FISH[want]
	_note("\"Weeks on this rock and nothing but crabs! Bring me a %s and I'll tell you where I hid something worth finding.\"" % f.name, UIKit.TEXT)
	var have := Game.count_species(want)
	_action("Give a %s (%d aboard)" % [f.name, have], _feed_castaway, have > 0)


func _feed_castaway() -> void:
	var want: String = island.state().want
	var i := _cheapest(func(f): return f.id == want)
	if i < 0:
		return
	Game.remove_fish(i)
	var gold := int(Data.FISH[want].gold) * 3 + 40 * _stars()
	Game.add_gold(gold)
	island.state().done = true
	Sfx.play("sell")
	var other: Island = world.reveal_nearest_island(island)
	var tip := " They mark %s on your chart." % other.island_name if other != null else ""
	_done("The castaway wolfs it down and presses %d gold into your hand.%s" % [gold, tip])


func _build_coconut() -> void:
	var boat: Boat = world.boat
	var wait := island.ready_in()
	if wait > 0.0:
		_note("The palms are picked bare. More coconuts in %s." % _clock(wait))
	elif boat.hp >= boat.max_hp:
		_note("Your crew is well fed and the hull is sound. Come back when you need it.")
	_action("Rest and gather coconuts (+40% HP)", _rest, wait <= 0.0 and boat.hp < boat.max_hp)


func _rest() -> void:
	var boat: Boat = world.boat
	var heal := minf(boat.max_hp * 0.4, boat.max_hp - boat.hp)
	boat.hp += heal
	Game.hp = boat.hp
	_cooldown()
	Sfx.play("repair")
	world.float_text(boat.position, "+%d HP" % int(heal), Color(0.5, 1.0, 0.6), 24)
	_done("Coconuts, fresh water and a quick patch job: +%d HP." % int(heal))


func _build_lookout() -> void:
	_action("Climb the tower", _climb)


func _climb() -> void:
	var r: Vector3i = world.lookout_reveal(island.position, 2.0 * Data.SECTOR_PX)
	var parts := ["%d sea areas" % r.x]
	if r.y > 0:
		parts.append("%d hot spot%s" % [r.y, "" if r.y == 1 else "s"])
	if r.z > 0:
		parts.append("%d island%s" % [r.z, "" if r.z == 1 else "s"])
	Sfx.play("upgrade")
	_done("From the top you chart %s." % ", ".join(parts))


func _build_lagoon() -> void:
	_note("Cast into the lagoon from the shore for much rarer bites. The water around the island is rich too.")
	var wait := island.ready_in()
	if wait > 0.0:
		_note("The tide pools are picked clean. They refill in %s." % _clock(wait))
	_action("Search the tide pools (+4 bait)", _tide_pools, wait <= 0.0)


func _tide_pools() -> void:
	Game.bait += 4
	Game.hold_changed.emit()
	_cooldown()
	Sfx.play("loot")
	_done("You scoop 4 bait from the tide pools.")


func _build_hideout() -> void:
	if island.done():
		_note("The cache is empty and the flag torn down.")
		return
	var guards := 0
	for p in world.get_pirates():
		if p.position.distance_to(island.position) < GUARD_RANGE * Data.U:
			guards += 1
	if guards > 0:
		_note("%d pirate%s still guard the hideout. Sink them before you go digging." % [guards, "" if guards == 1 else "s"], Color(1.0, 0.5, 0.45))
	_action("Raid the smugglers' cache", _raid, guards == 0)


func _raid() -> void:
	var gold := randi_range(150, 250) * _stars()
	Game.add_gold(gold)
	var lost := 0
	for i in 2:
		if not _give_fish(Data.make_fish(Data.roll_loot_fish(island.biome, "rare"), -1.0, island.biome)):
			lost += 1
	island.state().done = true
	Sfx.play("loot")
	world.float_text(world.boat.position, "+%d Gold" % gold, UIKit.GOLD, 26)
	_done("You haul out %d gold and two crates of prize fish!%s" % [gold, " (Hold full: %d lost.)" % lost if lost > 0 else ""])


const PORT_REPAIR := 0.5     # port shipyard repairs at this fraction of shop price
const PORT_MARKET := 1.1     # port market pays this times base fish value


func _build_port() -> void:
	if not island.done():
		_note("The shore battery still covers the harbor. The town won't open its gates until it's silenced.", Color(1.0, 0.6, 0.5))
		return
	var st := island.state()
	if not st.get("tribute", false):
		_action("Collect the town's tribute", _port_tribute)
	var boat: Boat = world.boat
	var missing := boat.max_hp - boat.hp
	var cost := ceili(missing * Data.REPAIR_PER_HP * PORT_REPAIR)
	if missing >= 1.0:
		_action("Shipyard repair: full hull (%d g)" % cost, _port_repair, Game.gold >= cost)
	else:
		_note("The shipyard has nothing to fix.")
	var total := 0
	for f in Game.hold:
		if not f.keep:
			total += _port_price(f)
	_action("Market: sell all unkept fish (+%d g)" % total, _port_sell, total > 0)


func _port_price(f: Dictionary) -> int:
	return int(round(Game.fish_value(f) * PORT_MARKET))


func _port_tribute() -> void:
	var gold := randi_range(120, 200) * _stars()
	Game.add_gold(gold)
	island.state().tribute = true
	var extra := ""
	var item := Data.make_fish(Data.roll_loot_fish(island.biome, "rare"), -1.0, island.biome)
	if _give_fish(item):
		extra = " and a %s" % Data.FISH[item.id].name
	Sfx.play("loot")
	world.float_text(world.boat.position, "+%d Gold" % gold, UIKit.GOLD, 26)
	_done("The harbormaster hands over %d gold%s. \"Please, no more cannon fire.\"" % [gold, extra])


func _port_repair() -> void:
	var boat: Boat = world.boat
	var missing := boat.max_hp - boat.hp
	if Game.spend(ceili(missing * Data.REPAIR_PER_HP * PORT_REPAIR)):
		boat.hp = boat.max_hp
		Game.hp = boat.hp
		Sfx.play("repair")
		_done("The shipyard patches every plank.")


func _port_sell() -> void:
	var total := 0
	for i in range(Game.hold.size() - 1, -1, -1):
		var f: Dictionary = Game.hold[i]
		if not f.keep:
			total += _port_price(f)
			Game.hold.remove_at(i)
	Game.hold_changed.emit()
	Game.add_gold(total)
	Sfx.play("sell")
	_done("Sold at the port market for %d gold." % total)


func _build_shrine() -> void:
	var wait := island.ready_in()
	if wait > 0.0:
		_note("The moonstone is dim. It will glow again in %s." % _clock(wait))
	else:
		_note("Offer an uncommon or rarer fish (your cheapest one) for a %d-minute blessing:" % int(Data.BLESSING_TIME / 60.0))
	var has := _offering() >= 0
	if wait <= 0.0 and not has:
		_note("You have no fish worthy of an offering.", Color(1.0, 0.6, 0.5))
	for id in Data.BLESSINGS:
		var b: Dictionary = Data.BLESSINGS[id]
		_action("%s — %s" % [b.name, b.desc], _bless.bind(id), wait <= 0.0 and has)


func _offering() -> int:
	return _cheapest(func(f): return Data.rarity_index(Data.FISH[f.id].rarity) >= 1)


func _bless(id: String) -> void:
	var i := _offering()
	if i < 0:
		return
	var item := Game.remove_fish(i)
	Game.buffs[id] = Game.play_time + Data.BLESSING_TIME
	_cooldown()
	Sfx.play("upgrade")
	var b: Dictionary = Data.BLESSINGS[id]
	Game.say("Blessing of %s!" % b.name, b.color)
	_done("The sea accepts your %s. Blessing of %s: %s." % [Data.FISH[item.id].name, b.name, b.desc])
