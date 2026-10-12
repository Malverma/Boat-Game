# BoatGame — Game Design Specification

**Platform:** Android (phone and tablet)
**Genre:** Top-down open-ocean fishing / light naval combat
**Orientation:** Landscape
**Status:** Draft v0.1 — 2026-10-09

---

## 1. Overview

The player captains a small boat on an open ocean. They sail between biomes and catch fish, then sell those fish for **Gold** at shops spread across the map. Gold buys boat upgrades. Pirate ships roam the sea and attack the player. The boat's cannon fires **fish** as ammunition, and each fish species has its own damage and special effect.

### 1.1 Core Loop

```
Sail → Fish → (Fight pirates using fish as ammo) → Reach shop → Sell fish → Buy upgrades → Sail further / into harder biomes
```

The main tension is that every fish is both **money** and **ammo**. The player has to choose between selling a rare fish and keeping it to fire at pirates.

### 1.2 Design Pillars

1. **Every catch is a decision:** sell it, or load it into the cannon.
2. **The ocean is alive:** currents, biomes and pirates make the route matter.
3. **Simple controls, deep systems:** one thumb steers and the other acts.

---

## 2. Controls & Input

### 2.1 Virtual Joystick
- An on-screen analog joystick steers the boat. Its direction sets the heading and its magnitude sets the throttle (0–100%).
- **Position:** bottom-right by default. A setting moves it to bottom-left (see §11).
- **Mode options (in settings):**
  - *Fixed*: the joystick base stays in one place.
  - *Floating*: the base appears wherever the thumb first touches inside the joystick zone.
- Dead zone: 10% of the radius (configurable 0–25%).
- The joystick zone covers the bottom ~40% of the screen height on its side.

### 2.2 Action Buttons
Action buttons sit on the side **opposite** the joystick and mirror automatically when the joystick side changes.

| Button | Function |
|---|---|
| **Cast / Reel** | Cast the fishing line. Tap or hold during the reel minigame. |
| **Load** | Tap to load the active ammo fish from the Hold into the cannon; the button then reads **LOADED**, and tapping the water fires it toward that point (see §7.3). Tap again to unload. **Hold for 1.5 s** to open the ammo swap screen, which pauses the game. |
| **Map** (top corner) | Pauses the game and opens the map with the pause menu beside it (Resume, Hold, Fishpedia, Settings, Save & Quit). It is the only top-corner button. |

### 2.3 Accessibility
- Adjustable UI scale (80–140%).
- Haptic feedback toggle.
- Hold-to-reel can be replaced with tap-to-reel.
- Colorblind-safe icons and labels for current direction and fish rarity.

---

## 3. World & Map

### 3.1 Structure
- One large, hand-authored ocean map, top-down 2D, roughly 8×8 "sectors."
- The camera follows the boat. The background is animated ocean water whose tint and detail change by biome.
- Fog of war: unexplored sectors stay hidden on the map until visited.
- Map edge: a storm wall that pushes the boat back.

### 3.2 Biomes
Each biome has its own fish table, current behavior, pirate threat level and visual style.

| Biome | Location | Difficulty | Visual | Current Behavior | Pirate Threat |
|---|---|---|---|---|---|
| **Shallows** | Starting area | ★ | Turquoise, sandbars, gulls | Calm, weak | None–Low |
| **Coral Reef** | Near start | ★★ | Bright coral, clear water | Gentle, swirling eddies | Low |
| **Kelp Forest** | Mid | ★★ | Dark green, kelp shadows | Moderate, steady | Medium |
| **Open Deep** | Mid–outer | ★★★ | Deep navy, swells | Strong, long streams | Medium–High |
| **Frozen Sea** | Far north | ★★★★ | Ice floes, pale blue | Strong, cold drift | High |
| **Volcanic Vents** | Far south | ★★★★ | Dark red glow, steam | Erratic bursts | High |
| **The Abyss** | Map edge / endgame | ★★★★★ | Near-black, bioluminescence | Chaotic, whirlpools | Very High (Pirate Lords) |

