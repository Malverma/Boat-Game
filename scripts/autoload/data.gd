extends Node
## Static game data: world layout, biomes, fish, pirates, upgrades and shops.
## All tuning numbers live here (spec §3–§7).

const U := 32.0                     # pixels per world unit
const GRID := 8                     # sectors per map side
const SECTOR := 40.0                # units per sector
const SECTOR_PX := SECTOR * U
const WORLD_PX := SECTOR_PX * GRID

# Average fish damage by star tier (index = stars). Each tier is 1.8× the last,
# so an enemy that takes 2–3 local fish takes 4–5 fish from the previous tier.
const TIER_DMG := [0.0, 10.0, 18.0, 32.0, 58.0, 104.0]
# Enemy hp assumes the barrel level a captain usually has by then (stars − 1),
# so upgrading past that shortens fights and falling behind lengthens them.
const BARREL_PER_TIER := 0.15

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
const RARITY_WEIGHTS := [60.0, 25.0, 10.0, 4.0, 1.0]
const RARITY_COLORS := {
	"junk": Color(0.54, 0.48, 0.4),
	"common": Color(0.75, 0.75, 0.75),
	"uncommon": Color(0.3, 0.77, 0.32),
	"rare": Color(0.25, 0.55, 1.0),
	"epic": Color(0.69, 0.36, 1.0),
	"legendary": Color(1.0, 0.77, 0.2),
}

# Hand-authored 8x8 map, row 0 = north. Codes map to BIOME_CODES.
const BIOME_GRID := [
	"AFFFFFFA",
	"DFFFFFFD",
	"DDKKKKDD",
	"DKRSSRKD",
	"DKRSSRKD",
	"DDKKKKDD",
	"DVVVVVVD",
	"AVVVVVVA",
]
const BIOME_CODES := {"S": "shallows", "R": "reef", "K": "kelp", "D": "deep", "F": "frozen", "V": "volcanic", "A": "abyss"}

# current: base strength in units/s (calm pockets cut it to zero, see CurrentField).
# threat: base encounter chance per spawn check. shark_chance: share of encounters
# that are a shark pack instead of pirates.
const BIOMES := {
	"shallows": {"name": "Shallows", "stars": 1, "deep": Color(0.13, 0.62, 0.7), "light": Color(0.5, 0.9, 0.86), "sparkle": 0.0,
		"current": 0.4, "style": "calm", "threat": 0.2, "pirates": ["dinghy"], "max_pirates": 1, "hazard": "", "shark_chance": 0.35},
	"reef": {"name": "Coral Reef", "stars": 2, "deep": Color(0.1, 0.55, 0.72), "light": Color(0.95, 0.55, 0.6), "sparkle": 0.0,
		"current": 0.7, "style": "eddy", "threat": 0.3, "pirates": ["dinghy"], "max_pirates": 1, "hazard": "", "shark_chance": 0.5},
	"kelp": {"name": "Kelp Forest", "stars": 2, "deep": Color(0.06, 0.3, 0.22), "light": Color(0.2, 0.48, 0.28), "sparkle": 0.0,
		"current": 1.1, "style": "steady", "threat": 0.4, "pirates": ["dinghy", "dinghy", "sloop"], "max_pirates": 2, "hazard": "", "shark_chance": 0.35},
	"deep": {"name": "Open Deep", "stars": 3, "deep": Color(0.05, 0.12, 0.3), "light": Color(0.12, 0.25, 0.48), "sparkle": 0.0,
		"current": 1.9, "style": "stream", "threat": 0.5, "pirates": ["sloop", "sloop", "brigantine"], "max_pirates": 2, "hazard": "", "shark_chance": 0.35},
	"frozen": {"name": "Frozen Sea", "stars": 4, "deep": Color(0.45, 0.62, 0.75), "light": Color(0.88, 0.95, 1.0), "sparkle": 0.6,
		"current": 1.7, "style": "drift", "threat": 0.6, "pirates": ["brigantine", "ironclad"], "max_pirates": 2, "hazard": "ice", "shark_chance": 0.3},
	"volcanic": {"name": "Volcanic Vents", "stars": 4, "deep": Color(0.22, 0.06, 0.05), "light": Color(0.6, 0.18, 0.08), "sparkle": 0.3,
		"current": 1.5, "style": "burst", "threat": 0.6, "pirates": ["brigantine", "ironclad"], "max_pirates": 2, "hazard": "heat"},
	"abyss": {"name": "The Abyss", "stars": 5, "deep": Color(0.02, 0.02, 0.06), "light": Color(0.06, 0.08, 0.16), "sparkle": 1.0,
		"current": 2.1, "style": "chaotic", "threat": 0.75, "pirates": ["ghost", "ghost", "ghost", "lord"], "max_pirates": 2, "hazard": ""},
}

const BIOME_NEIGHBORS := {
	"shallows": ["reef", "kelp"],
	"reef": ["shallows", "kelp"],
	"kelp": ["shallows", "reef", "deep"],
	"deep": ["kelp", "frozen", "volcanic", "abyss"],
	"frozen": ["deep", "abyss"],
	"volcanic": ["deep", "abyss"],
	"abyss": ["deep", "frozen", "volcanic"],
}

