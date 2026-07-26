# Skygear V5 Lane Asset Amendment

Updated: 2026-07-26  
Applies to: `storm-dusk-v5.html` / `PRESET.lanes`

## Why the manifest changes

V5 turns the deck cannon into a destructible lane gate, adds friendly crew waves, introduces a stationary enemy boarding hulk with sealed/open vulnerability states, and uses continuous cargo runs to make lane commitment real. The original 66-image manifest predates those mechanics and cannot represent their state changes.

This amendment adds the **minimum eight images** needed to stop those systems relying on procedural art. The production count becomes 75: the original 66, the already-added Furnace Knight back view, and these eight V5 images.

## Camera rule — production locked for V5+

The engine deck projection remains `0.72 rad / 41°`. Character and prop billboards are painted upright and nearly face-on, viewed only subtly from above at roughly `10–15° above horizontal`.

This is the V5+ production rule because the recent in-engine comparison found that the delivered upright sprites read correctly while a literal `40–49°` character bake looked pitched over on the projected deck. The live V5 lane view reinforces that result: player, crew, cannon, cargo-wall, hulk, and enemy silhouettes must stand visually upright while the engine supplies the ground-plane perspective.

- Do not use the archived literal-49° comparison set for production.
- Screen-space environment layers remain flat.
- Ground circles remain dead top-down and are squashed by the renderer.
- Generation of these eight images is unblocked.

## New assets — eight images

| File | Runtime target | Renderer role |
|---|---:|---|
| `props/cargo_wall_module.png` | 512×512 | Repeated short billboard module placed along code-owned wall collision |
| `allies/crew_front_idle.png` | 384×384 | Friendly crew advancing toward the bow/camera-facing quarter |
| `allies/crew_back_idle.png` | 384×384 | Friendly crew advancing away toward upper-left |
| `allies/crew_front_attack.png` | 384×384 | Pike thrust; engine mirrors for right-facing |
| `props/boarding_hulk_sealed.png` | 1024×640 | Hold-wave state; armour closed and invulnerable |
| `props/boarding_hulk_open.png` | 1024×640 | Push-wave state; same footprint, furnace core exposed |
| `props/boarding_hulk_destroyed.png` | 1024×640 | Defeated persistent bow wreck |
| `props/cannon_deck_destroyed.png` | 640×512 | Friendly lane cannon after its HP reaches zero |

The `allies/` category is new. It keeps friendly lane units separate from controllable heroes and hostile enemies.

## State contracts

### Cargo wall module

Collision and the continuous projected wall remain code-owned. Do not author one long rectangular wall image: Canvas 2D cannot perspective-warp it onto the lane geometry. Author one compact cargo-stack billboard that can repeat every ~150 world units along the wall run.

- Dark timber cargo cases, iron straps, rope lashings, and brass cap rail.
- Modular left/right edges with no unique endcap or directional emblem.
- Height must remain below the captain’s head and should not become a new occlusion tower.
- Renderer repeats modules but keeps the cross-passage and open base physically and visually clear.

### Friendly crew

A deck hand must read as friendly at crowd scale without competing with the captain.

- Shorter and simpler than the hero; slate-blue work coat, watch cap, boarding pike, narrow aether-teal sash.
- No hero greatcoat, goggles, ornate gauntlet, or sabre silhouette.
- Front/back identity, proportions, pike length, palette, and lighting must match exactly.
- Attack changes pose only: one readable forward pike thrust, no baked trail or impact.
- Full head, hands, feet, pike tip, and coat hem must remain inside the canvas.

### Boarding hulk

All three states share the same ground footprint, anchor, scale, camera, ribs, ramps, and outer silhouette. State changes must not cause the hulk to jump or resize.

- **Sealed:** thick plating covers the furnace maw; dim red slit only; unmistakably invulnerable.
- **Open:** plates hinge apart and expose a hot furnace core; this is the push-wave target. The open state must read instantly without relying on the HUD.
- **Destroyed:** central structure collapsed inward, ramps slack, core dark. No baked smoke animation; the engine supplies smoke particles.

The hulk is a projected bow billboard, not a screen-space background. Keep the bottom anchor consistent across all three files.

### Destroyed cannon

Match `props/cannon_deck.png` exactly in base footprint, swivel mount, material treatment, lighting, and camera. Drop or split the barrel, extinguish the teal coil, expose bent gears, and keep the object recognizable as the same cannon. No baked smoke, sparks, fire, floor, or shadow.

## Renderer integration requirements

1. Add all eight files to `ASSET_MANIFEST` with the target dimensions above.
2. Cargo-wall collision remains authoritative even when its art is missing.
3. Crew selects front/back idle by facing and briefly selects front attack during its windup/recover cycle.
4. Hulk selects sealed/open/destroyed directly from `vulnerable` and `dead`; do not signal vulnerability only with a code glow.
5. Cannon selects live/destroyed from `dead`, preserving its alpha-derived anchor.
6. Missing V5 art falls back to the current procedural renderer, never to an unrelated character placeholder.
7. Run exact-size optimization before packaging; high-resolution generation masters stay outside runtime folders.

## QA additions

- At three-lane density, crew and boarders remain distinguishable at a glance.
- Cargo modules never visually close the cross-passage or base rotation area.
- The captain remains the strongest friendly silhouette and still draws last.
- Hulk sealed/open state is identifiable with the HUD hidden.
- Destroyed cannon communicates a permanently open lane without resembling live cover.
- X-ray rims remain capped in screen pixels and are not baked into any PNG.