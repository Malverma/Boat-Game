class_name HoldUI
extends Overlay
## Hold / inventory (spec §8.2): sort by value, rarity or ammo damage; mark fish
## "Keep for ammo"; release fish; load a species into the active ammo slot.
## With a pending catch it becomes the "hold full" prompt (spec §4.1 step 6).

var pending := {}
var sort_by := "value"
var _list: VBoxContainer
var _sorts: HBoxContainer


func _init(pending_catch := {}) -> void:
	pending = pending_catch


func build() -> void:
	if pending.is_empty():
		header("Hold  %d / %d" % [Game.hold.size(), Game.hold_capacity()])
	else:
		var f: Dictionary = Data.FISH[pending.id]
		var h := header("Hold full!", false)
		h.add_child(UIKit.button("Discard new %s" % f.name, close))
		body.add_child(UIKit.label("Release a fish to make room for the %s (%.2fx)." % [f.name, pending.size], 19, Data.RARITY_COLORS[f.rarity]))
	_sorts = UIKit.hbox(8)
	body.add_child(_sorts)
	_list = scroll_list()
	_refresh()


func _set_sort(s: String) -> void:
	sort_by = s
	_refresh()


func _refresh() -> void:
	clear(_sorts)
	_sorts.add_child(UIKit.label("Sort:", 18, UIKit.DIM))
	for s in ["value", "rarity", "damage"]:
		var b := UIKit.button(s.capitalize(), _set_sort.bind(s), 17)
		b.disabled = s == sort_by
		_sorts.add_child(b)
	_sorts.add_child(UIKit.spacer())
	_sorts.add_child(UIKit.label("Active ammo slot %d: %s" % [Game.active_slot + 1, _slot_name(Game.active_slot)], 17, UIKit.DIM))
	clear(_list)
	if Game.hold.is_empty():
		_list.add_child(UIKit.label("Your hold is empty. Go fishing!", 20, UIKit.DIM))
		return
	var items := Game.hold.duplicate()
	match sort_by:
		"value": items.sort_custom(func(a, b): return Game.fish_value(a) > Game.fish_value(b))
		"rarity": items.sort_custom(func(a, b): return _rank(a) > _rank(b))
		"damage": items.sort_custom(func(a, b): return Data.fish_damage(a) > Data.fish_damage(b))
	for item in items:
		_list.add_child(_row(item))


func _rank(item: Dictionary) -> float:
	return Data.rarity_index(Data.FISH[item.id].rarity) * 10.0 + float(item.size)


func _slot_name(i: int) -> String:
	var sp: String = Game.ammo_slots[i]
	return "empty" if sp == "" else Data.FISH[sp].name


func _row(item: Dictionary) -> Control:
	var f: Dictionary = Data.FISH[item.id]
	var row := UIKit.row()
	var h := UIKit.hbox()
	row.add_child(h)
	h.add_child(FishIcon.new(item.id))
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label("%s  (%.2fx)%s" % [f.name, item.size, "  [kept for ammo]" if item.keep else ""], 20, Data.RARITY_COLORS[f.rarity]))
	v.add_child(UIKit.label("~%d g  ·  fresh %d%%  ·  %d dmg  ·  %s" % [Game.fish_value(item), int(Game.freshness(item) * 100), int(Data.fish_damage(item)), Data.EFFECT_INFO[f.effect]], 14, UIKit.DIM))
	h.add_child(v)
	h.add_child(UIKit.spacer())
	if pending.is_empty():
		h.add_child(UIKit.button("Load", _load.bind(item), 17))
		h.add_child(UIKit.button("Unkeep" if item.keep else "Keep", _toggle_keep.bind(item), 17))
	h.add_child(UIKit.button("Release" if pending.is_empty() else "Swap", _release.bind(item), 17))
	return row


## Loads this exact fish into the cannon (any fish already loaded goes back to
## the hold) and makes its species the active slot's ammo, then closes the hold.
func _load(item: Dictionary) -> void:
	var boat: Boat = Game.world.boat
	if boat.dead:
		return
	if boat.reload_left > 0.0:
		Game.say("Cannon reloading — %.1fs" % boat.reload_left, Color(1, 0.7, 0.5))
		return
	var idx := -1
	for i in Game.hold.size():
		if is_same(Game.hold[i], item):
			idx = i
			break
	if idx < 0:
		return
	var old: Dictionary = Game.cannon
	Game.cannon = Game.remove_fish(idx)
	if not old.is_empty():
		Game.add_fish(old)   # always fits: we just freed a spot
	boat.auto_reload = false
	Game.ammo_slots[Game.active_slot] = item.id
	Game.hold_changed.emit()
	Sfx.play("load")
	Game.haptic(30)
	close()


func _toggle_keep(item: Dictionary) -> void:
	item.keep = not item.keep
	Game.hold_changed.emit()
	_refresh()


func _release(item: Dictionary) -> void:
	for i in Game.hold.size():
		if is_same(Game.hold[i], item):
			Game.remove_fish(i)
			break
	if not pending.is_empty():
		Game.add_fish(pending)
		close()
		return
	_refresh()
