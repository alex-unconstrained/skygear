# BUILD 72 — the player-test polish pass

**Date:** 2026-08-12 · **Base:** `a1d7e3a` · **Target:** itch build 72, both channels, one commit
**Status:** design, approved in conversation 2026-08-12; implementation plan to follow

---

## 1 · What this is for

Build 71 (`eb63995`, itch `#1876328` / `#1876329`) is the build the owner and every tester
can currently reach. **Thirteen commits have landed since and none of them is an export**, so
the live build predates the whole SG-248…SG-255 menu overhaul — the title poster, the logo,
the sky under every menu, the metal plates, the shared sheet margin, the HOW TO PLAY spread
and four collision fixes.

That single fact reorders everything. **Shipping build 72 is not a task that runs beside the
verification rows — it is their prerequisite.** SG-242 (the film), SG-243 (the fonts), SG-244
(the ink pass), SG-226 (the cleave mark) and SG-208's G5 all end in "the owner looks at it",
and he cannot look at any of them until a build carrying them exists.

**Goal:** one build, both channels, off one commit and one harness run, that a stranger can be
handed without an apology.

---

## 2 · Decisions taken (owner, 2026-08-12)

| # | Decision | Consequence |
|---|----------|-------------|
| D1 | **Player-facing polish pass** — verify what shipped unverified, then fix what a tester collides with | Internal hygiene rows stay out; see §7 |
| D2 | **Testers get the FULL build only** | Class picker, COMPARE THE TWO and the SETTINGS ladder are all in the polish surface |
| D3 | **Fire: wire `dps` only, re-authored per-second.** Radii do not move | The three SG-163 checks stay green and unmodified; RESIDUE finally scales |
| D4 | **The playtest row hides in exported builds, stays in the editor** | Owner keeps OPEN ALL HEATS when running from the editor, not in the exe he plays |
| D5 | **Declare 1600×900 the minimum supported display** | `MIN_PT` stays 12; a boot guard names the unsupported case |
| D6 | **One build, everything** | Nothing reaches itch until §6's gate is met |

### 2a · The correction D3 rests on

The dispatch that opened this pass described fire as *"the fire you see is not the fire that
burns you"*, citing SG-121 and SG-164. **That bug was fixed on 2026-08-03.** Merge `0c690d8`
made `_field()` stamp `d["radius"] = FIRE_RADIUS` (`game.gd:5567`), deleted the renderer's
independent `f.get("radius", 62.0) * 2.2` (epitaph at `view3d.gd:5406`), and pinned the result
with three checks — including `hazard · the burn radius did not move — the picture moved, not
the damage` (`parity_test.gd:7489`), whose comment quotes the owner: *"Fix the picture to match
the damage."*

Every pool today draws and burns at 78. **Moving hitboxes to the art would have reversed a
shipped, harness-pinned owner verdict** on the strength of a stale board row. It is not being
done.

### 2b · The unit trap inside D3

`dps` means damage-per-**second** in this codebase. The only existing reader is the steam main:
`game.gd:4198` computes `float(SkyGearData.TAP.dps) * TAP_TICK`, and `game.gd:4178` states the
convention outright. Fire's shipped `7.5` is per-**tick** at `FIRE_TICK := 0.25` (`game.gd:4615`)
— **30 per second**.

So the authored `trail_dps 9.0` and `13.0 * residue`, read in the house unit, are a **57–70%
nerf**, and would make an epic card measurably worse than not taking it. The rates are therefore
**re-authored in the per-second unit**, not wired as written:

| source | authored dps | vs today | why |
|--------|--------------|----------|-----|
| `lantern` | **30.0** | unchanged | today's shipped rate, exactly. Ambient hazards must not move in the same commit that gives them a table |
| `scald_trail` | **18.0** | −40% | a retreat trail should be worth less than a committed skill |
| `residue` | **30.0 × stacks** | stack 1 neutral, stack 2 doubles | an epic's second copy should be felt |

---

## 3 · The three tiers

Sorted by what they contend for, because on this machine contention is the hazard. See §5.

### TIER 1 — no Godot, no file lock, fully parallel

