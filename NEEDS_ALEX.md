# NEEDS ALEX

**BUILD 73 IS LIVE ON ITCH. BOTH CHANNELS. GO AND BREAK IT.**

- **`windows`** build **#1880125** (from #1878613) — the full game.
- **`windows-demo`** build **#1880126** (from #1878614) — the demo cut.
- Version string on both: **`73-quality-pass`**, off commit `640942b`.
- **Rollback is build 72: #1878613 and #1878614.**

Harness **1286/1286**, exit 0, 0 script errors, 54 engine errors against a pinned 54.

**WHAT TO GO AND LOOK AT, in the order it will hit you:**

1. **Die.** You never could, on screen. The captain stood in a breathing idle
   through her own defeat cutscene for the entire life of this port, drifting up
   to nineteen units from where the game thought she was. She falls now, and so
   does the Boilerwright — whose death animation has been sitting in his pack
   since the day he was ingested with nothing ever asking for it. **Then read the
   card over the body**: it used to say THE BOILER IS LOST even when the Boiler
   was at full health and a furnace knight had killed you.
2. **Kill something and feel the pause.** Hit-stop has never once stopped the
   captain or a boarder — it froze the wave logic and the projectiles, and the
   swordsman kept moving at full speed through all 0.070 s of it. **I changed no
   tuning number.** It may now be too strong. That is a playtest call and it is
   yours — tell me and I will move it with evidence.
3. **Set something on fire.** Burn, frost and stun had no mark on a boarder at
   all. A three-stack target and a fresh one were the same picture. Watch a
   stunned gremlin especially — it also used to breathe at four times speed.
4. **The metal is exactly as you left it.** "B across the board" is in; all
   thirteen models are back to fully metallic and the decision is written into
   `lamplit.py` so no future pass quietly re-clamps them.

**Caught on the way out the door** — the demo's README told players to run
`SkyGear-Godot.exe`, and the demo zip contains `SkyGear-Demo.exe`. Wrong for
every demo download ever made. Found by reading the file out of the archive
instead of trusting the template, fixed before the push, and gated now.


---

**EVERYTHING THAT WAS "IN THE TREE AND NOT IN A BUILD" IS NOW IN A BUILD.** The
eight fixes off your Heat 3 playtest, the finished opening film, the poster title
screen, the menu pass, the real typefaces, the demo cut and the three shipping
bugs that would have cost a build — all of it went out in 72 and 73. That
inventory used to live here at seventy lines; it is history now, so it lives in
`skygear-godot/docs/BOARD-ARCHIVE.md` and the night logs, and this page is back to
being a page. **Nothing below is a status report. Everything below needs you.**

---

## Waiting on you

**1 · THREE THINGS ARE SHIPPED AND HAVE NOT BEEN LOOKED AT, AND ALL THREE ARE
VISUAL.** The GPU was rendering your film for the whole session, and a Godot
capture pass and a ComfyUI render contend hard for the one card — the freeze on
2026-08-11 is why that rule exists. So: **the opening film itself** (53.54 s,
the finished cut with the mix fixed and the two new spoken lines), **the ink
pass** (`deck_post.gdshader`, your shader ask — a depth-and-normal edge plus a
vignette over the deck) and **the new fonts at four widths** are all in the
build unverified. The two renderer items are each one line
to switch off: `view3d.set_deck_post(false)`, and `hud.gd`'s two face constants.
If the edge is wrong, say so and it goes — it is not load-bearing. **(Correction,
2026-08-12: `set_deck_post(false)` currently has no caller anywhere in the tree,
so as written that switch cannot be reached — SG-267, one line to wire up. The
same row has the guard that decides which runs get the ink backwards, and per the
SG-266 item below the two are one decision.)**

**2 · THE CAPTAIN'S PORTRAIT IS REDRAWN AND IN THE BUILD — CHANGE THE FRAME IF
YOU WANT A DIFFERENT ONE.** SG-228 is closed: he is male, chibi, spiked brown
hair, goggles, gold-starred red coat, and he matches the sprite and the film
because he came from the same two references. It is frame 91 of a 124-frame
push onto his face, and picking another is two commands:
`python tools/portrait_from_clip.py --sheet`, look, then `--frame N`. The file
it replaced is kept beside it as `.pre-SG-228`.

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

