# SkyGear: Godot port

This folder is an isolated Godot 4 project rebuilding SkyGear from the latest
shipped browser build, v11. It does not import from, write to, or require any
file outside this directory. **This is the active project** — the browser build
at the repo root is frozen and serves as the reference target.

**Start at [STATUS.md](STATUS.md)**, then [docs/BOARD.md](docs/BOARD.md) — the
work queue: claim an item before working, close it with evidence.
[docs/OUTSTANDING.md](docs/OUTSTANDING.md) is the ledger of what the owner
asked for; [DESIGN.md](DESIGN.md) is the running design record.

## What it is now

Playable end to end: twelve waves and the Colossus, two classes (the Sky-Corsair
and the Boilerwright), the full 41-card draft with reroll and seeded rolls,
persistent progression (the Workshop, the Articles, Heat), a difficulty ladder,
a run log, rebindable keys, a cutscene system with all five cues filled, two rigged boarders that walk and die, and the
browser's painted sky sampled by view direction. Verified by the harness —
1128 checks — and a text audit across 25 screens at 4 widths.

**That count goes stale the moment anybody adds a check, so do not trust it: run
the harness and read what it prints.** `tools/hub.gd` deliberately carries no
count for exactly this reason, and STATUS.md's sixth failure mode is a fact known
in one place and contradicted in another. A number in prose here is a convenience,
never evidence — evidence is a named check string (board SG-11).

Build 62 is on itch: https://alex-unconstrained.itch.io/skygear-godot-test

## Run

1. Install Godot 4.7 or later. The shipped builds are exported with 4.7.1,
   Forward+ — Windows first, hardware accelerated, no web export (the
   reasoning is DESIGN.md §12).
2. Import this directory by selecting `project.godot`.
3. Press F5, or run:

   ```powershell
   godot --path . --editor
   godot --path . --headless --quit-after 3
   ```

Controls: WASD moves, mouse aims, LMB/RMB/Q/E use skill slots, Space dashes,
1/2/3 chooses a draft card, Esc pauses, F2 rebinds keys, F4 opens the HUD
layout editor, F11 toggles fullscreen. Mousewheel zooms out.

## Tools

Everything is behind `SkyGear Tools.bat` at the repo root (or
`godot --path . --headless --script tools/hub.gd -- <name>`). The ones you will
reach for: `harness` (1128 checks at 2026-08-04 — green before anything ships, and
the printed number is the authority, not this line), `text`
(the audit), `screens` (every screen at every width as one reviewable page),
`parity` (browser against Godot, same seed, stitched side by side), and `all`
(every checker, one verdict). Run the tools before believing anything.

## Build gotchas

- The Windows export template lives in a **gitignored** `.templates/`, so a
  fresh clone cannot build until it is restored. `tools/pack_itch.py` packages
  the itch artifact.
- When agents are working, build from a clean `git worktree` of HEAD or you
  ship a half-written file.
- Meshy asset generation reads its key from `MESHY_API_KEY` or the gitignored
  `tools/.meshy_key`; the key must never reach a committed file.

## Isolation rule

`reference/` is a copied snapshot used only for comparison. `assets/` contains
copied runtime assets. All Godot code and derived files live here. Never point a
Godot importer, converter, or editor operation at the parent project.
