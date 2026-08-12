# SkyGear Godot — gameplay review and expansion design

Date: 2026-08-04  
Scope: the Godot game only  
Status: authoritative expansion brief and implementation handoff; no
implementation is included

Reader map: Sections 1–12 explain the design and its priorities; Sections
13–15 define the non-negotiable agent/engineering contract; Sections 16–20 are
the copyable implementation packets; Section 21 gives merge trains, commands
and Definition of Done. An implementer starts with its ID in Section 14, confirms
its **Requires** entries and separately notes **Serialize after**, reads the
shared contract, then reads only that complete packet
and the live code it names. When a number or implementation rule in Sections
1–12 differs from its packet, Sections 16–20 are authoritative; the earlier
sections explain intent, while the packet is the executable specification.

## 1. Executive assessment

SkyGear is already a coherent, feature-complete run game rather than a porting
prototype. The twelve-wave campaign, two heroes, four-slot draft, 36
shape-and-element combinations, reactive deck, lane cannons, crew, boarding
hulks, event waves, Workshop, Articles, Heat ladder, fittings and a bespoke
Colossus encounter all work together. The headless harness completes
successfully, and the repository has unusually strong deterministic and
geometry checks.

The main weakness is not lack of systems. It is that many of those systems
produce more *power* without producing enough new *decisions*:

- ordinary runs still replay the same authored enemy compositions;
- five live fittings fit into six berths, so ship customization currently has
  almost no opportunity cost;
- several ability shapes are mechanically adjacent despite different names;
- most elements add a status, but rarely change how a shape is aimed or used;
- the twelve waves are paced as a sequence, but only waves 4, 8 and 12 strongly
  change the player's job;
- the Captain and Boilerwright are excellent opposites, but there is room for a
  third hero whose question is control rather than proximity or preparation.

The recommended expansion is therefore a **depth pass**, not a breadth pass.
The order below is authoritative and supersedes the earlier draft of this
document, which incorrectly scheduled the riskier ability rewrite before the
already-designed enemy-variation seam:

1. make authored waves produce several fair encounter stories;
2. give the weakest ability shapes clearer identities without breaking the
   passive-slot contract;
3. make the element matrix change behavior, not merely colour and status;
4. turn fittings into a constrained ship loadout with visible trade-offs;
5. make the campaign read as three watches plus a boss, with a distinct combat
   lesson in each watch;
6. prototype the Rigger as the third hero only after those shared systems are
   stable.

## 2. Review basis

This review was made against the live Godot implementation, especially:

- `scripts/game_data.gd`: shapes, elements, enemies, waves, events and classes;
- `scripts/game.gd`: run flow, drafts, casts, pressure/Head, events, tempo,
  deckwork, allies, hulks, fittings and damage;
- `scripts/enemy.gd`: targeting, telegraphs, statuses and the Colossus;
- `scripts/cards.gd`: the 41-card draft catalogue and previews;
- `scripts/workshop.gd`: talents, Articles and Heat;
- `scripts/fittings.gd`: earned ship changes and berths;
- `scripts/deckwork.gd` and `scripts/lanes.gd`: deck verbs, cannons, crew and
  lane constraints;
- the current design, status, outstanding-work and focused design documents;
- `tests/parity_test.gd`, run headlessly on 2026-08-04 with a successful exit.

The older browser build is not treated as an authority. The design target is
the Godot game as it exists now.

## 3. What should be protected

### 3.1 The ship is one continuous battlefield

The 1680 × 2320 deck, three fixed lane bands, cargo runs and three crossings
form a learned tactical space. Replacing it with procedurally sized decks,
changing the lane count or adding navigation would destabilize the camera,
abilities, enemy clamps, Boiler pressure and readability for limited benefit.

Keep one ship. Create variety through who arrives, when they arrive, what role
they carry and which between-run fittings the player has installed.

### 3.2 The heroes ask different spatial questions

- The Captain asks: **How long can I stay close?**
- The Boilerwright asks: **Where will I make my stand?**

This is the strongest high-level design in the game. New heroes must add a new
question, not become a ranged Captain or a faster Boilerwright.

### 3.3 The shared shape × element matrix

Every hero drafting from the same matrix gives the game a strong language and
keeps content reusable. Reworks should deepen the nine shapes and four elements,
not replace them with hero-exclusive spell lists.

### 3.4 Readable danger and deterministic runs

Telegraphs must continue to own their hit geometry. New variation must use
isolated seeded streams and leave the main combat RNG untouched. A named enemy
or encounter rule must be visible before it matters.

### 3.5 The ship changes between runs, not between waves

The owner's direction and the current fittings layer agree: enemy variation
owns the run; ship modification owns the metagame. Do not resurrect per-wave
deck reshuffling.

## 4. Current design findings

### 4.1 Gameplay loop

The core loop is strong: draft, defend, triage lanes, exploit deck hazards,
repair, recover and draft again. Dash/Pressure and Head/Overpressure both create
real risk. The reactive props, crew, cannons and hulks ensure damage is not the
only thing happening on the deck.

The weak point is the ordinary wave. `WAVES` always authors the same type and
count sequence. Seeded tempo already changes spacing through STEADY, SURGE and
CRESCENDO, but spacing alone cannot turn the same roster into a new tactical
problem. The unbuilt Muster and elite-mark designs address the correct seam.

### 4.2 Ship customization

The fittings architecture has the right rules: fittings are earned rather than
bought, snapshot at run start, and may change deck geometry or deck verbs but
not hero stats. The problem is the loadout constraint. There are six defined
fittings, one is tabled, and the berth cap is six. A player with all live
fittings can sail with all of them.

That makes the berth screen a collection screen rather than customization.
Customization begins when installing one desirable thing prevents installing
another desirable thing.

### 4.3 Abilities

The matrix is broad, but its tactical identities are uneven:

| Shape | Current strength | Current overlap or weakness |
|---|---|---|
| Cleave | fast, close, follows the hero | overlaps Gale as another frontal fan |
| Lance | precise long line | overlaps Beam as immediate line damage |
| Gale | wide knockback and crowd control | often feels like slower Cleave |
| Mortar | unique aimed landing and thrown shell | already clear and worth protecting |
| Whip | unique target acquisition and jumps | already clear, but chain order is mostly automatic |
| Beam | visually distinct | resolves as instant line damage ×4, not a beam decision |
| Field | useful passive close zone | fully automatic and follows the hero, so it asks nothing |
| Pulse | readable periodic burst | fully automatic and timing is difficult to influence |
| Sentry | genuine placement choice with optional autocast | strongest example of an active tactical shape |

The elements are centralized and reliable, but mostly add burn, slow, stun
chance or knockback after the shape has already made its decision. A Frost
Mortar and Ember Mortar are different in outcome, but are aimed in almost the
same way.

There is also a live implementation gap the expansion must not build over:
`burn_damage`, `burn_duration`, `slow_amount` and `stun_chance` exist in the
card modifier table, while `enemy.gd` currently applies hard-coded status
values. Those upgrade promises therefore lack gameplay readers. EL-00 treats
this as prerequisite repair with deletion-sensitive checks before adding any
reaction damage.

### 4.4 Level and encounter design

The campaign has a good skeleton:

- waves 1–3 teach enemy roles and lane travel;
- wave 4 introduces the grapple and hulk;
- waves 5–7 introduce the Furnace Knight and mixed pressure;
- wave 8 is a blackout;
- waves 9–11 become dense, multi-lane checks;
- wave 12 is the Colossus.

The skeleton is not communicated as acts, and waves 5–7 and 9–11 do not each
have a clear authored purpose. The player experiences rising quantity more
readily than a changing job.

### 4.5 Heroes

The Captain is immediate, forgiving and mobile. The Boilerwright is distinct,
but his real mobility gap is much larger than the class comparison's top-speed
numbers imply because the Captain's recharging dashes dominate distance
covered. This should remain a deliberate price, but the class screen and
first-run coaching should state it as such.

The next hero should not arrive until the shared encounter and ability systems
are deeper. Otherwise the new hero will be content competing with systems that
still need differentiation.

## 5. Recommended gameplay improvement package

### 5.1 Enemy Muster: vary the question, conserve the threat

Build the existing Muster proposal at the spawn-queue seam. For waves 3, 5–7
and 9–11, mutate filler batches through legal, threat-budgeted substitutions:

- a Scrapper group may become a larger Swarm group;
- one lane may become a two-lane pincer;
- a Gunner may be paired with a melee screen;
- an Armored unit may replace several light bodies, never merely be added;
- signature batches on waves 4, 8 and 12 remain fixed.

Requirements:

- same seed produces the same twelve queues;
- main and visual RNG state do not move;
- threat budget remains within ±10% of the authored wave;
- waves 1–2 remain fixed teaching content;
- every mutation changes composition or lane pressure, not only count;
- the existing tempo profile composes with Muster but event waves remain
  STEADY.

This is the highest-value gameplay change because it makes the draft answer a
different problem on each run without adding a new enemy mesh or battlefield.

### 5.2 Elite marks: give waves a target priority

Give an eligible ordinary wave one 35% elite-deal roll from wave 5 onward, still
capped at one mark. Begin with two marks, not three:

- **Quartermaster:** nearby boarders move faster while it lives. The player must
  reach or isolate it.
- **Sparking:** periodically paints a clear Arc pulse on the deck. The player
  must leave safe damage positions.

Defer Veteran. Double health plus flinch immunity risks becoming time tax rather
than behavior.

An elite promotion must replace part of the wave budget, be visible on the
model and HUD, pay extra salvage, and move a behavioral statistic such as kill
order or player travel. If it only increases wave duration, cut it.

### 5.3 Arrival presentation: protect and integrate what is built

This feature is already implemented. `view3d.gd` rotates the four ambient hulls
through the bow hold, moves the selected hull on the simulation's wave clock,
draws ordinary boarders crossing during `SkyGearEnemy.ARRIVAL_TIME`, closes a
landing ring on the simulation position, keeps the boarder untouchable through
`can_be_hit()`, and excludes the Colossus. Do not build a second arrival
scheduler or another arc system.

Expansion work here is integration only:

1. prove a mutated Muster queue does not change the renderer-only contract;
2. keep the landing mark authoritative because the hull is not visible from
   every camera position;
3. let Signal Crane reveal information in the live queue produced from the
   cached plan;
4. retain the current boss exclusion and the boarding hulk's separate role.

Transports remain indestructible presentation. The renderer must never predict
or consume the spawn queue, and no Muster grammar may change the 0.8-second
arrival immunity window.

### 5.4 Recovery windows should produce deck decisions

SURGE already creates lulls. Make those lulls useful without creating a new
resource:

- repair remains a held, interruptible action;
- salvage collection, cannon repair and Boilerwright charging are the three
  recovery verbs;
- the HUD may briefly label a genuine gap **BREATHING ROOM** only when the
  player's current lane and active player-targeting threats are clear and the
  live queue proves no arrival can land within the action's minimum useful
  window; enemies fighting in another lane do not erase a local recovery choice;
- do not restore the tabled crate-pushing family until a new interaction pass
  makes positioning the crate faster and more consequential than walking.

This turns tempo into a play change rather than an invisible spawn statistic.

## 6. Ship customization redesign

### 6.1 Replace six generic berths with three hardpoints

Use three mutually exclusive hardpoints:

| Hardpoint | What it changes | Initial candidates |
|---|---|---|
| Bow | first contact and landing space | Bow Barricade, Signal Crane (new) |
| Waist | lane support and crossings | Fourth Vent, Powder Locker (new), Firebreak Grating (new) |
| Stern | defense of the Boiler line | Spare Gun, Scupper Grating, Emergency Main (new) |

The Wreck moves to a separate **trophy rail**. It remains visible and may remain
cover only if the cover does not make it a mandatory power pick; otherwise its
collision becomes cosmetic. The tabled Winch stays recorded but unavailable.

The legacy set creates only one immediate swap, at Stern; Bow and Waist each
have a single live candidate. The constraint therefore cannot ship by itself.
Powder Locker and Signal Crane are part of the same player-facing release unit,
after which every hardpoint has a visible rival and the player can no longer
install every functional fitting.

### 6.2 Every fitting needs a benefit and a spatial cost

Recommended fitting rules:

- no direct changes to hero stats, starting resources or Workshop fields;
- no invisible percentage bonuses;
- one fitting occupies one named physical hardpoint;
- installing it must visibly change movement, cover, hazard placement, a
  cannon position or an available deck verb;
- any fitting that is always correct in its hardpoint needs a cost or a rival;
- a bare ship remains fully viable.

### 6.3 Four fitting additions

1. **Powder Locker — Waist.** Adds a fixed rack with two kegs close
   enough to chain. It offers burst damage but creates a dangerous fire zone in
   the most useful crossing if detonated carelessly.
2. **Emergency Main — Stern.** Adds one deck valve near the Boiler. Holding the
   interact verb vents a short Steam wall up the middle lane once per wave, but
   the valve blocks the direct path between the two stern crossings while it is
   active. It is deck geometry plus a verb, not a stat bonus.
3. **Signal Crane — Bow.** Adds a visible landing crane and reveals the next
   transport's lane whenever a queued drop exists. It occupies space where the
   Bow Barricade would provide cover, trading information for defense rather
   than depending on a rare global lull.
4. **Firebreak Grating — Waist.** Replaces one crossing floor with a grate that
   extinguishes persistent fire fields on it but offers no cover. It competes
   directly with the Fourth Vent and Powder Locker for the same valuable space.

These are starting concepts. Each must be playtested against an empty
hardpoint and its two rivals; collection alone is not success.

### 6.4 Presets and ownership

Keep fittings earned through feats. Add three named loadout presets only after
there are at least two real choices in every hardpoint. A preset stores fitting
IDs, hero and Heat; it must not store drafted skills. Articles are permanent
ownership and `articles_for()` already derives every compatible live Article
from the selected hero, so a preset must not invent Article equip state. Loading
a preset with an unavailable or tabled fitting leaves that hardpoint empty and
explains why.

## 7. Ability and element rework

### 7.1 Give each shape one exclusive verb

| Shape | Exclusive verb | Proposed rework |
|---|---|---|
| Cleave | combo | alternate two quick arcs; the second rewards staying close |
| Lance | pierce | deals its best result through a lined-up group and carries excess knockback down the line |
| Gale | herd | leaves a short-lived directional current that continues pushing, clearly separating it from Cleave |
| Mortar | predict | keep the thrown shell; add a brief landing clock so placement, not reflex, is its skill test |
| Whip | route | first target remains aim-selected; jumps prefer afflicted targets, letting element setup influence chain order |
| Beam | commit | becomes a true short channel that tracks aim, trades movement for sustained line damage and can be abandoned only by spending a dash or jet |
| Field | claim | remains passive, but anchors at the last active skill's landing point instead of following the hero; the next active cast relocates it |
| Pulse | cadence | remains passive and periodic, but each successful active cast advances its visible timer by a small fixed amount |
| Sentry | fortify | retain manual placement/autocast; make its evolution choices change targeting, not raw damage |

Field and Pulse **remain passive shapes**. This is a load-bearing contract, not
an incidental label: `_slot_skill()` places passives from the far end, The
Second Hand deals only passive shapes into its keyless fifth slot, the draft
bot ranks them separately, the card face names their role, and the renderer
gives Field its own persistent volume. Turning either active would require a
fifth input or would silently break an Article. Their reworks add player agency
through the active skills around them rather than through another key.

Beam has no universal cancel command. The two shipped kits—and the proposed
Rigger—can spend a dash or jet to abandon it; a future hero with neither
movement verb must finish the channel unless that hero's own packet explicitly
authors a cancel.

### 7.2 Make elements modify the verb

Keep one centralized rule per element, then let shapes consume that rule:

- **Ember — Kindle:** repeated applications build heat; a heavy hit consumes
  the stack for a burst. Mortar and the second Cleave hit are natural consumers.
- **Frost — Fix:** slow builds toward Root; a Steam hit consumes Root for bonus
  damage and immediately frees the target. Frost prepares, Steam cashes out.
- **Arc — Conduct:** afflicted targets become preferred Whip jumps and share a
  fraction of Beam damage with one nearby afflicted target. Arc changes route.
- **Steam — Displace:** keep the stronger knockback; resistance from a heavy
  target or collision with solid deck structure creates a small impact burst.
  Steam changes position and makes overboard play legible.

Do not author 36 bespoke scripts. The matrix remains four element rules plus
nine shape verbs. The combinations emerge where a verb asks an element a
question: consume, root, route or displace.

### 7.3 Add weapon evolutions instead of more scalar cards

At the drafts after waves 4 and 8, replace two ordinary card positions with a
matched **Reforge** pair for one eligible, unevolved skill. Each shape has two
mutually exclusive evolutions. Examples:

- Beam: **Cutting Ray** locks its direction, narrows and ramps against a target
  that stays in the cut; **Tracking Coil** widens, shortens and rewards sweeping
  across several targets.
- Mortar: **Airburst** enlarges the rim and weakens the center; **Bunker Buster**
  narrows the rim and hits hulks/Armored harder.
- Sentry: **Watchman** prioritizes the deepest boarder; **Interdictor** targets
  the fastest boarder and applies stronger control.
- Field: **Strongpoint** grows after its anchor stays fixed for 1.5 seconds;
  **Rolling Front** eases its anchor slowly back toward the hero between casts.

Reforges should replace some generic +damage/+area offers, not inflate the card
count without bound. They create build identity that can be named in a run
report.

## 8. Level and campaign design

### 8.1 Present the run as three watches and a boss

**First Watch — waves 1–4: learn and answer.**  
Fixed waves 1–2 teach. Wave 3 is the first Muster variation. Wave 4 tests the
lesson with the Grapple Run and a hulk.

**Black Watch — waves 5–8: prioritize and hold.**  
Furnace Knights appear, elite marks begin, and Muster creates screens,
pincers and protected shooters. Wave 8 removes comfortable visibility through
Blackout but stays compositionally authored.

**Last Watch — waves 9–11: triage and sacrifice.**  
Two lanes demand attention at once. Each wave should deliberately ask which
asset the player is willing to leave alone: a cannon, crew group, Boiler health
or an elite target. Do not simply add bodies.

**The Colossus — wave 12: execute the build.**  
Keep his lane march, stomp, turn and high health. Filler enemies exist to force
target decisions, not to obscure his telegraphs. No elite, random behavior
quirk or arrival transport should compete with him.

### 8.2 Use four encounter grammars

Muster should assemble from a small readable grammar:

- **Assault:** one lane, mixed bodies, direct DPS/position test;
- **Pincer:** two outer lanes, travel and triage test;
- **Screen:** melee bodies protecting Gunners; Quartermaster promotion is
  excluded because its aura would stack a second protected-shooter pressure;
- **Siege:** one Armored anchor with timed supporting arrivals.

Each grammar needs a clear pre-wave threat line derived from the actual queue,
not authored separately. Examples: `PINCER · PORT + STARBOARD · SPARKING` or
`SIEGE · CENTRE · 1 FURNACE KNIGHT`.

### 8.3 Do not build a second map yet

A second deck should wait until the one-deck variation package, hardpoint
loadouts and third hero are proven. If a later map is commissioned, it should
be a different mission on the same dimensional deck envelope—such as escorting
a movable cargo engine or defending two linked boilers—not a differently sized
ship that invalidates the existing combat grammar.

## 9. Hero ideas

### 9.1 Recommended: The Rigger

**Question:** *Which threat will you move, and where will you put it?*