# Spec §5. "len" is the drawn length in units (placeholder art / projectile size).
# "pow" is cannon damage relative to the average catch: a fish hits for
# pow × TIER_DMG[tier of the waters it was caught in] (see fish_damage), and
# each biome's catch-weighted average pow is ~1.0.
const FISH := {
	"sardine": {"name": "Sardine", "biomes": ["shallows", "reef"], "rarity": "common", "gold": 5, "pow": 0.85, "effect": "scatter", "color": Color(0.62, 0.71, 0.78), "len": 0.5},
	"mackerel": {"name": "Mackerel", "biomes": ["shallows", "kelp"], "rarity": "common", "gold": 8, "pow": 1.15, "effect": "none", "color": Color(0.31, 0.5, 0.63), "len": 0.7},
	"kelp_bass": {"name": "Kelp Bass", "biomes": ["kelp"], "rarity": "common", "gold": 12, "pow": 0.8, "effect": "entangle", "color": Color(0.36, 0.54, 0.29), "len": 0.75},
	"clownfish": {"name": "Clownfish", "biomes": ["reef"], "rarity": "uncommon", "gold": 20, "pow": 1.0, "effect": "dazzle", "color": Color(1.0, 0.54, 0.16), "len": 0.5},
	"pufferfish": {"name": "Pufferfish", "biomes": ["reef"], "rarity": "uncommon", "gold": 30, "pow": 1.45, "effect": "spike", "color": Color(0.91, 0.82, 0.48), "len": 0.6},
	"tuna": {"name": "Tuna", "biomes": ["deep"], "rarity": "uncommon", "gold": 45, "pow": 0.95, "effect": "heavy", "color": Color(0.23, 0.31, 0.54), "len": 1.0},
	"ice_cod": {"name": "Ice Cod", "biomes": ["frozen"], "rarity": "uncommon", "gold": 50, "pow": 1.0, "effect": "freeze", "color": Color(0.75, 0.9, 1.0), "len": 0.8},
	"electric_eel": {"name": "Electric Eel", "biomes": ["kelp"], "rarity": "rare", "gold": 60, "pow": 1.15, "effect": "shock", "color": Color(0.85, 0.94, 0.29), "len": 1.0},
	"swordfish": {"name": "Swordfish", "biomes": ["deep"], "rarity": "rare", "gold": 90, "pow": 1.3, "effect": "pierce", "color": Color(0.44, 0.53, 0.72), "len": 1.2},
	"lava_eel": {"name": "Lava Eel", "biomes": ["volcanic"], "rarity": "rare", "gold": 110, "pow": 0.97, "effect": "burn", "color": Color(1.0, 0.35, 0.12), "len": 1.0},
	"hammerhead": {"name": "Hammerhead Shark", "biomes": ["deep"], "rarity": "epic", "gold": 200, "pow": 1.7, "effect": "bleed", "color": Color(0.49, 0.54, 0.59), "len": 1.3},
	"narwhal_fish": {"name": "Narwhal-fish", "biomes": ["frozen"], "rarity": "epic", "gold": 260, "pow": 1.6, "effect": "impale", "color": Color(0.9, 0.93, 0.95), "len": 1.3},
	"magma_grouper": {"name": "Magma Grouper", "biomes": ["volcanic"], "rarity": "epic", "gold": 240, "pow": 1.7, "effect": "explosive", "color": Color(0.66, 0.2, 0.12), "len": 1.1, "reload_extra": 0.5},
	"anglerfish": {"name": "Anglerfish", "biomes": ["abyss"], "rarity": "epic", "gold": 300, "pow": 1.0, "effect": "lure", "color": Color(0.23, 0.18, 0.32), "len": 0.9},
	"giant_squid": {"name": "Giant Squid", "biomes": ["abyss"], "rarity": "legendary", "gold": 800, "pow": 2.0, "effect": "ink", "color": Color(0.76, 0.25, 0.35), "len": 1.4, "reload_extra": 0.5},
	"golden_koi": {"name": "Golden Koi", "biomes": ["any"], "rarity": "legendary", "gold": 1000, "pow": 0.5, "effect": "midas", "color": Color(1.0, 0.82, 0.25), "len": 0.8},
	"old_boot": {"name": "Old Boot", "biomes": ["any"], "rarity": "junk", "gold": 0, "pow": 0.3, "effect": "bonk", "color": Color(0.42, 0.29, 0.18), "len": 0.6},
	# Crustaceans and bottom feeders: only caught in deployable traps ("trap": true).
	"shrimp": {"name": "Shrimp", "biomes": ["shallows", "reef"], "rarity": "common", "gold": 10, "pow": 0.6, "effect": "scatter", "color": Color(1.0, 0.6, 0.65), "len": 0.45, "trap": true},
	"red_crab": {"name": "Red Crab", "biomes": ["shallows", "reef"], "rarity": "common", "gold": 12, "pow": 1.15, "effect": "none", "color": Color(0.9, 0.25, 0.15), "len": 0.55, "trap": true},
	"oyster": {"name": "Oyster", "biomes": ["shallows", "kelp"], "rarity": "common", "gold": 14, "pow": 0.85, "effect": "heavy", "color": Color(0.55, 0.5, 0.45), "len": 0.45, "trap": true},
	"sea_cucumber": {"name": "Sea Cucumber", "biomes": ["kelp", "deep"], "rarity": "common", "gold": 15, "pow": 0.85, "effect": "entangle", "color": Color(0.55, 0.55, 0.15), "len": 0.55, "trap": true},
	"flounder": {"name": "Flounder", "biomes": ["shallows", "reef", "kelp"], "rarity": "uncommon", "gold": 28, "pow": 1.1, "effect": "dazzle", "color": Color(0.55, 0.42, 0.32), "len": 0.65, "trap": true},
	"rock_crab": {"name": "Rock Crab", "biomes": ["reef", "kelp"], "rarity": "uncommon", "gold": 32, "pow": 1.2, "effect": "heavy", "color": Color(1.0, 0.65, 0.15), "len": 0.6, "trap": true},
	"scallop": {"name": "Scallop", "biomes": ["reef", "deep"], "rarity": "uncommon", "gold": 35, "pow": 0.9, "effect": "scatter", "color": Color(0.95, 0.85, 0.75), "len": 0.5, "trap": true},
	"catfish": {"name": "Sea Catfish", "biomes": ["kelp", "deep"], "rarity": "uncommon", "gold": 40, "pow": 1.2, "effect": "spike", "color": Color(0.45, 0.43, 0.35), "len": 0.75, "trap": true},
	"sculpin": {"name": "Ice Sculpin", "biomes": ["frozen"], "rarity": "uncommon", "gold": 55, "pow": 1.0, "effect": "freeze", "color": Color(0.5, 0.32, 0.25), "len": 0.65, "trap": true},
	"fire_starfish": {"name": "Fire Starfish", "biomes": ["volcanic"], "rarity": "uncommon", "gold": 60, "pow": 1.0, "effect": "burn", "color": Color(1.0, 0.45, 0.1), "len": 0.6, "trap": true},
	"decorator_crab": {"name": "Decorator Crab", "biomes": ["reef", "kelp"], "rarity": "rare", "gold": 95, "pow": 1.3, "effect": "entangle", "color": Color(0.3, 0.65, 0.3), "len": 0.6, "trap": true},
	"lobster": {"name": "Lobster", "biomes": ["kelp", "deep", "volcanic"], "rarity": "rare", "gold": 110, "pow": 1.5, "effect": "pierce", "color": Color(0.85, 0.2, 0.1), "len": 0.75, "trap": true},
	"sea_star": {"name": "Frost Sea Star", "biomes": ["frozen"], "rarity": "rare", "gold": 120, "pow": 1.3, "effect": "freeze", "color": Color(0.7, 0.65, 0.95), "len": 0.6, "trap": true},
	"nautilus": {"name": "Nautilus", "biomes": ["deep", "frozen", "abyss"], "rarity": "rare", "gold": 140, "pow": 1.05, "effect": "pierce", "color": Color(0.95, 0.85, 0.65), "len": 0.6, "trap": true},
	"blobfish": {"name": "Blobfish", "biomes": ["deep", "abyss"], "rarity": "epic", "gold": 280, "pow": 1.6, "effect": "heavy", "color": Color(0.95, 0.7, 0.85), "len": 0.7, "trap": true},
	"blue_lobster": {"name": "Blue Lobster", "biomes": ["any"], "rarity": "legendary", "gold": 900, "pow": 2.0, "effect": "shock", "color": Color(0.2, 0.55, 0.9), "len": 0.75, "trap": true},
	"tin_can": {"name": "Tin Can", "biomes": ["any"], "rarity": "junk", "gold": 0, "pow": 0.35, "effect": "bonk", "color": Color(0.6, 0.2, 0.2), "len": 0.45, "trap": true},
}

