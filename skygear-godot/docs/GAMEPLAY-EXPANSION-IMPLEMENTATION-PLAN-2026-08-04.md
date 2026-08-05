# SkyGear Godot — gameplay expansion implementation plan

Date: 2026-08-04
Scope: implementation coordination for the 37 gameplay packets in
`GAMEPLAY-EXPANSION-DESIGN-2026-08-04.md`
Status: authoritative companion for dispatch order, evidence handling, merge
serialization, release decisions and rollback; it does not implement gameplay

## 1. Purpose and authority

This document turns the
[gameplay expansion design](./GAMEPLAY-EXPANSION-DESIGN-2026-08-04.md) into an
execution plan that a coordinator can safely divide among coding agents. It
does not replace any packet's behavior, numbers, allowed-file list, required
checks or kill condition. It adds the operational rules the design needs before
implementation can begin.

Use this authority map when instructions disagree:

1. **Live code and harness-pinned behavior define current truth.** `STATUS.md`,
   `docs/BOARD.md` and `docs/OUTSTANDING.md` identify current ownership and
   accepted owner decisions. A prose claim does not overrule a production path
   or a named check that demonstrates otherwise.
2. **Design Sections 16–20 define feature truth.** The complete packet owns its
   gameplay behavior, numerical values, allowed and forbidden files, required
   checks, gates, tuning allowance, feature-off seam and CUT condition. Design
   Sections 13–15 remain mandatory shared engineering constraints.
3. **This companion defines execution truth.** It owns readiness, dispatch and
   merge order, evidence shape, sampling discipline, lifecycle transitions,
   release composition and rollback procedure.

No implementer silently chooses between conflicting authorities. The packet
stays `BLOCKED`; the agent returns the two exact statements, file and line or
section references, the smallest reproducer, and which downstream rows are
affected. The coordinator files the conflict as a separate board item and
records the decision before the packet can become `READY`. A conflict is never
repaired opportunistically inside a feature packet.

The 37 IDs in the design remain the complete gameplay packet inventory.
`OPS-BAL-00` below is an operational prerequisite, not a hidden thirty-eighth
gameplay packet.

## 2. Coordinator operating contract

### 2.1 Roles and board ownership

The **coordinator** is the only role that may:

- allocate the next free `SG-` board ID, claim a packet row, change its board
  status or close/drop it;
- decide that prerequisite evidence is sufficient;
- grant a collision-heavy-file serialization slot;
- accept a G3 result, record a G5 verdict, merge a packet, release a train or
  execute rollback;
- file a separately scoped defect when a packet exposes an upstream problem.

A **feature agent** receives exactly one design packet. It does not claim or
close board work, edit the coordinator ledger, add a second packet, repair an
audit failure in place, or broaden the allowed-file list. It returns a commit
or isolated diff plus the evidence bundle specified in its dispatch card.

A **human verifier** plays the forced G5 fixture and writes a named verdict.
The verifier records the decision the feature creates, its counterplay, and any
readability or class-collapse failure. “Feels fine” is not a verdict.

When execution begins, the coordinator assigns a fresh board row to every
claimed packet. Agents working from stale worktrees are never asked to invent
an `SG-` number. Large logs and artifacts live in the ignored evidence area;
the durable board result and evidence pointer are written to that day's night
log under the coordinator-assigned ID.

### 2.2 Packet lifecycle

Every packet uses this state machine:

`BLOCKED → READY → CLAIMED → IMPLEMENTED → MEASURED → HUMAN-VERIFIED → MERGED → RELEASED`

`CUT` is a terminal failed-verdict state. It may be reached from
`IMPLEMENTED`, `MEASURED` or `HUMAN-VERIFIED` after the packet's permitted
tuning pass is exhausted or its explicit kill condition fires.

| State | Coordinator proof required to enter |
|---|---|
| `BLOCKED` | Default state, or a named missing prerequisite, authority conflict, red instrument, shared-file collision, unresolved metric or separate defect. |
| `READY` | Every `Requires` item has the exact stable/measurement/verdict evidence demanded by the design; every `Serialize after` item is recorded separately; allowed files, invariants, checks, stop condition and G3 preregistration are complete. |
| `CLAIMED` | Coordinator has assigned and claimed one board row, recorded the baseline commit and serialization cursor, and sent one complete dispatch card to one agent. |
| `IMPLEMENTED` | Agent returned only allowed-file changes, named focused checks, full handoff notes and no unresolved contract deviation. This is not a pass. |
| `MEASURED` | All required automated gates through G4 are recorded against the claimed commit. A packet without G3 or G4 records `NOT REQUIRED — design §…` rather than silently skipping the state. |
| `HUMAN-VERIFIED` | A named G5 verdict is recorded. A packet without G5 records `NOT REQUIRED — design §…`; an agent's own unstructured impression cannot substitute for a required human fixture. |
| `MERGED` | Coordinator rebased on the current merge-queue head, reran the required gates, merged exactly the reviewed change, recorded merge commit and rollback point, and closed or updated the board row with evidence. |
| `RELEASED` | The containing train and every cross-packet release gate passed in one candidate build; the release manifest names the packet merge commit and train rollback point. |
| `CUT` | Failed report and human notes are retained, gameplay changes are reverted or removed through the packet's declared seam, the board row is dropped with reason, and downstream consumers remain blocked. Revival requires a separately claimed repair or replacement decision. |

