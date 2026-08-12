# SG-203 verdict — FAIL / CUT

SG-203 did not satisfy its predeclared pass rule and must not unblock EL-00.
This result is retained rather than repaired in place.

## What passed

- The copied BASE-00 production bot, policy, 0.05-second integrator and excluded
  warm-up completed `BAL1` through `BAL120` exactly once: requested 120,
  distinct 120, effective n 120.
- Separate repeats of BAL1 and BAL2 were determinism audits only. Both repeat
  fingerprints matched; neither repeat entered the population or inflated n.
- The accepted AB-01/Beam implementation was the feature-off cursor. No project
  file differs between `508523c` and coordinator HEAD in `scripts/`, `tools/`,
  `tests/`, or `scenes/`.
- The corrected BAL2 arm set `game.auto_element = "FROST"` before `begin_run`.
  Its final equipped elements were Frost, Frost, Frost, Steam, Frost. There was
  no equipped/auto Ember source and no BURN reaction row.

## What failed

The true-non-Ember BAL2 arm observed five distinct enemies acquire one burn
stack. `result.json` therefore records
`true_non_ember_never_acquired_burn: false` and overall `FAIL`. The main fixture
exited with script status 1 and printed the same failing check in `fixture.log`.

This is not a Frost-selection failure. The read-only `source_probe.gd`
reproduced exactly five acquisitions and located all five immediately after
production `game._process` ticks:

- two in wave 7 while fire field 611 was live at `(-610, -100)`;
- two in wave 8 while fire field 680 was live at `(620, -420)`;
- one in wave 11 while fire field 1248 was live at `(620, -420)`.

Those are the two authored lantern positions in `game_data.gd`. Destroying a
lantern creates a production fire field, and `_update_fire_fields()` applies its
tick with element `EMBER`. The diagnostic also records `kill_explode: 0.0` for
every acquisition, excluding the other plausible non-equipped Ember path.

The predeclared rule said **no target ever acquires burn**, not merely “no
equipped weapon applies burn.” A full production BAL2 run with intact props
therefore cannot be accepted as the requested stable control. Disabling props,
clearing fire fields, changing the seed, or weakening the assertion here would
redefine the claimed arm after seeing the result. None was done.

Coordinator action: CUT SG-203 and claim a separately scoped evidence-fixture
repair if a controlled non-Ember arm is still required. Do not treat the report
named `damage-attribution-v1-true-non-ember.txt` as an accepted control; its
header visibly records the five acquisitions.

## Artifact hashes

- `sg203_fixture.gd`: `75AB8CB2D0FF3E3505C736B81B47A79684FA6920A23D3552139BF837EA4B56F7`
- `source_probe.gd`: `30029286231C3177E79C83A2A23BA7B4BBA0E3E68F599350C2575F0297DF5736`
- `feature-off-120.json`: `65F183243A8912D1D8005464EF9B2627E19BB4E6BF5D2D90A6C937A9794C3C7A`
- `result.json`: `585F0CEF8795952F52DA56E55C35AD29F22FF9BF307EDCFECDE3CDB80483712C`
- `source-probe.json`: `5F00E01283B2167CF2EEFFA009DAE585667C59899A99F3983F9900008BEC1D9F`
- Beam-stable Ember report: `8CB0B3D4D5B0A751C43B08B8B819FB84AAB72844A53CC02BE2570259B2563110`
- rejected Frost/BAL2 report: `8A70E3CE333F4D49540A15C4A9CA2AAB2D2E7E8C0DFF5D20B23AF1A0EA25190B`

