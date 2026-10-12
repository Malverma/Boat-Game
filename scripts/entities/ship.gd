class_name Ship
extends Node2D
## Shared base for the player boat and pirate ships: HP, status effects, impulses.

var world: Node
var hp := 100.0
var max_hp := 100.0
var radius := 0.9 * Data.U
var velocity := Vector2.ZERO   # px/s, steering-driven
var impulse := Vector2.ZERO    # px/s, knockback / flings, decays
var status := StatusEffects.new()
var dead := false
var hit_flash := 0.0
var _dot_accum := 0.0
var _dot_t := 0.0


func heading() -> Vector2:
	return Vector2.RIGHT.rotated(rotation)


func take_damage(amount: float, show := true) -> void:
	if dead or amount <= 0.0:
		return
	hp -= amount
	if show:
		hit_flash = 0.12
		world.float_text(position + Vector2(0, -radius), str(int(ceil(amount))), _damage_color())
	_on_damaged(amount)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		_on_died()


func _damage_color() -> Color:
	return Color(1, 1, 1)


func _on_damaged(_amount: float) -> void:
	pass


func _on_died() -> void:
	pass


## Call once per frame from subclasses: status DoTs, flash and impulse decay.
func tick_ship(delta: float) -> void:
	hit_flash = maxf(0.0, hit_flash - delta)
	var dot := status.update(delta)
	if dot > 0.0:
		_dot_accum += dot
		take_damage(dot, false)
	_dot_t -= delta
	if _dot_t <= 0.0:
		_dot_t = 0.6
		if _dot_accum >= 1.0 and not dead:
			world.float_text(position + Vector2(0, -radius), str(int(round(_dot_accum))), Color(1.0, 0.6, 0.3))
		_dot_accum = 0.0
	impulse = impulse.lerp(Vector2.ZERO, 1.0 - exp(-3.0 * delta))


## HP bar and status pips, drawn unrotated above the ship.
func draw_bars(show_hp: bool) -> void:
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	var y := -radius - 16.0
	if show_hp:
		var w := maxf(radius * 2.0, 40.0)
		draw_rect(Rect2(-w / 2 - 1, y - 1, w + 2, 7), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-w / 2, y, w * clampf(hp / max_hp, 0, 1), 5), Color(0.9, 0.2, 0.2))
	var i := 0
	for e in status.effects:
		draw_circle(Vector2(-12 + i * 9, y - 8), 4.0, StatusEffects.COLORS.get(e, Color.WHITE))
		i += 1
	draw_set_transform_matrix(Transform2D.IDENTITY)