**T1-a · The README inside both itch zips teaches the losing play.**
`tools/pack_itch.py:80` reads *"Two captains. The CAPTAIN dashes twice and fights at range."*
against the class's own compare row at `game_data.gd:308`: *"you lose by: kiting. Range is the
losing line and the gauge says so."* The game ships a coach whose top captain hint exists to
correct exactly this (`coach.gd:82`). The same paragraph calls **both** male classes "she"
(`:66` "her keyed Articles", `:81` "she banks Head"), and `:77` tells the *demo* reader to
survive *"twelve boarding waves"* when the demo is six.
*Fix:* rewrite the two-captain paragraph and the F/V line, lifting wording from `game_data.gd`'s
own compare rows so zip and game cannot drift; parameterise the wave count or move it into
`DEMO_TAIL`. `:67`'s unconditional *"Space dash (two charges)"* goes with it.
*Gate:* a pure-text check over the `README` constant — no Godot, no zip — demonstrated red on
today's text.
**This is the first document a tester reads. It is the highest value-per-minute item in the pass.**

**T1-b · `SkyGear Tools.bat pack` discards its arguments.**
`:49-53` invokes `python tools/pack_itch.py` with no `%2`, while `:44-48` forwards `%2 %3 %4 %5`.
So `"SkyGear Tools.bat" pack --demo` **silently builds and zips the full game** into
`SkyGear-Windows.zip`. `hub.gd:275-286` already documents this exact failure mode as fixed for
the Godot tools. *Do not* apply the same edit to the `parity` branch at `:38` — it already passes
a hardcoded `--open`.

**T1-c · The exe has stamped `0.70.0.0` since build 70.** Four keys, not two:
`export_presets.cfg:27`, `:28`, `:63`, `:64`, all under `modify_resources=true`. → `0.72.0.0`.

**T1-d · Board reconciliation — ONE commit.** Five agents each cutting one row from a 39-row
table is five conflicts on one table.
- **Archive whole:** SG-245, SG-210, SG-228 (the art shipped in `60f098e`; the ❌ clause is false).
- **Archive by folding:** SG-121 → its radius half closed at `0c690d8`; carry the surviving
  `dps` sentence into SG-164 *and* the note that the renderer once read the dictionary, because
  T3-a deliberately makes it read one again and a future agent will otherwise re-file it.
- **Reclassify:** SG-208 `IN PROGRESS` → `BLOCKED`, naming G5(b), G5(c) and IN-00 (an
  agent-runnable audit gate, not an owner decision). SG-127 → `BLOCKED` stub carrying only the
  Heat 5 question; its dead pointer says "NEEDS_ALEX §SG-127" and the live text is item 4.
  SG-105 `BLOCKED` → `OPEN`: the blocker is dead, `tools/imageforge.py` shipped two assets in
  `452578f` and names SG-105 in its own header.
- **Amend:** SG-240 — strike only the last two sentences of reason (2); **keep** the
  overwrite warning, it is still true. SG-226 — status becomes "captured 2026-08-11 15:22 at
  `.shots/clips/sg226_after/`, NOT YET ASSESSED" (the "GPU park" line is false, the capture
  exists) and `≈5209` repoints to `:5291`. SG-219 — 121→124 and the reframe in T3-b.
  SG-215 — `:25-26` repoints to `:44-45`. SG-241 — S1–S4 are shipped (`5c5e788`, `c5d4c82`);
  the row survives only for S5 and S6.
- **Write ten archive rows for SG-246…SG-255** from the commit bodies, which are unusually
  complete. **Declare SG-256 the next free ID in every dispatch.** Ten shipped commits and ten
  code comments already carry SG-246+; issuing one is board rule 1's documented disaster.

**T1-e · STATUS.md** says "Last updated 2026-08-04" and board rule 7 makes it the first thing
every agent reads. Refresh against HEAD. **Do not renumber or reorder its failure-mode list** —
SG-121, SG-125, SG-154 and SG-171 cite it by ordinal.

**T1-f · NEEDS_ALEX.md** is rewritten against HEAD. Its "What changed" section describes the
*superseded* chrome swap that `5ea23a8` retracts in writing; leaving it advertises the version
that was withdrawn.

---

### TIER 2 — `hud.gd` / `game.gd` / `parity_test.gd`, one writer at a time

`hud.gd` is the choke point: **all seven** of the last seven commits touch it. `parity_test.gd`
is a second lock — its check total is a pinned number, so concurrent edits drift it.

