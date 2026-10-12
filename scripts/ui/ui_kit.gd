class_name UIKit
extends RefCounted
## Theme and small widget helpers for code-built menus. If
## res://assets/ui/theme.tres exists it replaces the generated placeholder theme.

const BG := Color(0.11, 0.17, 0.23, 0.97)
const BRASS := Color(0.79, 0.64, 0.42)
const TEXT := Color(0.95, 0.92, 0.84)
const GOLD := Color(1.0, 0.85, 0.3)
const DIM := Color(0.7, 0.72, 0.75)

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	if ResourceLoader.exists("res://assets/ui/theme.tres"):
		_theme = load("res://assets/ui/theme.tres")
		return _theme
	var t := Theme.new()
	t.default_font_size = 22
	var panel := _box(BG, BRASS, 3, 10)
	panel.set_content_margin_all(14)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var row := _box(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, 6)
	row.set_content_margin_all(6)
	t.set_stylebox("panel", "RowPanel", row)
	t.set_type_variation("RowPanel", "PanelContainer")
	for cls in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, _box(Color(0.18, 0.29, 0.39), BRASS.darkened(0.3), 2, 8, 10))
		t.set_stylebox("hover", cls, _box(Color(0.23, 0.37, 0.5), BRASS, 2, 8, 10))
		t.set_stylebox("pressed", cls, _box(Color(0.13, 0.22, 0.3), BRASS, 2, 8, 10))
		t.set_stylebox("disabled", cls, _box(Color(0.15, 0.17, 0.2), Color(0.3, 0.3, 0.3), 2, 8, 10))
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_disabled_color", cls, Color(0.5, 0.5, 0.5))
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 10)
	var grabber := _box(BRASS, BRASS, 0, 10)
	t.set_stylebox("slider", "HSlider", _box(Color(0.1, 0.12, 0.15), Color(0, 0, 0, 0), 0, 4, 4))
	t.set_stylebox("grabber_area", "HSlider", _box(BRASS.darkened(0.2), Color(0, 0, 0, 0), 0, 4, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", grabber)
	_theme = t
	return t


static func _box(bg: Color, border: Color, bw: int, radius: int, pad := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	if pad > 0:
		sb.content_margin_left = pad * 1.6
		sb.content_margin_right = pad * 1.6
		sb.content_margin_top = pad
		sb.content_margin_bottom = pad
	return sb


static func label(text: String, size := 22, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, cb: Callable, size := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(cb)
	return b


static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func row() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "RowPanel"
	return p
