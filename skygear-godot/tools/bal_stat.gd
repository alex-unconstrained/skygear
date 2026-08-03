class_name SkyGearBalStat
extends RefCounted

## HOW BIG A SAMPLE `tools/balance.gd` NEEDS BEFORE IT IS ENTITLED TO A VERDICT —
## one answer, in one place (SG-128).
##
## THE THING THAT MADE THIS FILE NECESSARY. Two rows of the board recorded the
## SAME configuration of the SAME tool — Heat 0, the six BAL seeds, no Article —
## and wrote down two different answers. SG-14: *"Heat 0 held 5/6"*. SG-26:
## *"baseline 3/6 held"*. Both DONE, both dated 2026-08-01, both sitting in the
## ledger for two days with nothing in the repository noticing that they cannot
## both be right.
##
## THEY CAN BOTH BE RIGHT. That is the finding. 5/6 and 3/6 are not two answers;
## they are one answer reported twice by an instrument with no resolution at that
## sample size. Fisher's exact test on the 2x2 gives **p = 0.55** — the two
## counts are as close to indistinguishable as two counts get. Their 95% Wilson
## intervals are 44..97% and 19..81%, and they overlap across 37 points of the
## scale. Nothing needed to be re-run to establish that and nothing had been.
##
## WHICH MATTERS FAR BEYOND THOSE TWO ROWS, because n=6 is not an unusual sample
## in this repository — it is the DEFAULT. `SEEDS` has six entries and `count` is
## clamped to its size, so every `balance.gd` invocation that predates the `reps`
## argument was n=6 or smaller. **A held-count at n=6 is resolved to +-40
## percentage points in the worst case.** Every n=6 verdict in the ledger is a
## coin flip wearing a number.
##
## ---------------------------------------------------------------------------
## AND THE "8% NOISE FLOOR" IN `balance.gd`'s HEADER IS NOT A FLOOR (SG-128).
##
## That header tells the reader the rig's floor "is NOT zero — measured at 8% on
## damage-taken between two n=120 batches of identical code" and to "disbelieve
## anything that does not clear it". The 8% is real and the inference from it is
## wrong, and the difference is the whole point of this file:
##
##   A FLOOR does not shrink when you run more runs. SAMPLING ERROR does.
##
## Bootstrapped from a pool of 240 real Heat 0 runs, the 95% batch-to-batch range
## of the damage-taken mean is +-6.0% at n=120 — which is the 8% the header
## quotes, inside its own uncertainty. The two n=120 batches did not disagree
## because the instrument has an irreducible floor. They disagreed because n=120
## resolves that mean to about +-6%, and two draws from that spread land about 8%
## apart. Run n=480 and it halves. There is no floor there to clear.
##
## The practical consequence is the opposite of what the header advises: the rig
## is not permanently blind below 8%, it is blind below whatever its CURRENT
## SAMPLE resolves — which the tool now prints beside every number, so nobody has
## to take 8% on faith in either direction.
## ---------------------------------------------------------------------------
##
## WHAT COUNTS AS AN HONEST SAMPLE. There is no single n that is honest for every
## claim, and a file that pretended otherwise would be the next thing on this
## list. The rule is:
##
##   AN n IS HONEST FOR A CLAIM WHEN THE STATISTIC'S 95% BATCH-TO-BATCH RANGE IS
##   NARROWER THAN THE DIFFERENCE THE CLAIM IS MAKING.
##
## Measured on the 240-run Heat 0 pool (2026-08-03), that range is:
##
##     n     held-rate, worst case   damage-taken mean
##     6     +-40 points             +-26%
##     12    +-28 points             +-19%
##     30    +-18 points             +-12%
##     60    +-13 points             +- 8%
##     120   +- 9 points             +- 6%
##     240   +- 6 points             +- 4%
##
## `MIN_N` and `HONEST_N` below are the two lines drawn on that table. They are
## not judgement calls about what is interesting; they are the points where the
## arithmetic stops supporting the sentences this repository has been writing.

## NOTHING IS RECORDED BELOW THIS. At n=31 a held-rate is resolved to about +-18
## points, which is still coarse — but 31 is the smallest n at which the 83%-vs-
## 50% gap that SG-14 and SG-26 accidentally disagreed about could be CALLED at
## 80% power. Below it the rig cannot even see the largest disagreement it has
## ever produced about itself.
##
## IT IS 31 AND NOT A ROUND 30 BECAUSE THE HARNESS REFUSED THE ROUND NUMBER. The
## first draft of this file set it to 30 by eye; `bal · the floor below which
## nothing is recorded is derived from the gap it has to see, not picked` failed
## with "MIN_N 30 against a derivation of 31" before this file had ever shipped.
## That is the whole point of tying a constant to its derivation rather than to a
## comment, and it caught its own author on the first run.
const MIN_N := 31

