# Per-clip weapon binds — the plan

Alex, 2026-08-03, after hand-fitting the pike, the axe and the wrench:

> *"How do we more elegantly avoid clipping in certain animation loops or tweak
> position based on animation type? ... if we can identify in the lab which
> animations are used in game, and we can make separate binds for each that
> solves our problem."*

That is the right instinct and the scoping half of it is the valuable half.
Board SG-175. **Nothing here is built yet** — this is the plan, and it should
not be built until §6's evidence step says which clips actually need it.

---

## 1 · Why one static bind cannot win

A production rig ships a dedicated **weapon bone** (`prop_r`, `weapon_r`) that
sits under the hand and is *keyframed by the animator, per clip*. The weapon
inherits whatever the animator did, so "the axe clips his shoulder in swing3" is
fixed inside swing3, in the same file as the motion, at zero runtime cost.

**Our rigs have 41 bones, all `mixamorig_*`, and no prop bone.** They came from
body-only animation libraries. So the weapon hangs off `mixamorig_RightHand`
with ONE static transform that has to satisfy every clip at once. Hand-fitting
that is an over-constrained problem — there is no correct answer, only a least
bad one. That is what Alex was fighting.

## 2 · The scoping win: most clips can never play

The set of clips the game can ask for is **fully derivable** and much smaller
than the pack. `scripts/rig3d.gd` is the authority:

* `PRIORITY` is the whole state vocabulary — `die, hurt, turn, swing, jump,
  dash, plant, run, walk, idle`. Ten states, and nothing else is ever requested.
* `VARIANTS` expands two of them: `swing` -> `swing, swing2..swing5, spin,
  combo`, and `jump` -> `jump, jump2`.
* `_variant_of` filters to the clips a rig actually HAS; `_fallback` covers the
  rest.

Measured across the roster:

| figure | reachable | in the pack | never played |
|---|---|---|---|
| crew | **7** | 12 | strafe, strafe2, strafe3, strafe4, turn2 |
| armored (knight) | **14** | 51 | 37, incl. every block, cast, crouch, kick, draw |
| swarm (gremlin) | **9** | 19 | 10, incl. taunt, flex, four turn variants |
| captain | **10** | 14 | block, idle_alt, run_back, taunt |
| boilerwright | **15** | 51 | 36 |

**The furnace knight has 51 clips and 14 of them matter.** The lab's animation
bar shows all 51, so a fit was being judged against a row that is 73% noise.
Across the three newly-armed figures the entire surface area is **30 clips**,
not 82.

## 3 · Step one — make "reachable" a fact, in one place

Add `SkyGearRig3D.reachable_clips()`, derived from `PRIORITY` + `VARIANTS` +
what the rig has. **It must live in `rig3d.gd`** — that file already owns the
selection logic, and a second copy in the lab is precisely the two-derivations
failure this repo keeps paying for (`_deck_units` did it with the height formula
and quietly lied about every enemy for months, board SG-172).

Then:

* **The lab marks the bar.** Reachable clips lit, unreachable dimmed, with a
  count in the header and a key to hide the dead ones. Judge a grip against the
  14 that play, not the 51 that exist.
* **A harness check** asserts the lab's list is `rig3d`'s list, exactly as
  `rune · the telegraph prefixes the mask hides are the ones view3d actually
  draws` holds `rune_read` to `_decal_class`.

This step is worth doing **on its own**, before any per-clip binding, because it
makes every future fit cheaper and answers Alex's actual question.

## 4 · The data — deltas, not absolutes

In `weapons.json`, under a character:

```
"armored": {
  "bone": "...", "offset": [...], "rotation": [...], "length": 1.20,
  "weapon": "axe_furnace",
  "clips": {
    "swing3": {"offset": [0, 0.02, -0.03], "rotation": [0, -8, 0]}
  }
}
```

**Deltas onto the base fit, never absolutes.** With absolutes, nudging the base
grip silently invalidates every override; with deltas the base stays the one
place the grip is authored and an override says only "and in this clip, a bit
more". Absent clip = no entry, which is the normal case.

## 5 · The runtime — move the holder, do not rebuild it

`rig3d.hold()` tears down and rebuilds the weapon node. Calling it on every clip
change would rebuild a mesh several times a second and re-measure the blade tip
each time. Instead:

* Keep the holder; on a state change, **lerp its transform** toward
  `base + delta` over the same `BLEND[state]` the animation crossfades on. The
  fade already exists and the weapon should ride it, or the blade snaps while
  the body eases.
* One-shots (`swing`, `dash`, `hurt`, `die`, `plant`, `turn`, `jump`) hold their
  delta for the clip's own length and release with it, which `_one_shot_until`
  already tracks.
* `mount_weapon()` stays the single place the base fit is applied.

## 6 · The evidence step — and it comes FIRST

**Do not author a single override before this.** Extend `tools/grip_sheet.gd`
(which already shoots grips through the real `main3d.tscn`) to walk every
*reachable* clip for each armed figure at a few frames each, and stitch one
contact sheet per figure. 30 clips across three figures is a small sheet.

Then look, and write down which clips are actually bad **at the shipped camera**
— a centimetre of shoulder intersection on a 180-pixel figure at 41 degrees is
invisible, and half of what looks wrong in the lab's close-up orbit cannot be
seen in play. The overrides get authored only for what survives that test.

Expect the honest answer to be two or three clips, most likely among the swing
variants, and quite possibly none for the gremlin.

## 7 · Checks the feature needs

* Every `clips` key names a clip the rig HAS **and** that the game can reach —
  otherwise it is dead data. `grip_at` is the cautionary tale: authored for all
  six weapons and, until SG-171, read by nothing in the game.
* A clip with no entry renders byte-for-byte what it renders today.
* The override count is reported. If it grows past a handful the answer was
  never per-clip binds — it was that the base fit is wrong, or that the figure
  needs §8.

## 8 · What this does NOT solve — the pike

Per-clip binds move a rigidly-held weapon. They cannot make a **second hand**
track a shaft. The crew pike is held two-handed and levelled, and the off hand
will drift or clip through it no matter what the mount says.

That is the IK case: the weapon carries a second grip socket and the off hand is
constrained onto it (Godot 4 skeleton modifiers). It is the correct fix, it is
strictly more work than everything above, and it is worth doing only if the
pike's off hand actually reads badly in play — twelve crew are on deck at once,
which cuts both ways: most-seen weapon, smallest on screen.

## 9 · Order

1. `reachable_clips()` + the lab marking + the harness check. *(cheap, useful alone)*
2. The contact sheets. *(evidence)*
3. Read them, decide, and only then build §4/§5 for the clips that earned it.
4. Revisit the pike's off hand separately, or leave it.
