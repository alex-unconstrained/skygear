# SKYGEAR V10 — Public Playtest Release Contract

**Codex proposal · 2026-07-26**  
**Status:** Proposed scope for review after the V9 playtest  
**Intended release:** The first build we deliberately put in front of people as a coherent game, not merely the next technical experiment

---

## 0. Executive decision

V10 should be treated as **Skygear's public vertical-slice release**.

That means V10 is not successful because it contains more systems than V9. It is
successful when a new player can open one link, understand the objective,
control the captain confidently, make interesting build choices, read the
three-lane battle, experience a satisfying finale, and either finish or fail
without encountering an obvious placeholder, unexplained system, broken state,
or avoidable technical problem.

The recommended V10 strategy is:

1. **Freeze V9 as the final experimental baseline.**
2. **Use the V9 test to answer a short list of design questions before locking
   V10 balance.**
3. **Make V10 one canonical build.** Older versions remain available as
   history, but the landing page should present V10 as the game.
4. **Prioritise comprehension, feel, cohesion and evidence over feature count.**
5. **Finish the presentation pipeline:** still art, motion, VFX, UI, menus,
   sound, music and results reporting.
6. **Do not add meta-progression, additional heroes, endless mode or a relic
   system until the public build proves that one complete run is worth
   repeating.**

The phrase to use when deciding whether something belongs in V10 is:

> **Does this make the first complete public run clearer, more satisfying or
> more trustworthy?**

If the answer is no, it is not V10 work.

---

## 1. The V9 baseline — facts, not impressions

This proposal is grounded in the repository at clean `main`, with V9 at commit
`1369cab`.

| Area | Actual V9 state |
|---|---|
| Core format | Single-player steampunk hero-defence on a three-lane airship deck |
| Campaign | 12 waves; push waves at 4, 8 and 12; Colossus finale |
| Objective | Protect the stern Boiler while rotating between lanes |
| Friendly systems | Three deck cannons, recurring crew reinforcements, player-only cross-passages |
| Enemy roster | Scrapper, Gunner drone, Armoured Furnace Knight, Gremlin swarm, Colossus boss |
| Skill shapes | 9 engine shapes: Cleave, Lance, Gale, Mortar, Whip, Beam, Field, Pulse and Sentry |
| Elements | Ember, Frost, Arc and Steam |
| Matrix | 9 × 4 = 36 engine combinations; the duplicate slotted Cleave is deliberately excluded from normal skill drafts because Ember Cleave is the fixed auto-attack |
| Draft content | 36 card definitions in code, despite older documentation still saying 34 |
| Starting combat | Automatic Ember Cleave plus Frost Mortar; later slots are armed through mandatory weapon drafts |
| Passive shapes | Field, Pulse and Sentry occupy slots and use `AUTO` HUD treatment |
| Responsiveness | 120 Hz simulation, 140 ms input buffer, per-enemy hit-stop, faster movement response, 1.15 s dash |
| Art | 32 of 67 still-image manifest slots present |
| Missing still art | 35: 7 props, 3 environment, 7 ground, 6 FX and 12 UI |
| Animation | Two front run cycles exist as 28 loose 512 px frames; the approved future format is 19 packed strips |
| Audio | 6 of 54 manifest keys delivered: five SFX cue groups and one combat music track |
| Current static footprint | Approximately 22.88 MiB across V9 HTML, assets and delivered audio |
| Instrumentation | Build stamp exists; deterministic seeded runs, persistent run logs and copyable run reports do not |
| Automated evidence | Asset and animation validators exist; a reproducible committed end-to-end gameplay harness does not |

### 1.1 Documentation drift is already a product risk

The current README still describes a 6 × 4 matrix, 24 combinations and 34
cards. V9 has nine shapes and 36 card definitions. Several handoff and roadmap
sections also describe older asset counts and earlier live versions.

V10 must establish one generated or verified source of truth for:

- live version and build ID;
- player-visible matrix claim;
- card count;
- asset completion count;
- animation completion count;
- audio completion count;
- controls;
- shipped modes and supported platforms.

This is not cosmetic documentation work. A public player, tester or parallel
agent making decisions from stale information can build, test or explain the
wrong game.

### 1.2 The current art count is not a complete quality metric

The title reports resolved assets from the still manifest, but the manifest has
three UI entries that are loaded and never consumed:

- `icon_skill_dash`;
- `icon_skill_barrier`;
- `icon_currency_cog`.

At the same time, V9's three passive shapes have no painted icon slots:

- Field;
- Pulse;
- Sentry.

V10 should either wire an asset to a real visible consumer or remove it from
the production completion count. The title should report art that a player can
actually see.

### 1.3 V9 is the learning gate for V10

Do not interpret one V9 run only as “fun” or “not fun.” Capture answers to the
questions below:

