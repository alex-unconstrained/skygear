# Skygear — Visual Asset Specification v1
## Cinderia-style restyle · Steampunk airship · Asset generation brief for Codex 5.6 Sol

**What this document is.** A complete, self-contained brief for generating every image asset Skygear needs to move from its current look to a Cinderia-style presentation: high three-quarter perspective camera, dark painted world, chibi-proportioned 2D sprite characters with heavy outlines, saturated VFX popping off a dark base. The engine is **canvas 2D — no WebGL** — using billboarded sprites on a projected ground plane with a painter's-algorithm sort. Every constraint in §2 exists because of that renderer. Do not deviate from §2 even if an individual asset would look better otherwise.

**How to use it (instructions for Codex).**
1. Read §1 (style bible) and §2 (technical constraints) in full before generating anything.
2. Generate assets one at a time in manifest order (§4). One asset per image — never composite multiple assets into one canvas.
3. Prepend the **Master Style Block** (§1.4) to every generation prompt, then append the asset's own prompt from the manifest.
4. After each asset, run the QA checklist (§5). Regenerate on any failure before moving on.
5. Deliver files with the exact filenames and dimensions in the manifest, transparent-background PNG unless the manifest says otherwise.

---

## §1 · Style Bible

### 1.1 The one-line target
**"Cinderia's rendering language wearing Skygear's steampunk clothes."** Dark fairytale action-roguelite presentation — but the fairytale forest is replaced by the weather deck of a brass-and-timber airship at storm-dusk, high above a cloud sea.

### 1.2 Art direction pillars

- **Dark base, bright pops.** The world sits very dark — deep indigo-charcoal shadows, heavy ambient occlusion feel, muted mid-tones. Anything that matters gameplay-wise (VFX, telegraphs, pickups, rim-light on characters) is rendered saturated and bright so it detonates off the darkness. If an asset looks correctly exposed on a white background, it is too bright; it must look correct against `#14121B`.
- **Painted, not photographic.** Flat colour fields with visible painterly edges and linework. No photo textures, no gradients pretending to be photoreal metal. Brass reads as brass through 2–3 flat tones plus a hard specular stripe, not through reflection mapping.
- **Thick dark outlines.** Every character and prop carries a bold, near-black outline (`#0D0B12`), roughly 2–3% of the asset's height in weight. Outlines are slightly irregular — inked, not vectored.
- **Chibi-adjacent character proportions.** Characters are roughly 2.5–3 heads tall: oversized heads and hands, compact bodies, big readable silhouettes. Menace comes from shape and pose, not realism.
- **Steampunk vocabulary, storm-dusk mood.** Brass, riveted iron, oxidised copper, oiled timber, leather, rope, pressure gauges, gear trains, steam. Time of day is fixed at **storm-dusk**: a bruised violet-and-teal sky, moonlight breaking through cloud, warm lantern light on deck. *(Decision made so the Cinderia dark-base contrast works on an open-air deck — see §6 assumptions.)*
- **Two light sources, always the same two.** Cool moonlight from upper-left (steel-blue rim light), warm lantern/furnace glow from lower-right (amber fill). Every character and prop is lit this way, no exceptions — this is what makes a hundred separately generated assets sit in one world.

### 1.3 Palette

Base / environment:

| Role | Hex | Notes |
|---|---|---|
| Near-black outline & deepest shadow | `#0D0B12` | universal outline colour |
| Dark base / vignette | `#14121B` | the tone every asset must read against |
| Deck timber dark | `#2A2027` | plank shadow tone (code-drawn ground) |
| Deck timber mid | `#3D2E30` | plank base tone |
| Deck timber light | `#54413C` | plank lit edge |
| Storm sky deep | `#1B1830` | zenith |
| Storm sky mid | `#2E2A4E` | cloud mass |
| Moonbreak | `#8FA6C9` | cool highlight in sky and rim light |

Materials:

| Role | Hex | Notes |
|---|---|---|
| Brass mid | `#B0813F` | primary metal |
| Brass highlight | `#E8C376` | hard specular stripe only |
| Oxidised copper | `#3E8F83` | verdigris accents, pipes |
| Iron / gunmetal | `#4A4A55` | armour, cannon, automatons |
| Leather / rope | `#6E4A2F` | straps, rigging |
| Lantern warm | `#FFB347` | warm fill light, flame cores |

