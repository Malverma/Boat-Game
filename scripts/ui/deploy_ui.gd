class_name DeployUI
extends Overlay
## Drop a trap: pick which carried trap and which bait (or none), then deploy
## it astern. Traps and trap bait are bought under Deployables at fixed shops.

var world: Node
var _kind := ""
var _bait := ""
var _list: VBoxContainer


func _init(w: Node) -> void:
	world = w
	panel_frac = Vector2(0.6, 0.8)


func build() -> void:
	header("Deploy Trap")
	body.add_child(UIKit.label("%d deployed  ·  %d carried  ·  max %d owned" % [Game.deployed.size(), Game.traps_carried(), Data.MAX_TRAPS], 16, UIKit.DIM))
	_list = scroll_list()
	for k in Data.TRAP_ORDER:
		if int(Game.traps.get(k, 0)) > 0:
			_kind = k
			break
	_rebuild()


func _rebuild() -> void:
	clear(_list)
	if _kind == "":
		_list.add_child(UIKit.label("No traps aboard.", 22, Color(1, 0.7, 0.5)))
		_list.add_child(UIKit.label("Buy a Crab Pot under Deployables at any shop.\nSail back to a deployed trap and press Haul to collect it.", 16, UIKit.DIM))
		return
	_list.add_child(UIKit.label("Trap", 22, UIKit.BRASS))
	for k in Data.TRAP_ORDER:
		var n := int(Game.traps.get(k, 0))
		if n <= 0:
			continue
		var t: Dictionary = Data.TRAPS[k]
		_choice("%s  x%d" % [t.name, n], "Holds %d · a catch every ~%ds" % [int(t.capacity), int(t.interval)], k == _kind, _pick_kind.bind(k))
	_list.add_child(UIKit.label("Bait", 22, UIKit.BRASS))
	_choice("No bait", "Normal odds and speed", _bait == "", _pick_bait.bind(""))
	for b in Data.TRAP_BAIT_ORDER:
		var n := int(Game.trap_bait.get(b, 0))
		if n <= 0:
			if _bait == b:
				_bait = ""
			continue
		var d: Dictionary = Data.TRAP_BAITS[b]
		_choice("%s  x%d" % [d.name, n], d.desc, b == _bait, _pick_bait.bind(b), b)
	var drop := UIKit.button("Drop Trap", _drop, 26)
	_list.add_child(drop)


func _choice(title: String, desc: String, selected: bool, cb: Callable, bait_icon := "") -> void:
	var row := UIKit.row()
	var h := UIKit.hbox()
	row.add_child(h)
	if bait_icon != "":
		var tex := Art.tex("bait_" + bait_icon)
		if tex != null:
			var r := TextureRect.new()
			r.texture = tex
			r.custom_minimum_size = Vector2(40, 40)
			r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			h.add_child(r)
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label(title, 20, UIKit.GOLD if selected else UIKit.TEXT))
	v.add_child(UIKit.label(desc, 14, UIKit.DIM))
	h.add_child(v)
	h.add_child(UIKit.spacer())
	var b := UIKit.button("Selected" if selected else "Choose", cb, 18)
	b.disabled = selected
	h.add_child(b)
	_list.add_child(row)


func _pick_kind(k: String) -> void:
	_kind = k
	_rebuild()


func _pick_bait(b: String) -> void:
	_bait = b
	_rebuild()


func _drop() -> void:
	if world.deploy_trap(_kind, _bait):
		close()