1. Did the player understand that Ember Cleave is automatic?
2. Did they understand which slotted skills were active and which were passive?
3. Did passives reduce button pressure, or did they feel like dead slots?
4. Did the player finish with four useful skills?
5. Did a recognisable element or shape build emerge?
6. Did the player rotate lanes deliberately or merely chase the nearest target?
7. Were the two cross-passages discovered without explanation?
8. Did the minimap/lane readout identify danger early enough to act?
9. Were push waves tense, or simply long?
10. Did leaving the Boiler to attack the hulk feel like a meaningful trade?
11. Did the boss feel like a finale or a larger health bar?
12. Did the music improve the run or become repetitive?
13. Which procedural or missing presentation element was most noticeable?
14. Was the difficulty appropriate, and where did pressure first feel real?
15. Did the player want to restart after victory or defeat?

These answers determine tuning and presentation priority. They should not be
used to reopen the settled billboard camera decision unless the V9 test reveals
a new, reproducible readability failure.

---

## 2. V10 product promise

### 2.1 One-sentence public pitch

> **Defend a storm-lit airship across three pressured lanes, combining
> steampunk weapons and elemental machinery into a build strong enough to
> survive twelve boarding waves.**

### 2.2 What the player should feel

- **Immediately capable:** movement, dash and automatic cleave feel good before
  the player understands the build system.
- **Constantly informed:** the player knows which lane is failing, what the next
  threat is, why a skill is unavailable and what an upgrade changed.
- **Pulled between priorities:** defending the Boiler, saving a cannon, helping
  crew and attacking the hulk create decisions rather than chores.
- **Proud of the build:** by the end, the player can describe what they made in
  one sentence.
- **Rewarded by spectacle:** push waves and the boss change the visual and sonic
  intensity of the run.
- **Respected on failure:** defeat explains what happened and offers a fast,
  frictionless retry.

### 2.3 Target run profile

These are starting targets to validate, not arbitrary promises:

| Measure | V10 target |
|---|---|
| First meaningful choice | Within 90 seconds |
| First-time player run | Reaches approximately wave 6–9 |
| Competent player win rate | Approximately 30–50% on the default difficulty |
| Successful run duration | Roughly 14–20 minutes |
| Wave 4 push | Usually resolved within 45–75 seconds |
| Wave 8 push | Usually resolved within 55–90 seconds |
| Wave 12 finale | Usually resolved within 75–120 seconds |
| Immediate replay intent | At least 30% of external testers choose or say they would choose “Play Again” |

The important constraint is that no wave should stall indefinitely. If a
player is alive and the Boiler is alive, the game must still be visibly
progressing toward a conclusion.

---

## 3. Scope model

### 3.1 P0 — release contract

Every P0 item is required for the build to be called V10:

- V9 feedback captured and converted into explicit decisions;
- one canonical V10 build and one primary landing-page action;
- deterministic run seed and committed gameplay smoke harness;
- clear first-run onboarding;
- complete title, settings, pause, draft, victory and defeat flows;
- full visible HUD art and correct icons for all shipped shapes;
- no visible procedural stand-in caused by a missing production asset;
- a deliberate animation state for the captain and every frequently seen unit;
- coherent sampled audio for every high-frequency gameplay event;
- boss finale with distinct phases or behaviours and strong telegraphs;
- balanced 12-wave default campaign;
- keyboard/mouse remapping and usable volume controls;
- reduced-motion, screen-shake and high-contrast options;
- performance and memory budgets met on ordinary desktop hardware;
- clean package for GitHub Pages and itch.io;
- no critical or high-severity known bug;
- a copyable run report and structured playtest evidence.

### 3.2 P1 — ship if it strengthens the same run

P1 items may ship only after all P0 exit gates are green:

- Rigging Wraith as one new harassment archetype;
- a second difficulty preset;
- richer captain voice barks;
- optional codex/help screen for shapes, elements and enemies;
- extra environmental parallax events;
- additional low-frequency animation cycles;
- additional results breakdowns and personal-best comparisons;
- photo-mode or clean screenshot toggle.

P1 work must have a clean cut line. V10 must not be delayed because a stretch
feature is partially integrated.

### 3.3 Explicitly not V10

- additional playable heroes;
- endless mode;
- relics as a second progression system;
- account creation;
- cloud saves;
- online leaderboards;
- multiplayer or co-op;
- meta-progression or permanent unlock trees;
- mobile/touch support;
- procedural map generation;
- multiple new levels;
- a wholesale renderer rewrite;
- a new engine or WebGL migration;
- a marketing website larger than the game needs.

These may be excellent V11 ideas. They are dangerous V10 ideas because they
expand the number of systems that need balancing and explaining before the
first public run is complete.

---

## 4. Gameplay and combat deliverables

### 4.1 Make the 9 × 4 system truthful and legible

V10 should treat the expanded shape set as a design system, not merely more
entries in an object.

Required:

- Verify every shape-element cell through a deterministic matrix harness.
- Record whether each cell deals damage, applies its element and terminates
  correctly.
- Verify passive shapes never read held input.
- Verify active shapes never display the `AUTO` treatment.
- Verify cooldown, damage, range and element-wide cards affect the intended
  cells.
- Verify Twin Cast, Residue, Fifth Gear and kill-trigger cards do not create
  recursion, unbounded sentries or excessive particles.
- Decide the canonical public claim:
  - “36 engineered combinations,” with an explanation that Ember Cleave is the
    fixed basic; or
  - a more conservative “eight weapons × four elements, plus Ember Cleave.”
- Update title, README, help copy and results reporting to use the same claim.

