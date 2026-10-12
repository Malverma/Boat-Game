class_name MainMenu
extends UILayer
## Title screen (spec §8.2): Continue, New Game, Settings, Fishpedia.

signal start_game(new_game: bool)

var _box: VBoxContainer
var _bg: ColorRect


func _init() -> void:
	super(5)


func _ready() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.07, 0.3, 0.4)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bg)
	var bg_tex := Art.tex("title_background")
	if bg_tex != null:
		var tr := TextureRect.new()
		tr.texture = bg_tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bg.add_child(tr)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.add_child(center)
	_box = UIKit.vbox(14)
	_box.custom_minimum_size = Vector2(360, 0)
	center.add_child(_box)
	var logo := Art.tex("title_logo")
	if logo != null:
		var tr := TextureRect.new()
		tr.texture = logo
		tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		_box.add_child(tr)
	else:
		var title := UIKit.label("BoatGame", 64, UIKit.GOLD)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(title)
		var sub := UIKit.label("Every catch is a decision.", 20, UIKit.TEXT)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(sub)
	_box.add_child(UIKit.label("", 10))
	var cont := UIKit.button("Continue", func(): start_game.emit(false), 28)
	cont.disabled = not Game.has_save()
	_box.add_child(cont)
	_box.add_child(UIKit.button("New Game", _new_game, 28))
	_box.add_child(UIKit.button("Settings", func(): _open(SettingsUI.new()), 28))
	_box.add_child(UIKit.button("Fishpedia", _open_fishpedia, 28))
	relayout_done.connect(func(): _bg.size = root.size)
	super()


func _new_game() -> void:
	if not Game.has_save():
		start_game.emit(true)
		return
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "Start a new game? Your current save will be overwritten."
	confirm.confirmed.connect(func(): start_game.emit(true))
	add_child(confirm)
	confirm.popup_centered()


func _open_fishpedia() -> void:
	if Game.has_save():
		Game.load_game()
	_open(FishpediaUI.new())


func _open(o: Overlay) -> void:
	root.add_child(o)
