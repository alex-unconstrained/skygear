# SkyGear Godot port — living design document

Last updated: 2026-07-27  
Reference target: SkyGear v11 (`storm-dusk-v11.html`)  
Port status: Milestone 1 — playable combat vertical slice

## 1. Intent

Rebuild the latest shipped SkyGear in Godot while preserving the browser game
as an untouched reference. The port should retain the identity of the source:
a single-player, top-down steampunk hero-defense where a Sky-Corsair protects
the Boiler across twelve boarding waves and drafts shape × element skills.

The port is intentionally isolated in `skygear-godot/`. It never loads files
from `../assets`, `../audio`, `../src`, or the generated HTML build. Needed
inputs are copied into `reference/` or `assets/` before use.

## 2. Pillars carried forward

1. Keep the Boiler alive.
2. Movement and aim must feel immediate.
3. Skills are a true shape × element matrix, not bespoke one-offs.
4. Lane commitment creates strategy, while cross-passages preserve mobility.
5. Close-range risk earns pressure, healing, and dash tempo.
6. Enemy attacks are readable before they are dangerous.
7. The deck participates through destructible ordnance and salvage.

## 3. Target loop

Title → opening weapon draft → fight → wave clear → upgrade draft → next wave
→ boss → victory/results. Player death or Boiler destruction ends the run.

The fixed basic attack is Ember Cleave. Four ability slots use LMB, RMB, Q, and
E. Dash starts with two charges. Between waves, one of three cards is chosen.

## 4. World and camera

- World: 1900 × 2560 source-space envelope.
- Deck: 1680 × 2320, with three lanes and three cross-passages.
- Boiler: stern objective, 500 HP.
- View: bounded follow camera, top-down in Milestone 1. A later visual pass may
  restore the browser renderer's 41° projection while keeping gameplay in 2D.
- Art: production PNGs are used by actors and props; procedural deck geometry
  ensures the game remains legible while scene composition is rebuilt.

## 5. Combat data

Shapes:

| Shape | Player-facing name | Milestone 1 |
|---|---|---|
| CLOSEHIT | Cleave | implemented |
| LINE_BURST | Lance | implemented |
| CONE | Gale | implemented |
| RANGED_AOE | Mortar | implemented |
| CHAIN | Whip | implemented |
| RAY | Beam | implemented as a short channel burst |
| AURA | Field | data + draft; runtime tick implemented |
| PULSE | Pulse | data + draft; runtime auto-cast implemented |
| SENTRY | Sentry | data + draft; placeholder passive bonus |

Elements:

| Element | Effect |
|---|---|
| Ember | stacking damage-over-time |
| Frost | movement slow |
| Arc | stun chance; extra chain reach |
| Steam | stronger knockback |

The browser game exposes 9 shapes × 4 elements = 36 cells. The port stores all
36 combinations and keeps element application centralized.

## 6. v11 close-quarters loop

Milestone 1 uses the shipped v11 contract:

- close range: 210;
- pressure from close damage: 0.85 per damage;
- passive pressure: 6/s while at least two enemies crowd the captain;
- pressure decay: 14/s after 1.2 seconds out of danger;
- vent at 100: radial damage, knockback, heal, reset;
- close kills can drop salvage and refund dash time;
- two dash charges, 1.0s recharge, 30 contact damage.

The copied source contains later unshipped tuning edits in the working tree.
Milestone 1 uses the documented v11 values where the shipped plan and working
source differ; a parity harness will settle exact numbers before release.

## 7. Reactive deck

- Steam keg: 34 HP, 0.45s visible fuse, radial damage and knockback. It can hurt
  the captain and can light another keg.
- Crate: breaks into healing salvage.
- Lantern/brazier: breaks into a temporary fire pool.
- Props are recreated at each wave start.

Milestone 1 uses a reduced representative prop layout. Full v11 placement is a
planned data migration.

## 8. Architecture

| File | Responsibility |
|---|---|
| `scripts/game.gd` | run state, waves, combat queries, skills, props, pressure |
| `scripts/game_data.gd` | immutable shapes, elements, enemies, waves, draft data |
| `scripts/player.gd` | CharacterBody2D input, dash, health, camera-facing state |
| `scripts/enemy.gd` | enemy movement, telegraphs, melee/ranged attacks, statuses |
| `scripts/prop.gd` | destructible prop state and signals |
| `scripts/hud.gd` | title, HUD, pause, drafts, results |
| `scenes/*.tscn` | explicit Godot scene composition |

Simulation is ordinary Godot 2D physics. Gameplay boundaries are computed in
world space and remain independent of sprite dimensions.

## 9. Milestone status

