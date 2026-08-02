# SkyGear Godot port — living design document

Last updated: 2026-08-01  
Reference target: SkyGear v11 (`storm-dusk-v11.html`)  
Port status: playable end to end — twelve waves, two classes, persistent
progression. **`STATUS.md` is the status of record and `docs/OUTSTANDING.md`
is the open ledger.** This document is the running design record: sections are
dated, the earliest describe Milestone 1, and later sections supersede them
where they say so.

## 1. Intent

Rebuild the latest shipped SkyGear in Godot while preserving the browser game
as an untouched reference. The port should retain the identity of the source:
a single-player, top-down steampunk hero-defense where a Sky-Corsair protects
the Boiler across twelve boarding waves and drafts shape × element skills.

The port is intentionally isolated in `skygear-godot/`. It never loads files
from `../assets`, `../audio`, `../src`, or the generated HTML build. Needed
inputs are copied into `reference/` or `assets/` before use.

## 2. Pillars carried forward

1. Keep the Boiler alive.
2. Movement and aim must feel immediate.
3. Skills are a true shape × element matrix, not bespoke one-offs.
4. Lane commitment creates strategy, while cross-passages preserve mobility.
5. Close-range risk earns pressure, healing, and dash tempo.
6. Enemy attacks are readable before they are dangerous.
7. The deck participates through destructible ordnance and salvage.

## 3. Target loop

Title → opening weapon draft → fight → wave clear → upgrade draft → next wave
→ boss → victory/results. Player death or Boiler destruction ends the run.

The fixed basic attack is Ember Cleave. Four ability slots use LMB, RMB, Q, and
E. Dash starts with two charges. Between waves, one of three cards is chosen.

## 4. World and camera

- World: 1900 × 2560 source-space envelope.
- Deck: 1680 × 2320, with three lanes and three cross-passages.
- Boiler: stern objective, 500 HP.
- View: bounded follow camera, top-down in Milestone 1. A later visual pass may
  restore the browser renderer's 41° projection while keeping gameplay in 2D.
- Art: production PNGs are used by actors and props; procedural deck geometry
  ensures the game remains legible while scene composition is rebuilt.

## 5. Combat data

Shapes:

| Shape | Player-facing name | Milestone 1 |
|---|---|---|
| CLOSEHIT | Cleave | implemented |
| LINE_BURST | Lance | implemented |
| CONE | Gale | implemented |
| RANGED_AOE | Mortar | implemented |
| CHAIN | Whip | implemented |
| RAY | Beam | implemented as a short channel burst |
| AURA | Field | data + draft; runtime tick implemented |
| PULSE | Pulse | data + draft; runtime auto-cast implemented |
| SENTRY | Sentry | data + draft; placeholder passive bonus |

Elements:

| Element | Effect |
|---|---|
| Ember | stacking damage-over-time |
| Frost | movement slow |
| Arc | stun chance; extra chain reach |
| Steam | stronger knockback |

The browser game exposes 9 shapes × 4 elements = 36 cells. The port stores all
36 combinations and keeps element application centralized.

## 6. v11 close-quarters loop

Milestone 1 uses the shipped v11 contract:

- close range: 210;
- pressure from close damage: 0.85 per damage;
- passive pressure: 6/s while at least two enemies crowd the captain;
- pressure decay: 14/s after 1.2 seconds out of danger;
- vent at 100: radial damage, knockback, heal, reset;
- close kills can drop salvage and refund dash time;
- two dash charges, 1.0s recharge, 30 contact damage.

The copied source contains later unshipped tuning edits in the working tree.
Milestone 1 uses the documented v11 values where the shipped plan and working
source differ; a parity harness will settle exact numbers before release.

## 7. Reactive deck

- Steam keg: 34 HP, 0.45s visible fuse, radial damage and knockback. It can hurt
  the captain and can light another keg.
- Crate: breaks into healing salvage.
- Lantern/brazier: breaks into a temporary fire pool.
- Props are recreated at each wave start.

Milestone 1 uses a reduced representative prop layout. Full v11 placement is a
planned data migration.

## 8. Architecture

| File | Responsibility |
|---|---|
| `scripts/game.gd` | run state, waves, combat queries, skills, props, pressure |
| `scripts/game_data.gd` | immutable shapes, elements, enemies, waves, draft data |
| `scripts/player.gd` | CharacterBody2D input, dash, health, camera-facing state |
| `scripts/enemy.gd` | enemy movement, telegraphs, melee/ranged attacks, statuses |
| `scripts/prop.gd` | destructible prop state and signals |
| `scripts/hud.gd` | title, HUD, pause, drafts, results |
| `scenes/*.tscn` | explicit Godot scene composition |