const EFFECT_INFO := {
	"none": "Standard shot",
	"scatter": "Scatter — 3 projectiles in a cone",
	"dazzle": "Dazzle — target accuracy -40% for 4 s",
	"spike": "Spike Burst — small area damage",
	"shock": "Shock — stun 2 s, chains to 1 ship",
	"entangle": "Entangle — target speed -50% for 3 s",
	"pierce": "Pierce — passes through up to 3 ships",
	"heavy": "Heavy — knockback",
	"bleed": "Bleed — 5 dmg/s for 6 s",
	"freeze": "Freeze — target speed -80% for 3 s",
	"impale": "Impale — ignores armor",
	"burn": "Burn — 8 dmg/s for 5 s, spreads",
	"explosive": "Explosive — large area blast",
	"lure": "Lure — pulls enemies to impact",
	"ink": "Ink Cloud — blinds area 5 s, tentacle slams",
	"midas": "Midas — killing blow triples wreck Gold",
	"bonk": "Bonk — it's a boot",
}

# Spec §7.4. speed in units/s, turn in deg/s, radius in units.
# "toughness" = how many average fish from the waters it spawns in it takes to
# sink one (see enemy_hp): 2.2–2.8 for regular ships and creatures, so 2–3 local
# shots, or 4–5 from the previous tier's waters. Bosses take 8–16.
const PIRATES := {
	"dinghy": {"name": "Dinghy Raider", "toughness": 2.2, "speed": 5.8, "turn": 200, "radius": 0.7, "behavior": "ram", "ram_dmg": 12,
		"orbit": 0.0, "fire_cd": 0.0, "shot_dmg": 0, "shots": 0, "armor": 0.0, "gold": [10, 25], "fish_chance": 0.1, "fish_rarity": "common",
		"hull": Color(0.45, 0.3, 0.18), "sail": Color(0.15, 0.13, 0.12)},
	"sloop": {"name": "Sloop", "toughness": 2.4, "speed": 4.2, "turn": 120, "radius": 0.95, "behavior": "circle", "ram_dmg": 6,
		"orbit": 7.0, "fire_cd": 2.6, "shot_dmg": 8, "shots": 1, "armor": 0.0, "gold": [30, 60], "fish_chance": 0.4, "fish_rarity": "uncommon",
		"hull": Color(0.38, 0.24, 0.14), "sail": Color(0.12, 0.1, 0.1)},
	"brigantine": {"name": "Brigantine", "toughness": 2.6, "speed": 3.6, "turn": 80, "radius": 1.2, "behavior": "broadside", "ram_dmg": 10,
		"orbit": 7.5, "fire_cd": 4.0, "shot_dmg": 7, "shots": 3, "armor": 0.0, "gold": [80, 150], "fish_chance": 0.6, "fish_rarity": "rare",
		"hull": Color(0.32, 0.2, 0.12), "sail": Color(0.5, 0.1, 0.1)},
	"ironclad": {"name": "Ironclad", "toughness": 2.5, "speed": 2.6, "turn": 60, "radius": 1.3, "behavior": "broadside", "ram_dmg": 15,
		"orbit": 6.5, "fire_cd": 3.5, "shot_dmg": 12, "shots": 2, "armor": 0.2, "gold": [150, 250], "fish_chance": 0.3, "fish_rarity": "rare",
		"hull": Color(0.35, 0.37, 0.4), "sail": Color(0.18, 0.18, 0.2)},
	"ghost": {"name": "Ghost Ship", "toughness": 2.6, "speed": 4.0, "turn": 100, "radius": 1.2, "behavior": "circle", "ram_dmg": 10,
		"orbit": 7.0, "fire_cd": 2.2, "shot_dmg": 10, "shots": 1, "armor": 0.0, "gold": [200, 400], "fish_chance": 0.8, "fish_rarity": "epic",
		"hull": Color(0.35, 0.6, 0.55), "sail": Color(0.7, 0.95, 0.9), "invisible": true},
	"lord": {"name": "Pirate Lord", "toughness": 14, "speed": 3.2, "turn": 70, "radius": 1.8, "behavior": "lord", "ram_dmg": 20,
		"orbit": 8.0, "fire_cd": 3.2, "shot_dmg": 10, "shots": 3, "armor": 0.1, "gold": [1000, 1400], "fish_chance": 1.0, "fish_rarity": "legendary",
		"hull": Color(0.2, 0.1, 0.08), "sail": Color(0.75, 0.08, 0.1), "boss": true},
	# Sea creatures share the pirate AI/combat code. "art_scale" = sprite width / radius.
	# Shark: circles, then lunges for a bleeding bite. shot_dmg/fire_cd unused.
	"shark": {"name": "Shark", "toughness": 2.3, "speed": 6.4, "turn": 220, "radius": 0.8, "behavior": "shark", "ram_dmg": 14,
		"orbit": 5.0, "fire_cd": 3.0, "shot_dmg": 0, "shots": 0, "armor": 0.0, "gold": [0, 0], "fish_chance": 0.5, "fish_rarity": "uncommon",
		"hull": Color(0.43, 0.53, 0.6), "sail": Color(0.3, 0.4, 0.48), "creature": true, "art_scale": 3.4},
	# Kraken: rare boss. fire_cd = time between tentacle slams, shot_dmg = slam damage.
	"kraken": {"name": "Kraken", "toughness": 12, "speed": 2.8, "turn": 40, "radius": 2.4, "behavior": "kraken", "ram_dmg": 25,
		"orbit": 7.0, "fire_cd": 3.0, "shot_dmg": 18, "shots": 1, "armor": 0.15, "gold": [700, 1000], "fish_chance": 1.0, "fish_rarity": "legendary",
		"hull": Color(0.7, 0.23, 0.35), "sail": Color(0.56, 0.15, 0.27), "boss": true, "creature": true, "art_scale": 3.0},
	# Port City shore battery (island kind "port"): fixed on the island, outranges
	# the player, stone armor. Destroying it silences the port for good.
	"fort_cannon": {"name": "Shore Battery", "toughness": 6.0, "speed": 0.0, "turn": 90, "radius": 1.0, "behavior": "fort", "ram_dmg": 0,
		"orbit": 0.0, "fire_cd": 2.6, "shot_dmg": 11, "shots": 2, "armor": 0.3, "gold": [150, 250], "fish_chance": 0.0, "fish_rarity": "common",
		"hull": Color(0.5, 0.48, 0.45), "sail": Color(0.2, 0.2, 0.22)},
	# Treasure-map bosses (Data.BOSS_MAPS): they only rise at a marked lair.
	# Serpents circle and spit (shots/shot_dmg), and dive to resurface under the
	# boat for a bite (ram_dmg). "segments" = body length. Gold here is the body's
	# own loot; the map adds its bounty on top.
	"reef_serpent": {"name": "Reef Serpent", "toughness": 8, "speed": 4.6, "turn": 110, "radius": 1.2, "behavior": "serpent", "ram_dmg": 16,
		"orbit": 8.0, "fire_cd": 3.2, "shot_dmg": 8, "shots": 1, "armor": 0.0, "gold": [120, 200], "fish_chance": 1.0, "fish_rarity": "rare",
		"hull": Color(0.2, 0.62, 0.55), "sail": Color(0.95, 0.55, 0.45), "boss": true, "creature": true, "art_scale": 2.6, "segments": 7},
	"sea_serpent": {"name": "Sea Serpent", "toughness": 10, "speed": 5.0, "turn": 100, "radius": 1.5, "behavior": "serpent", "ram_dmg": 22,
		"orbit": 8.5, "fire_cd": 3.0, "shot_dmg": 11, "shots": 2, "armor": 0.05, "gold": [250, 400], "fish_chance": 1.0, "fish_rarity": "epic",
		"hull": Color(0.15, 0.32, 0.55), "sail": Color(0.55, 0.85, 0.75), "boss": true, "creature": true, "art_scale": 2.6, "segments": 9},
	"leviathan": {"name": "Ember Leviathan", "toughness": 13, "speed": 4.6, "turn": 85, "radius": 1.9, "behavior": "serpent", "ram_dmg": 30,
		"orbit": 9.0, "fire_cd": 2.8, "shot_dmg": 15, "shots": 3, "armor": 0.15, "gold": [500, 700], "fish_chance": 1.0, "fish_rarity": "epic",
		"hull": Color(0.32, 0.1, 0.07), "sail": Color(1.0, 0.5, 0.15), "boss": true, "creature": true, "art_scale": 2.6, "segments": 12},
	"elder_kraken": {"name": "Elder Kraken", "toughness": 16, "speed": 2.8, "turn": 40, "radius": 2.9, "behavior": "kraken", "ram_dmg": 32,
		"orbit": 7.5, "fire_cd": 2.6, "shot_dmg": 24, "shots": 1, "armor": 0.2, "gold": [800, 1100], "fish_chance": 1.0, "fish_rarity": "legendary",
		"hull": Color(0.32, 0.18, 0.5), "sail": Color(0.2, 0.1, 0.32), "boss": true, "creature": true, "art_scale": 3.0},
}
const KRAKEN_CHANCE := 0.07            # per spawn check in kraken waters (see SpawnDirector.CHECK_INTERVAL)
const KRAKEN_BIOMES := ["deep", "frozen", "abyss"]

