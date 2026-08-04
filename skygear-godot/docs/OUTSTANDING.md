# What was asked for, and whether it is done

Every item here came from a playtest or a direct request. Nothing goes in from
me having an idea.

**Why this file exists.** The skybox was reported twice and slipped twice. The
aesthetic audit — the original job — was quietly dropped somewhere around the
fourth feature. Both happened for the same reason: I kept picking the next
interesting thing, and there was no list to pick from instead. A list I write
into is not a process fix on its own, but it is the part that was missing.

**The rule:** an item leaves this file when it is done or when it is explicitly
dropped with a reason. Not when it is partly done, and not when it stops being
interesting. `SkyGear Tools.bat todo` prints the open ones.

---

## Open

### "Our ship feels like a floating plane" — and why the fix is the EDGE, not one modelled deck
Asked 2026-08-02: *"Any chance it might be worth having meshy create the 3D
model of the deck of our ship? I'm still not very happy with the design of the
railings, prow, etc... Our ship feels like a floating plane - not the deck of a
ship. Convince me of the better path."*

**The complaint is measured fact, not taste.** DECK-DESIGN §1: 94% of the
default frame is planking and the near two thirds carries no ship's edge at all.

**The recommendation given (awaiting his decision): model the EDGE KIT, not the
deck.** Four reasons the deck itself is the wrong object to generate:

1. **The deck is the play space and it is dimensioned.** 1680 x 2320, lanes at
   ±560, eight cargo rects, three crossings, the spawn line, cannon/vent/Boiler
   positions — every one a collision or gameplay number that checks measure. A
   generated mesh will not return at those dimensions, and ratio control is
   precisely Meshy's demonstrated weakness here: the boarding hulk ignored a
   stated depth ratio FOUR times, at ninety credits.
2. **Texture density goes backwards.** The deck is 23 m long and fills most of
   the screen; baked at 2048 that is a few pixels per plank, against procedural
   planking's effectively infinite resolution. It would trade the most-looked-at
   surface in the game for a blurrier one.
3. **The deck has to CHANGE.** Props re-stow every wave, fittings add real
   geometry (barricade, spare gun, fourth vent), and his own accumulating
   scorch-and-stain marks land on it. A baked mesh does none of that.
4. **The defect is peripheral.** Railings, prow, the absent hull — all edge. Fix
   the edge and the middle stops reading as a plane.

**The proposed kit** (hand-modelled by him, the route with a 7-for-7 record
today): a RAIL MODULE that tiles (one stanchion-and-rail section — also where
generation fails worst: a prompted railing came back on a timber plinth), the
BOW assembly as one real piece (replacing the painted prow he asked to delete),
the STERN, and optionally a MAST-AND-RIGGING kit, which DECK-IDENTITY-DESIGN
wants anyway as shadow casters. All of it wraps an unchanged rectangle.

**Sequencing advised:** an agent is building the bow/stern/sheer as procedural
geometry right now. Let it land, look at it, then hand-model whatever still
reads wrong — replacing known-bad parts rather than betting the play space on
one generation. Prompts to be written on his word.


### Boarders should ARRIVE, not appear — transports, and a jump across the gap
Asked 2026-08-02, in two messages that are one idea:

> *"Should we also make some 3D skyship assets to use as transports? They can
> be flying beneath the ship and maybe even be the trigger that spawns waves."*
> *"Perhaps we can have mobs jump across into the ship instead of pop-spawning
> in."*

Today a wave is a spawn queue writing figures onto the deck at a line. The ask
replaces the moment with a chain a player can read: a transport rises
alongside → it is the wave's telegraph, visible before anything lands → its
boarders jump the gap → they are on your deck. The spawn stops being an event
that happens TO the player and becomes one they watch coming.

**Two things make this cheaper than it sounds.** The jump clips already exist
and are sitting unwired: the goblin pack shipped `mutant jumping` and two jump
attacks, and the crew locomotion pack has a jump. And the four transport
prompts are written — `handoff-3d/skyship_transports/`, the owner is modelling
them (skiff, barge, cutter, hulk-tender).

**What it must not break:** the spawn queue is deterministic and seeded, and
several pinned checks measure waves by it (`stow`, `tempo`, the wave schedule,
push waves). The arrival is PRESENTATION over a queue that does not change —
the same rule the deaths follow (renderer-side, `_recycle` seam, no sim
surgery). If a boarder is in the air it is still the sim's boarder, on the
sim's schedule; only where it is drawn changes. The tempo work (SURGE/LULL) is
the natural partner: a lull is a transport climbing into position.

**Open questions for whoever builds it:** where transports sit relative to the
deck rect and the camera's 41° cone; whether a transport is destructible (it
would be a target, which is a gameplay change and needs the owner); and what
happens on a push wave, where a boarding hulk already grapples on — the hulk is
the heavy version of this idea and should not be duplicated by it.


### The deck itself — irregularity over time, and a hull shape around a rectangle
Asked 2026-08-02, alongside the deck-identity question:

> *"Maybe consider some subtle elements to break up the deck visuals? Blood
> stains, scorch marks? These could appear over time to add some irregularity
> to the deck. Also, can we address the deck shape and consider how to keep the
> playable area a rectangle, but make the visual deck look more shiplike."*

Two asks, and the second contains the insight: **the collision rectangle and
the visible silhouette do not have to be the same shape.** Lanes, cargo rects,
crossings and every pinned check keep the 1680 × 2320 rectangle they were
measured against; the DRAWN deck gets a bow that narrows to a point, sheer
along the sides, and a stern — geometry the player never walks on, outboard of
a play area that never changes. Nothing in the sim needs to know.

The first ask has a prior decision worth honouring rather than overturning
silently: `VFX-PLAN.md` §7 deliberately deferred accumulating decals — *"the
keg scorch is in; a persistent accumulating set needs a cap and an eviction
policy, which is a system rather than an effect."* That was right, and it is
now the specification: he is asking for the system, so it ships WITH the cap
and the eviction policy rather than as an unbounded set that grows for twelve
waves. Extends `docs/DECK-IDENTITY-DESIGN.md`, which already owns the deck's
look.


### The Colossus is not frightening, and it is not textured
Reported 2026-08-02 with a screenshot, minutes after the boss was wired:
*"Collosus is way too easy - he needs to be scary the player. Not sure what's
going on with his texture."*

Three separate faults, and only one is a surprise:

1. **No texture — FIXED (SG-94), and it was an ASSET gap, not a bug.** The
   part-segmentation GLB carries no UVs and no images (measured: zero bytes of
   texture), so the boss rendered as flat untextured geometry with the furnace
   lamp glowing inside it. The owner then sent the TEXTURED TWIN of the same
   sculpt, and `tools/segment_parts.py` now takes it as a third argument: the
   thirteen parts are re-cut FROM the painted mesh with the segmentation
   demoted to a label source, which is `tools/split_rotors.py`'s trick in the
   same direction. Ruled out by measurement, not taste — the two exports are
   not the same topology (1,318,962 triangles against 1,366,036), so nothing
   could simply be assigned; and transferring UVs onto the already-decimated
   parts would have smeared the map across the 5.4% of vertices that are seam
   duplicates. Kept: 13 named parts, their joints (worst drift 9.78 mm on a
   3,300 mm figure), the five beats, and the disassembly — `foot_l` still never
   releases, moving 0.001 m across the whole death. Maps shrunk the hulk way,
   34.66 MB → 0.454 MB. The furnace lamp stays at 1.28, re-measured rather than
   re-guessed (see `assets/models/lights.json`).
2. **Floating dark and gold blobs around it — FIXED (SG-94).** Two causes, and
   the first was fault 1 wearing a different hat: with no continuous surface,
   the dark-plate parts and the brass parts read as separate lumps rather than
   as one machine. The second is real and its own bug — one contact shadow,
   sized off the gameplay radius and dropped at the figure's origin, drawn
   against a machine whose death throws thirteen parts across two metres of
   deck. Every part now darkens the planking under its own measured footprint,
   fading out with height off the deck, so a standing machine shows its
   FOOTPRINT and a disassembling one grounds each part as it lands. The shared
   shadow system is deliberately untouched: the owner's separate
   "dynamic shadows, not one circle blob under everything" ask is board SG-95.
