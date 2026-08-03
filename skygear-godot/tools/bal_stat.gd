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
## WHAT IT COSTS on the Heat 0 damage-taken spread.
##
## ***RE-MEASURED 2026-08-03 (SG-137), AND BOTH OLD COLUMNS WERE WRONG AT HEAD.***
## The original table was taken at CV 0.36 and "~11 s per run". Neither survived
## a fresh 480-run Heat 0 pool, and this is exactly the failure this file was
## written to end — a measured constant frozen into a comment, outliving the
## build it was measured on. THE FILE DID IT TO ITSELF. Read the dates.
##
##   * CV is **0.45**, not 0.36 (mean 119.3, sd 53.4 at n=480). The mean moved
##     -43% because `15ea5e0` (SG-130) changed the bot's DRAFT policy after the
##     old pool was drawn; a better-drafting captain takes less damage. Since
##     `runs_for_mean` goes as CV squared, **every old price was 1.56x too
##     CHEAP** — the unsafe direction.
##   * A run costs **~1.7 s**, not 11 s — measured twice, 327 runs in 600 s and
##     480 runs in 800 s. **Six times cheaper than advertised**, which is the
##     timid direction, and it means work has been declined as unaffordable that
##     was not.
##
## AT HEAD, 2026-08-03 (CV 0.45, 1.7 s per run):
##
##     effect you want to see    n per arm    wall clock per arm
##     30%                        35           1 minute
##     20%                        79           2 minutes
##     15%                       140           4 minutes
##     10%                       314           9 minutes
##      5%                      1256          36 minutes
##      1%                     31386          14.8 hours
##
## AND DO NOT TRUST THIS TABLE EITHER. It is a snapshot of one build's spread and
## the last one was obsoleted by a bot change nobody connected to it. `balance.gd`
## prints `resolvable_at` from the CV of the batch IN FRONT OF IT, which is the
## number to use; this table is orientation, not authority.
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


## ---------------------------------------------------------------------------
## THE SLOPE FAMILY (SG-129). Everything above prices a DIFFERENCE OF TWO MEANS.
## SG-129 asks a different question — does one statistic TREND across the order
## its runs were played in? — and a trend is not a two-arm comparison, so it gets
## its own arithmetic rather than a borrowed formula.
##
## WHY IT MATTERS AND NOT ONLY TO SG-129: if damage-taken drifts with run index,
## then two arms played SEQUENTIALLY INSIDE ONE INVOCATION differ by run order as
## well as by the thing under test, and every such comparison is confounded. Arms
## run as separate processes are immune. That is the whole stake.
##
## THE PRICE OF A SLOPE, which is NOT the price of a difference and is much
## cheaper per run: for indices 0..n-1 the sum of squared deviations of the index
## is n(n^2-1)/12, which grows as n^3, so SE(slope) falls as n^-1.5 rather than
## the n^-0.5 that governs a mean. Doubling n buys nearly three times the
## resolution on a trend. At n=480 and the Heat 0 spread (sd ~75) SE is about
## 0.025 damage/run, so 80% power reaches a slope of 0.069/run — a 33-damage,
## ~16% drift end to end.
## ---------------------------------------------------------------------------

## OLS SLOPE of `ys` against its own 0-based index, with the t statistic for
## H0: slope = 0. Returns [slope, t, df]. The index is the run ORDER, which is
## the only thing SG-129 is about — so this deliberately takes no x vector: the
## caller cannot accidentally regress against something else.
static func ols_slope_t(ys: PackedFloat64Array) -> Array:
	var n := ys.size()
	if n < 3:
		return [0.0, 0.0, 0]
	var nf := float(n)
	var xbar := (nf - 1.0) * 0.5
	var ybar := 0.0
	for y in ys:
		ybar += y
	ybar /= nf
	## Closed form for sum (x - xbar)^2 over 0..n-1, used rather than accumulated
	## so the denominator cannot drift with floating-point order.
	var sxx := nf * (nf * nf - 1.0) / 12.0
	var sxy := 0.0
	for i in n:
		sxy += (float(i) - xbar) * (ys[i] - ybar)
	if sxx <= 0.0:
		return [0.0, 0.0, 0]
	var slope := sxy / sxx
	var intercept := ybar - slope * xbar
	var rss := 0.0
	for i in n:
		var resid := ys[i] - (intercept + slope * float(i))
		rss += resid * resid
	var df := n - 2
	var s2 := rss / float(df)
	var se := sqrt(s2 / sxx)
	if se <= 0.0:
		return [slope, 0.0, df]
	return [slope, slope / se, df]


