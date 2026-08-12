# SG-206 / AB-02 dispatch

- Baseline: `f9aa3b2`
- Design authority: gameplay expansion design §17.2
- Allowed tracked files: `scripts/game_data.gd`, `scripts/game.gd`, `scripts/view3d.gd`, HUD/card copy only if required, `tests/parity_test.gd`
- Files used: `scripts/game_data.gd`, `scripts/game.gd`, `scripts/view3d.gd`, `tests/parity_test.gd`
- Frozen values: Field damage 4.0, radius 150.0, tick rate 1.8; Beam behavior and argument order unchanged
- Stop conditions audited: no authority conflict, physical mismatch, or out-of-scope dependency found
- Manual Sentry rule: relocation occurs after successful append only. Ally-cap refusal returns before this point and therefore cannot relocate Field.

Required behavior delivered: per-AURA anchor schema and API, live unset fallback, all authored active landing conventions, normal-only Beam completion, manual-only Sentry placement, post-multishot publication, passive-only following, wave reset, shared simulation/render center, and deletion-sensitive damage behavior.