### 4.2 Active/passive trade

Passives should be useful without making active play irrational.

Acceptance targets:

- Against a representative four-target scenario, a passive should deliver
  roughly 70–90% of a competently used active's sustained value.
- A passive may exceed an active only in the exact crowd geometry it is
  intended to reward.
- Sentry count and lifetime must be capped visibly and technically.
- Pulse must communicate its next trigger without demanding stopwatch play.
- Field must make its radius readable without covering the deck in opaque
  colour.
- Passive upgrade cards must show the resulting change immediately.
- A player should be able to finish with zero, one or two passives without one
  of those routes being obviously dominant.

### 4.3 Draft quality

The draft is the centre of the replayable loop. V10 should improve its clarity
before increasing card count.

Required:

- Weapon drafts clearly state that the slot will be armed after the choice.
- Passive cards carry an explicit `AUTO` badge.
- Each choice shows shape, element, target slot and the plain-English effect.
- Upgrade cards show a **before → after** number where practical:
  cooldown, damage, radius, range, jump count or duration.
- Element-wide cards list the affected equipped skills.
- Rarity is communicated by both colour and ornament, not colour alone.
- Cards never present an option that cannot currently change the run.
- Three choices remain visually readable at 1280×720.
- Keyboard and mouse selection both work.
- Draft appearance and dismissal have short, skippable motion and matching
  sound.

### 4.4 Lane defence clarity

The player cannot stand in all three lanes. The information model must make
off-screen failure feel fair.

Required:

- Lane status shows:
  - live threat count;
  - furthest enemy progress;
  - cannon state/health;
  - whether crew are present;
  - critical Boiler pressure;
  - hulk vulnerability during a push.
- A lane entering critical state produces one restrained visual and audio alert.
- Repeated alerts have a cooldown so a losing lane does not become noise.
- The two player-only passages are visibly marked on the deck and on the lane
  readout.
- No solid prop, wall seam or decoration creates an invisible collision edge.
- Off-screen enemies that can damage the objective are represented before the
  damage lands.
- The player remains visually dominant over x-ray silhouettes and large props.

### 4.5 Push waves

Push waves are the signature strategic event. They should not feel like normal
waves with an extra health bar.

Each push should have:

1. a clear incoming-hulk announcement;
2. a physical grapple/arrival event;
3. a visible sealed-to-open transition;
4. a distinct music or mix state;
5. a clear choice between protecting the stern and attacking the bow;
6. escalating reinforcements that prevent passive waiting;
7. a decisive break event;
8. a brief recovery beat before the next draft.

Hulk health values should be tuned from human run times, not only a bot. Wave 4
must teach the push structure without consuming most of the Boiler. Waves 8 and
12 may demand stronger commitment, but they must remain recoverable after one
mistake.

### 4.6 Enemy role clarity

Every enemy needs one readable question:

| Enemy | Player question |
|---|---|
| Scrapper | Can I clear the basic lane body before it reaches my line? |
| Gremlin swarm | Do I have area coverage or movement to avoid being surrounded? |
| Gunner drone | Will I interrupt or dodge the ranged pressure? |
| Furnace Knight | Can I reposition around armour and stop the heavy hit? |
| Colossus | Can I read and answer the current boss pattern? |

Required:

- Distinct silhouette at typical and distant scales.
- Distinct telegraph language.
- Attack frame and sound occur at the correct gameplay moment.
- Death response matches mass.
- Target priority is understandable when enemies choose captain, crew, cannon
  or Boiler.
- No enemy becomes dangerous solely because it was hidden behind another
  billboard.

### 4.7 Optional Rigging Wraith decision

The original visual specification describes a Rigging Wraith, but V9 has no
gameplay counterpart or live asset slot.

Include it only if V9 testing shows the lane campaign needs one more tactical
role. Its purpose should be specific:

- ignores or crosses cargo-wall lanes in a telegraphed route;
- pressures a distant lane or briefly disables a cannon;
- has low durability and a strong approach tell;
- creates a rotation decision without dealing surprise objective damage.

If implemented, it needs:

- AI and wave-table entries;
- front idle and front attack stills;
- a restrained float/attack animation plan;
- one approach cue, one attack cue and one death cue;
- lane/minimap representation;
- full deterministic and human balance coverage.

Do not add it merely because concept art exists.

---

## 5. Boss and finale

The Colossus now has a coherent production identity, attack pose, back view and
wreck. V10 must give that art a finale worthy of it.

### 5.1 Recommended three-beat fight

**Beat 1 — Artillery posture**

- Cannon arms use clearly marked lanes or sectors.
- Fist arms remain defensive.
- Player learns that the boss has multiple weapon systems.

**Beat 2 — Furnace overdrive**

- At approximately 60% health, the furnace opens brighter.
- Attack cadence increases modestly.
- One slam or radial pressure pattern is introduced.
- Adds remain controlled; the fight should become richer, not visually opaque.

**Beat 3 — Last pressure**

- At approximately 25% health, the Colossus loses restraint rather than merely
  gaining health.
- Shorter recovery or alternating cannon/fist patterns create urgency.
- The Boiler remains threatened, preserving the defence identity.