The Rigger is the control hero. He is neither rewarded merely for standing
close nor for preparing one fixed zone. He earns power by changing enemy
position and by using the ship's edges.

- **Body:** medium health, medium speed, one recharging dash.
- **Fixed attack:** Steam Harpoon — a short line with modest damage and
  strong controlled displacement.
- **Gauge: Tension.** Builds from actual enemy displacement, impact against
  structures and overboard kills; decays slowly when no enemy has moved.
- **F — Make Fast.** Harpoons one target to a short-lived sternward limit. It
  can still attack, move sideways and be damaged but cannot advance past it;
  Armored duration is shorter and the Colossus converts the failed hold into
  Exposed instead.
- **V — Haul.** Spend Tension to pull the made-fast target toward the Rigger or,
  with no target, pull the Rigger toward the nearest valid deck anchor.
- **Space — one standard dash.** One recharging charge provides an escape
  without matching the Captain's mobility; anchor Haul is the Rigger's unique
  traversal.
- **Draft bias:** Lance, Gale, Whip and Beam; still uses the complete element
  matrix, while Harpoon defaults to Steam.

Why this hero first: enemy arrival, elite priority, Steam impact and hardpoint
geometry all make his decisions richer. He therefore benefits from the proposed
shared-system work and serves as its proof. Boss and Armored resistance must be
explicit; full immunity would make his class disappear in the most important
fights, while unrestricted control would trivialize them. Let Tension convert
failed displacement on heavies into a brief exposed-state bonus instead.

### 9.2 The Powderhand

**Question:** *How much of the deck are you willing to make dangerous?*

Builds Fuse from prop damage and plants limited powder charges. F detonates the
oldest charge; V links nearby kegs into a deliberate chain. Strong interaction
with the reactive deck and Powder Locker, but high risk of making keg placement
the universal answer or punishing a ship loadout for not taking powder. Keep as
the second prototype candidate.

### 9.3 The Signalman

**Question:** *Which lane gets the ship's attention?*

Marks a priority lane for cannon and crew behavior, builds Command when allies
complete work, and spends it to redeploy or reinforce. This makes the allied
deck layer playable, but risks becoming an indirect commander in an action game
and becoming weak at Heat 5 where crew is removed. Best held for a future mode
with richer ally behavior.

### 9.4 The Stormcaller

**Question:** *Which elemental state will you create and consume?*

Would specialize in the new Kindle/Fix/Conduct/Displace reactions and swap the
element of the fixed attack during combat. Mechanically clean, but it proves
the element rework less effectively than the Rigger and risks reading as
“better at the draft” rather than as a new spatial hero.

## 10. Delivery order

### Phase 0 — freeze the baseline

1. Record the current harness result and authored queue signatures.
2. Add no gameplay and change no balance numbers.
3. File the exact pre-change measurements each later packet requires.

Exit: every later A/B has a named baseline, an exact feature-off path or clean
before snapshot, and a non-vacuous test that distinguishes the two arms.

### Phase 1 — enemy-driven run variation

1. Build Muster with authored grammar and threat budget.
2. Add the derived threat line from the resulting queue.
3. Add Quartermaster, measure it, then add Sparking in a separate packet.
4. Regression-test and integrate the existing transport/drop presentation
   after queue variation is stable; do not rebuild it.

Exit: two runs on the same Heat regularly produce different target priorities
while holding authored difficulty bands.

### Phase 2 — shared combat identity

1. Rework Beam into a fixed-duration channel without changing its total base
   damage.
2. Anchor Field to active-skill landings while keeping it passive.
3. Let active casts advance Pulse's timer while keeping it passive.
4. Add the element-reaction attribution seam, then make the Captain's two-beat
   Cleave readable before Ember is allowed to consume its second beat.
5. Add reactions one at a time and add the Reforge infrastructure plus one Beam
   pair before authoring the rest.
6. Close with IN-00, the combined-system audit; isolated packet gates are not a
   substitute for exercising every core interaction together.

Exit: each changed shape creates a different input or positioning pattern, the
Second Hand still produces a valid keyless fifth slot, and a playtest can name
why a changed shape was chosen without citing DPS.

This phase's release-critical core is AB-01–04, EL-00–03, RF-00–01 and IN-00.
The P3 Lance, Gale, Mortar and Steam Impact packets are optional depth after the
ship/campaign pass; Gale and Steam Impact become prerequisites only if the
Rigger proceeds.

### Phase 3 — ship loadouts

1. Convert berths to Bow/Waist/Stern hardpoints plus trophy rail.
2. Map existing fittings and preserve save ownership.
3. Add Powder Locker and Signal Crane after the EV-05 arrival audit. SH-01–04
   are one player-facing release unit: individual packets may merge in order,
   but never publish the three-slot cap while Bow or Waist still lacks a rival.
4. Only add presets after every hardpoint has at least two valid choices.

Exit: no functional loadout can install everything, and playtesters can explain
what they gave up.

### Phase 4 — campaign watch pass

1. Add watch titles and derived encounter grammar to the draft/wave preview.
2. Re-author waves 5–7 and 9–11 around priority and triage, not more bodies.
3. Tune Colossus filler so the boss remains the readable center.

Exit: a player can describe the purpose of each four-wave band after one run.

### Phase 5 — third hero prototype

Prototype the Rigger with primitive presentation and the existing matrix. Test
waves 4, 8, 10 and 12 before commissioning final art or voice.

Exit: he creates a third spatial question, remains viable against heavy targets
and does not invalidate lane pressure through unlimited displacement.

## 11. Acceptance metrics

The expansion is successful when all of the following are true:

- the existing harness remains green and new fields have readers;
- same seed, Heat, hero and loadout reproduce the same queues and draft;
- ordinary wave threat remains within its declared budget;
- at least 70% of completed runs contain two or more different encounter
  grammars between waves 5 and 11;
- elite marks change kill order or player travel, not only clear time;
- every hardpoint has at least two choices with a measurable pick split; no
  fitting exceeds a 70% pick rate after players own all options;
- each ability shape has a distinct input or positioning pattern;
- Reforge choices appear in the run report and produce divergent usage;
- the Rigger's contribution is not dominated by raw damage and his control is
  not zero against the Colossus;
- IN-00 proves wave 12 remains readable with all release-critical shared combat
  systems enabled;
- visual A/B tools report an exact zero noise floor before their results are
  used.

## 12. Explicit non-goals

- no second deck size, fourth lane or navigation rewrite;
- no procedural prop restow between waves;
- no fitting that is a hidden stat bonus;
- no third persistent currency;
- no 36 bespoke ability implementations;
- no new enemy species until Muster and elite marks prove insufficient;
- no destructible transport ships in the arrival pass;
- no random modifier layered over event waves or the Colossus;
- no third hero commissioned into final art before a mechanical prototype
  survives the key waves.

The game is already broad. The next version should make its existing breadth
produce sharper choices, stronger run stories and a ship that is genuinely
configured rather than merely accumulated.

## 13. Agent operating contract

This section turns the design above into an implementation handoff. An agent
assigned one packet below is **not** assigned the whole expansion.

### 13.1 Authority and conflict handling

Use this order when two instructions appear to disagree:

1. the live code and its harness-pinned behavior;
2. `STATUS.md` and `docs/OUTSTANDING.md` for current ownership and explicit
   owner decisions;
3. this document for expansion order, scope and acceptance;
4. older focused design documents for rationale and rejected alternatives.

Inside this document, a packet in Sections 16–20 owns its implementation
numbers and rules. Sections 1–12 own intent and product direction, but never
override a packet's more specific numeric contract.

Do not silently pick a side when levels 1–3 conflict. Stop the packet, quote
both statements and ask for a decision. Do not “resolve” a conflict by changing
an unrelated subsystem.

### 13.2 One packet means one behavior

Every implementation assignment must name exactly one packet ID from section
14. A packet may include its tests, renderer read and documentation comments;
those are part of the behavior. It may not include opportunistic cleanup,
retuning neighboring systems, new assets, another packet or a general refactor.

Examples:

- EV-01 may add the Muster planner and its tests. It may not add an elite.
- AB-01 may make Beam a channel. It may not rework Lance because both are lines.
- SH-01 may enforce hardpoints. It may not add Powder Locker.
- HR-01 may prototype Tension and add its required reused model row. It may not
  commission or ingest unique Rigger art.

If a prerequisite defect is discovered, prove it with the smallest failing
check and stop. File it as its own packet. Do not hide the repair inside the
feature unless the feature cannot exist without the repair and the handoff
explicitly expands the allowed file list.

### 13.3 Required packet handoff

Before editing, the implementing agent must write down:

- packet ID and one-sentence outcome;
- every listed **Requires** item and the evidence that its required verdict is
  present;
- every **Serialize after** item the coordinator must order before this merge;
- files it expects to modify;
- invariants it must preserve;
- exact checks it will add;
- the feature-off or before/after comparison;
- any player-facing text or save-data change;
- the condition that would make it stop instead of tune.

At completion it must report:

- files actually changed;
- checks run and their exact verdicts;
- measured result against the packet's gate;
- any deviation from the specified data contract;
- any new field and the exact reader that consumes it;
- whether old saves and feature-off behavior were exercised;
- remaining risks, without declaring them solved by inspection.

### 13.4 Repository discipline

- Read the whole function being changed and every direct caller before editing.
- Search for every read of a renamed field or changed signature.
- Preserve unrelated dirty work. Never stage or commit another packet's file.
- Add optional parameters at the end of live signatures unless the packet
  explicitly authorizes a coordinated caller migration.
- Prefer a new pure helper over another stateful branch in `game.gd` when the
  behavior can be expressed without a Node.
- Do not add a data field without a behavioral reader and a check that fails if
  the reader is removed.
- Do not add player-facing copy until the underlying value is derived from the
  live state it describes.
- A renderer feature never changes simulation state or consumes simulation RNG.
- A test must fail when its production call is deleted. A check that only
  restates a constant is insufficient.

## 14. Priority, dependency and packet map

The priority is the order in which value should be shipped, not permission to
run overlapping packets in the same files. `game.gd`, `enemy.gd`, `hud.gd`,
`view3d.gd` and `tests/parity_test.gd` are collision-heavy; serialize packets
that touch the same file.

- **P0:** foundation required before expansion behavior can be trusted.
- **P1:** first release-train depth; it may remain player-hidden until a declared
  cross-packet release gate closes.
- **P2:** release-critical completion depth, dispatched only after its P1
  measurements hold.
- **P3:** optional experiment or late depth; failure must not hold P0–P2 hostage.

**Requires** is a hard mechanical or accepted-verdict prerequisite. If one is
absent, the assigned agent stops without editing. **Serialize after** is a
coordinator-owned order for shared-file collisions or evidence sequencing; its
absence does not mean the behavior is mechanically impossible and must not be
reported as a prerequisite defect. **Stable** means merged with every declared
automated gate green. **Verdict** means a lead has also reviewed its G3/G5
evidence and written an explicit continue decision; a green harness alone is
not that verdict.

| ID | Priority | Outcome | Requires | Serialize after |
|---|---:|---|---|---|
| BASE-00 | P0 | record baseline queue, harness and measurement fixtures | none | none |
| EV-01 | P0 | deterministic Muster plans for ordinary waves | BASE-00 | none |
| EV-02 | P0 | manifest/threat copy derived from cached live plans | EV-01 | none |
| EV-03 | P1 | Quartermaster creates an assassination priority | EV-01, EV-02 | none |
| EV-04 | P1 | Sparking creates a movement priority | EV-03 verdict | none |
| EV-05 | P1 | existing transport/drop presentation survives Muster and exposes a read for Signal Crane | EV-01 stable | none |
| EV-06 | P2 | lane-local proven lulls expose a recovery prompt | BASE-00 | EV-02 |
| AB-01 | P1 | Beam becomes a fixed-duration channel | BASE-00 | none |
| AB-02 | P1 | Field anchors to active-skill landings and stays passive | AB-01 stable | none |
| AB-03 | P1 | active casts advance Pulse and it stays passive | BASE-00 | AB-02 |
| AB-04 | P2 | Captain Cleave becomes a readable two-beat close combo | BASE-00 | AB-03 |
| AB-05 | P3 | Lance rewards a lined group with carried knock | BASE-00 | AB-01, AB-04 |
| AB-06 | P3 | Gale leaves one short directional current | BASE-00 | AB-01–03, EL-00 |
| AB-07 | P3 | Mortar lands after one authoritative warning clock | AB-02, EL-00 | AB-06 |
| EL-00 | P1 | status/reaction damage keeps source attribution | BASE-00 | AB-01 |
| EL-01 | P2 | Frost Root and Steam Shatter interaction | EL-00 | none |
| EL-02 | P2 | Arc Conduct changes Whip/Beam routing | AB-01, EL-00 | EL-01 |
| EL-03 | P2 | Ember Kindle gains readable Mortar/Cleave consumers | AB-04, EL-00 | EL-02 |
| EL-04 | P3 | Steam converts resisted displacement into Impact | AB-06, EL-01 stable | IN-00 |
| RF-00 | P2 | evolution field and Reforge draft infrastructure | AB-01 stable | EL-03 |
| RF-01 | P2 | one complete Beam evolution pair | AB-01, RF-00 | none |
| IN-00 | P2 | all release-critical combat systems pass one combined audit | AB-01–04, EL-00–03 and RF-01 stable | none |
| SH-01 | P1 | three hardpoints plus trophy rail constrain existing fittings | BASE-00 | none |
| SH-02 | P1 | hardpoint UI and save reconciliation are complete | SH-01 | none |
| SH-03 | P1 | Powder Locker gives Waist its first rival | SH-02 | none |
| SH-04 | P1 | Signal Crane gives Bow a persistent information rival | EV-05, SH-02 | SH-03 |
| SH-05 | P3 | Firebreak Grating competes for the Waist | EL-00, SH-02 | SH-04 |
| SH-06 | P3 | Emergency Main adds a stern deck verb | SH-02, EL-00 | SH-05 |
| SH-07 | P3 | three validated hardpoint presets | SH-03, SH-04, SH-05 and SH-06 all pass G5 | none |
| LV-01 | P1 | three Watches and encounter grammar are communicated | EV-02 | none |
| LV-02 | P2 | waves 5–7 are re-authored around priority | EV-03, EV-04 measurements | none |
| LV-03 | P2 | waves 9–11 are re-authored around triage | LV-02 verdict | none |
| LV-04 | P2 | wave-12 filler supports rather than obscures the Colossus | LV-03 | none |
| HR-00 | P3 | explicit gauge modes preserve both existing heroes | BASE-00 | IN-00, SH-04, LV-04 |
| HR-01 | P3 | primitive Rigger/Tension vertical slice | HR-00, EL-04 stable | none |
| HR-02 | P3 | Make Fast and Haul control prototype | HR-01 verdict, SH-02 | none |
| HR-03 | P3 | Rigger draft, report and class screen integration | HR-02 verdict, SH-04 and LV-04 stable | none |

Parallel work is safe only when the allowed file lists do not overlap. In
practice, EV work and SH work may proceed together only if neither packet is
editing `game.gd`, `hud.gd` or the shared harness at the same time.

### 14.1 Release gates

Every packet declares which gates apply:

- **G0 — parse and baseline:** project loads, harness exits zero, `git diff
  --check` is clean.
- **G1 — behavioral check:** a production call is exercised and deletion of
  that call would fail the new check.
- **G2 — deterministic check:** identical inputs produce byte-identical plan or
  save output; planning leaves unrelated RNG state unchanged.
- **G3 — distribution check:** the intended behavior moves a pre-declared
  statistic beyond the tool's measured resolution. “No visible difference” is
  not a pass.
- **G4 — visual check:** the drawn mark is driven from the simulation's exact
  center, radius and timer; visual A/B noise floor is exactly zero.
- **G5 — hands-on check:** a human can state the new decision and its
  counterplay after playing the forced fixture.

G0 applies to every packet. BASE-00 is the sole packet exempt from G1. IN-00
adds no feature, but its combined production-path checks still satisfy G1. A
packet cannot compensate for a failed gate by making its numbers larger unless
it explicitly allows one tuning pass. When a kill condition says CUT, preserve
the measured report, then revert the packet or use its explicitly declared
feature-off seam; do not invent a permanent flag solely to hide a failed design.

Two cross-packet release gates are explicit: AB-01–04, EL-00–03 and RF-01 do not
ship without IN-00; SH-01/SH-02 do not ship without SH-03/SH-04. These gates do
not authorize one agent to combine their implementation packets.

## 15. Shared engineering contracts

### 15.1 Run planning and RNG

There are currently two persistent streams and one derived wave stream:

- `rng` owns gameplay rolls and spawn jitter;
- `visual_rng` owns presentation and deterministic cosmetic placement;
- `tempo_for()` creates a local stream from seed, wave and salt.

Muster and elite planning must create their own local stream. Use one named
salt beside the planner; never draw from `rng`, `visual_rng`, global `rand*()`
or `RandomNumberGenerator.randomize()`. Planning must be a pure function of
seed, wave, Heat and authored data.

“Leaves RNG unchanged” means planning itself does not consume the live streams.
Once a plan contains a different number of enemies, the played run will
naturally make a different number of later combat and spawn-jitter rolls. Do
not write an impossible check demanding two different rosters leave the entire
future run's RNG state identical.

Build and cache all twelve immutable wave plans after the run seed and Heat are
resolved in `begin_run()`. `start_wave()` and `next_wave_manifest()` must read
the same cache. A manifest generated from `SkyGearData.WAVES` while the fight
uses a mutated queue is a release-blocking lie.

### 15.2 Data ownership

- Authored bases live in `game_data.gd` or the focused pure module named by the
  packet.
- Per-run choices live in the cached wave plan, run fitting snapshot or skill
  instance.
- Per-enemy timers and statuses live on `SkyGearEnemy`.
- The renderer mirrors live state and owns no gameplay countdown.
- HUD copy is derived from live/cached state and is never a second schedule.

Never mutate a dictionary stored in `SkyGearData`. If an enemy needs a derived
configuration, duplicate it or keep the overlay in a separate field. A check
must compare the base table before and after configuring a marked enemy.

### 15.3 Geometry and timers

One function owns each gameplay shape. Simulation and renderer both ask it.
Examples already in the project are `stomp_radius()`, `swing_wedge_reach()` and
`fire_pool_radius()`. New elite pulses, Field anchors, fitting walls and Rigger
tethers follow the same rule.

Countdowns must retain their original duration separately when the renderer
needs normalized progress. Never normalize by a countdown that shrinks every
frame. Heat-adjusted windups are read from the actual instance duration, not
re-derived from the base table.

### 15.4 Save compatibility

No packet may erase earned Workshop, Article or fitting ownership. New keys are
merged onto `SkyGearWorkshop.fresh()` in `load_state()`. A migration must be:

- idempotent;
- deterministic;
- safe when old arrays contain unknown or tabled IDs;
- covered with an ephemeral store, never the player's real `user://` file;
- explicit about which valid old choice wins when two old choices now conflict.

Prefer reinterpreting the existing `berths` array over replacing the entire
save schema. Section 18 specifies the hardpoint migration.

### 15.5 Telemetry and reports

Telemetry is added with the behavior that consumes it, not as a speculative
framework. Damage remains attributed to the slot that caused it. A reaction may
have a secondary label, but it must not become a second copy of the same damage
in the total.

Run reports remain copyable plain text. New detail is silent when absent so old
baseline reports remain stable. Queue grammar, elite name, evolution and
hardpoint selection must be reproducible from seed/Heat/loadout; do not add a
second visible “muster seed.”

