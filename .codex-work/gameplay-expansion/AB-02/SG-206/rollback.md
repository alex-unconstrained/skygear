# Rollback

Revert only the SG-206 hunks in these tracked files:

- `scripts/game_data.gd`: remove the AURA anchor schema fields.
- `scripts/game.gd`: remove the three Field API functions, wave reset call, ordinary-cast/Beam/manual-Sentry relocation calls, and restore the AURA tick center to `player.global_position`.
- `scripts/view3d.gd`: restore the AURA render center to `game.player.global_position`.
- `tests/parity_test.gd`: remove `_field_anchor()`, `_field_game()`, and the call from `_run()`.

Rollback point is baseline `f9aa3b2`. No other packet, save migration, generated asset, package, or external state must be reverted.

