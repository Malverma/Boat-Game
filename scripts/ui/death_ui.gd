class_name DeathUI
extends Overlay
## Shown when the boat sinks (spec §9.2).

var lost_gold := 0
var lost_fish := 0


func _init(gold: int, fish: int) -> void:
	lost_gold = gold
	lost_fish = fish


func build() -> void:
	panel_frac = Vector2(0.5, 0.5)
	header("Your boat sank!", false)
	body.add_child(UIKit.label("Lost: %d fish and %d gold." % [lost_fish, lost_gold], 22))
	body.add_child(UIKit.label("Upgrades are never lost.", 18, UIKit.DIM))
	body.add_child(UIKit.label("You'll respawn at %s." % Data.shop_by_id(Game.last_shop).name, 18, UIKit.DIM))
	body.add_child(UIKit.spacer())
	body.add_child(UIKit.button("Respawn", _respawn, 28))


func _respawn() -> void:
	Game.world.respawn()
	close()


func _unhandled_input(_event: InputEvent) -> void:
	pass   # can't dismiss without respawning
