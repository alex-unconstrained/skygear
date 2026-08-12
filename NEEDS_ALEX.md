# NEEDS ALEX

**BUILD 71 IS STILL THE LIVE BUILD. THERE IS A PILE OF WORK SITTING ON TOP OF IT
THAT YOU HAVE NOT SEEN, AND NO BUILD 72 HAS BEEN CUT.**

That is the whole headline. The tree is at commit `79b8841`, **harness 1229/1229,
exit 0, 54 engine errors** — thirteen IDs of work since build 71 shipped, none of
it in front of you, none of it packed. **Nothing below is a report on something
you have played.**

What is live, unchanged since 2026-08-11:

- **`windows-demo`** build **#1876328** — the demo cut. First build on that
  channel. Launched and photographed before it went up: it says *"six boarding
  waves"* and has no class picker.
- **`windows`** build **#1876329** — the full game.

Detail lives in `skygear-godot/docs/BOARD.md`, which is **the open queue and
nothing else** — you asked for that. It is **35 open rows** now; every finished
row and its evidence is in `docs/BOARD-ARCHIVE.md` (216 of them).

*Last cleaned 2026-08-12, against `79b8841`. Everything you answered is off this
list.*

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

**1 · TWO THINGS ARE SHIPPED AND HAVE NOT BEEN LOOKED AT, AND THEY ARE BOTH
VISUAL.** The GPU was rendering your film for the whole session, and a Godot
capture pass and a ComfyUI render contend hard for the one card — the freeze on
2026-08-11 is why that rule exists. So: **the ink pass** (`deck_post.gdshader`,
your shader ask — a depth-and-normal edge plus a vignette over the deck) and
**the new fonts at four widths** are in the build unverified. Both are one line
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
- **SG-266: mipmapping the furnace knight (SG-265) genuinely dimmed his molten
  grille, and the test that checks it has no margin left at all.**
  **CORRECTED 2026-08-12, and the correction makes it worse rather than
  better — please read this paragraph before deciding, the earlier version of
  this ask is struck below it.** The first version of this finding compared
  five fresh readings (0.18 / 0.19 / 0.18 / 0.19 / 0.20%, against a floor of
  0.18%) to a 2026-08-03 baseline of 0.23–0.25%. That comparison spanned **two**
  changes, not one: the ink pass landed 2026-08-11, in between, and the probe
  runs in a window rather than headless, so it had been seeing the ink and the
  baseline never had. **So it was re-measured properly — three runs at HEAD with
  the ink pass switched off, one at a time on an idle machine: 0.14% / 0.15% /
  0.14%.** The 2026-08-03 baseline was taken before the ink pass existed, so
  that is the honest like-for-like comparison, and it reads **0.24% → 0.143%, a
  40% fall.** **Two things follow.** (a) **The mipmaps really are the cause** —
  the ink pass was not responsible, and taking it out of both sides makes the
  drop bigger, not smaller. (b) **The ink pass had been holding the number up**
  by about 0.045 points, which is the only reason the check was still scraping
  past its floor. **With the ink off it does not pass: it failed all three
  runs.** So this is now the same decision as the ink-pass guard bug (SG-267) —
  that guard is backwards, and fixing it in either of the two sensible ways
  turns this check permanently red on the same day. **Nothing was tuned to
  produce any of this; `MOLTEN_FLOOR` is untouched.** This is still a published
  tuning constant and still your call, same shape as SG-136. **My read has
  shifted with the numbers: option (1) "just accept it" is harder to justify at
  0.143% than it was at 0.188%** — the grille is still an order of magnitude
  under its own ceiling and still reads as an emitter, but a check that only
  passes because of an unrelated bug is not passing. I'd now lean toward **(3),
  raise the knight's authored emissive a little** so the true measurement comes
  back up, rather than lowering the bar — but it's your constant either way.
  ~~*Was, before the isolating run: five readings of 0.18–0.20%, two of them
  exactly on the floor; "the check can start intermittently failing on ordinary
  GPU noise with nothing actually wrong"; recommendation (1), accept it.*~~

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