## AND THIS IS WHERE A NUMBER MAY BE WRITTEN INTO A DOCUMENT. n=120 is the point
## at which the worst-case held-rate resolution (+-9 points) meets the 8% the
## rig's own header already declares — so it is the sample the header has been
## implicitly assuming all along without ever saying so.
const HONEST_N := 120

## The threshold `MIN_N` is derived from, kept beside it so the next person can
## re-derive rather than trust: two arms this far apart, called at 80% power.
const MIN_N_GAP := Vector2(0.833, 0.5)


## WILSON 95% INTERVAL on a held-count. Wilson rather than the textbook normal
## interval deliberately: at k=6, n=6 the normal interval is [100%, 100%], which
## would have let a 6/6 Article result claim certainty. Wilson does not do that.
static func wilson(k: int, n: int, z: float = 1.96) -> Vector2:
	if n <= 0:
		return Vector2(0.0, 1.0)
	var ph := float(k) / float(n)
	var d := 1.0 + z * z / float(n)
	var c := (ph + z * z / (2.0 * float(n))) / d
	var h := z / d * sqrt(ph * (1.0 - ph) / float(n)
		+ z * z / (4.0 * float(n) * float(n)))
	return Vector2(maxf(0.0, c - h), minf(1.0, c + h))


## DO TWO HELD-COUNTS SAY ANYTHING DIFFERENT? Interval overlap, which is the
## conservative reading and the one that answers the question the board actually
## asked: is 5/6 a different result from 3/6? It is not.
static func held_agrees(k1: int, n1: int, k2: int, n2: int) -> bool:
	var a := wilson(k1, n1)
	var b := wilson(k2, n2)
	return a.x <= b.y and b.x <= a.y


## THE WORST-CASE HALF-WIDTH of a held-rate at this n, in PERCENTAGE POINTS —
## worst case meaning at p=0.5, where a proportion is hardest to pin down. This
## is the number that makes n=6 indefensible: it returns 40.
static func held_resolution(n: int) -> float:
	if n <= 0:
		return 100.0
	return 100.0 * 1.96 * sqrt(0.25 / float(n))


## SMALLEST n PER ARM that could call a gap this size at 80% power, two-sided.
## `MIN_N` is this function evaluated at `MIN_N_GAP`, and the harness checks that
## it still is — so a later edit cannot move the constant away from its reason.
static func min_n_for(p1: float, p2: float) -> int:
	var gap := absf(p1 - p2)
	if gap < 0.0001:
		return 1 << 30
	var pb := (p1 + p2) * 0.5
	var num := 1.96 * sqrt(2.0 * pb * (1.0 - pb)) \
		+ 0.84 * sqrt(p1 * (1.0 - p1) + p2 * (1.0 - p2))
	return int(ceil(num * num / (gap * gap)))


