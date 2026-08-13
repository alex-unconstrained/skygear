# NIGHT LOG — 2026-08-12, the quality-directive pass

Opened by opus/director against `d10443b` (the eight build-72 playtest fixes),
under `docs/QUALITY-DIRECTIVE.md`. Everything below is measured on this machine
in this session or it is marked as inherited.

---

## §0 · BASELINE, MEASURED BEFORE ANYTHING WAS TOUCHED (board rule 7)

### 0.1 The harness — GREEN

```
godot --path . --headless --script res://tests/parity_test.gd
1259/1259 checks passed
harness · the run raised no script errors           0 raised
harness · and no more engine errors than the ones already written down
                                                    54 engine errors against a pinned 54 (SG-153)
[exited with code 0]
```

**1259 checks, not the ~1245 the directive's ground-truth table states** — the
eight playtest-fix rows landed fourteen more after that table was written. The
count is read off the run, never off prose.

Two lines the run prints under the total and which are NOT counted as engine
errors by the pin: `WARNING: 12 ObjectDB instances were leaked at exit` and
`ERROR: 1 resources still in use at exit`. Both are at-exit teardown notices
raised after the last check has reported; they are pre-existing and unchanged.

### 0.2 Performance — MEASURED AND THEN THROWN AWAY, AND WHY

The first `profile_fight` run of the session:

```
godot --path . --resolution 1600x900 --script tools/profile_fight.gd -- 60
bucket        p50      p95      p99    worst
frame       10.56    16.93    20.39    59.58
script       5.93    11.30    13.68    51.31
physics      0.40     1.47     2.48     3.50
rd-cpu       0.75     0.99     1.23    14.14
rd-gpu       3.31     4.27     4.65     4.95
draws 998   prims 4,361,870   vram 801 MB   nodes 1750   rigs 69   boarders 63
```

**THIS NUMBER IS NOT EVIDENCE AND IS NOT USED ANYWHERE IN THIS PASS.** It was
taken while eight read-only audit agents were running ripgrep and python over
the whole repository, and the bucket it moved is `script` — the CPU bucket, the
one contention lands in. `rd-gpu` at p99 4.65 ms is the only bucket in that
table that can be read at all, and it says the GPU is not the constraint.

Recorded here rather than deleted because the fifth recurring failure mode is *a
measuring rig nobody measured*, and a profile taken on a loaded machine is the
same class of error with the load outside the process instead of inside it. The
real reading is taken on a confirmed-idle machine and appears in §4.

The inherited baseline it would have been compared against is **not the same
experiment either**: `docs/BOARD-ARCHIVE.md` records p50 4.40 / p95 6.31 / p99
7.96 / worst 8.71 ms at **40 boarders, windowed 2560×1440**, on a tree more than
a hundred commits old. Sixty boarders against forty is a different fight, and
the directive's own performance gate names sixty. Both counts are therefore
re-measured in §4 rather than either being assumed.

---

## §1 · WHAT THE DIRECTIVE SAYS THAT THE TREE NO LONGER SUPPORTS

The directive states, correctly, that the repo outranks its own summary. Checked
at HEAD, item by item:

| Directive claim | State at HEAD | Evidence |
| --- | --- | --- |
| "~1,245-check harness" | **1259** | the run above |
| "next free ID was SG-280" | **SG-282**, 39 open rows | `docs/BOARD.md:82`, `grep -c '^\| SG-' docs/BOARD.md` = 39 |
| "build 72 … held at the door", "not yet on itch" | **Build 72 is LIVE on both channels** | SG-270 DONE, `windows` #1878613 / `windows-demo` #1878614 |
| "`VFX-PLAN.md` §5 is still an open decision — make it a decision" | **DECIDED 2026-08-01 by the owner**, and the decision is written down | `skygear-godot/VFX-PLAN.md:116` — *"the chromatic hit and radial blur are DROPPED, by the owner"*, board SG-19 |
| "SG-217 … `react_hit` was a visual no-op … verify every enemy type actually receives it" | **FIXED.** `view3d.gd:1792 react_enemy_hit` exists and has a live caller at `game.gd:3864` | grep: three call sites total, one per figure class |
| "no landing animation exists for anyone" | half-stale — there is no landing *clip*, but `rig3d.react_land()` is real and is called on the frame a boarder stops being airborne | `rig3d.gd:782`, called `view3d.gd:9460` |
| "the swarm gremlin has no flinch — the only feedback a 20-hp boarder gives" | the *clip* gap is real (`swarm` ships 19 clips and none is a hurt) but it is no longer feedback-less: it takes the `react_hit` squash-and-flash like everything else | `assets/models/swarm/swarm.tscn` `metadata/clips`; `view3d.gd:1798` |
| `docs/superpowers/…` and `.superpowers/sdd/…` cited for the build-72 process | **neither directory exists in this repository** | `ls` |
| "`docs/skygear-visual-asset-spec-v1.md`" | lives at repo-root `docs/`, not `skygear-godot/docs/` | `find` |
| "`VFX-PLAN.md` §5" | lives at `skygear-godot/VFX-PLAN.md`, not under `docs/` | `find` |

