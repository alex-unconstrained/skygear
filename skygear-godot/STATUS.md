# SkyGear Godot port -- where things stand

Last updated 2026-08-02. **Read this first, then `docs/BOARD.md` — the work
queue agents claim items from and report evidence to. `docs/OUTSTANDING.md`
stays the ledger of owner asks; an ask lands there first and is mirrored to
the board as workable items.**

**THE GOAL CHANGED 2026-08-01, by the owner:** visual parity with browser v11
is retired — *"we build the Godot version to be better than the web one ever
was."* The browser is a reference and a regression yardstick now, not a
ceiling. Judge visual work by "is it better and legible," not "does it match."

Playable end to end: twelve waves, two classes, a draft, persistent progression,
a difficulty ladder, a sky, a cutscene system with all five cues filled —
a run-opening reveal, event-wave flourishes, the Colossus arrival, and victory
and defeat shots — and, since 2026-08-02, **the ship's own progression**: six
FITTINGS earned by finishing runs (at most one per run, `scripts/fittings.gd`),
chosen into six berths BETWEEN runs on the title's berth screen, applied to the
deck once at run start and never mid-run (the owner's rule, harness-pinned —
board SG-56). **1023 harness checks**; the text audit covers 24 screens at
4 widths and **is clean as of 2026-08-02, for the first time in a while** — the
sentence above it said so for days while the audit reported a BERTHS overflow on
every windowed run, filed under an ID (SG-68) that belongs to a different,
finished row. Board SG-92 has the whole of it, and the reason it was one finding
rather than four. Build 38 is on itch at
https://alex-unconstrained.itch.io/skygear-godot-test (butler pushes directly
from this machine now) and the source is at
https://github.com/alex-unconstrained/skygear

**THE COLOSSUS DIED IN 9.7 SECONDS, AND THE DESIGN DOC'S EXPLANATION OF WHY HE
IS EASY WAS HALF WRONG (SG-146, 2026-08-03, owner: "still super easy... he also
just needs a lot more HP I think").** His `hp` is **2900** now, picked by
measurement: at 900 he was resolved in 9.7 s of a 19.4 s wave, which is five
swings of his 1.90 s cycle across a two-beat fight, so the half-health turn had
two and a half swings to escalate with. **The instrument had to be built first,
and building it found a live instance of failure mode one in the damage path**:
`damage_player` has taken a `source` string since it was written and NOTHING HAS
EVER READ IT — the parameter was spelled `_source` while `enemy.gd` passed the
boarder's `kind`. So "is it the Colossus, or the four gremlins standing next to
him?" was unanswerable from a total that had the answer in its argument list.
`tel.taken_by_source` reads it now, and `tools/boss_probe.gd` times the WAVE-12
SEGMENT rather than the whole run — because a whole-run mean is the wrong
instrument for one wave in twelve, which is what SG-119 paid for.
**COLOSSUS-DESIGN §1 said his swing "geometrically cannot land" on a moving
captain; at hp 900 he was already dealing 66% of all wave-12 damage**, because
his second-beat swing reaches 253 units and `tools/bot.gd` orbits at 210. He
cannot land on a captain who RETREATS and lands freely on one who ORBITS. **More
health did NOT buy a longer boring fight** — wave 12 got 24% longer while damage
taken in it rose 189%, so danger per second rose 157% — and the honest cost is
that the Heat 0 hold-rate fell from 100% to 66%. **The design's recommended root
fix was built, measured, and ships OFF** behind `COLOSSUS_WALKS_THE_LANE`: it
failed §2's own pre-committed statistic (Boiler HP lost 9.5 → 11.3 against a
required +40) and it takes his damage to the captain to a structural zero. §1a of
that doc is the whole measurement. **And two harness lessons were paid for: a
check that RAISES instead of failing takes the rest of its function's checks with
it, and a check that can only read a shipped default is vacuous — deleting the
line it guarded left the run green at 946/946 until the gate was made settable
per instance.**

