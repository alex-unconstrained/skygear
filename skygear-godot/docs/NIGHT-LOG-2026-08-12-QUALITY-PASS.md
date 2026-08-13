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

---

## §8 · THE SECOND WAVE — the lamplit ceiling was enforced nowhere it was claimed

§7 named five survivors. This is the third of them, closed, and it turned out to
be larger than the audit had it.

### 8.1 What was actually true

`LAMPLIT_METALLIC_MAX = 0.34` exists because the owner looked at flat-albedo
brass at metallic 0.4 and called it **"very placeholder"** (SG-179). Under this
game's lamp-only rig — no reflection probe, no SSR, no environment map worth the
name — metallic above the ceiling has nothing to reflect but the lantern, so it
reads as tinted plastic rather than as brass. Two things were supposed to enforce
it, and **neither did**:

| Supposed to enforce it | What it actually asserted |
| --- | --- |
| `tools/lamplit.py audit` | that the **mean** texel was under the ceiling, while `clamp_metallic`'s own docstring guarantees the **peak** |
| `deck · the procedural deck obeys the same lamplit ceiling the models do` | that a float parsed out of a Python file equals a GDScript const. It never built a deck and never opened a material. |

A metallic map is a mask and is mostly dark by construction, so the mean of a map
whose brass is at 1.0 sits comfortably under 0.34. **Thirteen of forty shipped
models were over on peak and every one printed `ok`.** And beneath the table that
contained the disproof, the tool printed:

> *"13 carry an UNSET metallicFactor and pass anyway, because their map is dark
> enough that 1.0 x map stays under the ceiling."*

That is a claim about the peak, made by a function measuring the mean, and it was
false for all thirteen — four of which peaked at exactly 1.0. **Three failure
modes at once**: a detector reporting what it was not measuring (3), a claim
asserted rather than measured (4), and a guard green over the bug it is named
for (7).

### 8.2 What the player was looking at

Measured on the running game by `tools/metal_audit.gd` (new), which builds the
real deck and walks every `MeshInstance3D`:

```
309 surfaces walked, 39 distinct materials (16 built in code, 23 off disk)
MATERIALS THAT CAME OFF DISK: 15 over the ceiling of 23
  metallic 1.000  x4   Railing Segment      metallic 1.000  x4   Powder Keg
  metallic 1.000  x3   Cannon Deck          metallic 1.000  x3   Brazier
  metallic 1.000  x4   Crate Stack          metallic 1.000  x3   Crate Small
  metallic 1.000  x1   Mast Section         metallic 1.000  x5   Skyship Barge
```

The railing he runs along. The cannon. The crates every fight happens between.
The keg he detonates. The lit brazier. And on the code side, `band_mat` — the
brass capping and lashing straps — on **fifty-six instances**, waist to chest
height, through the middle of the play space, nearer the camera than either
surface SG-179 actually corrected.

### 8.3 The fix, and the instrument that had to be fixed first

Two lines in `lamplit.py` (judge `r[4]`, sort and filter on peak), the false
sentence replaced with what the tool can support, thirteen models through
`lamplit.py clamp` — which writes the factor and never touches a pixel — a forced
`godot --headless --import` of the thirteen, and nine `metallic` assignments in
`view3d.gd` brought to the constant. There is no other value left in that file.

**`tools/metal_audit.gd` reported twelve correctly-clamped models as failures on
its first run after the clamp, and that is recorded rather than quietly fixed.**
It was judging `BaseMaterial3D.metallic`, which is the *factor*; glTF's effective
metallic is factor × the map's blue channel, so `crate_stack`'s post-clamp factor
of 0.556 over a map peaking at 0.612 is an effective 0.34 and exactly right. **A
rig measuring the wrong number, inside the instrument built to catch a check that
measured the wrong number.** It judges only the flat code-built set now, defers
the mapped set to `lamplit.py` *by name*, prints the map flag rather than
assuming it, and shouts if a code-built material ever gains a map. One authority
per number.

### 8.4 The picture — and the measurement I had to withdraw

**READ 8.4b FIRST. The numbers in this section are struck.** They were taken
through `tools/prop_shot.gd` before anyone had asked that tool what its own noise
floor was, and when it was finally asked it answered **13.27%**. Two of the three
signals below are at or under that. The table is kept rather than deleted,
because a withdrawn measurement that is still on the page is the only kind the
next person can learn anything from.