Some biomes need an upgrade before the boat can enter safely:
- Frozen Sea needs a **Reinforced Hull** or the boat takes ice damage over time.
- Volcanic Vents needs **Heat Plating** or the boat takes heat damage over time.
- The Abyss needs the **Leviathan Rod** (Tier 5, §6.3) to catch anything there.

### 3.3 Ocean Currents
- Currents are vector fields laid over the map. Each region has a direction and strength, shown with animated streak particles on the water.
- **Good current:** flowing in the boat's direction of travel. Gives up to +50% speed.
- **Bad current:** flowing against the boat. Gives up to −60% speed, and strong currents can push a stopped boat backward.
- **Cross current:** drifts the boat sideways, so the player has to steer to compensate.
- **Whirlpools** (Abyss and Volcanic): pull the boat toward the center. Escaping takes high throttle. If the boat reaches the center it takes damage and is thrown out in a random direction.
- **Dynamic currents:** some regions reverse direction on a timer (about every 3–5 minutes). The map shows a forecast once the **Navigator's Chart** upgrade is bought.
- Current direction and strength appear as a small compass arrow on the HUD.
- The engine upgrade line (§6) reduces how much bad currents slow the boat.

---

## 4. Fishing

### 4.1 Flow
1. The boat must be **slow** (throttle < 25%) to cast.
2. **Cast:** press Cast. A short power meter sets cast distance.
3. **Wait:** the bobber sits in the water for a random bite time (2–8 s, shortened by bait or rod upgrades). Fish shadows can be seen swimming nearby.
4. **Bite:** a vibration plus a "!" prompt. The player has a short window (about 0.75 s) to hook the fish.
5. **Reel minigame:** a tension bar.
   - Holding Reel raises tension and pulls the fish closer.
   - Each fish thrashes in its own pattern, which spikes tension.
   - If tension maxes out, the line snaps and the fish escapes.
   - If tension sits at zero too long, the fish slips the hook.
   - Catch progress fills while tension stays in the green zone.
6. **Catch:** the fish goes into the **Hold**. If the hold is full, the player must release a fish or discard the new one.

### 4.2 Fishing Spots
- Bubbling or swirling water marks a **hot spot** with better rarity odds, and these spots move over time.
- Pirates are drawn to hot spots in higher-threat biomes.

### 4.3 Rarity Tiers

| Tier | Color | Base Catch Weight |
|---|---|---|
| Common | Gray | 60% |
| Uncommon | Green | 25% |
| Rare | Blue | 10% |
| Epic | Purple | 4% |
| Legendary | Gold | 1% |

The rod's Rarity Bonus (§6.3), bait and hot spots shift these weights upward.

### 4.4 Fish Size
Each catch rolls a size between 0.7× and 1.5× of its species base. Size scales both **sell price** and **cannon damage**.

---

## 5. Fish Catalog

Each fish has a sell price and a cannon profile. The prices and numbers below are starting values to be tuned.

