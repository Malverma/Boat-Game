class_name ShopUI
extends Overlay
## Shop screen (spec §6, §8.2): Sell, Upgrades, Repair, Supplies, Deployables and Maps tabs.
## Roaming merchants only offer Sell (bonus prices) and Supplies (rare stock).
## Upgrade stock depends on the shop's biome tier and specialties (Data.shop_upgrade_cap).

var shop: Shop
var tab := "sell"
var _gold: Label
var _tabs: HBoxContainer
var _list: VBoxContainer


func _init(s: Shop) -> void:
	shop = s


func build() -> void:
	var h := header(shop.shop_name, false)
	_gold = UIKit.label("", 26, UIKit.GOLD)
	h.add_child(_gold)
	h.add_child(UIKit.button("Leave", close))
	var sub: String = "%s  ·  Tier %d shop" % [Data.BIOMES[shop.biome].name, int(Data.BIOMES[shop.biome].stars)]
	if shop.merchant:
		sub = "Roaming merchant — pays extra for wanted fish, sells rare stock"
	body.add_child(UIKit.label(sub, 17, UIKit.DIM))
	_tabs = UIKit.hbox(8)
	body.add_child(_tabs)
	_list = scroll_list()
	Game.gold_changed.connect(_refresh_gold)
	_refresh_gold()
	_show("sell")


func _refresh_gold() -> void:
	_gold.text = "%d gold" % Game.gold


func _show(t: String) -> void:
	tab = t
	clear(_tabs)
	var tabs := ["sell", "supplies"] if shop.merchant else ["sell", "upgrades", "repair", "supplies", "deployables", "maps"]
	for id in tabs:
		var b := UIKit.button(String(id).capitalize(), _show.bind(id))
		b.disabled = id == tab
		_tabs.add_child(b)
	clear(_list)
	match tab:
		"sell": _build_sell()
		"upgrades": _build_upgrades()
		"repair": _build_repair()
		"supplies": _build_supplies()
		"deployables": _build_deployables()
		"maps": _build_maps()


func _price(item: Dictionary) -> int:
	return Game.sell_price(item, shop.id, shop.biome, shop.merchant)


func _index_of(item: Dictionary) -> int:
	for i in Game.hold.size():
		if is_same(Game.hold[i], item):
			return i
	return -1


# --- Sell ------------------------------------------------------------------------------

func _build_sell() -> void:
	var wanted := Game.wanted_for(shop.id, shop.merchant)
	var parts := []
	for id in wanted:
		parts.append("%s x%.1f" % [Data.FISH[id].name, wanted[id]])
	_list.add_child(UIKit.label("Wanted: " + ", ".join(parts), 19, Color(1.0, 0.9, 0.55)))
	_list.add_child(UIKit.label("Local fish sell for 0.8x, fish from distant waters for 1.2x.", 15, UIKit.DIM))
	if Game.hold.is_empty():
		_list.add_child(UIKit.label("Your hold is empty.", 20, UIKit.DIM))
		return
	var total := 0
	for f in Game.hold:
		if not f.keep:
			total += _price(f)
	var all := UIKit.button("Sell all unkept fish (+%d)" % total, _sell_all)
	all.disabled = total <= 0
	_list.add_child(all)
	var items := Game.hold.duplicate()
	items.sort_custom(func(a, b): return _price(a) > _price(b))
	for item in items:
		_list.add_child(_sell_row(item, wanted.has(item.id)))


func _sell_row(item: Dictionary, is_wanted: bool) -> Control:
	var f: Dictionary = Data.FISH[item.id]
	var row := UIKit.row()
	var h := UIKit.hbox()
	row.add_child(h)
	h.add_child(FishIcon.new(item.id))
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label("%s  (%.2fx)%s" % [f.name, item.size, "  WANTED" if is_wanted else ""], 20, Data.RARITY_COLORS[f.rarity]))
	v.add_child(UIKit.label("Fresh %d%%  ·  %d dmg  ·  %s" % [int(Game.freshness(item) * 100), int(Data.fish_damage(item)), Data.EFFECT_INFO[f.effect]], 14, UIKit.DIM))
	h.add_child(v)
	h.add_child(UIKit.spacer())
	h.add_child(UIKit.label("%d g" % _price(item), 22, UIKit.GOLD))
	var keep := UIKit.button("Kept" if item.keep else "Keep", _toggle_keep.bind(item), 17)
	keep.tooltip_text = "Keep for ammo: blocks selling"
	h.add_child(keep)
	var sell := UIKit.button("Sell", _sell.bind(item))
	sell.disabled = item.keep
	h.add_child(sell)
	return row