### 5.2 Finale requirements

- Boss intro never removes player control for more than a brief beat.
- Each dangerous action has a readable anticipation, active window and recovery.
- Telegraph colours obey the friendly/enemy palette.
- The boss cannot cover critical lane information.
- The fight uses the Colossus attack sprite or animation at the actual strike.
- Boss death replaces the entity with `colossus_wreck`.
- Music transitions to boss state and resolves into a victory sting.
- Victory waits long enough for the wreck and release of tension to register.
- Results screen follows without a white flash or abrupt audio cut.

---

## 6. Onboarding, UI and menu release

V10 needs a complete interaction shell. The current code-drawn screens are
functional, but they are not yet a coherent product-level interface.

### 6.1 First-run onboarding

Use short contextual prompts, not a large mandatory instruction panel:

1. Move and cross a lane boundary.
2. Show that Ember Cleave attacks automatically.
3. Cast Frost Mortar.
4. Dash through danger.
5. Identify the Boiler and lane readout.
6. Explain a weapon draft when the first new slot opens.
7. Explain `AUTO` only when the first passive appears.
8. Explain the hulk when the first push begins.

Requirements:

- Prompts disappear after the action is performed.
- Completed tutorial state is stored locally.
- “Replay tutorial tips” is available in settings.
- A returning player can disable tips.
- The game never pauses to explain something while the objective is taking
  damage unless the pause is intentional and explicit.

### 6.2 Title screen

Ship:

- Skygear title treatment;
- one-sentence game promise;
- **Start Run** as the dominant action;
- **How to Play**;
- **Settings**;
- **Credits**;
- personal best and last-run summary;
- build ID and visible asset/audio completion only in a developer-details area,
  not competing with the title;
- optional first-run “Recommended: keyboard + mouse” note.

The title should show the storm-dusk world and captain without becoming a
separate cinematic production.

### 6.3 Pause and settings

Pause must contain visible controls rather than relying on undocumented keys:

- Resume;
- Master, Music, SFX, UI and Voice volume sliders;
- Mute;
- fullscreen toggle;
- control remapping;
- screen-shake amount;
- hit-stop amount or reduced-motion mode;
- high-contrast telegraphs;
- text/HUD scale;
- tutorial-tip toggle;
- Restart Run with confirmation;
- Quit to Title with confirmation.

Changing a setting should apply immediately and persist in `localStorage`.

### 6.4 HUD

The HUD must answer six questions at a glance:

1. Am I healthy?
2. Is the Boiler healthy?
3. Which lane is failing?
4. What can I use now?
5. Which skills are automatic?
6. What is this wave asking me to do?

Art requirements:

- Captain portrait;
- bottom skill-frame treatment;
- gauge ring;
- six active-shape icons;
- three passive-shape icons;
- dash indicator if the painted icon is retained;
- hulk/push objective treatment;
- clear lane-state symbols;
- consistent brass, gunmetal and dark-base language.

Manifest cleanup:

- wire or remove Dash, Barrier and Currency Cog;
- add Field, Pulse and Sentry icons;
- ensure the title's completion count includes only consumed assets;
- do not create a currency readout unless a real currency system exists.

### 6.5 Draft screen

Ship one coherent card family:

- common, rare and epic treatments that remain readable without colour;
- shape/element emblem;
- `ACTIVE` or `AUTO` behaviour;
- effect text;
- before/after value;
- affected slot or element family;
- keyboard selection label;
- selected/rejected animation;
- hover/focus state;
- confirm sound.

### 6.6 Victory and defeat

Results must include:

- outcome and cause;
- waves survived;
- duration;
- enemies destroyed;
- damage dealt;
- damage taken;
- Boiler damage taken;
- best combo;
- final four-slot build;
- fixed Ember Cleave;
- drafted cards;
- seed;
- personal-best comparison;
- **Copy Run Report**;
- **Play Again** as the primary action;
- return to title.

The copied report should be compact enough to paste into Discord while retaining
version, seed, outcome, wave, build and key statistics.

### 6.7 Menu skin asset kit

The renderer should use a small reusable kit instead of a unique raster for
every screen:

| Asset | Purpose |
|---|---|
| `menu_panel_9slice` | Scalable dark brass panel for title, pause and results |
| `menu_button_primary` | Start, Play Again, confirm |
| `menu_button_secondary` | Settings, credits, back |
| `menu_card_frame` | Draft card foundation, tinted by rarity in code |
| `menu_divider` | Section separator |
| `menu_title_ornament` | Title and major-screen visual anchor |
| `menu_focus_ring` | Keyboard/controller-style focus indication |

Text must remain code-rendered for localisation, accessibility and sharpness.

---

## 7. Visual production plan

### 7.1 Complete the current 67-slot still manifest

The 35 missing runtime files are:

| Category | Missing | V10 purpose |
|---|---:|---|
| Props | 7 | Finish level dressing and remove procedural geometry mismatch |
| Environment | 3 | Complete depth/parallax and airship context |
| Ground | 7 | Telegraphs, shadows and battle aftermath |
| FX | 6 | Hits, attacks, smoke and elemental readability |
| UI | 12 | HUD identity and icon consistency |

No production still should remain absent at RC.