Simulation is ordinary Godot 2D physics. Gameplay boundaries are computed in
world space and remain independent of sprite dimensions.

## 9. Milestone status

**Historical — the Milestone 1 table as of 2026-07-27, kept as the record.**
Nearly every "not yet" row below has since landed; the current state is
`STATUS.md` and the harness (`tests/parity_test.gd`), not this table.

| System | Status | Next proof |
|---|---|---|
| Isolated project and copied references | complete | hash manifest |
| Movement, aim, camera | implemented and smoke-tested | hands-on playtest |
| Basic attack and active skills | implemented | matrix test scene |
| Enemy melee/ranged behavior | implemented | wave-one playtest |
| Boiler and loss state | implemented and smoke-tested | hands-on balance pass |
| Dash and pressure vent | implemented and smoke-tested | hands-on balance pass |
| Reactive props | implemented, reduced layout | full v11 layout |
| Draft | implemented, simplified cards | migrate all 37 cards |
| 12-wave campaign | data present; boss uses temporary heavy behavior | dedicated boss patterns |
| Push waves, crew, boarding hulk | not yet ported | Milestone 2 |
| Audio | key runtime SFX copied, basic playback wired | buses/music/voice director |
| Animation strips | copied, not yet wired | SpriteFrames importer |
| Settings, rebinding, seed, run report | not yet ported | Milestone 3 |
| Automated parity harness | 13-check native smoke test passing | expand to deterministic parity suite |

## 10. Verification policy

No parity claim is made from inspection alone. Each milestone should add a
headless test scene that checks combat cells, wave termination, both loss
conditions, prop chain reactions, pressure distance rules, healing ceilings,
and deterministic seeded runs. Visual verification should cover 1280×720
through 2560×1440.

## 11. Change log

- 2026-07-27: Created isolated Godot project and copied the v11 HTML, modular
  source snapshot, key design references, production runtime art, and `.ogg`
  SFX. Added Milestone 1 architecture and playable systems.

- 2026-07-27: Passed the 13-check headless smoke suite, exported and launch-tested
  the Windows release with Godot 4.7.1, and uploaded version `milestone-1` to
  itch.io channel `alex-unconstrained/skygear-godot-test:windows` (build
  `#1837384`).

- 2026-08-01: This changelog stopped being the record around here — the dated
  sections below (13b onward) are the record, `STATUS.md` is the current state,
  and `docs/OUTSTANDING.md` is the ledger. Header and §9 marked accordingly.

## 12. Target and renderer — decided 2026-07-27

**Windows first, hardware accelerated.** The project was on
`gl_compatibility`, which is the renderer a web export wants; the target is now
a native Windows build on **Forward+ (Vulkan)**. That is the only path that
gives 2D lighting, real batching and shaders — which is the whole reason to be
in an engine rather than in the Canvas 2D build that already exists and is
further along.

Consequences, stated so they are not rediscovered:

- The itch artifact is `SkyGear-Windows.zip` (a single embedded-pck .exe,
  129 MB uncompressed, 59 MB zipped), built by `tools/pack_itch.py`.
- There is no web export and no web export template installed. Adding one later
  means downloading ~1 GB of templates and switching the renderer back for that
  preset, and it would produce a strictly worse artifact than the browser build
  that already exists.
- Forward+ needs Vulkan. On hardware without it Godot falls back and logs; that
  is an accepted cost of choosing acceleration over reach.

## 13. Parity with the browser build, as of 2026-07-27

Verified by `tests/parity_test.gd` — **40 checks, all passing**:

```
godot --path . --headless --script tests/parity_test.gd
```

They are the browser harness's claims, re-asked here: every one of the 36
shape x element cells deals damage; pressure builds in close and only in close;
a full gauge vents, heals, hits and does not refill itself; no burst of healing
beats the 12 hp/s ceiling; lifesteal heals in close and nowhere else; a keg
lights a fuse rather than detonating and its blast lands on what stands in it;
the deck is re-stowed between waves; a cannon gates each lane and fires on the
boarder in it; a boarder attacks the cannon in its way; crew muster; a push wave
grapples a hulk on and does not end until it breaks; every card declares what it
touches; reroll spends one, deals a new hand and stops at zero; a seed deals the
same hand twice and a different seed does not; the Colossus turns at half
health, cannot be burst through the turn, clears what it called, and comes out
of it; damage is attributed to the slot that fired; and all three endings
resolve.

