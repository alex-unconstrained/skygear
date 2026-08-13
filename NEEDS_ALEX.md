# NEEDS ALEX

**THE HERO NEVER DIED ON SCREEN. SHE DOES NOW.** Five more fixes are on `main`
on top of your eight playtest ones, none of it in any build. Harness
**1278/1278, exit 0, 0 script errors, 54 engine errors against a pinned 54.**
Still nothing blocked on you — the decision is whether to pack and push build 73.

**The five, in the order they will hit you:**

- **You die on screen now.** For the whole life of the port, being killed put the
  captain in a *breathing idle* — and then held her there, framed and
  letterboxed, for the length of the defeat cutscene. Her body also stopped being
  drawn where the game thought she was, by up to nineteen units. **The
  Boilerwright has had a death animation since the day he was ingested and
  nothing had ever asked for it.** The captain had none at all, and her animation
  archive is long gone off this machine, so hers was retargeted in-project off
  the crew's — Mixamo's unarmed backwards fall, which suits a one-handed axe
  better than the two-handed deaths in the sword pack. No spend.
- **Dying as the Captain no longer tells you the Boiler was lost.** One cue
  covers both defeats and there is one defeat scene, so the card read THE BOILER
  IS LOST over a Boiler at full health — and then the results sheet behind it
  said the opposite. It says what actually happened now.
- **HIT-STOP HAS NEVER ACTUALLY STOPPED ANYTHING, AND NOW IT DOES.** This is the
  one to feel. The freeze on a kill gated the wave logic and the projectiles; the
  captain and every boarder live on the *physics* tick and nothing there had ever
  read the freeze. So they kept moving at full speed through all 0.070 s of it —
  measured, a captain slides 11.4 units and a boarder 5.6 inside a window you
  were being told was frozen. **I changed no tuning number.** 0.070 and 0.040
  were tuned against a stop that reached half the game; they now reach all of it,
  so they may be too strong. **That is a playtest question and it is yours** —
  tell me if kills feel sticky and I will move them with evidence.
- **You flash white when you are hit.** Every gremlin and knight already did; the
  hero's material had never been armed for it. Half her hit reaction was missing.
- **A stunned gremlin no longer breathes at four times speed.** It has no flinch
  clip, so it borrowed its idle — and the idle got stretched to fit the stun,
  which pinned it at the 4x clamp. Every ARC proc in the game did this.

**AND THE DECK'S METAL WAS NEVER ACTUALLY HELD TO YOUR OWN STANDARD.** You looked
at flat brass at metallic 0.4 once and said *"very placeholder"*, and the 0.34
ceiling came out of that. Two things were supposed to enforce it and neither did:
the clamp tool guarantees the brightest texel is under the ceiling and its AUDIT
was checking the average one, so **thirteen of forty models were over — up to a
flat 1.0 — and every one printed `ok`**. The railing you run along peaks at 1.0.
So do the deck cannon, the powder keg and the boarding hulk; the crate stacks,
the brazier and the mast are all over. On the deck's own side, the brass capping
on all eight cargo runs — fifty-six pieces of it, at waist height in the middle
of the fight — sat at 0.45. All of it is under the ceiling now. **See item 9: it
is the one change in this pass you should look at before it ships.**

**One thing I found by filming the death fix and did NOT change — see item 7.**

---

**Your eight playtest fixes, still unbuilt.** What you get when you push:

- **The title screen** loses the WHAT YOU DRAFT grid (it stays on HOW TO PLAY)
  and loses THE CORE entirely. The airship flies forwards now.
- **THE CORE is a wave-4 choice.** All four elements, once per run, and it does
  **not** cost you the draft — the ordinary draft opens behind it.
- **The wave/boarders readout and the lane tracker are off the rivets.** One
  cause, not two: the code that decides where a plate's brass ends was capping
  both axes off the SHORT side, so wide HUD strips laid their text 22 px inside
  the painted frame.
