# Browser 2D feel and look audit

Updated 2026-08-02 after the Sentry/passive-skill pass and a real 390?844 touch probe.

## What is already working

- The V1 painted deck, brass/ink framing, warm sky, and restrained four-element color language are the right identity. Keep them.
- Mobile class and opening-draft cards now stack cleanly, and the raised joystick/action cluster no longer collides with the legacy skill bar.
- Combat has immediate hit-stop, screen trauma, damage numbers, enemy windups, and an auto-aim affordance. Those are the strongest feel anchors.

## Highest-impact next improvements

| Priority | Observation | Smallest style-safe improvement | Proof |
| --- | --- | --- | --- |
| P0 | Sentry is easy to miss while it is alive or recharging. | Keep the brass turret, but add a small element-colored status pip, a thin target line only while firing, and a 14-second life/recharge ring on its slot. | A player can answer ?where is my Sentry and when is it ready?? without looking at debug text. |
| P0 | Aimed skills still have weak range/landing feedback on touch. | Add a soft projected reticle/range ring for the currently held skill; use the same existing element tint as the card glyph. Hide it while the joystick is active. | Mortar, Pulse, and Sentry landing points are readable before release at 390?844. |
| P1 | Event waves are mechanically distinct but can feel like another banner. | Let each event own one restrained screen treatment: blackout darkens the perimeter, grapple keeps the hulk bar pinned near the objective, Colossus adds a short low-frequency shake on phase changes. | Event asks change what the player does, not only what the banner says. |
| P1 | The deck is attractive but several props still read as decoration. | Add tiny, persistent affordance marks only to interactive objects (vent glow, cannon health pip, Sentries, the Boiler). Do not add labels to scenery. | New players can identify vents, cannons, Sentries, and the Boiler in one glance. |
| P1 | Mobile skill slots are readable but dense during a wave. | Keep four slots; add a two-state ready/armed border and shorten labels to shape nouns on widths under 600px. Preserve the existing card art and palette. | No overlap, no unreadable 8px labels, and the player can identify the next action by silhouette. |
| P2 | Workshop/meta progression is richer than the title screen communicates. | Add explicit touch-sized WORKSHOP and BERTHS buttons to the title overlay; keep keyboard shortcuts as aliases. | A mobile player can reach the systems that already exist without knowing the O shortcut. |
| P2 | Audio communicates firing and damage but not state changes. | Add short, non-looping cues for Sentry deployed, Sentry expired, event start, and hulk opened/broken. Reuse the current SFX envelope; no new music layer yet. | Each new system has an audible acknowledgement without audio clutter. |
| P2 | Death/results are clear but do not teach the run. | Add a compact ?what ended the run? line and one highlighted learning stat (close time, Sentry damage, or Boiler damage). | Results answer what to change next run in under two seconds. |

## Guardrails

1. Do not replace the painted V1 deck with a new renderer or a glossy UI kit.
2. Every new visual must use the existing ink outline, brass frame, and element tint rules.
3. Mobile additions must be tested at 390?844 and 844?390; no control may cover the skill bar, Boiler bar, or draft confirmation.
4. A mechanic is not complete until it has a visible state, an input acknowledgement, and a regression assertion.
5. Prefer one strong telegraph over extra particles. The deck should stay calm enough that a player can read lanes.

## This pass

- Added real AURA ticks, PULSE auto-casts, and SENTRY deployment/autonomous fire.
- Added event metadata preservation, lane-aware spawns, blackout treatment, grapple/hulk objective, crew, and cannon fire.
- Added Captain pressure/vent HUD state and the regression markers that protect these systems.
