# NEEDS ALEX

Things only you can unblock or decide. The loop keeps this current: items
appear when they block work, disappear when resolved (git history is the
record). Board IDs refer to `skygear-godot/docs/BOARD.md`.

_Last updated: 2026-08-01_

## Blockers

**1 · itch pushes — `butler login`** (SG-6)
Everything else about building is working (template restored, zip verified).
Butler is installed; the login is interactive on your itch account. In this
session, type:
`! "%USERPROFILE%\.local\bin\butler.exe" login`
Until then: builds land in `skygear-godot/builds/itch/` and you upload by hand.

## Decisions

**2 · Boilerwright model route** (SG-12) — gates ~30+ Meshy credits
He currently renders as the captain. Two routes; **recommendation: route 2** —
generate the mesh, then retarget the existing axe-pack clips onto it via
`tools/ingest_model.py`. It is the only route where both classes move on the
same clock (his timings would match hers, which `anim_timing.gd` measures).
Route 1 (Meshy's own rig + animation library) is cheaper but his clips would
never match hers. Say "route 2 approved" and an agent runs it end to end.

**3 · Boilerwright mobility gap** (SG-7) — *measurement now settled*
The old 67% figure was one draw of a noisy check; SG-1 made it deterministic:
**he covers 40% of a dashing captain's ground** (a 60% gap — direction and
conclusion unchanged). Either he gets compensated somewhere feelable, or the
class-comparison screen states the trade plainly. The ledger's rule: no tuning
by feel. Ready for your call.

**4 · The captain is 30,634 triangles, 4–10× the project's own budget** (SG-13)
She was rightly skipped by the prop remesh (it would destroy her skin
weights). Options: local skin-weight-preserving decimation, a hand-authored
LOD, or accept the cost and record it. **Recommendation: accept for now** —
she's one asset, the build runs at half frame budget, and both alternatives
risk the one rigged character that works.

**5 · Drop chromatic aberration / radial blur formally?** (SG-19)
The research audit argues against them on readability grounds. Nobody has
made the call. **Recommendation: drop.** One word from you closes it.

## Check when you next play

- **Text legibility** (SG-9, fixed): the real hole was windows under 1600px
  downscaling every label to ~8 physical pixels; the window now enforces a
  1600×900 minimum and the audit measures physical size. But if 12px text
  at 1920 *still* feels small to you, say so — that's a deliberate
  grow-the-boxes layout pass, a different job, and it needs your eyes first.
- **Enemy telegraphs** (SG-3, rebuilt): melee windups now draw the browser's
  filled danger wedge at the true swing arc; melee reach shifted a few units
  to match the browser exactly (ARMORED slightly longer, SWARM slightly
  shorter). Worth a feel-check that nothing reads unfair.
- **HEAVE THE CRATE** (SG-10, new verb): hold the bound key at the movable
  crate to narrow a lane and funnel boarders; it cycles stow→narrow→funnel
  and re-stows every wave, costing only the 2.8s you're out of the fight.
  First new gameplay verb since repair — does it read, and is 2.8s right?
- **Cutscenes** (SG-8, all five cues now filled): a 2.5s run-opening reveal,
  1.4s flourishes on waves 4 and 8, a 5.4s victory crane-up to the horizon
  (the one angle gameplay never shows), and a 3.6s defeat push onto the
  Boiler. All skippable with click/space. These are taste calls made by an
  agent — your eyes needed.
- **Heat 3–5 exist now** (SG-14): COLD DECK (thinner drafts), BOARDERS ALOFT
  (a hulk every second wave), SKELETON CREW (no crew, half cannons), behind a
  five-rung ladder on the title. The balance bot says the grade is real —
  but it also went 0/6 at Heat 3 and died on wave 4 every time at Heat 5.
  The bot is not you; whether the upper rungs are brutal-fair or just brutal
  is a feel-call for a human clear attempt.
- **The Colossus wreck** (SG-15) now floats off the bow after your first
  Colossus kill — visible when you push forward, subject of the run-open
  crane. Judge whether it earns its place.
- **A fresh build is cut**: `skygear-godot/builds/itch/SkyGear-Windows.zip`
  (everything from today: telegraphs, legibility floor, Boiler scale, the
  heave verb, crate x-ray, five cutscene shots, Heat 3–5 + ladder, the
  wreck). Upload to itch by hand until `butler login` is done.
