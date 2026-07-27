# v10 — reconciling the two roadmaps

Two independent plans exist: `V10-ROADMAP.md` (mine) and `V10-SHIP-ROADMAP.md`
(Codex's). This is the merge, written after reviewing Codex's, and it is the one
to act on. Where they conflict I say which wins and why.

---

## 1 · What the agreement means

We wrote these without seeing each other's. The overlap is large enough to be
evidence rather than coincidence, so treat everything in this list as settled:

- **v10 is the first build made for a stranger**, not another feature release.
- Teach in the first minute; the title-screen instruction wall goes.
- **Seeded runs, a copyable run report, `localStorage` persistence, no server.**
  We independently specified nearly the same report format.
- No second captain, no multiplayer, no meta-progression, no accounts.
- Volume categories, reduced motion, reduced flashes; **nothing critical
  communicated by colour alone.**
- Gameplay-bearing art before decorative art.
- **One musical identity with layers and stings**, not seven independent tracks.
- Freeze v9; deterministic build IDs; rollback is a link change.

Converging separately on these makes them the low-risk core of v10.

---

## 2 · Where Codex is straightforwardly better

I am adopting these outright.

**The combat feedback contract (§5).** Anticipation → commit → contact →
consequence → recovery, with a five-tier event priority, and one canonical event
sheet naming each event's SFX, VFX, animation, camera and UI response. I had no
equivalent. It is the right structure for stopping five disciplines from
polishing five different interpretations of "heavy hit", and the priority tiers
are what makes voice limiting and low-VFX modes principled instead of arbitrary.

**"Stop generating to the final duration" (§7.4).** This is a direct correction
to tooling I built and it is right. My ingest trims to the first transient and
hard-caps to the spec budget — which is why *every one of the first sixteen
masters landed exactly on its cap* and `crew_muster` was cut at 97% of its
energy. I treated the duration table as a generation instruction; it should be
an **edit budget**. Generate with a natural tail, edit down, then measure.

**Reject bad masters instead of rescuing them (§7.4).** Also aimed at my code.
My ingest auto-applies up to +18 dB to bring quiet cues up. Codex is right that
this raises the generation noise floor and teaches the mix around a bad source.
I would keep the correction as a *stopgap that reports loudly*, but it must not
become the reason a bad master ships.

**Shape grammar and hostile/friendly identity (§6.3, §6.4).** Per-shape
silhouette contracts, and — better than my element-motif idea — hostile
telegraphs use broken, outward-toothed edges while player areas use continuous
rims. That carries ownership without hue at all. Do both: its edge grammar and
my per-element motifs.

**Gates, ownership table and risk register (§12–14).** Better production
structure than my linear sequencing, and the ownership table is the answer to
the collisions we have already had.

**The `vary` field is misnamed.** It is documented as a fraction and multiplied
by 1200 into cents, so `0.06` is ±72 cents, ≈4.2%. Verified. Rename to
`pitchCents` with explicit per-category ranges.

**The game was miscounting itself.** The title screen and the landing page both
said "24 combinations"; it has been **32** since passives shipped. Fixed — and
now derived from `SHAPE_KEYS × ELEMENT_KEYS` rather than written down, so adding
a shape cannot make it stale again.

Its whole audit section is accurate. I checked the enemy cap (64), particle pool
(400), still count (32/67), cue count and the cents conversion. All correct.

---

## 3 · Where I disagree

### 3.1 The must-list is a 1.0 scope, not a demo scope — this is the main risk

Codex's own §14 names "'v10 is big' becomes uncontrolled scope" as the top risk,
then §4 lists as **must**: a balance pass over all 32 shape × element
combinations; a production-quality critical SFX set; no procedural/painted
snapping on the captain, crew, *all common enemies* and interactive lane objects;
automated simulation smoke tests; a browser compatibility sign-off; and an
authored multi-phase finale.

"No style snapping on common enemies" alone requires most of the 17 animation
cycles and much of the 35 missing stills. That is not weeks.

**Move to "should": the full 32-combination balance pass** (spot-check the
outliers instead), **the authored multi-phase finale**, **the browser matrix
beyond Chrome+Firefox**, and **style-snapping completeness beyond the captain
and Scrapper.** A stranger notices the captain changing art style every swing.
They do not notice the Gunner's idle.

### 3.2 It never proposes changing what a run opens with

The plan teaches the first minute well but **every run still begins with Frost
Mortar**. My highest value-to-cost item is letting the player choose one of three
opening skills: it puts the shape × element pitch in their hands in the first ten
seconds instead of by wave 6, it is most of what replay value is, and it reuses
`rollSkillCards()` wholesale. Codex's §2 target — "at least half of completed
sessions choose to restart" — is hard to hit when the next run opens identically.

**Keep this. It is close to free.**

### 3.3 Load time is right but placed too late

Codex sets good budgets (≤12 MB critical, ≤30 MB total, staged loading in §8.4)
but they sit under art and performance. Measured now: **24 MB, 19 s at 10 Mbit,
64 s at 3 Mbit**, heading to ~34 MB with the approved animation scope.

Every asset already has a procedural fallback, so this is not a loading-screen
problem — it is a *not needing one* problem. Start on procedural, stream in,
swap live. **That belongs in Gate 1**, not Gate 3, because it is a day of work
and everything else is judged through it.

### 3.4 "Mobile/touch: explicitly not v10" needs a second half

Agreed on not building it. But a phone visitor currently gets a broken game
rather than an explanation. **Detect and inform** — one line of copy, not a
project.

### 3.5 Endless — I concede

I proposed it; Codex explicitly excludes it. Its argument is better: these are
"ways to postpone the moment the existing game becomes excellent." Dropped.
Replay value comes from §3.2 and the run summary instead.

### 3.6 Some acceptance criteria cannot be run

"A 20-minute run creates no obvious repeated variant pattern", "photosensitivity
review passes", and the whole-run loudness capture (-20 LUFS ±2 over 30 minutes)
all need tooling or a person we have not budgeted. Either name who does them and
with what, or downgrade them to "should". An unfalsifiable checkbox in a
definition-of-done is worse than no checkbox, because it blocks the release
without telling anyone what to do.

---

## 4 · The merged plan

| Gate | Content | Owner |
|---|---|---|
| **0 — evidence** | Codex's §2 test protocol, run unchanged. Decide passives, music, difficulty from observation. | Both |
| **1 — front door** | Instant start on procedural + streaming swap; seeded RNG; run report; delete `assets-49`; opening-skill choice; contextual first-minute prompts; settings shell; touch detect-and-inform. | Me |
| **2 — vertical slice** | Codex's Gate 1: one minute at v10 quality. Event sheet authored first, then SFX Batch A and the shape/element VFX grammar against it. | Codex leads, I wire |
| **3 — content lock** | Wave beats, push and finale, shape/passive tuning, collision and telegraph dimensions frozen. | Both |
| **4 — sensory production** | Art stills by §8.2 priority, animation strips, SFX B–D, music decision, HUD/draft/end screens. | Codex |
| **5 — hardening** | Accessibility modes, browser matrix, min-spec perf, missing-asset tests, smoke suite. | Both |
| **6 — release** | Freeze v9, stamp v10, cold-cache check, changelog, feedback link, verified rollback. | Me |

Gate 1 is mine and can start immediately — none of it depends on the v9 test.

---

## 5 · Still unanswered

Codex's §16 lists decisions to make after the v9 test. Two are missing from both
documents and someone has to answer them:

1. **How long is v10 allowed to take?** Neither plan says. Codex's must-list is
   months at the stated quality bar; mine was weeks. This single number decides
   most of §3.1.
2. **Who does the human-judgement work?** Photosensitivity review, loudness
   capture on three output systems, five cold playtest sessions, a slow laptop.
   None of it can be done by either of us, and all of it is on the critical path
   to "confidently put in front of people."
