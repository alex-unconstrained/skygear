# DEMO-READINESS AUDIT — 2026-08-11

**What this is.** A read-only sweep of the gap between *feature-complete and
playable* and *commercial-quality, Steam-demo-ready on Windows*. Seven auditors
took one quality dimension each — first-run flow, combat readability, HUD,
persistence, stability/performance, audio and authored identity, and the
shipping surface. Every finding was then handed to an adversarial verifier
instructed to refute it by default and to open each cited `file:line` itself.
**45 findings survived; 6 were refuted.** Synthesis deduplicated the survivors
to 29 slices.

**HOW TO READ IT — the two limits, stated up front.**

1. **No Godot was run.** The audit was deliberately forbidden from executing the
   engine, because a builder held the write side and concurrent `godot --path .`
   invocations thrash the shared `.godot` import cache. Everything here is read
   off source, authored data, existing logs and documents. **Section 5 lists every
   claim that therefore CANNOT be asserted until it is measured against a running
   build.** Nothing in Section 5 may enter a packet's justification until it has
   been. Several claims in the ranked table depend on Section 5 items; where they
   do, the slice says so.
2. **Nothing here has been seen or heard.** Any word like "feel", "reads as",
   "cheap" or "unfinished" is inference from constants and authored data, not
   observation. The G5-class items at the end of Section 5 are the owner's to
   judge and no agent may substitute for that.

**Provenance.** Generated 2026-08-11 by a 15-agent read-only workflow
(7 auditors + 7 refuters + 1 synthesis). The refuters struck nine specific
claims outright; Section 6 records what was struck and why, which is as much a
part of the result as what survived. Line numbers in `game.gd` were taken
against two different snapshots while SG-208 was in flight — **dispatch by symbol
name, never by `game.gd` line number** (Section 0-B).

**Board IDs.** The slices are labelled `DR-nn` in this document. They are filed
on the board as the block **SG-209 … SG-237**; the mapping is in the board rows
themselves. Per board rule 1, that block was issued by the dispatching
coordinator — no agent may self-number from it.