An ordinary implementation failure does not justify skipping forward. The
coordinator may leave the row `CLAIMED` for an in-scope correction, return it to
`BLOCKED` for a separately filed prerequisite, or move it to `CUT` when the
design verdict fails. `IN-00` and other audit packets never change gameplay to
make their own result green.

### 2.3 Coordinator ledger

The coordinator keeps one durable record per packet in the dated night log and
one machine-readable index beside the ignored evidence. The board row is the
claim authority; the ledger is the execution authority. At minimum every record
contains:

| Field | Required content |
|---|---|
| `packet_id` | One design packet ID; operational work uses `OPS-BAL-00` and is explicitly typed `operations`. |
| `board_claim` | Coordinator-assigned `SG-` ID, owner, claim time and current board status. |
| `lifecycle` | One state from Section 2.2 plus transition time and coordinator. |
| `baseline_commit` | Exact commit on which the agent began; never “latest” or a branch name. |
| `prerequisites` | Verbatim `Requires` entries and the merge commits, report paths and named verdicts that satisfy them. |
| `prerequisite_evidence` | Direct pointers to each stable/G3/G5 artifact; absence keeps the row `BLOCKED`. |
| `serialize_after` | Verbatim design entries, recorded independently from mechanical prerequisites. |
| `serialization_cursor` | Collision queue position and queue-head commit granted at claim and at final rebase. |
| `allowed_files` | Verbatim allowed and forbidden file text from the complete packet; actual changed-file list is appended at handoff. |
| `predeclared_metric` | Primary statistic, comparison arms, feature-off seam, distinct-seed set/count, repetitions, effective `n`, required resolution, pass/CUT rule and sole permitted tuning variable. |
| `required_gates` | Design gates plus exact focused check strings, commands and whether G4/G5 artifacts apply. |
| `evidence_location` | Night-log anchor and ignored artifact directory. |
| `result` | `PENDING`, `PASS`, `FAIL`, `UNRESOLVED`, `BLOCKED` or `CUT`, with separate automated, measurement and human verdicts. |
| `merge_commit` | Exact accepted commit, blank until `MERGED`. |
| `rollback_point` | Exact parent or known-good release commit and packet-specific disable/revert instructions. |
| `downstream_unblocked` | Rows made `READY` by this result; an empty list is explicit. |

Recommended ignored layout, rooted at the repository's existing ignored work
area:

```text
.codex-work/gameplay-expansion/
  ledger.jsonl
  OPS-BAL-00/
    <board-id>/
  <packet-id>/
    <board-id>/
      dispatch.md
      commands.jsonl
      focused-checks.log
      full-harness.log
      metrics.json
      rng-save-findings.md
      result.json
      rollback.md
      human-g5.md
      visual/
```

`commands.jsonl` records working directory, executable, arguments, relevant
environment variables, start/end commit, exit code and output path. It must be
possible to distinguish feature-on from feature-off runs without guessing from
the filename. `metrics.json` records raw arms and seed IDs, not only a rounded
summary. Visual folders contain the zero-noise control as well as the changed
frame or clip.

### 2.4 Dispatch card for a coding agent

The coordinator fills every bracket before assigning work and attaches no
second packet:

```text
BOARD CLAIM: [SG-ID, claimed by coordinator]
PACKET: [ONE PACKET ID and design section]
BASELINE COMMIT: [full commit]
SERIALIZATION CURSOR: [queue position and queue-head commit]

Implement only the complete packet in
docs/GAMEPLAY-EXPANSION-DESIGN-2026-08-04.md.
Read STATUS.md, docs/BOARD.md, docs/OUTSTANDING.md, design Sections 13–15,
the complete assigned packet, every named function and every direct caller.
Return a conflict; never choose silently.

OUTCOME: [copy verbatim]
REQUIRES AND ACCEPTED EVIDENCE: [copy each entry and its evidence link]
SERIALIZE AFTER: [copy verbatim; this is merge order, not a prerequisite]
ALLOWED/FORBIDDEN FILES: [copy verbatim]
INVARIANTS: [copy packet invariants and applicable shared contracts]
REQUIRED CHECKS: [copy the packet's check statements verbatim]
GATES: [copy verbatim]
G3 PREREGISTRATION: [metric, arms, seam, distinct seeds, resolution, rule,
permitted single-variable pass]
PLAYER COPY/SAVE/RNG CONTRACT: [exactly what applies]
STOP CONDITION: [copy every packet CUT rule; add missing prerequisite,
authority conflict, out-of-scope file, red instrument and undeclared tuning]
EVIDENCE DIRECTORY: [exact path]

First response: expected files, direct callers, invariants, checks that will
fail before implementation, A/B or feature-off comparison, save/copy effects,
new fields and intended readers, and stop condition.

Final response: actual files, exact commands and verdicts, raw measurement
pointer, RNG/save findings, every new field/owner/reset/reader, deviations,
remaining risk, and rollback instructions. Do not edit the board or ledger.
```

