class_name Overlay
extends Control
## Base for full-screen menus: dims the game, centers a panel, closes on Back/Esc.
## Subclasses fill `body` in build().

signal closed

var panel_frac := Vector2(0.9, 0.88)
var panel: PanelContainer
var body: VBoxContainer
var _center: CenterContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)
	panel = PanelContainer.new()
	_center.add_child(panel)
	body = UIKit.vbox(10)
	panel.add_child(body)
	resized.connect(_fit)
	build()
	_fit()


func _fit() -> void:
	panel.custom_minimum_size = size * panel_frac


func build() -> void:
	pass


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


## Title row with an optional close button.
func header(title: String, with_close := true) -> HBoxContainer:
	var h := UIKit.hbox()
	h.add_child(UIKit.label(title, 30, UIKit.GOLD))
	h.add_child(UIKit.spacer())
	if with_close:
		h.add_child(UIKit.button("Close", close))
	body.add_child(h)
	return h


## Scrollable list area that expands to fill the panel.
func scroll_list() -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := UIKit.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	body.add_child(sc)
	return list


static func clear(node: Node) -> void:
	# Hide + queue_free (not remove_child) so a button can safely rebuild its own list.
	for c in node.get_children():
		if c is CanvasItem:
			c.visible = false
		c.queue_free()
