class_name UILayer
extends CanvasLayer
## CanvasLayer whose `root` Control is scaled by the UI-scale setting and inset
## to the device safe area (notches, gesture bars).

signal relayout_done

var root: Control


func _init(index := 1) -> void:
	layer = index
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.theme()
	add_child(root)


func _ready() -> void:
	get_viewport().size_changed.connect(relayout)
	Game.settings_changed.connect(relayout)
	relayout()


func relayout() -> void:
	var s: float = clampf(float(Game.settings.ui_scale), 0.8, 1.4)
	var vp := get_viewport().get_visible_rect().size
	var safe := _safe_rect(vp)
	scale = Vector2(s, s)
	offset = safe.position
	root.position = Vector2.ZERO
	root.size = safe.size / s
	relayout_done.emit()


## Maps a viewport-space point into root-local coordinates.
func to_local_ui(vp_point: Vector2) -> Vector2:
	return (vp_point - offset) / scale.x


func _safe_rect(vp: Vector2) -> Rect2:
	if not OS.has_feature("mobile"):
		return Rect2(Vector2.ZERO, vp)
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.x <= 0 or screen.y <= 0 or safe.size.x <= 0:
		return Rect2(Vector2.ZERO, vp)
	var k := vp / Vector2(screen)
	return Rect2(Vector2(safe.position) * k, Vector2(safe.size) * k)