**In:** the twelve-wave schedule, three lanes with cargo walls, deck cannons,
crew, boarding hulks and push waves, the Boiler, the automatic Cleave, nine
shapes crossed with four elements including the three passives, per-skill mods
and resolved stats, the full draft (41 cards across seven scopes, class bands,
affected-skill glyphs, reroll, adaptive slot weighting, seeded rolls),
telemetry with slot attribution and range buckets, the close-quarters loop at
v11.2 numbers, reactive kegs, crates and lanterns, salvage, dash with two
charges and contact damage, readable enemy bolts, the boss's two beats, and a
results screen that is the copyable run report.

**Not yet:** settings and persistence (volume, key rebinding, reduced motion,
the run log); audio beyond one-shot SFX — no music director and no voice layer;
and the presentation pass the browser build has (airstream, camera-tied
envelope, bolt ground shadows and trails, painted billboards rather than
primitives, HUD gauges with art). The browser build also still has 29 checks
this harness does not: layout across resolutions, storage denial, slow-line
loading, the frame budget, and the audio-node leak guard.

## 13b. The camera — corrected 2026-07-27

The port rendered the deck as a **flat overhead 2D scene**, and the game it is
porting has never been that. The browser build hand-writes a perspective camera
in Canvas 2D — 760 ground units above the deck, pitched 0.72 rad (41°), focal
length 1320, dividing by depth — and paints every character as an upright
billboard standing in it. `docs/LEVEL-KIT-BRIEF.md` calls that camera settled and
locked, and **every sprite in `assets/` was generated for it**: figures painted
10–15° above horizontal so they read as standing on a deck seen from 41°.

Rendering that art straight down was showing the right pictures through the
wrong camera, and it is the single most defining visual decision in the project.

**Fixed with an actual 3D camera**, which is what the browser was emulating and
what being in a hardware-accelerated engine is for. `scripts/view3d.gd` mirrors
the running simulation into a Node3D scene each frame:

- a `Camera3D` at the same 41° pitch, following the captain and aimed up-deck so
  she sits below centre with the boarders in front of her;
- `Sprite3D` billboards for every entity, which is the same trick the browser
  performs by hand — except these get real depth sorting and real cast shadows;
- the deck as a plane, the cargo runs as boxes, a gunwale, a hull beneath, and a
  cloud sea below so the void reads as ten thousand feet rather than as nothing;
- two directional lights matching the palette the art is painted for: steel-blue
  moon from the upper left, warm lantern fill from the lower right.

**The simulation is untouched.** It still runs in ground-plane coordinates in the
2D scene, which is still what all 44 parity checks drive; the 3D node only
mirrors it. Ground (x, y) becomes world (x, 0, y), with y as depth exactly as the
browser's TUNING comment says.

## 13c. Screenshot parity — closed 2026-07-27

Section 13b left the camera correct and the picture wrong: the framing was
guessed at rather than solved, and the deck, cargo and Boiler were flat colour.
Held against `.shots/fight-1366x768-art.png`, the port read as a prototype of the
same game. The gap is now closed; `.shots/parity-browser-vs-godot.png` is the
side by side.

**The camera is solved, not tuned.** `camera_back()` is `CAM.recompute()` ported
line for line, and the field of view is the browser's own focal length —
2·atan(430/1320) = 36.1° vertical, not the 52° that was in there. Two checks
assert it: `camera · the lens is the browser's focal length` (the lens value) and
`camera · the captain stands where the art was framed for` (she unprojects to
0.600 of screen height), which is the framing every sprite in `assets/` was
generated against.

**What the picture was missing, in the order it mattered:**

| Was | Is |
| --- | --- |
| Four grey rectangles and some text | Brass panels with riveted corners, the captain portrait, a pressure gauge with its own icon, dash pips, a three-lane readout with cannon health and deepest-boarder markers, and skill slots with shape glyphs and a cooldown sweep |
| Cargo textured with a cut-out sprite, alpha off — black slabs | A tiling procedural crate, a brass rim on four edges, and lashing straps per module |
| Beams and chains drawn as rings the size of their own length | A streak decal aimed along the shot; cones and cleaves get a fan baked per arc |
| Nothing in flight | Bolts with a hot head, a trail, and a shadow on the planking under them — the browser's answer to F-05 |
| No numbers, no plates, no arrows | Damage and healing floaters, health over hurt and elite boarders, status pips, off-screen markers, lane-breaking callouts, banners |
| A 300-unit Boiler with a funnel | A flat engine block per the browser's `boilerH: 132` *(stale — that was a v3/v4 preset; the live v11 build draws `boilerH: 150`, measured by SG-27 on 2026-08-01, and the mesh is now pinned to 150 by `boiler · renders at the browser's boilerH, not a taller mesh's own height`; the PRIMITIVE fallback behind it was quietly a 178-unit dome until SG-30 rebuilt it flat — both tiers now measure 150, the fallback pinned by `boiler · the primitive fallback measures at boilerH on the fallback path itself`)*, with a slatted furnace grille aimed at the camera. The tall one hid the captain behind it for the first second of every run |
| Point lights at 3.4 over five metres | Accents at 1.5 over three, plus a painted pool on the planking under every flame |
| Boarders vanishing behind cargo | The x-ray pass, as a slab test against the eight cargo rects |
| Athwartships planking, one tile grid | Boards along the keel at the browser's 116-unit width, faint staggered butt joints |