| System | Status | Next proof |
|---|---|---|
| Isolated project and copied references | complete | hash manifest |
| Movement, aim, camera | implemented and smoke-tested | hands-on playtest |
| Basic attack and active skills | implemented | matrix test scene |
| Enemy melee/ranged behavior | implemented | wave-one playtest |
| Boiler and loss state | implemented and smoke-tested | hands-on balance pass |
| Dash and pressure vent | implemented and smoke-tested | hands-on balance pass |
| Reactive props | implemented, reduced layout | full v11 layout |
| Draft | implemented, simplified cards | migrate all 37 cards |
| 12-wave campaign | data present; boss uses temporary heavy behavior | dedicated boss patterns |
| Push waves, crew, boarding hulk | not yet ported | Milestone 2 |
| Audio | key runtime SFX copied, basic playback wired | buses/music/voice director |
| Animation strips | copied, not yet wired | SpriteFrames importer |
| Settings, rebinding, seed, run report | not yet ported | Milestone 3 |
| Automated parity harness | 13-check native smoke test passing | expand to deterministic parity suite |

## 10. Verification policy

No parity claim is made from inspection alone. Each milestone should add a
headless test scene that checks combat cells, wave termination, both loss
conditions, prop chain reactions, pressure distance rules, healing ceilings,
and deterministic seeded runs. Visual verification should cover 1280×720
through 2560×1440.

## 11. Change log

- 2026-07-27: Created isolated Godot project and copied the v11 HTML, modular
  source snapshot, key design references, production runtime art, and `.ogg`
  SFX. Added Milestone 1 architecture and playable systems.

- 2026-07-27: Passed the 13-check headless smoke suite, exported and launch-tested
  the Windows release with Godot 4.7.1, and uploaded version `milestone-1` to
  itch.io channel `alex-unconstrained/skygear-godot-test:windows` (build
  `#1837384`).

## 12. Target and renderer — decided 2026-07-27

**Windows first, hardware accelerated.** The project was on
`gl_compatibility`, which is the renderer a web export wants; the target is now
a native Windows build on **Forward+ (Vulkan)**. That is the only path that
gives 2D lighting, real batching and shaders — which is the whole reason to be
in an engine rather than in the Canvas 2D build that already exists and is
further along.

Consequences, stated so they are not rediscovered:

- The itch artifact is `SkyGear-Windows.zip` (a single embedded-pck .exe,
  129 MB uncompressed, 59 MB zipped), built by `tools/pack_itch.py`.
- There is no web export and no web export template installed. Adding one later
  means downloading ~1 GB of templates and switching the renderer back for that
  preset, and it would produce a strictly worse artifact than the browser build
  that already exists.
- Forward+ needs Vulkan. On hardware without it Godot falls back and logs; that
  is an accepted cost of choosing acceleration over reach.

## 13. Parity with the browser build, as of 2026-07-27

Verified by `tests/parity_test.gd` — **40 checks, all passing**:

```
godot --path . --headless --script tests/parity_test.gd
```

They are the browser harness's claims, re-asked here: every one of the 36
shape x element cells deals damage; pressure builds in close and only in close;
a full gauge vents, heals, hits and does not refill itself; no burst of healing
beats the 12 hp/s ceiling; lifesteal heals in close and nowhere else; a keg
lights a fuse rather than detonating and its blast lands on what stands in it;
the deck is re-stowed between waves; a cannon gates each lane and fires on the
boarder in it; a boarder attacks the cannon in its way; crew muster; a push wave
grapples a hulk on and does not end until it breaks; every card declares what it
touches; reroll spends one, deals a new hand and stops at zero; a seed deals the
same hand twice and a different seed does not; the Colossus turns at half
health, cannot be burst through the turn, clears what it called, and comes out
of it; damage is attributed to the slot that fired; and all three endings
resolve.

**In:** the twelve-wave schedule, three lanes with cargo walls, deck cannons,
crew, boarding hulks and push waves, the Boiler, the automatic Cleave, nine
shapes crossed with four elements including the three passives, per-skill mods
and resolved stats, the full draft (41 cards across seven scopes, class bands,
affected-skill glyphs, reroll, adaptive slot weighting, seeded rolls),
telemetry with slot attribution and range buckets, the close-quarters loop at
v11.2 numbers, reactive kegs, crates and lanterns, salvage, dash with two
charges and contact damage, readable enemy bolts, the boss's two beats, and a
results screen that is the copyable run report.

**Not yet:** settings and persistence (volume, key rebinding, reduced motion,
the run log); audio beyond one-shot SFX — no music director and no voice layer;
and the presentation pass the browser build has (airstream, camera-tied
envelope, bolt ground shadows and trails, painted billboards rather than
primitives, HUD gauges with art). The browser build also still has 29 checks
this harness does not: layout across resolutions, storage denial, slow-line
loading, the frame budget, and the audio-node leak guard.

## 14. Known differences that are deliberate

- **Enemy separation** is Godot's own physics rather than the browser's hand-
  written pass, so crowds spread differently. The browser's numbers were tuned
  against its own solver and porting them literally would be cargo cult.
- **The deck is 1680 x 2320 in world units and lanes sit at -560/0/560**, which
  matches v11 rather than the browser's current geometry helper. Any future
  change to lane width has to move both.
- **No web export.** Windows first, Forward+, see section 12.