### 7.2 Additional V10 UI assets

The current manifest predates V9's passive shapes. Add only assets with real
consumers:

- `icon_skill_field`;
- `icon_skill_pulse`;
- `icon_skill_sentry`;
- the seven-piece reusable menu kit listed above;
- optional lane-status icons if code glyphs do not meet the readability test.

### 7.3 Level cohesion

The level should match character art through:

- completed near/far cloud layers;
- distant escort airship;
- consistent cool upper-left and warm lower-right lighting;
- painted props at the upright billboard angle;
- ground decals for battle history;
- authored pools of lantern light;
- controlled atmospheric depth;
- palette discipline that reserves gameplay colours for gameplay;
- no photo texture, inconsistent perspective or over-bright deck surface.

The deck remains code-drawn because the projected quads and collision geometry
must agree. Art should decorate and frame it rather than replace it with a
perspective texture Canvas 2D cannot warp correctly.

### 7.4 Animation

The approved full-cast plan is 19 cycles, approximately 160 frames:

| Unit | Required cycles |
|---|---|
| Captain | idle, run, attack |
| Scrapper | idle, run, attack |
| Gremlin | run, attack |
| Drone | idle, attack |
| Furnace Knight | idle, run, attack |
| Crew | idle, run, attack |
| Colossus | idle, attack |

Required pipeline:

- horizontal strip per cycle;
- 384 px frames, 512 px for Colossus;
- consistent crop and feet row;
- engine-side timing;
- attack cycles play once;
- stills remain fallback;
- strips validated by `src/check-animations.py`;
- existing loose hero and Scrapper frames packed or deliberately retained until
  equivalent strips are confirmed.

P0 animation priority:

1. Captain attack and idle;
2. Scrapper attack and idle;
3. full Crew set;
4. Furnace Knight;
5. Gremlin;
6. Drone;
7. Colossus.

If the complete 19-cycle set threatens the release, cut low-frequency cycles,
not quality within the captain's most-seen actions.

### 7.5 VFX

V10 must combine painted sprites and code-side motion:

- Ember Cleave slash;
- impact burst;
- Tesla bolt;
- steam and smoke puffs;
- ember particles;
- enemy and player ground runes;
- boss telegraphs;
- lane-critical pulse;
- hulk vulnerability highlight;
- controlled camera shake;
- brief hit flash that does not turn a large sprite into a solid white blob.

VFX acceptance:

- important threats remain visible under four-skill endgame load;
- particles never obscure the captain;
- enemy red/orange and friendly teal remain distinct;
- colour is not the only distinction;
- reduced-motion mode cuts shake, large flashes and excessive particles;
- no semi-transparent halo from chroma removal.

### 7.6 Art QA

Every delivered asset must pass:

- exact manifest filename;
- exact runtime dimensions;
- transparent corners where required;
- no residual chroma fringe;
- no accidental contact shadow;
- full silhouette and padding;
- approved upright billboard presentation;
- lighting consistency;
- palette sampling;
- readability against `#14121B`;
- style comparison against the captain;
- in-engine screenshot at actual rendered size.

Batch gates:

- validator after every batch;
- in-engine review every five assets;
- style-board comparison every ten;
- memory and network measurement after each animation group.

---

## 8. Audio and music release

V9 has a strong audio architecture and only a small part of its content.
V10 should make the procedural fallback a safety net, not the default sound.

### 8.1 Manifest completion

There are 54 audio keys:

- shape bodies;
- element tails;
- impacts and player actions;
- enemy attacks and deaths;
- lane and objective events;
- world ambience;
- UI;
- eight music states.

Only six keys are delivered today. V10 should aim for **54/54 resolved** in the
generated index. A cue may remain procedural only through an explicit review
decision, not because production forgot it.

### 8.2 Priority order

1. High-frequency player loop:
   Cleave, hit variants, crit, hurt, dash, ready.
2. Shape bodies and four element tails.
3. Enemy attacks, deaths and telegraphs.
4. Cannon, crew, hulk and Boiler states.
5. UI hover/click, card deal/pick and slot unlock.
6. Storm and ship ambience.
7. Remaining music states.
8. Captain voice barks.

### 8.3 Music set

The intended eight states are:

- title;
- combat low;
- combat mid;
- combat high;
- push;
- boss;
- victory;
- defeat.

V9's crossfade loop and fallback chain remain. Each new track needs measured
loop points, not assumed full-file looping.

### 8.4 Mix and fatigue requirements

- No clipping in delivered masters.
- One-shots finish naturally inside their duration budget.
- High-frequency events have variants, detune or strict voice caps.
- Player action remains louder and clearer than allied background fire.
- Off-screen lane danger remains audible but does not dominate the mix.
- Boiler critical loop is unmistakable and stops cleanly.
- Music ducks under critical objective and results cues.
- Bus sliders work during play and pause.
- Audio resumes gracefully after tab suspension.
- Mute state persists.

### 8.5 Voice

Voice is optional P1, but if included it should be sparse:

- run start;
- first push;
- Boiler critical;
- boss arrival;
- victory;
- defeat;
- occasional skill-ready or kill reaction only if it survives fatigue testing.

