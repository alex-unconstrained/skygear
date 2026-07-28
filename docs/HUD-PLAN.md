# SkyGear — HUD and UI plan

Written 2026-07-28, after moving the whole HUD into a bottom band. This is the
brief the generated art is made against, so the pieces arrive fitting a layout
that already exists rather than a layout being bent around whatever arrives.

---

## 1. Why it moved

The objective plate and the lane readout sat in the top-right corner. **The top
of the frame is where boarders come from.** Two panels, 348 wide and 250 tall
between them, were covering the deck a player most needs to watch — and the lane
readout, whose entire job is to tell you a lane is breaking, was covering the
lane that was breaking.

Everything is now one band along the bottom: the half of the screen the captain
already occupies, and the half nothing arrives from.

```
┌────────────────────────────────────────────────────────────┐
│                                                            │
│                    ← boarders arrive here →                │
│                                                            │
│                     [ the fight ]                          │
│                                                            │
├──────────────┬──────────────────────────┬──────────────────┤
│  CAPTAIN     │   LMB  RMB   Q    E      │  BOILER          │
│  portrait    │   ▣    ▣     ▣    ▣      │  WAVE / BOARDERS │
│  hp pressure │                          │  PORT ▬▬▬▬       │
│  dash        │                          │  CENTRE ▬▬▬      │
│              │                          │  STARBOARD ▬▬    │
└──────────────┴──────────────────────────┴──────────────────┘
```

Three clusters on one baseline: **her** on the left, **her hand** in the middle,
**the ship** on the right. The objective and the lanes merged into one plate,
because they are one answer to one question — how is the ship doing.

The side plates take whatever is left after the hand rather than a fixed width,
clamped to 250–350. Three clusters at their preferred sizes want 1258 px; below
that they either shrink or they overlap, and a HUD that overlaps itself on a
1152-wide window is a bug, not a hardware requirement. Asserted at six window
sizes by the layout matrix in the harness, driven off `SkyGearHUD.hud_plates`
so the check cannot drift from what is drawn.

## 2. What it is made of now, and what is wrong with it

| Piece | Now | Problem |
| ----- | --- | ------- |
| Panels | `draw_rect` fill + ink edge + brass inlay + 4 rivets | Code-drawn. Reads as a wireframe of a HUD, not a HUD. |
| Portrait bezel | `gauge_ring.png` | Correct, and the best-looking thing on the bar. |
| Health / Boiler bars | Two rects + capped tick marks | Flat. No cap, no end, no housing. |
| Pressure gauge | A thin rect with an icon watermark | The most important v11 mechanic is the least legible element. |
| Dash pips | `draw_circle` | Fine, but unrelated to everything around it. |
| Skill slots | Panel + tinted glyph + cooldown wipe | The wipe is a grey rect. |
| Lane tracks | Rects with a marker | Reads well. Keep the layout, paint the housing. |

The pattern: **the layout is right and the material is code.** Every panel in the
browser build is a painted plate; here they are rectangles that approximate one.

## 3. The theme, stated once

The ship is brass, iron, oxblood leather and dark timber, lit by a steel-blue
moon from the upper left and warm lantern amber from the lower right. The HUD is
**instrumentation bolted to that ship** — not a transparent overlay, not a fantasy
scroll. Everything on it should look like it was riveted on by the same crew who
lashed the cargo.

Concretely, every piece generated below:

- Brass housing with visible rivets and honest wear at the corners.
- Dark iron or smoked-glass interior where a value is displayed.
- Oxblood leather backing where something is held rather than read.
- **No text, no numerals, no icons in the plate art.** Text is drawn by the
  engine so it can be localised, and a number baked into a bezel is a number
  that is wrong for every other value.
- Authored **straight-on**, not in the deck's three-quarter view. This is the one
  place the camera bake does not apply — a HUD in perspective is a HUD you cannot
  read.

## 4. The pieces to generate

Nine, in the order they change how the bar reads. Prompts live in
`tools/forge.py` under batch `hud`, so a change to the look is a change in one
place. Style suffix `UI` (straight-on, flat, no perspective) rather than
`BILLBOARD`.

| Key | What | Size | Why it is on the list |
| --- | ---- | ---- | --------------------- |
| `ui_plate_wide` | The side-cluster housing: brass frame, riveted corners, dark smoked interior, 9-slice safe | 512×256 | Replaces `draw_rect` on the two biggest plates. Biggest single change. |
| `ui_plate_slot` | One skill slot: square brass bezel with a dark recess and a keycap tab at the top | 256×256 | Four on screen at all times. |
| `ui_bar_housing` | An empty gauge housing: brass channel with end caps and rivets, hollow middle | 512×64 | Health and Boiler both sit in it. |
| `ui_bar_fill_hot` | The fill: molten orange with a lit top edge, tileable horizontally | 256×64 | Health. |
| `ui_bar_fill_cold` | The same in verdigris teal | 256×64 | The Boiler. |
| `ui_pressure_dial` | A round pressure dial face: iron, brass bezel, a red danger arc across the last third, tick marks, **no needle and no numbers** | 256×256 | The v11 mechanic that is currently a thin rect. Needle drawn by the engine. |
| `ui_cooldown_sweep` | A radial sweep mask, white on transparent, a clock wipe | 256×256 | Turns the grey cooldown rect into a sweep. |
| `ui_dash_pip` | A single charge pip: brass ring, glass centre, lit and unlit implied by one image tinted | 64×64 | Ties the dash to the rest of the bar. |
| `ui_lane_track` | A lane channel: iron rail with brass end stops, hollow | 256×32 | Three on screen; the readout that matters most. |

**Not generated:** the portrait bezel (`gauge_ring.png` already works), the title
banner (`frame_hud.png`, now used at the size it was authored for), and every
skill glyph (nine already delivered).

## 5. How they get used

- `_panel()` becomes a 9-slice draw of `ui_plate_wide`. Godot's
  `draw_texture_rect_region` cannot 9-slice, so the HUD gets a small
  `_nine(texture, rect, margin)` helper — nine `draw_texture_rect_region` calls.
  Corners unscaled, edges stretched on one axis, middle on both.
- `_bar()` draws `ui_bar_housing` 9-sliced, then the fill clipped to the value,
  then the ticks on top. The fill is tileable so a long bar does not smear.
- The pressure gauge becomes the dial: plate, then a needle drawn as a rotated
  line from the centre, then the vent icon lighting up when it is full.
- The cooldown wipe becomes `ui_cooldown_sweep` drawn with a rotated region — or,
  simpler and exactly as legible, the existing bottom-up wipe masked by the
  sweep's alpha.

## 6. Order

1. `ui_plate_wide` + `ui_plate_slot` + the `_nine` helper. Six panels stop being
   rectangles; this is most of the change.
2. `ui_bar_housing` + the two fills. Health, Boiler and the three lane tracks.
3. `ui_pressure_dial`. The mechanic that most needs it.
4. `ui_cooldown_sweep`, `ui_dash_pip`, `ui_lane_track`. Polish.

Each step is shippable on its own, and each falls back to what is drawn now if
the art is not there — the same rule the animation strips follow, and the reason
the port can ship at any point in the middle of an art pipeline.
