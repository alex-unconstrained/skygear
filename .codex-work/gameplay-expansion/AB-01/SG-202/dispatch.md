# SG-202 dispatch — AB-01 Beam channel

## Authority and baseline

- Owning packet: AB-01, design §17.1.
- Board owner: SG-202, Codex/coordinator.
- Baseline and collision-queue cursor: `af7d8ce76c16f9f405c6aa646b05e4d831a565a4`.
- Requires: BASE-00 accepted at `0a6d34a`.
- Attribution-v1 artifacts remain immutable under BASE-00.
- Replay baseline:
  `.codex-work/gameplay-expansion/AB-01/pre-baseline/`, independently
  reproduced at the safe queue head under `pre-baseline-safe-head/`.
  Both canonical trace files have SHA-256
  `455719CB4ACC146A15FB2631CB93D5BC3802252E8A0DA648B604D21B416C1F24`.

## One packet

Implement design §17.1 exactly. Beam becomes a 0.36-second, four-tick channel
at elapsed 0.00, 0.12, 0.24 and 0.36. Seven damage per tick preserves 28 base
damage. Add no Beam damage tuning, no other shape work, no element-reaction
redesign and no neighboring cleanup.

The pre-baseline found `enemy.spawn_serial` declared but never assigned.
AB-01 must assign a unique serial to every spawned enemy through the production
spawn path before that field is used for the per-channel element-once map.
Aliasing live bodies to serial zero is a stop failure.

## Allowed files

- `scripts/game_data.gd`
- `scripts/game.gd`
- only the element-entry/serial guard in `scripts/enemy.gd`
- `scripts/player.gd`
- `scripts/view3d.gd`
- `scripts/telemetry.gd`
- focused tests
- one forced Beam visual probe

Do not touch wave data, Muster, other abilities, card values, Workshop,
fittings, save schemas or unrelated renderer paths.

## Exact checks and invariants

Add every verbatim `beam ·` check listed in design §17.1. The timer/status
fixtures must cover 1/60, 0.05, a 0.40 multi-tick catch-up step, cancellation,
pause, hit-stop, reset, wave completion and death. Existing damage, crit,
attribution, RNG, save and ability checks remain green.

The production invariants are the full §17.1 contract: one cast/cooldown/
Overpressure spend; independently delivered primary ticks; one selected-element
application per accepted body/serial/channel; Beam crit explosion forwards the
map but a synchronous kill explosion receives null; live aim may turn while an
explicit Vector2 stays fixed; ordinary walking is 0.60; dash/jet cancel; no
other active/basic re-entry; hulk splash and Residue resolve once on completion;
renderer reads simulation channel state and endpoint; no presentation timer.

## Predeclared evidence

- **Primary statistic:** primary Beam damage delivered over the full 0.36-second
  channel to the scripted laterally moving target.
- **Arms:** production live aim
  (`set_cursor_ground → player._update_aim → cast_skill(0)`) versus production
  explicit locked target (`cast_skill(0, Vector2)`).
- **Feature-off/before seam:** the immutable instant-Beam trace captured before
  implementation at the baseline SHA above; it is not a permanent runtime flag.
- **Sample:** BEAM1…BEAM120, 120 distinct paired trajectories, one observation
  per seed. Repetition is a determinism audit only.
- **Resolution/pass:** the paired live-minus-locked mean must be positive and
  larger than its printed paired 95% half-width; the live arm must retain the
  complete 28 base damage on the full-stay control, while the locked arm's loss
  comes only from the scripted target leaving its fixed line. Report delivered
  hits/damage, selected-element applications, status/reaction damage and
  crit-explosion damage separately.
- **Permitted tuning:** none.
- **G4:** one forced clip must show readable start, held line and release; exact
  simulation endpoint; zero probe noise.
- **G5:** after a clearly labelled candidate is on itch, Alex must be able to
  state that Beam asks for aim commitment, slows ordinary walking, and can be
  abandoned with dash/jet. Record the named verdict before merge/release.

## Stop condition

Stop and file a separate defect if a unique per-spawn serial cannot be assigned
inside the allowed production path; any timer-matrix member fails; an unrelated
check regresses; RNG/save state moves; the G3 paired effect does not clear its
printed resolution; the 28-damage full-stay control moves; status/reaction or
crit-explosion damage dominates unexpectedly; the visual probe has nonzero
noise; another file or balance number is required; or the human cannot name the
decision/counterplay. Do not repair another packet in place.