const UPGRADES := {
	"hull": {"name": "Hull Plating", "cat": "Hull", "max": 5, "cost": 120, "desc": "+25 Max HP per level"},
	"reinforced_hull": {"name": "Reinforced Hull", "cat": "Hull", "max": 1, "cost": 900, "desc": "Ice immunity — unlocks the Frozen Sea"},
	"heat_plating": {"name": "Heat Plating", "cat": "Hull", "max": 1, "cost": 1000, "desc": "Heat immunity — unlocks the Volcanic Vents"},
	"engine": {"name": "Engine", "cat": "Engine", "max": 5, "cost": 150, "desc": "+Top speed, resists bad currents"},
	"rudder": {"name": "Rudder", "cat": "Engine", "max": 3, "cost": 100, "desc": "+20°/s turn rate per level"},
	"cargo": {"name": "Cargo Hold", "cat": "Hold", "max": 4, "cost": 140, "desc": "Fish capacity 10 / 16 / 22 / 30 / 40"},
	"ice_box": {"name": "Ice Box", "cat": "Hold", "max": 1, "cost": 450, "desc": "Fish never lose freshness"},
	"rod": {"name": "Rod", "cat": "Fishing", "max": 5, "cost": 110, "desc": "+Reel strength, wider green zone, better bites"},
	"line": {"name": "Line", "cat": "Fishing", "max": 4, "cost": 120, "desc": "+Tension before the line snaps"},
	"deep_line": {"name": "Deep-Sea Line", "cat": "Fishing", "max": 1, "cost": 1500, "desc": "Enables fishing in the Abyss"},
	"barrel": {"name": "Barrel", "cat": "Cannon", "max": 5, "cost": 160, "desc": "+15% damage and +0.8 range per level"},
	"loader": {"name": "Loader", "cat": "Cannon", "max": 4, "cost": 140, "desc": "-0.2 s reload per level"},
	"ammo_rack": {"name": "Ammo Rack", "cat": "Cannon", "max": 3, "cost": 200, "desc": "+1 quick-select ammo slot (max 4)"},
	"swivel": {"name": "Swivel Mount", "cat": "Cannon", "max": 2, "cost": 180, "desc": "Wider cannon aim arc"},
	"chart": {"name": "Navigator's Chart", "cat": "Navigation", "max": 1, "cost": 350, "desc": "Map shows current forecasts and all hot spots"},
	"spyglass": {"name": "Spyglass", "cat": "Navigation", "max": 3, "cost": 120, "desc": "Spot pirates from farther away"},
}
const UPGRADE_ORDER := ["hull", "reinforced_hull", "heat_plating", "engine", "rudder", "cargo", "ice_box",
	"rod", "line", "deep_line", "barrel", "loader", "ammo_rack", "swivel", "chart", "spyglass"]