3. **"Way too easy — he needs to be scary." ANSWERED 2026-08-03 BY THE OWNER'S
   OWN DESIGN — boards SG-146 and SG-166.** The fight, not the picture. Health
   went 900 → 2900 (SG-146) and then, on 2026-08-03, he supplied the behavioural
   half himself: *"he's just a meat shield, just soaks and takes time... Maybe
   even just have him ignore the player and keep heading towards the middle,
   destroying the cannon and then attacking the main objective. Have the damage
   that he does just be damage around him so that it can hurt the player when
   the players try to kill him."* Both halves shipped — the lane walk is ON and
   his damage is a telegraphed area STOMP. **He deals 21% more than the chase
   build he replaced (123.97 → 150.21 by his own hand, n=480 a side) and the
   Heat 0 hold-rate ROSE 12.7 points**, because a readable threat has no tail;
   `docs/COLOSSUS-DESIGN.md` §1b is the whole measurement with a three-point
   curve if he wants the hold-rate back. **What he should judge by hand** is
   whether "he ignores you" reads as indifference — §4's own recorded risk — and
   whether the circle is escapable at speed. Left open only for that.


### The build-44 playtest — fifteen items, and the first praise of the port
Reported 2026-08-02 evening, after the all-mesh deck landed. Verbatim where it
matters. **"I LOVE the goblins and the new 3d enemy models"** — the first
unqualified praise this port has had, and it came the day the owner modelled
the figures himself.

**Bugs**
1. **Crew walk BACKWARDS** — "they should face enemies when walking."
   **DONE 2026-08-02 (board SG-110)** — a crewman was the one figure on this
   deck carrying no direction at all, so the renderer handed his rig the literal
   `Vector2(0, -1)`. That is true of the march up-deck and of nothing else he
   does: `_update_crew` sends him at the nearest boarder IN HIS LANE wherever
   that boarder is, so one astern of him had him reversing into the fight, and
   his bayonet stab was thrown at the horizon while the man was off his
   shoulder. Fixed by giving him the boarder's own two fields
   (`attack_direction`, `velocity`) and asking the boarder's own question,
   hoisted into one `figure_heading()` both sides of the deck call — travelling,
   face where you are going; engaged, face what you are fighting. The four aboard
   `strafe` clips stay unwired and the row says why: he walks in a straight line
   at his goal, so his travel vector and his threat vector are the same vector
   and a strafe has nothing to play. `figure · a sailor sent back down the deck
   after a boarder TURNS ROUND to walk at him, instead of reversing into the
   fight`, plus three more.
2. **The 2D hulk sprite still sits in the same place as the 3D model** — a
   duplicate, now that SG-76 wired three real states.
