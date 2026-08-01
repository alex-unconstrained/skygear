# THE BOARD — the work queue

**This is where agents pick up work and where they report it.** One item, one
row, one owner at a time. `docs/OUTSTANDING.md` stays the ledger of what the
owner asked for — an owner ask lands there first and gets mirrored here as one
or more workable items. Bugs found by tools, assets to generate, and infra work
land here directly.

## The rules

1. **Claim before working.** Set STATUS to `IN PROGRESS` with your agent name
   and the date. Two agents on one item is wasted work.
2. **DONE needs evidence.** A named harness check string, a tool output, or a
   commit hash — never "looks right". This adopts the audit rule: a claim of
   coverage names the check.
3. **Found a bug? File it before fixing it.** One row, source named, even if
   you fix it in the same session. The ledger exists because things slipped
   when nobody wrote them down.
4. **BLOCKED names the blocker** — a missing key, a decision only the owner can
   make, an upstream item by ID. Anything blocked on the owner is also
   mirrored, with a recommendation, in `/NEEDS_ALEX.md` at the repo root.
5. **Nothing is deleted.** DONE and DROPPED rows move to the bottom table with
   their evidence or reason. `git log` on this file is the audit trail.
6. **Priorities:** P1 = blocks shipping or contradicts a written claim ·
   P2 = owner-visible improvement · P3 = worth doing, not worth doing first.
7. **Before starting anything**: read `STATUS.md`, run
   `SkyGear Tools.bat harness` (green before AND after your change), and check
   this board's IN PROGRESS rows so you don't collide.

## Active