### 8.4a What was published, and is withdrawn

`tools/prop_shot.gd`, three poses, 1600×900, identical seed and camera:
`.shots/sg291/before/` and `.shots/sg291/after/`.

| | pixels moved >8/255 | max delta | on those pixels: luma | warmth (R−B) | saturation |
| --- | --- | --- | --- | --- | --- |
| portrail | 9.5% | 205 | 45.3 → **47.0** | 35.94 → 37.04 | 38.84 → 40.08 |
| bow | 26.2% | 218 | 41.8 → **42.7** | 22.48 → 22.58 | 24.89 → 24.98 |
| hulk | 12.4% | 162 | 47.7 → **50.8** | 25.91 → 26.31 | 28.54 → 29.01 |

**8.4b — AND THEN THE INSTRUMENT WAS MEASURED, WHICH IT SHOULD HAVE BEEN FIRST.**
`prop_shot.gd` run twice against itself, one commit, one pinned seed, nothing
else running: **13.27% and 13.15% of pixels differ at the 8/255 threshold**, peak
disagreement over 200. `vfx_shot.gd` answers **22.45%** on the same question. Both
call `SkyGearStill.freeze()` for real and both pin a seed, so this is not SG-152's
comment-satisfies-the-check problem — the freeze is stopping the clocks it knows
about and something else is moving. Board **SG-295** carries the full measurement,
one hypothesis tested and rejected (pinning the sway made it *worse*, 13.27% ->
18.46%, and the edit was reverted rather than shipped with a comment its own
measurement refuted), and the leading unconfirmed one.

So: the change is real, the frames on disk are worth looking at, and **the claim
that it measurably improved the picture is not established by this session.** It
rests instead on `clamp_metallic`'s own stated guarantee, on 27 of 40 models
already sitting at peak exactly 0.3400 while 13 did not, and on a harness check
demonstrated red. That is enough. The picture claim was not.

**8.4c — AND THEN IT WAS MEASURED PROPERLY, WITH THE TOOL THE PROJECT ALREADY
HAD.** `tools/shiny_ab.gd` is titled *"THE METALLIC CEILING, AS A PICTURE"*. It
takes both plates inside ONE freeze with only that float changed, prints its own
noise floor first, and its header contains the sentence this session spent an
hour rediscovering: *"two runs of a shot tool never land the brazier flicker, the
particle clock and the cloud drift in the same place twice (SG-108)."*

**The repository knew. Nothing pointed at it, and I did not look.** That is the
sixth failure mode — a fact known in one place and contradicted in another — and
this pass committed it while closing three other instances of it.

Run with the clamped tree as plate A and `metallicFactor 1.0` restored in memory
as plate B:

```
NOISE FLOOR (nothing changed between two plates): 0.00%  (0.00 is the pass condition)
```

| model | % of frame | clamped luma | unclamped | warmth (R−B) | saturation |
| --- | --- | --- | --- | --- | --- |
| railing_segment | 1.49% | **58.17** | 40.76 | 42.84 / 32.27 | 44.40 / 34.17 |
| cannon_deck | 2.29% | **69.86** | 52.16 | 67.29 / 50.90 | 69.92 / 53.45 |
| powder_keg | 1.82% | **49.19** | 40.87 | — | 32.73 / 31.06 |
| crate_stack | 0.34% | 47.35 | 45.40 | 25.16 / 23.76 | 32.64 / 31.28 |
| brazier | 0.36% | 43.96 | 42.11 | 11.62 / 11.01 | 21.76 / 21.35 |

**The railing is 43% brighter clamped and the deck cannon 34%**, with warmth and
saturation up by a third on both. And the plates settle it by eye as well:
`cannon_deck-B.png` is glassy chrome-gold with a hard mirror highlight, outside
the deck's painted language entirely; `-A.png` is flat warm brass with tonal
shading — the style bible's *"brass = 2–3 flat tones + a hard specular stripe"*
rather than a mirror. SG-179's verdict and its correction, side by side, at a
zero floor.

