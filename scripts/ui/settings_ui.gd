class_name SettingsUI
extends Overlay
## Settings (spec §11). Every change applies immediately and is saved.


func build() -> void:
	panel_frac = Vector2(0.7, 0.9)
	header("Settings")
	var list := scroll_list()
	_choice(list, "Joystick side", "joystick_side", ["right", "left"])
	_choice(list, "Joystick mode", "joystick_mode", ["floating", "fixed"])
	_slider(list, "Joystick dead zone", "dead_zone", 0.0, 0.25, 0.01, 100.0, "%d%%")
	_choice(list, "Reel input", "reel_input", ["hold", "tap"])
	_slider(list, "UI scale", "ui_scale", 0.8, 1.4, 0.05, 100.0, "%d%%")
	_toggle(list, "Haptics", "haptics")
	_slider(list, "Music volume", "music", 0, 100, 1, 1.0, "%d")
	_slider(list, "SFX volume", "sfx", 0, 100, 1, 1.0, "%d")
	_toggle(list, "Show current overlay", "show_currents")
	_choice(list, "Language", "language", ["system"])


func _row(list: VBoxContainer, title: String) -> HBoxContainer:
	var row := UIKit.row()
	var h := UIKit.hbox()
	row.add_child(h)
	var l := UIKit.label(title, 20)
	l.custom_minimum_size = Vector2(280, 0)
	h.add_child(l)
	list.add_child(row)
	return h


func _choice(list: VBoxContainer, title: String, key: String, options: Array) -> void:
	var h := _row(list, title)
	for o in options:
		var b := UIKit.button(String(o).capitalize(), func():
			Game.set_setting(key, o)
			_refresh_choices(h, key), 18)
		b.set_meta("value", o)
		h.add_child(b)
	_refresh_choices(h, key)


func _refresh_choices(h: HBoxContainer, key: String) -> void:
	for b in h.get_children():
		if b is Button:
			b.disabled = b.get_meta("value") == Game.settings[key]


func _slider(list: VBoxContainer, title: String, key: String, lo: float, hi: float, step: float, display_mult: float, fmt: String) -> void:
	var h := _row(list, title)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Game.settings[key])
	s.custom_minimum_size = Vector2(260, 32)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := UIKit.label(fmt % int(round(s.value * display_mult)), 18)
	val.custom_minimum_size = Vector2(70, 0)
	s.value_changed.connect(func(v: float): val.text = fmt % int(round(v * display_mult)))
	# Apply on release so UI scale doesn't relayout under the finger mid-drag.
	s.drag_ended.connect(func(_changed: bool): Game.set_setting(key, s.value))
	h.add_child(s)
	h.add_child(val)


func _toggle(list: VBoxContainer, title: String, key: String) -> void:
	var h := _row(list, title)
	var b := CheckButton.new()
	b.button_pressed = bool(Game.settings[key])
	b.toggled.connect(func(on: bool): Game.set_setting(key, on))
	h.add_child(b)
