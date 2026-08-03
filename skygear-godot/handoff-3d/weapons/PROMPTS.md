# Weapons — three models, hand-made, same pipeline as the ship kit

Requested by Alex, 2026-08-03: *"We still need to make 3D models of weapons. I
can do that work manually just like I did for the ship kit."* The ship kit
worked, so this follows it exactly.

**Weapons are a separate bone-mounted layer in this game and always have been.**
`assets/models/weapons.json` mounts a weapon onto a named bone with an offset,
a rotation and a grip point. That is why the captain's cutlass and the
Boilerwright's wrench are their own files, and it is why a character model must
arrive **empty-handed, in a clean T- or A-pose, with no accessories** — a weapon
modelled into the fist cannot be swapped, dropped, or re-fitted.

## What exists today

| | mounted | weapon file |
|---|---|---|
| Captain | yes | `sword_cutlass` |
| Boilerwright | yes | `wrench_pipe` |
| *(spare)* | — | `sword_gearblade` |
| **Crew** | **no — empty hands** | **needed** |
| **Furnace knight** | **no — empty hands** | **needed** |
| **Gremlin** | **no — empty hands** | **needed** |
| Colossus | n/a — fights with fists | — |
| Gunner drone | n/a — no arms, it flies | — |

The knight and the crew are the two you have named. The gremlin is the third
because its painting also carries a weapon and its model does not.

---

## 1 · THE CREW'S BOARDING PIKE — do this one first

**Reference:** `assets/art/allies/crew_front_attack.png`. He holds it
**two-handed, levelled**, which is the pose the game plays most.

A long straight haft of dark timber banded with iron, a **leaf-shaped
spearhead with two swept-back barbs** at its base, and a brass ferrule where
head meets haft. Plain, issued, and slightly worn — this is a sailor's boarding
weapon, not a knight's.

**Why first:** twelve crew are on the deck at once, so it is the most-seen
weapon in the game, and it is the simplest shape here.

**Length:** ~1.9 model units, matching the existing weapons. Grip is roughly a
third up from the butt — the manifest's `grip_at` will be tuned in the lab, so
model it honestly and I will fit it.

---

## 2 · THE FURNACE KNIGHT'S AXE

**Reference:** `assets/art/enemies/furnace_knight_front_attack.png`. He holds it
**one-handed, raised overhead** in the attack frame.

A **double-bladed axe**: two broad crescent blades back to back, each with a
scalloped cut-out and a **brass star boss** at the centre of the head. The haft
is banded timber with iron collars and a **heavy brass pommel cap**. Blackened
steel and warm brass, honestly worn.

**Why he has empty hands:** the animation pack that rigs him is a great-sword
pack, so his fists close on nothing. The axe is the fix.

**Length:** ~1.9 model units. It reads as *heavy* — the head should feel like it
has mass, since his whole redesign is about a slow, telegraphed, hard-hitting
swing.

---

## 3 · THE GREMLIN'S PIPE WRENCH

**Reference:** `assets/art/enemies/gremlin_front_attack.png`. Held **one-handed,
swung low**.

A scrap-built **pipe wrench**: a heavy toothed jaw at the head, an adjusting
screw and a small gauge on the body, all brass and blackened iron over a
banded grip. Salvage-made, mismatched, and cheerfully overbuilt — it should look
like it was assembled from three other tools.

**Deliberately distinct from `wrench_pipe`**, which is the Boilerwright's and
reads as a working engineer's tool. This one is a weapon a goblin made.

---

## The rules that make these drop straight in

Everything in `../README.md` holds. The ones that matter most here:

- **GLB, Y up, metres.** Model it **along one axis, pointing +Z**, so the mount
  rotation starts from something sane.
- **No hand, no arm, no character.** The weapon only.
- **No ground plane, no base, no plinth, no display stand.** This pipeline's
  most common failure — a prompt that called a character a "prop" once returned
  a suit of armour on a stand.
- **House palette, flat albedo, no baked lighting or shadow.** The deck's
  lighting is real, and a model carrying painted-in shadow fights it.
- **Metalness matters now.** Everything ships with metalness unset, which glTF
  reads as *fully metallic*, and this deck is lamp-lit — that was the Colossus's
  texture bug. The ingest clamps it (`tools/lamplit.py`), so you do not need to
  do anything, but do not bake a mirror finish into the albedo either.
- **≤4,000 triangles each.** These are small objects seen at a 41° camera; a
  weapon does not need the budget a hull does.

## Delivery

Drop the files anywhere and tell me the path. Ingestion is one manifest entry
and one pipeline run, **zero credits**. Then the fit is done in the lab:

```
model_lab --fit crew        # and --fit armored, --fit swarm
```

which is the same fitter your cutlass fit lives in. Expect to nudge the grip
rotation once per weapon; that is normal and it is two minutes each.

**If a generation comes back wrong twice, stop and tell me** — the standing rule
is two failures then escalate rather than burning attempts.
