extends Node
## Single lookup point for art. Every visual first asks Art.tex(key); if a file
## res://assets/sprites/<key>.png (or .webp) exists it is drawn, otherwise the
## entity falls back to its placeholder vector drawing. See README.md for keys.

const SPRITE_DIRS := ["res://assets/sprites/", "res://assets/sprites/fish_sheet/"]
## Fish sheet sprites (cut from assets/fish.png) are drawn diagonally, head up-left.
## Mirroring and turning them 45° makes them face +X; their body runs along the
## diagonal, so the texture is drawn at length / sqrt(2) to keep the fish `length` long.
const FISH_DIAG := 0.7071

var _cache := {}


func tex(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var t: Texture2D = null
	for dir in SPRITE_DIRS:
		for ext in ["png", "webp"]:
			var p := "%s%s.%s" % [dir, key, ext]
			if ResourceLoader.exists(p):
				t = load(p)
				break
		if t != null:
			break
	_cache[key] = t
	return t


## Draws a texture centered at `pos`, scaled so its width equals `width` px
## (sprites are authored facing right / +X).
func draw_tex(ci: CanvasItem, t: Texture2D, pos: Vector2, width: float, angle := 0.0, mod := Color.WHITE) -> void:
	var s := Vector2(width, width * t.get_height() / float(t.get_width()))
	ci.draw_set_transform(pos, angle, Vector2.ONE)
	ci.draw_texture_rect(t, Rect2(-s * 0.5, s), false, mod)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Draws a fish (sprite "fish_<id>" or placeholder) centered at pos, facing `angle`.
## `icon` keeps a sprite in its authored diagonal pose (inventory/UI) instead of
## turning it to face `angle`.
func draw_fish(ci: CanvasItem, id: String, pos: Vector2, length: float, angle := 0.0, mod := Color.WHITE, icon := false) -> void:
	var t := tex("fish_" + id)
	if t != null:
		var w := length * FISH_DIAG
		var s := Vector2(w, w * t.get_height() / float(t.get_width()))
		if icon:
			ci.draw_set_transform(pos, 0.0, Vector2.ONE)
		else:
			ci.draw_set_transform(pos, angle + PI * 0.25, Vector2(-1, 1))
		ci.draw_texture_rect(t, Rect2(-s * 0.5, s), false, mod)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	var f: Dictionary = Data.FISH.get(id, Data.FISH.mackerel)
	var c: Color = f.color * mod
	var dark := c.darkened(0.45)
	ci.draw_set_transform(pos, angle, Vector2.ONE)
	var L := length * 0.5
	if id == "old_boot":
		ci.draw_rect(Rect2(-L, -L * 0.25, L * 1.2, L * 0.6), c)
		ci.draw_rect(Rect2(-L, -L * 0.85, L * 0.55, L * 0.7), c)
		ci.draw_rect(Rect2(-L, L * 0.25, L * 1.3, L * 0.12), dark)
	else:
		var body := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			body.append(Vector2(cos(a) * L * 0.75 + L * 0.1, sin(a) * L * 0.32))
		ci.draw_colored_polygon(body, c)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-L * 0.55, 0), Vector2(-L, -L * 0.35), Vector2(-L, L * 0.35)]), dark)
		ci.draw_circle(Vector2(L * 0.55, -L * 0.08), maxf(1.5, L * 0.07), Color(0.05, 0.05, 0.05))
		if id == "swordfish" or id == "narwhal_fish":
			ci.draw_line(Vector2(L * 0.8, 0), Vector2(L * 1.35, 0), dark, maxf(1.5, L * 0.06))
		elif id == "clownfish":
			ci.draw_line(Vector2(L * 0.25, -L * 0.3), Vector2(L * 0.25, L * 0.3), Color.WHITE, maxf(1.5, L * 0.1))
		elif id == "anglerfish":
			ci.draw_line(Vector2(L * 0.6, -L * 0.3), Vector2(L * 0.9, -L * 0.6), dark, 1.5)
			ci.draw_circle(Vector2(L * 0.9, -L * 0.6), maxf(2.0, L * 0.09), Color(1.0, 1.0, 0.6))
		elif id == "giant_squid":
			for k in 4:
				var y := (k - 1.5) * L * 0.14
				ci.draw_line(Vector2(-L * 0.55, y), Vector2(-L * 1.25, y * 1.8), c, maxf(1.5, L * 0.07))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