| Fish | Biome(s) | Rarity | Base Gold | Cannon Dmg | Cannon Effect |
|---|---|---|---|---|---|
| Sardine | Shallows, Reef | Common | 5 | 8 | **Scatter**: fires 3 small projectiles in a cone |
| Mackerel | Shallows, Kelp | Common | 8 | 12 | None (reliable standard shot) |
| Clownfish | Reef | Uncommon | 20 | 10 | **Dazzle**: target's accuracy −40% for 4 s |
| Pufferfish | Reef | Uncommon | 30 | 15 | **Spike Burst**: explodes into spines, area damage (small radius) |
| Electric Eel | Kelp | Rare | 60 | 18 | **Shock**: stuns target 2 s, chains to 1 nearby ship |
| Kelp Bass | Kelp | Common | 12 | 14 | **Entangle**: target speed −50% for 3 s |
| Swordfish | Open Deep | Rare | 90 | 40 | **Pierce**: passes through and hits up to 3 ships in a line |
| Tuna | Open Deep | Uncommon | 45 | 30 | **Heavy**: knockback |
| Hammerhead Shark | Open Deep | Epic | 200 | 55 | **Bleed**: 5 damage/s for 6 s |
| Ice Cod | Frozen | Uncommon | 50 | 20 | **Freeze**: target speed −80% for 3 s |
| Narwhal-fish | Frozen | Epic | 260 | 50 | **Impale**: high damage that ignores armor |
| Lava Eel | Volcanic | Rare | 110 | 25 | **Burn**: 8 damage/s for 5 s, spreads to adjacent ships |
| Magma Grouper | Volcanic | Epic | 240 | 45 | **Explosive**: large-radius AOE blast |
| Anglerfish | Abyss | Epic | 300 | 35 | **Lure**: pulls nearby enemies toward impact point |
| Giant Squid | Abyss | Legendary | 800 | 60 | **Ink Cloud**: blinds all enemies in area 5 s; on hit, 2 tentacle slams |
| Golden Koi | Any (very rare) | Legendary | 1000 | 5 | **Midas**: if it kills the target, triples Gold from the wreck |
| Old Boot | Any | Junk | 0 | 3 | **Bonk**: none (a joke catch, still usable as ammo) |

### 5.1 Cannon Effect Rules
- Damage = `species base damage × size multiplier × cannon upgrade multiplier`.
- Status effects (Burn, Bleed, Freeze, Shock, Entangle) do not stack with themselves. Reapplying one refreshes its duration. Different effects can be active together.
- **Combo interactions** (stretch goal):
  - Freeze + Heavy (Tuna) → **Shatter**: ×2 damage
  - Burn + Explosive → **Inferno**: larger AOE
  - Entangle + Pierce → guaranteed critical

---

## 6. Shops & Economy

### 6.1 Shops
- Shops appear at fixed points across the map as floating docks, trading outposts or island ports. There are 1–2 per biome.
- **Periodic / roaming merchants:** in addition to fixed shops, merchant vessels appear at random for a limited time (about 3 minutes). They sell rare stock and pay bonus prices for certain fish.
- Shops are **safe zones**: pirates cannot enter the dock radius.
- Docking starts when the boat stops inside the dock radius.

### 6.2 Currency: Gold
- The only currency, earned by **selling fish** and **looting pirate wrecks**.
- Sell price = `base gold × size multiplier × shop demand modifier`.
- **Shop demand:** each shop has a rotating "wanted" list. Wanted fish sell for 1.5–2×. Fish native to the shop's own biome sell for 0.8×, and fish from distant biomes sell for 1.2×. This rewards the player for carrying catches between biomes.
- Gold is kept on death; see §9 for what is lost.

### 6.3 Fishing Rods (5 Tiers)

Rods are bought outright at shops. Each tier replaces the previous rod; there are no per-rod levels. Higher-tier rods are only stocked at shops in or near the biome they are built for (Tier 1–2 everywhere, Tier 3 from Kelp Forest outward, Tier 4 in Frozen Sea / Volcanic Vents, Tier 5 only at the Abyss-edge outpost).

#### Rod Stats

| Tier | Rod | Cost (Gold) | Built For | Rod Power | Reel Speed | Green Zone | Max Tension | Cast Range | Bite Time | Rarity Bonus |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | **Driftwood Rod** | Starter (free) | Shallows, Coral Reef | 1 | 1.00× | 30% | 100 | 6 m | 2–8 s | +0% |
| 2 | **Bamboo Rod** | 400 | Kelp Forest | 2 | 1.15× | 34% | 125 | 7.5 m | −10% | +5% |
| 3 | **Mariner's Fiberglass Rod** | 1,800 | Open Deep | 3 | 1.30× | 38% | 155 | 9 m | −20% | +10% |
| 4 | **Stormforged Carbon Rod** | 6,000 | Frozen Sea, Volcanic Vents | 4 | 1.50× | 42% | 190 | 10.5 m | −30% | +18% |
| 5 | **Leviathan Rod** | 18,000 | The Abyss | 5 | 1.75× | 46% | 240 | 12 m | −40% | +30% |

