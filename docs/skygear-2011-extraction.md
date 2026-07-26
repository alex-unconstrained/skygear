# SKYGEAR — 2011 Pitch Extraction

**Source:** https://prezi.com/aa7h6kpymg6k/skygear/
**Author:** Alexander Johnson · **Team:** Proxymorons · **Updated:** May 15, 2011
**Captured:** 2026-07-26 — 31 content frames + end card in `./frames/`

---

## Deck structure

Hub-and-spoke around the SKYGEAR wordmark (industrial gear-cluster art, olive/khaki + oxblood palette):

`Genre → Walkthrough → Features → Feasibility → Marketability → Q & A`

---

## 1. Genre

**Hero Defense.**

That's the whole slide. One phrase, deliberately.

---

## 2. Walkthrough (the mockups — this is the richest part)

### Character Selection screen (`frames/frame-04.png`, `05`)
- **4 character slots** (numbered 1–4), portrait preview pane above
- Skill loadout table with three columns: **Offensive · Defensive · Ultimate**
  - Offensive: 3 icons (red bomb/burst, yellow lightning bolt, cyan cone)
  - Defensive: 3 icons (grey shield/spike, gold gear, orange terrain/wall)
  - Ultimate: 2 icons (purple vortex, black figure/summon)
- Adjacent reference sheets define the **skill shape vocabulary** — a delivery-pattern taxonomy applied over a top-down arena:

| Shape | Read from the mockup |
|---|---|
| **Chain Effect** | hops between clustered enemies |
| **Ranged AoE** | placed circular burst at distance |
| **Projected Cone** | frontal cone from caster |
| **Line Burst** | straight-line pierce |
| **Closehit** | melee-range hit |
| **Ray Attack** | sustained beam |

Each shape is drawn in multiple colour variants (orange, purple, cyan, gold, white) — i.e. **shape × element** is the combinatorial axis of the skill system.

### HUD (`frames/frame-06.png`)
Painted mockup, top-down camera looking at the deck of an airship in flight:
- Player avatar (red-coated figure) centre-deck
- Purple vortex AoE effect mid-cast
- **Bottom-centre: 4 skill slots** in a gear-framed bar
- **Bottom-left: empty panel** (health/resource)
- **Bottom-right: minimap** showing the ship silhouette with red/green enemy + ally dots
- Sky/cloud parallax at frame edges, purple gas-bag envelopes above

### Gameplay (`frames/frame-07.png` – `10`)
Two-panel sequence, same arena in 3D-blocked form:
- Enemies (grey mechanical pirates) **board from the bow**, spawning in groups of ~4–8
- Player + a second unit (ally or co-op partner) engage
- Green enemy cluster caught in a purple **Ranged AoE**; second panel shows the same cluster hit by an orange fire burst — demonstrating the same shape with different elements
- **`WAVE 1 COMPLETE`** interstitial → arena clears

### Upgrade / progression step (`frames/frame-10.png`, `11`)
On wave completion, a **`+` node appears above each of the 4 skill slots**. Clicking one opens a choice card:

```
Increased AoE
Increased Range
Increased DoT
```

So: **wave → clear → spend one upgrade per skill slot → next wave.** That's the meta-loop.

### Theme (`frames/frame-12.png`)
- Steampunk
- Semi-serious
- **Repelling waves of pirates**

Concept art: red-envelope airship with brass gondola; sketch sheet of deck props — mounted guns, chain-link rails, crates, a switch-lever, cannon emplacements.

---

## 3. Features — scoped in A / B / C tiers

### A — Must have (`frames/frame-17.png`)
- Melee combos
- Skill pool
- Varying enemy types
  - Melee → **more hp**
  - Ranged → **less hp**
- Flow control
- Tutorial

### B — Should have (`frames/frame-18.png`)
- Multiple characters
- Unique passives
- Skill upgrades

> Worked example: **Steam Burst** → `Increased AoE` / `Increased Slow` / `Adds a DoT`

### C — Could have (`frames/frame-19.png`, `20`, `21`)
- Expanded skill selection
- **Co-op with gamepad support**
- Expanded enemy types:
  - **Armored** — more hp, slower
  - **Swarm** — less hp, longer range
  - **Boss** — tougher versions of the other enemy types

Enemy concept sheet: five mechanical pirate archetypes — a lean sabre-armed scrapper, a gatling/flamethrower gunner with rotor-blade headgear, a hook-armed brute, a small crouching scuttler, and a heavy piston-legged bruiser.

---

## 4. Feasibility

### Art (`frames/frame-13.png`, `14`, `15`)
- "Steampunk… **and magic!**"
- Style
- **Scope?** ← flagged with a question mark in the original

Mood board: brass locomotives, Edward Gorey-ish industrial interiors, a steampunk Dalek, cosplay armour, pocket-watch movements, gear vector clusters, a silhouette line-up of pirate crew, and a **6-swatch palette: burnt orange / dark brown / sage / charcoal-purple / olive / grey.**

Player-character concept sheet (`frame-15.png`): five playable-looking figures — a red-coated fire-conjuring captain, a brass spider-walker, a striped-shirt multi-armed automaton, a goggled pistol-and-piston rogue, a bearded brute with an arm cannon — plus the airship in isolation.

### Technology (`frames/frame-24.png`)
- Sufficient skills
- Customization is fun
- Effects!
- **Modularity** — adding/removing waves & skills

### Gameplay risk (`frames/frame-25.png`)
- Overwhelming to the player → **Tutorial**
- Basic gameplay
- **Balance**

---

## 5. Marketability

### Target audience (`frames/frame-27.png`)
- 13+
- Predominantly male audience
- ESRB **T** Rating

### Similar games (`frames/frame-28.png`)
- **League of Legends** (Clash of Fates-era logo)
- **Bloodline Champions**

---

## 6. Wrap Up (`frames/frame-29.png`)

- Hack and slash game
- Customization
- Steampunk
- Airship

---

## Reader's notes

1. **The genre call was early.** May 2011 predates *Orcs Must Die!* (Oct 2011), *Dungeon Defenders* (Oct 2011), and *Sanctum*'s console push. "Hero defense" as a named genre was barely a term yet.
2. **The comps are MOBAs, not tower defense.** LoL and Bloodline Champions explain the skill-shape vocabulary — chain / cone / line / ray is arena-MOBA grammar imported into a wave-defense frame.
3. **The single best idea in the deck is the shape × element skill matrix.** Six delivery shapes crossed with an element set generates a large skill pool from a small amount of authored content. That's also what makes it cheap to build.
4. **Modularity was already the stated architecture** ("adding/removing waves & skills"). Data-driven content, decided in 2011.
5. **Art scope was the acknowledged risk**, marked with a literal question mark. Code was never the bottleneck.
6. **Nothing in the deck defines:** movement/control scheme, resource or cooldown economy, health/damage numbers, wave composition or count, win condition, ship destructibility, or what happens when boarders reach an objective.
