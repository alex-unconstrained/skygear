# NEEDS ALEX

Things only you can unblock or decide. The loop keeps this current: items
appear when they block work, disappear when resolved (git history is the
record). Board IDs refer to `skygear-godot/docs/BOARD.md`.

_Last updated: 2026-08-01_

## Blockers

None hard. **Soft (SG-12):** the Pro Melee Axe Pack archive and the captain's
Meshy rig archive are absent from this machine, so `ingest_model.py`'s archive
path cannot re-extract raw clips. It did not block route 2 — the Boilerwright's
fourteen clips were retargeted from the captain's on-disk baked library instead
(`tools/retarget_library.gd`) — but ADDING a brand-new Mixamo clip (see the
decision below) needs the raw FBX from you, or those two archives restored to
`~/Downloads`, before the same retarget can bring it in.

## Decisions

**3 · Boilerwright mobility gap** (SG-7) — *you took this one* (2026-08-01:
"I'll test boilerwright movement myself"). The deterministic number when you
do: he covers 40% of a dashing captain's ground. Report back what it feels
like and whether the comparison screen should say the trade louder.

**4 · The captain is 30,634 triangles, 4–10× the project's own budget** (SG-13)
She was rightly skipped by the prop remesh (it would destroy her skin
weights). Options: local skin-weight-preserving decimation, a hand-authored
LOD, or accept the cost and record it. **Recommendation: accept for now** —
she's one asset, the build runs at half frame budget, and both alternatives
risk the one rigged character that works.

**5 · The Boilerwright's model is in — two calls for your eyes** (SG-12, route 2
delivered). He now has his own Meshy body: a broad, heavy, bearded engineer,
auto-rigged and moving on the captain's fourteen clips (the same clock — the
point of route 2). Two things need you:
  - **The belt pouches.** All three A-pose generations came back with belt
    pouches — Meshy will not draw a beltless engineer, even prompted against it
    three times. I kept the cleanest (two tight hip pouches, no hanging tools).
    They sit on the near-rigid pelvis and read small at the 41° camera, but they
    are technically the "no over-accessorizing" rule bent once. Accept, or say
    the word and I re-roll (20 credits a try).
  - **Two clips would make him HIM.** His fourteen are the captain's axe swings,
    and an axe swing reads wrong for a man who fights by cracking steam mains:
    the melee attacks (`swing`/`swing2`/`swing3`/`spin`/`combo`) look like
    sword-work, and there is NO clip for his signature — planting a Tap Main at
    his feet (CLASS-2 §7 names this exact gap). If you add Mixamo animations, the
    two worth most are **a kneel/press-to-deck** (for Tap Main) and **a heavy
    two-handed wrench or hammer swing** (to replace the light axe cuts). Hand me
    the FBX and the retarget path (`tools/retarget_library.gd`) brings them in.

**6 · His tool is unbuilt on purpose** (SG-38, filed unpriced). His hands are
empty by the standing rule — a pipe wrench is a separate bone-mounted mesh, the
cutlass pattern. Approve SG-38 and I generate + fit it.

*(Resolved 2026-08-01: #2 Boilerwright route — route 2 approved AND delivered,
SG-12; #5 chromatic/radial — dropped, recorded in VFX-PLAN §5.)*

## Check when you next play

- **Text legibility** (SG-9, fixed): the real hole was windows under 1600px
  downscaling every label to ~8 physical pixels; the window now enforces a
  1600×900 minimum and the audit measures physical size. But if 12px text
  at 1920 *still* feels small to you, say so — that's a deliberate
  grow-the-boxes layout pass, a different job, and it needs your eyes first.
- **Enemy telegraphs** (SG-3, rebuilt): melee windups now draw the browser's
  filled danger wedge at the true swing arc; melee reach shifted a few units
  to match the browser exactly (ARMORED slightly longer, SWARM slightly
  shorter). Worth a feel-check that nothing reads unfair.
- **SHOVE THE CRATE** (SG-37, reworked — in the next build): the hold-to-heave channel is gone (instant tap-shove, ~1s cooldown) and the crate can never block you now, only boarders — re-judge the fun; if it still isn't there, it gets dropped.
- **Cutscenes** (SG-8, all five cues now filled): a 2.5s run-opening reveal,
  1.4s flourishes on waves 4 and 8, a 5.4s victory crane-up to the horizon
  (the one angle gameplay never shows), and a 3.6s defeat push onto the
  Boiler. All skippable with click/space. These are taste calls made by an
  agent — your eyes needed.
- **Heat 3–5 exist now** (SG-14): COLD DECK (thinner drafts), BOARDERS ALOFT
  (a hulk every second wave), SKELETON CREW (no crew, half cannons), behind a
  five-rung ladder on the title. The balance bot says the grade is real —
  but it also went 0/6 at Heat 3 and died on wave 4 every time at Heat 5.
  The bot is not you; whether the upper rungs are brutal-fair or just brutal
  is a feel-call for a human clear attempt.
- **The Colossus wreck** (SG-15) now floats off the bow after your first
  Colossus kill — visible when you push forward, subject of the run-open
  crane. Judge whether it earns its place.
- **Build 32 is on itch** (pushed 2026-08-01): telegraphs, legibility floor,
  Boiler scale, the heave verb, crate x-ray, five cutscene shots, Heat 3–5 +
  ladder, the wreck — everything above in one build at
  https://alex-unconstrained.itch.io/skygear-godot-test
