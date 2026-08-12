# UI/UX AUDIT — 2026-08-11 (menus, text, information density)

**What this is.** The owner's ask, verbatim: *"a proper UI/UX pass … Right now
there are a lot of issues with text, a TON of overwhelming information to a new
player that doesn't need to be in primary menus."* This document is the
evidence-backed, ranked slice plan for that ask, judged through one lens: **a
first-time Steam-demo player with thirty seconds of patience and no context.**

**How it was produced, and the one limit.** Static source audit only. Mid-audit
the owner parked all Godot work while his ComfyUI render holds the GPU, so:
`tools/text_audit.gd` was **NOT run** (its last recorded state is CLEAN at 25
screens × 4 widths, per STATUS.md, 2026-08-02 — but that is containment and
contrast, not writing quality), and **no screenshots were captured**. Every
claim below is a quoted string with a `file:line`, an arithmetic count off the
draw code, or is explicitly labelled **PENDING VISUAL CONFIRMATION** (§C lists
the exact narrow captures to run later in one batch). Nothing here asserts how
a screen *looks*.

**What this builds on, not against.** SG-91 established the menu vocabulary
(`docs/MENU-DESIGN.md`: board / plate / lamp / door / cold iron / hatch /
rungs) and built the title to it. SG-93 — spreading it to SETTINGS, HOW TO
PLAY, CONTROLS, PAUSE — is BLOCKED on the owner's verdict, and his message is
effectively that verdict being asked for. This plan reuses that vocabulary
everywhere; it invents no third one.

**Five demo-readiness findings verified ALREADY FIXED in source** — do not
re-file: DR-01b ("GODOT PORT" gone — `hud.gd:535` now `"STORM-DUSK"`,
`game.gd:2067` report opens `"SKYGEAR"`); DR-04 (dev keys gated — the pause
footer only appends `" · F4 layout · F3 stats"` behind `if game.dev_tools`,
`hud.gd:4049`); DR-08 (both destructive pause buttons are two-press —
`_pause_confirm` at `hud.gd:3985–4000`, board SG-218); DR-13 (the off-canvas
milestone footer is deleted — the comment block at `hud.gd:714–729` records
it). DR-12 remains live (see §A-3).

---

## A · Text audit — the writing itself

The tool has only ever proven text sits inside its frame. This section is the
half it has no opinion on. Findings first, then what is genuinely good.

### A-1 · THE WORST OFFENDER: internal development process printed to the player

`scripts/hud.gd`, the Berths screen (post-first-victory, but a primary
progression surface):

- `hud.gd:5209` — a tabled fitting's row blurb: `"TABLED — an interaction
  pass will revisit"`
- `hud.gd:5231` — the same string again as its hover status
- `hud.gd:5237` — its foot-strip lead: `"tabled with the crate-verb family —
  nothing is lost"`

