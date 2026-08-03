# Browser 2D feel and look audit

Updated 2026-08-02 after the mobile targeting/camera pass and a real 390x844 touch probe.

## Research notes from the other SkyGear builds

- The v4-v11 browser builds separate auto-attack from ability aim: the captain picks the nearest boarder and faces it, while abilities retain the mouse aim channel. That split is the correct desktop model.
- The lane build uses nearest-threat rules for cannons and crew rather than asking the player to micromanage every shot. That is the right mobile precedent: the player chooses the moment and build, not a pixel-perfect coordinate.
- The Godot reference uses a visible aim ring as a gameplay mark. The browser build should keep that vocabulary and use it for the current mobile target lock.

## What is already working

- The V1 painted deck, brass/ink framing, warm sky, and restrained four-element color language remain the right identity.
- Mobile class and opening-draft cards stack cleanly, and the joystick/action cluster now has its own readable lower band.
- Combat has hit-stop, screen trauma, damage numbers, enemy windups, auto-attack, and a visible nearest-target lock.
- On mobile, active abilities now smart-cast to the nearest live boarder when tapped. Desktop keeps explicit pointer aiming.

## Highest-impact next improvements

| Priority | Observation | Smallest style-safe improvement | Proof |
| --- | --- | --- | --- |
| P0 | Sentry is easy to miss while alive or recharging. | Add a small element-colored status pip, a thin target line only while firing, and a life/recharge ring on its slot. | A player can answer "where is my Sentry and when is it ready?" without debug text. |
| P1 | Smart cast chooses the nearest boarder, but elite/boss priority is not explicit. | Add a tiny TAP TARGET badge that cycles nearest, elite, and objective threat; keep nearest as the default. | A mobile player can override target priority without dragging a reticle. |
| P1 | Event waves are mechanically distinct but can still feel like another banner. | Give each event one restrained screen treatment: blackout perimeter, grapple hulk bar, Colossus phase shake. | Event asks change what the player does, not only what the banner says. |
| P1 | Several props still read as decoration at the new zoom. | Add tiny persistent affordance marks only to vents, cannons, Sentries, and the Boiler. | Players can identify interactive objects in one glance. |
| P1 | Mobile skill slots are clearer but still dense during a wave. | Keep four slots; add a ready/armed border and shorten labels to shape nouns below 600px. | No overlap, no unreadable labels, and the next action is recognizable by silhouette. |
| P2 | Workshop/meta progression is richer than the title screen communicates. | Add explicit touch-sized WORKSHOP and BERTHS buttons; keep keyboard shortcuts as aliases. | Mobile players can reach existing systems without knowing the O shortcut. |
| P2 | Audio communicates firing and damage but not every new state. | Add short cues for smart-target lock, Sentry deploy/expire, event start, and hulk opened/broken. | Each new system has an audible acknowledgement without adding music clutter. |
| P2 | Results do not yet teach the next run. | Add one "what ended the run?" line and one highlighted learning stat. | Results answer what to change next in under two seconds. |

## Guardrails

1. Keep the painted V1 deck, ink outlines, brass frames, and element tint rules.
2. Mobile additions must be tested at 390x844 and 844x390; no control may cover the skill bar, Boiler bar, or draft confirmation.
3. A mechanic is not complete until it has a visible state, an input acknowledgement, and a regression assertion.
4. Prefer one strong telegraph over extra particles. The deck should stay calm enough to read lanes.

## This pass

- Restored the separate auto-facing and active-ability aim channels from the v4-v11 browser model.
- Added mobile smart cast to the nearest live target plus a visible target-lock reticle.
- Zoomed the mobile camera modestly and moved the health panel into the upper-left HUD band so the map reads larger without losing the deck.
- Kept the existing AURA, PULSE, SENTRY, event, hulk, crew, cannon, and Captain pressure systems intact.