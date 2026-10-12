class_name FishpediaUI
extends Overlay
## Collection log of every species (spec §8.2).


func build() -> void:
	var total := Data.FISH.size()
	header("Fishpedia  %d / %d" % [Game.fishpedia.size(), total])
	var list := scroll_list()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(grid)
	var ids := Data.FISH.keys()
	ids.sort_custom(func(a, b): return Data.rarity_index(Data.FISH[a].rarity) < Data.rarity_index(Data.FISH[b].rarity))
	for id in ids:
		grid.add_child(_entry(id))


func _entry(id: String) -> Control:
	var f: Dictionary = Data.FISH[id]
	var known := Game.fishpedia.has(id)
	var row := UIKit.row()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UIKit.hbox()
	row.add_child(h)
	var icon := FishIcon.new(id, Vector2(90, 54))
	if not known:
		icon.tint = Color(0, 0, 0, 0.6)
	h.add_child(icon)
	var v := UIKit.vbox(0)
	var biomes := []
	for b in f.biomes:
		biomes.append("Anywhere" if b == "any" else Data.BIOMES[b].name)
	if known:
		var e: Dictionary = Game.fishpedia[id]
		v.add_child(UIKit.label(f.name, 20, Data.RARITY_COLORS[f.rarity]))
		v.add_child(UIKit.label("%s · %s" % [String(f.rarity).capitalize(), ", ".join(biomes)], 14, UIKit.DIM))
		v.add_child(UIKit.label("Caught %d · biggest %.2fx · %d g base" % [int(e.count), float(e.best), int(f.gold)], 14))
		v.add_child(UIKit.label("%d dmg in home waters (more from tougher seas) · %s" % [int(Data.species_damage(id, Data.home_tier(id))), Data.EFFECT_INFO[f.effect]], 14, Color(1.0, 0.8, 0.6)))
	else:
		v.add_child(UIKit.label("???", 20, UIKit.DIM))
		v.add_child(UIKit.label("Found in: %s" % ", ".join(biomes), 14, UIKit.DIM))
		if f.get("trap", false):
			v.add_child(UIKit.label("Caught in traps", 14, Color(0.45, 1.0, 0.85)))
	h.add_child(v)
	return row
