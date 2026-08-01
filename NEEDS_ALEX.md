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

**3 · Boilerwright mobility gap** (SG-7)
Measured at 67% less ground covered than a dashing captain (not the 21% the
stat sheet implies). Either he gets compensated somewhere feelable, or the
class-comparison screen states the trade plainly. The ledger's rule: no tuning
by feel. *Note: an agent is currently re-verifying the measurement itself
(SG-1) — hold this one until that lands.*

**4 · The captain is 30,634 triangles, 4–10× the project's own budget** (SG-13)
She was rightly skipped by the prop remesh (it would destroy her skin
weights). Options: local skin-weight-preserving decimation, a hand-authored
LOD, or accept the cost and record it. **Recommendation: accept for now** —
she's one asset, the build runs at half frame budget, and both alternatives
risk the one rigged character that works.

**5 · Drop chromatic aberration / radial blur formally?** (SG-19)
The research audit argues against them on readability grounds. Nobody has
made the call. **Recommendation: drop.** One word from you closes it.