EL-00 is the declared exception to report comparability: it repairs burn
attribution that the live report currently omits. Its packet names the surviving
comparisons and establishes the `damage attribution v2` evidence baseline for
all later combat packets.

### 15.6 Performance and caps

Respect the existing 64-enemy spawn cap, ally cap, sentry cap, effect pools and
renderer reuse dictionaries. New planners run once per run, not every frame.
One elite aura may scan live enemies at current caps; do not allocate a Node or
material per frame. New renderer keys must join the existing `_used` cleanup
path.

## 16. Enemy-variation implementation packets

### 16.1 BASE-00 — baseline fixture

**Outcome:** later work has a trustworthy before state.  
**Files allowed:** no project files. Measurement output may live under the
existing ignored work area.  
**Requires:** none.  
**Gates:** G0.

Required checks and evidence:

- harness exit code and reported check total;
- byte signatures of `_build_spawn_queue()` for waves 1–12 at Heat 0 for seeds
  `STOW`, `TEMPO`, `WATCH1`, `WATCH2`, `WATCH3`, and `COLOSSUS`;
- `rng.state` and `visual_rng.state` immediately before and after queue
  construction;
- current wave duration, captain damage taken and held/not-held per wave from
  the balance tool at its stated sample resolution;
- one representative Ember and one non-Ember run report, including every
  per-slot damage/hit/kill row, labelled `damage attribution v1` in the evidence
  filename rather than added to player-facing copy;
- one posed screenshot each for an ordinary arrival, the blackout and the
  Colossus.

If the harness or a fixture fails before feature work, stop. Do not redefine
the baseline around the failure.

### 16.2 EV-01 — deterministic Muster

**Outcome:** eligible ordinary waves receive one reproducible encounter grammar
without changing event waves or difficulty budget.  
**Files allowed:** new `scripts/muster.gd`, `scripts/game.gd`, and focused
additions to `tests/parity_test.gd`. `scripts/game_data.gd` may change only if a
shared authored table is required.  
**Forbidden files:** `enemy.gd`, `hud.gd`, `view3d.gd`, cards, Workshop,
fittings and wave balance values.  
**Requires:** BASE-00.  
**Gates:** G0, G1, G2 and G3.

Create a pure `SkyGearMuster` helper. It owns no Node, no live game reference
and no mutable static state. Its public result is:

```gdscript
{
    wave: 5,
    grammar: "PINCER",
    batches: [
        {time: 0.0, type: "SWARM", count: 5,
         lanes: [0], source: 0},
    ],
    budget_before: 12.0,
    budget_after: 12.1,
}
```

`source` is the authored batch index and exists for diagnostics and transient
planner tie-breaking. It must not become runtime gameplay identity. The final
`spawn_queue` remains an array of `{time, type, lane}` dictionaries so every
existing consumer continues to work. Later elite packets add only an optional
`elite` string.

Use one local stream with:

```gdscript
const MUSTER_SALT := 104729
stream.seed = hash(seed_text) ^ (wave_number * 2654435761 + MUSTER_SALT)
```

The number is a stream separator, not balance. The harness must prove it is not
the tempo salt and that calling the planner leaves both live RNG states
unchanged.

Initial threat costs are authored planner costs, not enemy-stat formulas:

| Type | Cost |
|---|---:|
| SWARM | 0.35 |
| SCRAPPER | 1.00 |
| GUNNER | 1.25 |
| ARMORED | 4.00 |
| BOSS | immutable |

Start with only these near-budget substitutions:

- 1 Scrapper ↔ 3 Swarm (1.00 ↔ 1.05);
- 1 Gunner ↔ 1 Scrapper + 1 Swarm (1.25 ↔ 1.35);
- 4 Scrappers ↔ 1 Armored (4.00 ↔ 4.00), wave 5 or later only.

Do not invent a search optimizer. Generate a finite candidate list from these
rows, reject candidates outside the budget, then choose from the survivors.
At most two type substitutions and two lane reassignments may occur in one
wave. Budget is computed after expanding an `all` lane to all three lanes.

Eligibility is exact:

- waves 1 and 2: `AUTHORED`;
- waves 3, 5, 6, 7, 9, 10 and 11: eligible only when they are not a push at the
  selected Heat;
- waves 4, 8 and 12: `AUTHORED`;
- any event, push or boss wave: `AUTHORED` regardless of the numbered list;
- `SKYGEAR_MUSTER_FLAT` set: every wave `AUTHORED`.

The first grammar set is deliberately small:

- **ASSAULT:** concentrate at least 60% of mutable threat in one lane;
- **PINCER:** put at least 35% in each outer lane and no more than 30% in the
  centre;
- **SCREEN:** place a Gunner in a lane that also contains at least twice its
  threat in melee bodies;
- **SIEGE:** include exactly one Armored anchor plus light support; unavailable
  before wave 5 or when the budget cannot pay for it.

Choose only from grammars whose postconditions can be satisfied. If none can,
return `AUTHORED`; never loop until a random roll happens to fit. Time values
stay authored. Tempo remains the only system that reshapes within-batch
spacing.

Build order inside `game.gd` is fixed:

1. after seed and Heat are resolved in `begin_run()`, build and cache twelve
   immutable plans in `wave_plans`;
2. normalize authored lanes (`all` becomes `[0, 1, 2]`);
3. apply Muster to eligible normalized batches;
4. expand lanes and counts into temporary units carrying `source`, `lane` and a
   zero-based `member` index;
5. reserve this ordering seam for EV-03 promotion; EV-01 adds no stub, field or
   speculative hook and proceeds directly to tempo;
6. apply the existing tempo offset to the surviving temporary units;
7. sort by final time, source, lane and member in that order;
8. strip transient source/member fields, retaining only the optional elite ID,
   then store a deep copy as the plan's public queue;
9. `_build_spawn_queue(wave_number)` returns a deep copy of the cached queue.

Tools that call `_build_spawn_queue()` without `begin_run()` may build the one
requested plan on demand from current seed/Heat. They must receive the same
bytes as a cached run.

Required checks, using these exact intent statements:

- `muster · feature-off deals every authored queue byte-for-byte`;
- `muster · the same seed and Heat deal the same twelve plans`;
- `muster · planning consumes neither gameplay nor visual RNG`;
- `muster · events, pushes and the boss stay authored`;
- `muster · Heat 4 closes waves 6 and 10 to mutation`;
- `muster · every emitted type and lane exists`;
- `muster · every changed wave stays inside the ten-percent budget`;
- `muster · every named grammar satisfies its own postcondition`;
- `muster · at least two plans differ across twenty-four fixed seeds`;
- `muster · deleting the planner call makes the variation check fail`.

The G3 kill condition is the one already established by the focused enemy
design: forced grammar arms must move a pre-declared per-wave behavioral
distribution beyond the balance tool's printed resolution without moving
held-rate by more than the accepted difficulty band. If queues differ but play
does not, CUT Muster through its flat seam and keep the report.

### 16.3 EV-02 — one plan, one public description

**Outcome:** the Manifest talent, wave preview, future Signal Crane and run
diagnostics describe the queue that will actually spawn.  
**Files allowed:** `scripts/muster.gd`, `scripts/game.gd`, `scripts/hud.gd`,
`scripts/screen_poser.gd`, `tests/parity_test.gd`.  
**Requires:** EV-01.  
**Gates:** G0, G1, G2 and the text audit.

Add a pure `describe(plan)` reader. It derives, rather than trusts, all mutable
roster facts from `plan.queue`: lane pressure, type counts and elite names when
later present. Grammar is the planner's validated label, and event name comes
from the existing event reader. Diagnostic batches are never public roster
authority after promotion/payment.

`next_wave_manifest()` must stop walking `SkyGearData.WAVES` directly. It reads
the cached next plan. Watch Bill continues reading the live `spawn_queue`.
Do not add a second seed: the existing run seed plus Heat reproduces the plan.

The short line has a strict information order:

`WAVE 7 · PINCER · PORT + STARBOARD · 2 GUNNERS`

Omit a segment when it carries no information. Event waves keep their event
name and authored roster; the event name is never replaced by a grammar.

Required checks:

- `brief · every count equals the cached queue it describes`;
- `brief · every named lane contains planned threat`;
- `brief · the Manifest and the fight read the same plan object`;
- `brief · feature-off copy is the authored manifest`;
- `brief · longest forced line passes containment at all four widths`.

### 16.4 EV-03 — Quartermaster

**Outcome:** one marked enemy can make target order matter.  
**Files allowed:** `scripts/game_data.gd`, `scripts/muster.gd`, `scripts/game.gd`,
`scripts/enemy.gd`, `scripts/view3d.gd`, `scripts/telemetry.gd`,
`tests/parity_test.gd`, and one forced clip/probe scenario if needed.  
**Requires:** EV-01 and EV-02.  
**Gates:** G0–G5. One tuning pass is allowed on aura radius or speed multiplier,
not both.

Add an `ELITES` row with exactly these initial fields:

```gdscript
"QUARTERMASTER": {
    "name": "QUARTERMASTER",
    "base_kinds": ["SCRAPPER", "GUNNER"],
    "hp_scale": 1.25,
    "model_scale": 1.10,
    "aura_radius": 240.0,
    "speed_scale": 1.30,
    "threat_scale": 1.50,
    "salvage": 1,
}
```

Add `ELITE_CHANCE := 0.35` beside the Muster planner constants. Elite dealing
uses the same **local per-wave Muster stream**, after grammar/substitution is
final and before tempo offsets; it never touches either live RNG. Build every
legal paid promotion without RNG first. If none exists, return no elite without
rolling. Otherwise roll chance exactly once. On success, sort eligible elite IDs,
choose one uniformly, then choose one of that mark's payable candidates as
described below. Adding a later mark may change which mark is dealt, but may not
change the already-final grammar or substitutions.

Both uniform choices call `randi_range()` once even when their list has one
entry. Do not optimize away those draws; their order is part of the cached plan.

Payment is deterministic and deliberately simple. For each possible candidate,
expand a temporary unit list and exclude the candidate, Bosses and Armored
bodies from filler. Sort remaining filler by planner cost ascending, then spawn
time descending, source descending, lane descending and member descending.
Remove from that order until removed threat meets the elite's added threat,
`base_cost * (threat_scale - 1.0)`, with a hard cap of five removed bodies. The
candidate is payable only if the target was met, the final threat stays in the
ten-percent band and the selected grammar still satisfies its postcondition.
Apply only the chosen candidate's removals to the temporary unit list and
recompute `budget_after` from the survivors, applying the chosen elite's threat
scale to its base unit. Never renumber diagnostic `source` or reuse a removed
unit's member identity.

Promotion rules:

- at most one elite on an eligible wave;
- never before wave 5; never on an event, push or boss wave;
- Quartermaster has no legal candidate when the validated plan grammar is
  `SCREEN`; that grammar already spends its pressure on protected shooters, so
  its melee screen may not also receive a speed aura;
- prefer a Gunner, otherwise a Scrapper, in the first half of the plan;
- “first half” means `time <= (first_time + last_time) * 0.5`; within the
  preferred kind, sort payable candidates by time, source, lane and member,
  then select uniformly with the local stream;
- if the ten-percent band or grammar cannot hold after the exact payment rule,
  deal no elite;
- write optional `"elite": "QUARTERMASTER"` on the chosen queue entry;
- `spawn_enemy(kind, lane, elite_id: StringName = StringName())` and
  `enemy.configure(..., elite_id: StringName = StringName())` receive optional
  final parameters so
  existing callers remain valid.

The enemy keeps `elite_id` and a separate elite spec. It does not mutate its
base `config`. At configure, apply `hp_scale` once to instance current/max HP.
`model_scale` is renderer-only and does not enlarge radius, reach or any hit
geometry; `threat_scale` is planner-only. Every unlisted damage, speed, attack
and AI value stays on the base instance.

`game.enemy_speed_scale(enemy)` is the single Quartermaster gameplay reader:
it returns 1.30 only when another live Quartermaster is within 240 ground units,
otherwise 1.0. Apply it beside Frost's movement scale, multiplicatively. The
Quartermaster does not buff itself and two auras never stack.

On death it drops one guaranteed existing salvage pickup in addition to normal
rolls, increments `tel.salvage` once and becomes ineligible to buff immediately.
No new currency or pickup kind is created.

Presentation uses existing systems: a brass/Arc collar outside the body,
`QUARTERMASTER` on the health plate, and a subtle radius edge that never uses
the hostile attack-telegraph color. All sizes and center positions read the
same aura function as the speed check. No new asset is required.

Required checks:

- base config remains deep-equal before and after marked configuration;
- chance is one exact roll only after a payable list exists, on the local stream;
- candidate/payment choice is stable and removes only its declared filler;
- no elite is dealt on forbidden waves or over budget;
- Quartermaster is never promoted on a `SCREEN` plan, including authored wave 7;
- an ally inside the live aura moves 30% faster before Frost and base speed are
  applied; one outside does not;
- self is not buffed and two forced Quartermasters do not stack;
- death removes the buff and drops exactly one guaranteed salvage;
- every live Quartermaster has its marker and name;
- the forced fixture changes kill order, not only wave duration.

CUT the mark if the six-seed forced fixture always kills it first, never kills
it first, or only stretches clear time after the one allowed tuning pass.

### 16.5 EV-04 — Sparking

**Outcome:** a marked enemy forces the player to leave a chosen patch of deck.  
**Files allowed:** the EV-03 list.  
**Requires:** EV-03 verdict.  
**Gates:** G0–G5. One tuning pass is allowed on period or radius, not damage.

Initial row:

```gdscript
"SPARKING": {
    "name": "SPARKING",
    "base_kinds": ["SCRAPPER", "ARMORED"],
    "hp_scale": 1.15,
    "model_scale": 1.08,
    "period": 4.5,
    "windup": 0.85,
    "radius": 150.0,
    "damage": 8.0,
    "threat_scale": 1.40,
    "salvage": 1,
}
```

Register `SPARKING` in the existing dealer; do not add a second elite roll.
When both mark IDs have at least one payable candidate, the dealer's sorted-ID
choice gives each mark equal weight regardless of body count. Sparking prefers a
Scrapper, otherwise Armored; candidate sorting/selection and filler payment are
the EV-03 rules. Re-run Quartermaster's frequency and kill-order evidence because
adding a legal mark intentionally changes its dealt share.

Keep pulse state separate from the enemy's melee state:
`elite_pulse_left`, `elite_pulse_windup`, `elite_pulse_origin` and
`elite_pulse_duration`. At windup start, latch the origin. The ring and resolve
stay there even if the enemy is shoved. Killing the elite during windup cancels
the pulse. The pulse damages the captain only; it does not silently tax crew,
cannons, sentries or the Boiler, and it applies no stun. Resolve through
`damage_player(8.0, "sparking")` so taken-by-source telemetry can isolate it.
The elite windup is not multiplied by Heat's ordinary attack-windup scale.

Initialize `elite_pulse_left` to 4.5 and do not advance it during arrival
immunity. Once hittable, it runs in every melee/stun/root state on accepted
simulation delta. When it crosses zero, add 4.5 rather than assign it, latch the
origin and start a carried 0.85-second windup after applying any overshoot. The
next period continues during that windup, so resolved pulses remain 4.5 seconds
apart. Resolve once when the carried windup crosses zero; a bounded loop handles
a catch-up step, though `period > windup` forbids overlapping rings.

Expose `elite_pulse_radius()` and `elite_pulse_progress()` for both simulation
and renderer. Use the existing hostile telegraph family and telegraph decal
budget. Do not append a generic `_fx` circle whose geometry can drift.

Required checks cover exact timing at multiple step sizes, anchored center,
inside/outside damage, death cancellation, forbidden waves, budget, visual
radius/timer identity and a forced fixture that changes player distance moved.
If the player can ignore it or if it becomes unavoidable in a cargo crossing,
CUT after the one allowed period/radius adjustment.

### 16.6 EV-05 — arrival integration audit

**Outcome:** existing hull movement, airborne immunity, drop arcs and landing
rings remain correct with cached/mutated plans.  
**Files allowed:** tests and a probe only unless a demonstrated regression
requires a separately approved fix.  
**Requires:** EV-01 stable.  
**Gates:** G0, G1, G2 and G4.

Do not add an arrival planner. The existing renderer deliberately selects a
hull from wave number and reads simulation clocks. Required checks:

- Muster changes no `ARRIVAL_TIME`, arc endpoint or `can_be_hit()` result;
- every non-boss spawn still receives exactly one airborne window;
- the landing ring center equals the live simulation position on every sample;
- wave 12 still returns no arrival hull;
- event/push presentation does not duplicate the boarding hulk;
- feature-off and feature-on queues differ only in planned roster, never in the
  renderer's ownership of spawn time;
- the visual probe reports a zero noise floor.

### 16.7 EV-06 — real recovery window

**Outcome:** the player is told about a lane-local lull only when there is
enough live time to complete useful deckwork.  
**Files allowed:** `game.gd`, `hud.gd`, `coach.gd`, poser and tests.  
**Requires:** BASE-00. EV-02 is merge serialization, not a mechanical
prerequisite.  
**Gates:** G0, G1, G3, G5 and text audit.

Add one pure query, not a new timer:

```gdscript
func breathing_room() -> bool:
```

Define `player_lane()` as the lowest-index `LANE_CENTERS` entry with minimum
absolute x-distance from the player's current position. `breathing_room()` is
true only when all of these live facts hold:

- the game is in unposed `PLAY`, the remaining `spawn_queue` is non-empty and
  no boarding hulk is open;
- no live enemy, including airborne or temporarily unhittable instances, owns
  `player_lane()`;
- no live enemy in another lane currently returns `victim().who == "player"`;
- the next queued **landing**, not merely its spawn, is at least
  `SkyGearDeckwork.REPAIR_SECONDS + 0.40` seconds away.

Enemies committed to another lane do not suppress the window. The query is
read-only: it does not reserve a lane, retarget an enemy or consume the queue.
It returns false once the queue empties into wave clear. The coach may say
`BREATHING ROOM` once per wave on the false→true edge; no banner repeats while
the condition remains true.

“Seconds to landing” is exactly
`float(spawn_queue[0].time) + SkyGearEnemy.ARRIVAL_TIME - wave_time`; never
compare the absolute queue timestamp directly with the repair duration and
never omit the shipped 0.80-second airborne interval.

Required checks exercise exact boundary times, same-lane airborne and distant
enemies returning false, an other-lane enemy returning true until it chooses the
player, an open hulk, pause, wave clear, no queue/RNG mutation and the once-per-
wave latch. G3 records valid windows per run and the share of completed standard
Heat-0 samples with at least one. In the standard n-120 sample, the 95% Wilson
lower bound for that share must exceed 0.50. G5 passes only when a tester uses
the prompt to start a deck action they otherwise would have skipped. If the
frequency misses that floor, remove the copy rather than weakening the predicate
into a lie. Signal Crane is intentionally not a consumer of this query.

## 17. Ability, element and Reforge implementation packets

These packets deliberately separate shape behavior from element reactions.
An agent must not combine two packet IDs in one change because a damage delta
then has no single cause and the attribution checks cannot identify the fault.

### 17.1 AB-01 — Beam becomes a channel

**Outcome:** Beam occupies time, asks for aim commitment and remains the same
base damage budget instead of being a line attack with a beam picture.  
**Files allowed:** `scripts/game_data.gd`, `scripts/game.gd`, the element-entry
guard in `scripts/enemy.gd`, `scripts/player.gd`, `scripts/view3d.gd`,
`scripts/telemetry.gd`, tests and one forced visual probe.  
**Requires:** BASE-00.  
**Gates:** G0–G5. Do not tune damage in this packet.