## ---------------------------------------------------------------------------
## THE REPLACEMENT FOR "DISBELIEVE ANYTHING UNDER 8%" — and the reason a
## replacement was needed rather than a correction (SG-128).
##
## A CONSTANT GATE IS WRONG IN BOTH DIRECTIONS, and this rig has now been bitten
## by both. Quoted at n=120 the 8% was roughly right by accident. Quoted at n=30,
## where SG-126 used it, the sample cannot actually establish anything smaller
## than about **26%** — so the gate was far TOO PERMISSIVE there, and a 9%
## difference that happened to land the other way would have been "cleared the
## floor" and written down. A number that does not carry its n cannot be a gate.
##
## THE RULE THAT REPLACES IT, and it needs nothing but `tools/balance.gd`:
##
##   1. Decide the effect you would ACT on. Not the one you hope for — the one
##      that would change a tuning value if it were real.
##   2. Ask `runs_for_mean()` how many runs per arm that costs. The rig prints
##      this from its OWN observed spread under every result, so the number is
##      this build's, not a remembered one.
##   3. If you cannot afford that n, say the comparison was not attempted. Do NOT
##      run it small and report "no difference" — that is the SG-125 error, an
##      instrument that could not have seen an effect being read as evidence
##      against one.
##
## WHAT IT COSTS on the Heat 0 damage-taken spread (CV 0.36, ~11 s per run):
##
##     effect you want to see    n per arm    wall clock per arm
##     30%                        23           4 minutes
##     20%                        50           9 minutes
##     15%                        89          16 minutes
##     10%                       200          37 minutes
##      5%                       800           2.4 hours
##      1%                     19985          61 hours
##
## THAT TABLE IS THE FINDING. A whole-run mean on this rig is a BLUNT instrument
## — it can see a third of a change and it cannot see a twentieth at any price.
## Anything smaller belongs to a targeted probe, not to `balance.gd`.
##
## AND IT REACHES BACKWARDS. Three results were dismissed in the last day on the
## strength of the 8% "floor", and the dismissals were conservative — nothing
## shipped wrongly — but the reasoning was wrong, and it was wrong differently in
## each case:
##
## * **SG-117** (fire i-frames), n=120 per arm, damage taken 241.2 -> 216.7,
##   **-10%, t=2.43**. Dismissed as "the floor is the same size as the effect".
##   **It was not.** t=2.43 is p=0.015: a two-sample t already accounts for
##   sampling error, so the floor argument double-counted the noise and threw
##   away the one result of the three that CLEARED its own. The honest reading is
##   two-sided: the difference is unlikely to be zero, AND n=120 is only ~57%
##   powered for -10% (200 per arm is the 80% figure), so an effect that reaches
##   significance underpowered has its MAGNITUDE inflated — believe the sign,
##   not the 10%. SG-117's conclusion still stands, because it had a second and
##   better reason that has nothing to do with any of this: the bot walks out of
##   fire, so a whole-run average barely exercises the exploit. That reason is
##   the one the row should rest on.
## * **SG-119** (Colossus arc), n=120 per arm, **-1.0%, t=0.21**. Dismissed as
##   below the floor. Correct conclusion, wrong reason, and the right reason is
##   far stronger: resolving 1% on this spread needs **~20,000 runs per arm**,
##   about 61 hours. It is not "unresolved at n=120", it is unresolvable at any n
##   this project will ever pay for. The row's own argument — one wave in twelve,
##   a whole-run mean is the wrong instrument — is the durable one.
## * **SG-126** (discarded-remainder tick), **n=30** per arm, taken 192 -> 210
##   (+9%), held 23/30 -> 29/30. Dismissed as "at the rig's documented 8% floor".
##   Conclusion correct, citation backwards: at n=30 the smallest establishable
##   difference is ~26%, so +9% was nowhere near resolvable and the 8% gate would
##   have WAVED IT THROUGH had it been read as clearing. The row was saved by its
##   own better instinct — it noticed 23/30 was a low draw against the 92%
##   reference and refused the reading. The held pair confirms it: 23/30 is
##   59..88% and 29/30 is 83..99%, overlapping.
##
## NONE OF THE THREE IS RE-RUN HERE. Two of them cost hours and all three reach
## the same verdict on better reasoning; the correction is to the argument, not
## to the numbers.
## ---------------------------------------------------------------------------

## RUNS PER ARM to establish a relative difference `rel` in a mean whose spread
## is `cv` (sd/mean), at 80% power, two-sided 0.05. The replacement for the
## constant: you bring the effect you care about, it returns the price.
static func runs_for_mean(rel: float, cv: float) -> int:
	if rel <= 0.0 or cv <= 0.0:
		return 1 << 30
	var z := 1.96 + 0.84
	return int(ceil(2.0 * z * z * (cv / rel) * (cv / rel)))


## AND THE SAME ARITHMETIC READ THE OTHER WAY: the smallest relative difference a
## sample of `n` per arm could establish. This is the line that should have been
## printed beside SG-126's n=30, where it reads 26% against a quoted gate of 8%.
static func resolvable_at(n: int, cv: float) -> float:
	if n <= 0:
		return 1.0
	return (1.96 + 0.84) * cv * sqrt(2.0 / float(n))


## WELCH'S t FOR TWO ARMS' MEANS — unequal variances, because the arms this rig
## compares routinely have them (a Heat 5 arm that dies on wave 4 every run has
## almost no spread; a Heat 0 arm that holds has a lot).
static func welch_t(m1: float, sd1: float, n1: int,
		m2: float, sd2: float, n2: int) -> float:
	var v1 := sd1 * sd1 / maxf(1.0, float(n1))
	var v2 := sd2 * sd2 / maxf(1.0, float(n2))
	if v1 + v2 <= 0.0:
		return 0.0
	return (m1 - m2) / sqrt(v1 + v2)


## ONE SENTENCE THE TOOL PRINTS AND A HUMAN READS. Not a p-value on its own: the
## thing that went wrong here was never a misread p-value, it was a number
## written into a document with no sample size beside it.
static func verdict(n: int) -> String:
	if n < MIN_N:
		return "n=%d IS NOT A MEASUREMENT — a held-count here is worth +-%.0f points. Record nothing." \
			% [n, held_resolution(n)]
	if n < HONEST_N:
		return "n=%d resolves a held-count to +-%.0f points. Usable for a large gap; do not write it down as a figure." \
			% [n, held_resolution(n)]
	return "n=%d resolves a held-count to +-%.0f points — this sample may be quoted." \
		% [n, held_resolution(n)]