| ID | P | Type | Title | Status | Notes |
|----|---|------|-------|--------|-------|
| SG-27 | P2 | BUG | The Boiler PROP MESH dominates the lower third — larger than the browser's flat `boilerH: 132` block | OPEN | The real residual once SG-2 cleared the camera: the generated furnace mesh (`PROP_MODEL` boiler in `view3d.gd`) reads much taller/chunkier than the browser's flat engine block. This — not the camera — is what "the Boiler dominates the lower third" was seeing (`.shots/parity/deck.png`, `fight.png`). Diagnose against `PROP_HEIGHT`/the boiler's model scale; deleting its `PROP_MODEL` row falls back to the flat painted block. Belongs to SG-4 aesthetic parity. |
| SG-28 | P3 | FEATURE | The ranged firing line is a solid band, not the browser's animated dashed aim line | OPEN | SG-3 gave the GUNNER a bright danger firing band with a hot core that counts down the windup — the readability is there. The browser's `drawAimLines` additionally travels a DASHED line (`setLineDash([14,12])`, `lineDashOffset = -rt*90`) down the shot's path, which reads as motion toward you. A dashed/animated ribbon is a separate small job (needs geometry, not a decal — decals cannot dash). Cosmetic; the pillar-6 readability is already met. |
| SG-4 | P1 | FEATURE | Aesthetic parity — the original job. Browser vs Godot screenshots "almost identical in quality" | OPEN | `SkyGear Tools.bat parity` exists now; SG-3 came out of its first run. **SG-2 is cleared — the framing MATCHES to the pixel** (measured), so the two builds can now be compared on everything else. Remaining: work the fresh `.shots/parity/` reveals (starting with the Boiler prop, SG-27), plus parity scenes for the HUD and the draft. |
| SG-6 | P1 | INFRA | itch push capability: butler + credentials on this machine | BLOCKED — needs owner | Builds 1–31 were pushed from the previous device. Needs butler installed and `butler login` (interactive, owner's itch account). Until then: build locally, owner uploads by hand. |
| SG-7 | P2 | DECISION | Boilerwright mobility: compensate him somewhere feelable, or make the comparison screen say the trade plainly | BLOCKED — needs owner | Measured 60% gap (he covers 40% of her ground) after SG-1 made the measurement deterministic — was recorded as 67%/33% off a noisy sample. Explicitly not a tuning-by-feel item. |
| SG-8 | P2 | FEATURE | Cutscene shots for the three empty cues: `wave_start`, `victory`, `defeat` | OPEN | Data-only — author in `SkyGear Tools.bat cutscene`, save to `assets/cutscenes/`. The run-opening cue additionally needs one line wherever `begin_run` settles. |
| SG-9 | P2 | BUG | Text legibility (not containment): skills, cards, HUD hard to READ | IN PROGRESS — opus/SG-9, 2026-08-01 | Contrast and point size measured before changing anything; `_fits` shrinking text is itself a suspect. Distinct from the text audit, which a contained-but-7pt label passes. |
| SG-10 | P2 | FEATURE | Deckwork verbs beyond repair: drag a crate, close a lane, shape the fight | OPEN | One entry each in the verb table in `scripts/deckwork.gd`. The repair verb is the pattern. |
| SG-11 | P2 | DOCS | Adopt the audit rule repo-wide: every claim of harness coverage names its check string | OPEN | Ledger item, "Not done." Also fix the crit-only "worth less than three draft cards" check so it can actually fail (compares one field of thirty). |
| SG-12 | P2 | ASSET | The Boilerwright's model — currently renders as the captain | BLOCKED — route decision | Two routes in the ledger; the choice gates spending. Route 2 (mesh + retarget axe pack via `tools/ingest_model.py`) is the only one where both classes move on the same clock. Owner to confirm before credits are spent. |
| SG-13 | P2 | DECISION | The captain is 30,634 triangles, 4–10× the project's own budget, skipped by the remesh | OPEN | Needs a decision, not silence: local skin-weight-preserving decimation, hand LOD, or accept and record. |
| SG-14 | P2 | FEATURE | Heat as a ladder on the title screen — and Heat 3–5 do not exist | OPEN | Build the rungs before the rung display. Title screen has a COLLIDE history; wants its own audit pass. |
| SG-15 | P2 | FEATURE | Ship-and-maps first step: place the Colossus wreck as a permanent fitting | OPEN | `docs/SHIP-AND-MAPS-DESIGN.md` first recommendation; the art exists and has never been placed. |
| SG-16 | P3 | BUG | `ELEMENT_FX[*].life` is dead — declared per element, never read | OPEN | Honouring it means one emitter per element rather than per behaviour (`emit_particle` has no per-particle lifetime). Either build that or delete the field; a field nothing reads is failure mode one. |
| SG-17 | P3 | FEATURE | FX dials in the lab need a home: give the renderer a reader for effect constants | OPEN | Renderer change, not a tool change. Until then SAVE copies values to the clipboard beside their constant. |
| SG-18 | P3 | FEATURE | Weapon trail driven by the blade (`BoneAttachment3D` on her hand), not the effect clock | OPEN | `_beam_ribbon`'s two-layer construction ports straight across. VFX-PLAN §6. |
| SG-19 | P3 | DECISION | VFX-PLAN §5 chromatic hit / radial blur: drop it formally | OPEN | Research audit argues against on readability grounds. Somebody decide and record; do not build by default. |
| SG-20 | P3 | ASSET | Captain's sword grip re-fit in the lab with the timeline running | OPEN | "Two minutes in the fitter." The −120° pitch was tuned at rest; check it through `swing2`. |
| SG-21 | P3 | ASSET | Boarding hulk as a hand-modeled mesh (wide, shallow, ramps separate) | OPEN | Two Meshy attempts rejected; do not prompt a third. `HULK_MODEL` wiring is in place and inert. |
| SG-22 | P3 | ASSET | The furnace knight is still a sprite | OPEN | Two Meshy attempts failed to read as a 180-hp wall. Solve or drop with a reason. |
| SG-23 | P3 | FEATURE | Cloak with cloth physics — bone chain route | OPEN | Bone chain on the existing skeleton driven by velocity; the cape is ~40 px at this camera. `SoftBody3D` and shader routes recorded in the ledger. |
| SG-24 | P3 | BUG | Popup menus reported drifting right — not reproduced | OPEN | Measured static across eight samples. Needs to know WHICH menu before it can be chased. Do not close: unreproduced ≠ absent. |
| SG-25 | P3 | INFRA | Rendering-audit leftovers: reserved per-pool capacities, a D3D12 run, first-ever profile of the port | OPEN | DESIGN.md §13m "still open." Gameplay telegraphs must never be displaced by decorative effects. |
| SG-26 | P3 | FEATURE | Two more Articles | OPEN | STATUS "Designed, not built." Design source: `docs/META-PROGRESSION-DESIGN.md`. |

## Done / dropped

| ID | Resolution | Evidence / reason |
|----|-----------|-------------------|
| SG-0 | DONE 2026-08-01 | Dev environment on this machine: Godot 4.7.1 installed to `%USERPROFILE%\.local\bin\godot.exe` (where `SkyGear Tools.bat` looks), project imported clean, harness runs — 436/437, the failure filed as SG-1. |
| SG-5 | DONE 2026-08-01 | Export restored: `windows_release_x86_64.exe` (4.7.1 official) extracted into `.templates/`; `tools/pack_itch.py` built `builds/itch/SkyGear-Windows.zip`, 2 files, 94.5 MB from a 168.0 MB exe. |
| SG-1 | DONE 2026-08-01 (opus/SG-1) | Check `class · but ground covered against a dashing captain is worse than that` was nondeterministic, not machine-specific: it read `global_position` after `move_and_slide()`, which steps by the engine's real-frame physics delta (`get_physics_process_delta_time()`), not the loop's 0.05 sim tick — so it measured wall-clock jitter (200–570% run to run; 33% and 180% were two draws), compounded by the wave auto-completing and flipping state to DRAFT, which disabled `controls_enabled` mid-measurement. Fix: integrate `\|velocity\| * 0.05` (the speed the sim deterministically produces) and force `controls_enabled` on each tick. Now bit-for-bit repeatable — captain 3076, boilerwright 1228 every run — reading **40%** (was flapping). Harness 437/437, three consecutive green runs. Corrected the ledger's 67%/33% mobility gap to 60%/40% (`OUTSTANDING.md`). Fix is this commit (see `git log` for SG-1). |
| SG-3 | DONE 2026-08-01 (opus/SG-3) | **The melee windup was drawn, but as a plank-wide streak plus a small foot ring — measured against the browser it was a fraction of the readable danger.** The browser (`_render_entities.js drawTelegraphs`) draws a MELEE windup as a filled `PAL.danger` #FF3D2E wedge covering the swing arc out to `reach` (SCRAPPER 92/95°, ARMORED 118/120°, SWARM 64/80° — `_core_patched.js`), inner `PAL.dangerIn` #FF8C1A fill growing as the wind completes; lead time = `windup` (0.40/0.55/0.40 s); RANGED = a danger band + dashed aim line of `atkRange+80`. The port's `reach`/`swing` were never ported — it faked reach with a flat `attack_range + 24..28` fudge and drew a thin streak. **Fixed:** ported `reach`/`swing` into `game_data.gd` (the browser's tuned values), made the sim connect at `reach + target_radius` (`enemy.gd`) so what is DRAWN and what CONNECTS are ONE number (STATUS failure mode two), rebuilt the telegraph in `view3d.gd` as a filled danger wedge (`_fan_texture`) with a growing inner clock, and gave the GUNNER a bright firing band with a counting-down hot core. Evidence: harness `445/445` green; new checks `telegraph · a windup appends a telegraph decal to the deck`, `telegraph · the wedge is drawn at the reach the swing connects at` (drew 92 vs reach 92), `telegraph · every melee windup has a reach and a swing arc to draw`, `telegraph · a ranged shooter is not handed a melee swing`, `telegraph · the windup gives at least the browser's warning time`, `telegraph · the windup pool stays inside its reserve under flood` (48/48); `lanes · a boarder in every lane can reach the Boiler` still green on the new reach. Posed before/after in `.shots/telegraph/{before,after}/telegraphs.png` (`tools/telegraph_shot.gd`). Ranged dashed-aim-line polish filed as SG-28. Commit: see git log for SG-3. |
| SG-2 | CORRECTED 2026-08-01 (opus/SG-2) | **The camera was ported exactly; there is no framing gap. Measured, not asserted** (`tools/cam_measure.gd`): at one output resolution the browser's own `CAM.project()` and Godot's `Camera3D.unproject_position` agree to the pixel on every known length — deck full width 1680 = **3288.1 px in BOTH** (ratio 1.000); at the bow 1137.5 both; one lane 560 = 1096.0 both; vertical bow→stern 1695.7 both; the captain's ground point lands at the identical pixel (960, 705.4). Root cause of the false "zoomed in" finding: the browser's `_f = f * View.unit` (`_render_head.js:53`) scales focal length with resolution exactly as Godot's fixed vertical FOV does, so at any 16:9 aspect the two projections are identical — no `WORLD_SCALE`, deck-rect, distance or FOV gap exists. The original impression was made against a broken browser render (procedural sky fallback, images blocked over `file://`, as `parity.py`'s own comment documents) and/or unmatched resolution. Fresh evidence with the real art in `.shots/parity/{deck,fight,effects,boss}.png`; the one real residual (the Boiler PROP mesh, not the camera) filed as SG-27. Harness 437/437 — camera checks `the lens is the browser's focal length` (36.09°) and `the captain stands where the art was framed for` (0.600) both green, asserting the confirmed-correct invariant. |