**One correction to Section 0-C, recorded by the coordinator.** The audit could
not verify, from an uncommitted working-tree edit alone, that the owner had
passed AB-02/AB-03 — and was right to refuse. The verdict is genuine: Alex gave
it directly on 2026-08-11 (*"I approve of field and pulse changes. Those are
unblocked now."*). The audit's inability to see it is a real finding about the
record, not about the verdict: **a human gate recorded only in an uncommitted
working tree is not yet an audit trail.** Board rule 5 says `git log` on the
board is the trail; until that edit is committed, it is not.

---

# SkyGear — Coordinator's Demo-Readiness Backlog

Synthesis of 40 verifier-survived findings across seven read-only sweeps. Deduplicated to 29 slices. Read §0 before dispatching anything.

---

## §0 — Facts that change how you dispatch, today

**A. Four of the five serialized files are dirty in the working tree RIGHT NOW.**
`git status --porcelain` at synthesis time returns ` M scripts/game.gd`, ` M scripts/game_data.gd`, ` M scripts/view3d.gd`, ` M tests/parity_test.gd`, ` M docs/BOARD.md`, ` M NEEDS_ALEX.md` — `git diff --stat` shows +749/−29, with 496 added lines in `tests/parity_test.gd`. That is SG-208 (AB-04 Cleave) in flight. **Of the five serialized files, only `scripts/hud.gd` and `scripts/enemy.gd` are free.** Every slice below that names `game.gd`, `view3d.gd`, `game_data.gd` or `tests/parity_test.gd` must queue behind SG-208 landing or safe-stopping. That is the single largest constraint on this backlog — most of Tier 0/1 is blocked on it.

**B. `game.gd` line numbers in the findings below are against two different snapshots.** Verified: `SKYGEAR — Godot port` is `game.gd:2032` at HEAD and `game.gd:2047` in the working tree; `damage_enemy` is `:3430` at HEAD and `:3541` live; `play_sfx` is `:5140` at HEAD and `:5258` live. Both cite sets were correct when taken. **Dispatch by symbol name, never by `game.gd` line number.** `hud.gd`, `project.godot` and `export_presets.cfg` cites are stable — I re-read them at synthesis time and they match verbatim.

**C. SG-206 (Field) and SG-207 (Pulse) — the owner's G5 boundary. NO AGENT MAY RESOLVE THIS, INCLUDING ON THE EVIDENCE BELOW.**
The audit brief states both packets await the owner's hands-on G5 judgment. The **uncommitted working tree contradicts that**: `docs/BOARD.md` (modified, uncommitted) now carries `| SG-207 | **HUMAN-VERIFIED / DONE 2026-08-11 (Alex + opus/coordinator)** …` and `NEEDS_ALEX.md` (modified, uncommitted) opens `**Build 69 live · Field and Pulse PASSED your G5 on 2026-08-11 · harness 1187/1187.**` Both edits are the work of a concurrently-running agent and are not in any commit (`git log -- NEEDS_ALEX.md` ends at `fd0c7c5`, 2026-08-05, "Publish SG-207 Pulse candidate for G5").
**I cannot verify from a working-tree edit that the owner said those words.** From my position the boundary stands. Confirm the verdict with Alex directly before treating AB-02/AB-03 as unblocked, and before letting AB-04/IN-00 sequencing rest on it. Do not let any agent — including whichever one wrote those lines — close this loop for him.

**D. No expansion-design packet owns any work in this backlog.** I read §14's full packet map (`GAMEPLAY-EXPANSION-DESIGN-2026-08-04.md:734-777`). Every outcome column is gameplay depth — Muster, elites, ability verbs, elements, Reforge, hardpoints, Watches, heroes. Nothing there names branding, export configuration, audio wiring, dev-key gating, save durability or the shipping surface. Existing **BOARD** rows own five items and I use those IDs: **SG-183** (settings.cfg per-frame write), **SG-105** (Boilerwright portrait, BLOCKED on the Loom), **SG-161** (settings sheet footer/BACK overrun — a hard dependency for DR-10), **SG-192** (docs claiming coverage without naming a check), **SG-93** (menu vocabulary spread — owner-gated, collides with DR-09). Everything else is new. I use `DR-nn` placeholders; **board rule 1 says the next free SG id is a guess** — issue a block, don't let agents self-number.

**E. `tests/parity_test.gd` is an exclusive lock, not append-only.** The project treats it that way in writing: SG-152's status reads "`tests/parity_test.gd` is held by another agent". Nearly every slice below needs it for its proof-of-fix. That makes the harness the throughput bottleneck for this entire backlog, and it is currently held by SG-208.

---

## §1 — Ranked backlog

Ranked by what a store-page viewer or demo player hits **first**, not by size or interest.

| # | Slice | Hits the player at | Sev | Serialized files | Gate |
|---|---|---|---|---|---|
| 1 | **DR-01a** Exe identity: icon, name, version, company | before launch (store tile, taskbar, Properties) | blocking | **none** | needs an icon asset |
| 2 | **DR-01b** Title/report strings stop saying "GODOT PORT / Milestone 1" | frame 1 | blocking | hud.gd, game.gd, harness | — |
| 3 | **DR-02** Menus and title are dead silent; `card_hover.ogg` does not exist | second 1 | blocking | game.gd, hud.gd, harness | — |
| 4 | **DR-03** There is no demo build — one preset ships 100% of the game | at upload | blocking | game.gd, hud.gd, harness | **OWNER: scope** |
| 5 | **DR-04** F3/F4 dev tools ungated, and the pause menu tells the player to press F4 | minute 2 | blocking | game.gd, hud.gd, harness | — |
| 6 | **DR-05** Fullscreen defeats the physical legibility floor on any display under 1600px | frame 1, on affected hardware | damaging | game.gd, harness | — |
| 7 | **DR-17** Every string is `ThemeDB.fallback_font` on hand-authored brass | frame 1 | damaging | hud.gd, harness | **OWNER: font choice/licence** |
| 8 | **DR-06** Connecting hits, crits and elements are silent; 17 delivered takes unreachable | first swing | damaging | game.gd, harness | — |
| 9 | **DR-07** No boarder reacts to being hit; the flash and the status tint are both no-ops | first swing | damaging | view3d.gd, enemy.gd, harness | contradicts SG-85 in part |
| 10 | **DR-08** One unconfirmed mouse-down on RESTART/QUIT destroys the run | mid-run, once | damaging | hud.gd, harness | — |
| 11 | **DR-09** Controls screen: hardcoded key labels, PAUSE unbindable, two rows numbered "1", no KBM notice | on opening CONTROLS | damaging | hud.gd, game.gd, harness | partial **SG-93** gate |
| 12 | **DR-10** No cost-reducing graphics option exists anywhere | when the machine struggles | damaging | hud.gd, harness | blocked by **SG-161** |
| 13 | **DR-11** All 121 textures Lossless + no mipmaps → anisotropic filtering does nothing | continuously, as shimmer | damaging | **none** | — |
| 14 | **DR-12** Results damage table is space-padded for monospace, drawn proportional | end of every run | polish | hud.gd, game.gd, harness | — |
| 15 | **DR-13** After the first victory the title's last line draws at y=1096 on a 1080 canvas | after their best moment | polish | hud.gd, harness | — |
| 16 | **DR-14** A truncated `workshop.json` silently wipes every unlock; the next run makes it permanent | rare, unrecoverable | damaging | harness only | — |
| 17 | **DR-15** First rig of each kind loads inside a live frame; warmup warms everything except figures | wave 12 Colossus shot | damaging | harness only | **MEASURE FIRST** |
| 18 | **DR-16** Alt-tab does not pause a borderless-fullscreen run | whenever Discord pings | polish | game.gd, harness | — |
| 19 | **DR-18** The Boilerwright speaks in the Captain's voice for a whole run | half the replay pitch | damaging | hud.gd, harness | **OWNER: wrong voice vs no voice** |
| 20 | **DR-19** The full test suite, bot and probes are packed inside the 234 MB exe | at download | polish | **none** | — |
| 21 | **DR-20** The itch README links the free browser build and calls it "the original" | itch only, not Steam | polish | **none** | — |
| 22 | **DR-21** Nothing in the ship gate measures frame time — `bench.gd` is unreachable from the hub | never, until it is too late | polish | **none** | machine-dependent budget |
| 23 | **DR-22** `balance.gd` writes fixtures into the real `runs.json`; `profile_fight.gd` can bank into the real `workshop.json` — and the guarantee in NEEDS_ALEX overstates the coverage | owner/tester only | polish | tools half is **free** | — |
| 24 | **SG-183** Settings/pause sheets write `settings.cfg` every frame | not observably | polish | hud.gd, harness | existing row |
| 25 | **DR-23** `_advance` truncates: `0.3 s` runs 0.25 s (16.7% short) | never — instrument hazard | polish | harness only | — |
| 26 | **DR-24** The Captain's dash grants i-frames and nothing ever says so | HOW TO PLAY, optional | polish | hud.gd, game_data.gd, harness | — |
| 27 | **DR-25** Results screen: Down moves focus sideways, Left/Right do nothing | keyboard players only | polish | hud.gd, ui.gd, harness | — |
| 28 | **DR-26** Floater size encodes crit, not magnitude | wave 11 readability | polish | game.gd, hud.gd, harness | **OWNER: taste** |
| 29 | **DR-27** No basic attack reaches the hit-stop threshold in the default case | combat rhythm | polish | harness only | **contradicts a recorded decision** |
| 30 | **DR-28** The death screen cannot name what killed you | end of a losing run | polish | game.gd, harness | — |
| 31 | **DR-29** The telegraph reserve silently drops windups, and its comment says it cannot | wave 11, unquantified | polish | view3d.gd, harness | **MEASURE FIRST** |
| 32 | **SG-192** STATUS.md's five-guard and md5-manifest claims overstate what the checks assert | — | polish | harness, STATUS.md | fold into existing row |

---

## §2 — The slices

Each slice: what it merges, allowed files, the lock it takes, and its baseline / success / kill / rollback.

### DR-01a — Executable identity *(no serialized files — dispatch immediately)*
Merges four findings filed independently under first-run-flow, hud-ui, audio-identity and shipping-surface.
**Evidence** `export_presets.cfg:24` `application/icon=""`, `:27-28` both versions `"0.1.0.0"`, `:29` `company_name=""`, `:30` `product_name="SkyGear Godot Port"`, `:31` `file_description="SkyGear v11 Godot port - Milestone 1"`, `:32` `copyright=""`, with `:23 application/modify_resources=true` stamping all of it into the exe. `project.godot:7 config/name="SkyGear: Godot Port"` — nothing calls `window_set_title`, so that *is* the taskbar and alt-tab string. `grep -n icon project.godot` returns nothing; there is no `config/icon` and no `boot_splash` key, so the window, the taskbar and the launch splash all carry the stock Godot logo. **No board row, no doc and no harness check names any of this** — `docs/STEAM-LAUNCH.md` §4.3's icon rows are the Steamworks community/client icons, not the executable.
**Files** `export_presets.cfg`, `project.godot`, one new `assets/art/ui/icon.png` (256×256).
**Lock** none. **Baseline** today's Properties → Details tab. **Success** exported exe shows a non-Godot taskbar icon, product name free of "Godot", non-placeholder version, non-empty company and copyright. **Kill** none — this is configuration. **Rollback** revert two config files.
**Gate** the icon is an art asset. Alex's workflow is prompt → image → 3D and specs are ratios plus descriptive prompts, never dimensions; the Loom is not running on this machine (**SG-105**). Either the owner supplies it or this slice ships everything except `application/icon`/`config/icon` and a follow-up lands the file.

### DR-01b — The shipping surface stops calling itself a port *(hud.gd + game.gd + harness)*
**Evidence** `scripts/hud.gd:503` `_center_text("STORM-DUSK · GODOT PORT", 205.0, 24, Color("#37f0c8"))` — the second line under the banner, four lines into `_draw_title`. `scripts/hud.gd:682` `_center_text("Milestone 1 · v11 combat vertical slice", y + 14.0, 15,` — the last string the function draws. `run_report()`'s first line, `lines.append("SKYGEAR — Godot port")` (`game.gd:2047` live / `:2032` at HEAD) — the text the COPY REPORT button puts on a tester's clipboard.
**Files** `scripts/hud.gd`, `scripts/game.gd`, `tests/parity_test.gd`.
**Baseline** those three literals. **Success** a named check — the finding proposes `title · nothing on the shipping surface names the port or the milestone` — greps the posed title screen's drawn-string set and `run_report()` for `port|Milestone|vertical slice` and returns zero. **Kill** none. **Rollback** three string reverts.
**Pair with** a new `shipping ·` check domain that parses `export_presets.cfg` and `project.godot` as text — the layer the player meets first is currently pinned by nothing, which is *why* DR-01a/b could exist behind a green 1187. (Narrow the claim: `render ·` and `capture ·` do touch rendering; nothing touches the export preset or display config.)

### DR-02 — The first ten seconds have sound *(game.gd + hud.gd + audio.gd + harness)*
Merges "everything outside a live wave is dead silent" with the dead `card_hover.ogg` path.
**Evidence** `audio.play_music(...)` has exactly one call site and it is inside `start_wave` (`game.gd:2389` live); `audio.stop_music()` has exactly one, inside `go_to_title` (`:2136`). The game boots into `State.TITLE`, which no music call has ever reached — so title, Workshop, Berths, HOW TO PLAY, COMPARE and SETTINGS play nothing but `ui/click.ogg`. Confirmed at synthesis: `assets/audio/sfx/world/` contains `amb_ship.ogg` and `amb_storm.ogg`, both imported, both with zero references anywhere. And `scripts/hud.gd:36` requests `"ui/card_hover.ogg"`, which **does not exist** — the directory holds `card_deal, card_pick, click, hover, slot_unlock`. `play_sfx` swallows the miss silently (`if not ResourceLoader.exists(full_path): return`), so every menu hover in the game has been mute for the entire port with nothing able to see it.
**Files** `scripts/audio.gd`, `scripts/game.gd` (one call in `_set_state`), `scripts/hud.gd` (one string), `tests/parity_test.gd`.
**Baseline** silence on TITLE; `hover.ogg` unreferenced. **Success** `audio · the menus are not silent` (`audio.current != ""` in TITLE), `audio · the ship is audible under everything` (a playing ambience node on boot), and — the highest-value item in the slice — **`audio · every cue the code asks for is on disk`**, which walks every string literal passed to `play_sfx` and asserts `ResourceLoader.exists`. That check must be demonstrated failing on the current tree first. **Kill** if a menu bed proves intrusive, ship ambience alone and drop the music tier. **Rollback** per-half; the two halves are independent.
**Do not bundle** `world/boiler_critical.ogg` never firing — that is an unbuilt feature (the boiler only ever plays `boiler_hurt.ogg`), not this bug.

### DR-03 — A demo build exists as a build configuration *(OWNER-GATED SCOPE)*
**Evidence** `export_presets.cfg:1-13` is the only preset; `custom_features=""`, `exclude_filter="reference/*"`. `grep -rn -i "demo" scripts/` returns **zero** — no flag, no wave cap, no class lock, no end card. `grep -rn "is_debug_build|OS.has_feature" scripts/` returns zero, so there is no gating seam of any kind. The cut is fully written but has never become work: `docs/STEAM-LAUNCH.md:595` — *"Concretely, the demo cut I would propose: waves 1–6, Captain only, Heat 0, no fittings/berths, results screen intact, and an end card that says what the full game has."* No BOARD row names it. Uploading today's exe as the demo hands over both heroes, the Colossus, the Workshop, Articles, fittings and — via SETTINGS → OPEN ALL HEATS — the entire Heat ladder.
**Files** `export_presets.cfg`, `scripts/game.gd`, `scripts/hud.gd`, `tests/parity_test.gd`, `docs/BOARD.md`, `NEEDS_ALEX.md`.
**Baseline** one preset, no gate. **Success** `shipping · the demo feature caps the run at wave six, one class, Heat 0` passes with the feature forced on and off. **Kill** if the cut reads as a demo that ends before the game is interesting, that is a scope decision, not a revert. **Rollback** delete the preset; the feature read is inert without it.
**Gate** the STEAM-LAUNCH paragraph is a standing *recommendation*, not an accepted decision, and NEEDS_ALEX's only Steam line is *"start the paperwork whenever you want the clock running"*. **Put the one-line scope question in NEEDS_ALEX so the owner chooses rather than defaults.** Do not implement a cut he has not accepted.

### DR-04 — Developer tools are not in the player's hands *(game.gd + hud.gd + harness)*
Merges three independent filings. **Escalated to blocking on one fact: the game itself tells the player to press the key.**
**Evidence** `scripts/hud.gd:3974` draws on the pause sheet: `_label("WASD move · mouse aim · %s · F7 classes · F4 layout · F3 stats"` — verified verbatim at synthesis. `game.gd:728` toggles `layout_edit` on F4 and `:721` toggles the profiler on F3, with no build gate anywhere in the project. The editor does not stop the simulation — `layout_edit` is a plain bool and `_set_state` is never called on that path — and it draws an absolute Windows path (`"SAVED · " + globalize_path(...)`) and names `SkyGear Tools.bat` on screen.
**Files** `scripts/game.gd`, `scripts/hud.gd`, `tests/parity_test.gd`.
**Baseline** F3/F4 live in release; the footer advertises them. **Success** the finding's `keys · the developer keys are inert in a release build` — drive F3/F4 through the real `_unhandled_input` with the dev predicate forced false, assert `layout_edit == false`, `show_profiler == false`, and `user://hud_layout.json` byte-identical; plus the footer string containing no `F4`/`F3`. **Kill** none. **Rollback** one predicate, one string.
**Scope corrections carried from verification, do not re-litigate them:** F12 and P need no separate gate — they are only reachable once `layout_edit` is true. Recovery already exists on screen (`hud.gd:1584` draws `Ctrl+Z undo · Ctrl+S save · Ctrl+R reset`) and nothing persists without a deliberate Ctrl+S, so drop the "permanently misaligned with no reset" framing. **The SETTINGS "Playtest:" caption is out of scope** — it is the owner's own OPEN ALL HEATS bypass under SG-160 and is named in NEEDS_ALEX as a thing he uses; hiding it for a demo build is DR-03's business, not this slice's.

### DR-05 — The legibility floor holds on the path that ships *(project.godot + game.gd + ink.gd + harness)*
**Evidence** `project.godot:25-26` ships `window/size/mode=3` (borderless fullscreen) with `window/stretch/mode="canvas_items"`; `window/stretch/aspect` is set nowhere in the 98-line file. `scripts/ink.gd` computes layout at 1920 and scales the canvas. The only physical-legibility guard is `game.gd:528-530` `win.min_size = Vector2i(MIN_WINDOW_W, MIN_WINDOW_H)` — **a windowed constraint that a fullscreen window does not satisfy**. `SkyGearInk.physical_pt` has no runtime caller at all; the named check `ink · the point-size floor clears the physical floor at the min window` evaluates it only at 1600. Every UI tool deliberately turns the shipped scaling **off** (`tools/screen_shot.gd:70-76`, `tools/legibility_probe.gd:36-37`, `scripts/screen_poser.gd:102-103`), so the four-width matrix everyone cites as coverage has never exercised the shipped path. On a 1366×768 laptop, 12pt renders at 12 × 1366/1920 = 8.5 physical px against a `MIN_PHYS_PX` floor of 10.0.
**Files** `project.godot`, `scripts/game.gd`, `scripts/ink.gd`, `tests/parity_test.gd`.
**Baseline** 8.5 px at 1366 fullscreen. **Success** `ink · the physical floor holds on the display the game opens on, not only in a window` + `ink · the stretch aspect is pinned`. **Kill** if clamping out of fullscreen on small displays is worse than small type, that is an owner call. **Rollback** two lines.
**Struck from the original finding:** the ultrawide-distortion half is wrong. Godot defaults `stretch/aspect` to `keep` and the repo's own `tools/text_audit.gd:94-95` describes the shipped behaviour as a keep-aspect letterbox. A 21:9 monitor gets bars, not ellipses. Pin `aspect` explicitly as a drift guard, not as a distortion fix.

### DR-06 — Combat impact audio *(game.gd + harness)*
Merges "landing a hit makes no sound" (filed twice) with "every repeated cue plays take `_1` forever".
**Evidence** `damage_enemy` — the project's declared single funnel for damage dealt to a boarder — contains no `play_sfx` call anywhere in its body. `assets/audio/sfx/player/` ships `hit_1..hit_5`, `crit_1..crit_3` and `elem_ember/frost/arc/steam`, all imported; a repo-wide grep returns exactly one reader, `_: return "player/hit_1.ogg"` as the unknown-shape *cast* fallback in `_shape_sound`. **Seventeen** sibling takes are unreachable (the original finding said fifteen and then listed seventeen; my scan confirms seventeen): `death_heavy_2`, `death_light_2/3`, `cannon_down_2/3`, `cannon_fire_2/3`, `cannon_hurt_2/3`, `crew_attack_2/3`, `crew_down_2`, `crate_break_2`, `hit_2..hit_5`. So all 21 gremlins in wave 11's opening batch die to one sample and every lane cannon fires one sample.
**Files** `scripts/game.gd` (`damage_enemy`, `on_enemy_killed`, `play_sfx`), `tests/parity_test.gd`.
**Baseline** zero cues from the damage funnel; take `_1` forever. **Success** `impact · a connected hit is audible and a crit says so` (uncrit vs forced crit take different `player/` paths) plus `audio · a repeated cue does not repeat the same take` (50 resolutions of `enemy/death_light_1.ogg` return more than one stream), plus the orphan grep returning a reader for every take on disk. **Kill** if a Field ticking six boarders floods the mix, the rate limiter is the fix, not reverting — `impact.STOP_REFRACTORY` already owns that clock. **Rollback** one insertion, one resolver.
**Must vary off `visual_rng`, never `rng`** — the seeded gameplay stream cannot shift. **Corrections carried:** the swing sound does *not* fire on a whiff (`_process_basic_attack` early-returns when `nearest_enemy` is null), and hulk hits, prop breaks, kills and player hurt all *do* sound today. The gap is specific to **non-lethal hits on boarders**, plus crit and element having no acoustic signature at all. Drop the "no acoustic difference between hitting and missing anywhere" framing; drop the MAX_VOICES phase-stacking speculation.

### DR-07 — A struck boarder shows it *(view3d.gd + enemy.gd + rig3d.gd + harness — heaviest lock in the backlog)*
**Evidence** `scripts/rig3d.gd:773 func react_hit(...)` exists and `rig3d.gd:27` advertises it; a repo-wide grep returns two lines — the definition and `view3d.gd:8796 _captain.react_hit(1.0)`. **No enemy rig is ever handed a hit reaction.** The flash half is dead even for the captain: `rig3d.gd:859` uses `set_instance_shader_parameter("flash", ...)`, and `view3d.gd:3674` states in the project's own words that this "is a no-op against a StandardMaterial3D — it needs a shader that declares the uniform, which an imported glTF material does not"; the only `.gdshader` in the project is the sky. **And the status tint is dead too** — `view3d.gd:8168-8176` writes burn/frost/stun colour to a `Sprite3D` billboard, while SG-89 records "the deck is now ALL MESH", so no boarder billboard exists to tint. The renderer's own consolation, *"a number and a tint"*, is currently just a number.
**Files** `scripts/rig3d.gd`, `scripts/view3d.gd`, `scripts/enemy.gd`, `tests/parity_test.gd`.
**Baseline** hitting a 360-HP Furnace Knight changes nothing about the figure. **Success** two frames one physics tick apart showing measurably lighter albedo and `scale.y < height_scale`; a check naming the **flash** specifically (today's `rig · and a hit squashes it without moving it` proves only the squash). **Kill** if a per-hit tween on a 180-HP wall reads as a seizure at wave 11, ship the flash and drop the squash. **Rollback** per half.
**This argues against a recorded decision — say so in the packet.** `view3d.gd:9174-9179` states the flinch rides `stun_time` because "a flinch on every tick of damage would freeze a 180-hp wall solid" (SG-85). The proposal is a scale/albedo tween, not a clip, so it sidesteps that — but the packet must acknowledge it rather than present this as pure oversight. **The dead status tint is the cleanest, least contentious half and could ship alone.**

### DR-08 — Destroying a run takes two deliberate acts *(hud.gd + ui.gd + harness)*
**Evidence** `hud.gd:3928-3935` — four 40px buttons at 46px pitch; HOW TO PLAY sits **6px above RESTART RUN**, which fires `game.restart_run()` immediately with no confirmation state anywhere in the path. Banking and logging only happen on VICTORY or GAMEOVER, and there is no mid-run persistence of any kind (`grep` for `autosave|save_run|resume_run` returns nothing). **Two paths, not one:** `ui.gd:360-368` fires on mouse-**down**, not release, so a slipped press cannot be dragged off and cancelled; and `ui.gd:391-395` makes Space/Enter activate the currently-focused widget, where **focus follows hover** — so hovering RESTART RUN and tapping Space is a second unconfirmed route to the same destruction.
**Files** `scripts/hud.gd`, `scripts/ui.gd`, `tests/parity_test.gd`.
**Baseline** one mouse-down ends the run. **Success** `pause · one click on RESTART RUN does not end the run` — click once at wave 5, assert `wave == 5` and `state_name == "PAUSE"`; click again, assert restart. **Kill** none. **Rollback** the confirm state is additive.
**Drop from the writeup:** "forty minutes in" is unsupported, and that a voluntarily abandoned run pays nothing is a normal roguelite rule, not part of the defect.

### DR-09 — The controls the game shows you are the controls you have *(hud.gd + game.gd + harness)*
Merges three findings: hardcoded slot labels, the unreachable eleventh rebind row, and the missing keyboard-and-mouse-only notice.
**Evidence** (a) `hud.gd:2476 var labels := ["LMB", "RMB", "Q", "E", "AUTO"]` — the four slot wells the player reads all run — plus `hud.gd:508` and `hud.gd:3974`, all literals, while `keybinds.gd:20-32` makes all four move actions and all four skills rebindable and `SkyGearKeybinds.label()` already resolves live bindings for `_draw_keys`. **`coach.gd:100-101` has already written the rule down**: "`{key}` is filled from the live binding rather than written in, so a player who rebinds the key is not told to press the one they replaced." (b) `REBINDABLE` has **eleven** entries; `hud.gd:3870` numbers rows `(i + 1) % 10`, so row 10 (PAUSE) is labelled **"1"** — the same as row 0 — and `_digit_slot` maps only `KEY_1..9 → 0..8` and `KEY_0 → 9`, so index 10 is unreachable and pressing `1` selects MOVE UP. **PAUSE can never be rebound.** (c) `project.godot:62-107` defines all eleven actions with only key and mouse events; there is not one `InputEventJoypad*` in the project, `game.gd:557-566` routes only key and mouse into `_apply_rebind`, and no screen says in words that the game is keyboard-and-mouse only.
**Files** `scripts/hud.gd`, `scripts/game.gd`, `tests/parity_test.gd`.
**Success** the drawn slot-3 string equals the live binding after a rebind (read off the drawn text, not by calling the resolver — the keybind store is already diverted, so this cannot touch the player's `keys.cfg`); `keys · every rebindable row is reachable from the controls screen` walking `REBINDABLE` and failing today at index 10; a CONTROLS-sheet KBM notice with the text audit clean at all four widths.
**Two traps.** `skill_1` is bound to **both** MOUSE_BUTTON_LEFT and key 1 (same for `skill_2`/RMB), so a raw `label("skill_1")` returns `"LMB / 1"` — the well needs a first-event or preferred-event rule, not a swap. And AZERTY is worse than the original finding said, not better: `keybinds.gd:16-17` uses **physical** keycodes, so an AZERTY player presses ZQSD and never rebinds, while the well still reads "Q" and the title still reads "WASD" — **the labels are already wrong on that hardware with zero rebinding.**
**Gate** the minimum honest fix for (b) is two lines — number rows `i + 1`, extend `_digit_slot`. **Do not take the `ui.begin("keys", …)` widget-layer rework**: that is a menu-direction change and NEEDS_ALEX still lists Controls as *"untouched pending your verdict on the direction"* (**SG-93**).

### DR-10 — One dial a struggling player can turn *(hud.gd + audio.gd + harness; blocked by SG-161)*
**Evidence** `hud.gd:5268 var rows := 10` and the body at `:5285-5329` are the complete settings sheet: five volume sliders, MUTE, FULLSCREEN, OPEN ALL HEATS, REBIND, BACK. **No option changes rendering cost.** `project.godot:39-43` sets `scaling_3d/scale=1.0` — "the dial to turn down on a weak machine" — reachable only by hand-editing a config file. The renderer is loaded up by default: 4× MSAA plus screen-space AA, debanding, soft-shadow quality 3 on both light types. `docs/BOARD.md:241` records the **one and only** frame profile this port has ever produced: "**RTX 5080 … windowed 2560×1440.** Result: **frame p50 4.40 / p95 6.31 / p99 7.96 / worst 8.71 ms**".
**Files** `scripts/hud.gd`, `scripts/audio.gd`, `tests/parity_test.gd`.
**Success** a RENDER SCALE row (1.0/0.85/0.75/0.6) that round-trips through `SkyGearAudio.store` and reaches `scaling_3d_scale`. **Kill** none. **Rollback** one row.
**Hard dependency: SG-161** — the settings sheet already prints its footer *through* the BACK button at every width because `_draw_settings`'s `y` cursor and `writing_area(sheet).end.y` have never agreed. Adding a row without fixing that arithmetic (`SETTINGS_CAPTION_H`, const at `hud.gd:194`, used at `:5269` and `:5322`) makes an existing visual bug worse. **Do the SG-161 arithmetic in the same packet.**
**Two overreaches struck:** `project.godot:39-43` is a config-hygiene note, not a broken promise of a player-facing dial — do not present it as one. And FULLSCREEN *is* a display option and vsync *is* set (`project.godot:27`); the accurate claim is that no option changes rendering **cost**. The low-end premise is unmeasured (see §5).

### DR-11 — Mipmaps *(import metadata only — dispatch immediately, zero collision)*
**Evidence** re-verified at synthesis: `find assets -name "*.png.import" | wc -l` → **121**, and `compress/mode=0` × **121**, `mipmaps/generate=false` × **121**. Against `project.godot:45-46`, which spends two comments arguing for anisotropy — "The deck is one plane seen edge-on. Sixteen taps is the difference between plank detail and mush at the bow" — and sets `anisotropic_filtering_level=4`. **Anisotropic filtering only operates on mipmapped textures, so that setting is doing nothing at all**, and every distant deck decal, prop plate and boarder texture shimmers as the camera sways. `export_presets.cfg:20 texture_format/s3tc_bptc=true` is inert while all 121 are mode 0.
**Files** `assets/models/**/*.png.import`, `assets/art/{props,enemies,ground,fx,env}/*.png.import`. **Leave `assets/art/ui/*` Lossless with no mips — it is drawn in 2D.** Set `compress/normal_map=1` on `*_normal.png`. No scenes, no scripts.
**Baseline** 121/121 unmipped. **Success** `grep -c 'mipmaps/generate=false'` over `assets/models` returns 0, and a frozen-deck A/B at zoom-out shows far planking no longer aliasing between the plates. **Kill** if VRAM-compression artefacts show on the brass at play distance, keep mipmaps and revert compression only. **Rollback** re-import.
**Argue this on shimmer, not on VRAM.** The measured pixel budget is ~135 MB for the whole 3D-facing set as RGBA8; compression saves ~100 MB against a 700 MB figure dominated by 4× MSAA and shadow targets at 1440p — **~14%, not a category change.** The "4 GB card thrashes at wave 12" claim is unsupported by anything cited and must be struck.

### DR-12 — The results table lines up *(hud.gd + game.gd + harness)*
**Evidence** `hud.gd:23 font = ThemeDB.fallback_font` is the only font in the project — proportional. The report is built with monospace padding: `game.gd:2105 return "  %-20s %7d  %d%%   %d casts  %d kills"` and `:2086` likewise for reactions. Those strings are drawn as ordinary proportional text one line at a time at `hud.gd:5405-5408`, so damage / share / casts / kills columns drift line by line on the last screen of every run — the one a demo player studies and screenshots.
**Files** `scripts/hud.gd`, `scripts/game.gd`, `tests/parity_test.gd`.
**Success** the drawn right edge of the damage figure is identical across every skill row of a real run's report — an x-coordinate equality, not a string compare. **Keep the clipboard copy padded**, where monospace is a fair assumption. **Kill** none. **Rollback** localised to `_draw_results`.
**Sequencing note:** DR-17 could fix this for free if the report were routed through a shipped monospace face. **Decide DR-17 before doing DR-12**, or do DR-12 as columns and make it face-independent.

### DR-13 — Nothing the title draws falls off the canvas *(hud.gd + screen_poser.gd + harness)*
**Evidence** arithmetic, independently recomputed twice from the constants at `hud.gd:179-190` against the body sum at `:541-556`. With `heat_on` and `shop_on` both true, body = 104+76+76+46+92+76+138−8 = **600**, so `board.end.y` = 352+600+36 = **988**. Then `:654` y=1002; QUIT occupies 1002–1032 (48 px of clearance); `:664` y=1054; the history line at `:680` then `:681` y=1082; `:682` draws the footer at **1096**. `SkyGearInk.box` puts the box at `at.y - pt`, so the 15pt footer's box is **1081–1100.5 against a 1080 canvas — entirely off screen, not clipped.** This state is reached the moment the player wins their first run. **No detector can see it:** `tools/text_audit.gd` records only OVERFLOW/OUTSIDE/COLLIDE/WIDGET, the OUTSIDE test only fires while `_in_frame` (which `hud.gd:652` sets false before the tail), and the only off-canvas test in the project iterates the eight gameplay plates. One more menu row anywhere pushes QUIT itself off.
**Files** `scripts/hud.gd`, `scripts/screen_poser.gd`, `tests/parity_test.gd`.
**Success** `title · nothing the title draws falls off the bottom of the canvas`, posed with the ladder up, the Workshop unlocked and a non-empty run log, asserting `box.end.y <= size.y` at all four poser sizes — **failing today at 1100 vs 1080**. **Kill** none. **Rollback** one arithmetic block.

### DR-14 — The earned save survives *(workshop.gd + harness; hud.gd only if the alarm ships)*
Merges three persistence findings that the verifier confirmed are **one hardening pass on one file**, not three slices.
**Evidence** `workshop.gd:488-493` — `save_state` is open-WRITE + `store_string` + `close`: truncate-and-rewrite in place, **no temp file, no rename, no backup**. `:456-459` — any parse that is not a Dictionary returns `fresh()`, which is `unlocked:false, scrip:0, sigils:0, nodes:{}, articles:{}, fittings:{}, berths:[], best_heat:0` — everything the player has ever earned. The write fires from `bank()` on the frame VICTORY or GAMEOVER lands, and the **next** run's bank writes that fresh state over the corrupt file, ending recovery. The project applies the opposite standard everywhere else and pins it: `layout · a malformed screen entry falls back alone`, `view · a malformed lights entry falls back alone, never the deck`. **No check anywhere loads a malformed workshop save.** Two adjacent defects in the same file: `save_state`'s `bool` return is dropped by all four internal callers and all five UI call sites, so a denied write is completely silent (against `hud.gd:5504`'s `"COULD NOT WRITE THE RUN LOG — copy it before you leave"` on the same screen); and `respec()` indexes `NODES[id]` with **keys read out of the save file**, unguarded, while every other save-key iteration in the project guards — so the first patch that renames a talent makes RESPEC raise, refund nothing and clear nothing. `fresh()` carries no `version` key, so there is no place to migrate from.
**Files** `scripts/workshop.gd`, `tests/parity_test.gd` (+ `scripts/hud.gd` if the alarm line ships — **scope it out to keep this off the hud.gd lock**).
**Success** `shop · a truncated save is not a wiped save` (write, truncate to half, reload, assert every field returns); `shop · a save carrying a talent this build no longer has still respecs` (must raise against today's code); `shop · a denied write is reported, not swallowed` exercising the real `f == null` branch — **note `fittings · a denied write reports clean without reaching the disk` tests the *ephemeral* early return, not the denial branch, which has no coverage at all.** **Kill** none. **Rollback** one file.
**Honest severity:** the corruption trigger needs process death inside a ~1 KB write — not something a demo player hits on a healthy machine, and there is no measured instance in this repo. It is filed high because the loss is total and silent, not because it is likely. A live sub-defect exists today regardless: `hud.gd:4622-4629` computes the Workshop's COMMITTED ledger by walking `NODES.keys()`, so a stale node is already under-reported in the refund total the screen promises.

### DR-15 — Warm the figures *(warmup.gd + harness; MEASURE FIRST)*
**Evidence** `_sync_rig`'s miss path does `SkyGearRig3D.new()` → `add_child` → `setup(path, …)`, and `rig3d.gd:204-225` does `load(scene_path)`, `packed.instantiate()`, then **three** synchronous `find_children("*", …)` tree walks — all inside a live gameplay frame. `scripts/warmup.gd:36-109` is the whole of `warm()`: eight decal textures × two blends, four painted plates, the ribbon batch, one FogVolume, one particle per emitter — **and not one rig, mesh or skinned material.** `grep -rn 'preload("res://assets/models' scripts/` returns nothing. `assets/models/boss/boss_parts.scn` is **5,619,617 bytes**, and `game.gd:2817-2818` fires `view.cue("boss_arrival")` on the same frame as the Colossus `spawn_enemy` — so that load lands **inside an authored cutscene shot**, the capsule-video moment. `warmup.gd:6-14` already makes this exact argument in its own words and then warms everything except the figures.
**Files** `scripts/warmup.gd`, `tests/parity_test.gd`. **Success** `warmup · every boarder kind that has a model is drawn once before the run starts`, plus a `profile_fight.gd` run through the wave-12 arrival with and without, worst-frame measured against 8.71 ms. **Kill** if boot hold grows unacceptably, warm only BOSS and ARMORED. **Rollback** one function.
**Cite corrections:** `_sync_all` is at `view3d.gd:8034` with the boarder call at `:8123` — **not 7963**, which is fog-volume code. And the captain already pays part of this bill: `view3d.gd:8711-8714` builds `_captain` through the identical path at run open, so the skinned-material pipeline class is compiled before wave 1. What is genuinely unpaid per kind is **the disk load, the instantiate and the three tree walks** — justify the packet on that, not on "the material pipeline". **The hitch magnitude is unmeasured; do not assert milliseconds until profile_fight has run it.**

### DR-16 — Alt-tab pauses *(game.gd + harness)*
**Evidence** `grep -n "_notification|NOTIFICATION_"` across the whole of `skygear-godot/` returns **no matches** — there is not a single `_notification` override in the project, so focus-out is never seen. `project.godot:25` ships borderless fullscreen with the comment "so alt-tab behaves" — it behaves at the window-manager level; the simulation does not, because `_process` keeps stepping for as long as `state == State.PLAY`.
**Files** `scripts/game.gd`, `tests/parity_test.gd`. **Success** `shipping · losing window focus mid-wave pauses the run` — today the method does not exist, so the check cannot even be written. **Kill** none. **Rollback** one override.
File it as the quality-of-life gap it is; **drop the "loses your run" narrative — it is unmeasured.**

### DR-18 — The second hero has his own voice *(voice.gd + hud.gd + harness; OWNER-GATED)*
**Evidence** every player-facing key in `voice.gd:31-44` points at `captain/…`, and `assets/audio/voice/` contains only `boss/`, `captain/` and `crew/` — **there is no `boilerwright/` folder.** He is a released, distinct character with his own rig (`view3d.gd:8571`) and his own name and verbs. `voice.gd:92-100` already discovers takes by path at load, so a per-class root is a small change.
**Files** `scripts/voice.gd`, `scripts/hud.gd`, `tests/parity_test.gd`.
**The portrait half is already tracked — do not re-file it.** `docs/BOARD.md:88` **SG-105** names it in priority order: "**`portrait_boilerwright.png`** — a real bug, he wears the Corsair's face today", with the generation prompt written out in `docs/HUD-DESIGN.md` §6. It is BLOCKED on the owner starting the Loom, and NEEDS_ALEX lists it under "Only you can unblock".
**Owner gate, and it is a real one:** the proposed fix routes his keys to `boilerwright/…` and falls through to silence. **That makes the second hero mute rather than mis-voiced, which may be worse for a demo.** Put the choice to Alex — wrong voice, no voice, or hold until takes exist — do not pick it. Also note the "her voice" framing is inference; static evidence establishes only that both classes share the `captain/` take set.

### DR-19 — The exe stops shipping the test suite *(export_presets.cfg — zero collision)*
**Evidence** searched in the binary: `grep -a -o "res://tests/parity_test[^\"]*" builds/windows/SkyGear-Godot.exe` returns `res://tests/parity_test.gdc`, with `smoke_test.gd`, `bot.gd`, `demo_reel.gd`, `balance.gd`, `boss_probe.gd`, `cam_measure.gd` and the rest in the surrounding path table. Cause: `export_presets.cfg:9-11` `export_filter="all_resources"` with `exclude_filter="reference/*"` — only `reference/` is held back. Nothing loads them at runtime.
**Files** `export_presets.cfg` (one line: `exclude_filter="reference/*,tests/*,tools/*"`). **Success** both binary greps return 0 where they return non-zero today, and the size drops measurably against 234,249,424 bytes. **Kill** if the exported build's stderr is not clean, revert. **Rollback** one line.
**Carry this caveat:** `tools/lab_math.gd` registers the global class `LabMath` and Godot bakes the global class list into `project.binary`, so excluding `tools/*` can produce script-load noise for a registered-but-absent class. **Verify the exported build's stderr, not just that the paths are gone.**

### DR-20 — The itch README stops advertising the free browser build *(pack_itch.py — zero collision)*
**Evidence** `tools/pack_itch.py` writes a README beside the exe whose final sentence is: *"Every fourth wave is not a wave. The browser version at https://alex-unconstrained.github.io/skygear/ is the original."* That is the only prose a downloading player receives, and NEEDS_ALEX tells the owner to **"Send friends the itch link, not a Steam key"** — so this is the build friends get. The same README lists "1 2 3 pick a draft card" while the game handles a **fourth** card key (SG-46), and never names F or V despite describing the Boilerwright's jets and taps.
**Files** `tools/pack_itch.py`. **Success** the README contains no `github.io` URL and names every key in `REBINDABLE` plus F and V. **Kill** none.
**Argue this commercially and on correctness — do not cite board rule 3a.** Rule 3a governs *rationale for changes*, and this is a package that links a free substitute from a paid download plus two missing keys. Never reaches a Steam demo, so it is not demo-damaging.

### DR-21 — Frame time is in the ship gate *(tools/hub.gd — zero collision)*
**Evidence** `tests/bench.gd:64-66` carries a real verdict — `ok = p99 <= 16.7`, printing `PASS`/`OVER BUDGET` — but re-verified at synthesis: **`grep -c "bench" tools/hub.gd` returns 0**, and `hub.gd:24` says `all` runs only `kind: "check"` entries, so `hub -- all` (described as able to "gate a build on its own") cannot reach it. The one perf entry in the hub is `{"id": "profile", "kind": "window"}`, whose own comment says it has no pass/fail on purpose (SG-25). `grep -c p99 STATUS.md` returns 0.
**Files** `tools/hub.gd` (one entry; bench already refuses headless and already exits non-zero). **Success** `hub -- all` names `bench` and its exit code reflects the verdict — demonstrated by temporarily lowering 16.7 to go red. **Kill** if machine variance makes the gate flap, that is the reason to reconsider, not a reason to skip measuring.
**State the trade rather than assuming an oversight:** a 16.7 ms wall-clock budget makes `hub -- all` machine-dependent, which is plausibly why bench was left out. **Leak watching and a soak are the next two rows, not this one** — and re-cite the leak evidence: `grep -rn 'ObjectDB instances were leaked' .codex-work/` hits **AB-04/SG-208 only** (12 → 50 across seven logs in one packet). The AB-02/AB-03 logs cited in the original finding contain **zero** such lines; those numbers were misattributed.

### DR-22 — Tools stop writing to the owner's real saves, and the guarantee he was given is corrected *(tools half is collision-free)*
**Evidence, re-verified at synthesis.** `tools/balance.gd` is a first-class hub `check`. It drives runs to a terminal state, and `game.log_runs` defaults `true`, so `run_logged = not log_runs or SkyGearRunLog.record({...})` fires on every VICTORY/GAMEOVER. `grep -n "log_runs|fresh(true)|RunLog" tools/balance.gd` returns **one line: `518: game.workshop = SkyGearWorkshop.fresh(true)`** — it diverts the workshop and **not** the run log. `runlog.gd` keeps 60 rows and evicts from the front, so a sweep past 60 permanently evicts real runs. `grep` over `tools/profile_fight.gd` returns **neither guard** — `begin_run()` on a game whose `workshop` is the real save.
**And the promise made to the owner overstates the coverage.** `NEEDS_ALEX.md` tells Alex: *"All four files are diverted to scratch copies now, proved by a full-tree checksum that comes back identical across a run. It will not happen again."* The md5 manifest is a **one-off hand measurement recorded in SG-182 on 2026-08-04**, not a tool — `grep -rn md5` across every `.gd`, `.py`, `.bat` and `.md` returns exactly two prose sentences (`docs/BOARD.md:127`, `STATUS.md:305`) and **no executable manifest anywhere**. It covers the harness only; `tools/` was never in its scope. Separately, four of the five owner-file guards assert only that a `store` variable was reassigned — `_owner_file_guard` calls `_check(..., diverted, ...)` and its own comment says the byte compare is "REPORTED rather than asserted".
**Files** `tools/balance.gd`, `tools/profile_fight.gd` (tools-only half: two lines each, **zero serialized files**); optionally `scripts/game.gd` to make it structural by gating `bank()` behind the same `log_runs` flag that already gates the run-log write two lines above it; `STATUS.md` for the two sentences.
**Success** hash `runs.json` and `workshop.json`, run `balance` then `profile_fight`, hash again — both unchanged. **Kill** none.
**Split the two risks — they are asymmetric.** `balance.gd` risks only the run log (its workshop *is* ephemeral). `profile_fight.gd` is the one that can touch the earned save, and it is one of only three tools in 43 that does not use `fresh(true)`; **`anim_timing.gd` and `cutscene_lab.gd` share that exposure and were not mentioned in any finding — check them in the same pass.** Not player-facing; filed here because the owner's history was already destroyed once and he has been told it cannot recur.
**Fold the STATUS.md half into SG-192**, which already owns "sentences claiming coverage without naming a check". The demotion of the byte compare was **deliberate and evidenced** (`parity_test.gd:2578-2593` records a run failing with "was 127 bytes, now 0" because the owner's own itch build was caught mid-write) — do not file it as a defect; file the *prose* as the defect.

### DR-23 — The harness time base is the time asked for *(parity_test.gd, one token)*
**Evidence** `parity_test.gd:112-119` `var steps := int(seconds / 0.05)`. In IEEE-754 double, `0.3 / 0.05` = 5.999999999999999 → **5 steps = 0.25 s, 16.7% short**; `1.2 / 0.05` = 23.999999999999996 → 23 steps, 4.2% short. Nothing is red today — the `1.2` case at `:17891` has 0.35 s of slack against `ARRIVAL_TIME`. **Fix** `int(round(seconds / 0.05))`. **Success** `harness · a step count is the seconds asked for, not one step short`, demonstrated failing first, with the run total unchanged and no check flipping. **Kill** if any check flips, that check was passing on the truncation and needs investigating, not reverting.
**Corrections:** `0.6` is never passed to `_advance` — the durations actually in use that truncate are `0.3` and `1.2` only. **Lead with 0.3 (16.7%), not the 5% figure.**

### DR-24 / DR-25 / DR-26 / DR-27 / DR-28 / DR-29 — the tail

- **DR-24** (`hud.gd`, `game_data.gd`, harness) — `player.gd:177 invulnerability_left = DASH_TIME + 0.08` makes the dash the i-frame button, and `hud.gd:210`'s gate is what every damage source passes. The captain's HOW TO PLAY branch (`hud.gd:4238-4242`) has two rows and **no dash row**, while the Boilerwright's replacement for it gets a full row directly above (`:4233-4236`), a compare-table row (`game_data.gd:330`) and a renamed CONTROLS row. Quote `DASH_TIME` from the constant, never write the number in — the page's own rule. Real asymmetry, optional F1 page, partial live feedback already exists via the invuln chip.
- **DR-25** (`hud.gd`, `ui.gd`, harness) — `ui.gd:402-413 _step` walks declaration order with no spatial term, and `hud.gd:5430-5439` declares the four results buttons as a row-major 2×2, so Down jumps sideways and Left/Right are swallowed. **The project already knows the rule** — `hud.gd:522-524` records that a two-column title board was drafted and dropped for exactly this. Keyboard-only: the mouse works on all four (focus follows hover) and every button has a direct key hint, so nothing is unreachable and nothing shows in a screenshot. The one-column relayout is the smaller change.
- **DR-26** (`game.gd`, `hud.gd`, harness) — **OWNER TASTE.** `add_floater`'s `big` argument is the crit boolean, never the magnitude, and `hud.gd:3163` derives two point sizes from it. A 4-damage Field tick and a 90-damage crit Mortar share two sizes. A design improvement, not a defect a paying player would call broken. **Strike the cap-eviction half** — it needs 40 simultaneously-live floaters and nothing static shows the cap is ever reached.
- **DR-27** (`impact.gd`, harness) — **argues against a recorded decision; treat as a tuning proposal.** `impact.gd:26 STOP_THRESHOLD := 34.0` came "straight from the browser's `TUNING.feel`", and every shipped auto (Captain 22 / combo 20 / return 24, Scald 18) sits under it, so no basic attack reaches the hit-stop branch in the default case. `VFX-PLAN.md` records the small-hit exclusion as intentional. Corrections: `mods.slow_damage` at 0.50 pushes both autos over 34, so "ever" must become "in the default and near-default case"; and crits (44/48), kills, Pulse (34) and Mortar (40) all land stops today, so the player is not without time-domain confirmation.
- **DR-28** (`game.gd`, harness) — `end_reason = "The captain fell on wave %d."` is the entire account of a defeat, while `damage_player` writes `tel.taken_by_source[wave]` under a comment about nothing reading it. **Correct the finding:** it *is* read — by `tools/boss_probe.gd:340`, `tools/critx_probe.gd:273`, `tools/melee_probe.gd:345-346` and `tools/balance.gd:690`. The accurate defect is "**no player-facing reader**", and the player did see the blow land, the red floater and the shake, so what is missing is a post-run summary line.
- **DR-29** (`view3d.gd`, harness) — **MEASURE FIRST, do not fix on this evidence.** `view3d.gd:5690` says telegraphs are "never dropped" and `:5730` `if _decal_live[group] >= DECAL_BUDGET[group]: return` drops them, arbitrated by `for enemy in game.enemies()` iteration order rather than by danger. The existing check `telegraph · the windup pool stays inside its reserve under flood` proves only that the cap holds. But the player-impact story does not survive scrutiny: arrivals are staggered by `ARRIVAL_TIME` 0.8 s against 0.22–0.65 s spacing, so ~6–9 rings overlap, not 21; and a dropped telegraph is a **delay of one frame**, not a loss for the beat, because `_decal` is called every frame for the same key. **What is real is a false comment and an unmeasured budget.** Ship the measurement — peak live telegraph decals across a wave-11 segment, reported next to the 48 — before writing any ordering code.

---

## §3 — File locks and the second workstream

**The five serialized files, and who holds them right now:**

| File | Status at synthesis | Slices wanting it |
|---|---|---|
| `scripts/game.gd` | **HELD (SG-208, +130 lines)** | DR-01b, 02, 03, 04, 05, 06, 09, 16, 22*, 26, 28 |
| `scripts/view3d.gd` | **HELD (SG-208, +88)** | DR-07, DR-29 |
| `tests/parity_test.gd` | **HELD (SG-208, +496)** | ~every slice |
| `scripts/game_data.gd` | **HELD (SG-208, +26)** | DR-24 |
| `scripts/hud.gd` | free | DR-01b, 02, 03, 04, 09, 10, 12, 13, 14*, 17, 18, 24, 25, 26, SG-183 |
| `scripts/enemy.gd` | free | DR-07 |

`*` = the file can be scoped out of that slice.

**Second workstream — genuinely independent, touches none of the five and not the harness. Dispatch in parallel today:**

1. **DR-01a** — `export_presets.cfg` + `project.godot` + icon *(highest-ranked item in the whole backlog and it needs no lock)*
2. **DR-11** — `*.png.import` only
3. **DR-19** — `export_presets.cfg` (one line; **sequence after DR-01a**, same file)
4. **DR-21** — `tools/hub.gd`
5. **DR-20** — `tools/pack_itch.py`
6. **DR-22 (tools half)** — `tools/balance.gd`, `tools/profile_fight.gd`, and audit `anim_timing.gd` / `cutscene_lab.gd`

That lane covers the entire outer surface of the shipped product — icon, name, version, payload, README — plus the shimmer fix and the frame gate, with zero collision risk against SG-208.

**Third lane — harness lock only (one at a time, behind SG-208):** DR-14 (workshop-only scope), DR-15, DR-23, DR-27.

**Fourth lane — `hud.gd` only, free now, but internally serialized against itself.** Fifteen slices want `hud.gd`. Sequence them: **DR-13 → DR-12 → DR-10+SG-161 → DR-09 → DR-08 → DR-25 → DR-24**. DR-17 (typography) must go **first or last** in that chain — it moves every measured heading width and forces the four-width text audit to be re-run.

**Do not believe "one asset pair, six call sites" for DR-17.** `SkyGearInk`/`ui.gd` measure dynamically, which means the layout *moves* with the face; the containment and legibility audits are pinned against the current metrics. Treat that as the start of the work, not its extent.

---

## §4 — Owner-gated. No agent may decide these.

1. **SG-206 / SG-207 G5.** See §0-C. The brief says pending; an uncommitted working-tree edit says passed today. **Confirm with Alex directly.** No agent may resolve, simulate, or infer this verdict — including from the BOARD row that now asserts it.
2. **DR-03 demo scope.** The STEAM-LAUNCH.md:595 cut is a standing recommendation, never an accepted decision, and it is not on his list. Put the one-line question in NEEDS_ALEX.
3. **DR-17 typeface.** A licensed display + body face is a purchase and a taste call.
4. **DR-01a icon.** Art asset; the Loom is not running on this machine (SG-105 BLOCKED, and NEEDS_ALEX lists it under "Only you can unblock").
5. **DR-18** — wrong voice vs mute second hero.
6. **DR-09** — CONTROLS widget-layer direction is held by **SG-93** / NEEDS_ALEX ("Menus — untouched pending your verdict"). Take the two-line numbering fix only.
7. **DR-26, DR-27** — taste and a recorded decision respectively.
8. **DR-04 scope note** — the SETTINGS "OPEN ALL HEATS" row is his own SG-160 ask and is named in NEEDS_ALEX as a thing he uses. Hiding it belongs to DR-03, not to the dev-key gate.

---

## §5 — REQUIRES-RUNTIME-EVIDENCE

**This audit was forbidden from running Godot.** Every claim below needs a live build, a frame time, a screenshot or a hands-on judgment, and **none of it is asserted anywhere above**. Do not let any of these enter a packet's justification until it is measured.

**Cannot be established without a running build:**
- Whether the 48-decal telegraph reserve is **ever reached** in a real wave. DR-29's entire premise. Measure peak live telegraph decals across a wave-11 segment.
- Whether the 40-floater cap is ever reached (DR-26's eviction half — struck from the backlog for exactly this reason).
- The **magnitude** of the first-rig-load hitch, including the Colossus's 5.6 MB scene inside `boss_arrival` (DR-15). No milliseconds may be quoted.
- Whether this build runs acceptably on **any machine that is not an RTX 5080**. `docs/BOARD.md:241` is the only profile in the project's history. DR-10's "runs badly on their machine" is an assumption.
- Actual VRAM after compression, and whether the shimmer reduction is visible at play distance (DR-11).
- Whether per-frame `settings.cfg` writes produce measurable stutter (SG-183 / DR-24 severity).
- The exported exe size delta and stderr cleanliness after `exclude_filter` widens (DR-19, the `LabMath` caveat).
- Whether the packaged exe's taskbar icon, window title and Properties actually change (DR-01a's only real proof).
- Physical legibility at 1366×768 fullscreen and pillarboxing at 2560×1080, **through the shipped scaling with content scale left on** (DR-05). Every existing screenshot was taken with it disabled.
- Whether the shipped font swap breaks containment at any of the four widths (DR-17).
- Whether the 12 → 50 ObjectDB leak swing across SG-208's logs is benign (DR-21).
- Whether the harness is currently green: the last frozen figure in the tree is SG-208's red-first **1187/1200**, not 1187/1187, and 496 lines of new test code are uncommitted.
- Whether any slice above changes the check total, and whether the 56 pinned engine errors (**SG-153**) hold.

**Cannot be established by any static means at all — these are G5-class:**
- Whether hit-stop on small hits feels right, or turns 2.8 cuts/second into mush (DR-27).
- Whether floater banding reads at a glance in a wave-11 crowd (DR-26).
- Whether a hit flash on every damage tick reads as impact or as a strobe (DR-07).
- Whether a title-screen music bed is welcome or annoying on the fifth launch (DR-02).
- Whether the demo cut ends somewhere that makes a player want the rest (DR-03).
- **Everything in this backlog described as "feel", "reads as", "cheap" or "unfinished" is inference from source constants and authored data, not observation.** Nothing here has been seen or heard.

---

## §6 — Dedup and severity log

**Merged (40 findings → 29 slices):** product identity filed 4× → DR-01a/b · dev keys filed 3× → DR-04 · missing hit audio filed 2× → DR-06 (with take rotation) · no graphics option filed 2× → DR-10 · three workshop.gd findings → DR-14 (one file, one pass) · menu silence + dead `card_hover` path → DR-02 · slot labels + rebind rows + controller notice → DR-09 · the STATUS.md guard-claim finding → folded into **SG-192**.

**Severity moved down, with the reason:** the settings-write finding (no measured symptom; ~200-byte file — already **SG-183**) · the results focus-order finding (mouse works; keyboard-only; invisible in any screenshot) · the tools-hygiene finding (no demo ships `tools/`; owner data hygiene, not player-facing) · the harness byte-compare finding (documentary; the demotion was deliberate and evidenced) · the telegraph finding (dropped mark is a one-frame delay, and the flood may never occur) · the hit-stop finding (contradicts a recorded decision, and stops do land on crits, kills, Pulse and Mortar).

**Severity moved up:** DR-04, to blocking — because the pause menu *advertises* the dev key to the player in its own footer, which is a different defect from the key merely existing.

**Claims struck outright:** the 4 GB-VRAM-thrash failure mode (unsupported; saving is ~14%) · ultrawide geometry distortion (Godot defaults `aspect=keep`; the repo's own tooling says so) · "no acoustic difference between hitting and missing anywhere" (hulk hits, props, kills and player-hurt all sound) · "the swing fires on a whiff" (`_process_basic_attack` early-returns) · "measures it and throws it away" for `taken_by_source` (four tools read it) · "nothing was ever scoped as withheld" for the demo (STEAM-LAUNCH.md scopes it fully; the implementation and the board row are what is missing) · "no doc has ever raised the icon" (STEAM-LAUNCH.md:364 raises the *Steam client* icon; the exe icon and boot splash remain unraised) · three of four leak-log citations (misattributed to AB-02/AB-03 files that contain no such lines).