- **The Furnace Knight can reach you.** His swing now connects at 222 — exactly
  where your Cleave connects with him — against 135 before. Same health, same
  damage, same 0.90 s tell. There is a wedge to step out of now.
- **One repair bar**, on the gun.
- The keyless fifth slot's rule now lives with both dealers. **See the note
  below: this one was not the bug you hit.**

**BUILD 72 IS STILL WHAT IS LIVE ON ITCH**, both channels, off commit `84dadd7`.

- **`windows`** build **#1878613** (from #1876329) — the full game.
- **`windows-demo`** build **#1878614** (from #1876328) — the demo cut.
- Version string on both: `72-polish-pass`. **Rollback is build 71: #1876329 and #1876328.**

## One thing you asked for that was already true

You said: *"In the workshop, you can get a talent that unlocks an additional
slot. Let's make sure that that slot is always filled with an auto."* It already
was. The fifth well has only ever been dealt Field or Pulse, both of which fire
themselves, and its tab says AUTO for that reason. There was a hole in the OTHER
dealer — The Opening Bid's open matrix had no such filter — but the Workshop
makes the Bid and the Second Hand mutually exclusive, so no save can hold both
and no run could ever reach it. I closed it anyway and wrote down why: the rule
was being guaranteed by a purchase constraint in a different file, so lifting
that exclusion for any reason would have brought the dead button back silently.
**If you were hitting a slot you could not press, it was something else — tell me
which key and which weapon and I will find it.**

Detail lives in `skygear-godot/docs/BOARD.md`. **43 open rows; next free ID is
SG-293.** The eight playtest rows and the quality pass's seven are closed in
`skygear-godot/docs/BOARD-ARCHIVE.md`; the pass's own write-up is
`skygear-godot/docs/NIGHT-LOG-2026-08-12-QUALITY-PASS.md`.

*Last cleaned 2026-08-12, after the quality-directive pass.*

---

## What changed since build 71 — all of it pending a fresh build and your eyes

**None of this is in the build you have.** It is in the tree, it is green, and it
needs a pack and a look.

**THE FILM IS FINISHED, AND THE VERSION YOU HEARD WAS BROKEN.** You caught the
sound: three fight tracks were playing at once. The cause was not a mix balance —
the code unpacked a fade-out from every cue row and then never used it, so
nothing ever stopped; `combat_low` and `combat_high` alone overlapped for 31.25
seconds. Cues own a window now and hand over on named 0.8 s crossfades. There is
a guard so you are not the detector next time: `assert_mix_sane` refuses a mix
with an undeclared overlap **before** the four-minute encode, and it was
demonstrated against the shipped mix first — it names the 31.25 s pile-up. You
also found water in a shot; my audit had cropped one third of one frame per shot
and could not have seen it. Re-audited on three full frames from all nine — shot
6 was the only other offender, both are re-rolled, and the world rule is in every
prompt. **Two new spoken lines**, at your invitation: *"She's the only thing
holding us up."* at 18.2 s, because the film's WHY was previously stated only by
the enemy at 41.7 s of a 53 s film; and *"Then come and take her."* at 44.9 s, so
the ending is demand / refusal / order instead of demand / order. Final:
**53.54 s, -19.9 LUFS, peak -1.8 dBFS, 39 cues, seven voice moments.**

**THE TITLE SCREEN IS A POSTER NOW, AND THE LOGO IS A DRAWN EMBLEM.** You were
right about the type — *"I dont need the title written in the same lame font as
everything else"* — and my first two attempts were bigger versions of the wrong
thing. `logo_skygear.png` is carved brass with rivets, filigree, airship wings, a
gear stack, a gauge and ember light behind the metal; the plate that used to box
the typeset name is gone. The screen behind it is built from three paintings this
project already owned and had never shown you, including the prow that was
retired from the 3D world for being *"a wall across the top of the frame"* —
which on a head-on poster is exactly what a foreground is. **STORM-DUSK is off
every surface**, on your word. And the title now says what the game *is*: THE
HAND, thirty-six icons, nine shapes crossed with four elements.