None of this is a complaint about the directive — it says to recount before
trusting it. It is recorded because rule 2 makes an unverified claim evidence of
nothing, and because four of these rows would otherwise have become work.

---

## §2 · THE AUDIT — how the backlog was built, and what it threw away

Eight read-only specialists were run in parallel (animation · deck and props ·
materials · VFX and feel · audio · UI and type · palette drift · the harness and
the seven failure modes), then a synthesis agent that was told not to trust them:
**re-open the `file:line` each one cites, confirm the quoted code is really there,
and DROP anything you cannot confirm.** None of them ran Godot — the engine lock
was held by this session throughout, and every capture, probe and harness run in
this log is serial.

80 raw findings in; **33 ranked, 9 dropped.** The dropped list is the useful half,
because six of the nine are things the standing directive asserts that the tree no
longer supports:

- **the "legacy A/B graveyard"** (`_build_legacy_gunwale`, `edge_rail_legacy`,
  `shadow_legacy`, `strake_cap_mode`, `end_cap_mode`, `edge_stern_trial`) is
  **not dead code** — every one has a live consumer in `tools/edge_place.gd`,
  `tools/edge_ab.gd` or `tools/shadow_probe.gd`, and two are pinned from both
  sides by named harness checks. Deleting `strake_cap_mode` or `shadow_legacy`
  turns a check red. The one genuinely unreachable branch is the one the
  directive does not name: the procedural body of `_build_rigging`.
- **SG-267's "the ink pass's headless guard is inverted"** — two agents
  independently read `view3d.gd:1509` as `if DisplayServer.get_name() ==
  "headless": return`, which refuses correctly. The reachable half of that row
  (`set_deck_post` having no caller) stands; the "exact negation" half does not.
- **"#14121B has no code home"** — `hud.gd:1587 const PANEL_FILL := Color(0.078,
  0.070, 0.106, 0.94)` is exactly #14121B, written as a float triple, which is
  why every hex grep in this project has missed it.
- **SG-239's headline, "no durable encoder to .ogg exists on this machine"** —
  the audio agent found and RAN `imageio_ffmpeg`'s bundled ffmpeg 7.1 with
  libvorbis, at a persistent site-packages path. The pipeline half of that P1 is
  smaller than the row says.
- **the mipmap and 4096-map sweeps** — all eleven generating functions go through
  `_with_mips`, and the measured IHDRs turned up no uncut figure map.

Four of those would otherwise have become work. They are recorded here rather
than acted on, per rule 2: an unverified claim is evidence of nothing, in either
direction.

## §3 · WHAT WAS FIXED, AND WHY THESE FIVE

`docs/BOARD-ARCHIVE.md`'s **"The quality-directive pass — 2026-08-12"** block
carries the full evidence for each. In one line each:

| Row | The defect | The proof it was real |
| --- | --- | --- |
| **SG-282** P1 | The hero never died on screen. `_sync_all` skipped the entire player block once `hp <= 0`, and neither class had ever been asked for a death | negative control: `state idle, playing 'idle'`, and `drawn (0.0, 720.0) against sim (19.0, 720.0)` |
| **SG-283** P1 | Dying as the Captain held a card reading THE BOILER IS LOST over a Boiler at full health | negative control: `hero: 'THE BOILER IS LOST'` and `boiler: 'THE BOILER IS LOST'` — the same card twice |
| **SG-286** P1 | Hit-stop had never reached either moving body — `advance` gates `_process`, the bodies live in `_physics_process` | negative control: `frozen 11.400 units over 3 ticks`; boarders `moved 5.556, kept 223 u/s` |
| **SG-287** P2 | The hero's white hit flash was still a no-op; SG-217 armed every boarder and not her | negative control: `0 surfaces armed, 2 bare` |
| **SG-288** P2 | A figure with no flinch played its IDLE at the 4.00x attack clamp for the whole stun, under a check that asserted the missing flinch | negative control: `asked for 'hurt', got 'idle' at 4.00x` |

**They are one cluster, not five errands.** Four of the five are the same
sentence — *the moment a hit lands, or a run ends, the thing the player is
looking at does not react* — and the fifth is the card over the body. That is
the "weak or missing feedback on core actions" failure condition, four times.

**Two of the five were found by the other three.** SG-287 and SG-288 came out of
the audit pointed at SG-282's neighbourhood; SG-289 and SG-290 came out of
*photographing and profiling the fixes*, which is the whole argument for the
evidence discipline this project runs on.

## §4 · PERFORMANCE — the gate, and the thing the gate does not catch

All windowed 1600x900, vsync off, RTX 5080, machine confirmed idle, one Godot
process at a time. **The control is a `git stash` of this session's own diff on
the identical tree** — the only honest way to answer "did the pass cost anything".

