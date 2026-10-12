class_name HUD
extends UILayer
## In-game HUD (spec §8.1): joystick, action buttons (mirrored with the joystick
## side), HP/Gold, current compass, fishing meters, banners, toasts and
## off-screen indicators.

const STAR := 7.0
const SHOP_INDICATOR_RANGE := 50.0   # metres; shop arrows only show when this close
const SWAP_HOLD_TIME := 1.5          # seconds holding LOAD to open the ammo swap screen
const SWAP_HINT_DELAY := 0.3         # hold ring appears after this, so taps stay clean

var world: Node
var joystick: Joystick
var load_btn: TouchButton
var cast_btn: TouchButton
var map_btn: TouchButton
var shop_btn: TouchButton
var trap_btn: TouchButton
var haul_btn: TouchButton
var island_btn: TouchButton
var test_gold_btn: TouchButton   # TEMP test button
var test_fish_btn: TouchButton   # TEMP test button
var test_enemy_btn: TouchButton  # TEMP test button
var canvas: Control

var _mirror := false
var _banner := ""
var _banner_stars := 0
var _banner_t := 0.0
var _toasts := []
var _catch := {}
var _catch_first := false
var _catch_t := 0.0
var _no_ammo_t := 0.0
var _load_held := 0.0     # how long LOAD has been held this press
var _swap_opened := false # this press already opened the swap screen


func _init() -> void:
	super(1)


func _ready() -> void:
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_overlay)
	root.add_child(canvas)
	joystick = Joystick.new()
	root.add_child(joystick)

	# LOAD: tap to load/unload; hold SWAP_HOLD_TIME to open the ammo swap screen.
	load_btn = _btn("LOAD", true, "load", Color(0.45, 0.14, 0.12, 0.75))
	load_btn.pressed.connect(_on_load_pressed)
	load_btn.released.connect(_on_load_released)
	cast_btn = _btn("Cast", true, "cast", Color(0.12, 0.3, 0.42, 0.75))
	cast_btn.pressed.connect(func(): world.fishing.cast_pressed())
	cast_btn.released.connect(func(_d): world.fishing.cast_released())
	# Map doubles as pause: opens the map with the pause menu beside it.
	map_btn = _btn("Map", true, "map", Color(0.1, 0.16, 0.22, 0.7))
	map_btn.font_size = 16
	map_btn.text_on_art = false   # the map sprite is self-explanatory
	map_btn.pressed.connect(func(): world.open_map())
	# Shown while the boat is inside a shop's dock ring (opens on release so the
	# lifted finger doesn't land on the shop screen).
	shop_btn = _btn("Enter Shop", false, "", Color(0.45, 0.32, 0.1, 0.85))
	shop_btn.font_size = 22
	shop_btn.highlight = true
	shop_btn.visible = false
	shop_btn.released.connect(func(_d): world.enter_shop())
	# Deploy a carried trap (opens the trap/bait picker); Haul appears next to a trap.
	trap_btn = _btn("Drop Trap", true, "trap", Color(0.1, 0.32, 0.3, 0.75))
	trap_btn.font_size = 15
	trap_btn.visible = false
	trap_btn.released.connect(func(_d): world.open_deploy_menu())
	haul_btn = _btn("Haul Trap", false, "", Color(0.1, 0.36, 0.32, 0.85))
	haul_btn.font_size = 22
	haul_btn.highlight = true
	haul_btn.visible = false
	haul_btn.released.connect(func(_d): world.haul_trap())
	# Shown inside an island's landing ring (unless a shop's dock ring wins).
	island_btn = _btn("Go Ashore", false, "", Color(0.18, 0.4, 0.2, 0.85))
	island_btn.font_size = 22
	island_btn.highlight = true
	island_btn.visible = false
	island_btn.released.connect(func(_d): world.go_ashore())
	# TEMP test buttons (top middle) — remove before release.
	test_gold_btn = _btn("+250 Gold", false, "", Color(0.4, 0.32, 0.08, 0.75))
	test_gold_btn.font_size = 16
	test_gold_btn.pressed.connect(func(): Game.add_gold(250))
	test_fish_btn = _btn("+Fish", false, "", Color(0.12, 0.3, 0.42, 0.75))
	test_fish_btn.font_size = 16
	test_fish_btn.pressed.connect(_test_give_fish)
	test_enemy_btn = _btn("+Enemy", false, "", Color(0.45, 0.12, 0.1, 0.75))
	test_enemy_btn.font_size = 16
	test_enemy_btn.pressed.connect(_test_spawn_enemy)

	Game.toast.connect(_on_toast)
	Game.hold_changed.connect(_layout)
	Game.upgrades_changed.connect(_layout)
	relayout_done.connect(_layout)
	super()


