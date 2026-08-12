# SG-207 / AB-03 dispatch

- Development cursor: `d968499`
- Serialized baseline: `d123e88` (SG-206 implementation record)
- Design authority: gameplay expansion design §17.3
- Allowed tracked files: `scripts/game_data.gd`, `scripts/game.gd`, `scripts/hud.gd`, cards/view only if required, and `tests/parity_test.gd`
- Files used: `scripts/game_data.gd`, `scripts/game.gd`, `scripts/hud.gd`, `tests/parity_test.gd`
- Frozen values: Pulse damage 34.0, radius 210.0, raw cooldown 4.4; derived period remains 3.52 in the fixture
- New authored value: `cast_advance: 0.35`
- Stop conditions audited: no authority conflict, physical mismatch, save change, or out-of-scope dependency found
- Release hold: SG-207 is a development-only measured stack until SG-206 and SG-207 receive human G5 verdicts.

Required behavior delivered: Pulse remains passive and keyless; its simulation timer is the only scheduler and visible countdown source; accepted Beam advances once at channel start; ordinary and multishot casts advance after their final Field landing and cooldown; successful manual Sentry advances after placement and Field relocation; kill-autofire advances through its one real cast; rejected, passive, basic, automatic/refused Sentry, Beam completion, and Beam cancellation do not advance. Accumulated advance floors at `-derived_period + 0.001`; the public reader displays due-now as zero while the raw scheduler retains negative remainder.

Deletion proof: replacing the shared `advance_pulses()` behavior with a no-op made exactly six Pulse advance/timing checks red while the other 1,181 checks, zero-script-error gate, and pinned engine-error gate stayed green. Restoring the exact candidate returned the final harness to 1,187/1,187.
