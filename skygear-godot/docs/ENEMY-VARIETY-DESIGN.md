# Enemy variety — the design pass the owner's 2026-08-02 direction asked for

Status: **DESIGN, unbuilt.** Written 2026-08-02 against the owner's direction at
the top of `docs/OUTSTANDING.md`, `docs/POST-PARITY-PLAN.md` items 7–8, board
row SG-55, `scripts/game_data.gd`, `scripts/game.gd` and `tools/balance.gd`.
Items get mirrored to `docs/BOARD.md` before work starts; an item leaves this
file done, or cut with the reason written at its entry.

## 1. What varies, and what never varies

The direction, verbatim: *"it should be minor deck variety within waves… It
should be more based on the enemies. The ship modification should happen in
between runs."* Restated as rules:

- **Varies run to run:** which enemies come, in what mixes, on what rhythm;
  which of them carry elite marks; whether the run has a recurring hunter;
  later, one run-fixed behavioral quirk. All of it dealt by seed, all of it
  enemy-side.
- **Fixed within a run:** the deck and props (the fittings system owns the
  between-run axis), the draft's stability, the four boarder meshes (SG-55:
  rigging is anatomy-gated; the gunner will never pass a humanoid rig), the
  rails (POST-PARITY §3: no pathing, no clamp-as-geometry), waves 1–2 as the
  taught opening, and the signature beats of 4/8/12.
- **Fixed absolutely: difficulty is Heat's job.** Every variety layer conserves
  per-wave threat budget within an asserted band, so two seeds at one Heat are
  *different fights*, never *harder fights*. Heat may raise variety counts, but
  only through `heat_data` fields with a declared `HEAT_HARDER` direction, so
  the monotone-ladder check still binds.
- **Every roll comes from an isolated stream** seeded
  `hash(seed_text) ^ SALT` — the stowage spine's proven pattern (d10f09c) —
  consuming nothing from `rng` or `visual_rng`. This is not hygiene; it is what
  keeps every A/B below uncontaminated. One proposal drew from `game.rng` and
  would have displaced every downstream sim roll; that mistake is named here so
  it is not remade.
- **Every item pre-commits its kill-test before it is built**, written against
  `balance.gd` as it actually is: the tool's own comments say a single seed is
  not deterministic, so no kill-test below demands bit-identical *runs* —
  distributions across the six seeds, with the replay noise floor measured
  first and the threshold filed in `NEEDS_ALEX.md` before the first line lands.
  Determinism claims are made only where they are provable: queue construction,
  headless, no frames awaited. Variety that does not measurably change play
  gets cut, not tuned — the standard that cut the stowage spine, endorsed by
  the owner tonight.

## 2. The system, in build order

### 2.1 The Muster — a seeded mutation pass over the WAVES table
**What:** a MUSTER table beside WAVES declaring legal per-wave mutations:
same-role type swaps priced by threat budget (hp × damage × speed weight — 3
SCRAPPER may become 2 SCRAPPER + 3 SWARM, never 3 ARMORED), lane redeals, and
count jitter in a band. Applied as one pure Array→Array function in
`_build_spawn_queue` (game.gd:1969), rolled from a dedicated stream seeded
`hash(seed_text) ^ (wave * 2654435761)`. Waves 1–2 exempt; on 4/8/12 only the
filler batches mutate — the hulk, the blackout and the Colossus are untouchable.
Per-wave threat budget held within ±10% of authored, asserted.
**Why a player feels it:** run two stops replaying run one — wave 6 was an
ARMORED pincer last run and is a SWARM flood down the port lane this run. The
drafted build meets a different question each run; because budget is conserved
it reads as a different fight, never a spike.
**Kill-test (pre-committed):** measure the noise floor first — two identical
replays per seed, threshold filed in `NEEDS_ALEX.md`. Then `balance.gd`, six
seeds × four muster variants at Heat 0 and Heat 2: per-wave damage-taken and
wave-duration distributions across variants of one seed must separate beyond
that floor. Indistinguishable the way flat-vs-stowed was → the layer is cut and
this entry records it.
**Checks:** `muster · the same seed deals the same twelve waves` (byte-identical
queues, headless), `muster · rolling the muster leaves rng.state untouched`,
`muster · every wave's threat budget holds the ±10% band`, `muster · waves 4, 8
and 12 keep their signature batches`. `balance.gd` gains a muster-seed arg in
the heat-arg idiom.
**Size:** a week.

