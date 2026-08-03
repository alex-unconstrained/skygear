# NEEDS ALEX

_Last updated: 2026-08-02, build 44._

## The Colossus is textured — here is the frame. "Too easy" is still open. (SG-94)

Your ask: *"Collosus is way too easy - he needs to be scary the player. Not sure
what's going on with his texture."* Two of those three faults are fixed and the
third is yours to steer.

**The texture: nothing was on him.** The part-segmentation file he was cut from
is a visualisation — no UVs, zero bytes of image — so every part wore a flat
colour and the furnace lamp glowed inside an untextured body. The textured twin
you sent is now the surface the thirteen parts are cut FROM, with the
segmentation kept only as the label source. He keeps all thirteen parts, their
joints, all five beats and the disassembly (one foot still never lets go).

**The blobs: his shadow was one ellipse at his origin.** Fine for a boarder,
wrong for a machine whose death throws it across two metres of deck — the blob
stayed where he no longer was. Each part now shades the planking under its own
footprint. Your wider "dynamic shadows, not one circle blob under everything"
ask is filed separately as SG-95 and was deliberately not touched here.

**Look at `.shots/clips/boss_before_after.png`** — your frame on top, the same
staging underneath. `.shots/clips/boss.png` is the still on its own at the real
camera with the captain in it for scale, and `.shots/clips/boss.gif` is ten
seconds of the walk, the slam, the turn and the death.

**The question — and it is the half I did not touch:** "way too easy" is a
DESIGN change, not a number nudge, so it is filed as SG-96 rather than guessed
at. He has two beats and neither threatens you. It belongs with your furnace
knight ask from the same playtest ("hard hitting but designed to be dodged") —
both are about enemies you READ and RESPECT rather than out-damage. What should
he make you DO? He now looks the part, which makes the mismatch sharper.

## The title screen is rebuilt — does the vocabulary feel right before it spreads? (SG-91)

Your ask: *"the header UI element feels on-theme but the rest are just simple
text boxes."* The rest are hardware now — a riveted brass board with real
plates on it, an engraved channel under every label, a lit lamp on the plate you
are pointing at, the Heat chips turned into rungs bolted across a rail, BEGIN RUN
made obviously the door, and QUIT turned into a small iron hatch off the bottom
of the board. `docs/MENU-DESIGN.md` is the survey and the vocabulary; the whole
thing is drawn with primitives the Workshop board already used, so no new art.

**Look at `.shots/sg91/compare-title-heat-1920x1080.png`** (before beside after),
and `compare-title-1600x900.png` for the fresh-profile version at the minimum
window. 797/797 harness, text audit clean at all four widths.

**The question:** does this vocabulary feel like the ship? If yes, SG-93 spreads
it to SETTINGS, HOW TO PLAY, CONTROLS and PAUSE — deliberately NOT done in the
same pass, because you asked to see the direction first and because those four
are `ui.row` columns (left label, right value) rather than centred plates, so
they want one more noun rather than a reuse of this one. If it is wrong, it is
wrong in one file and one screen.

## The tail of the board — one thing needs your eye, one is a warning

**SG-84 — you are now STOPPED at the boarding hulk, and you asked for a
feel-check before anybody picked a fix, so here is the fix and here is the
question.** You could walk into the hulk and vanish inside it — harmless when it
was a painted card, not harmless since it became a 429-unit hull. She is pushed
out of it now, in the same function that already stops her at the cargo, off the
same `hulk.radius` the crew march on and every splash measures against — one
number, not a second copy. Deliberately the MINIMUM fix: a circle at the hull's
own radius, nothing clever.

What that costs, and what I want you to feel: **it changes movement at the bow on
every push wave.** The hull sits 190 units across the middle of the bow, and you
now slide around it instead of through it. Because the deck reaches further north
than the hull's centre, being pushed out at the very top of the deck puts you
ASTERN of it rather than in front — there is no ship on the other side to stand
on. Play a wave 4 or a wave 8 and tell me: does being stopped there feel right,
or does it feel like the bow got smaller? If it feels wrong, the honest answers
are a smaller radius or a bow-only exception. What I do NOT want to do is give
the hulk a second collision shape that disagrees with the one the crew use —
that is the failure mode this project keeps filing.