**6 · WHAT DOES A TESTER SEE IF THEY DIE BEFORE THEIR FIRST TWELVE-WAVE WIN?**
Named but not built — a results sheet with every progression line skipped
(no scrip, no sigil, no fitting, no `best_heat` moved) is strictly less closure
than the demo cut gives a player who was never promised a win at all. Nobody
has decided what that sheet should say instead. Deferred out of build-72's
scope on purpose (task-18 brief §"deferred"); it needs your call before anyone
writes it.

---

**7 · THE DEFEAT CAMERA POINTS AT THE BOILER, SO YOUR NEW DEATH PLAYS BEHIND IT.**
I filmed the fix before believing it, and the frames say the shot is aimed at the
wrong thing. `assets/cutscenes/defeat.json` is a four-key push whose every look
target is the Boiler — exactly right for the defeat it was authored for, and
wrong for the other defeat that fires the same cue. In
`.shots/clips/sg282-captain-death/`, frame 6 shows her red coat at the foot of
the Boiler and **frame 30 shows no captain at all.** So she dies properly, for
about a second, and then the camera swallows her.

**I did not fix it, on purpose.** A new authored camera move is a taste call, and
you already have unapproved visual work queued (the ink pass). **My
recommendation: a second scene, `defeat_hero.json`, framing the body, cued off
the same `player.hp <= 0` test the card already reads — and `defeat.json` left
exactly as it is for the Boiler.** Say the word and it is one lab session. Board
SG-289.

**8 · ONE FRAME IN EVERY FOUR SECONDS COSTS ~50 MS, AND IT IS NOT NEW.** Measured
on an idle machine at sixty boarders: p99 is **14.27 ms against the 16.67 budget**,
so the budget holds — but the worst frame is 56 ms, it is entirely in the script
bucket (the GPU never passes 3.6 ms), and **it is there on a clean control of the
tree without any of my changes.** The only baseline this project ever recorded had
*no frame over 8.71 ms at all*. I have not attributed it to anything, because the
comparison spans a hundred-plus commits and two resolutions. Board SG-290 says
what would settle it. **Nothing for you to decide** — flagged because you will
feel it as an occasional hitch and should know it is known and measured.

## Smaller calls, whenever

- **The demo's end card** names five things the full game has. Read it once —
  it is the last thing a demo player sees and it is the whole pitch.
- **The menus have a bed under them now** (storm, then the ship) because there
  is no menu track and three fight tracks. If you want music on the title
  instead, that is a composition, not a setting.
- **The crew look stacked** — buyable renderer-side without moving the
  simulation. Want it?
- ~~**RESIDUE buys nothing measurable** — a fire pool's `dps` has never been read.~~
  **FIXED 2026-08-12 (SG-164)**: every fire pool now burns at a rate its own
  source authors (`SkyGearData.FIRE_SOURCES`), read by the tick instead of a
  flat hardcoded 7.5/tick. Plumbed at today's numbers only — lantern, the
  scald trail and RESIDUE all still deal the same 30.0/s, so nothing a player
  feels moved yet. The open question this row raised — "should pools differ
  at all" — is still Alex's to answer whenever a balance pass wants to touch
  `game_data.gd`'s `FIRE_SOURCES` table; it is now a one-file, one-line change
  with its own revert instead of a data-cleanup-plus-balance-change bundle.
- **Crew strafing** — four clips wired up and unused.
- **Enemy bolts** — hard ink rim plus a hot leading spike. Yes?
- **COLD DECK deals a draft with no weapon in it in ~31% of runs.** Intended?
- **The Boilerwright still speaks in the Captain's voice.** Wrong voice, no
  voice, or leave it until there are takes?
- **A 4-damage Field tick and a 90-damage crit Mortar still draw the same two
  floater sizes.** The *bodies* now react proportionally; the numbers do not.

---

