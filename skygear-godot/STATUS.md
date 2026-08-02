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
board SG-56). **682 harness checks**; the text audit covers 24 screens at
4 widths and is clean. Build 38 is on itch at
https://alex-unconstrained.itch.io/skygear-godot-test (butler pushes directly
from this machine now) and the source is at
https://github.com/alex-unconstrained/skygear

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
`harness` (682 checks), `text` (the audit), `screens` (the BATCH-evidence mode:
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

**3. The four recurring failure modes.** Each has happened more than once.
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
| `scripts/deckwork.gd` | a verb table for acting on the deck. Two verbs: repair (held), shove (instant) |
| `scripts/coach.gd` | one hint at a time, and mostly silence |
| `scripts/sky.gdshader` | the browser's painted sky, sampled by view direction |
| `tests/parity_test.gd` | 682 checks; the closest thing to a specification |

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
| `harness` | 682 checks. Green before anything ships |
| `text` | every string on 24 screens x 4 sizes: containment, overlap, overprint, drift, contrast |
| `parity` | browser against Godot, same seed and tick count, stitched |
| `sky` | the sky, from the four places on the deck it is actually visible |
| `lab` | any model: triangles, height in ground units, bones; mounts weapons |
| `balance` `timing` `motion` `model` | simulated runs; clip-vs-skill; root drift; rigs |
| `todo` | the open half of OUTSTANDING |
| `all` | every checker in sequence, one verdict |

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

`prune` strips the 77 MB an asset arrives as down to the ~10 MB GLB actually
used, and refuses to run before the first import because extract-mode textures
leave a scene with no meshes and no error. The remesh pass took the props from
182 MB to 9 MB (the captain deliberately excluded — board SG-13); the itch zip
is 94.5 MB.
