# NEEDS ALEX

**Build 71 IS LIVE ON ITCH, as two downloads off one commit · harness
1227/1227 · there is an opening film and it is nine chibi shots of your
captain.**

- **`windows-demo`** build **#1876328** — the demo cut. First build on that
  channel. Launched and photographed before it went up: it says *"six boarding
  waves"* and has no class picker.
- **`windows`** build **#1876329** — the full game, with everything below. Detail
lives in `skygear-godot/docs/BOARD.md`, which is now **the open queue and
nothing else** — you asked for that and it went from 758 KB and 233 rows to
94 KB and 38, with all 198 resolved rows and their evidence in
`docs/BOARD-ARCHIVE.md`.

*Last cleaned 2026-08-11. Everything you answered is off this list.*

---

## What changed, and what to look at

**THE OPENING FILM EXISTS.** Nine shots, 53.5 s with the title card, under your
60 s ceiling. You ruled chibi and then sharpened it — *"I just want cutscenes to
honor the reference images and assets created for the protagonist so it's
consistent"* — so every shot the captain stands in carries **both** of his
reference sprites rather than one, and the renderer now **refuses to run** if a
captain shot loses its face reference. Shot 3 was auditioned before the other
eight were committed: same face, same goggles, same gold-starred red coat, same
gauntlet. It plays once at launch, is skippable from the first frame, and
SETTINGS has a WATCH THE OPENING row for when you want it back.

**THERE IS A DEMO BUILD NOW** — waves 1–6, Captain only, Heat 0, no fittings or
berths, results screen intact, end card on the win. That is **your own written
cut**, `docs/STEAM-LAUNCH.md:598`, built as written. It is an export feature
tag, not a second source tree, so both exes come off one commit and one harness
run. Seven checks prove every gate in both states.

**Every string in the game is a real typeface for the first time** — Oswald over
Lato, both OFL, licences in `assets/fonts/`. The four screens a new player opens
in minute one are drawn in the title's own hardware now: plates, bevels, rivets
and engraved channels instead of hairline rectangles.

**A landed hit makes a sound and the body reacts.** Neither had ever happened:
`damage_enemy` contained no `play_sfx` at all, and `react_hit` had two callers
in the whole repo, neither of them an enemy.

---

## Waiting on you

**1 · TWO THINGS ARE SHIPPED AND HAVE NOT BEEN LOOKED AT, AND THEY ARE BOTH
VISUAL.** The GPU was rendering your film for the whole session, and a Godot
capture pass and a ComfyUI render contend hard for the one card — the freeze on
2026-08-11 is why that rule exists. So: **the ink pass** (`deck_post.gdshader`,
your shader ask — a depth-and-normal edge plus a vignette over the deck) and
**the new fonts at four widths** are in the build unverified. Both are one line
to switch off: `view3d.set_deck_post(false)`, and `hud.gd`'s two face constants.
If the edge is wrong, say so and it goes — it is not load-bearing.

**2 · THE CAPTAIN'S PORTRAIT IS FINALLY BEING REDRAWN, AND YOU PICK THE FRAME.**
`portrait_corsair.png` is still the red-haired woman in the blue coat, worn by
both captains because it is the only portrait in the project. There is no image
generator on this machine, so it is coming from a 124-frame push onto his face
generated from the same two references the film uses. Run
`python tools/portrait_from_clip.py --sheet`, look, then `--frame N`.

**3 · SG-240 WAS A REPORTING BUG AND YOUR DECISION IS SMALLER THAN IT LOOKED.**
`forge.py list` said "0 delivered" for seven assets whose files have been on
disk and in use since 2026-08-01, because `existing()` asked the **browser**
build's manifest and only that — a Godot-era batch could never report delivered
whatever was there. It asks both trees now: **all seven are delivered.** So the
33 paid generations are candidate *replacements* for live art, not missing art,
and nothing is blocked on picking them. They are also still unreachable — they
live on the Loom, which is not on this machine.

**4 · HEAT 5 IS STILL A WALL, NOT A RUNG.** Unchanged and still yours:
0 of 120 runs held it, dead on wave 4 every time. SETTINGS → OPEN ALL HEATS →
any rung. (That row is hidden in the demo build, deliberately.)

**5 · CLEAVE'S LAST TWO QUESTIONS**, from your own live play. You already
answered the one that mattered — *"the cleave indicator is correct"* — and the
P1 you found with it (the swing drawing away from the bodies) is fixed. Still
open when you next play: **(b)** is 24-versus-20 something you *feel*, or only
something the floaters told you? **(c)** does anything hide the marker when you
fight beside the Boiler?

---

## Smaller calls, whenever

- **The demo's end card** names five things the full game has. Read it once —
  it is the last thing a demo player sees and it is the whole pitch.
- **The menus have a bed under them now** (storm, then the ship) because there
  is no menu track and three fight tracks. If you want music on the title
  instead, that is a composition, not a setting.
- **The crew look stacked** — buyable renderer-side without moving the
  simulation. Want it?
- **RESIDUE buys nothing measurable** — a fire pool's `dps` has never been read.
- **Crew strafing** — four clips wired up and unused.
- **Enemy bolts** — hard ink rim plus a hot leading spike. Yes?
- **COLD DECK deals a draft with no weapon in it in ~31% of runs.** Intended?
- **The Boilerwright still speaks in the Captain's voice.** Wrong voice, no
  voice, or leave it until there are takes?
- **A 4-damage Field tick and a 90-damage crit Mortar still draw the same two
  floater sizes.** The *bodies* now react proportionally; the numbers do not.

---

## Only you can unblock

- **The Aether Loom** — still not on this machine. Copy the server folder over,
  **or paste an image-API key** and `forge.py` gets rewritten to call the API
  directly. Recommend the key.
- **Steam** — the paperwork is the only critical path and it is entirely yours.
  The tax interview alone is 2–7 business days. **Send friends the itch link,
  not a Steam key** — keys need a three-week wait for a first-time dev.

---

## Things you should know, no action needed

**A truncated `workshop.json` used to wipe every unlock silently, and the next
run made it permanent.** The save opened the live file with a truncating write,
so everything you had earned was gone before the replacement existed. It is
written beside itself and renamed now.

**Sitting on the settings screen was sixty file writes a second**, on every
player's machine — the sliders are immediate mode and every frame called
`set_volume`, which saved. Fixed; it is also what made an old harness check
flaky enough to need a board row to explain.

**PAUSE could not be rebound at all.** Eleven rows numbered `(i+1) % 10`, so it
wore MOVE UP's "1", and the reader only ever mapped ten digits.

**The text audit was clean on the settings footer the whole time it was printing
through the BACK button.** Containment measures a string against its *frame*,
and a free label over a button share none. It took a rect intersection to see —
which then failed by 8 px at all four widths before the fix.
