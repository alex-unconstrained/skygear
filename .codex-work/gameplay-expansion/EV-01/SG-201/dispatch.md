# SG-201 dispatch — EV-01 PINCER contrast repair

## Authority and baseline

- Owning packet: EV-01, design §16.2; SG-198's 7.96% CUT remains immutable.
- Repair authority: implementation plan §7.4, separately claimed defect.
- Board claim and owner: SG-201, Codex/coordinator.
- Baseline and serialization cursor: `59993e746c2a2bc7cc3a080ff6da4b02b0388c29`.
- Restored candidate: `94fbdc2942de7a867c088ced7672383e0d03e557`.

## One repair lever

In `scripts/muster.gd::plan()`, when the chosen grammar is PINCER, identify
legal candidates whose source-to-lane signature differs from the authored plan.
If any exist, select only among those candidates; otherwise keep the current
valid-candidate fallback. Use no additional RNG draw.

Do not change `_candidates()`, grammar percentages, threat costs, the ±10%
budget, the two-reassignment cap, authored types/times, queue schema, event/push/
boss exemptions, Heat, bot policy, gameplay or visual RNG, or the G3 gate.

## Files and checks

Restore the accepted SG-198 candidate's `scripts/muster.gd`,
`scripts/muster.gd.uid`, `scripts/game.gd`, and ten focused additions to
`tests/parity_test.gd`. The repair itself may change only
`scripts/muster.gd` and focused tests.

Retain all ten verbatim `muster ·` checks from SG-198 and add:

`muster repair · PINCER prefers a lane reassignment when one is legal`

The new check must prove every fixed wave-6 PINCER fixture changes the authored
source→lane signature while retaining threat 24.75, authored roster and timing.
Disabling the preference must make it red.

## Frozen evidence and stop

Run the full harness, then the unchanged `muster_g3.gd` on BAL1…BAL120,
one observation per distinct seed. PINCER versus ASSAULT must move wave-6
absolute lateral Captain travel by at least 10% and clear the paired 95%
resolution. Only after that passes, run live Muster versus
`SKYGEAR_MUSTER_FLAT` on the same 120 seeds; absolute held-rate delta must
be at most 9 percentage points. Repetitions are one and tuning is none.

Stop and CUT the revival if the primary still misses 10%, the difficulty arm
fails, any original contract/check regresses, RNG/save state moves, another
file is required, or an unrelated check turns red. No second repair lever.