Add these fields to `RAY`:

```gdscript
channel_time: 0.36
channel_ticks: 4
channel_move_scale: 0.60
```

The table's `damage: 7.0` becomes damage **per tick**. Four ticks at elapsed
times 0.00, 0.12, 0.24 and 0.36 preserve the current 28 base damage against a
boarder that stays in the line. Keep the derived cooldown; do not write a
second literal for it.

For `RAY` only, clamp the fully derived cooldown after all ordinary shape,
element and card multipliers:

```gdscript
effective_cooldown = maxf(derived_cooldown, channel_time)
```

The card face, cooldown assignment and bot evaluation all read that effective
value. The normal cooldown begins on press, so it can never expire before the
0.36-second channel. Fifth Gear's explicit free-cast override may still assign
zero after this clamp; `active_channel` remains the sole re-entry guard until
that free channel completes or cancels.

`game.gd` owns one `active_channel` dictionary. An empty dictionary means no
channel. At minimum a live row carries:

```gdscript
{
    slot: int,
    elapsed: float,
    next_tick: int,
    tick_interval: float,
    forced_target: Variant,
    snapshot: Dictionary,
    last_land: Vector2,
    element_applied_serials: Dictionary,
}
```

Starting the channel is still one successful `cast_skill()` call. It must:

1. reject a passive, a cooling skill or a second live channel;
2. increment casts and telemetry exactly once;
3. resolve Fifth Gear, multi-shot scaling and Overpressure exactly once;
4. snapshot final damage, range, width, knock, element, evolution and whether
   the cooldown is free;
5. spend Overpressure once and start cooldown immediately;
6. deliver tick zero through the same tick resolver used by later ticks.

If `aim_at` is an explicit `Vector2`, every tick aims at that point. Otherwise
each tick reads the current live aim. The origin is the captain's current
position on that tick. A normal tick uses the existing line hit test and may
hit every body in the width. Catch up with a bounded `while` when a step crosses
more than one tick; never derive tick count from rendered frames. On each tick,
`last_land` inherits the shipped Ray convention exactly:
`origin + direction * range * 0.5`. It is the midpoint of the damaging segment,
not its rendered endpoint.

Each delivered tick is a complete primary damage hit: it rolls crit
independently per body, records a hit and may trigger the shipped crit explosion;
Pressure/lifesteal see only that tick's dealt amount. Element application has a
separate per-channel guard. The first accepted Beam-originated hit on an enemy's
`spawn_serial` applies the selected element and records that serial in
`element_applied_serials`; every later Beam tick or Beam crit-explosion hit on
that body deals its ordinary damage but skips `_apply_element()`. Keep the
selected element as damage context for existing tint, attribution and
crit-explosion routing; the guard suppresses status/reaction mutation only. An
immune or undelivered hit does not consume the serial. A body swept into the
line later still receives its one application.

Do not use a global or transient “Beam is resolving” flag: a Beam kill may open
the shipped kill-explosion call tree synchronously, and that independent Ember
effect must not inherit Beam's guard. Instead add an optional final
`element_once: Variant = null` argument, preserving existing caller order, to
the line helper, `damage_enemy()`, `enemy.take_damage()`, `_apply_element()` and
the crit-explosion circle helper. A Beam primary passes the exact
`active_channel.element_applied_serials` dictionary through that chain. The
crit-explosion edge forwards the same dictionary; every other primary, status,
kill explosion, deck effect and ally call uses the null default.

Do not claim a serial in the line intersection loop: `damage_enemy()` rolls crit
before `enemy.take_damage()` rejects immunity, and that placement would either
consume an immune target's element or move RNG. `_apply_element()`, reached only
after the shipped hit-eligibility gate, checks the optional dictionary. If the
serial exists, it returns without status mutation; otherwise it records the
serial **before** applying the status, so the later crit-explosion edge sees the
claim. `null` always permits the element and writes nothing. The kill-explosion
path must have a focused check proving it receives null even when a Beam caused
the kill.

Thus four ticks intentionally create four damage/crit/hit opportunities but
only one selected-element application per body per channel. Frost Beam needs
three casts to Root; Ember Beam cannot Kindle a body in one channel. Arc Beam's
first accepted hit may establish Conduct and later ticks may exploit that
already-existing state under EL-02. Do not fake one hidden 28-damage hit. G3
must break out status/reaction and crit-explosion damage so a nonlinear increase
is visible; if it dominates the result, stop for a follow-up rule rather than
lowering Beam base damage inside AB-01.

While the channel is live:

- `combat_move_scale()` returns 0.60 and `player.gd` applies it only to ordinary
  walking target velocity;
- other active skill casts and the class basic attack refuse to start;
- starting either the Captain's dash or the Boilerwright's Bleed Jet cancels
  the remaining ticks with no cooldown or Overpressure refund;
- being hurt does not cancel it;
- pause, hit-stop and posed state freeze it because its update receives only
  accepted simulation delta;
- run reset, wave completion, game over and returning to title clear it.

Channel completion resolves hulk splash and Residue once at `last_land`, using
the same single-cast damage value those systems receive today. It then moves a
Field anchor once under AB-02. Cancellation does neither. A kill-triggered
autofire may start one Beam, but while that channel exists further autofire is
rejected by the same guard.

The renderer reads `active_channel`; it does not run a presentation timer. It
draws a continuous origin-to-end beam and may layer a brief pulse on a delivered
tick. The visible endpoint and simulation endpoint must be returned by one
query. Sound starts once and may stop on completion/cancel; it never plays four
independent cast sounds.

Required checks:

- `beam · four scheduled ticks total twenty-eight base damage` at 1/60, 0.05
  and one 0.40-second catch-up step;
- `beam · cooldown and Overpressure are paid once on press`;
- `beam · maximum ordinary cooldown reduction cannot produce a cooldown below
  channel time; a free cast still cannot re-enter its live channel`;
- `beam · an explicit target is stable and live aim can turn between ticks`;
- `beam · walking is sixty percent while dash and jet cancel`;
- `beam · another cast and the basic wait for completion`;
- `beam · pause, hit-stop, reset and death own no orphan tick`;
- `beam · one cast and four hits share one slot attribution`;
- `beam · one body receives one element application per channel while damage
  and crit remain per tick; a swept-in body receives one and the next cast resets`;
- `beam · its crit explosion shares the element-once context while a kill
  explosion caused inside the same call tree receives null and applies normally`;
- `beam · last_land is the current ray midpoint, not the line endpoint`;
- `beam · hulk and Residue resolve once, never once per visual frame`;
- the forced clip shows a readable start, held line and release with zero probe
  noise.

### 17.2 AB-02 — Field claims ground

**Outcome:** Field remains the keyless passive Second Hand can equip, but its
location expresses the player's last committed active cast.  
**Files allowed:** `scripts/game_data.gd`, `scripts/game.gd`,
`scripts/view3d.gd`, HUD card copy and tests.  
**Requires:** AB-01, because Beam completion must publish one landing point.  
**Gates:** G0–G5. Damage, radius and tick rate stay unchanged.

Every AURA skill instance owns `field_anchor: Vector2` and
`field_anchor_set: bool`. Provide these queries/actions rather than reading the
dictionary throughout the project:

```gdscript
func field_center(skill: Dictionary) -> Vector2
func relocate_fields(land: Vector2) -> void
func reset_field_anchors() -> void
```

`field_center()` returns the captain's **current** position while
`field_anchor_set` is false. This is a live fallback, not a one-time copy: a
passive-only build therefore keeps the shipped follow behavior until the first
accepted active landing of that wave. Once set, the passive tick and
`_sync_auras()` both read the fixed anchor. No renderer code writes it.

One **accepted player active cast** relocates all equipped Fields once:

- arc, line and cone use their existing `land` result;
- Mortar uses its clamped target; before AB-07 this publishes at immediate cast
  resolution, while after AB-07 the delayed shell publishes the same point only
  at impact;
- Whip uses its final reached target;
- a manually placed Sentry uses its clamped placement point;
- Beam uses its inherited Ray midpoint `last_land`, never the rendered endpoint,
  only on normal channel completion;
- a kill-autofired active skill counts because it is a real cast;
- passive ticks, the class basic, Sentry auto-placement and a cancelled Beam do
  not count.

For multi-shot skills, publish only the final resolved `land`. Relocation
happens after all shot resolution, never inside `_resolve_cast()`. On every
`start_wave()` set `field_anchor_set = false`; `field_anchor` may copy the
captain's then-current position for diagnostics but is not authoritative while
unset. This prevents a zone left across the old deck from attacking the next
wave invisibly while allowing a build with no active skill to follow the hero
for the whole wave. Draft and pause do not move an initialized anchor.

Required checks cover initial center, each active shape's landing convention,
manual versus automatic Sentry, Beam completion/cancel, multi-shot exactly
once, wave reset, tick damage centered on the anchor, renderer/simulation center
identity, a passive-only/no-active build that follows for the full wave, and a
clip where the captain visibly leaves a useful Field behind.
Deleting the anchor from the damage tick must make the center check fail.

### 17.3 AB-03 — Pulse rewards casting cadence

**Outcome:** Pulse remains a periodic passive, but active play can bring its
next discharge forward.  
**Files allowed:** `scripts/game_data.gd`, `scripts/game.gd`, HUD/card copy,
`scripts/view3d.gd` only if its existing tell needs a read, and tests.  
**Requires:** BASE-00. AB-02 is merge serialization, not a mechanical
prerequisite.  
**Gates:** G0–G5. Base Pulse damage, radius and period stay unchanged.

Add `cast_advance: 0.35` to `PULSE`. Once per accepted active cast, after that
cast has paid its cost, subtract 0.35 from every equipped Pulse's
`passive_timer`. A Beam advances Pulse when the channel starts, not on each
tick or completion. A multi-shot skill advances once. Manual Sentry placement
advances it; Sentry auto-placement, the class basic, passives and rejected
presses do not.

The existing passive catch-up loop remains the only firing scheduler. The
advance may make the timer negative so the next simulation update fires, but
clamp accumulated advance above `-period + 0.001` so one input burst cannot
manufacture multiple retroactive pulses. Keep carrying normal timer remainder.

Expose `pulse_time_left(skill)` and `pulse_period(skill)` for the passive card
face and any world tell. Both are reads of the simulation timer. Do not put a
second countdown in the HUD.

Required checks cover accepted/rejected casts, one advance for Beam and
multi-shot, manual/automatic Sentry, exact floor behavior, timer remainder at
three step sizes, Second Hand's fifth keyless slot and a visible timer that
equals the firing scheduler on every sampled frame. G5 requires a forced clip
where the player deliberately casts to bring a Pulse forward before a group
crosses its radius; passive DPS alone is not a pass.

### 17.4 EL-00 — one attributable status-damage path

**Outcome:** burn and every future reaction are credited to the skill or basic
attack that created them without acquiring crit, knock or recursive element
application.  
**Files allowed:** `scripts/game.gd`, `scripts/enemy.gd`,
`scripts/telemetry.gd`, `scripts/cards.gd` only for modifier wiring, run report
and tests.  
**Requires:** BASE-00.  
**Gates:** G0–G3. This packet adds no new reaction.

There is a prerequisite defect to close here: the live enemy status code uses
hard-coded burn damage, burn duration, Frost slow and Arc stun chance. The
draft modifiers `burn_damage`, `burn_duration`, `slow_amount` and
`stun_chance` therefore have no gameplay reader. EL-00 must first add a failing
check for each promised card value, then make the existing status read the
corresponding run modifier. Do not silently rebalance their authored values.

Name the shipped schedule in `enemy.gd` as `const BURN_TICK := 0.25`. The `5.0`
is damage **per second per stack**, so the exact per-tick amount is:

```gdscript
amount = 5.0 * burn_stacks * BURN_TICK * mods.burn_damage
burn_tick += BURN_TICK
```

Never replace the shipped `0.25` tick factor with `mods.burn_damage`; at its
default 1.0 that mistake deals four times the intended burn. Ember sets duration
to `3.0 + mods.burn_duration`; Frost sets the existing two-second slow to
`mods.slow_amount`; Arc rolls `mods.stun_chance`. Defaults therefore reproduce
all four shipped values before any card: one stack remains 5 DPS across four
1.25-damage ticks, not 20 DPS. Short-circuit the Arc roll when chance is zero so
EL-02 can remove base stun without moving RNG.

AB-01 has already appended its optional `element_once` context to the damage
chain. Append `source_slot: int = -1` **after** that argument in
`enemy.take_damage()` and `_apply_element()`; do not reorder or replace the
guard. `game.damage_enemy()` forwards its current guard and `src_slot`. A
successful Ember application stores the most recent source in
`burn_source_slot`; later burn ticks keep that owner even after another
non-Ember hit. If EL-00 is developed before AB-01 exists on the branch, append
the source normally and let the coordinator rebase to this final order; that
missing Serialize-after row is not a reason to refuse the packet.

Add exactly one public helper:

```gdscript
func damage_status(
        enemy: SkyGearEnemy,
        amount: float,
        source_slot: int,
        reaction_id: String) -> float:
```

It temporarily installs `src_slot`, then calls the ordinary damage funnel with
empty element, zero knock, `can_crit = false` and a null `element_once` context.
Append optional funnel parameters `applies_slow_bonus: bool = true` and
`extends_taps: bool = true`; status passes false for both. Set
`grants_pressure` only when
`source_slot >= -1`; deck and allied status damage must not fund the hero. It
restores the previous slot on every return.
Consequently status damage:

- respects `can_be_hit()` and kills through the existing one-death path;
- appears once in the creating slot's ordinary damage/hit/kill totals;
- grants close-range Pressure/lifesteal for a basic or skill source, preserving
  current player-authored burn behavior, but never for deck/allied sources;
- does not roll crit, consume gameplay RNG, multiply against slow, apply an
  element, add knock, open a crit explosion or extend Tap Main;
- may show one ordinary impact/floater, but does not create a new effect timer.

Replace the burn loop's direct `hp` subtraction with `damage_status()`. Preserve
the `BURN_TICK` carried schedule and the rule that suppressed airborne/boss-turn
ticks advance their clock rather than piling up. A burn expiry clears stacks,
time and source. Burn passes reaction ID `BURN`.

`SkyGearTelemetry.fresh()` gains `reactions: {}`. A pure
`note_reaction(tel, id, amount)` stores `{triggers, damage}` per ID for
diagnostics. It does **not** add to aggregate or per-slot damage; the normal
damage note already did that. The run report prints reaction rows only when
their trigger count is non-zero.

`damage_status()` calls `note_reaction()` after its ordinary funnel only when
actual dealt damage is positive. One damaging target is one trigger; an immune
or already-dead target is zero. An area reaction therefore records several
applications but still only their once-counted total damage.

This is an intentional telemetry-attribution boundary even though combat
balance is preserved. Live burn currently subtracts HP and calls
`register_damage()` without `note_damage()`. After EL-00, an Ember run's
aggregate reported player damage, per-slot damage, hit counts, kill attribution
and any shares derived from those rows are **not comparable** with BASE-00's
`damage attribution v1` report. Queue signatures, RNG state, clear time, held
rate, damage taken, cast counts and non-Ember reports remain comparable; enemy
HP removed, Pressure and lifesteal behavior must remain physically unchanged.
Capture new representative Ember/non-Ember reports as `damage attribution v2`
before EL-01, and use only v2 report rows for later combat A/B evidence.

Required checks:

- each of the four existing status-card modifiers changes its promised value;
- default burn deals exactly `5.0 * stacks` per second as four
  `5.0 * stacks * BURN_TICK` ticks and the modifier scales that result once;
- a burn tick is credited to its latest Ember source, including slot four;
- primary totals include status damage once and reaction totals describe it
  without double-counting;
- burn cannot crit, recursively burn, gain slowed-target bonus or consume RNG;
- burn/status kills do not newly extend Tap Main;
- airborne and boss-turn immunity advance the burn clock without stored burst;
- lethal burn calls kill, salvage and report paths once;
- deck/allied status damage fills no hero gauge and triggers no lifesteal;
- the v2 Ember report changes attribution while clear time, enemy HP removed,
  Pressure and lifesteal match the v1 fixture; the non-Ember report is stable;
- deleting `damage_status()` from the burn tick makes attribution fail.

### 17.5 EL-01 — Frost Fix and Steam Shatter

**Outcome:** Frost can establish a stationary target and Steam can cash that
setup for a deliberate burst.  
**Files allowed:** EL-00 files plus `scripts/view3d.gd` and card/status copy.  
**Requires:** EL-00.  
**Gates:** G0–G5. One tuning pass may alter Shatter damage or ordinary root
duration, not both.

Add enemy state `frost_stacks`, `frost_stack_time` and `root_time`. A successful
Frost hit keeps the existing slow, adds one stack up to three and refreshes a
two-second stack window. At three stacks:

- clear the stacks and their timer;
- set root by target class: 0.90 seconds for Scrapper, Gunner and Swarm; 0.45
  for Armored; 0.18 for Boss.

Root sets desired walking speed to zero. It does not erase knock velocity,
cancel a windup already begun, extend arrival immunity or prevent an overboard
fall. Slow continues to exist before and after root. Status clocks receive only
simulation delta.

While `root_time > 0.0`, another Frost hit may deal damage and refresh the
ordinary slow, but it adds no Frost stack and never refreshes Root. This is the
per-target Root lockout; do not add a second cooldown clock. Once Root expires
or Steam consumes it, the target starts from zero stacks and must receive three
new accepted Frost applications.

When AB-01 is present, its once-per-body-per-channel element guard applies:
one Frost Beam cast adds one stack to a body, never three. No second Root
cooldown field is needed: Frost is ignored for stacking during Root, a new Root
requires three accepted applications after release, and the normal Beam cooldown
cannot undercut channel time. IN-00 owns the combined lockdown measurement
rather than weakening Root duration in this isolated packet.

In the normal damage funnel, snapshot whether the target was rooted before a
Steam primary hit. After the primary hit has been reported, if the target is
still alive and was rooted, clear root **before** applying exactly 12 status
damage attributed to the Steam source as `FROST_SHATTER`. This can trigger only
once per root. Steam's shipped swing cancel remains, including the Colossus
stomp exception.

The renderer reads `root_time` for a low ice clamp and reads the existing slow
state for tint. It must not infer root from velocity, because a shoved rooted
enemy still moves. Shatter gets one compact Steam/Frost impact, not a persistent
third status marker.

Required checks cover stack expiry and refresh, exact third-hit root, no stacks
or Root refresh while already rooted, three new applications after release, class
durations, zero walking with preserved knock, windup and boss-stomp behavior,
one Shatter, attribution to the Steam consumer, lethal Shatter, immunity, timer
step invariance, and render/simulation root lifetime identity. The forced
fixture must show a player choosing when to spend Steam rather than merely
raising total damage.

### 17.6 EL-02 — Arc Conduct changes routing

**Outcome:** Arc establishes a temporary network that Whip and Beam can exploit
without turning every Arc hit into another random stop.  
**Files allowed:** `scripts/game.gd`, `scripts/enemy.gd`, `scripts/cards.gd`,
`scripts/view3d.gd`, telemetry and tests.  
**Requires:** EL-00 and AB-01.  
**Gates:** G0–G5. Secondary share or Conduct duration may receive one tuning
pass, not both.