func _btn(label: String, round_btn: bool, icon: String, c: Color) -> TouchButton:
	var b := TouchButton.new(label, round_btn)
	b.icon_key = icon
	b.color = c
	root.add_child(b)
	return b


func joystick_vector() -> Vector2:
	return joystick.output


# --- Layout ------------------------------------------------------------------------

func _mx(x: float) -> float:
	return root.size.x - x if _mirror else x


func _place(b: Control, center: Vector2, s: Vector2) -> void:
	b.size = s
	b.position = Vector2(_mx(center.x), center.y) - s * 0.5


func _layout() -> void:
	if canvas == null:
		return
	var W := root.size.x
	var H := root.size.y
	var right: bool = Game.settings.joystick_side == "right"
	_mirror = not right   # action buttons sit opposite the joystick
	canvas.size = root.size
	var zone := Vector2(W * 0.45, H * 0.45)
	joystick.size = zone
	joystick.position = Vector2(W - zone.x if right else 0.0, H - zone.y)
	joystick.home = Vector2(zone.x - 150.0 if right else 150.0, zone.y - 130.0)
	joystick.reset()
	_place(load_btn, Vector2(100, H - 105), Vector2(130, 130))
	_place(cast_btn, Vector2(245, H - 85), Vector2(110, 110))
	_place(map_btn, Vector2(W - 46, 46), Vector2(60, 60))
	if _mirror:   # the map button stays top-right regardless of joystick side
		map_btn.position.x = W - 46 - 30
	shop_btn.size = Vector2(220, 64)
	shop_btn.position = Vector2(W / 2 - 110, H - 150)
	island_btn.size = Vector2(220, 64)
	island_btn.position = Vector2(W / 2 - 110, H - 150)
	haul_btn.size = Vector2(220, 64)
	haul_btn.position = Vector2(W / 2 - 110, H - 240)
	# Middle-left edge, regardless of joystick side; only shown while a trap is carried.
	trap_btn.size = Vector2(84, 84)
	trap_btn.position = Vector2(16, H / 2 - 42)
	test_gold_btn.size = Vector2(110, 44)
	test_gold_btn.position = Vector2(W / 2 - 175, 16)
	test_fish_btn.size = Vector2(110, 44)
	test_fish_btn.position = Vector2(W / 2 - 55, 16)
	test_enemy_btn.size = Vector2(110, 44)
	test_enemy_btn.position = Vector2(W / 2 + 65, 16)


# --- Input handlers -----------------------------------------------------------------

func _on_load_pressed() -> void:
	_load_held = 0.0
	_swap_opened = false


func _on_load_released(_d: Vector2) -> void:
	if not _swap_opened:
		world.boat.load_cannon()


## TEMP: grants a random fish as if it were just caught.
func _test_give_fish() -> void:
	var item := Data.make_fish(Data.FISH.keys().pick_random(), -1.0, world.current_biome)
	var first := Game.record_catch(item)
	show_catch(item, first)
	if not Game.add_fish(item):
		world.open_hold_full(item)


## TEMP: spawns a random enemy (any pirate, creature or boss) near the boat, already engaged.
func _test_spawn_enemy() -> void:
	if world.boat.dead:
		return
	var type: String = Data.PIRATES.keys().pick_random()
	# Spawn just off-screen-ish, 10–13 units away roughly ahead, and chase for real.
	var boat: Boat = world.boat
	var pos := boat.position + boat.heading().rotated(randf_range(-1.2, 1.2)) * randf_range(10.0, 13.0) * Data.U
	var p: Pirate = world.director.spawn_pirate(type, world.current_biome, pos)
	p.engaged = true
	p.relentless = true
	Game.say("Test spawn: %s" % Data.PIRATES[type].name, Color(1.0, 0.4, 0.35))


# --- Public notifications -------------------------------------------------------------

