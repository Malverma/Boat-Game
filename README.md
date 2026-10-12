# BoatGame

Top-down open-ocean fishing and light naval combat, built in **Godot 4.7** (GL Compatibility renderer for wide Android support). The design is in `spec.md`.

Open the folder in Godot 4.7+ and press Play. Everything currently renders with placeholder vector art. Drop sprites into `assets/` (see below) and they replace the placeholders automatically, with no code changes.

## Desktop controls (for testing)

| Action | Keys |
|---|---|
| Steer / throttle | WASD or arrow keys (or drag the on-screen joystick with the mouse) |
| Cast / hook / reel (hold) | Space or E |
| Load cannon / fire | Tap **LOAD**, then click (tap) the water to fire that way. F or Enter loads, then fires at the auto-aim target |
| Swap ammo | Hold **LOAD** for 1.5 s (pauses), or R. Q cycles ammo slots |
| Map + pause menu / Hold | M, Esc or P (or the **Map** button) / I or Tab |
| Enter shop / haul trap | C (or the **Enter Shop** / **Haul Trap** button when close) |
| Deploy a trap | T (or the **Trap** button) |
| Debug: spawn pirates / +500 gold / summon the Kraken | F9 / F10 / F8 (debug builds only) |

The mouse emulates touch, so the on-screen buttons and joystick also work on desktop.

## Code layout

```
scripts/autoload/  data.gd (all tuning data), game.gd (state, stats, save/settings), art.gd, sfx.gd
scripts/world/     world.gd (root/glue), current_field.gd, ocean.gd, fishing.gd, combat.gd, spawn_director.gd
scripts/entities/  ship.gd, boat.gd, pirate.gd, projectile.gd, status_effects.gd, shop.gd, wreck.gd, hotspot.gd, island.gd, fx.gd
scripts/ui/        hud.gd, joystick.gd, touch_button.gd, overlay.gd + every menu screen (map_ui.gd is also the pause menu)
shaders/ocean.gdshader
```

All numbers from the spec (fish, pirates, biomes, upgrades, shops) live in `scripts/autoload/data.gd`. 1 world unit = 32 px.

## Art hooks

Every visual first calls `Art.tex(key)`, which loads `res://assets/sprites/<key>.png` (or `.webp`) when the file exists and falls back to the placeholder drawing otherwise. Author sprites **facing right (+X)** and centered. Each one is scaled to the width listed below with its aspect ratio kept, so any pixel resolution works.

| Key(s) | Drawn width |
|---|---|
| `boat`, `boat_cannon` | 83 px, 29 px |
| `pirate_dinghy`, `pirate_sloop`, `pirate_brigantine`, `pirate_ironclad`, `pirate_ghost`, `pirate_lord` | ≈ ship radius × 2.8 (63–161 px) |
| `pirate_shark`, `pirate_kraken` (temp art from Penpot) | 87 px, 230 px (radius × `art_scale` in `Data.PIRATES`) |
| `kraken_tentacle` (temp art; base on the left, tip pointing right) | 109 px |
| `fish_<id>`: sardine, mackerel, kelp_bass, clownfish, pufferfish, tuna, ice_cod, electric_eel, swordfish, lava_eel, hammerhead, narwhal_fish, magma_grouper, anglerfish, giant_squid, golden_koi, old_boot, plus trap catches: shrimp, red_crab, oyster, sea_cucumber, flounder, rock_crab, scallop, catfish, sculpin, fire_starfish, decorator_crab, lobster, sea_star, nautilus, blobfish, blue_lobster, tin_can | varies (used for icons, projectiles, catch card). Cut from `assets/fish.png` into `assets/sprites/fish_sheet/` (also searched); these are drawn **diagonally, head up-left**, and `Art.draw_fish` turns them to face their heading |
| `trap_<kind>`: crab_pot, lobster_cage (deployed buoy, top-down; also the shop icon) · `bait_<id>`: worm, meal, chum, glow (trap bait icons, cut from `assets/fish.png`) | 1.2 units (buoy) |
| `fish_shadow`, `bobber`, `cannonball` | 38, 16, 14 px |
| `shop`, `merchant`, `wreck`, `hotspot`, `whirlpool` | 128, 96, 64, 192, 358 px |
| `island_<kind>` (treasure, castaway, coconut, lookout, lagoon, hideout, shrine), fallback `island` | land radius × 2.2 (≈150–235 px) |
| `fx_splash`, `fx_boom`, `fx_spines`, `fx_ice`, `fx_ink`, `fx_lightning`, `fx_sparkle`, `fx_slam` | effect radius × 2, fades out |
| `ui_btn_load`, `ui_btn_cast`, `ui_btn_map` | fills the button rect |
| `ui_joystick_base`, `ui_joystick_knob` | 170 px, 71 px |
| `title_background`, `title_logo` | cover screen / natural size |

- **Menu theme:** if `res://assets/ui/theme.tres` exists, it replaces the generated theme (`scripts/ui/ui_kit.gd`).
- **Water:** each biome's tint comes from the `deep`/`light` colors in `Data.BIOMES`, rendered by `shaders/ocean.gdshader`.
- **Boat upgrades:** the placeholder boat already shows upgrades (plating, crates, sail size). A sprite set could switch keys by `Game.lvl(...)` in `boat.gd::_draw`.

## Audio hooks

`Sfx.play(key)` loads `res://assets/audio/sfx/<key>.(ogg|wav|mp3)`. Missing files are skipped.

- **SFX keys:** `cannon`, `hit_<fish_id>`, `hit_player`, `splash`, `pirate_fire`, `ram`, `ship_sink`, `player_sink`, `loot`, `cast`, `bite`, `hook`, `catch`, `line_snap`, `no_ammo`, `load`, `shark_lunge`, `shark_bite`, `kraken_roar`, `tentacle_slam`, `creature_die`, `sell`, `buy`, `upgrade`, `repair`, `shop_jingle`
- **Music:** `res://assets/audio/music/ambient_<biome>` (one per biome) and `combat` (faded in while pirates are around)