Before: `.shots/sg84/inside-the-hull-before.png` (you are not in the frame at
all). After: `.shots/sg84/stopped-at-the-hull.png`.

**SG-72 — the railings are 3D and the cargo hatches are staying painted, and I
want you to know I chose that rather than ran out of money.** The railing won on
its second roll and looks right. The hatch was generated three times and lost
every time: it lies FLAT in the planking, so at our camera almost everything you
see of it is its own top face — which is a texture whether it is a mesh or a
card. Three rolls, three boxes standing proud of the deck, reading as a fifth
kind of crate on a ship that already has four. If you disagree, the prompts and
all three verdicts are written where they wait in `tools/meshy.py`; it is 35
credits to reopen. **140 of the 200 credits spent; balance 1857.**

**A WARNING FOR WHOEVER RUNS THE MODEL TOOLS NEXT, and it cost me a confusing
half hour.** `tools/static_model.gd` rebuilds the `.tscn` for EVERY key in its
table — including the RIGGED figures. Running it to wrap one new static prop
silently overwrote `scrapper.tscn` and its neighbours with dumb static holders,
and the harness went to 725/729 with the boss reporting one part where thirteen
should be. It does not warn. I reverted them and nothing of that is in this
commit, but the tool should probably refuse to touch a key that has an
AnimationLibrary beside it. Not fixed — it is not my row and somebody else is in
that file right now.

**One honest defect in my own commit, and it is already healed.** Two of us
were committing into this tree within the same hour. `fa14403` (mine) picked up
nine `menu ·` checks that had appeared in `tests/parity_test.gd` while I was
staging it, without the `hud.gd` constants they read — so THAT COMMIT ALONE does
not parse. The very next commit, `16e778e`, brings the constants and main is
green again: **797/797, text audit clean, containment clean, 0 faint, 0 small.**
Nothing is broken now and nothing needs doing; but if you ever bisect across this
evening, `fa14403` is the one commit that will not run, and the reason is
staging, not code. I did not rewrite it — it is not mine alone any more, and
rebasing somebody else's commit off the top to tidy my own is worse than the
untidiness.

**And a housekeeping note you may already know:** two of us were writing this
tree at the same time this evening. `scripts/hud.gd` had an in-flight menu
redesign in it (SG-91, `docs/MENU-DESIGN.md`) while I was fixing the BERTHS
screen in the same file. I committed only my own hunks and left the menu work
untouched in your working tree — but that is a coin-flip I would rather not
repeat, and it is why my new row is numbered SG-92 rather than the SG-87 I first
claimed.

## Build 44 is live — the deck is ALL MESH

**Nothing painted stands on the planking any more.** You modelled the last four
figures yourself this afternoon and every one is wired: the crew (bayonet stab,
and Dying Backwards as a real death), the goblin swarm (three attacks and a
death; six of them are six skeletons sharing ONE mesh), the gunner drone (its
three rotors actually turn — the export was one welded surface, so a new tool
found the blades by measurement), and the Colossus — 1,366,036 triangles down
to 7,994 locally for zero credits, dying by coming apart at the joints it
hinged on, in sequence, with one foot that never releases so it collapses off
its own anchor.

**Every dying thing on this deck now has a death.** It had none this morning.