func show_banner(biome: String) -> void:
	_banner = Data.BIOMES[biome].name
	_banner_stars = int(Data.BIOMES[biome].stars)
	_banner_t = 3.5


func show_catch(item: Dictionary, first: bool) -> void:
	_catch = item
	_catch_first = first
	_catch_t = 3.0


func flash_no_ammo() -> void:
	_no_ammo_t = 1.2


func _on_toast(text: String, color: Color) -> void:
	_toasts.append({"text": text, "color": color, "t": 3.2})
	if _toasts.size() > 4:
		_toasts.pop_front()


func world_to_hud(p: Vector2) -> Vector2:
	return to_local_ui(get_viewport().get_canvas_transform() * p)


# --- Per-frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	var boat: Boat = world.boat
	_banner_t -= delta
	_catch_t -= delta
	_no_ammo_t -= delta
	for t in _toasts:
		t.t -= delta
	while not _toasts.is_empty() and _toasts[0].t <= 0.0:
		_toasts.pop_front()
	if load_btn.is_down() and not _swap_opened:
		_load_held += delta
		if _load_held >= SWAP_HOLD_TIME:
			_swap_opened = true
			world.open_ammo_menu()   # pauses the game
	load_btn.progress = 1.0 - boat.reload_left / maxf(boat.reload_total, 0.01)
	var loaded := boat.is_loaded()
	load_btn.text = "LOADED" if loaded else "LOAD"
	load_btn.font_size = 17 if loaded else 20
	load_btn.highlight = loaded
	cast_btn.text = world.fishing.button_label()
	cast_btn.highlight = world.fishing.state == FishingSystem.State.BITE
	var near: Shop = world.docked_shop
	shop_btn.visible = near != null and not boat.dead
	var trap: Trap = world.near_trap
	haul_btn.visible = trap != null and not boat.dead
	if haul_btn.visible:
		haul_btn.text = "Haul Trap  %d/%d" % [trap.data.catch.size(), trap.capacity()]
	island_btn.visible = world.docked_island != null and not shop_btn.visible and not boat.dead
	trap_btn.visible = Game.traps_carried() > 0 and not boat.dead
	trap_btn.sub_text = str(Game.traps_carried())
	for b in [load_btn, cast_btn, shop_btn, trap_btn, haul_btn, island_btn]:
		b.queue_redraw()
	canvas.queue_redraw()


# --- Overlay drawing -------------------------------------------------------------------

