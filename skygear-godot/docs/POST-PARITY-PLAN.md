# The post-parity plan — direction for the era after the browser stopped being the ceiling

Status: **DIRECTION, not a queue.** Written 2026-08-01 against `STATUS.md`, the
`docs/OUTSTANDING.md` ledger, `docs/BOARD.md`, `docs/SHIP-AND-MAPS-DESIGN.md`,
`docs/META-PROGRESSION-DESIGN.md`, `docs/CLASS-2-DESIGN.md` and the pillars in
`DESIGN.md` §2. Every buildable item below gets mirrored onto the board as one
or more rows before anyone works it; §4 says how. An item leaves this plan the
way an item leaves the ledger: done, or dropped with the reason written here.

## 1. What the game is becoming

The parity goal is retired and the owner's sentence replaces it: *"we build the
Godot version to be better than the web one ever was."* The two ways to be
better trace to two things the owner actually asked for, and this plan is both
of them in an order that respects their risk. First, the ship becomes the second
character — the deck varies per wave from the seed, keeps fittings the player
earned, and can eventually be stood on between runs — which is the four asks of
SHIP-AND-MAPS §0, all data + deterministic sim + headless tools, zero Meshy
credits, the shape the agent loop builds best. Second, the figures come alive —
the boarders stop being unrigged statues (today `scrapper.tscn`, `gunner.tscn`,
`swarm.tscn` and `boss.tscn` contain no `Skeleton3D` and no `AnimationPlayer`)
and the Boilerwright gets the kneel that CLASS-2 §7 says his class is missing —
which is the owner's stated near-term want, spends credits, and is scaled only
after a one-enemy pilot proves the pipeline on something cheaper than four
meshes at once. The browser never had a ship that became yours and never had a
third dimension to swing through; these are the two claims it cannot answer.

## 2. The plan, in order

The ship thread and the figure thread interleave: ship work needs no credits
and few owner decisions, so it fills the loop while the figure thread waits on
SG-45, on credit approvals, and on evening-session verdicts. Sizes are honest
guesses; a size that proves wrong gets re-stated on the board row, not here.

**1 · Motion evidence: `tools/clip.gd`.** A capture tool in the hub family:
pose a scenario the way `tools/screens.gd` and `vfx_shot.gd` pose theirs, run N
seconds of real sim+render, save a frame sequence to `.shots/`, stitch to an
animated file. Runs WINDOWED — the headless readback hang is documented (SG-29).
Closes SG-32 as a special case, since a cutscene is a posed clip. *Why first:*
every figure-thread claim below is a claim about motion, and the entire
evidence discipline today is stills; "the walk reads well" without this is the
assert-from-memory failure mode STATUS names. *Verified by:* file-count and
duration assertions plus a smoke run in the hub's `all` sequence. *Size:* days.
*Owner:* nothing.

**2 · The stowage spine: `layout_rng`, the STOWAGE table, `tools/stow.gd`, and
the kill-test.** SHIP-AND-MAPS §4 and §9 as written: a STOWAGE table beside
`PROP_LAYOUT` (fixed entries for mast, hatches, ballistae and all three vents;
weighted slots with jitter for the dressing positions), rolled per wave from a
third stream seeded `hash(seed_text) ^ (wave * 2654435761)`, consuming nothing
from `rng` or `visual_rng`. `restow_props()` already rebuilds every prop at
every `start_wave`, so twelve stowages cost the same as one. `tools/stow.gd`
ships in the same change: N seeds × 12 waves headless, asserting a vent per
lane, no two kegs within 200 units, every cross-passage passable, cover area in
a band, worst offender printed with seed and wave — and the POWDER STORE keg
drop gets the same 200-unit minimum, which §7.3 notes can be violated today.
*Verified by:* checks named up front — `stow · the same seed deals the same
twelve decks` (byte-identical), `stow · rolling the stowage leaves rng.state
untouched` — plus the stow.gd invariants. Then the §7.1 kill-test:
`tools/balance.gd` over its six seeds, table flat vs live; **if the close-share
distribution is indistinguishable, the variety is cosmetic and gets cut, not
tuned.** *Size:* days. *Owner:* two decisions filed in `NEEDS_ALEX.md` before
the first stowage lands — the close-share threshold, and whether balance.gd's
seed count rises or its band widens.