**THE MENU PASS YOU MARKED IN BLUE IS DONE, AND YOUR DIAGNOSIS WAS THE FIX.**
*"This is a consistent issue across all menus. So fixing it here will help us
everywhere."* It was one constant. Sheets laid content out in the least inset
that keeps a string off the painted edge — a floor, not a margin — so every row
ran rail to rail. Every sheet in the game takes its margin from one place now,
and each grew by twice the breath so content keeps its width and only the gap is
new. Your *"thin and poorly aligned"* was also one cause and it was a colour: the
engraved channel was a cold near-black, which reads as a hole punched through the
plate rather than metal cut into metal. It is the same hue in shadow now, so a
label reads as stamped.

**AND I HAVE TO RETRACT SOMETHING I TOLD YOU.** The last page said the four
screens a new player opens were *"drawn in the title's own hardware"*. That was
based on a chrome swap — I changed how buttons are **painted** and touched no
layout, no density and no hierarchy on any sheet. **Calling that done was wrong.**
What has actually been done since: **HOW TO PLAY is rebuilt** — it was eleven
prose sections in one column at 15pt on the screen whose only job is to teach, and
it is a two-column spread ending on THE HAND now; and **the objective plate — the
Boiler gauge, the thing you lose by — was printing four strings on top of each
other for the whole life of the build**, because the plate was 76 px holding 66 px
of content in a 44 px budget. It is 118 px. Nobody had ever opened a screenshot of
the actual playing screen. **Still not done, still named rather than claimed:**
the Workshop is four columns of ~35 rows at 11pt, the Berths two of the same
(both hidden in the demo), and SETTINGS is ten rows where the audit says four.

**Every string in the game is a real typeface** — Oswald over Lato, both OFL,
licences in `assets/fonts/`. Shipped in 71; still unverified by you (item 1).

**THREE SHIPPING BUGS THAT WOULD HAVE COST A BUILD.** The README inside both itch
zips taught the *losing* play — it said the CAPTAIN "fights at range" when range
is the line she dies on, called both male classes "she", and told demo players to
survive twelve waves of their six. `SkyGear Tools.bat pack --demo` silently threw
away the `--demo` flag and built and zipped the **full game under the full game's
filename** — a wrong-file push waiting for ship day. And the exe had stamped
`0.70.0.0` into its Windows version info for two builds, including 71. All three
now have checks; none of them had ever had one.

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

**9 · THE METAL CHANGE IS THE ONE TO LOOK AT, AND I HAVE SHOT IT BOTH WAYS.**
`.shots/sg291/before/` and `.shots/sg291/after/` — three poses, same seed, same
camera, 1600x900. This is conformance to YOUR standard rather than a taste of
mine, and twenty-seven of the forty models were already sitting exactly where I
have now put the other thirteen — the inconsistency was the defect. But it is
player-visible on the prop kit you see every second of every run, so you get the
pair rather than an announcement.

**What it does, measured:** the frame overall does not change — exposure and hue
balance move by a fraction of a percent, which is correct, since only metal
should move. Between 9% and 26% of the pixels change, by up to 218 of 255, and on
exactly those the surfaces get **brighter and slightly warmer**. That is the
whole mechanism: metal has no diffuse response, so a near-metallic railing under
a lamp can only give you a cold highlight; under the ceiling the same railing
takes the lantern as painted colour. Crates read as timber with brass hardware
instead of grey.

**If you hate it, it is one commit to revert** and the board row names every file.
Board SG-291 and SG-292.

**6 · WHAT DOES A TESTER SEE IF THEY DIE BEFORE THEIR FIRST TWELVE-WAVE WIN?**
Named but not built — a results sheet with every progression line skipped
(no scrip, no sigil, no fitting, no `best_heat` moved) is strictly less closure
than the demo cut gives a player who was never promised a win at all. Nobody
has decided what that sheet should say instead. Deferred out of build-72's
scope on purpose (task-18 brief §"deferred"); it needs your call before anyone
writes it.

---

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