| | p50 | p95 | p99 | worst | spikes over 33 ms |
| --- | --- | --- | --- | --- | --- |
| **60 boarders, with the pass** | 8.06 | 11.10 | **14.27** | 55.97 | 1 in 5 s |
| 60 boarders, stash control | 7.57 | 11.46 | 13.74 | 53.08 | 1 in 5 s |
| 40 boarders, with the pass | 6.86 | 9.60 | 13.64 | 55.68 | 1 in 4 s |
| *the only archived baseline* — 40 boarders at 2560x1440 | *4.40* | *6.31* | *7.96* | *8.71* | *—* |

**The gate holds: p99 14.27 ms at sixty boarders against 16.67 ms.** The pass
costs nothing measurable — its p95 is *lower* than the control's, and every
difference is inside this rig's run-to-run spread.

**What the p99 does not say** is filed as **SG-290**: one frame in every four to
five seconds costs ~50 ms, entirely in the `script` bucket (`rd-gpu` never
exceeds 3.6 ms in any run), and it is present in the control. Against the only
baseline this project has ever recorded — which had **no frame over 8.71 ms at
all** — that is a real change, at a *lower* resolution. It is filed, measured,
and deliberately **not attributed**: the comparison spans a hundred-plus commits
and two resolutions, and this pass did not cause it.

**Single-machine caveat, stated as the directive requires: one machine has ever
been profiled.**

## §5 · SCORECARD

Scored against the directive's own interpretation (7 professional · 8 highly
polished · 9 exceptional), and only for what this session actually looked at.
Unexamined domains are marked rather than guessed.

| Domain | Before | After | Why |
| --- | --- | --- | --- |
| Animation — the hero | 4 | **7** | She has a death, it holds, and her body is drawn where the sim put it. Still: no landing clip in the pack, and four states unreachable (SG-285) |
| Animation — boarders | 6 | **7** | The 4.00x borrowed-clip bug is gone from every stun in the game. The gremlin still has no flinch of its own (SG-284) |
| Game feel — impact | 5 | **8** | Hit-stop reaches both bodies for the first time. The constants behind it are now untested at their full strength — an owner playtest question, not a number to change quietly |
| Feedback on a hit | 5 | **7** | The hero flashes. Status tints on boarders are still a no-op (audit rank 3, unfixed) |
| Endings presentation | 3 | **6** | The card names the right defeat and there is a body to look at. The camera still frames the Boiler (SG-289) |
| Evidence discipline | 8 | **9** | 18 checks, all red-first, two tightened mid-proof, one detector repaired; a new tool that reported a zero floor on its first run |
| Performance | — | **7** | Gate holds at p99 14.27 ms; a ~50 ms periodic spike measured, filed and unexplained (SG-290) |
| Art direction · deck · materials · lighting · UI · audio | — | **not scored** | Audited, ranked, filed — not touched. Scoring a domain off a static audit is the mistake `docs/UI-UX-AUDIT-2026-08-11.md` is the cautionary tale for |

## §6 · EVIDENCE INDEX

- **Harness:** baseline `1259/1259`; final `1277/1277`, exit 0, 0 script errors,
  54 engine errors against the pinned 54. Six negative-control runs, at 1265,
  1267, 1269, 1270, 1274 and 1275 out of 1271–1277.
- **Clips (frame-locked pair):** `.shots/clips/sg282-captain-death/` and
  `.shots/clips/sg282-boilerwright-death/` — 120 frames each, 73 unique each,
  one seed (CLIP), one deck, one camera, wave 3, the real `damage_player` kill
  and the real auto-cue. `frame_0006.png` carries the corrected caption;
  `frame_0030.png` is SG-289's evidence.
- **Profiles:** four `profile_fight` runs — 60 with the pass, 60 stash control,
  40 with the pass, and one discarded contended run (§0.2).
- **Tool output:** `tools/graft_clip.gd --dry` and its write, both quoted in
  SG-282's archived row, including the zero root-motion floor.

## §7 · WHAT IS LEFT, STATED PLAINLY

The audit ranked 33 confirmed findings and this session closed five. **The
twenty-eight that remain are not lost** — they are in the synthesis and the ones
worth a row are filed. The largest, in the audit's own ranking:

1. **The captain ships albedo-only** — one texture bound where the furnace knight
   binds five, with her own normal/rough/metal maps sitting unbound on disk. The
   nearest, largest figure on screen, lit as flat albedo. (Tier 3, assets.)
2. **Burn, frost and stun tints are invisible on every boarder** — the status
   block tints a `Sprite3D` that has been null for every figure since the models
   were ingested. An EMBER build's whole identity has no channel on the target.
3. **The lamplit ceiling never reaches the figures** — `lamplit.py` globs `.glb`
   and the knight and the Boilerwright ship as `.res`, at metallic factor 1.0.
   And the audit tool judges on MEAN while its clamp guarantees PEAK, so thirteen
   props sit over the ceiling and it reports zero.
4. **Sixteen shipped `.ogg` files never play** — every multi-take family is
   hardcoded to its `_1` variant. Twenty-one boarders die to one sample.
5. **Standing in a fire pool locks the captain in the flinch clip** and re-fires
   the whole hurt chord four times a second.

None of those were touched, none are claimed, and each needs its own row before
it is worked. That is the next session's queue, not this one's omission.