**3 · Fittings, the berth cap, and the run-log fix.** **DONE 2026-08-02 (board
SG-56), under the owner's midnight reframe:** the stowage table this item said
fittings work through was CUT (SG-48), so fittings apply their deck changes
ONCE at run start from the berthed set — `scripts/fittings.gd`, awarded in
`bank()`, at most one per run, six berths, `ship: [ids]` on the run row.
Verified by the checks this item asked for, named: `fittings · a ship with
nothing berthed sails today's deck exactly — byte for byte`, `fittings · no
fitting names a forbidden field`, one fixture check per award rule
(`fittings · the first victory keeps the wreck…` through `…an unhealed win
pays the scupper grating`), and the owner's rule itself, `fittings · the ship
never changes mid-run — a berth signed mid-run waits for the next run`. The
WINCH verb (item 4's shape) shipped in the same pass as the fitting that
grants it. Original text follows. — SHIP-AND-MAPS §5:
fittings are never bought — the ship keeps at most one per run, awarded in
`SkyGearWorkshop.bank()` from fields the run row already records. First set as
designed: BOW BARRICADE, SPARE GUN, WINCH, FOURTH VENT, SCUPPER GRATING beside
the shipped Wreck (SG-15). Six berths, chosen between runs, behind
`state.unlocked`. The hard rule verbatim: no fitting touches `mods`, `player`,
a starting value, or any `SkyGearWorkshop.NODES` field — a fitting may only
change the stowage table or the deckwork verb table. Same pass adds the
`ship: [ids]` field to `SkyGearRunLog.record` — the last reproduction hole.
(The recorded bug this item originally carried was HALF stale: `record` has
written `class_id` since the class shipped and `heat` since e32210d, and the
unblocked half was closed as board SG-53 — the round-trip is pinned by
`log · and the row carries the class and the heat that reproduce the run`,
old-format rows by `log · an old-format row without heat or class still loads
and counts`, and heat is surfaced on the report line and the title readout.) *Verified by:* a
bare-ship baseline check (a run on the bare deck reproduces today's numbers
exactly, the §7.2 pattern), a data-shape check that no fitting names a
forbidden field, and one fixture-row check per award rule. *Size:* about a
week. *Owner:* confirm the six fittings and the cap, and the Heat
comparability call — record fitting count in the Heat row (the design doc's
lean) versus Heat runs sailing bare. Both to `NEEDS_ALEX.md`.

**4 · THE WINCH, built to the SG-37 lesson.** **DONE 2026-08-02 with item 3
(board SG-56), exactly as corrected here:** a tap-to-haul in the shove idiom,
one entry in `deckwork.gd`'s verb table, `WINCH_STEP` per tap, its own ~1s
cooldown, stops `WINCH_GAP` short of the captain, granted by the WINCH
fitting. Verified by `fittings · the winch verb exists exactly while its
fitting is berthed`, `fittings · the winch verb does not exist on a ship
without the fitting`, and `fittings · a tap hauls one fixed step, and the
stack can never land on the captain`; the owner's play-it-and-say verdict
stays owed, with the drop-with-reason exit pre-committed. Original text
follows. — The verb OUTSTANDING still owes
("dragging a crate to close a lane… shaping where the fight happens"),
corrected by two established facts: boarders are on rails (§2 — nothing
placeable funnels them; the verb shapes the *player's* cover), and the owner
rejected hold-to-channel ("the hold to move is not fun"). So not the design
doc's 2.0-second channel: a tap-to-haul in the shove idiom, one entry in
`deckwork.gd`'s verb table, a fixed distance per tap, per-crate cooldown as the
cost, never colliding with the captain. Granted by the WINCH fitting; prompt
via the repair-verb pattern with the live binding. *Verified by:* the haul
respects the passable-crossing invariant from stow.gd, and the verb exists only
when the fitting is berthed. *Size:* days. *Owner:* the play-it-and-say verdict
SG-37 got, with the drop-with-reason exit pre-committed.

**5 · The berth screen.** **DONE 2026-08-02 with item 3 (board SG-56):**
`SkyGearHUD._draw_berths`, opened from the title's THE BERTHS button (no key —
structurally between-runs), posed as the audit's 24th screen at its fullest
state mix. Verified as this item asked: `fittings · the berth cap refuses a
seventh`, `fittings · a fitting the ship has not earned refuses to berth`,
`fittings · the earned set and the berthed set round-trip the save file`,
`fittings · a denied write reports clean without reaching the disk`; the
results screen's line is posed on `deck lost + workshop`; text audit clean at
all four widths. The owner's hands-on screen verdict stays owed. Original
text follows. — One screen in the Workshop's visual language (`ui.gd`
widgets, the SG-14 idiom): earned fittings as objects, six berths, locked ones
stating their earn rule on hover the way the Heat ladder's padlocks do; the
results screen gains one line when a run earns a fitting. *Verified by:* berth
cap enforced, a locked fitting refuses to berth, the berthed set round-trips
`user://` persistence and a denied write; text audit clean at all four widths
with the fullest state posed, zero COLLIDE. *Size:* about a week. *Owner:* the
usual hands-on screen verdict in an evening build.