# Shop stock by area. A shop's tier is its biome's star rating. Multi-level lines
# are capped by tier (see shop_upgrade_cap); one-off upgrades need a minimum tier.
# Each biome's specialties are stocked one level beyond the tier cap.
const UPGRADE_MIN_TIER := {
	"ice_box": 2, "chart": 2, "reinforced_hull": 3, "heat_plating": 3, "deep_line": 4,
}
const BIOME_SPECIALTIES := {
	"shallows": ["cargo", "spyglass"],
	"reef": ["rod", "line"],
	"kelp": ["engine", "rudder"],
	"deep": ["barrel", "cargo", "loader"],
	"frozen": ["hull", "line"],
	"volcanic": ["barrel", "loader", "ammo_rack"],
	"abyss": [],
}

# Deployable traps (shop "Deployables" tab). A trap soaks where it was dropped and
# rolls a catch every `interval` seconds until `capacity` is reached. `luck` works
# like rod/bait luck (shifts rarity weights up). min_tier = lowest shop tier selling it.
const TRAPS := {
	"crab_pot": {"name": "Crab Pot", "price": 200, "capacity": 3, "interval": 45.0, "luck": 0.0, "min_tier": 1,
		"desc": "Holds 3 catches. A slow, cheap way to fill the hold."},
	"lobster_cage": {"name": "Lobster Cage", "price": 650, "capacity": 5, "interval": 35.0, "luck": 0.25, "min_tier": 3,
		"desc": "Holds 5 catches, fills faster and lures rarer creatures."},
}
const TRAP_ORDER := ["crab_pot", "lobster_cage"]
const MAX_TRAPS := 4               # traps owned in total (carried + deployed)
const TRAP_HAUL_RADIUS := 3.0      # units

