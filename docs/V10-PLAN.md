# SKYGEAR v10 — the plan of record

**This supersedes all four v10 proposals.** `V10-ROADMAP.md` (mine),
`V10-SHIP-ROADMAP.md` and `SKYGEAR-V10-RELEASE-ROADMAP-CODEX-PROPOSAL.md`
(Codex's) and `V10-RECONCILED.md` are now historical. Where they disagreed, the
resolution is here and the reasoning is kept so nobody relitigates it.

Written 2026-07-27 against v9 (`storm-dusk-v9.html`).

---

## 0 · What v10 is

Every build so far was made for two people who already knew how it worked. v10
is the first made for a stranger: someone who opens a link, reads nothing, is on
an unknown machine, and leaves the moment it feels broken.

**The test:** a person we have never met opens the URL, plays with no coaching,
finishes a run, and can describe the game to someone else.

**The question for any proposed work:** does this make the first complete public
run clearer, more satisfying, or more trustworthy? If not, it is v11.

All three proposals reached this independently. It is settled.

### What v10 is not

No second captain. No endless mode. No meta-progression, relics, currencies or
unlock trees. No accounts, cloud saves or leaderboards. No multiplayer. No
mobile or touch controls. No procedural maps. No renderer rewrite. These are not
bad ideas — they are ways to postpone the moment this game becomes excellent.

---

## 1 · Where the three proposals disagreed, and what wins

| Question | Resolution | Why |
|---|---|---|
| Endless mode | **Cut.** | I proposed it; both Codex documents excluded it. Their argument is better. Replay value comes from the opening-skill choice and the run summary instead. |
| Scope of "must ship" | **REVERSED 2026-07-27 — go for all of it.** Everything is in scope: the full 32-cell pass, every animation cycle, every still, the complete audio manifest, the browser matrix, the authored finale. | I proposed trimming and was overruled. The trim assumed a deadline nobody had set. With no deadline and generation now owned end to end by one agent, the argument for cutting was weaker than the argument for shipping the whole thing once. **The cut list in §0 still stands** — full scope means finishing what exists, not adding heroes or endless mode. |
| Opening skill | **In, as P0.** | Neither Codex doc proposes it. Every run still opens with Frost Mortar. It puts the shape × element pitch in the player's hands in ten seconds instead of by wave 6, and reuses `rollSkillCards()` wholesale. |
| Load time | **Promoted to first.** | 24 MB today; ~34 MB with the approved animation scope. Every asset already has a procedural fallback, so this is a *not needing a loading screen* problem, and everything else is judged through it. |
| Rigging Wraith | **Cut from v10.** | Codex's own condition — "do not add it merely because concept art exists" — is not met. Revisit in v11. |
| Public combination claim | **"32 combinations."** | 9 engine shapes × 4 elements = 36 cells, but Cleave is the fixed basic and excluded from drafts, so 32 are draftable. Now *derived in code*, not written down. |
| Boss finale | **Two beats, not three.** | Codex's three-beat design is right in shape; two phases is the version that ships. |
| Loudness capture, photosensitivity review | **Downgraded to "should", with a named owner or not at all.** | Both require tooling and a person we have not budgeted. An unfalsifiable checkbox in a definition of done blocks a release without telling anyone what to do. |

---

## 2 · The v9 baseline, verified

Measured, not remembered. All figures re-checked 2026-07-27.

| | |
|---|---|
| Campaign | 12 waves, pushes at 4/8/12, Colossus finale |
| Shapes | 9 (Cleave, Lance, Gale, Mortar, Whip, Beam, Field, Pulse, Sentry) |
| Elements | 4 · **32 draftable combinations**, Cleave fixed as the basic |
| Still art | **32 of 67** delivered — 35 missing: ui 12, props 8, ground 7, fx 6, colossus 3, env 3 |
| Animation | 2 run cycles, 28 loose frames, 3.9 MB. 17 cycles outstanding |
| Audio | **6 of 55** cues; 1 music track |
| First load | **24 MB — 19 s at 10 Mbit, 64 s at 3 Mbit** |
| Perf | 1.9 ms/frame typical, 3 ms p95, 37 enemies, on a fast dev box only |
| Determinism | none — no seed, no run log, no report |

### Defects found while reviewing, already fixed

- **Audio died silently after a tab switch.** `unlock()` returned early once
  audio had started, making its own `resume()` unreachable. Every cue still
  reported success while producing nothing. Now resumes unconditionally, on
  `visibilitychange`/`focus`, plus a once-a-second retry.
- **The game miscounted itself** — "24 combinations" on the title and landing
  page since passives shipped. Now derived from `SHAPE_KEYS × ELEMENT_KEYS`.
- **Four shapes shared one icon.** `paintGlyph` had five branches and a
  catch-all, so Beam, Field, Pulse and Sentry drew the *same glyph* in the HUD
  and on draft cards. Each now has its own; the passives gained icon slots.

### Known-bad, not yet fixed

- Three UI assets load and are never drawn (`ui_icon_dash`, `ui_icon_barrier`,
  `ui_icon_cog`), inflating the completion count the title reports.
- README describes a 6 × 4 matrix, 24 combinations and 34 cards. All wrong.
- Five of the sixteen delivered audio masters clip; two need +13 and +18 dB of
  runtime rescue.

---

## 3 · The build order

Seven blocks. Each is independently shippable — if v10 stopped after block 3 it
would already be far better than v9. Blocks 1–2 depend on nothing.

### Block 1 — the front door

- **Instant start.** Boot on procedural art; stream assets in priority order
  (captain → wave-1 enemies → deck/lanes → HUD → props → fx/ui) and swap live.
  No black screen at any connection speed.
- **Seeded RNG** for all gameplay randomness, `?seed=`, seed shown on results
  and in the report. Audio/particle randomness stays outside determinism.
- **Run report + local log.** Copyable one-block report; last ten runs in
  `localStorage`; personal best.
- Delete `assets-49/` (0.98 MB, decision settled).
- Stop counting assets nobody sees in the title's completion badge.

### Block 2 — the first ninety seconds

- **Choose your opening skill**: three cards, different shapes and elements.
- **Contextual first-run prompts**, one line each, fired at the moment the thing
  first happens, dismissed by doing it, stored in `localStorage`, re-enablable:
  first boarder, first draft, first slot unlock, first passive, first push,
  Boiler below 50%.
- **Title screen becomes a title screen** — name, promise, Start Run, How to
  Play, Settings. Controls move into the pause menu.

### Block 3 — settings and access

- **Pause menu**: resume, per-bus volume, mute, fullscreen, restart, quit.
- **Remappable keys** with visible defaults.
- **Reduced motion** — halves trauma, removes full-screen flashes, shortens
  hit-stop. Defaults on under `prefers-reduced-motion`.
- **Element legibility without hue.** Each element gets a shape motif on its
  rings, glyphs and cards; hostile telegraphs use broken outward-toothed edges,
  player areas continuous rims. Colour stops being load-bearing.
- HUD/text scale. Everything persists.

### Block 4 — the run has an end

- Results screen: outcome and cause, waves, duration, kills, damage, the final
  build shown as its shape × element grid, cards taken, seed, personal best.
- **Play Again** as the primary action.
- Copy Run Report next to it.

### Block 5 — legibility in the fight

- Lane readout carries threat count, deepest enemy, cannon health, crew
  presence, push state — with redundant shape, not colour alone.
- One restrained alert when a lane goes critical, with a repeat cooldown.
- Cross-passages marked on the deck and the lane readout.
- Draft cards show shape, element, target slot, `ACTIVE`/`AUTO`, and
  **before → after numbers**.
- Damage numbers aggregate under heavy multi-hit.

### Block 6 — presentation (Codex leads)

- 35 remaining stills, `ground/` and `ui/` first — telegraphs are read every
  second of every fight and are still pure code.
- 3 passive icons into the slots now waiting for them.
- Animation as atlas strips per `ANIMATION-BRIEF.md`, priority: captain
  attack/idle → Scrapper attack/idle → crew → Armored → Swarm → Gunner →
  Colossus.
- SFX by Codex's batch order, generated with natural tails and **edited down** —
  the duration table is an edit budget, not a generation instruction.
- Music: one corrected combat identity plus push, boss, victory and defeat
  derived from it. Not seven unrelated tracks.
- Boss: two beats and a real arrival, using existing telegraph/push/lane rules.

### Block 7 — hardening

- Committed headless harness: boots, no console errors, every shape × element
  executes, every wave starts and clears, pushes spawn fresh hulks, both loss
  conditions and victory resolve, restart is clean, frozen hashes hold.
- Chrome and Firefox; Safari if available.
- 1280×720 through 2560×1440; DPR 1 and 2.
- Perf on a real low-spec machine, cache cold and warm.
- Missing/failed asset behaviour under a throttled connection.

---

## 4 · The feedback contract (adopted from Codex)

Every combat action has five stages. Author SFX, VFX and animation against this
sheet together, not separately.

| Stage | Player question | Feedback |
|---|---|---|
| Anticipation | What is about to happen? | Telegraph shape, charge motion |
| Commit | What did I do? | Shape body sound, cast pose, muzzle |
| Contact | Did it connect, and how hard? | Impact transient, hit-stop, flash, sparks, number |
| Consequence | What changed? | Knockback, death, status, HP |
| Recovery | When can I do it again? | Recovery animation, cooldown ring, ready tick |

A miss gets commit without contact. No stage fires twice.

### Event priority — a mix and render rule, not a label

| Tier | Events | Rule |
|---|---|---|
| 0 survival | captain hurt/low, Boiler hurt/critical, cannon down, push objective, boss telegraph | never culled, audible off-screen |
| 1 agency | player cast, crit, dash, draft/slot unlock | dominant near the captain |
| 2 tactical | enemy wind-up, cannon fire, heavy death, status | limited by threat and distance |
| 3 texture | crew, routine deaths, debris, idle steam | first to thin under load |
| 4 ambience | storm bed, decorative motion | never competes with tier 0 |

Low-VFX and voice limiting cull from the bottom. **Gameplay boundaries never
scale with quality settings.**

---

## 5 · Acceptance — what "done" means

Runnable checks, not aspirations. Anything that needs a person is marked.

**Comprehension** *(needs testers)*
- 80% state the objective after one minute
- 80% use dash by wave 3
- most testers use a cross-passage deliberately
- 90% of completed runs finish with 3–4 skills

**Game**
- every one of the 32 draftable cells deals damage, applies its element, terminates
- no passive exceeds a competently used active outside its intended geometry
- pushes spawn a fresh hulk; wave 4 teaches without consuming the Boiler
- both loss conditions and victory resolve; restart is clean
- a fixed seed reproduces a run

**Presentation**
- no style snapping on captain, crew or Scrapper
- a greyscale screenshot still separates captain, crew and hostiles
- collision area and rendered area agree at near and far depth
- low-VFX preserves every gameplay boundary
- no repeated large-area flash

**Audio**
- no delivered master clips; no runtime rescue above ±6 dB
- wave 11 does not clip; survival cues stay intelligible
- a cannon loss is locatable with the camera in another lane
- no loop survives restart or tab suspension

**Delivery**
- interactive in under 2 s on a cold cache
- critical transfer ≤ 12 MB, total ≤ 30 MB
- 60 fps at 1366×768 on integrated graphics; p95 ≤ 16.7 ms
- zero uncaught console errors across the matrix
- frozen builds byte-identical; rollback is a link change

---

## 6 · Ownership

| Track | Owns | Must not change alone |
|---|---|---|
| Engine (me) | blocks 1–5, 7; loading, buses, budgets, settings, reports, tests | frozen builds; manifest names after ingest |
| Presentation (Codex) | block 6; stills, strips, VFX textures, SFX masters, music | gameplay boundary sizes; collision/telegraph dimensions after content lock |
| Human | playtests, low-spec hardware, loudness and photosensitivity judgement | — |

One canonical event sheet (§4) is shared. Neither side changes collision or
telegraph geometry after block 5 without telling the other — that is what makes
block 6's output safe to produce in bulk.

---

## 7 · Full scope — what that actually commits to

Decided 2026-07-27: v10 ships complete rather than staged.

| | Volume | Notes |
|---|---|---|
| Stills | 35 | ~20 at 4 candidates, ~15 at 1 = **~95 image generations** |
| Animation | 17 cycles | 1 video generation each, plus reruns for weak loops. Historically 3 of 5 loops scored weak, so budget **~27 video generations** |
| SFX | 48 cues | 3–5 takes each ≈ 180 generations ≈ 20k characters, well inside the 300k quota |
| Music | 6 more tracks | one identity with layers, not six unrelated |
| Engine | blocks 1–5, 7 | unchanged |

**Video generation is the dominant cost** and the only one worth pacing. Forge
one candidate for props and four only for things a player looks at; animate only
after a still is approved, because regenerating a cycle from a bad source pays
the expensive call twice.

Ship **incrementally** into v10 as each asset lands. Every asset has a
procedural fallback, so a partial batch degrades one sprite rather than breaking
anything, and a broken asset is found the same day it is made.

## 8 · The two questions nobody has answered

1. **How long is v10 allowed to take?** Blocks 1–4 are days. All seven is weeks.
   This number decides how much of §1's scope trimming is enough.
2. **Who does the human work?** Five cold playtests, a slow laptop, loudness on
   three output systems, photosensitivity review. None of it can be done by an
   agent and all of it is on the critical path to "confidently put in front of
   people."

Work proceeds through blocks 1–5 regardless; neither answer blocks them.
