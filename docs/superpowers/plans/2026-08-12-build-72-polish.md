# Build 72 — Player-Test Polish Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship itch build 72 on both channels off one commit — verifying three things that shipped unlooked-at, fixing what a first-time tester collides with, and reconciling a board that stopped at build 71.

**Architecture:** Three tiers by contention. Tier 1 touches nothing Godot reads and runs fully parallel. Tier 2 serializes on `scripts/hud.gd` and `tests/parity_test.gd`. Tier 3 needs an exclusive Godot process. Every behaviour change is gated by a named harness check demonstrated RED before it is made green.

**Tech Stack:** Godot 4.7.1 (GDScript), Python 3.13 for the packaging tools, `butler` for itch, Windows.

**Spec:** `docs/superpowers/specs/2026-08-12-build-72-polish-design.md`

---

## Global Constraints

- **ONE GODOT PROCESS AT A TIME. NEVER TWO.** Concurrent `godot --path .` runs thrash the shared `.godot` import cache; on 2026-08-11 that froze the machine and corrupted git. This binds harder than any file lock and covers the harness, every capture, every probe, the mipmap re-import and both exports. Never beside a ComfyUI or `imageforge` render.
- **The next free board ID is `SG-256`.** `SG-246`…`SG-255` are consumed by shipped commits and ten code comments. Do not issue `SG-246`.
- **"The browser did it this way" is not a reason for anything.** Parity was retired 2026-08-01 and hardened 2026-08-03. `skygear-godot/reference/` is an archive, never an authority.
- **DONE needs evidence**: a named harness check string, a tool output, or a commit hash. Never "looks right".
- **Every new check must be demonstrated RED before it is made green**, and the failing line pasted into the commit body. A check that has never failed is not a gate.
- **The harness total is not pinned** — `parity_test.gd:450` prints `checks/checks`, so the number rises as checks are added. What *is* pinned: `ENGINE_ERROR_BUDGET := 56` (`parity_test.gd:429`, may fall, may not rise) and the floor `EXPECTED_AT_LEAST := 250` (`:443`). The gate is **exit code 0 with zero failures**, not a particular total.
- **Baseline, MEASURED at `d1d0125` in Task 1: `1227/1227 checks passed`, exit 0, 0 script errors, and *54* engine errors.**
- **The engine-error count is 54, not the 56 every recent commit quotes.** The budget is a ceiling (`<=`), so the check passes green with the pin two above reality. Task 11 lowers it to 54. **Until then, expect 54 and treat any rise as a regression you caused.**
- **Shipped version string for this build: `0.72.0.0`.** All four keys.
- **Fire rate unit is damage-per-SECOND**, as for `SkyGearData.TAP.dps`. The shipped `7.5` is per-tick at `FIRE_TICK := 0.25` — that is `30.0` per second.

### The two commands every task uses

Run from the repo root. `$GODOT` is `C:/Users/alexr/.local/bin/godot.exe`.

```bash
# THE HARNESS. One at a time. Takes a few minutes.
cd skygear-godot && "$HOME/.local/bin/godot.exe" --path . --headless --script res://tests/parity_test.gd 2>&1 | tail -30

# THE STRICTER GATE — also fails on a GDScript SCRIPT ERROR even at exit 0 (hub.gd:314-317).
"./SkyGear Tools.bat" all
```

To see one check's line, pipe through grep on a distinctive fragment of its name:

```bash
cd skygear-godot && "$HOME/.local/bin/godot.exe" --path . --headless --script res://tests/parity_test.gd 2>&1 | grep -i "stamped version"
```

---

## File Structure

| File | Responsibility in this plan | Tasks |
|------|------------------------------|-------|
| `skygear-godot/tools/pack_itch.py` | The zip's README copy; the export/zip procedure | 2 |
| `SkyGear Tools.bat` | Front-door dispatch; must stop eating arguments | 3 |
| `skygear-godot/export_presets.cfg` | Stamped exe identity and version | 4 |
| `skygear-godot/docs/BOARD.md`, `BOARD-ARCHIVE.md`, `STATUS.md`, `/NEEDS_ALEX.md` | The ledger, reconciled to HEAD | 5, 18 |
| `skygear-godot/scripts/hud.gd` | Every drawn string fixed in Tier 2 — **the choke point, one writer at a time** | 7, 8, 9, 10 |
| `skygear-godot/scripts/game.gd` | Window title; `boiler_max_hp` reset; defeat line; the fire tick and `_field` | 6, 8, 9, 12 |
| `skygear-godot/scripts/game_data.gd` | `FIRE_SOURCES` — the per-source rate table | 12, 13 |
| `skygear-godot/scripts/ink.gd` | `MIN_SUPPORTED_W`, the legibility floor's new basis | 16 |
| `skygear-godot/project.godot` | `stretch/aspect` drift guard | 16 |
| `skygear-godot/tests/parity_test.gd` | **Every gate in this plan — the second lock** | 2, 4, 6–13, 16 |
| `skygear-godot/tools/bot.gd` | Stops keeping a private copy of the fire radius | 12 |
| `skygear-godot/assets/**/*.png.import` | Mipmaps on the 3D-facing set | 15 |

---

## Task 1: Record the baseline

**Files:** none modified.

**Interfaces:**
- Produces: the baseline numbers every later task compares against.

- [ ] **Step 1: Confirm the tree is clean and at the expected commit**

```bash
cd "C:/Users/alexr/OneDrive/Documents/GitHub/skygear"
git status --short
git log --oneline -1
```

Expected: no output from `status`; `a1d7e3a` (or later, if earlier tasks have landed).

- [ ] **Step 2: Run the harness**

```bash
cd skygear-godot && "$HOME/.local/bin/godot.exe" --path . --headless --script res://tests/parity_test.gd 2>&1 | tail -30
```

Expected: a final line `1227/1227 checks passed` and exit code 0. **MEASURED 2026-08-12: 1227/1227, exit 0, and 54 engine errors against a pin of 56** — the budget is a ceiling, so it passes green while sitting two above reality. Task 11 lowers the pin to 54.

- [ ] **Step 3: Write the numbers down**

Record the total, the engine-error count and the exit code in the task notes. Every later task states its expected new total as `baseline + N`.

**No commit** — this task changes nothing.

---

## Task 2: The README inside both itch zips

The first document a tester reads tells them to play the losing line. `pack_itch.py:80` says the CAPTAIN *"fights at range"*; `game_data.gd:308` says *"you lose by: kiting. Range is the losing line and the gauge says so."* The same paragraph calls both male classes "she", and `:77` tells the demo reader to survive *"twelve boarding waves"* when the demo is six. **No harness check has ever covered `pack_itch.py`.**

**Files:**
- Modify: `skygear-godot/tools/pack_itch.py:57-86` (the `README` constant) and `:100`
- Modify: `skygear-godot/tests/parity_test.gd` (new check)

**Interfaces:**
- Produces: `README_TMPL` — a module-level `str` containing the sentinel `{WAVES}`, replaced at pack time. Task 18 consumes the packed output.

- [ ] **Step 1: Write the failing check**

In `tests/parity_test.gd`, beside the other source-scanning checks (the idiom is `FileAccess.get_file_as_string` + `.contains()`, as at `:1310` and `:1750`), add:

```gdscript
	## THE FIRST DOCUMENT A TESTER READS. It sat in the zip for two builds saying
	## the CAPTAIN "fights at range" while `game_data.gd`'s own compare row says
	## "you lose by: kiting. Range is the losing line and the gauge says so." — and
	## calling both male classes "she". Nothing covered `pack_itch.py` at all,
	## which is why it survived SG-228's text sweep.
	var packer := FileAccess.get_file_as_string("res://tools/pack_itch.py")
	var readme_sins: Array[String] = []
	for phrase in ["fights at range", "her keyed Articles", "she banks Head",
			"if she is carrying any", "the pressure she is carrying"]:
		if packer.contains(phrase):
			readme_sins.append(phrase)
	_check("shipping", "the packed README names each class by the pronoun and the range the game gives it",
		readme_sins.is_empty() and packer.contains("{WAVES}"),
		"offending phrases %s; wave count parameterised %s"
			% [str(readme_sins), str(packer.contains("{WAVES}"))])
```

- [ ] **Step 2: Run the harness and watch it fail**

```bash
cd skygear-godot && "$HOME/.local/bin/godot.exe" --path . --headless --script res://tests/parity_test.gd 2>&1 | grep -i "packed README"
```

Expected: a FAIL line naming all five phrases and `wave count parameterised false`.

- [ ] **Step 3: Rewrite the README copy**

In `tools/pack_itch.py`, rename the constant to `README_TMPL` and make these four edits. Replace lines 65-67:

```python
  F V       the Boilerwright's tap and blowdown. On the captain these are
            his keyed Articles, if he is carrying any.
  Space     dash, two charges — or the Boilerwright's bleed jet, which is
            how he moves instead.
```

Replace line 77's sentence:

```python
Keep the Boiler alive through {WAVES} boarding waves. Every skill is a shape
```

Replace lines 80-83 entirely:

```python
Two captains, and they do not play alike. The CAPTAIN dashes twice and has to
fight CLOSE — his gauge fills from damage landed inside 210 units, and range is
the losing line. The BOILERWRIGHT has no dash at all: he banks Head from the
Boiler where he stands, and the pressure he is carrying is the resource the
whole class turns on. The class screen says how, in numbers.
```

- [ ] **Step 4: Parameterise the wave count at pack time**

Replace line 100:

```python
    readme = README_TMPL.replace("{WAVES}", "six" if a.demo else "twelve")
    if a.demo:
        readme += DEMO_TAIL
```

`.replace` rather than `.format` or `%`: the README is prose that may grow braces or percent signs later, and a sentinel cannot be broken by either.

- [ ] **Step 5: Run the harness and watch it pass**

```bash
cd skygear-godot && "$HOME/.local/bin/godot.exe" --path . --headless --script res://tests/parity_test.gd 2>&1 | grep -i "packed README"
```

Expected: `ok · shipping · the packed README names each class by the pronoun and the range the game gives it`.

- [ ] **Step 6: Prove the check non-vacuous in the other direction**

Temporarily put `fights at range` back in the file, re-run, confirm RED, then restore and confirm `git diff tools/pack_itch.py` shows only the intended change.