- **Reel Speed:** how fast catch progress fills while tension is in the green zone.
- **Green Zone:** width of the safe band on the tension bar.
- **Max Tension:** how much strain the line takes before it snaps. Thrashing spikes are measured against this.
- **Bite Time:** reduction applied to the base 2–8 s wait.
- **Rarity Bonus:** shifts catch weights from Common toward higher tiers (see §4.3). For example, +30% moves 30% of the Common weight up into the other tiers proportionally.

#### Rod Power vs. Fish Weight Class

Every fish has a weight class from 1 to 5 (roughly: Common 1, Uncommon 2, Rare 3, Epic 4, Legendary 5, with exceptions such as Golden Koi at 2 and Giant Squid at 5).

- If the fish's class is **at or below** the Rod Power, the reel minigame plays normally.
- For each class **above** the Rod Power, tension rises 50% faster and thrash spikes are 50% bigger. The catch is possible but hard, so a skilled player can land a big fish early.
- **Abyss exception:** Abyss fish cannot be hooked at all without the Leviathan Rod (it replaces the old Deep-Sea Line upgrade).

#### Rod Perks

Each rod adds one perk on top of its stats. Perks carry forward: a higher-tier rod keeps every earlier perk.

| Tier | Perk | Effect |
|---|---|---|
| 1 | — | No perk. |
| 2 | **Steady Grip** | Thrash spikes are 15% smaller. |
| 3 | **Quick Hook** | The hook-set window after a bite grows from 0.75 s to 1.0 s. |
| 4 | **Weatherproof** | Bite time and tension aren't affected by Frozen Sea cold or Volcanic heat bursts. |
| 5 | **Second Wind** | Once per catch, a line that would snap drops back to 60% tension instead. Legendary catch weight is doubled. |

#### Progression Pacing (target)
- Tier 2 after the first 2–3 shop trips (~10 minutes).
- Tier 3 around the time the player first enters the Open Deep (~45 minutes).
- Tier 4 at roughly the midpoint (~2–3 hours), alongside the hull unlocks.
- Tier 5 as an endgame goal, after the Pirate Lord is in reach.

### 6.4 Core Boat Upgrades (5 Lines)

These five upgrade lines are on sale at every fixed shop. Each has 5 levels, bought in order. Roaming merchants sell the same upgrades at 15% off.

#### 1. Hull Plating (survivability)

| Level | Max HP | Bonus | Cost |
|---|---|---|---|
| Base | 100 | — | — |
| 1 | 125 | — | 200 |
| 2 | 150 | — | 400 |
| 3 | 180 | Ramming damage taken −25% | 800 |
| 4 | 215 | — | 1,600 |
| 5 | 250 | All damage taken −10% | 3,200 |

#### 2. Engine (speed & currents)

| Level | Top Speed | Bad-Current Slowdown | Turn Rate | Cost |
|---|---|---|---|---|
| Base | 5.0 u/s | −60% | 90°/s | — |
| 1 | 5.5 u/s | −54% | 95°/s | 250 |
| 2 | 6.0 u/s | −48% | 100°/s | 500 |
| 3 | 6.6 u/s | −40% | 110°/s | 1,000 |
| 4 | 7.2 u/s | −32% | 120°/s | 2,000 |
| 5 | 8.0 u/s | −20%; can escape whirlpools at 75% throttle | 130°/s | 4,000 |

Good-current speed bonus (+50%) is unchanged at every level.

#### 3. Cargo Hold (capacity)

| Level | Hold Capacity | Bonus | Cost |
|---|---|---|---|
| Base | 10 | — | — |
| 1 | 14 | — | 300 |
| 2 | 18 | — | 600 |
| 3 | 24 | — | 1,200 |
| 4 | 32 | — | 2,400 |
| 5 | 40 | Fish lose value 50% slower (stacks with Ice Box) | 4,800 |