Do not narrate information the HUD already communicates continuously.

---

## 9. Accessibility and controls

V10 should make desktop play broadly usable without pretending to support
platforms it does not.

### 9.1 Required

- remappable keyboard and mouse actions;
- visible alternative numeric keys for four slots;
- pause on focus loss;
- independent volume buses;
- fullscreen;
- HUD/text scale;
- high-contrast telegraphs;
- reduced screen shake;
- reduced motion/particles;
- flash intensity option;
- persistent settings;
- keyboard navigation through title, pause, draft and results;
- visible focus state;
- confirmation for destructive menu choices;
- colour-plus-shape language for elements, rarity and lane danger.

### 9.2 Evaluate, do not promise

- gamepad support;
- left-handed default preset;
- aim assist;
- alternative hold/toggle behaviour for Beam;
- difficulty assists.

If gamepad is added, it must cover the entire menu and combat loop. Partial
gamepad support is worse than an honest keyboard/mouse requirement.

### 9.3 Not supported in V10

- touch controls;
- mobile layout;
- screen readers for the canvas game;
- localisation beyond keeping text code-rendered and extractable.

---

## 10. Evidence, testing and telemetry

### 10.1 Deterministic runs

P0:

- replace gameplay-critical raw randomness with a seeded PRNG;
- accept `?seed=`;
- show the seed on results;
- include seed in copied reports;
- keep audio randomness outside gameplay determinism;
- replay at least ten fixed seeds after every balance change.

### 10.2 Committed gameplay harness

The repository needs a runnable harness that proves:

- V10 boots;
- no console errors occur;
- player can move and cast;
- active and passive shapes execute;
- every wave starts and terminates;
- pushes create fresh hulks;
- victory is reachable;
- player-death loss fires;
- Boiler-death loss fires;
- results screen appears;
- restart returns to a clean state;
- generated build matches sources;
- frozen builds remain unchanged.

Cheats may be used for reachability tests only when the test name says so.
Balance evidence must come from an honest configuration.

### 10.3 Run log

Store locally:

```text
version, build, seed, outcome, wave, cause, duration,
kills, damageDealt, damageTaken, boilerDamage,
bestCombo, dashes, basic, slots[], cards[],
passiveCount, elementCounts, shapeCounts
```

No account, server or personal identifier is required.

### 10.4 Human playtest cohorts

Before RC:

- at least five first-time players;
- at least three action/roguelite players;
- at least two players who did not receive verbal instruction;
- at least one lower-spec desktop;
- at least one test using reduced-motion/high-contrast settings.

Observe actions, not only opinions.

### 10.5 Success scorecard

| Area | Release signal |
|---|---|
| Objective comprehension | At least 80% identify the Boiler and lane objective before wave 2 ends |
| Controls | At least 80% use movement, dash and one active skill without coaching |
| Build breadth | At least 90% of completed runs finish with three or four equipped skills |
| Passive clarity | At least 80% can identify an `AUTO` skill after receiving one |
| Lane comprehension | Most testers deliberately use a cross-passage at least once |
| Fairness | Critical objective damage is preceded by visible/audible warning |
| Difficulty | First-timers typically reach wave 6–9; skilled testers do not win every run |
| Build variety | No single slotted shape dominates an overwhelming majority of successful reports |
| Stability | Zero critical/high bugs and zero uncaught console errors in the final matrix |
| Replay intent | At least 30% immediate replay or stated immediate replay intent |

These are directional thresholds for a small test, not statistical proof.

---

## 11. Performance, memory and delivery budgets

V10 adds the heaviest content categories: animation, UI and audio. Budgets must
be enforced while production is incremental.

### 11.1 Runtime targets

| Metric | Target |
|---|---|
| Frame rate | Stable 60 fps at 1366×768 on ordinary integrated graphics |
| Frame-time p95 | Under 16.7 ms during a representative late wave |
| Frame-time p99 | Under 25 ms, excluding explicit hit-stop |
| Sim | 120 Hz without accumulating backlog |
| Crowd test | Representative 200-entity stress scene remains controllable |
| Input | Buffered action fires on the first eligible simulation step |
| Console | Zero uncaught errors or repeating asset/audio errors |

### 11.2 Content budgets

Recommended initial budgets:

- compressed runtime still art: **≤ 20 MiB**;
- compressed animation strips: **≤ 14 MiB**;
- total shipped audio/music: **≤ 30 MiB** unless quality requires a documented
  exception;
- decoded art/animation working set: **≤ 220 MiB**;
- total browser memory: soft target **≤ 350 MiB**, hard investigation threshold
  **500 MiB**;
- no individual non-music request unnecessarily larger than its runtime use.

The exact browser memory number needs measurement because decoded RGBA and GPU
copies are implementation-dependent.

### 11.3 Loading strategy

- Title and menu become interactive before all gameplay art loads.
- High-frequency hero, enemy, HUD and wave-one assets load first.
- Later enemy and boss animation strips load by expected wave.
- Music remains lazy.
- Failed optional asset loads fall back cleanly.
- Production packages exclude chroma masters and high-resolution generation
  sources.
- Cache-busting build ID continues to identify deployed content.

### 11.4 Supported display matrix

Test:

- 1280×720;
- 1366×768;
- 1440×900;
- 1920×1080;
- 2560×1440;
- browser zoom 90%, 100% and 125%;
- fullscreen and windowed;
- device pixel ratios 1 and 2 where available.

No critical HUD element may leave the safe area or overlap a draft choice.

---

## 12. Engineering and repository hygiene

### 12.1 One live source

- V9 is frozen.
- V10 alone is writable by the live build command.
- Generated HTML is never edited manually.
- Gameplay sources, manifest sources and generated output must agree.
- Classic and earlier versions remain historical comparisons, not parallel
  production targets.

### 12.2 Required automated checks

One release command or CI workflow should run:

1. JavaScript syntax validation;
2. Python syntax validation;
3. deterministic build;
4. frozen-build hash verification;
5. still-asset dimension and alpha validation;
6. animation strip size/frame/drift validation;
7. audio index and file-format validation;
8. no missing P0 manifest assets;
9. headless gameplay smoke;
10. both loss conditions;
11. victory path;
12. generated-source consistency;
13. itch package content check;
14. file-size budget report.

### 12.3 Manifest truth

V10 should distinguish:

- required and visible;
- optional with fallback;
- developer comparison only;
- archived.

The title completion badge should count only required visible production assets.
Archived 49-degree comparison art and unused UI slots must not affect the public
completion number.

### 12.4 Documentation set

At V10 RC:

- README reflects V10;
- controls match the game;
- matrix/card counts are generated or checked;
- V10 changelog exists;
- asset and audio credits exist;
- known limitations are honest;
- accessibility settings are documented;
- packaging instructions are reproducible;
- old roadmap items are closed, migrated or explicitly rejected.

---

## 13. Milestones and gates

### Gate 0 — V9 learning

Deliver:

- at least one full human run;
- structured notes against §1.3;
- decision on passive value and clarity;
- decision on default difficulty;
- decision on whether Rigging Wraith is needed;
- top five observed presentation problems.

Exit:

- V10 design decisions written before balance or content expansion begins.

### Milestone 1 — V10 foundation

Deliver:

- V9 frozen;
- V10 preset/build created;
- seeded PRNG;
- run log and copy report;
- committed gameplay harness;
- current docs corrected to V9/V10 facts;
- manifest cleanup plan.

Exit:

- every later change can be tested and attributed.

### Milestone 2 — Comprehension slice

Deliver:

- first-run prompts;
- final title/pause/settings flows;
- HUD information architecture;
- passive icons and `AUTO` treatment;
- draft before/after values;
- lane critical alerts;
- results/report flow.

Exit:

- a first-time tester can play to wave 4 without verbal coaching.

### Milestone 3 — Visual completion

Deliver:

- remaining 35 current still assets;
- passive icons;
- menu kit;
- environment/parallax completion;
- ground telegraphs and decals;
- VFX pass;
- no visible stand-ins.

Exit:

- every live manifest entry resolves and is visible in the correct context.

### Milestone 4 — Motion and sound

Deliver:

- captain and Scrapper priority cycles;
- crew motion;
- remaining approved cycles in priority order;
- high-frequency SFX;
- shape/element audio layering;
- objective, UI and enemy cues;
- complete music-state plan.

Exit:

- one full run contains no conspicuous transition from polished to placeholder
  feedback.

### Milestone 5 — Campaign and finale

Deliver:

- human-tuned wave pacing;
- push-wave timing;
- passive/active balance;
- boss beats;
- wreck/victory sequence;
- optional Wraith decision complete.

Exit:

- default campaign is winnable, losable and fair across fixed seeds and human
  tests.

### Milestone 6 — Accessibility and performance

Deliver:

- settings persistence;
- reduced motion;
- high contrast;
- remapping;
- display matrix;
- late-wave performance capture;
- memory/network budget review;
- load-order optimisation.

Exit:

- budgets and accessibility acceptance criteria pass.

### Milestone 7 — Release candidate

Deliver:

- content lock;
- complete regression pass;
- zero critical/high bugs;
- final copy and credits;
- GitHub Pages deploy;
- itch.io package;
- screenshots/short gameplay capture;
- public playtest form;
- rollback commit identified.

Exit:

- two clean installs/runs from the public packages, not local development files.

### Milestone 8 — Public V10

Deliver:

- landing page points primarily to V10;
- previous builds move into an archive/comparison section;
- feedback channel is visible;
- first 48-hour issues are triaged by severity;
- hotfixes change only critical defects, not design scope.

---

## 14. Ownership and parallel work

| Lane | Primary owner | Deliverables |
|---|---|---|
| Vision and final scope | Alex | V9 findings, P0/P1 approval, public release decision |
| Simulation and gameplay | Claude | tuning, wave logic, boss, onboarding hooks, settings, deterministic harness |
| Renderer integration | Claude | UI/menu consumers, animation strips, loading/lazy loading, accessibility rendering |
| Still art and UI art | Codex | remaining manifest, passive icons, menu kit, asset QA |
| Animation production | Codex | cycle generation, strip packing, alpha/drift QA |
| Audio production | Codex | cue generation, source QC, ingest-ready delivery |
| Audio integration and mix | Claude + Codex | manifest behaviour, loop points, in-engine level/fatigue review |
| Release QA | Shared | matrix tests, browser/display tests, human test notes |
| Public presentation | Alex + Shared | landing copy, screenshots, itch package, feedback collection |

