# SKYGEAR — road to a testable MVP

**Where we are.** Three playable builds off one simulation. Classic (top-down) is
complete against the original one-shot spec and verified: all 24 shape×element
combos deal damage and apply their element, all 34 draft cards apply cleanly,
a headless run clears 12 waves to the victory screen, both loss conditions fire.
Storm-Dusk is the same game under the Cinderia-style renderer from the visual
spec — projected ground plane, billboards, storm-dusk palette — with procedural
stand-ins for all 66 art assets.

**What an MVP is for here.** Not a finished game. A build where one question can
be answered honestly: *is shape × element + draft a loop people want to repeat?*
Everything below is ordered by how much it moves that question, not by how
interesting it is to build.

---

## Phase 0 — Ship what exists · **done**

Deployed as a static site. Two builds behind one landing page so the restyle is
an A/B test rather than a leap of faith.

**Exit:** a link a stranger can click. ✅

---

## Playtest 1 result — and what v3 changed

**Verdict: Classic played better than Storm-Dusk.** Both the tester and Alex
agreed. That is a real result and it was acted on rather than argued with.

**Root cause.** Not polish — geometry. The Boiler's billboard stood 210 units
tall against a 120-unit boarder, and at the spec's 0.72 rad pitch that silhouette
covered the deck from the Boiler back to roughly 465 units behind it. On a
1360-deep deck, **over a third of the arena was blind, and it was precisely the
far side of the objective** where boarders do their damage. A defence game was
hiding the thing you defend behind the thing you defend.

**v3 (`storm-dusk-v3.html`) addresses it four ways:**

| Change | Why |
|---|---|
| **Occlusion x-ray** | Anything hidden behind the Boiler, a mast or a crate stack is re-drawn on top as a coloured rim with a dark interior. Rims, not solid fills, so a pile of boarders stays countable. This is the actual fix. |
| **Bounded follow camera** | The tester's suggestion. The camera tracks the captain so you can walk round and take an angle. Leashed to the deck, not to the Boiler — an earlier build clamped to keep the objective framed and could push the *captain* off screen at the bow, which is far worse. The Boiler gets an edge marker with its health instead. |
| **Deck lengthened 1360 → 2240** | Also the tester's suggestion. More room to manoeuvre, and it gives the follow camera something to do. Deck dressing is now authored in normalised coordinates so one table dresses any deck length. |
| **Pitch 0.72 → 0.86, Boiler 210 → 132 tall** | Attacks the problem at source. A steeper camera and a flatter engine block shrink the blind band directly, and steeper pitch also evens out the depth foreshortening that made aiming into the distance feel inconsistent. |

v3 clears all 12 waves to victory in a headless run and holds ~82 fps.

> ### ✅ RESOLVED — bake at 49°, render at 41°
>
> **Superseded an earlier call in this document.** I first said "keep 40°, stand
> down the 49° set". That was wrong, and the reason is worth recording: the test
> varied *engine pitch* against one fixed 40° bake, which could only ever favour
> the bake being held constant. It also let pitch changes silently re-frame the
> whole shot, so it was partly comparing composition.
>
> With framing made pitch-invariant and the sets compared as matched pairs, the
> answer inverts:
>
> | | |
> |---|---|
> | **Asset bake** | **49°** — reads as genuinely looked-down-at. The 40° trial reads near eye-level and sits like a standee. |
> | **Engine pitch** | **0.72 rad / 41°** — a steeper camera badly compresses the depth *ahead* of the captain, which matters more as the design goes lane-based. |
>
> Painting slightly steeper than the camera is the right error: figures read as
> grounded. The reverse is what looks broken. The `production_49deg` work was
> not wasted — it is the set to continue from.
>
> Swap and re-judge any time: `?art=40` / `?art=49`, `?pitch=`, `[` and `]`,
> with both shown in `F3`.

### What the trial roster taught us about the pipeline

Three findings, all cheap to act on and all worth fixing before 62 more arrive.

**1 · The 40° trial bake was too shallow; the 49° bake is the keeper.**
The trial assets read closer to 10–15° above horizontal — face straight on, no
top-of-head, no foreshortening — which sits like a standee on a projected floor.
The `production_49deg` set reads correctly looked-down-at. Reword §1.4 and §4 to
describe the 49° pose, and note that the engine renders at 41° deliberately.