3. **The sentry sometimes has no model** — already fixed (SG-66, the shared
   billboard pool handing a sentry a spark's additive material), but the fix
   landed AFTER build 44 was cut. Not a recurrence; ships in 45.
4. **Enemy projectiles are far too large** "and dont look very cool."
   **SIZE DONE 2026-08-02 (board SG-112); "not very cool" left for his eye.**
   Not a matter of taste — the browser this is a port of records the number:
   `drawBolts` draws the bolt's hard body at radius **7** ground units, and the
   HOSTILE row's `girth` was **16**, a body 32 units across and wider than a
   crewman's whole footprint. Measured at the real camera on the same
   deterministic frame from two clean trees: **38-41 px tall -> 14-18 px**, a
   quarter of the captain's on-screen height down to a tenth. The three things
   the browser's own note says make an inbound shot trackable — the oxblood
   colour, the ground mark, the nine samples of tail — are all untouched, so
   pillar 6 is not what shrank. `core · the enemy's shot is the size the browser
   draws it, and stays smaller than the mark it throws on the planking`.

**Tuning / balance**
5. **Crew 10–15% smaller** — too close to the hero's size.
   **DONE 2026-08-02 (board SG-111)** — `FIGURE_SCALE["CREW"] = 0.875`, the
   middle of the band he named rather than either edge: **165 -> 144**, 82% of
   her 176 and still 1.75x a goblin's 83, so the three tiers stay ordered. The
   cut lands in the one table every shrunk figure's cut already lands in, not in
   the sim (a `radius` is the footprint a boarder swings at) and not in the mesh.
   `figure · and he is the ten-to-fifteen per cent shorter the owner asked for —
   under his captain, still well over a goblin`.
6. **Furnace knights want slower, more telegraphed hits** — "hard hitting but
   designed to be dodged." A design change, not a number nudge: the fantasy is
   a wall you read and step around.
   **DONE 2026-08-02 (board SG-97)** — four numbers as one design: windup
   0.55 -> 0.90 (the read, the Colossus's own tell), recover 0.60 -> 1.00 (the
   punish), damage 20 -> 34 (three connected swings kill you), reach and swing
   untouched because they ARE the drawn wedge. Throughput against things that
   cannot dodge is held at 17.4 -> 17.9 dps on purpose, so the wave schedule is
   unmoved. And the fault under the ask: the wedge was drawn as a 120-degree fan
   and the hit was tested as a full CIRCLE, so stepping around the flank — the
   exact move the picture asks for — never worked. `telegraph · a swing lands
   inside the wedge it drew and nowhere else`. Balance numbers on the board row,
   with the honest caveat that the bot never dodges. **Left open in NEEDS_ALEX
   for his hands** — the bot cannot judge this one for him.
   **DONE 2026-08-02 (board SG-97)** — four numbers as one design: windup
   0.55 -> 0.90 (the read, the Colossus's own tell), recover 0.60 -> 1.00 (the
   punish), damage 20 -> 34 (three connected swings kill you), reach and swing
   untouched because they ARE the drawn wedge. Throughput against things that
   cannot dodge is held at 17.4 -> 17.9 dps on purpose, so the wave schedule is
   unmoved. And the fault under the ask: the wedge was drawn as a 120-degree fan
   and the hit was tested as a full CIRCLE, so stepping around the flank — the
   exact move the picture asks for — never worked. `telegraph · a swing lands
   inside the wedge it drew and nowhere else`. Balance numbers on the board row,
   with the honest caveat that the bot never dodges. **Left open in NEEDS_ALEX
   for his hands** — the bot cannot judge this one for him.
7. **Object scale audit** — "why are some objects so much larger and what do
   they do?" Distinct from SG-79 (which trued heights against intent): he is
   asking what each thing IS and whether its size is earned.

**Features**
8. **Sentry autocast** — hold the hotkey to toggle "always drop at my feet,"
   with a visual indicator that it is on.
   **DONE 2026-08-02 (board SG-98)** — hold the slot's own binding for 0.45s to
   arm it, the same hold again to stand it down; a lit ring in the element's
   colour plus the word AUTO on the key row says it is armed. Armed means the
   existing idle auto-place drops its grace to zero, so it lands at your feet
   the instant the cooldown ends. Survives a draft, a wave and a pause because
   the flag lives on the skill dict: `sentry · and stays armed across a wave
   change`, `sentry · and is still armed when the pause lifts`.
   **DONE 2026-08-02 (board SG-98)** — hold the slot's own binding for 0.45s to
   arm it, the same hold again to stand it down; a lit ring in the element's
   colour plus the word AUTO on the key row says it is armed. Armed means the
   existing idle auto-place drops its grace to zero, so it lands at your feet
   the instant the cooldown ends. Survives a draft, a wave and a pause because
   the flag lives on the skill dict: `sentry · and stays armed across a wave
   change`, `sentry · and is still armed when the pause lifts`.
9. **Auto-attack element choice** — so the basic attack is not always Ember.
   **DONE 2026-08-02 (board SG-99)** — a cycling THE CORE plate on the title
   screen, under WHO IS ABOARD, which is where the auto-attack's element was
   already being chosen silently by the class pick. Not a card (a card is dealt,
   and this is wanted every run), not the draft (the Cleave is deliberately
   undraftable and the 32-cell matrix is derived by counting the eight shapes
   that are), not the Workshop (it would gate flavour behind scrip). Consumes no
   RNG, so seeds are unmoved: `auto · and naming another one costs the seeded
   stream nothing`, `auto · and the Cleave is still never dealt as a card`.
   **DONE 2026-08-02 (board SG-99)** — a cycling THE CORE plate on the title
   screen, under WHO IS ABOARD, which is where the auto-attack's element was
   already being chosen silently by the class pick. Not a card (a card is dealt,
   and this is wanted every run), not the draft (the Cleave is deliberately
   undraftable and the 32-cell matrix is derived by counting the eight shapes
   that are), not the Workshop (it would gate flavour behind scrip). Consumes no
   RNG, so seeds are unmoved: `auto · and naming another one costs the seeded
   stream nothing`, `auto · and the Cleave is still never dealt as a card`.
10. **Enemies should FADE after death** rather than vanishing.
    **DONE 2026-08-02 (board SG-113)** — three separate disappearances were
    happening and only one had a tail. The four kinds with a real `die` clip
    played it and sank, which still CLIPPED out at the deck line; **the kinds
    with no death clip (the scrapper's borrowed library, the gunner drone) were
    freed the same frame the simulation finished with them**, which is the one he
    was looking at; and a figure BILLBOARD was hidden and shelved on that frame
    too. One curve now — `corpse_fade`, solid through the death clip then to
    nothing over 0.60 s — spent on `GeometryInstance3D.transparency` by a rigged
    body and on `modulate.a` by a painted one. The fade STARTS BEFORE the sink so
    the deck line stops being the moment anything happens, and `corpse_life()` is
    unchanged at 2.00 s, so a body holds a rig no longer than it always did
    (DESIGN §13m). `figure · a boarder with no death clip fades out where it
    stood instead of ceasing to exist mid-stride`, plus four more.
11. **3D weapons** — spears for the crew (who currently bayonet-stab with empty
    hands), plus a few steampunk weapons banked for later.

**Aesthetic direction**
12. **Cloud diversity** — variations, sizes, shapes, more Z layers.
13. **Dynamic shadows** — not one circle blob under everything.
14. **"How do we make the deck feel more shiplike, and more steampunk?"** — the
    open question, prompted by liking the steam. This one gets a design pass
    rather than a guess.



### The morning-after playtest — eight findings from the owner's Boilerwright run
Reported 2026-08-02 morning after a full run to wave 11 (seed SFHBVG, THE
WRECK berthed), with clarifications taken before work started. Items, each a
board row:

1. **F4 needs axis-locked dragging** — hold Shift while dragging to move on
   one axis only (SG-58).
2. **Vents invisible and untaught** — playing the Boilerwright: *"I dont
   understand the vent mechanics, cant seem to visually identify a vent."*
   Clarified: mechanic stands; fix is visual identity + teaching (SG-59).
3. **Aim feedback missing** — *"Its hard to tell where an aimed skill will
   land - or determine range, since the cursor doesnt show any of that
   information visually."* (SG-60)
4. **The boarding hulk has no visible HP bar** — the push wave's objective
   is invisible (SG-61).
5. **KNOCKBACK IS GAME-BREAKING AGAIN** — *"Something is still knocking back
   enemies all the way to the boiler area, very buggy visually and annoying
   gameplaywise this is a game breaking bug."* Build carried SLEDGE FORCE +
   OVERPRESSURE + Frost; crew/cannons took 58% damage share, consistent with
   flung enemies being delivered to the stern guns. (SG-62, P1)
   **DONE 2026-08-02 — the vector was the frame, not the cap**: the July-31 fix
   capped the shove's VELOCITY, but `velocity += knock_velocity` folded the
   capped shove into the walk velocity the move-lerp keeps ~90% of, so it was
   integrated twice — one capped hit measured 1,338 units of carry, mid-deck
   to the stern wall. Fixed with two positional laws in `enemy.gd`
   (`KNOCK_TRAVEL_MAX` 390, `KNOCK_STERN_GIVE` 60) — evidence and check
   strings on board SG-62's Done row.
6. **Hard cap on allied units alive** — plus the 58% ally share wants
   measuring while in there (SG-62, same sim pass).
   **DONE 2026-08-02**: `SkyGearGame.ALLY_CAP` 32, crew + sentries counted
   together, refused at every spawn door — `allies · the alive cap holds
   under flood`. Share numbers on the board row; the owner's 58% was a real
   run, so the number that matters is his next playtest.
7. **2D reads remaining** — impacts/puffs, skill-shape billboards in the air,
   AND the 2D crew/ally figures all named: *"I still see 2D sprite particles
   on skill usage, why?"* (SG-63 renderer pass; figures gated on rigging)
8. **The 2D→3D purge, verdicts reopened** — *"completely remove any existing
   2D objects that should be migrated to 3D now that we have the meshy
   workflow"* — clarified: reopen the rejected props (brazier, small crate,
   hulk), generate the never-tried, AND migrate figures; scrapper regen
   implicitly approved as the figure pilot. (SG-64 props, SG-65 scrapper)
   **PROPS HALF DONE 2026-08-02** (board SG-64 has the full inventory and
   per-prop verdicts): brazier and small crate re-rolled with the recorded
   rejection reasons as prompt constraints — both CLEARED; the mast and the
   two bow ballistae generated and wired — the mast was the deck's worst
   remaining eyesore; the hulk's one constrained re-attempt got the wall
   shape and lost on stone-masonry palette + arch-for-iris — hand-model
   verdict FINAL, spec in `handoff-3d/`. Still painted, recorded with
   reasons on the row: railing/hatch (unfunded under the 200-credit cap,
   filed), rope coil (smallest thing on the deck), the wreck fitting.
   `prop · every wired deck prop scene keeps the statics' bargain — a scene
   on disk, meshes inside it, and an honest ruler` pins the wired set.

Animations: clarified as wrong-reading clips, not glitches — the owner makes
Mixamo clips from `Downloads\boilerwright-mixamo.zip`; the retarget path
ingests FBX on delivery.

### The variety direction, from the owner — enemies vary the run, the ship changes between runs
Answered 2026-08-02, 00:30, when asked whether to resurrect the cut stowage
spine: *"When you're talking about deck variety, it should be minor deck
variety within waves because the ship itself shouldn't change during the
playthrough that much. It should be more based on the enemies. The ship
modification should happen in between runs. As you complete all twelve waves,
you would want to see modifications and changes and upgrades that can be made
to the ship itself."*

Three consequences: (1) the stowage spine stays CUT — per-wave deck shuffling
was the wrong axis, the kill-test and the owner agree; (2) run-to-run variety
work goes to the ENEMY side (composition, mutations, behaviors — designed
2026-08-02, `docs/ENEMY-VARIETY-DESIGN.md`; unbuilt); (3) the
fittings system is UNBLOCKED and reframed: fittings are between-run ship
modifications earned by finishing waves, visible on the deck at run start,
never changing mid-run. POST-PARITY-PLAN items 3/5 proceed on that basis.

**Consequence (3) SHIPPED 2026-08-02 (board SG-56) — left open for your
hands-on verdict on the screen and the six.** Six fittings, each a DECK or
VERB change and never a stat (the hard rule is a harness check): THE WRECK
(your first Colossus kill, riding off the bow — migrated from SG-15 into the
berths), BOW BARRICADE (clear wave 8 — a fixed crate line at the bow of the
middle lane), SPARE GUN (win at Heat 1+ — a fourth cannon, shipped broken,
repaired by the verb you know), FOURTH VENT (win as the Boilerwright — his
prize, in the bow crossing), THE WINCH (12 salvage in one run — grants
tap-to-haul on the crate stacks, the SG-37 idiom), SCUPPER GRATING (win
without healing — seals one crossing, stands a vent on it). At most ONE per
run, decided where the scrip is; six berths, chosen on THE BERTHS screen off
the title, saved with the Workshop; the run row records `ship: [ids]` and the
report names the refit. The ship NEVER changes mid-run — your rule, now
literally a check string: `fittings · the ship never changes mid-run — a
berth signed mid-run waits for the next run`. A bare ship is byte-identical
to today's. Harness 641/641; the berth screen is the audit's 24th, clean at
all four widths; `.shots/clips/fight.gif` now films the fight with all six
berthed.

**THE WINCH TABLED 2026-08-02 (board SG-68), with the crate-verb family your
"boring" verdict tabled:** a fitting whose whole grant is a dead verb would
be a lie, so while the family is down the winch is unearnable (its award
rule is skipped; the next rule in table order takes its place), unberthable,
and never sails — THE BERTHS shows it as "TABLED — an interaction pass will
revisit" rather than vanishing, an earned one in a save stays earned (a
berthed one un-berths gracefully on load), and the other five fittings are
untouched. It returns with the family:
`deckwork · the tabled verbs come back with one flag`.

### The editor can't REACH the screens — round two of the alignment ask
Reported 2026-08-01, after SG-42 shipped: *"You still didnt fix the screens
tool to allow me to interactively edit UI/text."* SG-42's "you edit the
screen you are ON — the game navigates" rule is the miss: reaching the
results screen means winning a run, reaching GAMEOVER means dying.

**SHIPPED 2026-08-02 (board SG-44) — left OPEN for your hands-on verdict,
like SG-42 itself.** Press **P** inside F4 and pick any of the 23 screens the
audit shoots — the list IS the audit's list, posed by ONE shared poser
(`scripts/screen_poser.gd`) that the text audit, the batch camera and the
editor all call, so a second drifting copy cannot exist (harness-pinned).
Picking poses the screen live on a SANDBOX — real widgets, real strings,
never your run — and the SG-42 editor works on it exactly as everywhere:
descend, drag, nudge, type, verdicts, Ctrl+S, F12. Offsets save under the
same screen id the real screen reads, so an alignment fixed on a posed
GAMEOVER is fixed on the one you die into. **Esc hands the game back
exactly** — mid-run included; the run's clock, boarders and RNG hold still
under the glass (the cutscene player's "camera comes back exactly" contract,
now a harness check). Try: F4 anywhere → P → "deck lost" → move something →
Ctrl+S → Esc. Full evidence on board row SG-44; `docs/HUD-LAYOUT.md` §"The
screen picker" is the how-to.