#### 4. Cannon Barrel (damage & range)

| Level | Damage Multiplier | Range | Bonus | Cost |
|---|---|---|---|---|
| Base | 1.00× | 8 u | — | — |
| 1 | 1.15× | 9 u | — | 250 |
| 2 | 1.30× | 10 u | — | 500 |
| 3 | 1.50× | 11 u | Status effects last +1 s | 1,000 |
| 4 | 1.75× | 12 u | — | 2,000 |
| 5 | 2.00× | 13 u | 10% chance a shot doesn't use up its fish | 4,000 |

#### 5. Loader (reload & ammo slots)

| Level | Reload Time | Ammo Rack Slots | Cost |
|---|---|---|---|
| Base | 3.0 s | 1 | — |
| 1 | 2.6 s | 2 | 200 |
| 2 | 2.3 s | 2 | 400 |
| 3 | 2.0 s | 3 | 800 |
| 4 | 1.7 s | 3 | 1,600 |
| 5 | 1.4 s | 4 | 3,200 |

The heavy-fish reload penalty (+1 s, see §7.2) still applies on top.

#### Cost Summary

| Line | Total to Max |
|---|---|
| Hull Plating | 6,200 |
| Engine | 7,750 |
| Cargo Hold | 9,300 |
| Cannon Barrel | 7,750 |
| Loader | 6,200 |
| **All five lines** | **37,200** |
| All rods (Tiers 2–5) | 26,200 |

These are first-pass numbers. Balancing goal: a mid-game trip of a full hold (~18–24 fish) plus one pirate wreck should earn 800–1,500 Gold, so the next upgrade is never more than 2–3 trips away.

### 6.5 Other Purchases

These sit outside the five core lines:

| Item | Effect | Cost | Type |
|---|---|---|---|
| Reinforced Hull | Unlocks the Frozen Sea (ice immunity) | 2,500 | One-time |
| Heat Plating | Unlocks the Volcanic Vents (heat immunity) | 2,500 | One-time |
| Ice Box | Fish don't lose value over time (see §6.6) | 1,200 | One-time |
| Navigator's Chart | Shows current forecasts and hot spots on the map | 900 | One-time |
| Spyglass | Pirate detection radius +50% | 700 | One-time |
| Bait | Bite time −25% and Rarity Bonus +5% for the next 5 casts | 30 | Consumable |
| Repair | Restores HP | 1 Gold per HP | Service |

The old Rudder, Line, Deep-Sea Line, Ammo Rack and Swivel Mount upgrades are removed. Their effects were folded into the Engine, the rods and the Loader. Swivel Mount is gone for good, since tap-to-fire shoots in any direction.

### 6.6 Fish Freshness (optional system)
- Without the Ice Box, a fish loses 1% of its value per minute after being caught, down to a floor of 50%.
- This pushes the player to sell regularly and makes shop routes matter.

---

## 7. Combat

### 7.1 Player Ship Stats
| Stat | Base |
|---|---|
| HP | 100 |
| Top speed | 5 units/s |
| Turn rate | 90°/s |
| Cannon reload | 3.0 s |
| Hold capacity | 10 fish |

### 7.2 Cannon & Ammo
- The cannon **must be loaded with a fish from the Hold** to fire. Firing **uses up** that fish.
- **Ammo Rack slots** (1–4, from the Loader upgrade, §6.4): the player assigns fish species to quick-select slots. If the selected slot runs out, the next slot is used automatically.
- With no fish in the hold, the cannon cannot fire. A "No Ammo" indicator flashes.
- Reload time applies between shots. Some heavy fish (Magma Grouper, Giant Squid) add +1 s.