### 14.1 Collision rules

- Engine work does not silently overwrite generated art.
- Art work does not edit frozen builds.
- Every asset batch names exact files and dimensions.
- Every integration commit stages explicit paths.
- Dirty work from another agent is preserved.
- A handoff file records current counts, last validation and next priority.
- Major scope or source-of-truth changes are written before parallel work starts.

---

## 15. Risk register

| Risk | Trigger | Mitigation | Cut line |
|---|---|---|---|
| V10 becomes a feature dump | P1 begins before P0 gates | Weekly scope review against product promise | Cut Wraith, voice and extra environmental events first |
| Passives dominate | Human reports prefer passive-only slots | Tune against representative crowds and run reports | Reduce passive value or cap passive slots; do not add counters |
| Four skills still overload | Players ignore two active slots | Improve drafts, AUTO clarity and input mapping | Encourage 1–2 passives; do not add fifth slot |
| Boss is unreadable | Testers take unexplained damage | Reduce simultaneous patterns and adds | Keep two strong boss beats instead of three weak ones |
| Art style drifts | New UI/FX no longer matches captain | Locked references and batch comparisons | Regenerate drifters, not the approved anchor |
| Animation explodes memory | Working set approaches hard budget | Strip packing, wave-based lazy loading, lower frame ceilings | Cut low-frequency cycles before reducing hero quality |
| Audio becomes exhausting | Repeated cues dominate after ten minutes | Variants, caps, detune, mix hierarchy | Keep approved procedural fallback for low-frequency cue |
| Lane alerts become noise | Multiple lanes pulse continuously | Prioritised alerts and cooldowns | Show only highest-severity off-screen alert |
| Difficulty is tuned to one tester | Win/loss outcomes vary wildly | Fixed seeds and mixed-skill cohort | Ship one default plus assist only if evidence supports it |
| Docs drift again | Counts disagree across README/title/handoff | Generate or validate facts from manifests/code | Fail release check on mismatched canonical counts |
| Deployment cache hides release | Public build ID does not change | Existing content-derived stamp and cache-busted link | Roll back landing link until correct build is verifiable |
| Partial gamepad support misleads | Menus or draft cannot be operated | End-to-end support gate | Do not advertise or ship gamepad support |

---

## 16. V10 definition of done

V10 is done only when all statements below are true:

### Game

- A stranger can start without verbal instruction.
- The objective and lane structure are understood.
- Automatic and active/passive skills are distinguishable.
- All shipped shape-element behaviour passes the matrix harness.
- All 12 waves start, progress and end.
- Push waves spawn fresh, functional hulks.
- The boss has a readable, satisfying finale.
- Victory and both loss conditions work.
- Retry produces a clean new run.

### Presentation

- No visible procedural stand-in remains unintentionally.
- All required still assets resolve at exact dimensions.
- High-frequency character actions have coherent motion.
- VFX communicate gameplay without hiding it.
- HUD and menus share one visual language.
- Title, pause, settings, draft and results are complete.
- Music and SFX cover the run coherently.

### Accessibility

- remapping works;
- bus volumes work;
- settings persist;
- reduced motion and high contrast work;
- keyboard navigation and visible focus work;
- supported resolution matrix passes.

### Evidence

- seed and run report exist;
- automated smoke passes;
- honest victory/loss tests pass;
- asset, animation and audio validators pass;
- external playtests meet the minimum cohort;
- scorecard has no unexplained red area.

### Delivery

- V10 build ID is visible and correct;
- GitHub Pages link loads the intended build;
- itch package contains every required runtime asset;
- production package excludes high-resolution/chroma sources;
- README, controls, counts and credits are current;
- no critical/high bugs remain;
- rollback point is known.

---

## 17. Recommended first ten actions

1. Run V9 and record answers to the 15 questions in §1.3.
2. Freeze V9 immediately after the test.
3. Create V10 as the only live build target.
4. Add deterministic seeds, run log and copyable report.
5. Correct the canonical matrix/card/asset documentation.
6. Finalise HUD/menu information architecture before generating the full UI set.
7. Finish the 35 missing still assets in gameplay-impact order.
8. Pack the two existing loose run cycles and produce captain attack/idle.
9. Deliver the high-frequency player and objective audio batch.
10. Test the first public-quality slice through wave 4 before completing the
    remainder.

The reason for this order is simple: V10 should become **learnable and
measurable before it becomes expensive**.

---

## 18. Final recommendation

V10 should not try to prove that Skygear can contain endless ideas. V9 already
proves that the code can support more shapes, more presentation systems and
more tactical structure.

V10 should prove something harder:

> **Skygear can turn those systems into one finished, understandable,
> exciting run that people want to share and play again.**

That requires ambition, but it is the ambition of completion:

- one clear product promise;
- one canonical build;
- one coherent art language;
- one full feedback language;
- one campaign with a real finale;
- one evidence trail we can trust.

If V10 ships that, it earns every larger feature that follows.
