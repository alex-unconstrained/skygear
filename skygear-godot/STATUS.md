# SkyGear Godot port — where things stand

Last updated 2026-07-28. Read this first after a break.

## Shipped

Live at https://alex-unconstrained.itch.io/skygear-godot-test — latest build
`m6-melee-animations`. `python tools/pack_itch.py` builds; `butler push
builds/itch/SkyGear-Windows.zip alex-unconstrained/skygear-godot-test:windows
--userversion <tag>` publishes.

**161 checks**, all passing: `godot --path . --headless --script
tests/parity_test.gd`. Exit code is the failure count.

## Waiting on Alex

1. **A HUD layout pass.** Press **F4** in game, drag panels, **Enter** to drill
   into a panel and move the elements inside it, **Ctrl+S** to save. That writes
   `%APPDATA%\Godot\app_userdata\SkyGear Godot\hud_layout.json`. Send it over
   and it becomes the shipped default — it is a one-file copy.
   `docs/HUD-LAYOUT.md` has the keys.
2. **Which part of the browser UI/UX felt furthest ahead** — draft screens, the
   in-fight HUD, or menus and controls. All three are fixable, they are
   different jobs, and knowing which one hurt would beat guessing.
3. **3D models for the other units.** Drop them in `tools/models.json` and run
   `python tools/ingest_model.py <name>`; the renderer picks up
   `assets/models/<kind>/<kind>.tscn` with no code change. Kinds: `scrapper`,
   `gunner`, `armored`, `swarm`, `boss`, `crew`. No 2D character animation
   cycles should be commissioned until this is decided — twelve of the fourteen
   pending ones are for units that may become meshes.

## Next up, in order, nothing blocking

1. **Reserved pool capacity** (`docs/VFX-RESEARCH-AUDIT.md`, finding 2 remainder).
   Pools are real now but share one free list, so a hostile telegraph and a
   scorch mark compete for it. The audit has the budget table.
2. **A frame profiler.** The port has never been measured. The browser has
   `tools/profile.mjs`; there is no Godot equivalent, and every performance
   complaint so far has been diagnosed without one.
3. **Bolt and chain ribbons** (VFX plan item 3) — projectiles have a head and a
   ground shadow but no body in the air.
4. **Re-forge two HUD pieces at their real aspect.** `ui_bar_housing` is a 3:1
   trough being squeezed into a 10:1 bar; `ui_lane_track` has end stops that are
   most of an 8px rail. The prompts are right, the canvas was wrong.
5. **A weapon mesh on `mixamorig_RightHand`.** The melee pack animates an axe
   the character does not have. She reads acceptably because of the brass
   gauntlet, but the animations do not mean what they were animated to mean.

## The tools, and why they exist

Standing instruction: before doing a piece of work, ask what tool makes this and
every future instance cheaper, then build it.

| Tool | Does |
|---|---|
| `tools/forge.py` | Art generation. Prompts live beside the manifest key they fill, so a change to the look is one edit. |
| `tools/ingest_model.py` | A rigged character from an archive to a usable scene, verified after the sources are deleted. |
| `tools/ingest_ui.py` | Forged HUD furniture into the port. |
| `tools/pack_itch.py` | Export and zip. |
| F4 in game | HUD layout, two levels, saved to disk. |
| `tests/parity_test.gd` | 161 checks. |
| `tests/_shot3d.gd`, `_shot_model.gd`, `_shot_screens.gd`, `_shot_anim.gd` | Screenshots for looking at things without launching. |

## Known-wrong, deliberately

- Two HUD assets do not fit their slots (above).
- Only Vulkan has been tested; D3D12 never has.
- The port has never been profiled.
- 14 of the 2D animation cycles are undelivered and listed `pending` in
  `scripts/sprites.gd`; a missing strip falls back to the still, which is why
  the game ships mid-pipeline.