### 7.3 Aiming
- **Tap to fire:** press **Load** to put the active ammo fish in the cannon. Then tap anywhere on the water (outside the buttons and joystick) to fire it toward that point, in any direction.
- The loaded fish shows on the Load button and at the cannon's muzzle, with a "Tap to fire" hint.
- Reload time starts after each shot, and the cannon can't be loaded again until it finishes.
- Keyboard (testing): F loads, then fires at the nearest pirate in range (with lead), or straight ahead if there is none.
- Projectiles arc and are slower than real cannonballs, so leading a moving target matters.
- Range: 8 units at base, increased by Cannon Barrel upgrades (§6.4).

### 7.4 Pirate Ships

| Pirate Type | Appears In | HP | Behavior | Loot |
|---|---|---|---|---|
| **Dinghy Raider** | Reef, Kelp | 30 | Fast; rams the player | 10–25 Gold |
| **Sloop** | Kelp, Open Deep | 80 | Circles and fires single cannonballs | 30–60 Gold, chance of fish |
| **Brigantine** | Open Deep, Frozen, Volcanic | 180 | Broadside volleys of 3 shots | 80–150 Gold, rare fish |
| **Ironclad** | Frozen, Volcanic | 300 | Armored (−30% damage taken); slow | 150–250 Gold |
| **Ghost Ship** | Abyss | 250 | Turns invisible at intervals | 200–400 Gold, Epic fish |
| **Pirate Lord** (boss) | Abyss, special events | 1000 | Multi-phase; summons Dinghies | 1000+ Gold, Legendary fish, unique cosmetic |

### 7.5 Pirate Spawning
- Spawn checks run every ~45 s while the player is outside safe zones.
- Spawn chance depends on biome threat level, time since the last encounter, and the value of the player's cargo. Richer cargo draws more pirates.
- Pirates spawn off-screen and an edge-of-screen indicator warns the player.
- Pirates give up the chase if the player outruns them past a leash distance (about 25 units) or enters a shop safe zone.
- A grace period of about 90 s follows each encounter before the next spawn check can succeed.

### 7.6 Wrecks & Loot
- A sunk pirate ship leaves a floating wreck for 20 s. Sailing over it collects the Gold and any fish.
- Looted fish go into the hold, which supplies more ammo.

---

## 8. HUD & UI

### 8.1 In-Game HUD
```
┌──────────────────────────────────────────────────────────┐
│ [HP bar]   [Gold: 1,240]          [Current ➚]       [Map] │
│                                                          │
│                                                          │
│                   (boat, ocean, fish)                    │
│                                                          │
│                                                          │
│                                                          │
│                                                          │
│  (Load) (Cast)                              ( Joystick ) │
└──────────────────────────────────────────────────────────┘
```
(Shown with the joystick on the right. With the left setting, the whole bottom row mirrors.)

- **Off-screen indicators:** arrows for pirates (red), plus shops (gold) and roaming merchants (purple) only when they're within 50 m.
- **Minimap:** optional, in a top corner.
- **Biome name banner:** fades in when entering a new biome.

### 8.2 Screens
- Main Menu: Continue, New Game, Settings, Fishpedia
- Shop: tabs for Sell, Upgrades, Repair and Supplies
- Hold / Inventory: sort by value, rarity or ammo damage. Fish can be marked "Keep for ammo" to block accidental selling.
- **Fishpedia:** a collection log of every species caught, with biggest size, sell price and cannon effect.
- Map: full map with fog of war, shops, discovered hot spots and the current overlay
- Map + Pause menu (one screen, opened from the Map button): Resume, Hold, Fishpedia, Settings, Save & Quit

---

## 9. Progression, Failure & Saving

### 9.1 Progression
- Progress is gated by upgrades (hull and line unlocks) and by difficulty (pirate threat).
- Optional milestones: complete the Fishpedia per biome and defeat the Pirate Lord.

### 9.2 Death
- When HP reaches 0 the boat sinks.
- The player **respawns at the last visited shop**.
- **Penalty:** every fish in the hold is lost, plus 10% of carried Gold. Upgrades are never lost.

### 9.3 Saving
- Autosaves on docking at a shop, on entering a new biome, and when the app is backgrounded (`onPause`).
- One save slot, with cloud save as a stretch goal (Google Play Games Services).