## Only you can unblock

- **The Aether Loom** — still not on this machine, **but it is no longer the
  blocker it was.** `tools/imageforge.py` is a second, independent door: it calls
  an image API directly, needs nothing local, and it has already drawn the logo
  and the Boilerwright's first 2D art. What is left behind it is a **taste and a
  money call, not a technical one**: the Boilerwright is still drawn wearing the
  Captain's portrait in the HUD (one hardcoded path, no class branch), and since
  that portrait was redrawn as one specific young man the mismatch is worse than
  it was. **Say go and it gets drawn; it costs money to generate.**
- **Steam** — the paperwork is the only critical path and it is entirely yours.
  The tax interview alone is 2–7 business days. **Send friends the itch link,
  not a Steam key** — keys need a three-week wait for a first-time dev.
- **SG-266: the furnace knight's molten grille really has dimmed, the ink pass
  is NOT the reason, and I no longer claim to know for certain what IS.**
  **CORRECTED TWICE, 2026-08-12. Please read the whole of this before deciding.
  The second correction WITHDRAWS a cause I stated to you as confirmed, so the
  bit that changed is flagged in bold rather than buried.**

  **THE MEASUREMENTS, and these are not in dispute.** The first version of this
  finding compared five fresh readings (0.18 / 0.19 / 0.18 / 0.19 / 0.20%,
  against a floor of 0.18%) to a 2026-08-03 baseline of 0.23–0.25%. That
  comparison spanned two changes, not one: the ink pass landed 2026-08-11, in
  between, and the probe runs in a window rather than headless, so it had been
  seeing the ink and the baseline never had. **So it was re-measured — three
  runs at HEAD with the ink pass switched off, one at a time on an idle machine:
  0.14% / 0.15% / 0.14%, mean 0.143%.** The 2026-08-03 baseline predates the ink
  pass, so ink-off against ink-off is the honest like-for-like, and it reads
  **0.24% → 0.143%, a 40% fall.**

  **(a) THE INK PASS IS CLEARED, and it was hiding part of the problem.** It was
  holding the number UP by about 0.045 points, which is the only reason the check
  was still scraping past its floor. **With the ink off it does not pass: it
  failed all three runs.** So this remains the same decision as the ink-pass
  guard bug (SG-267) — that guard is backwards, and fixing it either sensible
  way turns this check permanently red on the same day.

  **(b) WHAT I AM WITHDRAWING: I told you "the mipmaps really are the cause."
  That was overstated and I should not have said it.** It rested on a
  before/after mipmap pair that does not exist — the task-15 report says in so
  many words that a true "before" run was never captured, because it would have
  cost a second exclusive re-import. **So the only comparison this number has
  ever had is a CROSS-DATE one, 2026-08-03 to 2026-08-12**, and that span carries
  well over a hundred commits: the gameplay work, the audio and hit-feedback
  pass, the font swap, sixteen build-72 tasks. Taking the ink pass out of both
  ends removed ONE variable out of that, not all of them. **And the probe's own
  scene is documented as unpinned** — a different roster of boarders in
  different facings has moved this same number from 0.24% to 0.81% before, and
  the painting's own front-versus-back spread is 1.25% against 0.48%, which is a
  bigger swing than the 1.68x I was attributing to mipmaps. The boarder-pixel
  counts being close is a headcount, not a proof of composition. **The mipmaps
  are still the LEADING theory** — the probe spawns the ARMORED knight, one of
  the 59 files that got mipmapped, so the mechanism is available — but it is a
  theory. **Settling it costs a specific, expensive thing:** revert the 59 import
  flags, reimport, run the probe, reimport forward again. Two exclusive
  re-imports, which is exactly the cost that got declined the first time.

  **(c) THE THING THAT MAKES ME TAKE THE DROP SERIOUSLY ANYWAY.** The probe's own
  comment (`tests/lit_probe.gd:124-130`) records that with Meshy's **empty**
  emission map the deck scores **0.15 / 0.15 / 0.13** — "paint catching a warm
  omni, and no emitter at all" — and with the **authored** map it scores
  **0.22 / 0.24 / 0.24**. The floor was deliberately set between those two bands
  "so it fails if the emission map is ever reverted, re-ingested from the Meshy
  source, or overwritten by a remesh." **Our three ink-off readings — 0.14 /
  0.15 / 0.14 — land inside the NO-EMITTER band.** Whatever the cause turns out
  to be, the shipped grille is now measuring where a blank map measured. That is
  the strongest corroboration in the file that something real degraded.

  **(d) OPTION (2), lowering `MOLTEN_FLOOR` to accept the new number, is off the
  table, and (c) is why.** Any floor low enough to pass 0.143% can no longer tell
  an authored emission map from an empty one — and that is the only failure this
  check exists to catch. Dropping the floor would not weaken the check; it would
  delete it.

  **(e) OPTION (3), raising the emissive energy, I recommended to you last time
  and I was wrong about it.** There is a measured counter-example already in the
  harness (`tests/parity_test.gd:2637-2644`): "if someone later turns the energy
  up as well, the grille goes white and stops reading as molten at all —
  measured, at gain 1.00 the molten count FALLS from 1229 to 700." The molten
  test is a COLOUR window, not a brightness one, so brighter means whiter means
  the pixels fall out of the window. **Raising the energy moves this number the
  wrong way.** The energy is also already pinned by a live harness check at the
  6.0 it was tuned at, and any map-side fix has to stay inside the
  `GRILLE_LIT_MIN`/`GRILLE_LIT_MAX` window it was authored against.

  **SO I HAVE NO CLEAN RECOMMENDATION, and I would rather say that than invent
  one.** Nothing was tuned to produce any of this; `MOLTEN_FLOOR`,
  `PAINTING_MOLTEN_FRONT/BACK` and the emissive energy are all untouched. It is
  still a published tuning constant and still your call, same shape as SG-136.
  The honest menu: **(1) accept the fragile margin** — harder to justify now
  that the reading sits in the no-emitter band, though the grille is still an
  order of magnitude under the painting's own ceiling; **(4) pay for the
  isolating measurement** — the two re-imports in (b), the only thing that turns
  the cause from theory into answer; **(5) re-author the emission MAP itself** —
  more lit texels at the same 6.0 energy, staying inside the authored window,
  which raises the true measurement without touching the bar or the pinned
  energy. **Given the ambiguity I think this is a choose-and-tell-me, not a
  recommend-and-confirm.**
  ~~*Was, before the isolating run: five readings of 0.18–0.20%, two of them
  exactly on the floor; "the check can start intermittently failing on ordinary
  GPU noise with nothing actually wrong"; recommendation (1), accept it.*~~
  ~~*And after it, but before this correction: "the mipmaps really are the
  cause", recommendation (3), raise the authored emissive. Both halves of that
  are withdrawn above.*~~

---

## Things you should know, no action needed

**THE METAL QUESTION IS CLOSED — you answered it.** You were shown five labelled
side-by-sides and said *"B across the board."* All thirteen models are back to
fully metallic, and the decision is written into `tools/lamplit.py` as an
`OWNER_KEPT` list with the date and your words, so the audit reports them as KEPT
rather than as a defect and no future pass quietly re-clamps them. The nine
FLAT-albedo materials the renderer builds in code are still clamped and were not
part of what you judged — different surface class, the one SG-179 was actually
about. Say the word in either direction.

**AND TWO THINGS I GOT WRONG GETTING THERE.** I published a before/after
measurement taken through a capture tool without first asking that tool what its
own noise floor was; it turned out to be 13.2%, larger than two of my three
numbers, and they are struck on the board and in the night log. The project
already owned the right tool — `tools/shiny_ab.gd`, both plates in one frozen
scene, 0.00% floor — and its header says so in as many words. Separately, I wrote
"machine confirmed idle" over every performance figure without checking: two
Godot instances from your Card-Game-Prototype were holding 6,389 CPU-seconds
throughout. Nothing was at risk (they cannot touch this project's import cache),
but only the differential numbers survive. Board SG-295.

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