**One real bug came out of it.** Damage floaters were scattered with
`rng.randf_range`, which is the *seeded* stream — so every crit roll, scrap roll
and spawn jitter after the first hit of a run shifted. A cosmetic feature was
quietly rewriting the run. There is now a separate `visual_rng` and a check that
`add_floater` leaves `rng.state` alone.

Eleven checks were added for all of this (44 → 55), because the previous harness
drove the model exclusively and therefore could not have caught a port whose
simulation was right and whose picture was a different game.

## 13d. What the last pass added, 2026-07-28

Staged for the next itch push, not yet pushed.

**The voice layer.** 67 takes across nineteen keys were sitting in `audio/voice/`
unused by the port. `scripts/voice.gd` is the browser's `Voice` director ported
with its rules intact, because the rules are the feature: one line at a time,
higher priority cuts in, every key has its own cooldown, the dash grunt is one
in six behind an eight second floor, and nothing is ever announced only by
voice — every call site sits on a mechanical cue that already fires. No
procedural fallback: an absent line is silence, not a synth impression of a
person. Own bus, own volume.

**F-03, the airstream.** It had been ported into `game.gd` and then the scene
that drew it was hidden, so what shipped was nothing. Rebuilt as 48 flat ribbons
lying in the air along the keel, travelling past the camera and shearing with the
captain's lateral movement. Three passes to tune: billboarded (drew every streak
as a horizontal bar, the one direction air down a keel does not travel), then
too many and too bright (milky fog over the fight), then pushed back so nothing
passes within four metres of the lens.

**F-04, the sway.** Reported as "very subtle, didn't notice much even after being
told", which in 2D it was always going to be. A real camera can roll the horizon:
0.85° of roll on two beating periods, 0.42° of yaw, 26 units of heave, none of
them dividing into each other so the motion never resolves into a loop. The
harness turns it off — a camera deliberately never still cannot also be what a
framing check measures against.

**The run report was unreachable.** `_draw_results` had existed since the report
landed and `_draw()` never called it: GAMEOVER and VICTORY both drew a one-line
overlay instead. The telemetry layer, the per-slot attribution and the copy key
were all feeding a screen no player had ever seen.

**The run log.** `scripts/runlog.gd`, `user://runs.json`, last 60 runs, and the
title screen reads a best-wave out of it. One run is an anecdote; the reason v11
tracks damage per skill and time at each range is so ten of them read as a shape.
Total on failure, and the results screen says so out loud when the write did not
land, because a log that silently is not being written is worse than none.

**Rebindable keys.** `scripts/keybinds.gd` plus an F2 screen. Physical keycodes
throughout, so AZERTY gets ZQSD without anyone touching it. Ten actions;
conflicts are refused with the name of the action that already owns the key
rather than silently double-bound. Menu keys are deliberately not on the list —
rebinding your way out of the rebind screen leaves no way back in.

**Harness 55 -> 76.** The three browser groups that had no equivalent here now
do: persistence (the log round-trips, is capped, and reports whether it reached
the disk), keys (rebind, conflict, reload, reset, and that menu keys are out of
scope), and the layout matrix (every HUD plate fits and none overlap at six
window sizes).

## 13e. The VFX layer — answered and rebuilt, 2026-07-28

Asked of the pushed build: *"targeted vfx and auras were all rendering strangely.
are they setup to be working 3d vfx?"* No, they were not. They were flat unshaded
quads lying 1.5 ground units — one and a half centimetres — above the deck plane,
which is a 2D sticker that happens to live in a 3D scene.

**Four defects, all of them visible:**

1. **The pools were keyed by ARRAY INDEX.** `_decal("fx%d" % i, …)` against an
   array that compacts with `remove_at` the moment an entry expires. So node
   `fx3` was one effect this frame and a different one the next: a ring became a
   beam, jumped across the deck and resized halfway through its own fade. The
   same bug ran on fire fields, bolts, bolt trails and salvage. A passive build
   is where it is worst, because a Field and a Sentry append and expire
   something several times a second — which is exactly when it was reported.
2. **A Field drew nothing at all.** `_update_passives` ticks `_damage_circle` at
   150 units and appended no effect, so the aura was 150 units of standing
   damage with no picture. The other passives fake it by appending a circle when
   they fire; a Field fires 1.8 times a second and would have strobed.