Every successful Arc hit sets `conduct_time = 2.50`. Base Arc no longer rolls
the hard-coded 20% stun. Preserve the rare OVERLOAD card by setting base
`mods.stun_chance` to zero and allowing that card's explicit chance to roll;
short-circuit before `rng.randf()` when the chance is zero. Conduct itself never
uses RNG.

Routing rules are exact:

- after Whip's aim-selected first target, each jump first selects the nearest
  unvisited conducted target inside `jump_range`;
- if none exists, it uses the current nearest-unvisited rule;
- equal distance is resolved by `spawn_serial`, never group iteration order;
- the chosen target receives/refreshes Conduct after the hit as usual.

Have the line hit helper return the bodies it actually damaged; existing
callers may ignore the return. Once per Beam tick, if at least one body was
already conducted before that tick, take the lowest-serial such body and find
the nearest **other** live conducted enemy within 180 units. Deal that second
enemy 25% of the tick's snapped damage through `damage_status()` as
`CONDUCT_SHARE`. It cannot chain, crit, apply Arc or happen more than once per
tick. It remains attributed to the Beam slot.

AB-01 still permits only one Arc application per body per channel. Therefore an
Arc Beam's first accepted contact may establish Conduct, while ticks two through
four may share from that existing state without refreshing it. A crit explosion
does not bypass the channel's element guard.

The renderer uses a faint blue-white contact ring plus an occasional short arc
between conducted neighbors. The arc is visual only, bounded to the existing
effect budget and seeded from `visual_rng` if variation is needed.

Required checks cover expiry/refresh, zero base RNG consumption, optional
OVERLOAD RNG, deterministic tie-breaking, conducted-first/fallback Whip route,
one Beam share per eligible later tick after first contact, one Arc application
per body per channel, no recursion, source attribution, no share outside 180,
dead/airborne exclusions and a forced cluster whose kill order changes.

### 17.7 AB-04 — Cleave is a two-beat close combo

**Outcome:** the Captain's fixed arc asks her to remain close through a return
cut rather than repeating one identical fan.  
**Files allowed:** `scripts/game_data.gd`, the class-basic resolver in
`scripts/game.gd`, basic VFX/animation reads, telemetry and tests.  
**Requires:** BASE-00. EL-03 consumes this packet's beat; it is not a
prerequisite.  
**Gates:** G0–G5. Period and two-swing close damage stay fixed.

This is the Captain's authored `auto.kind == arc`, not every cone and not a new
drafted input. Add these fields beside its existing auto row:

```gdscript
"combo_damage": [20.0, 20.0]
"combo_angle": 0.20944 # twelve degrees
"combo_close_range": 110.0
"combo_return_scale": 1.20
```

Add game-owned `basic_swing_serial`, reset it in `begin_run()` and increment it
only after a valid body/hulk target is found and the basic is actually resolving.
Odd swings resolve the first 20-damage arc centered 12 degrees port of
aim. Even swings resolve the return arc 12 degrees starboard; a body whose
center is within 110 ground units receives 24, otherwise 20. Thus two connected
close swings total the shipped 44 base damage, while playing at the edge loses
four. Keep 0.36 period, 190 range, 2.443 arc and 150 knock.

Latch beat/damage for the whole cone. Multi-target distance is evaluated per
body. Hulk splash uses the resolved 20 or 24 once. All elements, crit, basic
telemetry, Overpressure and sound stay in the ordinary path. A miss does not
advance the beat, so animation and next damage never disagree. EL-03 may later
read the even beat as a Kindle consumer; AB-04 must not pre-implement that
reaction.

Expose a read-only `cleave_next_beat()` derived from the successful-swing serial.
Between swings, the Captain's weapon-side pose or compact arc-notch tell shows
which side will enter next; it exists before a target is acquired and uses no
presentation timer. The two attack animations/effects visibly enter from those
opposite sides without changing the simulation arc. Required checks cover
odd/even direction, next-beat read before contact, close and edge totals, misses,
multiple targets, hulk, all four elements, run reset and a clip where the player
stays out for the first cut then commits to the telegraphed return. CUT if
players cannot perceive the next beat without watching numbers.

### 17.8 EL-03 — Ember Kindle gets named consumers

**Outcome:** three existing burn stacks become visible setup that Mortar or an
every-other Cleave can spend.  
**Files allowed:** `scripts/game.gd`, `scripts/enemy.gd`, `scripts/view3d.gd`,
telemetry and tests.  
**Requires:** AB-04 and EL-00. AB-04 must already provide the readable beat and
successful-swing serial.  
**Gates:** G0–G5. One tuning pass may alter burst damage only.

The existing three `burn_stacks` are Kindle. A target is fully kindled at three
and shows one clear hot-core marker; do not add a second stack variable.

Two attack contexts consume it:

1. a hit from shape `RANGED_AOE`, regardless of that Mortar's element;
2. an even-numbered successful class basic whose authored kind is `arc`,
   regardless of the selected basic element.

Read AB-04's `basic_swing_serial`; EL-03 must not create, increment or reset a
second beat clock. The even-swing flag is latched for the entire cone so every
fully kindled body hit by that one Cleave is eligible. Boilerwright's cone basic
is not a Cleave consumer. AB-04's between-swing next-beat tell is the required
player-facing authority; Kindle copy may name `RETURN CUT`, but it may not infer
parity from an animation frame.

After primary damage and its element application, if an eligible target is
alive and now has three stacks, clear burn stacks/time/source first, then deal
15 status damage through `damage_status()` as `KINDLE_BURST`. Thus an Ember
consumer may supply the third stack and immediately spend it. One primary hit
can create at most one burst on a body; the burst cannot rekindle itself.

Required checks cover third-stack visibility, expiry, Mortars of all four
elements, odd/even Cleaves, missed basics not incrementing the sequence,
Boilerwright exclusion, multi-target cones, one burst per target, source
attribution to the consumer, lethal burst and no recursion. A forced fixture
must show the player reading the next-beat tell and deliberately delaying the
return-cut consumer for a fully kindled heavy.

### 17.9 RF-00 — Reforge infrastructure without branch behavior

**Outcome:** waves 4 and 8 can offer a deterministic, mutually exclusive branch
pair without changing hand size or corrupting the normal dealer.  
**Files allowed:** `scripts/game_data.gd`, `scripts/game.gd`,
`scripts/cards.gd` only for shared labels, HUD/card face, run report and tests.  
**Requires:** the relevant shape packet; initially AB-01.  
**Gates:** G0–G4. This packet must not change combat numbers.

`make_skill()` gains `"evolution": StringName()`; skill instances remain the sole
owner. Add a centralized `REFORGES` table keyed by shape, then branch ID. A
branch row contains only presentation and authored behavior parameters:
`name`, `text`, `shape`, and a `values` dictionary. A callable never lives in
data.

An eligible slot is active, has an implemented two-row Reforge table and has no
evolution. Passive shapes stay ineligible until both of their branches have
their own packets. There is no invented upgrade-level threshold: the live game
does not increment `skill.level`, so using it would create a gate no player can
reach.

`open_draft()` first generates the ordinary hand exactly as it does now. Then
`inject_reforge(options)` may replace option indices 0 and 1 when all are true:

- the completed wave is 4 or 8;
- the hand has at least two options and is an upgrade-card hand, not a new-skill
  matrix/hand;
- at least one slot is eligible.

Choose the slot with a local `RandomNumberGenerator` derived from run seed,
completed wave and `REFORGE_SALT := 32452843`. Do not read or advance `rng` or
`visual_rng`:

```gdscript
stream.seed = hash(seed_text) ^ (completed_wave * 2654435761 + REFORGE_SALT)
```

Collect eligible slots in ascending index order and call `randi_range()` once,
even when only one exists. Sort the two stable branch IDs lexically; option zero
receives the first and option one the second. The options use `kind: reforge`,
carry the same slot and include all generic card-face fields. A reroll re-deals
ordinary filler through the shipped path but presents the same slot/pair for
that gate.

`choose_draft()` handles `reforge` directly: revalidate slot, shape and empty
evolution; set the branch ID; append its title to `cards_taken`; then continue
the normal next-wave transition. A stale or malformed option refuses safely
without starting the next wave. Never encode behavior as an `apply` closure
capturing a loop variable.

At Heat 3, a two-card hand contains the two branches and therefore makes
Reforge the whole choice. At lower Heat, remaining positions keep their
ordinary cards. This is intentional: Reforge replaces progression bandwidth;
it does not add a free fifth card.

Add `skill_build_name(skill)` for report/UI use. It returns the current skill
name when unevolved and `NAME [EVOLUTION]` when evolved. Existing short combat
labels may stay unexpanded where containment requires it. `skill_stats()` is
the only place later branch scalar parameters are applied.

Required checks:

- non-gate, new-skill and no-candidate hands remain byte-equivalent;
- eligible gates replace exactly two positions and keep hand size;
- both cards target one slot and are mutually exclusive;
- same seed/gate/build gives the same pair without moving either RNG state;
- reroll preserves the pair while changing only normal filler as before;
- Heat 3 shows exactly both branches;
- malformed/stale choices cannot mutate a different skill or advance play;
- report names the selected branch and run reset removes it with the skill;
- deleting injection makes the gate-presence check fail.

### 17.10 RF-01 — first complete pair: Beam

**Outcome:** the infrastructure proves two Beam play patterns, not two hidden
damage multipliers.  
**Files allowed:** RF-00 files plus AB-01's channel/render files and tests.  
**Requires:** AB-01 and RF-00.  
**Gates:** G0–G5. Tune only after both forced fixtures work.

The pair is exact:

**Cutting Ray**

- lock direction at channel start; later live aim is ignored;
- multiply final width by 0.625, taking an unmodified width from 24 to 15;
- tick zero deals snapped tick damage;
- on tick `n > 0`, a body also hit on tick `n - 1` receives
  `1.0 + 0.20 * n` tick damage; leaving the line resets that body's ramp;
- apply hulk splash at tick damage on each delivered tick and suppress the
  base completion splash, so a full committed cut deals 28 unmodified structure
  damage rather than seven.

**Tracking Coil**

- keep live aim on every tick;
- multiply final range by 0.85 and final width by 1.50;
- each body may receive at most two of the four primary ticks in one channel;
- bodies already at the cap remain visible intersections but receive no damage,
  status or hit telemetry; the player must sweep to find more work;
- hulk/Residue use the ordinary once-on-completion rule.

Evolution multipliers apply after per-skill and global stats are derived, so a
range card still helps both branches and no preview requires reverse arithmetic.
RF-01 extends `active_channel` with `hit_ids_previous_tick` and `hit_counts`,
initialized empty at channel start. Those per-cast rows own Cutting Ray's ramp
and Tracking Coil's cap; enemies do not retain Beam-specific state between
casts. They are not speculative fields in AB-01.

Card preview names channel time, tick count, effective range/width and maximum
unmodified full-lock damage. Cutting Ray copy says direction locks; Tracking
Coil copy says two ticks per target. The renderer visibly narrows or widens the
same simulation line and shows the locked/live aiming rule.

Required checks cover exact four-tick single-target totals, ramp reset,
direction lock, Tracking's two-hit cap across at least three bodies, stat order,
structure rules, per-tick telemetry only on delivered hits, AB-01's one element
application per body/channel under both branches, report naming and two
forced clips: a committed heavy cut and a crowd sweep. If both branches are
played by holding the cursor on the nearest target, CUT the pair and revisit
before authoring another Reforge.

RF-01 is the only implementation-authorized Reforge pair in this document. The
Mortar, Sentry and Field branch names in Section 7 are concept backlog, not
permission to invent mechanics. A later branch needs its own packet, numeric
contract, dependency row and forced A/B fixture after RF-01 passes G5.

### 17.11 AB-05 — Lance carries force down a lineup

**Outcome:** Lance remains immediate precision but gets its best control result
only by lining up several bodies.  
**Files allowed:** `scripts/game.gd`, line VFX, telemetry and tests; shape base
damage/cooldown/range are forbidden.  
**Requires:** BASE-00. AB-01 and AB-04 are merge serialization; this packet
creates the ordered shared line query and does not require Beam or Cleave
behavior.  
**Gates:** G0–G5. No damage tuning is allowed.

Centralize line intersections into a pure ordered query. Return each hittable
body once, sorted by distance projected from line origin and then
`spawn_serial`. Beam may use the same geometry but keeps its own tick rules and
AB-01's optional `element_once` forwarding. Lance always passes null; this
packet may not collapse the query and damage delivery into a helper that loses
that context.

For active shape `LINE_BURST`, damage every intersected body at the unchanged
value. Knock is:

```text
first body:  derived knock
second:      derived knock + 35
third:       derived knock + 70
fourth+:     derived knock + 105 (cap)
```

Order and carry reset for every multi-shot. A missed/immune intersection does
not increment carry. Props and hulk receive their current damage once and never
consume or receive carry. The extra knock goes through the same mass, travel,
stern-give and overboard rules; it is not direct position editing.

Draw one brief pressure collar at each body, increasing toward the far end; the
collar position comes from the ordered hit list. Required checks cover stable
ordering, single-target byte equivalence, four-body exact knock, immunity,
multi-shot reset, mass/rail rules, no damage change, the IN-00 Beam
element-once subset still green, and a forced fixture where the far body crosses
a behavioral boundary only when a lineup was made. CUT if
the effect reads as random launch order in motion.

### 17.12 AB-06 — Gale leaves a directional current

**Outcome:** Gale performs its existing hit, then owns a short piece of ground
that keeps herding bodies in the cast direction.  
**Files allowed:** `scripts/game_data.gd`, `scripts/game.gd`, a small knock
extraction in `scripts/enemy.gd`, `scripts/view3d.gd`, telemetry and tests.  
**Requires:** BASE-00. AB-01, AB-02, AB-03 and EL-00 are merge serialization,
not behavioral prerequisites; this packet creates its own `apply_knock()` seam.  
**Gates:** G0–G5. Primary damage/knock and current duration are frozen; one pass
may tune current impulse only.

Add to `CONE`:

```gdscript
"current_time": 0.90
"current_period": 0.15
"current_knock": 20.0
```

Only an accepted drafted `CONE` active creates a current. The Boilerwright's
automatic Scald and every other arc/cone do not. After all multi-shots resolve,
append one row to game-owned `gusts`:

```gdscript
{
    "origin": Vector2,
    "direction": Vector2,
    "range": float,
    "arc": float,
    "time": 0.90,
    "tick": 0.15,
    "knock": float,
}
```

`skill_stats()` derives the row's knock as
`current_knock * mods.knock_multiplier` at cast. No damage, Fifth Gear,
multi-shot or element multiplier changes it; the one row snapshots that final
value.

Latch origin/direction; it never follows the player. Carry the 0.15 schedule
and deliver exactly six pulses, including the pulse at 0.90 before removal. A
body whose center is in the original cone receives 20 derived knock per pulse,
once per pulse. The current deals zero damage, applies no element/status, rolls
no crit, grants no Pressure/lifesteal and does not touch props/hulk.

Extract the knock-vector portion of `enemy.take_damage()` into one guarded
`apply_knock(origin, amount)` path so a zero-damage current does not fake a hit.
It respects hittable state, mass, cap, anchor, travel, stern and rail rules.
AB-06 adds no unread element/source field and no hero special case. HR-01 may
extend the call with explicit player-control ownership when Tension has a reader.

At most four gust rows may exist. The safety cap evicts the oldest only if
malformed cooldown/multi fixtures exceed what normal play can create. Renderer
draws low directional streamers from the same cone and remaining time, never a
second effect circle or timer.

Required checks cover primary byte equivalence, six carried pulses at three
step sizes, cone boundary, latched geometry, no Scald current, multi-shot once,
zero damage/status/RNG/Pressure, mass/rail behavior, cap/reset and sim/render
identity. G5 requires a player to use the current to keep a group off a crossing;
mere extra travel distance is not enough.

### 17.13 AB-07 — Mortar has an authoritative landing clock

**Outcome:** Mortar commits to a point that enemies may enter or leave before
the shell lands, preserving its damage while making prediction its skill test.  
**Files allowed:** `scripts/game_data.gd`, `scripts/game.gd`,
`scripts/view3d.gd`, HUD/card copy, telemetry and tests.  
**Requires:** AB-02 and EL-00.  
**Gates:** G0–G5. Damage, radius, range and cooldown stay unchanged; one pass may
tune landing time only.

Add `landing_time: 0.32` to `RANGED_AOE`. `game.gd` owns
`pending_shells`, capped at eight live cast rows. An accepted Mortar snapshots:

```gdscript
{
    "origin": Vector2,
    "target": Vector2,
    "time": 0.32,
    "slot": int,
    "context": {"shape": "RANGED_AOE", "element": String},
    "radius": float,
    "knock": float,
    "damage": float,
    "shots": int,
    "residue_dps": float,
}
```

The row must not retain the live skill or full stats dictionary: `cooldown_left`,
cast count and later lifecycle changes make the former mutable authority, while
most stats have no impact reader. Copy the two context strings and listed
scalars at press, derive `residue_dps` then, and omit any extra field until its
impact reader exists.

Clamp target at press. Pay cooldown/Overpressure, increment cast telemetry and
advance Pulse immediately. Do not hit anything yet. Multiple shots share one
row and landing clock. Other skills and movement remain available while it is
in flight.

On the carried timer reaching zero, temporarily restore its slot attribution,
resolve the existing circle once per snapped shot at the fixed point, resolve
hulk splash once with `damage * shots`, create Residue once, relocate Field once
and remove the row. Element/status, crit and target membership are evaluated at
impact through the ordinary funnels. This intentionally changes the time at
which gameplay RNG is consumed but adds no RNG stream; identical input/timing
must still replay exactly.

Pending shells count as combat work for wave-clear for at most 0.32 seconds, so
a draft cannot erase a paid shell. Pause/hit-stop freeze them. Run reset, game
over and title clear them; they never cross waves. If the cap is full, reject a
new Mortar before cast/cost telemetry.

Renderer reads each row's one timer to draw the existing throw arc and a
shrinking non-hostile landing rim. Simulation and rim use the same target,
radius and normalized progress. Sound has one launch and one existing impact
family cue, not a loop.

Required checks cover target clamp, no early hit, exact landing at multiple
steps, bodies entering/leaving, snapshotted scalars, multi-shot, Pulse-at-press,
Field/Residue/hulk-at-impact once, delayed attribution/status/crit, wave-clear
hold, cap refusal, pause/reset and zero visual noise. G5 requires distinct
leading of a moving target; if 0.32 is imperceptible after the one allowed pass,
CUT the warning rather than inflating radius.

### 17.14 EL-04 — Steam Impact converts resisted displacement

**Outcome:** Steam's existing shove gains a payoff when a heavy body resists it
or a lighter body is driven into actual ship structure.  
**Files allowed:** `scripts/game.gd`, `scripts/enemy.gd`,
`scripts/telemetry.gd`, `scripts/view3d.gd`, status copy and tests.  
**Requires:** AB-06 and EL-01 stable.  
**Gates:** G0–G5. One tuning pass may alter Impact damage or radius, not both.

HR-01 must reuse the motion seam created here.

Create one general observation seam for a knock step:

```gdscript
func note_knock_motion(
        enemy: SkyGearEnemy,
        intended_step: Vector2,
        ordinary_step: Vector2,
        before: Vector2,
        after: Vector2,
        structure_clipped: bool) -> void:
```