**THE COLOSSUS'S HITBOX WAS A CIRCLE AND HIS TELEGRAPH WAS A WEDGE, AND THE
HARNESS HAD A CHECK PINNING IT THAT WAY (SG-119, 2026-08-03).** He was the only
melee row carrying no `reach` and no `swing`, so `_swing_hits` returned true
unconditionally — a **360° circle at 163** — while `view3d.gd` drew him a **120°
fan at 146** out of a fallback constant the simulation had never heard of.
Stepping behind the Colossus, the thing his own telegraph invites, had never
once worked. He carries the two fields now, **both carve-out branches are
deleted** so no enemy can take a reach-less path, and the wedge is ONE function
(`enemy.swing_wedge_reach/arc()`) that the renderer calls rather than
re-deriving. **His swing lands at exactly the same distance it always did** —
146 is precisely the `attack_range + 26` both fallbacks computed, so 163 to the
captain and 253 on the second beat, before and after; the ARC is the whole
change, and his damage, health, windup and recover are harness-pinned untouched.
**This makes him easier and nothing was compensated**, on purpose: his
difficulty is `docs/COLOSSUS-DESIGN.md`'s open question and a shape fix is not
the place to answer it. **The ugly part is that the harness was asserting the
bug**: `telegraph · a boarder that draws no wedge keeps its circle` passed every
run for weeks under a comment claiming he "telegraphs with a phase ring rather
than a fan" — a renderer that did not exist. That check is INVERTED, in place,
so the diff shows the assertion changing sides. The measurement that matters is
geometric and cannot be satisfied by a mismatched shape: sweep the connect test
over a full circle and the share that lands must equal the arc that is drawn —
**BOSS 0.335 against a drawn 0.333**, where it read 1.000 before.

**And two smaller ones that were both about a number nobody had measured.**
`visual_rng` was never seeded anywhere in the repo (SG-120) while
`set_seed_text` promised in its own comment that a seed reproduces a run — which
was cosmetic right up until the POWDER STORE talent placed real explosive kegs
from that stream, so two players on one seed got different decks. It is seeded
beside `rng` under its own salt now, consuming nothing from it. And a fire
pool's tick period was reset by ASSIGNMENT rather than carried (SG-122), so the
overshoot was discarded and the true period was `ceil(0.25 / delta) * delta`.
**The board row called that "harmless at 60 fps" and it was not**: 1/60 does not
divide 0.25 in binary floating point either, so the pool has been delivering
**11.4 dps against its authored 12.0 in every build that ever shipped** — which
also means SG-117's recorded "the authored 12 dps" was 11.4, and that row is
annotated rather than left standing. It is 12.0 at 1/60, 0.05 and 0.1 now.
**The same discard pattern is in three more places and is deliberately NOT
fixed here** — the steam taps and the player's aura and pulse passives, filed as
**SG-126**, because those are player-damage rates and want their own before and
after rather than a fourth change in one commit.

**THE SAFEST PLACE ON THE DECK WAS INSIDE THE FIRE, AND THE RIG THAT SHOULD
HAVE CAUGHT IT WAS MEASURING A CAPTAIN WHO NEVER MOVED (SG-117 + SG-118,
2026-08-03).** `invulnerability_left` is ONE global variable and a fire tick set
it to 0.55 s four times a second, so a captain standing in a pool was immune to
*everything* — a boarder's 26-damage swing included — while the pool itself
landed one tick in three. Measured directly, a captain being swung at every
1.5 s for a minute took **700 damage standing IN the fire against 1014 standing
CLEAR of it**: the hazard was a 31% damage shield. It is a `grants_invuln` flag
threaded `damage_player` → `take_damage`, default TRUE so every discrete hit is
byte-for-byte unchanged, FALSE from the tick — and the sweep for other periodic
sources was RUN rather than assumed: there is exactly one, because enemy burn
stacks drain the enemy and the steam taps' half-second accumulator calls
`_damage_circle`, which never iterates the captain. In fire now costs 1440.
Five `hazard ·` checks, the pre-committed one being `hazard · a fire tick never
buys immunity to a swing`.