### UI alignment must be EDITABLE, not just photographed
Asked 2026-08-01 after running the screens audit: *"I got all of the
screenshots but I'm not able to directly edit/align content within UI
elements. Add this functionality as the primary purpose, and then the massive
screenshot dump is a secondary."*

**SHIPPED 2026-08-01 (board SG-42) — left OPEN for your hands-on verdict,
like the crate and the lab.** F4 now works on EVERY screen, and it reaches
INSIDE: on the fight HUD it is the plate editor you know; everywhere else
(title, draft, pause, settings, workshop, results, comparison, controls) it
captures the screen's own elements — labels, readouts, buttons, the card
emblem — as the screen draws them. Click a panel, click again for what is
inside; drag, arrow-nudge (Shift ×10, Alt ×0.1), or click the offset readout
and TYPE it (Enter applies, malformed refused). Ctrl+Z undoes, Ctrl+S saves
into the same hud_layout.json family (`SkyGear Tools.bat layout` promotes),
Ctrl+R resets the one screen, F12 photographs the screen you are fixing.
The verdict bar runs the text audit's own detectors live while you edit.
You edit the screen you are ON — the game navigates. The 84-shot dump stays
as the secondary batch-evidence mode (`SkyGear Tools.bat screens`). Full
evidence on the board row; docs/HUD-LAYOUT.md is the how-to.

### Projectiles look like cheap 2D sprites — the first ask of the post-parity era
Asked 2026-08-01 with a screenshot of the cartoon fireball bolts: *"Can we get
better VFX particles? Instead of these 2D sprites that look like they are
cheap? What did our VFX investigation into Godot yield for us?"*

The bolts are the browser's painted sprites billboarded into 3D — kept
because parity said keep them, un-blocked the moment parity was retired. The
research audit's architecture is already in place (emit_particle injection,
behaviour-keyed emitters, element motion signatures); what was never done is
making the projectiles THEMSELVES 3D — emissive cores, particle trails,
per-element light. Board SG-40, queued behind the lighting pass (same file).

**SHIPPED (SG-40, 2026-08-01) — awaiting your eyes; NOT closed.** Every bolt
head is a real emissive mesh now — a low sphere stretched into a teardrop down
its own velocity, glowing from its own light so the bloom catches it, with a
small omni under the nearest few. The painted fireball is gone from the default
path and kept only as the art-missing fallback. Element identity rides the
MOTION, not the hue: Ember is a fat throbbing ball shedding rising flecks,
Frost a long narrow shard with a tight sinking wake, Arc a hard slug flickering
fast, Steam a soft round billow; the enemy's inbound shot is a blunt oxblood
orb that sheds nothing (so a lane of them stays legible) and our cannon a tight
brass slug — theirs and ours never confused. Pools stay capped (24 cores, 6
lights), the ground shadow stays under every bolt, and the telegraphs and the
SG-34 lighting are untouched and green. Measured under a saturated wave (51
live bolts): p99 5.98 ms against the 16.7 ms budget. Before/after posed frames
in `.shots/vfx-sg40-before/` and `.shots/vfx-sg40-after/`. This stays OPEN
because YOU judge whether it reads better now — play it and say. Harness
517/517.

### The lab needs a usability pass — typed values, and yaw/roll collapse
Asked 2026-08-01, with a screenshot of MOUNT mode on the cutlass: *"Yaw and
roll here seem to do the same thing. I like the changes to the Lab, but I do
feel as though it can be made more user friendly. Allow me to type in values
as well. Send an agent to do a full improvement pass on the lab."*

The yaw/roll observation has a probable mechanical cause, not just a UI one:
the fit in the screenshot sits at pitch −96°, on top of the ±90° gimbal
singularity where the yaw and roll axes align — nudges that edit Euler
components will do the same thing there. Board SG-39: typed input on every
numeric row, rotation nudges applied about the weapon's live local axes
rather than Euler fields, and a general friendliness pass.

**SHIPPED (SG-39, 2026-08-01) — awaiting your hands-on verdict; NOT closed.**
The mechanical cause was confirmed by measurement: at pitch −90 the stored Euler
yaw and roll build the *same* basis to 1.6e-8 — genuinely one control, not a
perception issue. Three things are in the next build.

1. **The collapse is gone.** Every rotation nudge — the PITCH/YAW/ROLL buttons,
the A/D/W/S/Q/E keys, the wheel, and right-drag — now composes a turn about the
blade's OWN live local axis instead of incrementing an Euler field, so the three
rows always do visibly different things at any orientation (measured 0.59 apart
at the exact pitch that used to collapse). The file stays Euler, and your saved
cutlass fit loads to the identical pose it saved at — guarded so it cannot
regress.

2. **Type any value.** Click a number on any row — MOUNT's seven, the four LIGHT
rows, the nine FX dials — type it, ENTER applies, ESC or a click away cancels,
and a malformed entry is refused with the old value kept. One reused box, not
seven.

3. **Friendlier all round.** Hovering (or nudging) a rotation row lights the
matching coloured axis line on the blade so you can SEE which line it spins.
Shift makes every step ×10 and Alt makes it ×0.1, both spelled out in the header.
The wheel over a row nudges it. The dev-note instruction block was rewritten to a
plain hint. The "no size for this" line now reads as information, not an error.
And Ctrl+Z takes back the last nudge or typed entry.

Play it and say — if a control still fights you, that is the thing to name.

### The Boilerwright's mobility gap is 60%, not the 21% the numbers say
Reported at playtest as "Boilerwright feels slower", alongside "I'm not sure I
understand what the class actually does". The second half is fixed — the
comparison screen is built and Overpressure is a ring round the dial. The first
half turned out to be real and much larger than the stat sheet admits.

205 against 260 is 79%, and that is TOP SPEED — a number nobody experiences.
What a player experiences is ground covered while a lane walks down on them.
Measured over six seconds, `class · but ground covered against a dashing
captain is worse than that`: **he covers 40% of her distance.** `ACCEL` is
shared so he actually reaches his top speed faster than she reaches hers; the
entire gap is the dash.

The 33% first recorded here (2026-07-31) was a noisy sample: that measurement
read `global_position` after `move_and_slide()`, which steps by the engine's
real-frame physics delta rather than the 0.05 sim tick, so the ratio swung
across 200–570% run to run and 33% was one draw of it. SG-1 (2026-08-01)
rebuilt the measurement to integrate `|velocity| * 0.05` — the speed the sim
actually produces — which is bit-for-bit repeatable: captain 3076, boilerwright
1228, every run. The gap is real and the direction is unchanged; the corrected,
deterministic figure is **40% of her ground, a 60% gap**, not 33%/67%.

Read it as an upper bound: she dashes on every cooldown and he never spends
bank on the Bleed Jet, which is the widest the gap can be. But the jet costs
the bank that carries the multiplier the class is built on, so closing the gap
means giving up the reason to be the class — and that IS the trade the player
is feeling.

Not a bug and no numbers changed. It is a design question the measurement now
makes answerable: either he is compensated somewhere a player can feel, or the
comparison screen has to say plainly that he trades mobility for damage. What
must not happen is tuning it by feel — that is what the number is for.


### A cutscene tool — BUILT, AND ONE SHOT IS WIRED. Three trigger points are empty
Asked for: *"set up frame, key frame, camera movement… use the in-game renderer…
save those so that they can play at certain times during the game."* All four
halves are in. `SkyGear Tools.bat cutscene`.

- **Author.** A timeline with keyframes you add, drag in time, delete and scrub.
  Drag to orbit, right-drag to slide the shot across the deck, wheel to push in;
  every one of those numbers is also a labelled minus/plus row with its live
  value beside it, in GROUND UNITS. AUTO-KEY records a keyframe wherever you move
  the camera. Five easing curves per segment, because a linear camera reads as a
  machine on a rail. Nothing needs a key a laptop lacks.
- **The real renderer.** It instantiates `scenes/main3d.tscn` — the real deck,
  models, lighting and lens — the way the model lab's FX mode does. The STAGE
  panel puts the Colossus or three boarders on the planking so there is something
  to frame.