The coordinator copies Required checks and numerical acceptance language from
the design verbatim. A summary written from memory is not a lower-capability
agent handoff.

## 3. Operational prerequisite — `OPS-BAL-00`

`OPS-BAL-00` repairs the evidence instrument before `BASE-00`. It is a plan-only
operational prerequisite, not part of the 37-packet gameplay inventory, and
cannot tune gameplay or be bundled with baseline capture. Execution fulfilled
it as **SG-195**, merge `2c1ee5e`; the corrected **BASE-00** then passed as
SG-196 at `0a6d34a`. Evidence remains under
`.codex-work/gameplay-expansion/{OPS-BAL-00/SG-195,BASE-00/SG-196}/` and
the durable verdicts are in `docs/NIGHT-LOG-2026-08-04.md`.

### 3.1 Reason for the block

Before SG-195, the live physics-stepping repair made repeated executions of one
seed deterministic while `tools/balance.gd` still defined only six seed
strings, clamped a requested count to that list, and added every repetition to
`results.size()`. Repetitions could therefore narrow intervals without adding
an independent seed. That historical state was an instrument failure, not
gameplay evidence. SG-195 corrected it and SG-196 established the first
acceptable baseline; no earlier repeated-six-seed result satisfies a G3 gate.

### 3.2 Scope and behavior

Allowed files are `tools/balance.gd` and focused balance-instrument additions to
`tests/parity_test.gd`. If a production-independent pure helper is necessary,
the coordinator must approve and add that exact helper path before claim; no
gameplay, bot policy, balance value or packet file may change.

Preserve the positional CLI:

```text
balance.gd -- <seed-count> <heat> <article-or-none> <reps>
```

Implement these rules:

- A request for `n` seeds generates `BAL1` through `BALn`; it never clamps at
  six and never silently substitutes repetition count for seed count.
- `reps == 1` is the normal evidence mode.
- `reps > 1` is only a determinism audit. Group all rows by seed, calculate a
  fingerprint from every reported result field, and require all repetitions of
  that seed to agree.
- Statistics consume exactly one observation per distinct seed. Identical
  repetitions do not increase effective `n`; a differing fingerprint for one
  seed is an instrument failure, exits non-zero, and suppresses any gameplay
  verdict.
- Every summary prints requested seeds, distinct seeds, repetitions and
  effective `n` separately. Every interval and resolution helper receives the
  distinct-seed `n`.
- Update the tool's header and examples so they describe the deterministic
  contract. Do not retain prose that calls repeated fixed seeds independent
  observations.

Required focused check intent:

- `balance instrument · one hundred twenty requested samples are BAL1 through BAL120`;
- `balance instrument · repeated fingerprints never inflate effective n`;
- `balance instrument · variation within one seed fails the instrument`;
- `balance instrument · positional heat article and reps arguments remain compatible`;
- `balance instrument · every reported interval reads the distinct-seed count`.

The coordinator may adjust the final check wording to match existing harness
grammar, but the claimed row and completion evidence must name the exact strings
that land.

### 3.3 Acceptance and corrected baseline command

After the focused checks and full harness pass, the standard general evidence
command becomes:

```powershell
godot --path . --headless --script tools/balance.gd -- 120 0 none 1
```

It must print 120 distinct seed IDs and effective `n = 120`. A determinism audit
may use repetitions greater than one, but its effective sample size remains the
number of distinct seeds and its only verdict is instrument pass/fail.

`BASE-00` starts only after the coordinator records the operational merge
commit, the five named focused checks, a clean full harness, one successful
120-distinct-seed invocation and its printed resolution. Historical balance
results collected by repeating six seeds are retained as historical artifacts
but cannot satisfy a prerequisite or G3 gate in this expansion.

## 4. Readiness and merge serialization

### 4.1 One collision queue

There is one coordinator-owned merge queue for:

- `scripts/game.gd`;
- `scripts/enemy.gd`;
- `scripts/hud.gd`;
- `scripts/view3d.gd`;
- `tests/parity_test.gd`.

Any packet expecting to edit at least one of these files receives one queue
position and may merge only at the current cursor. Parallel development is
allowed only when expected allowed-file sets are disjoint. An overlap in any
other file also forbids parallel development even if that file is not on the
named list. `Serialize after` always controls merge/evidence order, including
when two implementations happened to develop cleanly in parallel.

Before merge, the coordinator rebases or reapplies the packet onto the current
queue head, rereads every changed signature and caller against that head, and
reruns all required gates. Evidence from the agent's stale baseline may explain
the change but cannot be the merge verdict. The ledger records both the claim
cursor and final cursor.

### 4.2 Readiness algorithm

For each next schedule row, the coordinator performs these checks in order:

1. Confirm `OPS-BAL-00` and corrected `BASE-00` evidence when the packet uses
   G3 or consumes a baseline comparison.
2. Resolve every design `Requires` entry to a merge commit and any explicitly
   required stable/G3/G5 verdict.
3. Record every `Serialize after` entry independently and wait for the merge
   cursor. Never report a serialization wait as a missing mechanical feature.
4. Compare the packet's exact allowed files with every active claim. Any
   overlap keeps it `BLOCKED`.
5. Copy the packet checks, invariants, tuning allowance and CUT condition.
6. For G3, freeze the primary statistic, arms, seam, distinct seeds, printed
   resolution and pass rule before code is seen. If the design does not supply
   enough detail to do this without inventing a contract, file a decision and
   keep the packet `BLOCKED`.
7. Allocate the board row, evidence path, baseline commit, serialization cursor
   and rollback point; then advance `READY → CLAIMED` and dispatch one card.

## 5. Canonical execution schedule

This is the only canonical packet-row schedule. Each of the 37 design packet
IDs has one row. `Requires` is mechanical or verdict readiness; `Serialize
after` is coordinator merge order. Gates and feature behavior still come from
the complete referenced packet, not from this abbreviated table.

<!-- packet-schedule:start -->
| Train step | Packet | Design | Required acceptance before `READY` | `Serialize after` / queue condition |
|---|---|---:|---|---|
| T1.1 | `BASE-00` | §16.1 | `OPS-BAL-00` merged; corrected instrument checks and invocation green | none |
| T1.2 | `EV-01` | §16.2 | baseline fixture accepted | none |
| T1.3 | `EV-02` | §16.3 | deterministic Muster merged green | none |
| T1.4 | `EV-05` | §16.6 | deterministic Muster stable | none |
| T1.5 | `EV-03` | §16.4 | deterministic Muster and live-plan description merged | none |
| T1.6 | `EV-04` | §16.5 | named Quartermaster G3/G5 continue verdict | none |
| T1.7 | `EV-06` | §16.7 | baseline fixture accepted | live-plan description merged first |
| T1.8 | `LV-01` | §19.1 | live-plan description merged | none |
| T2.1 | `AB-01` | §17.1 | baseline fixture accepted | none |
| T2.2 | `EL-00` | §17.4 | baseline fixture accepted | Beam seam merged first |
| T2.3 | `AB-02` | §17.2 | Beam stable | none |
| T2.4 | `AB-03` | §17.3 | baseline fixture accepted | Field merged first |
| T2.5 | `AB-04` | §17.7 | baseline fixture accepted | Pulse merged first |
| T2.6 | `EL-01` | §17.5 | attribution-v2 seam merged and its new baseline accepted | none |
| T2.7 | `EL-02` | §17.6 | Beam and attribution-v2 seam merged | Frost/Steam interaction merged first |
| T2.8 | `EL-03` | §17.8 | Cleave beat and attribution-v2 seam merged | Arc Conduct merged first |
| T2.9 | `RF-00` | §17.9 | Beam stable | named element reactions merged first |
| T2.10 | `RF-01` | §17.10 | Beam and Reforge infrastructure merged | none |
| T2.11 | `IN-00` | §17.15 | release-critical shapes, attribution-v2 reactions and Beam Reforge pair all stable | none; audit current queue head |
| T3.1 | `SH-01` | §18.1 | baseline fixture accepted | none |
| T3.2 | `SH-02` | §18.2 | hardpoint model and reconciliation merged | none |
| T3.3 | `SH-03` | §18.3 | hardpoint UI/save work merged | none |
| T3.4 | `SH-04` | §18.4 | hardpoint UI/save work and arrival audit merged | Powder Locker merged first |
| T4.1 | `LV-02` | §19.2 | Quartermaster and Sparking both have accepted G3/G5 measurements | none |
| T4.2 | `LV-03` | §19.3 | named Black Watch verdict | none |
| T4.3 | `LV-04` | §19.4 | Last Watch merged and existing Colossus contract confirmed | none |
| T5C.1 | `AB-05` | §17.11 | baseline fixture accepted | Beam and Cleave merged first |
| T5C.2 | `AB-06` | §17.12 | baseline fixture accepted | Beam, Field, Pulse and attribution-v2 seam merged first |
| T5C.3 | `AB-07` | §17.13 | Field and attribution-v2 seam merged | Gale merged first |
| T5C.4 | `EL-04` | §17.14 | Gale and Frost/Steam interaction stable | combined combat audit merged first |
| T5S.1 | `SH-05` | §18.5 | attribution-v2 seam and hardpoint UI/save work merged | Signal Crane merged first |
| T5S.2 | `SH-06` | §18.6 | hardpoint UI/save work and attribution-v2 seam merged | Firebreak Grating merged first |
| T5S.3 | `SH-07` | §18.7 | all four rival fittings passed G5 and coordinator accepted every-hardpoint pick-split verdict | none |
| T6.1 | `HR-00` | §20.1 | baseline fixture accepted | combined combat audit, Signal Crane and final campaign wave work stable |
| T6.2 | `HR-01` | §20.2 | explicit gauge modes and Steam Impact stable | none |
| T6.3 | `HR-02` | §20.3 | named Rigger/Tension vertical-slice verdict and hardpoint UI/save work merged | none |
| T6.4 | `HR-03` | §20.4 | Make Fast/Haul passed G5; Signal Crane and final campaign wave work stable | none |
<!-- packet-schedule:end -->