**And the second half is the fifth failure mode again, one level deeper than it
has been found before.** `tools/balance.gd` — the source of every simulated-run
verdict in these docs — carried a comment saying its bot *"keeps moving"* beside
a loop that issued **no movement input at all**. It moves now, and its policy is
a file of its own (`tools/bot.gd`) that the harness drives directly, because a
policy buried in a loop is a policy nobody can test: it holds the captain's own
210-unit gauge band, strafes inside it, leaves a fire pool it is standing in
(but does not route around one it is clear of — a bot that dodged fire perfectly
would have made SG-117 look free), and dashes only to break contact, because
dash grants i-frames and a bot dashing on cooldown carries a background immunity
that flatters exactly what SG-117 measures. Two more things were ticking behind
the rig's back and are fixed: the engine was stepping the **captain** on real
frames (`set_process(false)` on the game never reached her — she is her own
node), and nothing had ever disabled the **props**, so a lit keg's 0.45 s fuse
burned on wall-clock time and a keg is 26 damage. **A moving captain is a
different game**: Heat 0, n=120 — damage taken **34.6 → 241**, runs held
**38% → 92%**, close-range time **3–5% → ~22%**. Every balance number in these
docs predating this is a number about a stationary captain, and **SG-57's
held-rate observation — the one waiting on the owner's threshold — has flipped
sign and is no longer significant**; its own row had wondered aloud whether it
was "a bot fact", and it was.

**The rig is STILL not deterministic, and it now says so where it used to claim
otherwise.** The residual is below the scene tree — `move_and_slide()` queries a
physics space the server syncs on its own tick — so the header states plainly
that this tool reports a DISTRIBUTION and that **its floor is not zero: 8% on
damage-taken between two n=120 batches of identical code.** That floor is why
SG-117's run-level result (−10%) was reported to the owner as *below the rig's
resolution* rather than as a finding, and why the fix's real evidence is the
direct probe instead. Three `bot ·` checks; the one that matters is `bot · the
bot actually moves the captain — the SG-118 regression`.

**THE MODELS CAN BE LIT NOW, AND THE LIGHTS ARE DATA (SG-81, owner ask:
"the models don't have baked lighting").** `assets/models/lights.json` is a
per-MODEL-KEY table — omni or spot, colour, strength, reach, falloff, offset in
ground units, a spot's cone and aim, an optional pulse or flicker — read by
`scripts/view3d.gd` at launch and worn by EVERY live instance of that model.
**The lab writes it**: `SkyGear Tools.bat lab`, the new **LIGHTS** mode, add a
light, dial every field on the SG-39 typed widget, see it on the real mesh with
a gizmo showing where it is and how far it reaches, DARK ROOM to kill the lab's
own lamps, SAVE. Not the clipboard — the renderer got the reader first. **Model
lights are ACCENTS and the budget is arithmetic:** every row is clamped to 2.0
energy over 460 ground units as it is read, at most 8 are live, and their summed
energy cannot pass 7.5 — which is the 7.39 the deck already carried, so the
table moves light around rather than adding it (a 40-row flood lights 3).
Figures are admitted before scenery, because a brazier that loses its light
keeps its painted floor pool and a boarder has nothing. Five seeded: the
brazier, the lantern post, the steam vent (a spot, up out of the grate), the
Boiler, and the furnace knight — whose chest light is SG-86's named candidate
and measurably lifts him (30.4 → 33.4 mean luminance, 10 → 276 hot pixels).
`.shots/sg81/` is the witness.