- **Saved** to `assets/cutscenes/<id>.json`, with an index beside it.
- **Played.** `scripts/cutscene.gd` is the reader and `scripts/cutscene_player.gd`
  drives the camera; both existed before the first file did. A shot names a `cue`,
  and the four cues are real call sites: `boss_arrival` in `game.gd::spawn_enemy`,
  and `wave_start` / `victory` / `defeat` watched in `view3d.gd::_watch_cues`.
  **`colossus_arrival` plays at wave 12** when the boss climbs aboard.

**DONE (SG-8, 2026-08-01).** All four cues now carry a shot, and the suggested
run opening was added as a fifth cue: `run_open` (2.5s establishing crane),
`wave_start` as a short milestone flourish narrowed to the event waves 4 and 8
(never wave 12 — it would suppress the Colossus), `victory` (a 5.4s crane-up to
the sky the deck framing never shows), and `defeat` (a 3.6s heavy push onto the
dying Boiler, held for the results screen). The run opening's one line of code
is a flag `begin_run` raises and `view3d.gd::_watch_cues` spends on the first
wave — it cannot fire from `begin_run` itself, which settles into the opening
draft where a cutscene is not allowed. Fifteen new harness checks, 463→478.

**Two things worth knowing before authoring one.** The camera CAN break the
shipped solve — a key carries its own field of view, height and roll — and the
gameplay camera is put back exactly when the shot ends, pinned by
`cutscene · THE GAMEPLAY CAMERA COMES BACK EXACTLY` and the four checks beside
it. And a key can be PINNED to the live gameplay camera, which is how a shot
hands back without a cut; the Colossus arrival ends on one.

### The lab needs animation and VFX playback — BUILT; one dial has no home
Asked for, and now built. `SkyGear Tools.bat lab`, three modes on three buttons.

- **Animation** plays. A timeline along the bottom in VIEW and MOUNT: click any
  of the fourteen clips, PLAY, drag the bar to scrub, STEP one 60th of a second
  at a time, and five speed presets down to a tenth. Mounting no longer resets
  the pose, so a weapon can be nudged AT the frame it slips. `--clip <name>
  --at <0..1> --shot <png>` renders one named frame headless, which is what a
  before-and-after on a grip needs.
- **VFX** loop. FX mode instantiates the real `main3d.tscn` — the real renderer,
  the real deck, the real camera — and fires the same `_fx` dictionary the skill
  code fires, on a period you set. Six shapes, four elements, and dials for
  radius, arc, life, damage, glow, particle size, particle lifetime and a
  slow-motion time scale. Nothing is re-implemented; a second copy of the effect
  code was the thing to avoid.
- **Modifiers** are exposed: wireframe, clay, flat lighting, a grid in GROUND
  units with a 176-unit ruler post, the skeleton drawn over the mesh, RGB axes
  on the selected bone, five backdrops, and the key light swung, raised and
  dimmed. Everything is a button or a drag; nothing needs a key a laptop lacks.

**What it still cannot do, and why.** The FX dials do not write to a file. Every
one of them is a *constant* in `view3d.gd` or a literal in a `_fx({...})` call,
and inventing a JSON for them would be the sixth time this project shipped a
table nothing reads. SAVE in FX mode puts the numbers on the clipboard next to
the exact constant they belong to instead. Giving them a real home means giving
the renderer a reader first — that is a renderer change, not a tool change.

**And one thing the lab found:** `ELEMENT_FX[*].life` in `view3d.gd` is dead.
Four elements declare a particle lifetime and `impact_at` never reads it — the
emitter's own `lifetime = 1.0` governs all three families. That is failure mode
one, already in the tree. It cannot be fixed by reading the field, either:
`emit_particle` has no per-particle lifetime flag, so honouring it means one
emitter per element rather than per behaviour.


### ~~THE CAMERA IS ZOOMED IN~~ — MEASURED, AND IT IS NOT. The claim was right after all
Kept as a record of a finding that did not survive being measured — the
popup-drift pattern again. I had said the camera was "ported exactly" from the
browser's `CAM.recompute()` solve, then the first parity run made me doubt it:
side by side, Godot *looked* like it showed less of the deck, so this entry
recorded a framing gap and made it upstream of everything else.

**There is no framing gap. The port IS exact.** Measured rather than eyeballed —
`tools/cam_measure.gd` puts a known ground length on screen in both builds at one
output resolution and unprojects it: the browser's own `CAM.project()` math and
Godot's `Camera3D.unproject_position` land **on the same pixel** for every length
tested.

| known length | browser px | godot px | ratio |
| --- | --- | --- | --- |
| deck full width 1680 @ focus depth | 3288.1 | 3288.1 | 1.000 |
| deck full width 1680 @ the bow | 1137.5 | 1137.5 | 1.000 |
| one lane 560 @ focus depth | 1096.0 | 1096.0 | 1.000 |
| bow→stern depth @ keel | 1695.7 | 1695.7 | 1.000 |

The captain's own ground point lands at the identical pixel `(960, 705.4)` in
both. No `WORLD_SCALE`, deck-rectangle, camera-distance or FOV discrepancy
exists, and no browser zoom-out was dropped.

**Why the impression, then.** The browser's focal length is not the bare 1320 —
`recompute()` sets `_f = f * View.unit` (`reference/web-source/_render_head.js:53`),
and `View.unit = clamp(min(w/1400, h/860), …)` scales it with the output
resolution. That is *exactly* what Godot's fixed vertical FOV of
2·atan(430/1320) already does at any 16:9 window, so the two frame identically at
every size. What actually differed was the picture the earlier comparisons were
made against: the browser side was long drawing its procedural sky FALLBACK
because Chromium blocked its `new Image()` loads over `file://` (now fixed in
`parity.py`, which serves over HTTP and asserts the art arrived) — every "the
camera is zoomed in" judgement was made against a stand-in render. Fresh
side-by-sides with the real art are in `.shots/parity/`.

Nothing was changed in the solve, deliberately — the two harness checks that pin
it (`camera · the lens is the browser's focal length`, 36.09°, and
`camera · the captain stands where the art was framed for`, 0.600 of screen
height) were confirmed to assert the CORRECT invariant, not the bug. The one real
residual the side-by-sides show — the Boiler PROP mesh reading larger than the
browser's flat `boilerH: 132` block — is a model-scale question, not a camera
one, and is board item SG-27.

One latent inconsistency noted while here, harmless: `parity.py` passes
`--resolution 1600x900` but the project's `canvas_items` stretch keeps the render
viewport at 1920×1080, so the Godot half is captured at 1080p and the browser
half at 900p. Both are 16:9 and the stitch matches height, so the framing
comparison is unaffected — but the tool's `SIZE` is not the Godot render size.

### ~~The telegraph edges are too soft~~ — DONE 2026-08-03 (board SG-162)
Asked 2026-08-03, on the SG-158 work: *"I see what you're talking about for the
wind-up and the strike indicators. I like them, but I feel like the edges are a
little soft. I think when doing the sort of wind-up damage indicators, the edge
of that should be very clear to the player. Having it lined with something a
little harder, as opposed to that soft edge, could make it clearer for the
player."*

He was describing a measurable fact. The wedge peaked at **88% of its own reach**
and had fallen through half its brightness by **93.5%**, so on the Colossus's 146
the brightest part of the danger zone was at 128 and the picture was over by 137.
It is a rim line now: brightest pixel at **99%**, half brightness still carried at
**98.8%**, fill 0.21 against an edge of 1.00. The size did not move — it cannot,
it is `enemy.swing_wedge_reach()` and SG-119 was paid for by a drawn shape and a
hit shape disagreeing. `.shots/sg159/before` against `.shots/sg159/after`.

### ~~The fire hitbox does not match the fire~~ — DONE 2026-08-03 (board SG-163)
Asked 2026-08-03: *"For the fire hitbox, match the burn size. Fix the picture to
match the damage."*

A pool was drawn at 46 and burned at **78** — it cooked you from 88% outside its
own picture, and the ring of deck around it looked clear. The picture moved and
no balance number did; the burn is the same 78.0 it has always been. There is one
derivation of the radius now (`fire_pool_radius()`), read by the tick, by the
hidden 2D draw and by the renderer. `tools/pool_shot.gd` is the witness and it
measures the burn from the damage path rather than drawing a ring at the constant.

### ~~Crew stand around auto-attacking at the end of a cleared lane~~ — DONE 2026-08-04 (board SG-187)
Asked after a full twelve-wave run: *"Dont have crew standing around and auto
attacking at the end of their lane - we can improve their AI to run towards
available enemies if their lane is clear."*

