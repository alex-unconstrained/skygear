# SKYGEAR — feedback and bug tracker

Everything reported from a playtest, in one place, with what is known about the
cause and what has been done about it. **Tracking only unless an entry says
otherwise** — the standing instruction is not to get ahead of the Godot port
with browser-side rewrites, so this file records and diagnoses; it does not
assume anything gets fixed here.

The rule for an entry: **what was reported, in their words**, then what is
actually known, kept apart. A hypothesis is labelled as one until something
measures it.

| Status | Means |
|---|---|
| `OPEN` | reported, not diagnosed |
| `DIAGNOSED` | cause identified, not fixed |
| `FIXED` | fixed and verified, with what verified it |
| `CONFIRMED-GOOD` | reported as working; do not "improve" it without a reason |

Running version history: [VERSIONS.md](VERSIONS.md). Current plan:
[V12-PLAN.md](V12-PLAN.md).

---

## Session 2026-07-27 · v11 build `d27b694`

Second playthrough, after the healing ceiling, the frame-budget fix, the
camera-tied envelope and the airstream landed.

---

### F-01 · Audio makes it progressively laggy, and muting does not fix it `FIXED`

> "turned sound on (was muted) and we got crazy lag spikes. turned it back off
> and its still crazy laggy. fresh restart resolved it. memory leak?"

**Almost certainly yes, and the shape of the report identifies it.** Three
details together are diagnostic: it got worse over time with audio on, muting
stopped it getting worse but did not recover, and a page reload cleared it. That
is an accumulating resource that mute cannot release and reload can.

**The likely cause** is in `Sound.sample` (`src/storm-dusk/_audio.js`). Every cue
builds a `BufferSource`, a `GainNode` and sometimes a `StereoPanner`, connects
them to a bus, and starts them. When the source finishes, `onended` marks the
record `done` and the record is pruned from `_voices[key]` on the *next* call for
that key — but **nothing is ever `disconnect()`ed**. The gain node stays wired to
a live bus, so it stays reachable, so it is not collected. A five-minute run
fires thousands of cues; each one leaves a node behind on the graph, and Web
Audio's cost per node is paid every render quantum whether it is producing sound
or not.

That also explains the part that looks contradictory: `Sound.sample` returns
early when `muted`, so muting stops *new* nodes being created but does nothing
about the several thousand already connected.

**Why explosions made it worst** — see F-02. They are the moment the game creates
the most audio nodes at once.

**The fix, when it is time:** disconnect in `onended` —

```js
src.onended = () => { rec.done = true;
  try { g.disconnect(); if (rec.pan) rec.pan.disconnect(); } catch (e) {} };
```

**Fixed 2026-07-27**, because the build testers are playing should not have a
measured leak in it — this is three lines, not a rewrite, and it is not the kind
of browser-side investment the Godot instruction was about.

`onended` now disconnects the gain, the panner and the source; hand-stopped
voices (a stolen voice, a stopped loop) go through a shared `Sound.release`;
and `Sound.nodesMade` / `nodesFreed` count both sides.

**Measured, before and after.** `tools/profile.mjs` now counts `Sound.sample()`
calls as well as canvas calls, and a saturated wave-11 fight asks for **~515
cues per second** — every one of which used to leave a node set connected to a
bus. The harness fires 400 cues and asserts what is still connected afterwards:

```
leak · audio nodes are released, not merely marked done
       0 still connected after 400 cues (made 400, freed 400)
```

That check had to be fixed twice before it was worth anything, which is worth
recording: the first version waited on the wrong condition, timed out, and
reported SKIPPED as a pass; the second fired `hit` 400 times and created exactly
one node, because `hit` has a 30ms retrigger floor. A green line that tested
nothing is the most expensive kind of check.

---

### F-02 · Lag when blowing up lots of enemies and barrels `FIXED (pending a tester)`

> "lagging happened when blowing up lots of enemies and barrels"

Consistent with F-01 and with a second, smaller thing.

**A keg chain is the peak audio event in the game.** One keg detonating into a
crowd calls `damageArea`, which calls `hitEnemy` per target, which calls
`SFX.hit()` per target — so a chain across forty boarders creates on the order of
a hundred audio node sets in a single frame, each one leaking per F-01. That is
both the spike and the accelerant.

**Second suspect, unverified:** `S.nums` (floating damage numbers) has no cap,
and text is among the most expensive things a 2D canvas draws. `S.fx` was capped
in `d27b694` and `S.nums` was not.