**2 · Feet anchors vary, and the engine now absorbs it.**
Measured across the four: feet landed at 79.7%, 85.6%, 88.5% and 88.7% of
canvas height against the §2.4 target of ~92%. Rather than bounce them back,
the loader now measures each sprite's alpha bounds and derives its own anchor,
horizontal centre and figure height, so `worldH` sizes the *figure* rather than
the canvas. Any crop now lands on the deck at the right size. Consistency is
still worth aiming for, but it is no longer load-bearing.

**3 · Missing back views will pop to placeholder.**
§4.2 gives only the melee grunt a `back_idle`; the tank, ranged and swarm get
front views only. The moment one turns away from the camera it falls back to
the procedural stand-in, which is a completely different look. Boarders mostly
walk *toward* camera so this is rarer than it sounds, but **ARMORED / Furnace
Knight is big, slow and lingers on screen — it should get a `back_idle`.**
The hero already has one specified, which is right: the captain walks away from
camera constantly.

**Still open after v3:** whether the follow camera is actually better than a
fixed one for a *defence* game. Holding a fixed objective may simply want a
fixed view. That is what the next test is for — all three builds ship side by
side so it is a comparison, not an argument.

---

## Phase 1 — Make the test produce evidence · **~half a day**

Right now a tester plays and you learn vibes. This is the highest-value work in
the document and it is cheap.

| # | Item | Notes |
|---|---|---|
| 1.1 | **Seeded runs** | All randomness already funnels through `rnd()`/`chance()`/`rollCards()` — only **4 raw `Math.random()` call sites** exist, one of which is the audio noise buffer. Swap in a small xorshift PRNG, accept `?seed=`, show the seed on the end screen. ~10 lines. |
| 1.2 | **Run log** | On death/victory write `{seed, wave, cause, kills, damage, bestCombo, timeAlive, slots[], cards[]}` to `localStorage`. No server, no accounts. |
| 1.3 | **Copy run report** | One button on the end screen that puts a compact text summary on the clipboard. Testers paste into Discord; you get structured data without building a backend. |
| 1.4 | **Personal best** | Show best wave reached on the title screen. Costs nothing, and it is the cheapest retention hook that exists. |
| 1.5 | **Build string** | Render the loadout as e.g. `Ember Cleave / Frost Mortar / Arc Whip / —` in the report so builds are comparable across testers. |

**Exit:** after ten sessions you can state, with numbers, which wave kills people
and what they build on the way there.

---

## Phase 2 — One codebase · **~half a day**

Two divergent builds is a tax that compounds every gameplay change. Today
`src/storm-dusk/_core_patched.js` is produced by *text-substituting* the classic
file — brittle, and it will silently rot the first time the two drift.

| # | Item |
|---|---|
| 2.1 | Promote the shared simulation to `src/core/` as the single source of truth (tuning, data tables, systems, sim loop — everything above the render banner). |
| 2.2 | Replace the patch script with a **`WORLD_PRESET` object** — deck dimensions, palette, element colours — that each build passes in. Config, not string surgery. |
| 2.3 | Both builds' `build.py` concatenate `core + preset + renderer`. One command builds both. |
| 2.4 | A smoke test that runs the headless 12-wave playthrough against **both** builds and fails loudly on a regression. |

**Exit:** a balance change lands in both builds from one edit, and CI-ish proof
that neither broke.

> **Decision to make after the first playtest, not before:** whether Classic
> survives. It exists as the control for the camera change. If Storm-Dusk reads
> as well or better, delete Classic and this phase gets cheaper permanently.

---

## Phase 3 — Close the gaps that make the test unfair · **~2 days**

