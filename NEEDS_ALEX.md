# NEEDS ALEX — the morning edition

_Last updated: 2026-08-02, ~02:15, end of the overnight run._

## Good morning — the night in five lines

Builds **36 through 40** shipped to itch (40 is live). Harness **499 → 649**,
every build verified green on the committed tree before butler pushed. Two
guiding documents written by ultracode panels: `docs/POST-PARITY-PLAN.md` and
`docs/ENEMY-VARIETY-DESIGN.md`. Your four midnight answers were executed the
same hour. Everything below is either a decision or a play-verdict; the
details live on the board rows.

**Look first:** `.shots/clips/` (ten animated clips — the fight, the cloak
cracking on a dash, projectiles, every cutscene) and
`.shots/screens/morning/index.html` (the fresh 24-screen gallery).

**F4 resizes now (SG-80), and your Ctrl+S bug was real (SG-83): the harness had been deleting `user://hud_layout.json` six times a run, so the editor saved correctly and a tool run wiped it minutes later — fixed, and the bar now says SAVED with the real path, or shouts if a write fails.**

**Your three boarding-hulk models are in and all three states are wired (SG-76) — feel-check the sequence in a push wave (wave 4): it now hangs on SEALED and shrugs off everything for 2.5 s, opens and starts unloading, and wears the wreck when it breaks; and say whether the sealed 2.5 s is the right beat, because that number is the only thing in it I picked rather than measured.**

## Your 2026-08-02 screenshot — the three corrections, one line each

- **SG-78, the aim indicator:** the range ring and the cursor echo are gone;
  the small reticle clamped at the skill's reach is the whole in-game feature —
  look at `.shots/sg78-82/aim-in-range.png` and say whether it is now subtle
  enough, because the disc was the painted `rune_player.png` plate being a
  filled disc rather than a ring, and the other effect rings still draw through
  that same plate if you ever see one flood.
- **SG-82, the cape:** off, and `HERO_CLOAKS` is empty — nobody wears one until
  you say so; the SG-82 board row records exactly why it read as a plank
  (rigid ring binds, board proportions, one flat baked normal, and a texture
  that is the deck-planking painter in red), which is the brief SG-63 rebuilds
  against.
- **SG-79, the prop sizes:** all ten wired props now stand the screen height of
  the painting they replaced (audit table on the board row) — the deck cannon
  was the worst at 2.07x and comes down the most, so if the guns now read SMALL
  to you it is their 130-unit height constant to raise, not the ruler.

## Blockers

None hard. ~~**Soft:** adding NEW Mixamo clips (the Boilerwright's kneel, a
wrench swing) needs raw FBX from you.~~ **DELIVERED — your Great Sword Pack
landed and the whole thing is in** (board SG-74): he stands on HIS OWN Mixamo
rig now with all 51 of your clips aboard — the five heavy slashes are his
attack rotation, impact is his flinch, and **the kneel is wired to Tap Main**
(the "Two clips would make him HIM" ask, both halves). Feel-check when you
play him: (1) do the slash cuts read as WRENCH work now rather than sword
work, and (2) does the kneel's 0.7 s on a tap feel planted or sluggish —
`.shots/clips/boilerwright.gif` is the 6-second preview (march, two cuts,
the kneel inside his tap ring). One number for you: the OBJ you ran through
Mixamo carried the 12,476-tri REFINE mesh, not the 3,093 remesh — harmless
on screen and pinned by a check, but if you ever re-export the REMESHED OBJ
through the same Mixamo pack, one re-run of
`python tools/ingest_model.py boilerwright` puts him back under budget for
zero credits.

## Decisions

**1 · Scrapper regeneration, ~40 credits** (SG-55). Meshy's rigger refused
the current mesh five times — arms welded to torso, no neck; it predates your
T-pose rules. 0 credits were spent finding this out. Approve ~40 (regen to
the standing rules + remesh + rig) and the animation pilot resumes; or name a
different boarder to try first (refused submissions are free).
**Recommendation: approve.** Balance: 507 credits.
**DONE 2026-08-02 (SG-65): the scrapper is rigged and WALKING — the pilot verdict awaits your eyes at `.shots/clips/scrapper.gif` (statue-glide kept as `scrapper-before.gif`); Meshy refused even a textbook A-pose, so the rig is local and free — SG-65 on the board has the read and the rollout fork.**

**2 · Tempo's held-rate flag** (SG-57 / NEEDS #8). The spawn-rhythm system
shipped gated on hard queue statistics (SURGE is provably bimodal). But the
balance bot held the deck less often under SURGE (23/60 vs 34/60) — possibly
real difficulty, possibly the bot not using lulls to repair like a human
would. Play a SURGE wave and say; also set the noise-floor threshold the
ENEMY-VARIETY doc wants before the Muster gets built.

**3 · The six fittings as built** (SG-56) — confirm or amend: THE WRECK
(first Colossus kill), BOW BARRICADE (clear wave 8), SPARE GUN (win at
Heat 1+, ships broken, repair it), FOURTH VENT (win as Boilerwright), THE
WINCH (12 salvage in one run → tap-to-haul verb), SCUPPER GRATING (win
without healing). One earned per run, six berths, THE BERTHS screen off the
title.

**Done, no decision needed:** your "push crate mechanic is boring" tabling
LANDED (board SG-68) — shove + winch verbs dormant behind one flag, the crate
is an ordinary stowed prop, THE WINCH shows "TABLED — an interaction pass
will revisit" on THE BERTHS (earned ones stay earned), and the checks now pin
the tabled state, none silenced.

**4 · The Muster** (ENEMY-VARIETY §2.1, ~a week): seeded wave mutations
inside a conserved threat budget — the biggest remaining enemy-variety item.
Proceed after your noise-floor call in #2?

**5 · The belt pouches** (SG-12, still pending your eyes): Meshy refused a
beltless engineer three times; the kept pair is small at game camera.
Accept, or 20 credits a re-roll.

## Play-verdicts you owe the ledger (all in build 40)

The ledger keeps these OPEN until you say fun/not-fun — one word each is
enough: **the crate shove** (your "sucks" rework) · **the lab** (gimbal fix,
typed values) · **the F4 editor + P screen picker** (your two alignment
asks) · **projectiles** (your "cheap sprites" ask) · **cutscenes** (five
cues) · **Heat 3–5** (brutal-fair?) · **the cloak** · **the wrench** (2-min
grip polish in the lab: `--fit boilerwright`) · **the Boilerwright visible**
(he never rendered before last night) · **THE BERTHS + fittings** · **SURGE
tempo waves** · **the wreck** · **text size at 1920** · **telegraph
fairness**.

Your uncommitted cutlass fit still sits safely in the working tree — re-fit
with the fixed lab when ready and say the word to commit it.