Train numbers express release grouping, not permission to ignore dependency or
file collisions. A later train may develop against stable prerequisites while
another disjoint train is being measured, but the one collision queue and the
row's merge order still apply.

## 6. Release-train runbooks

Every train below names entry criteria, exit evidence, failure action, rollback
point and downstream unlocks. “Verdict” means a coordinator has recorded the
required measurements and a named G5 decision; harness green alone is not a
verdict.

### 6.1 Train 1 — encounter truth

**Entry criteria.** `OPS-BAL-00` is `MERGED`; its five focused instrument checks
and the full harness are green; the corrected command has produced 120 distinct
seeds; the merge queue has no conflicting active claim; and the baseline
evidence directory is allocated.

**Order.** Run `BASE-00 → EV-01 → EV-02 → EV-05 → EV-03 → verdict → EV-04 →
verdict`, then run `EV-06` and `LV-01` when their own prerequisites and
serialization positions are satisfied. Capture the baseline before any feature
packet. Do not develop Sparking while the Quartermaster verdict is pending.

**Exit evidence.** The train record contains:

- wave 1–12 baseline queue byte signatures at the six design fixture seeds,
  main and visual RNG states around queue construction, full harness output and
  the corrected 120-distinct-seed general balance report;
- one Ember and one non-Ember `damage attribution v1` report, plus the ordinary,
  Blackout and Colossus screenshots required by the baseline packet;
- cached-plan and feature-off queue evidence, live-plan/Manifest identity,
  arrival checks and zero-noise arrival visual evidence;
- preregistered Quartermaster and Sparking G3 reports, their forced fixtures,
  exact permitted tuning history and named G5 continue decisions;
- recovery-window frequency with its required Wilson result, a named human use
  of the prompt, Watch text/containment evidence and a named Watch play verdict.

**Failure action.** Any failing baseline or instrument stops the train before
feature edits. A failed Quartermaster verdict blocks Sparking and the first
campaign-authorship packet; preserve the report and either CUT the mark through
its declared seam or file a separately claimed repair. A failed Sparking verdict
blocks campaign authorship in the same way. The arrival audit records a
regression but never fixes it in place. Recovery/Watch failures stay within
their own rows and do not justify weakening live queue truth.

**Rollback point.** The train rollback is the commit immediately before
Muster. Each packet also records its own parent. Muster uses its declared flat
seam for evidence and can be reverted cleanly; failed elite or reader packets
are reverted individually and all later evidence collected on them is marked
stale.

**Downstream unlocks.** Accepted arrival evidence unlocks Signal Crane.
Accepted elite measurements unlock campaign authorship. Stable cached plans and
Watch copy complete the encounter half of the core release. Train 1 does not by
itself authorize player publication.

### 6.2 Train 2 — combat agency

**Entry criteria.** The corrected baseline is accepted, the Beam dispatch has a
collision-queue slot, attribution-v1 artifacts are immutable, and every G3
packet has a preregistered statistic and before/feature-off arm.

**Order.** Serialize `AB-01 → EL-00 → AB-02 → AB-03 → AB-04 → EL-01 → EL-02 →
EL-03 → RF-00 → RF-01 → IN-00`. `EL-00` lands immediately after the Beam seam
and captures new representative Ember/non-Ember reports labelled
`damage attribution v2` before any later element evidence. Never compare later
combat attribution rows with attribution-v1.

Every new timer, channel or status check includes 1/60, 0.05 and a step that
crosses multiple ticks, plus cancellation, pause, reset and death. A missing
member of that matrix keeps the packet below `MEASURED`.

**Exit evidence.** The train record contains all packet checks; attribution-v2
reports; per-packet forced A/B fixtures and visual noise controls; Reforge
choice and branch fixtures; and the complete `IN-00` production-path pairwise
matrix. The all-on fixture is forced wave 12 at normal camera scale and includes
Root uptime, reaction triggers by ID, damage by slot, main/visual RNG deltas,
hostile-tell/marker separation, and a named human G5 readability verdict.

**Failure action.** A packet failure is attributed to the smallest owning
packet and either corrected within its still-claimed scope, separately filed,
or cut according to its design rule. `IN-00` changes no gameplay or tuning; it
stops, identifies the owner, waits for the separate repair, then reruns the
entire pairwise matrix and all-on fixture. No release-critical combat packet
ships while this audit is red or its human verdict is absent.

**Rollback point.** Each merge records its parent and the v2-baseline commit it
consumes. Reverting an attribution or shared-signature packet invalidates all
downstream combat evidence; the coordinator rewinds to the last green queue
commit and replays later packets in order. The train release rollback is the
last Train-1-compatible commit before Beam.