*"An interaction pass"* is sprint vocabulary. *"The crate-verb family"* is
this repo's internal design taxonomy (board SG-68). A player who reads these
learns nothing except that they are looking at scaffolding — the exact thing a
Steam demo must not show. Same family, softer instance: `hud.gd:5038`, the
Workshop respec caption — `"free, and never mid-run — experimenting is all a
tree this small has to offer"` — a self-deprecating developer aside ("a tree
this small") on a shipping screen. And `hud.gd:5393`, the settings caption
opening with the word `"Playtest:"` — accurate for the owner's own bypass
(SG-160), developer-facing for everyone else; its fate is a demo-scope
question (DR-03), not a copyedit.

### A-2 · One outcome, two names — and the results screen says everything twice

- On screen the defeat verdict is `"DECK LOST"` (`hud.gd:175`); the copied
  report calls the same outcome `"BOARDED"` (`game.gd:2068`). Two nouns for
  the one moment a frustrated player is most likely to screenshot.
- `_draw_results` draws its own banner, a 52pt verdict and the reason
  (`hud.gd:5470–5472`) — then prints the **entire** `run_report()` verbatim
  under them (`hud.gd:5481–5489`), whose first two lines are `"SKYGEAR"` and
  `"DECK HELD — <reason>"` (`game.gd:2067–2068`). So the game's name appears
  twice and the verdict + reason appear twice, on the same screen, a few
  hundred pixels apart. Countable, not taste.

### A-3 · Standing text defects confirmed still live (owned by existing rows — referenced, not re-filed)

- **DR-12**: `_report_row` pads for monospace — `"  %-20s %7d  %d%%   %d casts
  %d kills"` (`game.gd:2140`) and the reactions twin at `game.gd:2121` — drawn
  proportional (`hud.gd:39` is `ThemeDB.fallback_font`; drawn line-by-line at
  `hud.gd:5486`). The columns cannot line up on screen.
- **DR-09(a)**: key labels are literals while rebinding exists —
  `hud.gd:540` `"WASD move · mouse aim · LMB/RMB/Q/E skills · %s"` on the
  title, `hud.gd:2522` `var labels := ["LMB", "RMB", "Q", "E", "AUTO"]` on the
  four skill wells. `SkyGearKeybinds.label()` already resolves live bindings.
- **DR-09(b)**: `REBINDABLE` has **11** rows (`keybinds.gd:20–33`, PAUSE is
  index 10); `_draw_keys` numbers rows `(i + 1) % 10` (`hud.gd:3916`) so PAUSE
  is labelled `"1"` — the same digit as MOVE UP — and `_digit_slot`
  (`game.gd:1641`) maps only `KEY_1..9 → 0..8`, `KEY_0 → 9`. Rows are not
  clickable (no widget per row), so **PAUSE cannot be rebound at all.**
- **DR-24**: HOW TO PLAY's captain branch never mentions that the dash grants
  i-frames (`hud.gd:4313–4317` is the whole captain section).
- **DR-17**: everything is the engine fallback font (`hud.gd:39`) — owner
  gate on a face and licence.

### A-4 · Dead code carrying wrong instructions

`_pause_text()` at `hud.gd:5424–5438` has **zero callers** (repo grep). Its
strings are stale twice over: `"Space dash"` unconditional (false for the
Boilerwright, which the live pause footer at `hud.gd:4045` already handles)
and `"1/2/3 pick a card"` (FOURTH CARD, SG-46, deals four). Harmless today;
a landmine for whoever next wires a pause string. Delete it.

### A-5 · Taste flags (labelled as taste, the owner's call)

- `"THE CORE"` (`hud.gd:623`) is the one first-screen label that names an
  internal concept rather than a player one; its saving grace is the caption
  under it ("Her basic attack, and the only weapon every run has").
- Draft subheads are writerly at a moment of time pressure: `"WHICH WEAPON,
  NOT WHETHER — PRESS 1 / 2 / 3"` (`hud.gd:3415–3416`), `"IT FIGHTS ON ITS
  OWN — IN PLACE OF THIS WAVE'S CARDS"` (`hud.gd:3418`). Confident house
  voice; a first-timer may need a beat to parse them.
- Berths idle foot strip: `"rest on a slate for what it does"` (`hud.gd:5303`)
  — "rest on" meaning "hover" is charming and slightly opaque.

### A-6 · What is genuinely good — protect it

- **Terminology discipline is real.** Scrip, sigils, Heat, STOKED, fittings,
  berths, Articles are used consistently across every screen read; headers are
  ALL-CAPS and captions lowercase everywhere; the coach fills `{key}` from
  live bindings (`coach.gd:100`) — the rule DR-09 asks for is already written
  down in-repo.
- **The class-compare copy is exemplary Ravenswatch-dimension work**: one
  question per row, both classes answering it (`game_data.gd:296–309` /
  `347–357` — "the question", "what it buys", "you lose by"), with the four
  numbers derived from the balance table (`class_stats()`,
  `game_data.gd:376`), not transcribed.
- **HOW TO PLAY teaches the one non-obvious loop, per class, with numbers
  read from the simulation's own tables** (`hud.gd:4298–4327`). The
  Boilerwright getting his own truthful page instead of hers is exactly right.
- The SteamWorld-Heist-II dimension — authored brass-and-ink personality — is
  carried by this voice. Slices below remove *development* language, never the
  nautical register.

---

## B · Information density — what each primary surface draws vs what a new player needs

Counts are off the draw code, deterministic per state.

### B-1 · Title, fresh save (the first 10 seconds)

Draws **14 elements**: 4 header text lines (SKYGEAR, STORM-DUSK, the boiler
sentence, the controls line) + 8 plates (WHO IS ABOARD, THE CORE, COMPARE THE
TWO, BEGIN RUN, HOW TO PLAY, SETTINGS, CONTROLS, QUIT) + 2 caption blurbs.
The heat ladder, Workshop and Berths are correctly hidden pre-victory
(`hud.gd:570–583` — the `workshop.gd` "NONE OF THIS EXISTS UNTIL YOU HAVE
WON" rule, which MENU-DESIGN §3.5 already defended; do not touch it).

**A new player needs 11 of the 14.** The 3 to defer: **THE CORE plate + its
blurb** (`hud.gd:622–631`) — an element-tuning knob offered before the player
has ever swung the weapon it tunes; they have no basis to choose and it makes
the pre-run screen pose *two* decisions where Ravenswatch's lesson is to pose
*one* (who are you?). And arguably the **controls line** (`hud.gd:540`),
which duplicates CONTROLS/HOW TO PLAY and is the screen's one rebind-stale
string. Where they go: THE CORE folds into the compare/class surface or
appears after the first run (it already cycles per-run thereafter); the
controls line dies with DR-09(a) or moves to HOW TO PLAY. **OWNER TASTE —
flagged, not decided** (slice S6).

Post-victory the title grows to ~24 elements (ladder header + 5 rungs +
sentence strip, plus WORKSHOP and BERTHS rows) — that is *earned* progressive
disclosure and is working as designed. No finding.

### B-2 · Results (end of every run — the single most overloaded screen)

For a representative 4-skill victory the screen draws **~19 report text
lines + 4 buttons + up to 4 conditional footer lines**: verdict, reason, then
the verbatim tester report — name line, verdict line *again* (§A-2), the
wave/time/seed header, refit line, build line, draft line, a 5–7 row damage
table with casts/kills columns, a reactions table, a range-distribution line
(`"range: %d%% close · %d%% mid…"`, `game.gd:2131`), and
`"vents %d · healed %d · salvage %d · rerolls %d"` (`game.gd:2134`).

**A first-time player needs ~6 of it**: verdict, reason, wave/time, what it
banked (`"+%d scrip"` line), THE SHIP KEEPS line when present, and PLAY
AGAIN / QUIT. The damage-share table, reactions, range mix and the
vents/salvage line are **balance telemetry** — invaluable on the clipboard
(COPY REPORT keeps it byte-identical), meaningless and intimidating as the
default face of "you died on wave 3". This is Hades-II's dimension: the
after-action screen leads with the run's story, and detail is one deliberate
step away. Slice S1.

### B-3 · Settings — 10 rows, a demo player needs 4

`hud.gd:5342` `var rows := 10`: five per-channel volume sliders + MUTE +
FULLSCREEN + OPEN ALL HEATS + its two-line "Playtest:" caption + REBIND
CONTROLS + BACK + a footer. A demo first-timer needs **4** (master volume,
fullscreen, rebind, back). The 6 to fold or gate: four sub-channel sliders
(fold behind an AUDIO expander or leave — cheap either way, taste), and OPEN
ALL HEATS + caption, which are the owner's own playtest bypass (SG-160) —
their visibility in a *demo build* is DR-03's scope decision, not this
audit's. **Known live bug on this sheet: SG-161** (footer printed through
BACK at every width — board row confirmed OPEN; geometry PENDING VISUAL
CONFIRMATION). Also the sheet is the old flat `_panel`+rows idiom — SG-93's
second-cheapest target (MENU-DESIGN §5: "a call swap per row").

### B-4 · Pause — good, with one column worth praising

Five buttons + volume + mute + the YOUR BUILD loadout column + one footer
line. Post SG-218 (two-press destruction) and SG-214 (dev keys gated) this
screen is **right-sized**: the loadout column is the only place a player can
read their build unshot-at, and it earns its space. No density finding. Its
remaining work is SG-93 vocabulary only.

### B-5 · Controls — 11 rows + 3 caption lines; density fine, truth broken

The density is correct for a rebind sheet. The defects are DR-09's (§A-3):
row "1" appearing twice, PAUSE unreachable, and no keyboard-and-mouse-only
notice anywhere.

### B-6 · Draft (second ~25 of a run)

Heading + subhead + reroll button + 3–4 cards, each carrying ~9 elements
(number/class band, element swatch+word, rarity word, emblem, role badge,
title, ≤3 lines of prose, before→after rows, affects/slot stamp). ~32
elements under time pressure — dense, but each element answers a distinct
question the browser playtests asked for (the file's own comments cite the
reports), and the opening draft omits before→after rows. **No cut
recommended without seeing it**; hierarchy judgment is PENDING VISUAL
CONFIRMATION. The first-run manifest line only appears behind a Workshop
talent — correct gating.

### B-7 · Workshop / Berths / Articles (post-victory)

23 nodes + 7 Articles + a 4-cell ledger + foot strip: heavy, but post-first-
victory by hard rule, restructured by the pipework pass so state reads by
shape, and the foot strip answers focus. Density is fine *for when a player
meets it*. Its findings are textual (§A-1) and visual-pending only.

---

## C · Visual evidence — NOT CAPTURED, and exactly what to capture

The owner froze Godot work mid-audit (GPU held by his render). No capture was
run; no visual claim is made above. **One narrow batch, later, when the
machine is free** (`python tools/screen_review.py --only <name>`, never
`--headless`, one Godot at a time):

1. `--only title` — fresh-save AND post-victory poses, 1280 + 1920: confirm
   the board hierarchy (does the eye land on BEGIN RUN?), and the fresh-save
   element count on screen.
2. `--only settings` — all 4 widths: SG-161's footer-through-BACK, current
   geometry after the SG-160 caption insert.
3. `--only results` (victory pose with a 4-skill build) — the duplication and
   table-drift of §A-2/§B-2 as pixels.
4. `--only draft` at 1280 — card hierarchy under the smallest window.
5. `godot --path . --script tools/text_audit.gd` (no `--headless`) — re-prove
   CLEAN before and after every slice below; treat the 2026-08-02 CLEAN as
   stale until re-run.

---

## D · The ranked slice plan

Ranked by (first-time-demo player impact) ÷ (risk × cost). **Every slice
below touches `scripts/hud.gd`, which serializes — these run strictly one at
a time, in this order.** Harness (`tests/parity_test.gd`) is also a lock.
Board rule 1: take IDs from the coordinator's block; `UX-n` are placeholders.

### S1 · The results screen tells the run's story; the telemetry is one step away
- **Outcome:** a player who just lost sees what happened and how to go again —
  not a damage-share spreadsheet.
- **The one visible improvement:** default results = verdict, reason,
  wave/time, what it banked, THE SHIP KEEPS, four buttons. The full report
  moves behind a `DETAILS` fold (or stays whole on COPY REPORT — clipboard
  stays byte-identical either way). Kills the §A-2 duplication (strip the
  report's first two lines from the *drawn* body only). Sidesteps DR-12 for
  the default view; if the table stays visible inside DETAILS, do DR-12's
  x-coordinate alignment there in the same slice.
- **Files:** `scripts/hud.gd` (`_draw_results`), `tests/parity_test.gd`.
  `game.gd` untouched — `run_report()` stays the clipboard truth.
- **Evidence:** named checks — `results · the drawn sheet does not say the
  verdict twice` (walk drawn strings, assert one occurrence), `results · the
  clipboard report is byte-identical before and after`; text audit CLEAN ×4
  widths; capture C-3 before/after.
- **Kill / rollback:** if the owner wants the full report as the default
  face, invert the fold's default state — one bool; full revert is one
  function.
- **Owner decision:** fold depth (hidden vs collapsed-but-visible). Ask,
  don't pick.

### S2 · SG-93 — the menu vocabulary reaches SETTINGS, HOW TO PLAY, CONTROLS, PAUSE *(existing row — owner-gated; his message is the verdict being requested)*
- **Outcome:** the four screens a new player opens in minute one come from
  the same game as the title.
- **The one visible improvement:** plates/board/lamp instead of hairline
  rectangles on four sheets — MENU-DESIGN §5 costs it as "a call swap per
  row" since the SG-91 primitives exist.
- **Files:** `scripts/hud.gd` only; harness. **Do the SG-161 arithmetic fix
  first, inside this slice's settings pass** (its footer/BACK collision is on
  the exact lines being rewritten; fixing it separately afterwards would
  churn the same function twice) — and extend the audit so a free `_label`
  over a `ui.button` is detectable (SG-161's "detector never pointed here"
  half).
- **Evidence:** text audit CLEAN ×4 on all four screens; a new named check
  `settings · the footer never prints through BACK` (rect-intersection,
  failing first); captures C-2 before/after.
- **Kill / rollback:** per-screen — each sheet converts independently; revert
  is per-function.
- **Owner decision:** confirm SG-93's gate is open before dispatch. Do not
  let this audit stand in for his verdict.

### S3 · No development vocabulary on a shipping surface
- **Outcome:** the player never reads sprint language.
- **The one visible improvement:** `hud.gd:5209/5231/5237` rewritten in the
  ship's own register (e.g. "STOWED — not rigged for this voyage"; final
  wording is the owner's, offer three options), `hud.gd:5038` loses "all a
  tree this small has to offer", `hud.gd:175`/`game.gd:2068` agree on one
  defeat noun, and dead `_pause_text()` (`hud.gd:5424–5438`) is deleted.
- **Files:** `scripts/hud.gd`, `scripts/game.gd` (one string literal),
  `tests/parity_test.gd`.
- **Evidence:** a named check `text · no development vocabulary on a shipping
  surface` — grep the drawn-string set of every posed screen for
  `interaction pass|crate-verb|playtest|milestone` — demonstrated failing on
  today's tree first. Note: changing `game.gd:2068` changes the copied
  report; any harness fixture matching `"BOARDED"` must move in the same
  commit.
- **Kill / rollback:** none / string reverts.
- **Owner decision:** the replacement wordings only (one-line sign-off).

### S4 · DR-09 — the controls the game shows are the controls you have *(existing DR row; partial SG-93 gate)*
- **Outcome:** a player who rebinds — or owns an AZERTY board — is never told
  to press a key they don't have; PAUSE becomes rebindable.
- **Minimum honest fix** (per the DR-09 gate, no widget-layer rework): number
  rows `i + 1` and extend `_digit_slot` past 10 (`hud.gd:3916`,
  `game.gd:1641`); route `hud.gd:540` and `hud.gd:2522` through
  `SkyGearKeybinds.label()` with a preferred-event rule (skill_1 is
  LMB *and* 1); add the one-line KBM-only notice on CONTROLS.
- **Files:** `scripts/hud.gd`, `scripts/game.gd`, `tests/parity_test.gd`.
- **Evidence:** DR-09's own named checks (`keys · every rebindable row is
  reachable…` failing today at index 10; drawn slot string equals live
  binding after a diverted rebind).
- **Kill / rollback:** none / localized.

### S5 · Title, pre-first-run: one decision, then the door *(OWNER TASTE — proposal only)*
- **Outcome:** the first screen poses one question (who is aboard?) and one
  action (BEGIN RUN).
- **The proposal:** defer THE CORE plate + blurb until after the first
  victory (or fold it into the compare screen); retire the title's hardcoded
  controls line in favour of HOW TO PLAY (S4 makes it truthful if it stays).
  Counts in §B-1. This is his call — the row was added deliberately (SG-99).
- **Files:** `scripts/hud.gd`; harness (board-height arithmetic at
  `hud.gd:573–586` changes with the row).
- **Evidence:** capture C-1 before/after; text audit CLEAN; the board-height
  check that already pins `MENU_LADDER_H` agreement.
- **Kill / rollback:** if he says the element choice belongs up front, drop
  the slice entirely — it is taste, and it is his.

### S6 · Settings demo hygiene *(blocked on DR-03's owner scope decision)*
- OPEN ALL HEATS + "Playtest:" caption hidden behind the demo/dev predicate
  once DR-03 decides a demo build exists; optionally fold the four
  sub-channel volume sliders. **Do not dispatch before the DR-03 answer** —
  today that switch is a tool the owner uses (SG-160, named in NEEDS_ALEX).

**Deliberately not sliced:** the draft screen (dense but each element is a
paid-for answer; re-judge after capture C-4), the Workshop/Berths structure
(post-victory, already restructured, only S3's strings), the fight HUD
(different rules — HUD-DESIGN §3; out of this brief), and anything the five
already-fixed DR items cover.

---

*Static audit by a read-only pass, 2026-08-11. No Godot was launched after
the owner's freeze; §C is the debt and it is narrow.*