3. **Z-fighting.** 0.015 m of separation inside a 0.05–400 m depth range is
   inside the depth buffer's own precision.
4. **Slicing.** A flat plane cannot climb a cargo run, so effects were cut off
   along a hard straight line at every crate and went through the Boiler plinth.

**Rebuilt as actual `Decal` nodes,** which is the one thing that most justifies
being in a 3D renderer for this: a decal projects down a box onto whatever
geometry is inside it, so a ring wraps the deck AND the crate, cannot z-fight
because it is not a surface, and needs no depth ordering against anything.

One trap worth recording: **a Decal's emission channel ignores the texture's
alpha.** Feeding it the ring — white RGB, shaped alpha — lit the entire
projection box, painting a solid glowing rectangle over the deck, the crates and
the fight. The fix is a premultiplied emission map, alpha baked into RGB, so the
hollow parts are black and black emits nothing.

**And it was under FIVE MORE EFFECTS than SG-78 fixed — 2026-08-02, board
SG-63.** SG-78 measured the plate and fixed the aim ring. It did not sweep the
rest, and the rest were all sized from gameplay numbers too: the `circle` shape
(a Pulse at `radius * 2`), the lingering fire fields, the Colossus turn ring,
the Boilerwright's vent stand, and — worst of them — the AURA EDGE, whose radius
comes from `skill_stats` and which a draft card WIDENS. `burst_impact.png` is
the same shape of fault: opaque at its centre, scaling to 520 ground units on a
hulk break. All six draw through `_ring_texture()` now. `slash_arc.png` was
measured on the same run and KEPT — it reads alpha 0 at its centre and peaks
mid-radius, so it is genuinely a rim and the rule does not touch it. The rule is
enforced rather than remembered: `vfx · no ring or burst decal draws through a
plate that measures opaque` greps the renderer's CODE (not its comments — the
first version counted its own explanation as three call sites), and `vfx · the
two retired plates are opaque at their centres` measures the PNGs, so nobody can
retire the rule on the grounds that it stopped mattering.

**And the trap has a second door — found 2026-08-02, board SG-78.** The
premultiplied map only saves you if the SHAPE is hollow. `_art("ring", …)`
prefers the painted plate `assets/art/ground/rune_player.png` over the generated
rim-only `_ring_texture()`, and that plate is 68 percent alpha-255: a filled
disc with a circular cutout, not a ring. Premultiplying a filled disc gives a
filled glow map, so the SG-60 aim ring — drawn at `range * 2`, 840 ground units
for a Mortar — lit as a glowing opaque plate across half the deck, which is what
the owner photographed. The rule the fix leaves behind: **a decal whose size
scales with a gameplay number must draw through a texture whose hollowness is
guaranteed**, which for now means `_ring_texture()` and not the painted seam.

**The aura got a body.** A soft cylinder of charged air around the captain with
its far wall only — you are standing inside it, so the near wall is between the
camera and you, and additively that bleached her and anyone next to her — plus a
decal ring on the planking marking exactly where it stops. Both driven from
`skill_stats` each frame, so a card that widens the field widens the picture.

**And effects anchored to the captain now follow her.** A cleave baked at the
position you cast it from slides out of your hands at dash speed, which is most
of its own lifetime.

Five checks guard all of it.

## 13f. The captain, as a mesh — parked

A Meshy OBJ arrived and is in `reference/models/captain/`, which carries a
`.gdignore` so Godot never imports it. `tools/pose_captain.py` brings her out of
the T-pose Meshy exports — no skeleton to pose with, but the geometry separates
cleanly (body inside |x| < 0.24, arms out to 0.95), so the arms rotate about a
shoulder pivot with the angle ramped across the joint. That is a skin cluster
with one bone a side and a hand-authored falloff.

`SkyGearView3D.USE_MESH_CAPTAIN` is **false**. A static unrigged mesh slides
across a deck in a fixed pose, which reads worse than the painted billboard it
replaced — the billboard at least has an artist's stance in it. The loader stays
in place for a rigged export; what it wants is Y up, facing +Z at rest, roughly
1.8 units crown to sole, glTF/GLB so the skeleton and animations come with it,
moved into `assets/models/captain/`.

## 13g. The HUD moved to the bottom, 2026-07-28

The objective plate and the lane readout sat in the top-right corner, and **the
top of the frame is where boarders come from**. Two panels, 348 wide and 250 tall
between them, were covering the deck a player most needs to watch — and the lane
readout, whose entire job is to say a lane is breaking, was covering the lane
that was breaking.