# Trap baits: one is used per deployment and lasts the whole soak. speed divides
# the catch interval; luck adds to the trap's luck. Sold in bundles of 5.
const TRAP_BAITS := {
	"worm": {"name": "Bait Worms", "price": 45, "luck": 0.15, "speed": 1.15, "min_tier": 1, "desc": "A little faster, a little luckier."},
	"meal": {"name": "Fish Meal", "price": 90, "luck": 0.3, "speed": 1.3, "min_tier": 1, "desc": "Solid all-rounder."},
	"chum": {"name": "Chum", "price": 160, "luck": 0.5, "speed": 1.5, "min_tier": 2, "desc": "Draws in crabs and lobsters fast."},
	"glow": {"name": "Glow Paste", "price": 350, "luck": 0.9, "speed": 1.6, "min_tier": 3, "desc": "Deep-sea lure. No junk; rare catches likely."},
}
const TRAP_BAIT_ORDER := ["worm", "meal", "chum", "glow"]

const BAIT_PRICE := 40         # for a bundle of 5
const GOLDEN_BAIT_PRICE := 250 # merchants only
const REPAIR_PER_HP := 1.0

# Fixed shops. "sector" is in sector coordinates (multiply by SECTOR_PX).
const SHOPS := [
	{"id": "driftwood", "name": "Driftwood Dock", "sector": Vector2(4.0, 4.0)},
	{"id": "coral_cove", "name": "Coral Cove", "sector": Vector2(2.5, 3.5)},
	{"id": "anemone", "name": "Anemone Market", "sector": Vector2(5.5, 4.5)},
	{"id": "kelpwatch", "name": "Kelpwatch Outpost", "sector": Vector2(3.5, 2.5)},
	{"id": "greenwater", "name": "Greenwater Post", "sector": Vector2(4.5, 5.5)},
	{"id": "lonely_buoy", "name": "Lonely Buoy", "sector": Vector2(0.5, 4.5)},
	{"id": "whale_rock", "name": "Whale Rock Port", "sector": Vector2(7.5, 3.5)},
	{"id": "frostbite", "name": "Frostbite Harbor", "sector": Vector2(3.0, 1.0)},
	{"id": "iceberg_hut", "name": "Iceberg Hut", "sector": Vector2(6.0, 0.5)},
	{"id": "ember_port", "name": "Ember Port", "sector": Vector2(2.0, 7.0)},
	{"id": "ashfall", "name": "Ashfall Dock", "sector": Vector2(5.5, 6.5)},
	{"id": "last_light", "name": "Last Light", "sector": Vector2(0.5, 0.5)},
	{"id": "lanterns_end", "name": "Lantern's End", "sector": Vector2(7.5, 7.5)},
]
const MERCHANT_NAMES := ["The Wandering Gull", "Salty Sal's Barge", "The Velvet Kraken", "Madame Brine", "The Copper Clam"]

# Rare small islands, placed once per save by World._place_islands (one per
# sector at most). "w" = pick weight in the allowed biomes ("any" = all).
const ISLAND_COUNT := 10
const ISLANDS := {
	"treasure": {"title": "Treasure Isle", "biomes": ["any"], "w": 3.0,
		"names": ["Doubloon Key", "Pegleg Atoll", "Skull Sands", "Old Ned's Rest"],
		"desc": "A red X is scratched into the sand beneath the palms. Someone buried something here."},
	"castaway": {"title": "Castaway's Rock", "biomes": ["shallows", "reef", "kelp", "deep", "frozen", "volcanic"], "w": 2.0,
		"names": ["Lonesome Rock", "Driftwood Spit", "Hermit's Perch"],
		"desc": "A ragged sailor waves from a smoky campfire."},
	"coconut": {"title": "Coconut Cay", "biomes": ["shallows", "reef", "kelp", "deep"], "w": 2.0,
		"names": ["Coconut Cay", "Palm Hollow", "Breezy Cay"],
		"desc": "Heavy palms and fresh water. Your crew can patch the hull and eat their fill."},
	"lookout": {"title": "Lookout Peak", "biomes": ["any"], "w": 2.0,
		"names": ["Gull's Watch", "Crow's Crag", "Spyglass Rock"],
		"desc": "An old stone watchtower. From the top you can see for miles."},
	"lagoon": {"title": "Hidden Lagoon", "biomes": ["shallows", "reef", "kelp", "deep", "frozen"], "w": 2.0,
		"names": ["Jade Lagoon", "Mirror Atoll", "Sunken Ring"],
		"desc": "A ring of sand around a still lagoon. Rare fish shelter inside — cast into it from the shore."},
	"hideout": {"title": "Pirate Hideout", "biomes": ["kelp", "deep", "frozen", "volcanic", "abyss"], "w": 2.0,
		"names": ["Blackflag Cove", "Cutlass Key", "Smuggler's Shelf"],
		"desc": "A smugglers' camp under a black flag. Their cache is buried somewhere near the hut."},
	"shrine": {"title": "Moonstone Shrine", "biomes": ["deep", "frozen", "volcanic", "abyss"], "w": 2.0,
		"names": ["Moonstone Shrine", "Tidecaller's Ring", "The Still Stones"],
		"desc": "Standing stones around a glowing moonstone. Sailors leave fish here for the sea's favor."},
	# Ports are placed on top of ISLAND_COUNT ("extra"), from their own seed, so
	# adding them didn't reshuffle the islands of existing saves.
	"port": {"title": "Port City", "biomes": ["reef", "kelp", "deep", "frozen", "volcanic", "abyss"], "w": 0.0, "extra": true,
		"names": ["Port Royal", "Saltmarsh Harbor", "Gallows Bay", "Fort Brinewall"],
		"desc": "A walled harbor town. Its shore battery fires on any ship that comes close — silence it and the town will deal."},
}
const ISLAND_COOLDOWN := {"coconut": 180.0, "lagoon": 240.0, "shrine": 300.0}
const HIDEOUT_GUARD_CD := 150.0     # seconds before a hideout's guards return
const PORT_COUNT := 2               # Port Cities per save (extra islands)
const FORT_WAKE := 24.0             # units: a port's battery opens fire inside this range
const FORT_RANGE := 14.0            # units its shots fly (outranges an un-upgraded cannon)

