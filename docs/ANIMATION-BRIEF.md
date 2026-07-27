# Animation brief — every character, every state

Approved scope: run, attack and idle cycles for the whole cast. This is the
largest single asset workstream in the project and it will not fit as loose
PNGs, so read §1 before generating anything.

---

## 1 · Deliver atlas strips, not loose frames

The two existing cycles ship as 28 separate 512×512 PNGs and cost **3.9 MB** —
more than every still asset combined. Extending that shape to the full cast is
roughly **270 files and 33 MB**, on top of 16 MB of stills. That is not a
loading screen problem, it is a "nobody on hotel wifi ever sees the game"
problem.

So: **one PNG per cycle, frames laid out left to right in a single row.**

| | |
|---|---|
| **Layout** | Horizontal strip. Frame 1 leftmost. No padding, no gutters, no trim. |
| **Frame size** | **384 × 384** for everything except the Colossus, which is 512 × 512. |
| **File** | `assets/animations/<character>_<state>.png` — one file, e.g. `scrapper_run.png` |
| **Canvas** | `384 × (384 × frameCount)` wide. A 10-frame cycle is 3840 × 384. |

Three reasons beyond file count: one PNG shares a single compression dictionary
across all frames and lands roughly 20–30% smaller than the same frames
separately; it is one request instead of thirteen; and every frame is
guaranteed identical in size, which is what stops a figure jittering as its
silhouette changes.

**Every frame in a strip must share one crop.** The character's feet must sit at
the same pixel row in all frames and the body must not drift horizontally. The
engine measures the strip once and applies that anchor to all frames — it cannot
correct per-frame drift, and drift reads as the character sliding on the deck.

Keep the existing `hero_front_run` and `scrapper_front_run` loose frames as they
are; I will convert them. New work is strips.

---

## 2 · Frame budgets

Frame count is the entire cost lever. These are ceilings, not targets — a
readable 8-frame run beats a mushy 14-frame one.

| State | Frames | Notes |
|---|---|---|
| **idle** | **6** | Breathing, a slight weapon shift. Loops. Seen constantly, so it must not draw attention. |
| **run** | **10** | Full contact-to-contact cycle. Loops. |
| **attack** | **8** | Wind-up → strike → recover. **Does not loop** — plays once and returns to idle. |

| Character | Size | Cycles | Notes |
|---|---|---|---|
| Captain (`hero`) | 384 | idle, run, attack | Highest priority. Her attack fires every 0.36 s. |
| `scrapper` (automaton) | 384 | idle, run, attack | Most numerous enemy. |
| `swarm` (gremlin) | 384 | run, attack | No idle — it never stops moving. |
| `gunner` (drone) | 384 | idle, attack | No run — it hovers and repositions slowly. |
| `armored` (furnace knight) | 384 | idle, run, attack | Slow and lingering, so its idle is on screen a long time. |
| `crew` (your allies) | 384 | idle, run, attack | Six on screen at once; readability matters more than detail. |
| `colossus` (boss) | **512** | idle, attack | Wave 12 only. No run — it walks in the attack rhythm. |

**19 cycles, ~160 frames.** At 384 in strips that should land near **12–14 MB**,
which is the budget. If a cycle comes in far over, cut frames before quality.

---

## 3 · What the engine does with them

- Strips are decoded once and drawn frame by frame; no per-frame requests.
- **Timing is engine-side, not baked.** Play rate comes from the manifest
  (12 fps default) and run cycles are scaled by actual movement speed, so a
  slowed enemy animates slower. Do not pre-time anything into the frames.
- **Attack cycles are triggered, not looped**, and are cut short if the attack
  is interrupted. Front-load the readable pose: the strike should land in the
  first third, because that is what the player sees before the sprite changes
  again.
- Every frame is mirrored horizontally for right-facing. Strongly asymmetric
  detail will be seen flipped.
- The still `*_front_idle.png` assets remain the fallback for any character or
  state without a cycle, and for the first frames before a strip finishes
  decoding. **Do not delete or replace the stills.**
- Back views stay still-only. Animating them costs as much as front views and
  they are seen a fraction as often.

### Manifest entry I will add per cycle

```js
hero_attack: {
  file:'assets/animations/hero_attack.png',
  frames:8, w:384, h:384, fps:12, loop:false,
},
```

You do not need to edit this — tell me the file and frame count and I will wire
it, same as the still manifest.

---

## 4 · Style — unchanged, and it matters more here

Everything in `skygear-visual-asset-spec-v1.md` and the camera lock in
`LEVEL-KIT-BRIEF.md` still applies. Two that bite specifically on animation:

- **Billboards stay upright, 10–15° above horizontal.** A figure that pitches
  over during a cycle will read as falling.
- **The moonbreak is upper-left.** Lighting must not swim between frames — a
  highlight that migrates across a cycle reads as the light source moving, which
  is worse than no lighting at all.

---

## 5 · Order

Ship in this order; each row is independently useful and I will wire each as it
lands rather than waiting for the set.

| # | Cycles | Why |
|---|---|---|
| 1 | `hero_attack`, `hero_idle` | Her attack is the most-seen frame in the game since the cleave became the auto-attack. |
| 2 | `scrapper_attack`, `scrapper_idle` | Most numerous enemy; run cycle already exists. |
| 3 | `crew_*` (3) | Six allies on screen and currently the least animated thing in frame. |
| 4 | `armored_*` (3), `swarm_*` (2) | Armoured lingers; swarm is always moving. |
| 5 | `gunner_*` (2) | Hovers, so it changes least. |
| 6 | `colossus_*` (2) | Wave 12 only, but it is the finale. |

---

## 6 · Check before sending

```
python src/check-animations.py          # frame count, uniform size, drift
```

It reports, per strip: declared vs actual frame count, whether the canvas
divides evenly by frame width, and whether the figure's alpha bounds stay put
across frames — the drift check being the one that catches sliding feet, which
is invisible in a contact sheet and obvious in motion.
