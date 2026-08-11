# Reference images — manifest

No binaries are copied here; every entry points at the real path. All paths are
relative to `skygear-godot/`. The IDs (R0, R1a, …) are the ones the storyboard
table and the prompt files use.

**Global preparation rule — flatten alpha.** Every sprite/prop PNG below is a
cut-out on a transparent background. H3 reads transparency unpredictably, so
before use flatten each onto a solid dark slate `#141020` (sampled from
`sky_backdrop.png`'s upper cloud field) at its native size. One ImageMagick
line per file, e.g.:

```
magick assets/art/heroes/corsair_front_idle.png -background "#141020" -flatten refs/prepped/corsair_front_idle.png
```

Write prepped copies to `docs/cutscene/refs/prepped/` (gitignored working
files; the repo keeps only this manifest). `sky_backdrop.png` needs no prep.

## The anchor

| ID | Path | For | Prep |
|---|---|---|---|
| **R0** | `assets/art/env/sky_backdrop.png` | **Every shot's `ref_images.ref_image_0`.** The exact sky, palette and painting style: moon through a cloud well upper-left, violet mid-field, ember horizon lower-right. This is the aesthetic anchor of the whole film. | None. 2048×1024, opaque. |

## The captain (identity lock — same refs in every shot he appears in)

| ID | Path | For | Prep |
|---|---|---|---|
| **R1a** | `assets/art/heroes/corsair_front_idle.png` | Face, hair, goggles, coat at rest. | Flatten. |
| **R1b** | `assets/art/heroes/corsair_front_attack.png` | The action pose: gauntlet raised, cutlass low and drawn. The definitive costume read. | Flatten. |
| **R1c** | `assets/art/heroes/corsair_back_idle.png` | Over-shoulder / from-behind framing (shot 9). | Flatten. |

**Do NOT use `assets/art/ui/portrait_corsair.png`** — a blue-coated red-haired
woman that matches neither the sprite nor the model nor the owner's SG-228
ruling (captain is male, young). It is not a style reference, not an identity
reference, not anything.

## Crew, enemies, threat

| ID | Path | For | Prep |
|---|---|---|---|
| **R2** | `assets/art/allies/crew_front_attack.png` | Crewmen charging/tending (shots 4, 6). | Flatten. |
| **R6a** | `assets/art/props/boarding_hulk_sealed.png` | The hulk arriving closed (shot 5, first half). | Flatten. |
| **R6b** | `assets/art/props/boarding_hulk_open.png` | Plates open on the red core, ramps down (shot 5, second half). | Flatten. |
| **R7** | `assets/art/enemies/automaton_front_attack.png` | The boarders (shots 5, 6). | Flatten. |
| **R9** | `assets/art/enemies/furnace_knight_front_attack.png` | The heavy and his axe (shot 7). Use `furnace_knight_front_idle.png` as a second ref in the same shot for the silhouette at rest. | Flatten both. |
| **R10** | `assets/art/enemies/colossus_front_idle.png` | The boss (shot 8): brass giant, furnace chest, orange eye, shoulder cannons, anchor feet. | Flatten. |

## The ship

| ID | Path | For | Prep |
|---|---|---|---|
| **R3** | `assets/art/env/airship_distant.png` | The whole ship in profile (shots 1, 2). | Flatten, then **crop to the content box** — the painted ship occupies roughly the top 55% of the 512×256 canvas; crop away the empty lower band so the ref is the ship, not black space. |
| **R4** | `assets/art/env/bow_prow.png` | The brass dragon figurehead and bow bulwark (shots 2, 8). | Flatten. |
| **R8** | `assets/art/props/cannon_deck.png` | The deck gun (shot 6). | Flatten. |

Also available if a shot needs deck dressing: `assets/art/props/brazier.png`,
`lantern_post.png`, `crate_stack.png`, `mast_section.png` — same flatten rule.

## Staged frames (to be captured — DO NOT run while the GPU is parked)

Two real-renderer frames, captured by whoever runs the generation session, at
the moment the GPU is free. `cutscene_lab.gd --frame` renders the real deck
through the real lens with **no interface** — preferred. `model_lab.gd --shot`
includes the tool's own UI and **must be cropped**.

| ID | Command (run from `skygear-godot/`) | For | Prep |
|---|---|---|---|
| **R5** (boiler) | `godot --path . --resolution 1600x900 --script tools/model_lab.gd -- --model boiler --shot docs/cutscene/refs/staged/boiler_raw.png` | Shot 4 and 9: the Boiler's real geometry — riveted dome, fire grate, gauges. | **Crop out the lab UI**: keep approximately x 420–1420, y 120–780 of the 1600×900 frame (the list column is 194 px wide on the left; dial rack sits low). Verify no UI text or gizmo remains in the crop before use; tighten the box if it does. Save as `boiler.png`. |
| **R5b** (deck) | `godot --path . --resolution 1600x900 --script tools/cutscene_lab.gd -- --play run_open --at 0.5 --frame docs/cutscene/refs/staged/deck_run_open.png` | Shot 6: the real deck's geography — lanes, cargo runs, lamplight — so the fight happens on a deck shaped like the game's. | None (no UI). If the instant is dull, re-render at `--at 0.3` / `--at 0.7` and keep the frame with the most deck and the least sky. |
| **R5c** (colossus on deck) | `godot --path . --resolution 1600x900 --script tools/cutscene_lab.gd -- --play colossus_arrival --at 0.62 --frame docs/cutscene/refs/staged/colossus_arrival.png` | Shot 8: the boss's real scale against the real bow, through the shipped lens. | None (no UI). |

These are **composition and geometry references only** — in every prompt they
are subordinate to R0 for palette and style, and the prompt says so. If a
staged frame reads flat-lit (the failure that sank the earlier gameplay-frame
attempt), it is still safe: the directive prompt assigns palette to R0 and only
geometry to the staged frame.

## Feeding order per shot

The prompt files bind refs to indices explicitly. Convention used throughout:
`ref_image_0` = R0 (style/palette), `ref_image_1` = the identity that must not
drift (captain, or the shot's creature), `ref_image_2+` = secondary subjects
and staged geometry. Keys are DOTTED in the API: `ref_images.ref_image_0`.