One band along the bottom now: her on the left, her hand in the middle, the ship
on the right, all on one baseline. The objective and the lanes merged into one
plate because they are one answer to one question. The side plates take whatever
is left after the hand rather than a fixed width — three clusters at their
preferred sizes want 1258 px, and a HUD that overlaps itself on a 1152-wide
window is a bug rather than a hardware requirement.

The layout matrix now drives `SkyGearHUD.hud_plates` rather than a second copy of
the arithmetic, so the check cannot drift from what is drawn. It also asserts
nothing is in the top 60% of the screen, which is the property that was actually
wanted and was never stated.

Full brief, including the nine pieces of art being generated against it, in
`docs/HUD-PLAN.md`.

## 13h. The model pipeline and the animation engine, 2026-07-28

**`tools/ingest_model.py` + `tools/ingest_model.gd`.** Bringing the captain in
took an afternoon and three false starts, and none of the work was about her.
Every rigged model has the same six problems — 190 MB of FBX because each clip
embeds the mesh, a different rest pose per clip, clips disagreeing where the rig
lives, an imported material pointing into a directory about to be deleted, maps
far too big, and a unit scale on the root that naive placement overwrites. All
six are solved once, from `tools/models.json`, and the result is verified **after
the sources are deleted** — the captain passed a load check while the FBXs were
still on disk and then failed to load in the game.

Running it against the captain reproduces her exactly: 6 clips, 20 track paths
repathed for the Rigify-sourced swing, self-contained, 7.7 MB.

**`scripts/rig3d.gd`.** Her state machine was four `if`s in the renderer, a yaw
written straight onto the transform, and no notion of a clip finishing. That is
enough for one character and wrong for two, with five boarders and a crew behind
her. The component owns: clips chosen by priority, one-shots that hold for their
own length rather than being cancelled by the state underneath, a **rate-limited
turn that goes the short way round** (lerping raw angles takes the long way
whenever a turn crosses PI, which looks like a figure spinning to avoid you),
playback speed matched to actual ground speed so feet stop skating, and hit/land
reactions as decaying scalars rather than Tween allocations per hit.

Clip fallback is part of it: `run` degrades to `walk` degrades to `idle`. The
boarders will arrive with fewer cycles than she has, and the renderer should not
have to know that.

## 13i. VFX

`VFX-PLAN.md` ranks the work by one test — can a player answer a question faster
with it than without — and names the four questions worth answering. Top three
are impact particles, hit-stop with additive shake, and element identity carried
by light rather than by hue. Every item gets a check that asserts its pool is
capped, because every performance problem this project has had was an unbounded
collection and not a slow algorithm.

## 13j. Tools, as a standing policy — 2026-07-28

Asked for directly: on this game, before doing a piece of work, ask what tool
would make this and every future instance of it cheaper, and build the tool.

The project has paid for the same manual work twice more than once. The captain
took an afternoon of hand-holding before `tools/ingest_model.py` existed. HUD
positions were being nudged three pixels at a time through a patch, rebuild,
screenshot, look loop — a turn per adjustment, on a question whose answer is a
matter of taste and therefore one I cannot settle alone.

The test for whether to build a tool: is the work going to recur, is it a
feedback loop I cannot close myself, or is it something Alex could do faster
than he could describe? Any of those and the tool is worth the hour.

Tools so far: `tools/forge.py` (art, prompts beside the manifest key they fill),
`tools/ingest_model.py` (rigged models, archive to usable scene, verified after
the sources are deleted), `tools/ingest_ui.py`, and the HUD layout editor below.

## 13k. The HUD layout editor (F4)

The positions were constants in `_draw`. Now they are `assets/hud_layout.json`,
the game reads it, and F4 lets a person drag the panels and save.

What makes it worth having rather than an external mockup tool: **the panels
being dragged are the real panels, with the real content, at the real
resolution, over the real fight.** A mockup is a picture of a decision; this is
the decision.

- **Anchored, not absolute.** A panel records which screen corner it hangs off
  and how far in, so one hand-placed layout is correct at 1280 and at 2560.
  Re-anchoring never moves the panel, only what its offset is measured from —
  otherwise every anchor change is also a jump and the editor is a puzzle.
- **Guides and a verdict.** Edges snap-highlight against other panels, and the
  top bar says clean, or names what is wrong: off screen, overlapping, or crept
  back into the top half where the boarders come from.
- **Nothing a person can do in it can break the game.** A malformed file falls
  back per panel, so a bad edit costs one panel rather than the HUD. Panels have
  a floor size. Ctrl+R restores. Eight checks cover the round trip, the anchor
  invariant, and the refusal of nonsense.

Saving writes `user://hud_layout.json`, which wins over the shipped file.
Promoting a layout to the default is copying one file. `docs/HUD-LAYOUT.md` is
the page for whoever is doing the dragging.