Two faults, one line. A crewman with nothing to fight was sent to a fixed point
at the head of his lane and the arrival test was `distance <= reach` — a test
that asks how far away his GOAL is and never asks whether anything is standing
in it. So he arrived, wound up, swung at bare planking, recovered, and did it
again for the rest of the wave. He STANDS now, watching the bow; and if his lane
is clear he crosses into the next one, under four rules written at
`SkyGearLanes.ASSIST_LEASH`: his own lane outranks everything and is re-asked
every tick (so the recall is the order of two loops, not a timer); the leash is
exactly one lane spacing measured from his own station; one man per boarder, so
a fight next door cannot collect a mob; and every lane keeps an anchor, so no
arrangement of boarders can empty a lane of its crew.

**And the measured cost of the whole row turned out to be a line nobody asked
for.** Standing still made it visible that every hand in a lane holds the same
station — four sailors inside one another — so the first version fanned them out
by +-120 units. Against a 240-run Heat 0 baseline that ONE cosmetic line took
crew damage share from **6.02% to 4.55%** and damage taken from **346 to 406**,
and it cost the same fanned across the lane as fanned down it, which is what
identifies the mechanism: a stacked watch is four swings on one boarder with no
walking, and 120 units of separation is a second of not swinging per man per
boarder. The fan is refused and the constant deleted rather than zeroed. **The
roaming the ask is actually about costs nothing resolvable** — crew 6.31%
against 6.02%, taken 360 against 346, held 80.4% against 80.0%. Fifteen
`crew ·` checks; `.shots/clips/sg187-before.gif` against `sg187-after.gif`. If
he wants the watch to look like a watch, the honest ways to buy it are a
renderer-side nudge or paying for it somewhere — not that line, quietly.

### Enemy attack telegraphs are missing or much weaker
The browser draws a large teal ellipse on the deck when a boarder winds up. In
the same posed moment Godot draws nothing comparable. Pillar 6 of the design is
that every attack is readable before it lands, so this is the readability item
the whole VFX plan was ranked around.

### ~~AESTHETIC PARITY — the original job~~ — SUPERSEDED BY THE OWNER, 2026-08-01
> *"I want the game screenshots of both versions to be almost identical in
> quality before we consider this job done."*

Closed by a newer instruction, verbatim: *"we can move beyond trying to
achieve visual parity with web v11 — we are now in uncharted and exciting new
territory as we build the Godot version to be better than the web one ever
was."*