### 2.2 Tempo — surge and lull replace the flat 0.22 drip
**Status: BUILT 2026-08-02 (board SG-57), before 2.1** — the seam did not need
the muster to exist first, and tempo's stream salt (`+ 7919`) was chosen so the
muster's own stream (`wave * 2654435761` bare, the d10f09c pattern) can land
later without colliding. The queue-signature half of the kill-test PASSED (the
gap-histogram valley test: SURGE pooled 267 within-batch gaps across 12 seeds —
219 at the 0.22 metronome, 48 in the 4–6 s lulls, 0 in the 1–3 s valley;
STEADY 804 gaps, every one at 0.22 — check `tempo · SURGE's gaps are bimodal
where STEADY's are unimodal — the gap-histogram valley test`). The six-seed
damage-taken half is recorded on the board row; its verdict waits on §1's
noise-floor rule — the threshold is the owner's call, not this pass's. All
three §2.2 check strings below are live in the harness, plus
`tempo · rolling the tempo leaves rng.state untouched`,
`tempo · STEADY deals today's queue byte-identically`,
`tempo · waves one and two keep the taught opening` and
`tempo · CRESCENDO tightens monotonically through the wave`.
**What:** today every batch member arrives at `time + i * 0.22` — one metronome
for twelve waves. Three authored TEMPO profiles (STEADY as today; SURGE, pulses
with 4–6 s lulls; CRESCENDO, spacing tightening monotonically), dealt per wave
by the muster stream; event and push waves pinned STEADY. A profile is a
function from (batch, member) to a time offset at the one line that writes
`time`; the existing sort and the 64-cap absorb it.
**Why:** rhythm is the most legible variety there is — squalls versus a tide
coming in — and it multiplies 2.1 rather than adding to it. The lull is a
readable invitation to repair and shove mid-wave.
**Kill-test:** the inter-spawn-interval distribution on SURGE must be
measurably bimodal where STEADY's is unimodal — a hard statistical signature
from the queue itself, no bot needed — AND six-seed damage-taken *variance*
within waves must shift beyond the noise floor. The original proposal's
repair-completion test is dropped honestly: the balance bot never repairs, so
that number cannot be read without unbudgeted bot work; it is not smuggled in.
**Checks:** `tempo · the same seed deals the same tempo twelve times`, `tempo ·
event waves are always STEADY`, `tempo · no profile pushes a spawn more than 8
seconds past the wave's authored last batch`.
**Size:** days.

### 2.3 Elite marks — stat-and-marker tiers on the four meshes that exist
**What:** an ELITES table, three marks, each an overlay on the ENEMIES config
read in `enemy.configure()` plus a marker the *renderer* draws — tint, +15%
scale, a nameplate in the `_health_bar` idiom, a ring in the SG-3 telegraph
language. (Markers go through `view3d`, which mirrors the sim; the 2D scene is
hidden and drawing there shows nobody anything.) Each mark changes what you DO
— the EVENTS table's own second rule: VETERAN (2× hp, flinch-immune — commit or
disengage), SPARKING (telegraphed arc pulse — punishes standing), QUARTERMASTER
(nearby boarders +30% speed while it lives — an assassination order). 0–2
promotions per wave from wave 5, rolled by the muster stream; a promotion is
paid for out of the wave's filler so the ±10% band holds. Kills pay salvage —
engagement pays, the third rule.
**Why:** SG-55's finding made composable — rigging costs per MESH and is
anatomy-gated; tiers cost per TABLE ROW and reuse every mesh, sprite and health
bar the renderer already draws. A QUARTERMASTER wave plays as a hunt, a VETERAN
wave as a siege.
**Kill-test (per mark, individually):** force the mark on versus stripped
across the six seeds; the mark must move at least one *behavioral* statistic
beyond the floor — position spread for SPARKING, kill-order for QUARTERMASTER —
not merely wave duration. A mark that only stretches time-to-clear is a
hit-point tax wearing a nameplate: cut by name, the others surviving.
**Checks:** `elite · a mark never spawns before wave 5`, `elite · the overlay
leaves the base ENEMIES row untouched`, `elite · every mark on deck carries its
marker` — no invisible elites; pillar 6 binds.
**Size:** a week.