## 13l. The melee pack — the pipeline paying for itself, 2026-07-28

A Mixamo-style axe pack arrived: one 25 MB character FBX with the mesh and skin,
and 47 animation-only clips at a fifth of a megabyte each. Total 38 MB, against
190 MB for six Meshy clips, because these do not each embed the whole character.

**Bringing it in cost two small pipeline additions and a manifest entry.** That
is the return on `tools/ingest_model.py`: the first character took an afternoon
and three false starts, this one took a `models.json` edit and one command.

- All 33 bones share the Mixamo naming and every clip sits a **consistent 19.6
  degrees** off the character's rest — one retarget covers all fourteen, and the
  code that does it was already written for the Meshy pack's much worse case.
- The rig came from the CHARACTER file this time rather than from an animation
  file. The manifest says which, so neither is special-cased.
- **`maps_archive`** is the one new manifest key: an animation pack retargeted
  onto a character ships the clips and the character but not the source textures
  at a useful size, and re-extracting a 4096 albedo from an FBX we are about to
  delete is work for nothing when the original archive is still on disk.

**Fourteen clips, up from six**: idle and a looking variant, walk, run, run back,
four distinct melee attacks plus a spin and a combo, jump, a flinch, a block and
a taunt. `SkyGearRig3D.VARIANTS` cycles the attacks, so repeated casts no longer
perform the identical horizontal cut — which reads worse than a billboard,
because a billboard never claimed to be swinging. The flinch is wired to taking
damage, which the port had no animation for at all.

**Two checks were wrong and the new pack found them.** One asserted every
animation track began with `Armature/Skeleton3D` — true of the Meshy rig, false
of a Mixamo one, and irrelevant either way: what matters is that a track
*resolves*, which is the thing that was actually broken when the swing clip
animated nothing. The other multiplied by 1.92153, the old model's height in
its own units. This one measures 0.018. Both now assert the invariant instead
of the constant, which is the entire point of normalising by height.

**Still open:** the pack is authored for a character holding an axe and ships no
axe. She reads acceptably because she already wears a heavy brass gauntlet on
the swing arm, but a weapon mesh attached to `mixamorig_RightHand` would make
the animations mean what they were animated to mean.

**The precedent paid again, 2026-08-02 (board SG-74).** The second pack — the
owner's Great Sword Pack: his own Boilerwright mesh auto-rigged by Mixamo plus
51 animation-only clips — went through this exact path as one `models.json`
entry and one command. Every clip sat a consistent 57.4 degrees off the rig's
rest (this pack's 19.6), one retarget covered all 51, and `maps_archive`
earned its keep a second time: the Mixamo FBX is untextured, so the maps come
from the Meshy originals still on disk. The one new lesson: the OBJ that went
through Mixamo carried the refine mesh (12,476 tris), not the remesh — a
skinned mesh cannot be re-decimated after the fact, so the count is pinned by
its own check rather than silently accepted, and the fix is a re-export, not
surgery.

**And a third time, on the same day (board SG-85) — the furnace knight.** The
owner's Emberforge Sentinel came back from Mixamo as the same shape again (one
rigged FBX, 51 clips, a consistent 30.7 degrees off rest) and ingested as one
manifest entry and one command, this time for an ENEMY rather than a class:
the entry is keyed by the enemy kind, so the renderer picked him up with no
code change at all. Two things this third pass added to the pipeline itself:

- **An emission reader.** `ingest_model.gd` had thrown every emission map away
  since the captain, because nothing on the deck needed one; the knight's
  identity is a furnace-grille chest, so it reads one now — `emission`, sized
  and downscaled like any other map, with `emission_energy` as manifest data.
  The trap is worth writing down, because two sessions have now hit it from
  opposite sides: StandardMaterial3D's emission operator is ADD, so the base
  colour must stay BLACK. A white base with a map on top does not tint the map,
  it emits `(white + map) x energy` over the whole mesh — the flat white
  silhouette SG-65 spent a session on. And a Meshy emission sheet is authored
  dim (his peaks at 49/255, 0.03 in linear light), which is why the energy is
  data and not a constant.
- **A walk is not a slow run.** `AUTHORED_RUN_SPEED` rated both, which was
  invisible while every animated figure ran. A boarder at 75 ground units a
  second put the rate under its own floor and skated. There are two authored
  speeds now, measured off the pack's own root motion before the ingest
  in-places it, and `SkyGearRig3D.gait()` picks the cycle that has to be
  strained less.

**The 13l "still open" above now has a second name on it.** This pack ships no
weapon either, and the knight is worse off than the captain for it: his painted
sprite carries a double-bladed axe and his mesh carries nothing. The mount seam
(`weapons.json` + `hold()`) has worked since the cutlass; what is missing is the
asset. Board SG-86.