`enemy.gd` calls it in both its stunned and ordinary movement paths, after
`move_and_slide()`, rein-in and position correction. `intended_step` is the
knock-velocity contribution captured **before** decay, multiplied by that
physics delta. `ordinary_step` is the pre-knock walk contribution for the same
delta and is zero while stunned. Project
`(after - before) - ordinary_step` onto the intended knock direction and clamp
the result to `[0, intended_step.length()]`. This prevents walking along the
shove from printing free control distance. It deliberately treats walk lost to
the same collision as blocked knock rather than trying to replay physics. This
is the one realized/blocked-motion measurement later consumed by Tension—do not
create a second estimator in hero code.

`structure_clipped` is true only when the attempted knock step was shortened by
a real cargo/hull collision or correction identified through the existing ship
collision bodies and shared deck/cargo geometry. It is false for the artificial
lane band, the knock travel cap, `KNOCK_STERN_GIVE`, the end of the physics step
and a side-rail overboard. A collision from ordinary walking is never reported
as knock impact. If the live collision layer cannot distinguish cargo/hull from
other bodies, add one pure classification helper at that layer rather than
guessing from position in `game.gd`.

Extend AB-06's helper with optional final source metadata:

```gdscript
func apply_knock(
        origin: Vector2,
        amount: float,
        source_slot: int = -1,
        source_element: String = "") -> bool:
```

Return whether positive knock was accepted. `take_damage()` passes EL-00's
source slot and its actual element. Gale's zero-damage current calls with the
defaults, so it is explicitly unowned/non-elemental; metadata must never make it
apply a status or record a hit. A positive non-Steam source clears an armed Steam
claim and marks that claim spent for the episode. Later Steam in that same
episode cannot steal it back.

Increment an enemy-owned `knock_episode_serial` only when accepted positive
knock starts from `knock_live == false`; additional hits while that shove remains
live keep the serial. Clear any armed Impact when the episode ends, the target
dies or the run resets. Store `steam_impact_episode`,
`steam_impact_source_slot`, `steam_impact_armed` and
`steam_impact_spent`. These are simulation fields, not renderer state.

After a successful Steam primary hit with accepted positive knock has completed
EL-01 Shatter and the target is still alive, claim and arm the current episode
only when `steam_impact_episode != knock_episode_serial`. Later Steam ticks in
that same episode neither re-arm nor change its source, whether the claim
resolved or was displaced by another source. Resolve one Impact by either of
these mutually exclusive routes:

1. **Resisted heavy:** if `mass >= 2.6`, resolve immediately on that body and
   mark the episode spent. The existing `can_be_hit()` gate still protects
   arrival and the Colossus turn.
2. **Structure collision:** otherwise, the first `structure_clipped == true`
   observation while that Steam episode is armed resolves at the corrected body
   position and marks it spent. Going over the side does not also Impact.

Impact uses named constants `STEAM_IMPACT_DAMAGE := 10.0` and
`STEAM_IMPACT_RADIUS := 65.0`. Snapshot eligible live enemies in the circle,
sort by `spawn_serial`, and call `damage_status()` once per body with the stored
Steam slot and reaction ID `STEAM_IMPACT`. Include the struck body if it remains
alive. The helper supplies existing hittable/death/Pressure/lifesteal behavior;
Impact cannot crit, knock, apply an element, recurse or consume RNG. One compact
burst is emitted at the same center/radius; the renderer receives no clock and
never performs the damage query.

Required checks cover immediate Armored/Boss Impact, boss-turn and arrival
immunity, one Impact across a four-tick Beam shove, a light target hitting real
cargo, no false trigger from lane correction/travel cap/stern give/walking, no
double event on overboard, stable multi-body order, source attribution including
slot four, exact radius boundary, lethal status damage, no recursion/RNG and
motion observation at 1/60, 0.05 and a catch-up step. G5 requires a fixture where
aiming Steam across cargo changes the useful result; if players merely receive
ten automatic damage on every heavy, CUT the heavy route before raising damage.

### 17.15 IN-00 — release-critical combat integration audit

**Outcome:** the combat depth pass is exercised as one system, so a packet that
is fair alone cannot create lockdown, unreadable feedback or false telemetry in
combination.  
**Files allowed:** focused tests, deterministic balance scenarios, poser/probe
fixtures and ignored evidence output only. No gameplay, data, copy or tuning
file may change in this packet.  
**Requires:** AB-01–04, EL-00–03 and RF-01 stable on the `damage attribution v2`
baseline.  
**Gates:** G0–G5. This is a release gate, not another feature.

Build one deterministic pairwise matrix and one all-on scenario. The matrix
must call production cast, damage, status, passive and report paths; directly
setting a reaction counter is not evidence. At minimum it proves:

- Frost Beam applies one stack per body per channel, Roots only on the third
  cast, cannot pre-bank stacks during Root, and under the maximum legal ordinary
  cooldown reduction leaves at least 0.10 seconds unrooted before a Beam-only
  Root can recur;
- Ember Beam cannot fully Kindle a body in one channel, reaches three stacks on
  three casts, and one Mortar or visibly telegraphed return Cleave consumes the
  setup once;
- Arc Beam establishes Conduct on its first accepted contact and may share on
  eligible later ticks without a second Arc application or base-stun RNG;
- a Steam Beam hitting a rooted target Shatters once, not once per tick;
- a Beam press advances Pulse exactly once; normal completion relocates Field
  exactly once to the inherited Ray midpoint; cancellation keeps the paid Pulse
  advance but performs neither relocation nor completion work;
- Cutting Ray and Tracking Coil retain their distinct hit rules while obeying
  the one-element-application guard, including a Beam crit explosion, without
  leaking that guard into a resulting kill explosion;
- The Second Hand still deals a legal keyless fifth passive and both Field and
  Pulse retain one simulation clock each;
- the v2 run report attributes primary, burn, Shatter, Conduct and Kindle damage
  once to the creating/consuming slot, with reaction rows descriptive rather
  than additive.

The all-on G4/G5 fixture is a forced wave 12 using the release-critical Beam,
Field, Pulse, Cleave, element and Reforge systems together. It records a zero
visual noise floor first, then proves hostile Colossus tells, Root/Kindle/Conduct
markers, Beam channel state, Field anchor and Pulse timing remain distinguishable
at normal camera scale. G3 records Root uptime, reaction triggers by ID, damage
by slot and main/visual RNG deltas; the same seed and inputs must replay exactly.

IN-00 never repairs a failure in place. Attribute a failure to the smallest
owning packet, stop, dispatch a separately reviewed correction within that
packet's file boundary, then rerun the entire matrix. The combat release cannot
pass on isolated green gates while IN-00 is red or lacks its human readability
verdict.

## 18. Ship hardpoint and fitting implementation packets

The live save already has the right durable concepts: `fittings` is ownership
and `berths` is installation. Keep both keys and reinterpret the installation
array. A new `hardpoints` save dictionary would create two authorities that can
disagree and is forbidden.

### 18.1 SH-01 — hardpoint model and legacy reconciliation

**Outcome:** at most one functional fitting sails in each of Bow, Waist and
Stern while the Wreck remains a non-competing trophy.  
**Files allowed:** `scripts/fittings.gd`, `scripts/workshop.gd`, the run-snapshot
reader in `scripts/game.gd`, and fitting tests. No HUD or fitting behavior in
this packet.  
**Requires:** BASE-00.  
**Gates:** G0–G2. The bare ship and every single existing fitting retain their
current deck behavior.

**Release guard:** SH-01 is migration infrastructure, not a shippable loadout.
With only live legacy fittings it removes two installed items and leaves Bow and
Waist with no choice. SH-01 and SH-02 may merge for serialized verification, but
no player-facing build may expose the three-functional-slot cap until both
SH-03 and SH-04 pass their gates.

Add the stable constants:

```gdscript
const HARDPOINTS := [&"bow", &"waist", &"stern"]
const TROPHY_RAIL := &"trophy"
const CAP := 3 # compatibility name: functional hardpoints, not raw array size
```

Every `FITTINGS` row receives exactly one `hardpoint` field:

| Fitting | Hardpoint |
|---|---|
| Wreck | trophy |
| Bow Barricade | bow |
| Spare Gun | stern |
| Fourth Vent | waist |
| Winch, still tabled | waist |
| Scupper Grating | stern |

Update the fitting-row allowlist check before adding the reader. Provide one
implementation of each question:

```gdscript
static func hardpoint_of(id: String) -> StringName
static func installed_in(state: Dictionary, point: StringName) -> String
static func functional_ids(state: Dictionary) -> Array[String]
static func trophy_ids(state: Dictionary) -> Array[String]
static func equip(state: Dictionary, id: String) -> bool
static func reconcile_hardpoints(state: Dictionary) -> bool
```

`berthed_ids()` remains the raw saved array for compatibility. `is_berthed()`
continues to answer membership. `functional_ids()` and `installed_in()` are the
only counts/readers for gameplay and UI. `sailing()` returns mounted trophies
first, followed by the valid installed fitting in HARDPOINTS order; it never
uses raw array length as a cap.

Rules for mutation:

- an ID must be known, earned, available and not already installed;
- ordinary `berth()` is strict and refuses when that hardpoint is occupied;
- `equip()` atomically removes the current ID at the same hardpoint and appends
  the requested ID; it never touches another hardpoint or ownership;
- `unberth()` refuses the Wreck trophy but remains free for functional fittings;
- `award_in()` mounts the Wreck and auto-berths a newly earned functional item
  only if its hardpoint is empty; otherwise the item is earned and waits;
- tabled Winch remains owned but never installed or returned by `sailing()`.

`SkyGearWorkshop.load_state()` calls the existing tabled reconciliation, then
`reconcile_hardpoints()`. The hardpoint migration is exact and idempotent:

1. ensure `fittings` is a dictionary and `berths` is an array;
2. walk the legacy `berths` in its existing order;
3. drop unknown, unearned, duplicate and tabled IDs from installation only;
4. keep the first valid functional ID encountered for each hardpoint and leave
   later conflicts earned but uninstalled;
5. if the Wreck is earned, place it once at the start of the array; this mounts
   a trophy a legacy player had manually un-berthed because trophies no longer
   consume a choice;
6. append retained functional IDs in their original relative order;
7. report true only if the resulting array differs.

For the common legacy full set
`[wreck, bow_barricade, spare_gun, fourth_vent, scupper_grating]`, the result is
`[wreck, bow_barricade, spare_gun, fourth_vent]`: Scupper remains earned and can
replace Spare Gun later. The Workshop owns persistence; `fittings.gd` never
writes disk.

Required checks:

- all rows name one valid point and no forbidden stat field;
- one fitting per functional point, trophy excluded from the count;
- strict berth refusal and atomic same-point swap;
- no cross-point removal during equip/unberth;
- award auto-install only into an empty point;
- full, conflicting, duplicate, tabled, unknown and pre-berth saves reconcile
  to the declared output without losing any known ownership;
- running reconciliation twice yields identical JSON and false on the second;
- `sailing()` is stable in trophy/Bow/Waist/Stern order and empty before unlock;
- old single-fitting fixtures produce byte-equivalent deck identity and consume
  neither RNG stream;
- a bare run's props, walls, turrets, verbs and report remain byte-equivalent.

### 18.2 SH-02 — hardpoint screen, save feedback and title snapshot

**Outcome:** a player can understand and swap one candidate per physical point,
and every click immediately agrees with the next run snapshot.  
**Files allowed:** `scripts/hud.gd`, `scripts/game.gd` title/refit handlers,
`scripts/screen_poser.gd`, copy and tests.  
**Requires:** SH-01.  
**Gates:** G0, G1, G2 and the full text/containment audit.

The SH-01 release guard applies to this screen. A development branch may expose
it to poser/tests, but a published build must include SH-03 and SH-04 so every
Bow, Waist and Stern column contains at least one real swap.

Keep `berths_open` and existing input routes as internal compatibility names;
the player-facing title becomes **THE HARDPOINTS**. The title menu plate reads
`THE HARDPOINTS · n OF 3`, where `n` comes from `functional_ids()`, never raw
`berths.size()`.

The page has four regions:

1. a full-width Trophy Rail showing the Wreck as locked or mounted, with no
   remove affordance;
2. three equal Bow, Waist and Stern columns;
3. one installed socket at the head of each column;
4. every fitting for that point listed below as installed, ready, locked or
   tabled with its existing earn rule and behavior sentence.

Clicking a ready candidate calls `equip()`, so a direct click swaps its rival.
Clicking the installed candidate calls `unberth()` and leaves the point empty.
Locked/tabled/trophy rows focus for explanation but do not mutate. Keyboard and
controller traversal order is Trophy, then Bow top-to-bottom, Waist, Stern,
then Back; mouse hit boxes use the same generated list.

After a successful mutation the existing handler must:

1. save Workshop state once;
2. call `refresh_berthed()` so the title's ship backdrop reflects the selection;
3. show `INSTALLED AT WAIST`, `WAIST CLEARED` or the matching point;
4. leave an earned item visible when its point is occupied.

If persistence reports failure, retain the in-memory selection for the current
session but show `COULD NOT SAVE REFIT`; do not falsely say installed for next
run. Results copy changes from “berths full” to
`earned; STERN occupied by SPARE GUN`, derived from `installed_in()`.

Replace the existing fullest poser fixture with: mounted Wreck; Bow Barricade
installed; Fourth Vent installed with Powder Locker ready once SH-03 exists;
Spare Gun installed with Scupper ready; one locked; Winch tabled. The page and
its shared foot-strip calculation must pass at exactly the poser sizes
1280×720, 1600×900, 1920×1080 and 2560×1080. No label may fall below the
established point-size floor.

Required checks cover click and keyboard swaps, empty point, locked/tabled
refusal, save/refresh calls exactly once, title count, results reason, focus
reachability, hover copy and containment at all four sizes. Deleting `equip()`
from the click path must make the swap check fail.

### 18.3 SH-03 — Powder Locker, the first rival fitting

**Outcome:** the Waist offers authored burst potential whose placement is also
a liability.  
**Files allowed:** `scripts/fittings.gd`, the fitting-prop portion of
`scripts/game.gd`, existing prop presentation, fitting tests and a forced clip.  
**Requires:** SH-02.  
**Gates:** G0–G5. Keg damage, radius and player damage remain the shipped keg
values.

Add this functional row after the existing awardable fittings:

```gdscript
"powder_locker": {
    "name": "POWDER LOCKER",
    "text": "two chained kegs in the starboard waist — a broadside waiting for either side to light it",
    "earn": "win at Heat 2 or above",
    "hardpoint": &"waist",
    "props": [
        {"type": "keg", "position": Vector2(410.0, 15.0)},
        {"type": "keg", "position": Vector2(550.0, 15.0)},
    ],
}
```

Its award rule uses only fields the run row already records:
`won and heat >= 2`. Existing table order and one-award-per-run behavior remain
unchanged.

The two authored centers are 140 units apart, intentionally inside the 175-unit
keg blast and below `KEG_SPACING`; either keg therefore chains the other. This
is the fitting's rule, not a global reduction in spacing. They are ordinary
targetable keg props, re-stow every wave and use the shipped explosion, damage,
crit, player-danger, telemetry and sound paths.

When fitting geometry is spawned, append every fitting keg position to the
local `keg_spots` list before the Powder Store talent places random extra kegs.
Talent kegs must remain at least `KEG_SPACING` from **both** locker kegs and all
base kegs. The authored pair consumes neither RNG stream and does not move when
the talent is present.

Required checks cover exact positions, one deliberate 140-unit pair, safe deck
and cargo bounds, one explosion chaining the other, two possible player hits,
restow each wave, absence on a bare/other-Waist ship, no RNG movement, and
talent-keg clearance over fixed seeds. G5 compares empty Waist, Fourth Vent and
Powder Locker; a tester must describe when they avoided firing their own rack.

### 18.4 SH-04 — Signal Crane reads the live next drop

**Outcome:** Bow can trade the Barricade's cover for persistent advance lane
information throughout a live queue.  
**Files allowed:** `scripts/fittings.gd`, `scripts/game.gd`,
`scripts/view3d.gd`, HUD/coach copy, tests and a clip.  
**Requires:** SH-02 and EV-05. EV-06 is independent and must not gate this
fitting.  
**Gates:** G0–G5. No queue, plan or arrival timing may change.

Add a Bow row named `signal_crane`, earned by a Heat 3+ win. It needs only the
normal text/earn/hardpoint fields; behavior is gated by `fitted()` so no
presentation-only flag enters the data table.

Add a pure query:

```gdscript
func signal_lanes() -> Array[int]:
```

It returns empty unless Signal Crane is in the frozen run snapshot, the current
run is in a PLAY wave and the remaining `spawn_queue` is non-empty. It never
reads `breathing_room()`. Find the earliest queued `time`, collect every distinct
lane at that same time within 0.001, sort ascending and return it. Never pop,
reorder or copy data back into the queue. Boss/no-more-arrival returns empty.
Event and push waves are not special-cased: the live queue is authority.

The renderer assembles a small jib and hanging signal from existing procedural
beam/rope materials at the bow; no imported asset is required. During a valid
read it points toward the returned lane set and the HUD says, for example,
`NEXT DROP · PORT + STARBOARD`. The drawn line uses the same lane-center query
as arrivals. Manifest describes a future wave plan; Signal Crane describes the
next live drop, so neither replaces the other.

Required checks cover fitted/bare, availability during active combat and during
an EV-06 false state, simultaneous lanes, sorted/deduplicated output, empty
queue, event/push, no queue or RNG mutation, renderer/query identity and a forced
clip where advance information changes the lane the player prepares. G3 must
show the query returns a non-empty answer on at least 80% of sampled non-boss
wave time while a future drop remains queued; otherwise the fitting is still a
trap pick. Any `breathing_room()` read or duplicate arrival scheduler is an
automatic rejection.

### 18.5 SH-05 — Firebreak Grating is build-dependent safety

**Outcome:** Waist can suppress persistent fire in a valuable crossing, helping
some ships while erasing damage from Ember/Residue/Bleed Jet builds.  
**Files allowed:** `scripts/fittings.gd`, `scripts/game.gd`,
`scripts/view3d.gd`, tests and a clip.  
**Requires:** SH-02 and EL-00.  
**Gates:** G0–G5. No fire damage number changes.

Add `firebreak_grating` at Waist with an authored
`firebreak: Rect2(-190.0, -75.0, 380.0, 150.0)` row. Extend the fitting allowlist
and add `firebreaks(ids)` as the sole data reader. Earn it with a Captain win at
Heat 2+ using existing `class_id`, `won` and `heat` fields.

All persistent fire fields, friendly or hostile, ask
`inside_firebreak(position)` at creation. A center inside any fitted rect is
refused. The update loop also removes a live field whose center is inside, as a
defense against restoration/legacy fixtures. Immediate Ember hits, burn status,
keg blasts and non-persistent visual fire are unaffected.

The 3D grate and its cool vapor occupy exactly that rect and read no timer. It
provides no wall or cover. Its cost is the Waist slot plus erased player fire;
do not add a compensating damage or resistance stat.

Required checks cover all creation sources, both ownership sides, boundary
points, no effect outside/bare, Residue and Bleed Jet loss, no RNG mutation and
a G5 comparison with a fire-heavy and fire-light build. If it is still always
correct against Powder/Fourth Vent, CUT rather than add an invisible penalty.

### 18.6 SH-06 — Emergency Main is one stern commitment

