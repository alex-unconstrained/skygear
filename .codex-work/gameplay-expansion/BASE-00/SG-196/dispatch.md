# BASE-00 dispatch — SG-196

BOARD CLAIM: SG-196, claimed by Codex/coordinator 2026-08-04 19:22 MDT  
PACKET: BASE-00, design §16.1  
BASELINE COMMIT: `2c1ee5e6ed819f5351339daba840b881961db511`  
SERIALIZATION CURSOR: position 0; queue head `2c1ee5e`; no collision-heavy project files allowed

Outcome: later work has a trustworthy before state.

Requires: none. Operational readiness is satisfied by OPS-BAL-00 merge
`2c1ee5e` and the post-merge 120-distinct-seed pass.

Allowed files: no project files. Measurement output may live under this ignored
evidence directory. Gates: G0.

Required checks and evidence, verbatim from design §16.1:

- harness exit code and reported check total;
- byte signatures of `_build_spawn_queue()` for waves 1–12 at Heat 0 for seeds
  `STOW`, `TEMPO`, `WATCH1`, `WATCH2`, `WATCH3`, and `COLOSSUS`;
- `rng.state` and `visual_rng.state` immediately before and after queue
  construction;
- current wave duration, captain damage taken and held/not-held per wave from
  the balance tool at its stated sample resolution;
- one representative Ember and one non-Ember run report, including every
  per-slot damage/hit/kill row, labelled `damage attribution v1` in the evidence
  filename rather than added to player-facing copy;
- one posed screenshot each for an ordinary arrival, the blackout and the
  Colossus.

Stop condition: if the harness or a fixture fails before feature work, stop.
Do not redefine the baseline around the failure. No tuning is permitted.