**Downstream unlocks.** A green combined audit closes the combat cross-packet
release gate, unlocks the optional Steam Impact serialization point and is one
of the four stable inputs to Rigger proof. It also makes the combat half of the
core release eligible, but not independently publishable from the other core
trains.

### 6.3 Train 3 — ship choice

**Entry criteria.** The corrected baseline is accepted. Arrival integration is
stable before the Signal Crane row. The coordinator has reserved the shared
save/UI queue and has a legacy-save fixture copied to an ephemeral store.

**Order.** Serialize `SH-01 → SH-02 → SH-03 → SH-04`. Keep the entire feature
player-hidden until all four rows pass. A development-only poser may expose
intermediate UI; a published build may not.

**Exit evidence.** The train record contains idempotent legacy reconciliation;
frozen run snapshots; bare ship and every existing single-fitting equivalence;
keyboard, controller and mouse navigation; save/refresh call counts; and exact
containment at 1280×720, 1600×900, 1920×1080 and 2560×1080. It also contains
empty/rival A/B evidence for every introduced point, all Powder Locker placement
and chain checks, Signal Crane's read from the unmodified live queue, its
availability statistic and a named clip where advance information changes
preparation.

**Failure action.** Failure of any row keeps the whole hardpoint feature hidden.
Never expose the three-functional-hardpoint cap after only the model/UI rows;
both Powder Locker and Signal Crane must be present and green. A migration
failure is repaired as a separately reviewed save defect if it cannot remain
inside the claimed packet. No failing rival is replaced by an unmeasured bonus.

**Rollback point.** Packet rollback is the parent of each merge; publication
rollback is the commit before the hardpoint model. Preserve the original
Workshop ownership keys throughout so rollback can read legacy state. Never
roll back by deleting earned fitting ownership.

**Downstream unlocks.** The four rows publish as one core unit. Stable hardpoint
UI enables both optional fitting rows and Rigger's control integration; stable
Signal Crane enables the final Rigger measurement set. Presets remain blocked
until all three points have measured rival choices.

### 6.4 Train 4 — campaign authorship

**Entry criteria.** Quartermaster and Sparking have stable accepted G3/G5
measurements; the distinct-seed instrument and baseline are green; no elite
repair is pending; and the authored threat baselines are recorded before any
wave row changes.

**Order.** Run `LV-02 → verdict → LV-03 → verdict → LV-04`. Do not begin the
next authored block while the prior block's measurement or human verdict is
pending.

**Exit evidence.** Each row records authored threat, held-rate agreement at the
tool's printed resolution, per-wave damage taken, clear time and lane travel,
plus every forced grammar/elite arm named by the design. The Last Watch record
also includes first-at-risk asset categories and both required Heat arms. The
boss row uses distinct seeds and records clear time, connected attacks,
boss/filler damage by source, target switches and turn/stomp visibility.

**Failure action.** Each packet receives only its declared single-variable
tuning pass: batch time for the first two rows and either filler timing or count
for the boss row, never both. Rerun the complete preregistered sample after that
one change. If the gate still fails, stop the train and revert the authored row;
do not compensate with enemy stats, tempo, Heat, bot policy or a second roster
variable.

**Rollback point.** The packet parent is the rollback for its authored wave
block. The train rollback is the commit before waves 5–7 were re-authored. A
reverted early block invalidates later Watch evidence even when their rows do
not textually overlap.

**Downstream unlocks.** Each accepted row may release independently after the
prior one. Stable final wave work satisfies a Rigger-train entry condition.
This train is not part of the core-release gate and cannot delay a green core
candidate.

### 6.5 Train 5 — optional depth

**Entry criteria.** The combined combat audit is stable before Steam Impact;
the relevant shared shape/element seams and hardpoint UI are stable; the core
train release points are recorded; and P3 failure has an explicit non-core CUT
path.

**Order.** Use two independently serialized branches:

- combat: `AB-05 → AB-06 → AB-07 → EL-04`;
- ship: `SH-05 → SH-06 → pick-split verdict → SH-07`.

The branch arrows are merge order even where the design lists a dependency as
serialization rather than mechanics. Presets do not start until the coordinator
records that every hardpoint has at least two demonstrated, situationally
distinct picks and all four rival fitting G5 verdicts are green.

**Exit evidence.** Combat evidence includes ordered-line behavior, motion
readability, Gale's control use, Mortar leading, Steam's realized/blocked-motion
seam and each exact CUT boundary. Ship evidence includes fire-heavy/fire-light
comparisons, Emergency Main control versus self-obstruction, bare/rival arms,
save/UI checks and the per-hardpoint pick-split decision. Preset evidence is
accepted only after the decision record exists.

**Failure action.** Preserve every failed P3 report and CUT only the failed row
or branch. Do not let optional depth hold trains 1–4 or an already-green core
release. However, Gale and Steam Impact must both pass before Rigger proof can
start; cutting either leaves the hero train blocked without blocking anything
else.

