# Rollback

Revert only the SG-207 hunks in these tracked files:

- `scripts/game_data.gd`: remove `PULSE.cast_advance`.
- `scripts/game.gd`: remove `pulse_period`, `pulse_time_left`, and `advance_pulses`, plus the Beam-start, regular-cast, and successful-manual-Sentry advance calls.
- `scripts/hud.gd`: restore the ordinary cooldown-only face path for skill slots.
- `tests/parity_test.gd`: remove `_pulse_cadence`, its two helpers, and the call from `_run()`.

Rollback point is serialized baseline `d123e88`; development was performed from cursor `d968499`. Reverting SG-206 invalidates all SG-207 evidence. No save migration, generated asset, package, board row, or external state was changed by this worker.

The evidence-only deletion mutation was fully restored. `full-harness-final.log` is the post-restore proof; no negative-test hunk remains in tracked code.