What the parity chase accomplished before it was retired: the comparison tool
(`SkyGear Tools.bat parity`, six scenes), the camera proven pixel-exact
(SG-2), the Boiler rescaled (SG-27), telegraphs rebuilt (SG-3), the skill-bar
posing fixed (SG-4), and the lighting/card gaps found (SG-34/35 — both being
worked at the moment the goal changed, redirected mid-flight to "better than,
not identical to"). **The browser is a reference now, not a ceiling.** The
parity tool stays — it answers "did we regress something the browser did
well," which is still a real question; it just no longer defines done.

### 3D models for the remaining objects — MOSTLY DONE, three rejected
Asked for. Ten generated through `tools/meshy.py run props`, 360 credits.

**On the deck now:** the Boiler, the powder keg, the lantern post, the crate
stack, the steam vent, the deck cannon and the salvage pile. `PROP_MODEL` in
`view3d.gd` is the switch; deleting a row puts one back to painted.

**Generated, on disk, deliberately not wired** — each reads worse at the real
camera than the art it would replace, reasoning at the missing row in
`tools/static_model.gd`: the **brazier** (grey rock instead of burning coals, and
238 ground units across), **crate_small** (a bright orange treasure chest), and
the **boarding hulk** (see its own item below).

**Never generated:** `rope_coil`, 30 ground units tall, the shortest thing in
`PROP_HEIGHT`. The prompt is written and costs 30 credits if anyone disagrees.

~~Still worth doing: the REMESH step.~~ Done, and the premise here was wrong:
94% of every file was TEXTURE, not geometry. 218,332 triangles across 17 assets
is 11.5 MB; the other 170 MB was 68 embedded 2048-square JPEGs. 182 MB to 9 MB,
and the exe from 242 to 168. The captain was excluded and that has its own
entry below.

### Text legibility, not containment
Asked for: skills, cards and HUD elements are hard to READ. Distinct from the
text audit, which only proves text is inside its frame — a 7pt label perfectly
contained on textured brass passes that check and is still unreadable. `_fits`
shrinking text to fit is itself a suspect. An agent is measuring contrast and
point size before changing anything.

### Deckwork needs MORE VERBS — the prompt is done
Repairing a dead cannon works and is now findable: the coach announces that a
downed gun can come back (naming the bound key, not a hard-coded R), and a
prompt over the gun says you are standing where it works, with the progress
under it and the reason when it refuses. Three checks, including one asserting
the line carries the live binding and not the raw `{key}` token.

What the ask was actually about — dragging a crate to close a lane,
funnelling, shaping where the fight happens — was built (SG-10, reworked
SG-37, extended by SG-56's winch) and then TABLED by your 2026-08-02 verdict:
"the current push crate mechanic is boring. table that feature for now we can
revisit interactions like that later." (Board SG-68.) The verb TABLE stands —
repair lives in it, and the tabled rows return with one flag when the
interaction pass revisits; new verbs remain one entry each in
`scripts/deckwork.gd`.

### A cloak with cloth physics
Raised again. Godot has `SoftBody3D`, which is the obvious route, but it wants a
mesh with pinned vertices and the captain's rig came out of Mixamo without one.
Options, cheapest first: a bone chain on the existing skeleton driven by her
velocity (no new mesh, no solver, works with the animation blend); a separate
`SoftBody3D` cape pinned to a shoulder bone; or a vertex shader that fakes it.
The bone chain is almost certainly right for a figure this size on screen — at
this camera distance the cape is about forty pixels tall.

**BUILT 2026-08-02 (board SG-23), the bone-chain route as chosen above — left
open here for the owner's eyes on the cloth, like the crate and the lab.**
Four cape bones on a mount at her chest, a 32-triangle skinned banner in
procedural oxblood, a spring chain that trails at a run (1.19 rad, measured),
CRACKS on the dash (2.11 rad — the signature move gets the signature cloth),
sways at the ship's own periods when she stands, and snaps to a bitwise-exact
rest when the sway is off (the framing-check rule). Clamped so it can never
cross her torso at the 41° camera. Captain only, one `HERO_CLOAKS` row per
class — the Boilerwright opts in later with a row, not a build. Seven
`cloak ·` checks; pictures in `.shots/cloak/`.

### Popup menus drifting right — REPORTED, NOT REPRODUCED
Seen while watching screenshot runs go past. I measured it and could not find
it: the pause panel's left edge sits at exactly x=869 and the draft's at x=611,
identical on every frame across eight samples with the ship swaying underneath.
The HUD control does not move and its size does not change.

Two things I can think of that would produce the impression, neither confirmed:
the camera sways continuously (0.42 degrees of yaw, 0.85 of roll), so the WORLD
drifts behind a static menu and the relative motion can read as the menu
moving; or a menu I did not test does it. Needs to know WHICH menu before it
can be chased further.

Left open rather than closed, because "I could not reproduce it" is not the
same as "it does not happen."

### Documentation claims that are not enforceable
From the Fable audit. The pattern is right — every design doc ends with a list
of where the build departs from it — but the claims inside are not checkable, so
they rot silently:

- ~~three documents restate "the whole tree is worth less than three draft cards"
  and the check behind it compares only `crit_chance` (x1.06 against x2.28). It
  cannot fail~~ — **FIXED (SG-11).** `shop · the whole tree is worth less than
  three cards` now measures the real aggregate on both sides: the maxed tree's
  offensive product (crit_chance+range+vent_radius = **×1.31**) against the three
  per-skill cards read from the live catalogue (**×2.28**). Measured fully the
  inequality HOLDS, and a second check `shop · the three-card yardstick is the
  real catalogue, not three typed numbers` keeps the card side from drifting back
  to typed constants. META §4.1 and SHIP-AND-MAPS §7.2 updated to name it.
- ~~`CLASS-2-DESIGN.md` says "BUILT AND COMPLETE" over an omissions list missing
  at least four entries.~~ — **FIXED (SG-11).** Six audited entries added to the
  omissions list (repair budget, the 40-Head allowance, the six per-class cards,
  SUPERHEAT, per-class card gating + label, kegs as a Head source), and the stale
  "Head does not cost Boiler HP" entry corrected (the flat charge is now built).

The audit's proposed rule is the fix and it has been adopted (SG-11): **any claim
of harness coverage must name the check string** — recorded as BOARD rule 2,
extended to design docs, and swept through `skygear-godot/*.md` +
`skygear-godot/docs/*.md` (claims named where a check exists, marked `UNVERIFIED —`
where none does).

### ~~The airstream washes over the sky~~ — FIXED, and it was a bug not a tuning problem
Worth keeping as a record of a wrong diagnosis. This entry assumed the ribbons
were correctly built and merely too wide, and proposed narrowing
`STREAK_SPREAD` — a number three other things are calibrated against.

They were not correctly built. `Basis.scaled()` multiplies the basis ROWS,
which is a scale in the PARENT frame, and the streak basis is a 90 degree
rotation — so the two never lined up. The local X column points down the keel
and scaling the world-X row leaves it untouched, so THE 190-430 UNIT LENGTH WAS
DISCARDED and landed on the athwartships column instead. Forty-eight additive
plates up to 430 units wide ACROSS the ship at head height, sweeping over the
deck.

Found by measuring rather than by eye — `tools/deck_probe.gd -- airsize`
prints wanted against got, and it now reads 366.9 x 1.4 against a wanted
366.9 x 1.38, long axis (0,0,-1) down the keel. Fixed by scaling the columns
at construction. `STREAK_SPREAD` never moved.

### A 3D model for the boarding hulk — TRIED TWICE, SPRITE KEPT
Reported, and attempted: two Meshy generations, 60 credits, both rejected. Both
are on disk at `assets/models/boarding_hulk/` and the full reasoning is at the
missing row in `tools/static_model.gd`. Short version:

v1 came back a submarine. v2 is a good model — a wide armoured box, a round door
open with fire in its throat, a ramp down — and still loses, to something no
prompt fixes. The sprite wins because a billboard **turns to face the camera**,
so all 420 units of the hulk are always presented square-on as a wall of armour
with a glowing hole in it. The mesh is as deep as it is wide; at 41 degrees its
mass goes up out of frame and all that is left on screen is the ramp, lying
across the middle of the deck like a staircase. Posed against the sprite at the
bow and again from mid-deck, it loses both times.

The three states turned out not to be the hard part: the ramps are down in all
three PNGs and the whole difference is the door, and `game.gd` sets
`hulk.vulnerable = true` on the frame it grapples on and never clears it, so
SEALED is currently unreachable. One mesh of the OPEN state plus the painted
wreck would have covered it.

**If this is tried again it should be modelled by hand, not prompted** — it needs
to be much wider and much shallower than text-to-3D will return, with the ramps
as separate low geometry. The renderer wiring is already in place and inert
(`HULK_MODEL` in `view3d.gd`); a wrapped `.tscn` appearing is all it takes.


### The captain's grip on the sword
Reported. `weapon_fit` is interactive now (arrows nudge, ENTER saves) but **the
grip itself has not been re-fitted** — the tool was rebuilt, the number was not
changed. Two minutes in the fitter closes this.

The lab can now show it MOVING, which is the part that was missing: MOUNT, then
play `swing2` and scrub. Nudging is live at whatever frame you paused on, and
SAVE writes `assets/models/weapons.json`.

**A claim that was here and is wrong.** The lab agent reported that at frame 75
of 136 of `swing2` the cutlass sits beside her hip rather than in her fist —
"a grip that only holds at rest". It does not. Measured: the `BoneAttachment3D`
tracks `mixamorig_RightHand` to **0.002 m at rest and 0.002 m at that exact
frame**, and rendering the frame shows her right hand IS down at her hip in
that pose, which is where the sword looked detached. The pose was misread.

What is still possibly wrong is smaller and different: the fit carries a −120°
pitch and no offset, tuned against the rest pose, and a wrist that rotates
through a swing can make a correct attachment read badly. That is a fitting
judgement to make in the lab with the timeline running, not a bug.

### The captain is 30,634 triangles and was skipped by the remesh
Found by the lab, which flags her HEAVY in its own readout. She is **5.7 MB of
the 18 MB the models now cost** — a third of the budget on one asset — and she
is not in `.model_originals/`, so the pass that took every prop from 182 MB to
9 MB never touched her.

Probably correct to have skipped her, and that is the point of writing it down
rather than leaving it implied: decimating a 33-bone skinned mesh risks the
skin weights, and Meshy's remesh would return no rig at all, so the route that
worked for the props cannot be pointed at her. But by that pass's own budget —
`0.021 x px²` at her on-screen height — she should be 3,000 to 8,000 triangles.
She is 4 to 10 times over, and she is the one figure on screen 100% of the
time.

Needs a decision, not silence. The candidates are a skin-weight-preserving
decimation done locally, a hand-authored LOD, or accepting the cost and saying
so here.

### VFX plan items never started — TWO LEFT
From `VFX-PLAN.md`. §3 and §4 landed on 2026-07-31; these two did not:

- **§6 the captain's weapon trail.** The Cleave now draws a sweeping ribbon
  through the air, which covers the swing visually, but it is driven by the
  EFFECT's clock rather than by the `swing` clip through a `BoneAttachment3D` on
  her hand — so it is an arc where the blade approximately is, not a trail the
  blade actually left. The audit's two-layer construction (hot core, wide outer)
  exists in `_beam_ribbon` and would port straight across.
- **§5 chromatic hit and radial blur.** Shake and hit-stop are done. The
  research audit argues against the other two on readability grounds
  (`VFX-RESEARCH-AUDIT.md`, "Screen effects": avoid continuous chromatic
  aberration and radial blur, and if used restrict them to a prewarmed sub-150ms
  boss transition). Not started, and should probably be dropped rather than
  built — but that is a decision, not an omission, and nobody has made it.

### The Boilerwright looks exactly like the captain
Asked for as "a model for the second player class", and it is the one thing on
this list that **cannot** be closed by the Meshy pipeline as it stands.

`SkyGearView3D._sync_captain` loads one constant, `CAPTAIN_SCENE`, for both
classes. So the heavy engineer who built the Boiler is currently a fast
red-coated woman with a cutlass, and the only way to tell which class you picked
is the gauge. `CLASS-2-DESIGN.md` §7 already books him as **commissioned art**
and it is right: he needs the captain's 33-bone Mixamo skeleton and her clip
set, plus the plant/kneel clip §7 names, and a Meshy text-to-3D result has no
skeleton, no clips and no rest pose to retarget from. `tools/static_model.gd`
exists precisely because that is true, and it produces static scenes — a static
scene in `_sync_captain` is a statue that slides around the deck.

Two routes, and the choice has to be made before anyone spends:

1. **Mesh, then Meshy's own rig + animation endpoints** (`/openapi/v1/rigging`,
   then the animation library). Cheapest, but his clips would then be Meshy's,
   not the axe pack's, so his timings would not match hers and `anim_timing.gd`
   measures against skill windows.
2. **Mesh, then retarget the axe pack onto it** through `tools/ingest_model.py`
   and `tools/models.json`, which is how the captain was built and the only
   route where the two classes move on the same clock. Needs the auto-rig to
   come back with Mixamo bone names.

Until that is decided, generating a mesh is 30 credits on step one of three.
Nothing has been spent and no prompt is in the manifest, deliberately: an entry
in `tools/meshy.py` is a thing you can run, and running this one buys an asset
the renderer has no way to display.

**RESOLVED in three landings, the last 2026-08-02.** Route 2 built him (SG-12),
SG-45 made him render, and the owner then answered the follow-up ask — "Two
clips would make him HIM: a kneel/press-to-deck for Tap Main and a heavy
two-handed swing" — by delivering the **Great Sword Pack**: his own mesh
auto-rigged by Mixamo plus 51 native clips, ingested whole as board **SG-74**.
His five slashes are the attack rotation now, and Tap Main plays a real kneel
(`figure · tapping a main plays the plant, and the kneel fits the tap window
like a swing fits its cast`; the delivery film is
`.shots/clips/boilerwright.gif`). What remains of this section is only the
owner's feel-verdict, tracked in NEEDS_ALEX.

### The furnace knight is still a sprite
Two Meshy attempts; neither read as the 180-hp thing you cannot walk through.
Not a bug — a deliberate call — but it is the one boarder breaking the 3D
consistency that was asked for, so it stays here until it is solved or dropped.

### The Workshop is a visual tree now — and Heat is a ladder (SG-14, 2026-08-01)
> *"We need to also work on making the workshop more of a visual tree — love the
> abilities and such, but the menu itself is quite dull/boring. Needs a visual
> pass."*

Done, and the ask listed four things to use judgement about. Three landed: node
state at a glance, rank as rivets, what a node does on hover, the running total
including what a respec returns, and the Articles as their own object — a
sidebar of wax seals on a cord rather than more rows.

**The fourth is now done too.** "Articles and Heat given their own visual
identity rather than more rows" — Heat was a single cycling `ui.choice` row on
the title, the exact treatment the ask objected to. It is now a **ladder**: five
clickable rungs, cleared ones lit brass, the next reachable one teal, locked
ones dim with a padlock that states its unlock rule on hover, and the selected
rung's one sentence spelled out beneath. STOKED (Heat 0) is the ground you stand
on rather than a rung — clicking the rung you are on steps back down to it, and
the header always names where you stand. Mouse-first, keyboard still works,
rebind-safe (menu navigation is not on the gameplay action map). It passed the
title's own audit pass, which it needed: the title is the one screen where a
widget-count change had already produced a COLLIDE. Text audit CONTAINMENT clean
and zero COLLIDE at all four widths with the fullest state posed (three rungs
cleared, the fourth reachable, the fifth locked, the longest blurb selected).

The other candidate fix — **moving the picker into the Workshop** — stays
rejected, not deferred: Heat is a per-run choice made on the way into a run and
the Workshop is where you spend between runs, so putting it there makes you visit
two screens to start.

And the prerequisite is met: **Heat 3, 4 and 5 now exist** as real, cumulative,
tested difficulty modifiers (rungs before the rung display, as the ledger asked)
— Cold Deck (two cards on one reroll), Boarders Aloft (a hulk on waves 4/6/8/10)
and Skeleton Crew (no crew muster, cannons at half health). The balance tool
takes a Heat argument now and reports the difficulty as a distribution: across
six seeds the bot held Heat 0 five times to average wave 11.7, held Heat 3 none
to average wave 10.2, and held Heat 5 none, dying on wave 4 every run.

---

## Done

- **DONE 2026-08-03 — jump straight to any Heat, for testing.** Asked the same
  day: *"to be fair, I've only ever played the game on heat 1, so I don't have a
  lot of information to share. For me, if you're able to just unlock it so I can
  jump to any heat, that would be better for my testing."* **SETTINGS → OPEN ALL
  HEATS → ON**, then pick any rung on the title. It persists in
  `user://settings.cfg`, so it holds across restarts and works in the packaged
  Windows build. The progression gate is NOT deleted — the ladder still climbs
  for anyone who has not switched it on — and **a run played above the rung you
  have earned banks nothing at all**, which is what keeps your save and every
  balance claim in these docs meaning what they meant. Board SG-160.

- **DROPPED — the crate mechanics ("The crate mechanics suck"), by your own
  verdict, 2026-08-02:** *"the current push crate mechanic is boring. table
  that feature for now we can revisit interactions like that later."* The
  entry's own exit clause fired — it said the verb gets dropped with the entry
  as the reason if the SG-37 rework still was not fun, and it was not. The
  first entry to leave this file by the drop door rather than the done door.
  TABLED, not deleted (board SG-68): one flag (`SkyGearGame.CRATE_VERBS_ENABLED`)
  holds the shove verb, the winch verb and THE WINCH fitting dormant — the
  crate stands at its home as an ordinary stowed prop, the coach's shove line
  is quiet, THE BERTHS shows the winch as "TABLED — an interaction pass will
  revisit" (an earned one stays earned), and
  `deckwork · the tabled verbs come back with one flag` proves the whole
  family returns when the revisit comes. The repair verb is untouched.

- **Player projectiles and VFX reading as 2D.** Both halves. The hitscan shapes
  now draw a travelling bolt inside the window the effect already lived for —
  the head runs out along the line and the tail chases it — so a Lance has
  something in the air without the simulation gaining a projectile. And chains,
  beams, sweeps, cones, shockwaves and the Mortar's shell are GEOMETRY now
  rather than decal streaks: strips of triangles whose width is offset
  perpendicular to the line of sight, so they face the camera instead of lying
  on the planking. Every element has its own width, wander, kink and rise, so
  the four are distinguishable by shape and not only by hue. Ground decals stay
  underneath all of them, dimmed — they are still the half that says where on
  the deck a thing will cross you. `VFX-PLAN.md` §3 and §4; nine harness checks,
  all of them on the cap. Whole-frame cost avg 7.6 → 8.4 ms against 16.7.
- **Deck cannons: visible shots and clear health bars.** The shot landed in the
  previous pass; the bar is here. The lane panel in the corner already carried
  the number and the corner was the wrong place for it — it says a cannon is
  dying without saying which of the three guns in front of you it is. Now the
  same number is over the gun as well, in the boarders' own language
  (`_health_bar`, same bed, same ticks), unprojected from the world so it holds
  its size when the wheel pulls the camera back. Hidden at full health. A dead
  gun shows an empty red bed, the word DOWN, and fills the bar back up as you
  repair it; in the world it gets a scorch, a guttering ember and a plume of
  vented steam, so the broken lane reads as broken from across the deck.
- **THE SKYBOX — clouds, a moon, and parallax.** Reported three times. The
  first two passes treated it as a colour problem and the third found out why
  they could not have worked: the browser's `drawEnvironment` stretches
  `assets/env/sky_backdrop.png` over the WHOLE viewport behind the deck, and
  that painting — a moon breaking through cloud upper left, banked purple
  cumulus, a warm ember lower right — is what the player remembers. Its two
  scrolling cloud bands are pinned to the horizon and `CAM.horizonY()` returns
  **-761.58** at 1600x900, so they have been drawn off the top of the screen for
  the life of the build; nobody has ever seen them.

  Here the painting is a **sky shader** rather than a quad: it is sampled by view
  direction through the browser's own projection, so at the shipped framing it
  lands where the browser puts it to the pixel, and being at infinity it cannot
  shear or slide when the wheel pulls the camera back. The parallax comes from
  **six real cloud quads at two real distances** — 300 and 640 metres, the pair
  that turns the browser's 16 and 34 pixels a second into an angular rate at one
  drift speed — so the layers part against each other and against the deck for
  free under the perspective camera. `tools/sky_shot.gd` (or
  `SkyGear Tools.bat sky`) poses the four places the sky is actually visible;
  before and after are in `.shots/sky-before/` and `.shots/sky/`. Measured at
  under 0.1 ms on the GPU, which is inside the noise floor. Seven harness
  checks, `sky · the backdrop is the browser's painting, not a gradient`
  through `sky · the far plane clears the furthest corner of the field`.

- **The sky gradient itself** — the same item, one layer down, and closed by the
  same change. There is no gradient any more except as the fallback for a build
  with the art missing.

- **Sentries drop nothing** — were `passive: true`, firing an invisible beam from
  the player. Now placed at the cursor or auto-dropped.
- **Skill aiming and projectiles** — aim came from the hidden 2D scene; now
  unprojected from the cursor onto the deck plane.
- **UI readability** — the whole HUD rebuilt on a widget layer; text audit across
  16 screens at 4 resolutions, clean.
- **Card text escaping its frame** — three functions disagreed about where the
  brass ends. One `rail()` now, and a tool that fails the build if text leaves a
  frame or two widgets share pixels.
- **Clicking skills to select upgrades did nothing** — there was no widget layer.
- **SFX and character audio inaudible** — mixer ducking, five channels in
  settings.
- **Ice-skating movement** — a forward run cycle played while moving backwards,
  a dash that never stopped, and braking as soft as acceleration.
- **Animation popping and getting stuck on terrain** — root motion was sliding
  the mesh 129 ground units off the simulation's position.
- **Animation speed not matching skills** — clips now stretch to the skill's own
  window; `hub -- timing` measures it.
- **Fullscreen, high resolution by default.**
- **A sword asset** — Meshy cutlass, in her hand via a bone attachment.
- **3D boarders** — four of five.
- **Boiler health prominent** — moved to top centre.
- **Crew and cannons doing too much damage** — rebalanced to meat shields.
- **Enemy health bars and status** — bigger, with drain-timed status chips.
- **The second class** — the Boilerwright, complete.
- **Every 4 waves an event** — 4, 8 and 12, named and announced.
- **Meta-progression** — the Workshop, the Articles, and Heat.
- **A HUD alignment tool** — F4, with sub-element positioning.
- **Old versions demoable on the website.**
- **All the tools in one place** — `SkyGear Tools.bat`.
- **Movement felt slower after the skating fix** — I over-corrected. Braking
  went 2700 to 5200, which stops in 0.05s and reads as glue, and the dash was
  made to exit at exactly walking speed so it covered less ground than the old
  gliding one. 3600 and a 1.55x dash exit; the checks now pin the SHAPE
  (stopping quicker than starting, but not instantly) rather than the numbers.
- **Mousewheel zoom** — pulls the camera back along its own axis rather than
  widening the field of view, so the projection every telegraph and billboard
  height is calibrated against does not move. Out only, never closer than the
  shipped framing.
