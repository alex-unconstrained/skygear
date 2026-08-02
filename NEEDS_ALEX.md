# NEEDS ALEX

Things only you can unblock or decide. The loop keeps this current: items
appear when they block work, disappear when resolved (git history is the
record). Board IDs refer to `skygear-godot/docs/BOARD.md`.

_Last updated: 2026-08-02_

## Blockers

None hard. **Soft (SG-12):** the Pro Melee Axe Pack archive and the captain's
Meshy rig archive are absent from this machine, so `ingest_model.py`'s archive
path cannot re-extract raw clips. It did not block route 2 — the Boilerwright's
fourteen clips were retargeted from the captain's on-disk baked library instead
(`tools/retarget_library.gd`) — but ADDING a brand-new Mixamo clip (see the
decision below) needs the raw FBX from you, or those two archives restored to
`~/Downloads`, before the same retarget can bring it in.

## Decisions

*(Answered 2026-08-02, 00:30, before sleep: stowage stays cut — variety
belongs to ENEMIES within runs, ship modification happens BETWEEN runs
(fittings reframed and unblocked); wrench + scrapper pilot both approved
(~45 credits); captain's triangle cost accepted and recorded; the pouches
accepted. All in motion.)*

**0 · The post-parity plan is written — skim it first** —
`skygear-godot/docs/POST-PARITY-PLAN.md`, produced overnight by a 3-designer /
2-judge / 1-synthesis workflow per your ultracode instruction. Two threads:
the ship becomes the second character (stowage variety, earned fittings, the
berth screen), and the figures come alive (the Boilerwright's kneel, a
one-enemy animation pilot before scaling). Its decisions for you, each with
the plan's recommendation:
  - **Stowage kill-test threshold** (item 2): what close-share difference
    counts as "real variety"? Recommendation: accept the plan's band and let
    the measurement decide. **MEASURED 2026-08-02 (board SG-48): it decided.**
    Close-share over 60 runs per config came back 5.38% live vs 5.25% flat —
    indistinguishable — so the seeded variety was cut per the plan's own
    pre-committed rule, not tuned. The full spine (third RNG stream, STOWAGE
    table, `tools/stow.gd`) is preserved at commit d10f09c: if you want the
    cosmetic variety anyway (it costs nothing and reads as twelve different
    decks), or want the test re-run with a better bot than balance.gd's
    long-range kiter, say so and it is one revert away. The numbers are on
    the SG-48 board row.
  - **Fittings** (item 3): confirm the six named fittings + one-per-run cap,
    and whether Heat rows record fitting count (recommended) or Heat runs
    sail bare. **BUILT 2026-08-02 (SG-56) awaiting that confirmation** — the
    midnight answer reframed the mechanism (between runs, deck-only, never
    mid-run) but did not enumerate the six, so they shipped as: THE WRECK
    (first Colossus kill), BOW BARRICADE (clear wave 8), SPARE GUN (win at
    Heat 1+), FOURTH VENT (Boilerwright win), THE WINCH (12 salvage in one
    run — grants the tap-to-haul verb), SCUPPER GRATING (unhealed win).
    Two earn rules were adapted to fields the run row records (the doc's
    cannon-loss and repair-count rules had no data); the Heat call went the
    recommended way — the run row records `ship: [ids]`, Heat runs may sail
    fitted. Say the word on any of the six and it is one table row.
  - **SG-38, the wrench** (~35 credits, item 6): approve and he gets his tool
    fitted in the lab.
  - **The scrapper animation pilot** (item 7): one enemy first, ~10 credits,
    before any talk of animating all four. Recommendation: approve the pilot.