| # | Item | Why it blocks a fair test |
|---|---|---|
| 3.1 | **Verify frame rate on real hardware** | Genuinely unresolved. Large optimizations landed (baked deck, sky, HUD glyphs, enemy sprite atlas — roughly an order of magnitude fewer draw calls), and a clean measurement showed 239fps idle with 400 particles free. But the 200-entity case could never be measured: the browser driver caps calls at 30s and a saturated page starves its own control channel. **`F3` is in both builds — one glance on real hardware settles it.** If it is under 60, the next lever is an LOD pass on distant billboards. |
| 3.2 | **Balance with an honest autopilot** | The headless run that won 12 waves had HP and Boiler cheats on. Re-run it clean, sweep difficulty, and find where an average player actually stalls. Target: a competent player wins ~1 run in 3; a first-timer reaches wave 5–7. |
| 3.3 | **Depth-aiming feel (Storm-Dusk only)** | Cursor→ground unprojection is mathematically right, but enemies at the far end are small and aiming into depth is unproven by human hands. Likely fixes if it feels bad: a minimum billboard scale, a slightly shallower pitch, or a subtle target highlight under the cursor. |
| 3.4 | **Unimplemented spec content (Storm-Dusk)** | `E5 Rigging Wraith` has no gameplay counterpart; the ground decals (`decal_scorch`, `decal_oil`, `decal_gear_scatter`) and `colossus_wreck` are declared in the manifest but never spawned. Each is small — decals on kill, a wreck prop after the boss dies. |
| 3.5 | **Audio fatigue pass** | Fifteen cues, no variation. Add ±8% pitch jitter and a same-frame voice cap. An hour of work; the difference over a 20-minute session is large. |
| 3.6 | **Volume in the pause menu** | Currently keyboard-only. Testers will not read the key list. |

**Exit:** nothing in a tester's feedback is attributable to a rough edge you
already knew about.

---

## Phase 4 — Art integration · **gated on art delivery, not on us**

The pipeline is already built and waiting.

| # | Item |
|---|---|
| 4.1 | Generate the 66 assets per the visual spec manifest. **External dependency — the long pole.** |
| 4.2 | Drop files at their spec paths under `assets/`; run with `?assets=1`. The loader already replaces stand-ins **one file at a time**, so this is incremental, not a big-bang swap. |
| 4.3 | Run the §5 QA checklist per asset — especially the 40° angle and the "reads against `#14121B`" test. |
| 4.4 | Style-drift check every 10 assets against `corsair_front_idle.png`. |
| 4.5 | Re-tune billboard world-heights (`BILLBOARD_H`) once real sprites land — the stand-ins set the current proportions. |

**Exit:** zero procedural stand-ins remaining, and the QA checklist passes.

> Note: real PNGs require serving over http — browsers block `file://` image
> reads. The deployed site already satisfies this; local work needs
> `python -m http.server`.

---

## Phase 5 — Retention · **only if Phase 1 says the loop works**

Do not build any of this until the data says the core is worth extending.

| # | Item |
|---|---|
| 5.1 | **Endless mode** past wave 12 with continued scaling — turns a 7-minute demo into a score chase. |
| 5.2 | **Starting-loadout variety** — the 2011 deck had four characters. Even three fixed starts would triple perceived replay value for very little work. |
| 5.3 | **Relics** — the visual spec's UI already anticipates them (five relic icons sit unused in the manifest). A second upgrade axis alongside the draft. |
| 5.4 | **Wave modifiers** — occasional "this wave: all boarders are armoured" style twists to break the fixed 12-wave script. |

**Exit:** median session is more than one run.

---

## Explicitly out of the MVP

Naming these now so they do not creep in:

- **Mobile / touch** — the game is mouse-aim at its core; a touch scheme is a redesign, not a port.
- **Co-op** — it was C-tier in the 2011 deck and it is C-tier now.
- **Music** — the original spec said not to build a music system. Still right.
- **Meta-progression / unlocks** — earn the right to build this with Phase 1 data.
- **Accounts, servers, leaderboards** — `localStorage` and a copy-paste report answer every question the first playtest asks.

---

## Open risks, honestly

| Risk | Standing |
|---|---|
| **Frame rate at full crowd** | Unverified, not unaddressed. `F3` on real hardware resolves it in seconds. Highest-uncertainty item in the document. |
| **The three-quarter camera may cost readability** | Real possibility. Mitigated by shipping Classic alongside as a control rather than arguing about it. |
| **Balance is machine-tested only** | No human has played a full run. Phase 3.2 plus the first playtest fixes this; expect the curve to be wrong somewhere. |
| **Art is external and is the long pole** | Everything else can finish without it. The stand-ins mean art is never a blocker to testing, only to shipping. |
| **Two codebases drifting** | Real today. Phase 2 removes it; until then, gameplay edits must be made twice. |

---

## Suggested order

```
Phase 1  ──► first playtest ──► Phase 3.1 + 3.2 (act on data)
   │                                  │
   └──► Phase 2 (in parallel)         └──► Phase 5 (only if the loop holds)

Phase 4 runs alongside all of it, as art arrives.
```

Phase 1 before anything else. A test you cannot learn from is worse than no
test, because it feels like progress.
