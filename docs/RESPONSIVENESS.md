# v4 — the responsiveness pass

Goal: make it read as a true ARPG/MOBA rather than a game you mash at. Every
change here is behind `PRESET.feel`, and the defaults reproduce v2/v3 exactly,
so those stay frozen as a record.

## What was actually costing the feel

Two things, and neither was frame rate.

**1 · Hit-stop was freezing the world on every kill, including trash.**
A flat 70ms sim freeze fired on *any* death. Measured against kill rate:

| scenario | kills/sec | sim frozen |
|---|---|---|
| wave 3, steady clear | 1.5 | **11%** |
| wave 8, cone into a pack | 4.0 | **28%** |
| wave 11, horde | 6.5 | **46%** |

At wave 11 roughly half of wall-clock time was spent not simulating. Input felt
mushy because the game genuinely was not listening.

**2 · No input buffering at all.** Pressing 20ms before a cooldown ended was
swallowed entirely — you had to press again. This is the single most common
reason an action game feels unresponsive, and the cheapest to fix.

## What v4 changes

| Change | From | To | Why |
|---|---|---|---|
| Sim rate | 60 Hz | **120 Hz** | Halves worst-case input-to-action latency (16.7ms → 8.3ms). Sim costs 0.38ms/step at 200 entities, so this is nearly free. |
| Input buffer | none | **140 ms** | A press just before ready fires the instant it comes up. |
| Hit-stop on kill | flat 70 ms | **per type**: swarm 0, grunt 30ms, armored 55ms, boss 100ms, plus a 100ms refractory | Trash dying no longer stops the world; big kills still land. |
| Cooldowns | — | **×0.80** | The original spec asked to bias shorter than feels right on paper. |
| Move accel / friction | 2400 / 1900 | **3100 / 2700** | Less slide on release; starts and stops closer to intent. |
| Dash cooldown | 1.6 s | **1.15 s** | Dash is the most important verb; it should be available. |
| Cast recoil | full | **×0.35** | Self-knockback on heavy casts was fighting the player's movement. |
| Camera follow | 155 ms | **75 ms** | The camera kept up instead of trailing the captain. |

## Auto-attack — the control-scheme change

The captain now has a basic swing that is genuinely automatic:

- picks the nearest boarder within **195 units**
- **turns to face it** (12 rad/s), so she reads as engaged
- swings every **0.55 s** for 16 damage, with a tight sabre-flick arc

Crucially, **the cursor still aims the four abilities**. Facing follows the
auto-target; aim follows the mouse. They are separate, which is exactly how a
MOBA behaves and it means you can auto-attack one thing while placing a mortar
somewhere else entirely.

Verified hands-off: 128 damage dealt in 3 seconds with the mouse parked away
from the fight and zero clicks, facing tracking the target to the degree while
the cursor stayed independent.

The consequence is the point: **LMB is now a real ability slot.** All four slots
are abilities on cooldown rather than something to mash. The auto-attack gets a
keyless `AUTO` pip on the HUD showing its cadence and whether it has a target.

## Balance note

Shorter cooldowns plus a free ~29 dps of auto-attack makes the player stronger.
The 12-wave curve has not been re-tuned for it — expect v4 to be easier than v3
until wave scaling is revisited. That is deliberate for a feel test; flagged so
it is not mistaken for the difficulty being right.

## Open

The auto-attack is always on. If it turns out some players want manual control,
a toggle is a one-line addition — but shipping it always-on is the cleaner test
of whether the scheme is better.