**Rollback point.** Each optional row rolls back to its own parent. Branch
release manifests name independent rollback commits. A preset rollback retains
the live hardpoint configuration and ownership; it removes only preset state
through the packet's migration-safe path.

**Downstream unlocks.** Stable Gale plus Steam Impact unlock the Rigger motion
and Tension seam. Accepted fitting rivals plus pick-split verdict unlock presets.
Neither branch is required for core release except where a later independently
chosen Rigger release consumes the combat branch.

### 6.6 Train 6 — Rigger proof

**Entry criteria.** `IN-00`, Signal Crane, final campaign wave work and Steam
Impact are stable; hardpoint UI/save behavior is available; the Rigger remains
player-hidden; and the comparison arms, key waves, distinct seeds and human
class-differentiation questions are preregistered.

**Order.** Run `HR-00 → HR-01 → verdict → HR-02 → verdict → HR-03`. Do not
commission unique art, animation or voice during this train.

**Exit evidence.** The gauge-mode row proves existing Captain and Boilerwright
fixtures unchanged. The first prototype verdict proves class differentiation,
targeted Tension generation from measured motion, source replacement and
ordinary/Armored/Boss rules before future spend can rescue the concept. The
second proves Make Fast and target/self Haul create control value rather than a
raw-damage loop. Final evidence includes class isolation, Article filtering,
three-column UI containment at all four sizes, waves 4/8/10/12, flat and forced
Pincer arms, bare/Barricade/Signal Crane arms, full control telemetry and a named
human statement that the Rigger is not a slower Captain.

**Failure action.** A class-collapse verdict stops before the next packet. Keep
the prototype unreleased and retain all reports if viability requires any of
the forbidden rescues named by the design. A failed Rigger packet never holds a
core, campaign or optional-fitting release. Repairs are separate claims; the
integration audit adds no new combat mechanic.

**Rollback point.** Each row records its parent; the train release rollback is
the commit before explicit gauge modes. Because the third class remains hidden
until the final release change, rollback must preserve existing two-class saves,
run logs and Article ownership byte-for-byte.

**Downstream unlocks.** A full pass authorizes release of the primitive Rigger
and a separate art/animation/voice brief. It does not authorize those assets or
another hero packet.

## 7. Measurement and evidence policy

### 7.1 G3 preregistration

No G3 row becomes `READY` until the ledger freezes all of these fields:

| Field | Rule |
|---|---|
| Primary statistic | One statistic named by the packet's intended decision. Supporting telemetry cannot replace it after results are seen. |
| Comparison arms | Before/after or forced on/off arms identical in seed, Heat, class, draft, fitting, wave and bot policy except for the declared variable. |
| Feature-off seam | Use the packet's existing environment seam, bare configuration or baseline commit. Do not invent a permanent gameplay flag only to produce evidence. |
| Distinct seeds | Default quotable general sample is 120 distinct seed strings. The manifest lists every seed. |
| Repetitions | Normally one. A greater value audits determinism only and never changes effective `n`. Any same-seed fingerprint variation fails the instrument. |
| Required resolution | Copy the tool's printed resolution and the packet's numerical/behavioral gate before implementation. If the resolution cannot establish the intended effect, increase distinct seeds or use a more targeted declared instrument. |
| Permitted tuning | `none`, or exactly the single variable/pass named by the packet. Record its initial and final value and rerun the full sample. |
| Verdict | `PASS`, `FAIL` or `UNRESOLVED`. An underpowered comparison is `UNRESOLVED`, never “no difference.” |

The 120-seed rule is a default for quotable general balance evidence, not a
license to use the wrong statistic. Forced deterministic geometry/timer
fixtures still use exact packet inputs. If a targeted packet instrument needs
fewer or more distinct seeds, the preregistration states why, reports its own
resolution, and never generalizes beyond it. Design-specific minimum fixtures
remain required in addition to, not as a replacement for, any general sample.

Boss evidence follows the same independence rule. Each seed/salt combination
must be distinct; repetitions do not increase effective `n`. If the boss tool's
current seed family cannot establish the preregistered effect, use additional
non-overlapping salted seed families or file a focused instrument expansion.
Never pool copies of one deterministic seed.

### 7.2 Evidence bundle

Every packet stores:

- its exact coordinator dispatch card and authoritative commit/cursor;
- exact focused and full-harness commands, exit codes and named check output;
- machine-readable raw results for each arm, seed manifest, effective `n`,
  intervals/resolution and summarized verdict;
- visual control and changed artifacts for G4, including zero-noise result;
- named G5 notes containing fixture, tester, date, decision, counterplay and
  pass/fail language;
- main/visual RNG findings and save/legacy/feature-off findings as applicable;
- actual file list, signature/caller audit, new state owner/reset/reader map;
- rollback parent, packet seam or revert command, stale downstream evidence and
  the coordinator's final result.

Automated proof, statistical measurement and human judgment are separate
fields. One cannot be cited as another.

### 7.3 Standard execution commands