- [ ] **Step 7: Commit**

```bash
git add skygear-godot/tools/pack_itch.py skygear-godot/tests/parity_test.gd
git commit -m "SG-256: the first document a tester reads taught the losing play"
```

---

## Task 3: `SkyGear Tools.bat pack` stops discarding its arguments

`:49-53` invokes `python tools/pack_itch.py` with no `%2`, so `pack --demo` **silently builds and zips the full game** into `SkyGear-Windows.zip` — a wrong-file push waiting to happen on ship day. `hub.gd:275-286` documents this exact failure as already fixed for the Godot tools.

**Files:**
- Modify: `SkyGear Tools.bat:49-53`

**Interfaces:**
- Produces: `"SkyGear Tools.bat" pack --demo` reaching `pack_itch.py` with `--demo`. Task 18 relies on this.

- [ ] **Step 1: Make the change**

```bat
if /i "%~1"=="pack" (
  python tools/pack_itch.py %2 %3 %4 %5
  pause
  exit /b
)
```

**Do NOT make the same edit to the `parity` branch at `:37-41`.** It already passes a hardcoded `--open`, so forwarding extra arguments appends to an existing flag rather than filling an empty slot — a different change that needs `parity.py`'s argparse checked first.

- [ ] **Step 2: Verify by observation — no harness reaches a `.bat`**

```bash
cd "C:/Users/alexr/OneDrive/Documents/GitHub/skygear"
"./SkyGear Tools.bat" pack --demo --no-export
ls -la skygear-godot/builds/itch/
```

Expected: `SkyGear-Demo-Windows.zip` is written (or the run fails naming the *demo* exe as missing). Before this change the same command produced `SkyGear-Windows.zip`. `--no-export` keeps this from starting a Godot process.

- [ ] **Step 3: Commit**

```bash
git add "SkyGear Tools.bat"
git commit -m "SG-257: the front door dropped every argument after pack"
```

---

## Task 4: The exe has stamped 0.70.0.0 since build 70

Four keys, not two: `export_presets.cfg:27`, `:28`, `:63`, `:64`, all stamped into the binary by `modify_resources=true`. SG-210's own row asked for a `shipping ·` check domain that parses these files as text; it still does not exist.

**Files:**
- Modify: `skygear-godot/export_presets.cfg:27,28,63,64`
- Modify: `skygear-godot/tests/parity_test.gd`

**Interfaces:**
- Consumes: the `shipping` check domain introduced in Task 2.
- Produces: `SHIPPED_VERSION` — a `String` constant in `parity_test.gd`, the single declared build version.

- [ ] **Step 1: Write the failing check**

```gdscript
	## SG-210 asked for this domain and it never got written, which is how the exe
	## carried 0.70.0.0 through build 71. Four keys, two presets — counting them is
	## half the check, because a third preset would otherwise slip past unstamped.
	const SHIPPED_VERSION := "0.72.0.0"
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	var stamped := 0
	var wrong: Array[String] = []
	for raw in presets.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("application/file_version=") \
				or line.begins_with("application/product_version="):
			stamped += 1
			if not line.ends_with("\"%s\"" % SHIPPED_VERSION):
				wrong.append(line)
	_check("shipping", "every stamped version key agrees with the build this commit ships",
		stamped == 4 and wrong.is_empty(),
		"%d version keys found (want 4), disagreeing: %s" % [stamped, str(wrong)])
```

- [ ] **Step 2: Run the harness and watch it fail**

```bash
cd skygear-godot && "$HOME/.local/bin/godot.exe" --path . --headless --script res://tests/parity_test.gd 2>&1 | grep -i "stamped version"
```

Expected: FAIL, `4 version keys found (want 4), disagreeing: [...0.70.0.0"...]` listing all four.

- [ ] **Step 3: Bump all four keys**

In `export_presets.cfg`, set `:27`, `:28`, `:63`, `:64` to `"0.72.0.0"`.

- [ ] **Step 4: Run the harness and watch it pass**

Expected: `ok · shipping · every stamped version key agrees with the build this commit ships`.

- [ ] **Step 5: Prove the count clause bites**

Temporarily change `:27` to `"0.71.0.0"`, re-run, confirm RED naming that line, restore.

- [ ] **Step 6: Commit**

```bash
git add skygear-godot/export_presets.cfg skygear-godot/tests/parity_test.gd
git commit -m "SG-258: the exe said 0.70.0.0 for two builds, and nothing was watching"
```

---

## Task 5: Reconcile the board to HEAD — one commit

`BOARD.md`'s newest commit is `eb63995`; HEAD is thirteen commits later. `SG-246`…`SG-255` exist only in commit messages. Five agents each cutting one row from a 39-row table is five conflicts on one table, so this is **one commit by one writer**.

**Files:**
- Modify: `skygear-godot/docs/BOARD.md`, `skygear-godot/docs/BOARD-ARCHIVE.md`, `skygear-godot/STATUS.md`, `NEEDS_ALEX.md`

**Interfaces:**
- Produces: a board whose Active table holds only open work, and `SG-256` as the declared next free ID. Tasks 2–4 have already consumed `SG-256`–`SG-258`; this task files their rows and declares `SG-259` next.

- [ ] **Step 1: Write ten archive rows for the unfiled work**

```bash
cd "C:/Users/alexr/OneDrive/Documents/GitHub/skygear"
git log --format='%H%n%s%n%b%n---' eb63995..a1d7e3a
```

Each of the ten commit bodies states its own root cause and its harness figure. Write one archive row per ID — `SG-246`, `SG-247`, `SG-248`, `SG-249`, `SG-250`, `SG-251`, `SG-252`, `SG-253`, `SG-254`, `SG-255` — into `BOARD-ARCHIVE.md`, each carrying its commit hash and its `Harness 1227/1227` line.

- [ ] **Step 2: Cut the finished rows out of Active into the archive, evidence intact**

- **SG-245** — DONE, nothing open. The three things it names as unshipped are carried by SG-242/243/244, all separately Active.
- **SG-210** — DONE. `export_presets.cfg:24` and `:60` carry the icon, `project.godot:24` carries `config/icon`, both files exist. Its dead pointer ("NEEDS_ALEX item 4") is now about Heat 5; the icon debt is paid. Its alt-tab half is correctly owned by SG-223.
- **SG-228** — DONE. `60f098e` shipped `portrait_corsair.png` (324,023 B, the old file kept as `.pre-SG-228`). The ❌ "remains a blue-coated, red-haired woman" clause is false.
- **SG-121** — fold and archive. Its radius half closed at `0c690d8`. **Carry two sentences into SG-164 before cutting**: the surviving `dps` complaint, and the record that the renderer once read the dictionary — Task 12 deliberately makes it read one again, and a future agent will otherwise re-file it as a regression.

- [ ] **Step 3: Reclassify the rows whose status label is the lie**

- **SG-208**: `IN PROGRESS` → `BLOCKED`. Blockers: G5(b) and G5(c) from the owner, plus IN-00 — and record that IN-00 is an **agent-runnable audit gate**, not an owner decision. Labelled IN PROGRESS it reads as claimable and a builder will claim it and find nothing to build.
- **SG-127**: → `BLOCKED`, reduced to a one-line stub carrying only the Heat 5 question. Cut the re-measured SG-128 body into the archive. Fix its dead pointer: it says "Owner decision in NEEDS_ALEX §SG-127"; the live text is item 4. **Verify before cutting** that SG-132 still carries "Heats 1 and 2 have still never been run" — it does, and that is the other residual's home.
- **SG-105**: `BLOCKED` → `OPEN`. The blocker is dead: `tools/imageforge.py` exists, names SG-105 in its own header as "a second, independent door", and shipped two assets in `452578f`. Rescope the row to its one player-visible bug — the Boilerwright wears `portrait_corsair.png` because `hud.gd:2910` has no class branch, and SG-228 made that portrait unmistakably one specific young man. Mark it **needs the owner's go, costs money**.
- **SG-241**: S1–S4 are all shipped (`5c5e788`, `c5d4c82`). Strike "S3 · NEXT", strike "S2 · CLEARED, NOT STARTED", and strike SG-161, DR-09 and DR-17 from its "also live" list — all three landed. Name the four checks that close them: `text · no development vocabulary on a shipping surface`, `settings · the footer never prints through BACK`, `results · the drawn sheet does not say the verdict twice`, `results · the clipboard report is byte-identical before and after`. The row stays open for S5 (owner taste) and S6 (Task 10).

- [ ] **Step 4: Amend the rows whose facts have rotted**

- **SG-240**: strike **only the last two sentences** of reason (2) — the "0 delivered" contradiction is resolved (`forge.py:525-533` asks both trees now). **Keep** the sentence warning that every target file already exists and ingest overwrites live art; it is still true and the row's own risk depends on it.
- **SG-226**: the status says "windowed capture deferred by the owner's GPU park". False — `.shots/clips/sg226_after/` (80 frames) and a 14 MB gif were captured at 15:22 on 08-11 and nobody looked. Restate as "captured 2026-08-11 15:22, NOT YET ASSESSED", and repoint `≈5209` to `:5291`.
- **SG-219**: 121 → 124 `.png.import` files, and replace the headline reason per Task 15 — the deck is a generated texture that already mipmaps.
- **SG-215**: repoint `project.godot:25-26` to `:44-45`; the file is 127 lines, not 98.
- **SG-164**: repoint `game.gd:3923+` to `:4648`, and record that there are **two** RESIDUE creators (`:3337` and `:3419`), not one.

- [ ] **Step 5: Declare the next free ID and file this pass's own rows**

Add rows for `SG-256`, `SG-257`, `SG-258` (Tasks 2–4) and state in the Active table's preamble: **next free ID is `SG-259`.**

- [ ] **Step 6: Refresh STATUS.md**

Board rule 7 makes it the first thing every agent reads and it says "Last updated 2026-08-04". Bring it to HEAD. **Do not renumber or reorder its failure-mode list** — SG-121, SG-125, SG-154 and SG-171 cite it by ordinal ("the first failure mode", "the sixth", "the seventh").

- [ ] **Step 7: Rewrite NEEDS_ALEX.md against HEAD**

