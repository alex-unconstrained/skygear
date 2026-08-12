# AB-01 pre-implementation moving-target trace audit

Captured 2026-08-04 with the coordinator queue at
`6ff512d96f0b92612481008cb6a141fc40ac3238`. The workspace also carried the
claimed SG-201 Muster candidate; its edits did not touch the Beam/aim/damage
call chain used here. A new one-repetition replay at safe queue head
`af7d8ce76c16f9f405c6aa646b05e4d831a565a4` reproduced the canonical trace
byte-for-byte under `../pre-baseline-safe-head/`.

## Commands

From `skygear-godot`:

```powershell
godot --path . --headless --script builds/evidence/beam_trace.gd -- 120 2 res://../.codex-work/gameplay-expansion/AB-01/pre-baseline
godot --path . --headless --script builds/evidence/beam_trace.gd -- 120 1 res://../.codex-work/gameplay-expansion/AB-01/pre-baseline-rerun
godot --path . --headless --script builds/evidence/beam_trace.gd -- 120 1 res://../.codex-work/gameplay-expansion/AB-01/pre-baseline-safe-head
```

The tool is ignored by `skygear-godot/.gitignore` through `builds/`; its
SHA-256 at capture was
`D8541D557C5BC9438CB1560B22F68BF423AF6506590DCF6D5A1097E6397DC286`.

## Result

- 120 distinct seeds, BEAM1 through BEAM120.
- Two paired arms per seed: live aim and explicit Vector2; 240 canonical rows.
- Two repetitions in the primary invocation; effective n remains 120 per arm.
- Zero within-seed/arm divergences.
- Independent one-repetition invocations, including the safe queue head,
  reproduced `traces.jsonl` byte-for-byte.
- Trace SHA-256:
  `455719CB4ACC146A15FB2631CB93D5BC3802252E8A0DA648B604D21B416C1F24`.
- Shipped Beam delivered exactly 28 damage, one hit, one cast and one Ember
  application in every arm/seed. `active_channel` is absent on this baseline.
- Live aim geometry intersected the moving target in 120/120 traces at every
  sample.
- Explicit direction intersected at t=0 in 120/120, at t=.12 in 79/120 and at
  t=.24/t=.36 in 0/120.

This is a replay baseline, not a current live-versus-explicit effect claim:
shipped Beam resolves wholly on press, so later aim samples cannot change
current damage. After AB-01, the same input rows test the scheduled ticks
without changing trajectories.

## Exact production seam

- `SkyGearGame.set_cursor_ground(Vector2)` supplies the 3D cursor ground point.
- `SkyGearPlayer._update_aim()` copies `game.aim_target()` into
  `player.aim_direction`; omitting this does not reproduce the production
  no-argument cast seam.
- `SkyGearGame.cast_skill(0)` selects live aim on press.
- `SkyGearGame.cast_skill(0, explicit_target)` selects the fixed-target arm.
- Current Ray resolves through `_resolve_cast() → _damage_line() →
  _distance_to_segment() / damage_enemy() → SkyGearEnemy.take_damage()` and
  `SkyGearTelemetry.note_damage()`.
- Between scheduled positions, replay calls `game._process(delta)` while
  engine, player and enemy physics are disabled. The target is written manually
  before each accepted simulation delta.

## Machine-readable schema

Each `traces.jsonl` row contains identity, trajectory inputs, Ray stats, the
shipped press endpoint, totals, RNG states, channel-property presence, four
sample rows and a SHA-256 fingerprint over the canonical row. Each sample stores
elapsed time, target, selected aim, computed endpoint, exact line distance,
geometry eligibility, HP, slot attribution and channel presence.

`summary.json` records requested distinct seeds, arms, canonical row count,
repetitions, effective n, the no-inflation rule, determinism verdict,
divergences, arm means and exact caller/step contract.

## Blockers and use limits

1. `SkyGearEnemy.spawn_serial` exists but is never assigned on this baseline.
   AB-01 must establish a unique per-spawn serial before using it as the
   per-body element-once key; otherwise every live body aliases serial 0.
2. Current Beam has no channel, so this baseline cannot itself measure
   between-tick turning. It freezes deterministic inputs and the shipped t=0
   result for a post-implementation replay.
3. Crit chance is forced to zero to make geometry/damage replay exact. This
   fixture does not satisfy AB-01's G3 breakout of status/reaction and
   crit-explosion damage.
4. The live arm must call `player._update_aim()` after every
   `set_cursor_ground()`. Production physics normally performs that copy
   before skill input.
