class_name Shop
extends Node2D
## A fixed dock or a roaming merchant vessel (spec §6.1). The safe radius keeps
## pirates out; inside the dock radius the HUD offers an Enter Shop button.

var id := ""
var shop_name := ""
var biome := ""
var merchant := false
var life := INF                  # merchants expire
var safe_radius := 7.0 * Data.U
var dock_radius := 5.5 * Data.U


func setup_fixed(d: Dictionary) -> void:
	id = d.id
	shop_name = d.name
	position = Data.shop_pos(d)
	biome = Data.biome_at(position)


func setup_merchant(pos: Vector2, lifetime: float) -> void:
	id = "merchant_%d" % randi()
	shop_name = Data.MERCHANT_NAMES.pick_random()
	position = pos
	biome = Data.biome_at(pos)
	merchant = true
	life = lifetime
	safe_radius = 5.0 * Data.U
	dock_radius = 4.0 * Data.U


func _process(delta: float) -> void:
	if merchant:
		life -= delta
	queue_redraw()


func _draw() -> void:
	var ring := Color(1.0, 0.85, 0.4, 0.18) if not merchant else Color(0.8, 0.5, 1.0, 0.2)
	_dashed_circle(safe_radius, ring)
	draw_arc(Vector2.ZERO, dock_radius, 0, TAU, 48, Color(ring, 0.55), 3.0)
	var t := Art.tex("merchant" if merchant else "shop")
	if t != null:
		Art.draw_tex(self, t, Vector2.ZERO, (3.0 if merchant else 4.0) * Data.U)
	elif merchant:
		_draw_merchant()
	else:
		_draw_dock()
	var font := ThemeDB.fallback_font
	var label := shop_name if not merchant else "%s (%d:%02d)" % [shop_name, int(life) / 60, int(life) % 60]
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 18).x
	draw_string_outline(font, Vector2(-w / 2, -2.4 * Data.U), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(-w / 2, -2.4 * Data.U), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.95, 0.8))


func _draw_dock() -> void:
	var wood := Color(0.6, 0.42, 0.24)
	draw_rect(Rect2(-56, -12, 112, 24), wood)
	for i in 8:
		draw_line(Vector2(-56 + i * 14, -12), Vector2(-56 + i * 14, 12), wood.darkened(0.3), 1.0)
	draw_rect(Rect2(-14, -52, 28, 40), wood)
	for x in [-60, 60]:
		draw_circle(Vector2(x, 0), 5.0, wood.darkened(0.4))
	draw_rect(Rect2(-36, -50, 30, 30), Color(0.75, 0.55, 0.32))
	draw_colored_polygon(PackedVector2Array([Vector2(-40, -50), Vector2(-21, -66), Vector2(-2, -50)]), Color(0.7, 0.2, 0.15))
	draw_line(Vector2(30, -12), Vector2(30, -60), Color(0.3, 0.2, 0.1), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(30, -60), Vector2(50, -54), Vector2(30, -48)]), Color(1.0, 0.8, 0.2))


func _draw_merchant() -> void:
	var L := 1.4 * Data.U
	var W := 0.6 * Data.U
	var hull := PackedVector2Array([Vector2(L, 0), Vector2(L * 0.4, -W), Vector2(-L * 0.9, -W * 0.85),
		Vector2(-L * 0.9, W * 0.85), Vector2(L * 0.4, W)])
	draw_colored_polygon(hull, Color(0.45, 0.28, 0.4))
	draw_rect(Rect2(-L * 0.12, -W * 1.3, L * 0.2, W * 2.6), Color(0.7, 0.4, 0.95))
	draw_rect(Rect2(-L * 0.7, -W * 0.4, 14, 14), Color(1.0, 0.8, 0.3))


func _dashed_circle(r: float, c: Color) -> void:
	var n := 48
	for i in n:
		if i % 2 == 0:
			draw_arc(Vector2.ZERO, r, TAU * i / n, TAU * (i + 1) / n, 4, c, 2.0)
