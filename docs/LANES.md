# v5 — the MOBA lane restructure

v4's feel, on a lane map. Built to the four answers you gave: three
hard-separated lanes, turrets **and** crew holding them, some waves push and
some hold, mostly-lane spawning with occasional rail boarders.

Shipped as v5 rather than folded into v4 so v4 stays a clean "responsiveness"
milestone you can still compare against.

## Topology

```
                    THEIR BOARDING HULK  (nexus, 3200 HP)
        ▲▲▲                ▲▲▲                ▲▲▲
   ┌──────────┬───────────────────┬──────────┐
   │   PORT   ██     CENTRE      ██ STARBOARD│   cargo runs, solid
   │          ██                 ██          │
   │  ← ← ← ← ←  cross-passage  → → → → →    │   you rotate here
   │          ██                 ██          │   (boarders never do)
   │   ╦ cannon    ╦ cannon    ╦ cannon      │   620 HP each, gate the lane
   └──────────┴───────────────────┴──────────┘
                  ▓▓ BOILER ▓▓                    the stern. What you lose by.
```

- **Lanes are hard-separated** by cargo runs drawn as projected boxes. One
  cross-passage opens amidships so you can rotate; **boarders and crew are
  lane-locked and never use it**, so committing to a lane means something.
- **The base** — the rear of the deck — is open across all three, which is how
  you get between lanes without the passage.
- **Deck cannons** auto-fire at whatever is nearest the Boiler in their lane
  (430 range, 26 dmg, 1.15s). Boarders stop and break them to advance. Lose one
  and that lane is open — you get a banner and the lane readout flags it.
- **Your crew** spawn three per lane every 7.5s, push up-lane, and fight
  whatever they meet. They are what holds a lane you are not standing in.
- **Target priority for boarders**: the captain if she is close → crew in the
  way → the lane's cannon → the Boiler.

## Hold waves and push waves

Waves 4, 8 and 12 are **pushes**: the hulk's plating opens, it takes damage, and
breaking it ends the wave. Everything else is a hold. Pushes keep spawning
reinforcements the whole time, so leaving the Boiler is a real cost.

The banner reads *THEIR PLATING IS OPEN — BREAK THE HULK*, and a hulk health bar
appears under the wave panel only while it is vulnerable.

## Reading three lanes at once

You can only be in one, so the lane readout (top right) is the minimap
equivalent. Per lane: name, a live count of boarders, a dot showing how far the
furthest one has pushed toward the Boiler, and the cannon's health as a teal
stub. The lane you are standing in is highlighted.

## What is new in code

`_lanes.js` (simulation) and `_render_lanes.js` (walls, cannons, crew, hulk,
readout). Both are inert unless `PRESET.lanes`, so classic / v2 / v3 / v4 are
untouched. The arena is now fully parameterised — width, centre, radius, depth
and objective position all come from the preset — so a lane map can be wider and
deeper than a duelling deck without forking the core again.

## Known and deliberate

- **Balance is untuned.** v5 inherits v4's shorter cooldowns and free auto-attack
  damage, and now also has cannons and crew fighting for you. Expect it to be
  easy. The wave table is authored but the numbers have had no pass.
- **No draft cards touch lanes yet.** Cannon repair/upgrade and crew buffs are
  the obvious additions and none exist.
- **Solid props are filtered out of lane interiors** — a mast in the middle of a
  lane is a wall you cannot see coming. Dressing now only survives near the
  walls and in the base.
- **The 66-asset manifest does not cover this map.** Lanes need a cargo-wall run,
  a crew character (front/back/attack) and the hulk. The deck cannon is now a
  gameplay object with a destroyed state, not set dressing.