## 13m. Response to the rendering audit — 2026-07-28

`docs/VFX-RESEARCH-AUDIT.md` arrived and found four things wrong with work that
had shipped that same day. All four were correct. Recorded here with what has
been done, because a critique that gets read and not acted on is worse than one
that never arrived.

### Fixed

**Finding 3 — the particle architecture was wrong, and one part of it was a
bug.** `restart()` on a shared one-shot emitter throws away the particles
already in flight, so two boarders dying half a second apart meant the second
kill erased the first one's sparks: every impact after the first was, on screen,
the only impact. And `amount_ratio` does not reduce processing cost — the
capacity stays allocated — so scaling it by damage bought nothing. Rebuilt on
`emit_particle`, which injects particles individually into an emitter that is
never restarted. Emitters are now keyed by **behaviour** (spark, shard, steam)
rather than by element, with the colour riding on the particle.

**Finding 4 — coloured light is still a hue cue.** The plan claimed element
identity had moved "through light, not hue". That was wrong: coloured light *is*
hue, and it cannot be the accessibility answer on its own. Each element now has a
motion and timing signature that survives colour blindness — Frost falls, snaps
outward in a narrow cone and its light dies at 26/s; Ember rises, spreads wide
and lingers at 8/s. The flashes stay as reinforcement, now with
`light_volumetric_fog_energy = 0` so a fog-lit scene does not keep a trail of
every hit.

**Finding 2 — the "pools" were not pools.** They freed every unclaimed node each
frame and built a new one when it was next needed, which is churn with the word
pool written on it. Decals and billboards are now hidden and returned to a free
list, claimed back on demand, with the list trimmed past a slack of 24 so a keg
chain does not leave hundreds of hidden nodes resident. Rigs are deliberately
still freed: a character is a whole scene with a skeleton and an animation
player, and holding a dead boarder's is holding far more than a sprite.

**Finding 1 — Forward+ does not mean Vulkan.** The renderer and the driver are
separate settings and the project never selected a driver, so the "Forward+
(Vulkan)" claim in this document was an assumption. It happens to be true on this
machine. `scripts/renderer_check.gd` now reports both at runtime. More
importantly: **Compatibility cannot draw `Decal`**, and every gameplay telegraph
in this game is a Decal — the enemy windup rune, the aura edge, the mortar ring,
the contact shadows. A player dropped to Compatibility would not get a
worse-looking game, they would get one with the tells missing and nothing saying
so. There is now a warning for that case.

### Still open from the audit

- ~~**Reserved capacity per pool.**~~ DONE (commit 1144d44, verified under
  SG-25 2026-08-02): decals carry per-class live budgets — `DECAL_BUDGET`,
  48 telegraph / 24 player / 40 decor — so a scorch mark can never spend a
  telegraph's slot. The free NODE list stays shared deliberately: a claim
  that misses it builds a fresh node, so sharing recycled nodes cannot
  displace anything. Harness: `budget · a telegraph draws from its own
  reserve`, `budget · decoration cannot spend past its own allowance`,
  `budget · and a telegraph still gets drawn on a flooded deck`.
- ~~**D3D12 has never been tested.**~~ Ran for the first time 2026-08-02
  (SG-25, RTX 5080): boots and renders Forward+ over D3D12. Windowed wave-11
  profile: frame p50 4.92 ms vs Vulkan's 4.40, vram 796 vs 703 MB — works,
  slightly behind Vulkan, no reason to switch. Harness also green under
  `--rendering-driver d3d12` (596/596 — though headless, so that run
  exercises no GPU path; the windowed boot is the evidence).
- **`fixed_fps` / visibility AABB tuning** is set from the audit's guidance.
  The port now HAS a first profile (`tools/profile_fight.gd`, SG-25 baseline
  on the board: frame p50 4.40 / p99 7.96 ms at 40 boarders, RTX 5080), but
  one baseline is not a comparison — the tuning itself remains unprofiled,
  and nothing was tuned from one profile.
- Sections beyond the four findings — tonemapping and grading, shader-stutter
  prevention, the validation requirements — have been read but not yet worked
  through.

## 14. Known differences that are deliberate

- **Enemy separation** is Godot's own physics rather than the browser's hand-
  written pass, so crowds spread differently. The browser's numbers were tuned
  against its own solver and porting them literally would be cargo cult.
- **The deck is 1680 x 2320 in world units and lanes sit at -560/0/560**, which
  matches v11 rather than the browser's current geometry helper. Any future
  change to lane width has to move both.
- **No web export.** Windows first, Forward+, see section 12.
