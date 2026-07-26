# SKYGEAR — one-shot build prompt

> Paste everything below the line into a **fresh Opus 5 session**. It is self-contained — it assumes no knowledge of the 2011 deck.

---

Build **SKYGEAR**, a single-player top-down hero-defense action game, as **one self-contained `skygear.html` file** that runs by double-clicking it. No build step, no npm, no external assets, no network calls, no frameworks. Vanilla JS + `<canvas>` 2D. Everything — art, audio, data — generated in code.

Ship it complete and playable in one pass. Do not stub anything. Do not leave TODOs.

## The pitch

You are a sky-pirate captain defending the deck of your airship. Mechanical boarders swarm over the rails in waves. You fight them off with a hand of magic-industrial skills, and between waves you draft upgrades that reshape those skills. Steampunk, semi-serious, brass and fire.

**The game must be fun within 15 seconds of loading.** That is the primary acceptance criterion. Everything below serves it.

---

## 1. The core hook: shape × element

Every skill is a **Shape** (how it delivers) crossed with an **Element** (what it does). This is the whole design. Six shapes, four elements, 24 combinations — implement it as a real matrix, not 24 hardcoded skills.

### Shapes

| Shape | Delivery | Base numbers |
|---|---|---|
| `CLOSEHIT` | 140° arc sweep at melee range | range 90px, 22 dmg, 0.45s cd |
| `LINE_BURST` | piercing bolt along a line, hits all in path | length 520px, width 26px, 30 dmg, 1.1s cd |
| `CONE` | expanding frontal cone | 65° / 260px, 26 dmg, 1.4s cd |
| `RANGED_AOE` | circular burst placed at cursor | radius 110px, cast range 420px, 40 dmg, 2.6s cd |
| `CHAIN` | hits nearest target, then arcs to 3 more within 200px | 26 dmg, −15% per jump, 2.0s cd |
| `RAY` | sustained beam while held, ticks 8×/sec | length 480px, 7 dmg/tick, 0.6s cd after release, 2.5s max duration |

### Elements

| Element | Colour | On-hit effect |
|---|---|---|
| `EMBER` | `#E2691E` | burn: 5 dmg/s for 3s, stacks to 3 |
| `FROST` | `#7FC7D9` | slow 40% for 2s |
| `ARC` | `#F2D14B` | 20% chance to stun 0.6s; +1 chain jump if shape is CHAIN |
| `STEAM` | `#B9A8C9` | knockback 120px + 25% accuracy loss on enemy for 2s |

Element effects apply to **any** shape. `RAY` + `EMBER` is a flamethrower. `CHAIN` + `FROST` freezes a cluster. `RANGED_AOE` + `STEAM` scatters a pack off the rail. Make sure all 24 combos actually work and visibly differ.

### Loadout

- Player has **4 skill slots**. Slots 1–2 unlocked at start, slot 3 at wave 3, slot 4 at wave 6.
- Starting loadout: slot 1 = `CLOSEHIT`+`EMBER`, slot 2 = `RANGED_AOE`+`FROST`.
- New slots are filled by a draft choice (see §4).

---

## 2. Controls & feel

- **WASD / arrows** — move. Player speed 260 px/s, with acceleration (reach top speed in ~0.12s) and a little slide on release. Never instant-stop; it feels dead.
- **Mouse** — aim. The character always faces the cursor.
- **LMB** — fire slot 1. **RMB** — slot 2. **Space** — slot 3. **Shift** — slot 4. Also **1/2/3/4** as alternates.
- **E** — dash: 220px over 0.16s, i-frames for the full dash, 1.6s cooldown. Leaves a fading afterimage trail. This is the most important verb in the game — make it crisp.
- **Esc** — pause.

### Game feel — non-negotiable, this is where one-shots fail

Implement every one of these:

1. **Hit-stop.** On any hit that deals ≥25 damage, freeze the simulation for 40ms (70ms on a kill). Not the render loop — the sim.
2. **Screen shake.** Trauma-based: add trauma on hit (0.15) / kill (0.25) / player-hit (0.5), decay at 1.6/s, offset = trauma² × 14px with random direction. Cap it.
3. **Knockback** on every hit, scaled by damage, with friction decay.
4. **Enemy hit flash** — full white silhouette for 60ms.
5. **Floating damage numbers** — rise and fade over 0.7s, crits (see below) larger and orange.
6. **Particles.** Impact sparks on every hit, gib burst on death (8–14 shards with velocity + gravity + fade), muzzle flash on skill fire, dust puffs under the player's feet while moving.
7. **Enemy attack telegraph.** Every enemy attack shows a red arc/line/circle for 0.4s before it lands. Player must always be able to read incoming damage.
8. **Skill cooldown sweep** — radial wipe on the HUD icon, plus a soft flash + click when it comes back up.
9. **Wave clear juice** — time dilates to 0.35× for 0.8s, `WAVE N COMPLETE` slams in with a scale-down, gold particles.
10. **Screen-edge vignette** pulsing red when player HP < 30%.
11. **Crits** — 12% base chance, 2× damage, distinct sound + bigger number.

### Audio

Generate everything with **WebAudio oscillators/noise** — no files. You need at minimum: skill fire (per element, different waveform), enemy hit (short noise burst), enemy death, player hurt, dash whoosh, crit ding, wave-clear chime, upgrade-pick confirm. Keep them short and punchy. Add a master volume control and a mute key (`M`). Do not build a music system.

---

## 3. The arena and the defense

The airship deck, viewed top-down, occupies the play area. Around it: sky, cloud parallax layers scrolling slowly, and the purple gas-bag envelope framing the top of the screen.