**Outcome:** Stern gains a once-per-wave deckwork action that can reclaim the
middle approach while temporarily obstructing the captain's Boiler route.  
**Files allowed:** `scripts/fittings.gd`, `scripts/deckwork.gd`,
`scripts/game.gd`, `scripts/view3d.gd`, HUD prompt, tests and a clip.  
**Requires:** SH-02 and EL-00.  
**Gates:** G0–G5. One tuning pass may change duration or tick damage, not both.

Add `emergency_main` at Stern, earned by a Heat 4+ win. Add one always-authored
deckwork row gated by `fitting: emergency_main`:

```gdscript
{
    "id": "open_emergency_main",
    "verb": "CRACK THE EMERGENCY MAIN",
    "at": "emergency_main",
    "reach": 96.0,
    "seconds": 0.80,
    "fitting": "emergency_main",
    "blocked": "boarders are on it",
}
```

`emergency_main_target()` returns a fixed target at `Vector2(0.0, 680.0)` only
when fitted and unused this wave. Existing held-deckwork interruption and
contested rules apply; do not create another interaction channel. Completion
sets `emergency_main_used = true`, `emergency_main_left = 3.0` and a carried
0.25-second tick clock. Both reset appropriately: used resets at `start_wave`,
active state clears on every wave/run/end transition. Initialize the first tick
to 0.25 rather than firing immediately, yielding exactly twelve ticks in three
seconds.

On each tick, every hittable enemy inside
`Rect2(-100.0, 220.0, 200.0, 580.0)` receives 2 Steam damage and 35 knock from
an origin astern of it. Install `src_slot = -2` around the pass so the existing
deck bucket owns damage and any Steam reaction. Each enemy is hit at most once
per tick. The effect may crit under the shipped broad-crit rule; the schedule,
not the crit result, is deterministic.

While active, `correct_player_position()` additionally clamps against
`Rect2(-90.0, 585.0, 180.0, 180.0)`. Enemy pathing never reads this wall. The
renderer draws the valve, Steam strip and obstruction from those exact constants
and `emergency_main_left`; it owns no countdown.

Required checks cover held completion/interrupt, contesting, once per wave,
reset/clear transitions, 12 carried ticks at three step sizes, rect boundaries,
one hit per enemy/tick, deck attribution with no hero gauge/lifesteal, Steam
reactions, player-only wall,
renderer identity, bare ship and a clip proving the obstruction makes timing
matter. If activation is a free panic button or self-traps without an escape,
CUT after the one allowed duration/damage pass.

### 18.7 SH-07 — presets only after the choices exist

**Outcome:** three validated loadouts can be saved and restored without
silently substituting unavailable content.  
**Files allowed:** `scripts/workshop.gd`, `scripts/hud.gd`, title/refit handlers
in `scripts/game.gd`, `scripts/screen_poser.gd` and focused save/UI tests.  
**Requires:** SH-03, SH-04, SH-05 and SH-06 all passing G5.  
**Gates:** G0–G2 and the full text/containment audit.

Do not implement presets while any hardpoint has fewer than two available
functional candidates. Once SH-03–SH-06 pass G5, add exactly three Workshop
slots. Their display names are the derived copy `LOADOUT I`, `LOADOUT II` and
`LOADOUT III`; this packet adds no free-text entry. A filled slot has exactly
this save shape:

```json
{
  "version": 1,
  "class_id": "captain",
  "heat": 2,
  "fittings": {"bow": "bow_barricade", "waist": "", "stern": "spare_gun"}
}
```

The array index owns the name. A row never stores seed, skills, cards, Articles,
run resources, trophy state or a copy of fitting data. `fittings` in this row is
a configuration snapshot, not the live Workshop ownership dictionary.

Each slot exposes **SAVE CURRENT**, **APPLY** and **CLEAR**. Saving captures the
current class, Heat and `installed_in()` for the three functional points; it
overwrites only after the existing confirm input. Clear writes an empty
dictionary. Normalize a legacy missing/short/malformed
`presets` array into exactly three dictionary slots without touching the live
configuration.

Applying first builds a validation result without mutation. An unknown or
unreleased class, or Heat above the current unlock, refuses the whole apply.
Unknown, unowned or tabled fittings leave only their named point empty and are
reported; a fitting saved under the wrong point is treated as unavailable, never
moved to its authored point. The preset row itself remains unchanged so later
ownership can make it usable. A valid/partial apply calls the existing
class/Heat setters and `equip()` path, then saves once and refreshes once; it
never substitutes a rival. Compatible Articles continue to derive from
ownership after the selected class changes.

Required checks cover round-trip, stable ordering, stale and tabled IDs,
unowned/locked content, partial load, setters and save/refresh exactly once,
legacy default, no substitution, keyboard/mouse focus and all four poser sizes.

## 19. Watch and wave implementation packets

Wave work starts only after Muster and elite metrics exist. A wave packet edits
authored rosters; it does not also tune enemy stats, tempo, Heat or the bot.
Threat below uses EV-01's normalized costs after expanding `all`.

### 19.1 LV-01 — communicate the three Watches

**Outcome:** the player can name where they are in the run and what that band is
teaching without adding another gameplay state.  
**Files allowed:** `scripts/game.gd` pure reads, event/wave HUD and voice copy,
`scripts/screen_poser.gd`, tests.  
**Requires:** EV-02.  
**Gates:** G0, G1, G5 and text/containment audit.

Add pure derived reads:

```gdscript
static func watch_for(wave_number: int) -> StringName
static func watch_name(wave_number: int) -> String
```

Mapping is 1–4 `first`, 5–8 `black`, 9–11 `last`, 12 `colossus`; all other
inputs return empty. The wave-start banner's information order is
`FIRST WATCH · WAVE 3`, followed by event or live plan line. Draft screens after
waves 4 and 8 say `BLACK WATCH AHEAD` and `LAST WATCH AHEAD`; they do not change
the next wave or insert an extra pause.

At wave 12, `THE COLOSSUS · WAVE 12` outranks “watch” copy. Existing event names
remain the authority: Watch copy wraps GRAPPLE RUN/BOILER BLACKOUT and never
renames them. Manifest/Signal facts remain derived from their live sources.

Required checks cover every integer boundary, invalid inputs, event composition,
next-Watch draft copy, existing title/draft input, and longest lines at all four
poser sizes. A one-run playtest passes only if the player can identify the four
bands in order without being prompted by the tester.

### 19.2 LV-02 — Black Watch first-pass rosters, waves 5–7

**Outcome:** wave 5 introduces an anchor, wave 6 demands outer-lane travel and
wave 7 makes a protected firing line; wave 8 remains the authored Blackout.  
**Files allowed:** `scripts/game_data.gd`, wave-plan tests, balance fixtures and
the design measurement record.  
**Requires:** EV-03 and EV-04 passing G3/G5.  
**Gates:** G0–G3 and G5. First pass may tune batch times only.

Replace only WAVES rows 5–7 with these initial authored batches:

```gdscript
# wave 5 · SIEGE LESSON · threat 14.05 (old 14.75, -4.7%)
[
    [0.0, "ARMORED", 1, 1],
    [2.0, "SCRAPPER", 2, 1],
    [5.0, "SWARM", 4, 0], [5.0, "SWARM", 4, 2],
    [8.0, "GUNNER", 1, 1],
    [11.0, "SCRAPPER", 2, 0], [11.0, "SCRAPPER", 2, 2],
]

# wave 6 · PINCER · threat 24.75 (old 24.75)
[
    [0.0, "SCRAPPER", 4, 0], [0.0, "SCRAPPER", 4, 2],
    [3.0, "GUNNER", 2, 0], [3.0, "GUNNER", 2, 2],
    [6.0, "ARMORED", 1, 0], [6.0, "ARMORED", 1, 2],
    [10.0, "SWARM", 5, 1],
    [14.0, "SCRAPPER", 2, 1],
]

# wave 7 · SCREEN AND RELIEF · threat 26.85 (old 26.80, +0.2%)
[
    [0.0, "SWARM", 8, 1],
    [2.0, "SCRAPPER", 4, 1],
    [5.0, "GUNNER", 3, 1],
    [8.0, "ARMORED", 1, 1],
    [10.0, "SCRAPPER", 3, 0], [10.0, "SCRAPPER", 3, 2],
    [14.0, "SWARM", 9, 0], [14.0, "SWARM", 9, 2],
]
```

Do not mark these as events or bypass Muster. The authored plan is the flat
baseline and the same ten-percent mutation ceiling applies. EV-03 forbids a
Quartermaster promotion on wave 7 because its authored grammar is `SCREEN`;
Sparking may never be stacked into the same plan merely to make the lesson
louder.

Required checks and measurement protocol:

1. record flat-Muster A/B on at least the balance tool's declared minimum sample
   for quotable held-rate results;
2. compare held rate with the repository's Wilson agreement helper, not raw
   percentages from six runs;
3. record per-wave damage taken, clear time and lane travel for waves 5–7;
4. force each legal grammar/elite arm separately;
5. if overall difficulty disagrees, move one batch time by at most two seconds,
   rerun the whole sample and do not alter counts/types in the same pass.

G3 requires wave 5 to increase time spent contesting the center, wave 6 to
increase outer-lane travel and wave 7's protected Gunner fixture to change
first-or-second kill order without an elite aura. If the intended statistic
does not move, revert the row rather than adding bodies.

### 19.3 LV-03 — Last Watch first-pass rosters, waves 9–11

**Outcome:** the last three ordinary waves create simultaneous obligations,
then rotating lane alarms, then overlapping sequential collapses.  
**Files allowed:** LV-02's list.  
**Requires:** LV-02 verdict.  
**Gates:** G0–G3 and G5. First pass may tune batch times only.

Initial authored batches:

```gdscript
# wave 9 · OUTER TRIAGE · threat 30.80 (old 30.80)
[
    [0.0, "ARMORED", 1, 0], [0.0, "ARMORED", 1, 2],
    [1.0, "GUNNER", 2, 0], [1.0, "GUNNER", 2, 2],
    [5.0, "SWARM", 8, 1],
    [8.0, "SCRAPPER", 4, 0], [8.0, "SCRAPPER", 4, 2],
    [12.0, "SWARM", 10, 0], [12.0, "SWARM", 10, 2],
]

# wave 10 · ROTATING ALARMS · threat 41.55 (old 41.55)
[
    [0.0, "ARMORED", 1, 0], [1.0, "GUNNER", 3, 0],
    [5.0, "ARMORED", 1, 2], [6.0, "GUNNER", 3, 2],
    [10.0, "ARMORED", 1, 1], [11.0, "GUNNER", 3, 1],
    [14.0, "SCRAPPER", 4, "all"],
    [19.0, "SWARM", 6, "all"],
]

# wave 11 · OVERLAPPING COLLAPSE · threat 61.95 (old 61.95)
[
    [0.0, "SWARM", 7, 0], [2.0, "SCRAPPER", 4, 0],
    [5.0, "ARMORED", 2, 0], [7.0, "GUNNER", 3, 0],
    [8.0, "SWARM", 7, 2], [10.0, "SCRAPPER", 4, 2],
    [13.0, "ARMORED", 2, 2], [15.0, "GUNNER", 3, 2],
    [16.0, "SWARM", 7, 1], [18.0, "SCRAPPER", 4, 1],
    [21.0, "ARMORED", 2, 1], [23.0, "GUNNER", 3, 1],
    [27.0, "SWARM", 7, "all"],
]
```

Heat 4 turns wave 10 into a push through the existing single authority. It
therefore remains authored/no-Muster at that Heat and must be measured both at
Heat 0 and Heat 4. No packet adds a second hulk rule.

Required checks use LV-02's protocol plus asset-loss outcome: record which turret, crew group or
Boiler is first put at risk. G3 requires at least two such outcome categories
across the fixed seed set, wave 10 lane travel in the authored port→starboard→
center order, and wave 11 overlap (the previous heavy still alive when the next
lane opens) in a majority of forced baseline runs. A time adjustment may move
one lane block by at most two seconds. Counts remain frozen for the first pass.

### 19.4 LV-04 — Colossus-supporting filler

**Outcome:** filler creates brief target switches without becoming the visual or
damage center of wave 12.  
**Files allowed:** `scripts/game_data.gd`, boss probe/fixture, wave tests and one
boss clip.  
**Requires:** LV-03 and the existing Colossus contract.  
**Gates:** G0–G5. The Colossus row and stats are forbidden in this packet.

Replace wave 12's two filler batches with:

```gdscript
[
    [0.0, "BOSS", 1, 1],
    [8.0, "SWARM", 3, 0], [8.0, "SWARM", 3, 2],
    [22.0, "SCRAPPER", 2, 0], [22.0, "SCRAPPER", 2, 2],
]
```

Filler threat falls from 13.20 to 6.10 on purpose. There are no center-lane
fillers, Gunners, Armored, elites, Muster mutation, boarding hulk or boss
arrival hull. Filler bodies keep their ordinary airborne/drop-ring window while
wave 12 retains its current no-arrival-hull selection.

Required checks use the boss probe to record Colossus clear time, connected attacks, boss/filler
damage taken by source and turn/stomp visibility. Pass only if filler causes at
least one target switch in the forced clip, accounts for no more than 30% of
enemy damage taken in the fixed sample, and never covers the stomp/turn read in
the visual audit. One tuning pass may move filler times or counts, not both;
Boss health/damage is out of scope.

## 20. Rigger implementation packets and hero backlog

The Rigger is a prototype until HR-03 passes. Do not commission a unique model,
animations or voice before then. A temporary model row and procedural rope are
required so the prototype is visible and the all-classes renderer check remains
honest.

### 20.1 HR-00 — replace the binary gauge assumption

**Outcome:** existing Captain and Boilerwright behavior is selected by explicit
gauge mode, leaving a safe third mode without adding the Rigger yet.  
**Files allowed:** `scripts/game_data.gd`, `scripts/game.gd`, gauge HUD/coach
readers and class tests.  
**Requires:** BASE-00. IN-00, SH-04 and LV-04 are the Section 14 schedule/merge
serialization for this collision-heavy file, not mechanical prerequisites for
introducing an explicit gauge mode.  
**Gates:** G0–G2. Every existing hero seed fixture must remain byte-equivalent.

Add `gauge_mode: &"pressure"` to Captain and `gauge_mode: &"head"` to
Boilerwright. Add:

```gdscript
func gauge_mode() -> StringName
func gauge_is_pressure() -> bool
func gauge_is_head() -> bool
func gauge_is_tension() -> bool
```

Keep `gauge_is_banked()` temporarily as a compatibility alias for
`gauge_is_head()`, but migrate production decisions to the positive query that
owns them:

- close damage/kill fill, idle fill, decay and automatic vent are pressure;
- ground fill, Boiler cost, Overpressure, Tap Main, Blowdown and Bleed Jet are
  head;
- generic gauge display and reset remain generic;
- a mode not named in a branch does nothing rather than falling into Head.

Do not rename the live `pressure` field in this packet. A sweeping rename would
mix mechanical work with plumbing and add no player value. Do not change card
eligibility yet; HR-03 handles the third-mode audit once it exists.

Checks must compare Captain and Boilerwright before/after snapshots for body,
draft, gauge fill/decay, F/V, dash/jet, damage multiplier, report and RNG state.
Also force a synthetic unknown mode and prove it gains no Pressure, fills no
Head, spends no Overpressure and triggers no automatic vent. Deleting a mode
guard must make a named existing-hero check fail.

### 20.2 HR-01 — primitive body, Harpoon and Tension slice

**Outcome:** a hidden prototype can fight a normal run and earn a gauge from
measured displacement, with no F/V abilities yet.  
**Files allowed:** `scripts/game_data.gd`, `scripts/game.gd`,
`scripts/enemy.gd`, `scripts/player.gd`, `scripts/telemetry.gd`, primitive
`scripts/view3d.gd` model/effect rows, gauge HUD, bot only for a dedicated
fixture, and tests.  
**Requires:** HR-00 and EL-04.  
**Gates:** G0–G5. Tune Harpoon knock or Tension-per-unit once, not both.

Add an unreleased Rigger row with exact initial values:

```gdscript
"rigger": {
    "name": "THE RIGGER",
    "blurb": "Builds Tension by moving threats, then spends it to choose where they stay.",
    "released": false,
    "hp": 110.0,
    "speed": 240.0,
    "dashes": 1,
    "gauge": "TENSION",
    "gauge_mode": &"tension",
    "auto": {
        "kind": "line_first",
        "name": "Harpoon",
        "range": 270.0,
        "width": 18.0,
        "damage": 18.0,
        "period": 0.52,
        "element": "STEAM",
        "knock": 420.0,
        "sound": "player/shape_lance.ogg",
    },
    "tension": {
        "per_moved_unit": 0.10,
        "per_blocked_unit": 0.05,
        "overboard": 18.0,
        "grace": 1.50,
        "decay": 6.0,
    },
    "shape_bias": {
        "LINE_BURST": 3.0, "CHAIN": 2.5, "CONE": 2.0, "RAY": 2.0,
        "RANGED_AOE": 1.0, "SENTRY": 1.0, "AURA": 0.75, "PULSE": 0.75,
    },
}
```

Do not add a `starting` row: the live opening hand reads the shared
`STARTING_SKILLS`, not the existing class-local dead field. The Rigger keeps the
complete shared matrix.

Add `class_ids(include_unreleased := false)` and make title/compare cycling read
it. Preserve `CLASSES` insertion order and treat a missing `released` field as
true, so the two existing rows need no data churn. Tests and prototype tools may
explicitly include or directly select the unreleased row; ordinary players
cannot. Add a temporary `HERO_MODELS.rigger`
row reusing a compatible existing skeleton/mesh with a distinct rope tool and
palette. No class in `CLASSES` may lack a model row even while hidden.

Extend the basic resolver with `line_first`: find all hittable bodies
intersecting the segment, choose the one nearest the origin with `spawn_serial`
as tie-break, and damage only it. If no body is present but the hulk is in the
existing splash band, Harpoon still attacks the hulk. It uses the normal basic
element selection, damage/crit/basic attribution, cooldown, effect and report
paths. Do not introduce a drafted shape or a second line intersection formula.

Tension comes from **realized control movement**, not requested knock. Reuse
EL-04's `note_knock_motion()` inputs and projection; adding a Rigger-only
pre/post displacement estimator is a packet failure:

1. extend EL-04's `apply_knock()` after `source_element` with one optional final
   `control_owner: StringName = StringName()` value;
   ordinary Rigger damage with positive knock passes Rigger ownership when
   `src_slot >= -1`, and a Rigger-cast Gale current passes the same ownership
   despite dealing zero damage;
2. deck/allied/unowned knock passes an empty owner and replaces prior ownership
   only when it supplies positive knock;
3. EL-04's `note_knock_motion()` supplies `moved`; set `blocked` to the remaining
   intended distance only when its `structure_clipped` input is true, otherwise
   zero—lane correction, travel cap, stern give and frame end never print blocked
   credit;
4. call one `note_control_motion(moved, blocked)` only while the current episode
   is Rigger-owned;
5. clear ownership when the knock ends, target dies or another source takes it.

Gain `moved * 0.10 + blocked * 0.05`, capped at 100. An overboard kill whose
last live control owner is the Rigger adds 18 once through the existing death
path. Gain refreshes a 1.5-second grace; after it expires Tension decays six per
second. It never auto-vents, fills from ordinary damage, grants Overpressure,
spends on a normal cast or inherits Head's ground fill. Pause/hit-stop freeze
grace/decay.

Telemetry gains a `control` row with moved units, blocked units, overboards,
Tension gained and later Tension spent. These describe the mechanic and do not
enter damage totals. The run report prints the row only for non-zero control.