func _toggle_keep(item: Dictionary) -> void:
	item.keep = not item.keep
	Game.hold_changed.emit()
	_show("sell")


func _sell(item: Dictionary) -> void:
	var i := _index_of(item)
	if i < 0:
		return
	var p := _price(item)
	Game.remove_fish(i)
	Game.add_gold(p)
	Sfx.play("sell")
	_show("sell")


func _sell_all() -> void:
	var total := 0
	for i in range(Game.hold.size() - 1, -1, -1):
		var f: Dictionary = Game.hold[i]
		if not f.keep:
			total += _price(f)
			Game.hold.remove_at(i)
	Game.hold_changed.emit()
	Game.add_gold(total)
	Sfx.play("sell")
	_show("sell")


# --- Upgrades ----------------------------------------------------------------------------

func _build_upgrades() -> void:
	var cat := ""
	for id in Data.UPGRADE_ORDER:
		var u: Dictionary = Data.UPGRADES[id]
		if u.cat != cat:
			cat = u.cat
			_list.add_child(UIKit.label(cat, 22, UIKit.BRASS))
		var level := Game.lvl(id)
		var maxed := level >= int(u.max)
		var cap := Data.shop_upgrade_cap(id, shop.biome)
		var row := UIKit.row()
		var h := UIKit.hbox()
		row.add_child(h)
		var v := UIKit.vbox(0)
		var title := "%s   Lv %d/%d" % [u.name, level, u.max]
		if id in Data.BIOME_SPECIALTIES[shop.biome]:
			title += "   ★ Local specialty"
		v.add_child(UIKit.label(title, 20))
		v.add_child(UIKit.label(u.desc, 15, UIKit.DIM))
		h.add_child(v)
		h.add_child(UIKit.spacer())
		if maxed:
			h.add_child(UIKit.label("MAX", 20, Color(0.5, 1.0, 0.6)))
		elif level >= cap:
			var need := maxi(Data.upgrade_tier_needed(id, level), int(Data.BIOMES[shop.biome].stars) + 1)
			h.add_child(UIKit.label("Not stocked here\nTier %d+ shops" % mini(need, 5), 16, UIKit.DIM))
		else:
			var cost := Data.upgrade_cost(id, level)
			h.add_child(UIKit.label("%d g" % cost, 20, UIKit.GOLD))
			var b := UIKit.button("Buy", _buy.bind(id))
			b.disabled = Game.gold < cost
			h.add_child(b)
		_list.add_child(row)


func _buy(id: String) -> void:
	if Game.lvl(id) < Data.shop_upgrade_cap(id, shop.biome) and Game.buy_upgrade(id):
		Sfx.play("upgrade")
		Game.save_game()
	_show("upgrades")


# --- Repair ---------------------------------------------------------------------------------

func _build_repair() -> void:
	var boat: Boat = Game.world.boat
	var missing := boat.max_hp - boat.hp
	_list.add_child(UIKit.label("Hull: %d / %d HP" % [ceili(boat.hp), int(boat.max_hp)], 24))
	if missing < 1.0:
		_list.add_child(UIKit.label("Your boat is in perfect shape.", 20, UIKit.DIM))
		return
	var full := ceili(missing * Data.REPAIR_PER_HP)
	var b := UIKit.button("Full repair (%d g)" % full, _repair.bind(missing))
	b.disabled = Game.gold < full
	_list.add_child(b)
	var afford := minf(missing, floorf(Game.gold / Data.REPAIR_PER_HP))
	if afford >= 1.0 and afford < missing:
		_list.add_child(UIKit.button("Repair %d HP (%d g)" % [int(afford), ceili(afford * Data.REPAIR_PER_HP)], _repair.bind(afford)))


func _repair(amount: float) -> void:
	var boat: Boat = Game.world.boat
	if Game.spend(ceili(amount * Data.REPAIR_PER_HP)):
		boat.hp = minf(boat.hp + amount, boat.max_hp)
		Game.hp = boat.hp
		Sfx.play("repair")
	_show("repair")


# --- Supplies --------------------------------------------------------------------------------

func _build_supplies() -> void:
	_list.add_child(UIKit.label("Bait: %d   ·   Golden Bait: %d" % [Game.bait, Game.golden_bait], 20))
	_list.add_child(UIKit.label("Bait is used automatically when you cast.", 15, UIKit.DIM))
	var bait_price := Data.BAIT_PRICE - (10 if shop.merchant else 0)
	_supply_row("Bait x5", "Shorter bite time and better rarity", bait_price, func(): Game.bait += 5)
	if shop.merchant:
		_supply_row("Golden Bait", "Much better odds of rare fish on one cast", Data.GOLDEN_BAIT_PRICE, func(): Game.golden_bait += 1)