Two numbers worth your eye: the boss stands at **330 units** (the sim's own
number for the archetype, not my spec's 360 guess) — does it read big enough
beside the knight? And the crew came out at **165**, retiring a hard-coded 110
that was simply wrong.

Clips: `.shots/clips/{crew,swarm,drone,boss,deck44}.gif`.

## Build 43 — what landed before it

**You made two of its best pieces.** The hulk's three states and the furnace
knight both came from your own Meshy sessions after prompted attempts failed;
`handoff-3d/` is now an empty queue.

- **THE DECK IS ALL MESH NOW — feel-check the crowd, not the figures.** Your
  crew, your goblin and your drone are all in and each looks right on its own;
  what nobody can tell you from a still is whether a **late wave still reads**
  with six goblins scuttling at 230 units a second, four drones bobbing over
  them and your own sailors dying in the lanes. Watch `.shots/clips/swarm.gif`,
  `crew.gif` and `drone.gif` in that order and say whether the deck got busier
  or noisier. (Two specifics if you want them: your crew now stand **165**
  ground units instead of the 110 the sprites were drawn at, which is a head
  under the captain rather than two thirds of her — and the goblin has **no
  flinch clip** in its pack, so a stunned one does not react. Both are cheap to
  change.)
- **THE BOSS COMES APART WHEN IT DIES — feel-check it.** Your segmented
  Juggernaut is wired and your call on the approach was the right one; the
  Colossus now walks, slams, plays the half-health turn, and its thirteen parts
  break at the joints they hinged on and land on the planking.
  `.shots/clips/boss.gif`.
- **The furnace knight walks, swings and DIES** — the game's first death
  animation; a 180-hp wall that falls on the planking instead of vanishing.
  `.shots/clips/knight.gif` against `knight-before.gif`.
- **The boarding hulk has three real faces.** Two of your three filenames were
  mislabelled and the evidence overruled them: *Ironbound Gate* is the SEALED
  state (emission map entirely black), *Emberforge Core* is OPEN (the only one
  with fire in it). Also: the sealed state had **never once been on screen** in
  this port's life — the sim marked the hulk vulnerable the instant it grappled.
  There is a real invulnerable beat now while the door is shut.
- **Aim is just the reticle**, per your spec. (The "ring" was drawing a painted
  plate that is a filled disc with a hole in it — hence the flood.)
- **The impact puffs and the explosions are 3D now** — the particles were flat
  cards facing the camera, so a steam plume was one painted cloud sprite
  stacked forty times; and the explosion itself (every kill, every keg) was a
  cartoon starburst lying on the floor. `.shots/sg63/burst-before-after.png`,
  `.shots/sg63/puff-before-after.png`, and the clips in `.shots/sg63/clips/`.
- **THE CAPE: I rebuilt it, it is no longer a plank, and I left it OFF — your
  call.** Look at `.shots/sg63/cape-before-after.png`: the left column is what
  you called atrocious (a flat red signboard with straight edges), the right
  column is the rebuild — eighteen bones instead of four, real folds that
  catch the light, a scalloped hem, and cloth instead of the deck-planking
  texture in red. `.shots/sg63/clips/sg63-cape-dash-before.gif` against
  `sg63-cape-dash-after.gif` is the same in motion. **I did not turn it on**:
  you have vetoed it twice by eye, and all I can prove is that the GEOMETRY is
  no longer the reason it looked wrong. If you want it, it is one line —
  uncomment `"captain": {}` in `HERO_CLOAKS` (`scripts/view3d.gd`) and flip
  the `cloak · no class wears a cape` check. If you still hate it, say so and
  it gets deleted rather than parked.
- **Every prop was oversized** for one systematic reason and all are trued now.
- **THE MODELS CAN BE LIT NOW, AND YOU CAN DO IT YOURSELF (SG-81).** `SkyGear
  Tools.bat lab` → pick a model → the new **LIGHTS** button: ADD OMNI or ADD
  SPOT on the right, dial colour/strength/reach/falloff/offset/cone/throb on the
  left (click any number to type it, wheel a row to nudge), turn on **DARK
  ROOM** to see only the light you are making, then **SAVE** — it writes
  `assets/models/lights.json` and the game reads it on the next launch, on every
  one of that model on the deck. **Feel-check the five I seeded**: the brazier,
  the lantern post, the steam vent (a cone aimed up out of the grate), the
  Boiler, and the furnace knight. The first four are dialled to reproduce the
  lights they already had, so the deck should look the same to you; the knight's
  chest light is new and is my answer to question 2 below.
- **The last painted cards are off the deck (SG-63).** Impact sparks, shards
  and steam puffs are real bodies now (the steam tumbles, so deck lamps travel
  across it); explosions finally have geometry in the AIR — every kill, keg and
  hulk break had been drawing a flat painted starburst on the planking. And the
  filled-plate trap that flooded your aim ring was open under FIVE more effects
  (the circle shape, fire fields, the Colossus turn ring, the vent stand ring,
  and the aura edge a card widens) — all hollow now.
- **F4 resizes text boxes**, and **your saves work** — see below.

## Answers you owe (quick)

1. **Do the cannons now read too small?** They were the worst scale offender
   (2.07× oversized) and came down the most. If they look wrong, it is their
   130-unit height constant to raise, not the new ruler to loosen.
2. **The knight's chest glow — partly answered, and it wants your eye.** He now
   carries a per-model light from SG-81's table (a 1.15-energy warm omni at the
   chest), which measurably lifts him: right-hand knight 30.4 → 33.4 mean
   luminance, 10 → 276 hot-orange pixels over the same crop. It does NOT shut
   the gap to the painting's 45.4, and one of three knights came out flat
   because a brazier beside him gave up its omni to the light budget. Is he
   bright enough now, or does he want more? It is one number in the lab.
   (SG-81 / SG-86)
