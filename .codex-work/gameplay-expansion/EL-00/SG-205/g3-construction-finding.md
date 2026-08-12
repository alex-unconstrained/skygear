# G3 construction finding

The first attempted driver compared whole SG-203 campaign records after EL-00.
That is not a valid causal arm. At the next upgrade draft, `game.gd` weights
target slots with `SkyGearTelemetry.use(tel, slot)`; repaired burn attribution
therefore changes which later targeted upgrades are offered. Builds then
diverge, and downstream clear time, damage, and damage taken become nonlinear.

The invalid construction was stopped after 45 production seeds. Every observed
campaign row had diverged, and primary differences no longer equalled BURN
damage. This was an instrument failure, not relabelled gameplay evidence.
`g3-first-fail.log` and the explicitly marked invalid `sg205_g3.gd` are
retained.

The first pre-consumer construction correctly removed the draft confound and
proved attribution, but its physical fingerprint omitted `visual_rng`.
All ordinary outcomes matched; visual RNG differed because the new ordinary
funnel emitted a status floater. That stream also places gameplay kegs, so it
cannot be dismissed as cosmetic. `g3-predraft-first-fail.log` is retained.

The implementation now suppresses the optional status impact/floater edge. The
exact harness asserts both gameplay and visual RNG stability. The authoritative
driver restores visual RNG to the physical fingerprint and passes all 120
distinct pairs. This is an evidence-only reconstruction of accepted parent
`e870b6a`, not a gameplay flag.

The required deletion control then replaced the production `damage_status()`
burn call with that accepted-parent direct-HP body. Five named status and
attribution checks went red (1156/1162 overall), including slot-four ownership,
once-counted primary/reaction totals, lethal routing, the v2 report, and the
direct-subtraction detector. The mutation was reversed and the complete
candidate returned to 1162/1162.