| id | change | file:anchor | gate |
|----|--------|-------------|------|
| T2-a | `DisplayServer.window_set_title("SkyGear")` — the alt-tab label, **without** renaming `config/name` | `game.gd`, near `:1629`'s existing `window_set_mode` idiom | check that `project.godot` still holds the old `config/name` **and** the title call exists |
| T2-b | `"WAVE %d / %d"` reading `SkyGearDemo.last_wave()` | `hud.gd:3137` | `demo · the fight HUD counts to the demo's last wave`, posed at `_forced` 1 and 0 |
| T2-c | HOW TO PLAY's literal `500` → `game.boiler_max_hp`, **plus reset `boiler_max_hp` in `begin_run`** | `hud.gd:5058`; `game.gd:2049` | `how · the page quotes the Boiler's live maximum`, **and** a check that two `begin_run()`s in one process leave the maximum equal |
| T2-d | `"The captain fell"` → the class that actually fell; draft footer `"AFFECTS THE CAPTAIN"` → the same lookup | `game.gd:4331` (+ its quoting comment at `:2232`); `hud.gd:4502` | `results · the defeat line names the class that actually fell` |
| T2-e | Playtest row gated on `game.dev_tools and not demo` | `hud.gd:6135`/`:6188`, arithmetic at `:6136`/`:6145` | see the trap below |
| T2-f | Two harness fixtures measure strings S3 deleted | `parity_test.gd:3574`, `:3581` | the two `berths ·` checks measure live text again |
| T2-g | `parity_test.gd:2713` asserts in a comment that four guards are byte-compares; they assert `diverted` and only *report* bytes | `parity_test.gd:2687`, `:2713` | correct the comment; optionally make guards 2–5 assert bytes too |

> **T2-c is a real bug, not a copyedit.** `boiler_max_hp` is declared once at `game.gd:166`
> and `game.gd:2049` does `+=` on every `begin_run()`; `cards.gd:830` adds another 150 mid-run.
> Nothing resets it. **A second run in one session already starts with a compounded Boiler
> maximum.** Reading the live value onto HOW TO PLAY would have printed that compounded number
> to the player, which is how it was found. Reset first, then read.

> **T2-e carries a trap that will ship a red harness if missed.**
> `parity_test.gd:14778` — `demo · and SETTINGS drops the playtest bypass with its caption` —
> toggles `SkyGearDemo._forced` and asserts the full build *contains* "Playtest". Moving the
> gate makes the row draw regardless of `_forced`, and the check goes **permanently red**.
> It must be rewritten in the same commit. Separately, the vocabulary walk runs under the
> editor binary, so `OS.has_feature("editor")` is TRUE during the harness — the walk must
> force `game.dev_tools = false` on its posed game **before** "playtest" is added to the banned
> array at `:14494`, or that check is red on every run rather than being a gate.

---

### TIER 3 — exclusive Godot, strictly serial

**T3-a · Fire `dps`, seven steps, balance quarantined.**
Steps 1–4 are behaviour-neutral by construction; step 5 is the entire balance change, in one
data file, with its own revert.

1. `game_data.gd` only — add `FIRE_SOURCES` carrying **today's** rate (`lantern` 30.0, i.e. the
   shipped `7.5`-per-tick literal expressed in the house per-second unit). Dead data, zero
   behaviour change.
   **The table carries `dps` and nothing else.** Radius stays `FIRE_RADIUS`, stamped by `_field()`
   as it is today — putting a per-source radius in this table, even one equal to 78 everywhere,
   re-opens the question D3 settled and invites the next agent to differentiate it.
2. `game.gd` only — `_field()` reads `d.get("source", "lantern")` and stamps `dps` beside the
   radius it already stamps. Accessors live beside `fire_pool_radius()` (`game.gd:4644`).
   **Do not change `fire_pool_radius()`'s arity in place** — it has *seven* zero-argument call
   sites (`game.gd:4658`, `:4659`, `:5730`, `:5731`; `view3d.gd:5420`; `parity_test.gd:7448`;
   `pool_shot.gd:139`), including a 2D `_draw` at `game.gd:5730-5731` that no prior analysis
   named.
3. `_update_fire_fields` — `float(field.dps) * FIRE_TICK` on the enemy leg;
   `* PLAYER_FIRE_SHARE` on the player leg, where `const PLAYER_FIRE_SHARE := 0.4` is
   **derived and commented as exactly `3.0 / 7.5`** — the shipped asymmetry preserved rather
   than retyped. This keeps `parity_test.gd:16178` and `:16216` green through the whole
   plumbing phase, which is the cheapest available safety net. The multiplication stays
   **inside** the `while` loop at `:4655` or a hitching frame silently changes the rate.
4. **Both** RESIDUE creators — `game.gd:3336` (instant) **and `game.gd:3418`** (the channelled
   path inside `_finish_active_channel`, which no board row counts). A grep-and-fix that stops
   at the first `13.0 *` ships instant and channelled casts leaving different fires.
5. `game_data.gd` only, **data diff, the whole balance change** — the §2b table.
6. `tools/bot.gd:215` reads `float(field.radius)`; delete `const FIRE_RADIUS := 78.0` at `:130`.
   Instrument only, but it must land **before** any measurement is recorded.
7. `parity_test.gd` — the new checks; derive `:5204`'s `"authored": 7.5` from the table.

*Checks:* `hazard · a pool burns at the rate its own source authored — a lantern and a scald
trail are not the same fire`; `hazard · a channelled skill leaves the same pool an instant one
does`; and a RESIDUE stack check that **measures damage dealt to a body**, in the shape of
`parity_test.gd:16178`. A check asserting `dps(2) == 2 * dps(1)` off the table reads the table
against itself and proves the number equals itself.
*Non-vacuity, both directions, for every new check:* (i) drift the authored side and confirm the
named check fails quoting the drifted number; (ii) **restore the literal `7.5` at `game.gd:4658`
and confirm the same check fails quoting 7.5.** Only (ii) catches a consumer regression.
*Measurement:* **not `tools/balance.gd`.** It never calls `set_class`, so the Boilerwright's
scald trail cannot occur in a balance run at any n, and RESIDUE enters only by accident
(`bot.gd:160` gives upgrade cards no ranking). A null result would be true and meaningless.
Use a deterministic per-source bench — fixed enemy, fixed offset, integrate 10 s at 1/60 — and
`tools/pool_shot.gd` for the footprint half.

**T3-b · Mipmaps — and the row's headline reason is wrong.**
SG-219 argues that `anisotropic_filtering_level=4` "is doing nothing at all" because the deck
is unmipped. **The deck is not an imported PNG.** `view3d.gd:1208` binds `_planking_texture()`,
`view3d.gd:3917` routes it through `_with_mips` → `img.generate_mipmaps()`, `view3d.gd:1215`
sets `LINEAR_WITH_MIPMAPS_ANISOTROPIC` on that material, and `parity_test.gd:8804` already
asserts it. Anisotropy does real work on the deck.

The real defect is one line away: **`view3d.gd:9899` sets `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`
on every character billboard**, whose textures *are* the unmipped imports — a no-op request.
`view3d.gd:3865-3869` already wrote the argument; the generated half landed and the imported
half never did.

That reframes the fix and shrinks it:
- **Set `mipmaps/generate=true` only. Keep `compress/mode=0` (Lossless) everywhere.**
- **Do not set `compress/normal_map=1`** — it selects a VRAM format and is inert under Lossless.
- Anisotropy works fine on an uncompressed mipmapped texture, so this buys the entire stated
  benefit while deleting the pixel-band regression risk: BPTC/S3TC is what moves the published
  bands `still.gd` and `lit_probe.gd` measure against, and it is not being adopted.
- **Partition: 63 files, not 124 and not 74.** Only 12 model textures are bound by any `.res`;
  21 `*_thumb.png` are pipeline artifacts bound by nothing; `captain_metal/normal/rough` are
  unbound; 5 of 7 `ground`, 4 of 6 `fx` and `env/bow_prow.png` are never loaded (their `_art`
  keys are dead or retired); `heroes/boilerwright_front_attack.png` is referenced by nothing.
  `assets/art/ui/*` (26) stays untouched — it is drawn in 2D.
- **Atlas hazard, unnamed by the row:** `assets/art/animations/*.png` are sprite sheets drawn
  through `region_rect` (`sprites.gd:28-32`, `view3d.gd:9803-9805`). Mipmapping an atlas bleeds
  neighbouring frames at minified levels. **Default: exclude those four, making the set 59.**
  Include them only if the before/after specifically inspects a running and an idling figure for
  frame bleed and finds none — in which case the set is 63 and the row says which it shipped.
- **Alpha-cut erosion** covers the 19 prop plates too (`view3d.gd:9898` is in the same branch
  reached by `_place`), not only distant boarders — masts and railings are the worst case.
- *Gate:* a manifest **superset** scan that prints its count rather than equality-testing it.
  A literal `== 63` goes red the next time anyone adds an asset; the count moved 121→124 in one
  working day.

**T3-c · The legibility floor at 1600×900.**
- `project.godot`: add `window/stretch/aspect="keep"` as a **drift guard** — not a distortion
  fix, that half was struck. Godot rewrites this file on editor open, so the pin below must land
  in the same commit as the key.
- `ink.gd`: `const MIN_SUPPORTED_W := 1600` beside `MIN_WINDOW_W`, commented with why
  `min_size` is the wrong instrument for a fullscreen window.
- Three checks, replacing one vacuous one. `parity_test.gd:15157` evaluates
  `12 × 1600/1920 = 10.0` against a floor of `10.0` — **it passes by exactly zero, at one
  width.** New: `ink · the floor is measured against the scaling the game actually ships`
  (reads the four shipped keys back, folding in the existing `viewport_width` check rather than
  adding a fifth near-duplicate); `ink · the point-size floor clears the physical floor on the
  narrowest supported display`; and a tightness sibling proving it would go red —
  `physical_pt(MIN_PT - 1, MIN_SUPPORTED_W) < MIN_PHYS_PX`. **Use that general form**, not the
  `- 64` width step, which is arithmetically broken under other choices of the constant.
- Boot guard beside `game.gd:558` reading `DisplayServer.screen_get_size()`, surfacing "below
  supported resolution".
- `--shipped` mode on `tools/legibility_probe.gd` leaving content scale ON, so the matrix
  finally exercises the shipped path. **Add a separate constant — do not touch `poser.SIZES`**,
  which `parity_test.gd:14186` asserts equal to the screens tool's copy.
- Keep the ten existing content-scale-disable sites. They are correct for measurement; the hole
  is a missing mode, not ten wrong lines.

**T3-d · One capture session, serial, at HEAD.** Everything below shares one card and one
import cache.
1. Fonts at four widths at HEAD. The existing sets are all stale: `polish-audit` (16:06)
   predates the font commit (18:45) by two and a half hours; `aaa` (23:00) predates SG-254 and
   SG-255. **Add a mechanical identity gate** — `text_audit` exits on violation *count* and has
   no notion of font identity, so every string silently falling back to `ThemeDB.fallback_font`
   (`hud.gd:2796` only warns) would still exit 0. Assert `hud.font`/`hud.display` are not the
   fallback.
2. Ink pass on/off pair on the five deck-bearing poses. **Its stated protection is backwards:**
   `_arm_deck_post` refuses only when the display is headless (`view3d.gd:1509`), which is the
   exact negation of `can_capture()` — so *every* tool that can photograph the deck photographs
   it **with** ink, including the windowed `still_probe` and `lit_probe` whose published
   absolute bands the row claims to protect. `view3d.gd:1539 set_deck_post(false)` is never
   called by anything; NEEDS_ALEX offers it as the off switch and it is unreachable.
3. Film: confirm the shipped blob. `eb63995`'s `opening.ogv` is `58fc733…`, 33,315,163 B;
   HEAD's is `cc27ac8…`, 31,356,599 B. **The film the owner would watch is not the one build 71
   shipped.**
4. SG-226: **no new capture.** `.shots/clips/sg226_after/` (80 frames + a 14 MB gif) was taken
   at 15:22 on 08-11 and nobody has looked — `grep sg226_after docs/` returns nothing. The
   remaining question is one sentence: does the rim read thinner than the retired solid crescent?

---

## 4 · Wants the owner's go, not in scope by default

- **SG-105 — the Boilerwright wears the Captain's portrait**, and SG-228 made that worse: the
  portrait is now unmistakably one specific young man, and `hud.gd:2910` hardcodes it with no
  class branch. Under D2 every tester can pick the Boilerwright. `tools/imageforge.py` can
  produce it without the Loom, but it **costs money** and needs the same explicit go the 50 VO
  takes did. Reuse `portrait_from_clip.py`'s feathered-disc mask or the corners show.
- **A pre-first-win tester gets nothing.** Workshop, Berths, Heat and fittings are all gated on
  a first *twelve-wave* victory (`workshop.gd:568`), so a tester who dies on wave 5 sees a
  results sheet with every progression line skipped — strictly less closure than the demo cut,
  which wins at wave 6 and pays an end card. **Do not weaken the first-victory rule**;
  `MENU-DESIGN.md:166-176` already refused that. The cheap honest version is one conditional
  line on the results sheet naming what the first held deck opens. It is a design change and
  it is the owner's call.

---

## 5 · Serialization — the machine-safety rules

1. **One Godot process at a time, always.** The 2026-08-11 freeze came from concurrent passes
   thrashing the shared `.godot` import cache, and it corrupted git. This binds harder than any
   file lock and covers: the mipmap re-import, every capture, `pool_shot`, `legibility_probe`,
   the harness, and both exports. **Never beside a ComfyUI or `imageforge` render.**
2. **`hud.gd` and `ui.gd` are one lock, not two** (`b4d50fa` touched both). Every T2 item queues.
3. **`parity_test.gd` is a second lock.** Its check total is pinned; any two items landing
   together merge their check additions in one edit.
4. **`game_data.gd` T3-a steps 1 and 5 are separate commits against the same lines** — that
   separation *is* the balance change's revert.
5. **Board edits are one commit** (T1-d).
6. Tier 1 runs fully parallel with everything: `pack_itch.py`, the batch file and
   `export_presets.cfg` touch nothing the Godot project reads.

---

## 6 · The ship gate

Nothing is pushed until every line below is true and **observed, not quoted**:

1. Harness green at its new total (≥1227), **exit 0, 0 script errors, 56 engine errors against
   the pinned 56**. `"SkyGear Tools.bat" all` is the stricter gate — `hub.gd:314-317` counts a
   script error as a failure even on exit 0.
2. Every new check demonstrated **red** first, both directions where §3 says so, with the
   failing line pasted into the row.
3. `python tools/pack_itch.py` and `python tools/pack_itch.py --demo`, **both off one commit
   and one harness run** (`pack_itch.py:33-37`).
4. Both exes' VersionInfo read back: `SkyGear-Godot.exe` → `product_name="SkyGear"`,
   `SkyGear-Demo.exe` → `"SkyGear Demo"`, both `0.72.0.0`. This is how the feature tag is proved
   applied rather than assumed.
5. The demo exe **launched and photographed** at its title screen, as build 71's was.
6. `butler push … alex-unconstrained/skygear-godot-test:windows` and `… :windows-demo`, with
   `--userversion 72-<slug>` — build 71 used `71-demo-cut-and-opening-film`, so the slug names
   what the build is for, not its date.
7. Build numbers recorded in a new SHIPPING board row **and** in NEEDS_ALEX, with the rollback
   number written down (the only rollback mechanism this project has).

Toolchain confirmed present: `godot.exe` 4.7.1, `.templates/windows_release_x86_64.exe`
(109,212,160 B, gitignored), `butler.exe` with saved credentials at `~/.config/itch/butler_creds`.

---

## 7 · Explicitly out of scope

Named so nobody treats the omission as an oversight: SG-95 (dynamic shadows), SG-73 (the
Colossus billboard), SG-227 (the swing-plate repaint), SG-171 (`grip_at`), SG-153 (the 56 engine
errors), SG-189 (the crew's swing), SG-151/SG-152 (triangle budget and guard), SG-175, SG-124,
SG-125/SG-127/SG-132 (the measurement-rig rows), SG-154 (the crit self-hit), SG-24, SG-20,
SG-239 (the audio pipeline — and note two of its premises are refuted: the ffmpeg is durable in
user site-packages, and `tools/vo_line.py:41` already writes `.ogg` into the Godot tree), and
NEW-8 (each class's dead `starting` key — free to delete, but it is data cleanup, not polish).

---

## 8 · Risks

| risk | mitigation |
|------|------------|
| T2-e ships a permanently red check | `parity_test.gd:14778` is rewritten in the same commit; the vocabulary walk forces `dev_tools = false` before "playtest" joins the banned list |
| The mipmap re-import moves published pixel bands | Compression is **not** adopted; only mipmaps change. `lit_probe`'s bands are re-read after, not before |
| An atlas bleeds frames | The four `animations` sheets are excluded, or frame bleed is an explicit clause of the before/after |
| The fire balance step is unmeasurable | `balance.gd` is not used; a deterministic per-source bench is built first, and `bot.gd`'s stale 78 is fixed before any number is recorded |
| A stale board ID collides | SG-256 is declared the next free ID in every dispatch, and the ten missing rows land before any ID is issued |
| The owner judges a build that is not HEAD | The ship gate records a commit hash with the build number |