## REGULARIZED INCOMPLETE BETA I_x(a, b), Lentz's continued fraction. Present
## only because the two-sided p below needs it; it is not a general-purpose
## numerics library and should not grow into one.
static func _betacf(a: float, b: float, x: float) -> float:
	var tiny := 1.0e-30
	var qab := a + b
	var qap := a + 1.0
	var qam := a - 1.0
	var c := 1.0
	var d := 1.0 - qab * x / qap
	if absf(d) < tiny:
		d = tiny
	d = 1.0 / d
	var h := d
	for m in range(1, 200):
		var mf := float(m)
		var m2 := 2.0 * mf
		var aa := mf * (b - mf) * x / ((qam + m2) * (a + m2))
		d = 1.0 + aa * d
		if absf(d) < tiny:
			d = tiny
		c = 1.0 + aa / c
		if absf(c) < tiny:
			c = tiny
		d = 1.0 / d
		h *= d * c
		aa = -(a + mf) * (qab + mf) * x / ((a + m2) * (qap + m2))
		d = 1.0 + aa * d
		if absf(d) < tiny:
			d = tiny
		c = 1.0 + aa / c
		if absf(c) < tiny:
			c = tiny
		d = 1.0 / d
		var del := d * c
		h *= del
		if absf(del - 1.0) < 3.0e-14:
			break
	return h


## LOG-GAMMA, Lanczos g=7. Written out because GDScript has no `lgamma` — that
## is not an oversight worth working around with an approximation, since the beta
## function below is only as good as this is.
static func _lgamma(z: float) -> float:
	const G := [
		0.99999999999980993, 676.5203681218851, -1259.1392167224028,
		771.32342877765313, -176.61502916214059, 12.507343278686905,
		-0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7]
	if z < 0.5:
		## Reflection, so the caller never has to know the range.
		return log(PI / sin(PI * z)) - _lgamma(1.0 - z)
	var zz := z - 1.0
	var x: float = G[0]
	for i in range(1, 9):
		x += float(G[i]) / (zz + float(i))
	var t := zz + 7.5
	return 0.5 * log(2.0 * PI) + (zz + 0.5) * log(t) - t + log(x)


static func _betai(a: float, b: float, x: float) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	var lbeta := _lgamma(a + b) - _lgamma(a) - _lgamma(b) \
		+ a * log(x) + b * log(1.0 - x)
	var bt := exp(lbeta)
	if x < (a + 1.0) / (a + b + 2.0):
		return bt * _betacf(a, b, x) / a
	return 1.0 - bt * _betacf(b, a, 1.0 - x) / b


## TWO-SIDED p FOR A t STATISTIC, from the STUDENT t with `df` degrees of
## freedom — not the normal approximation. At SG-129's df=478 the two agree to
## the fourth decimal and it would not have mattered; it is exact here so that
## the SAME function is still right the next time somebody runs a trend at n=40,
## where the critical value is 2.02 rather than 1.96 and the shortcut would call
## a result that the honest distribution refuses.
static func t_p_two_sided(t: float, df: int) -> float:
	if df <= 0:
		return 1.0
	var dff := float(df)
	return _betai(dff * 0.5, 0.5, dff / (dff + t * t))


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
