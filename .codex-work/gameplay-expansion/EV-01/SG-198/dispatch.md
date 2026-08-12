# SG-198 dispatch — EV-01 deterministic encounter grammar

## Authority and baseline

- Design authority: `docs/GAMEPLAY-EXPANSION-DESIGN-2026-08-04.md` §16.2,
  with §§13–15 for shared contracts.
- Execution authority:
  `docs/GAMEPLAY-EXPANSION-IMPLEMENTATION-PLAN-2026-08-04.md`.
- Baseline and serialization cursor: `6e5c9a1`.
- Prerequisite: BASE-00 accepted as SG-196.

## Allowed files

- new `scripts/muster.gd`
- `scripts/game.gd`
- focused additions to `tests/parity_test.gd`
- `scripts/game_data.gd` only if a shared authored table proves necessary

No other project file is authorized. Coordinator evidence may be written below
this ignored packet directory. Stop on any contract conflict, RNG/save mutation,
undeclared file, or unrelated red check.

## Required invariants

- Muster is a pure helper with its own locally seeded RNG; planning consumes
  neither gameplay nor visual RNG and writes no save.
- All twelve immutable plans are cached only after run seed and Heat resolve.
  A tool-time on-demand plan must match the cached bytes.
- Event, push and boss waves remain authored. Heat 4 closes waves 6 and 10.
- Feature-off seam `SKYGEAR_MUSTER_FLAT` returns every authored queue
  byte-for-byte.
- Final queues keep only `time`, `type`, and `lane`; stable sort is time,
  source, lane, member before transient keys are stripped.
- Only design §16.2's finite substitutions are legal, with at most two type
  substitutions and two lane reassignments and a ±10% expanded-lane budget.
- Existing spawn cap, wave timing, event logic, Heat values, cards, Workshop,
  fittings and enemy behavior do not change.

## Verbatim focused checks

1. `muster · feature-off deals every authored queue byte-for-byte`
2. `muster · the same seed and Heat deal the same twelve plans`
3. `muster · planning consumes neither gameplay nor visual RNG`
4. `muster · events, pushes and the boss stay authored`
5. `muster · Heat 4 closes waves 6 and 10 to mutation`
6. `muster · every emitted type and lane exists`
7. `muster · every changed wave stays inside the ten-percent budget`
8. `muster · every named grammar satisfies its own postcondition`
9. `muster · at least two plans differ across twenty-four fixed seeds`
10. `muster · deleting the planner call makes the variation check fail`

## Frozen G3 contract

- Primary: absolute lateral ground travelled by the Captain during wave 6.
- Arms: forced PINCER versus forced ASSAULT at identical Heat 0, class, draft,
  fittings and bot for `BAL1…BAL120`.
- Effective sample: 120 distinct seeds, one observation per seed; repetitions
  are one and never increase n.
- Behavioral pass: mean changes by at least 10% and the targeted tool's 95%
  comparison clears its printed resolvable effect.
- Difficulty arm: live Muster versus `SKYGEAR_MUSTER_FLAT`, same seeds.
- Difficulty pass: absolute held-rate delta no more than 9 percentage points.
- Permitted tuning: none. Same-seed variation is instrument failure.
- Failure: retain the report and cut Muster through the flat seam.

## Required evidence

Exact commands; focused red/green and negative-control output; full G0 output;
machine-readable G1/G2 plan, queue, RNG and save findings; G3 raw distinct-seed
rows plus printed statistic/resolution/verdict; changed-file audit; rollback
instructions. G4 and G5 are not required for this packet.
