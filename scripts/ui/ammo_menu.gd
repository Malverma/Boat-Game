class_name AmmoMenu
extends Overlay
## Quick radial ammo selector (spec §2.2): choose which species the active rack
## slot fires. Species in the hold are laid out in a ring. Tapping a fish makes
## it the one to load (first in the fire order); holding one for HOLD_TIME adds
## it as the next in line (2nd, 3rd, ...) or takes it back out. Auto-reload
## follows that order after each shot.

const HOLD_TIME := 1.5
const ORDINALS := ["1st", "2nd", "3rd"]

var _ring: Control
var _held_id := ""       # fish button being pressed
var _held_t := 0.0
var _held_btn: Button
var _held_bar: ColorRect
var _hold_fired := false   # the hold already acted; ignore the release


func build() -> void:
	panel.visible = false
	_ring = Control.new()
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)
	_ring.resized.connect(_rebuild)
	_rebuild.call_deferred()


func _rebuild() -> void:
	clear(_ring)
	var center := size * 0.5
	var title := UIKit.label("Load ammo — slot %d" % (Game.active_slot + 1), 26, UIKit.GOLD)
	title.position = center + Vector2(-170, -size.y * 0.5 + 24)
	_ring.add_child(title)
	if Game.rack_size() > 1:
		var slots := UIKit.hbox(8)
		for i in Game.rack_size():
			var b := UIKit.button("Slot %d" % (i + 1), _pick_slot.bind(i), 17)
			b.disabled = i == Game.active_slot
			slots.add_child(b)
		slots.position = center + Vector2(-170, -size.y * 0.5 + 64)
		_ring.add_child(slots)
	var species := []
	for f in Game.hold:
		if not species.has(f.id):
			species.append(f.id)
	var clear_b := UIKit.button("Clear", _clear, 18)
	clear_b.position = center - Vector2(64, 50)
	_ring.add_child(clear_b)
	var close_b := UIKit.button("Close", close, 18)
	close_b.position = center + Vector2(-40, 10)
	_ring.add_child(close_b)
	if species.is_empty():
		var l := UIKit.label("No fish aboard — the cannon can't fire.", 20, Color(1, 0.6, 0.5))
		l.position = center + Vector2(-190, 70)
		_ring.add_child(l)
		return
	var r := minf(size.x, size.y) * 0.33
	for i in species.size():
		var id: String = species[i]
		var f: Dictionary = Data.FISH[id]
		var a := -PI / 2 + TAU * i / species.size()
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 104)
		b.size = b.custom_minimum_size
		b.position = center + Vector2.RIGHT.rotated(a) * r - b.size * 0.5
		var dmg := Data.fish_damage(Game.hold[Game._best_of(id)])
		b.text = "\n\n%s x%d\n%d dmg" % [f.name, Game.count_species(id), int(dmg)]
		b.add_theme_font_size_override("font_size", 15)
		b.button_down.connect(_on_down.bind(id, b))
		b.button_up.connect(_on_up.bind(id))
		var icon := FishIcon.new(id, Vector2(80, 40))
		icon.position = Vector2(35, 4)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		var rank := Game.fire_priority.find(id)
		if rank >= 0:
			var tag := UIKit.label(ORDINALS[rank] if rank < ORDINALS.size() else "%dth" % (rank + 1), 16, UIKit.GOLD)
			tag.position = Vector2(6, 2)
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(tag)
			b.add_theme_color_override("font_color", UIKit.GOLD)
		_ring.add_child(b)
	var order := PackedStringArray()
	for id in Game.fire_priority:
		order.append(Data.FISH[id].name)
	var info := UIKit.label("Tap: load first  ·  Hold %.1f s: add next in line\nFire order: %s" % [HOLD_TIME,
			" > ".join(order) if not order.is_empty() else "active slot"], 16, UIKit.DIM)
	info.position = center + Vector2(-170, size.y * 0.5 - 64)
	_ring.add_child(info)


func _process(delta: float) -> void:
	if _held_id == "" or _hold_fired:
		return
	_held_t += delta
	if is_instance_valid(_held_bar):
		_held_bar.size.x = _held_btn.size.x * clampf(_held_t / HOLD_TIME, 0.0, 1.0)
	if _held_t >= HOLD_TIME:
		_hold_fired = true
		_queue_next(_held_id)


func _on_down(id: String, b: Button) -> void:
	_held_id = id
	_held_t = 0.0
	_hold_fired = false
	_held_btn = b
	_held_bar = ColorRect.new()
	_held_bar.color = Color(UIKit.GOLD, 0.6)
	_held_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_bar.position = Vector2(0, b.size.y - 6)
	_held_bar.size = Vector2(0, 6)
	b.add_child(_held_bar)


func _on_up(id: String) -> void:
	var tap := not _hold_fired and _held_id == id
	_held_id = ""
	if is_instance_valid(_held_bar):
		_held_bar.queue_free()
	if tap:
		_load_first(id)


func _pick_slot(i: int) -> void:
	Game.active_slot = i
	Game.hold_changed.emit()
	_rebuild()


## Tap: this fish loads next; the rest of the order is kept behind it.
func _load_first(id: String) -> void:
	Game.ammo_slots[Game.active_slot] = id
	Game.fire_priority.erase(id)
	Game.fire_priority.push_front(id)
	Game.hold_changed.emit()
	Sfx.play("load")
	_rebuild.call_deferred()


## Hold: add the fish to the end of the fire order, or take it out if it's
## already queued behind the first.
func _queue_next(id: String) -> void:
	var rank := Game.fire_priority.find(id)
	if rank < 0:
		Game.fire_priority.append(id)
	elif rank > 0:
		Game.fire_priority.remove_at(rank)
	Game.hold_changed.emit()
	Game.haptic(30)
	_rebuild.call_deferred()


func _clear() -> void:
	Game.ammo_slots[Game.active_slot] = ""
	Game.fire_priority.clear()
	Game.hold_changed.emit()
	_rebuild()