Its headline still reads "Build 71 IS LIVE ON ITCH". Its "What changed" section describes the plate treatment that `5ea23a8`'s own body retracts — *"calling it done was wrong"* — so the page currently advertises a superseded version of the work. Rewrite both.

- [ ] **Step 8: Verify no ID is orphaned**

```bash
cd "C:/Users/alexr/OneDrive/Documents/GitHub/skygear"
for id in 246 247 248 249 250 251 252 253 254 255 256 257 258; do
  printf "SG-%s " "$id"
  grep -l "SG-$id" skygear-godot/docs/BOARD.md skygear-godot/docs/BOARD-ARCHIVE.md 2>/dev/null | tr '\n' ' '
  echo
done
```

Expected: every ID appears in at least one of the two files.

- [ ] **Step 9: Commit**

```bash
git add skygear-godot/docs/BOARD.md skygear-godot/docs/BOARD-ARCHIVE.md skygear-godot/STATUS.md NEEDS_ALEX.md
git commit -m "The board stopped at build 71 and the tree did not — ten IDs filed, five rows archived"
```

---

## Task 6: The alt-tab label

`grep -rn 'window_set_title' --include=*.gd .` returns nothing, so `config/name="SkyGear: Godot Port"` **is** the taskbar string. Godot also derives `user://` from that value, which is why renaming it orphans every save (SG-223) — **so this task does not rename it.** One line fixes the label and touches no save path.