**6 · The Boilerwright's kneel and his wrench.** CLASS-2 §7's two commissioned
rows, gated on SG-45 (his scene rendering at all, IN PROGRESS). The kneel is a
Mixamo plant clip retargeted through `tools/ingest_model.py` — a `models.json`
edit, no Meshy spend — wired to `tap_main()` through the clip-stretched-to-
window machinery `hub -- timing` measures; a brace clip for Blowdown the same
way. The wrench is SG-38 as filed: one mesh via the PROP frame, fitted to
`mixamorig_RightHand` in the lab with the timeline running (the SG-20 lesson).
*Verified by:* a `class ·` check that tapping a main plays the plant and it
fits the tap window, plus the SG-45 guard that every Skin bind resolves against
its own skeleton. *Size:* about a week. *Owner:* approve SG-38's ~35 credits,
and say whether the kneel reads.

**DELIVERED 2026-08-02 except the Blowdown brace** (SG-38 the wrench, SG-74
the kneel — on the owner's own Great Sword Pack rather than a retargeted
stranger's clip, better than this item planned): `figure · tapping a main
plays the plant, and the kneel fits the tap window like a swing fits its
cast` · `class · tapping a main opens the plant window the renderer reads off
tap_cooldown` · `weapon · his mount carries the wrench itself now, not the
empty hand`. Still open from this item: the **Blowdown brace clip** — the
pack's crouch2 (kneel-to-stand) or crouch4 (crouched press) are aboard and
unwired, so it is a rig3d/view3d wiring decision now, zero assets needed.

**7 · Enemy animation, as a pilot: the SCRAPPER, alone.** The owner's stated
near-term want, scoped to what the record supports. The pipeline's single
precedent currently ships invisible (SG-45), the four enemy meshes predate the
clean-T-pose rule, and every Meshy attempt at an enemy-shaped judgment call
(hulk twice, furnace knight twice) ended in rejection — so the plan is one
enemy, not four. Gated on: SG-45 landed with its guard extended to enemy
scenes, and item 1's clip tool existing. Route: Meshy auto-rig with Mixamo bone
names, retarget a shared clip set (walk, attack, flinch, death) through
`ingest_model.py`; death plays the clip and holds the corpse briefly instead of
the instant squash, flinch routes from damage above a threshold, and VFX-PLAN
§1's never-finished `amount_ratio`-by-damage scaling lands beside it (that
piece is independent and can ship first). *Verified by:* `figure ·` checks that
the scrapper loads a rigged scene and its swing fits the attack window (the
`anim_timing` pattern), a reviewable clip from item 1, and `tests/bench.gd`
holding the frame budget at sixty boarders. *Size:* about a week for the pilot.
*Owner:* approve the rig-endpoint spend from the ~547 balance before it starts,
and each ~30-credit regeneration if the mesh fails the T-pose rule. **If the
pilot fails review, stop and report before spending on GUNNER** — the
remaining three are separate board rows that exist only after the pilot passes.

**8 · Cross-passages as data — the two fittings that change movement.**
`CARGO_RECTS` becomes per-run data at its four read sites (one already
converted by SG-31), driven only by fittings — never the seed roll, which would
contaminate the close-share data item 2 reads. SCUPPER GRATING closes a
crossing and puts a vent in it; FOURTH VENT is the Boilerwright's prize.
*Verified by:* a closed crossing is closed to the captain and invisible to the
clamp (boarders provably untouched), stow.gd's invariants re-run per
permutation, the bare-deck crossings pinned at −470/+15/+515. *Size:* days.
*Owner:* nothing new — gated on item 3 and on the item-2 kill-test verdict.

**9 · Walk the ship — last, blocked, skippable.** SHIP-AND-MAPS §6's minimum:
the title screen is already the live ship behind a 72% scrim; drop the scrim on
a key that is not Enter, empty `spawn_queue`, deckwork prompts fire on berthed
fittings, Enter still deploys in four seconds from anywhere. The real bill is
auditing the thirteen `state == State.PLAY` gates in `game.gd`. **BLOCKED until
items 3 and 5 are DONE** — a hub before the refit is META-PROGRESSION §8's
front-door failure verbatim, and this is a rule, not a preference. *Verified
by:* checks that in WALK no wave starts, nothing ticks, no coach line fires,
and the hub is never entered automatically. *Size:* days. *Owner:* the skip
test — if it can be skipped and nothing is lost, it is correctly optional.

## 3. Explicitly not

- **Seed entry, seed display, or a shareable run card.** The owner never asked
  for any of it; the ledger's founding rule is "nothing goes in from me having
  an idea." Determinism stays a guarantee (item 2's checks); the UI for
  advertising it waits for an ask.
- **Seeded night palettes and event-wave variants.** Same reason. Both are
  plausible and neither traces to an owner sentence. If run variety is wanted
  beyond stowage, the owner says so first.
- **An audio layering pass.** A real gap, nowhere in the ledger. Filed here so
  it is not forgotten; not built until asked.
- **All four enemies rigged in one push.** Replaced by the item-7 pilot; the
  reasons are SG-45, the T-pose rule, and the hulk lesson.
- **A second deck, more lanes, a vertical layer.** SHIP-AND-MAPS §3's
  rejections stand: renderer + recalibration + the loss of the regression
  yardstick, buying variety a crate buys.
- **Boarder pathing, or the lane clamp as real geometry.** §2: boarders are on
  rails; turning the clamp into collision is the most expensive item available,
  and the clamp is why generated stowage is safe at all.
- **A below-decks interior.** One projection, ~350 checks standing on it; §6
  cut it and it stays cut.
- **A third currency, or purchasable fittings.** §5: fittings are what the
  ship kept, or the ship is a second Workshop with a different noun.
- **Free procedural prop placement.** §4: it moves the vents a class is built
  on and its review cost never goes down; weighted authored slots only.
- **Boilerwright mobility retune.** SG-7 is an owner decision and explicitly
  not tuning-by-feel; item 6 makes the class look like its trade without
  moving a number.
- **VFX-PLAN §5 chromatic/radial blur.** The research audit argues against it
  and half was already dropped; SG-19 gets the formal drop recorded, not a
  build.

## 4. This document and the board

This file is direction; `docs/BOARD.md` is the queue. Each numbered item in §2
gets mirrored as one or more board rows before work starts, with this document
cited in the row's notes; the board's rules then govern — claim before working,
DONE needs a named check string or tool output (rule 2), blockers named. The
owner decisions in items 2, 3, 6 and 7 go to `NEEDS_ALEX.md` with a
recommendation apiece, per board rule 4. The order here is the intended order,
but the board is the truth about what is actually in flight: if a row here is
BLOCKED, agents take the next unblocked one rather than idling on sequence.
When the board and this file disagree about whether something should exist,
this file wins until the owner edits it; when they disagree about whether
something is done, the board's evidence wins.