---

## 10. Audio & Visual Style

- **Art:** 2D top-down pixel art, with gentle wave animation and biome-specific tints and particles.
- **Boat:** visible upgrades change the sprite (bigger hull, cannon model, sails).
- **Fish projectiles:** each fish flies as its own sprite, with impact VFX matching its effect (ice shards, flames, ink cloud, lightning).
- **Audio:** ambient ocean per biome, a seagull and wind layer, a combat music layer that fades in when pirates appear, a shop jingle, and a unique impact sound per fish.

---

## 11. Settings

| Setting | Options | Default |
|---|---|---|
| Joystick side | Right / Left | Right |
| Joystick mode | Fixed / Floating | Floating |
| Joystick dead zone | 0–25% | 10% |
| Reel input | Hold / Tap | Hold |
| UI scale | 80–140% | 100% |
| Haptics | On / Off | On |
| Music volume | 0–100 | 70 |
| SFX volume | 0–100 | 80 |
| Show current overlay | On / Off | On |
| Language | — | System |

Changing **Joystick side** mirrors all action buttons and the ammo indicator to the opposite side immediately, without a restart.

---

## 12. Technical Requirements

| Item | Requirement |
|---|---|
| Engine | Godot 4.x (recommended) or Unity. Final choice TBD. |
| Language | GDScript / C# (match the engine) |
| Min Android | API 26 (Android 8.0) |
| Target Android | Latest stable API level required by Google Play |
| Target FPS | 60 fps on mid-range devices; 30 fps floor on low-end |
| Resolution | Scales to 16:9 through 21:9; safe-area aware (notches, gesture bars) |
| Input | Multi-touch (minimum 2 simultaneous touches) |
| Storage | Local save (JSON or binary) in app-private storage |
| Size | < 150 MB install |
| Offline | Fully playable offline |
| Monetization | TBD (premium, or free with cosmetic IAP only; no pay-to-win ammo) |

### 12.1 Key Systems / Modules
- `BoatController`: movement, joystick input, current forces
- `CurrentField`: per-region current vectors, timed reversals, whirlpools
- `FishingSystem`: casting, bite timing, tension minigame
- `FishDatabase`: species data (biome, rarity, price, cannon profile), stored as data/resources
- `Inventory`: hold, ammo rack slots, freshness
- `CannonSystem`: loading, aiming, projectile spawn, effect application
- `StatusEffects`: burn, bleed, freeze, shock, entangle, etc.
- `PirateAI`: state machine (Patrol → Chase → Attack → Flee/Leash)
- `SpawnDirector`: pirate and roaming-merchant spawning
- `ShopSystem`: buy/sell, demand modifiers, upgrades
- `SaveSystem`
- `UI`: HUD, menus, mirrored layout support

---

## 13. Scope & Milestones

| Milestone | Contents |
|---|---|
| **M1: Prototype** | Boat movement + joystick (both sides), ocean background, basic currents, one biome, fishing minigame, 3 fish |
| **M2: Economy** | Hold, one shop, selling, 5 upgrades, saving |
| **M3: Combat** | Cannon with fish ammo, 5 fish effects, Dinghy + Sloop pirates, wrecks/loot |
| **M4: World** | All 7 biomes, full fish catalog, roaming merchants, map + fog of war |
| **M5: Content & Polish** | All pirate types, Pirate Lord boss, Fishpedia, audio, VFX, settings, balancing |
| **M6: Release** | Performance pass, device testing, Play Store build |

---

## 14. Open Questions

1. Final engine: Godot or Unity?
2. Should time of day or weather affect fish spawns and pirate activity?
3. Monetization model?
4. Should the cannon have a "basic shot" fallback when the hold is empty, or stay strictly fish-only? (The current spec says fish-only.)
5. Does Fish Freshness (§6.6) stay in, or is it too punishing?
6. Should fixed shops ever close or move, or are only the roaming merchants periodic?