func _draw_overlay() -> void:
	var c := canvas
	var font := ThemeDB.fallback_font
	var W := root.size.x
	var H := root.size.y
	var boat: Boat = world.boat
	_indicators(c, font)
	# HP bar
	var hp_rect := Rect2(16, 16, 260, 24)
	c.draw_rect(hp_rect.grow(2), Color(0, 0, 0, 0.6))
	var frac := clampf(boat.hp / boat.max_hp, 0.0, 1.0)
	c.draw_rect(Rect2(hp_rect.position, Vector2(hp_rect.size.x * frac, hp_rect.size.y)), Color(0.85, 0.2, 0.2).lerp(Color(0.3, 0.8, 0.35), frac))
	_text(c, font, Vector2(24, 35), "HP %d / %d" % [ceili(boat.hp), int(boat.max_hp)], 18, Color.WHITE)
	# Gold
	c.draw_circle(Vector2(30, 62), 10, UIKit.GOLD)
	c.draw_circle(Vector2(30, 62), 6, UIKit.GOLD.darkened(0.25))
	_text(c, font, Vector2(48, 70), _commas(Game.gold), 24, UIKit.GOLD)
	if Game.bait + Game.golden_bait > 0:
		_text(c, font, Vector2(170, 70), "Bait %d%s" % [Game.bait, (" +%d gold" % Game.golden_bait) if Game.golden_bait > 0 else ""], 16, UIKit.DIM)
	_compass(c, font, Vector2(W - 210, 46))
	# Status lines under the top bar
	var y := 98.0
	if world.player_in_safe_zone():
		_text(c, font, Vector2(16, y), "Safe Zone", 16, Color(0.6, 1.0, 0.7))
		y += 20
	if world.at_hotspot(boat.position) or world.at_hotspot(world.fishing.bobber) and world.fishing.is_active():
		_text(c, font, Vector2(16, y), "Hot Spot!", 16, Color(1.0, 0.95, 0.6))
		y += 20
	if world.island_luck(boat.position) > 0.0 or world.fishing.is_active() and world.island_luck(world.fishing.bobber) > 0.0:
		_text(c, font, Vector2(16, y), "Lagoon waters!", 16, Color(0.6, 1.0, 0.85))
		y += 20
	for id in Data.BLESSINGS:
		if Game.buff(id):
			var left := float(Game.buffs[id]) - Game.play_time
			var b: Dictionary = Data.BLESSINGS[id]
			_text(c, font, Vector2(16, y), "Blessing of %s  %d:%02d" % [b.name, int(left) / 60, int(left) % 60], 16, b.color)
			y += 20
	_banner_draw(c, font, W)
	# Toasts
	for i in _toasts.size():
		var t: Dictionary = _toasts[i]
		var a := clampf(t.t / 0.4, 0.0, 1.0)
		var w := font.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var p := Vector2(W / 2 - w / 2, 190 + i * 32)
		c.draw_rect(Rect2(p + Vector2(-10, -22), Vector2(w + 20, 30)), Color(0, 0, 0, 0.5 * a))
		_text(c, font, p, t.text, 20, Color(t.color, a))
	_catch_draw(c, font, W)
	_fishing_draw(c, font, H)
	_swap_ring_draw(c, font)
	if shop_btn.visible:
		var sn: String = world.docked_shop.shop_name
		var sw := font.get_string_size(sn, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		_text(c, font, Vector2(W / 2 - sw / 2, shop_btn.position.y - 10), sn, 18, Color(1, 0.95, 0.8))
	elif island_btn.visible:
		var isl: Island = world.docked_island
		var iname := isl.full_name()
		var iw := font.get_string_size(iname, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		_text(c, font, Vector2(W / 2 - iw / 2, island_btn.position.y - 10), iname, 18, Color(0.75, 1.0, 0.8))
	if boat.is_loaded() and not load_btn.is_down():
		var hint := "Tap to fire"
		var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		_text(c, font, Vector2(_mx(100) - hw / 2, H - 180), hint, 18, Color(1.0, 0.92, 0.55))
	elif _no_ammo_t > 0.0 and fmod(_no_ammo_t, 0.3) > 0.12:
		_text(c, font, Vector2(_mx(100) - 50, H - 180), "NO AMMO", 22, Color(1, 0.3, 0.3))


## Ring around LOAD that fills while it's held, toward opening the swap screen.
func _swap_ring_draw(c: Control, font: Font) -> void:
	if not load_btn.is_down() or _swap_opened or _load_held < SWAP_HINT_DELAY:
		return
	var f := clampf((_load_held - SWAP_HINT_DELAY) / (SWAP_HOLD_TIME - SWAP_HINT_DELAY), 0.0, 1.0)
	var center := load_btn.position + load_btn.size * 0.5
	var r := load_btn.size.x * 0.5 + 9.0
	c.draw_arc(center, r, 0, TAU, 48, Color(0, 0, 0, 0.45), 7.0)
	c.draw_arc(center, r, -PI / 2, -PI / 2 + TAU * f, 48, UIKit.GOLD, 7.0)
	var label := "Hold to swap ammo"
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_text(c, font, Vector2(center.x - w / 2, center.y - r - 14), label, 16, UIKit.GOLD)


func _text(c: Control, font: Font, p: Vector2, s: String, size: int, col: Color) -> void:
	c.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.75 * col.a))
	c.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _commas(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func _star(c: Control, center: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(center + Vector2.UP.rotated(TAU * i / 10.0) * rr)
	c.draw_colored_polygon(pts, col)


## Current compass (spec §3.3): arrow = direction, length/label = strength,
## plus a with/against/cross tag relative to the boat heading.
func _compass(c: Control, font: Font, center: Vector2) -> void:
	var boat: Boat = world.boat
	var v: Vector2 = world.currents.sample(boat.position) + world.currents.whirl_force(boat.position)
	var s := v.length()
	c.draw_circle(center, 30, Color(0, 0, 0, 0.45))
	c.draw_arc(center, 30, 0, TAU, 32, Color(UIKit.BRASS, 0.7), 2.0)
	if s > 0.05:
		var d := v.normalized()
		var tip := center + d * 24.0
		c.draw_line(center - d * 14.0, tip, Color.WHITE, 4.0)
		c.draw_colored_polygon(PackedVector2Array([tip + d * 4, tip - d * 8 + d.orthogonal() * 8, tip - d * 8 - d.orthogonal() * 8]), Color.WHITE)
	var label := "Calm"
	if s >= 3.0: label = "Raging"
	elif s >= 2.2: label = "Strong"
	elif s >= 1.4: label = "Moderate"
	elif s >= 0.6: label = "Gentle"
	var rel := ""
	if s > 0.4 and boat.throttle > 0.1:
		var dot := v.normalized().dot(boat.heading())
		rel = "with you" if dot > 0.5 else ("against" if dot < -0.5 else "cross")
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_text(c, font, center + Vector2(-w / 2, 50), label, 15, Color.WHITE)
	if rel != "":
		var w2 := font.get_string_size(rel, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var rc := Color(0.5, 1.0, 0.6) if rel == "with you" else (Color(1.0, 0.5, 0.4) if rel == "against" else Color(1.0, 0.9, 0.5))
		_text(c, font, center + Vector2(-w2 / 2, 67), rel, 14, rc)


func _banner_draw(c: Control, font: Font, W: float) -> void:
	if _banner_t <= 0.0:
		return
	var a := clampf(minf(_banner_t, 3.5 - _banner_t) / 0.6, 0.0, 1.0)
	var w := font.get_string_size(_banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	_text(c, font, Vector2(W / 2 - w / 2, 120), _banner, 40, Color(1, 0.97, 0.88, a))
	for i in _banner_stars:
		_star(c, Vector2(W / 2 + (i - (_banner_stars - 1) * 0.5) * 20, 142), STAR, Color(UIKit.GOLD, a))


func _catch_draw(c: Control, font: Font, W: float) -> void:
	if _catch_t <= 0.0 or _catch.is_empty():
		return
	var f: Dictionary = Data.FISH[_catch.id]
	var a := clampf(minf(_catch_t, 3.0 - _catch_t) / 0.3, 0.0, 1.0)
	var rect := Rect2(W / 2 - 220, 330, 440, 96)
	var rc: Color = Data.RARITY_COLORS[f.rarity]
	c.draw_rect(rect, Color(0.08, 0.12, 0.17, 0.9 * a))
	c.draw_rect(rect, Color(rc, a), false, 3.0)
	Art.draw_fish(c, _catch.id, rect.position + Vector2(60, 48), 90.0, 0.0, Color(1, 1, 1, a), true)
	_text(c, font, rect.position + Vector2(120, 34), "%s%s" % [f.name, "  NEW!" if _catch_first else ""], 24, Color(rc, a))
	_text(c, font, rect.position + Vector2(120, 60), "%s  ·  size %.2fx  ·  ~%d gold" % [String(f.rarity).capitalize(), _catch.size, Game.fish_value(_catch)], 17, Color(1, 1, 1, a))
	_text(c, font, rect.position + Vector2(120, 84), "%d dmg  ·  %s" % [int(Data.fish_damage(_catch)), Data.EFFECT_INFO[f.effect]], 15, Color(0.8, 0.85, 0.9, a))


func _fishing_draw(c: Control, font: Font, H: float) -> void:
	var fs: FishingSystem = world.fishing
	var cast_c := cast_btn.position + cast_btn.size * 0.5
	match fs.state:
		FishingSystem.State.CHARGE:
			var r := Rect2(cast_c + Vector2(-70, -92), Vector2(140, 18))
			c.draw_rect(r.grow(2), Color(0, 0, 0, 0.6))
			c.draw_rect(Rect2(r.position, Vector2(r.size.x * fs.power, r.size.y)), Color(1.0, 0.8, 0.3).lerp(Color(0.4, 1.0, 0.5), fs.power))
			_text(c, font, r.position + Vector2(0, -6), "Cast power", 15, Color.WHITE)
		FishingSystem.State.BITE:
			var p := world_to_hud(fs.bobber) + Vector2(-12, -36)
			var pulse := 1.0 + 0.25 * sin(Time.get_ticks_msec() / 60.0)
			_text(c, font, p, "!", int(56 * pulse), Color(1.0, 0.9, 0.2))
		FishingSystem.State.REEL:
			var x := _mx(360) - 20
			var bar := Rect2(x, H * 0.22, 40, 280)
			c.draw_rect(bar.grow(3), Color(0, 0, 0, 0.65))
			c.draw_rect(bar, Color(0.25, 0.1, 0.1, 0.8))
			var gz := fs.green_zone()
			var y0 := bar.end.y - bar.size.y * gz.y
			c.draw_rect(Rect2(bar.position.x, y0, bar.size.x, bar.size.y * (gz.y - gz.x)), Color(0.25, 0.75, 0.3, 0.8))
			var ty := bar.end.y - bar.size.y * clampf(fs.tension, 0.0, 1.0)
			var danger := fs.tension >= 0.98
			c.draw_rect(Rect2(bar.position.x - 6, ty - 3, bar.size.x + 12, 6), Color(1, 0.2, 0.2) if danger else Color.WHITE)
			var pb := Rect2(bar.end.x + 8, bar.position.y, 12, bar.size.y)
			c.draw_rect(pb.grow(2), Color(0, 0, 0, 0.6))
			c.draw_rect(Rect2(pb.position.x, pb.end.y - pb.size.y * fs.progress, pb.size.x, pb.size.y * fs.progress), Color(0.4, 0.8, 1.0))
			_text(c, font, Vector2(bar.position.x - 16, bar.position.y - 10), "Tension", 15, Color.WHITE)
			var hint := "Hold to reel — stay in the green" if Game.settings.reel_input == "hold" else "Tap to reel — stay in the green"
			_text(c, font, Vector2(bar.position.x - 70, bar.end.y + 26), hint, 15, Color(0.9, 0.9, 0.9))


## Edge-of-screen arrows: pirates (red), shops within SHOP_INDICATOR_RANGE (gold),
## merchants (purple), found islands (green) and your deployed traps (teal, any distance).
func _indicators(c: Control, font: Font) -> void:
	var boat: Boat = world.boat
	var detect := Game.detect_radius() * Data.U
	for p in world.get_pirates():
		if p.invisible or p.position.distance_to(boat.position) > detect:
			continue
		_arrow(c, font, p.position, Color(1.0, 0.25, 0.2), "")
	var fixed := []
	var shop_range := SHOP_INDICATOR_RANGE * Data.U
	for s in world.shops:
		if s.position.distance_to(boat.position) > shop_range:
			continue
		if s.merchant:
			_arrow(c, font, s.position, Color(0.75, 0.45, 1.0), s.shop_name)
		else:
			fixed.append(s)
	fixed.sort_custom(func(a, b): return a.position.distance_squared_to(boat.position) < b.position.distance_squared_to(boat.position))
	for i in mini(2, fixed.size()):
		_arrow(c, font, fixed[i].position, UIKit.GOLD, fixed[i].shop_name)
	for isl in world.islands:   # found islands with something left to do
		if isl.found() and not isl.done() and isl.position.distance_to(boat.position) < shop_range:
			_arrow(c, font, isl.position, Color(0.5, 0.95, 0.55), isl.island_name)
	for t in world.traps():
		_arrow(c, font, t.position, Color(0.45, 1.0, 0.85), "Trap %d/%d" % [t.data.catch.size(), t.capacity()])


func _arrow(c: Control, font: Font, world_pos: Vector2, col: Color, label: String) -> void:
	var size := root.size
	var q := world_to_hud(world_pos)
	if Rect2(Vector2.ZERO, size).has_point(q):
		return
	var center := size * 0.5
	var dir := q - center
	var half := size * 0.5 - Vector2(44, 44)
	var k := INF
	if absf(dir.x) > 0.001: k = minf(k, half.x / absf(dir.x))
	if absf(dir.y) > 0.001: k = minf(k, half.y / absf(dir.y))
	var p := center + dir * k
	var d := dir.normalized()
	c.draw_colored_polygon(PackedVector2Array([p + d * 16, p - d * 10 + d.orthogonal() * 12, p - d * 10 - d.orthogonal() * 12]), col)
	var dist := int(world.boat.position.distance_to(world_pos) / Data.U)
	var txt := ("%s %dm" % [label, dist]) if label != "" else "%dm" % dist
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var tp := p - d * 30 + Vector2(-w / 2, 5)
	tp.x = clampf(tp.x, 4, size.x - w - 4)
	_text(c, font, tp, txt, 14, col)