func _supply_row(title: String, desc: String, price: int, give: Callable) -> void:
	var row := UIKit.row()
	var h := UIKit.hbox()
	row.add_child(h)
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label(title, 20))
	v.add_child(UIKit.label(desc, 15, UIKit.DIM))
	h.add_child(v)
	h.add_child(UIKit.spacer())
	h.add_child(UIKit.label("%d g" % price, 20, UIKit.GOLD))
	var b := UIKit.button("Buy", func():
		if Game.spend(price):
			give.call()
			Game.hold_changed.emit()
			Sfx.play("buy")
		_show("supplies"))
	b.disabled = Game.gold < price
	h.add_child(b)
	_list.add_child(row)


# --- Deployables (traps + trap bait) ---------------------------------------------------------

func _tier() -> int:
	return int(Data.BIOMES[shop.biome].stars)


func _build_deployables() -> void:
	_list.add_child(UIKit.label("Traps: %d carried · %d deployed · max %d" % [Game.traps_carried(), Game.deployed.size(), Data.MAX_TRAPS], 20))
	_list.add_child(UIKit.label("Drop a trap with the Trap button (T), sail off, then come back and Haul it (C).\nTraps catch crabs, shellfish and bottom feeders from the waters they're dropped in.", 15, UIKit.DIM))
	_list.add_child(UIKit.label("Traps", 22, UIKit.BRASS))
	for k in Data.TRAP_ORDER:
		var t: Dictionary = Data.TRAPS[k]
		var info := "%s  ·  holds %d, a catch every ~%ds" % [t.desc, int(t.capacity), int(t.interval)]
		var block := ""
		if _tier() < int(t.min_tier):
			block = "Not stocked here\nTier %d+ shops" % int(t.min_tier)
		elif Game.traps_owned() >= Data.MAX_TRAPS:
			block = "Trap limit reached"
		_deploy_row("trap_" + k, "%s   (own %d)" % [t.name, int(Game.traps.get(k, 0))], info, int(t.price), block, Game.buy_trap.bind(k))
	_list.add_child(UIKit.label("Trap Bait", 22, UIKit.BRASS))
	for b in Data.TRAP_BAIT_ORDER:
		var d: Dictionary = Data.TRAP_BAITS[b]
		var block := "" if _tier() >= int(d.min_tier) else "Not stocked here\nTier %d+ shops" % int(d.min_tier)
		_deploy_row("bait_" + b, "%s x5   (have %d)" % [d.name, int(Game.trap_bait.get(b, 0))], d.desc, int(d.price), block, Game.buy_trap_bait.bind(b))


func _deploy_row(icon: String, title: String, desc: String, price: int, block: String, buy: Callable) -> void:
	var row := UIKit.row()
	var h := UIKit.hbox()
	row.add_child(h)
	var tex := Art.tex(icon)
	if tex != null:
		var r := TextureRect.new()
		r.texture = tex
		r.custom_minimum_size = Vector2(44, 44)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		h.add_child(r)
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label(title, 20))
	v.add_child(UIKit.label(desc, 15, UIKit.DIM))
	h.add_child(v)
	h.add_child(UIKit.spacer())
	if block != "":
		h.add_child(UIKit.label(block, 16, UIKit.DIM))
	else:
		h.add_child(UIKit.label("%d g" % price, 20, UIKit.GOLD))
		var b := UIKit.button("Buy", func():
			if buy.call():
				Game.hold_changed.emit()
				Sfx.play("buy")
				Game.save_game()
			_show("deployables"))
		b.disabled = Game.gold < price
		h.add_child(b)
	_list.add_child(row)


# --- Maps (boss treasure maps + island charts) ------------------------------------------------

