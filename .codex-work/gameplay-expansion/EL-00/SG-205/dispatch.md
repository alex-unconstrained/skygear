# SG-205 / EL-00 dispatch

Authority: live code and harness-pinned behavior; gameplay outcome and numbers
from design §17.4; execution/evidence policy from the companion plan.

Baseline and rollback cursor: `e870b6a`.

Allowed project files:

- `scripts/game.gd`
- `scripts/enemy.gd`
- `scripts/telemetry.gd`
- `scripts/cards.gd` only if modifier wiring required it
- `tests/parity_test.gd`

No card data change was required. No defaults, authored card values, physical
damage, save schema, assets, renderer files, or itch artifacts may move.

Invariants:

- preserve AB-01's `element_once` argument, with `source_slot` appended after it;
- default burn is 5 DPS per stack in four `5 * stacks * 0.25` ticks;
- default duration/slow/stun stay 3.0 / 0.40 / 0.20;
- status uses one ordinary attribution/kill funnel without crit, element,
  knock, slowed-target bonus, Tap extension, hit-stop, floater/visual RNG, or
  allied/deck hero payout;
- BURN reaction rows describe ordinary damage and never add it again;
- immunity spends the carried schedule rather than storing a burst;
- expiry clears stacks, time, source, and the carried clock;
- no project file outside the claim changes.

Stop condition: any authority conflict, out-of-scope file need, authored-value
change, physical/RNG mismatch before an attribution consumer, non-Ember report
change, or failed exact check stops the packet.

G3 declaration:

- primary identities: feature-on primary increase equals BURN reaction damage,
  and every pre-consumer physical fingerprint matches the feature-off arm;
- arms: exact accepted-parent legacy tick reconstructed in evidence only versus
  production `enemy._update_statuses()`;
- seed set: the immutable SG-203 BAL1…BAL120 set; one observation per seed;
- repetitions: BAL1/BAL2 determinism audit only, never added to effective n;
- consumer boundary: the comparison ends before a targeted upgrade draft can
  read the repaired attribution;
- no tuning pass is permitted.

The exact accepted-parent source is `e870b6a`,
`enemy.gd` Git blob `8372ab10b302e5e13e571eeb2bb6d21c01756d00`.
Its legacy evidence-only seam is `burn_tick += 0.25`,
`amount = 5.0 * burn_stacks * 0.25`, direct HP subtraction, then
`register_damage(dealt, global_position)`.

G5: not required by §17.4.