**AND THE FX DIALS HAVE A HOME TOO (SG-17), on exactly that pattern and with
the reader written first.** `assets/models/fx.json` carries the three FX dials
that are genuinely RENDERER constants — the bloom over emissives, a scale on the
impact particles' bodies, and how long one of them lives — read by
`scripts/view3d.gd` at launch, clamped as they are read, with per-KEY fallback
so a half-typed file costs you the dial you were half-typing. The lab's SAVE
writes it. **The other six dials go on going to the clipboard, and that is the
honest half:** `radius`, `arc`, `life` and `damage` are arguments the SIMULATION
picks per shape at the moment it fires, so their home is the `_fx({...})` call in
`game.gd`; `period` and `slowmo` are the lab's own controls and do not exist in a
run. **Two of the three were moving nothing at all before this** — GLOW wrote a
property this renderer has never set, and SPARK wrote `mesh.size` on a `QuadMesh`
that SG-63 replaced with real prisms and spheres, so it has been dialling a null
cast for weeks. A reader for dials that reach nothing would have been the failure
wearing the fix's clothes; `view · every dial in the fx table is read by the
renderer` and `view · and the renderer on screen is built out of those dials, not
out of literals beside them` are the two checks that say it is not.

**The deck's railings are geometry (SG-72), and the cargo hatches are NOT, on
purpose.** The railing won its second roll — v1 arrived standing on a solid
timber board, because the prompt asked for "base flanges" while the shared frame
refused a plinth, and on the deck it read as a bench lying at the rail. The
hatch was generated three times and REJECTED: it lies flat IN the planking, so at
the locked 41-degree camera nearly all of it that reaches the player is its own
top face, which is a texture either way — the rope coil's standing verdict, one
size up. All three verdicts are written where the prompts wait, in
`tools/meshy.py` and `tools/static_model.gd`.

**One trap, found the hard way:** `tools/static_model.gd` rebuilds the `.tscn`
for EVERY key in its table, including the RIGGED figures — so running it to wrap
one new static prop overwrote `scrapper.tscn` and its neighbours with dumb
static holders and took the harness to 725/729. It is silent. Revert the `.tscn`
files you did not mean to touch before you believe a green run.

**THE MENU IS HARDWARE NOW, NOT FOURTEEN HAIRLINE RECTANGLES (SG-91, owner ask:
"the header UI element feels on-theme but the rest are just simple text
boxes").** He was right, and the survey found the reason: the SKYGEAR banner is
painted brass carrying material, a bevel, corner ironwork and weight, while
every control under it was `SkyGearUI.button` — **two shape calls**, a flat tint
and a hairline, with its whole state carried by swapping two colours. The title
is a **board** now: a riveted iron bulkhead the plates are bolted to, each plate
a solid body with a bevel, four rivets and an **engraved channel** its label
stands in; the lit state is a LAMP rather than a tint (a wash down the plate, a
deepened shadow so it reads raised, rivets catching light on the fire fields'
own flicker clock); BEGIN RUN is **the door** — taller, teal, wearing the
banner's own corner brackets, never dark; QUIT is a small iron **hatch** off the
foot of the board; and the Heat chips are **rungs bolted across a rail**, with
the chosen one SEATED rather than merely tinted. **The flicker cannot reach a
glyph, mechanically**: the engraved channel is drawn opaque over every lit layer
beneath it, which is what keeps the legibility pass — it renders each screen
twice and samples the second — from measuring noise. `docs/MENU-DESIGN.md` is
the survey, the vocabulary and the ordered plan; the other screens are SG-93 and
are deliberately waiting on the owner's look. **Nine `menu ·` checks**, the text
audit clean at all four widths (and the pass turned a detector ON — nothing on
the title was inside any frame before, so containment had no opinion about the
menu at all). It also found and fixed a real bug: a `bare` widget drew at the
rect from BEFORE the F4 adjustment, so a nudged Heat rung moved its click target
and left its painted rung behind (`menu · a nudged Heat rung takes its own art
with it`). `.shots/sg91/` is the witness.

**F4 RESIZES NOW (SG-80, owner ask): a selected element has a size as well as
a position** — drag a grip, type into the w×h readout, or hold Ctrl and use the
arrows. It saves as a SIZE DELTA from the size the drawing code chose, beside
the offset in the same entry (`{"o":[dx,dy],"s":[dw,dh]}`); an entry with no
size stays the bare pair it has always been, so old layout files load and save
unchanged. Narrowing a box past its own words is allowed and the live verdict
says so the same frame; a box narrower than one `MIN_PT` glyph is refused.
**And Ctrl+S was genuinely broken (SG-83) — but not where anyone would look:**
the harness deleted `user://hud_layout.json` six times a run and wrote fixtures
over it, so a hand-alignment pass saved correctly and was wiped by the next
`SkyGear Tools.bat harness`. Test runs go to a scratch file now and the last
check of every run proves the player's own file is byte-identical; the editor
also says `SAVED ·` with the real path, or shouts if a write fails.

