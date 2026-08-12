# SG-205 rollback

Rollback point: `e870b6a`.

Revert the future coordinator commit containing only:

- `skygear-godot/scripts/game.gd`
- `skygear-godot/scripts/enemy.gd`
- `skygear-godot/scripts/telemetry.gd`
- `skygear-godot/tests/parity_test.gd`

`scripts/cards.gd` was not changed. No save migration, asset, build, or user
file needs reversal. Retain this evidence directory and the damage-attribution
v1/v2 reports when rolling back; later combat packets must also roll back if
they have begun consuming attribution v2.