**Now measured, and it was the audio.** The profiler counts audio calls as well
as canvas calls, and the answer is that a keg chain is not expensive to *draw* —
it is expensive because every enemy it hits plays a sound, and every sound leaked
a node set. With F-01 fixed the spike source is gone; what remains to confirm is
whether the tester still sees it.

`S.nums` is still uncapped and text is still expensive on canvas. Left as a
suspect rather than a finding, because nothing has measured it hurting.

---

### F-07 · "Lag triggered by lightning or screen shake perhaps" `DIAGNOSED — the guess was half right`

Worth writing out, because the guess pointed at the right *trigger* for the
wrong *reason*, and only measuring it separated the two.

`tools/profile.mjs --arc` builds the tester's actual loadout — all Arc, chain
heavy — sets trauma to maximum so the frame is shaking, and counts one frame:

| build | canvas calls | audio cues/sec |
|---|---|---|
| all-Arc, chains, shaking | **7,063** | 515 |
| mixed elements, no shake | **8,158** | 516 |

So chain lightning is *cheaper* to draw than the mixed build, and screen shake
costs nothing in draw calls — it translates and rotates a frame that is fully
repainted anyway. Neither is the cause.

What lightning and keg chains have in common is not visual: **they are the two
things in the game that hit many enemies per action**, and every hit plays a
sound (F-01). The tester noticed lag around lightning because lightning was
generating the most audio nodes per second, not the most pixels.

---

### F-03 · Air movement should be constant, and should react to sideways movement `OPEN`

> "make the air movement vfx more constant and even trigger when player moves
> sideways."

Feature request, and the second half is the interesting one: the airstream
currently runs at a fixed rate along the keel regardless of what the captain
does. Reacting to lateral movement would mean the streaks skew with the player's
velocity — which is a genuinely different claim than "the ship is moving": it
says *you* are moving through air.

Rough shape: a persistent base rate (higher than now — "more constant" reads as
"currently intermittent"), plus a shear term driven by `P.vx` so the streaks lean
against sideways motion, plus a short burst on dash. All in `drawAirstream`
(`src/storm-dusk/_render_world.js`); no simulation involvement.

---

### F-04 · Sway/yaw is too subtle to notice `OPEN`

> "sway/yaw was very subtle. player didnt notice much even after being told."

Fair, and expected: what shipped in `d27b694` is a cloud-band bob of about 0.6%
and 1.0% of screen height. The ±0.4° frame roll described in `V12-PLAN.md` §3 was
*not* built, precisely because it is the one most likely to interfere with
aiming.

If a player cannot see it after being told it is there, it is not doing anything
and should either be made real or removed. "Made real" means the frame roll, and
it wants its own playtest question: does aiming still feel accurate.

---

### F-05 · Health drops feel too frequent alongside the vent heal `OPEN`

> "health drops seem maybe too frequent with the additional steam valve heal."

Note the distinction from F-06: the *amount* of healing is right now, the
*frequency of the pickup event* is not. Those want different fixes — this is
about how often a green thing appears on the deck, not about hit points.

Current values in `d27b694`: close kills drop salvage 10% of the time at 6 hp;
SCRAPPER'S LUCK adds 15% at 12 hp and can only be taken once; crates drop one at
12 and often a second at 8.

Likely right answer: **fewer, larger drops.** Same hit points per wave, a third
as many pickups, each worth going to get. Also worth considering: crate salvage
only, no drop from kills at all, so salvage becomes a thing the *deck* gives you
rather than a kill reward — that would also reinforce the ordnance loop.

---

### F-06 · Health balance `CONFIRMED-GOOD`

> "health balance feels good"

The 12 hp/s ceiling across all healing, the vent at 10 hp on a 2.0s floor, and
FIELD DRESSING paying below 60% only. **Do not re-tune these without a reason
that is not F-05** — F-05 is about pickup frequency, and fixing it by cutting
healing would undo this.

Enemy damage was deliberately left alone in `d27b694` pending exactly this
answer. It stays alone.

---

## Open questions for the next test

1. Does the lag survive **F-01's fix**? That is the single question that decides
   how much of the performance story is the platform and how much was ours.
2. With the frame roll actually visible (F-04), does aiming still feel accurate?
3. Did they ever choose to fight at range — still unanswered from the previous
   round, and still the question that tells us whether the close-quarters loop is
   a choice or a treadmill.

## Not tracked here

Anything already in a plan document with a decision attached: the animation
queue, the five music slots, the art compression pass, and the Godot port's four
measurements all live in `V12-PLAN.md`. This file is for what testers hit.