**Files:**
- Modify: `skygear-godot/scripts/game.gd` (near `:1629`'s existing `DisplayServer.window_set_mode` idiom)
- Modify: `skygear-godot/tests/parity_test.gd`

**Interfaces:**
- Produces: nothing other tasks consume.

- [ ] **Step 1: Write the failing check**

```gdscript
	## SG-223, THE CHEAP HALF. `config/name` is ALSO what Godot derives `user://`
	## from, so renaming it orphans every save the player has — the rename was made
	## and reverted inside an hour on 2026-08-11. Nothing in this codebase reads
	## `config/name`; its only effects are the window title and that derivation. So
	## the title is set at runtime and the setting is left alone ON PURPOSE, and
	## this check asserts BOTH halves so a later agent cannot "tidy" one of them.
	var proj := FileAccess.get_file_as_string("res://project.godot")
	var game_src := FileAccess.get_file_as_string("res://scripts/game.gd")
	_check("shipping", "the window names the game, and the save path is left where the saves are",
		game_src.contains("DisplayServer.window_set_title(\"SkyGear\")")
			and proj.contains("config/name=\"SkyGear: Godot Port\""),
		"title call %s; config/name untouched %s"
			% [str(game_src.contains("DisplayServer.window_set_title(\"SkyGear\")")),
				str(proj.contains("config/name=\"SkyGear: Godot Port\""))])
```

- [ ] **Step 2: Run the harness and watch it fail**

Expected: FAIL, `title call false; config/name untouched true`.

- [ ] **Step 3: Set the title**

In `scripts/game.gd`, inside `_ready()` (which begins at `:519`), beside the existing window work near `:558`:

```gdscript
	## THE LABEL, WITHOUT THE COUPLING. `config/name` stays "SkyGear: Godot Port"
	## because Godot derives `%APPDATA%/Godot/app_userdata/<name>` from it and the
	## player's runs.json, workshop.json, keys.cfg, settings.cfg and hud_layout.json
	## all live under the old one (board SG-223). Renaming it is a migration, not a
	## copyedit; setting the title is neither.
	DisplayServer.window_set_title("SkyGear")
```

- [ ] **Step 4: Run the harness and watch it pass**

- [ ] **Step 5: Commit**

```bash
git add skygear-godot/scripts/game.gd skygear-godot/tests/parity_test.gd
git commit -m "SG-223: the alt-tab label, without touching the string every save hangs off"
```

---

## Task 7: The fight HUD counts to twelve in a six-wave build

`hud.gd:3137` hardcodes `"WAVE %d / 12"` while `demo.gd:33` sets `LAST_WAVE := 6`. `game.gd:2124` and `hud.gd:1117` both already do this correctly; the HUD does not, and not one of the seven `demo ·` checks reads the fight HUD.

**Files:**
- Modify: `skygear-godot/scripts/hud.gd:3137`
- Modify: `skygear-godot/tests/parity_test.gd`

- [ ] **Step 1: Write the failing check**

Add inside `func _demo_cut()` (`parity_test.gd:14691`), **after** the settings block ends at `:14787`, so it can reuse the `said` closure already defined at `:14737`. That closure clears `hud.ink`, awaits a frame and joins every drawn note; the objective string reaches it because `hud.gd:3138` draws through `_value` → `_say` → `_note`, which is what fills `hud.ink`.

```gdscript
	## THE OBJECTIVE PLATE is the one surface a demo player looks at for twelve
	## waves' worth of a six-wave game. `game.gd:2124` and the title strapline at
	## `hud.gd:1117` both ask `SkyGearDemo.last_wave()`; this one restated the
	## number, and not one of the seven demo checks reads the fight HUD.
	game.settings_open = false
	game.how_open = false
	game._set_state(game.State.PLAY)
	game.wave = 3
	SkyGearDemo._forced = 1
	var demo_hud: String = await said.call()
	SkyGearDemo._forced = 0
	var full_hud: String = await said.call()
	_check("demo", "the fight HUD counts to the demo's last wave",
		demo_hud.contains("WAVE 3 / 6") and full_hud.contains("WAVE 3 / 12"),
		"demo drew %s; full drew %s"
			% [str(demo_hud.contains("WAVE 3 / 6")), str(full_hud.contains("WAVE 3 / 12"))])
```

`_demo_cut()` restores `SkyGearDemo._forced` from `was` on every exit path (`:14695`) — leave that restoration intact, and add this check *before* it.

- [ ] **Step 2: Run the harness and watch it fail**

Expected: FAIL, `demo drew false; full drew true`.

- [ ] **Step 3: Make the change**

```gdscript
	var wave_text := "WAVE %d / %d" % [game.wave, SkyGearDemo.last_wave()]
```

- [ ] **Step 4: Run the harness and watch it pass**

The string is measured by `_fits(wave_text, wave_at.size.x, 16, 11)` at `:3139`. `WAVE 3 / 6` is one glyph *narrower* than today's `WAVE 3 / 12` in the demo and identical in the full build, so no layout can move.

- [ ] **Step 5: Commit**

```bash
git add skygear-godot/scripts/hud.gd skygear-godot/tests/parity_test.gd
git commit -m "SG-259: the demo's objective plate counted to twelve"
```

---

## Task 8: The Boiler's maximum accumulates across runs

`hud.gd:5058` teaches the Boiler's health as a literal `500` while `game.gd:2049` raises it with a Workshop talent. Reading the live value exposes a second, worse bug: **`boiler_max_hp` is never reset.** It is declared once at `game.gd:166` and `:2049` does `+=` on every `begin_run()`; `cards.gd:830` adds another 150 mid-run. **A second run in one session already starts with a compounded Boiler maximum.** Reset first, then read.

**Files:**
- Modify: `skygear-godot/scripts/game.gd:166,2049`
- Modify: `skygear-godot/scripts/hud.gd:5058`
- Modify: `skygear-godot/tests/parity_test.gd`

**Interfaces:**
- Produces: `SkyGearGame.BOILER_BASE_HP` — a `float` constant, `500.0`.

- [ ] **Step 1: Write the two failing checks**

```gdscript
	## THE BUG UNDER THE TYPO. `boiler_max_hp` was declared once and `+=`'d in
	## `begin_run` on every run, and a mid-run card adds another 150 — so a second
	## run in one process started with a Boiler maximum the player never bought.
	## Found by trying to print the live number on HOW TO PLAY.
	var boiler_game := _new_game()
	boiler_game.workshop.talents = {"boiler_hp": 150.0}
	boiler_game.begin_run()
	var first_max: float = boiler_game.boiler_max_hp
	boiler_game.begin_run()
	var second_max: float = boiler_game.boiler_max_hp
	_check("run", "a second run starts with the Boiler the player actually bought",
		is_equal_approx(first_max, second_max) and is_equal_approx(first_max, 650.0),
		"first run %.1f, second run %.1f (want 650.0 both)" % [first_max, second_max])
```

and, in the same pass, a check that the teaching page quotes the live number. `game.how_open = true` is what poses HOW TO PLAY (`game.gd:383`, and `screen_poser.gd:44` uses the same flag):

```gdscript
	## The player's half was read from the class table and the Boiler's half was a
	## literal, so the teaching page understated the Boiler by exactly what the
	## Workshop talent cost. A first-timer has no talents, so it is the RETURNING
	## player — the one who paid — who was misinformed.
	var how_hud: SkyGearHUD = boiler_game.hud
	var how_said := func() -> String:
		how_hud.ink = []
		how_hud.queue_redraw()
		await process_frame
		var all := ""
		for note in how_hud.ink:
			all += str((note as Dictionary).text) + "\n"
		return all
	boiler_game.how_open = true
	var how_page: String = await how_said.call()
	boiler_game.how_open = false
	_check("how", "the page quotes the Boiler's live maximum",
		how_page.contains("it has 650"),
		"drawn page says: %s" % how_page.substr(maxi(0, how_page.find("it has")), 24))
```

The closure is the same shape as the one at `parity_test.gd:14737`; it is redefined here because that one is local to `_demo_cut()`. `boiler_game` is the game built in the first check above, which already carries the 150-point talent.

- [ ] **Step 2: Run the harness and watch both fail**

Expected: `first run 650.0, second run 800.0` and `drawn page says it has 500`.

- [ ] **Step 3: Give the base a name and reset it**

In `scripts/game.gd`, replace `:166`:

```gdscript
## The Boiler's own health. BOILER_BASE_HP is a const because `begin_run` has to
## be able to return to it: the talent below is `+=`, and without a reset every
## run in a session compounded the last one's maximum (board SG-259).
const BOILER_BASE_HP := 500.0
var boiler_max_hp := BOILER_BASE_HP
```

and replace `:2049`:

```gdscript
	boiler_max_hp = BOILER_BASE_HP + float(talents.get("boiler_hp", 0.0))
```

`:2050`'s `boiler_hp = boiler_max_hp` is already correct and stays.

- [ ] **Step 4: Read the live value onto the page**

In `scripts/hud.gd:5058`, replace the trailing `500` in the format arguments with `int(game.boiler_max_hp)`:

```gdscript
		["", "The Boiler, not you. It sits at the stern and boarders walk to it. You have %d health and it has %d; dying costs you the run, but so does letting three lanes through while you are alive and well." % [int(kit.get("hp", SkyGearPlayer.MAX_HP)), int(game.boiler_max_hp)]],
```

- [ ] **Step 5: Run the harness and watch both pass**

The sentence wraps through `_says(..., 6, ...)` at `hud.gd:5144` against a column height measured at `:5098`, so a wider number can add a wrapped line. Confirm the full run is green, not just these two checks.

- [ ] **Step 6: Commit**

```bash
git add skygear-godot/scripts/game.gd skygear-godot/scripts/hud.gd skygear-godot/tests/parity_test.gd
git commit -m "SG-260: the Boiler's maximum compounded every run in a session"
```

---

## Task 9: "The captain fell" when the Boilerwright falls

`game.gd:4331` has no class branch, and THE CAPTAIN is literally the other class's proper name (`game_data.gd:246`). It is drawn under the 52pt verdict at `hud.gd:6370` and copied byte-for-byte into the clipboard report at `game.gd:2123`. The same family: `hud.gd:4502`'s draft footer tells a Boilerwright player a card AFFECTS THE CAPTAIN.

**Do not touch `cards.gd:59`'s `SCOPE_CAPTAIN: "CAPTAIN"`.** That is a *category* label sitting parallel to `SCOPE_SHIP: "THE BOILER"`; substituting a proper name would put THE BOILERWRIGHT next to THE BOILER in the same eight-word band. It is also a `const` baked at parse time and copied into each card instance at deal time (`game.gd:2710`), so it cannot hold a per-run lookup.

**Files:**
- Modify: `skygear-godot/scripts/game.gd:4331` and its quoting comment at `:2232`
- Modify: `skygear-godot/scripts/hud.gd:4502`
- Modify: `skygear-godot/tests/parity_test.gd`

- [ ] **Step 1: Write the failing check**

```gdscript
	## "The captain fell" is the other class's proper name. It is drawn under the
	## verdict AND copied into the clipboard, so a Boilerwright player's own report
	## named someone else.
	for who in ["captain", "boilerwright"]:
		var fell := _new_game()
		fell.set_class(who)
		fell.begin_run()
		fell.wave = 4
		## The defeat path is `damage_player` crossing zero (game.gd:4330-4334) —
		## it is what sets `end_reason` and pushes State.GAMEOVER. One overkill
		## blow rather than a loop, so nothing else in the run can intervene.
		fell.damage_player(fell.player.max_hp * 2.0, "harness", false)
		var mine: String = str(SkyGearData.CLASSES[who].name).to_lower().trim_prefix("the ")
		var theirs: String = str(SkyGearData.CLASSES[
			"boilerwright" if who == "captain" else "captain"].name).to_lower().trim_prefix("the ")
		_check("results", "the defeat line names the class that actually fell",
			fell.end_reason.to_lower().contains(mine)
				and not fell.end_reason.to_lower().contains(theirs),
			"%s died and the line read: %s" % [who, fell.end_reason])
		fell.queue_free()
```

`_new_game()` is `parity_test.gd:85` — it instantiates `main.tscn`, adds it to `root`, disables hit-stop and gives the game an ephemeral workshop so the harness never reads the developer's own save.

- [ ] **Step 2: Run the harness and watch it fail**

Expected: the `boilerwright` iteration FAILs — `boilerwright died and the line read: The captain fell on wave 4.`

- [ ] **Step 3: Make the defeat line class-aware**

```gdscript
			end_reason = "%s fell on wave %d." % [str(class_data().name).capitalize(), wave]
```

and update the comment at `:2232`, which quotes the old sentence verbatim inside `_set_state` — leaving it makes it a false record.

- [ ] **Step 4: Make the draft footer class-aware**

`hud.gd:4502` is the default arm of a `match` on the card's scope. Replace the literal:

```gdscript
			var label := "AFFECTS %s" % str(game.class_data().name)
```

- [ ] **Step 5: Run the harness and watch it pass**

`grep -rn "The captain fell" skygear-godot/` returns four hits and none is a test, so there is no existing fixture to migrate — but re-run the full harness to confirm the clipboard checks are unaffected.

- [ ] **Step 6: Commit**

```bash
git add skygear-godot/scripts/game.gd skygear-godot/scripts/hud.gd skygear-godot/tests/parity_test.gd
git commit -m "SG-261: the Boilerwright's own defeat report named the captain"
```

---

## Task 10: The playtest bypass leaves the shipped build

`hud.gd:6188`'s `if not demo:` guards OPEN ALL HEATS and its caption, which opens with the word *"Playtest:"*. The demo gate was the only thing hiding it — and testers now get the **full** build. Per the owner's decision it moves behind `dev_tools`, so he keeps it in the editor and no tester sees it.

**This task carries a trap that ships a red harness if missed.** `parity_test.gd:14778` — `demo · and SETTINGS drops the playtest bypass with its caption` — toggles `SkyGearDemo._forced` and asserts the **full** build *contains* "Playtest". Moving the gate makes the row draw regardless of `_forced`, and that check goes **permanently red**. It must be rewritten in the same commit. Separately, `OS.has_feature("editor")` is TRUE during a headless harness run, so the vocabulary walk must force `dev_tools = false` before "playtest" joins the banned list.

**Files:**
- Modify: `skygear-godot/scripts/hud.gd:6135-6146,6188`
- Modify: `skygear-godot/tests/parity_test.gd:14489-14491,14494,14778-14787`

**Interfaces:**
- Consumes: `game.dev_tools` (`game.gd:373`), the project's existing release predicate, already used for F3/F4.

- [ ] **Step 1: Rewrite the existing demo check to assert the new contract**

Replace `parity_test.gd:14778-14787` — the row is now absent from *both* exported builds, so the demo/full distinction it tested no longer exists:

```gdscript
	game.dev_tools = false
	var shipped_settings: String = await said.call()
	game.dev_tools = true
	var editor_settings: String = await said.call()
	game.dev_tools = false
	_check("settings", "the playtest bypass is absent from an exported build and present in the editor",
		not shipped_settings.contains("OPEN ALL HEATS")
			and not shipped_settings.contains("Playtest")
			and editor_settings.contains("OPEN ALL HEATS")
			and editor_settings.contains("Playtest")
			and shipped_settings.contains("FULLSCREEN"),
		"shipped says heats %s / playtest %s; editor says heats %s"
			% [str(shipped_settings.contains("OPEN ALL HEATS")),
				str(shipped_settings.contains("Playtest")),
				str(editor_settings.contains("OPEN ALL HEATS"))])
```

- [ ] **Step 2: Run the harness and watch it fail**

Expected: FAIL, `shipped says heats true / playtest true` — the row draws in both because the gate has not moved yet.

- [ ] **Step 3: Move the gate**

In `scripts/hud.gd`, replace the rationale comment at `:6129-6134` and the predicate at `:6135-6136`:

```gdscript
	## THE PLAYTEST BYPASS IS AN EDITOR TOOL NOW, NOT A DEMO EXEMPTION. OPEN ALL
	## HEATS is the owner's own switch (SG-160) and its caption opens with the word
	## "Playtest:" — a developer-facing string. The demo tag used to hide it, which
	## was enough while the demo was what strangers got. It is not: testers get the
	## FULL build (owner, 2026-08-12), so the gate is the release predicate the F3
	## and F4 tools already use, and the word can finally join S3's banned list.
	var demo: bool = SkyGearDemo.active()
	var bypass: bool = game.dev_tools and not demo
	var rows := 10 if bypass else 9
```

Replace `:6146`'s caption term to follow the same predicate:

```gdscript
	var tall: float = 150.0 + rows * 40.0 + 58.0 + 56.0 \
		+ (SETTINGS_CAPTION_H if bypass else 0.0)
```

and replace `:6188`'s `if not demo:` with `if bypass:`.

- [ ] **Step 4: Run the harness and watch it pass**

The sheet's height is computed from the row count at `:6145` — SG-161's footer collision lived on exactly these lines, so confirm the whole run is green, not just this check.

- [ ] **Step 5: Ban the word, and stop the walk from tripping over itself**

The vocabulary walk runs under the editor binary, so `dev_tools` is TRUE there and the row would draw during the walk. Force it false on the posed game first (the walk already sets `layout_edit`, so a second field is cheap), then delete the exemption comment at `:14489-14491` and add the word at `:14494`:

```gdscript
	var banned: Array[String] = ["interaction pass", "crate-verb", "playtest",
```

- [ ] **Step 6: Prove the ban non-vacuous**

Temporarily restore `if not demo:` at `hud.gd:6188`, re-run, confirm `text · no development vocabulary on a shipping surface` goes RED naming "playtest", then restore.

- [ ] **Step 7: Commit**

```bash
git add skygear-godot/scripts/hud.gd skygear-godot/tests/parity_test.gd
git commit -m "SG-262: 'Playtest:' shipped to every full build, and only the demo gate hid it"
```

---

## Task 11: Two harness fixtures measure strings that no longer exist

S3 replaced the Berths status text but `parity_test.gd:3574` and `:3581` still measure the old pair, so `berths · every slate's foot strip fits both its sentences at the ink floor` and `berths · and the tightest slate on the board still keeps room to spare` report headroom for text the screen does not draw. The live string is **6 characters shorter**, so the figures are not the screen's. Separately, `parity_test.gd:2713` asserts in a comment that four `editor ·` guards are byte-compares; they assert `diverted` and only *report* bytes (`:2687`).

**Files:**
- Modify: `skygear-godot/tests/parity_test.gd:3574,3581,2713`

- [ ] **Step 1: Point the fixtures at the live strings**

```bash
cd skygear-godot
sed -n '3572,3582p' tests/parity_test.gd
grep -n 'STOWED — not rigged for this voyage\|stowed below decks' scripts/hud.gd
```

Replace `"tabled with the crate-verb family — nothing is lost"` at `:3574` with `"stowed below decks — nothing you have earned is lost"` (`hud.gd:6023`), and `"TABLED — an interaction pass will revisit"` at `:3581` with `"STOWED — not rigged for this voyage"` (`hud.gd:5995`).

- [ ] **Step 2: Lower the engine-error pin to what the harness actually raises**

Task 1 measured **54** engine errors at `d1d0125`, while `ENGINE_ERROR_BUDGET := 56` (`parity_test.gd:429`) and every commit from `452578f` through `a1d7e3a` quote 56. The assertion at `:431` is `<=`, so the check passes green with the pin two above reality — and the constant's own comment is unambiguous about what to do: *"the count is PINNED: it may fall, it may not rise. The next agent who adds a 57th has to look at it, and whoever fixes SG-153 lowers this number and the check tightens itself."*

Set it to `54`. Then run the harness and confirm it is still green — if it goes red, the count is not stable at 54 and that instability is a finding worth more than the tightening; report it instead of widening the pin back.

**Do not investigate why it fell.** SG-153 stays open, and attributing the drop is its work, not this task's.

- [ ] **Step 3: Correct the false comment**

`:2713` reads `## THE SG-182 THREE, and they are the BYTE-COMPARE kind on purpose.` Replace it with what `:2687` actually does — assert `diverted`, report the byte delta as corroboration — so the harness stops ratifying a claim about itself that is not true. The board sentence repeating it is fixed in Task 5.

- [ ] **Step 4: Run the harness**

Expected: green at **54 engine errors against a pinned 54**, and the two `berths ·` checks now print headroom against the live text. **Record the new headroom figure** — if it is materially different from the old, that difference is the measure of how long the fixtures had been lying.

- [ ] **Step 5: Commit**

```bash
git add skygear-godot/tests/parity_test.gd
git commit -m "SG-263: two Berths fixtures measured text S3 deleted, a comment asserted a byte-compare that is not one, and the engine-error pin sat two above reality"
```

---

## Task 12: Fire — per-source rates, plumbed neutrally

Steps here are **behaviour-neutral by construction**: the table carries today's rate for every source, so nothing a player can feel moves. The balance change is Task 13, alone, in one data file, with its own revert.

`dps` means damage-per-**second** (`game.gd:4198` computes `TAP.dps * TAP_TICK`; the convention is stated at `:4178`). The shipped fire literal is `7.5` per tick at `FIRE_TICK := 0.25` — **30.0 per second**.

**The table carries `dps` and nothing else.** Radius stays `FIRE_RADIUS`. SG-163 settled that every pool burns at one radius and the picture follows the damage — pinned by `hazard · the burn radius did not move — the picture moved, not the damage`, whose comment quotes the owner. A per-source radius here, even one equal to 78 everywhere, re-opens a closed question.

**Files:**
- Modify: `skygear-godot/scripts/game_data.gd:338` and a new `FIRE_SOURCES` const
- Modify: `skygear-godot/scripts/game.gd:3336-3337,3418-3419,4000-4001,4644,4658,4667,5554-5568`
- Modify: `skygear-godot/tools/bot.gd:130,215`
- Modify: `skygear-godot/tests/parity_test.gd:5204` and new checks

**Interfaces:**
- Produces: `SkyGearData.FIRE_SOURCES` — `Dictionary` keyed by source name, each value `{"dps": float}` and optionally `{"per_stack": bool}`.
- Produces: `SkyGearGame.fire_pool_dps(source: String, stacks: float) -> float`.
- Produces: `SkyGearGame.PLAYER_FIRE_SHARE` — `float`, `0.4`.
- Produces: every `fire_fields` entry carries `dps: float`, stamped by `_field()`.

- [ ] **Step 1: Write the three failing checks**

```gdscript
	## Per source, so a lantern and a scald trail can differ. The rate is stamped by
	## `_field` the way the radius is (SG-163), so a caller cannot put a number in
	## the dictionary that the burn will ignore.
	var lantern_dps := game.fire_pool_dps("lantern", 1.0)
	var trail_dps := game.fire_pool_dps("scald_trail", 1.0)
	_check("hazard", "a pool burns at the rate its own source authored — a lantern and a scald trail are not the same fire",
		is_equal_approx(lantern_dps * SkyGearGame.FIRE_TICK, 7.5)
			and trail_dps > 0.0,
		"lantern %.2f/s = %.2f per tick; scald trail %.2f/s" % [lantern_dps, lantern_dps * SkyGearGame.FIRE_TICK, trail_dps])

	## TWO RESIDUE CREATORS, NOT ONE. `game.gd:3336` is the instant cast and
	## `game.gd:3418` is the channelled one inside `_finish_active_channel`; no
	## board row counts the second, so a grep-and-fix that stops at the first
	## `13.0 *` ships instant and channelled casts leaving different fires. The
	## structural half is the one that catches that, because it reads BOTH sites.
	var sim_src := FileAccess.get_file_as_string("res://scripts/game.gd")
	var rate_writers: Array[String] = []
	for raw in sim_src.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("\"dps\":") or line.contains("\"dps\": 13.0") \
				or line.contains("\"dps\": float(spec."):
			rate_writers.append(line)
	_check("hazard", "no pool creator writes its own rate — the table is the one place a fire's rate is decided",
		rate_writers.is_empty(),
		"%d call sites still author a rate: %s" % [rate_writers.size(), str(rate_writers)])

	var instant_field := _new_game()
	instant_field._field({"position": Vector2.ZERO, "source": "residue",
		"stacks": 2.0, "time": 2.0, "tick": 0.0})
	instant_field._field({"position": Vector2(400.0, 0.0), "source": "residue",
		"stacks": 2.0, "time": 2.0, "tick": 0.0})
	_check("hazard", "a channelled skill leaves the same pool an instant one does",
		is_equal_approx(float(instant_field.fire_fields[0].dps),
				float(instant_field.fire_fields[1].dps))
			and is_equal_approx(float(instant_field.fire_fields[0].radius),
				float(instant_field.fire_fields[1].radius)),
		"first %.2f/%.1f, second %.2f/%.1f"
			% [float(instant_field.fire_fields[0].dps), float(instant_field.fire_fields[0].radius),
				float(instant_field.fire_fields[1].dps), float(instant_field.fire_fields[1].radius)])
	instant_field.queue_free()
```

Then the measured-on-a-body check. **Lift the enemy placement and integration verbatim from the existing rate check at `parity_test.gd:16162-16178`** — it already stands a body in a pool, integrates 600 steps and reads an HP delta, and reusing its rig means this check and that one cannot disagree about method. Run it twice, once at `"stacks": 1.0` and once at `"stacks": 2.0`, capturing each HP delta:

```gdscript
	## MEASURED ON A BODY, NOT READ OFF THE TABLE. Asserting dps(2) == 2 * dps(1)
	## against `FIRE_SOURCES` compares the table with itself and proves the number
	## equals itself — `pool_shot.gd:17` names that as the fifth failure mode.
	_check("hazard", "RESIDUE's stacks are worth what they cost, measured on a body",
		stack1_damage > 0.0 and stack2_damage > 0.0
			and is_equal_approx(stack2_damage / stack1_damage, EXPECTED_STACK_RATIO),
		"stack 1 dealt %.1f, stack 2 dealt %.1f, ratio %.3f (want %.3f)"
			% [stack1_damage, stack2_damage, stack2_damage / stack1_damage, EXPECTED_STACK_RATIO])
```

For **this** task set `const EXPECTED_STACK_RATIO := 1.0` — the plumbing is neutral and stacks do not differ yet. Task 13 raises it to `2.0`, and that one-line change is what makes the balance commit visible in the harness.

- [ ] **Step 2: Run the harness and watch all three fail**

Expected: the first FAILs with `Invalid call ... fire_pool_dps`, and the run reports a script error. That is the correct red for a missing function.

- [ ] **Step 3: Author the table — `game_data.gd` only, no reader yet**

```gdscript
## FIRE, PER SOURCE — THE RATE ONLY, AND THE RADIUS IS DELIBERATELY NOT HERE.
## SG-163 settled that every pool burns at one radius and the picture follows the
## damage ("Fix the picture to match the damage" — the owner, pinned by
## `hazard · the burn radius did not move`). A per-source radius in this table,
## even one equal to 78 everywhere, re-opens a closed question.
##
## THE UNIT IS DAMAGE PER SECOND, as it is for `TAP.dps` — the steam main is
## "deliberately shaped exactly like `fire_fields`" and pays `dps * TAP_TICK`.
## The shipped fire literal was 7.5 per tick at a 0.25 s tick, which is 30.0 per
## second, so `lantern` carries today's rate EXACTLY and nothing ambient moves.
const FIRE_SOURCES := {
	"lantern": {"dps": 30.0},
	"scald_trail": {"dps": 30.0},
	"residue": {"dps": 30.0},
}
```

Delete the two dead keys from the jet spec at `:338` — `trail_radius` has been unread since SG-163 stamped the radius, and `trail_dps`'s rate is owned here now. Verify first:

```bash
cd skygear-godot && grep -rn 'trail_dps\|trail_radius' scripts/ tools/ tests/
```

Expected after the edit: only comments remain.

- [ ] **Step 4: Add the accessor and stamp the rate — `game.gd`**

Beside `fire_pool_radius()` at `:4644`, which is where SG-164's row says the rate belongs:

```gdscript
## The captain's share of a pool's rate. DERIVED, not chosen: the shipped pair
## was 7.5 to a boarder and 3.0 to her, and 3.0 / 7.5 is 0.4. Writing it as the
## ratio keeps that asymmetry true when a source's rate moves.
const PLAYER_FIRE_SHARE := 0.4


func fire_pool_dps(source: String, stacks: float) -> float:
	var row: Dictionary = SkyGearData.FIRE_SOURCES.get(
		source, SkyGearData.FIRE_SOURCES["lantern"])
	var base: float = float(row.dps)
	if bool(row.get("per_stack", false)):
		return base * maxf(1.0, stacks)
	return base
```

In `_field()` (`:5554`), beside the radius stamp at `:5567`:

```gdscript
	d["dps"] = fire_pool_dps(str(d.get("source", "lantern")), float(d.get("stacks", 1.0)))
```

**Do not change `fire_pool_radius()`'s arity.** It has seven zero-argument call sites — `game.gd:4658`, `:4659`, `:5730`, `:5731`, `view3d.gd:5420`, `parity_test.gd:7448`, `pool_shot.gd:139` — including a 2D `_draw` at `game.gd:5730-5731` that no board row names.

- [ ] **Step 5: Consume the stamped rate in the tick**

In `_update_fire_fields` (`:4648`), replace the two literals. Both stay **inside** the `while` loop at `:4653` — a per-tick value that is now a multiplication must not drift outside it, or a hitching frame silently changes the rate.

```gdscript
			_damage_circle(field.position, fire_pool_radius(), float(field.dps) * FIRE_TICK, "EMBER", 0.0, false, false)
```

```gdscript
				damage_player(float(field.dps) * FIRE_TICK * PLAYER_FIRE_SHARE, "fire", false)
```

Arithmetic check: `30.0 * 0.25 = 7.5` and `30.0 * 0.25 * 0.4 = 3.0` — exactly today's numbers, so `hazard · and a fire pool now deals its authored 12 dps, not a third of it` (`:16178`) and `hazard · and it deals it at any frame rate` (`:16216`) stay green untouched.

- [ ] **Step 6: Name the source at all four creators**

`game.gd:3336-3337` (instant RESIDUE):

```gdscript
		_field({"position": land, "source": "residue",
			"stacks": float(mods.residue), "time": 2.0, "tick": 0.0})
```

`game.gd:3418-3419` (channelled RESIDUE — **the one nobody counted**):

```gdscript
		_field({"position": Vector2(row.last_land), "source": "residue",
			"stacks": float(snap.residue), "time": 2.0, "tick": 0.0})
```

`game.gd:4000-4001` (the scald trail):

```gdscript
		_field({"position": at, "source": "scald_trail",
			"time": float(spec.trail_life), "tick": 0.0})
```

`game.gd:4567` (the broken lantern) already names nothing and now correctly gets the default.

- [ ] **Step 7: Stop the measurement rig keeping its own copy of the radius**

`tools/bot.gd:130` holds `const FIRE_RADIUS := 78.0`. It equals the game's today, so nothing is diverging yet — but it must be fixed **before** any measurement is recorded in Task 13, or the bot flees a pool by a remembered number. Replace `:215`'s `if reach < FIRE_RADIUS:` with `if reach < float(field.radius):` and delete the constant.

`parity_test.gd:16439` (`bot · and she walks out of a fire pool she is standing in`) is the only existing exercise of that line; separation is 40 units against a 78 radius, so it survives. Confirm it does.

- [ ] **Step 8: Make the crit table derive rather than restate**

`parity_test.gd:5204` pins `"authored": 7.5`. Replace with `SkyGearData.FIRE_SOURCES["lantern"].dps * SkyGearGame.FIRE_TICK`.

- [ ] **Step 9: Run the harness and watch everything pass**

Expected: green at `baseline + 3` checks or more, **54 engine errors**, exit 0. All three SG-163 radius checks (`parity_test.gd:7457`, `:7464`, `:7481`, `:7489`) untouched and green — if any of them moved, the radius was changed and it should not have been.

- [ ] **Step 10: Prove the new checks non-vacuous in BOTH directions**

This is the step that makes them gates:

1. **Drift the authored side** — change `FIRE_SOURCES.scald_trail.dps` to `99.0`, re-run, confirm the per-source check FAILs quoting 99. Restore; confirm `git diff scripts/game_data.gd` is empty.
2. **Drift the consumer side** — restore the literal `7.5` at `game.gd:4658`, re-run, confirm **the same check** FAILs quoting 7.5 against the authored rate. Restore.

A check that fails only on (1) reads the table against itself.

- [ ] **Step 11: Commit**

```bash
git add skygear-godot/scripts/game_data.gd skygear-godot/scripts/game.gd skygear-godot/tools/bot.gd skygear-godot/tests/parity_test.gd
git commit -m "SG-164: fire pools get a rate table, plumbed at today's numbers so nothing moves yet"
```

---

## Task 13: Fire — the balance change, one data file

Everything a player can feel is in this one diff, so it has its own revert. **`lantern` does not move**: it is the most common hazard in the game and changing an ambient rate in the same commit that differentiates the others would make a bad wave unattributable.

**Files:**
- Modify: `skygear-godot/scripts/game_data.gd` (`FIRE_SOURCES` only)
- Modify: `skygear-godot/tests/parity_test.gd` (`EXPECTED_STACK_RATIO`)
- Create: `skygear-godot/tools/fire_bench.gd`

**Interfaces:**
- Consumes: `SkyGearData.FIRE_SOURCES`, `SkyGearGame.fire_pool_dps` from Task 12.

- [ ] **Step 1: Build the measurement instrument first**

**Do not use `tools/balance.gd`.** `grep -n 'class_id\|set_class' tools/balance.gd tools/bot.gd` returns nothing — no balance run ever calls `set_class`, so the Boilerwright's scald trail **cannot occur in a balance run at any n**, and RESIDUE enters only by accident (`bot.gd:160` gives upgrade cards no ranking). A null result there would be true and meaningless.

Create `tools/fire_bench.gd`: for each source in `FIRE_SOURCES`, and for RESIDUE at one and two stacks, stand one enemy at a fixed offset inside one pool, integrate 10 s at 1/60, and print damage dealt per source per side. Deterministic — no bot, no seeds, no sampling error. Model it on the existing check at `parity_test.gd:16178`, which already integrates 600 steps and reads an HP delta.

- [ ] **Step 2: Record the before**

```bash
cd skygear-godot && "$HOME/.local/bin/godot.exe" --path . --headless --script res://tools/fire_bench.gd
```

Save the table. Every source should read 30.0/s to a boarder and 12.0/s to the captain — that is Task 12's neutrality, measured rather than asserted.

- [ ] **Step 3: Change the rates**

```gdscript
const FIRE_SOURCES := {
	"lantern": {"dps": 30.0},
	"scald_trail": {"dps": 18.0},
	"residue": {"dps": 30.0, "per_stack": true},
}
```

- **`lantern` 30.0, unchanged** — today's rate exactly.
- **`scald_trail` 18.0** — a retreat trail is worth less than a committed skill.
- **`residue` 30.0 per stack** — stack 1 is damage-neutral, so the first copy buys nothing it did not already; stack 2 doubles the rate, which is what an epic's second copy should feel like. RESIDUE currently buys *nothing at all*.

- [ ] **Step 4: Raise the expected stack ratio**

In `parity_test.gd`, `const EXPECTED_STACK_RATIO := 2.0`.

- [ ] **Step 5: Run the harness and watch the measured-on-a-body check move from 1.0 to 2.0**

Expected: green. If `hazard · and a fire pool now deals its authored 12 dps` moved, the lantern's rate was touched and it should not have been.

- [ ] **Step 6: Record the after**

Re-run `fire_bench.gd`. Expected: lantern unchanged, scald trail 18.0/s to a boarder and 7.2/s to the captain, RESIDUE 30.0/s at one stack and 60.0/s at two.

- [ ] **Step 7: Commit, with both tables in the body**

```bash
git add skygear-godot/scripts/game_data.gd skygear-godot/tests/parity_test.gd skygear-godot/tools/fire_bench.gd
git commit -m "SG-164: the balance half — a scald trail is not a lantern, and RESIDUE's second stack finally buys something"
```

The commit body carries the before and after tables and states plainly that `balance.gd` was **not** used, and why.

---

## Task 14: Assess SG-226 from the frames that already exist

The row says "windowed capture deferred by the owner's GPU park". That is false: `.shots/clips/sg226_after/` holds 80 frames and a 14 MB gif, captured 2026-08-11 15:22, **after** the fix. `grep -rn sg226_after skygear-godot/docs/` returns nothing — somebody paid the GPU cost and nobody looked. **No new capture. Do not start Godot for this.**

**Files:**
- Modify: `skygear-godot/docs/BOARD.md` (SG-226)

- [ ] **Step 1: Look at the frames**

```bash
ls "C:/Users/alexr/OneDrive/Documents/GitHub/skygear/skygear-godot/.shots/clips/sg226_after/"
```

Read a mid-swing frame and a landing frame.

- [ ] **Step 2: Answer the row's one open question in writing**

The generated fan is a **rim** (`view3d.gd:5291`, `filled = false`) where the retired plate was a solid crescent, so the row flags that the deck mark very likely reads **thinner**. Write a verdict: does it? The two candidates the row already names are the filled variant (`true`, as the cone uses) or SG-227's repaint.

- [ ] **Step 3: Record the verdict in the row, and commit**

```bash
git add skygear-godot/docs/BOARD.md
git commit -m "SG-226: the capture existed all along — assessed, not re-shot"
```

---

## Task 15: Mipmaps on the 3D-facing set — and the row's headline reason is wrong

SG-219 says anisotropy "is doing nothing at all" because the textures are unmipped. **The deck is not an imported PNG.** `view3d.gd:1208` binds `_planking_texture()`, `:3917` routes it through `_with_mips` → `generate_mipmaps()`, `:1215` sets `LINEAR_WITH_MIPMAPS_ANISOTROPIC` on that material, and `parity_test.gd:8804` already asserts it. Anisotropy does real work on the deck.

The real defect is one line away: **`view3d.gd:9899` requests `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` on every character billboard**, whose textures *are* the unmipped imports — a no-op request. `view3d.gd:3865-3869` already wrote the argument; the generated half landed and the imported half never did.

**Mipmaps only. Keep `compress/mode=0` (Lossless) everywhere. Do NOT set `compress/normal_map=1`** — it selects a VRAM format and is inert under Lossless. Compression is what moves the published pixel bands `still.gd` and `lit_probe.gd` measure against, and it is not being adopted; the VRAM argument that motivated it was struck.

**Files:**
- Modify: 59 `*.png.import` files (see partition)
- Modify: `skygear-godot/tests/parity_test.gd`
- Modify: `skygear-godot/docs/BOARD.md` (SG-219's reason)

- [ ] **Step 1: Establish the partition, by measurement**

```bash
cd skygear-godot
find assets -name "*.png.import" | wc -l                     # expect 124
grep -a -o 'res://assets/models/[A-Za-z0-9_/]*\.png' assets/models/*/*.res assets/models/*/*.tscn | sort -u
find assets/models -name '*_thumb.png' | wc -l               # expect 21, bound by nothing
```

**CHANGE (59 files):** the 12 model textures bound by a `.res` (`armored_{albedo,emission,metal,normal,rough}`, `boilerwright_{albedo,metal,normal,rough}`, `captain_albedo`, `crew_albedo`, `swarm_albedo`); `assets/art/props` (19); `assets/art/enemies` (13); `assets/art/allies` (3); `assets/art/heroes` (3 loaded); `assets/art/ground` (2 loaded: `shadow_blob`, `decal_scorch`); `assets/art/fx` (2 loaded: `puff_steam`, `bolt_tesla`); `assets/art/env` (5 loaded).

**DO NOT TOUCH:** `assets/art/ui/*` (26 — drawn in 2D); the 21 `*_thumb.png` (pipeline artifacts); `captain_metal/normal/rough` (on disk, unbound by `captain_mesh.res`); the dead `ground`/`fx` keys whose `_art` entries are retired; `heroes/boilerwright_front_attack.png` (referenced by nothing).

**AND EXCLUDE `assets/art/animations/*.png` (4).** They are sprite-sheet atlases drawn through `region_rect` (`sprites.gd:28-32`, `view3d.gd:9803-9805`), and mipmapping an atlas bleeds neighbouring frames at minified levels. Include them only if Step 5's before/after specifically inspects a running and an idling figure and finds no bleed — in which case the set is 63 and the board row says which shipped.

- [ ] **Step 2: Write the failing check**

A **superset scan that prints its count**, never `== 59`: the count went 121 → 124 in one working day, and a literal goes red the next time anyone adds an asset.

```gdscript
	## Every texture the 3D view samples must carry mipmaps, because
	## `view3d.gd:9899` asks for LINEAR_WITH_MIPMAPS on every character billboard
	## and that request is a no-op against a mip-less import. The generated half of
	## this landed at SG-108; the imported half never did.
	## THE MANIFEST IS AUTHORED, not scanned, because "every png under assets" is
	## the wrong set: 21 `*_thumb.png` are pipeline artifacts bound by nothing, the
	## whole of `art/ui` is drawn in 2D, and several `art/ground` and `art/fx` keys
	## are retired. What IS scanned is the directories, so a NEW texture arriving
	## unmipped fails for the right reason — see the sibling check below.
	const MIPPED_IN_3D: Array[String] = [
		"res://assets/models/armored/armored_albedo.png",
		"res://assets/models/armored/armored_emission.png",
		# ... the remaining 10 bound model textures, then every file in
		# art/props, art/enemies, art/allies, and the loaded members of
		# art/heroes, art/ground, art/fx, art/env, as enumerated in Step 1.
	]
	var unmipped: Array[String] = []
	for path in MIPPED_IN_3D:
		var cfg := ConfigFile.new()
		if cfg.load(path + ".import") != OK:
			unmipped.append(path + " (no .import)")
		elif not bool(cfg.get_value("params", "mipmaps/generate", false)):
			unmipped.append(path)
	_check("render", "every texture drawn in 3D carries the mipmaps its filter asks for",
		unmipped.is_empty(),
		"%d of %d still unmipped: %s" % [unmipped.size(), MIPPED_IN_3D.size(), str(unmipped)])

	## AND THE MANIFEST DOES NOT SILENTLY FALL BEHIND THE DIRECTORY. A new prop or
	## boarder texture arrives unmipped by default; without this, the check above
	## stays green because the manifest never heard of it. Prints the counts rather
	## than equality-testing them — this project watched the total go 121 -> 124 in
	## one working day, and a literal would have gone red for arithmetic.
	var uncovered: Array[String] = []
	for dir in ["res://assets/art/props", "res://assets/art/enemies",
			"res://assets/art/allies"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".png") and not MIPPED_IN_3D.has(dir + "/" + f):
				uncovered.append(dir + "/" + f)
	_check("render", "and the mipmap manifest still covers every billboard directory",
		uncovered.is_empty(),
		"%d textures in the 3D directories are not in the %d-entry manifest: %s"
			% [uncovered.size(), MIPPED_IN_3D.size(), str(uncovered)])
```

- [ ] **Step 3: Run the harness and watch the first fail**

Expected: `59 of 59 still unmipped: [...]`.

The sibling coverage check is green from the start by construction, so **it earns its red separately**: temporarily delete one `art/props` entry from `MIPPED_IN_3D`, re-run, confirm it FAILs naming exactly that file, then restore. Without that demonstration it is an assertion nobody has ever seen fail, which the Global Constraints forbid.

- [ ] **Step 4: Set the flag and re-import — EXCLUSIVE GODOT, NOTHING ELSE RUNNING**

Set `mipmaps/generate=true` in each of the 59 `.import` files. Leave `compress/mode=0`. Leave `compress/normal_map=0`.

```bash
cd skygear-godot && "$HOME/.local/bin/godot.exe" --path . --headless --import
```

**Nothing else may run during this.** A re-import is the most machine-dangerous operation in this plan.

- [ ] **Step 5: Capture the before/after at the shipped camera**

One serial pass. Confirm the bow reads sharper rather than softer, and — if the four atlases were included — that no running or idling figure shows frame bleed.

- [ ] **Step 6: Re-read the published bands**

Run `tests/lit_probe.gd` (windowed, **not** `--headless`) and confirm the deck and molten bands still sit inside their published ranges. They should: compression is what moves them and it was not adopted.

- [ ] **Step 7: Run the harness and watch it pass**

- [ ] **Step 8: Commit**

```bash
git add skygear-godot/assets skygear-godot/tests/parity_test.gd skygear-godot/docs/BOARD.md
git commit -m "SG-219: the billboards asked for mipmaps for months and the imports had none"
```

---

## Task 16: The legibility floor at 1600×900

The floor is enforced by `game.gd:558`'s `win.min_size`, a **windowed** constraint, and the game ships borderless fullscreen (`project.godot:44`). The named check is vacuous by arithmetic: `physical_pt(12, 1600)` = `12 × 1600/1920` = **10.0** against a floor of **10.0** — it passes by exactly zero, at one width. Per the owner's decision the build declares **1600×900** minimum.

**Files:**
- Modify: `skygear-godot/project.godot` ([display])
- Modify: `skygear-godot/scripts/ink.gd:59`
- Modify: `skygear-godot/scripts/game.gd` (near `:558`)
- Modify: `skygear-godot/tests/parity_test.gd:15157,15166`
- Modify: `skygear-godot/tools/legibility_probe.gd`

**Interfaces:**
- Produces: `SkyGearInk.MIN_SUPPORTED_W` — `int`, `1600`.

- [ ] **Step 1: Write the three failing checks**

```gdscript
	## PIN WHAT THE FLOOR WAS COMPUTED AGAINST. Godot rewrites project.godot on
	## editor open and can reorder or drop hand-added keys, so the key and its pin
	## land together or the key will not survive.
	_check("ink", "the floor is measured against the scaling the game actually ships",
		str(ProjectSettings.get_setting("display/window/stretch/mode")) == "canvas_items"
			and str(ProjectSettings.get_setting("display/window/stretch/aspect")) == "keep"
			and int(ProjectSettings.get_setting("display/window/size/mode")) == 3
			and int(ProjectSettings.get_setting("display/window/size/viewport_width")) == SkyGearInk.BASE_W,
		"mode %s / aspect %s / window mode %s / canvas %s"
			% [str(ProjectSettings.get_setting("display/window/stretch/mode")),
				str(ProjectSettings.get_setting("display/window/stretch/aspect")),
				str(ProjectSettings.get_setting("display/window/size/mode")),
				str(ProjectSettings.get_setting("display/window/size/viewport_width"))])

	## THE CATEGORY ERROR THIS REPLACES: MIN_WINDOW_W is a WINDOW constraint and
	## the game is fullscreen, so the binding quantity is the narrowest DISPLAY the
	## build claims to support.
	_check("ink", "the point-size floor clears the physical floor on the narrowest supported display",
		SkyGearInk.physical_pt(SkyGearInk.MIN_PT, SkyGearInk.MIN_SUPPORTED_W) >= SkyGearInk.MIN_PHYS_PX,
		"%.2f physical px at %d wide against a floor of %.1f"
			% [SkyGearInk.physical_pt(SkyGearInk.MIN_PT, SkyGearInk.MIN_SUPPORTED_W),
				SkyGearInk.MIN_SUPPORTED_W, SkyGearInk.MIN_PHYS_PX])

	## AND THE PROOF IT WOULD GO RED, which is the thing nobody can say about the
	## check this replaces. Use MIN_PT - 1 rather than a width step: a hand-picked
	## `- 64` is arithmetically broken under other choices of the constant.
	_check("ink", "and that floor is tight rather than slack",
		SkyGearInk.physical_pt(SkyGearInk.MIN_PT - 1, SkyGearInk.MIN_SUPPORTED_W) < SkyGearInk.MIN_PHYS_PX,
		"one point smaller gives %.2f px, which must be under %.1f"
			% [SkyGearInk.physical_pt(SkyGearInk.MIN_PT - 1, SkyGearInk.MIN_SUPPORTED_W),
				SkyGearInk.MIN_PHYS_PX])
```

Fold the existing `ink · the downscale base matches the project's design canvas` (`:15166`) into the first check rather than leaving a near-duplicate, and **delete** the vacuous `:15157`.

- [ ] **Step 2: Run the harness and watch the first and second fail**

Expected: `aspect <null>` and `Invalid ... MIN_SUPPORTED_W`.

- [ ] **Step 3: Add the settings and the constant**

In `project.godot`'s `[display]` section: `window/stretch/aspect="keep"`. This is a **drift guard**, not a distortion fix — the ultrawide-distortion half of SG-215 was struck; Godot already defaults to keep-aspect and `text_audit.gd:95-96` describes the shipped behaviour as a letterbox. Pinning it stops the default moving under us.

In `scripts/ink.gd`, beside `MIN_WINDOW_W` at `:59`:

```gdscript
## THE NARROWEST DISPLAY THIS BUILD CLAIMS TO SUPPORT. `MIN_WINDOW_W` above is a
## WINDOW constraint and `min_size` cannot reach a borderless-fullscreen window,
## so it never governed the shipped path — this does. 1600 is not chosen, it is
## the break-even: 12 pt across a 1920 canvas on a 1600-wide display is exactly
## MIN_PHYS_PX. A narrower display needs a bigger MIN_PT, which re-measures every
## string in the game (owner, 2026-08-12: declare 1600).
const MIN_SUPPORTED_W := 1600
```

- [ ] **Step 4: Run the harness and watch all three pass**

- [ ] **Step 5: Tell the player when their display is below it**

Beside the `min_size` line at `game.gd:558`:

```gdscript
	## min_size governs a WINDOW and this game opens borderless fullscreen, so on a
	## 1366-wide laptop 12 pt lands at 8.5 physical px against a floor of 10.0 and
	## nothing stops it. Say so rather than shipping type nobody can read.
	var screen_w: int = DisplayServer.screen_get_size().x
	if screen_w < SkyGearInk.MIN_SUPPORTED_W:
		push_warning("SkyGear supports %d wide and up; this display is %d — text will be below the legibility floor."
			% [SkyGearInk.MIN_SUPPORTED_W, screen_w])
```

- [ ] **Step 6: Close the coverage hole**

Every UI tool disables the shipped scaling — ten sites, all correct for measurement. The hole is a **missing mode**, not ten wrong lines. Add `--shipped` to `tools/legibility_probe.gd` leaving content scale ON and posing fullscreen at the declared width.

**Add a separate constant for its widths. Do not touch `poser.SIZES`** — `parity_test.gd:14186` asserts it equal to the screens tool's copy, so editing it breaks the tool-parity check first.

- [ ] **Step 7: Run the probe in its new mode**

```bash
cd skygear-godot && "$HOME/.local/bin/godot.exe" --path . --resolution 1600x900 --script res://tools/legibility_probe.gd -- --shipped
```

Record the physical-pixel report — the first time the shipped path has been measured.

- [ ] **Step 8: Commit**

```bash
git add skygear-godot/project.godot skygear-godot/scripts/ink.gd skygear-godot/scripts/game.gd skygear-godot/tests/parity_test.gd skygear-godot/tools/legibility_probe.gd
git commit -m "SG-215: the legibility floor was measured in a window the game never opens"
```

---

## Task 17: The capture session — one serial pass at HEAD

Three things shipped in build 71 without anyone looking. **Every existing capture set is stale**: `polish-audit` (16:06) predates the font commit (18:45); `aaa` (23:00) predates SG-254 and SG-255. Nothing on disk was shot at HEAD.

**One Godot process at a time, and never beside a ComfyUI or `imageforge` render.**

**Files:**
- Modify: `skygear-godot/tests/parity_test.gd` (font identity gate)
- Modify: `skygear-godot/docs/BOARD.md` (SG-242, SG-243, SG-244)

- [ ] **Step 1: Add a font identity gate that can actually fail**

`text_audit` exits on violation **count** and its classes are OVERFLOW / OUTSIDE / SMALL / FAINT — **none of them font identity**. `hud.gd:2791-2797`'s `_load_face` silently returns `ThemeDB.fallback_font` on a missing path with only a `push_warning`, so every string falling back would still exit 0.

```gdscript
	## SG-243 shipped two faces and the only gate was a text audit that cannot see
	## which font drew anything. A missing .ttf falls back silently by design — good
	## for the player, useless as evidence.
	_check("ink", "the shipped faces are the faces, not the engine's fallback",
		ResourceLoader.exists(SkyGearHUD.DISPLAY_FACE)
			and ResourceLoader.exists(SkyGearHUD.BODY_FACE)
			and hud.font != ThemeDB.fallback_font
			and hud.display != ThemeDB.fallback_font,
		"display %s / body %s on disk; live faces fallback: %s / %s"
			% [str(ResourceLoader.exists(SkyGearHUD.DISPLAY_FACE)),
				str(ResourceLoader.exists(SkyGearHUD.BODY_FACE)),
				str(hud.display == ThemeDB.fallback_font),
				str(hud.font == ThemeDB.fallback_font)])
```

Prove it non-vacuous by temporarily pointing `DISPLAY_FACE` at a path that does not exist.

- [ ] **Step 2: Shoot the full matrix at HEAD**

```bash
cd "C:/Users/alexr/OneDrive/Documents/GitHub/skygear"
"./SkyGear Tools.bat" screens --tag build72
```

25 screens × 4 widths. This is the first set that contains the fonts, the ink pass **and** the SG-248…SG-255 menu work together.

- [ ] **Step 3: Shoot the ink pass on and off**

`_arm_deck_post` (`view3d.gd:1508`) refuses only when the display is headless (`:1509`) — **the exact negation of `SkyGearRendererCheck.can_capture()`** — so every tool that can photograph the deck photographs it **with** ink, including the windowed `still_probe` and `lit_probe` whose published bands SG-244 claims to protect. And `view3d.gd:1539 set_deck_post(false)` has **no caller anywhere**; NEEDS_ALEX offers it as the off switch and it is unreachable.

Give it a temporary caller, or edit `_arm_deck_post` to bail, and shoot the five deck-bearing poses (`screen_poser.gd:68,72,78,83,94`) both ways. Revert the temporary edit before committing.

- [ ] **Step 4: Confirm which film is in the tree**

```bash
cd "C:/Users/alexr/OneDrive/Documents/GitHub/skygear"
git rev-parse eb63995:skygear-godot/assets/video/opening.ogv
git rev-parse HEAD:skygear-godot/assets/video/opening.ogv
```

Expected: `58fc733…` (33,315,163 B) versus `cc27ac8…` (31,356,599 B). **The film the owner would watch is not the one build 71 shipped.** Run `tools/film_smoke.gd` to confirm the current blob plays and advances.

- [ ] **Step 5: Write the verdicts into the three rows, and commit**

Each row's remaining gate is the owner's eyes against a build-72 exe, so record what is now *photographed* and what still needs him.

```bash
git add skygear-godot/tests/parity_test.gd skygear-godot/docs/BOARD.md
git commit -m "SG-242/243/244: photographed at HEAD at last, and a font gate that can go red"
```

---

## Task 18: Ship build 72

**Nothing here may run beside anything else.**

**Files:**
- Modify: `skygear-godot/docs/BOARD.md`, `NEEDS_ALEX.md`

- [ ] **Step 1: The stricter gate, on a clean tree**

```bash
cd "C:/Users/alexr/OneDrive/Documents/GitHub/skygear"
git status --short          # must be empty
"./SkyGear Tools.bat" all
```

Required: exit 0, **0 script errors**, **54 engine errors against the pin Task 11 lowered to 54**, zero failures. `hub.gd:314-317` counts a GDScript script error as a failure even at exit 0, which the bare harness does not.

- [ ] **Step 2: Export both, off one commit and one harness run**

```bash
cd skygear-godot
python tools/pack_itch.py
python tools/pack_itch.py --demo
```

If the export fails with *"Prepare Template: The given export path doesn't exist"*, that is **not** a template problem — Godot will not create the output directory (`pack_itch.py:16-18`).

- [ ] **Step 3: Read the identity back off both binaries**

```powershell
(Get-Item skygear-godot/builds/windows/SkyGear-Godot.exe).VersionInfo | Format-List ProductName,FileVersion
(Get-Item skygear-godot/builds/windows-demo/SkyGear-Demo.exe).VersionInfo | Format-List ProductName,FileVersion
```

Required: `SkyGear` / `0.72.0.0` and `SkyGear Demo` / `0.72.0.0`. **This is how the feature tag is proved applied rather than assumed** — it is the method build 71 used.

- [ ] **Step 4: Launch the demo exe and photograph its title screen**

Build 71 did this and it is what caught the demo cut being real. Confirm the strapline says **six** waves, there is no class picker, and it survives a 20-second run.

- [ ] **Step 5: Push both channels**

```bash
cd skygear-godot
butler push builds/itch/SkyGear-Windows.zip alex-unconstrained/skygear-godot-test:windows --userversion 72-polish-pass
butler push builds/itch/SkyGear-Demo-Windows.zip alex-unconstrained/skygear-godot-test:windows-demo --userversion 72-polish-pass
```

Both channels ship. Leaving `windows-demo` stale at 71 puts a build-71 demo zip beside a build-72 full zip on one page, and the smaller-sounding file is the one strangers click.

- [ ] **Step 6: Record it, with the rollback number**

File a new SHIPPING row carrying: the commit hash, both butler build numbers, the harness total, and **the rollback build number** — a number written down by hand is the only rollback mechanism this project has. Rewrite NEEDS_ALEX's headline to build 72 and list what needs his eyes: the fonts, the ink pass, the film, cleave G5(b) and G5(c), and the two §4 questions from the spec (the Boilerwright's portrait, and what a pre-first-win tester is told).

- [ ] **Step 7: Commit**

```bash
git add skygear-godot/docs/BOARD.md NEEDS_ALEX.md
git commit -m "SG-264: build 72 is live on itch — the polish pass, both channels, one commit"
```

---

## Execution order

```
Task 1 (baseline)
  ├─ Tasks 2, 3, 4, 5  ......... Tier 1, parallel, no Godot
  ├─ Tasks 6 → 7 → 8 → 9 → 10 → 11  ... Tier 2, STRICTLY SERIAL (hud.gd + parity_test.gd)
  └─ Task 14 ................... docs only, any time
Then, one at a time, exclusive Godot:
     Task 12 → Task 13 ......... fire: plumbing, then balance
     Task 15 ................... mipmaps (re-import — the most dangerous step)
     Task 16 ................... legibility
     Task 17 ................... captures
Finally:
     Task 18 ................... ship
```

Tasks 2–5 may run beside Tier 2 only if no two agents write `tests/parity_test.gd` at once. In practice: give `parity_test.gd` one owner for the whole pass.

---

## Deferred, and named so the omission reads as a choice

Out of scope: SG-95, SG-73, SG-227, SG-171, SG-153, SG-189, SG-151, SG-152, SG-175, SG-124, SG-125, SG-127, SG-132, SG-154, SG-24, SG-20, SG-239, and the dead `starting` keys on each class.

Needs the owner's go, not scheduled here: **SG-105** — the Boilerwright wears the Captain's portrait and SG-228 made that unmistakably one specific young man; `imageforge.py` can fix it without the Loom but it costs money. And **the pre-first-win results line** — a tester who dies before their first twelve-wave victory sees a results sheet with every progression line skipped, which is strictly less closure than the demo cut gives. Both are in the spec's §4.