# Treasure maps (shop "Maps" tab). A boss map marks a lair in one of `biomes`;
# sailing up to it raises `boss`, and sinking it pays `bounty` gold plus a
# `loot`-rarity fish. Shops stock maps up to their tier, so rarer maps are only
# sold in higher-star waters.
const BOSS_MAPS := {
	"reef_serpent": {"name": "Reef Serpent's Den", "boss": "reef_serpent", "rarity": "uncommon", "min_tier": 1, "price": 220,
		"biomes": ["reef", "kelp"], "bounty": [250, 400], "loot": "rare", "desc": "A young serpent coils in warm water. A good first hunt."},
	"sea_serpent": {"name": "Sea Serpent's Coil", "boss": "sea_serpent", "rarity": "rare", "min_tier": 2, "price": 550,
		"biomes": ["kelp", "deep"], "bounty": [600, 900], "loot": "epic", "desc": "It dives and strikes from below. Keep moving."},
	"kraken": {"name": "Kraken's Lair", "boss": "kraken", "rarity": "epic", "min_tier": 3, "price": 1000,
		"biomes": ["deep", "frozen"], "bounty": [1200, 1700], "loot": "epic", "desc": "Tentacles drag ships under. Bring your best ammo."},
	"leviathan": {"name": "Ember Leviathan's Vent", "boss": "leviathan", "rarity": "legendary", "min_tier": 4, "price": 1800,
		"biomes": ["volcanic", "frozen"], "bounty": [2200, 3000], "loot": "legendary", "desc": "A burning serpent the size of a galleon."},
	"elder_kraken": {"name": "Elder Kraken's Trench", "boss": "elder_kraken", "rarity": "legendary", "min_tier": 5, "price": 2600,
		"biomes": ["abyss"], "bounty": [3200, 4200], "loot": "legendary", "desc": "The oldest thing in the sea. Few captains return."},
}
const BOSS_MAP_ORDER := ["reef_serpent", "sea_serpent", "kraken", "leviathan", "elder_kraken"]
const MAX_BOSS_MAPS := 3            # boss maps carried at once
const LAIR_TRIGGER := 11.0          # units: sailing this close to a lair raises its boss
# Island charts: price by island kind, plus 10% per shop tier. A shop sells
# charts to the unfound islands nearest to it (ISLAND_CHART_STOCK of them).
const ISLAND_CHART_PRICE := {"coconut": 150, "lookout": 150, "castaway": 200, "lagoon": 260, "treasure": 320, "hideout": 360, "shrine": 420, "port": 300}
const ISLAND_CHART_STOCK := 2

# Shrine blessings (Game.buffs). Offering needs an uncommon or rarer fish.
const BLESSING_TIME := 180.0
const BLESSINGS := {
	"fortune": {"name": "Fortune", "desc": "rarer bites", "color": Color(0.5, 1.0, 0.6)},
	"fury": {"name": "Fury", "desc": "+30% cannon damage", "color": Color(1.0, 0.45, 0.35)},
	"tailwind": {"name": "Tailwind", "desc": "+20% top speed", "color": Color(0.6, 0.85, 1.0)},
}


func biome_at_sector(x: int, y: int) -> String:
	x = clampi(x, 0, GRID - 1)
	y = clampi(y, 0, GRID - 1)
	return BIOME_CODES[BIOME_GRID[y][x]]


func sector_of(pos: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floor(pos.x / SECTOR_PX)), 0, GRID - 1), clampi(int(floor(pos.y / SECTOR_PX)), 0, GRID - 1))


func biome_at(pos: Vector2) -> String:
	var s := sector_of(pos)
	return biome_at_sector(s.x, s.y)


func shop_by_id(id: String) -> Dictionary:
	for s in SHOPS:
		if s.id == id:
			return s
	return SHOPS[0]


func shop_pos(shop: Dictionary) -> Vector2:
	return shop.sector * SECTOR_PX


func upgrade_cost(id: String, level: int) -> int:
	return int(round(UPGRADES[id].cost * pow(1.8, level)))


## Highest level of `id` a fixed shop in `biome` sells (0 = not stocked there).
func shop_upgrade_cap(id: String, biome: String) -> int:
	var tier := int(BIOMES[biome].stars)
	var m := int(UPGRADES[id].max)
	if m == 1:
		return 1 if tier >= int(UPGRADE_MIN_TIER.get(id, 1)) else 0
	var cap := ceili(m * minf(tier + 1, 5) / 5.0)
	if id in BIOME_SPECIALTIES[biome]:
		cap += 1
	return mini(cap, m)