### 2.4 The Harrier — a hunter that withdraws at wave-end and returns until killed
**What:** dealt onto one mid-run wave by the muster stream (never 1–2, never
4/8/12): an elite built from ARMORED — ~2.5× hp, +15% speed, distinct tint and
nameplate, `reach`/`swing` bit-equal to the base row so every learned telegraph
stays true. If the wave clears while it lives, it withdraws with a banner and
returns on the next wave's first batch AT ITS SURVIVING HP, until killed.
Killing it pays a fixed purse and is announced. It never boards wave 12 — the
SG-8 rule; the Colossus is never upstaged.
**Why:** the run acquires an antagonist with a memory. "I left the Harrier at a
third health and it came back during the blackout" is a story no wave table
produces, and the finish-it-now-or-fight-beside-it decision compounds because
chip damage persists.
**Kill-test:** determinism half as a harness *fixture*, not a bot run: damage
it to 40%, clear, assert respawn hp — exact, headless, provable. Play half on
the distribution: across six seeds the bot must kill it in some runs and carry
it in others, and carried waves must shift damage-taken beyond the floor.
Always-dies-on-arrival is a fat scrapper; never-killable is a tax — either
degenerate outcome after one tuning pass on the multiplier = cut, distribution
printed as the reason.
**Checks:** `harrier · armored's silhouette at armored's reach — the learned
telegraph stays true`, `harrier · a survivor returns at its surviving hp`,
`harrier · it never boards wave 12`, `harrier · killing it pays and it stays
dead`; a `tools/clip.gd` scenario for the motion evidence.
**Size:** a week.

### 2.5 Behavior quirks — the owner's own word, gated behind the layers above
**What:** "behaviors" is in the direction, so this is designed now and built
only after 2.1–2.3 prove the measurement path. One quirk per run (not two — one
named thing at a time), rolled at `begin_run` from its own stream — explicitly
NOT `game.rng` — fixed for all twelve waves (deck-stability mirrored), named in
a banner before wave 1, badged through the renderer. First candidate: CRAVEN —
a marked SCRAPPER/SWARM under 30% hp routs up its own lane for ~2.5 s, then
returns; sprite flip, rout streamer, still damageable, still clamped; STEAM's
state-reset must not cancel a rout, pinned by its own check. Second: WARDEN
PAIRS — a gunner invulnerable while its scrapper bodyguard stands within tether
range, guard clause beside the Colossus turn-immunity precedent in
`take_damage`; shove breaks the tether, so knockback is the counterplay.
**Kill-test (CRAVEN):** across six seeds, median time-to-kill for marked kinds
rises ≥15% AND player distance-moved per wave shifts ≥10% versus quirk-none —
both as cross-seed distributions. Guard rail: average wave-held stays within 1
of baseline, or it is a Heat rung wearing a quirk's clothes. The telemetry
columns these read (time-to-kill, distance-moved, kill-order) are two-line adds
to existing call sites, shipped WITH the first quirk — not as a standalone
"rig" demanding bit-identical runs balance.gd's own comments call impossible.
**Checks:** `quirk · the same seed rolls the same quirk and marks the same
boarders`, `quirk · forced to none, a run is state-identical to a build without
the frame`, `quirk · a rout never leaves the lane band or strands a wave`.
**Size:** days per quirk, after 2.1 lands.