Gameplay / VFX (the "pop" colours — use nowhere else):

| Role | Hex | Notes |
|---|---|---|
| Player skill / friendly telegraph | `#37F0C8` | aether-teal |
| Enemy telegraph / danger rune | `#FF3D2E` | with `#FF8C1A` inner glow |
| Fire & explosion VFX | `#FF7A2F` | core `#FFE08A` |
| Electric / tesla VFX | `#7ADCFF` | core `#FFFFFF` |
| Crit number yellow | `#FFD52E` | code-rendered text, listed for reference |
| Pickup / loot glow | `#C77DFF` | relic-purple |

### 1.4 Master Style Block — prepend to every generation prompt

> Dark fairytale steampunk game asset, hand-painted 2D style, flat colour fields with painterly edges, bold near-black ink outlines (#0D0B12) about 2–3% of asset height, chibi-adjacent proportions where characters appear, billboard pose lock for characters and props: upright and nearly face-on, viewed only subtly from above at roughly 10–15 degrees above horizontal, two-source lighting: cool steel-blue moonlight rim from upper-left (#8FA6C9) and warm amber lantern glow from lower-right (#FFB347), muted dark base tones that read against a #14121B background, saturated accents only where specified, no photorealism, no soft airbrushed gradients, no baked-in drop shadow, no ground plane or contact shadow under the subject, fully transparent background, single subject centered with 8% transparent padding on all sides.

---

## §2 · Technical Constraints (renderer-driven — non-negotiable)

The engine projects a flat ground plane through a fixed-yaw pinhole camera (pitch ≈ 0.72 rad / ~41°, no rotation, no zoom). Entities are 2D billboard sprites scaled by depth and sorted far-to-near. Canvas 2D can do **affine** transforms only — it can uniformly/non-uniformly scale, rotate, and translate an image, but it cannot perspective-warp one. These rules follow:

1. **Billboard presentation: upright, subtly elevated.** Characters and prop billboards are painted nearly face-on, viewed only subtly from above at roughly 10–15° above horizontal. Avoid crown-heavy top views and strong shoulder/body foreshortening. The engine projects the deck separately at ~41°; literally baking that pitch into a billboard makes the subject read pitched over. Screen-space layers stay flat and ground circles remain dead top-down.
2. **Two facings per character, mirrored in code.** Each character gets a **front-quarter** view (facing toward camera-lower-LEFT) and a **back-quarter** view (facing away, toward upper-LEFT). The engine mirrors horizontally for right-facing. Consequence: **no text, and no strongly asymmetric features** (eyepatch, shoulder cannon) unless the asset owner accepts them flipping sides.
3. **No sprite sheets, no animation frames.** Image models can't hold frame-to-frame consistency, and the engine animates in code (bob, tilt, squash-and-stretch, flash). Each character = static poses only: **idle** (both facings) and **attack** (front-quarter only). Three images per character, total.
4. **Feet on the anchor line.** The character's ground contact point sits at bottom-center of the canvas (above the 8% padding). The engine positions and shadows sprites from that anchor. No baked contact shadow — the engine draws a soft ellipse shadow itself.
5. **Ground-flat art must be circular.** Anything lying flat on the deck (telegraph runes, decals, stains) is authored as a **perfect circle viewed dead top-down** on transparency. The engine squashes circle → ellipse (affine-safe) to lay it on the projected ground. Never author these pre-distorted, and never author square/rectangular ground art — a rectangle can't be perspective-mapped in canvas 2D.
6. **The deck itself is code-drawn.** Planks are flat-filled projected quads (§1.3 timber palette + `#0D0B12` seam lines). **No ground texture images are needed or wanted.** Only circular decals (§4.5) go on top of it.
7. **Backgrounds are flat screen-space layers.** Sky, cloud layers, and the gas-bag envelope are wide screen-space images translated for parallax — paint them as flat backdrops, no baked perspective toward a vanishing point.
8. **Sizes are render targets, engine downsamples.** Generate at listed sizes; crisp downscaling is fine, upscaling is not. PNG-24 with alpha. No semi-transparent halo pixels around outlines (matte against transparency, not white).
9. **Damage numbers, cones, and beam telegraphs are NOT image assets.** Numbers are code-rendered text (`#FFD52E`, `#0D0B12` outline, `!!` on crits); cone/line telegraphs are code-drawn projected wedges using the telegraph palette. Do not generate images for them.

### 2.1 File naming

`assets/{category}/{name}_{variant}.png` — lowercase snake_case, categories: `heroes/`, `enemies/`, `props/`, `env/`, `ground/`, `fx/`, `ui/`. Exact filenames are given per asset in §4.

---

## §3 · Asset Count Summary

| Category | Assets | Images |
|---|---|---|
| Hero (1 for the one-shot) | 1 character | 3 |
| Enemies | 5 archetypes + 1 boss | 14 |
| Deck props (incl. boss wreck) | 13 | 13 |
| Environment layers | 6 | 6 |
| Ground circles (runes + decals) | 7 | 7 |
| FX sprites | 6 | 6 |
| UI (portrait, HUD, 14 icons) | 17 | 17 |
| **Total** | | **66** |

⚠️ **Roster note:** the hero and enemy identities below are placeholder steampunk archetypes written to be swap-friendly — if Skygear's actual design doc names different characters, keep each prompt's structure and swap only the flavour clause marked `[FLAVOUR]`. Everything else (angle, pose, palette, proportions) must stay verbatim.

---

## §4 · Asset Manifest

### 4.1 Hero

**H1 — Sky-Corsair (player character).** Chibi steampunk duellist: long weathered teal-lined greatcoat, brass-buckled harness, heavy gauntlet with pressure gauge, aviator goggles pushed up into wind-blown hair, sabre with a gear-toothed guard.

- `heroes/corsair_front_idle.png` — 512×512
  > [Master Style Block] + Chibi steampunk sky-corsair hero, 2.5 heads tall, upright billboard presentation viewed only subtly from above, roughly 10–15 degrees above horizontal, facing toward camera lower-left, relaxed ready stance with sabre held low, [FLAVOUR: weathered dark greatcoat with oxidised-copper (#3E8F83) lining, brass buckles, goggles pushed up, heavy brass gauntlet with small pressure gauge], cool moonlight rim on the upper-left of the silhouette, warm amber underlight from lower-right, heroic and confident, feet together at bottom-center anchor.
- `heroes/corsair_back_idle.png` — 512×512
  > Same character, same style block, viewed from behind with the same upright 10–15-degree billboard presentation, facing away toward upper-left, coat and hair pushed by wind, sabre visible at hip.
- `heroes/corsair_front_attack.png` — 512×512
  > Same character mid horizontal sabre slash, exaggerated squash-and-stretch action pose, coat flaring, facing camera lower-left, no motion-trail VFX baked in (engine adds the teal arc).

### 4.2 Enemies

Shared enemy rule: enemies skew **iron/gunmetal + ember-orange furnace glow** so they read as hostile against the hero's teal. Grunts get idle front + idle back + attack front (3 images); the ranged, tank and swarm archetypes get front idle + front attack (2); the boss gets 3 + a destroyed-state prop.

**E1 — Boarding Automaton (melee grunt, the "forty converging" horde body).**
- `enemies/automaton_front_idle.png` · `enemies/automaton_back_idle.png` · `enemies/automaton_front_attack.png` — 512×512 each
  > [Master Style Block] + Chibi clockwork boarding automaton, squat riveted gunmetal (#4A4A55) body, single glowing ember-orange (#FF7A2F) eye-lens, exposed brass gear heart in chest, hook-blade arms, steam wisps at joints, upright billboard presentation viewed only subtly from above, roughly 10–15 degrees above horizontal, facing camera lower-left [back variant: facing away upper-left; attack variant: both hook-blades raised mid-lunge], menacing but toylike, feet at bottom-center anchor.

**E2 — Cog-Gremlin (fast swarmer).**
- `enemies/gremlin_front_idle.png` · `enemies/gremlin_front_attack.png` — 384×384
  > Tiny feral gremlin in scavenged brass scrap-armour, oversized wrench, hunched sprint-ready posture, wild ember eyes, 2 heads tall, same angle/lighting rules. Attack: mid-leap wrench swing.

**E3 — Tesla Drone (ranged, airborne).**
- `enemies/drone_front_idle.png` · `enemies/drone_front_attack.png` — 448×448
  > Hovering brass sphere with three gimballed propellers, cracked glass core glowing electric blue (#7ADCFF), dangling grounding chains, hovers so anchor point is bottom-center with visible air gap below chains. Attack: core flaring white, arc coils extended. (Engine bobs it; no propeller blur baked in.)
- Its projectile: see FX §4.6, `fx/bolt_tesla.png`.

**E4 — Furnace Knight (tank / elite).**
- `enemies/furnace_knight_front_idle.png` · `enemies/furnace_knight_front_attack.png` — 640×640
  > Hulking iron knight built around a pot-belly furnace, grated chest spilling ember light, massive riveted anchor-hammer, slow heavy stance, chimney shoulder venting smoke. Attack: hammer raised overhead two-handed.

**E5 — Rigging Wraith (harasser, vertical threat).**
- `enemies/wraith_front_idle.png` · `enemies/wraith_front_attack.png` — 512×512
  > Tattered sky-ghost of a fallen aeronaut, translucent teal-grey body trailing into torn rope and cloth instead of legs, brass diving-mask face with hollow glow, floats with anchor at bottom-center of trailing wisps. Attack: both claw arms extended forward. (Engine handles transparency pulsing; paint at full intended opacity.)

**E6 — Boss: The Brass Colossus.**
- `enemies/colossus_front_idle.png` · `enemies/colossus_back_idle.png` · `enemies/colossus_front_attack.png` — 1024×1024
  > Colossal four-armed brass-and-iron automaton the size of six grunts, cathedral of pipes and gauges for a torso, furnace maw, two arms ending in cannon barrels and two in fists, commanding wide stance, same chibi head-heavy proportion pushed to imposing scale, same upright 10–15-degree billboard presentation. Attack: all four arms spread, maw blazing.
- `props/colossus_wreck.png` — 1024×768 — the boss collapsed as a smoking deck wreck, for the post-fight arena.

### 4.3 Deck props (billboards, occluders in the painter's sort)

All use the same upright 10–15° billboard presentation, standard two-source lighting, and bottom-center anchor. These are the objects the player weaves between, so silhouettes must stay readable at 30% scale.

| File | Size | Prompt core (append to Master Style Block) |
|---|---|---|
| `props/crate_small.png` | 384×384 | riveted timber cargo crate, brass corner caps, stencil-free faces |
| `props/crate_stack.png` | 512×640 | three crates stacked and rope-lashed, slightly askew |
| `props/barrel.png` | 320×384 | iron-banded oak barrel, tar-sealed lid |
| `props/rope_coil.png` | 320×256 | fat coil of tarred rope, low and wide |
| `props/cannon_deck.png` | 640×512 | brass deck cannon on a riveted swivel carriage, oxidised-copper fittings |
| `props/mast_section.png` | 512×1024 | lower section of a timber mast with brass collar, cleats, wrapped rigging, cut off cleanly at top of canvas |
| `props/railing_segment.png` | 512×384 | one repeatable segment of deck railing, timber rail on brass stanchions (engine tiles it along deck edges) |
| `props/lantern_post.png` | 384×768 | wrought-iron lamp post with caged amber flame, the warm light source of the scene |
| `props/steam_vent.png` | 384×320 | brass floor vent unit with pipes and a spinning gauge, slight ember glow within |
| `props/hatch_cargo.png` | 512×384 | raised cargo hatch frame with iron-banded doors, closed |
| `props/harpoon_ballista.png` | 640×512 | mounted brass harpoon launcher, loaded, rope spooled beneath |
| `props/loot_chest.png` | 384×384 | ornate brass-filigree reward chest, faint relic-purple (#C77DFF) light in the seam |

### 4.4 Environment layers (screen-space, opaque or semi-transparent, painted FLAT — no vanishing point)

| File | Size | Prompt core |
|---|---|---|
| `env/sky_backdrop.png` | 2048×1024 | opaque storm-dusk sky panorama: bruised violet-indigo cloud masses (#1B1830→#2E2A4E), one dramatic moonbreak of cool light (#8FA6C9) upper-left, subtle warm horizon ember lower-right, painterly, darkest at top corners for natural vignette |
| `env/clouds_far.png` | 2048×512 | transparent strip of distant flat cloud-sea tops, cool and desaturated, horizontally tileable |
| `env/clouds_near.png` | 2048×512 | transparent strip of nearer torn storm clouds, slightly warmer edges, horizontally tileable, bolder shapes |
| `env/airship_distant.png` | 512×256 | small silhouette of an escort airship with lantern dots, nearly flat dark shape against sky |
| `env/envelope_top.png` | 2048×768 | the underside of our own airship's gas-bag envelope seen from the deck: huge curved canvas mass with brass ribs, netting and rigging lines dropping toward the viewer, occupies the top of the frame and fades to transparent at the bottom edge; storm light grazing across it |
| `env/bow_prow.png` | 1024×640 | the ship's bow rising at the far end of the deck: figurehead, brass trim, navigation lanterns, painted as a flat backdrop piece, transparent background |

### 4.5 Ground circles — telegraphs & decals (⚠ author as PERFECT CIRCLES, dead top-down, per §2.5)

| File | Size | Prompt core |
|---|---|---|
| `ground/rune_enemy.png` | 512×512 | glowing danger rune ring, top-down perfect circle, hot red-orange (#FF3D2E edge, #FF8C1A inner glow), gear-toothed outer ring with angular warning glyphs, transparent center and background, emissive look |
| `ground/rune_enemy_filled.png` | 512×512 | same ring with a 30%-opacity molten fill disc inside (final-warning state) |
| `ground/rune_player.png` | 512×512 | aether-teal (#37F0C8) targeting ring, cleaner and thinner than the enemy rune, fine clockwork tick marks around the circumference, transparent center |
| `ground/decal_scorch.png` | 384×384 | roughly circular scorch mark, charcoal black with faint ember edge, top-down, soft irregular edge |
| `ground/decal_oil.png` | 384×384 | roughly circular dark oil stain with faint teal-purple sheen, top-down |
| `ground/decal_gear_scatter.png` | 384×384 | loose scattering of small cogs, springs and rivets in a circular footprint, top-down (automaton death litter) |
| `ground/shadow_blob.png` | 256×256 | soft-edged plain black circle at ~60% max opacity fading to 0 at rim, no texture — the universal entity shadow the engine squashes to an ellipse |

### 4.6 FX sprites (single frames — engine handles motion, scaling, fading, additive blending)

| File | Size | Prompt core |
|---|---|---|
| `fx/puff_steam.png` | 256×256 | single soft painterly steam puff, warm-grey with amber underlight, transparent |
| `fx/puff_smoke_dark.png` | 256×256 | single dark oily smoke puff, ember flecks |
| `fx/burst_impact.png` | 320×320 | radial impact burst, spiky hand-painted star of #FFE08A core and #FF7A2F rays, comic-book energy |
| `fx/bolt_tesla.png` | 256×128 | horizontal crackling bolt projectile, #7ADCFF with white core, jagged painted arcs |
| `fx/slash_arc.png` | 384×256 | curved sabre-slash arc, aether-teal (#37F0C8) with white leading edge, painterly taper |
| `fx/ember_particle.png` | 64×64 | single glowing ember mote, #FF7A2F with #FFE08A center |

### 4.7 UI

Icons are read at 40–64 px: one bold symbol, no interior detail smaller than 10% of the canvas, consistent framing.

- `ui/portrait_corsair.png` — 512×512 — bust portrait of the Sky-Corsair, same character as H1 but at portrait framing (head and shoulders, three-quarter face), painterly, dark vignetted background baked in (this one is NOT transparent), determined expression.
- `ui/frame_hud.png` — 1024×256 — ornate but restrained brass HUD plate for the bottom bar: riveted edge, gauge-bezel sockets for skill icons, transparent center regions where the engine composites bars and icons.
- `ui/gauge_ring.png` — 256×256 — circular brass gauge bezel with tick marks, transparent center (cooldown overlay frame).
- **Skill icons** — 256×256 each, unified treatment: dark disc background `#14121B`, thin brass ring, single bold emblem in the listed colour:
  | File | Emblem |
  |---|---|
  | `ui/icon_skill_slash.png` | teal sabre arc |
  | `ui/icon_skill_dash.png` | teal double-chevron with speed lines |
  | `ui/icon_skill_aoe.png` | teal ring with center burst (the RANGED_AOE) |
  | `ui/icon_skill_cone.png` | teal wedge fan (the CONE) |
  | `ui/icon_skill_turret.png` | brass mini-cannon on teal disc |
  | `ui/icon_skill_barrier.png` | teal hex-riveted shield plate |
  | `ui/icon_skill_hook.png` | teal harpoon hook |
  | `ui/icon_skill_ult.png` | teal-and-gold lightning-wreathed gear (ultimate — only icon allowed gold) |
- **Relic icons** — 256×256, same disc treatment but **relic-purple ring** (`#C77DFF`), used as the template for the full relic set; generate these five now:
  | File | Emblem |
  |---|---|
  | `ui/icon_relic_gear_heart.png` | purple-glowing brass gear heart |
  | `ui/icon_relic_stormglass.png` | vial of bottled lightning |
  | `ui/icon_relic_lodestone.png` | cracked magnet-stone with orbiting rivets |
  | `ui/icon_relic_aether_flask.png` | teal-liquid brass flask |
  | `ui/icon_relic_black_cog.png` | ominous matte-black cog, red glint |
- `ui/icon_currency_cog.png` — 128×128 — small polished brass cog, the currency drop/counter icon.

*(Not assets: damage numbers, health/steam bars, cone and line telegraphs, vignette, ambient fog — all code-rendered per §2.9. Codex must not generate them.)*

---

## §5 · Per-Asset QA Checklist (run before accepting any image)

1. Reads correctly against `#14121B` — silhouette clear, nothing lost in darkness, nothing glowing that shouldn't.
2. Characters and prop billboards match the upright 10–15° production anchors: nearly face-on, subtly elevated, with no crown-heavy top view or strong body foreshortening — **except** §4.5 ground circles (dead top-down) and §4.4 layers (flat).
3. Outline present, near-black, consistent weight with previously accepted assets.
4. Lighting: cool rim upper-left, warm fill lower-right. No other light logic.
5. Background fully transparent (unless marked opaque), no white halo or semi-transparent fringe on outlines.
6. No baked drop shadow, no baked ground contact, feet/base on the bottom-center anchor with the 8% padding.
7. No baked motion blur or VFX on characters; no text anywhere.
8. Ground circles are perfect circles, centered, symmetric enough to survive ellipse-squashing.
9. Palette drift check: sample the dominant tones — they should sit within the §1.3 tables. Gameplay colours (teal/red/purple) appear ONLY on gameplay elements.
10. Style drift check every 10 assets: place new asset beside `corsair_front_idle.png` — same world? If not, regenerate the drifter, not the hero.

---

## §6 · Assumptions Made (flag to Alex before generating if any are wrong)

1. **Roster is placeholder.** One hero and six enemy archetypes invented to fit a steampunk boarding-action horde game; swap `[FLAVOUR]` clauses to match Skygear's real design doc without touching structure.
2. **Storm-dusk is a new art-direction decision**, made so Cinderia's dark-base/bright-pop contrast works on an open-air deck. A daytime sky would break the entire lighting model in this doc.
3. **Single hero for the one-shot.** Additional heroes reuse the H1 template: 3 images + portrait + swap the `[FLAVOUR]` clause.
4. **Facing scheme is 2-views-mirrored** (front-quarter + back-quarter). If the game later needs true 4-direction art, each character gains 2 more images — the prompts extend naturally.
5. **All animation is code-side** (bob/squash/flash/tint). If real frame animation is ever wanted, that's a different pipeline (cut-out puppet rigs), not more image generation.
6. V5+ uses engine pitch ≈ 0.72 rad with fixed yaw and an intentionally separate upright 10–15° character/prop billboard presentation. Re-test the pair if the renderer changes materially.

*— Prepared for handover to Codex 5.6 Sol · Skygear restyle v1 · 2026-07-26*


