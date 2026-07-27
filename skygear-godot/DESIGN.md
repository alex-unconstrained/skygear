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
| Movement, aim, camera | implemented | run in Godot editor |
| Basic attack and active skills | implemented | matrix test scene |
| Enemy melee/ranged behavior | implemented | wave-one playtest |
| Boiler and loss state | implemented | automated damage test |
| Dash and pressure vent | implemented | close/range assertions |
| Reactive props | implemented, reduced layout | full v11 layout |
| Draft | implemented, simplified cards | migrate all 37 cards |
| 12-wave campaign | data present; boss uses temporary heavy behavior | dedicated boss patterns |
| Push waves, crew, boarding hulk | not yet ported | Milestone 2 |
| Audio | key runtime SFX copied, basic playback wired | buses/music/voice director |
| Animation strips | copied, not yet wired | SpriteFrames importer |
| Settings, rebinding, seed, run report | not yet ported | Milestone 3 |
| Automated parity harness | not yet ported | headless GUT/native tests |

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

