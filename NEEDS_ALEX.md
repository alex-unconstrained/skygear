# NEEDS ALEX

_Last updated: 2026-08-02, build 42._

## Build 42 is live — what to look at

**You made two of its best pieces.** The hulk's three states and the furnace
knight both came from your own Meshy sessions after prompted attempts failed;
`handoff-3d/` is now an empty queue.

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
- **The cape is gone**, off by default until a rebuild earns it back.
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
5. **Codex is running in your repo.** A branch `codex/browser-2d-godot-parity`
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