### 2.6 The threat report — the muster made legible and reproducible
**What:** a pre-wave line derived FROM the built queue, never hand-written
(failure mode two, pre-empted): "WAVE 7 · swarm-heavy · one QUARTERMASTER",
in the existing banner. And the run-log row gains the muster seed exactly as
heat rode in via SG-53, with `balance.gd` accepting it back — a reported run
replays its twelve waves. No seed-entry or seed-display UI: the seed rides the
log row, not a screen; the ledger's founding rule stands.
**Kill-test:** lives and dies with 2.1 — if the muster is cut this goes with
it. Its own bar: `report · the threat line names every type, mark and signal
actually in the queue` (asserted against the live queue), `log · a row's muster
seed replays byte-identical queues`, text audit clean at all four widths with
the longest line posed.
**Size:** days.

## 3. Explicitly not, with reasons

- **New enemy species or meshes.** SG-55 binds: five rig submissions refused,
  anatomy-gated, costed per mesh; the scrapper regeneration stays its own
  owner-gated board row. Elite marks buy the composition dividend from the four
  meshes that render today.
- **Boarder pathing, AI navigation, or the lane clamp as geometry.** POST-PARITY
  §3's rejection stands. This system varies which/when/what-they-carry, never
  how they move.
- **Per-wave deck or stowage variation.** Cut by the kill-test and the owner in
  the same night. The deck is stable within a run; fittings own between-run.
- **Named wave modifiers (the SIGNALS table) — deferred, not designed in.** They
  overlap tempo (both reshape arrival) and would put a third named system on
  screen before the first two prove out. If muster + tempo survive their
  kill-tests and the waves still lack punctuation, SIGNALS is the next design
  pass, one per wave, never on 1–3 or 4/8/12.
- **Sky states, palettes, weather-as-variety.** By its own proposal's admission
  it is not enemy variety, and it sits on a written rejection. If a surviving
  mechanic later needs livery to be legible, that is that mechanic's item.
- **A standalone measurement rig demanding bit-identical telemetry.**
  balance.gd:147–161 says in writing that per-run determinism does not exist;
  an item whose acceptance criterion contradicts the tool it reads is an
  unscoped engine project wearing a "days" label. Telemetry ships in two-line
  increments beside the quirk that reads it.
- **Modifier stacking.** At most one named thing per ordinary wave — an event,
  a push, a quirk's presence, or (later) a signal. Three simultaneous named
  things is zero named things.
- **Mid-run rerolls, waves 13+, seed UI, wind as physics.** No owner sentence
  asks for any of them.

## 4. Composing with Heat and the events at 4/8/12

**One axis owns difficulty.** At any fixed Heat, every layer above holds the
±10% threat band — asserted, not intended — so a bad muster roll can never be
the reason a run died. Heat raises variety *counts* (a third promotion, higher
quirk mark-fraction) only via `heat_data` fields read through one question-site
(the `pushes_on` pattern) with a `HEAT_HARDER` direction declared, so the
monotone-ladder check proves a rung never got easier and variety never gets
provably harder at fixed Heat.

**No double-punishing.** A wave already carrying a named thing is closed to a
second: 4/8/12 keep grapple/blackout/Colossus (muster touches only their filler,
tempo pins STEADY, the Harrier never returns onto 12); BOARDERS ALOFT's extra
pushes on 6/10 make those waves promotion-light by rule (the hulk is the named
thing); Rust's hp_scaling multiplies the same base rows the muster budget is
priced in, so budget conservation holds at every rung by construction.

## 5. Build first: the Muster (2.1)

One pure function at the single seam where authored waves already become the
run's waves; the stream pattern exists in d10f09c to copy; zero credits, zero
renderer work, headless-checkable end to end; and its kill-test is the only one
that starts by measuring the tool's own noise floor and filing the threshold
before building — the discipline every later item then inherits. Everything
else in §2 composes on top of its stream, its budget assertion and its
balance.gd arg. If the Muster fails its kill-test, that verdict is cheap,
early, and redirects the whole system toward 2.3–2.5 (marks and behaviors,
which change what enemies *are and do* rather than which arrive) before
anything expensive is built on sand.