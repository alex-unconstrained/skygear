# BASE-00 RNG and save findings

- All 72 `_build_spawn_queue()` fixtures left `rng.state` and
  `visual_rng.state` unchanged. Exact before/after strings are retained in
  `queue-fixtures.json`.
- The measurement fixture replaces the loaded workshop with
  `SkyGearWorkshop.fresh(true)` before beginning a run.
- `game.log_runs` is false for measured and visual runs. No run history,
  workshop, setting or player save was written.
- BASE-00 added no data field, owner, reset path or reader.
- No player-facing copy changed.