func _build_maps() -> void:
	var tier := int(Data.BIOMES[shop.biome].stars)
	_list.add_child(UIKit.label("Your treasure maps (%d/%d)" % [Game.treasure_maps.size(), Data.MAX_BOSS_MAPS], 22, UIKit.BRASS))
	if Game.treasure_maps.is_empty():
		_list.add_child(UIKit.label("None. A map marks a boss lair on your Sea Chart; sail there to raise it.", 15, UIKit.DIM))
	for m in Game.treasure_maps:
		var bm: Dictionary = Data.BOSS_MAPS[m.kind]
		var pos := Vector2(float(m.pos[0]), float(m.pos[1]))
		_list.add_child(UIKit.label("%s — lair %s, in the %s" % [bm.name, _bearing(pos), Data.BIOMES[Data.biome_at(pos)].name], 17, Data.RARITY_COLORS[bm.rarity]))

	_list.add_child(UIKit.label("Boss maps", 22, UIKit.BRASS))
	_list.add_child(UIKit.label("Higher-tier shops sell maps to rarer, deadlier bosses.", 15, UIKit.DIM))
	for kind in Data.BOSS_MAP_ORDER:
		var bm: Dictionary = Data.BOSS_MAPS[kind]
		var waters := []
		for b in bm.biomes:
			waters.append(Data.BIOMES[b].name)
		var desc := "%s\nBoss: %s  ·  Bounty %d–%d g + %s fish  ·  %s" % [bm.desc, Data.PIRATES[bm.boss].name,
			bm.bounty[0], bm.bounty[1], bm.loot, ", ".join(waters)]
		var block := ""
		if tier < int(bm.min_tier):
			block = "Sold in Tier %d+ shops" % bm.min_tier
		elif _owns_map(kind):
			block = "Already charted"
		elif Game.treasure_maps.size() >= Data.MAX_BOSS_MAPS:
			block = "Carrying %d maps" % Data.MAX_BOSS_MAPS
		_map_row("Map: " + bm.name, Data.RARITY_COLORS[bm.rarity], desc, int(bm.price), block, _buy_boss_map.bind(kind))

	_list.add_child(UIKit.label("Island charts", 22, UIKit.BRASS))
	var isles := _uncharted_islands()
	if isles.is_empty():
		_list.add_child(UIKit.label("Every island in these waters is already charted.", 15, UIKit.DIM))
	for isl in isles:
		var desc := "Marks it on your Sea Chart: %s, in the %s." % [_bearing(isl.position), Data.BIOMES[isl.biome].name]
		_map_row("Chart: " + isl.title(), Color(0.6, 0.9, 0.7), desc, _chart_price(isl), "", _buy_island_chart.bind(isl))


## Unfound islands nearest this shop (Data.ISLAND_CHART_STOCK of them).
func _uncharted_islands() -> Array:
	var out := []
	if Game.world == null or not "islands" in Game.world:
		return out
	for isl in Game.world.islands:
		if not isl.found():
			out.append(isl)
	out.sort_custom(func(a, b): return a.position.distance_to(shop.position) < b.position.distance_to(shop.position))
	return out.slice(0, Data.ISLAND_CHART_STOCK)


func _chart_price(isl: Island) -> int:
	var base := int(Data.ISLAND_CHART_PRICE.get(isl.kind, 200))
	return int(round(base * (1.0 + 0.1 * int(Data.BIOMES[shop.biome].stars)) / 10.0)) * 10


func _owns_map(kind: String) -> bool:
	for m in Game.treasure_maps:
		if m.kind == kind:
			return true
	return false


## "about 140 units north-east of here"
func _bearing(pos: Vector2) -> String:
	var d := pos - shop.position
	const NAMES := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	var i := wrapi(int(round(d.angle() / (PI / 4.0))), 0, 8)
	return "about %d units %s of here" % [int(round(d.length() / Data.U / 10.0)) * 10, NAMES[i]]


func _buy_boss_map(kind: String) -> bool:
	var pos := Lair.pick_spot(Game.world, kind, shop.position)
	if pos == Vector2.INF:
		Game.say("No lair could be charted right now", Color(1, 0.6, 0.5))
		return false
	if not Game.buy_boss_map(kind, pos):
		return false
	Game.world.add_lair(Game.treasure_maps[-1])
	Game.say("Lair marked on your Sea Chart: %s" % Data.BOSS_MAPS[kind].name, Color(1.0, 0.85, 0.3))
	return true


func _buy_island_chart(isl: Island) -> bool:
	if isl.found() or not Game.spend(_chart_price(isl)):
		return false
	Game.world.reveal_island(isl)
	Game.say("Island charted: %s" % isl.island_name, Color(0.6, 0.9, 0.7))
	return true


func _map_row(title: String, color: Color, desc: String, price: int, block: String, buy: Callable) -> void:
	var row := UIKit.row()
	var h := UIKit.hbox()
	row.add_child(h)
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(title, 20, color))
	var d := UIKit.label(desc, 15, UIKit.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	h.add_child(v)
	if block != "":
		h.add_child(UIKit.label(block, 16, UIKit.DIM))
	else:
		h.add_child(UIKit.label("%d g" % price, 20, UIKit.GOLD))
		var b := UIKit.button("Buy", func():
			if buy.call():
				Sfx.play("buy")
				Game.save_game()
			_show("maps"))
		b.disabled = Game.gold < price
		h.add_child(b)
	_list.add_child(row)