HR-01 is the highest class-collapse risk, not HR-02. At 240 speed and one dash,
this body can read as a slightly slower Captain until Haul exists. Do not let the
future spend rescue this packet's verdict. Its forced comparison uses the same
seed, wave and draft for Captain and Rigger and records travel, dash uptime,
basic target geometry and Tension earned from cross-deck versus down-lane aim.
Before HR-02 begins, testers must describe Harpoon's displacement-aiming loop as
the reason the prototype differs; “Captain with less mobility” is a stop verdict.

Required checks cover body/dash, hidden selection, first-body line tie-break,
hulk fallback, actual versus requested motion, collision versus artificial clamp, source
ownership replacement, Armored mass, overboard once, grace/decay at several
step sizes, no Head/Pressure leakage, telemetry and a primitive clip. G5 passes
only if a tester can fill materially faster by aiming across the deck rather
than straight down a lane and can name that control loop without being shown
Haul.

### 20.3 HR-02 — Make Fast and Haul control loop

**Outcome:** Tension has a positional spend and the Rigger can hold one threat,
move it, or move himself to authored ship geometry.  
**Files allowed:** HR-01 files plus class input, fixed-prop queries and focused
control clips/tests.  
**Requires:** HR-01 verdict and SH-02.  
**Gates:** G0–G5. Tune Haul cost or ordinary pull distance once, not both.

First replace the hard-coded F/V chain with:

```gdscript
func use_class_primary() -> bool
func use_class_secondary() -> bool
```

Captain returns false so keyed Articles retain F/V. Boilerwright delegates to
the existing Tap Main/Blowdown functions. Rigger delegates to Make Fast/Haul.
Input still tries the class action before an Article. Existing
`captain_only` Article filtering remains authoritative. All class actions reject
outside PLAY and while an AB-01 channel is active.

Add these exact Rigger values:

```gdscript
"make_fast": {
    "range": 480.0, "aim_radius": 70.0, "cooldown": 6.0,
    "ordinary_time": 3.0, "armored_time": 1.5, "boss_time": 0.9,
}
"haul": {
    "cost": 30.0, "cooldown": 0.60,
    "ordinary_distance": 220.0, "armored_distance": 85.0,
    "anchor_range": 520.0, "anchor_aim_radius": 120.0,
    "anchor_stop": 52.0, "travel_time": 0.18,
    "exposed_time": 2.0, "exposed_scale": 1.15,
}
```

#### Make Fast

F selects the nearest hittable body within 70 units of the live aim point, then
refuses if that body is more than 480 from the Rigger. There is no fallback to
nearest-to-player; a missed harpoon is a missed selection and starts no
cooldown.

Store one weak target reference, its cast position as `made_fast_anchor` and one
simulation timer. Recasting later releases any prior target. An ordinary or
Armored target retains its AI and attacks normally, may move sideways and may
be shoved bow-ward, but after movement its y position cannot advance stern-ward
past the anchor. It is a forward limit, not stun, root or teleport. Update the
anchor only after a successful Haul.

The Colossus becomes the target for 0.9 seconds but ignores the forward limit.
Instead Make Fast gives it the same two-second Exposed state described below.
Airborne, turning, dead and overboard bodies cannot be selected because the
existing hittable query refuses them. Wave/end/reset/death clears the weak
reference and timer.

#### Haul a target

V first uses the live made-fast target, regardless of current cursor. It refuses
without 30 Tension or during its 0.60 cooldown. After a valid destination is
known, spend 30 and record telemetry once.

Pull toward the Rigger by 220 units for an ordinary body, 85 for Armored and
zero for Boss. One `control_displace()` function returns actual and blocked
distance after deck, cargo, lane-relaxation, stern-give and rail rules. It may
put a light body over a side rail through the existing overboard death path; it
may never drag a body more than the existing 60-unit stern give toward the
Boiler. Feed actual/blocked distance into the HR-01 Tension/telemetry path, then
set the tether anchor to the surviving target's new position.

If a target realizes less than half its requested motion, set
`rigger_exposed_time = 2.0`; Boss always receives it. While Exposed, damage
owned by the Rigger (`src_slot >= -1`, including his attributed status damage)
is multiplied by 1.15. Deck and allies get no bonus. Exposed refreshes but never
stacks and uses simulation delta.

#### Haul the Rigger

With no live tether, V searches deterministic anchor candidates: live fixed
props of the existing types `mast`, `rope` or `crates`, plus corners exposed by fitted
player-only walls. Exclude dead/movable props and anything farther than 520.
Choose a candidate within 120 of the aim point by aim distance, then coordinate
order. If none exists, refuse without cost/cooldown.

Stop 52 units short on the player-facing side. Add `player.pull_to(point, 0.18)`
as a distinct movement state: it uses ordinary collision/correction, grants no
invulnerability, emits no dash signal, increments no dash serial, triggers no
dash impact/Keel Hauling and spends no dash charge. Player input cannot steer it.
Collision may shorten it and gives no refund. Renderer and cloak may read the
pull state for motion but never advance it.

#### Readability and checks

Draw one rope from the exact anchor through the target; color drains with the
simulation timer. Exposed uses a small open-knot marker, not an enemy elite or
Frost icon. HUD shows `F MAKE FAST`, `V HAUL · 30`, current target name and
cooldowns from live state.

Required checks cover deliberate selection/miss, single target, all three
durations, forward-only constraint, attacks/knock while tethered, boss behavior,
target pull distances, stern cap, side overboard, anchor refresh, actual/blocked
Tension, spend once, Exposed ownership, deterministic prop anchors, no-valid-
anchor refusal, pull collision and every forbidden dash side effect. Forced G5
fixtures are Armored reposition, rail kill, self-haul across a cargo crossing
and Colossus Exposed payoff.

### 20.4 HR-03 — integration and prototype release verdict

**Outcome:** the complete primitive is selectable, teachable, draft-safe,
reportable and measurable across the key campaign waves.  
**Files allowed:** class/card/HUD/coach/bot/report/run-log/model rows and their
tests; no new combat mechanic.  
**Requires:** HR-02 passing G5, SH-04 stable and LV-04 stable; the required
measurement set explicitly exercises Signal Crane and the final authored key
waves.  
**Gates:** G0–G5 at Heat 0 and the highest normally unlocked Heat.

Integration work is finite:

- set `released: true` only in the final change after every gate passes;
- audit cards by gauge mode: vent heal/damage allow Pressure and Head;
  Pressure-rate and Field Dressing allow Pressure only; dash cards allow any
  class with at least one authored dash; no Rigger-only card pack ships yet;
- passive Articles remain available, keyed Articles remain Captain-only, and
  neither F nor V can fall through after a successful Rigger action;
- update coach/how-to/gauge text from Rigger data and actual key state;
- report class, Harpoon, control units, overboards, Tension gained/spent,
  Make Fast uses, target Hauls, anchor Hauls and Exposed damage;
- run-log persistence continues using the existing `class_id` and needs no
  Rigger-specific schema;
- the bot aims Harpoon across bodies, prioritizes elite→Gunner→Armored for Make
  Fast and Hauls a target only above 60 Tension; it does not use anchor Haul in
  balance samples until an explicit steering policy exists.

The comparison screen can no longer use its hard-coded two-column positions.
Generate three columns from `class_ids()`, show the four derived stat rows, then
only these shared prose rows: `the question`, `what it buys`, `stand`,
`you lose by`. A focused class's full blurb occupies the foot strip. The Rigger
copy is:

| Row | Text |
|---|---|
| the question | Which threat will you move, and where will you put it? |
| what it buys | TENSION pays for HAUL: move one made-fast threat or pull to the ship. |
| stand | off-axis from a threat, with a rail or anchor behind your decision |
| you lose by | firing straight down-lane, where displacement buys no ground |

Re-author the matching four rows for Captain/Boilerwright by shortening their
existing meaning, not changing it. Dynamic column math and all buttons/focus
must pass at the four poser sizes; no third entry may index a two-item array.

Measurement set is fixed: waves 4, 8, 10 and 12; flat Muster plus forced Pincer;
bare ship plus Bow Barricade and Signal Crane; ordinary, Armored and Boss target;
Captain and Boilerwright A/B on the same seed/Heat. Record Wilson-held agreement,
damage, damage taken, moved/blocked distance, Tension gain/spend, tether uptime,
Haul types, overboards, Exposed damage and lane travel.

Release requires:

- held rate statistically agrees with at least one existing hero at Heat 0;
- the Rigger spends Tension in a majority of completed fixed-seed runs;
- target and anchor Haul both occur in forced fixtures;
- Armored yields non-zero motion and Boss yields non-zero Exposed damage;
- control telemetry is material while raw player damage does not exceed the
  stronger existing hero beyond measurement agreement;
- Make Fast never holds more than one body and does not erase a whole lane;
- a tester states the Rigger's question differently from both existing heroes.

Fail the prototype, keep it unreleased and preserve the report if viability
requires unrestricted Boss displacement, permanent tether, free Haul, a global
damage multiplier or bespoke draft weapons. Passing authorizes a separate art,
animation and voice brief; it does not authorize those assets in HR-03.

### 20.5 Ordered hero backlog

| Rank | Idea | Prototype only after | Kill condition |
|---:|---|---|---|
| 1 | Rigger | packets above | control collapses into damage or deletes lane pressure |
| 2 | Powderhand | Powder Locker and Firebreak have real pick splits; prop ownership telemetry is stable | optimal play requires Powder Locker or detonating every prop on sight |
| 3 | Stormcaller | EL-01–04 pass and reaction attribution is trusted | element swapping is only a damage multiplier, not a create/consume decision |
| 4 | Signalman | ally lane orders exist at every Heat, including the crew-removal rung | hero becomes passive UI management or loses its kit when allies are absent |

The Powderhand prototype should use limited placed charges, not spawn more
random kegs. The Stormcaller should change the fixed attack's element in combat,
not redraw the 36-cell matrix. The Signalman waits longest because it needs a
Heat-safe ally command contract, not because its theme is weak. None of these
ideas should share an implementation packet with the Rigger.

## 21. Dispatch, verification and Definition of Done

### 21.1 Recommended release trains

Do not hand the whole expansion to one agent. Dispatch these trains in order,
with a human or lead-agent verdict at every G3/G5 boundary:

1. **Encounter truth:** BASE-00 → EV-01 → EV-02 → EV-05 → EV-03. Decide whether
   Quartermaster works before EV-04; then run EV-06 and LV-01 as independent
   readers of the stabilized wave state.
2. **Combat agency:** AB-01 → AB-02 → AB-03 → AB-04. Serialize EL-00 after the
   Beam seam, establish its v2 report baseline, then land EL-01 → EL-02 → EL-03.
   Finish RF-00 → RF-01, then IN-00; no core combat release skips the combined
   audit.
3. **Ship choice:** SH-01 → SH-02 → SH-03 → SH-04. Merge in order but publish
   them as one unit; do not expose the cap after SH-01/02 and do not start presets.
4. **Campaign authorship:** LV-02 → verdict → LV-03 → verdict → LV-04.
5. **Optional depth:** serialize AB-05 and AB-07 in dependency-safe order. The
   hero path specifically requires AB-06 → EL-04. SH-05 and SH-06 may follow
   their shared dependencies; start SH-07 only if every point has a real pick
   split.
6. **Hero proof:** HR-00 → HR-01 → verdict → HR-02 → verdict → HR-03.

Within a train, the arrow is a merge order. Even “parallel-safe” packets must
not both edit `game.gd`, `hud.gd`, `view3d.gd`, `enemy.gd` or the large harness
in separate worktrees and hope a textual merge preserves their invariants.

The smallest sensible expansion release ends after trains 1–3 with Quartermaster,
Beam/Field/Pulse/Cleave identities, attributable element reactions, one Reforge
pair, an IN-00 verdict, hardpoints and the first two new fitting rivals. Watches
and the Rigger should not hold those proven depth improvements hostage.

### 21.2 Copy/paste assignment for a coding agent

Use this template; replace bracketed text and attach no second packet:

```text
Implement only [PACKET-ID] from
docs/GAMEPLAY-EXPANSION-DESIGN-2026-08-04.md.

Before editing, read STATUS.md, docs/BOARD.md, docs/OUTSTANDING.md, the complete
packet, every function it names, and every direct caller. Report any conflict
instead of choosing silently.

Confirm every Requires entry in Section 14 and cite the required stable/G3/G5
verdict. If one is absent, stop without editing. Copy Serialize after separately:
it governs coordinator merge/evidence order, not mechanical eligibility. A
missing Serialize-after packet is not a prerequisite defect; report the shared-
file order and do not merge ahead of it without coordinator direction.

Allowed files: [COPY THE PACKET LIST]. Do not modify any other file. Preserve
all unrelated work. Do not add assets, cleanup, refactors, balance changes or
another packet.

First send: intended files, invariants, exact failing checks, feature-off/A-B
comparison, save/copy changes and stop condition. Then implement the smallest
vertical behavior. Every new field needs a production reader. Renderer code may
only read simulation state and may not consume gameplay RNG.

Run the packet's gates and the full parity harness. At completion send: changed
files, exact commands/verdicts, measurements, RNG/save compatibility, every new
field and reader, deviations, and remaining risk. Do not call the packet done if
its G3/G5 criterion was not measured; revert the packet or use its declared seam
and return the evidence.
```

For a low-capability agent, also paste the packet's Required checks verbatim
into its task. Do not paraphrase numeric tables; copying avoids accidental
“reasonable” replacements.

### 21.3 Standard commands and evidence

Run from `skygear-godot/`. The executable may be a platform-specific Godot
4.7+ path, but arguments stay exact.

```powershell
# Full non-destructive simulation harness
godot --path . --headless --script tests/parity_test.gd

# Args: 6 seeds, Heat 0, no forced class, 20 repetitions per seed = n 120
godot --path . --headless --script tools/balance.gd -- 6 0 none 20

# Boss-specific simulation evidence
godot --path . --headless --script tools/boss_probe.gd

# Windowed text audit and full screen review; never add --headless
godot --path . --script tools/text_audit.gd
python tools/screen_review.py --tag after-PACKET-ID

# Windowed motion/visual evidence as applicable
godot --path . --script tools/clip.gd -- list
godot --path . --script tools/vfx_shot.gd
godot --path . --script tools/arrival_shot.gd

# Repository checks, from the repository root
git diff --check
git status --short
```

A balance packet records before and after in separate invocations with identical
arguments and states whether any feature-off environment variable was set. Use
the resolution and interval the tool prints. In the command above, `6` is the
seed count and `20` is repetitions per seed; dropping the final argument to run
only six total samples is smoke, not evidence.
Do not claim deterministic balance output: the tool documents residual physics
noise. Queue/save/pure-helper fixtures **are** deterministic and should compare
exact values.

The harness uses redirected scratch paths for player saves. New persistence
checks must follow that pattern; they may not read, truncate or restore the
owner's actual `user://` file as a testing strategy. Visual claims require a
window because framebuffer readback is unavailable headless.

### 21.4 State ownership registry

This table prevents the most likely implementation failure: adding a second
clock or authority because the first one is hard to reach.

| State | Sole owner | Created/reset | Advanced by | Public reader |
|---|---|---|---|---|
| `wave_plans` | game run | after seed/Heat; clear on run reset | never after planning | cached plan/manifest/Muster tools |
| queue `elite` ID | cached plan entry | Muster promotion | never | spawn/configure |
| elite aura/pulse clocks | enemy instance | configure; death/reset frees | enemy simulation delta | enemy query used by game and renderer |
| arrival time/airborne | existing enemy + existing view reads | spawn | existing sim clock | `can_be_hit()` and arrival queries |
| `active_channel` | game run | accepted Beam; clear every exit | accepted game simulation delta and once-per-body element serials | endpoint/progress queries |
| Field anchor | skill instance | unset at wave start; set by first accepted landing | accepted active-cast completion | `field_center()`; current player while unset |
| Pulse timer | skill instance | skill creation | existing passive scheduler plus cast advance | pulse time/period queries |
| `basic_swing_serial` | game run (AB-04) | `begin_run()` | successful Captain basic resolve only | Cleave next-beat tell and Kindle consumer context |
| Gale current rows | game run `gusts` | Gale primary resolve; clear exits | accepted simulation delta | shared cone/progress query |
| Mortar shell rows | game run `pending_shells` | accepted Mortar; clear exits | accepted simulation delta | shared target/progress query |
| evolution ID | skill instance | Reforge choice; run reset with skill | never | `skill_stats()`/build name |
| burn/Frost/root/Conduct | enemy instance | successful element hit | enemy simulation delta | status queries/render |
| knock episode/Steam Impact | enemy instance | knock start/Steam hit; clear episode/exits | enemy motion through `note_knock_motion()` | episode/status queries |
| reaction totals | run telemetry | `fresh()` | `note_reaction()` only | report/tooling |
| owned fittings | Workshop `fittings` | award/load migration | between-run award only | `earned()` |
| installed fittings | Workshop `berths` | load reconciliation/UI | between-run equip only | hardpoint helpers/`sailing()` |
| preset slots | Workshop `presets` | load normalization/save UI | between-run save/clear only | validated preset reader/apply plan |
| `run_fittings` | game run snapshot | `begin_run()` | never mid-run | `fitted()` and fitting readers |
| Emergency Main clock/use | game run/wave | wave start/end | accepted simulation delta | effect/wall queries |
| made-fast target/anchor | game class state | successful F; clear exits/death | accepted simulation delta/Haul | tether/forward-limit queries |
| Exposed/control ownership | enemy instance | Rigger control hit | enemy simulation delta | damage/control readers |
| Tension value/grace | existing game gauge field | run reset | control note and gauge update | generic gauge plus class queries |

If an implementation needs another owner, stop and explain why the listed one
cannot answer the use case. Convenience is not sufficient.

### 21.5 Verification matrix

| Change type | Minimum evidence beyond G0/G1 |
|---|---|
| deterministic planner or save migration | exact same-input bytes/JSON; unrelated RNG state before/after |
| timer/channel/status | boundary and catch-up at 1/60, 0.05 and one step crossing multiple ticks; pause/reset/death |
| geometry or hazard | inside, boundary, outside; simulation/render center/radius identity |
| UI/copy | keyboard/mouse focus, text audit and all four poser sizes |
| enemy/wave balance | forced-behavior fixture plus sample large enough for the tool's printed resolution |
| fitting | bare A/B, rival A/B, frozen run snapshot, legacy save and no RNG movement |
| hero | class isolation, key waves, heavy/Boss rule, bot policy disclosure and control telemetry |
| combined combat release | IN-00 pairwise matrix, all-on wave-12 probe, v2 attribution and human readability verdict |

### 21.6 Definition of Done

A packet is complete only when all are true:

- only its allowed files changed and `git diff --check` is clean;
- the full harness exits zero and prints the new non-vacuous check names;
- removing the production call would fail at least one new check;
- every new field has one named owner, reset, production reader and test;
- all changed signatures have every caller audited;
- main and visual RNG consumption match the packet's contract;
- feature-off/bare/legacy behavior was exercised where declared;
- player-facing copy is derived from live state and passes containment;
- the specified metric moved beyond measurement resolution, or the feature was
  cut/disabled and the failed report retained;
- completion notes distinguish automated proof, measurement and human judgment.
- a release-critical combat packet is not release-ready until IN-00 has rerun
  green with its human wave-12 readability verdict.

“Looks correct,” “tests pass” without named verdicts, a six-run percentage,
renderer inspection without a windowed probe, or a constant-only check are not
completion evidence.