**AND THE LAST OF THE "2D READS" ARE GONE (SG-63, 2026-08-02).** He named three
things; two were VFX and both are geometry now. **The impact and explosion
particles have bodies** — every one of them was a flat card swung to face the
camera, so a steam plume was one painted cloud sprite stacked forty times. A
spark is a prism lying along its own velocity; a puff is a LIT low-poly sphere
that tumbles, so the deck's lamps travel across it as it rises. **And the
`burst` — every kill, every powder keg, the hulk coming apart — had nothing in
the air at all**: VFX-PLAN §3/§4 gave every other shape geometry in July and
this one was skipped, so a thing coming apart drew a painted cartoon star flat
on the planking. It is a shock ring, a dome of shell rings and a throw of real
debris now. **The SG-78 flooded-disc trap turned out to be under five more
effects** — the Pulse ring, the fire fields, the Colossus turn ring, the
Boilerwright's vent stand, and the aura edge a card WIDENS — because they all
drew through `rune_player.png`, which measures alpha-255 across its whole disc.
Every ring in the game draws through the generated rim now, and a harness check
keeps the two measurably-opaque plates out of the decal path for good.
**The cape was rebuilt and is STILL OFF**: it is a 3x6 lattice of eighteen bones
with blended weights, real folded normals, a garment's cut and a twill instead
of the deck-planking painter, and against SG-82's flat red signboard it is
plainly cloth (`.shots/sg63/cape-before-after.png`). What that proves is that
the GEOMETRY is no longer the reason it looked wrong; whether he wants a cape at
all is his call, and turning it on is still one commented line.

**Three corrections off the owner's 2026-08-02 screenshot are in** (SG-78/79/82).
The aim indicator lost its range ring: the small landing reticle, clamped at the
skill's reach and dimming past it, is now the whole feature — the ring drew as a
flooded opaque disc because it went through the painted `rune_player.png` plate,
which is a FILLED disc, so DESIGN §13e's premultiplied emission map lit the whole
projection box. The captain's cape is OFF by default and `HERO_CLOAKS` is empty
(two verdicts: "looks horrible", "atrocious") — the cloak code stays in the build
under harness for the SG-63 rebuild, and the SG-82 board row records exactly why
it read as a plank. And the prop ruler now measures what the CAMERA sees rather
than the model's AABB: a billboard is camera-facing and has no depth, so scaling a
solid to `PROP_HEIGHT` handed a squat deep prop up to 2.07x the screen height of
the painting it replaced. All ten wired prop rows are pinned within ±10% of intent.