Run gameplay commands from `skygear-godot/`. Record the actual Godot 4.7+
executable path used; arguments remain exact.

```powershell
# Full non-destructive harness
godot --path . --headless --script tests/parity_test.gd

# Standard general balance evidence after OPS-BAL-00
godot --path . --headless --script tools/balance.gd -- 120 0 none 1

# A determinism audit: twelve distinct seeds, two fingerprints per seed,
# effective n remains twelve and variation is an instrument failure
godot --path . --headless --script tools/balance.gd -- 12 0 none 2

# Boss evidence uses distinct salted seeds and one repetition
godot --path . --headless --script tools/boss_probe.gd -- 32 0 1 BOSS-A-

# Windowed UI and visual evidence; never add --headless
godot --path . --script tools/text_audit.gd
python tools/screen_review.py --tag after-PACKET-ID
godot --path . --script tools/clip.gd -- list
godot --path . --script tools/vfx_shot.gd
godot --path . --script tools/arrival_shot.gd
```

Before/after arms use identical arguments, ordered seed manifests and relevant
environment variables. The coordinator increases distinct seeds when the
printed resolution is insufficient. For boss samples larger than one seed
family, use non-overlapping salt prefixes and store every raw row before
pooling.

### 7.4 Failure, repair and CUT policy

A failed packet has three legitimate outcomes:

1. **Revert:** restore the recorded parent, retain evidence, mark downstream
   artifacts stale and leave consumers blocked.
2. **CUT:** use the declared feature-off seam or revert, record the explicit
   failed verdict and move the lifecycle to terminal `CUT`.
3. **Separate repair:** coordinator files and claims a defect with its own
   allowed files and evidence. After it merges, rerun the owning packet from
   the relevant lifecycle gate and rerun every affected audit.

No packet broadens itself into a repair. `IN-00`, arrival audits, baseline and
other audit-only work never alter gameplay in place. A failed G3 does not
authorize larger numbers beyond the packet's single declared tuning pass.

## 8. Release and rollback policy

### 8.1 Core release decision

The core release requires all of the following in one candidate:

- `OPS-BAL-00` merged, corrected distinct-seed baseline accepted and no open
  instrument failure;
- every Train-1, Train-2 and Train-3 row at least `MERGED`, with its required
  measurements and named human verdicts;
- the combat cross-packet gate green: all release-critical shared combat rows
  pass the complete combined audit and its human wave-12 readability verdict;
- the hardpoint cross-packet gate green: migration/UI and both first rival
  fittings are present, so the three-point cap is never exposed alone;
- the full harness exits zero on the release commit, all required named checks
  are present, `git diff --check` is clean, and visual/text evidence is current;
- a release manifest lists packet merge commits, exact rollback commits,
  evidence anchors and the coordinator/human names making the decision.

Trains 4–6 are independently releasable and cannot hold this core candidate
hostage. Optional P3 CUT decisions stay in the manifest as exclusions rather
than turning a proven core release red.

### 8.2 Later-train release decisions

- Campaign authorship releases only through the last contiguous green authored
  block; a failed later block does not retract a prior released one.
- Optional combat and optional ship branches release independently. Presets
  require the pick-split verdict even when their save/UI checks are green.
- The Rigger releases only as the complete four-row train after final class
  isolation, telemetry, UI and human differentiation verdicts. Until then the
  prototype remains hidden.

### 8.3 Rollback execution

Before publishing, rehearse rollback from the candidate manifest without
touching a player's real save. Restore the named train rollback commit or revert
the listed packet merges in reverse merge order, then run the full harness and
the train's feature-off/legacy checks. Save migrations must be forward-safe:
owned Workshop, Article and fitting data is never deleted to make an older
build load.

After a production rollback, record the deployed commit, reason, affected train,
retained evidence and downstream packets returned to `BLOCKED`. Never use a
branch name or an unrecorded working tree as a rollback point.

## 9. Coordinator validation checklist

Before this plan is used for dispatch, and again whenever its schedule changes:

- verify the canonical schedule contains 37 packet rows, one for every design
  inventory ID and no duplicate row ID;
- compare each row's prerequisite and serialization language with design
  Section 14, then confirm every prerequisite appears earlier than its consumer
  or is named as a cross-train entry gate;
- confirm `OPS-BAL-00` is labelled operational everywhere and is not counted as
  gameplay content;
- confirm all six train runbooks have entry criteria, exit evidence, failure
  action, rollback point and downstream unlocks;
- search command examples for the corrected 120-distinct-seed balance command,
  and reject any evidence prose that treats deterministic repetitions as added
  sample size;
- confirm the two cross-packet release gates, attribution-v2 boundary, one merge
  queue and coordinator-only board ownership remain explicit;
- run Markdown/reference searches and `git diff --check` from the repository
  root;
- confirm `git status --short` shows only this new companion beyond work that
  was already present before the documentation task.

This document-only change does not run Godot. Gameplay commands above are the
future execution contract; current validation is Markdown, reference, packet
inventory, dependency-order and repository-diff validation only.