## Lowest star tier whose shops sell level `level + 1` of `id` (ignores specialties).
func upgrade_tier_needed(id: String, level: int) -> int:
	for tier in range(1, 6):
		var m := int(UPGRADES[id].max)
		if m == 1:
			if tier >= int(UPGRADE_MIN_TIER.get(id, 1)):
				return tier
		elif ceili(m * minf(tier + 1, 5) / 5.0) > level:
			return tier
	return 5


func rarity_index(r: String) -> int:
	return RARITIES.find(r)


## Species of `rarity` found in `biome`. Rod and loot rolls use rod species;
## traps pass trap = true for the crustaceans and bottom feeders.
func species_for(biome: String, rarity: String, trap := false) -> Array:
	var out := []
	for id in FISH:
		var f: Dictionary = FISH[id]
		if f.rarity == rarity and biome in f.biomes and bool(f.get("trap", false)) == trap:
			out.append(id)
	return out


## Rolls a species for a bite. luck shifts rarity weights upward (spec §4.3).
func roll_fish(biome: String, luck: float) -> String:
	if randf() < 0.06 / (1.0 + luck):
		return "old_boot"
	if randf() < 0.004 * (1.0 + luck * 2.0):
		return "golden_koi"
	var weights := []
	var total := 0.0
	for i in RARITIES.size():
		var w: float = RARITY_WEIGHTS[i] * pow(1.0 + luck, i)
		weights.append(w)
		total += w
	var r := randf() * total
	var tier := 0
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			tier = i
			break
	return _species_near_tier(biome, tier)


## Rolls what a trap pulls up. luck = trap luck + bait luck; no_junk for Glow Paste.
func roll_trap_catch(biome: String, luck: float, no_junk := false) -> String:
	if not no_junk and randf() < 0.12 / (1.0 + luck):
		return "tin_can"
	if randf() < 0.002 * (1.0 + luck * 2.0):
		return "blue_lobster"
	var weights := []
	var total := 0.0
	for i in RARITIES.size() - 1:   # legendary only via the Blue Lobster roll above
		var w: float = RARITY_WEIGHTS[i] * pow(1.0 + luck, i)
		weights.append(w)
		total += w
	var r := randf() * total
	var tier := 0
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			tier = i
			break
	return _species_near_tier(biome, tier, true)


## Picks a species of the given tier in the biome, falling back to the nearest
## lower tier, then higher tiers, when the biome has none at that tier.
func _species_near_tier(biome: String, tier: int, trap := false) -> String:
	var order := []
	for i in range(tier, -1, -1):
		order.append(i)
	for i in range(tier + 1, RARITIES.size()):
		order.append(i)
	for i in order:
		var list := species_for(biome, RARITIES[i], trap)
		if not list.is_empty():
			return list.pick_random()
	return "red_crab" if trap else "mackerel"


func roll_loot_fish(biome: String, rarity: String) -> String:
	var list := species_for(biome, rarity)
	if list.is_empty():
		for id in FISH:
			if FISH[id].rarity == rarity and not ("any" in FISH[id].biomes) and not FISH[id].get("trap", false):
				list.append(id)
	if list.is_empty():
		return _species_near_tier(biome, rarity_index(rarity))
	return list.pick_random()


## Size multiplier 0.7–1.5, skewed toward smaller catches (spec §4.4).
func roll_size() -> float:
	return snappedf(0.7 + 0.8 * pow(randf(), 1.8), 0.01)


## `biome` = the waters it came from, which set its damage tier (default: the
## species' own lowest-tier home waters).
func make_fish(id: String, size := -1.0, biome := "") -> Dictionary:
	var tier := tier_of(biome) if biome != "" else home_tier(id)
	return {"id": id, "size": size if size > 0.0 else roll_size(), "t": Game.play_time, "keep": false, "tier": tier}


func tier_of(biome: String) -> int:
	return int(BIOMES[biome].stars)


## Lowest star tier among a species' biomes (1 for "any").
func home_tier(id: String) -> int:
	var t := 5
	for b in FISH[id].biomes:
		t = mini(t, 1 if b == "any" else tier_of(b))
	return t


## Damage of an average-size `id` from waters of `tier`, before barrel upgrades.
func species_damage(id: String, tier: int) -> float:
	return float(FISH[id].pow) * TIER_DMG[clampi(tier, 1, 5)]


## Hit points of a `type` spawning in `biome` (see "toughness" in PIRATES).
## Armor is divided out so armored ships still take the same number of shots;
## impale (which ignores armor) just sinks them faster.
func enemy_hp(type: String, biome: String) -> float:
	var d: Dictionary = PIRATES[type]
	var t := tier_of(biome)
	return roundf(float(d.toughness) * TIER_DMG[t] * (1.0 + BARREL_PER_TIER * (t - 1)) / (1.0 - float(d.armor)))


## Shop demand modifier for fish origin (spec §6.2): native 0.8×, neighbor 1×, distant 1.2×.
func biome_relation(fish_id: String, shop_biome: String) -> float:
	var biomes: Array = FISH[fish_id].biomes
	if "any" in biomes:
		return 1.0
	if shop_biome in biomes:
		return 0.8
	for b in biomes:
		if shop_biome in BIOME_NEIGHBORS[b]:
			return 1.0
	return 1.2


func fish_damage(item: Dictionary) -> float:
	return species_damage(item.id, int(item.get("tier", home_tier(item.id)))) * float(item.size) * Game.dmg_mult()
