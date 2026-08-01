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
   make, an upstream item by ID.
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
| SG-1 | P1 | BUG | Harness red on this machine: `class · but ground covered against a dashing captain is worse than that` reads 180% here vs the 33% recorded 2026-07-31 | OPEN | 436/437 on a fresh 4.7.1 import (2026-08-01, this machine). Suspect the measurement is timing/physics dependent rather than deterministic, or the fresh import changed behavior. Diagnose before touching numbers — the check may be the bug (it usually was). |
| SG-2 | P1 | BUG | The camera frames tighter than the browser — largest parity gap, contradicts the "ported exactly" claim | OPEN | Ledger item. **Measure before touching**: put a known length on screen in both builds and compare pixels. Candidates: `WORLD_SCALE`, deck rect, camera distance, a browser zoom-out the port dropped. Upstream of every other parity judgement. |
| SG-3 | P1 | BUG | Enemy attack telegraphs missing or much weaker than the browser's teal windup ellipse | OPEN | Pillar 6: every attack readable before it lands. The readability item the VFX plan was ranked around. |
| SG-4 | P1 | FEATURE | Aesthetic parity — the original job. Browser vs Godot screenshots "almost identical in quality" | OPEN | `SkyGear Tools.bat parity` exists now; SG-2 and SG-3 came out of its first run. Remaining: work it reveals, plus parity scenes for the HUD and the draft. Blocked-ish on SG-2 (framing must match before anything else can be judged). |
| SG-5 | P1 | INFRA | Restore the Windows export template so this machine can build | IN PROGRESS — main loop, 2026-08-01 | 4.7.1 templates downloading; extract `windows_release_x86_64.exe` into gitignored `.templates/`. Evidence when done: `tools/pack_itch.py` produces a zip. |
| SG-6 | P1 | INFRA | itch push capability: butler + credentials on this machine | BLOCKED — needs owner | Builds 1–31 were pushed from the previous device. Needs butler installed and `butler login` (interactive, owner's itch account). Until then: build locally, owner uploads by hand. |
| SG-7 | P2 | DECISION | Boilerwright mobility: compensate him somewhere feelable, or make the comparison screen say the trade plainly | BLOCKED — needs owner | Measured 67% gap (ledger). Explicitly not a tuning-by-feel item. Related: SG-1 questions the measurement's stability. |
| SG-8 | P2 | FEATURE | Cutscene shots for the three empty cues: `wave_start`, `victory`, `defeat` | OPEN | Data-only — author in `SkyGear Tools.bat cutscene`, save to `assets/cutscenes/`. The run-opening cue additionally needs one line wherever `begin_run` settles. |
| SG-9 | P2 | BUG | Text legibility (not containment): skills, cards, HUD hard to READ | OPEN | Contrast and point size measured before changing anything; `_fits` shrinking text is itself a suspect. Distinct from the text audit, which a contained-but-7pt label passes. |
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