- Deck is a rounded-rectangle arena roughly 1100×700 world units. Camera is fixed — the whole deck is always visible. **No scrolling.** Readability beats scale.
- **The Boiler** sits amidships — a brass engine core with **500 HP**. This is what makes it *defense* and not just an arena brawler.
- Enemies board over the **bow and both rails** at telegraphed spawn points (a marker + climbing animation for 0.8s before they're active — never spawn an enemy directly onto the player).
- Enemies prefer the player if within 260px, otherwise they path to the Boiler and attack it.
- **Lose** when the Boiler hits 0 **or** the player hits 0. Player has 100 HP, regenerates 4 HP per wave clear, no combat regen.
- **Win** by clearing wave 12.

Deck props for cover and interest: crates, a mounted gun, chain rails, hatches. Purely visual + they block movement. Keep the middle open.

---

## 4. Waves and the draft

12 waves. Escalating composition. After **every** wave, present a **draft: 3 cards, pick 1.** This is the retention loop — make the cards feel good.

### Enemy types

| Type | HP | Speed | Behaviour |
|---|---|---|---|
| `SCRAPPER` | 60 | 150 | melee, closes and swings, 12 dmg |
| `GUNNER` | 35 | 110 | ranged, stops at 340px, fires a slow telegraphed bolt, 10 dmg |
| `ARMORED` | 180 | 75 | melee, 40% damage reduction from the front only — reward flanking, 20 dmg |
| `SWARM` | 20 | 230 | fast, numerous, beelines for the Boiler and ignores the player, 6 dmg |
| `BOSS` | 900 | 95 | wave 12 only. Three attacks on a rotation: ground slam (ring telegraph), summon 6 SWARM, sustained ray sweep. |

Scale enemy HP by `1 + 0.06 × (wave − 1)`. Do not scale their damage — scale their count. Getting overwhelmed should feel like a crowd problem, not a numbers problem.

Wave 12 is the Boss plus continuous adds.

### Draft cards

Offer 3 random cards from a pool of at least **22**. Weight toward the player's current build. Categories:

- **Shape mods** — `+35% AoE`, `+30% range`, `−20% cooldown`, `+1 chain jump`, `+2 pierce`, `cone widens to 95°`
- **Element mods** — `+50% burn damage`, `slow becomes 65%`, `stun chance → 40%`, `knockback +80%`
- **Element swap** — reroll one slot's element (huge, changes your build)
- **New skill** — fills an empty slot with a random shape+element
- **Player mods** — `+20 max HP`, `+12% move speed`, `dash cooldown −0.4s`, `dash damages enemies passed through`, `+8% crit`, `crits explode for 20 AoE damage`, `kills have a 15% chance to drop a 15 HP scrap pickup`
- **Spicy** — `every 5th cast is free and doubled`, `skills leave a 2s damaging field where they land`, `on kill, 10% chance to fire slot 1 automatically at a random enemy`

Cards must show a clear name, one line of plain-English text, and their effect must be **immediately visible in play**. Rarity tint the borders. Draft screen pauses the game.

---

## 5. Art direction

Everything drawn procedurally. No sprites, no images, no emoji as game objects.

**Palette — use these exact values:**

```
deck / khaki      #B9AE86
burnt orange      #C86A2E
dark brown        #4A3628
sage              #97A07E
charcoal purple   #4A4453
olive             #7D7448
grey              #6E6E6E
oxblood accent    #8B1A1A
brass highlight   #D9A441
sky               #A8C4D4
```

Style: bold flat shapes with heavy dark outlines, a single warm light source, long soft shadows under every entity so things read as being *on* the deck. Player is a red-coated silhouette. Enemies are brass-and-grey mechanical pirates — build them from primitives (body, limbs, a weapon shape, a glowing eye) and vary the silhouette **clearly** between the five types. A player must identify enemy type from silhouette alone at a glance.

Skill VFX carry the element colour and the shape's geometry, with additive blending and a bright core + soft outer glow. Effects should be readable over a crowd, not obscure it — cap simultaneous particles around 400 and cull aggressively.

**UI:** brass-framed panels. Bottom-centre: 4 skill slots with cooldown sweeps. Bottom-left: player HP. Top-centre: Boiler HP + wave number + enemies remaining. Title screen with the SKYGEAR wordmark in a heavy condensed face, a "how to play" panel, and a start button. Game-over and victory screens with a stat summary (waves survived, kills, damage dealt, best combo) and a restart.

---

## 6. Architecture

Data-driven throughout. The design must be editable by changing tables, not code:

```js
const SHAPES   = { CLOSEHIT: {...}, LINE_BURST: {...}, ... }
const ELEMENTS = { EMBER: {...}, FROST: {...}, ... }
const ENEMIES  = { SCRAPPER: {...}, ... }
const WAVES    = [ { spawns: [...], delay: ... }, ... ]
const CARDS    = [ { id, name, text, rarity, weight, apply(state) }, ... ]
```

Adding a wave or a skill must mean adding one object to one array. A single `TUNING` object at the top of the file holds every balance constant.

Fixed-timestep simulation at 60Hz with an accumulator, decoupled from render. Spatial hashing for collision if entity count justifies it — target **200+ entities at a stable 60fps**.

Structure the file readably: `TUNING` → data tables → engine → entities → systems → UI → bootstrap.

---

## 7. Definition of done

Before you finish, verify each of these is true:

- [ ] Opens from the filesystem and plays. Zero console errors.
- [ ] All 6 shapes and all 4 elements implemented, all 24 combos functional and visually distinct.
- [ ] All 12 waves playable through to the boss and a victory screen.
- [ ] At least 22 draft cards, each with a visible in-game effect.
- [ ] Every item in the game-feel list of §2 is present.
- [ ] Enemy attacks are always telegraphed before they land.
- [ ] Holds 60fps with 200 entities.
- [ ] Both loss conditions and the win condition work, each with its own screen.
- [ ] A first-time player understands the controls without being told.

Do not ask clarifying questions. Where this spec is silent, make the choice that is more fun, and note it in a short comment. Bias toward **more juice, faster pacing, and shorter cooldowns** than feels correct on paper.