3. **SG-84 — the captain can walk *inside* the hulk and vanish.** Harmless with
   a flat card, not with a 429-unit-deep hull. It is a movement change, so it
   wants your feel-check before I pick a fix.
4. **The Muster** (ENEMY-VARIETY §2.1) is the biggest remaining gameplay item
   and still waits on your noise-floor threshold from the tempo work.
5. **SG-24 — WHICH menu drifts right?** The sentries-turned-orbs bug is found
   and fixed (it was the billboard pool handing a shelved spark's additive
   material to the next thing that claimed the node — see SG-66). The drifting
   menus are the one of the four I still cannot reproduce, and I looked again
   today after a day of heavy renderer changes: all 24 posed screens, all four
   widths, sixty redraws each, every widget rectangle compared — nothing moved,
   at any width. The row stays OPEN, not closed, because not reproducing it is
   not the same as it not happening. Name the screen (pause? draft? the
   settings sheet?) and roughly how fast it walks, and I have somewhere to look.
6. **Codex is running in your repo.** A branch `codex/browser-2d-godot-parity`
   appeared mid-session building a new browser 2D project. Not mine, and not
   yours as far as I know. It left its branch checked out over my working tree,
   which cost some untangling. Worth knowing it is there; it cuts against the
   retired-parity direction if it is meant seriously.

## Your F4 saves — the cause was ugly

Your alignment work was not lost to a broken save. **The harness was deleting
`user://hud_layout.json` six times per run** and writing fixtures over it — and
agents run the harness on your machine constantly. Same family as the bug where
posed screens wrote fake rows into your run log. Fixed: the harness uses a
scratch file, and the last check of every run proves your real file was never
touched. Two dead keys fixed too (the picker swallowed Ctrl+S; inside the typed
box Ctrl+S typed a literal "s"), and the editor now says `SAVED · <path>` or
shouts if a write fails. **Redo that pass on build 42** — worth it now, since
every prop changed size anyway.

## Still open from before

- **Boilerwright feel-checks**: do the wrench cuts read as wrench work, does
  the Tap Main kneel feel planted (0.7 s)?
- **Heat 3–5**: brutal-fair or just brutal? The bot went 0/6 at Heat 3.
- **The berths and the six fittings** — confirm or amend the set.
- **Scrapper rollout**: the pilot says SWARM/ARMORED via Meshy, the boss via the
  free local rig, the gunner procedural forever. Approve and I run it.
- **Your cutlass fit** is still uncommitted in the tree, preserved through every
  build. Re-fit it in the fixed lab (`model_lab --fit captain`) and say the word
  to commit it.

## Next round, ready to start

Unblocked and queued: **SG-81** (lab lighting — attach and tune lights per model,
saved where the renderer reads them; the tool you asked for), **SG-63** (the last
2D reads: impact particles, in-air skill shapes, and the cape rebuild), and the
**figure migration** for the remaining boarders. Say if you would rather steer
elsewhere.