**8 · Tempo's balance verdict is yours to call — the numbers are in, the
threshold is not** (SG-57, built 2026-08-02). The wave-rhythm variety
(ENEMY-VARIETY-DESIGN §2.2 — STEADY/SURGE/CRESCENDO dealt per wave by seed)
shipped tonight on its QUEUE kill-test, which passed decisively: SURGE's
inter-spawn gaps are bimodal (219 at the 0.22 metronome, 48 in the 4–6 s
lulls, zero in the 1–3 s valley across 12 seeds) where STEADY's are a single
point mass — a harness check now pins it. The softer half — six-seed
damage-taken via `tools/balance.gd`, 60 runs live vs 60 flat — came back
INSIDE the noise on its named metric (within-run wave-sd 4.95 vs 4.89,
t≈0.38; damage-taken mean 34.6 vs 35.7, t≈−0.61), and §1's rule says the
noise floor and the threshold are measured and filed for you, not invented at
midnight, so that half is OPEN-pending your call rather than declared or cut.
**One number you should look at before ruling:** the bot HELD 23/60 with the
tempo live against 34/60 flat (z≈2.0, avg wave 11.00 vs 11.30). If that is
real, SURGE's simultaneity is a difficulty shift and §1 says difficulty is
Heat's job — but the bot never repairs and never shoves, which is exactly
what a lull invites and a pulse punishes, so it may be a bot fact (the SG-48
lesson: its long-range kiting was why stowage read as nothing).
Recommendation: play two runs with it live — the rhythm is the most legible
variety there is — and either accept, or say the word and SURGE's pulse cap
drops from 4 to 3 for a re-measure. The flat lever (`SKYGEAR_TEMPO_FLAT=1`)
reproduces today's rhythm exactly, checked byte-identical, if you want it off
while deciding.

**7 · The scrapper pilot stalled at Meshy's front door — 0 of your ~10 credits
spent** (SG-55, blocked 2026-08-02). The rig endpoint refused the scrapper five
times over ("Pose estimation failed", never charged): its arms are welded
against the spherical torso and the head has no neck — the mesh predates your
T-pose standing rules, exactly as POST-PARITY-PLAN item 7 warned. The pipeline
itself is fine (the Boilerwright sailed through the same path for 5 credits),
and everything around the rig is already landed and waiting: the SG-45 guards
now cover boarder scenes, the run-cycle speed sync is fixed for half-height
figures, and `tools/clip.gd -- scrapper` films the walk-and-swing witness (it
shows the statue-glide today). **The call:** approve ~40 credits to restart —
regenerate the scrapper to the standing rules (keep the hooks and the hunch as
identity, hold the arms clear, give it a neck; ~30) + remesh (5) + rig (5) —
and the pilot resumes at one models.json entry and one retarget run.
Recommendation: approve. Cheaper alternative if you would rather not respend on
this mesh: say which boarder to try instead — a refused rig submission costs
nothing, so candidates can be tested for free before a credit moves.

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

**6 · His tool — DELIVERED** (SG-38, approved 2026-08-02, built the same
night). The pipe wrench is generated, remeshed to the prop budget, and fitted
to his right hand in `assets/models/weapons.json` — the cutlass pattern,
40 credits of the ~35 you approved (one meshy-5 second opinion was bought and
rejected; the story is in the manifest comment at `tools/meshy.py`). The fit
was placed numerically and verified at rest and through `swing2`
(`.shots/wrench/`); it reads right at the 41° camera, but a perfect grip is
your two minutes in the lab — `model_lab` now takes `--fit boilerwright` so
SAVE writes HIS row, not hers. Two honest marks on the mesh, recorded on the
SG-38 board row: a small linkage dangles at the worm screw and the butt forks
into two rings — both turned toward his body by the fit, both invisible at
game scale. Re-roll is one command if they bother you.

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
  crane. Judge whether it earns its place. **Since SG-56 it lives in the
  berths**: your existing save migrates it in, earned and berthed.
- **THE BERTHS** (SG-56, new): a button under THE WORKSHOP on the title once
  you have won — six fittings earned by finishing runs (one per run at most),
  six berths, changes apply at the NEXT run start, never mid-run. Judge the
  screen, the six earn rules, and whether the spare gun / barricade / grating
  read on the deck. The winch verb gets the same play-it-and-say deal the
  crate shove got.
- **Build 33 is on itch** (pushed 2026-08-01, evening): everything in build
  32 plus the CRATE REWORK (instant tap-shove, never blocks you — re-judge
  it) and the BOILERWRIGHT'S OWN MODEL (broad bearded engineer on the
  captain's clips — check the belt pouches and how the axe swings read).
  https://alex-unconstrained.itch.io/skygear-godot-test