**Alignment is FIXED in the game now, not filed from screenshots** (SG-42, the
owner's ask): press **F4 on the screen that is wrong** — any screen — and move
the thing itself: panels, and the elements INSIDE them (labels, readouts,
buttons, a card's emblem), by drag, arrow-nudge or typed offset, with the text
audit's own detectors as the live verdict. **And you no longer have to BE on
the screen** (SG-44, round two of the same ask): **P** inside the editor poses
any of the audit's screens on a sandbox — edit GAMEOVER without dying, the
results without winning — and Esc hands the game back exactly, mid-run
included (`editor · and leaving the pose hands the run back exactly`).
`docs/HUD-LAYOUT.md` is the how-to.

**The four tools you will reach for**, all behind `SkyGear Tools.bat`:
`harness` (1023 checks), `text` (the audit), `screens` (the BATCH-evidence mode:
photograph all 24 screens at all 4 widths as one page — for auditing everything
at once; fixing is F4), and `layout` (promote the F4 alignment — plates, items
and per-screen element offsets — out of `user://` and into the repo, which is
the step that makes a hand-alignment pass real).

---

## Three things to read before touching anything

**1. `docs/OUTSTANDING.md` is the ledger.** Only things the owner asked for,
never things anyone thought of. An item leaves it when it is done or when it is
dropped WITH A REASON -- not when it is partly done. `SkyGear Tools.bat todo`
prints the open half. The file exists because the skybox was reported twice and
slipped twice -- and then a third time, which is when it was measured instead of
guessed at and finally built.

**2. Run the tools before believing anything.** `SkyGear Tools.bat` lists them,
`all` runs every checker. Nearly every real bug found lately was found by a
tool, and several were things a confident commit message had already declared
fine.

**3. The seven recurring failure modes.** Each has happened more than once.
Assume you are about to commit one:

- **Data with no reader.** A table field nothing consumes, so a feature reads as
  done and does nothing. FIVE times. Two harness guards exist now
  (`shop - every talent field is read by something` and the article twin);
  extend them rather than trusting yourself.
- **Two functions disagreeing about one number.** Three visual bugs came from
  this. `SkyGearHUD.rail()` and `scripts/ink.gd` exist because of it.
- **A detector silenced to make a screen pass.** The harness once reported
  192/192 while skipping a quarter of itself. The text audit exempted every
  widget label and called 16 screens clean while 30 were broken.
- **Claims asserted from memory rather than measured.** "The camera was ported
  exactly" was said repeatedly and is false.
- **A measuring rig nobody measured — the newest one, and it cost the most.**
  FOUR times a tool has taken two photographs of "the same frozen scene", called
  the difference a result, and been wrong, because something in the scene was
  still moving: the brazier phase, then the renderer's own tick, then the GPU's
  particle clock, then — the largest — **every rigged figure's `AnimationPlayer`,
  which runs on the engine's clock and ignores both `set_process(false)` calls
  (SG-108).** Each was found by a different tool, fixed inside that tool alone,
  and rediscovered by the next one. Eight A/B answers were published against
  those floors and **three of them turned out to be the floor**, including the
  one that drove a shipped tuning change. There is one freeze now, `tools/still.gd`,
  and the rule that follows from all four: **a tool that reports a difference
  must first report its own noise floor, and that floor must be exactly zero** —
  not small, zero. A floor allowed to be 3% is a floor that can hide a 3%
  feature. `SkyGear Tools.bat still` is that assertion; the five `still ·` checks
  in the harness are what stop the next tool from skipping it.

- **A fact known in one place and contradicted in another — the newest, and the
  one that made the fifth so expensive.** On 2026-08-02 the SG-97 row wrote down
  *"balance.gd's bot never moves the captain"* and reasoned correctly from it,
  refusing to let its own numbers stand as a verdict. It did everything right.
  The fact then reached nothing else: the rig's own comment went on claiming the
  bot "keeps moving"; SG-57 wondered aloud whether its result was "a bot fact"
  without checking; SG-48 CUT a feature on a statistic the fact invalidates;
  SG-70 filed as an open mystery the very gap the fact explains; and a day later
  SG-118 rediscovered it from scratch. **The repository knew.** When you learn
  something that invalidates a measurement, the row you are working on is the
  LAST place it belongs — fix the tool's comment, and name the rows that
  depended on it. SG-125 is the audit that should not have been necessary.
- **A harness check that asserts the bug.** Distinct from silencing a detector:
  here the detector is loud, green, and wrong. `telegraph · a boarder that draws
  no wedge keeps its circle` passed every run for weeks while pinning the exact
  defect SG-119 fixed, under a comment describing a phase ring this renderer has
  never drawn. Beside it, a roster check looped a hand-typed list of three names
  — and the one melee row missing from that list was the only row that could
  have failed it. A check written from the same misunderstanding as the code
  does not test the code. Prefer checks that read the table.

**AND THE ONE SENTENCE TO MEET BEFORE YOU TYPE "NO SIGNIFICANT DIFFERENCE" IN A
BOARD ROW (SG-128).** `tools/balance.gd` **can see about a third of a change and
cannot see a twentieth of one at any price.** On its own measured spread a 30%
difference costs 23 runs per arm, 10% costs 200, and 1% costs about twenty
thousand — 61 hours. So a small sample that comes back "no difference" is not
evidence of no effect; it is an instrument that could not have seen one, which is
the mistake SG-125 exists to catch. **The old rule this replaces — "the rig's
floor is 8%, disbelieve anything under it" — was wrong, and wrong in BOTH
directions:** the 8% was sampling error at n=120 mistaken for a property of the
instrument, so it shrinks with n rather than standing as a wall; quoted at n=120
it was roughly right by accident, and quoted at n=30 (SG-126) the real bar is
~26% and the gate was three times too permissive. There is no constant now. The
rig prints what THIS sample can resolve, and what the effect you care about would
cost, under every result. `n=6` — the default before SG-118 added `reps` — is
worth +-40 points on a held-count and is not a measurement at all.

---

## The code

| | |
|---|---|
| `scripts/game.gd` | the simulation: waves, damage, draft, classes, deckwork |
| `scripts/game_data.gd` | every table: shapes, elements, enemies, waves, events, classes |
| `scripts/view3d.gd` | the renderer; mirrors the hidden 2D sim into 3D |
| `scripts/hud.gd` | every screen. All text goes through `_say` / `_says` |
| `scripts/ink.gd` | one source of truth for point size, outline, contrast floors |
| `scripts/ui.gd` | the widget layer: immediate mode, retained focus |
| `scripts/cards.gd` | 41 draft cards. `preview()` runs a card on a sandbox copy |
| `scripts/workshop.gd` | persistent progression, gated behind a first victory |
| `scripts/deckwork.gd` | a verb table for acting on the deck. One live verb: repair (held); the crate shove/winch family is TABLED behind one flag (SG-68, owner: "boring") |
| `scripts/coach.gd` | one hint at a time, and mostly silence |
| `scripts/sky.gdshader` | the browser's painted sky, sampled by view direction |
| `tests/parity_test.gd` | 1023 checks; the closest thing to a specification |

A hidden 2D scene runs the simulation and `view3d.gd` mirrors it into 3D at
`WORLD_SCALE = 0.01`. The camera is the browser's `CAM.recompute()` solve locked
at 41 degrees -- and as of 2026-08-01 that is MEASURED, not asserted:
`tools/cam_measure.gd` projects known deck lengths through both builds' math
and they agree to the pixel (ratio 1.000). The earlier "framing tighter than
the browser, unexplained" impression was an artifact of a broken browser-side
render at a mismatched resolution. Three other systems are calibrated against
that solve; the real residual it was blamed for was the Boiler prop mesh,
since rescaled to the browser's boilerH 150 and pinned by its own check
(SG-27).

**One consequence of that solve is worth knowing before you judge any
screenshot.** At 41 degrees with a 36 degree vertical field, the top of the
frame looks 23 degrees BELOW horizontal, so the horizon is off the top of the
picture at every zoom and mid-deck shots contain no sky at all. That is why the
skybox was reported three times and missed three times. `SkyGear Tools.bat sky`
poses the four places sky is actually visible; judge it from those.

---

## The tools

`SkyGear Tools.bat <name>`, or `godot --path . --script tools/hub.gd -- <name>`.

| | |
|---|---|
| `harness` | 1023 checks. Green before anything ships |
| `text` | every string on 24 screens x 4 sizes: containment, overlap, overprint, drift, contrast |
| `parity` | browser against Godot, same seed and tick count, stitched |
| `sky` | the sky, from the four places on the deck it is actually visible |
| `lab` | any model: triangles, height in ground units, bones; mounts weapons |
| `balance` `timing` `motion` `model` | simulated runs; clip-vs-skill; root drift; rigs |
| `todo` | the open half of OUTSTANDING |
| `all` | every checker in sequence, one verdict |

**A third party works in this repo.** Codex runs side experiments on its own
branches (e.g. `codex/browser-2d-godot-parity`, an isolated browser 2D
project). Leave them alone — they are the owner's, they are not the port, and
they do not reopen the retired parity goal. But CHECK `git branch
--show-current` is `main` before you work: a Codex branch checked out over
the shared tree once made every agent read its own committed work as a mess.

**A THIRD GOTCHA, AND IT IS ABOUT COMMITTING RATHER THAN BUILDING (found the
hard way 2026-08-03).** Everyone follows the rule *commit with explicit
pathspecs, never* `git add -A`. **That is not enough when two agents are live in
one tree, because the unit git stages is the FILE, not your hunks.** SG-117/118
touched `tests/parity_test.gd`; another agent had in-progress SG-116 work sitting
uncommitted in the same file, and `git add tests/parity_test.gd` took all of it —
including a check referencing a constant that existed only in their unstaged
`tools/rune_read.gd`. The commit looked fine and the harness passed **in the
working tree**; a freshly extracted worktree of that HEAD would not PARSE. So the
clean-worktree verification is not a formality that confirms what you already
know — it is the only thing that catches this, and it caught it. If you share a
file with a live agent, diff your commit against its parent for that file before
you believe it, and rebuild the file from the parent plus your own additions if
it carries someone else's.

**Two build gotchas.** The Windows export template lives in a GITIGNORED
`skygear-godot/.templates/`, so a fresh clone cannot build. And when agents are
working, build from a clean `git worktree` of HEAD or you ship a half-written
file — **and that goes for the screenshot tools too**: `screens`/`text`/
`parity` run against the live tree, and a mid-edit `hud.gd` renders a deck
with no UI (bitten 2026-08-01, three times in one day). When agents are
active, run visual tools from a worktree of HEAD or wait for the next
verified push.

---

## Designed, not built

- `docs/SHIP-AND-MAPS-DESIGN.md` -- maps, run diversity, ship progression,
  between-run downtime. The Colossus wreck fitting was placed 2026-08-01
  (SG-15); the stowage spine was built and then CUT by its own §7.1 kill-test
  (SG-48); §5's fittings + berths + berth screen were BUILT 2026-08-02 under
  the owner's between-runs reframe (SG-56). Still unbuilt: §6's walkable
  downtime, gated behind the refit by its own rule.
- `docs/AUDIT-2026-07-31.md` -- an independent audit. Its top three findings are
  fixed; its documentation recommendations are not (board SG-11).
- `VFX-PLAN.md` §6, the blade-driven weapon trail (SG-18). The two remaining
  Articles — The Opening Bid and The Second Hand — were BUILT 2026-08-01
  (SG-26), each with its trade live in the sim. Heat 3-5 were built 2026-08-01; §5's chromatic/radial half was
  DROPPED by the owner the same day (recorded at the section).

## Generated assets

Meshy, via `tools/meshy.py`. **The key must never reach a committed file** --
read from `MESHY_API_KEY` or the gitignored `tools/.meshy_key`, and run
`git grep "msy_"` before committing.

**Character models — the owner's standing rules (2026-08-01).** These exist
because every character we generate will eventually be rigged and animated
(the Boilerwright, then enemies), and a model that fails them is credits spent
on an asset the animation pipeline cannot use:

- **Clean T-pose or A-pose only.** Prompt for it, and reject a generation that
  comes back posed — retargeting needs a neutral rest pose to work from.
- **No over-accessorizing.** Dangling pouches, straps, horns and ornaments
  become part of the skinned mesh and deform strangely under animation. Keep
  the silhouette clean; character identity can ride on texture and proportion.
- **Weapons are separate models**, mounted via `BoneAttachment3D` — the
  cutlass is the pattern (`assets/models/weapons.json`, fitted in the lab).
  Never prompt a character holding their weapon.
- **Capes, cloaks and loose cloth are separate too.** The captain's cape was
  removed from her model for exactly this reason; cloth gets added back as its
  own layer, never baked into the character mesh. **The payoff shipped
  2026-08-02 (board SG-23):** her cape is a four-bone chain (`scripts/cloak.gd`)
  on a chest mount — trails at a run, cracks on the dash, bitwise-still at
  rest when sway is off (`cloak ·` checks, seven of them; `.shots/cloak/`).
  Per-class rows in `view3d.HERO_CLOAKS`; the Boilerwright opts in with one
  row when his day comes.

**The Boilerwright moves on HIS OWN clips now (board SG-74, 2026-08-02).** The
owner ran his mesh through Mixamo and delivered the Great Sword Pack — his
native rig plus 51 clips — and the whole thing ingested as one `models.json`
entry through `tools/ingest_model.py` (the §13l axe-pack path, second use).
Five heavy slashes rotate as his attacks, and Tap Main plays a real kneel
(`figure · tapping a main plays the plant, and the kneel fits the tap window
like a swing fits its cast`); the borrowed captain-clip retarget is retired.
`.shots/clips/boilerwright.gif` is the witness.

**And the FURNACE KNIGHT is a mesh, on the owner's own rig (board SG-85,
2026-08-02) — the second rigged boarder, and the first figure in this game that
DIES on screen.** Same shape as SG-74 (his Emberforge Sentinel through Mixamo:
a native rig plus 51 clips, one `models.json` entry, one ingest run), which
closes SG-22 and empties the `handoff-3d/` queue. He stands 216 ground units —
the SIM's own number for the archetype, a head over the captain — and he WALKS,
because he is the first boarder slow enough to need one: the run cycle rated at
75 units a second fell under the playback floor and skated, so `gait()` picks
the cycle by ground speed and `AUTHORED_WALK_SPEED` rates a walk against a
walk. Death is presentation only: the simulation kills, pays out and frees the
enemy exactly as before, and the RENDERER keeps the body 1.6 s to play `die`
before it sinks (`figure · and the body does not start leaving until the death
has been played`). His furnace chest is the first emission map this pipeline
has ever read — and the honest note beside it is SG-86: on the deck he is about
a quarter darker than the painting he replaces, and his hands are empty where
the sprite carries an axe. `.shots/clips/knight.gif` against
`knight-before.gif` is the witness.

`prune` strips the 77 MB an asset arrives as down to the ~10 MB GLB actually
used, and refuses to run before the first import because extract-mode textures
leave a scene with no meshes and no error. The remesh pass took the props from
182 MB to 9 MB (the captain deliberately excluded — board SG-13); the itch zip
is 94.5 MB.