*(The withdrawn reading from 8.4a, kept because it is instructive:)* my first
impression by eye was that the deck got warmer, and the numbers said otherwise — Global mean warmth moves +0.2% to
+0.4% — nothing. Exposure and hue balance are unchanged, which is the *right*
result for a change that should touch only metal. What changed is confined to
9.5–26.2% of the frame, is large where it lands, and on exactly those pixels the
surfaces get **brighter, marginally warmer and marginally more saturated**.

That is what taking metal off a surface does here: metal has no diffuse response,
so a near-metallic surface under a lamp can only return a cold specular
highlight. Below the ceiling the same surface takes the lantern as *painted
colour*. Which is the style bible's **"brass reads as brass by tone-stripe, not
by mirror metallic"** restated as a measurement rather than as a preference.

**It is player-visible, so it is mirrored to `/NEEDS_ALEX.md` with the A/B rather
than presented as settled** — even though it is conformance to a standard the
owner's own verdict produced, and even though twenty-seven of the forty models in
the same kit were already at peak exactly 0.3400. The inconsistency was the
defect; the direction of the fix is his to confirm.

### 8.5 Scorecard delta

| Domain | §5 | now | Why |
| --- | --- | --- | --- |
| Models & materials | not scored | **7** | Every shipped model and every code-built material is under the ceiling for the first time, and both halves of the enforcement now measure what they claim. Not higher: the captain still ships albedo-only with her own normal/rough/metal maps unbound on disk (audit rank 2, untouched) |
| Deck & environment | not scored | **7** | The near-camera prop kit no longer reads as tinted plastic. Untouched: the starboard hatch is authored inside a cargo wall (SG-294 territory), and boarders walk through the stern cargo stacks |
| Evidence discipline | 9 | **9** | Held. Two instruments were corrected mid-pass by reading their own output — the audit tool and one of my own checks — and both corrections are in the record rather than in a silent edit |

---

## §9 · CLOSING GATES

Run on the committed tree, machine idle, one Godot process at a time.

**Harness — `1285/1285 checks passed`, exit 0, `0 raised` script errors, `54
engine errors against a pinned 54`.** 1259 at the start of the session; **26 new
checks**, every one demonstrated red first.

**Performance, `profile_fight -- 60`, windowed 1600×900, vsync off:**

| | p50 | p95 | p99 | worst |
| --- | --- | --- | --- | --- |
| pre-pass `git stash` control | 7.57 | 11.46 | 13.74 | 53.08 |
| after wave 1 | 8.06 | 11.10 | 14.27 | 55.97 |
| **final, all three waves** | **7.71** | **11.21** | **12.91** | 54.74 |

**p99 12.91 ms against the 16.67 ms budget — and lower than the control it
started from.** That is not a coincidence and it is not an optimisation pass
either: SG-294's fix pushes shader parameters *on change* rather than *while
non-zero*, which removes a per-frame `find_children` walk from every rig that is
not currently flashing — most of them, most of the time. The old guard paid that
walk for exactly the rigs that did not need it.

The ~50 ms periodic spike is unchanged and unexplained, in the control as well as
in the result. It is **SG-290** and it is still nobody's new fault.

**Single-machine caveat, restated: one machine has ever been profiled.**

## §10 · WHAT THIS SESSION IS, HONESTLY

Twelve rows filed, nine closed, three left open on purpose. The closed work is
**seven defects of absence** — things that had never been asked for, in places
nobody had photographed — plus the two instruments that were supposed to have
caught them.

**The pattern is worth naming, because it is the whole yield of the pass:** every
single one of these was invisible to a check that asserted a function was called,
a tool that measured the wrong number, or a name that promised more than its
assertion delivered. The hero's death, the boarder's burn, the hit-stop, the
white flash, the ceiling — none of them was *broken*. Each was simply never
wired, under a green gate that said otherwise.

**And the pass committed two of the same class itself, both caught by measuring
rather than by reasoning:** a new tool that judged the metallic factor instead of
the effective value and called twelve correct models wrong, and a picture
measurement taken through an instrument whose floor was larger than the signal —
in a repository that already contained the right tool, with the reason written in
its header. Both are in the record at full length. That is the only way the next
person gets them for free.

**What is not done is named in §7 and on the board**, and the largest of it is
still the captain shipping albedo-only with her own maps unbound on disk.
