class_name StatusEffects
extends RefCounted
## Timed status effects on a ship (spec §5.1). Reapplying an effect refreshes its
## duration instead of stacking; different effects can be active together.

const COLORS := {
	"burn": Color(1.0, 0.45, 0.1), "bleed": Color(0.85, 0.08, 0.12), "freeze": Color(0.6, 0.9, 1.0),
	"stun": Color(1.0, 0.95, 0.3), "entangle": Color(0.35, 0.75, 0.25), "dazzle": Color(1.0, 0.55, 0.9),
	"blind": Color(0.45, 0.3, 0.6),
}

var effects := {}


func apply(effect: String, duration: float, dps := 0.0) -> void:
	effects[effect] = {"t": duration, "dps": dps}


func has(effect: String) -> bool:
	return effects.has(effect)


## Advances timers and returns damage-over-time dealt this frame.
func update(delta: float) -> float:
	var dmg := 0.0
	for e in effects.keys():
		var s: Dictionary = effects[e]
		dmg += float(s.dps) * minf(delta, float(s.t))
		s.t = float(s.t) - delta
		if s.t <= 0.0:
			effects.erase(e)
	return dmg


func speed_mult() -> float:
	if effects.has("stun"):
		return 0.0
	var m := 1.0
	if effects.has("entangle"):
		m = minf(m, 0.5)
	if effects.has("freeze"):
		m = minf(m, 0.2)
	return m


func is_stunned() -> bool:
	return effects.has("stun")


## Multiplier on firing spread: Dazzle lowers accuracy by 40%.
func spread_mult() -> float:
	return 1.0 / 0.6 if effects.has("dazzle") else 1.0


func clear() -> void:
	effects.clear()
