class_name SkyGearView3D
extends Node3D

## The three-quarter view, in actual 3D.
##
## THIS IS A CORRECTION. The port rendered the deck as a flat overhead 2D scene,
## and the browser build it is porting has never been that: it hand-writes a
## perspective camera in Canvas 2D — height 760 above the deck, pitched 0.72 rad
## (41°), focal length 1320, dividing by depth — and paints every character as an
## upright billboard standing in it. `docs/LEVEL-KIT-BRIEF.md` calls the camera
## settled and locked, and every sprite in `assets/` was generated for it: figures
## painted 10–15° above horizontal so they read as standing on a deck seen from
## 41°, not as lying on it.
##
## Rendering that art straight down was showing the right pictures through the
## wrong camera. It is also the one thing an engine should not have to fake, and
## faking it was the browser's constraint, not ours.
##
## So: a real Camera3D at the same pitch, a real ground plane, and Sprite3D
## billboards. The simulation is untouched — it still runs in ground-plane
## coordinates in the 2D scene, and every one of the 44 parity checks still
## drives it directly. This node only mirrors that state into a 3D scene each
## frame. Ground (x, y) becomes world (x, 0, y); y is depth, exactly as in the
## browser's TUNING comment.

## --- the camera, solved from the browser's own numbers -----------------------
## An earlier version of this file guessed at framing ("lower and closer gives
## the same composition") and it did not: it put the cargo runs in the lens as
## black slabs and cropped the deck to a corridor. The browser is not doing
## anything mysterious, so there is nothing to guess at — its `CAM` is a pinhole
## with four constants and one solve, and all of it ports exactly.
const PITCH := 0.72                 ## radians below horizontal. Locked. See the brief.
const CAM_HEIGHT := 760.0           ## ground units above the deck  (browser: CAM.h)
const CAM_NEAR := 460.0             ## camera to focus point, along the deck (CAM.near)
const FOCAL := 1320.0               ## focal length at reference scale  (CAM.f)
const REF_HEIGHT := 860.0           ## the height that focal length is quoted at
const STAND_FRAC := 0.60            ## where the captain sits, as a fraction of screen
const CAM_TAU := 0.155              ## follow smoothing, seconds  (FEEL.camTau)
const WORLD_SCALE := 0.01           ## ground units -> metres, so Godot's units stay sane

## Cargo modules are tiled down a run rather than stretched over a box, which is
## what the browser does and the reason its crates read as lashed cargo instead
## of as a wall with a picture on it.
## Visual layers. Layer 1 is the ship; layer 2 is anybody standing on it.
##
## Decals project onto whatever geometry is inside their box, which is the whole
## point of them — and the captain, the crew and every boarder are inside those
## boxes. A mortar ring was being painted across her chest, the aura washed the
## crew to cream, and every contact shadow darkened the person standing on it.
## Splitting the layers is the fix: a ring belongs on the deck.
const LAYER_WORLD := 1
const LAYER_FIGURES := 2
## Contact shadows get their own layer so the effect decals do not project onto
## them — a mortar ring painted across a boarder's shadow is a ring that looks
## like it is on the deck twice.
const LAYER_SHADOWS := 4

## How tall each prop stands, in ground units. The browser's `PROP_H`.
const PROP_HEIGHT := {
	"keg": 100.0, "crate": 84.0, "crates": 148.0, "rope": 30.0, "lantern": 200.0,
	"brazier": 116.0, "mast": 340.0, "railing": 52.0, "hatch": 44.0,
	"ballista": 118.0, "vent": 52.0, "wreck": 210.0,
}

## Which deck props have a generated mesh: prop_type -> the directory under
## `assets/models/`. A prop_type with no row here keeps its painted billboard.
##
## THIS TABLE IS THE SWITCH, and it is the same switch `tools/static_model.gd`
## documents for the boarders: the bar a generated mesh has to clear is the art
## it replaces, not the previous generation of itself, and the furnace knight is
## on the deck as a sprite because it never cleared it. Deleting a row here puts
## a prop back to painted with no other change.
##
## The keys on the right are the ART filenames rather than the prop_type strings.
## That is deliberate: what a reviewer does with one of these is hold it up
## against `assets/art/props/<key>.png`, and a name that does not match the file
## you are comparing it to makes that harder for no gain. The two exceptions are
## named where they are used below.
const PROP_MODEL := {
	## barrel.png is the powder keg — the fuse chimney, the pressure gauge and
	## the red flame triangle are all painted on it — so there is one model for
	## it and it is called what the object is.
	"keg": "powder_keg",
	"crates": "crate_stack",
	"lantern": "lantern_post",
	"vent": "steam_vent",
	## "crate" and "brazier": the SG-64 re-rolls with the v1 rejection reasons
	## written into the prompts. Both cleared the bar this time — verdicts, and
	## the v1 history they were re-rolled against, at tools/static_model.gd.
	"crate": "crate_small",
	"brazier": "brazier",
	## rope: NOT generated. 30 ground units tall, the shortest thing in
	## PROP_HEIGHT by a factor of two. A billboard of a flat coil of rope and a
	## mesh of one are the same forty pixels at this camera. The prompt is
	## written and waiting in tools/meshy.py; nobody has paid for it — and the
	## SG-64 wave, capped at 200 credits, spent its budget on the mast, the
	## ballista and the reopened rejections instead (the board row has the
	## priority order: smallest screen presence goes last).
	## railing (52u x4), hatch (44u x2): still painted, next-smallest presence,
	## unfunded this wave — SG-66 has the queue.
	"mast": "mast_section",
	"ballista": "harpoon_ballista",
	## SG-72, half of it. The railing WON at the real camera on its second roll
	## (v1 arrived on a timber plinth and read as a bench lying at the rail);
	## v2 stands free, dark, and shows the deck through its rods.
	"railing": "railing_segment",
	## "hatch": NOT generated, and REJECTED rather than unfunded — three rolls,
	## the verdict at tools/static_model.gd. It is the rope coil's argument one
	## size up: a hatch cover lies FLAT in the planking, so at the locked 41
	## degree camera essentially everything the player sees of it is its own top
	## face, and a top face is a texture either way. All three rolls came back
	## with DEPTH the object must not have and read as a fifth kind of small
	## crate on a ship that already carries four.
}

## The deck cannons and the salvage pickups are not in the `props` group, so they
## are not reached by prop_type. Named here so all of the generated deck geometry
## is switched from one screenful.
const TURRET_MODEL := "cannon_deck"
const SALVAGE_MODEL := "salvage_pile"
## The enemy's boarding craft. Wired at the hulk block near the bottom of
## `_sync_all`, where the three painted states are chosen between — and INERT
## for the whole port until 2026-08-02, because two generations were rejected
## and `tools/static_model.gd` deliberately wrapped no scene for it. The wiring
## stayed for the same reason `_sync_rig` stays for the furnace knight: the
## model-or-billboard fork is the permanent shape of this renderer, and the next
## attempt should be a FILE APPEARING rather than a code change. Three files
## appeared. This is what the fork was kept for.
##
## THE BOARDING HULK, one model key per painted state — board SG-76, and the
## owner modelled all three himself after three prompted attempts failed to buy
## even one (`handoff-3d/README.md` carries that history). `game.hulk_state()`
## names the row.
##
## HULK_RULER is the state every one of them is SCALED by. SG-79's rule is that
## a prop covers `height_units` of screen at the shipped camera, measured from
## its own three-axis span — and the three states have honestly different spans
## (the sealed face carries a deep chevron, the wreck has lost its roof), so
## scaling each by its own would swing the silhouette 430 -> 529 -> 550 ground
## units of width across the fight. They are ONE OBJECT wearing three faces:
## one ruler, measured on the state the player actually fights, and the swap is
## a face changing rather than the wall growing.
const HULK_MODELS := {
	"sealed": "boarding_hulk_sealed",
	"open": "boarding_hulk_open",
	"destroyed": "boarding_hulk_destroyed",
}
const HULK_RULER := "boarding_hulk_open"
## The painted fallback's own height, which is the 420 this block used for
## everything until SG-140. Kept for the plate tier only — see the call site.
const HULK_PLATE_HEIGHT := 420.0
## SG-139. How long a broken hulk takes to settle, and what it settles AT.
## The residual is not zero and the call site explains why at length: the
## simulation keeps a dead hulk's hull solid, so an invisible wreck is an
## invisible wall.
const WRECK_FADE_TIME := 2.2
const WRECK_RESIDUAL := 0.28

## The Boiler. Until now the ONLY object in the port with no art at all — four
## cylinders, two toruses, a box and a quad assembled in `_build_boiler` — and at
## the bottom centre of every frame at the largest apparent size of anything on
## the deck, which made it read as placeholder next to thirty painted assets.
##
## The height is NOT a taste number and must not be raised casually — it is
## PINNED to the LIVE browser's `boilerH`, which is what `tools/parity.py`
## photographs (storm-dusk-v11.html), and `tools/boiler_measure.gd` /
## `parity_test` guard the rendered result against it. SG-27 caught this at 168:
## the generated mesh is a near-cube (measured 168 tall x 167 wide x 162 DEEP),
## so at 168 it read 208 px tall and 291 px wide — a solid drum dominating the
## lower third against the browser's FLAT 150-unit / 184 px block, exactly the
## "everything looks bigger" report once SG-2 cleared the camera. Scaled to the
## browser's own 150 the mesh's furnace face (authored to +Z, the one direction
## this locked camera ever sees) still reads as the furnace and now sits at the
## browser's height. NOT 168, and never a bare "buys the pipes" bump again: the
## number is whatever the LIVE browser draws, so the two builds stay one picture.
## (DESIGN §13c cites 132 — that was the v3/v4 preset; the LIVE v11 build moved
## boilerH to 150, and parity compares against v11.) The first 3D pass built a
## 300-unit drum that hid the captain for the first second of every run — she
## spawns 130 units in front of this thing; the browser's own 150 does not.
const BOILER_MODEL := "boiler"
## The LIVE browser's PRESET.boilerH (storm-dusk-v11.html / reference/web-source
## build.py v11). The Boiler renders at exactly this in ground units, mesh or
## primitive, and `parity_test` fails if the rendered subtree drifts off it.
const BOILER_HEIGHT := 150.0

## THE COLOSSUS WRECK — board SG-15, the first fitting in docs/SHIP-AND-MAPS-DESIGN.
##
## The design doc's whole thesis in one object: the ship carries the memory of
## the runs it survived, and the Colossus is the boss you kill to survive one.
## The art has been on disk and sized (`colossus_wreck.png`, PROP_HEIGHT/SCALES)
## since the props pass and NOTHING has ever placed it. This places it — and it
## is the ONLY generated deck geometry here whose position is a fitting rather
## than a prop, so it is switched from one screenful like the rest.
##
## WHERE, AND WHY NOT WHERE THE DOC SAYS. §5 wants it "in lane 1, in front of the
## Boiler" as 210 units of hard cover. A permanent fitting may not do that: the
## gameplay envelope (the three lanes, `game.cargo_rects()`, the boarder clamp,
## the prop-per-wave count) is the one collision source of truth and a fitting is
## set dressing that must not touch it. So among the off-envelope homes it is put
## OFF THE BOW, beyond the play area, resting in the cloud sea ahead — the one
## spot that reads as a landmark at the shipped 41 deg camera. MEASURED, not
## guessed (tools/wreck_measure.gd): the stern sits off the bottom of the frame
## at every pose and the rails off the sides, but the bow fills the top of the
## frame the instant the captain advances toward it, and it is the establishing
## crane's subject and where the Colossus itself arrives and falls. The corpse of
## the giant, adrift ahead of the prow, every run after the first you down it.
##
## GATED, because the doc is not silent: fittings are meta-progression and live
## behind `state.unlocked` — the SAME first-victory latch the Workshop opens on
## (a win is a wave-12 Colossus kill). SINCE SG-56 the wreck is the berth
## system's first resident: earned by that same win, it occupies a berth like
## the other five and shows while berthed (`_wreck_berthed` reads the run's
## snapshot; `SkyGearWorkshop.load_state` migrates pre-berth winners' saves).
## Delete its `SkyGearFittings.FITTINGS` row and these rows and it is gone.
const WRECK_TEXTURE := "res://assets/art/props/colossus_wreck.png"
## Ground units. Bow edge is DECK_RECT.position.y = -1160; the spawn line is
## -1115 and the hulk grapples at BOW_Y -1000, so -1500 is 340 beyond the deck,
## 385 beyond where anything spawns — wholly outside the fight envelope.
const WRECK_POSITION := Vector2(0.0, -1500.0)
## Its authored height is PROP_HEIGHT["wreck"]; read from there so the fitting and
## the prop table can never disagree about how tall the same picture stands.

## THE TRANSPORT FLEET — the owner's own five ships, and the FIRST geometry this
## renderer puts outside the hull entirely.
##
## His ask, and the reason the two tiers below are two tiers: *"I was thinking
## more of having the sky ships be visible in the distance and below the player
## ship and then for each wave maybe just having a ship pull up to the front and
## a bunch of enemies jump off. I just think that ships in the distance can make
## the sky and the game feel more intense and lived in."* An ambient fleet that
## does nothing is what makes the one that pulls up MEAN something.
##
## THIS IS THE AMBIENT TIER ONLY. Nothing here spawns, schedules or carries a
## boarder; the arrival choreography is the ledger's "Boarders should ARRIVE, not
## appear" and it has to be presentation over an UNCHANGED deterministic seeded
## queue, the same bargain the deaths keep. What this owes that work is a mark to
## hit, and `SKYSHIP_BOW_HOLD` below is it.
##
## WHERE THEY CAN BE, AND IT IS MEASURED. `tools/skyship_probe.gd` swept 140
## stations against six real play poses at both zooms — not the four sky poses,
## which are where the SKY is visible and not where a run is spent. The verdict
## is narrow and it is the whole reason these positions look lopsided:
##
##   * AHEAD, ALWAYS. Every station at z >= 0 — abeam or astern — is in frame
##     from at most 3 of the 12 pose/zoom pairs, and most from none. The camera
##     is 460 units astern of its focus looking 41 degrees DOWN the deck: there
##     is no sideways left to see with. 63 of the 140 stations are visible from
##     no pose at all.
##   * AND BELOW. The top of the frame looks 23 degrees below horizontal, so at
##     3,000 units ahead everything above y = -510 is off the top of the picture.
##     That is the fact that hid the skybox three times (`tools/sky_shot.gd`) and
##     it is not negotiable; it is also why a fleet "in the distance" has to be a
##     fleet BELOW, which is what the owner asked for in the same sentence.
##
## So the band is a wedge off the bow between about 2,500 and 6,000 units ahead,
## 700 to 2,100 below, and out to ~2,400 either side. Everything here sits in it,
## spread in depth so the four parallax against each other and against the two
## cloud layers for free.
##
## y IS THE KEEL. `tools/static_model.gd` stands each hull's measured floor at
## its scene origin, so the number in a row is how far the bottom of that ship is
## below the planking — the number you can reason about when you are asking
## whether a mast clears the top of the frame.
##
## DELETE A ROW AND THAT SHIP IS GONE; empty the table and `_build_skyships`
## builds nothing and the frame is what it was. No other system reads it.
const SKYSHIPS := [
	## THE CUTTER, nearest and to port — the knife, and the one hull whose
	## silhouette survives being small. 900 units at this station is 423 px of
	## screen, the largest of the four, which is what `tools/skyships.py` sizes
	## the whole fleet's texture budget against.
	{"model": "skyship_cutter", "at": Vector3(-1250.0, -950.0, -2600.0),
		"length": 900.0, "yaw": 180.0, "heave": 26.0, "period": 7.3},
	## THE SKIFF, starboard and a little further out. The small disposable one,
	## so it is the one that reads as "there are lots of these".
	{"model": "skyship_skiff", "at": Vector3(1500.0, -1150.0, -3400.0),
		"length": 700.0, "yaw": 180.0, "heave": 34.0, "period": 5.9},
	## THE BARGE, far to port and lowest but one — 1,400 units, the length the
	## handoff allows only this archetype, so distance is what keeps it from
	## dominating. Its four rotors are separate meshes (`Rotor1`..`Rotor4`) and
	## nothing turns them yet.
	{"model": "skyship_barge", "at": Vector3(-2100.0, -1650.0, -4600.0),
		"length": 1400.0, "yaw": 180.0, "heave": 18.0, "period": 9.7},
	## THE TENDER, farthest and deepest, off the starboard bow — the scrap-built
	## one. Deliberately the least legible station: it is the ship you notice
	## third, and a fleet with nothing at the back of it is a row of four.
	{"model": "skyship_tender", "at": Vector3(2400.0, -2100.0, -5600.0),
		"length": 800.0, "yaw": 180.0, "heave": 22.0, "period": 8.4},
	## `skyship_barge_heavy` is ingested, budgeted and checked and is NOT here.
	## It is the second barge; four archetypes is what the handoff asked for and
	## a fifth hull in the same wedge is traffic. One row brings it back.
]

## Where a transport should HOLD STATION when it comes forward for a wave, and
## nothing in this file reads it yet. It is here because the measurement that
## found it was made here and would otherwise have to be made twice: the bow is
## the one direction that is on screen from every pose at both zooms, which makes
## it the safe placement and the reason the arrival tier will work even though
## the ambient tier had to be argued for. 2,600 units ahead of the deck centre is
## 1,440 beyond the bow edge and 1,485 beyond the spawn line — clear of the
## gameplay rectangle, the cargo rects and the boarder clamp by a wide margin —
## and 520 below puts its deck a little under ours, which is the direction you
## want figures to jump FROM.
const SKYSHIP_BOW_HOLD := Vector3(0.0, -520.0, -2600.0)

## --- THE ARRIVAL TIER (board SG-134, stage one) -------------------------------
##
## The owner, twice: *"having a ship pull up to the front and a bunch of enemies
## jump off"*. `SKYSHIPS` above is the ambient half of that sentence and shipped
## as SG-102; this is the other half's first stage — A SHIP PULLS UP. Nothing
## here jumps, nothing here spawns, and nothing here is read by the simulation.
##
## WHICH HULL IS THE ARRIVAL SHIP — A DEFAULT, AND IT IS AWAITING ALEX'S CHOICE.
## `/NEEDS_ALEX.md` decision 5 has asked which ship is the arrival ship since
## SG-102 and he has not named one. `docs/BOARDING-ARRIVAL-DESIGN.md` §6 lays out
## three answers; this is (b), its recommendation — **one of the four hulls
## already flying comes forward per wave, and its ambient station goes empty
## while it is away.** THAT SECOND CLAUSE IS FREE AND IT IS THE POINT: the hull
## on the bow is the same node as the hull missing from the wedge, so "a ship
## pulled up" and "the fleet is one short" are one fact told twice, and neither
## can drift from the other.
##
## Three properties of picking (b) rather than (a) or (c), all of which are why
## this can be a default instead of a block:
##
##   * IT ANSWERS NO OTHER OPEN QUESTION BY ACCIDENT. `skyship_barge_heavy` stays
##     on the bench, so decision 3 — is the sixth hull allowed off it — is left
##     exactly where it was rather than being settled by a stage-one commit.
##   * IT IS ONE CONSTANT TO OVERRULE. Cut this list to a single entry and the
##     feature is answer (a), a dedicated arrival ship, with no other edit.
##   * IT CLAIMS NO CHANNEL NOBODY HAS MEASURED. Answer (c) — the hull SAYS what
##     is coming — needs the hull to be legible from the poses a run is spent in,
##     and §6 is blunt that from mid-deck at zoom 1.0 the deck is 100% of the
##     frame. That is SG-139's row, after a number.
##
## THE ORDER IS BY HOW FAR THE HULL TRAVELS, LONGEST FIRST, and that was a
## MEASUREMENT rather than taste. The first draft of this list started with the
## cutter on the reasoning that it is nearest and reads largest — and the frames
## said no: **the cutter's ambient station is already at z = -2600, the hold's own
## depth, and at keel -950 it is already at the hold's own height.** Its entire
## arrival is a sideways slide. The wave that TEACHES the mechanic cannot be the
## one where nothing approaches, so the order runs
##
##   tender  z -5600, keel -2100   — 3,000 forward and 1,150 up
##   barge   z -4600, keel -1650   — 2,000 forward and  700 up
##   skiff   z -3400, keel -1150   —   800 forward and  200 up
##   cutter  z -2600, keel  -950   —   sideways only
##
## so wave 1 is the biggest approach in the fleet and the smallest lands on wave
## 4, by which point the player knows what she is looking at. Pinned by
## `arrival · wave one brings the hull with the furthest to travel`.
const ARRIVAL_HULL_ORDER := ["skyship_tender", "skyship_barge",
	"skyship_skiff", "skyship_cutter"]

## How long the hull takes to come forward, in seconds of the SIMULATION's own
## wave clock. Long enough to read as a ship manoeuvring rather than a decal
## sliding, short enough that it is on station before the first boarder is.
const ARRIVAL_APPROACH := 2.6

## WHERE THE ARRIVING HULL'S DECK SITS — and this is a CORRECTION to
## `SKYSHIP_BOW_HOLD`, found by being the first thing ever to read it.
##
## THE BUG IN THE MARK. Every `y` in `SKYSHIPS` is a KEEL: `tools/static_model.gd`
## stands each hull's measured floor at its scene origin, so the number in a row
## is how far the BOTTOM of that ship is below the planking. `SKYSHIP_BOW_HOLD`
## was written in the same units — y = -520, with the reasoning *"520 below puts
## its deck a little under ours, which is the direction you want figures to jump
## FROM"*. But a keel 520 down is not a deck 520 down; the deck is the keel plus
## the hull's own height, and the hulls measure 205 to 465 ground units tall. Put
## the cutter's KEEL at -520 and its masthead is at -315 — against a frame
## ceiling that the same file measures at about -510 at this range. **The entire
## hull is above the top of the picture and what reaches the player is the last
## few units of its underside.** Photographed before this line existed:
## `.shots/sg134/bow-z1.00-hold.png` on commit c486000's tree.
##
## So the mark the arrival tier hits is the hull's DECK, and its keel is DERIVED
## per hull — which is also the only version of this that makes four hulls of
## three different heights read as the same manoeuvre instead of as four
## different ones. `SKYSHIP_BOW_HOLD` keeps the x and z it was measured for; only
## its y is superseded, and only for this tier.
##
## AND THE NUMBER IS NOT CHOSEN, IT IS THE FLEET'S OWN CEILING. -745 is the
## HIGHEST MASTHEAD IN THE AMBIENT WEDGE — the cutter, keel -950 and 205 ground
## units tall — and SG-102's 140-station sweep photographed that station from all
## six play poses at both zooms and found it in frame from the bow and the port
## rail at zoom 1.0. The arrival hull is held to it so that it never asks for
## more of the picture than a hull the fleet already proves is visible. Typed
## once here and pinned to the measured fleet by
## `arrival · the hold sits at the fleet's own measured ceiling, not at a chosen
## height`, which re-measures every hull and fails the day one of them moves.
const ARRIVAL_DECK_Y := -745.0


## WHERE ACROSS AND HOW FAR AHEAD — AND IT IS NOT `SKYSHIP_BOW_HOLD`'s x AND z,
## WHICH IS THE SECOND CORRECTION THIS TIER OWES ITS OWN MARK.
##
## `SKYSHIP_BOW_HOLD` is x = 0, DEAD AHEAD, on the reasoning that *"the bow is
## the one direction that is on screen from every pose at both zooms"*. That is
## true of the FRUSTUM and false of the picture, and the file it is written in
## says why four paragraphs earlier: `tools/skyship_probe.gd`'s own header warns
## that the analytic sweep "cannot see the SHIP'S OWN HULL — a transport below
## and abeam is inside the frustum and behind forty metres of opaque deck, and
## the only instrument that reports that is a photograph." Dead ahead and below
## is the one bearing where the thing in the way is OUR OWN BOW, and it is the
## bearing the whole mark was placed on.
##
## Photographed: with the hold at x = 0 the tender projects to screen (960, 633)
## from the bow pose at zoom 1.0 — the middle of the planking — and nothing
## whatever is drawn there. `.shots/sg134/bow-z1.00-hold.png` and
## `bow-z1.55-hold.png` on commit c486000's tree carry it; the frame is all deck
## below the prow and all sky above it, and the ship is on the wrong side of the
## line.
##
## THE FLEET ALREADY KNEW THE ANSWER. Every one of SG-102's four stations is well
## off the centreline — |x| from 1,250 to 2,400 — and they read, which is the
## 140-station sweep's actual verdict rather than the summary of it. So the hold
## takes the CUTTER'S OWN BEARING, the nearest and most legible of the four, and
## moves 400 units further forward so that a hull sitting on it is unmistakably
## ahead of the wedge rather than in it.
##
## It is still "a ship pulls up to the front": 3,000 units off the bow and 745
## below, which is forward of every ambient station and the only place a
## transport can be both close and seen.
const ARRIVAL_HOLD_XZ := Vector2(-1250.0, -3000.0)


## The station an arriving hull of this height holds, in ground units. One place,
## so the shot tool, the harness and the renderer cannot hold three opinions.
static func arrival_hold(tall: float) -> Vector3:
	return Vector3(ARRIVAL_HOLD_XZ.x, ARRIVAL_DECK_Y - maxf(0.0, tall),
		ARRIVAL_HOLD_XZ.y)


## WHICH HULL COMES FORWARD FOR THIS WAVE, or "" for none.
##
## Reactive, and off the WAVE NUMBER alone — never off the spawn queue. The
## design kills a predictive berth planner by name: reading a copy of the queue
## to know what is about to spawn is a second implementation of the wave
## scheduler living in the renderer, and `_update_wave` gates popping on
## `enemy_count() < 64`, so that second copy desynchronises exactly when the deck
## is fullest and the mistake is most visible.
##
## THE BOSS NEVER GETS ONE. Wave 12 is `{"boss": true}`, owns a cutscene
## (`cue("boss_arrival")`), SG-119's fixed wedge and the SEGMENTED shadow path,
## and a transport sliding across that is three fights at once.
static func arrival_hull_for_wave(wave: int) -> String:
	if wave < 1 or wave > SkyGearData.WAVES.size():
		return ""
	if bool(SkyGearData.WAVES[wave - 1].get("boss", false)):
		return ""
	return str(ARRIVAL_HULL_ORDER[(wave - 1) % ARRIVAL_HULL_ORDER.size()])


## HOW FAR FORWARD THE HULL IS — 0 at its ambient station, 1 at the bow hold.
##
## A PURE FUNCTION OF TWO NUMBERS THE SIMULATION ALREADY KEEPS, and that is the
## whole of its clock. No accumulator, no `Time.get_ticks_msec()`, nothing to
## drift: `tools/still.gd` freezes it by construction rather than by hope
## (STATUS failure mode five, four prior instances), and two runs of a screenshot
## tool agree because there is nothing for them to disagree about — SG-133's
## complaint, which was exactly a renderer holding a clock of its own.
##
## THE DEPARTURE RIDES THE SIM'S OWN WAVE-CLEAR COUNTDOWN rather than a second
## timer of the same length. `wave_clear_time` counts DOWN from
## `SkyGearGame.WAVE_CLEAR_TIME` to zero and then the draft opens, so reading it
## directly means the hull is back on station on the frame the draft appears, and
## the day that number moves the ship moves with it.
static func arrival_u(wave_time: float, wave_clear_time: float) -> float:
	if wave_clear_time >= 0.0:
		return _arrival_ease(clampf(wave_clear_time
			/ maxf(0.001, SkyGearGame.WAVE_CLEAR_TIME), 0.0, 1.0))
	return _arrival_ease(clampf(wave_time / ARRIVAL_APPROACH, 0.0, 1.0))


## Ease in and out, so the hull leans out of its station and settles into the
## hold instead of starting and stopping at full speed. `SkyGearCutscene`'s
## `inout` shape, which is the one every other move in this project uses.
static func _arrival_ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


## ═══ THE DROP ═══════════════════════════════════════════════════════════════
##
## Stage 3. A boarder is drawn crossing from the transport to the planking
## instead of standing on the planking from its first frame — the half of the
## ask the owner has now made three times, most recently as *"why cant you make
## the enemies jump off the boarding ship and land on deck"*.
##
## RENDERER ONLY, AND THE PROPERTY THAT MAKES THAT SAFE. The simulation already
## holds a boarder still and untouchable for `SkyGearEnemy.ARRIVAL_TIME`:
## `state == "climb"` zeroes its velocity and `can_be_hit()` is false, and every
## path that can reduce a boarder's health consults it. So nothing here changes
## what can be damaged, what can be reached, or where anything is. What it
## changes is where the MESH is drawn during a window the simulation has already
## declared inert.
##
## THE LANDING POINT IS A PARAMETER, NEVER A MEMBER. `arrival_arc_ground` is
## handed `land` and re-read from `enemy.global_position` on every frame, so a
## boarder shoved by a STEAM push or knocked by a Cleave bends its arc mid-flight
## and CANNOT land anywhere but on the spot the simulation already believes it
## occupies. That is bounded by construction rather than by a tolerance — there
## is no stored endpoint to go stale, because there is no stored endpoint. The
## design's killed `_build_berth_plan`, which would have predicted the spawn
## queue 2.2 s ahead, is the version of this that has state to desynchronise.
##
## AND IT HOLDS NO CLOCK. Every function below is a pure function of
## `enemy.state_time`, which the simulation owns and counts down, exactly as
## `arrival_u` is a pure function of the wave clock. `tools/still.gd` freezes the
## drop by construction, and two runs of a screenshot tool agree because there is
## nothing for them to disagree about (STATUS failure mode five).

## HOW HIGH THE ARC GOES over the planking, in ground units, and WHEN it stops
## climbing as a fraction of the crossing.
##
## READABILITY SET THESE, NOT SPECTACLE, and the ordering matters: Pillar 6
## outranks atmosphere, so the arc is shaped around the ring rather than the ring
## being fitted around the arc. The apex is EARLY (just past halfway) and the
## horizontal lead is FRONT-LOADED (below), which together mean the boarder is
## essentially over its own landing ring by the time it starts to fall. The last
## third of the crossing is a near-vertical drop onto a mark that is already
## closed — the player reads WHERE from the ring and WHEN from the falling
## figure, and the two cues point at the same pixel instead of competing.
##
## 300 is deliberately modest against `SHADOW_LIFT_SPREAD`'s 300 and
## `SHADOW_LIFT_FADE`'s 220: at the apex the contact mark is exactly twice as
## wide and 2.36 times as faint as the one under a standing boarder, which is a
## clear read without the mark dissolving. A taller arc buys a more dramatic
## silhouette and costs the mark — and if the choice ever has to be made again,
## the answer is to cut the height, not the ring.
const ARRIVAL_ARC_APEX := 300.0
const ARRIVAL_ARC_APEX_U := 0.52

## How front-loaded the horizontal crossing is. `1 - (1-u)^LEAD`: at LEAD = 1 the
## boarder travels at constant speed and is still moving sideways as it lands,
## which reads as a figure being slid into place. At 2.4 it has covered 82% of
## the distance by the apex and the remainder while dropping — a leap that
## commits early and comes down, which is what a jump looks like and, more to the
## point, what keeps the descent over the ring.
const ARRIVAL_ARC_LEAD := 2.4

## How far a boarder may bow off the straight line between the transport and its
## mark, at the widest point, in ground units. Zero would send a batch of eight
## down eight parallel rails — a conveyor belt, not a boarding party. It closes
## to nothing at both ends by construction (`sin(PI*u)`), so it can never move
## where a boarder lands.
const ARRIVAL_ARC_SWAY := 130.0


## HOW FAR THROUGH THE CROSSING — 0 as the boarder leaves the transport, 1 as it
## lands. `state_time` counts DOWN from `ARRIVAL_TIME`, so this inverts it; the
## window is read off the simulation and never restated here, the same rule
## `arrival_ring_closing` follows.
static func arrival_arc_u(state_time: float) -> float:
	return 1.0 - clampf(state_time
		/ maxf(0.05, SkyGearEnemy.ARRIVAL_TIME), 0.0, 1.0)


## HOW HIGH OFF THE PLANKING, in ground units. Negative early, and that is the
## point: `ARRIVAL_DECK_Y` is where the arriving hull's DECK sits and it is
## BELOW ours (the stage-1 kill test is "masthead strictly below y = 0"), so a
## boarder starts under our rail and climbs onto the deck rather than dropping
## out of the sky onto it. It crosses zero about a quarter of the way through,
## which is roughly when it clears the bow and becomes worth looking at.
##
## Two arcs, not one parabola, because one parabola cannot have both a chosen
## apex height and a chosen apex time when the start and end heights are 1,045
## units apart — a real ballistic curve from 745 below to 300 above would put the
## apex almost at the landing. The climb eases out (a leap decelerating) and the
## fall accelerates (`1 - d²`), so there is a beat of hang at the top and then a
## committed drop.
static func arrival_arc_lift(state_time: float, spread: float = 1.0) -> float:
	var u := arrival_arc_u(state_time)
	var apex: float = ARRIVAL_ARC_APEX * maxf(0.1, spread)
	if u >= ARRIVAL_ARC_APEX_U:
		var d: float = (u - ARRIVAL_ARC_APEX_U) \
			/ maxf(0.001, 1.0 - ARRIVAL_ARC_APEX_U)
		return apex * (1.0 - d * d)
	var r: float = u / maxf(0.001, ARRIVAL_ARC_APEX_U)
	return lerpf(ARRIVAL_DECK_Y, apex, 1.0 - (1.0 - r) * (1.0 - r))


## WHERE ON THE DECK PLANE the boarder is drawn on its way in.
##
## `land` IS THE PARAMETER THAT MAKES THIS SAFE. It is `enemy.global_position`,
## passed fresh every frame and stored nowhere, so at u = 1 this returns exactly
## the simulation's own position — bit for bit, not within a tolerance — and no
## amount of shoving mid-flight can put the mesh anywhere else at landing.
##
## The launch end is `ARRIVAL_HOLD_XZ`, the station stage 1 parks the hull on. It
## is a constant, so this is a pure function of the sim's clock and the sim's
## position and nothing else.
static func arrival_arc_ground(land: Vector2, state_time: float,
		sway: float = 0.0) -> Vector2:
	var u := arrival_arc_u(state_time)
	var travel: float = 1.0 - pow(1.0 - u, ARRIVAL_ARC_LEAD)
	var at := ARRIVAL_HOLD_XZ.lerp(land, travel)
	if sway != 0.0:
		var run := land - ARRIVAL_HOLD_XZ
		if run.length_squared() > 1.0:
			at += run.normalized().orthogonal() \
				* sway * ARRIVAL_ARC_SWAY * sin(PI * u)
	return at


## PER-FIGURE VARIATION, and it is hashed off the boarder's INSTANCE ID rather
## than off its landing position, which is a deliberate departure from the
## design's wording.
##
## The design says "hashed from the rounded ground position". That bakes nothing,
## which is right — but it makes the hash a function of a value that MOVES: a
## boarder knocked across a grid boundary mid-flight would have its apex and its
## bow change between one frame and the next, which is a visible pop, and the
## whole point of re-reading the endpoint is that being shoved must bend the arc
## smoothly. The instance id is free, stable for the life of the boarder, unable
## to be disturbed by anything the player does, and the file two hundred lines
## down already uses it for exactly this (`phase`, the billboard cycle offset).
static func arrival_arc_sway(id: int) -> float:
	return float(id % 61) / 30.0 - 1.0


static func arrival_arc_spread(id: int) -> float:
	return 1.0 + 0.16 * (float((id / 7) % 41) / 20.0 - 1.0)


## WHO ARRIVES ON AN ARC AND WHO KEEPS ITS OWN HEIGHT — read off the tables that
## already exist rather than off a hand-typed roster, because a hand-typed roster
## is the exact shape of STATUS's seventh failure mode (a check that loops three
## names, and the one row missing from the list is the only row that could have
## failed it).
##
## A kind in `ROTOR_MOTION` FLIES: `_fly` writes its `position.y` after `place`,
## and a second author of that one number is the two-functions-disagreeing
## failure. So a drone glides in along the horizontal path and keeps its own
## hover height — it still stops popping into existence, which is the ask, and
## nothing touches the arithmetic that owns its altitude.
static func arrival_arc_lifts(kind: String) -> bool:
	return not ROTOR_MOTION.has(kind) and not SEGMENTED.has(kind)


## A kind in `SEGMENTED` is the Colossus, and it does not arrive at all: wave 12
## is `{"boss": true}`, `arrival_hull_for_wave` gives it no transport to leave,
## it owns a cutscene and a thirteen-part shadow path, and the design kills a
## boss leap by name.
static func arrival_arc_travels(kind: String) -> bool:
	return not SEGMENTED.has(kind)

## The SCUPPER GRATING's height in ground units (SG-56): low deck ironwork,
## not a cargo wall — it must never hide a boarder, so it stays well under the
## 125-unit module height `_occluded` reasons about, and out of that list.
const GRATING_H := 55.0

const WALL_MODULE_D := 100.0
const WALL_MODULE_H := 125.0

## THE CARGO RUNS ARE CRATES NOW, NOT A PAINTING OF CRATES (board SG-138, the
## owner: *"I still see some 2D sprites and just some straight, simple deck
## layouts"*).
##
## This repository already knew. The SG-41 note in `tests/parity_test.gd` wrote
## it down in so many words — *"`_build_cargo` projects it across every cargo
## run's TOP face, which is most of what a 41-degree camera sees"* — and then
## fixed the COLOUR of the band it had found there and left the mechanism
## standing. A `Decal` with no rotation projects along its own -Y, which is
## straight down, so `cargo_wall_module.png` — a cut-out the browser draws
## SIDE-ON — was being stamped flat onto the lid of eight boxes. At the locked
## 41-degree camera the lid is most of what reaches the player, so eight of the
## largest objects on the deck were, precisely, a painted picture of crates
## lying face-up on a slab. That is the read the owner has reported more than
## once, and it is the sixth failure mode: the fact was in the repo and never
## reached the thing it was a fact about.
##
## So the runs are built out of THE SAME MESH the deck's loose crates use — the
## one standing beside the captain in his screenshot — instanced through one
## `MultiMesh`, which is why ~100 real crate stacks cost ONE draw call and not
## a hundred. The painted module stays, rotated onto the OUTBOARD FACE where
## the browser always drew it and where a cut-out reads as markings on cargo
## rather than as the cargo itself; that also keeps `cargo_wall_module.png` a
## thing the renderer still reads, so the SG-41 check goes on guarding an asset
## that is actually on screen instead of an orphan.
const CARGO_CRATE_MODEL := "crate_stack"
## The crate stacks are scaled so the TALLEST of them is exactly WALL_MODULE_H.
## That is not a taste number: `_occluded` tests a sight line against
## WALL_MODULE_H to decide whether a boarder needs an x-ray silhouette, so
## geometry that stood TALLER than the test would hide a figure the test had
## already decided was in clear air. Every instance varies DOWNWARD from this
## and none of them exceeds it, which keeps the error on the safe side — an
## unnecessary ghost, never a lost boarder.
const CARGO_CRATE_JITTER := 0.10   ## how far below full height a stack may sit
## A low lashed plinth under the stacks, so the run meets the planking in a
## straight line instead of in a row of gaps.
const CARGO_PLINTH_H := 22.0

## THE AIRSTREAM (F-03) and THE SWAY (F-04).
##
## Both were reported against the browser build and both are still open there.
## The port had the airstream ported into `game.gd` and then hid the scene that
## drew it, so what actually shipped was nothing at all.
##
## Rebuilt here as what it always wanted to be: streaks in the air travelling
## past the camera, at the camera's own height, rather than lines drawn on a
## flat picture of a deck. The tester asked what they were supposed to look at to
## see the ship was flying, and the answer has to be something between them and
## the deck, moving.
## Tuned down hard from the first pass. Seventy-two ribbons at 0.4 additive were
## not air, they were fog: milky bands washing across the deck and the fight.
## Air you are moving through is a thing you notice in motion and barely see in a
## still, which is the right target for a still.
const STREAK_COUNT := 48
const STREAK_SPEED := 1450.0        ## ground units per second, toward the stern
const STREAK_DEPTH := 3000.0        ## the volume they live in, ahead of the camera
const STREAK_SPREAD := 1500.0       ## and across it

## How hard the painted sky is driven before the post chain gets it. The backdrop
## arrives as a finished painting and then loses a third of itself on the way to
## the screen — Filmic tonemapping with a white point of 6, a 1.10 contrast lift
## and 15% of the depth fog. Measured against the browser's own canvas at the
## same framing rather than guessed at; see `tools/sky_shot.gd`.
const SKY_ENERGY := 1.55

## THE CLOUD FIELD — and this is where the parallax comes from.
##
## The browser drifts two painted cloud bands at 16 and 34 pixels a second, and
## a pixel a second is not a speed, it is an ANGULAR RATE: its focal length at
## 1600x900 is 1320 * min(1600/1400, 900/860) = 1381.4 pixels per radian, so the
## two bands sweep 0.01158 and 0.02461 radians a second. Reproducing an angular
## rate with real geometry leaves one degree of freedom — rate = speed /
## distance — and either half of that pair may be chosen freely.
##
## Distance was chosen first, because it is the half with hard limits. The near
## layer has to clear the deck and the gunwale by enough that it never reads as
## something ON the ship; the far layer has to fit inside a camera far plane that
## is not absurd. 300 and 640 metres. The drift then follows and is not a taste
## number: 7.2 m/s puts the near layer at 0.0240 rad/s and the far at 0.0113,
## which is 33.2 and 15.5 of the browser's pixels a second against its 34 and 16.
##
## Doing it this way rather than by panning a texture is the whole point. Two
## objects at two real distances under one perspective camera parallax against
## each other for free, they parallax against the deck for free, and they stay
## correct when the wheel pulls the camera back — none of which a scrolling
## backdrop does, and all three are what was actually asked for.
const CLOUD_DRIFT := 720.0          ## ground units per second, toward the stern
const CLOUD_NEAR_RANGE := 30000.0   ## 300 m, the fast layer
const CLOUD_FAR_RANGE := 64000.0    ## 640 m, the slow one — 2.13x, browser 2.125x

## And the sway. Reported as "very subtle, player didn't notice much even after
## being told" — because in 2D it could only ever be a small parallax nudge. A
## real camera can roll the horizon, which is what standing on a ship feels
## like, and one degree of roll is unmistakable where ten pixels of drift is not.
const SWAY_ROLL := 0.85             ## degrees
const SWAY_YAW := 0.42
const SWAY_HEAVE := 26.0            ## ground units, vertical

@export var game_path: NodePath = ^"SkyGear"

var game: SkyGearGame
var camera: Camera3D
var deck: MeshInstance3D
var _billboards: Dictionary = {}     ## key -> Sprite3D
var _used: Dictionary = {}
var _textures: Dictionary = {}
var _decals: Dictionary = {}         ## key -> Decal, projected onto the deck
var _volumes: Dictionary = {}        ## key -> MeshInstance3D, the aura cylinders
var _decals_used: Dictionary = {}
var _lights: Dictionary = {}         ## prop id -> OmniLight3D
var _envelope: MeshInstance3D
var _wreck: Sprite3D                  ## the Colossus fitting (SG-15/56); null if the art is absent
var _grating: MeshInstance3D          ## the scupper grating fitting (SG-56)
## Every crate stack in every cargo run, in ONE batch (SG-138). Null only if
## `crate_stack` failed to load, which is also the only way the runs are still
## the painted box — so the harness can read this and tell the two apart.
var _cargo_crates: MultiMeshInstance3D
## How long the hulk at the bow has been a wreck (SG-139). Reset the moment it
## is anything else, so a fresh hulk grappling on starts solid.
var _hulk_wreck_age := 0.0
var _focus := Vector2.ZERO
var _focus_set := false
var _flicker := 0.0
var _made: Dictionary = {}           ## generated textures, by key
var _cloud_bands: Array[Dictionary] = []
## The transport fleet (`SKYSHIPS`), one entry per BUILT ship — a row whose scene
## was missing is not in here, so `_sync_skyships` iterates what exists rather
## than what was asked for.
var _skyships: Array[Dictionary] = []
var _escort: MeshInstance3D           ## the distant airship, running with us
var _sparks: Dictionary = {}          ## element -> GPUParticles3D
var _flashes: Array[OmniLight3D] = []
var _flash_next := 0
var _impact_rng := RandomNumberGenerator.new()
## The projectile CORES — real emissive geometry in the air, replacing the
## painted `_spark` fireball the owner called cheap (board SG-40). Pooled exactly
## like the billboards: `_cores` is in use this frame, `_free_cores` is the shelf.
var _cores: Dictionary = {}           ## key -> MeshInstance3D, a stretched emissive orb
var _free_cores: Array[MeshInstance3D] = []
var _peak_cores := 0
var _core_mesh: SphereMesh            ## one sphere, scaled per bolt into a teardrop
## The per-bolt light pool. Smaller than the core pool ON PURPOSE — lights are the
## expensive half, so only the nearest N cores to the camera get one. See
## `_flush_core_lights` and the budget note at CORE_LIGHT_POOL.
var _core_lights: Array[OmniLight3D] = []
var _core_light_req: Array = []       ## this frame's {pos, col} light requests
var _shadow_batch: MultiMeshInstance3D
var _shadow_at: PackedVector2Array = PackedVector2Array()
var _shadow_size: PackedFloat32Array = PackedFloat32Array()
## Depth is its own array rather than `size * 0.62` at flush time, because a
## FIGURE is an upright thing whose shadow is a squashed circle and a fallen
## MACHINE PART is not — a Colossus foot lying on the planking is half again
## deeper than it is wide. Every existing caller omits it and gets the 0.62
## it always got; only a part that measured its own footprint passes one.
var _shadow_depth: PackedFloat32Array = PackedFloat32Array()
var _shadow_alpha: PackedFloat32Array = PackedFloat32Array()
## How far off the planking the caster is, in ground units, and which of the
## three rules its mark obeys. See `_shadow`.
var _shadow_lift: PackedFloat32Array = PackedFloat32Array()
var _shadow_kind: PackedInt32Array = PackedInt32Array()
var _shadow_count := 0
## How many of the marks in the last flush were contact cores rather than whole
## blobs — i.e. how many figures on this deck the moon is already drawing. The
## harness's window on rule two, and the probe's.
var _shadow_cores := 0
var _shadow_cores_last := 0
## THE KILL-TEST'S SWITCH, and it is here rather than in the tool for a reason
## this project has paid for twice: DECK-IDENTITY §7.5 records the same build
## measuring 0.72% and 13.55% on consecutive runs because two godot processes
## reach the shutter with the braziers, the particles and the GPU's own clocks in
## different places. An A/B that matters has to happen inside ONE process, one
## frame apart, which means the old behaviour has to be reachable at runtime.
## `tools/shadow_probe.gd` is the only thing that sets this, and
## `shadow · the pool leans where the moon does` asserts it is false in play.
var shadow_legacy := false
var _warmup := SkyGearWarmup.new()
var _warm_frames := 0
## The actual free lists. `_billboards` and `_decals` hold what is IN USE this
## frame; these hold what has been returned and is waiting to be claimed again.
var _free_billboards: Array[Sprite3D] = []
var _free_decals: Array[Decal] = []
var _peak_decals := 0
var _peak_billboards := 0
var _rigs: Dictionary = {}            ## key -> SkyGearRig3D, for anything with a model
var _no_model: Dictionary = {}        ## kinds we have already looked for and not found

## --- SG-85: the first death on screen ---------------------------------------
##
## Bodies the SIMULATION has already finished with, kept a moment longer so the
## death clip can play. key -> {rig, life, height}. Deliberately NOT `_rigs`: a
## corpse is claimed by nobody, must never be handed to a live boarder, and the
## next spawn builds its own figure.
var _corpses: Dictionary = {}

## …and the same courtesy for the tier that has no skeleton to lie down with
## (board SG-103). A painted figure the renderer stopped claiming was hidden on
## that same frame, which is the "just vanishing" the owner reported, in its
## purest form: no death clip, no sink, no tail, one frame. These are the sprites
## on the way out — {node, life} — aged beside the corpses and shelved into
## `_free_billboards` exactly as `_recycle` would have shelved them, only later.
##
## Capped, because everything pooled here is. Past the cap a sprite is shelved
## on the spot the way it always was: the fade is a courtesy and a courtesy that
## can starve the pool is a leak with a nice name.
var _fading: Array[Dictionary] = []
const FADE_CAP := 24

## And a cap on the BODIES, which never needed one until the fade arrived. Until
## SG-103 a corpse could only be one of the four kinds that carry a `die` clip
## and everything else was freed on the spot; now every unclaimed rig is held
## for at least `DEATH_FADE`, so a wave that wipes twelve goblins at once holds
## twelve rigs it used to have already let go of. Sixteen is over twice the
## most a real flood has ever produced at once, and past it a body is freed the
## instant it is unclaimed exactly as it always was — DESIGN §13m's rule is that
## a rig is FREED rather than pooled, and this delays the freeing by two thirds
## of a second rather than turning it into a reservation.
const CORPSE_CAP := 16

## The renderer's own crew identity counter (SG-88). A crewman is a Dictionary
## in an Array the simulation calls `remove_at` on, so his INDEX is not a name;
## this is. See the crew block in `_sync_all` for why a death needed one and a
## billboard never did.
var _crew_seq := 0

## How long the death clip gets. The knight's `die` is 2.40 s and a fight cannot
## stop for that, so it rides the same clip-stretched-to-window machinery every
## swing does (1.5x, which reads as going down HARD rather than sagging).
const DEATH_WINDOW := 1.60

## …and then the body sinks through the planking rather than blinking out. The
## last thing a death should do is remind you it was a node.
const DEATH_SINK := 0.40

## AND IT GOES TRANSPARENT ON THE WAY DOWN (board SG-103). Owner, build-44:
## *"Should enemies fade away after they die instead of just vanishing?"*
##
## Yes, and the sink was half an answer already — a body that drops through the
## planking still CLIPS out of existence at the deck line, and the billboard tier
## had no tail at all: a sprite the renderer stopped claiming was hidden on the
## same frame, which is the pop he is describing.
##
## Longer than the sink on purpose, and that ordering is the whole design: the
## body has visibly begun to leave BEFORE it starts through the floor, so the
## deck line stops being the moment anything happens. It is also strictly INSIDE
## `corpse_life` — this adds nothing to how long a corpse is held, which matters
## because rigs are freed rather than pooled (DESIGN §13m) and a fade that
## extended the window would be a rig budget change wearing a VFX one.
const DEATH_FADE := 0.60


## How long a corpse is kept, total. UNCHANGED by the fade, which is the point:
## the tail is carved out of the window the body already had.
static func corpse_life() -> float:
	return DEATH_WINDOW + DEATH_SINK


## How far a corpse has dropped below the deck, given the life it has left and
## the height it stands. Zero for the whole death clip — the body does not start
## leaving until the death has been PLAYED — then a full body-height in the last
## `DEATH_SINK` seconds.
static func corpse_drop(life: float, height: float) -> float:
	if life >= DEATH_SINK:
		return 0.0
	return height * (1.0 - maxf(0.0, life) / DEATH_SINK)


## How SOLID a body still is, given the life it has left: one for the whole death
## clip — nothing starts disappearing until it has finished dying — then linearly
## to nothing across the last `DEATH_FADE` seconds. The `corpse_drop` idiom,
## static and pure, so the harness pins the curve without standing a deck up.
##
## ONE function for both tiers. A rigged corpse spends it on every mesh's
## `transparency`; a painted one spends it on the sprite's `modulate.a`. A body
## and the sprite it falls back to disappearing at different rates would be the
## same two-numbers fault `crew_height` exists to prevent, one layer down.
static func corpse_fade(life: float) -> float:
	if life >= DEATH_FADE:
		return 1.0
	return clampf(life / DEATH_FADE, 0.0, 1.0)


## Whether this figure has a death to show. The scrapper's borrowed library has
## none (SG-65 flagged it, SG-74 found the source), so he keeps despawning
## exactly as he shipped — the same always-both-paths rule the meshes follow.
static func dies_on_screen(rig: SkyGearRig3D) -> bool:
	return rig != null and rig.has_clip("die")
var _prop_models: Dictionary = {}     ## key -> Node3D, a static generated mesh in use
var _free_prop_models: Dictionary = {} ## model key -> Array[Node3D], hidden, reusable
var _no_prop_model: Dictionary = {}   ## model keys already looked for and not found
var _boiler_glow: OmniLight3D         ## the furnace lamp, on either Boiler body
var _boiler_mats: Array[StandardMaterial3D] = []   ## override copies, tinted by health
var _boiler_base: PackedColorArray = PackedColorArray()  ## their albedo at full health
var _stream: Array[MeshInstance3D] = []
var _stream_v: PackedFloat32Array = PackedFloat32Array()
var _stream_len: PackedFloat32Array = PackedFloat32Array()   ## length, width, per streak
var _roll := 0.0
var _yaw := 0.0
## Off for the harness. A camera that is deliberately never still cannot also be
## the thing a framing check measures against, and the check is measuring the
## framing the sway moves AROUND.
var sway := true


func _ready() -> void:
	game = get_node_or_null(game_path)
	_build_world()
	if game != null:
		# the 2D scene keeps simulating; it just stops being what you look at
		game.visible = false
		# the HUD still draws over the fight, so it needs the lens we are using
		if game.hud != null:
			game.hud.view = self
		game.view = self
	## LAST, so it sits after the game scene in the tree — unhandled input is
	## walked in reverse, and the skip has to reach the cutscene before the pause
	## key reaches the game.
	_cutscene = (load(CUTSCENE_PLAYER) as GDScript).new()
	_cutscene.view = self
	add_child(_cutscene)


## How far behind the captain the focus point sits, so she lands at STAND_FRAC.
## Straight out of `CAM.recompute()`: the browser solves this rather than tuning
## it, because a hard-coded offset silently re-frames the whole fight the moment
## the pitch or the focal length moves.
static func camera_back() -> float:
	var r: float = (0.5 - STAND_FRAC) * REF_HEIGHT / FOCAL
	var den: float = sin(PITCH) - r * cos(PITCH)
	if absf(den) < 1e-4:
		return CAM_NEAR + 200.0
	return clampf(CAM_HEIGHT * (r * sin(PITCH) + cos(PITCH)) / den - CAM_NEAR, -260.0, 900.0)


func _build_world() -> void:
	## SG-81, before anything that can be lit by it: the per-model lights table.
	## An absent or unreadable file leaves this empty, which is the "no model
	## lights at all, today's rendering" path — see the MODEL LIGHTS region.
	_model_light_rows = load_model_lights()
	## SG-17, and for the same reason and in the same order: the FX constants
	## table, read before the environment that spends the first of them and long
	## before `_build_impacts` spends the other two.
	_fx_tuning = load_fx()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	## A real sky, because the top of the frame is where the horizon is and a
	## flat clear colour reads as a void rather than as altitude at dusk.
	## REPORTED THREE TIMES: "where is the sky box? It's missing." Twice it was
	## treated as a colour problem and twice that was wrong. It was a CONTENT
	## problem: a two-stop gradient with nothing in it, while the browser has a
	## painted moon breaking through cloud and the player remembered the painting.
	##
	## The painting is `assets/art/env/sky_backdrop.png` and it has been in this
	## repository the whole time. `scripts/sky.gdshader` puts it back — see that
	## file for why it is a sky shader rather than a quad, and for the measurement
	## that explains why every earlier screenshot of the sky was a screenshot of
	## planking. The procedural gradient stays as the fallback for a build where
	## the art has not been imported, because a missing texture should cost the
	## sky its detail rather than turn the top of the frame black.
	var sky_res := Sky.new()
	var backdrop := _texture("res://assets/art/env/sky_backdrop.png")
	if backdrop != null:
		var painted := ShaderMaterial.new()
		painted.shader = load("res://scripts/sky.gdshader")
		painted.set_shader_parameter("backdrop", backdrop)
		## The four camera constants, read from the camera rather than retyped.
		painted.set_shader_parameter("pitch", PITCH)
		painted.set_shader_parameter("ref_tan", (REF_HEIGHT * 0.5) / FOCAL)
		painted.set_shader_parameter("ref_aspect", 16.0 / 9.0)
		painted.set_shader_parameter("energy", SKY_ENERGY)
		painted.set_shader_parameter("away", Color("#14111f"))
		sky_res.sky_material = painted
		## The shader returns one flat colour for the radiance capture, so the
		## probe costs nothing worth measuring and can be tiny. It is only feeding
		## the specular on the brass rails; the ambient term is a colour.
		sky_res.radiance_size = Sky.RADIANCE_SIZE_32
		sky_res.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	else:
		## STORM-DUSK means the sun is going down BEHIND the weather, so the
		## horizon is the brightest thing in the frame and the top is the darkest.
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color("#1a1636")
		sky_mat.sky_horizon_color = Color("#8a5a6e")
		sky_mat.sky_curve = 0.19
		sky_mat.ground_bottom_color = Color("#0f0d1c")
		sky_mat.ground_horizon_color = Color("#5c4460")
		sky_mat.ground_curve = 0.08
		sky_mat.sun_angle_max = 24.0
		sky_mat.sun_curve = 0.12
		sky_mat.energy_multiplier = 1.35
		sky_res.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky_res
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	## A NEUTRAL-warm ambient floor, not a cool one. SG-34: measured against the
	## browser, the deck was not darker or cooler on average — it was BRIGHTER and
	## warmer in the mean — but its focal surfaces (the crate and prop tops) read
	## navy, because the cool moon directional and a cool-PURPLE ambient (#4a4058,
	## blue dominant) were the only fill on every up-facing face the warm point
	## pools do not reach. Pushed fully warm the floor went monochrome orange while
	## the crates stayed navy (measured warm/blue split), so the fill is set to a
	## near-neutral, faintly warm brown-grey (red just ahead of blue): it lifts a
	## crate top out of steel without repainting the whole deck orange, matching the
	## browser's ONE modest-warm field with cool shadows. Pinned by `view · the deck
	## is lit warm and even, not a hot pool`.
	e.ambient_light_color = Color("#494551")
	e.ambient_light_energy = 0.62
	e.fog_enabled = true
	e.fog_light_color = Color("#3a3340")
	e.fog_density = 0.011
	## AND THE FOG MUST NOT EAT THE SKY. At the default the depth fog is applied
	## to the background too, so a horizon painted warm arrives grey — which is
	## most of why brightening the material alone did not help the first time.
	e.fog_sky_affect = 0.15
	## VOLUMETRIC FOG, FOR THE FIELDS ONLY. See `VOLUMETRIC_FIELDS`.
	##
	## Global density stays at zero, which is the audit's own recommendation when
	## only local volumes are wanted: the deck is not fogged, the lanterns are not
	## lighting a medium, and the only thing in the froxels is whatever
	## `_sync_auras` puts there. The range is cut to 22 metres because the deck is
	## 23 long and the default 64 spends most of the pass on empty sky.
	if VOLUMETRIC_FIELDS:
		e.volumetric_fog_enabled = true
		e.volumetric_fog_density = 0.0
		e.volumetric_fog_length = 22.0
		## Temporal reprojection ON, which is NOT what the audit recommends for a
		## volume that follows a moving player — and the measurement overrules it.
		## Off, the pass resolves in full every frame and the bench's 99th
		## percentile goes 9.5 -> 13.6 ms; on, it goes 9.5 -> 10.7. Four
		## milliseconds of tail is not a price a passive that most runs never draft
		## gets to charge on every frame of every run. What it costs back is a short
		## smear of haze behind the captain while she runs, which on a Steam Field
		## is what steam does anyway.
		e.volumetric_fog_temporal_reprojection_enabled = true
		e.volumetric_fog_gi_inject = 0.0
	## Bloom. The browser fakes every glow by hand with radial gradients — the
	## lantern haze, the furnace mouth, the rim on a cleave — because Canvas 2D
	## has no post chain. Here it is one flag, and without it the emissive
	## surfaces read as flat orange paint rather than as light.
	e.glow_enabled = true
	## SG-17: the lab's GLOW dial lands HERE. It used to write `glow_strength`,
	## which this renderer never sets — so the dial moved a number the shipped
	## game does not have, which is "no home" by another route.
	e.glow_intensity = fx_glow(_fx_tuning)
	e.glow_bloom = 0.06
	e.glow_hdr_threshold = 1.05
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	## Contact shadowing in the creases of the cargo, which is most of what makes
	## a box look like an object rather than a shape.
	e.ssao_enabled = true
	e.ssao_intensity = 1.6
	e.ssao_radius = 0.6
	## A1. THERE WAS NO TONEMAPPER, so the environment ran Linear and everything
	## above 1.0 hard-clipped to white — while this renderer deliberately pushes
	## above 1.0 everywhere: effect tints at 1.45x, impact particles at 1.7x, the
	## furnace emission at 2.6x, a glow threshold of 1.05. Every one of those was
	## clipping to white at exactly the moment it was meant to carry an element's
	## colour, which is the one job it had.
	##
	## Filmic rather than AgX: AgX desaturates hard in the highlights and this
	## palette is carrying information in the hue of a bright ring.
	##
	## SG-34, MEASURED then chosen: exposure is a DELIBERATE 0.80, not the default
	## 1.0. A probe over `.shots/parity/` found the deck was not dark or cool (the
	## premise) — it was BRIGHTER than the browser (deck-region luminance ~53 vs
	## ~44) with a searing hot pool (99th-percentile luminance 163 vs 148) that, by
	## simultaneous contrast, made the warm surround read cold. Deepening the whole
	## frame to 0.80 pulls luminance to ~44 and the pool peak to ~148 — a richer,
	## deeper amber with the mood a flat Canvas 2D deck never had, and telegraphs
	## and element flashes pop HARDER against it, not softer. Pinned, with the
	## ambient and key, by `view · the deck is lit warm and even, not a hot pool`.
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.80
	e.tonemap_white = 6.0
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.10
	e.adjustment_saturation = 1.04
	env.environment = e
	add_child(env)

	## Two sources, the same two the art is painted for: a steel-blue moon rim
	## from the upper left and a warm lantern fill from the lower right.
	## SG-34, MEASURED: the moon stays the cool storm-dusk KEY at its shipped 1.45,
	## and it is deliberately NOT reduced. The premise was that the deck read cool
	## and dark; measured against the browser it read the opposite — brighter and
	## warmer — and pulling this cool key only spiked the whole deck orange (R/B
	## drifted to 2.3 against the browser's modest ~1.5) without fixing the one
	## thing that genuinely reads blue: the crate STACKS, which are blue from their
	## own model texture, not from this light (they stayed navy at 1.15 too — filed
	## SG-41). The over-bright, over-hot-pool read SG-34 was really about is fixed
	## at the exposure and the accent pools, not here; this key is what keeps the
	## deck's warmth near the browser's rather than orange.
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#8fa6c9")
	moon.light_energy = 1.45
	moon.rotation_degrees = Vector3(-52, 34, 0)
	moon.shadow_enabled = true
	moon.shadow_blur = 2.2
	## 60 metres was roughly double the visible deck (16.8 x 23.2). Tightening it
	## to the deck plus a margin nearly doubles the effective shadow resolution
	## for nothing.
	moon.directional_shadow_max_distance = 34.0
	moon.shadow_opacity = 0.72
	add_child(moon)
	var lantern := DirectionalLight3D.new()
	lantern.light_color = Color("#ffb347")
	lantern.light_energy = 0.38
	lantern.rotation_degrees = Vector3(-28, -150, 0)
	add_child(lantern)
	## THE THIRD SOURCE, and the one the paintings always had (SG-86).
	##
	## Every enemy painting in `assets/art/enemies/` is lit as a three-point
	## setup: a warm key, a fill, and a cool rim that traces the whole silhouette.
	## The deck had the first two and not the third, so a mesh boarder arrived
	## with no edge — measured on the furnace knight, mean luminance 34.4 against
	## his painting's 45.4 over the same crop, and the failure is not brightness
	## alone but SEPARATION: he is a warm brown figure standing on warm brown
	## planking with nothing between the two. That is a Pillar 6 problem before it
	## is an atmosphere one; the shape at the rail has to be identifiable.
	##
	## MEASURED, and this is why it is a light and not an emission tweak:
	## `emission_energy` cannot fix it, because `armored_emission.png` peaks at
	## 51/255 and covers 0.15% of its texels — there is no emissive area to
	## amplify, which is the real reason 6 -> 18 -> 40 moved nothing (SG-86 read
	## that as a saturated tonemapper; it is an empty map, and the grille is
	## filed separately for Alex).
	##
	## It shines from the BOW toward the camera, which is the only direction that
	## rims a figure the camera is looking at: yaw 200 puts it over the port bow
	## so the edge lands on the same side the paintings light, and the shallow
	## -16 pitch is deliberate — a rim wants grazing angles on VERTICAL surfaces,
	## and every degree of pitch spent on the deck plane is a degree that washes
	## the planking instead of the boarder standing on it. No shadows: a rim that
	## casts is a second shadow from an impossible sun, and the cost is real.
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(RIM_COLOUR)
	rim.light_energy = RIM_ENERGY
	rim.rotation_degrees = RIM_ANGLE
	rim.shadow_enabled = false
	add_child(rim)
	_moon = moon
	_lantern = lantern
	_rim = rim
	_moon_energy = moon.light_energy
	_lantern_energy = lantern.light_energy
	_rim_energy = rim.light_energy
	_ambient_energy = e.ambient_light_energy
	_environment = e

	deck = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(SkyGearGame.DECK_RECT.size.x, SkyGearGame.DECK_RECT.size.y) * WORLD_SCALE
	deck.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _planking_texture()
	## 1.8 tiles across 1680 units puts a board at roughly 116 wide, which is the
	## browser's own plank width; 2.9 down 2320 puts a butt joint every ~400.
	mat.uv1_scale = Vector3(1.8, 7.0, 1.0)
	mat.roughness = 0.86
	## Anisotropy, for the same reason: a plank run receding to the bow is the
	## textbook case where trilinear alone turns detail into mush.
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	deck.material_override = mat
	deck.position = Vector3(
		(SkyGearGame.DECK_RECT.position.x + SkyGearGame.DECK_RECT.size.x * 0.5) * WORLD_SCALE,
		0.0,
		(SkyGearGame.DECK_RECT.position.y + SkyGearGame.DECK_RECT.size.y * 0.5) * WORLD_SCALE)
	add_child(deck)

	_build_cargo()

	## The ship's SHAPE, which is not the ship's RECTANGLE. Built here, before the
	## gunwale, so whoever replaces the two solid bars with stanchions
	## (DECK-IDENTITY item 4) can seat them on `sheer_lift()` rather than on a
	## second copy of the curve.
	_build_hull_shape()

	## The rig overhead — which the camera never sees and the deck wears all run.
	_build_rigging()

	## The gunwale. Without it the deck is a rectangle that stops, and at
	## altitude the thing you most need to read is where the edge is.
	## THE BREAST RAIL, DARKENED AND TAKEN UNDER THE CEILING (SG-179). The owner:
	## *"that lightish brown/yellow ... look out of place against our other
	## models and seem very placeholder."* He is right, and it is two faults at
	## once: a flat albedo with no maps beside models that carry four, and a
	## metallic of 0.4 on a deck whose every MODEL was clamped to 0.34 the day
	## before. This fixes the second and takes the edge off the first. It stays
	## brass rather than becoming timber because this bar is not decoration —
	## DECK-IDENTITY 6 gives it a job, drawing the play boundary, and a boundary
	## the eye cannot find is worse than an ugly one.
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color("#7c5a2c")
	rail_mat.roughness = 0.74
	rail_mat.metallic = LAMPLIT_METALLIC_MAX
	## THE TWO SOLID SIDE BARS ARE GONE (SG-157). DECK-IDENTITY item 4 asked for
	## exactly this and said why in one sentence: *a rail reads as a rail because
	## you see past it*, and a solid 14 x 40 x 2320 bar cannot produce the
	## periodic gap at any camera. `_build_edge_kit()` puts the owner's own
	## hand-modelled module there instead. The END CAPS below stay — they are a
	## different object doing a different job (DECK-IDENTITY 6: the breast rail
	## that draws the play boundary in brass) and nothing asked for them to go.
	_build_edge_kit()
	_end_cap_mat = rail_mat
	_build_end_caps()

	## The hull below the deck, so the ship has a bottom and the frame does not
	## end in void where the planking stops.
	var hull := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(SkyGearGame.DECK_RECT.size.x * 0.94, 300.0,
		SkyGearGame.DECK_RECT.size.y * 0.98) * WORLD_SCALE
	hull.mesh = hm
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color("#241b25")
	hull.material_override = hull_mat
	hull.position = Vector3(
		(SkyGearGame.DECK_RECT.position.x + SkyGearGame.DECK_RECT.size.x * 0.5) * WORLD_SCALE,
		-152.0 * WORLD_SCALE,
		(SkyGearGame.DECK_RECT.position.y + SkyGearGame.DECK_RECT.size.y * 0.5) * WORLD_SCALE)
	add_child(hull)

	_build_clouds()
	_build_skyships()

	## THE PAINTED PROW IS RETIRED, 2026-08-02, on the owner's word: *"Get rid of
	## this 2D sprite — it's not needed anymore."*
	##
	## `bow_prow.png` was a 900-unit Sprite3D at z = -1310 leaning back 14°, and
	## it never had a chance. DECK-DESIGN §1 measured why: the vertical headroom
	## at the bow is **65 units at zoom 1.0**, and 900 is fourteen times that, so
	## the painting could only ever be a wall across the top of the frame. It was
	## the right answer to "the deck ends in nothing" while the deck was a
	## rectangle. It is the wrong answer now that there is a bow.
	##
	## `_build_hull_shape` replaces it with the thing it was standing in for: an
	## apron of the deck's own planking narrowing to a stem, in the deck PLANE
	## where the budget actually is, with the sheer strake following it in. The
	## two must never be on screen together — a painted prow standing on a drawn
	## one is two bows.
	##
	## THE PNG STAYS ON DISK. The row that draws it is what went. Restoring it is
	## this comment plus twelve lines, which is the cost of being wrong.

	## THE COLOSSUS WRECK (SG-15). An upright billboard adrift off the bow, built
	## once here beside the prow — it is a fitting, not a `props`-group prop, so it
	## never enters the sim, the cargo rects or the per-wave stow, and nothing on
	## the deck can path to it. Height straight from PROP_HEIGHT["wreck"], the one
	## place the wreck's size lives. Visibility is refreshed every frame from the
	## RUN's berthed set (`_wreck_berthed` — board SG-56 moved the SG-15 gate
	## into the berth system), so it rides off the bow while THE WRECK is
	## berthed and clears the sky when it is not. Absent art costs the fitting,
	## not the frame.
	var wreck_tex := _texture(WRECK_TEXTURE)
	if wreck_tex != null:
		var wreck := Sprite3D.new()
		wreck.texture = wreck_tex
		wreck.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		wreck.shaded = false
		wreck.double_sided = true
		wreck.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		wreck.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		wreck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wreck.layers = LAYER_FIGURES
		var wreck_h: float = float(PROP_HEIGHT["wreck"])
		wreck.pixel_size = wreck_h * WORLD_SCALE / maxf(1.0, float(wreck_tex.get_height()))
		wreck.position = Vector3(WRECK_POSITION.x * WORLD_SCALE,
			wreck_h * 0.5 * WORLD_SCALE, WRECK_POSITION.y * WORLD_SCALE)
		wreck.visible = _wreck_berthed()
		add_child(wreck)
		_wreck = wreck

	## THE SCUPPER GRATING (SG-56). The one fitting that closes ground: a low
	## iron grate filling the port stern crossing, with a vent standing on it
	## (the vent is a prop the stow places; this is the grate itself). Built
	## once, toggled per frame from the RUN's berthed set like the wreck —
	## visible geometry for a closure the captain's clamp enforces, because a
	## wall you cannot see is a collision bug, not a fitting. LOW on purpose:
	## at 55 units it reads as deck furniture, hides nobody (so it stays out of
	## `_occluded`'s cargo list), and the vent on it stays in view.
	var grate_rect: Rect2 = (SkyGearFittings.FITTINGS["scupper_grating"] as Dictionary).wall
	var grate := MeshInstance3D.new()
	var grate_mesh := BoxMesh.new()
	grate_mesh.size = Vector3(grate_rect.size.x, GRATING_H, grate_rect.size.y) * WORLD_SCALE
	grate.mesh = grate_mesh
	var grate_mat := StandardMaterial3D.new()
	grate_mat.albedo_color = Color("#3f3428")
	grate_mat.metallic = 0.55
	grate_mat.roughness = 0.5
	grate.material_override = grate_mat
	grate.position = Vector3(grate_rect.get_center().x * WORLD_SCALE,
		GRATING_H * 0.5 * WORLD_SCALE, grate_rect.get_center().y * WORLD_SCALE)
	grate.visible = game != null and game.fitted("scupper_grating")
	add_child(grate)
	_grating = grate
	## A brass lip along its top edge, the cargo caps' own language, so the
	## grate reads as the ship's ironwork rather than an untextured block.
	var lip := MeshInstance3D.new()
	var lip_mesh := BoxMesh.new()
	lip_mesh.size = Vector3(grate_rect.size.x + 4.0, 5.0, grate_rect.size.y + 4.0) * WORLD_SCALE
	lip.mesh = lip_mesh
	var lip_mat := StandardMaterial3D.new()
	lip_mat.albedo_color = Color("#6d5227")
	lip_mat.metallic = 0.45
	lip_mat.roughness = 0.55
	lip.material_override = lip_mat
	lip.position = Vector3(0.0, (GRATING_H * 0.5 + 2.5) * WORLD_SCALE, 0.0)
	grate.add_child(lip)

	## Our own gas bag, overhead. Tied to the camera rather than the world so it
	## stays where a thing hanging above you stays — and kept thin, because the
	## browser build was reported for exactly this: the envelope was covering the
	## top third of the frame, which is the direction boarders arrive from.
	var env_tex := _texture("res://assets/art/env/envelope_top.png")
	if env_tex != null:
		_envelope = MeshInstance3D.new()
		var eq := QuadMesh.new()
		eq.size = Vector2(3600.0, 1100.0) * WORLD_SCALE
		_envelope.mesh = eq
		var em := StandardMaterial3D.new()
		em.albedo_texture = env_tex
		em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		em.albedo_color = Color(1, 1, 1, 0.85)
		em.cull_mode = BaseMaterial3D.CULL_DISABLED
		_envelope.mesh.material = em
		## THE OTHER HALF OF DECK-IDENTITY ITEM 1, AND IT WAS BUILT AND THEN CUT.
		## The item asks for this to become `..._ON`, on the argument that the quad
		## is 36 x 11 m, is rebuilt into a transform every frame, and can never be
		## seen — its lowest edge sits at +5 degrees of elevation while the top of
		## the frame is -23. The first two facts are true. The conclusion does not
		## follow, and three measurements say so:
		##
		##   1. **It is not one character.** A `TRANSPARENCY_ALPHA` material is
		##      drawn in the transparent pass and Godot does not rasterise it into
		##      the shadow map at all, so the enum alone is a no-op. Making it cast
		##      also means moving it to `ALPHA_HASH` — a dithered cutout on a quad,
		##      which is a material change, not a constant.
		##   2. **It costs the deck a further 1% for nothing legible.** Deck-region
		##      mean luminance at zoom 1.00: 43.93 shipped, 43.03 with the rig
		##      (-2.04%), 42.60 with the rig and this casting (-3.02%). At zoom
		##      1.55 the extra term is -0.1%, i.e. inside the noise. What it adds
		##      at 1.00 is a broad soft wash over the bow, not a gas bag.
		##   3. **AND IT IS TIED TO THE CAMERA.** `_sync_envelope` parks this quad
		##      at `camera.position + …`, so its shadow does not belong to the ship
		##      — it belongs to the PLAYER, and a large soft band would slide
		##      across the planking as she walks. The design's own "explicitly
		##      not" list rejects precisely that: *"cloud shadows moving across the
		##      deck — a 12% band sweeping a telegraph is pillar 6 traded for
		##      decoration."* A band welded to the captain's own feet is that
		##      trade with a shorter lever.
		##
		## So the rig ships and this stays OFF. The real finding underneath the
		## item is still true and still unbanked: this quad is invisible and is
		## transformed every frame anyway. The cheap correct answer is probably to
		## stop DRAWING it rather than to start casting it — but "never seen" has
		## only been argued from the gameplay camera, and the four `sky_shot` poses
		## drag it. Left alone tonight; it is a question in NEEDS_ALEX.
		_envelope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_envelope)

	_build_boiler()

	_build_airstream()
	_build_impacts()
	_build_cores()
	_build_ribbons()
	_shadow_at.resize(SHADOW_CAP)
	_shadow_size.resize(SHADOW_CAP)
	_shadow_depth.resize(SHADOW_CAP)
	_shadow_alpha.resize(SHADOW_CAP)
	_shadow_lift.resize(SHADOW_CAP)
	_shadow_kind.resize(SHADOW_CAP)
	_build_shadows()
	_build_marks()
	## A4. Build every generated texture NOW rather than the first time it is
	## drawn. `_glow_map` runs a per-pixel GDScript loop and `_fan_texture` runs
	## atan2 and exp per pixel — the first cone cast was paying for a 128x128
	## texture mid-fight, which is a hitch at the exact moment the player is
	## reacting to something.
	_ring_texture()
	_streak_texture()
	_blob_texture()
	_spark_texture()
	_crate_texture()
	_grille_texture()
	_wall_texture()
	_ribbon_texture()
	## Player cleave/cone arcs, plus the enemy melee swing arcs (SWARM 80°=1.396,
	## SCRAPPER 95°=1.658, ARMORED/BOSS 120°=2.094) — a windup wedge built mid-swing
	## is a hitch at the exact moment the player is reading a telegraph.
	for arc in [0.9, 1.134, 1.396263, 1.658, 1.7, 2.094395, 2.443]:
		## AND THEIR EMISSION MAPS, which this loop did not build and should
		## always have (board SG-162). `_decal` calls `_glow_map` on whatever
		## texture it is handed, so the first windup in a run was paying for a
		## per-pixel GDScript pass over the fan as well as the fan itself — the
		## exact hitch the paragraph above exists to prevent, half-prevented.
		## SG-162 took the fan to 256² for the sake of a one-texel rim, which
		## makes that unbuilt pass four times the cost it was.
		_glow_map(_fan_texture(arc, true))
		_glow_map(_fan_texture(arc, false))
	for key in PAINTED.keys():
		var painted := _texture(str(PAINTED[key]))
		if painted != null:
			_glow_map(painted)
	_glow_map(_ring_texture())
	_glow_map(_streak_texture())

	camera = Camera3D.new()
	## Not a taste dial. The browser's focal length is 1320 quoted against a
	## reference height of 860, so its vertical field of view is
	## 2·atan(430/1320) — about 36° — at every window size. Godot's `fov` is the
	## vertical one by default, so this is the same lens rather than a similar
	## one, and it is why the deck now reads to the horizon instead of the cargo
	## filling the frame.
	camera.fov = rad_to_deg(2.0 * atan((REF_HEIGHT * 0.5) / FOCAL))
	camera.near = 0.05
	## 400 metres was enough when the furthest object was a cloud band 60 metres
	## out. The far cloud layer sits at 640, because that is the distance that
	## reproduces the browser's slower band as a real angular rate, so anything
	## short of about 800 would clip it out of existence — and it is a 400-metre
	## quad, so its far corner is another 200 out and the plane cuts a straight
	## line across a painted cloud when it is too close. 1800 is that worst case
	## with room. Costs nothing: this renderer is Forward+, which is reverse-Z,
	## and reverse-Z spends its depth precision near the camera rather than
	## spreading it evenly over the range.
	camera.far = 1800.0
	camera.current = true
	add_child(camera)
	_track_camera(1.0)


## Impact particles and impact light.
##
## VFX-PLAN.md items 1 and 2, REVISED after the rendering audit
## (`docs/VFX-RESEARCH-AUDIT.md` findings 3 and 4) found two real faults in the
## first version:
##
##   * **`restart()` on a shared one-shot emitter throws away the particles
##     already in flight.** Two boarders dying half a second apart meant the
##     second kill erased the first one's sparks. Every impact after the first
##     was, visually, the only impact.
##   * **`amount_ratio` does not reduce processing cost** — the capacity stays
##     allocated — so scaling it by damage bought nothing.
##
## `emit_particle` is the right API and was the answer to both: particles are
## injected individually with their own transform, velocity and colour, into a
## continuously live emitter that is never restarted. Overlapping impacts now
## overlap.
##
## And the systems are keyed by BEHAVIOUR rather than by element. Sparks fly and
## fade; steam rises and dissolves; frost shards go out hard and stop. Four
## elements share three behaviours, and the colour rides on the particle.
const SPARK_CAPACITY := 512
const FLASH_POOL := 8

## --- AND THE PARTICLES THEMSELVES ARE BODIES NOW (board SG-63) ---------------
##
## The owner's remaining "2D reads", first item: the hit and explosion puffs.
## Every one of these was a `QuadMesh` in `BILLBOARD_PARTICLES` mode — a flat
## card turned to face the camera, wearing a painted plate. That is the SAME
## tell SG-40 fixed on the projectile HEADS: a thing that presents the identical
## disc from every angle is a sticker, and forty of them are forty copies of one
## sticker. A steam puff drawn that way is a painted cloud standing in the air.
##
## Each behaviour now has a real body, and the BODY carries the behaviour — the
## research audit's finding 4 in geometry rather than in hue:
##
##   spark   a short prism ALIGNED TO ITS OWN VELOCITY, so a fleck thrown out of
##           a hit lies along the way it is going and swings as it curves.
##           Unshaded and additive: a spark is light, not matter.
##   shard   the same prism, longer and thinner, which is what makes Frost's
##           splinter a splinter from every angle instead of only from this one.
##   steam   a low-poly SPHERE, and the only LIT thing in the particle layer. A
##           puff has to read as a VOLUME, and a volume is what the deck lamps
##           model: the moon catches its crown, a brazier catches its flank, and
##           it tumbles about its own axis so the highlight travels across it
##           while it rises. None of which a camera-facing card can do.
##
## The painted plates stay ON the meshes as a mask, which is the one job they
## are still good at: a low-poly sphere has a hard polygonal rim, and
## `puff_steam`'s soft edge eats it, so the puff's outline is cloud and not
## football. Element identity is untouched — it stays in `ELEMENT_FX`'s motion
## and in the light decay, exactly where finding 4 put it.
##
## Sized in GROUND units, like everything else a caller here reasons about.
const PARTICLE_BODY := {
	"spark": {"girth": 9.0, "long": 25.0},
	"shard": {"girth": 6.0, "long": 36.0},
	"steam": {"girth": 19.0, "long": 19.0},
}
## How fast a puff tumbles, degrees a second. Slow — a puff that spins reads as
## a thrown object; one that turns lazily reads as air.
const PUFF_SPIN := 46.0

## Which behaviour each element throws, and how it moves. The audit's finding 4
## is the reason this table exists at all: **coloured light is still a hue cue**,
## so it cannot be the accessibility answer on its own. Shape, direction and
## timing are the channels that survive colour blindness, and they are set here.
## A `life` field lived here once (per element: EMBER 0.70, FROST 0.28, ARC 0.22,
## STEAM 0.95) and NOTHING read it — the emitter's own `lifetime = 1.0` governed
## every family, so it was declared timing that never rendered (board SG-16,
## failure mode one). DELETED rather than honoured. Honouring a per-PARTICLE
## lifetime needs one emitter per element, and finding 3 of the rendering audit
## (DESIGN §13m) is emphatic that emitters are keyed by BEHAVIOUR — colour rides
## on the particle — because a shared `emit_particle` emitter that is never
## restarted is the fix to a real bug, and per-element emitters would regress it,
## break the pinned "one emitter per behaviour" check, and add a 512-cap node
## against the still-open pool budgets. It could not even be honoured per FAMILY:
## EMBER (0.70) and ARC (0.22) share the `spark` emitter with different lifetimes,
## so the field was self-contradictory as per-element data on a per-behaviour
## system — proof it was never wireable. The timing signature finding 4 requires
## survives without it: it lives in the LIGHT decay (26/s FROST·ARC vs 8/s
## EMBER·STEAM, in `impact_at`) and the particle MOTION (rise / spread / speed).
const ELEMENT_FX := {
	"EMBER": {"family": "spark", "rise": 40.0, "spread": 70.0, "speed": 230.0,
		"count": 14},
	"FROST": {"family": "shard", "rise": -40.0, "spread": 26.0, "speed": 420.0,
		"count": 12},
	"ARC": {"family": "spark", "rise": 10.0, "spread": 14.0, "speed": 520.0,
		"count": 10},
	"STEAM": {"family": "steam", "rise": 150.0, "spread": 88.0, "speed": 120.0,
		"count": 12},
}

func _build_impacts() -> void:
	for family in ["spark", "shard", "steam"]:
		var node := GPUParticles3D.new()
		node.amount = SPARK_CAPACITY
		## SG-17: the lab's PARTICLE LIFE dial lands here.
		node.lifetime = fx_particle_life(_fx_tuning)
		node.one_shot = false
		node.emitting = false          ## nothing auto-emits; everything is injected
		node.local_coords = false
		node.fixed_fps = 30
		node.interpolate = true
		node.preprocess = 0.0
		node.explosiveness = 0.0
		node.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
		## An accurate box, or Godot culls the system when the emitter node is off
		## screen and the sparks vanish mid-flight.
		node.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
		## THE BODY. See `PARTICLE_BODY` — a prism for the two that are light and
		## a lit sphere for the one that is air. Not a `QuadMesh` in
		## `BILLBOARD_PARTICLES`, which is where the sticker read came from.
		var body: Dictionary = PARTICLE_BODY[family]
		## SG-17: the lab's SPARK dial lands here, as a SCALE on the three
		## authored bodies rather than as one absolute size. The dial used to
		## write `mesh.size` on a `QuadMesh` — and SG-63 gave these particles
		## real bodies, so `draw_pass_1 as QuadMesh` has been null and the dial
		## has moved nothing since. A scale keeps the per-family proportions
		## (a shard is long, a puff is round) that an absolute size flattened.
		var figure: Vector2 = fx_particle_body(_fx_tuning, str(family))
		var girth: float = figure.x
		var long: float = figure.y
		var puff: bool = str(family) == "steam"
		var mesh: Mesh
		if puff:
			var ball := SphereMesh.new()
			ball.radius = girth
			ball.height = long * 2.0
			## Cheap on purpose: at this camera a puff is a few dozen pixels and
			## the read is the shading gradient across it, not the smoothness of
			## its rim — which the mask texture softens anyway.
			ball.radial_segments = 10
			ball.rings = 6
			mesh = ball
		else:
			var chip := PrismMesh.new()
			chip.size = Vector3(girth, long, girth)
			mesh = chip
		var mat := StandardMaterial3D.new()
		## LIT for the puff, unshaded for the two made of light. This one line is
		## most of the item: an unshaded sphere is a flat disc with a texture on
		## it, and a lit one is a thing the deck's own lamps are falling on.
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if puff \
			else BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX if puff \
			else BaseMaterial3D.BLEND_MODE_ADD
		## DISABLED, which is the whole point — the mesh is oriented by the
		## process material (down its velocity, or tumbling) rather than being
		## swung to face the camera every frame.
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
		mat.vertex_color_use_as_albedo = true    ## the colour rides on the particle
		## THE PUFF WEARS THE PAINTED PLATE AND THE SLIVERS DO NOT, and that split
		## is a bug this pass had to find twice. `puff_steam` is a soft alpha mask
		## and on a sphere it does exactly what is wanted: eats the polygonal rim
		## so the outline is cloud rather than football. `ember_particle` is a
		## painted BILLBOARD — a sprite authored to BE the particle, and it carries
		## cool rim highlights (around 130 of its lit pixels sit in the cyan-blue
		## hues). Wrapped round a prism and minified at this camera, those pixels
		## survive as coloured speckle on additive geometry, and a burst came out
		## as a rainbow firework instead of as sparks. The generated white dot has
		## no hue to leak.
		mat.albedo_texture = (_art("steam", _spark_texture()) if puff
			else _spark_texture())
		if puff:
			mat.roughness = 1.0
			mat.metallic = 0.0
			## A puff is closed, so the far side is wasted work — and with the
			## near side alpha-blended over it, drawing both reads as a double
			## exposure of the same cloud.
			mat.cull_mode = BaseMaterial3D.CULL_BACK
			## Steam is thin. A little of the light it is standing in comes
			## through it rather than stopping at the front face, which is what
			## keeps a backlit plume from reading as a grey pebble.
			mat.backlight_enabled = true
			mat.backlight = Color(0.34, 0.34, 0.34)
		else:
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.surface_set_material(0, mat)
		node.draw_pass_1 = mesh
		var process := ParticleProcessMaterial.new()
		process.gravity = Vector3.ZERO         ## per-particle velocity does the work
		process.damping_min = 1.2
		process.damping_max = 3.0
		process.scale_min = 0.4
		process.scale_max = 1.0
		if puff:
			## Tumbling, about its own axis. A still sphere and a billboard are
			## the same picture; a turning one is not, and the turn is what says
			## there is a body under the mask.
			process.particle_flag_rotate_y = true
			process.angle_min = 0.0
			process.angle_max = 360.0
			process.angular_velocity_min = -PUFF_SPIN
			process.angular_velocity_max = PUFF_SPIN
		else:
			## Lying along its own flight. A spark that curves swings with the
			## curve, which is the parallax a camera-facing card cannot have.
			process.particle_flag_align_y = true
		var curve := CurveTexture.new()
		var ramp := Curve.new()
		ramp.add_point(Vector2(0.0, 1.0))
		ramp.add_point(Vector2(1.0, 0.0))
		curve.curve = ramp
		process.scale_curve = curve
		process.alpha_curve = curve
		node.process_material = process
		node.layers = LAYER_FIGURES
		## A5. Particles do not cast. `cast_shadow` defaults ON, so three
		## 512-capacity systems were rendering into the shadow map of the one
		## shadowed light for no visible gain — the blob decals under everything
		## already carry the grounding.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_sparks[family] = node
		node.emitting = true

	## Eight pooled flashes, as reinforcement rather than as the cue. Shadowless
	## and with no volumetric contribution, or a fog-lit scene keeps a trail of
	## every hit for as long as the fog takes to settle.
	for i in FLASH_POOL:
		var light := OmniLight3D.new()
		light.light_energy = 0.0
		light.omni_range = 300.0 * WORLD_SCALE
		light.omni_attenuation = 1.6
		light.shadow_enabled = false
		light.light_volumetric_fog_energy = 0.0
		add_child(light)
		_flashes.append(light)


## A hit landed here, this hard, of this element.
func impact_at(ground: Vector2, element: String, damage: float) -> void:
	var spec: Dictionary = ELEMENT_FX.get(element, ELEMENT_FX.EMBER)
	var node: GPUParticles3D = _sparks.get(str(spec.family))
	var tint: Color = SkyGearData.ELEMENTS.get(element, {}).get("color", Color.WHITE)
	if node != null:
		var at := Vector3(ground.x * WORLD_SCALE, 48.0 * WORLD_SCALE,
			ground.y * WORLD_SCALE)
		var count: int = int(clampf(float(spec.count) * (0.4 + damage / 70.0),
			4.0, float(spec.count) * 2.0))
		var spread: float = deg_to_rad(float(spec.spread))
		for i in count:
			## Injected one at a time, into an emitter that is never restarted —
			## which is the whole fix. A `restart()` here would erase whatever is
			## still in the air from the last kill.
			var yaw: float = _impact_rng.randf() * TAU
			var pitch: float = _impact_rng.randf_range(0.0, spread)
			var dir := Vector3(sin(pitch) * cos(yaw), cos(pitch), sin(pitch) * sin(yaw))
			var speed: float = float(spec.speed) * _impact_rng.randf_range(0.55, 1.35)
			var velocity := dir * speed * WORLD_SCALE
			velocity.y += float(spec.rise) * WORLD_SCALE
			var scatter := Vector3(_impact_rng.randf_range(-14.0, 14.0), 0.0,
				_impact_rng.randf_range(-14.0, 14.0)) * WORLD_SCALE
			node.emit_particle(Transform3D(Basis(), at + scatter), velocity,
				Color(tint.r * 1.7, tint.g * 1.7, tint.b * 1.7, 1.0), Color.WHITE,
				GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY
					| GPUParticles3D.EMIT_FLAG_COLOR)
	if _flashes.is_empty():
		return
	var light: OmniLight3D = _flashes[_flash_next % _flashes.size()]
	_flash_next += 1
	light.light_color = tint
	light.light_energy = clampf(1.4 + damage / 40.0, 1.4, 5.0)
	## Timing is a channel colour blindness cannot take away. Frost snaps out,
	## Ember lingers — see `_flash_decay`.
	light.set_meta("decay", 26.0 if element == "FROST" or element == "ARC" else 8.0)
	light.position = Vector3(ground.x * WORLD_SCALE, 70.0 * WORLD_SCALE,
		ground.y * WORLD_SCALE)


## --- THE PROJECTILE CORE — EMISSIVE GEOMETRY, NOT A PAINTED SPRITE -----------
##
## Board SG-40, the first ask of the post-parity era, verbatim: "Can we get
## better VFX particles? Instead of these 2D sprites that look like they are
## cheap?" The screenshot was the fireball bolts — every projectile head in the
## game was `_spark`, a flat billboard of `_spark_texture()` turned to face the
## camera. Turned to face the camera is exactly the tell: a bolt that is the same
## disc from every angle reads as a sticker, not as a thing travelling through the
## air. The ribbon trail (VFX-PLAN §3, already 3D) gave it a wake; the HEAD stayed
## 2D, and the head is what the eye tracks.
##
## The fix is a real oriented mesh: one low-poly sphere, scaled into a teardrop
## STRETCHED ALONG ITS VELOCITY and lit from its own emission so the glow chain
## catches it. It is 3D because it is oriented in 3D — the long axis swings to the
## line of flight, it parallaxes against the deck, and its own light spills onto
## the planking under it. None of which a billboard can do.
##
## PER ELEMENT, and the identity is in the MOTION, not the hue — the research
## audit's finding 4, the same rule `ELEMENT_FX` (impacts) and `ELEMENT_RIBBON`
## (trails) already carry. A colour-blind player has to read a Frost slug from an
## Ember lick by SHAPE and BEHAVIOUR: Frost is a long narrow shard that sheds a
## tight downward wake; Ember is a fat throbbing ball that sheds rising flecks;
## Arc is a hard fast slug that flickers violently; Steam is a soft round billow.
## HOSTILE and CANNON are the two in-flight ordnance identities — the enemy's
## oxblood danger shot (SG-3's language) and our deck gun's brass slug — kept
## visibly apart from the player's spellcraft and from each other.
##
##   stretch  the long axis as a multiple of girth — a shard is long, steam round
##   girth    the cross-section radius, ground units
##   pulse    hz the emission throbs at (0 = steady) — a flame flickers, ice does not
##   emit     emission energy, well over the 1.05 glow threshold so it blooms
##   shed     which behaviour-keyed emitter it sheds motes into ("" = none)
##   sheds    motes per frame — kept low; the emitters self-cap at SPARK_CAPACITY
##   wake     ground units/s the shed motes travel back and up (Ember rises, Frost sinks)
const ELEMENT_BOLT := {
	"EMBER": {"stretch": 2.0, "girth": 15.0, "pulse": 11.0, "emit": 3.2,
		"shed": "spark", "sheds": 2, "wake": 60.0},
	"FROST": {"stretch": 3.4, "girth": 9.0, "pulse": 0.0, "emit": 4.2,
		"shed": "shard", "sheds": 1, "wake": -34.0},
	"ARC": {"stretch": 2.6, "girth": 11.0, "pulse": 33.0, "emit": 4.0,
		"shed": "spark", "sheds": 1, "wake": 12.0},
	"STEAM": {"stretch": 1.4, "girth": 21.0, "pulse": 3.0, "emit": 2.2,
		"shed": "steam", "sheds": 2, "wake": 120.0},
	## The enemy's inbound shot. Blunt, heavy, no flicker and it SHEDS NOTHING — a
	## lane full of these has to stay legible, so they do not smear the air behind
	## them the way a spell does. Oxblood danger comes from the colour the caller
	## passes, the SG-3 hostile language.
	##
	## GIRTH 16 -> 7 (board SG-103). Owner, build-44: *"Projectiles from enemies
	## are way larger than they should be, and dont look very cool."* He is right
	## and the amount is measurable rather than a matter of taste, because the
	## build this shot was first authored in RECORDS its size:
	## `src/storm-dusk/_render_entities.js::drawBolts` puts the bolt's hard body
	## at `ctx.arc(q.x, q.y, 7 * q.k)` — radius seven ground units, fourteen
	## across. `girth` is a cross-section RADIUS too (see the key above), so 16
	## was drawing a body 32 units wide: wider than a crewman's whole footprint,
	## and 2.3x what the game it is a port of ever drew. At the shipped camera,
	## a bolt crossing the captain's own ground subtends 50 screen pixels of an
	## 860-pixel frame at 16 and 22 at 7 — a quarter of the hero's on-screen
	## height, against a tenth.
	##
	## READABILITY IS NOT WHAT SHRANK. The browser's own note above `drawBolts`
	## names the three things that make an inbound shot trackable — the oxblood
	## colour, the GROUND SHADOW that says where it will cross you, and the nine
	## samples of TAIL that turn a flicker into a direction. All three are
	## untouched: `_shadow("b%d", ..., 40.0, 0.38)` still draws a 40-unit mark on
	## the planking under a 14-unit body, and the ribbon still runs off the
	## simulation's own trail. Pillar 6 asks that enemy fire be readable before
	## it is dangerous; matching the size the browser reads at is the opposite of
	## a regression against it. Stretch, pulse and shed are unchanged — this is
	## the blunt orb it always was, at the size it always should have been.
	"HOSTILE": {"stretch": 1.7, "girth": 7.0, "pulse": 0.0, "emit": 2.6,
		"shed": "", "sheds": 0, "wake": 0.0},
	## Our deck cannon. A tight brass slug — long and clean like Frost's shard but
	## warm, so ours and theirs crossing the same lane cannot be confused.
	"CANNON": {"stretch": 3.0, "girth": 12.0, "pulse": 0.0, "emit": 3.4,
		"shed": "", "sheds": 0, "wake": 0.0},
}

## THE DEFAULT PATH IS THE MESH (board SG-40 item 6: the old sprites retire). The
## painted `_spark` billboard stays in the tree as the FALLBACK tier — the
## project's standing rule that everything has one — reached through `_bolt_head`
## when this flag is off. Flipping it false is the whole rollback, the same shape
## as `USE_MESH_CAPTAIN`.
const USE_MESH_CORES := true

## The core pool cap. Bolts can flood a lane, and every performance problem this
## project has had was an unbounded collection — so the cores are reserved like
## the telegraphs and the ribbons: past this many live, a new bolt keeps its
## ribbon trail and its ground shadow (the readable halves) but goes without an
## emissive body. Twenty-four simultaneous lit bolts is already more than a
## saturated wave produces; measured on a posed flood, live cores peak well under
## it.
const CORE_CAP := 24

## THE LIGHT POOL, DELIBERATELY SMALLER THAN THE CORE POOL. A per-bolt omni is the
## expensive half of this feature, and a lane of thirty lit bolts is exactly the
## SG-34 hot-pool problem reborn. So only the nearest N cores to the camera — the
## ones whose light actually reads on the deck in front of the player — get one;
## the rest glow from emission and bloom alone. Six holds the near cluster and
## costs six small omnis at worst. Low energy, small radius, no shadow, no
## volumetric contribution: an accent under the bolt, never a floodlight (SG-34).
const CORE_LIGHT_POOL := 6
const CORE_LIGHT_ENERGY := 2.1
const CORE_LIGHT_RANGE := 230.0        ## ground units


func _build_cores() -> void:
	## One sphere for every bolt in the game. Low-poly on purpose: at this camera a
	## bolt is a few dozen pixels and the read comes from the elongation and the
	## glow, not from the silhouette's smoothness.
	_core_mesh = SphereMesh.new()
	_core_mesh.radius = 1.0
	_core_mesh.height = 2.0
	_core_mesh.radial_segments = 8
	_core_mesh.rings = 5
	for i in CORE_LIGHT_POOL:
		var light := OmniLight3D.new()
		light.light_energy = 0.0
		light.omni_range = CORE_LIGHT_RANGE * WORLD_SCALE
		light.omni_attenuation = 1.8
		light.shadow_enabled = false
		## Same discipline as the impact flashes: a bolt light that feeds the fog
		## leaves a smear of every shot for as long as the haze takes to settle.
		light.light_volumetric_fog_energy = 0.0
		add_child(light)
		_core_lights.append(light)


## A bolt's emissive body at `ground`, `height` off the deck, travelling along
## `dir` (a ground-plane heading). `element` keys `ELEMENT_BOLT`; `colour` is the
## hue the emission and the shed motes ride. `size_mul` scales the whole thing so
## a spell head and a cannon slug can share one function. Returns false when the
## mesh path is disabled, so the caller can fall back to the painted sprite.
func _core(key: String, ground: Vector2, height: float, dir: Vector2,
		element: String, colour: Color, size_mul: float = 1.0) -> bool:
	if not USE_MESH_CORES or _core_mesh == null:
		return false
	var spec: Dictionary = ELEMENT_BOLT.get(element, ELEMENT_BOLT.EMBER)
	## The cap gate, before anything is claimed — a new core over the reserve is
	## simply not drawn (the ribbon and shadow carry it), never half-built.
	if not _cores.has(key) and _cores.size() >= CORE_CAP:
		return true
	_used[key] = true
	var node: MeshInstance3D = _cores.get(key)
	if node == null:
		node = _free_cores.pop_back() if not _free_cores.is_empty() else _make_core()
		node.visible = true
		if node.get_parent() == null:
			add_child(node)
		_cores[key] = node
		_peak_cores = maxi(_peak_cores, _cores.size())
	## Orient the long axis (local +Y — the sphere's poles) down the line of
	## flight, then scale IN THE LOCAL FRAME by writing the basis columns directly.
	## `Basis.scaled()` multiplies rows, which is a scale in the PARENT frame and is
	## exactly the airstream bug (F-03) — so the long axis would land on the wrong
	## column. Columns are the transformed axes; scaling them is a local scale.
	var flight := Vector3(dir.x, 0.0, dir.y)
	if flight.length_squared() < 1e-6:
		flight = Vector3.FORWARD
	var rot := Basis(Quaternion(Vector3.UP, flight.normalized()))
	var g: float = float(spec.girth) * size_mul * WORLD_SCALE
	var long: float = g * float(spec.stretch)
	var b := Basis(rot.x * g, rot.y * long, rot.z * g)
	node.transform = Transform3D(b, Vector3(ground.x * WORLD_SCALE,
		height * WORLD_SCALE, ground.y * WORLD_SCALE))
	## The emission throbs for the elements that flicker and holds steady for the
	## ones that do not — the timing channel, keyed off a per-bolt seed so two
	## bolts do not pulse in lockstep.
	var mat := node.material_override as StandardMaterial3D
	if mat != null:
		var seed: float = float(hash(key) % 1000) * 0.041
		var throb: float = 1.0 if float(spec.pulse) <= 0.0 \
			else 1.0 + 0.22 * sin(_flicker * float(spec.pulse) + seed)
		mat.albedo_color = Color(colour.r * 0.5, colour.g * 0.5, colour.b * 0.5)
		mat.emission = colour
		mat.emission_energy_multiplier = float(spec.emit) * throb
	## The light request — collected now, resolved against the whole frame's cores
	## in `_flush_core_lights` so only the nearest few actually light.
	if float(spec.emit) > 0.0:
		_core_light_req.append({
			"pos": Vector3(ground.x * WORLD_SCALE, height * WORLD_SCALE,
				ground.y * WORLD_SCALE),
			"col": colour})
	## And the wake — motes shed off the TAIL into the behaviour-keyed emitter that
	## already serves impacts. Never `restart()`ed, injected one at a time, so a
	## lane of bolts overlaps instead of erasing each other (the emit_particle fix).
	## This is the "particle trail" half of the ask, and it carries the motion
	## signature: Ember's flecks rise and linger in the air, Frost's shards snap
	## back tight and low, Steam billows up.
	if str(spec.shed) != "" and float(spec.sheds) > 0.0:
		_core_shed(spec, ground, height, dir, colour)
	return true


func _make_core() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _core_mesh
	var mat := StandardMaterial3D.new()
	## Lit, NOT unshaded — the emission is what makes it glow and bloom, and an
	## unshaded material ignores emission entirely (albedo only). A faint lit body
	## under the emission is also what keeps it reading as a solid object rather
	## than a flat additive smear.
	mat.emission_enabled = true
	mat.metallic = 0.0
	mat.roughness = 0.4
	## Opaque. A projectile is a solid hot thing; the trail is the additive half.
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.layers = LAYER_FIGURES
	return node


## Motes off a bolt's tail, into the shared behaviour emitter. A hair behind the
## head and scattered, with a velocity that carries the element's motion.
func _core_shed(spec: Dictionary, ground: Vector2, height: float, dir: Vector2,
		colour: Color) -> void:
	var node: GPUParticles3D = _sparks.get(str(spec.shed))
	if node == null:
		return
	var back := dir.normalized() if dir.length_squared() > 1e-6 else Vector2.DOWN
	var tail := ground - back * float(spec.girth) * float(spec.stretch) * 0.8
	var tint := Color(colour.r * 1.7, colour.g * 1.7, colour.b * 1.7, 1.0)
	for i in int(spec.sheds):
		var at := Vector3(
			(tail.x + _impact_rng.randf_range(-8.0, 8.0)) * WORLD_SCALE,
			(height + _impact_rng.randf_range(-6.0, 6.0)) * WORLD_SCALE,
			(tail.y + _impact_rng.randf_range(-8.0, 8.0)) * WORLD_SCALE)
		## Drift straight back off the tail, plus the element's own rise or sink.
		var vel := Vector3(-back.x, 0.0, -back.y) * 40.0
		vel.y += float(spec.wake)
		vel += Vector3(_impact_rng.randf_range(-30.0, 30.0), 0.0,
			_impact_rng.randf_range(-30.0, 30.0))
		node.emit_particle(Transform3D(Basis(), at), vel * WORLD_SCALE, tint,
			Color.WHITE, GPUParticles3D.EMIT_FLAG_POSITION
				| GPUParticles3D.EMIT_FLAG_VELOCITY | GPUParticles3D.EMIT_FLAG_COLOR)


## Resolve the frame's light requests: the nearest N cores to the camera get a
## small omni, everything else glows from emission and bloom alone. This is where
## a lane of thirty bolts stops being thirty lights — the budget the SG-34 pass
## fought a hot pool over, held by construction.
func _flush_core_lights() -> void:
	if _core_lights.is_empty():
		_core_light_req.clear()
		return
	var eye: Vector3 = camera.global_position if camera != null else Vector3.ZERO
	## Nearest first. A partial sort would do for a handful of lights, but the
	## request list is already small (<= CORE_CAP) so a full sort is honest and
	## cheap, and it cannot leave a far bolt lit over a near one.
	_core_light_req.sort_custom(func(a, b):
		return (a.pos as Vector3).distance_squared_to(eye) 			< (b.pos as Vector3).distance_squared_to(eye))
	for i in _core_lights.size():
		var light: OmniLight3D = _core_lights[i]
		if i < _core_light_req.size():
			var req: Dictionary = _core_light_req[i]
			light.position = req.pos
			light.light_color = req.col
			light.light_energy = CORE_LIGHT_ENERGY
		else:
			light.light_energy = 0.0
	_core_light_req.clear()


## The bolt head: an emissive mesh core by default, the painted sprite as the
## fallback tier (board SG-40 item 5). One door for the three things that throw a
## head — a projectile in flight, a hitscan spell's leading dash, a Mortar shell.
func _bolt_head(key: String, ground: Vector2, height: float, dir: Vector2,
		element: String, colour: Color, size: float) -> void:
	if _core(key, ground, height, dir, element, colour):
		return
	## Art-missing / mesh-disabled fallback: the old painted spark, unchanged.
	_spark(key, ground, height, size, colour)


## --- TRAILS THAT ARE GEOMETRY, NOT DECALS ------------------------------------
##
## VFX-PLAN.md §3, and the half of "projectiles and vfx from the player still
## look like 2D instead of 3D" that is a real bug rather than a design decision.
## There were two separate faults and they need separate fixes:
##
##   * **The chain, the bolt and the beam were `_streak_texture` DECALS.** A
##     decal is a mark projected onto whatever is under it, which for these was
##     always the planking. At a camera pitched 41 degrees a mark on the floor
##     and an object in the air are the same picture only when the object in the
##     air is lying on the floor, so a bolt of lightning read as a scuff.
##   * **The hitscan shapes had no travelling body at all.** Arc, cone, line and
##     aoe resolve on the frame they are cast, so between the captain and the
##     boarder she killed there was, correctly, nothing — and the player was
##     right that there is no projectile, because there was not one.
##
## Both are answered by the same object: a RIBBON, real triangles in the air,
## with each pair of vertices offset perpendicular to the LINE OF SIGHT so the
## strip always turns its width toward the camera. That is the difference
## between geometry that happens to be 3D and geometry that reads as 3D — a
## ribbon lying in a fixed plane disappears to a hairline at half the angles the
## deck presents.
##
## `docs/VFX-RESEARCH-AUDIT.md` is emphatic that this must not be an
## `ImmediateMesh` per projectile rebuilt every frame, and it is not: there is
## ONE mesh for the whole scene, cleared and rewritten once a frame, and
## everything airborne writes into it. One draw call, one budget, one place to
## look when it gets expensive.
##
## THE GROUND DECAL STAYS under every one of them. It is the readable half — it
## says where on the deck the thing will cross you, which is the question a
## player is actually asking — and the audit says to keep the two separate for
## exactly that reason. What has changed is that the effect now also exists
## above it.

## The whole scene's ribbon budget, in vertices. A strip of N points costs
## (N-1)*6, so this is about sixty simultaneous ribbons of ten points — far more
## than a keg chain into a Whip can produce, and a hard stop rather than a hope.
const RIBBON_VERTS := 3600
## Where a cast leaves her hand and where it arrives on a boarder, in ground
## units above the planking. Not taste: the captain is 176 units sole to crown,
## so 108 is her hand and 62 is a SCRAPPER's chest. A trail drawn between those
## two heights is a trail that starts and ends on a body.
const RIBBON_HAND := 108.0
const RIBBON_CHEST := 62.0

## HOW EACH ELEMENT MOVES, in the air.
##
## The audit's finding 4 again, applied to trails rather than to impacts:
## coloured light is still a hue cue, so it cannot carry element identity by
## itself. A player who cannot tell teal from orange has to be able to tell a
## Frost bolt from an Ember one by its SHAPE, and these are the four shapes.
##
##   width     the ribbon at its fattest, in ground units across
##   waver     how far the path wanders off the straight line
##   hz        and how fast — the difference between a flame and a stationary bar
##   zig       a hard alternating kink instead of a smooth wander
##   rise      how far the middle of the path lifts (Steam) or sags (Frost)
##   segments  how many points the path is cut into; a kink needs more than a curve
##   hot       how far over 1.0 the colour is pushed, so the glow chain catches it
##
## `hot` is deliberately modest and all four are near each other. The first pass
## ran 1.9 to 2.6 on the theory that brighter is more dramatic, and the result
## was that every trail in the game came out WHITE: the tonemapper is Filmic at a
## white point of 6, so a colour whose brightest channel is at 2.6 has its other
## two channels dragged up with it and an Arc bolt and an Ember one are the same
## pale streak. 1.45 is the number the decals already use for the same reason and
## it is over the 1.05 glow threshold, so these still bloom — they just bloom in
## their own colour, which is the entire point of having four of them.
##   grow      the width at the head against the width at the tail
const ELEMENT_RIBBON := {
	## Ember licks. Fat, slow, wandering, and it opens out as it travels — a
	## thrown flame rather than a shot.
	"EMBER": {"width": 34.0, "waver": 22.0, "hz": 5.0, "zig": 0.0, "rise": 16.0,
		"segments": 12, "hot": 1.45, "grow": 1.40},
	## Frost is a shard. Dead straight, narrow, hard at both ends, faintly barbed
	## and it does not open out: the whole read is that it went exactly where it
	## was pointed and stopped.
	"FROST": {"width": 17.0, "waver": 0.0, "hz": 0.0, "zig": 8.0, "rise": -12.0,
		"segments": 8, "hot": 1.55, "grow": 0.85},
	## Arc branches. A hard alternating kink, reseeded off the clock so it crawls
	## along its own length rather than sitting still.
	"ARC": {"width": 24.0, "waver": 6.0, "hz": 21.0, "zig": 40.0, "rise": 30.0,
		"segments": 14, "hot": 1.50, "grow": 1.0},
	## Steam billows. The broadest and the slowest, rising as it goes, and drawn
	## soft enough that it reads as a volume of air rather than as a rope.
	"STEAM": {"width": 62.0, "waver": 36.0, "hz": 2.2, "zig": 0.0, "rise": 78.0,
		"segments": 12, "hot": 0.85, "grow": 1.75},
}

var _ribbon_mesh: ArrayMesh
var _ribbon_node: MeshInstance3D
var _ribbon_verts := 0
## The scratch buffers, allocated once at full capacity and never resized. See
## `_ribbons_end` for why this is not an ImmediateMesh.
var _rib_pos: PackedVector3Array = PackedVector3Array()
var _rib_uv: PackedVector2Array = PackedVector2Array()
var _rib_col: PackedColorArray = PackedColorArray()
var _ribbon_peak := 0
var _ribbon_dropped := 0
## How often a wrecked deck cannon puffs. See the turret block in `_sync_all`.
const SMOKE_EVERY := 0.10
var _smoke_clock := 0.0
## Vent plume ticks actually emitted (SG-59) — the harness's proof the plume
## path runs, since `emit_particle` itself is fire-and-forget.
var _vent_puffs := 0
## And how often an aura throws a mote up through itself.
const MOTE_EVERY := 0.05
var _mote_clock := 0.0

## THE BLADE-DRIVEN WEAPON TRAIL — VFX-PLAN.md §6, board SG-18.
##
## The Cleave's sweeping ribbon was `_sweep_ribbon`, an arc drawn where the
## blade APPROXIMATELY is: a circle segment swept by the EFFECT's clock, at a
## radius the skill table says, while the actual cutlass — bone-mounted,
## animated, five swing VARIANTS deep — went wherever the clip took it. Two
## authorities on one number is STATUS failure mode two wearing a sword.
##
## So the trail is the blade's own path now: the tip is sampled every frame off
## the hand mount (`SkyGearRig3D.blade_points`, the same `BoneAttachment3D` the
## cutlass hangs from), kept for TRAIL_LIFE seconds, and drawn as the two-layer
## ribbon the beam already proved out — a wide soft sleeve with a narrow hot
## core inside it. Whatever the animation does — swing2, spin, combo, the
## Boilerwright's retargeted axe arcs — the trail does, because it is not a
## drawing OF the swing, it is the swing's own wake. When the rig or the mount
## is absent (billboard tier), `_sweep_ribbon` still draws, so every fallback
## tier keeps a swing tell.
##
## CAPPED twice: the sample buffer is a ring of TRAIL_SAMPLES and the strip is
## written through `_ribbon`, which budgets against RIBBON_VERTS like every
## other trail on this deck.
const TRAIL_LIFE := 0.16             ## seconds a sample survives — dies with the swing
const TRAIL_SAMPLES := 24            ## the ring; at 60 fps a whole swing fits
var _trail: Array[Dictionary] = []   ## {tip: Vector3 ground units, at: seconds}
var _trail_element := "EMBER"        ## the last player swing's element, for the shape
var _trail_colour := Color("#ff9a4a")


func _blade_trail_live() -> bool:
	return _captain != null and _captain.held != null \
		and is_instance_valid(_captain.held) and _trail.size() >= 2


## Sample the blade NOW, during a swing. Called from `_sync_captain`, so the
## trail exists exactly as long as the simulation says the attack does — no
## timer of its own to outlive or undercut the clip.
func _sample_blade() -> void:
	if _captain == null:
		return
	if _captain.held == null or not is_instance_valid(_captain.held):
		_captain.mount_hand()
	var ends := _captain.blade_points()
	if ends.size() != 2:
		return
	var tip: Vector3 = ends[1] / WORLD_SCALE
	if not _trail.is_empty() and tip.distance_to(Vector3(_trail.back().tip)) < 1.0:
		return
	_trail.append({"tip": tip, "at": _flicker})
	while _trail.size() > TRAIL_SAMPLES:
		_trail.pop_front()


## Age the buffer and draw what is left. Runs every frame inside the ribbon
## batch whether or not she is swinging, because the last few samples of a
## finished swing are the follow-through — they fade inside TRAIL_LIFE.
func _emit_blade_trail() -> void:
	while not _trail.is_empty() and _flicker - float(_trail[0].at) > TRAIL_LIFE:
		_trail.pop_front()
	var n := _trail.size()
	if n < 2:
		return
	var spec: Dictionary = ELEMENT_RIBBON.get(_trail_element, ELEMENT_RIBBON.EMBER)
	var hue := _ribbon_tint(_trail_colour, float(spec.hot))
	## The element's width, FLOORED AND CAPPED for a blade. Steam's 62-unit
	## billow is right for a gust and wrong wrapped round a figure — at 1.9x
	## sleeve it was a 118-unit crescent that swallowed the Boilerwright whole.
	var breadth: float = clampf(float(spec.width), 20.0, 38.0)
	var pts := PackedVector3Array()
	var sleeve_w := PackedFloat32Array()
	var core_w := PackedFloat32Array()
	var sleeve_c := PackedColorArray()
	var core_c := PackedColorArray()
	pts.resize(n)
	sleeve_w.resize(n)
	core_w.resize(n)
	sleeve_c.resize(n)
	core_c.resize(n)
	for i in n:
		pts[i] = _trail[i].tip
		var u: float = float(i) / float(n - 1)
		var age: float = clampf(1.0 - (_flicker - float(_trail[i].at)) / TRAIL_LIFE,
			0.0, 1.0)
		## Bright and full at the blade, tapered to nothing where the swing was —
		## the same comet logic as the bolt trails, aged instead of travelled.
		var fade: float = age * (0.14 + 0.86 * u)
		var body: float = 0.30 + 0.70 * u
		sleeve_w[i] = breadth * 0.5 * 1.9 * body
		core_w[i] = breadth * 0.5 * 0.50 * body
		sleeve_c[i] = Color(hue.r, hue.g, hue.b, 0.30 * fade)
		core_c[i] = Color(hue.r, hue.g, hue.b, 0.95 * fade)
	## The sleeve first and the core over it — `_beam_ribbon`'s construction,
	## ported per the plan: two layers is the difference between a blade's wake
	## and a line of paint.
	_ribbon(pts, sleeve_w, sleeve_c)
	_ribbon(pts, core_w, core_c)


## VOLUMETRIC FIELDS — VFX-PLAN.md §4, and the one item on that list whose cost
## had to be measured before it could be committed to.
##
## `Environment.volumetric_fog_enabled` turns on a froxel pass that runs whether
## or not anything is in it, so the honest question is not "what does a Field
## cost" but "what does having Fields available cost on every frame of every
## run". `tests/bench.gd` at 60 boarders, on this machine:
##
##     off   avg 7.79   p99  9.54 ms
##     on    avg 7.92   p99 10.70 ms
##
## An eighth of a millisecond in the average and one in the tail, which is
## affordable — but only with temporal reprojection left on, and that trade is
## written at the flag itself rather than here.
##
## `volumetric_fog_density` stays at ZERO globally, per the audit: only the
## `FogVolume`s contribute, so the deck itself is not fogged and the lanterns are
## not lighting a global medium. One flag, one place, and turning it off here
## takes the whole feature out without touching `_sync_auras`.
const VOLUMETRIC_FIELDS := true
var _fog: Dictionary = {}            ## key -> FogVolume, one per live aura


func _build_ribbons() -> void:
	_ribbon_mesh = ArrayMesh.new()
	_rib_pos.resize(RIBBON_VERTS)
	_rib_uv.resize(RIBBON_VERTS)
	_rib_col.resize(RIBBON_VERTS)
	_ribbon_node = MeshInstance3D.new()
	_ribbon_node.mesh = _ribbon_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	## The colour rides on the vertex, which is what lets four elements and a
	## dozen simultaneous effects share one material and therefore one draw.
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _ribbon_texture()
	## No depth WRITE — additive strips that write depth occlude each other and a
	## Whip crossing its own jump goes black at the crossing. Depth TEST stays on,
	## so a cargo run still hides a bolt passing behind it.
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_ribbon_node.material_override = mat
	_ribbon_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	## LAYER_FIGURES, for the reason at the top of this file: a ring belongs on
	## the deck, and a decal projecting onto a bolt of lightning is a ring painted
	## across the lightning.
	_ribbon_node.layers = LAYER_FIGURES
	## An explicit box. An ImmediateMesh rebuilt every frame has no useful bounds
	## of its own until it is built, so without this the whole batch is culled on
	## the frame it appears — which is the frame it matters.
	_ribbon_node.custom_aabb = AABB(Vector3(-14, -1, -16), Vector3(28, 8, 32))
	add_child(_ribbon_node)


## The strip's cross-section: opaque hot core, soft to nothing at both edges.
## The taper across the ribbon is what stops it reading as a length of pipe, and
## it belongs in the texture rather than in the geometry so a strip stays two
## triangles wide.
func _ribbon_texture() -> ImageTexture:
	if _made.has("ribbon"):
		return _made.ribbon
	var w := 8
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var v: float = (float(y) + 0.5) / float(h) * 2.0 - 1.0
		## 2.2 rather than a linear falloff: a linear edge on an additive strip
		## reads as a hard band because the eye is looking at the derivative.
		var a: float = pow(clampf(1.0 - absf(v), 0.0, 1.0), 2.2)
		## And a hotter centre inside it, so an Ember bolt has a bright core in
		## its orange the way a real one does. A THIRD of the edge value and no
		## more: pushed to 0.7 it saturated every element to white, which is the
		## same mistake `hot` was making one multiplication later.
		var core: float = pow(clampf(1.0 - absf(v) * 2.4, 0.0, 1.0), 2.0)
		for x in w:
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(a + core * 0.34, 0.0, 1.0)))
	_made.ribbon = _with_mips(img)
	return _made.ribbon


## THE COLOUR A RIBBON IS ACTUALLY WRITTEN AT, and it is not the palette colour.
##
## Two corrections, both of them learned from the first pass coming out white:
##
##   * **Saturate first.** Arc is #7adcff — a pale sky blue with a red channel at
##     0.48 — and on an ADDITIVE strip anything with a floor that high is white
##     with a blue idea behind it. The decals get away with the palette value
##     because they mix against the deck; a strip that adds does not. Pushing
##     saturation before brightness keeps the hue as the value climbs.
##   * **Normalise the value, then scale it.** Otherwise `hot` means something
##     different for every element, because the four palette colours are at four
##     different brightnesses to start with.
##
## The palette value is still what the RINGS are drawn in, so the two halves of
## an effect agree; this is the same hue at the saturation additive blending
## needs to keep it.
static func _ribbon_tint(colour: Color, hot: float) -> Color:
	var pure := Color.from_hsv(colour.h, clampf(colour.s * 1.45, 0.0, 1.0), 1.0)
	return Color(pure.r * hot, pure.g * hot, pure.b * hot, 1.0)


## THE BATCH IS FILLED INTO ARRAYS AND HANDED OVER ONCE.
##
## The first version used `ImmediateMesh` and `surface_add_vertex`, which is the
## obvious way to write this and is what `VFX-PLAN.md` §3 proposed. Measured, it
## cost **6.4 ms of the frame** at the bench's sixty-boarder load — more than
## twice the entire rest of the renderer — because three engine calls per vertex
## at three and a half thousand vertices is ten thousand calls out of GDScript
## every frame, and that crossing is the cost rather than the geometry.
##
## Same triangles, same one draw, filled into preallocated `Packed*Array`s at
## full capacity and handed to `ArrayMesh` in a single call. 6.4 ms became 0.9.
## The arrays are never reallocated; only the slice actually used is copied.
func _ribbons_begin() -> void:
	_ribbon_verts = 0
	_aim_dashes_drawn = 0


func _ribbons_end() -> void:
	if _ribbon_mesh == null:
		return
	_ribbon_mesh.clear_surfaces()
	_ribbon_peak = maxi(_ribbon_peak, _ribbon_verts)
	if _ribbon_verts < 3:
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _rib_pos.slice(0, _ribbon_verts)
	arrays[Mesh.ARRAY_TEX_UV] = _rib_uv.slice(0, _ribbon_verts)
	arrays[Mesh.ARRAY_COLOR] = _rib_col.slice(0, _ribbon_verts)
	_ribbon_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## One ribbon. `points` are in GROUND units as (x, height above the planking, y)
## so no caller ever has to think in metres; `half` is the half-width at each
## point and `tint` its colour and alpha there.
##
## Per-point rather than per-ribbon because the TAPER is the readability: a trail
## that ends in a hard rectangle reads as a plank, and one that ends in nothing
## reads as speed.
func _ribbon(points: PackedVector3Array, half: PackedFloat32Array,
		tint: PackedColorArray) -> void:
	var n := points.size()
	if n < 2 or camera == null or _ribbon_mesh == null:
		return
	## Budgeted BEFORE anything is written, so a ribbon is either whole or absent.
	## Half a lightning bolt is worse than no lightning bolt.
	var needed := (n - 1) * 6
	if _ribbon_verts + needed > RIBBON_VERTS:
		_ribbon_dropped += 1
		return
	var eye := camera.global_position
	var side := PackedVector3Array()
	side.resize(n)
	for i in n:
		var here: Vector3 = points[i] * WORLD_SCALE
		var along: Vector3
		if i == 0:
			along = points[1] - points[0]
		elif i == n - 1:
			along = points[n - 1] - points[n - 2]
		else:
			along = points[i + 1] - points[i - 1]
		if along.length_squared() < 1e-9:
			along = Vector3.FORWARD
		along = along.normalized()
		## THE BILLBOARDING, and the whole reason this reads as 3D rather than as
		## a flat sticker: the width runs perpendicular BOTH to the path and to the
		## line of sight, recomputed per point per frame. A strip built in a fixed
		## plane vanishes to a hairline whenever the camera looks along that plane,
		## which on a deck seen from 41 degrees is most of the directions a skill
		## is ever fired in.
		var s := along.cross((eye - here).normalized())
		if s.length_squared() < 1e-8:
			s = along.cross(Vector3.UP)
		side[i] = s.normalized() if s.length_squared() > 1e-8 else Vector3.RIGHT
	for i in n - 1:
		var a: Vector3 = points[i] * WORLD_SCALE
		var b: Vector3 = points[i + 1] * WORLD_SCALE
		var wa: Vector3 = side[i] * half[i] * WORLD_SCALE
		var wb: Vector3 = side[i + 1] * half[i + 1] * WORLD_SCALE
		var ua: float = float(i) / float(n - 1)
		var ub: float = float(i + 1) / float(n - 1)
		var at := _ribbon_verts + i * 6
		_rib_pos[at] = a - wa; _rib_uv[at] = Vector2(ua, 0.0); _rib_col[at] = tint[i]
		_rib_pos[at + 1] = a + wa; _rib_uv[at + 1] = Vector2(ua, 1.0); _rib_col[at + 1] = tint[i]
		_rib_pos[at + 2] = b - wb; _rib_uv[at + 2] = Vector2(ub, 0.0); _rib_col[at + 2] = tint[i + 1]
		_rib_pos[at + 3] = a + wa; _rib_uv[at + 3] = Vector2(ua, 1.0); _rib_col[at + 3] = tint[i]
		_rib_pos[at + 4] = b + wb; _rib_uv[at + 4] = Vector2(ub, 1.0); _rib_col[at + 4] = tint[i + 1]
		_rib_pos[at + 5] = b - wb; _rib_uv[at + 5] = Vector2(ub, 0.0); _rib_col[at + 5] = tint[i + 1]
	_ribbon_verts += needed



## A path from A to B with one element's handwriting on it.
##
## `lift` is how far the middle of it rises above the straight line — a chain
## jump arcs over the deck, a Lance does not — and `phase` is what keeps a given
## effect's wander stable from frame to frame instead of boiling: pass the same
## number for the same effect and it wanders smoothly, pass a new one and it
## crawls.
##
## Nothing wanders at the ENDS. The envelope is a half-sine, so a trail's tip is
## always exactly on the target it hit: a bolt drawn a metre wide of the boarder
## it killed is the picture telling a lie the simulation did not.
func _element_path(from: Vector3, to: Vector3, element: String, lift: float,
		phase: float) -> PackedVector3Array:
	var spec: Dictionary = ELEMENT_RIBBON.get(element, ELEMENT_RIBBON.EMBER)
	var n := int(spec.segments)
	var out := PackedVector3Array()
	out.resize(n + 1)
	var span := to - from
	var flat := Vector3(span.x, 0.0, span.z)
	var across := Vector3(-flat.z, 0.0, flat.x)
	across = across.normalized() if across.length_squared() > 1e-6 else Vector3.RIGHT
	for i in n + 1:
		var t := float(i) / float(n)
		var p: Vector3 = from + span * t
		var envelope: float = sin(t * PI)
		p.y += (lift + float(spec.rise)) * envelope
		p += across * sin(t * 5.4 + phase) * float(spec.waver) * envelope
		if float(spec.zig) > 0.0:
			var flip: float = 1.0 if i % 2 == 0 else -1.0
			p += across * flip * float(spec.zig) * envelope
			p.y += (0.55 if i % 3 == 0 else -0.35) * float(spec.zig) * envelope
		out[i] = p
	return out


## The common case: a path drawn as a comet — fat and bright at the head, tapered
## to nothing at the tail. `scale` widens or narrows the whole thing against the
## element's own width, and `head` is which end is leading (1.0 the last point,
## 0.0 the first) because a beam and a bolt taper opposite ways.
func _ribbon_path(points: PackedVector3Array, element: String, tint: Color,
		alpha: float, scale: float = 1.0, head: float = 1.0) -> void:
	var spec: Dictionary = ELEMENT_RIBBON.get(element, ELEMENT_RIBBON.EMBER)
	var n := points.size()
	if n < 2:
		return
	var half := PackedFloat32Array()
	var cols := PackedColorArray()
	half.resize(n)
	cols.resize(n)
	var hue := _ribbon_tint(tint, float(spec.hot))
	for i in n:
		var t: float = float(i) / float(n - 1)
		var lead: float = t if head >= 0.5 else 1.0 - t
		## Wide at the head, nothing at the tail, and rounded off at the very tip
		## so it is a comet rather than a wedge.
		var shape: float = lerpf(1.0, float(spec.grow), lead)
		shape *= smoothstep(0.0, 0.26, lead)
		shape *= 0.62 + 0.38 * smoothstep(0.0, 0.14, 1.0 - lead)
		half[i] = float(spec.width) * 0.5 * scale * shape
		cols[i] = Color(hue.r, hue.g, hue.b, alpha * (0.22 + 0.78 * lead))
	_ribbon(points, half, cols)


## The same strip at an EVEN width, soft at both ends rather than tapered to
## one. A beam, a shockwave and a bolt in flight are three different objects and
## only one of them is a comet: putting a comet taper on something that is not
## travelling is most of what made the beam read as a smear.
##
## `pulse` runs a bright band down its length. A beam that flickers as a whole
## reads as a fault; one with something running along it reads as power going
## somewhere.
func _ribbon_even(points: PackedVector3Array, element: String, tint: Color,
		alpha: float, scale: float = 1.0, pulse: float = 0.0) -> void:
	var spec: Dictionary = ELEMENT_RIBBON.get(element, ELEMENT_RIBBON.EMBER)
	var n := points.size()
	if n < 2:
		return
	var half := PackedFloat32Array()
	var cols := PackedColorArray()
	half.resize(n)
	cols.resize(n)
	var hue := _ribbon_tint(tint, float(spec.hot))
	for i in n:
		var t: float = float(i) / float(n - 1)
		var shape: float = smoothstep(0.0, 0.09, t) * smoothstep(0.0, 0.09, 1.0 - t)
		half[i] = float(spec.width) * 0.5 * scale * (0.35 + 0.65 * shape)
		var beat: float = 1.0 if pulse <= 0.0 else 0.72 + 0.28 * sin(t * 13.0 - _flicker * pulse)
		cols[i] = Color(hue.r, hue.g, hue.b, alpha * shape * beat)
	_ribbon(points, half, cols)


## A HITSCAN SHOT, GIVEN A BODY.
##
## Lance, Whip and the sentries all resolve on the frame they fire. That stays
## true — making them travel would be a balance change wearing a visual one, and
## the browser does not do it either — but there is a window of about a fifth of
## a second in which the effect exists, and a shot crossing 520 units inside that
## window is a shot the eye can follow.
##
## So the head runs out along the line over the first 42% of the effect's life
## and the tail chases it over the rest: a dash of light that leaves her hand,
## crosses the deck and is gone. Nothing new is tracked, nothing is added to the
## simulation, and the damage still lands on frame one.
##
## `lift` is how far the middle of the flight arcs over the deck. A Lance is flat
## and a Whip's jump is not — a chain link between two boarders is an arc through
## the air, which is exactly what `VFX-PLAN.md` §3 says it should have been.
func _bolt_ribbon(fid: int, from: Vector2, to: Vector2, element: String,
		colour: Color, alpha: float, progress: float, phase: float,
		lift: float) -> void:
	var head_t: float = ease(clampf(progress / 0.42, 0.0, 1.0), 0.62)
	var tail_t: float = clampf((progress - 0.24) / 0.76, 0.0, 1.0)
	if head_t - tail_t < 0.02:
		return
	var a3 := Vector3(from.x, RIBBON_HAND, from.y)
	var b3 := Vector3(to.x, RIBBON_CHEST, to.y)
	var tail := a3.lerp(b3, tail_t)
	var head := a3.lerp(b3, head_t)
	## The lift is scaled by how much of the flight is still drawn. Held at full
	## height while the tail catches up, a jump reads as a standing hoop rather
	## than as a whip going over.
	_ribbon_path(_element_path(tail, head, element, lift * (head_t - tail_t), phase),
		element, colour, alpha)
	## And the head as an emissive core (SG-40), because the ribbon is the MOTION
	## and this is the object doing the moving. Oriented down the flight line
	## (tail→head); the ribbon is its wake. Without it a bolt has no front, which
	## is most of what a projectile is.
	if head_t < 0.995:
		_bolt_head("bh%d" % fid, Vector2(head.x, head.z), head.y,
			Vector2(head.x - tail.x, head.z - tail.z), element, colour,
			float(ELEMENT_RIBBON[element].width) * 2.2)


## A HELD BEAM. Full length on its first frame, because that is what a beam is,
## but with a body: a wide soft sleeve and a narrow hot core inside it. Two
## layers is what the audit asks for on the weapon trail, and it is the whole
## difference between a beam and a line — one layer at any width reads as paint.
func _beam_ribbon(from: Vector2, to: Vector2, element: String, colour: Color,
		alpha: float, _progress: float, phase: float) -> void:
	var a3 := Vector3(from.x, RIBBON_HAND, from.y)
	var b3 := Vector3(to.x, RIBBON_CHEST + 14.0, to.y)
	var path := _element_path(a3, b3, element, 8.0, phase)
	## The sleeve first and the core over it, so the core is what the glow chain
	## finds. Both additive, so the order is only about which one is brighter.
	_ribbon_even(path, element, colour, alpha * 0.30, 1.9)
	_ribbon_even(path, element, colour, alpha * 0.95, 0.50, 26.0)


## THE SWING, IN THE AIR.
##
## The most-seen effect in the game by a wide margin: the captain's Cleave fires
## every 0.36 s for an entire run and the Boilerwright's Scald every 0.6, and
## both were a painted fan lying on the planking. A fan on the floor is a good
## answer to "how far does this reach" and no answer at all to "she just swung
## something", which is the thing the player is actually watching for.
##
## The blade LEADS and the trail follows it round. And the ribbon descends as it
## sweeps — 132 units off the deck at the start of the arc down to 58 at the end
## — so it reads as a diagonal chop through a body rather than as a hoop drawn
## round her waist. That diagonal is why it has to be geometry: a decal cannot be
## at one height at one end and a different height at the other.
func _sweep_ribbon(fx: Dictionary, _fid: int, centre: Vector2, radius: float,
		element: String, colour: Color, alpha: float, progress: float) -> void:
	var dir: float = float(fx.get("direction", 0.0))
	var half_arc: float = float(fx.get("arc", 1.7)) * 0.5
	var lead: float = clampf(progress / 0.52, 0.0, 1.0)
	var back: float = clampf((progress - 0.28) / 0.72, 0.0, 1.0)
	if lead - back < 0.03:
		return
	var spec: Dictionary = ELEMENT_RIBBON.get(element, ELEMENT_RIBBON.EMBER)
	var hue := _ribbon_tint(colour, float(spec.hot))
	var n := 9
	var pts := PackedVector3Array()
	var half := PackedFloat32Array()
	var cols := PackedColorArray()
	pts.resize(n)
	half.resize(n)
	cols.resize(n)
	for i in n:
		var u: float = float(i) / float(n - 1)
		var t: float = lerpf(back, lead, u)
		var a: float = dir + lerpf(-half_arc, half_arc, t)
		## Bellied out through the middle of the swing, because that is where the
		## blade is furthest from her and it is what makes an arc read as an arc
		## rather than as a segment of a circle drawn round a point.
		var r: float = radius * (0.78 + 0.16 * sin(t * PI))
		pts[i] = Vector3(centre.x + cos(a) * r, lerpf(132.0, 58.0, t),
			centre.y + sin(a) * r)
		half[i] = float(spec.width) * 0.66 * (0.18 + 0.82 * u)
		cols[i] = Color(hue.r, hue.g, hue.b, alpha * (0.16 + 0.84 * u))
	_ribbon(pts, half, cols)


## A CONE OF MOVING AIR. Five ribbons blown out of her rather than one wedge
## painted on the deck. The Boilerwright's whole class is about where the steam
## IS, and steam that exists only as a mark on the floor is steam you can stand
## in without noticing.
func _gust_ribbon(fx: Dictionary, fid: int, centre: Vector2, radius: float,
		element: String, colour: Color, alpha: float, progress: float) -> void:
	var dir: float = float(fx.get("direction", 0.0))
	var half_arc: float = float(fx.get("arc", 0.9)) * 0.5
	var reach: float = radius * (0.62 + progress * 0.5)
	var hz := float(ELEMENT_RIBBON[element].hz)
	## Five, and an odd number deliberately: an even fan has a seam straight down
	## the middle, which is exactly where the player is aiming.
	var lanes := 5
	for k in lanes:
		var u: float = float(k) / float(lanes - 1)
		var a: float = dir + lerpf(-half_arc, half_arc, u)
		var out := Vector2(cos(a), sin(a))
		var start := Vector3(centre.x + out.x * 30.0, RIBBON_HAND,
			centre.y + out.y * 30.0)
		var stop := Vector3(centre.x + out.x * reach, RIBBON_CHEST + 30.0,
			centre.y + out.y * reach)
		## Soft. Steam at full strength was five hard white chevrons stamped on
		## the deck rather than a cloud you could stand in — an additive strip 76
		## units across at 0.78 is a wall, not a gust.
		_ribbon_path(_element_path(start, stop, element, 0.0,
			float(fid) + float(k) * 2.1 + _flicker * hz),
			element, colour, alpha * 0.48, 0.58)


## A SHOCKWAVE, STANDING UP OFF THE DECK. The ring on the planking says where a
## Pulse or a vent REACHES, which is the gameplay question; this says what it is,
## which is a wall of air going out and up. Both, because they answer different
## questions, and the flat one on its own was reading as a stencil.
func _wave_ribbon(centre: Vector2, radius: float, element: String, colour: Color,
		alpha: float, progress: float) -> void:
	if radius < 30.0:
		return
	var spec: Dictionary = ELEMENT_RIBBON.get(element, ELEMENT_RIBBON.EMBER)
	var hue := _ribbon_tint(colour, float(spec.hot))
	## Twenty segments closes a circle without a visible corner at this camera
	## distance, and closing it costs one extra point rather than a second ribbon.
	var n := 20
	var pts := PackedVector3Array()
	var half := PackedFloat32Array()
	var cols := PackedColorArray()
	pts.resize(n + 1)
	half.resize(n + 1)
	cols.resize(n + 1)
	var rise: float = 22.0 + 96.0 * progress
	var fade: float = alpha * (1.0 - progress * 0.35)
	for i in n + 1:
		var a: float = TAU * float(i) / float(n)
		pts[i] = Vector3(centre.x + cos(a) * radius, rise,
			centre.y + sin(a) * radius)
		half[i] = float(spec.width) * 0.42 * (1.0 - progress * 0.5)
		cols[i] = Color(hue.r, hue.g, hue.b, fade)
	_ribbon(pts, half, cols)


## --- THE BURST — AN EXPLOSION WITH A BODY (board SG-63) ----------------------
##
## `burst` is the game's death-and-detonation effect: every boarder that dies,
## every crate broken, every powder keg (radius 175), the hulk coming apart
## (260), the Boiler taking a hit, the captain being hurt. It was the LAST shape
## with nothing in the air at all — VFX-PLAN §3 gave arc, cone, line, chain,
## beam, circle and aoe a body in 2026-07-31 and this one was skipped, so the
## most-seen violent moment in the game was a painted cartoon starburst
## (`burst_impact.png`) projected flat onto the planking. It is the sticker the
## owner photographed: a hard-edged star lying on the floor where a thing had
## just come apart in the air.
##
## Three parts, and each answers a different half of "did it land, how hard":
##
##   the SHARDS   a radial spray of ribbons, thrown out of the point on a real
##                HEMISPHERE of directions — not a flat ring — each arcing up and
##                falling back under its own sag, so the spray has depth against
##                the deck at 41 degrees instead of lying in it.
##   the DEBRIS   a one-shot throw into the behaviour-keyed emitters, scaled by
##                RADIUS rather than by damage, so a keg reads bigger than a
##                gremlin. Fired ONCE per effect however many frames it lives —
##                see `_burst_new`.
##   the MARK     the ground ring stays, because it is still the readable half
##                (the audit's rule, §3's rule): it says where on the deck the
##                blast reached. It is drawn through `_ring_texture()` now
##                rather than through the painted plate, for the reason recorded
##                at `_sync_effects`.
##
## Element identity rides on `ELEMENT_RIBBON` exactly as every other shape's
## does, so a Frost detonation throws narrow sagging splinters and an Ember one
## throws fat rising licks — motion and timing, never hue.
## How far the shell races out, as a multiple of the blast radius, and how much
## of that the crown ring above it keeps.
const BURST_REACH := 1.05
const BURST_CROWN := 0.52

## The fired-once ledger. A ring of the last N effect ids that have thrown their
## debris, scanned linearly — fixed size, allocated at build, never grown, which
## is the pool law applied to a bookkeeping array. Sixty-four is more than a keg
## chain into a full deck produces in one frame, and an id that ages out of it
## has long since expired (a burst lives 0.18–0.45 s).
const BURST_MARKS := 64
var _burst_fired: PackedInt32Array = PackedInt32Array()
var _burst_head := 0

## How much debris a blast of this radius throws, and how wide. Capped hard: the
## emitters self-cap at SPARK_CAPACITY, but a keg chain into forty boarders must
## not spend the whole budget on one frame's worth of kills.
const BURST_DEBRIS_MAX := 18


## Has this burst thrown its debris yet? First call for an id answers false and
## records it; every later call in the effect's life answers true. Ordering-free
## — it does not assume the renderer sees the effect on the tick it was created,
## which is the kind of assumption that breaks the day the sim's update order
## moves.
func _burst_new(fid: int) -> bool:
	if _burst_fired.is_empty():
		_burst_fired.resize(BURST_MARKS)
		for i in BURST_MARKS:
			_burst_fired[i] = -1
	for i in BURST_MARKS:
		if _burst_fired[i] == fid:
			return false
	_burst_fired[_burst_head] = fid
	_burst_head = (_burst_head + 1) % BURST_MARKS
	return true


## THE SHELL. Two rings of shockwave standing off the deck — a wide one racing
## out and a smaller one riding above it — which together read as the top of a
## dome coming off the point. The SPRAY is the debris (`_burst_debris`), which
## is real oriented geometry now and does that job honestly.
##
## THIS WAS A RADIAL FAN OF RIBBONS FIRST, and it did not work — recorded
## because the reason is a property of `_ribbon` that any future radial effect
## will hit. A ribbon's width runs perpendicular BOTH to its path and to the
## line of sight, which is exactly what stops a strip vanishing to a hairline —
## but a spray throws shards in EVERY direction, and the ones travelling along
## the view ray have a path parallel to the sight line, so the cross product
## that sets the width collapses. Those shards came out as fat pale lozenges
## lying over the fight rather than as splinters. A ring is safe from it by
## construction: no part of a circle around the camera's own axis is ever
## parallel to the ray through it.
func _burst_ribbon(fid: int, centre: Vector2, radius: float, element: String,
		colour: Color, alpha: float, progress: float) -> void:
	## Out fast, then decelerating — the shape of a shockwave rather than of
	## something expanding at a constant rate.
	var out: float = ease(clampf(progress, 0.0, 1.0), 0.42)
	if out < 0.02:
		return
	## The seed is unused by the rings themselves, but a burst that reports its
	## own id is a burst the harness can tell apart from its neighbour.
	## Held DOWN, deliberately. Two rings and a spray of additive bodies through
	## the same pixels is three things adding, and additive things that overlap
	## go white — which is how every element ends up looking identical. Each
	## layer here is drawn at less than it would be drawn at alone.
	var fade: float = alpha * (1.0 - progress * 0.25) * 0.70
	_wave_ribbon(centre, radius * (0.35 + out * BURST_REACH), element, colour, fade,
		progress)
	## And the crown: a tighter ring, higher and later, so the two together are a
	## dome's silhouette and not one hoop. Half the alpha, because the second one
	## is a hint and the first one is the reach.
	if progress > 0.10:
		_wave_ribbon(centre, radius * (0.18 + out * BURST_CROWN), element, colour,
			fade * 0.42, clampf(progress * 1.35, 0.0, 1.0))
	if fid < 0:
		return


## The debris, thrown once. Scaled by the BLAST rather than by a damage number,
## because a burst is the one effect whose size is already the thing being said.
func _burst_debris(centre: Vector2, radius: float, element: String,
		colour: Color) -> void:
	var spec: Dictionary = ELEMENT_FX.get(element, ELEMENT_FX.EMBER)
	var node: GPUParticles3D = _sparks.get(str(spec.family))
	if node == null:
		return
	var count: int = clampi(int(float(spec.count) * (0.4 + radius / 130.0)),
		5, BURST_DEBRIS_MAX)
	## 1.2 rather than the 1.7 a HIT throws at. A burst puts three times as many
	## bodies through the same pixels, and the tonemapper is Filmic at a white
	## point of 6: stack enough over-bright orange and the channels clip at
	## different rates, which comes out as coloured speckle rather than as fire.
	## Same lesson `ELEMENT_RIBBON.hot` records one multiplication later.
	## SATURATED before it is brightened, and only to 1.2 — the same two lessons
	## `_ribbon_tint` records. Additive bodies stacked through the same pixels go
	## white, so a burst drawn at the palette value comes out as a white spray
	## with an orange idea behind it, which is how every element ends up looking
	## the same. A HIT throws at 1.7; a burst puts three times as many bodies in
	## one place, so it throws lower.
	var pure := Color.from_hsv(colour.h, clampf(colour.s * 1.45, 0.0, 1.0), 1.0)
	var tint := Color(pure.r * 1.2, pure.g * 1.2, pure.b * 1.2, 1.0)
	## A detonation throws over the whole upper hemisphere; a hit throws in a
	## cone (`ELEMENT_FX.spread`). That difference is the whole reason this is
	## not a call to `impact_at` with the radius in the damage slot.
	for i in count:
		var yaw: float = _impact_rng.randf() * TAU
		var pitch: float = _impact_rng.randf_range(-0.25, 1.25)
		var dir := Vector3(cos(pitch) * cos(yaw), sin(pitch), cos(pitch) * sin(yaw))
		var speed: float = radius * _impact_rng.randf_range(2.2, 5.0)
		var velocity := dir * speed * WORLD_SCALE
		velocity.y += float(spec.rise) * WORLD_SCALE
		var at := Vector3(centre.x, 40.0 + radius * 0.25, centre.y) * WORLD_SCALE
		node.emit_particle(Transform3D(Basis(), at), velocity, tint, Color.WHITE,
			GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY
				| GPUParticles3D.EMIT_FLAG_COLOR)
	## And it lights the deck for an instant, off the SAME pool and the SAME
	## decay rule as a hit — Frost snaps, Ember lingers (finding 4's timing
	## channel). A keg going off in the dark that does not light anything is the
	## thing the flashes exist to fix.
	if _flashes.is_empty():
		return
	var light: OmniLight3D = _flashes[_flash_next % _flashes.size()]
	_flash_next += 1
	light.light_color = colour
	light.light_energy = clampf(1.6 + radius / 55.0, 1.6, 5.5)
	light.set_meta("decay", 26.0 if element == "FROST" or element == "ARC" else 8.0)
	light.position = Vector3(centre.x, 70.0, centre.y) * WORLD_SCALE


## THE SHELL. A Mortar resolves at the target on the frame it is cast, so this is
## not a projectile in flight — it is the THROW, drawn in the tenth of a second
## after it happened. Which is honest: what the player did was lob something, and
## the arc says so without a shell having to arrive late and contradict a damage
## number already floating over the boarder.
func _lob_ribbon(fid: int, from: Vector2, to: Vector2, element: String,
		colour: Color, progress: float) -> void:
	var travel: float = clampf(progress / 0.40, 0.0, 1.0)
	var tail: float = clampf((progress - 0.16) / 0.52, 0.0, 1.0)
	if travel - tail < 0.03:
		return
	## The apex comes from the throw's own length, floored so a short lob still
	## leaves the deck and capped low. 0.55 of the distance was the first number
	## and it put a full-range Mortar's shell 340 units up, which at 41 degrees of
	## pitch is off the top of the frame: the camera has almost no sky in it, so an
	## arc that would look right from the side is an arc that leaves the picture.
	var apex: float = clampf(from.distance_to(to) * 0.34, 90.0, 190.0)
	var n := 10
	var pts := PackedVector3Array()
	pts.resize(n + 1)
	for i in n + 1:
		var g: float = lerpf(tail, travel, float(i) / float(n))
		var p := from.lerp(to, g)
		pts[i] = Vector3(p.x, RIBBON_HAND + apex * sin(g * PI), p.y)
	_ribbon_path(pts, element, colour, clampf(1.0 - progress * 1.2, 0.0, 1.0), 1.0)
	## The shell itself, an emissive core (SG-40). Same argument as the bolt head:
	## the ribbon is the throw and this is the thing that was thrown. Oriented
	## along the ground travel — the arc's own tangent reads at this camera.
	var lead := from.lerp(to, travel)
	_bolt_head("lob%d" % fid, lead,
		RIBBON_HAND + apex * sin(travel * PI), to - from, element, colour,
		float(ELEMENT_RIBBON[element].width) * 2.0)


## Real clouds, at real distances, off both rails.
##
## WHERE THEY GO IS NOT A TASTE DECISION EITHER, and working it out is the thing
## three previous passes at the skybox skipped. At 41 degrees of pitch with a 36
## degree vertical field, the frame looks between 23 and 59 degrees BELOW
## horizontal — the horizon is never in it at any zoom — and a ray leaving the
## camera downward crosses the deck plane 7.6 metres below itself, so it clears
## the port gunwale only if it also travels 4.7 metres sideways in that distance.
## Solve the two together and the sky over the rail is a wedge roughly 17 to 30
## degrees off the keel and 23 to 40 degrees down, widening as it rises. Put a
## cloud outside that wedge and it is behind the ship's own planking.
##
## So each one is placed by the angle it should appear at rather than by a
## coordinate, and the coordinate is derived. Anything else is guessing, and the
## last two attempts at this file guessed and put the clouds under the hull.
## The angles below are where each cloud sits at the MIDDLE of its drift; it
## enters the wedge high and shallow and leaves it low and wide, because that is
## what an object passing a moving camera does.
##
## SIX, AND NOT TEN. The first pass put ten out there and they were a fog: at
## these distances one quad is 180 metres across and covers half the frame, so
## two overlapping is two painted cloudscapes multiplied together and the seam
## where one sorts in front of the other reads as a straight cut through the
## middle of a cloud. Six, spread across four azimuths and two phases, never has
## more than two in the wedge at once. Screenshotted at one, three and six before
## settling; `tools/sky_shot.gd` is what that was done with.
const CLOUD_FIELD := [
	## azimuth off the keel (negative is port), degrees below horizontal, layer
	{"az": -26.0, "el": 29.0, "far": false, "phase": 0.00},
	{"az":  27.0, "el": 30.0, "far": false, "phase": 0.30},
	{"az": -23.0, "el": 25.0, "far": false, "phase": 0.55},
	{"az":  24.0, "el": 26.0, "far": false, "phase": 0.80},
	{"az": -25.0, "el": 26.0, "far": true, "phase": 0.15},
	{"az":  26.0, "el": 27.0, "far": true, "phase": 0.65},
]
## How far a cloud travels before it is put back out ahead. 200 metres at 7.2 a
## second is a 28-second cycle, and with four near clouds phased across it one is
## crossing the wedge roughly every seven.
const CLOUD_WRAP := 20000.0
## Quad widths, not cloud widths: the painted mass is about a third of its
## 2048-pixel sheet and the rest is transparent. 180 metres at 300 subtends 11
## degrees of cloud, 400 at 640 subtends 9 — an object you notice against a
## 36-degree frame rather than a wall across it.
const CLOUD_NEAR_WIDTH := 18000.0
const CLOUD_FAR_WIDTH := 40000.0


## THE TRANSPORT FLEET, built once. See `SKYSHIPS` for where they are and why
## there is nowhere else for them to be.
##
## Built here rather than through `_sync_prop_model`, and the difference is the
## point: that path claims and releases per frame because the deck's props come
## and go with the stow. These never move house. They are the wreck's bargain
## (SG-15) — set dressing outside the fight envelope, built once, never entering
## the sim, the cargo rects or the per-wave stow, and nothing on the deck can
## path to one.
##
## SCALED BY LENGTH, not by height, which is the one place a ship differs from
## every other entry in the model table. `_sync_prop_model` scales a prop so its
## measured height matches `PROP_HEIGHT` because a crate is judged standing up. A
## hull is judged along its length — the handoff spec sizes all five that way
## ("600-900 ground units long ... up to ~1400 for the barge") — and after
## `tools/static_model.gd`'s +90 rest facing that length is the span's Z.
##
## ABSENT ART COSTS THE FLEET, NOT THE FRAME: a row whose scene is missing is
## skipped with a warning, exactly as the wreck's own texture is.
func _build_skyships() -> void:
	for row: Dictionary in SKYSHIPS:
		var key := str(row.model)
		var path := model_path(key)
		if not ResourceLoader.exists(path):
			push_warning("skyship %s: no %s — the fleet flies one short" % [key, path])
			continue
		var packed := load(path) as PackedScene
		var ship: Node3D = packed.instantiate() as Node3D if packed != null else null
		if ship == null:
			continue
		var span := measure_span(ship)
		if span.z <= 0.0:
			ship.free()
			push_warning("skyship %s: no mesh to measure" % key)
			continue
		var s: float = float(row.length) * WORLD_SCALE / span.z
		ship.scale = Vector3(s, s, s)
		ship.rotation.y = deg_to_rad(float(row.yaw))
		var at: Vector3 = row.at
		ship.position = at * WORLD_SCALE
		## No shadow, and it is not a micro-optimisation. The sun's shadow atlas
		## is budgeted for a deck 23 metres long; a hull 56 metres out in front of
		## it either falls outside the range entirely or eats the resolution the
		## boarders' contact shadows are made of.
		for mi: MeshInstance3D in ship.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ship)
		## The model key rides along so the arrival tier can name a hull rather
		## than an index into a table it does not own — a row whose scene was
		## missing is not in `_skyships` at all, so index N here and index N in
		## `SKYSHIPS` are not the same ship the moment any art is absent.
		## …and its measured HEIGHT in ground units, because the arrival tier
		## parks a hull by its DECK rather than by its keel and the deck is the
		## keel plus this. Measured once, here, off the same span the scale came
		## from — re-measuring it at the berth would be a second answer to a
		## question this line already asked.
		_skyships.append({"node": ship, "at": at, "heave": float(row.heave),
			"period": maxf(0.5, float(row.period)), "model": key,
			"tall": span.y * float(row.length) / span.z})


## Their only motion, and it is deliberately the smallest one that reads.
##
## A ship pinned exactly still against two drifting cloud layers reads as a
## decal on the sky; a ship that TRAVELS accumulates, wanders out of the measured
## wedge, and needs a wrap rule and a reason for it. A phase-offset heave does
## neither — it is bounded by construction, it cannot leave the band, it is a
## pure function of run time so two runs of a screenshot tool agree, and at 18 to
## 34 units against a 700-unit hull it is a ship riding air rather than a ship
## bouncing. The periods are coprime-ish so the four never pump together.
func _sync_skyships() -> void:
	var t: float = float(Time.get_ticks_msec()) * 0.001
	for i in _skyships.size():
		var s: Dictionary = _skyships[i]
		var node: Node3D = s.node
		if not is_instance_valid(node):
			continue
		var at: Vector3 = s.at
		var w: float = TAU / float(s.period)
		node.position.y = (at.y + float(s.heave) * sin(w * t + float(i) * 1.7)) * WORLD_SCALE
		## And a whisper of roll off the same phase, a quarter turn behind the
		## heave, because a hull that rises without leaning is a lift.
		node.rotation.z = deg_to_rad(0.9 * sin(w * t + float(i) * 1.7 - PI * 0.5))
	## And then ONE of them may be somewhere else entirely. See `_sync_arrival`:
	## it runs after this on purpose and overwrites the hull that is forward,
	## which is `_fly()`'s exact relationship to `place()` — the general rule
	## writes everything, the special case bends one of them, and the special
	## case is one function you can delete.
	_sync_arrival()


## A SHIP PULLS UP TO THE FRONT — board SG-134 stage one, and half of the owner's
## second sentence.
##
## The hull for this wave leaves its station in the ambient wedge, comes forward
## and up to `SKYSHIP_BOW_HOLD`, holds there for the fight, and rides the wave's
## own clear countdown back. **Its station is empty sky while it is away**, at no
## cost and with nothing to keep in step, because the ship on the bow and the gap
## in the wedge are the same node.
##
## WRITES NOTHING AND READS THREE FIELDS. `game.wave`, `game.wave_time`,
## `game.wave_clear_time`. Delete this function and the wave plays out
## identically; delete `ARRIVAL_HULL_ORDER` and the fleet is SG-102 exactly.
func _sync_arrival() -> void:
	if game == null or _skyships.is_empty():
		return
	var hull := arrival_hull_for_wave(int(game.wave))
	if hull == "":
		return
	## NO EARLY RETURN AT u = 0, and that is not a micro-optimisation forgone.
	## `_sync_skyships` rewrites only `.y`, so skipping this at the station would
	## leave x and z carrying the last frame the hull WAS forward — the ship
	## would come back down but never come back across, and the wedge would be
	## permanently one hull short with a duplicate parked on the bow. The lerp at
	## u = 0 is the station exactly; letting it run is what makes `u` the whole of
	## the state rather than most of it.
	var u := arrival_u(float(game.wave_time), float(game.wave_clear_time))
	for s: Dictionary in _skyships:
		if str(s.get("model", "")) != hull:
			continue
		var node: Node3D = s.node
		if not is_instance_valid(node):
			return
		## The heave this hull is riding THIS frame, taken back out of the
		## position `_sync_skyships` just wrote and put back on at the far end —
		## so a ship at the bow hold is still riding air rather than pinned to a
		## coordinate, and the two motions compose instead of one erasing the
		## other.
		##
		## AND IT IS COMPUTED FROM THE STATION, NEVER FROM WHERE THE SHIP IS.
		## `_sync_skyships` rewrites only `.y` every frame, so lerping the node's
		## own `.position` toward the hold would leave x and z carrying last
		## frame's answer into this one — an accumulator, and the fleet would
		## creep bowward a little further every wave it flew. `at` is the fixed
		## point; `u` is the whole of the state.
		var at: Vector3 = s.at
		var bob: float = node.position.y / WORLD_SCALE - at.y
		var from := Vector3(at.x, at.y + bob, at.z)
		var hold := arrival_hold(float(s.get("tall", 0.0)))
		var to := Vector3(hold.x, hold.y + bob, hold.z)
		node.position = from.lerp(to, u) * WORLD_SCALE
		return


func _build_clouds() -> void:
	var art := {
		false: _texture("res://assets/art/env/clouds_near.png"),
		true: _texture("res://assets/art/env/clouds_far.png"),
	}
	if art[false] == null and art[true] == null:
		return
	var centre_z: float = (SkyGearGame.DECK_RECT.position.y
		+ SkyGearGame.DECK_RECT.size.y * 0.5)
	## One material per layer rather than one per cloud, so the far six are a
	## single draw state and the near four another.
	var mats := {}
	for far in [false, true]:
		if art[far] == null:
			continue
		var m := StandardMaterial3D.new()
		m.albedo_texture = art[far]
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		## Y-billboarded: they yaw to face the camera and stay upright, which is
		## what a cloud bank does and what keeps them square-on however far round
		## the deck the captain has dragged the camera. It is also the only
		## orientation that survives the wheel without needing a second thought —
		## the GPU redoes it from the live view matrix every frame.
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.billboard_keep_scale = true
		## THE FOG MUST NOT REACH THEM. Depth fog at 0.011 per metre is total by
		## 400 metres, so left alone every one of these arrives as a flat patch of
		## fog colour — which is exactly the failure the flat cloud sea they
		## replace was already committing.
		m.disable_fog = true
		## The far layer is dimmer and cooler, which is the aerial perspective the
		## fog would have given them if it could be trusted at this range.
		m.albedo_color = (Color(0.60, 0.64, 0.84, 0.80) if far
			else Color(0.92, 0.90, 1.0, 0.96))
		mats[far] = m
	for spec in CLOUD_FIELD:
		var far: bool = bool(spec.get("far", false))
		if not mats.has(far):
			continue
		var range_units: float = CLOUD_FAR_RANGE if far else CLOUD_NEAR_RANGE
		var az := deg_to_rad(float(spec.az))
		var el := deg_to_rad(float(spec.el))
		var node := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var width: float = CLOUD_FAR_WIDTH if far else CLOUD_NEAR_WIDTH
		## The sheets are 2048x512, and a quad that does not keep that ratio
		## stretches a painted cloud into a smear.
		quad.size = Vector2(width, width * 0.25) * WORLD_SCALE
		node.mesh = quad
		node.material_override = mats[far]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		## A cloud a third of a kilometre wide has no business in the shadow
		## atlas or the SSAO pass either.
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(node)
		var home := Vector3(
			range_units * sin(az),
			-range_units * tan(el),
			centre_z - range_units * cos(az))
		_cloud_bands.append({
			"node": node,
			"home": home,
			## Stored as distance already travelled rather than as a fraction, so
			## `_sync_clouds` is one addition and a wrap.
			"phase": float(spec.get("phase", 0.0)) * CLOUD_WRAP,
		})
	_sync_clouds(0.0)

	## And another ship out there, which is the cheapest possible way to say this
	## one is not the only thing in the sky. It used to sit 4.2 metres ABOVE the
	## deck and therefore above the top of the frame; it is now inside the same
	## wedge the clouds are, low and to port, running with us.
	var far_ship := _texture("res://assets/art/env/airship_distant.png")
	if far_ship == null:
		return
	_escort = MeshInstance3D.new()
	var oq := QuadMesh.new()
	oq.size = Vector2(9000.0, 4500.0) * WORLD_SCALE
	_escort.mesh = oq
	var om := StandardMaterial3D.new()
	om.albedo_texture = far_ship
	om.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	om.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	om.billboard_keep_scale = true
	om.disable_fog = true
	om.albedo_color = Color(0.78, 0.80, 0.94, 0.72)
	_escort.material_override = om
	_escort.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_escort.position = Vector3(
		-CLOUD_NEAR_RANGE * sin(deg_to_rad(21.0)),
		-CLOUD_NEAR_RANGE * tan(deg_to_rad(26.0)),
		centre_z - CLOUD_NEAR_RANGE * cos(deg_to_rad(21.0))) * WORLD_SCALE
	add_child(_escort)


## The field drifts aft and wraps. `_flicker` rather than a private clock because
## the sway, the flames and the airstream all already run off it, and a second
## clock is a second thing to keep in step.
func _sync_clouds(_delta: float) -> void:
	for band in _cloud_bands:
		var node: MeshInstance3D = band.node
		var home: Vector3 = band.home
		var travelled: float = fmod(_flicker * CLOUD_DRIFT + float(band.phase),
			CLOUD_WRAP)
		## `home` is where the cloud sits at the MIDDLE of its run, which is the
		## angle it was placed at, so the offset is measured from half a wrap.
		node.position = Vector3(home.x, home.y,
			home.z + travelled - CLOUD_WRAP * 0.5) * WORLD_SCALE
	if _escort != null:
		## The browser swings its escort across a third of the screen on a 0.06
		## rad/s sine. Same period, same idea, in metres.
		_escort.position.x = (-CLOUD_NEAR_RANGE * sin(deg_to_rad(21.0))
			+ sin(_flicker * 0.06) * 6000.0) * WORLD_SCALE


## Streaks of moving air, as objects in the world. Unshaded, additive, and each
## one aligned to the direction it is travelling so it leans when the captain
## does — which is the half of F-03 the browser was missing when it was reviewed:
## constant rather than intermittent, and shearing with lateral movement so it
## says "you are moving through air" and not only "the ship is".
func _build_airstream() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _streak_texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.62, 0.74, 0.92, 0.19)
	## NOT billboarded. A billboard yaws to face the camera, which overrode the
	## heading and drew every streak as a horizontal bar across the screen —
	## precisely the one direction air rushing down a keel does not travel.
	## Instead each streak is a flat ribbon lying in the air, long axis along the
	## keel; a camera pitched 41 degrees projects that to a near-vertical line,
	## which is what the browser draws by hand.
	var rng := RandomNumberGenerator.new()
	rng.seed = 8811
	_stream_len.clear()
	for i in STREAK_COUNT:
		var node := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		node.mesh = quad
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_stream.append(node)
		_stream_v.append(rng.randf())
		_stream_len.append(rng.randf_range(190.0, 430.0))
		_stream_len.append(rng.randf_range(1.1, 2.4))


## The cargo runs. In the browser these are `cargo_wall_module` billboards tiled
## down the run — 120 wide, stepped every 100, alternating mirror so one module
## does not read as a repeating stamp. Here they get to be a real box (which is
## what stops a boarder, and what the lane collision already assumes) with the
## module painted around it and a brass capping rail on top.
##
## The first version stretched the module texture over the box with alpha
## blending off, and since the module is a cut-out with a transparent surround,
## every crate rendered as a black slab. Cut-outs belong on billboards; a box
## gets a tiling texture, so this paints one.
func _build_cargo() -> void:
	var crate_mat := StandardMaterial3D.new()
	crate_mat.albedo_texture = _crate_texture()
	crate_mat.roughness = 0.88
	crate_mat.uv1_triplanar = true
	## One tile per 70 ground units. At 150 the module was larger than the box it
	## was on, so each run showed a single flat swatch of the middle of it.
	crate_mat.uv1_scale = Vector3(1.0, 1.0, 1.0) / (70.0 * WORLD_SCALE)
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color("#6d5227")
	band_mat.metallic = 0.45
	band_mat.roughness = 0.55
	## The mesh every run is built out of, and the fork this whole row turns on.
	## Without it the runs stay the solid painted box they have always been: a
	## cargo wall is what stops a boarder and what `_occluded` reasons about, so
	## it has to EXIST whatever the asset pipeline is doing — the same argument
	## `_build_boiler` makes about the object you lose the run by.
	var crate_mesh := _cargo_crate_mesh()
	var real_crates: bool = crate_mesh != null
	## A 22-unit lashed plinth under real stacks; the whole 125-unit wall
	## without them.
	var base_h: float = CARGO_PLINTH_H if real_crates else WALL_MODULE_H
	var placements: Array[Transform3D] = []
	var module := _texture("res://assets/art/props/cargo_wall_module.png")
	for r in SkyGearGame.CARGO_RECTS.size():
		var rect: Rect2 = SkyGearGame.CARGO_RECTS[r]
		var height := WALL_MODULE_H
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(rect.size.x, base_h, rect.size.y) * WORLD_SCALE
		box.mesh = mesh
		box.material_override = crate_mat
		box.position = Vector3((rect.position.x + rect.size.x * 0.5) * WORLD_SCALE,
			base_h * 0.5 * WORLD_SCALE, (rect.position.y + rect.size.y * 0.5) * WORLD_SCALE)
		add_child(box)
		## The brass capping rail, riding the top of whatever the base is. A full
		## plate over the top face turned every cargo run into a flat olive slab
		## from this angle, which is what the camera mostly sees — so it is four
		## edge bars, and over the plinth they read as the kick rail the stacks
		## are lashed down to.
		for edge in 4:
			var along_x: bool = edge < 2
			var cap := MeshInstance3D.new()
			var cm := BoxMesh.new()
			cm.size = Vector3(rect.size.x + 5.0 if along_x else 5.0, 6.0,
				5.0 if along_x else rect.size.y + 5.0) * WORLD_SCALE
			cap.mesh = cm
			var ox: float = 0.0 if along_x else (rect.size.x * 0.5) * (1.0 if edge == 2 else -1.0)
			var oz: float = 0.0 if not along_x else (rect.size.y * 0.5) * (1.0 if edge == 0 else -1.0)
			cap.material_override = band_mat
			cap.position = Vector3((rect.position.x + rect.size.x * 0.5 + ox) * WORLD_SCALE,
				(base_h + 2.0) * WORLD_SCALE,
				(rect.position.y + rect.size.y * 0.5 + oz) * WORLD_SCALE)
			add_child(cap)
		## THE CRATES THEMSELVES. Real geometry, standing on the plinth.
		if real_crates:
			_stack_cargo_run(r, rect, crate_mesh.get_aabb(), placements)
		## The painted module — SIDE-ON, and the rotation below is the fix.
		##
		## `cargo_wall_module.png` is what the browser paints its cargo with and
		## it is drawn there SIDE-ON, where its steel-blue chest is a sliver. A
		## `Decal` projects along its own -Y, and unrotated that is straight
		## DOWN, so this stamped a side-on cut-out flat across the LID of every
		## run — which at 41 degrees is most of what reaches the player, and is
		## exactly the "painted crate-stacks lying on the planking" read. SG-41
		## measured that top-face projection, hue-shifted the navy band it
		## found there, and left the projection standing.
		var modules := maxi(1, int(round(rect.size.y / WALL_MODULE_D)))
		for i in modules:
			var t: float = 0.5 if modules == 1 else float(i) / float(modules - 1)
			var z: float = lerpf(rect.position.y + 34.0, rect.end.y - 34.0, t)
			if module != null and not real_crates:
				var skin := Decal.new()
				skin.cull_mask = 0xFFFFF & ~LAYER_FIGURES & ~LAYER_SHADOWS
				skin.texture_albedo = module
				## MARKINGS on real crates, not a replacement for them. At 1.0
				## the cut-out overwrote whatever it landed on, which is the
				## whole reason the old lid read as a painting.
				skin.albedo_mix = 0.55 if real_crates else 1.0
				skin.upper_fade = 0.05
				skin.lower_fade = 0.05
				skin.normal_fade = 0.0
				## In the decal's OWN frame: local X and Z are the texture
				## plane, local Y is how far it projects. Rolled onto the run's
				## outboard face that makes X the length of one module along the
				## run, Y the width it has to punch through, and Z the height.
				skin.size = Vector3(WALL_MODULE_D, rect.size.x + 10.0,
					height + 30.0) * WORLD_SCALE
				skin.position = Vector3((rect.position.x + rect.size.x * 0.5) * WORLD_SCALE,
					height * 0.5 * WORLD_SCALE, z * WORLD_SCALE)
				skin.basis = _outboard_decal_basis(rect)
				add_child(skin)
			# and a lashing strap, so the run reads as cargo rather than as wall
			var strap := MeshInstance3D.new()
			var sm2 := BoxMesh.new()
			sm2.size = Vector3(rect.size.x + 5.0, 7.0, 5.0) * WORLD_SCALE
			strap.mesh = sm2
			strap.material_override = band_mat
			strap.position = Vector3((rect.position.x + rect.size.x * 0.5) * WORLD_SCALE,
				height * 0.62 * WORLD_SCALE, z * WORLD_SCALE)
			add_child(strap)
	## ONE MultiMesh for every cargo run on the ship — about a hundred crate
	## stacks in a single draw call. Instanced rather than `_sync_prop_model`ed
	## because these never move, never recycle and are all the same object; a
	## hundred `Node3D`s would be a hundred draw calls for a wall.
	if real_crates and not placements.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = crate_mesh
		mm.instance_count = placements.size()
		for i in placements.size():
			mm.set_instance_transform(i, placements[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)
		_cargo_crates = mmi


## The one mesh the cargo runs are instanced from — the SAME asset the deck's
## loose `crates` prop uses, which is the point: the owner's screenshot has a
## real crate standing beside a painted one, and this is what closes that gap.
##
## Returns the `Mesh` rather than the scene. A `MultiMesh` needs one mesh with
## one material and `crate_stack` is exactly that (one `MeshInstance3D`, one
## surface, 3017 triangles), so a hundred of them cost one draw call. A model
## that ever arrives with several surfaces would return the first and look
## wrong, which is why this asserts a single mesh instead of guessing.
func _cargo_crate_mesh() -> Mesh:
	var path := model_path(CARGO_CRATE_MODEL)
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var probe: Node3D = packed.instantiate() as Node3D
	if probe == null:
		return null
	var found: Mesh = null
	for child in probe.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		if found != null or mi.mesh.get_surface_count() != 1:
			## More than one mesh, or more than one material on it: this cannot
			## be one MultiMesh, and half a cargo wall is worse than the box.
			found = null
			break
		found = mi.mesh
	probe.free()
	return found


## Fill one cargo run with crate stacks, appending their transforms to `into`.
##
## Two columns and as many rows as the run is long, each stack overlapping its
## neighbour slightly so no sight line opens down the middle of a wall the
## simulation treats as solid.
func _stack_cargo_run(index: int, rect: Rect2, aabb: AABB,
		into: Array[Transform3D]) -> void:
	if aabb.size.y <= 0.0:
		return
	## Scaled so a FULL-height stack is exactly WALL_MODULE_H. See the constant:
	## standing taller than the number `_occluded` tests against would hide a
	## boarder the x-ray pass had already decided was in clear air.
	var full: float = (WALL_MODULE_H - CARGO_PLINTH_H) * WORLD_SCALE / aabb.size.y
	var crate_d: float = aabb.size.z * full
	var rows: int = maxi(2, int(round(rect.size.y * WORLD_SCALE / (crate_d * 0.92))))
	## The two columns sit inboard of the rect's own edges and OVERLAP at the
	## centre line, so the shortest pair in a row still meets in the middle.
	var col: float = rect.size.x * 0.215
	for iz in rows:
		var t: float = 0.5 if rows == 1 else float(iz) / float(rows - 1)
		var z: float = lerpf(rect.position.y + rect.size.x * 0.22,
			rect.end.y - rect.size.x * 0.22, t)
		for ix in 2:
			var j := _cargo_jitter(index, ix, iz)
			var s: float = full * lerpf(1.0 - CARGO_CRATE_JITTER, 1.0, j)
			## A HALF TURN, and it is the difference between cargo and
			## corrugated iron. One stack repeated down a run puts its rope
			## lashings in the same place every 44 units, which reads as a
			## ribbed stripe rather than as crates — the same trap the browser's
			## own module tiling avoided by "alternating mirror so one module
			## does not read as a repeating stamp". 180 degrees mirrors the
			## lashings and leaves the FOOTPRINT identical, which a quarter turn
			## would not: the stack is 55 by 48, so turning it would swing its
			## depth past the row spacing and crates would intersect.
			var flip: float = 180.0 if _cargo_jitter(index, ix + 31, iz) > 0.5 else 0.0
			var yaw: float = deg_to_rad(flip
				+ lerpf(-11.0, 11.0, _cargo_jitter(index, ix + 7, iz)))
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s))
			var x: float = rect.position.x + rect.size.x * 0.5 \
				+ (col if ix == 1 else -col) \
				+ lerpf(-3.0, 3.0, _cargo_jitter(index, ix + 53, iz))
			var foot := Vector3(x * WORLD_SCALE, CARGO_PLINTH_H * WORLD_SCALE,
				(z + lerpf(-4.0, 4.0, _cargo_jitter(index, ix + 97, iz))) * WORLD_SCALE)
			## The mesh is modelled about its own centre, so its base has to be
			## brought to the plinth rather than assumed to be at y = 0.
			var centre := Vector3(aabb.position.x + aabb.size.x * 0.5,
				aabb.position.y, aabb.position.z + aabb.size.z * 0.5)
			into.append(Transform3D(basis, foot - basis * centre))


## Deterministic per-stack variation. NOT `visual_rng` and not `randf()`: the
## deck has to be byte-identical between two photographs of it, which is the
## whole of `tools/still.gd`'s rule, and it must not consume from the stream a
## seed reproduces a run out of (SG-120). A hash of the three indices is stable
## across runs, machines and reorderings of this loop.
static func _cargo_jitter(a: int, b: int, c: int) -> float:
	var h: int = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	return float(absi(h) % 65536) / 65535.0


## The basis that rolls a cargo decal off the run's LID and onto its OUTBOARD
## face. `looking_at` aims local -Z along the projection direction; a decal
## projects along local -Y, so the quarter turn about X swings one onto the
## other. Outboard rather than inboard because that is the face the module art
## was drawn for and the face a wide shot of the deck actually shows.
static func _outboard_decal_basis(rect: Rect2) -> Basis:
	var dir := Vector3(-1.0 if rect.get_center().x < 0.0 else 1.0, 0.0, 0.0)
	return Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, deg_to_rad(90.0))


## The Boiler, as geometry. There is no painted boiler in the manifest — the
## browser draws it procedurally — and borrowing another prop's sprite for the
## thing you lose by is worse than building it: a brass drum on a plinth with a
## furnace mouth, lit from inside.
func _build_boiler() -> void:
	var boiler := Node3D.new()
	boiler.position = Vector3(SkyGearGame.BOILER_POSITION.x * WORLD_SCALE, 0.0,
		SkyGearGame.BOILER_POSITION.y * WORLD_SCALE)
	add_child(boiler)
	## SG-81: the one host that is neither pooled nor rigged. Registered whether
	## or not the table names it, because the table can gain a `boiler` row
	## without this function being edited again.
	_model_light_statics.append({"key": BOILER_MODEL, "node": boiler})
	## A generated mesh if one has been wrapped, the primitives below if not.
	## Both paths stay, and this one is not like the props: a prop that fails to
	## load falls back to a painted billboard, and there is no painted Boiler.
	## The object you lose the run by cannot be allowed to not exist.
	if not _boiler_mesh(boiler):
		_boiler_primitive(boiler)
	## And the furnace lamp — UNLESS the lights table has taken it over (SG-81).
	## A `boiler` row is authored at `BOILER_LAMP_FULL` in the same place with
	## the same colour, so the picture is the one this line drew; what changes is
	## that the owner can now move it in the lab. Without a row this is exactly
	## the call it always was.
	if not model_lit_by_table(BOILER_MODEL):
		_boiler_fire(boiler)


## THE PRIMITIVE FALLBACK, rebuilt to be honest — board SG-30.
##
## The previous fallback was a stack of fat cylinders and torus bands: 178 tall
## by 192 wide by 192 DEEP, taller than `BOILER_HEIGHT` and CHUNKIER than the
## generated mesh it backs up, and it would have FAILED the SG-27 boilerH check
## the moment the mesh vanished. The §13c narrative — "deleting the mesh row
## falls back to the flat block" — was false as written.
##
## This is what the browser actually draws (`boilerSprite`, storm-dusk-v11):
## a FLAT riveted drum on a plinth with a slatted furnace grate aimed at the
## camera, a gauge and one stubby chimney on top — 150 units to the very top,
## which is `BOILER_HEIGHT`, which is `boilerH`. The captain spawns 130 units in
## front of this thing; anything tall enough to be impressive is tall enough to
## hide her for the first second of every run, and anything smooth enough to
## shine is the polished toy §13c warned about. Boxes, not domes.
##
## Its own function so the harness can stand the FALLBACK tier up and measure
## it whether or not the mesh is on disk — the check that makes §13c true.
func _boiler_primitive(parent: Node3D) -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("#4c4238")
	iron.metallic = 0.45
	iron.roughness = 0.58
	var brass := StandardMaterial3D.new()
	## Darker and rougher than the old #c9903c at 0.3: a bright mirror-gold
	## block is the "polished toy" read again, just with corners.
	brass.albedo_color = Color("#a87a34")
	brass.metallic = 0.5
	brass.roughness = 0.55
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = Color("#5d4a33")
	lid_mat.metallic = 0.4
	lid_mat.roughness = 0.5
	var bright := StandardMaterial3D.new()
	bright.albedo_color = Color("#d8a44b")
	bright.metallic = 0.55
	bright.roughness = 0.4
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color("#7d5a2c")
	bronze.metallic = 0.5
	bronze.roughness = 0.45
	## The fallback goes cold and grey as the Boiler dies, exactly like the mesh
	## tier — same reader (`_sync_boiler_damage`), same fiction.
	for mat in [iron, brass, lid_mat, bright, bronze]:
		_boiler_mats.append(mat)
		_boiler_base.append((mat as StandardMaterial3D).albedo_color)

	## The plinth it stands on. Browser: plate(0,-18,150,36) of iron.
	_boiler_box(parent, iron, Vector3(118.0, 26.0, 88.0), Vector3(0.0, 13.0, 0.0))
	## The drum — the flat engine block itself. Browser: plate(0,-104,120,132)
	## of brass. A box 96 wide and 104 tall, top at 130.
	_boiler_box(parent, brass, Vector3(96.0, 104.0, 64.0), Vector3(0.0, 78.0, 0.0))
	## Two iron straps across the drum, so the brass reads as riveted plate work
	## rather than one extruded gold field.
	_boiler_box(parent, iron, Vector3(98.0, 8.0, 66.0), Vector3(0.0, 52.0, 0.0))
	_boiler_box(parent, iron, Vector3(98.0, 8.0, 66.0), Vector3(0.0, 108.0, 0.0))
	## The shoulder plate over it, iron-dark, top at 140.
	_boiler_box(parent, lid_mat, Vector3(104.0, 10.0, 72.0), Vector3(0.0, 135.0, 0.0))
	## The gauge on top. Browser: circ(0,-178,22). Top at 148.
	var gauge := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 15.0 * WORLD_SCALE
	gm.bottom_radius = 17.0 * WORLD_SCALE
	gm.height = 8.0 * WORLD_SCALE
	gauge.mesh = gm
	gauge.material_override = bright
	gauge.position = Vector3(20.0, 144.0, 6.0) * WORLD_SCALE
	parent.add_child(gauge)
	## The one stubby chimney. Browser: plate(-44,-196,26,44) of iron. Its lip is
	## the top of the whole object, at exactly BOILER_HEIGHT — the number the
	## SG-27 check measures, mesh or no mesh.
	var chimney := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 10.0 * WORLD_SCALE
	cm.bottom_radius = 13.0 * WORLD_SCALE
	cm.height = 36.0 * WORLD_SCALE
	chimney.mesh = cm
	chimney.material_override = iron
	chimney.position = Vector3(-34.0, BOILER_HEIGHT - 18.0, -18.0) * WORLD_SCALE
	parent.add_child(chimney)
	## Rivets across the drum face, two rows like the sprite's, so the block
	## reads as built rather than extruded.
	for stud in [Vector2(-38.0, 118.0), Vector2(0.0, 122.0), Vector2(38.0, 118.0),
			Vector2(-38.0, 44.0), Vector2(0.0, 40.0), Vector2(38.0, 44.0)]:
		var rivet := MeshInstance3D.new()
		var rmesh := CylinderMesh.new()
		rmesh.top_radius = 3.5 * WORLD_SCALE
		rmesh.bottom_radius = 3.5 * WORLD_SCALE
		rmesh.height = 6.0 * WORLD_SCALE
		rivet.mesh = rmesh
		rivet.material_override = bright
		rivet.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		rivet.position = Vector3(stud.x, stud.y, 34.0) * WORLD_SCALE
		parent.add_child(rivet)
	## The furnace face — the Boiler as anyone remembers it, a slatted grille
	## with fire behind it, aimed at the camera because the camera never moves
	## and a detail on the far side is a detail nobody ever sees.
	var bezel := MeshInstance3D.new()
	var bz := BoxMesh.new()
	bz.size = Vector3(86.0, 66.0, 8.0) * WORLD_SCALE
	bezel.mesh = bz
	bezel.material_override = bronze
	bezel.position = Vector3(0.0, 66.0, 31.0) * WORLD_SCALE
	parent.add_child(bezel)
	var furnace := MeshInstance3D.new()
	var fm := QuadMesh.new()
	fm.size = Vector2(72.0, 54.0) * WORLD_SCALE
	furnace.mesh = fm
	var fire := StandardMaterial3D.new()
	fire.albedo_texture = _grille_texture()
	fire.emission_enabled = true
	fire.emission_texture = _grille_texture()
	fire.emission = Color("#ffb060")
	fire.emission_energy_multiplier = 2.0
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire.cull_mode = BaseMaterial3D.CULL_DISABLED
	furnace.mesh.material = fire
	furnace.position = Vector3(0.0, 66.0, 36.0) * WORLD_SCALE
	furnace.rotation_degrees = Vector3(-10.0, 0.0, 0.0)
	parent.add_child(furnace)


## One iron-or-brass slab of the fallback Boiler. Sizes and positions in ground
## units, converted here, so the geometry above reads like the browser's own
## plate() calls.
func _boiler_box(parent: Node3D, material: StandardMaterial3D, size: Vector3,
		at: Vector3) -> void:
	var slab := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size * WORLD_SCALE
	slab.mesh = box
	slab.material_override = material
	slab.position = at * WORLD_SCALE
	parent.add_child(slab)


## The furnace light, and it belongs to the RENDERER rather than to whichever
## body it ends up on. A hot texture in an albedo map cannot light the planking
## the captain is standing on, and this lamp is most of what says the Boiler is
## alive from across the deck. Shared by the mesh path and the primitive one, so
## the two versions are lit identically and only the geometry differs.
func _boiler_fire(boiler: Node3D) -> void:
	_boiler_glow = OmniLight3D.new()
	_boiler_glow.light_color = Color("#ff9a4a")
	_boiler_glow.omni_range = 360.0 * WORLD_SCALE
	_boiler_glow.position = Vector3(0.0, 60.0 * WORLD_SCALE, 96.0 * WORLD_SCALE)
	boiler.add_child(_boiler_glow)


## THE BOILER'S DAMAGE, WITHOUT A SECOND MODEL.
##
## A damaged variant — scorched plates, sprung seams, venting — is a second
## generation, a second 11 MB GLB and a visible pop the moment it swaps in, for
## an object that is at the bottom centre of the frame the whole game. This is
## the cheaper read and it is also the better one, because it is CONTINUOUS: the
## fire goes out as the Boiler dies.
##
## Which is the fiction. It is a furnace that has been kept lit for thirty years
## (CLASS-2-DESIGN.md §1) and losing the run is that fire going out, so a lamp
## that dims and a body that goes cold and grey say the thing the ring at its
## feet can only count. The ring is a number; this is the object itself.
##
## The lamp also FLICKERS harder as it fails rather than merely dimming, because
## a light that only fades reads as dusk falling and a light that gutters reads
## as something wrong.
## The furnace lamp's brightness, as one expression with one home. Read by the
## built-in lamp below AND — when the lights table has taken the lamp over
## (SG-81) — by `_model_light_gain`, which divides it by `BOILER_LAMP_FULL` to
## turn it back into the multiplier a table row rides. Two callers, one number:
## the failure STATUS names is two functions each with their own copy.
func _boiler_lamp() -> float:
	var life: float = clampf(game.boiler_hp / maxf(1.0, game.boiler_max_hp), 0.0, 1.0)
	## Never all the way out while the run is alive: at 1 hp left the Boiler is
	## still the brightest thing on the deck and still the thing you are stood on
	## defending. A quarter of the light is a dying fire, no light is a prop.
	var gutter: float = 1.0 if life > 0.35 else 0.72 + 0.28 * sin(_flicker * 13.0)
	return (0.38 + 0.95 * life) * gutter


func _sync_boiler_damage() -> void:
	var life: float = clampf(game.boiler_hp / maxf(1.0, game.boiler_max_hp), 0.0, 1.0)
	## The lamp, when it is still the renderer's own. With a table row it is a
	## pooled model light and `_flush_model_lights` writes it — the tint below
	## runs either way, which is why this is a branch and not an early return.
	if _boiler_glow != null:
		_boiler_glow.light_energy = _boiler_lamp()
	## And the body goes cold and grey. There is no `modulate` on a Node3D, and
	## `set_instance_shader_parameter` is a no-op against a StandardMaterial3D —
	## it needs a shader that declares the uniform, which an imported glTF
	## material does not. So the tint is written to per-surface OVERRIDE copies
	## made once at load, which is also what stops the Boiler dyeing every other
	## object that shares a material with it.
	var chill: float = 1.0 - life
	for i in _boiler_mats.size():
		_boiler_mats[i].albedo_color = _boiler_base[i].lerp(
			Color(0.40, 0.38, 0.42) * _boiler_base[i].a, chill)


## The generated Boiler, if `tools/static_model.gd` has wrapped one.
##
## Not `_sync_prop_model`: this is built once at startup, never moves, is never
## pooled and never recycled, and routing it through the per-frame prop path
## would put the one permanent object in the scene on a free list.
func _boiler_mesh(parent: Node3D) -> bool:
	var path := model_path(BOILER_MODEL)
	if not ResourceLoader.exists(path):
		return false
	var packed := load(path) as PackedScene
	var node: Node3D = packed.instantiate() as Node3D if packed != null else null
	if node == null:
		return false
	var measured: float = float(node.get_meta("model_height", 0.0))
	if measured <= 0.0:
		push_warning("boiler: no model_height - falling back to the primitives")
		node.queue_free()
		return false
	var s: float = BOILER_HEIGHT * WORLD_SCALE / measured
	node.scale = Vector3(s, s, s)
	## LAYER_FIGURES, which is a CHANGE from the primitive Boiler and a
	## deliberate one. The Boiler's own health ring is a 330-unit decal centred
	## on it, and against the primitives it projects up the dome and reads as a
	## halo round the objective rather than as a mark on the planking. The layer
	## comment at the top of this file says a ring belongs on the deck; this is
	## the largest object it was getting that wrong on.
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		mi.layers = LAYER_FIGURES
		if mi.mesh == null:
			continue
		## Own copies of the materials, made once, so `_sync_boiler_damage` has
		## something it can write a tint to every frame without editing the
		## imported resource — which is shared, cached by path, and would follow
		## the change into the next scene that loaded it.
		for surface in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(surface) as StandardMaterial3D
			if mat == null:
				continue
			var own := mat.duplicate() as StandardMaterial3D
			mi.set_surface_override_material(surface, own)
			_boiler_mats.append(own)
			_boiler_base.append(own.albedo_color)
	parent.add_child(node)
	return true


## PAINTED ART BEATS GENERATED ART.
##
## Everything below this line was being drawn with a texture written in code
## because, when the 3D view was built, nobody had gone looking for what was
## already in `assets/art/`. There is a painted ring for a player aura, a painted
## ring for an enemy one, a painted scorch, a soft shadow, an impact burst, a
## slash arc, a tesla bolt, steam and embers — nineteen files, none of them
## reachable from any script. The generated versions stay as the fallback, which
## is what they are good for.
const PAINTED := {
	"blob": "res://assets/art/ground/shadow_blob.png",
	"ring": "res://assets/art/ground/rune_player.png",
	"ring_hostile": "res://assets/art/ground/rune_enemy.png",
	"ring_filled": "res://assets/art/ground/rune_enemy_filled.png",
	"scorch": "res://assets/art/ground/decal_scorch.png",
	"oil": "res://assets/art/ground/decal_oil.png",
	"gears": "res://assets/art/ground/decal_gear_scatter.png",
	## RETIRED FROM THE DECAL PATH, 2026-08-02 (board SG-63). Both of these
	## measure OPAQUE across their middle — `rune_player` is alpha-255 out to
	## 90% of its radius and `burst_impact` is 255 at its centre — and every
	## place they were used sized the decal from a gameplay number, which is
	## the trap DESIGN §13e names and SG-78 photographed. They stay in the
	## table because they are still the browser's art and a billboard or a
	## fixed-size plate may want them again; nothing reaches them today, and
	## the harness check `vfx · no ring or burst decal draws through a plate
	## that measures opaque` is what keeps it that way.
	"burst": "res://assets/art/fx/burst_impact.png",
	"slash": "res://assets/art/fx/slash_arc.png",
	"bolt": "res://assets/art/fx/bolt_tesla.png",
	"steam": "res://assets/art/fx/puff_steam.png",
	"smoke": "res://assets/art/fx/puff_smoke_dark.png",
	"ember": "res://assets/art/fx/ember_particle.png",
}


## The painted version if it is on disk, otherwise the one we can always draw.
func _art(key: String, fallback: Texture2D) -> Texture2D:
	var path: String = str(PAINTED.get(key, ""))
	if path == "":
		return fallback
	var tex := _texture(path)
	return tex if tex != null else fallback


## --- generated textures ------------------------------------------------------
## Everything below is painted at startup rather than shipped as art, for the
## same reason the browser paints its deck in code: a tiling photo of wood reads
## as a floor and this has to read as a SHIP. Each one is cached by key.

## A2. Mipmaps, on everything generated.
##
## Every one of these was uploaded with `mipmaps = false` while the billboards
## asked for `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` against them, and the deck
## tiles planking 1.8 x 7.0 over a 23-metre plane seen at 41 degrees — which is
## grazing, which is the exact case mipmaps exist for. The result was shimmering
## planking and aliased rims on the telegraphs, and an aliased telegraph is a
## readability problem rather than an ugly one.
static func _with_mips(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Planked timber.
func _planking_texture() -> ImageTexture:
	if _made.has("plank"):
		return _made.plank
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	## Warmer and lighter than the browser's hex values, deliberately: those are
	## the colour of the finished pixel, and this one goes through a blue key and
	## a purple ambient before anyone sees it. Painting the browser's #3d2e30
	## here came out as grey stone tile.
	var base := Color("#5c433a")
	var dark := Color("#33262a")
	var light := Color("#856046")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260727
	for y in size:
		for x in size:
			## Boards run along the KEEL. The plane maps u across the ship and v
			## down it, so a board is a column in this image — the first version
			## had them running athwartships, which is not how anyone has ever
			## planked a deck and read as floor tile at distance.
			var board := int(x / 32.0)
			var shade: float = 0.90 + fmod(float(board) * 0.37, 1.0) * 0.2
			var c := base * shade
			# the seam between two boards
			if x % 32 == 0:
				c = dark
			elif x % 32 == 31:
				c = c.lerp(light, 0.22)     # the lit lip of the next board over
			## Butt joints, staggered board to board — and FAINT. At full dark
			## every 128 rows they crossed the plank seams into a tile grid, and
			## a tiled deck is a floor rather than a ship.
			if (y + board * 61) % 128 < 2:
				c = c.lerp(dark, 0.28)
			# grain
			var grain := rng.randf()
			if grain < 0.06:
				c = c.lerp(dark, 0.5)
			elif grain > 0.965:
				c = c.lerp(light, 0.35)
			img.set_pixel(x, y, c)
	_made.plank = _with_mips(img)
	return _made.plank


## Lashed crate: vertical boards, an iron band top and bottom, corner plates.
## Tiles in both axes so it can go on a box triplanar without seams reading.
func _crate_texture() -> ImageTexture:
	if _made.has("crate"):
		return _made.crate
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var wood := Color("#6b4c37")
	var dark := Color("#2d2128")
	var lit := Color("#9a7350")
	var band := Color("#94702f")
	var rng := RandomNumberGenerator.new()
	rng.seed = 419
	for y in size:
		for x in size:
			var c := wood
			# vertical planks, 16px, each its own shade
			var plank := int(x / 16.0)
			c = c * (0.86 + fmod(float(plank) * 0.41, 1.0) * 0.28)
			if x % 16 == 0:
				c = dark
			# iron bands across the top and bottom thirds
			if (y > 18 and y < 28) or (y > 100 and y < 110):
				c = band * (0.8 + 0.4 * float((x / 8) % 2))
			# rivets on the bands
			if ((y == 23 or y == 105) and x % 16 == 8):
				c = lit
			var n := rng.randf()
			if n < 0.07:
				c = c.lerp(dark, 0.45)
			elif n > 0.96:
				c = c.lerp(lit, 0.3)
			img.set_pixel(x, y, c)
	_made.crate = _with_mips(img)
	return _made.crate


## A soft ring, bright at the rim and hollow in the middle — the shape every
## radial ground effect in this game actually is.
##
## WHERE THE RIM IS, AS A NUMBER RATHER THAN AS A MAGIC 0.92 (board SG-163). This
## texture's bright band does NOT sit at the edge of its own square: it peaks at
## 92% of the half-size. So a caller that wants the visible line to land on a
## gameplay radius has to divide, and until SG-163 every caller multiplied a
## literal instead and none of them agreed. `ring_span_for(r)` is that division,
## written once — hand it the radius you want the player to SEE and it gives you
## the decal size that puts the line there.
const RING_RIM_D := 0.92

## The decal width/height that puts this ring's bright band on `radius`.
static func ring_span_for(radius: float) -> float:
	return radius * 2.0 / RING_RIM_D


func _ring_texture() -> ImageTexture:
	if _made.has("ring"):
		return _made.ring
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(centre) / (size * 0.5)
			var a := 0.0
			if d <= 1.0:
				## Mostly rim. The first version washed the inside at 0.22 alpha
				## additive, and at a mortar's radius that is a bright disc the
				## size of a lane sitting on top of the fight — the browser's
				## rings are a fill you can see through and an edge you cannot
				## miss, and the ratio is what makes them readable.
				a = 0.05 * (1.0 - d * 0.55)
				a += 1.0 * exp(-pow((d - RING_RIM_D) / 0.06, 2.0))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_made.ring = _with_mips(img)
	return _made.ring


## A streak, for anything that goes from A to B: bright along the centreline,
## soft across it, faded at both ends. Beams and chains were being drawn as
## RINGS the size of their own length, which is where the two enormous blue
## hoops in the first 3D screenshot came from.
func _streak_texture() -> ImageTexture:
	if _made.has("streak"):
		return _made.streak
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		var v: float = absf(float(y) / float(size - 1) - 0.5) * 2.0
		var across: float = exp(-pow(v / 0.30, 2.0))
		for x in size:
			var u := float(x) / float(size - 1)
			var ends: float = smoothstep(0.0, 0.06, u) * smoothstep(0.0, 0.06, 1.0 - u)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(across * ends, 0.0, 1.0)))
	_made.streak = _with_mips(img)
	return _made.streak


## THE DANGER WEDGE'S EDGE IS THE MOST IMPORTANT LINE IN THIS GAME (board SG-162,
## owner: *"the edge of that should be very clear to the player. Having it lined
## with something a little harder, as opposed to that soft edge, could make it
## clearer."*)
##
## WHAT WAS WRONG. The filled wedge was a gradient in all three directions at
## once: `(0.30 + 0.55*d)` brightening outward, an outer `smoothstep(1.0, 0.86, d)`
## fading the last 14% of the reach to nothing, and cut sides feathered over 16%
## OF THE HALF-ARC — which on the Colossus's 120° fan is a 9.6° smear down each
## side. Every one of those is a ramp, so the shape had a bright middle and no
## boundary anywhere. In `.shots/sg159/before` it reads as spilled orange light,
## and against the furnace knight's own emissive chest it reads as *his glow*.
## The player's question at a telegraph is binary — **am I in it?** — and a shape
## whose brightest part is its interior and whose edge is a 20-pixel fade cannot
## answer a binary question.
##
## THE TARGET IS `_ring_texture()`'S OWN STATED PRINCIPLE, twenty lines up this
## file and never applied here: *the browser's rings are a fill you can see
## through and an EDGE YOU CANNOT MISS, and the ratio is what makes them
## readable.* The ring gets it by spending 0.05 alpha on its interior and 1.0 on
## a band at its rim — a 20:1 ratio. The wedge spent 0.85 on its interior and
## nothing on its boundary. It is the same ratio now: a see-through fill, a rim
## line that peaks AT the boundary, and cut sides one texel wide.
##
## THE SIZE DOES NOT MOVE, and that is a hard constraint rather than a courtesy.
## The decal is drawn at `enemy.swing_wedge_reach() * 2.0` — the same function the
## simulation connects with — and board SG-119 was paid for by a drawn shape and
## a hit shape disagreeing about a number. `d == 1.0` is the true reach, so that
## is exactly where the rim's peak is put and exactly where the alpha is cut to
## zero. Nothing outside `d = 1.0` or `off = half` is painted at all, which was
## also true before; what changed is that you can now SEE where that is.
##
## THE FEATHERS ARE IN TEXELS, NOT IN FRACTIONS OF THE SHAPE. A feather quoted as
## a fraction of the half-arc is wide on a wide fan and narrow on a narrow one, so
## the Colossus's boundary was three times softer than a gremlin's for no reason
## anyone chose. `FAN_AA` texels of antialiasing is the same crispness on every
## arc in the table, and it is antialiasing rather than styling: one and a quarter
## texels is what it takes to keep a hard step from stair-casing under the
## bilinear magnification a 128-texture gets at a 146-unit reach.
##
## `filled` is still the difference between a cone and a cleave: a cone is a wedge
## of ground you are about to cook, a cleave is the rim of one. Both are hard at
## the boundary now — the unfilled variant is SG-158's strike flash, which is the
## frame the blow lands and has even less business being vague.
## Cached per arc, because there are only ever a handful of distinct arcs.
const FAN_RIM_W := 0.085       ## the rim line's width, as a fraction of the reach
const FAN_RIM_A := 0.95        ## and its alpha at the boundary itself
const FAN_FILL_NEAR := 0.12    ## the see-through fill, at the apex
const FAN_FILL_FAR := 0.24     ## and where it meets the rim — still see-through
const FAN_AA := 1.25           ## the feather on every hard edge, in TEXELS
const FAN_SIZE := 256          ## a rim one texel wide wants texels worth having

func _fan_texture(arc: float, filled: bool) -> ImageTexture:
	var key := "fan%s_%d" % ["f" if filled else "r", int(arc * 24.0)]
	if _made.has(key):
		return _made[key]
	var size := FAN_SIZE
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size) * 0.5
	var half: float = clampf(arc, 0.15, TAU) * 0.5
	## One texel, expressed in the same 0..1 `d` the loop works in.
	var texel: float = 1.0 / c
	for y in size:
		for x in size:
			var dx := float(x) + 0.5 - c
			var dy := float(y) + 0.5 - c
			var d := sqrt(dx * dx + dy * dy) / c
			var a := 0.0
			# the fan opens along +X of the decal, which the transform aims
			var off: float = absf(atan2(dy, dx))
			if d <= 1.0 and off <= half:
				## THE TWO CUT SIDES. `(half - off)` is an ANGLE; multiplied by the
				## radius it is the arc-length distance to the cut, which is what a
				## texel count has to be measured against. Near the apex that
				## distance genuinely is under a texel, so the point of the wedge
				## fades — correctly: a wedge's apex is a point, and the old
				## angle-only feather painted a full-alpha blob at the boarder's
				## feet where the shape has no area.
				var side: float = clampf((half - off) * maxf(d, texel) / (FAN_AA * texel),
					0.0, 1.0)
				## THE OUTER BOUNDARY, cut hard at the true reach and feathered
				## over the same texel count — the whole difference from the old
				## `smoothstep(1.0, 0.86, d)`, which spent 14% of the reach fading.
				var outer: float = clampf((1.0 - d) / (FAN_AA * texel), 0.0, 1.0)
				## THE RIM LINE. It ramps to full over the last `FAN_RIM_W` of the
				## reach and peaks at `d = 1.0`, so the brightest pixel of the whole
				## shape sits on the boundary the simulation swings to.
				var rim: float = smoothstep(1.0 - FAN_RIM_W, 1.0, d)
				if filled:
					a = (FAN_FILL_NEAR + (FAN_FILL_FAR - FAN_FILL_NEAR) * d
						+ FAN_RIM_A * rim) * side * outer
				else:
					## The cleave/strike variant: the rim line and nothing under
					## it. Twice the band width, because with no fill beneath it
					## this line is the entire shape and has to carry it alone.
					a = smoothstep(1.0 - FAN_RIM_W * 2.0, 1.0, d) * side * outer
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_made[key] = _with_mips(img)
	return _made[key]


## The furnace grille: horizontal iron slats with fire behind them, hottest in
## the middle and cooling toward the edges.
func _grille_texture() -> ImageTexture:
	if _made.has("grille"):
		return _made.grille
	var w := 96
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var slat: bool = (y % 11) < 4
		for x in w:
			var u := (float(x) / float(w - 1)) * 2.0 - 1.0
			var v := (float(y) / float(h - 1)) * 2.0 - 1.0
			var heat: float = clampf(1.0 - sqrt(u * u * 0.7 + v * v * 1.1), 0.0, 1.0)
			var c := Color("#1b1418") if slat else 				Color("#ff4a12").lerp(Color("#ffe6a8"), heat * heat) * (0.35 + heat * 1.5)
			if y < 3 or y > h - 4 or x < 3 or x > w - 4:
				c = Color("#241b25")
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	_made.grille = _with_mips(img)
	return _made.grille


## The wall of an aura: brightest at the top and bottom edges, thin in between,
## so a cylinder of it reads as a boundary rather than as a tube of fog.
func _wall_texture() -> ImageTexture:
	if _made.has("wall"):
		return _made.wall
	var w := 8
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var v := float(y) / float(h - 1)
		var a: float = exp(-pow(v / 0.16, 2.0)) * 0.9 + exp(-pow((1.0 - v) / 0.12, 2.0)) + 0.10
		for x in w:
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_made.wall = _with_mips(img)
	return _made.wall


## The emission map for a shape: its alpha, baked into RGB, opaque. Cached
## against the texture it came from, built once on first use.
func _glow_map(tex: Texture2D) -> Texture2D:
	var key := "glow_%d" % tex.get_instance_id()
	if _made.has(key):
		return _made[key]
	var src := tex.get_image()
	var out := Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
	for y in src.get_height():
		for x in src.get_width():
			var a: float = src.get_pixel(x, y).a
			out.set_pixel(x, y, Color(a, a, a, 1.0))
	_made[key] = _with_mips(out)
	return _made[key]


## A soft dark blob. Every billboard needs one under it or it floats: the
## browser calls this `entityShadow` and draws one for everything on the deck.
func _blob_texture() -> ImageTexture:
	if _made.has("blob"):
		return _made.blob
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (size * 0.5)
			var a: float = 0.0 if d > 1.0 else pow(1.0 - d, 1.7)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_made.blob = _with_mips(img)
	return _made.blob


## A hot point, for bolts and sparks.
func _spark_texture() -> ImageTexture:
	if _made.has("spark"):
		return _made.spark
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (size * 0.5)
			var a: float = 0.0 if d > 1.0 else pow(1.0 - d, 2.4) + exp(-pow(d / 0.22, 2.0))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_made.spark = _with_mips(img)
	return _made.spark


## The Colossus fitting's gate, second edition (SG-15 → SG-56). The wreck was
## the berth system's first resident before the berths existed — it shipped
## gated on `workshop.unlocked` alone. Now it asks the RUN's berthed set
## (`SkyGearGame.fitted`, the snapshot `begin_run` took), which is the same
## first-victory latch one layer up: `load_state` migrates any pre-berth
## winner's save to an earned, berthed wreck, so nobody's trophy vanishes.
## Between runs it follows the save through `refresh_berthed()`, so the title
## deck shows what will sail; mid-run it cannot move — the owner's rule.
func _wreck_berthed() -> bool:
	return game != null and game.fitted("wreck")


func _process(delta: float) -> void:
	if game == null:
		return
	## The shader warm-up: draw one of everything for a few frames, off-screen,
	## then take it down. A pipeline is created when something is first RENDERED
	## with a material, so the only honest way to pay that cost early is to
	## render it early. The first bench found a 150 ms worst frame here against
	## an 8.5 ms steady state.
	if _warmup != null:
		_warm_frames += 1
		if _warm_frames == 1:
			_warmup.warm(self)
		elif _warm_frames > SkyGearWarmup.HOLD_FRAMES:
			_warmup.cool()
			_warmup = null
	_flicker += delta
	_aim_from_cursor()
	_track_camera(delta)
	## AFTER the solve, never instead of it. `_track_camera` writes the gameplay
	## transform every frame from state a cutscene is forbidden to touch, so a
	## cutscene overwriting its RESULT here means "stop overwriting" is a complete
	## restore — see the header of `scripts/cutscene_player.gd`.
	_watch_cues()
	if _cutscene != null:
		## This frame's ship motion, in degrees, handed over rather than looked up:
		## `SWAY_ROLL` and `SWAY_YAW` live here and a cutscene that recomputed them
		## would be a second copy of a number `_track_camera` already owns.
		_cutscene.sway_roll = SWAY_ROLL * _roll
		_cutscene.sway_yaw = SWAY_YAW * _yaw
		_cutscene.advance(delta)
	## The fittings follow the RUN's snapshot (between runs, the save through
	## `refresh_berthed`): the wreck and the grating show what is berthed, and
	## mid-run the snapshot cannot move. Two array reads a frame.
	if _wreck != null:
		_wreck.visible = _wreck_berthed()
	if _grating != null:
		_grating.visible = game.fitted("scupper_grating")
	_used.clear()
	_decals_used.clear()
	## The ribbon batch is written from scratch every frame between these two, the
	## same way the shadow batch is and for the same reason: there is no persistent
	## identity to preserve, the count is small, and a rebuild cannot leave a stale
	## bolt hanging in the air over a boarder that died two seconds ago.
	_mote_clock += delta
	_ribbons_begin()
	_sync_all(delta)
	_sync_auras()
	_sync_aim()
	_sync_effects()
	## The blade trail last, after `_sync_effects` has told it this swing's
	## element — the samples were taken in `_sync_captain`, off the bone.
	_emit_blade_trail()
	_ribbons_end()
	_sync_darkness(delta)
	## The deck's memory, aged and drawn BEFORE the shadows so a figure's contact
	## shadow lands on top of its own blood rather than under it.
	_age_marks(delta)
	_flush_marks()
	_flush_shadows()
	## After every core this frame is placed, hand the nearest few a light. See
	## `_flush_core_lights` — this is the cap that keeps a lane of bolts from
	## becoming a lane of lights (SG-34).
	_flush_core_lights()
	## And the per-model accents, after every prop mesh and rig this frame has
	## been placed — same shape, same reason, its own budget (SG-81).
	_flush_model_lights()
	_sync_airstream(delta)
	## The flashes fade. Ember lingers, Frost is instant — the decay carries the
	## element as much as the colour does.
	for light in _flashes:
		if light.light_energy > 0.0:
			light.light_energy = maxf(0.0, light.light_energy
				- delta * float(light.get_meta("decay", 11.0)))
	_sync_clouds(delta)
	_sync_skyships()
	_recycle()


## Return what nobody claimed this frame — HIDE it, do not free it.
##
## The rendering audit was blunt about this and correct: freeing every unclaimed
## node each frame and building a new one when it is next needed is churn with
## the word "pool" written on it. A fight is a few dozen decals and billboards
## appearing and disappearing several times a second, which was several dozen
## node allocations a second for no reason.
##
## Freed only when the free list is deeper than anything has ever needed at once,
## so a keg chain does not leave four hundred hidden nodes resident for the rest
## of the run.
const POOL_SLACK := 24

## The corpses, aged. Called from `_sync_all`, not from `_recycle`, for one
## reason: it draws a shadow, and the shadow batch is flushed before the recycle
## runs — a body lying on the planking with nothing under it is a decal, not a
## corpse. A body converted at the end of frame N first ages on frame N+1, which
## costs it a frame of its window and keeps every shadow in one pass.
func _age_corpses(delta: float) -> void:
	## The painted tier first, and it is the whole of its own death: no clip, no
	## sink, just the plate going out over `DEATH_FADE` and then going back on
	## the shelf. Walked backwards so a shelved sprite can be removed in place.
	for i in range(_fading.size() - 1, -1, -1):
		var going: Dictionary = _fading[i]
		going.life = float(going.life) - delta
		var sprite: Sprite3D = going.node
		if float(going.life) <= 0.0 or not is_instance_valid(sprite):
			if is_instance_valid(sprite):
				sprite.visible = false
				_free_billboards.append(sprite)
			_fading.remove_at(i)
			continue
		sprite.modulate.a = corpse_fade(float(going.life))
	for key in _corpses.keys():
		var body: Dictionary = _corpses[key]
		body.life = float(body.life) - delta
		var rig: SkyGearRig3D = body.rig
		if float(body.life) <= 0.0 or not is_instance_valid(rig):
			if is_instance_valid(rig):
				rig.queue_free()
			_corpses.erase(key)
			continue
		## The sink belongs to a body that has PLAYED a death. A figure with no
		## death clip is fading out of the pose it was standing in, and dropping
		## it through the planking as well would be a death animation invented by
		## the renderer for a character that does not have one.
		if bool(body.get("sink", true)):
			rig.position.y = -corpse_drop(float(body.life), float(body.height))
		## THE BODY GOES WITH IT (board SG-103). `transparency` is per
		## GeometryInstance3D, not per material, so a fading corpse cannot make
		## every other figure sharing that mesh see-through — which matters when
		## one crew mesh serves the whole deck. The mesh list was found ONCE, at
		## the moment the corpse was made: a `find_children` per part per frame
		## for every body on the planking is a tree walk in the middle of a
		## fight, and the corpse has left `_rigs` and cannot be asked twice.
		var solid: float = corpse_fade(float(body.life))
		if solid < 1.0:
			for node in body.get("meshes", []):
				if is_instance_valid(node):
					(node as GeometryInstance3D).transparency = 1.0 - solid
		var fade: float = clampf(float(body.life) / DEATH_SINK, 0.0, 1.0)
		## A DISASSEMBLY HAS NO ONE PLACE TO PUT A SHADOW. The Colossus's death
		## throws thirteen parts across two metres of deck, and the blob below —
		## sized off the body height, dropped at the rig's origin — stayed
		## exactly where the machine no longer was, which is the second half of
		## the owner's "floating dark and gold blobs". Each part grounds itself
		## instead, and lands its own shadow when it lands.
		if not _part_shadows("dead" + key, rig, fade):
			_shadow("dead" + key, Vector2(rig.position.x / WORLD_SCALE,
				rig.position.z / WORLD_SCALE),
				float(body.height) / WORLD_SCALE * 0.55, 0.5 * fade)


func _recycle() -> void:
	for key in _billboards.keys():
		if not _used.has(key):
			var node: Sprite3D = _billboards[key]
			_billboards.erase(key)
			## A FIGURE GETS A TAIL (board SG-103). Only a figure: a decal, a
			## spark and a prop plate all go through this same pool, and a barrel
			## that was destroyed or a spark that burnt out has its own effect
			## already — fading everything would put a half-second ghost on every
			## sentry ring and every collected pickup in the game.
			if str(node.get_meta("billboard_kind", "")) == BILLBOARD_FIGURE \
					and _fading.size() < FADE_CAP and game != null and game.is_playing():
				## Two properties, and the second is the important one. Figures
				## are drawn with an ALPHA SCISSOR (`_dress_billboard`), which
				## has no opinion between 0.99 and 0.51 and then discards the
				## whole plate — so a scissored sprite cannot fade at all. And
				## CLEARING THE KIND STAMP is what guarantees the scissor comes
				## back: `_claim_billboard` re-dresses any node whose stamp does
				## not match what is being asked for, and no stamp matches
				## nothing. That is the SG-66 pool-identity check doing exactly
				## the job it was built for rather than a second reset path that
				## could forget a property.
				node.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
				node.set_meta("billboard_kind", "")
				_fading.append({"node": node, "life": DEATH_FADE})
				continue
			node.visible = false
			_free_billboards.append(node)
	for key in _decals.keys():
		if not _decals_used.has(key):
			var node: Decal = _decals[key]
			node.visible = false
			_free_decals.append(node)
			_decals.erase(key)
			_decal_live[_decal_class(key)] -= 1
	## Projectile cores, hidden-and-shelved exactly like the billboards — a bolt
	## that reached its target this frame gives its mesh back rather than freeing it.
	for key in _cores.keys():
		if not _used.has(key):
			var node: MeshInstance3D = _cores[key]
			node.visible = false
			_free_cores.append(node)
			_cores.erase(key)
	## Rigs are the exception: a character is a whole scene with a skeleton and an
	## animation player, and keeping a dead boarder's one alive to re-skin later
	## is holding far more than a sprite.
	##
	## …unless it can DIE (board SG-85, the game's first death animation). A rig
	## that goes unclaimed is a boarder the simulation has finished with — killed,
	## despawned or cleared — and until the furnace knight arrived the only thing
	## to do about it was free the node the same frame, which is why every death
	## in this game is a figure ceasing to exist inside its own burst.
	##
	## Presentation only, and the seam is exactly where it has to be: the sim ran
	## `on_enemy_killed` (the scrap, the pressure, the burst, the sfx) and freed
	## the enemy BEFORE this line, so nothing here can hold up a kill, a wave, or
	## a payout — the body is a corpse the renderer keeps for a second and a half
	## after the simulation has stopped believing in it.
	for key in _rigs.keys():
		if not _used.has(key):
			var rig: SkyGearRig3D = _rigs[key]
			_rigs.erase(key)
			## THE GHOST DOES NOT OUTLIVE THE BOARDER (board SG-141). A rig that
			## leaves `_rigs` is never handed to `_xray` again, so nothing would
			## ever turn its silhouette off — and a corpse that keeps one lies
			## about where the danger is for a second and a half, on top of
			## fighting the corpse fade for the same mesh instances.
			rig.silhouette(false)
			if _corpses.size() >= CORPSE_CAP or game == null or not game.is_playing():
				## The cap, and the not-in-a-fight case: freed on the spot, which
				## is what every unclaimed rig did before there was a death.
				rig.queue_free()
			elif not dies_on_screen(rig):
				## NO DEATH CLIP, AND STILL NOT A DISAPPEARANCE (board SG-103).
				## This is the branch the owner was actually looking at. Four
				## kinds play a real `die`; the scrapper's borrowed library has
				## none and the gunner drone has no clips at all — and those two
				## were `queue_free()`d the same frame the simulation finished
				## with them, which is a figure ceasing to exist mid-stride. It
				## gets the tail without the theatre: no clip to play, so no
				## `DEATH_WINDOW`; no death to have finished, so no sink; it
				## simply stops being there over `DEATH_FADE` in the pose it was
				## last in. A tenth of the budget a real corpse holds.
				_corpses[key] = {"rig": rig, "life": DEATH_FADE,
					"height": rig.fit_height, "sink": false,
					"meshes": rig.model.find_children("*", "MeshInstance3D",
						true, false) if rig.model != null else []}
			else:
				rig.want("die", 0.0, DEATH_WINDOW)
				_corpses[key] = {"rig": rig, "life": corpse_life(),
					"height": rig.fit_height,
					## Found once, here, for the fade — see `_age_corpses`.
					"meshes": rig.model.find_children("*", "MeshInstance3D",
						true, false) if rig.model != null else []}
				## The deck remembers it. Nearly free evidence: this line already
				## fires exactly once, at the kill location, for every figure
				## that has a death to play. A drone leaks, everything else
				## bleeds. DECK-IDENTITY-DESIGN §7.3.
				var slug: String = str(rig.get_meta("model_key", ""))
				_mark(MarkKind.OIL if MARK_OIL_MODELS.has(slug) else MarkKind.BLOOD,
					Vector2(rig.position.x, rig.position.z) / WORLD_SCALE,
					clampf(rig.fit_height / (176.0 * WORLD_SCALE), 0.6, 1.5))
	## Prop meshes go back on a shelf instead, one shelf per model. They are not
	## rigs — there is no skeleton or AnimationPlayer to hold — and salvage is the
	## case that decides it: a pickup appears and is collected several times a
	## second all run, so freeing its mesh on collection is `load` and
	## `instantiate` on a repeating loop for a thing that will be needed again in
	## two seconds.
	for key in _prop_models.keys():
		if not _used.has(key):
			var node: Node3D = _prop_models[key]
			node.visible = false
			var model_key: String = str(node.get_meta("prop_model", ""))
			if not _free_prop_models.has(model_key):
				_free_prop_models[model_key] = []
			_free_prop_models[model_key].append(node)
			_prop_models.erase(key)
	for model_key in _free_prop_models:
		_trim(_free_prop_models[model_key])
	_trim(_free_billboards)
	_trim(_free_decals)
	_trim(_free_cores)


func _trim(free_list: Array) -> void:
	while free_list.size() > POOL_SLACK:
		var node: Node = free_list.pop_back()
		node.queue_free()


## The camera sits behind and above the captain and looks down the pitch, and
## the numbers are the browser's own — see `camera_back()`. She rides at 60% of
## screen height, which is what the art was framed against.
func _track_camera(delta: float) -> void:
	var back := camera_back()
	var p: Vector2 = game.player.global_position if game.player != null else Vector2.ZERO
	var deck_rect: Rect2 = SkyGearGame.DECK_RECT
	var slack: float = deck_rect.size.x * 0.22
	var centre_x: float = deck_rect.position.x + deck_rect.size.x * 0.5
	## The leash is against the DECK, not against the Boiler. Clamping to keep
	## the objective framed can shove the captain off the top of the screen at
	## the bow, and losing yourself is far worse than losing sight of a thing
	## that has an edge marker for exactly this reason.
	var target := Vector2(
		clampf(p.x, centre_x - slack, centre_x + slack),
		clampf(p.y + back, deck_rect.position.y + 300.0, deck_rect.end.y + 200.0))
	if not _focus_set:
		_focus = target
		_focus_set = true
	else:
		_focus = _focus.lerp(target, 1.0 - exp(-delta / CAM_TAU))
	## The sway. Three periods that do not divide into each other, so the motion
	## never resolves into a loop you can count: a long roll, a shorter yaw, and
	## a heave on its own clock. Deliberately at the top of what is comfortable
	## rather than the bottom — the browser's version was invisible.
	_roll = 0.0
	_yaw = 0.0
	var heave := 0.0
	if sway:
		_roll = sin(_flicker * 0.31) * 0.72 + sin(_flicker * 0.73) * 0.28
		_yaw = sin(_flicker * 0.47)
		heave = sin(_flicker * 0.58) * SWAY_HEAVE
	## Shake is ADDED to the sway, never assigned over it. Two systems both
	## writing the camera transform is two systems fighting, and the sway is the
	## one the ship is doing.
	var kick := game.impact.shake_offset() if game.impact != null else Vector2.ZERO
	## ZOOM. Requested, and it is also the honest short-term answer to the parity
	## finding — side by side the port shows materially less deck than the browser
	## and nobody has diagnosed why yet. A wheel does not fix that, but it stops
	## the player being stuck inside it while I work out what moved.
	##
	## The camera pulls BACK ALONG ITS OWN AXIS rather than changing FOV. Both
	## show more deck; only one keeps the projection the whole game is calibrated
	## to. Changing the field of view would change the perspective every telegraph,
	## decal and billboard height was solved against.
	_zoom = lerpf(_zoom, _zoom_target, 1.0 - exp(-delta / ZOOM_TAU))
	camera.position = Vector3((_focus.x + kick.x) * WORLD_SCALE,
		(CAM_HEIGHT * _zoom + heave + kick.y) * WORLD_SCALE,
		(_focus.y + CAM_NEAR * _zoom) * WORLD_SCALE)
	camera.rotation = Vector3(-PITCH, deg_to_rad(SWAY_YAW * _yaw),
		deg_to_rad(SWAY_ROLL * _roll))
	if _envelope != null:
		# hangs above and ahead, angled to face the camera
		_envelope.position = camera.position + Vector3(0.0, 620.0 * WORLD_SCALE,
			-1500.0 * WORLD_SCALE)
		_envelope.rotation = Vector3(-PITCH * 0.55, 0.0, 0.0)


func _sync_airstream(delta: float) -> void:
	var shear: float = 0.0
	if game.player != null:
		shear = clampf(game.player.velocity.x / 320.0, -1.0, 1.0)
	var lean := -shear * 0.30                     # radians, against the movement
	## They never get closer than this. A ribbon that passes within a couple of
	## metres of the lens is a pale smear over half the frame no matter how thin
	## it is in world units, which is what the first two passes looked like.
	var near_z: float = camera.position.z / WORLD_SCALE - 430.0
	for i in _stream.size():
		var node := _stream[i]
		# a stable per-streak pseudo-random, so nothing pops when one recycles
		var salt := float(i) * 0.6180339887
		var t: float = _stream_v[i] + delta * (STREAK_SPEED * (0.7 + fmod(salt * 7.3, 1.0) * 0.8)) / STREAK_DEPTH
		if t >= 1.0:
			t = fmod(t, 1.0)
		_stream_v[i] = t
		var z: float = near_z - STREAK_DEPTH * (1.0 - t)
		var x: float = _focus.x + (fmod(salt * 31.7, 1.0) - 0.5) * STREAK_SPREAD
		var y: float = 70.0 + fmod(salt * 13.1, 1.0) * 420.0
		# aim it down the keel, leaned by the shear
		var angle: float = -PI * 0.5 + lean
		var ca := cos(angle)
		var sa := sin(angle)
		## SCALED ON THE COLUMNS, not by `Basis.scaled()`.
		##
		## `scaled()` multiplies the basis ROWS, which is a scale in the PARENT
		## frame, and this basis is a 90 degree rotation — so the two did not line
		## up. At `angle = -PI/2` the local X column is (0, 0, -1), pointing down
		## the keel, and scaling the world-X row leaves it untouched: THE 367-UNIT
		## LENGTH WAS DISCARDED. It landed on the local Y column instead, which
		## points athwartships. Forty-eight additive plates, up to 430 units wide
		## ACROSS the ship at head height, sweeping over the deck.
		##
		## Invisible for months against a near-black sky and obvious the day a
		## moonlit cloudscape went in behind them — the pale horizontal bars in
		## the first sky screenshots were these. Found by measurement rather than
		## by eye: `tools/deck_probe.gd -- airsize` prints wanted against got.
		##
		## The comment eight lines above warns that a ribbon passing close to the
		## lens is a smear over half the frame, and then the code does exactly
		## that through a different door. Multiplying the columns applies the
		## scale in the quad's OWN frame, which is where length and width mean
		## what they are named.
		var along: float = _stream_len[i * 2] * WORLD_SCALE
		var across: float = _stream_len[i * 2 + 1] * WORLD_SCALE
		var basis := Basis(
			Vector3(ca, 0.0, sa) * along,
			Vector3(sa, 0.0, -ca) * across,
			Vector3(0.0, 1.0, 0.0))
		node.transform = Transform3D(basis, Vector3(x, y, z) * WORLD_SCALE)
		# fade in at the far end and out as it passes, so nothing appears in shot
		var fade: float = smoothstep(0.0, 0.16, t) * smoothstep(1.0, 0.70, t)
		node.transparency = 1.0 - fade


## Where the cursor is pointing, ON THE DECK.
##
## THIS WAS THE AIMING BUG. `Node2D.get_global_mouse_position()` returns the
## mouse in the 2D scene's coordinates — and the 2D scene is hidden. What the
## player is looking at is a perspective projection of the deck through a
## Camera3D forty-one degrees above it, and the two spaces have no relationship
## whatsoever. Every skill was aimed at a point that had nothing to do with the
## cursor: a Lance fired past the pointer, a Mortar landed somewhere else, and a
## Cleave aimed away from the boarder it looked like it was facing.
##
## The browser has `CAM.unproject` for exactly this and it is the same three
## lines: take the ray under the cursor and intersect it with the deck plane.
## THE LIGHTS GO OUT. Wave 8's event, and the reason it is not a second boarding
## hulk: an event should change how the deck plays, and darkness changes every
## decision on it at once — where you can afford to be, whether that shape at the
## rail is a crate or a boarder, whether chasing salvage into the bow is worth it.
##
## Eased rather than switched, over about a second and a half. A hard cut reads
## as a bug, and the slow failure of the lamps is most of the drama.


## THE RIM (SG-86). Cool, because the deck is warm and a warm rim on warm
## planking separates nothing — the hue contrast is doing as much work as the
## luminance. Sampled from the paintings themselves: the cyan edge on
## `furnace_knight_front_idle.png` sits around #9fc6e8, a touch cooler and
## lighter than the moon's #8fa6c9, which is what tells the eye the two are
## different sources rather than one smeared one.
const RIM_COLOUR := "#9fc6e8"
const RIM_ENERGY := 0.62
## AND THE PITCH IS THE WHOLE FIX. This started at -16 and -16 DID NOT WORK, in
## the specific way that is worth keeping written down: measured on the frozen
## probe it took the knight from 40.81 to 48.12 and the planking he stands on
## from 47.83 to 55.88. It lifted both by about the same eight points. That is
## not a rim light, it is the exposure dial with a colour on it, and by eye the
## picture was no easier to read — the boarder stayed a dark shape on a slightly
## brighter deck.
##
## A directional light puts `sin(pitch)` of itself on a floor and roughly
## `cos(pitch)` on the vertical surfaces of anything standing on it, so every
## degree of pitch is spent on planking. Taken to -1 the same 0.62 gives:
##
##     figure 40.81 -> 51.19      deck 47.83 -> 49.53
##
## Ten points onto the boarder and under two onto the deck he stands on, which
## flips the thing that actually decides whether he reads: he was 15% DARKER
## than his own planking (0.853) and is now marginally brighter (1.034). Pinned
## by `lit · the furnace knight reads brighter than the deck he stands on`.
##
## The energy is held low for the reason the pitch is held shallow. A boarder
## who out-glows his own wind-up is a Pillar 6 REGRESSION however well he
## measures, and at this pitch the deck is still 49.53 against the painting's
## 55.03 — there is room left, and it is deliberately not being spent.
const RIM_ANGLE := Vector3(-1, 200, 0)
var _moon: DirectionalLight3D
var _lantern: DirectionalLight3D
var _rim: DirectionalLight3D
var _environment: Environment
var _moon_energy := 1.45
var _lantern_energy := 0.38
var _rim_energy := RIM_ENERGY
var _ambient_energy := 0.62
var _darkness := 0.0
var _darkness_target := 0.0
const DARKNESS_TAU := 0.55
## Never fully black. At 1.0 the deck is unplayable rather than dangerous, and
## the moon is the one thing that should still be up there.
const DARKNESS_FLOOR := 0.22


func set_darkness(amount: float) -> void:
	_darkness_target = clampf(amount, 0.0, 1.0)


func _sync_darkness(delta: float) -> void:
	if is_equal_approx(_darkness, _darkness_target) and _darkness <= 0.0001:
		return
	_darkness = lerpf(_darkness, _darkness_target, 1.0 - exp(-delta / DARKNESS_TAU))
	var keep: float = lerpf(1.0, DARKNESS_FLOOR, _darkness)
	if _moon != null:
		## The moon dims least. Losing the rim light entirely turns every figure
		## into a silhouette you cannot identify, which is unfair rather than dark.
		_moon.light_energy = _moon_energy * lerpf(1.0, 0.52, _darkness)
	if _rim != null:
		## And the rim dims WITH the moon, on the same curve, for the same reason
		## the moon does: in a hulk the rim is the last thing telling you the
		## shape at the rail has a boarder's outline. Losing it first would make
		## darkness hardest exactly where it is already hardest to read (SG-86).
		_rim.light_energy = _rim_energy * lerpf(1.0, 0.52, _darkness)
	if _lantern != null:
		_lantern.light_energy = _lantern_energy * keep
	if _environment != null:
		_environment.ambient_light_energy = _ambient_energy * keep
		## And the fog thickens, so the far end of the deck goes first — the bow
		## is where a push comes from, so that is the part worth losing.
		_environment.fog_enabled = true


## How far back the wheel has pulled the camera. 1.0 is the shipped framing, and
## it is the DEFAULT and the floor — you may pull out, never push in past the
## composition the art was built for.
var _zoom := 1.0
var _zoom_target := 1.0
const ZOOM_MIN := 1.0
const ZOOM_MAX := 1.55
const ZOOM_STEP := 0.09
const ZOOM_TAU := 0.11      ## eased, because a wheel notch that teleports is nausea


func zoom_by(notches: float) -> void:
	_zoom_target = clampf(_zoom_target + notches * ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)


func zoom_amount() -> float:
	return _zoom_target


## --- CUTSCENES ---------------------------------------------------------------
##
## The camera is the one thing in this renderer another system is allowed to
## take, and this is the only door it can take it through. `cue()` names a
## MOMENT; whether anything is wired to that moment is a question for the files
## in `assets/cutscenes/`, and the answer is usually no. A cue with no cutscene
## costs one directory listing and does nothing, which is what makes adding a
## shot to an existing moment a data change rather than a code change.
##
## The four moments and where they are fired from are listed in
## `SkyGearCutscene.CUES`, and the harness reads this source file to prove each
## one of them is really called. Three of the four are fired below — the
## renderer already watches the game's state every frame, so a moment that is
## only a state transition needs nothing from `game.gd`. The fourth,
## `boss_arrival`, is not a state: it is the frame the Colossus is instantiated,
## and only the spawn knows about that.
## LOADED BY PATH, NOT NAMED. `SkyGearCutscenePlayer` reaches
## `SkyGearCutscene`, which reads the four camera constants at the top of this
## file — so naming either class here closes a ring, and GDScript answers a ring
## by refusing to compile a file at the far end of it with a message that points
## at the wrong place. A runtime `load` costs one resource lookup at startup and
## keeps the dependency one-way: cutscenes know about the camera, the camera does
## not know about cutscenes.
const CUTSCENE_PLAYER := "res://scripts/cutscene_player.gd"
var _cutscene
var _cue_state := -1
var _cue_wave := -1
## Off in `tools/cutscene_lab.gd`, and nowhere else. The lab stages wave 12 to
## frame the Colossus, and without this that fires the very cutscene being
## authored on top of the authoring — hiding the interface, locking the controls
## and fighting for the camera.
var cutscenes_enabled := true


## Fire a moment. Returns whether a cutscene actually started, so a call site
## can tell the difference between "nothing is wired here" and "it is running".
func cue(name: String, wave_number: int = 0) -> bool:
	if not cutscenes_enabled or _cutscene == null:
		return false
	return bool(_cutscene.cue(name, wave_number))


func play_cutscene(id: String) -> bool:
	if _cutscene == null:
		return false
	return bool(_cutscene.play(id))


func cutscene_active() -> bool:
	return _cutscene != null and _cutscene.active()


func stop_cutscene() -> void:
	if _cutscene != null:
		_cutscene.stop()


## Three of the four cues, from state the renderer is already reading. Edge
## triggered on purpose: `state` and `wave` are levels, and a cutscene fired
## from a level runs every frame the level holds.
func _watch_cues() -> void:
	if game == null or _cutscene == null:
		return
	var state := int(game.state)
	var wave_number := int(game.wave)
	var first := _cue_state < 0
	var state_changed := state != _cue_state
	var wave_changed := wave_number != _cue_wave
	_cue_state = state
	_cue_wave = wave_number
	## The first frame is not a transition — everything has "changed" from -1,
	## and firing a victory shot because the renderer just booted would be a very
	## strange bug to chase.
	if first or _cutscene.active():
		return
	if state_changed and state == int(SkyGearGame.State.VICTORY):
		cue("victory")
		return
	if state_changed and state == int(SkyGearGame.State.GAMEOVER):
		cue("defeat")
		return
	## The establishing shot, owed by `begin_run` and spent HERE — the one place a
	## camera is allowed, once the opening draft is behind us and the deck is in
	## PLAY. Spent before `wave_start` so wave 1 opens the run rather than firing a
	## milestone flourish, and the flag is cleared so a run plays it exactly once.
	if wave_changed and wave_number == 1 and state == int(SkyGearGame.State.PLAY) \
			and bool(game.run_opening):
		game.run_opening = false
		cue("run_open")
		return
	if wave_changed and wave_number > 0 and state == int(SkyGearGame.State.PLAY):
		cue("wave_start", wave_number)


func _aim_from_cursor() -> void:
	## A posed cursor (SG-60's tool/harness seam) wins over the live mouse —
	## headless, the mouse is parked at 0,0 and would repaint the posed read
	## every frame.
	if _aim_pose_cursor.is_finite():
		game.set_cursor_ground(_aim_pose_cursor)
		return
	if camera == null:
		return
	var viewport := camera.get_viewport()
	if viewport == null:
		return
	var mouse := viewport.get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	## Parallel to the deck means the cursor is on or above the horizon. Keep the
	## last good point rather than aiming at infinity behind the ship.
	if absf(direction.y) < 0.00001:
		return
	var distance := -from.y / direction.y
	if distance <= 0.0:
		return
	var hit := from + direction * distance
	game.set_cursor_ground(Vector2(hit.x, hit.z) / WORLD_SCALE)


## Ground point under a screen position, for the harness and for anything that
## needs to ask without waiting for a frame.
func ground_at(screen: Vector2) -> Vector2:
	var from := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	if absf(direction.y) < 0.00001:
		return Vector2.ZERO
	var hit := from + direction * (-from.y / direction.y)
	return Vector2(hit.x, hit.z) / WORLD_SCALE


## Effects, projected flat onto the deck.
##
## In the browser every skill draws its shape on the ground, and it is most of
## what a fight looks like: the arc of a cleave, the ring of a mortar, the wedge
## of a gale, the streak of a beam. They live in the 2D scene here, which is no
## longer the scene anyone looks at — so they are rebuilt as unshaded quads lying
## a centimetre above the planking, which is what a decal is and what the browser
## was approximating.
## PAL.danger #FF3D2E outer, PAL.dangerIn #FF8C1A inner — the browser's hostile
## palette, oxblood-to-orange, never the player's teal. Class scope because the
## windup decals and the SG-28 aim dashes are the same language and must not
## carry two copies of it.
const TG_DANGER := Color(1.0, 0.239, 0.180)
const TG_DANGER_IN := Color(1.0, 0.549, 0.102)
## And the other half of the browser's split: the PLAYER's teal, the colour the
## cannon bars and the Boiler ring already speak. Everything ground-drawn that
## belongs to YOU — the aim ring (SG-60), the vent stand-here ring (SG-59) —
## says it in this, and never in the oxblood above. Mixing the two palettes is
## how a telegraph stops meaning "danger".
const PLAYER_TEAL := Color(0.216, 0.941, 0.784)   # #37f0c8
## How much of the recovery the strike flash burns through (SG-158). A fifth: it
## has to outlast a dropped frame and die well before the boarder can swing
## again, or the flash of one blow reads as the warning of the next. At the
## Colossus's 1.00 s recover that is 200 ms; at the furnace knight's, 130 ms.
const STRIKE_FLASH_FRAC := 0.20
## TG_SWING_ARC lived here — 120°, "the fallback wedge for a reach-less melee".
## It is DELETED rather than left unused (board SG-119): it was a second opinion
## about a swing's shape held in the renderer, and the one enemy it applied to
## was being drawn a wedge the simulation had never agreed to. Every arc this
## file draws now comes from `enemy.swing_wedge_arc()`.

## THE ANIMATED RANGED AIM LINE — board SG-28.
##
## SG-3 gave the GUNNER's windup a solid danger band with a counting-down hot
## core, and the readability is there — but the browser ALSO travels a DASHED
## line down the shot path (`setLineDash([14,12])`, `lineDashOffset = -rt*90`),
## and the march of the dashes is what reads as motion TOWARD you: not only
## "this lane is dangerous" but "something is about to come down it, this way".
##
## A decal cannot dash, so the dashes are geometry: short ribbon segments a hand
## above the planking, written into the same one-batch, one-draw, capped ribbon
## mesh as every other trail. Post-parity, one better-than: the dashes
## ACCELERATE as the windup completes (`wind` squared, on top of the browser's
## constant 90 u/s), so the line itself says how close the shot is. They exist
## only inside `state == "windup"` and are gone the frame the shot fires —
## the moment the band stops being a warning it stops being drawn.
const AIM_DASH_ON := 14.0        ## the browser's dash length, ground units
const AIM_DASH_OFF := 12.0       ## and its gap
const AIM_DASH_SPEED := 90.0     ## the browser's constant march, units/second
const AIM_DASH_ACCEL := 170.0    ## extra travel as the wind completes (wind², units)
const AIM_DASH_MAX := 26         ## dashes per line — capped, like every pool here
const AIM_DASH_HEIGHT := 12.0    ## off the planking, so it reads as a shot, not paint
var _aim_dashes_drawn := 0       ## this frame's count; reset with the ribbon batch


## How far the dash pattern has marched toward the target. Static and pure so
## the harness can pin both halves: the browser's 90 u/s base, and the
## acceleration as `wind` (0 at the start of the windup, 1 at the shot) rises.
static func aim_dash_travel(clock: float, wind: float) -> float:
	return clock * AIM_DASH_SPEED + wind * wind * AIM_DASH_ACCEL


func _aim_dash_ribbon(from: Vector2, dir: Vector2, length: float, wind: float) -> void:
	var period := AIM_DASH_ON + AIM_DASH_OFF
	## Negative first start, so a dash mid-birth slides in from the shooter's
	## end rather than popping whole — the pattern shifts toward the target as
	## the travel grows, which is the browser's negative dash offset.
	var s: float = -fmod(aim_dash_travel(_flicker, wind), period)
	## Hostile language, pushed over the 1.05 glow threshold like the decals.
	var sleeve := Color(TG_DANGER.r * 1.45, TG_DANGER.g * 1.45, TG_DANGER.b * 1.45)
	var hot := Color(TG_DANGER_IN.r * 1.45, TG_DANGER_IN.g * 1.45, TG_DANGER_IN.b * 1.45)
	var glow: float = 0.26 + 0.50 * wind
	var drawn := 0
	while s < length and drawn < AIM_DASH_MAX:
		var s0: float = maxf(s, 0.0)
		var s1: float = minf(s + AIM_DASH_ON, length)
		s += period
		if s1 - s0 < 2.0:
			continue
		var p0: Vector2 = from + dir * s0
		var p1: Vector2 = from + dir * s1
		var pts := PackedVector3Array([Vector3(p0.x, AIM_DASH_HEIGHT, p0.y),
			Vector3(p1.x, AIM_DASH_HEIGHT, p1.y)])
		## The same two-layer build as every ribbon: a soft oxblood sleeve and a
		## hot orange core, so a dash is a shape with a heart, not a stripe.
		_ribbon(pts, PackedFloat32Array([7.0, 7.0]),
			PackedColorArray([Color(sleeve, glow * 0.40), Color(sleeve, glow * 0.40)]))
		_ribbon(pts, PackedFloat32Array([3.2, 3.2]),
			PackedColorArray([Color(hot, glow), Color(hot, glow)]))
		drawn += 1
	_aim_dashes_drawn += drawn


## --- SG-60/SG-78: the player's own aim, on the deck ---------------------------
##
## "Hard to tell where an aimed skill will land — or determine range." The
## enemies telegraph everything (the oxblood language above); the player's own
## weapons telegraphed nothing. SG-60 answered that with three shapes: a range
## RING at `skill_stats().range`, a landing marker, and a cursor echo past the
## reach.
##
## SG-78 CUT IT BACK TO ONE, on the owner's screenshot of 2026-08-02. Verbatim:
## "it should be subtle, way more subtle. I am more interested in the smaller
## aiming reticle that's locked to the aiming distance of the player, I don't
## think we need more than that in-game." So the range ring is GONE from
## gameplay, the cursor echo with it, and what is left is the RETICLE: a small
## hollow collar where the shot will actually land — the cursor, clamped to the
## reach exactly as `cast_skill`'s aoe branch clamps it, so a Mortar thrown past
## its arc shows you the clamp instead of lying. Past the reach it loses its
## glow and dims: the dim IS the out-of-range read, and it costs no second
## shape.
##
## WHY IT DREW AS A FLOODED OPAQUE DISC, recorded because it is DESIGN §13e's
## trap arriving through a door §13e did not name. §13e fixed the EMISSION
## channel — a Decal's emission ignores texture alpha, so it is fed a
## premultiplied glow map instead. But the ring here was drawn through
## `_art("ring", …)`, which prefers the painted plate `rune_player.png` over the
## generated rim-only `_ring_texture()` — and that plate is 68% ALPHA-255: a
## filled disc, not a hollow ring. A filled disc premultiplies to a filled glow
## map, so the whole projection box lit; at `range * 2` — 840 ground units for a
## Mortar — that is a glowing opaque plate across half the deck. The reticle
## below therefore draws through `_ring_texture()` DIRECTLY, the same generated
## hollow rim the sentry collars and the Boiler ring use, and never through the
## painted-art seam.
##
## ARMED means: a skill key held, or the beat after a cast (`AIM_LINGER`), so
## every throw paints its own landing point for a beat and a player who wants to
## study a weapon holds its key. Cleave-shaped skills (kind "arc" — the
## auto-attack language, melee around the captain) and passives draw NOTHING: an
## aura already draws its own edge, and a mark under an auto-swing is noise with
## a palette.
##
## Keys are `fxaim_*` — the `fx` prefix routes them to the PLAYER decal
## reserve, so a flooded deck can never spend the aim read away (nor the aim
## read a telegraph).
const AIM_LINGER := 1.1
const AIM_MARK_MIN := 30.0        ## a point shape's marker collar, ground units
## And the ceiling. An aoe reticle shows its own blast footprint, which is
## honest — but a radius card must never be able to inflate the one remaining
## shape back into the disc SG-78 removed. Above a base Mortar's 110, below the
## width of a lane.
const AIM_MARK_MAX := 150.0
var _aim_pose_slot := -1          ## tool/harness seam — poses win over Input
var _aim_pose_cursor := Vector2.INF
var _aim_last := -1               ## last armed slot, for the post-cast linger
var _aim_until := -1.0            ## _flicker time the linger runs out
var _aim_seen_casts := {}         ## slot -> casts, to catch a cast this frame


## Pose the aim the way a player's hand would: `slot` reads as held, `cursor`
## wins over the live mouse (which in a headless harness is parked at 0,0 and
## would repaint the posed read every frame).
func pose_aim(slot: int, cursor: Vector2) -> void:
	_aim_pose_slot = slot
	_aim_pose_cursor = cursor


func clear_aim_pose() -> void:
	_aim_pose_slot = -1
	_aim_pose_cursor = Vector2.INF
	_aim_last = -1
	_aim_until = -1.0


## Which shapes get the read at all. Passives have no press and `arc` is the
## auto-attack language — both say nothing.
static func aim_shows(shape: Dictionary) -> bool:
	return not bool(shape.get("passive", false)) \
		and str(shape.get("kind", "")) != "arc"


## The reticle's radius for a blast of `blast`, in ground units: the skill's own
## footprint, floored so a point shape still has a mark and ceilinged so no card
## can grow the last remaining shape back into SG-78's disc. Static and pure so
## the harness pins both ends without posing a cast.
static func aim_mark_girth(blast: float) -> float:
	return clampf(blast, AIM_MARK_MIN, AIM_MARK_MAX)


## The whole read, computed once and drawn from — and the harness's window into
## it. Every number in here is `game.skill_stats`' own, never a copy.
func aim_read(index: int) -> Dictionary:
	if game == null or game.player == null \
			or index < 0 or index >= game.skills.size():
		return {}
	var skill: Dictionary = game.skills[index]
	if not aim_shows(SkyGearData.SHAPES[skill.shape]):
		return {}
	var st: Dictionary = game.skill_stats(skill)
	var origin: Vector2 = game.player.global_position
	var cursor: Vector2 = game.aim_target()
	var reach := float(st.range)
	var offset := cursor - origin
	var beyond: bool = offset.length() > reach
	## `cast_skill`'s aoe clamp, verbatim: normalized offset times the range.
	var land: Vector2 = cursor if not beyond \
		else origin + offset.normalized() * reach
	return {"slot": index, "range": reach, "origin": origin, "cursor": cursor,
		"land": land, "beyond": beyond, "blast": float(st.radius),
		"kind": str(st.kind)}


## The armed slot this frame, or -1. A held key wins; a cast lingers.
func _armed_slot() -> int:
	if _aim_pose_slot >= 0:
		return _aim_pose_slot
	if game == null:
		return -1
	var actions := ["skill_1", "skill_2", "skill_3", "skill_4"]
	for i in mini(game.skills.size(), actions.size()):
		## A cast this frame re-arms the read, so every throw paints its own
		## range for a beat. Increases only: a new run resets `casts` to zero
		## and that is not a press.
		var casts: int = int(game.skills[i].get("casts", 0))
		var seen: int = int(_aim_seen_casts.get(i, casts))
		_aim_seen_casts[i] = casts
		if casts > seen:
			_aim_last = i
			_aim_until = _flicker + AIM_LINGER
		if Input.is_action_pressed(actions[i]):
			_aim_last = i
			_aim_until = _flicker + AIM_LINGER
	if _aim_last >= 0 and _flicker < _aim_until:
		return _aim_last
	return -1


func _sync_aim() -> void:
	if game.state != SkyGearGame.State.PLAY \
			or game.player == null or game.player.hp <= 0.0:
		return
	if _cutscene != null and _cutscene.active():
		return
	var read := aim_read(_armed_slot())
	if read.is_empty():
		return
	## THE RETICLE, AND NOTHING ELSE (SG-78). An aoe shows its true blast
	## footprint between the collar and the ceiling, a point shape the collar. In
	## range it glows; past it the glow goes and the alpha halves — which is the
	## whole out-of-range read, colour untouched.
	##
	## `_ring_texture()` directly, NOT `_art("ring", …)`: the painted plate is a
	## filled disc and this is the one shape left, so it stays hollow. See the
	## block above.
	var girth: float = aim_mark_girth(float(read.blast))
	var hot: bool = not bool(read.beyond)
	_decal("fxaim_land", read.land, 0.0, girth * 2.0, girth * 2.0,
		_ring_texture(),
		Color(PLAYER_TEAL.r, PLAYER_TEAL.g, PLAYER_TEAL.b,
			0.45 if hot else 0.22), hot)


func _sync_effects() -> void:
	for i in game.effects.size():
		var fx: Dictionary = game.effects[i]
		## By ID, never by index. See `_fx()` in game.gd — these arrays compact
		## on expiry, so an index is a different effect from one frame to the
		## next and the node pooled against it inherits the wrong contents.
		var fid: int = int(fx.get("id", -1))
		if fid < 0:
			continue
		var kind := str(fx.kind)
		if kind == "banner":
			continue
		var progress: float = float(fx.time) / maxf(0.001, float(fx.life))
		var alpha: float = clampf(1.0 - progress, 0.0, 1.0)
		var colour: Color = fx.get("color", Color.WHITE)
		## Over 1.0 on purpose. The glow threshold is 1.05, so a skill drawn at
		## its own palette value never blooms — and the browser's rings all carry
		## a hand-painted halo. This is the same halo, from the post chain.
		var tint := Color(colour.r * 1.45, colour.g * 1.45, colour.b * 1.45, alpha)
		var centre: Vector2 = fx.get("position", Vector2.ZERO)
		## WHICH ELEMENT THIS IS, from the effect rather than guessed from its
		## colour. The trails carry element identity in their SHAPE — see
		## `ELEMENT_RIBBON` — and shape cannot be recovered from a hue: two cards
		## can tint the same, and the keg and the vent are not elements at all.
		## Anything with no element falls back to Ember's handwriting, which is
		## also what the impact particles do.
		var element := str(fx.get("element", ""))
		if not ELEMENT_RIBBON.has(element):
			element = "EMBER"
		## Stable per effect, so a bolt's wander crawls along its own length
		## instead of boiling from frame to frame.
		var phase: float = float(fid) * 1.37 + _flicker * float(ELEMENT_RIBBON[element].hz)
		match kind:
			"arc":
				var r: float = float(fx.get("radius", 120.0)) * (0.9 + progress * 0.2)
				_decal("fx%d" % fid, centre, float(fx.get("direction", 0.0)),
					r * 2.0, r * 2.0, _art("slash", _fan_texture(float(fx.get("arc", 1.7)), false)),
					tint)
				## A player swing tells the blade trail what colour it is — the fx
				## carries the element, and the trail is drawn from the bone.
				if bool(fx.get("follow", false)):
					_trail_element = element
					_trail_colour = colour
				## The effect-clock sweep only when the blade is NOT driving the
				## trail (SG-18): billboard tier, missing mount. Two authorities
				## drawing one swing is the picture disagreeing with itself.
				if not _blade_trail_live():
					_sweep_ribbon(fx, fid, centre, r, element, colour, alpha, progress)
			"cone":
				var rc: float = float(fx.get("radius", 120.0)) * (0.55 + progress * 0.55)
				_decal("fx%d" % fid, centre, float(fx.get("direction", 0.0)),
					rc * 2.0, rc * 2.0, _fan_texture(float(fx.get("arc", 0.9)), true),
					Color(tint.r, tint.g, tint.b, tint.a * 0.85))
				## The Boilerwright's swing is a cone; his blade trail rides OVER
				## the gust, coloured by the same cast (SG-18, both classes).
				if bool(fx.get("follow", false)):
					_trail_element = element
					_trail_colour = colour
				_gust_ribbon(fx, fid, centre, rc, element, colour, alpha, progress)
			"circle":
				var rb: float = float(fx.get("radius", 120.0)) * maxf(0.25, progress)
				## `_ring_texture()`, NOT `_art("ring", …)` — see the block above
				## the `burst` arm. A Pulse's ring is `radius * 2`, a gameplay
				## number, and the painted plate is opaque across its whole disc.
				_decal("fx%d" % fid, centre, 0.0, rb * 2.0, rb * 2.0,
					_ring_texture(), tint)
				## And the wall of it, standing up off the deck. A Pulse and a vent
				## are shockwaves through the air; the ring on the planking is where
				## they REACH, which is a different question from what they are.
				_wave_ribbon(centre, rb, element, colour, alpha * 0.9, progress)
				## A lobbed shell, when the effect came from somewhere. `from` is
				## written by the Mortar and nothing else, which is why this is the
				## only ring that has anything in the air over the throw.
				if fx.has("from"):
					_lob_ribbon(fid, Vector2(fx.from), centre, element, colour, progress)
			"burst":
				## THE LAST SHAPE THAT WAS STILL A PAINTED CARD (board SG-63).
				##
				## This drew ONE thing: `burst_impact.png` as a decal at
				## `radius * 2`. Two faults in one line, and they are the two
				## faults this whole item is about.
				##
				## **It had no body.** Every other shape got geometry in the air
				## on 2026-07-31 (VFX-PLAN §3/§4); this one was skipped, so the
				## game's death-and-detonation effect — every kill, every powder
				## keg, the hulk coming apart — was a flat cartoon star lying on
				## the planking under a thing that had just come apart in the
				## air. The shards fix that; see `_burst_ribbon`.
				##
				## **And the plate is the SG-78 trap again.** `burst_impact`
				## measures fully opaque at its centre, falling to alpha 14 only
				## at the extreme rim: a filled blob, not a hollow mark. DESIGN
				## §13e's rule is that a decal whose size scales with a gameplay
				## number must draw through a texture whose hollowness is
				## GUARANTEED, and this one scaled to 520 ground units on a hulk
				## break. It draws through `_ring_texture()` now — a shock ring
				## marking where the blast reached, which is the readable half
				## the audit says to keep, with the violence moved into the air
				## where it belongs.
				var rp: float = float(fx.get("radius", 120.0)) * (0.5 + progress * 0.9)
				_decal("fx%d" % fid, centre, 0.0, rp * 2.0, rp * 2.0,
					_ring_texture(), Color(tint.r, tint.g, tint.b, tint.a * 0.55))
				var rb2: float = float(fx.get("radius", 120.0))
				_burst_ribbon(fid, centre, rb2, element, colour, alpha, progress)
				## Once per effect, whatever frame the renderer first sees it on
				## — never once per frame, which would be a keg throwing its
				## whole load fifteen times over.
				if _burst_new(fid):
					_burst_debris(centre, rb2, element, colour)
					## And the boards are scorched, if the blast was big enough
					## to have scorched them. 150 separates the keg (175) and the
					## hulk coming apart (260) from a kill's own little burst
					## (radius*2.5, 60-100) — which leaves a body's mark instead
					## and does not get a scorch as well. DECK-IDENTITY §7.3.
					if rb2 >= MARK_BURST_MIN:
						_mark(MarkKind.SCORCH, centre, rb2 / 175.0)
			"line", "beam":
				var from: Vector2 = fx.get("from", Vector2.ZERO)
				var to: Vector2 = fx.get("to", Vector2.ZERO)
				var span := to - from
				## The ground streak is kept and DIMMED. It is the readable half —
				## it says where across the deck the shot passed, which the audit is
				## right that an airborne trail communicates worse — but at full
				## strength it was also the only half, and it read as a scratch on
				## the planking. Half the alpha makes it the shadow of the bolt
				## rather than the bolt.
				var width: float = (26.0 if kind == "line" else 54.0) * (1.0 - progress * 0.35)
				_decal("fx%d" % fid, (from + to) * 0.5, span.angle(),
					maxf(8.0, span.length()), width,
					_art("bolt", _streak_texture()) if kind == "line" else _streak_texture(),
					Color(tint.r, tint.g, tint.b, tint.a * 0.45))
				if kind == "beam":
					_beam_ribbon(from, to, element, colour, alpha, progress, phase)
				else:
					_bolt_ribbon(fid, from, to, element, colour, alpha, progress,
						phase, float(fx.get("lift", 0.0)))
			_:
				## An effect kind nothing here names. It gets the same two halves
				## every named one gets — a hollow mark on the planking AND a wall
				## of air standing off it — so a shape added to the sim tomorrow
				## arrives with a body rather than as a plate on the floor, which
				## is how this arm read for every kind that ever fell through it.
				var rr: float = float(fx.get("radius", 90.0))
				_decal("fx%d" % fid, centre, 0.0, rr * 2.0, rr * 2.0, _ring_texture(), tint)
				_wave_ribbon(centre, rr, element, colour, alpha * 0.8, progress)

	## Lingering fire. It is a hazard you have to read the floor for, so it gets
	## a decal that breathes rather than a static disc.
	## THE PICTURE IS THE BURN NOW (board SG-163, owner: *"For the fire hitbox,
	## match the burn size. Fix the picture to match the damage."*)
	##
	## THIS LINE USED TO READ `float(f.get("radius", 62.0)) * 2.2`, and every part
	## of that was a second opinion. `field.radius` is set by the three `_field()`
	## sites to 46, 62 and 62 + 22·residue; the burn is `game.fire_pool_radius()`
	## and has been a flat 78 since it was written. So the Sear trail's pool was
	## DRAWN at a rim of about 46 and BURNED at 78 — it cooked you from 70% outside
	## its own picture, and the safe-looking ring of deck around it was the part
	## that hurt. `radius` is not consulted here any more; the renderer asks the
	## simulation how big the pool is, which is the only arrangement in which the
	## two cannot drift (STATUS failure mode two).
	##
	## `ring_span_for()` rather than a multiplier, because the ring texture's bright
	## band peaks at 92% of its own half-size: sizing the decal to `burn * 2` would
	## have put the visible line 8% INSIDE the burn and shipped a smaller version of
	## the same bug while claiming to have fixed it.
	var burn: float = game.fire_pool_radius()
	for i in game.fire_fields.size():
		var f: Dictionary = game.fire_fields[i]
		var pulse: float = 0.72 + sin(_flicker * 7.0 + float(i)) * 0.14
		var fid2: int = int(f.get("id", i))
		## The scorch on the planking, and the fire standing on top of it. The
		## scorch is a soft dark disc ending exactly where the bright line is, so
		## the two halves of the mark agree about the boundary instead of the soot
		## trailing past it.
		var fr: float = burn * 2.0
		_decal("scorch%d" % fid2, f.position, 0.0, fr, fr, _art("scorch", _blob_texture()),
			Color(0.10, 0.07, 0.08, 0.75), false)
		## `_ring_texture()`: this is a gameplay-scaled decal and the painted plate
		## is opaque across its whole disc (SG-63, the SG-78 rule).
		var span: float = ring_span_for(burn)
		_decal("fire%d" % fid2, f.position, 0.0, span, span,
			_ring_texture(),
			Color(1.0, 0.52, 0.18, clampf(float(f.time) / 3.0, 0.0, 1.0) * pulse))
		## Fire burns the boards, and the burn outlasts the fire. Once per field
		## id — a field is a LEVEL the renderer sees every frame, and a mark that
		## restamped would be a clock wearing an event's clothes. The id space is
		## offset off the fx sequence so two unrelated counters cannot collide.
		if _mark_new(0x20000000 + fid2):
			_mark(MarkKind.SCORCH, f.position, fr / 190.0)

	## CRACKED MAINS. The Boilerwright's ground, and the only thing on the deck a
	## player put there on purpose — so it has to read as a place rather than as
	## an effect. A hard rim you can stand on the edge of, a soft fill, and steam
	## boiling off it; the rim is what matters, because the class is about knowing
	## exactly where the line is.
	for i in game.taps.size():
		var tap: Dictionary = game.taps[i]
		var left: float = clampf(float(tap.life) / maxf(0.1, float(tap.max_life)),
			0.0, 1.0)
		## The last two seconds pulse, same language the sentries use.
		var dying: bool = float(tap.life) < 2.0
		var beat: float = 1.0 if not dying else 0.55 + 0.45 * absf(sin(_flicker * 9.0))
		var span: float = float(tap.radius) * 2.0
		var steam := Color("#9be8d2")
		_decal("tapf%d" % i, tap.position, 0.0, span, span, _blob_texture(),
			Color(steam.r, steam.g, steam.b, 0.16 * beat), false)
		_decal("tapr%d" % i, tap.position, 0.0, span, span, _ring_texture(),
			Color(steam.r, steam.g, steam.b, 0.72 * beat))
		## A cracked main bleaches the boards around it, and THAT is where the
		## scald goes — not under a vent. A vent has no event: `_fill_head` polls
		## a distance every frame and emits nothing, so a vent scald could only
		## ever be driven by a clock, which is item 6's named failure. A tap is a
		## place a player chose. `taps` carry no id, so the key is the place
		## itself, quantised to 40 units — two taps in one cell are one scald.
		var tkey: int = 0x40000000 + int(floor(tap.position.x / 40.0)) * 4096 \
			+ int(floor(tap.position.y / 40.0))
		if _mark_new(tkey):
			_mark(MarkKind.SCALD, tap.position, float(tap.radius) / 110.0)
		## And it is venting, visibly — three plumes off the rim rather than one
		## in the middle, because a main is a crack in the deck, not a fountain.
		for plume in 3:
			var angle: float = _flicker * 0.5 + float(plume) * TAU / 3.0
			var at: Vector2 = Vector2(tap.position) + Vector2(cos(angle), sin(angle)) 				* float(tap.radius) * 0.62
			_spark("tapv%d_%d" % [i, plume], at, 60.0 + sin(_flicker * 3.0 + plume) * 24.0,
				52.0 * beat, steam)

	## The ordnance the deck already knows about: a lit keg draws its blast.
	for prop in game.props():
		if is_instance_valid(prop) and not prop.dead and prop.fuse_left > 0.0:
			var f2: float = 1.0 - prop.fuse_left / 0.45
			_decal("keg%d" % prop.get_instance_id(), prop.global_position, 0.0, 350.0, 350.0,
				_ring_texture(), Color(0.95, 0.92, 1.0, 0.25 + f2 * 0.35))

	## Enemy telegraphs. Design pillar 6 — every attack readable before it is
	## dangerous, and this is the single most important thing on screen when three
	## boarders are on you. The browser draws a MELEE windup as a filled oxblood
	## WEDGE covering the swing arc out to `reach`, brightening as the swing nears;
	## a RANGED shooter's shot as a danger band down its firing line; the Colossus
	## turn as a held gold ring. The port had shrunk the melee tell to a thin red
	## streak the width of a plank plus a small foot ring — present, but not the
	## thing you read across a crowd (board SG-3). Rebuilt at the same `reach`/`swing`
	## the swing itself uses (game_data), so what is DRAWN and what CONNECTS are one
	## shape, not a picture and a hit-check disagreeing about a number.
	##
	for enemy in game.enemies():
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		if enemy.state == "stomp":
			## THE STOMP, DRAWN (board SG-166). The owner asked for "damage around
			## him"; this is the picture that makes it fair.
			##
			## TWO RINGS, AND THEY ANSWER THE TWO DIFFERENT QUESTIONS a telegraph has
			## to answer. A thin outline held at the FULL radius for the whole
			## telegraph says WHERE — where the edge is, so "am I out?" is readable
			## the instant the mark appears rather than only at the end. A second,
			## brighter ring growing from his own body out to that edge says WHEN —
			## it is the countdown, run off the sim's own `state_time` exactly the way
			## the windup wedge's inner fill is. COLOSSUS-DESIGN §5 asked for this
			## pair by name; what it wanted from the shape is the standing-place, and
			## a static ring is the only mark that gives you one.
			##
			## HOLLOW, BOTH OF THEM. A filled 240-unit disc under the biggest figure
			## on the deck is the flooded-plate trap SG-78 and SG-63 paid for twice,
			## and `_ring_texture()` is the generated rim every ring in this game
			## draws through now. It is also the only reason the mark survives him
			## standing in it: at 41 degrees his body covers the middle, and the rim
			## is the part he cannot hide (SG-158's finding, one shape over).
			##
			## OXBLOOD AND ORANGE, the hostile family — not the turn's gold and never
			## the player's teal. The SHAPE carries the difference from a swing: a
			## circle means "leave", a fan means "step around". Same palette, two
			## verbs, one frame to tell them apart.
			##
			## CENTRED ON `stomp_origin`, NOT ON HIM. The sim resolves at the anchor,
			## so the mark is drawn at the anchor; a Colossus shoved mid-telegraph
			## must not drag the promise of where the blow lands after him.
			## The RADIUS is `enemy.stomp_radius()` — his function, the one the hit
			## test calls. This file does not own a second opinion about it.
			var sr: float = float(enemy.stomp_radius())
			var sk: float = 1.0 - clampf(enemy.state_time
				/ maxf(0.05, float(enemy.stomp_wind)), 0.0, 1.0)
			_decal("ts%d" % enemy.get_instance_id(), enemy.stomp_origin, 0.0,
				sr * 2.0, sr * 2.0, _ring_texture(),
				Color(TG_DANGER.r, TG_DANGER.g, TG_DANGER.b, 0.30 + 0.26 * sk))
			## From his own footprint outward, so the growth reads as the weight
			## coming down rather than as a second, smaller circle appearing.
			var closing: float = lerpf(float(enemy.radius), sr, sk) * 2.0
			_decal("tsc%d" % enemy.get_instance_id(), enemy.stomp_origin, 0.0,
				closing, closing, _ring_texture(),
				Color(TG_DANGER_IN.r, TG_DANGER_IN.g, TG_DANGER_IN.b, 0.35 + 0.55 * sk))
		elif enemy.state == "windup":
			## 0 at the start of the wind, 1 the instant it connects: the clock.
			var kk: float = 1.0 - clampf(enemy.state_time / maxf(0.05,
				float(enemy.config.windup)), 0.0, 1.0)
			var flick: float = 0.34 + 0.30 * kk + sin(_flicker * 22.0) * 0.06
			var ang: float = enemy.attack_direction.angle()
			if enemy.config.ai == "ranged":
				## The firing line: a danger band down the shot's path, atkRange + 80
				## (the browser's aim-line length), with a brighter hot core that runs
				## out as the wind completes so the band itself counts down.
				var flen: float = float(enemy.config.attack_range) + 80.0
				var fmid: Vector2 = enemy.global_position + enemy.attack_direction * flen * 0.5
				_decal("tg%d" % enemy.get_instance_id(), fmid, ang, flen, 28.0,
					_streak_texture(), Color(TG_DANGER.r, TG_DANGER.g, TG_DANGER.b, 0.18 + kk * 0.44))
				var clen: float = flen * (0.34 + 0.66 * kk)
				var cmid: Vector2 = enemy.global_position + enemy.attack_direction * clen * 0.5
				_decal("tr%d" % enemy.get_instance_id(), cmid, ang, clen, 13.0,
					_streak_texture(), Color(TG_DANGER_IN.r, TG_DANGER_IN.g, TG_DANGER_IN.b, 0.9))
				## And the browser's travelling dashes over the band (SG-28): the
				## march down the path is the "it is coming toward you" read the
				## static band cannot carry. Windup only — gone the frame it fires.
				_aim_dash_ribbon(enemy.global_position, enemy.attack_direction, flen, kk)
			else:
				## The swing wedge. Apex on the boarder, opening down its facing to
				## `reach`, spanning `swing` — and BOTH come from `enemy.gd`'s own
				## `swing_wedge_*()`, the same call the sim connects with, so this
				## drawing cannot disagree with the hit test (board SG-119). There
				## used to be a fallback branch here for a reach-less melee, which
				## invented a 120° arc the sim had never heard of; it is gone, and
				## the Colossus's second-beat extension lives in that one function
				## instead of being re-derived on this side.
				var reach: float = enemy.swing_wedge_reach()
				var arc: float = enemy.swing_wedge_arc()
				## THE DECAL ALPHA WENT UP AND THE SHAPE GOT DIMMER (board SG-162).
				## `_fan_texture` now spends its alpha on a rim line rather than on
				## its interior, so the same 0.5 multiplier that used to produce a
				## bright orange puddle would produce a rim you could not see. The
				## multiplier is gone: the TEXTURE owns the fill-to-edge ratio now,
				## and this number is just how loud the whole mark is. At full wind
				## the boundary peaks near 0.66 alpha over a fill of 0.08–0.17,
				## which is the 4:1-to-8:1 the ring has always had.
				_decal("tg%d" % enemy.get_instance_id(), enemy.global_position, ang,
					reach * 2.0, reach * 2.0, _fan_texture(arc, true),
					Color(TG_DANGER.r, TG_DANGER.g, TG_DANGER.b, clampf(flick, 0.0, 1.0)))
				## The inner wedge fills outward as the wind completes: the clock.
				## It carries a hard rim of its own now, so the clock is a LINE
				## travelling out to meet the boundary rather than a puddle
				## growing — and it is deliberately dimmer than the boundary it is
				## travelling toward. Two hard lines of equal weight would be two
				## boundaries, and only one of them is the one you must not cross.
				var fill: float = maxf(0.10, kk)
				_decal("tr%d" % enemy.get_instance_id(), enemy.global_position, ang,
					reach * 2.0 * fill, reach * 2.0 * fill, _fan_texture(arc, true),
					Color(TG_DANGER_IN.r, TG_DANGER_IN.g, TG_DANGER_IN.b, 0.55))
		elif enemy.state == "recover" and enemy.config.ai != "ranged":
			## THE STRIKE AND THE OPENING — the two frames this deck never drew
			## (SG-158, and the owner asked for it twice).
			##
			## WHAT WAS WRONG IS THAT THE WARNING WAS THE WHOLE ACCOUNT. The wedge
			## above is drawn only while the boarder is WINDING UP. On the frame it
			## actually strikes you, that decal is simply not re-used and the
			## renderer shelves it — so the player's entire visual record of being
			## hit is *a warning disappearing*. And the second of recovery after
			## it, the window the fight is built around punishing, carried no mark
			## at all. Two of the three beats of every melee exchange were unlit.
			##
			## BOTH SHAPES COME FROM `enemy.gd`'s OWN `swing_wedge_*()`, the same
			## call the windup above uses and the same one the simulation connects
			## with, so the strike is drawn exactly where it was warned and exactly
			## where it landed. Three derivations of one wedge is what board SG-119
			## cost us; this adds none.
			##
			## AND THE DIRECTION IS THE SWING'S, NOT THE BODY'S. `attack_direction`
			## is aimed ONCE, when the wind starts, and never re-aimed — that is
			## what makes a walking captain hit by only one swing in three (SG-156)
			## and it is deliberate. Reading it here rather than the boarder's
			## facing means the mark sits where the blow actually went, including
			## when it went wide of you. A miss you can SEE miss is the point.
			var rreach: float = enemy.swing_wedge_reach()
			var rarc: float = enemy.swing_wedge_arc()
			var rang: float = enemy.attack_direction.angle()
			## 0 on the strike frame, 1 when he is ready again: the clock, run the
			## same way the windup's runs, off the sim's own countdown.
			var rr: float = 1.0 - clampf(enemy.state_time
				/ maxf(0.05, float(enemy.config.recover)), 0.0, 1.0)
			##
			## 1. THE STRIKE FLASH, AND IT IS DRAWN ON THE RIM ON PURPOSE.
			## `_fan_texture(arc, false)` is the unfilled variant — a bright band
			## at the outer edge of the fan — and it has existed unused since the
			## fan was written. It is the right shape here for a reason the owner
			## measured: the enemy STANDS ON its own warning, and at this camera
			## its body is between the player and the patch of deck the filled
			## wedge paints, so the Colossus hides nearly all of his. The rim is
			## the one part of that wedge the body cannot cover — and it is also
			## exactly where the captain is standing when the blow arrives.
			## Fast: gone within a fifth of the recovery, because a flash that
			## outlasts the hit reads as a second attack starting.
			var flash: float = clampf(1.0 - rr / STRIKE_FLASH_FRAC, 0.0, 1.0)
			if flash > 0.0:
				## KEPT SATURATED, and the first cut of this was not. Pushing it
				## most of the way to white and giving it a full-alpha emission
				## made a pale bloom on the planking that read as spilled LIGHT
				## rather than as a mark with an edge — indistinguishable from the
				## knight's own furnace glow in `.shots/sg158`. The hostile orange
				## carries the shape; only a fifth of the way to white, which is
				## enough to separate the blow from the warning that preceded it
				## without turning the band into a lamp.
				var hot: Color = Color(TG_DANGER_IN.r, TG_DANGER_IN.g,
					TG_DANGER_IN.b).lerp(Color(1, 1, 1), 0.20 * flash)
				## AND IT FLASHES THE SHAPE THAT ACTUALLY LANDED (SG-166). `recover`
				## is shared by the swing and the Colossus's stomp, and the two are
				## different shapes in different places: flashing a fan after a
				## circular blow would light ground where nothing happened, which is
				## the same class of lie SG-119 fixed in the other direction. The
				## boarder itself says which — `stomp_struck` is written on the frame
				## the blow resolves — and the stomp's flash is drawn at its ANCHOR
				## and its own radius, both read from the simulation.
				if enemy.stomp_struck:
					var sfr: float = float(enemy.stomp_radius()) * 2.0
					_decal("tsf%d" % enemy.get_instance_id(), enemy.stomp_origin,
						0.0, sfr, sfr, _ring_texture(),
						Color(hot.r, hot.g, hot.b, 0.22 + 0.56 * flash))
				else:
					_decal("tf%d" % enemy.get_instance_id(), enemy.global_position,
						rang, rreach * 2.0, rreach * 2.0, _fan_texture(rarc, false),
						Color(hot.r, hot.g, hot.b, 0.22 + 0.56 * flash))
			##
			## 2. THE OPENING — A RING ON HIS OWN FOOTPRINT, AND IT IS TEAL.
			##
			## THIS WAS A FILLED WEDGE FIRST AND THE WEDGE WAS THE WRONG CARRIER.
			## A wedge is a statement about GROUND — "this patch is dangerous" —
			## and the recovery is not about ground at all, it is about a TARGET
			## being open. Worse, the filled wedge is painted on the deck the
			## boarder is standing on, which is the exact occlusion the owner
			## measured: the Colossus's body covered nearly all of it, so the mark
			## meant to say "hit him" was hidden behind him.
			##
			## A ring on his own footprint is the answer to both. It reads as a
			## property OF HIM rather than of the planking, and a ring survives
			## the body standing in it — the near arc is occluded, the rest is not,
			## which is why the arrival ring works at this camera.
			##
			## TEAL, because this is the only ground mark in the game that says
			## "now hit HIM". Red means a thing is about to happen TO you; teal
			## has meant "this is yours" since the aim ring, and a punish window
			## drawn in oxblood would be the precise way to make a telegraph stop
			## meaning danger.
			##
			## It FADES rather than fills: the window is widest the instant he is
			## committed and closes as he recovers, so the mark is strongest when
			## acting on it is safest.
			var open_a: float = 0.55 * (1.0 - 0.62 * rr)
			## WIDE ENOUGH TO CLEAR HIS OWN BODY, which is the whole trick and the
			## reason the first size drew nothing at all. The arrival ring gets to
			## sit at barely twice the gameplay radius because a boarder in its
			## arrival window is IN THE AIR — the planking under it is unobstructed.
			## A recovering boarder is standing on its ring, and at 1.5x the body
			## covered every pixel of it. 2.5x puts the band outside the footprint
			## the figure paints on the deck, which is the only place it can be
			## seen from this camera. It also lands near the reach of the heavy it
			## matters most for — the Colossus's ring reads at 175 against his 146.
			var open_span: float = float(enemy.radius) * 2.0 * 2.5
			_decal("tp%d" % enemy.get_instance_id(), enemy.global_position, 0.0,
				open_span, open_span, _ring_texture(),
				Color(PLAYER_TEAL.r, PLAYER_TEAL.g, PLAYER_TEAL.b, open_a))
		elif enemy.airborne():
			## THE LANDING RING — board SG-135, and it is a telegraph that has
			## existed for months where nobody could see it.
			##
			## `enemy.gd::_draw()` has always drawn a gold `#e8c376` ring around a
			## boarder in its arrival window. It draws it in the 2D scene, which
			## is HIDDEN, so no player has ever seen it — a mark with no reader,
			## STATUS's first failure mode wearing a colour. This is that ring,
			## promoted onto the planking, where the mark for every other
			## telegraph on this deck already lives.
			##
			## AND IT CLOSES, which the 2D one never did. A ring at a fixed radius
			## says "something is here"; a ring shrinking from wide to the
			## boarder's own gameplay radius says WHEN, and a countdown is the
			## whole difference between a decoration and a telegraph. It is also
			## the only channel that survives the thing SG-102 measured and stage
			## one cannot fix: from mid-deck at zoom 1.0 the deck is 100% of the
			## frame and NO hull is visible, so the arrival has to be legible from
			## the planking or it is legible nowhere.
			##
			## THE CLOCK IS THE SIM'S OWN and the window is read off the boarder
			## rather than re-declared here — `SkyGearEnemy.ARRIVAL_TIME`. And the
			## CENTRE is `global_position`, live, every frame: the sim owns where
			## a boarder lands, so the ring cannot promise a spot the boarder does
			## not take.
			var closing := arrival_ring_closing(enemy.state_time)
			var span := arrival_ring_span(float(enemy.radius), enemy.state_time)
			## Brightening as it closes, for the same reason: the last quarter
			## second is the one that has to be read across a crowded deck.
			_decal("tar%d" % enemy.get_instance_id(), enemy.global_position, 0.0,
				span, span, _ring_texture(),
				Color(ARRIVAL_RING.r, ARRIVAL_RING.g, ARRIVAL_RING.b,
					0.34 + 0.52 * closing))
		elif enemy.state == "turn":
			var ring: float = (enemy.radius + 26.0 + sin(enemy.turn_time * 9.0) * 6.0) * 2.0
			## Hollow by construction: `ring` is built from the boss's own radius,
			## and a TELEGRAPH is the last decal in the game allowed to flood the
			## deck it is warning about.
			_decal("tn%d" % enemy.get_instance_id(), enemy.global_position, 0.0, ring, ring,
				_ring_texture(), Color("#ffd36b"))


## One ground effect, pooled, as an actual projected decal.
##
## THIS WAS NOT 3D. Every skill shape, every fire field, every contact shadow was
## an unshaded quad lying one and a half centimetres above the deck plane, which
## is a 2D sticker that happens to live in a 3D scene. Three things follow from
## that and all three were visible:
##
##   1. **Z-fighting.** 0.015 m of separation inside a 0.05–400 m depth range is
##      inside the depth buffer's own precision. Rings shimmered.
##   2. **Slicing.** The quad is a flat plane, so where an effect reached a cargo
##      run it was cut off along a hard straight line instead of climbing it, and
##      where it reached the Boiler plinth it went through it.
##   3. **No conforming.** A mortar landing at the foot of a crate painted half a
##      ring on the floor and nothing on the crate.
##
## Godot's `Decal` is the fix and it is the whole reason to be in a 3D renderer
## for this: it projects down a box onto whatever geometry is inside it, so the
## ring wraps the deck AND the crate, cannot z-fight because it is not a surface,
## and needs no depth ordering against anything.
##
## `angle` aims the texture's +X down a direction in ground coordinates; `sx`/`sy`
## are its size along and across that.
## What a decal is FOR, and how many of each we will draw.
##
## The pooling was real but the budget was not: `_decal` would allocate an
## unbounded number of live decals, and a decorative scorch competed on equal
## footing with an enemy windup rune. On a bad frame the thing that gets dropped
## should never be the thing that tells you a boarder is about to hit you.
##
## Reserved rather than shared. A telegraph is guaranteed its capacity even when
## the deck is covered in scorch marks.
## THE LANDING RING'S COLOUR AND ITS OPENING WIDTH (board SG-135). The colour is
## `enemy.gd::_draw()`'s own `#e8c376` — the ring this promotes out of the hidden
## 2D scene — because the point is to SHOW the mark that has always been drawn,
## not to invent a second one. The width is a MULTIPLE of the boarder's own
## gameplay radius rather than a flat number of units, so a gremlin's ring and a
## Colossus's both close onto the circle you actually have to fight.
const ARRIVAL_RING := Color("#e8c376")
const ARRIVAL_RING_WIDE := 3.4


## HOW FAR THROUGH ITS CLOSE THE RING IS — 0 the frame the boarder starts
## arriving, 1 the frame it lands. Eased out, so the ring slams shut on contact
## rather than creeping in at a constant rate; the last quarter second is the one
## that has to read across a crowded deck.
##
## STATIC AND PURE, the `corpse_drop` idiom: the harness can pin the countdown
## without standing a deck up, and the clock is the SIMULATION's own `state_time`
## counting down over the SIMULATION's own `ARRIVAL_TIME`, so `tools/still.gd`
## freezes the ring by construction and nothing here holds a second copy of 0.8.
static func arrival_ring_closing(state_time: float) -> float:
	var t: float = 1.0 - clampf(state_time
		/ maxf(0.05, SkyGearEnemy.ARRIVAL_TIME), 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 2.2)


## …and how wide it is drawn, as a DIAMETER in ground units. It ends at exactly
## the boarder's own gameplay radius: the ring is a promise about the circle you
## will have to fight, so it may not close onto a circle that is not that one.
static func arrival_ring_span(radius: float, state_time: float) -> float:
	return lerpf(radius * ARRIVAL_RING_WIDE, radius,
		arrival_ring_closing(state_time)) * 2.0

enum DecalClass { TELEGRAPH, PLAYER, DECOR }
const DECAL_BUDGET := {
	DecalClass.TELEGRAPH: 48,      ## enemy windups and turn rings — never dropped
	DecalClass.PLAYER: 24,         ## your own shapes, fields and aura edges
	DecalClass.DECOR: 40,          ## scorch, glow pools, keg blasts, bolt trails
}
var _decal_live := {DecalClass.TELEGRAPH: 0, DecalClass.PLAYER: 0, DecalClass.DECOR: 0}


## Which budget a key draws from. Derived from the key rather than passed in, so
## a new effect cannot forget to declare itself and quietly spend a telegraph.
static func _decal_class(key: String) -> DecalClass:
	## The landing ring is a TELEGRAPH and spends that budget. A ring that fell
	## through to DECOR would be evicted by scorch marks at exactly the moment the
	## deck is busiest — which is the moment it is the only thing telling the
	## player where a boarder is about to be. Its prefix is quoted in
	## `tools/rune_read.gd`, and a harness check holds the two spellings together.
	## `tf` (the strike flash) and `tp` (the punish window) joined them with
	## SG-158, and they spend the telegraph budget for the same reason the landing
	## ring does: they are the two beats of a melee exchange the deck used to
	## leave unlit, and being evicted by scorch marks at the busiest moment is
	## exactly when they are the only thing saying he is open.
	## `ts` joined them with SG-166 — the Colossus's stomp: the held outline, the
	## closing ring and the flash that lands on it. It is a TELEGRAPH for the same
	## reason the rest are: it is the only thing on the deck saying that a circle
	## 240 units wide is about to hurt, and being evicted by scorch marks at the
	## busiest moment of the busiest wave is precisely when it must not be.
	if key.begins_with("tg") or key.begins_with("tr") or key.begins_with("tn") \
			or key.begins_with("tar") or key.begins_with("tf") \
			or key.begins_with("tp") or key.begins_with("ts"):
		return DecalClass.TELEGRAPH
	if key.begins_with("fx") or key.begins_with("aura") or key.begins_with("boiler"):
		return DecalClass.PLAYER
	return DecalClass.DECOR


func _decal(key: String, centre: Vector2, angle: float, sx: float, sy: float,
		texture: Texture2D, colour: Color, glowing: bool = true) -> void:
	## An existing decal keeps its slot; only a NEW one has to find budget, or a
	## long-lived aura would be evicted by its own next frame.
	if not _decals.has(key):
		var group := _decal_class(key)
		if _decal_live[group] >= int(DECAL_BUDGET[group]):
			return
		_decal_live[group] += 1
	_decals_used[key] = true
	var node: Decal = _decals.get(key)
	if node == null:
		if not _free_decals.is_empty():
			node = _free_decals.pop_back()
			node.visible = true
		else:
			node = Decal.new()
			node.cull_mask = 0xFFFFF & ~LAYER_FIGURES & ~LAYER_SHADOWS
			node.upper_fade = 0.1
			node.lower_fade = 0.1
			node.normal_fade = 0.0
			add_child(node)
		_decals[key] = node
		_peak_decals = maxi(_peak_decals, _decals.size())
	node.texture_albedo = texture
	node.modulate = Color(colour.r, colour.g, colour.b, 1.0)
	## Emission through a PREMULTIPLIED map, never through the albedo texture.
	## A Decal's emission channel ignores the texture's alpha and lights the
	## whole projection box, so feeding it the ring — white RGB, shaped alpha —
	## painted a solid glowing rectangle the size of the effect's bounding box
	## over the deck, the crates and the fight. Baking alpha into RGB makes the
	## hollow parts black, and black emits nothing.
	if glowing:
		node.texture_emission = _glow_map(texture)
		node.emission_energy = 0.85 * colour.a
	else:
		node.texture_emission = null
		node.emission_energy = 0.0
	node.albedo_mix = colour.a
	## The projection box. Tall enough to reach the top of a cargo run from above
	## so an effect that touches one climbs it, and to reach the deck from a metre
	## up so nothing falls short.
	var basis := Basis(Vector3(cos(angle), 0.0, sin(angle)), Vector3(0.0, 1.0, 0.0),
		Vector3(-sin(angle), 0.0, cos(angle)))
	node.transform = Transform3D(basis, Vector3(centre.x * WORLD_SCALE,
		90.0 * WORLD_SCALE, centre.y * WORLD_SCALE))
	node.size = Vector3(sx, 260.0, sy) * WORLD_SCALE


## Contact shadows, all of them, in one draw.
##
## Every figure, prop, cannon, crewman, projectile and pickup on the deck had its
## own `Decal` for the blob underneath it — about seventy clustered decals at
## bench load before a single telegraph or effect, and the largest remaining GPU
## item in the scene. They are all the same quad, the same texture and the same
## flat orientation, which is exactly what a MultiMesh is for.
##
## Written from scratch each frame rather than diffed: there is no persistent
## identity to preserve, the count is small, and a rebuild cannot leak a stale
## shadow under something that has died.
const SHADOW_CAP := 256

## `depth` defaults to zero meaning "the figure squash", which is what every
## caller but the segmented one wants.
const SHADOW_SQUASH := 0.62

## --- ONE SHADOW AUTHORITY -----------------------------------------------------
##
## DECK-IDENTITY item 2. Three things were true in the shipped build and together
## they made a bug the owner reported as an aesthetic: `_flush_shadows` built
## `Basis().scaled(...)` — a scale, with NO LIGHT TERM IN IT AT ALL; every rigged
## figure's mesh casts a real moon shadow (a `MeshInstance3D` casts by default and
## `rig3d.gd:286` sets it explicitly on the weapon); and the moon throws that real
## shadow 0.437 of a height to port and 0.647 toward the bow. So a boarder carried
## TWO shadows pointing in different directions, and the one the eye goes to was
## the sticker. A shell two hundred units up dragged a hard disc across the boards
## as if it were lying on them.
##
## The fix is not a second number. It is that there is ONE light in this scene and
## exactly one place is allowed to say where it points: `_moon`'s own basis, read
## live in `_flush_shadows` and never retyped. Two functions disagreeing about one
## number is this project's second failure mode, and the whole reason this item
## exists is that it had already happened here.
##
## THE TWO RULES THAT ARE NOT NEGOTIABLE, each pinned by its own check:
##
##   * **A projectile's mark is never thrown.** It scales with height and it
##     stays directly beneath the thing — DESIGN §13c and the audit both say the
##     mark under a bolt is what tells you where it will cross you. Lean it and
##     the mark stops answering the only question it is asked. Height scaling
##     applies; the offset does not.
##   * **Nothing carries a cast shadow AND a full-strength blob.** Where a mesh
##     already casts, the blob drops to a tight contact core — the dark under the
##     feet that a shadow map at this distance cannot resolve — instead of a
##     second full ellipse pointing somewhere else.
##
## `SHADOW_CAP` stays 256, one MultiMesh, one material, one draw call.
enum {
	## The ordinary mark: leans along the moon, elongates, offsets with height.
	SHADOW_LEANS,
	## A projectile. Height scales it; the lean does not touch it.
	SHADOW_CENTRED,
	## A mesh already casts here. A contact core, not a second shadow.
	SHADOW_CORE,
}

## How far up something has to be for its mark to double in width, and to fade to
## half. A shell is a few hundred units up at the top of its arc; a bobbing
## pickup is nine. These are the numbers that make "in the air" read as a
## DIFFERENT thing rather than as a slightly bigger circle.
const SHADOW_LIFT_SPREAD := 300.0
const SHADOW_LIFT_FADE := 220.0
## What a contact core keeps of the blob it replaces. Small enough that the mesh's
## own cast shadow is the shape you read, dark enough that the feet are joined to
## the planking — a shadow map at 34 m over a whole deck cannot resolve the inch
## under a boot, which is the one place the eye checks.
const SHADOW_CORE_WIDTH := 0.42
const SHADOW_CORE_ALPHA := 0.62

## How many marks the batch drew last frame, and how many of them were contact
## cores. Functions rather than raw arrays so the harness and the probes never
## have to reach into the pool — the same rule `mark_count()` follows.
func multimesh_shadow_count() -> int:
	if _shadow_batch == null:
		return 0
	return (_shadow_batch.multimesh as MultiMesh).visible_instance_count


func shadow_core_count() -> int:
	return _shadow_cores_last


## DOES THE MOON ALREADY DRAW THIS ONE? Asked of the built tree rather than of a
## list of model keys, because a list of model keys is the thing that goes stale
## the afternoon somebody adds a figure — and the failure would be silent and
## would look exactly like the bug this item is fixing. A rigged figure is a mesh
## and a mesh casts unless somebody turned it off; a painted billboard is a
## `Sprite3D` with `SHADOW_CASTING_SETTING_OFF` and has nothing but its blob.
func _casts_own_shadow(key: String) -> bool:
	var rig: SkyGearRig3D = _captain if key == "player" else _rigs.get(key)
	if rig == null or not is_instance_valid(rig) or not rig.visible:
		return false
	for child in rig.find_children("*", "MeshInstance3D", true, false):
		if (child as MeshInstance3D).cast_shadow \
				!= GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return true
	return false


func _shadow(_key: String, centre: Vector2, width: float, alpha: float,
		depth: float = 0.0, height: float = 0.0, kind: int = SHADOW_LEANS) -> void:
	if _shadow_count >= SHADOW_CAP:
		return
	## A MARK WITH HEIGHT UNDER IT IS NEVER A CONTACT CORE, and this is the rule
	## the arrival drop needed and could not have got at its own call site.
	##
	## `SHADOW_CORE` means "a mesh is already casting here, so this blob is only
	## the inch under a boot the shadow map cannot resolve" — and that sentence is
	## true of a figure STANDING and false of one in the air. There is no inch
	## under the boot; there is 300 units of nothing, the cast shadow has been
	## suppressed precisely so it does not draw a second wrong mark, and the blob
	## is the ONLY thing telling the player where the figure is going to be. The
	## old behaviour shrank it to 42% and faded it to 62% at exactly that moment.
	##
	## Resolved HERE rather than in the enemy sync because it is a property of
	## marks, not of boarders: every caller inherits it, including the hovering
	## GUNNER and every corpse `corpse_drop` lifts, the day either of those starts
	## passing a lift (neither does today — see the note on `_sync_all`).
	##
	## ONLY THE CORE. `SHADOW_CENTRED` is a projectile and is left alone: RULE ONE
	## says a bolt's mark stays directly beneath it however high it is, and a
	## height test that swept that case up would have thrown every shell's mark
	## down the moonlight — the marks are already lifted today, so this would have
	## shipped as a live bug rather than as a dormant one.
	if kind == SHADOW_CORE and height > 0.0:
		kind = SHADOW_LEANS
	## The core shrink happens here rather than at flush, so legacy has to be
	## honoured here too — otherwise "today's ellipse" would come back with
	## today's geometry and this item's footprint, which is neither build.
	if kind == SHADOW_CORE and not shadow_legacy:
		width *= SHADOW_CORE_WIDTH
		alpha *= SHADOW_CORE_ALPHA
		depth *= SHADOW_CORE_WIDTH
		_shadow_cores += 1
	_shadow_at[_shadow_count] = centre
	_shadow_size[_shadow_count] = width
	_shadow_depth[_shadow_count] = depth if depth > 0.0 else width * SHADOW_SQUASH
	_shadow_alpha[_shadow_count] = alpha
	_shadow_lift[_shadow_count] = maxf(0.0, height)
	_shadow_kind[_shadow_count] = kind
	_shadow_count += 1


func _build_shadows() -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	## Flat on the deck. Lying down is the quad's own orientation, not a
	## per-instance rotation, so every instance transform is a scale and an
	## offset and nothing more.
	mesh.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = _art("blob", _blob_texture())
	## The alpha rides on the instance colour, which is the whole reason this can
	## be one draw: a fading shadow needs no material of its own.
	mat.vertex_color_use_as_albedo = true
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.no_depth_test = false
	_shadow_batch = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = SHADOW_CAP
	mm.visible_instance_count = 0
	_shadow_batch.multimesh = mm
	_shadow_batch.material_override = mat
	_shadow_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow_batch.layers = LAYER_SHADOWS
	## The deck is 16.8 x 23.2 metres; without an explicit box the batch is culled
	## whenever its origin leaves the frustum and every shadow blinks out.
	_shadow_batch.custom_aabb = AABB(Vector3(-12, -1, -14), Vector3(24, 2, 28))
	add_child(_shadow_batch)


## THE ONE LIGHT VECTOR, READ AND NOT RETYPED. A `DirectionalLight3D` shines down
## its own -Z, so this is the direction the light TRAVELS. Every number in the
## mark's pose falls out of it: nothing restates -0.344 / -0.788 / -0.510, and if
## somebody re-aims the moon tomorrow every mark on the deck turns with it in the
## same frame. That is the whole item — the renderer and the light can no longer
## hold different opinions about where the light comes from.
func moon_track() -> Vector3:
	return -_moon.global_transform.basis.z if _moon != null \
		else Vector3(-0.344, -0.788, -0.510)


## WHERE ONE MARK GOES, as arithmetic rather than as a side effect on a GPU
## buffer. `_flush_shadows` calls this and so does the harness, which is not a
## convenience: a `MultiMesh`'s instance buffer lives on the rendering server and
## does NOT read back under `--headless`, so a check that asserted on
## `get_instance_transform` asserted on an identity matrix and passed whatever it
## was given. One function, two callers, and the thing being checked is the thing
## being drawn.
func shadow_pose(centre: Vector2, width: float, depth: float, lift: float,
		kind: int) -> Transform3D:
	if shadow_legacy:
		lift = 0.0
		kind = SHADOW_CENTRED
	var dir := moon_track()
	## How far a mark slides per unit of height, and how much it stretches. Both
	## are the same triangle: `down` is sin(elevation), so `1/down` is the
	## elongation of a circle cast onto a floor at that angle, and `flat/down` is
	## the ground travel per unit of height.
	var down: float = maxf(0.05, -dir.y)
	var flat := Vector2(dir.x, dir.z)
	## HEIGHT. A thing in the air and the spot it will land on stop being the same
	## pixel: the mark widens, softens and — unless it is a projectile — slides
	## down the light. A readability gain, not decoration.
	var spread: float = 1.0 + lift / SHADOW_LIFT_SPREAD
	var at := centre
	## RULE ONE. A projectile keeps its mark directly beneath itself. The mark
	## under a bolt is what tells you where it will cross you, so it may grow and
	## it may fade but it is NEVER thrown (DESIGN §13c).
	if kind != SHADOW_CENTRED:
		at += (flat / down) * lift
	var w: float = width * spread * WORLD_SCALE
	var d: float = depth * spread * WORLD_SCALE
	var basis: Basis
	if kind == SHADOW_CENTRED:
		## A centred mark has no lean to elongate along — it is a circle under a
		## thing seen from above, and stretching it would be a direction it does
		## not have.
		basis = Basis().scaled(Vector3(w, 1.0, d))
	else:
		## The mark's LONG axis is the one that lies along the light. The quad is
		## FACE_Y with its width on local X, so aligning X to the ground track of
		## the light is what makes every mark on this deck lean the same way.
		basis = Basis(Vector3.UP, atan2(flat.x, flat.y)) \
			* Basis().scaled(Vector3(w / down, 1.0, d))
	return Transform3D(basis, Vector3(at.x * WORLD_SCALE, 2.0 * WORLD_SCALE,
		at.y * WORLD_SCALE))


## And how dark it is at that height. Same reason it is a function.
func shadow_alpha(alpha: float, lift: float) -> float:
	if shadow_legacy:
		return alpha
	return alpha / (1.0 + maxf(0.0, lift) / SHADOW_LIFT_FADE)


func _flush_shadows() -> void:
	if _shadow_batch == null:
		return
	var mm: MultiMesh = _shadow_batch.multimesh
	for i in _shadow_count:
		mm.set_instance_transform(i, shadow_pose(_shadow_at[i], _shadow_size[i],
			_shadow_depth[i], _shadow_lift[i], _shadow_kind[i]))
		mm.set_instance_color(i, Color(0.02, 0.015, 0.03,
			shadow_alpha(_shadow_alpha[i], _shadow_lift[i])))
	mm.visible_instance_count = _shadow_count
	_shadow_count = 0
	_shadow_cores_last = _shadow_cores
	_shadow_cores = 0


## --- A HULL SHAPE AROUND A RECTANGLE ------------------------------------------
##
## DECK-IDENTITY-DESIGN §6. The whole item rests on one decoupling: the shape the
## player COLLIDES with and the shape the player SEES have never been required to
## agree. `DECK_RECT` is a number in game.gd; the ship is a pile of meshes here.
##
## So the sim keeps its measured 1680 x 2320 rectangle — the lanes at +/-560, the
## eight cargo rects, the crossings, the spawn line at y = -1115, every pinned
## check — and the DRAWN deck gets a sheer that curves, a bow that narrows to a
## stem and a stern nobody walks on.
##
## TWO PROPERTIES, and they are properties of the construction rather than
## promises about it:
##
##   1. **The drawn deck is a strict SUPERSET.** Every piece below is outboard:
##      |x| >= 840, or z <= -1160, or z >= 1160. The bow taper BEGINS at the bow
##      line at full beam and narrows only forward of it. There is nowhere she
##      can stand that is not drawn. `hull · ...` pins it with an AABB assert.
##   2. **None of it carries collision.** MeshInstance3D and nothing else — no
##      body, no `CARGO_RECTS` entry, no `fitting_walls` entry, no `hulk_hull`.
##      Drawn geometry cannot stop her because there is nothing to stop her with.
##
## We err toward *drawn where she cannot stand*, never *standable where nothing
## is drawn*. A player who finds a foot of bulwark she cannot step onto has
## learned something true about a ship; a player who stops in empty air has found
## a bug.
##
## THE ONE THING THAT MOVED IN MEANING, not in geometry: the gunwale's two end
## caps at z = +/-1160 are untouched, and now read as a breast rail dividing the
## working deck from the head and the counter beyond. That is a real ship
## feature, and it happens to draw the play boundary in brass.
## 96, not the 150 DECK-DESIGN P3 proposed, and the reason is a picture. At 150
## the two bulwarks converging on the bow line filled the top of the frame with a
## dark wall from the captain's own eye-line — which is the SAME fault the
## painted `bow_prow.png` was retired for on the same afternoon, rebuilt in
## timber. `.shots/marks/clean-bow-z1.00.png` is the shot that said so.
##
## The measurement behind the number was already written down: DECK-DESIGN §1
## puts the vertical budget at the bow line at 65 units at zoom 1.0. 96 is over
## that and deliberately so, because the bulwark is at the frame's EDGES rather
## than at the captain's depth — but 150 was over it by more than a captain, and
## a bow you look along should read as depth, not as a fence. P3's own written
## fallback was to cap the forward lift; this is that, taken.
##
## It also clears P3's other trap for free: boarders spawn at y = -1115, 45 units
## inside the bow line, and 96 is well under the 110 P3 named as the safe cap.
const SHEER_BOW := 96.0         ## peak lift forward, at the bow line
const SHEER_STERN := 90.0       ## and aft
const SHEER_BASE := 30.0        ## the strake's own depth below the lift

## THE LAMPLIT CEILING, AND THE PROCEDURAL DECK HAD NEVER HEARD OF IT (SG-179).
##
## `tools/lamplit.py` owns this number and clamps every shipped MODEL to it — all
## 17 that were over, on the owner's verdict of 2026-08-03. But that audit walks
## `assets/models/*.glb` and nothing else, so the deck's own procedurally-built
## boxes were never in it. The gunwale end caps and the sheer strake's brass
## capping both shipped at `metallic = 0.4`, ABOVE the ceiling every model on the
## deck had just been brought under — which is part of why the owner reported
## them as reading like placeholder plastic against the textured pieces.
##
## Restated here rather than imported because a GDScript cannot read a Python
## module, and held to that source by the harness check
## `deck · the procedural deck obeys the same lamplit ceiling the models do`,
## which parses the number out of `tools/lamplit.py` and fails if the two drift.
## Same thread that holds `rune_read`'s prefixes to `_decal_class`.
const LAMPLIT_METALLIC_MAX := 0.34
const SHEER_WIDTH := 58.0       ## outboard of the deck edge, never inboard
const SHEER_SEGMENTS := 20
const BOW_LENGTH := 620.0       ## how far forward of the bow line the stem is
const BOW_SEGMENTS := 10
const STERN_LENGTH := 380.0
const STERN_SEGMENTS := 6
## The transom keeps half its beam rather than coming to a point: a ship with two
## bows is a canoe.
const STERN_BEAM := 0.52

var _hull_shape: Node3D
## The masts, yards and shrouds. Never drawn — see `_build_rigging`.
var _rigging: Node3D


## The sheer line, as one function of depth, because a curve retyped in two
## places is two curves. `z` in ground units; returns lift above the deck.
##
## Zero amidships, 150 at the bow, 90 at the stern, and the exponents are what
## make it a sheer rather than a parabola — steeper forward, which is how a hull
## is actually drawn. DECK-DESIGN P3 measured these.
static func sheer_lift(z: float) -> float:
	var rect: Rect2 = SkyGearGame.DECK_RECT
	var t: float = clampf((z - rect.position.y) / rect.size.y, 0.0, 1.0)
	return SHEER_BOW * pow(1.0 - t, 2.2) + SHEER_STERN * pow(t, 2.6)


## How wide the drawn deck is, as a fraction of full beam, at a depth `z`.
##
## **1.0 everywhere inside the rectangle.** That is the superset property written
## as a function: the taper cannot start early because the argument is clamped
## against the rectangle's own ends before it is used.
static func hull_beam(z: float) -> float:
	var rect: Rect2 = SkyGearGame.DECK_RECT
	if z >= rect.position.y and z <= rect.end.y:
		return 1.0
	if z < rect.position.y:
		var t: float = clampf((rect.position.y - z) / BOW_LENGTH, 0.0, 1.0)
		## A fine entry: it leaves the bow line gently and sharpens to the stem.
		## Exponent > 1 on purpose — a taper that starts fast puts a hard corner
		## exactly at the seam, which is the one place it must not be visible.
		return 1.0 - pow(t, 1.6)
	var s: float = clampf((z - rect.end.y) / STERN_LENGTH, 0.0, 1.0)
	return 1.0 - (1.0 - STERN_BEAM) * pow(s, 1.35)


## --- THE RIG OVERHEAD, AS SHADOW ONLY -----------------------------------------
##
## DECK-IDENTITY-DESIGN item 1, and it is the top-ranked item there for one
## reason: DECK-DESIGN §1 measured that 94% of the default frame is planking and
## the near two thirds carries no ship's edge at all. The rail, the sheer and the
## bow all live at the EDGE of the frame. This is the only cue that reaches the
## middle of it.
##
## VISIBLE RIGGING WAS TRIED TWICE AND FAILED TWICE, with pictures:
## `.shots/deck/rig-mid-z1.00.png` and `rig2-mid-z1.55.png`. At the captain's own
## depth the frame is 490 ground units wide, so a 10 cm rope four metres from the
## lens is a 30-pixel bar with the captain behind it. `SHADOWS_ONLY` is the only
## version that works, and it works BY CONSTRUCTION rather than by taste: Godot
## renders these into the moon's shadow atlas and into no other pass, so there
## are zero pixels of geometry available to occlude anybody.
##
## THE TRICK IS THE LIGHT ANGLE. The moon sits at rotation (-52, 34, 0), a
## direction of (-0.344, -0.788, -0.510), so every shadow lands 0.437 of its
## caster's height to PORT and 0.647 of it toward the BOW. A 1500-unit mast at
## z = +900 is aft of the camera and never in shot, and prints its rig from there
## to z = -70 — straight across the middle of the deck. The caster lives where
## the camera cannot go; the shadow lives where the player is looking all run.
##
## TWO TRAPS, both written down in DECK-DESIGN P2 before a line was built:
##
##   1. `directional_shadow_max_distance` is 34.0 m and was deliberately
##      tightened to "the deck plus a margin". A mast placed further aft SILENTLY
##      stops casting — no error, no warning, just a deck that goes blank. Pinned
##      by `rig · every caster is inside the moon's 34 m shadow distance`, which
##      measures the far corner of each caster's own AABB rather than trusting
##      the table.
##   2. `shadow_blur` is 2.2, which smears a 4-unit shroud into a broad band that
##      reads as LIGHTING rather than as rope. P2 said try 8-10 first. The
##      prototype in `deck_probe.gd:_build_rig2` is at 4 and reads as haze; this
##      ships at 9. The shrouds cost nothing to thicken — they are never drawn.
##
## The masts stand on the LANE DIVIDERS, not in a lane, so that if any of them is
## ever promoted to visible geometry it still is not standing where somebody
## fights. Authored rows, never a seeded roll — the same rule the cloud field
## keeps, and the reason the checks below can be checks at all.
const RIG_MASTS := [
	{"x": 280.0, "z": 900.0, "h": 1500.0},
	{"x": -280.0, "z": 260.0, "h": 1500.0},
	{"x": 280.0, "z": -560.0, "h": 1500.0},
]
## Trap 2. Not 4.
const RIG_SHROUD_RADIUS := 9.0
const RIG_YARD_AT := 0.74            ## of mast height
const RIG_SHROUD_HEAD := 0.82        ## of mast height


## ON, BY THE OWNER'S EYE, 2026-08-03 — and against this file's own advice.
##
## `tools/edge_place.gd -- mast` swapped the procedural casters for
## `mast_crowned` to answer whether the owner's mast should REPLACE them, FEED
## them, or stand beside them. The measured read was to keep the procedural
## ones: side by side at the shipped camera
## (`.shots/owner-review/1-bow-stern-mast/mast-mid__*.png`) the procedural
## shrouds throw CRISP DIAGONAL LINES across the planking and `mast_crowned`
## throws soft broad blobs, so the lattice is lost and the deck reads darker.
##
## The owner looked at exactly that pair and said **"Model shadows look cooler
## in my opinion."** That is the whole argument and it beats the analysis: this
## is a look, the look is his, and "the lines are crisper" is a measurement of
## a thing nobody asked to maximise. REPLACE, then — the procedural casters are
## off when this is on, they do not stack.
##
## What this does NOT do is put the mast on screen. The three stations sit at
## x +/-280, inside the lane figures fight in, so the mesh stays SHADOWS_ONLY
## through `_rig_piece`; what changed is only what shape the moon throws.
var rig_model_masts := true


func _build_rigging() -> void:
	_rigging = Node3D.new()
	_rigging.name = "Rigging"
	add_child(_rigging)

	if rig_model_masts:
		_build_rigging_from_model()
		return

	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color("#41301d")
	timber.roughness = 0.86
	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color("#6a5738")
	rope.roughness = 0.95

	for m in RIG_MASTS:
		var h: float = float(m.h)
		var mx: float = float(m.x)
		var mz: float = float(m.z)

		var mast := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 13.0 * WORLD_SCALE
		cm.bottom_radius = 26.0 * WORLD_SCALE
		cm.height = h * WORLD_SCALE
		cm.radial_segments = 8
		mast.mesh = cm
		mast.material_override = timber
		mast.position = Vector3(mx * WORLD_SCALE, h * 0.5 * WORLD_SCALE,
			mz * WORLD_SCALE)
		_rig_piece(mast)

		var yard := MeshInstance3D.new()
		var ym := CylinderMesh.new()
		ym.top_radius = 10.0 * WORLD_SCALE
		ym.bottom_radius = 10.0 * WORLD_SCALE
		ym.height = 1150.0 * WORLD_SCALE
		ym.radial_segments = 6
		yard.mesh = ym
		yard.material_override = timber
		yard.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		yard.position = Vector3(mx * WORLD_SCALE, h * RIG_YARD_AT * WORLD_SCALE,
			mz * WORLD_SCALE)
		_rig_piece(yard)

		## Six shrouds a mast, three a side, feet spread 300 / 490 / 680 and
		## staggered fore-and-aft so the lattice lands DIAGONAL across the
		## planking. That is deliberate: every telegraph in this game is a circle,
		## a cone or a lane-aligned strip, so a diagonal lattice shares no
		## direction with any of them and cannot be mistaken for one.
		var head := Vector3(mx * WORLD_SCALE, h * RIG_SHROUD_HEAD * WORLD_SCALE,
			mz * WORLD_SCALE)
		for dx in [-1.0, 1.0]:
			for i in 3:
				var spread: float = 300.0 + float(i) * 190.0
				var foot := Vector3((mx + dx * spread) * WORLD_SCALE,
					40.0 * WORLD_SCALE, (mz + (float(i) - 1.0) * 150.0) * WORLD_SCALE)
				var line := MeshInstance3D.new()
				var lm := CylinderMesh.new()
				lm.top_radius = RIG_SHROUD_RADIUS * WORLD_SCALE
				lm.bottom_radius = RIG_SHROUD_RADIUS * WORLD_SCALE
				lm.height = foot.distance_to(head)
				lm.radial_segments = 4
				line.mesh = lm
				line.material_override = rope
				var mid := (foot + head) * 0.5
				line.position = mid
				line.look_at_from_position(mid, head, Vector3.RIGHT)
				line.rotate_object_local(Vector3.RIGHT, PI * 0.5)
				_rig_piece(line)


## `mast_crowned` in the caster's place, at the same three stations and the same
## 1500-unit height, every mesh in it forced SHADOWS_ONLY through `_rig_piece`.
func _build_rigging_from_model() -> void:
	var scene: PackedScene = load("res://assets/models/mast_crowned/mast_crowned.tscn")
	if scene == null:
		return
	for m in RIG_MASTS:
		var h: float = float(m.h)
		## The model is 189.9 ground units tall; scale it to the station height.
		var k: float = h / 189.9
		var node: Node3D = scene.instantiate()
		node.transform = Transform3D(Basis().scaled(Vector3(k, k, k)),
			Vector3(float(m.x), 0.0, float(m.z)) * WORLD_SCALE)
		_rigging.add_child(node)
		var stack: Array = [node]
		while not stack.is_empty():
			var n = stack.pop_back()
			for c in n.get_children(): stack.append(c)
			if n is MeshInstance3D:
				n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
				n.layers = LAYER_WORLD


## ONE PLACE SETS THE ENUM. A piece of rig that arrived with the default
## `SHADOW_CASTING_SETTING_ON` would be a 30-pixel bar across the lane — the
## exact failure the shadows-only version exists to avoid — so the enum is not
## written at eleven call sites where the twelfth can be forgotten. Pinned by
## `rig · nothing in the rig is in the colour pass`, which walks the built tree.
func _rig_piece(node: MeshInstance3D) -> void:
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	node.layers = LAYER_WORLD
	_rigging.add_child(node)


## --- THE DECK EDGE, TRIED THREE WAYS (SG-180) ---------------------------------
##
## The owner on build 60: *"We need to either REMOVE the 'wall' made up of that
## lightish brown/yellow rectangular prisms or TEXTURE them, they look out of
## place against our other models and seem very placeholder."* SG-179 took the
## cheap half of "texture" — retint, roughen, clamp to the lamplit ceiling — and
## it helped without solving it: they are still flat colour beside models that
## carry four maps each.
##
## His second suggestion is what these switches exist to photograph: *"try
## reusing the rail at low profile."* `rail_stanchion` is his own hand-made
## tiling module, already on the deck edge at N = 10 (SG-157) and already reused
## on the upper deck (SG-178). This puts a SHORTER run of it where the brass
## capping is, and it also builds the state he named FIRST — the capping simply
## deleted, leaving the dark timber strake to read on its own.
##
## OWNER VERDICT, 2026-08-04 (SG-200): ship the modular breast rails and delete
## the strake capping. The other states stay available to the comparison tool,
## but 2/1 is the only startup path and the deck check pins its built geometry.
##
##   0  the legacy SG-179 brass capping / flat breast rail
##   1  the owner's rail module, at low profile, in its place
##   2  deleted (strake capping only — the END CAPS may be restyled but never
##      removed: DECK-IDENTITY 6 gives them a job, drawing the play boundary,
##      and there is no mode 2 for them on purpose)
var strake_cap_mode := 2
var end_cap_mode := 1

## THE LOW RUN'S SCALE IS THE SHIPPED RAIL'S, DIVIDED BY AN INTEGER, AND THE
## INTEGER IS THE WHOLE DESIGN.
##
## Two rails whose posts do not line up read as a mistake even when each is fine
## alone, so the pitch is not a free number here. The low run is tiled at
## `edge_rail_tiles * div` tiles across the same deck, which makes its pitch
## exactly `1/div` of the shipped run's — so every stanchion of the main rail has
## a stanchion of the low one directly under it, at every seam, for any `div`.
## The scale follows from the tiling the same way `edge_rail_scale()` does, so
## the two runs cannot drift apart: change `edge_rail_tiles` and both move.
##
##   div = 2   pitch  58.0   low rail top 62.6 above the strake  (half the main)
##   div = 3   pitch  38.7   low rail top 41.8                   (a third)
##   div = 4   pitch  29.0   low rail top 31.3                   (a quarter)
var strake_cap_rail_div := 2
## And the one dial that DECOUPLES height from pitch, because the brief asked
## whether the pitch should match/double/halve independently of how tall the low
## run is: 0 means uniform (the honest 1/div in all three axes), anything else is
## the vertical scale as a fraction of the SHIPPED rail's height, which squashes
## the module rather than shrinking it.
var strake_cap_rail_height := 0.0

## The breast rails at the bow and stern lines, and the material `_ready` built
## for them. Held so `rebuild_deck_edge()` can put them back in another state
## without re-running `_ready`; the material is the SAME instance the shipped
## deck uses, never a second copy of #7c5a2c that could drift from it.
var _end_caps: Array[Node3D] = []
var _end_cap_mat: StandardMaterial3D


## THE BREAST RAIL AT EACH END OF THE RECTANGLE — the play boundary, drawn.
##
## Mode 1 is the owner-approved shipping state (SG-200): his rail module laid
## ACROSS the ship, unrotated — the module's +X is its length, so an
## athwartships run needs no yaw at all, where the deck-edge run needs -90°.
## Mode 0 keeps SG-179's flat box only for the recorded comparison.
##
## The count is the nearest whole number of modules that spans the beam and the
## scale is then solved to make that count fit EXACTLY, so the run ends on the
## strake lines at both ends and the boundary is drawn all the way across. It is
## derived from `edge_rail_scale()` — never typed — so it tracks the shipped rail.
func _build_end_caps() -> void:
	for old in _end_caps:
		if is_instance_valid(old):
			remove_child(old)
			old.queue_free()
	_end_caps.clear()
	var rect: Rect2 = SkyGearGame.DECK_RECT
	var mid_x: float = rect.position.x + rect.size.x * 0.5
	for i in 2:
		var end_z: float = rect.position.y if i == 0 else rect.end.y
		var label: String = "BreastRailFore" if i == 0 else "BreastRailAft"
		if end_cap_mode == 0:
			var cap := MeshInstance3D.new()
			var cm := BoxMesh.new()
			cm.size = Vector3(rect.size.x, 40.0, 14.0) * WORLD_SCALE
			cap.mesh = cm
			cap.material_override = _end_cap_mat
			cap.position = Vector3(mid_x * WORLD_SCALE, 20.0 * WORLD_SCALE,
				end_z * WORLD_SCALE)
			cap.name = label
			add_child(cap)
			_end_caps.append(cap)
			continue
		var scene: PackedScene = load(EDGE_RAIL_SCENE)
		if scene == null:
			push_warning("edge kit: no rail module at %s" % EDGE_RAIL_SCENE)
			return
		var run := Node3D.new()
		run.name = label
		add_child(run)
		_end_caps.append(run)
		var want: float = 2.0 * RAIL_PITCH_NATIVE * edge_rail_scale() \
			/ float(strake_cap_rail_div)
		var count: int = maxi(1, int(round(rect.size.x / want)))
		var s: float = rect.size.x / (float(count) * 2.0 * RAIL_PITCH_NATIVE)
		var s_y: float = s if strake_cap_rail_height <= 0.0 \
			else edge_rail_scale() * strake_cap_rail_height
		for k in count:
			var node: Node3D = scene.instantiate()
			## Unrotated here, so this vector IS the model's own order: length
			## across the beam, height, depth fore-and-aft — and the depth takes
			## the height factor for the same reason the strake run's does.
			node.transform = Transform3D(
				Basis().scaled(Vector3(s, s_y, s_y)),
				Vector3(rect.position.x + rect.size.x * (float(k) + 0.5) / float(count),
					0.0, end_z) * WORLD_SCALE)
			node.name = "%sModule%d" % [label, k]
			run.add_child(node)


## Put the deck edge back in another state without re-running `_ready`.
##
## The capping is built by `_build_hull_shape` and the low run by the EDGE KIT,
## which are two different nodes with two different lifetimes — so a tool that
## flipped `strake_cap_mode` and called `rebuild_edge_kit()` alone would get a
## low rail standing on a capping that is still there. This is the one entry
## point, and `tools/edge_place.gd` uses nothing else.
func rebuild_deck_edge() -> void:
	if _hull_shape != null:
		remove_child(_hull_shape)
		_hull_shape.queue_free()
		_hull_shape = null
	_build_hull_shape()
	rebuild_edge_kit(edge_rail_tiles)
	_build_end_caps()


func _build_hull_shape() -> void:
	var rect: Rect2 = SkyGearGame.DECK_RECT
	var half: float = rect.size.x * 0.5
	_hull_shape = Node3D.new()
	_hull_shape.name = "HullShape"
	add_child(_hull_shape)

	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color("#3a2b22")
	timber.roughness = 0.88
	## The capping along the top of the strake, in the gunwale's own brass so the
	## new edge and the old one are visibly the same ship.
	## Darkened and taken under the lamplit ceiling with the breast rail above
	## (SG-179). This capping runs the whole length of both deck edges — forty
	## boxes — so it is the largest untextured surface in the frame and it was
	## the loudest of the two.
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("#674c26")
	brass.roughness = 0.80
	brass.metallic = LAMPLIT_METALLIC_MAX

	## a · THE SHEER STRAKE. Twenty boxes a side straddling the deck edge, inner
	## face exactly on |x| = 840 and every millimetre of the rest of it OUTBOARD.
	## The top edge rides `sheer_lift`, so amidships it hides under the existing
	## gunwale and it grows fore and aft. That growth IS the curve.
	for side in [-1.0, 1.0]:
		for i in SHEER_SEGMENTS:
			var z0: float = rect.position.y + rect.size.y * (float(i) / SHEER_SEGMENTS)
			var z1: float = rect.position.y + rect.size.y * (float(i + 1) / SHEER_SEGMENTS)
			var lift := sheer_lift((z0 + z1) * 0.5)
			_strake_box(timber, brass, side * (half + SHEER_WIDTH * 0.5),
				(z0 + z1) * 0.5, SHEER_WIDTH, z1 - z0, lift, 0.0)

	## b · THE BOW. An apron of real planking carrying the deck forward of the bow
	## line and narrowing to a stem, with the strake following it in. The taper is
	## in the deck PLANE, which is the only place there is any budget for it: the
	## vertical headroom at the bow is 65 units at zoom 1.0 (DECK-DESIGN §1), and
	## that is exactly why `bow_prow.png` reads as a wall instead of a prow.
	_hull_apron(rect.position.y, -BOW_LENGTH, BOW_SEGMENTS, timber, brass)
	## c · THE STERN. Cheapest of the three — the aft half is off screen unless
	## the captain walks into it — and it is here because a ship with a bow and no
	## stern is a wedge.
	_hull_apron(rect.end.y, STERN_LENGTH, STERN_SEGMENTS, timber, brass)


## One box of sheer strake, plus its brass capping. `yaw` swings it to follow the
## bow taper; zero along the straight sides.
func _strake_box(timber: StandardMaterial3D, brass: StandardMaterial3D,
		x: float, z: float, width: float, length: float, lift: float,
		yaw: float) -> void:
	var height: float = SHEER_BASE + lift
	var strip := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, height, length) * WORLD_SCALE
	strip.mesh = bm
	strip.material_override = timber
	## Hung so the top edge sits at `lift - 8`: flush under the existing 40-unit
	## gunwale amidships, rising clear of it toward both ends.
	strip.position = Vector3(x * WORLD_SCALE,
		(lift - 8.0 - height * 0.5) * WORLD_SCALE, z * WORLD_SCALE)
	strip.rotation.y = yaw
	_hull_shape.add_child(strip)
	if lift < 12.0:
		return
	## SG-180. Both nonzero states drop the brass box: mode 1 puts the low
	## rail run in its place along the RECTANGLE (`_build_strake_rail`, in the
	## edge kit, where the rebuild lives), mode 2 leaves the timber bare. The
	## APRON cappings — the curved runs forward of the bow line and aft of the
	## stern line — go in both states rather than only in mode 2, and that is a
	## decision rather than an oversight: the aprons are yawed, tapering segments
	## of unequal length, and a tiling module cannot follow them without a
	## per-segment stretch that would break the one property the low run is FOR,
	## a pitch that lines up with the rail above it. So mode 1's bow is bare
	## timber and the frames show it.
	if strake_cap_mode != 0:
		return
	var cap := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(width * 1.12, 11.0, length) * WORLD_SCALE
	cap.mesh = cm
	cap.material_override = brass
	## The capping is wider than the timber it sits on, and every millimetre of
	## that extra width goes OUTBOARD. Centring it cost 3.6 units of overhang
	## across the deck line, which the lattice caught at (839, 1159) — a rail cap
	## proud of the deck is the exact class of thing that occludes a boarder's
	## feet at the rail and is never noticed until somebody dies to it.
	var out := Vector2(cos(yaw), -sin(yaw)) * (width * 0.06) * signf(x)
	cap.position = Vector3((x + out.x) * WORLD_SCALE, (lift - 2.5) * WORLD_SCALE,
		(z + out.y) * WORLD_SCALE)
	cap.rotation.y = yaw
	_hull_shape.add_child(cap)


## An apron of planking from `z_edge` running `span` units beyond the rectangle
## (negative forward), narrowing on `hull_beam`, with the strake following it.
##
## The planking material is the DECK's own instance, read off the node rather
## than rebuilt, so the boards run unbroken across the bow line and there is no
## second place for a plank width to disagree.
func _hull_apron(z_edge: float, span: float, segments: int,
		timber: StandardMaterial3D, brass: StandardMaterial3D) -> void:
	var rect: Rect2 = SkyGearGame.DECK_RECT
	var half: float = rect.size.x * 0.5
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	for i in segments:
		var z0: float = z_edge + span * (float(i) / segments)
		var z1: float = z_edge + span * (float(i + 1) / segments)
		var h0: float = half * hull_beam(z0)
		var h1: float = half * hull_beam(z1)
		## Wound so the face points UP whichever way the apron runs.
		var quad: Array = [
			Vector3(-h0, 0.0, z0), Vector3(h0, 0.0, z0),
			Vector3(h1, 0.0, z1), Vector3(-h1, 0.0, z1)]
		## The winding is not guessed at — the apron material below is drawn
		## two-sided, because the bow runs one way in z and the stern the other
		## and exactly one of the two orders is right for each. The first attempt
		## picked per-direction orders and the bow came back as a black wedge
		## between the two bulwarks in `.shots/marks/clean-bow-z1.00.png`.
		var order: Array = [0, 2, 1, 0, 3, 2]
		for k in order:
			var p: Vector3 = quad[k]
			verts.append(p * WORLD_SCALE)
			## The deck's own UV frame, continued: same tiling, same plank width,
			## joints that line up across the seam.
			uvs.append(Vector2((p.x - rect.position.x) / rect.size.x,
				(p.z - rect.position.y) / rect.size.y))
			normals.append(Vector3.UP)
		## And the strake, following the taper in. One box per segment, and it is
		## seated on the tapering EDGE LINE rather than on the mean beam.
		##
		## That distinction is the whole superset property at the seam, and the
		## harness caught the naive version: a box centred on the segment's mean
		## half-beam and then yawed swings its inboard corner back across the bow
		## line — measured at (799, 1159) against a rectangle that ends at 840.
		## Seated on the edge with its inner face ON the line and its body pushed
		## out along the line's own normal, every corner is outboard by
		## construction, whatever the taper does.
		for side in [-1.0, 1.0]:
			var mid_z: float = (z0 + z1) * 0.5
			var run := Vector2(side * (h1 - h0), z1 - z0)
			var length := maxf(1.0, run.length())
			var dir := run / length
			var normal := Vector2(dir.y, -dir.x)
			if signf(normal.x) != side:
				normal = -normal
			var seat := Vector2(side * (h0 + h1) * 0.5, mid_z) \
				+ normal * (SHEER_WIDTH * 0.5)
			var lift: float = sheer_lift(z_edge) * (0.42 + 0.58 * hull_beam(mid_z))
			_strake_box(timber, brass, seat.x, seat.y,
				SHEER_WIDTH, length, lift, atan2(dir.x, dir.y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var apron := MeshInstance3D.new()
	apron.mesh = mesh
	## The DECK's own material, duplicated rather than rebuilt, so the planking
	## runs unbroken across the bow line and a plank width has one owner — with
	## culling off, which is the whole reason it is a copy and not the original.
	var skin: StandardMaterial3D = (deck.material_override as StandardMaterial3D).duplicate()
	skin.cull_mode = BaseMaterial3D.CULL_DISABLED
	apron.material_override = skin
	_hull_shape.add_child(apron)


## --- THE SHIP'S EDGE KIT — the owner's own four pieces, on the deck ------------
##
## SG-157, and the complaint it answers is a measured one rather than a mood:
## the deck read as *"a floating plane — not the deck of a ship"*, and
## DECK-DESIGN §1 found that 94% of the default frame is planking with the near
## two thirds carrying no ship's edge at all. `handoff-3d/ship_edge_kit/` is the
## answer, hand-modelled: a tiling rail module, a bow, a stern and a mast.
##
## WHAT IS HERE AND WHAT IS NOT. **The rail is placed. The bow, the stern and
## the mast are not**, and all three are refusals with frames behind them rather
## than omissions — the verdicts are written out below, each naming the shots it
## rests on. A piece that reads badly at this camera is worth more as a written
## finding than as geometry nobody wants to be the one to defend, and the rail is
## the piece DECK-IDENTITY ranked first anyway: it is the only one of the four
## that reaches the part of the frame the player actually stares at all run.
##
## EVERY NUMBER BELOW IS MEASURED OFF THE MESH, not read off a filename or a
## board row. `tools/edge_place.gd -- measure` prints them and is the only place
## they come from — the module is 189.83 x 90.17 x 22.44 ground units with three
## stanchions on an 83.45-unit pitch, and its rail overhangs 11.45 units past
## each end stanchion.
const EDGE_RAIL_SCENE := "res://assets/models/rail_stanchion/rail_stanchion.tscn"

## Ground units, at model scale 1. Measured, `tools/edge_place.gd -- measure`.
const RAIL_PITCH_NATIVE := 83.45     ## stanchion to stanchion
const RAIL_TOP_NATIVE := 90.17       ## overall height of the module
const RAIL_DEPTH_NATIVE := 22.44     ## across the rail, athwartships

## THE SCALE DECISION, AS ONE INTEGER — and it is the owner's, not this file's.
##
## The tiling is arithmetic. Modules are placed every TWO stanchion pitches so
## the end stanchions of neighbours COINCIDE and the pitch stays uniform through
## every seam; butt-joining at the natural pitch bunches stanchions in pairs.
## That makes the tile count the only free variable: `N` tiles across the 2320
## rectangle means a spacing of `2320/N`, a pitch of half that, and a uniform
## scale of `spacing / (2 x 83.45)`. Only whole `N` divides the deck evenly, so
## the candidates are discrete and there are three worth looking at:
##
##   N =  8   spacing 290.0   pitch 145.0   rail top 156.7   89% of a captain
##   N = 10   spacing 232.0   pitch 116.0   rail top 125.3   71% of a captain
##   N = 12   spacing 193.3   pitch  96.7   rail top 104.5   59% of a captain
##
## N = 8 is the 290-unit tiling already established. **N = 10 is what ships
## pending the owner's eye**, and the reason is that it is the SPEC arrived at
## from the other end. Item 4 asks for two rails at y = 66 and 118. The module's
## four solid bands measure 0-10, 12-28, 40-60 and 68-88 at scale 1, and at
## N = 10 the upper two land at **69.6** (against the spec's 66) and span
## **94.7 to 122.6**, so the spec's 118 falls INSIDE the top band. SG-145
## reported the spec unreachable "at ANY uniform scale"; that is right about the
## BAR COUNT — this is a three-bar rail with a cap where the spec describes two
## bars — and wrong about the HEIGHTS, which N = 10 hits. Recorded rather than
## quietly worked around, because a fact contradicted in one place and believed
## in another is this repo's sixth failure mode.
##
## Settable rather than `const` so `tools/edge_place.gd` can photograph the
## candidates through the SHIPPED renderer instead of mocking up a second rail
## that could disagree with this one.
var edge_rail_tiles := 10

var _edge_kit: Node3D

## TRIAL ONLY, default OFF. `tools/edge_place.gd -- stern <scale> <z>` turns this
## on to photograph `stern_counter` in place. It is not shipped geometry and the
## verdict below says why.
var edge_stern_trial := 0.0
var edge_stern_z := 1380.0

## THE RETIRED GUNWALE, and it is here for exactly one reason: so the before and
## the after can be photographed IN ONE PROCESS. Two runs of a shot tool never
## land their flicker, particles and cloud drift at the same point twice, which
## is the whole of SG-108 — an A/B across two invocations is partly an A/B of the
## weather. `tools/edge_place.gd -- before` sets this, and nothing else ever
## should.
var edge_rail_legacy := false


## --- THE SECOND PAIR, SG-174 ---------------------------------------------------
##
## `bow_ram` and `stern_counter` were REFUSED by SG-157 on proportion and the
## owner remade both. The new pieces are `prow_ram` and `stern_counter_v2`, and
## the rejected pair is still in `assets/models/` untouched so the comparison
## survives — nothing below reads them.
##
## EVERY NUMBER HERE IS MEASURED OFF THE TRIMMED MESH THAT SHIPS, in ground
## units at model scale 1, and the measurement is the one thing that decides the
## HEADING for each piece rather than a filename or a delivery note:
##
##   prow_ram          189.6 x  93.2 x  83.4    3,000 tris
##   stern_counter_v2  189.3 x  40.1 x  89.8    3,000 tris
##
## THE PROW'S HEADING DOES NOT MATTER AND THAT IS A MEASUREMENT. Its plan is a
## rounded RECTANGLE — no point, no taper, symmetric in both horizontal axes —
## and the only taper in it runs DOWNWARD (1.896 across the top narrowing to
## 0.554 at the keel). That is a hull section, so the long axis is the beam and
## the piece is placed unrotated.
##
## THE STERN'S HEADING IS FORCED BY ITS SYMMETRY AND IT IS NOT THE LONG AXIS.
## The delivery was measured 1.898 x 0.402 x 0.896 and read as "width on the
## long axis"; the mesh says otherwise. It is a lens in plan, blunt at +X and
## drawn to a point at -X, and it is MIRROR-SYMMETRIC ABOUT ITS OWN XY PLANE.
## A ship's piece is symmetric about the centreline, so the centreline is the
## X axis: 189.3 of it runs FORE-AND-AFT and 89.8 goes across. The blunt end is
## the transom — `.shots/sg148/sg174-id/stern_counter_v2-y270.png` is that end
## seen square on, a framed arch with a centre post over a squared lower band —
## so the placement turns +X to +Z and everything forward of the transom is hull
## under the deck, which is exactly where a counter's length is supposed to go.
const EDGE_PROW_SCENE := "res://assets/models/prow_ram/prow_ram.tscn"
const EDGE_STERN_V2_SCENE := "res://assets/models/stern_counter_v2/stern_counter_v2.tscn"

const PROW_NATIVE := Vector3(189.6, 93.2, 83.4)
const STERN_V2_NATIVE := Vector3(189.3, 40.1, 89.8)

## THE PROW IS ON. THE STERN IS OFF, AND IT IS A REFUSAL WITH A NUMBER RATHER
## THAN A PREFERENCE — the verdict is written out under `_build_edge_stern_v2()`
## and it is the same camera fact SG-157 measured, now confirmed against a piece
## that has no proportion problem at all. Both switches exist so
## `tools/edge_ab.gd` can take the control plate in the SAME freeze and so the
## refusal's frames stay reproducible from one flag.
var edge_prow := true
var edge_stern_v2 := false

## THE PROW IS SEATED BY ITS AFT EDGE AND ITS SCALE IS DERIVED, NOT TYPED.
##
## The first placement fixed a scale and a forward face and it read exactly like
## the piece SG-157 refused: a dark slab hanging in the sky forward of the stem,
## with a wedge of unlit apron visible BETWEEN it and the two brass strakes
## (`.shots/sg157/sg174-prow-z-1500/`). The gap was the whole failure — a nose that
## does not touch the bulwarks it is supposed to finish is a separate object.
##
## So the free variable is WHERE THE PIECE ENDS, and the scale follows from it:
## the piece is scaled so its beam equals the apron's own beam at that z, which
## puts its two aft corners exactly on the strake lines by construction. There is
## no value of `edge_prow_aft_z` that leaves a gap, and that is the point of
## writing it this way rather than as a scale plus a hope.
## -1620 is chosen from frames and not from arithmetic: it is where the piece is
## 638 across against a 638-wide apron, which is big enough to be a nose and
## small enough not to reach the sky at the top of the frame.
## `.shots/sg157/sg174-prow-z*` is the sweep it was picked out of — four seats
## from -1160 to -1750 crossed with three heights.
var edge_prow_aft_z := -1620.0
## HOW FAR PROUD OF THE APRON, and this one is the whole argument.
##
## At +3 the piece's top face is coplanar with the apron and it VANISHES: the
## apron is a flat plane at y = 0 too, so the only difference the frame gets is a
## brass line (`.shots/sg157/sg174-prow-z-1500-t3/`). At +160 it clears the stem
## entirely and reads as a separate object hanging in the sky, cropped by the top
## of the frame — which is exactly what `bow_ram` was cut for
## (`sg174-prow-z-1680-t160/`). +110 is the seat where its aft corners are still
## on the strakes and its brass underframe is what the camera gets.
var edge_prow_top := 110.0


## The uniform scale that makes the prow exactly as wide as the hull it caps.
func edge_prow_scale() -> float:
	return (SkyGearGame.DECK_RECT.size.x * hull_beam(edge_prow_aft_z)) / PROW_NATIVE.x

## THE STERN, seated by its TRANSOM. `edge_stern_v2_width` is the across-ship
## beam the piece is scaled to, and 874 is not a taste: it is `STERN_BEAM * 1680`,
## the width the hull's own counter tapers to, so the transom face lands exactly
## as wide as the hull it closes.
var edge_stern_v2_aft_z := 1540.0
var edge_stern_v2_width := 874.0
## The top face against the deck edge. SG-157's stern FAILED ON SEATING — it
## floated in the void with a visible gap under the strake — so this is the
## number that row is really about, and it is measured off the same `sheer_lift`
## the strake is built on rather than typed in beside it.
var edge_stern_v2_top := 0.0
## THE HEADING, IN DEGREES, AND IT IS A TRIAL VARIABLE BECAUSE THE MESH ARGUES
## WITH THE DELIVERY NOTE. -90 turns the model's +X aft, which is what its own
## mirror plane asks for; 0 lays the long axis ACROSS the ship, which is what the
## delivery note said and what the spec asked for. Both were photographed —
## `.shots/sg157/sg174-stern-*` — because the verdict is about which one READS,
## not about which one is nominally correct.
var edge_stern_v2_yaw := -90.0


## The uniform scale that makes `edge_rail_tiles` modules tile the deck exactly.
func edge_rail_scale() -> float:
	var spacing: float = SkyGearGame.DECK_RECT.size.y / float(edge_rail_tiles)
	return spacing / (2.0 * RAIL_PITCH_NATIVE)


func _build_edge_kit() -> void:
	_edge_kit = Node3D.new()
	_edge_kit.name = "EdgeKit"
	add_child(_edge_kit)
	_build_edge_rail()
	if strake_cap_mode == 1:
		_build_strake_rail()
	if edge_stern_trial > 0.0:
		_build_edge_stern_trial()
	## `bow_ram` IS STILL NOT BUILT — SG-157's verdict below stands and the model
	## is kept only for the comparison. Its replacement is the two calls under it.
	if edge_prow:
		_build_edge_prow()
	if edge_stern_v2:
		_build_edge_stern_v2()
	if upper_deck:
		_build_upper_deck()


## Rebuild at a different tile count, for the scale comparison. The probe drives
## this rather than carrying its own copy of the placement — two functions
## disagreeing about one number is failure mode two, and the whole point of the
## comparison is that what Alex judges is what ships.
func rebuild_edge_kit(tiles: int) -> void:
	edge_rail_tiles = tiles
	if _edge_kit != null:
		_edge_kit.queue_free()
		remove_child(_edge_kit)
	_build_edge_kit()


## THE RAIL, ALONG BOTH SIDES, RIDING THE SHEER.
##
## It seats on `sheer_lift()` — the one function the hull curve lives in — so the
## rail rises toward the bow and the stern the way the strake under it does. Each
## tile is TILTED to the slope between its own two ends rather than stood flat at
## its centre height: neighbours therefore meet at exactly the same y, because
## both read the same function at the same z, and the run has no staircase in it.
##
## OUTBOARD BY CONSTRUCTION, which is the superset property §6.1 pins. The
## module is symmetric about its long axis, so seating its CENTRE at
## `840 + depth/2` puts its inner face exactly on |x| = 840 and every millimetre
## of its depth outboard of the rectangle. Nothing here is walked on and nothing
## here collides — MeshInstance3D and no body, the same rule the hull keeps.
##
## IT CANNOT HIDE ANYBODY, and that is geometry rather than a hope. Camera x is
## clamped to +/-369.6 (`slack` in `_track_camera`), figures never pass +/-750,
## and the rail centres land at +/-856. The rail is always OUTBOARD of the figure
## and the camera is always INBOARD of it, so the rail is never between the two
## at any zoom. Pinned by `edge · no rail module stands between the camera and a
## figure at any zoom`, which measures it through `unproject_position` rather
## than repeating this paragraph.
func _build_edge_rail() -> void:
	if edge_rail_legacy:
		_build_legacy_gunwale()
		return
	var scene: PackedScene = load(EDGE_RAIL_SCENE)
	if scene == null:
		push_warning("edge kit: no rail module at %s" % EDGE_RAIL_SCENE)
		return
	var rect: Rect2 = SkyGearGame.DECK_RECT
	var s := edge_rail_scale()
	var spacing: float = rect.size.y / float(edge_rail_tiles)
	var x_off: float = rect.size.x * 0.5 + RAIL_DEPTH_NATIVE * s * 0.5
	for side in [-1.0, 1.0]:
		for i in edge_rail_tiles:
			var z0: float = rect.position.y + spacing * float(i)
			var z1: float = z0 + spacing
			## The strake's top edge sits at `lift - 8`; the rail stands on it.
			var y0: float = sheer_lift(z0) - 8.0
			var y1: float = sheer_lift(z1) - 8.0
			var run := Vector2(y1 - y0, z1 - z0)
			var tilt: float = -asin(run.x / maxf(1.0, run.length()))
			## Model +X runs along the deck (+Z); the tilt is applied in the
			## WORLD frame afterwards, so it follows the sheer rather than
			## rolling the rail over on its side.
			var basis := Basis(Vector3.RIGHT, tilt) * Basis(Vector3.UP, -PI * 0.5)
			var node: Node3D = scene.instantiate()
			node.transform = Transform3D(basis.scaled(Vector3(s, s, s)),
				Vector3(side * x_off, (y0 + y1) * 0.5, (z0 + z1) * 0.5) * WORLD_SCALE)
			_edge_kit.add_child(node)
			## NAMED, and not decoratively. An instanced scene keeps its own root
			## name for the FIRST copy and Godot renames every one after that to
			## `@Node3D@246` — so a harness check that counts rail modules by name
			## counted ONE of twenty until this line existed.
			node.name = "RailModule%s%d" % ["P" if side < 0.0 else "S", i]


## THE LOW RUN ON THE STRAKE — SG-180, and the owner's own suggestion.
##
## Where it goes is forced, and the forcing is the risk in this whole idea. The
## shipped rail already stands on the strake's top edge at `lift - 8`, and the
## brass capping this replaces sits at `lift - 2.5` — five and a half units above
## the same plane. The two occupy the SAME BAND. So a low run cannot go under the
## main rail; there is nothing under it but the timber face of the strake. It
## goes OUTBOARD of it instead, on the outboard half of the strake's top, which
## is the only room there is: the main rail's outer face is at 871.2 at the
## shipped scale and the strake's own outboard edge is at 898.
##
## That makes this a rail BESIDE a rail rather than a rail beneath one, and
## whether it reads as a double bulwark or as two rails stacked is a question for
## the frames and not for this comment.
##
## EVERYTHING IS DERIVED FROM `edge_rail_scale()`. The tile count is the shipped
## count times `strake_cap_rail_div`, so the low pitch divides the main pitch
## exactly and every main stanchion has one under it; the x offset is the main
## rail's own outer face plus half the low module's depth, so the low run cannot
## be inboard of the main one at any div; and the seat is the same
## `sheer_lift()`, tilted per tile, so it rides the sheer with everything else.
func _build_strake_rail() -> void:
	var scene: PackedScene = load(EDGE_RAIL_SCENE)
	if scene == null:
		push_warning("edge kit: no rail module at %s" % EDGE_RAIL_SCENE)
		return
	var rect: Rect2 = SkyGearGame.DECK_RECT
	var s_main := edge_rail_scale()
	var tiles: int = edge_rail_tiles * maxi(1, strake_cap_rail_div)
	var s: float = s_main / float(maxi(1, strake_cap_rail_div))
	var s_y: float = s if strake_cap_rail_height <= 0.0 \
		else s_main * strake_cap_rail_height
	var spacing: float = rect.size.y / float(tiles)
	## THE HEIGHT DIAL TAKES THE SECTION WITH IT, and that is not cosmetic. The
	## module's DEPTH is scaled by the same factor as its height, never by the
	## pitch factor, so squashing the run keeps it on the strake: at div 1 with a
	## full-depth module the run's outer face lands at 902.4 against a strake that
	## ends at 898, i.e. four units of rail hanging over open air. Height and
	## depth are the SECTION; the pitch factor is the LENGTH; they are different
	## questions and the frames asked both.
	var x_off: float = rect.size.x * 0.5 + RAIL_DEPTH_NATIVE * s_main \
		+ RAIL_DEPTH_NATIVE * s_y * 0.5
	for side in [-1.0, 1.0]:
		for i in tiles:
			var z0: float = rect.position.y + spacing * float(i)
			var z1: float = z0 + spacing
			var y0: float = sheer_lift(z0) - 8.0
			var y1: float = sheer_lift(z1) - 8.0
			var run := Vector2(y1 - y0, z1 - z0)
			var tilt: float = -asin(run.x / maxf(1.0, run.length()))
			var basis := Basis(Vector3.RIGHT, tilt) * Basis(Vector3.UP, -PI * 0.5)
			var node: Node3D = scene.instantiate()
			## `Basis.scaled` applies in the PARENT frame, after the -90° yaw —
			## so world X is the module's depth, world Z its length. That is why
			## the vector is not the model's own (length, height, depth) order.
			node.transform = Transform3D(basis.scaled(Vector3(s_y, s_y, s)),
				Vector3(side * x_off, (y0 + y1) * 0.5, (z0 + z1) * 0.5) * WORLD_SCALE)
			## NOT `Rail...`, and the name is load-bearing: `edge · the deck rail
			## is the tiling module, not the solid bar it replaced` counts kit
			## children whose name begins with "Rail" and requires exactly
			## `edge_rail_tiles * 2` of them. These are a second run of the same
			## module and would break that count while being perfectly correct.
			## The whole-kit properties (nothing inboard, nothing solid, nothing
			## in the rectangle she walks) are name-blind and still cover them.
			node.name = "StrakeRail%s%d" % ["P" if side < 0.0 else "S", i]
			_edge_kit.add_child(node)


## THE PROW — a nose on the bow the apron already draws, SG-174.
##
## `_hull_apron()` carries real planking 620 units forward of the bow line and
## narrows it to NOTHING on `hull_beam()`, so the ship already reads as having a
## bow: two bulwarks converging on a stem. What it does not have is a stem — the
## convergence runs out to a paper edge. This is the block that edge lands on.
##
## THE SEAT IS THE AFT EDGE, at `edge_prow_aft_z`, and the scale comes from the
## hull there — see the note on `edge_prow_scale()`. The `.tscn` wrapper stands
## the mesh on its own floor and centres it over its footprint, so the node's
## origin is the BASE and the middle of the plan: the y below drops it until its
## TOP is `edge_prow_top` above the apron, and the z below pushes it FORWARD by
## half its own depth so its aft face lands on the seat rather than its middle.
##
## NOTHING HERE COLLIDES AND NOTHING HERE IS INBOARD. The piece lives entirely
## forward of `DECK_RECT.position.y` — 540 units forward of the bow line at the
## shipped seat — so it cannot reach the rectangle the captain walks, and like
## every other kit piece it is a MeshInstance3D with no body. Both are harness
## checks rather than paragraphs.
func _build_edge_prow() -> void:
	var scene: PackedScene = load(EDGE_PROW_SCENE)
	if scene == null:
		push_warning("edge kit: no prow at %s" % EDGE_PROW_SCENE)
		return
	var s := edge_prow_scale()
	var node: Node3D = scene.instantiate()
	node.transform = Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(
		0.0,
		edge_prow_top - PROW_NATIVE.y * s,
		edge_prow_aft_z - PROW_NATIVE.z * s * 0.5) * WORLD_SCALE)
	node.name = "Prow"
	_edge_kit.add_child(node)


## THE STERN — the transom the counter was missing, SG-174.
##
## SG-157's stern did not fail on size, it failed on SEATING: it hung in the
## black below the deck edge with a gap between it and the strake, so it read as
## a crate parked near the ship rather than as the end of it. The seat here is
## therefore stated as a rule and not as a coordinate — the piece's TOP FACE goes
## at `edge_stern_v2_top` above the apron plane and its TRANSOM FACE goes at
## `edge_stern_v2_aft_z`, which defaults to `DECK_RECT.end.y + STERN_LENGTH`: the
## exact z where `_hull_apron` stops drawing planking. Top face and apron plane
## are then the same plane at the same z, which is what "butts with no gap and no
## overlap" means when it is written as arithmetic.
##
## `Basis(UP, -PI/2)` carries the model's +X to world +Z, putting the blunt
## transom end aft — see the heading note above, which measures it rather than
## reading it off the delivery.
func _build_edge_stern_v2() -> void:
	var scene: PackedScene = load(EDGE_STERN_V2_SCENE)
	if scene == null:
		push_warning("edge kit: no stern at %s" % EDGE_STERN_V2_SCENE)
		return
	## Which of the model's two horizontal extents ends up ACROSS the ship follows
	## from the heading, so the scale and the aft offset are read out of the same
	## turn rather than typed twice.
	var turned: bool = absf(sin(deg_to_rad(edge_stern_v2_yaw))) > 0.5
	var across: float = STERN_V2_NATIVE.z if turned else STERN_V2_NATIVE.x
	var along: float = STERN_V2_NATIVE.x if turned else STERN_V2_NATIVE.z
	var s: float = edge_stern_v2_width / across
	var node: Node3D = scene.instantiate()
	var basis := Basis(Vector3.UP, deg_to_rad(edge_stern_v2_yaw)).scaled(Vector3(s, s, s))
	node.transform = Transform3D(basis, Vector3(
		0.0,
		edge_stern_v2_top - STERN_V2_NATIVE.y * s,
		edge_stern_v2_aft_z - along * s * 0.5) * WORLD_SCALE)
	node.name = "SternCounter"
	_edge_kit.add_child(node)


## --- THE UPPER DECK — SG-178, and it is a KIT rather than four objects ---------
##
## Alex: *"I wanted there to be an upper level that you can see from the deck but
## you don't actually, or at least not currently, go on to it."* Four modules
## arrived against `handoff-3d/ship_edge_kit/UPPER-DECK-KIT.md` — a platform bay,
## a support post, a staircase and a corner post — and the fifth piece of the kit
## is `rail_stanchion`, which is NOT respecced: SG-176 proved the module the deck
## already ships reads up there at the scale it already ships at.
##
## EVERY NUMBER BELOW IS MEASURED OFF THE SHIPPED MESH, in ground units at model
## scale 1, and TWO OF THEM ARE MEASURED OFF SURFACES RATHER THAN OFF A BOUNDING
## BOX, which is the part that matters:
##
##   upper_bay      189.6 x 107.8 x 152.2   2,688 tris
##   upper_post      41.6 x 189.9 x  41.5   2,934 tris
##   upper_stair    119.1 x 172.4 x 189.6   2,920 tris
##   upper_corner    76.4 x 189.9 x  45.6   2,920 tris   (as WRAPPED, facing +90)
##
## `BAY_SOFFIT_NATIVE` is the flat underside of the beam, not the bottom of the
## piece: the bay's lowest geometry is the two curved KNEES, 107.1 below the
## planking, while the soffit the posts have to meet is the 2.02-unit-area
## down-facing plane 32.8 below it. Standing the posts on the bbox floor would
## have driven them into the knees and left the beam unsupported by 74 units.
##
## `STAIR_RISE_NATIVE` is likewise not the model's height. The mesh is 172.4 tall
## because its HANDRAIL is, and a stair scaled by its handrail lands its treads
## three quarters of the way up the platform. The climb is measured off the TREADS
## — ten up-facing planes of ~0.19 area each from -0.761 to +0.353 in model units,
## a 12.4-unit riser, over a floor at -0.863 — so the deck it delivers her onto is
## one riser above the top tread: (0.353 + 0.863) * 100 + 12.4 = 134.0. Eleven
## risers, which is what the delivery note said it was built with.
const UPPER_BAY_SCENE := "res://assets/models/upper_bay/upper_bay.tscn"
const UPPER_POST_SCENE := "res://assets/models/upper_post/upper_post.tscn"
const UPPER_STAIR_SCENE := "res://assets/models/upper_stair/upper_stair.tscn"
const UPPER_CORNER_SCENE := "res://assets/models/upper_corner/upper_corner.tscn"

const BAY_NATIVE := Vector3(189.6, 107.8, 152.2)
const BAY_SOFFIT_NATIVE := 32.8      ## plank top down to the beam's underside
const POST_NATIVE := Vector3(41.6, 189.9, 41.5)
const STAIR_NATIVE := Vector3(119.1, 172.4, 189.6)
const STAIR_RISE_NATIVE := 134.0     ## its own floor to the deck it lands on
const CORNER_NATIVE := Vector3(76.4, 189.9, 45.6)
## The rail module's own LENGTH, the one dimension `_build_edge_rail` never needs
## because it tiles by pitch and the deck is exactly divisible. Laid across the
## ship the run is finite, so the last module's overhang is the whole question of
## whether the corner posts fit. Measured, `tools/edge_place.gd -- measure`.
const RAIL_MODULE_NATIVE := 189.83

## ON. Unlike the stern this is not a refusal — see the verdict under
## `_build_upper_deck()` — but the switch exists so `tools/edge_ab.gd` can take
## the control plate in the SAME freeze, which is the only kind of A/B this repo
## accepts (SG-108).
var upper_deck := true

## THE PLATFORM'S HEIGHT IS DERIVED FROM THE SHIPPED RAIL AND IS NOT A LITERAL.
##
## The kit was proportioned to "two of your rails stacked" and the STAIR WAS BUILT
## TO CLIMB EXACTLY THAT, so the number has to come from the rail the deck
## actually ships rather than from a 250 typed in here. `edge_rail_tiles` is a
## live variable — `tools/edge_place.gd -- scales` drives it through 8, 10 and 12
## — and at N = 8 the rail's top is 156.7 rather than 125.3. A literal would have
## silently put the stair's top tread 62 units below a platform that had moved.
var upper_rails_stacked := 2

## Five bays across, one post under each. The kit doc asks for "about five" bays
## and "four or five" posts; both counts are variables and the tiling is arithmetic
## so either can move without a hand-placed list moving with it.
var upper_bays := 5

## HOW FAR FORWARD THE STAIR'S FOOT STANDS OF THE BOW LINE. Four units, and it is
## not a taste: the seat below is derived so the stair's foot lands ON the bow
## line, and `Rect2.intersects` excludes borders, so a piece whose aft face is at
## exactly `DECK_RECT.position.y` passes or fails the play-rectangle check on the
## last bit of a float. This is the clearance that makes the answer not depend on
## rounding.
const UPPER_STAIR_CLEAR := 4.0


## The platform's floor, in ground units above the deck plane. Two rail-heights,
## read off the rail this deck ships.
func upper_platform_top() -> float:
	return RAIL_TOP_NATIVE * edge_rail_scale() * float(upper_rails_stacked)


## The stair is scaled by its CLIMB, so its top tread lands on the platform by
## construction — there is no value of anything above that floats it or buries it.
func upper_stair_scale() -> float:
	return upper_platform_top() / STAIR_RISE_NATIVE


func upper_stair_run() -> float:
	return STAIR_NATIVE.z * upper_stair_scale()


## THE SEAT, AND IT IS THE WHOLE PLACEMENT ARGUMENT.
##
## The platform's aft edge is exactly one STAIR RUN forward of the bow line, so
## the flight fits between the two — and that single derivation is what satisfies
## the three constraints that were in tension, none of which is negotiable:
##
##   1. SG-176 measured that a stair running forward UNDERNEATH the platform
##      cannot be found in the frame. So the stair has to be AFT of the platform's
##      aft edge, in the open.
##   2. Nothing in this kit may stand in the rectangle she walks. So the stair
##      cannot be aft of the BOW LINE either.
##   3. The stair's slope is the model's, and its rise is the platform's height,
##      so its run is not a free variable: 355 units at the shipped rail scale.
##
## (1) and (2) together leave exactly one strip of ship for the flight — the
## apron between the bow line and the platform — and (3) says how wide that strip
## has to be. The seat is therefore the aft-most one that works, which is the one
## that keeps the platform as big and as near the lens as the stair allows.
##
## THE COST IS RECORDED RATHER THAN HIDDEN: SG-176's mock stood the platform ON
## the bow line at the full 1,680 beam and measured 49.31% of the frame. It had no
## stair in it that could be found. This seat is 355 units further out, where the
## hull is 59% of its beam, and the frame share it buys is in the board row.
func upper_deck_aft_z() -> float:
	return SkyGearGame.DECK_RECT.position.y - UPPER_STAIR_CLEAR - upper_stair_run()


## THE PLATFORM'S BEAM IS THE HULL'S OWN BEAM WHERE IT SEATS — `_build_edge_prow`'s
## rule, for `_build_edge_prow`'s reason. The apron narrows on `hull_beam()`, so a
## platform sized independently of its seat either overhangs into open air (the
## posts under its ends stand on nothing, which is SG-157's whole bow verdict) or
## stops short of the strakes. Derived, there is no setting that does either.
func upper_deck_beam() -> float:
	return SkyGearGame.DECK_RECT.size.x * hull_beam(upper_deck_aft_z())


func upper_bay_scale() -> float:
	return upper_deck_beam() / (float(upper_bays) * BAY_NATIVE.x)


## A head above the rail cap, which is what §4 asks the corner post to stand.
## A head is the captain's own height over seven, so the piece is proportioned
## against the figure it has to read beside rather than against a typed number.
func upper_corner_scale() -> float:
	return (RAIL_TOP_NATIVE * edge_rail_scale() + CAPTAIN_HEIGHT / 7.0) / CORNER_NATIVE.y


## HOW MANY RAIL MODULES CROSS THE PLATFORM, and it is counted rather than chosen.
##
## The rail is laid across the ship at the scale the DECK ships it at (SG-176 —
## "no new railing asset"), so its module length and its two-pitch step are both
## fixed and the run has to fit between the two corner posts. That is the seam the
## corner post exists to make: the rail's cap ends where the post's inboard face
## begins, so the run terminates rather than stopping in mid-air.
##
## `n` modules butt-joined every TWO stanchion pitches span (n-1) steps plus one
## module — the same arithmetic `_build_edge_rail` tiles the deck with, so the
## pitch survives every seam here too.
func upper_rail_count() -> int:
	var s := edge_rail_scale()
	var room: float = upper_deck_beam() - 2.0 * CORNER_NATIVE.x * upper_corner_scale()
	var step: float = 2.0 * RAIL_PITCH_NATIVE * s
	return maxi(1, int(floor((room - RAIL_MODULE_NATIVE * s) / step)) + 1)


func upper_rail_run() -> float:
	return RAIL_MODULE_NATIVE * edge_rail_scale() \
		+ float(upper_rail_count() - 1) * 2.0 * RAIL_PITCH_NATIVE * edge_rail_scale()


## THE UPPER DECK, BUILT. Set dressing and nothing else: every node here is an
## instanced `MeshInstance3D` tree with no body of any kind, nothing reaches aft of
## the bow line, and the rectangle she walks is not touched by a single unit. Both
## are harness checks rather than paragraphs.
func _build_upper_deck() -> void:
	var bay_scene: PackedScene = load(UPPER_BAY_SCENE)
	var post_scene: PackedScene = load(UPPER_POST_SCENE)
	var stair_scene: PackedScene = load(UPPER_STAIR_SCENE)
	var corner_scene: PackedScene = load(UPPER_CORNER_SCENE)
	if bay_scene == null or post_scene == null or stair_scene == null \
			or corner_scene == null:
		push_warning("upper deck: a kit piece is missing from assets/models/upper_*")
		return

	var top := upper_platform_top()
	var aft := upper_deck_aft_z()
	var beam := upper_deck_beam()
	var s_bay := upper_bay_scale()
	var bay_w: float = BAY_NATIVE.x * s_bay
	var bay_d: float = BAY_NATIVE.z * s_bay
	## The underside the player looks at all run. Posts stop here, not at the
	## knees — see `BAY_SOFFIT_NATIVE`.
	var soffit: float = top - BAY_SOFFIT_NATIVE * s_bay

	## a · THE BAYS. Butt ends, left face against right face, `upper_bays` of them
	## across the platform's own beam. The wrapper stands each piece on its floor
	## and centres it over its footprint, so the y below drops the piece until its
	## PLANK TOP is the platform floor and the z pushes it forward by half its own
	## depth so its aft face lands on the seat rather than its middle.
	for i in upper_bays:
		var node: Node3D = bay_scene.instantiate()
		node.transform = Transform3D(Basis().scaled(Vector3(s_bay, s_bay, s_bay)),
			Vector3(-beam * 0.5 + bay_w * (float(i) + 0.5),
				top - BAY_NATIVE.y * s_bay,
				aft - bay_d * 0.5) * WORLD_SCALE)
		node.name = "UpperBay%d" % i
		_edge_kit.add_child(node)

	## b · THE POSTS, one under each bay, standing on the apron at y = 0 and
	## carrying the beam. Scaled by the SOFFIT rather than by the platform floor:
	## the post's flared head takes the beam, and a post scaled to the floor would
	## push its bracket up through the planking it is holding.
	var s_post: float = soffit / POST_NATIVE.y
	for i in upper_bays:
		var node: Node3D = post_scene.instantiate()
		node.transform = Transform3D(Basis().scaled(Vector3(s_post, s_post, s_post)),
			Vector3(-beam * 0.5 + bay_w * (float(i) + 0.5), 0.0,
				aft - POST_NATIVE.z * s_post * 0.5) * WORLD_SCALE)
		node.name = "UpperPost%d" % i
		_edge_kit.add_child(node)

	## c · THE STAIR, on the open apron between the bow line and the platform,
	## climbing FORWARD. The model already climbs toward -Z (its mesh top falls
	## monotonically from +0.86 to -0.16 along z), so nothing turns it; the seat is
	## stated as "foot on the bow line, top tread on the platform" and both follow
	## from `upper_stair_scale()`.
	##
	## To PORT, and aligned on the second bay from port rather than on a
	## coordinate, so it stays under the structure it lands on at any bay count.
	var s_stair := upper_stair_scale()
	var stair: Node3D = stair_scene.instantiate()
	stair.transform = Transform3D(Basis().scaled(Vector3(s_stair, s_stair, s_stair)),
		Vector3(-beam * 0.5 + bay_w * 1.5, 0.0,
			SkyGearGame.DECK_RECT.position.y - UPPER_STAIR_CLEAR
				- upper_stair_run() * 0.5) * WORLD_SCALE)
	stair.name = "UpperStair"
	_edge_kit.add_child(stair)

	## d · THE RAIL — HIS OWN MODULE, at the scale the deck already ships it at,
	## laid ACROSS the beam instead of along the side. The module is symmetric
	## about its long axis and its long axis is already +X, so unlike the deck run
	## this one takes no yaw at all.
	var s_rail := edge_rail_scale()
	var run := upper_rail_run()
	var step: float = 2.0 * RAIL_PITCH_NATIVE * s_rail
	## Standing at the platform's aft edge, its outboard face flush with the
	## platform's aft face — a rail belongs on the edge it guards.
	var rail_z: float = aft - RAIL_DEPTH_NATIVE * s_rail * 0.5
	var count := upper_rail_count()
	for i in count:
		var node: Node3D = rail_scene_instance(s_rail)
		node.position = Vector3(
			-run * 0.5 + RAIL_MODULE_NATIVE * s_rail * 0.5 + step * float(i),
			top, rail_z) * WORLD_SCALE
		node.name = "UpperRail%d" % i
		_edge_kit.add_child(node)

	## e · THE CORNER POSTS, one at each end of the RAIL RUN — that is what §4
	## asks them to terminate, and putting them at the platform's ends instead
	## would leave the rail stopping in mid-air with bare planking beyond it.
	##
	## THE LANTERN POINTS OUTBOARD, WHICH IS WHY THERE IS A YAW HERE AT ALL. The
	## wrapper turns the piece so its lantern faces +X; that is outboard to
	## STARBOARD and inboard to port, so the port copy takes a half turn. §4 wants
	## the lantern found by the eye at the end of a long dark run, and a lantern
	## aimed up-deck is behind its own post from every camera this game has.
	var s_corner := upper_corner_scale()
	for side in [-1.0, 1.0]:
		var node: Node3D = corner_scene.instantiate()
		var basis := Basis(Vector3.UP, PI if side < 0.0 else 0.0) \
			.scaled(Vector3(s_corner, s_corner, s_corner))
		node.transform = Transform3D(basis, Vector3(
			side * (run * 0.5 + CORNER_NATIVE.x * s_corner * 0.5), top, rail_z)
			* WORLD_SCALE)
		node.name = "UpperCorner%s" % ["P" if side < 0.0 else "S"]
		_edge_kit.add_child(node)


## One rail module at a given scale, unrotated. Its own scene, loaded once per
## call the way every other kit piece is — kept as a function only so the tiling
## loop above reads as arithmetic rather than as scene plumbing.
func rail_scene_instance(s: float) -> Node3D:
	var scene: PackedScene = load(EDGE_RAIL_SCENE)
	var node: Node3D = scene.instantiate()
	node.transform = Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3.ZERO)
	return node


## THE STERN IS CUT AGAIN, AND THIS TIME THE MODEL IS NOT THE PROBLEM.
##
## `stern_counter_v2` is built by the function above and `edge_stern_v2` is OFF.
## SG-157 refused the first stern on SEATING — it hung in the black with a gap
## under the strake. That is fixed here by construction: the seat is stated as
## "top face on the apron plane, transom face at the apron's own aft limit", so
## there is no value of either variable that leaves a gap. **And seating it
## correctly makes it INVISIBLE.**
##
## MEASURED, not judged by eye. The A/B pair at the transom pose, both plates
## inside one freeze, differs on **0.000% of its pixels at a threshold of 2/255,
## with a maximum single-channel delta of 1** — under the tool's own noise floor,
## which is 0.00% at that pose. At zoom 1.55 it is 0.019%.
## `.shots/owner-review/2-bow-stern-redo/sternv2-*` is the pair, and the two
## plates are the same picture.
##
## THE CAUSE IS THE CAMERA AND IT IS THE SAME 209-UNIT BAND SG-157 MEASURED.
## A piece whose top is at or below the apron plane is under an opaque two-sided
## apron everywhere the apron exists, and aft of that it is in a part of the
## frame that carries no lamp; there is nothing down there for the moon to catch.
## Raising it is the only way to make it visible and raising it puts it BETWEEN
## THE LENS AND THE CAPTAIN, which is measured too:
##
##   * `.shots/sg157/sg174-stern-z1540-t110-y0/` — 110 up, long axis across the
##     ship. She is cut off at the chest.
##   * `.shots/sg157/sg174-stern-z1300-t110-y0/` — 100 further forward. She is
##     gone; only her hair shows.
##   * `.shots/sg157/sg174-stern-z1540-t90/` and `z1340-t140/` — the mesh's own
##     heading (long axis fore-and-aft). At the beam-matched scale that heading
##     is 1,842 units long, so lifting it at all lays a brass tub over the whole
##     aft third of the deck.
##
## SO THE FINDING IS NOT ABOUT EITHER MODEL. Two hand-made sterns of completely
## different proportion have now failed the same way, and the reason is that this
## camera never sees the outside of the hull: it sits 460 units astern of a focus
## that clamps at 1360 and looks DOWN at 41 degrees, so everything a transom is
## made of is either behind the deck it closes or below the bottom of the frame.
## A stern that shows on this deck is a stern standing ON it. Filed for the owner
## rather than shipped dark: turning it on is one flag, and `edge_stern_v2_top`
## is the dial that decides how much of her it costs.
func _build_edge_stern_trial() -> void:
	var scene: PackedScene = load("res://assets/models/stern_counter/stern_counter.tscn")
	if scene == null:
		return
	var node: Node3D = scene.instantiate()
	var k := edge_stern_trial
	node.transform = Transform3D(Basis().scaled(Vector3(k, k, k)),
		Vector3(0.0, 0.0, edge_stern_z) * WORLD_SCALE)
	_edge_kit.add_child(node)


## The two solid 14 x 40 x 2320 bars this replaced, verbatim, for the A/B only.
func _build_legacy_gunwale() -> void:
	var rect: Rect2 = SkyGearGame.DECK_RECT
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#b0813f")
	mat.roughness = 0.6
	mat.metallic = 0.4
	for side in [-1.0, 1.0]:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(14.0, 40.0, rect.size.y) * WORLD_SCALE
		bar.mesh = bm
		bar.material_override = mat
		bar.position = Vector3(
			(rect.position.x + (0.0 if side < 0.0 else rect.size.x)) * WORLD_SCALE,
			20.0 * WORLD_SCALE,
			(rect.position.y + rect.size.y * 0.5) * WORLD_SCALE)
		_edge_kit.add_child(bar)


## THE STERN IS CUT TOO, AND THE REASON IS THE CAMERA RATHER THAN THE MODEL.
##
## `stern_counter` is not on the deck. Two placements, both photographed:
##
##   * `.shots/sg157/stern-trial-s2.5/transom-z1.00.png` — scale 2.5, sized
##     toward the 874-unit transom. It fills the bottom half of the frame, its
##     texture goes to mush (8,000 triangles over a huge projected area, which is
##     SG-151's finding pointing the other way), and the captain is not visible
##     at all.
##   * `.shots/sg157/stern-trial-s1.0/transom-z1.00.png` — scale 1.0, its own
##     authored size. THE CAPTAIN IS HIDDEN BEHIND IT: only her hair shows above
##     its rail. Measured, not eyeballed — `edge_place.gd -- where transom` puts
##     her foot at (960, 745) inside the piece's screen box of x 752..1168,
##     y 595..1046.
##
## THE BAND IT WOULD HAVE TO LIVE IN IS 209 UNITS WIDE AND IT IS THE WRONG SIDE
## OF HER. The frame's bottom edge meets the deck at `focus - 102` and the camera
## focus clamps at `DECK_RECT.end.y + 200` = 1360, so nothing aft of z ~ 1258 is
## ever on screen. Anything inside that band is BETWEEN the lens and a captain
## standing at the transom, because the camera sits 460 units astern of its focus
## and she cannot go past z = 1160. A stern that is visible is a stern that
## occludes her; a stern that does not occlude her is off the bottom of the
## frame. That is the whole of it, and no scale escapes it.
##
## DECK-IDENTITY item 3 called the stern "cheapest of the three edges, since the
## aft half is off screen unless the captain walks into it". That was right, and
## the part it did not say is that WALKING INTO IT is exactly when the piece is
## in front of her. `edge_place.gd -- where` prints the bottom-edge number now;
## nothing had ever printed it, so "the aft half is off screen" had been an
## assertion since the day it was written.
##
## **CONFIRMED AGAINST A SECOND, BETTER STERN — SG-174.** The owner remade this
## piece and the remake fixes the seating completely; it is still cut, and the
## A/B says so with a zero rather than an opinion. The verdict on
## `_build_edge_stern_v2()` has the numbers. What that adds to this paragraph is
## that the band is not a fact about `stern_counter`: it is a fact about the
## camera, and no model answers it.


## THE MAST STAYS AS IT IS — the owner's model neither replaces the casters nor
## joins them, and this is the measurement rather than a preference.
##
## The question was whether `mast_crowned` should REPLACE the 24 procedural
## SHADOWS_ONLY pieces, FEED them, or stand beside them. It was tried as the
## caster (`rig_model_masts`, and `tools/edge_place.gd -- mast` reproduces it) at
## the same three stations and the same 1500-unit height, every mesh in it forced
## SHADOWS_ONLY. `.shots/sg157/MAST-trial-vs-shipped.png` is the pair.
##
## IT LOSES THE LATTICE. The shipped rig prints crisp diagonal shroud lines
## across the middle of the deck; the model prints broad soft shading with the
## lines gone. The deck gets DARKER — mean luminance over the planking band falls
## 45.13 to 41.66, 7.7% — while carrying less information, which is precisely
## DECK-DESIGN P2's trap 2: a shadow that reads as LIGHTING rather than as rope.
## `RIG_SHROUD_RADIUS` is 9.0 for that exact reason and the model's rigging is
## thinner than the 2.2 blur can hold. SG-116 measured the lattice as HELPING
## telegraph contrast, so trading it for a darker deck is a regression, and the
## brief for this work named it as one in advance.
##
## AND IT CANNOT BE VISIBLE EITHER. `RIG_MASTS` stands at x = +/-280 on the lane
## dividers, two of the three inside the play rectangle, so a drawn pole there is
## a bar standing where somebody fights — the failure that killed visible rigging
## twice already, with pictures at `.shots/deck/rig-mid-z1.00.png` and
## `rig2-mid-z1.55.png`. The camera never looks up; there is no pose from which a
## mast is scenery rather than an obstacle.
##
## So the mast is the one piece of the four with no defect at all and no place to
## go. Filed for the owner rather than forced onto the deck.


## THE BOW IS CUT, AND THIS IS THE REASON RATHER THAN AN OMISSION.
##
## `bow_ram` is not on the deck. It was placed three times, photographed each
## time at the shipped camera, and it reads badly at every one of them. The
## frames are kept on purpose because they are the argument:
##
##   1. `.shots/sg157/bow-cut/1-at-apron-tip-z*.png` — seated at the apron's tip
##      (z = -1655, scale 1.75), sized to the 344-unit stem it would cap. It is
##      INVISIBLE. Forward of the breast rail the apron carries no lamp and falls
##      away from the moon, so the stem is a dark wedge at the top of the frame
##      and 8,000 triangles of hand-modelled ram land in it unseen.
##   2. `.shots/sg157/bow-cut/2-at-bow-line-crop-z1.55.png` — brought in to
##      z = -1350 at scale 2.0, into the last of the lit deck. It reads as a dark
##      DRUM directly behind the captain's head.
##   3. `.shots/sg157/bow-cut/3-enlarged-crop-z1.55.png` — z = -1560 at scale 3.0,
##      big enough that it cannot be missed. It is a dark mass hanging OVER her
##      head, cropped by the top of the frame. This is `bow_prow.png`'s exact
##      failure rebuilt in geometry, which is what that sprite was retired for.
##
## THE CAUSE IS PROPORTION AND IT IS NOT FIXABLE BY TUNING. The piece measures
## 189.9 x 75.7 x 52.2 — a NARROW prow, 3.6 times longer than it is wide, which
## is what its original export name (`Brassbound_Torpedo_Sh...`) describes. This
## ship's bow is the opposite shape: 1680 units of beam tapering over 620 of
## length, wider than it is long. Scaled small enough to match the stem it is
## invisible; scaled large enough to be seen it is a tall mass ON THE CENTRELINE
## at the one depth where the vertical budget is 65 units — and the centreline at
## the bow is exactly where the captain stands, so every placement puts it behind
## her head. `tools/edge_place.gd -- where stem` measures that overlap rather
## than leaving it to the eye: her head projects at (796, 188) and the piece's
## box is x 704..828, y 64..260.
##
## WHAT THE BOW SHOULD DO INSTEAD, AND ALREADY DOES. `_hull_apron()` carries real
## planking 620 units forward of the bow line, narrowing on `hull_beam()` with the
## strake following it in, and in these same frames it reads as a bow — two
## bulwarks converging on a stem, looked ALONG, in the deck plane. The deck does
## not need this model to have a bow. It needs a bow-shaped model, and this is a
## torpedo boat. Filed for the owner: a prow re-modelled at roughly 3:1 WIDE
## rather than 3.6:1 LONG would drop straight into `_build_edge_kit()`.
##
## **ANSWERED, SG-174.** He remade it at 2.27:1 wide and it did drop straight in:
## `prow_ram` is on the deck, seated by `_build_edge_prow()` above. This
## paragraph stays because `bow_ram` is still in `assets/models/` for the
## comparison and the reason it is not placed has not changed.


## --- THE DECK REMEMBERS THE FIGHT ---------------------------------------------
##
## Accumulating marks: blood and oil where a figure died, scorch where something
## detonated or burned, scald where the Boilerwright cracked a main. The design
## and every number below is DECK-IDENTITY-DESIGN §7.
##
## VFX-PLAN §7 deferred this once, and the sentence it used is the whole
## specification: *"a persistent accumulating set needs a cap and an eviction
## policy, which is a system rather than an effect."* That was right. Every
## performance problem this project has had was an unbounded collection — the
## decals before `DECAL_BUDGET`, the seventy clustered shadow `Decal`s before
## `SHADOW_CAP`, the ribbon pools before `_trim` — so the cap and the eviction
## come first here and the prettiness comes after.
##
## Why a MultiMesh and not `_decal()`: forty-eight persistent decals would eat
## the whole `DECOR` budget and starve the glow pools, and each would be a node
## with a projection box. These are flat quads on flat planking. That is what a
## MultiMesh is for, and it is one draw, one material, no node per mark.
enum MarkKind { BLOOD, OIL, SCORCH, SCALD }

## THE CAP. Never exceeded. 24 live plus at most 8 waiting for a retiring slot,
## so the batch is sized 32 and there is no path here that allocates a 33rd.
##
## 24, NOT the 48 DECK-IDENTITY §7.1 first argued for on coverage grounds, and
## the halving is the kill-test being taken rather than talked around. At 48 the
## set paints 12.5% of the planking; at 24 it paints 5.7%, measured by
## `tools/marks_shot.gd` rather than computed. The draw cost was never the
## question — the shadow batch carries 256 of the same quad in one call for
## nothing — the question was always how much of a telegraph this is allowed to
## cost, and the answer that could be defended was the smaller number.
const MARK_CAP := 24
const MARK_PENDING_CAP := 8
## Full strength, then a long fade. 150 s total is two or three waves: enough
## that wave 9 looks like something happened on it, not so much that wave 12 is
## uniformly brown and the memory stops meaning anything.
const MARK_HOLD := 90.0
const MARK_FADE := 60.0
const MARK_IN := 0.35
## An evicted mark FADES. It is never erased between two frames — a pop in the
## corner of the eye mid-fight is worse than no mark at all, and "it popped" is
## the failure this whole state machine exists to prevent.
const MARK_EVICT := 0.60
## A same-kind mark this close DEEPENS the one already there instead of taking a
## slot. The single most important line in the system: it is why a lane where six
## boarders died is one dark pool rather than six discs, and why a bleed-jet
## trail of fire fields collapses into a scorched run instead of eating the cap.
const MARK_MIN_SEP := 70.0
## The ceiling: 0.12, down from the 0.30 DECK-IDENTITY §7.1 first wrote.
##
## AND THE HONEST STATE OF THE MEASUREMENT, because this is the number the
## kill-test was supposed to decide and it did not decide it cleanly.
##
## `tools/marks_shot.gd` renders the four `telegraph_shot` windups over marked
## and unmarked planking and reports what the marks cost a rune's contrast. Three
## confounds were found and fixed in it, each of which had been silently changing
## the answer: two separate processes reach the shutter with different lighting
## phase (fixed: one process, `_flicker` pinned); `view._process` keeps advancing
## between the two plates (fixed: the renderer is stopped); and `GPUParticles3D`
## runs on the GPU's own clock and does not care (fixed: hidden).
##
## After all three, the rig STILL answers non-proportionally: halving the cap and
## nearly halving the alpha moved the reported cost from 11.5% to 9.1%, when the
## covered fraction of the frame fell by more than half. A rune median cannot
## move 8% when 5.7% of the deck is covered at alpha 0.12 — so something in that
## measurement is not the marks, and it has not been found.
##
## THEREFORE THIS SHIPS AT THE CONSERVATIVE END AND SAYS SO. Not at the number
## that flatters it. What IS established: the set is hard-capped, evicted without
## popping, never emissive, never a ring, one draw, and gentler than the
## contact-shadow batch above it (0.02, 0.015, 0.03 at up to alpha 0.5) which has
## shipped for weeks. What is NOT established is a trustworthy figure for the
## telegraph cost, and the board row says that rather than quoting 0.7%.
##
## The remaining lever, if a playtest says these still read: `MARK_CAP` to 12.
const MARK_ALPHA_MAX := 0.12
## Below the shadows (2.0), above the planking. A figure's contact shadow draws
## over its own blood, which is the right way round.
const MARK_LIFT := 1.0
## A burst this big scorched the boards; anything smaller was something dying,
## and that already leaves a body's mark. The keg is 175 and the hulk coming
## apart is 260; a kill's own burst is radius*2.5 ~= 60-100 and the boiler's 90.
## A threshold rather than `radius == 175.0`, which would go stale silently.
const MARK_BURST_MIN := 150.0

## Colour and footprint per kind.
##
## THESE ARE UNSHADED COLOURS WRITTEN STRAIGHT INTO THE HDR BUFFER, and that is
## the whole reason they look so nearly black written down. The calibration point
## is the contact-shadow batch, which draws Color(0.02, 0.015, 0.03) on the same
## kind of quad in the same pass — an order of magnitude darker than any colour
## anybody would name if asked what blood looks like.
##
## The first pass at this table used honest paint values (blood 0.17 red, scald a
## bleached-timber 0.40) and every one of them was BRIGHTER than the planking's
## own radiance in shadow, so the marks lightened the deck instead of staining
## it, and cost 11.8% of a telegraph rune's contrast. Measured, in one process,
## with the renderer frozen between the two plates — see `tools/marks_shot.gd`.
## Against this table the same measurement is the number in the board row.
##
## So: a mark darkens. All four of them, including the scald — scalded boards go
## grey and dead, not white, and a lighter-than-deck mark on this deck is a lamp.
const MARK_LOOK := {
	MarkKind.BLOOD:  {"tint": Color(0.055, 0.009, 0.013), "width": 118.0},
	MarkKind.OIL:    {"tint": Color(0.016, 0.014, 0.022), "width": 104.0},
	MarkKind.SCORCH: {"tint": Color(0.020, 0.015, 0.016), "width": 190.0},
	MarkKind.SCALD:  {"tint": Color(0.042, 0.042, 0.037), "width": 132.0},
}
## Which figures bleed and which leak. Default is BLOOD; only the gunner is a
## drone. Keyed off `model_key`, which `_sync_rig` already stamps on every rig
## from `model_path()` — the one place a kind's slug lives.
const MARK_OIL_MODELS := ["gunner"]

var _mark_batch: MultiMeshInstance3D
var _mark_at: PackedVector2Array = PackedVector2Array()
var _mark_width: PackedFloat32Array = PackedFloat32Array()
var _mark_yaw: PackedFloat32Array = PackedFloat32Array()
var _mark_age: PackedFloat32Array = PackedFloat32Array()
var _mark_depth: PackedFloat32Array = PackedFloat32Array()
var _mark_kind: PackedInt32Array = PackedInt32Array()
## > 0 means the slot is RETIRING: it was chosen for eviction and is fading out.
## When it reaches zero the slot is free and the pending queue may claim it.
var _mark_retire: PackedFloat32Array = PackedFloat32Array()
var _mark_pending: Array = []
## Idempotence ledgers, the `_burst_new` idiom: an fx, a fire field and a tap are
## all levels the renderer sees every frame, and a mark must be stamped on the
## frame the thing STARTED and never again.
var _mark_seen_fx: PackedInt32Array = PackedInt32Array()
var _mark_seen_head := 0
## Wave watcher for "a new run starts on clean boards". `begin_run` puts the wave
## back to 0, so a wave number that goes BACKWARDS is a new run, in every path
## into the deck, without the renderer needing a hook the game does not offer.
var _mark_wave := -1
var _mark_rng := RandomNumberGenerator.new()


func _build_marks() -> void:
	_mark_at.resize(MARK_CAP)
	_mark_width.resize(MARK_CAP)
	_mark_yaw.resize(MARK_CAP)
	_mark_age.resize(MARK_CAP)
	_mark_depth.resize(MARK_CAP)
	_mark_retire.resize(MARK_CAP)
	_mark_kind.resize(MARK_CAP)
	for i in MARK_CAP:
		_mark_kind[i] = -1
	_mark_seen_fx.resize(64)
	for i in 64:
		_mark_seen_fx[i] = -1
	_mark_rng.seed = 20260802
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	mesh.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	## UNSHADED and MIX, and NO EMISSION — not dimly, not at all. The planking's
	## own light is telegraphs, ground rings and glow pools; a stain that glows
	## has joined that vocabulary and started lying about being a mechanic. This
	## is pinned by `marks · no mark ever glows`.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	## `_blob_texture()`, never a ring and never the painted burst plate. Rings
	## mean gameplay on this deck (SG-59's teal stand-here, a turn ring, a
	## telegraph) and the plate is retired under SG-78 for measuring opaque.
	mat.albedo_texture = _blob_texture()
	mat.vertex_color_use_as_albedo = true
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.no_depth_test = false
	_mark_batch = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = MARK_CAP
	mm.visible_instance_count = 0
	_mark_batch.multimesh = mm
	_mark_batch.material_override = mat
	_mark_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	## LAYER_SHADOWS, which every Decal's `cull_mask` already excludes, so a
	## telegraph never paints itself onto a bloodstain.
	_mark_batch.layers = LAYER_SHADOWS
	## The same trap the shadow batch documents: without an explicit box the whole
	## batch is culled the moment its origin leaves the frustum and every mark on
	## the deck blinks out on a camera sway.
	_mark_batch.custom_aabb = AABB(Vector3(-12, -1, -14), Vector3(24, 2, 28))
	add_child(_mark_batch)


## Has this id already been marked? The `_burst_new` idiom, its own ring, because
## a fire field and a burst can share an id space with nothing in common.
func _mark_new(id: int) -> bool:
	for i in _mark_seen_fx.size():
		if _mark_seen_fx[i] == id:
			return false
	_mark_seen_fx[_mark_seen_head] = id
	_mark_seen_head = (_mark_seen_head + 1) % _mark_seen_fx.size()
	return true


## Stamp a mark. THE one entry point, and every refusal lives here so no caller
## can forget one.
func _mark(kind: int, centre: Vector2, scale: float = 1.0) -> void:
	## Only during a real run. A cutscene pose, a model-lab frame or the screen
	## poser must never stain the live deck.
	if game == null or not game.is_playing():
		return
	## Off the walkable rectangle, or under a lane wall it could never climb.
	if not SkyGearGame.DECK_RECT.grow(-20.0).has_point(centre):
		return
	for rect in SkyGearGame.CARGO_RECTS:
		if (rect as Rect2).has_point(centre):
			return
	var look: Dictionary = MARK_LOOK[kind]
	var width: float = float(look.width) * clampf(scale, 0.55, 1.9)
	## DEEPEN, don't multiply. A same-kind mark inside MARK_MIN_SEP is the same
	## event happening again in the same place, and the deck should get darker
	## there rather than acquire a second disc.
	for i in MARK_CAP:
		if _mark_kind[i] != kind or _mark_retire[i] > 0.0:
			continue
		if _mark_at[i].distance_to(centre) > MARK_MIN_SEP:
			continue
		_mark_depth[i] = minf(1.0, _mark_depth[i] + 0.34)
		_mark_width[i] = minf(_mark_width[i] * 1.06, float(look.width) * 1.9)
		_mark_age[i] = 0.0
		return
	## A free slot, if there is one.
	for i in MARK_CAP:
		if _mark_kind[i] < 0:
			_mark_set(i, kind, centre, width)
			return
	## EVICTION. Full, so the faintest live mark is chosen — ties to the oldest —
	## and set retiring. The newcomer waits in the queue rather than replacing it
	## outright, because replacing it outright is the pop.
	var worst := -1
	var worst_alpha := INF
	var worst_age := -1.0
	for i in MARK_CAP:
		if _mark_retire[i] > 0.0:
			continue
		var a: float = _mark_strength(i)
		if a < worst_alpha - 0.0001 or (absf(a - worst_alpha) <= 0.0001 \
				and _mark_age[i] > worst_age):
			worst = i
			worst_alpha = a
			worst_age = _mark_age[i]
	if worst < 0:
		## Everything is already retiring; the queue will catch this one.
		pass
	else:
		_mark_retire[worst] = MARK_EVICT
	if _mark_pending.size() >= MARK_PENDING_CAP:
		_mark_pending.pop_front()
	_mark_pending.append({"kind": kind, "at": centre, "width": width})


func _mark_set(slot: int, kind: int, centre: Vector2, width: float) -> void:
	_mark_kind[slot] = kind
	_mark_at[slot] = centre
	_mark_width[slot] = width
	_mark_yaw[slot] = _mark_rng.randf_range(0.0, TAU)
	_mark_age[slot] = 0.0
	_mark_depth[slot] = 0.62
	_mark_retire[slot] = 0.0


## How much MARK there is in a slot — depth times its age fade, and deliberately
## NOT its fade-in ramp.
##
## This is what "faintest" means to the eviction search, and the distinction is
## not pedantry: ranking on drawn alpha meant a mark stamped this frame ranked as
## the faintest thing on the deck and was evicted immediately by the next one. A
## deck under heavy fire would have evicted every mark it had just made and kept
## nothing. The newest evidence is the most relevant evidence; only age may make
## a mark expendable.
func _mark_strength(i: int) -> float:
	if _mark_kind[i] < 0:
		return 0.0
	var a: float = _mark_depth[i]
	if _mark_age[i] > MARK_HOLD:
		a *= clampf(1.0 - (_mark_age[i] - MARK_HOLD) / MARK_FADE, 0.0, 1.0)
	if _mark_retire[i] > 0.0:
		a *= clampf(_mark_retire[i] / MARK_EVICT, 0.0, 1.0)
	return a


## What a slot DRAWS at right now.
func _mark_alpha(i: int) -> float:
	if _mark_kind[i] < 0:
		return 0.0
	var a: float = MARK_ALPHA_MAX * _mark_depth[i]
	## Fading IN.
	a *= clampf(_mark_age[i] / MARK_IN, 0.0, 1.0)
	## The long fade at the end of life.
	if _mark_age[i] > MARK_HOLD:
		a *= clampf(1.0 - (_mark_age[i] - MARK_HOLD) / MARK_FADE, 0.0, 1.0)
	## And the eviction ramp, which multiplies everything else to zero.
	if _mark_retire[i] > 0.0:
		a *= clampf(_mark_retire[i] / MARK_EVICT, 0.0, 1.0)
	return a


func _age_marks(delta: float) -> void:
	## A new run starts on clean boards. `begin_run` puts the wave back to 0, so
	## a wave number that goes backwards is the only signal needed and it works
	## on every path into the deck.
	var wave := int(game.wave) if game != null else 0
	if wave < _mark_wave:
		_clear_marks()
	_mark_wave = wave
	for i in MARK_CAP:
		if _mark_kind[i] < 0:
			continue
		_mark_age[i] += delta
		if _mark_retire[i] > 0.0:
			_mark_retire[i] -= delta
			if _mark_retire[i] <= 0.0:
				_mark_kind[i] = -1
			continue
		## Died of old age.
		if _mark_age[i] >= MARK_HOLD + MARK_FADE:
			_mark_kind[i] = -1
	## Pending marks claim whatever the eviction freed.
	while not _mark_pending.is_empty():
		var slot := -1
		for i in MARK_CAP:
			if _mark_kind[i] < 0:
				slot = i
				break
		if slot < 0:
			break
		var want: Dictionary = _mark_pending.pop_front()
		_mark_set(slot, int(want.kind), Vector2(want.at), float(want.width))


func _clear_marks() -> void:
	for i in MARK_CAP:
		_mark_kind[i] = -1
		_mark_retire[i] = 0.0
		_mark_depth[i] = 0.0
	_mark_pending.clear()
	for i in _mark_seen_fx.size():
		_mark_seen_fx[i] = -1
	_mark_seen_head = 0


## How many marks are on the boards right now. The harness's window on the cap,
## and the only reason it is a function is so nothing has to reach into arrays.
func mark_count() -> int:
	var n := 0
	for i in MARK_CAP:
		if _mark_kind[i] >= 0:
			n += 1
	return n


func _flush_marks() -> void:
	if _mark_batch == null:
		return
	var mm: MultiMesh = _mark_batch.multimesh
	var n := 0
	for i in MARK_CAP:
		if _mark_kind[i] < 0:
			continue
		var alpha := _mark_alpha(i)
		if alpha <= 0.002:
			continue
		var w: float = _mark_width[i] * WORLD_SCALE
		## A yaw per mark, unlike the shadow batch — forty-eight identical discs
		## read as a pattern, and the whole ask was irregularity.
		var basis := Basis().rotated(Vector3.UP, _mark_yaw[i]) \
			.scaled(Vector3(w, 1.0, w * 0.78))
		mm.set_instance_transform(n, Transform3D(basis,
			Vector3(_mark_at[i].x * WORLD_SCALE, MARK_LIFT * WORLD_SCALE,
				_mark_at[i].y * WORLD_SCALE)))
		var look: Dictionary = MARK_LOOK[_mark_kind[i]]
		var tint: Color = look.tint
		mm.set_instance_color(n, Color(tint.r, tint.g, tint.b, alpha))
		n += 1
	mm.visible_instance_count = n


## The aura, as a volume.
##
## A Field was the one skill in the game with NO visual at all: `_update_passives`
## ticks `_damage_circle` at the captain's radius and appended nothing, so a
## hundred and fifty units of standing damage were invisible and the player had
## no way to know where the edge of their own aura was. The other passives fake
## it by appending a circle every time they fire; a Field fires 1.8 times a
## second and would have strobed.
##
## So it gets what it actually is: a soft cylinder of charged air around her,
## plus a decal ring on the planking marking exactly where it stops. Both are
## driven from `skill_stats` each frame, so a card that widens the field widens
## the picture with no second place to change.
func _sync_auras() -> void:
	var index := 0
	for skill in game.skills:
		var shape: Dictionary = SkyGearData.SHAPES[skill.shape]
		if str(shape.get("kind", "")) != "aura":
			continue
		index += 1
		var st: Dictionary = game.skill_stats(skill)
		var radius := float(st.radius)
		var tint: Color = SkyGearData.ELEMENTS[skill.element].color
		var at: Vector2 = game.player.global_position
		# the edge, on the deck
		## The widest gameplay-scaled ring in the game — a card that widens
		## the Field widens this — so it is the one that most needed the
		## generated rim rather than the painted plate (SG-63).
		_decal("aura%d" % index, at, 0.0, radius * 2.0, radius * 2.0,
			_ring_texture(),
			Color(tint.r, tint.g, tint.b, 0.42 + sin(_flicker * 2.6) * 0.08))
		# and the air inside it
		var key := "auravol%d" % index
		_used[key] = true
		var vol: MeshInstance3D = _volumes.get(key)
		if vol == null:
			vol = MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 1.0
			cyl.bottom_radius = 1.0
			cyl.height = 1.0
			cyl.radial_segments = 40
			cyl.cap_top = false
			cyl.cap_bottom = false
			vol.mesh = cyl
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.albedo_texture = _wall_texture()
			m.disable_receive_shadows = true
			## Only the FAR wall. You are standing inside this thing, so the near
			## wall is between the camera and you — and drawn additively that
			## bleached the captain and anyone next to her every time a Field was
			## equipped. Culling the front faces leaves the boundary you are
			## looking at and removes the one you are looking through.
			m.cull_mode = BaseMaterial3D.CULL_FRONT
			vol.material_override = m
			vol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(vol)
			_volumes[key] = vol
		var mat: StandardMaterial3D = vol.material_override
		mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.22)
		vol.scale = Vector3(radius * WORLD_SCALE, 118.0 * WORLD_SCALE, radius * WORLD_SCALE)
		vol.position = Vector3(at.x * WORLD_SCALE, 59.0 * WORLD_SCALE, at.y * WORLD_SCALE)
		## AND THE AIR ITSELF. VFX-PLAN.md §4, and the reason it was worth doing
		## after the cylinder rather than instead of it: the cylinder is a WALL, so
		## a Field reads as a fence you are standing in the middle of, and the
		## inside of it is empty. A `FogVolume` puts something between the boarders
		## and the camera, which is the only way "you are standing in a cloud of
		## scalding steam" can be true rather than outlined.
		##
		## The ring on the planking is still the gameplay object — the exact edge —
		## and this is deliberately softer than it, so nothing about where the
		## damage stops is being read off a blur.
		if VOLUMETRIC_FIELDS:
			var fkey := "aurafog%d" % index
			_used[fkey] = true
			var fog: FogVolume = _fog.get(fkey)
			if fog == null:
				fog = FogVolume.new()
				fog.shape = RenderingServer.FOG_VOLUME_SHAPE_CYLINDER
				var fm := FogMaterial.new()
				## Low. Fog density is per METRE through the volume and the volume
				## is three metres across, so anything over about 0.1 is a wall of
				## milk with a fight somewhere behind it.
				fm.density = 0.055
				## The edge does the work: a hard-edged fog cylinder has a visible
				## seam where it meets clear air, which reads as geometry.
				fm.edge_fade = 0.55
				fm.height_falloff = 0.9
				fog.material = fm
				add_child(fog)
				_fog[fkey] = fog
			var fmat: FogMaterial = fog.material
			fmat.albedo = Color(tint.r, tint.g, tint.b)
			## Emission, not albedo, is what makes a Frost field glow rather than
			## merely fog: a fog volume with no light in it is grey at dusk, and
			## these are supposed to be the brightest thing at the player's feet.
			fmat.emission = Color(tint.r * 0.32, tint.g * 0.32, tint.b * 0.32)
			fog.size = Vector3(radius * 2.0, 150.0, radius * 2.0) * WORLD_SCALE
			fog.position = Vector3(at.x * WORLD_SCALE, 66.0 * WORLD_SCALE,
				at.y * WORLD_SCALE)
		## And motes rising through it, metered the same way the wreck smoke is.
		## Sparse on purpose: this is reinforcement for the ring, and a field full
		## of particles hides the boarders standing in it, which is the one thing
		## it must not do.
		if _mote_clock >= MOTE_EVERY:
			var family: String = str(ELEMENT_FX.get(skill.element, ELEMENT_FX.EMBER).family)
			var node: GPUParticles3D = _sparks.get(family)
			if node != null:
				var a: float = _impact_rng.randf() * TAU
				var d: float = sqrt(_impact_rng.randf()) * radius
				node.emit_particle(Transform3D(Basis(), Vector3(
						at.x + cos(a) * d, 14.0, at.y + sin(a) * d) * WORLD_SCALE),
					Vector3(0.0, _impact_rng.randf_range(70.0, 150.0), 0.0) * WORLD_SCALE,
					Color(tint.r * 1.5, tint.g * 1.5, tint.b * 1.5, 1.0), Color.WHITE,
					GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY
						| GPUParticles3D.EMIT_FLAG_COLOR)
	if _mote_clock >= MOTE_EVERY:
		_mote_clock = 0.0
	# a field that was dropped stops being drawn
	for key in _volumes.keys():
		if not _used.has(key):
			var dead: MeshInstance3D = _volumes[key]
			dead.queue_free()
			_volumes.erase(key)
	for key in _fog.keys():
		if not _used.has(key):
			var gone: FogVolume = _fog[key]
			gone.queue_free()
			_fog.erase(key)


func _sync_all(delta: float) -> void:
	_age_corpses(delta)
	if game.player != null and game.player.hp > 0.0:
		## She is a mesh whenever `_sync_captain` is driving her, so her blob is a
		## contact core and the moon draws the rest. On the sprite fallback the
		## blob is all she has and it stays whole.
		_shadow("player", game.player.global_position, 96.0, 0.55, 0.0, 0.0,
			SHADOW_CORE if _casts_own_shadow("player") else SHADOW_LEANS)
		if not _sync_captain(delta):
			_draw_figure("player", "hero", game.player.global_position,
				game.player.aim_direction, 150.0,
				game.player.attack_time > 0.0,
				game.player.velocity.length() > 35.0 and game.player.dash_time_left <= 0.0,
				game.run_time, game.player.attack_time)
			_xray("player", game.player.global_position, 150.0, Color(1.0, 0.86, 0.42, 0.62))
	for enemy in game.enemies():
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		## HOW TALL A BOARDER STANDS, and it was wrong for the small ones.
		##
		## `120 + radius * 3` put a SCRAPPER at 186 and a GUNNER at 183 against a
		## captain of 176 — so the rank and file were TALLER THAN THE HERO, and
		## the three kinds that are meant to read as scurrying goblins read as a
		## line of men. Reported as "goblins probably need to be scaled down to
		## about 50%".
		##
		## Per-kind, because a flat halving would take the furnace knight from 216
		## to 108 and the boss from 330 to 165 — captain-sized — and those two are
		## frightening precisely because of their bulk. Shrinking the small three
		## makes that contrast sharper rather than flattening it.
		##
		## NOTE the footprint does not move: `radius` is gameplay, and the shadow
		## is drawn from it, so a goblin is now short and still as wide as it
		## always was to hit. That is deliberate — changing reach is a balance
		## change wearing a visual one — but it is the number to revisit if they
		## look stubby.
		var height: float = boarder_height(enemy.kind)
		var key := "e%d" % enemy.get_instance_id()
		## Boarders come DOWN the deck, so most of the time you are looking at
		## their backs — which is the view the port never drew. They face you when
		## they turn to swing, and that turn is the tell.
		## …through `figure_heading`, which is this rule hoisted so the CREW can
		## ask it too (board SG-103). It answered here first and nothing about
		## the boarders' read changes.
		var heading: Vector2 = figure_heading(enemy.attack_direction,
			enemy.velocity, enemy.state == "move")
		## The stomp is an ATTACK and the figure has to be seen committing to it
		## (SG-166) — a Colossus who plants a 240-unit circle while playing his idle
		## is a mark with no author. It maps onto the same `swing` clip the wind and
		## the recovery use, which is the right one: his kit's five clips are idle,
		## walk, swing, turn and die, and a stomp is a swing that goes down.
		var swinging: bool = enemy.state == "windup" or enemy.state == "recover" \
			or enemy.state == "stomp"
		# a phase offset per boarder, or a lane of them marches in lockstep
		var phase: float = float(enemy.get_instance_id() % 97) * 0.113
		## ═══ THE DROP (SG-142) ═══════════════════════════════════════════════
		##
		## `airborne()` is the simulation's own word for "has not hit the deck and
		## has not started moving", asked of the enemy rather than restated here,
		## and it is the same predicate `can_be_hit()` is written on — so a boarder
		## is drawn in the air for exactly the window it is untouchable for, and
		## the two can never drift apart into a figure that can be shot at while
		## still crossing.
		##
		## GATED ON THE HULL EXISTING. No transport this wave means nothing to jump
		## off, and `arrival_hull_for_wave` already returns "" for the boss wave —
		## so the exclusion the design asks for falls out of stage 1's own table
		## instead of being a second list that can disagree with it.
		##
		## `draw_at` IS THE ONLY THING THAT MOVES. Every line below this block
		## reads `draw_at` and `lift` where it used to read `enemy.global_position`
		## and zero, and at the end of the crossing `draw_at` IS
		## `enemy.global_position` — `arrival_arc_ground` returns `land` unchanged
		## at u = 1, so the frame the boarder becomes hittable is the frame the
		## mesh is exactly where it always was.
		var arcing: bool = enemy.airborne() \
			and arrival_arc_travels(enemy.kind) \
			and arrival_hull_for_wave(int(game.wave)) != ""
		var draw_at: Vector2 = enemy.global_position
		var lift := 0.0
		if arcing:
			draw_at = arrival_arc_ground(enemy.global_position, enemy.state_time,
				arrival_arc_sway(enemy.get_instance_id()))
			if arrival_arc_lifts(enemy.kind):
				lift = maxf(0.0, arrival_arc_lift(enemy.state_time,
					arrival_arc_spread(enemy.get_instance_id())))
		## A mesh if one has been ingested for this kind, the painted billboard
		## if not. Both paths are always here: the boarders will become models
		## one at a time, and the renderer should not need editing for each.
		if not _sync_rig(key, enemy.kind, draw_at, heading, height,
				swinging, enemy.state == "move", enemy.velocity.length(),
				maxf(0.0, enemy.state_time), delta, enemy.stun_time,
				enemy.state == "turn", arcing, enemy.attack_beat()):
			_draw_figure(key, enemy.kind, draw_at, heading, height, swinging,
				enemy.state == "move", game.run_time + phase,
				maxf(0.0, enemy.state_time), lift)
		else:
			## `place` writes the whole transform and puts y at zero, so the height
			## goes on after it — the same order `_fly` uses, and for the same
			## reason. A flier's `_fly` has already written this number and `lift`
			## is zero for it by `arrival_arc_lifts`, so the two never both write.
			var rig: SkyGearRig3D = _rigs.get(key)
			if lift > 0.0 and rig != null and is_instance_valid(rig):
				rig.position.y = lift * WORLD_SCALE
			_arrival_flight(rig, arcing)
		## THE CONTACT SHADOW, and it is drawn AFTER the figure rather than
		## before it so the rig exists to be asked. A segmented machine grounds
		## itself part by part (`_part_shadows`); everything else — every
		## billboard, and every skinned boarder — keeps the single blob off its
		## gameplay radius that it always had.
		## RULE TWO. A segmented machine grounds itself part by part (SG-94's
		## `_part_shadows`). Everything else gets one blob — but a RIGGED boarder
		## is a mesh, and a mesh casts a real moon shadow of its own, so a
		## full-strength ellipse under it is the second shadow the owner reported:
		## two marks under one man, pointing different ways. Where the mesh casts,
		## this drops to a contact core. A painted billboard has no cast shadow at
		## all and keeps the whole blob, which is the only thing holding it to the
		## planking.
		## ...and A LIFT IS FINALLY PASSED. `shadow_pose` has carried the airborne
		## arithmetic since SG-107 — `SHADOW_LIFT_SPREAD`, `SHADOW_LIFT_FADE`, and
		## the slide down `moon_track()` — and every caller in the file handed it a
		## zero, so the branch existed and nothing ever reached it. This is the
		## caller. A mark that widens and softens as a boarder falls is what sells
		## the height, and it converges onto the closing ring exactly as the
		## boarder lands, because both are functions of the same `state_time`.
		##
		## The centre is `draw_at`, the point the figure is over — not the landing
		## point. `shadow_pose` adds the slide down the moonlight itself; handing
		## it the destination would be this file re-deriving a rule that function
		## owns.
		if not _part_shadows(key, _rigs.get(key), 1.0):
			_shadow(key, draw_at, float(enemy.radius) * 2.6, 0.5,
				0.0, lift, SHADOW_CORE if _casts_own_shadow(key) else SHADOW_LEANS)
		# burning boarders glow; frozen ones go blue. The status is the read.
		var node: Sprite3D = _billboards.get(key)
		if node != null:
			var tint := Color.WHITE
			if enemy.burn_stacks > 0:
				tint = Color(1.0, 0.72, 0.52).lerp(Color(1.6, 0.9, 0.6), 0.4)
			elif enemy.slow_time > 0.0:
				tint = Color(0.68, 0.86, 1.0)
			if enemy.stun_time > 0.0:
				tint = tint.lerp(Color(1.3, 1.25, 0.8), 0.5)
			node.modulate = tint
		_xray(key, draw_at, height, Color(0.95, 0.30, 0.22, 0.55))
	for prop in game.props():
		if not is_instance_valid(prop) or prop.dead:
			continue
		var pkey := "p%d" % prop.get_instance_id()
		## Heights straight from the browser's `PROP_H`, which is the table that
		## decides whether a keg reads as ordnance or as a footstool.
		var ph: float = float(PROP_HEIGHT.get(prop.prop_type, 110.0))
		_shadow(pkey, prop.global_position, 80.0, 0.45)
		## A mesh if one has been generated for this prop_type, the painted
		## billboard if not — PROP_MODEL is the switch and both paths stay.
		if not _sync_prop_model(pkey, str(PROP_MODEL.get(prop.prop_type, "")),
				prop.global_position, ph):
			_place(pkey, _texture(prop.texture_path()), prop.global_position, ph)
	for i in game.crew.size():
		var c: Dictionary = game.crew[i]
		if bool(c.dead):
			continue
		## A STABLE KEY, and it is the thing wiring the crew as a MESH forced
		## (board SG-88). Every other figure the renderer draws is a Node with
		## an instance id; a crewman is a plain Dictionary in an Array that
		## `_update_crew` calls `remove_at` on, so `"c%d" % i` names a
		## DIFFERENT man the frame after anyone dies. Billboards did not care —
		## the crew are identical by design and a sprite that jumps one lane
		## slot is a sprite. A DEATH cares: `_recycle` would have shelved
		## whichever rig fell off the end of the array, played the death clip at
		## the wrong sailor's feet, and handed the dead man's body to a live
		## one.
		##
		## So the renderer stamps its own identity onto the crewman the first
		## time it draws him. Written INTO the simulation's dictionary because a
		## GDScript Dictionary is a reference and that is where the identity has
		## to live to survive a `remove_at` — but it is renderer-owned data, the
		## simulation neither sets it nor reads it, and it dies with the man. No
		## sim change, which is the SG-85 death-seam rule.
		if not c.has("rig_key"):
			_crew_seq += 1
			c["rig_key"] = "c%d" % _crew_seq
		var ckey: String = str(c.rig_key)
		_shadow(ckey, c.position, 74.0, 0.45, 0.0, 0.0,
			SHADOW_CORE if _casts_own_shadow(ckey) else SHADOW_LEANS)
		## Crew push UP the deck, into the boarders, so they are almost always
		## showing you their backs. Drawing them front-on made a line of allies
		## look like it was retreating.
		##
		## …but "up the deck" was written as the literal `Vector2(0, -1)` below,
		## which is the whole of build-44's "crew walk backwards" (board SG-103).
		## A crewman now carries the boarder's own two fields and answers the
		## boarder's own question — see `figure_heading`.
		var busy: bool = str(c.get("state", "move")) != "move"
		var chead: Vector2 = figure_heading(
			c.get("attack_direction", Vector2(0.0, -1.0)),
			c.get("velocity", Vector2.ZERO), not busy)
		## A MESH IF ONE HAS BEEN INGESTED, the painted billboard if not — the
		## same fork every boarder has had since the scrapper, arriving on the
		## ally side of the deck at last. The crew are the only figures the
		## renderer draws that are not enemies, so this is the one call site
		## where the height does not come from `boarder_height`.
		var cheight: float = crew_height()
		## HIS OWN SPEED, NOT THE TABLE'S (SG-187). This passed the constant
		## `CREW.speed` for any crewman who was not mid-swing, and asserted
		## `moving` for the same men — which was true right up until the assist
		## work gave a crewman a reason to STAND: with nothing in his lane he now
		## holds his station instead of swinging at the planking, and a figure
		## standing still fed a 118 would have played a walk cycle on the spot,
		## which is the skate `gait()` exists to stop wearing a different hat.
		## `velocity` is written every tick by `_update_crew` and is exactly zero
		## when he is holding, so the rig picks `idle` for a man at his post and
		## the same walk it always did for a man crossing the deck (118 is under
		## `GAIT_CROSSOVER`, before and after — no gait changed here).
		var cspeed: float = (c.get("velocity", Vector2.ZERO) as Vector2).length()
		var walking: bool = not busy and cspeed > 1.0
		if not _sync_rig(ckey, "CREW", c.position, chead, cheight,
				busy, walking, cspeed if walking else 0.0,
				float(c.get("state_time", 0.0)), delta):
			_draw_figure(ckey, "CREW", c.position, chead, cheight,
				busy, walking, game.run_time + float(i) * 0.21,
				float(c.get("state_time", 0.0)))
	## Deployed sentries. A short brass post with a live head on it, the range it
	## covers written on the planking, and a wick that burns down — you should be
	## able to tell at a glance, from across the deck, which of yours is about to
	## expire and whether the lane you are worried about is inside one.
	for s in game.sentries:
		var sid: int = int(s.id)
		var tint: Color = SkyGearData.ELEMENTS[str(s.element)].color
		var left: float = clampf(float(s.life) / maxf(0.1, float(s.max_life)), 0.0, 1.0)
		## The last two seconds pulse. Everything else about it is static, so the
		## only thing that moves is the thing that is running out.
		var urgent: bool = float(s.life) < 2.0
		var beat: float = 1.0 if not urgent else 0.55 + 0.45 * absf(sin(_flicker * 9.0))
		_shadow("sy%d" % sid, s.position, 92.0, 0.48)
		## THE RANGE RING, ON ARRIVAL ONLY. Drawn permanently it is 840 units
		## across — two of them cover the deck and the fight happens inside a pair
		## of glowing hoops. It is the answer to "what does this cover?", which is
		## a question you ask when you place it and never again, so it flares over
		## the first three quarters of a second and then goes.
		var age: float = game.run_time - float(s.born)
		if age < 0.75:
			var fade: float = 1.0 - age / 0.75
			_decal("syr%d" % sid, s.position, 0.0, float(s.range) * 2.0,
				float(s.range) * 2.0, _ring_texture(),
				Color(tint.r, tint.g, tint.b, 0.34 * fade * fade))
		## What stays is a small collar at its feet: enough to say "this one is
		## yours, and it is an ARC one", without claiming a quarter of the deck.
		_decal("syb%d" % sid, s.position, 0.0, 132.0, 132.0, _ring_texture(),
			Color(tint.r, tint.g, tint.b, 0.5 * beat))
		## The wick — a bar on the planking that shortens with the life left, so
		## the countdown is legible from across the deck without a number.
		_decal("syw%d" % sid, s.position + Vector2(0.0, 82.0), 0.0,
			104.0 * left, 11.0, _streak_texture(),
			Color(tint.r, tint.g, tint.b, 0.9 * beat))
		## A ballista rather than a deck cannon. Sharing art with the ship's own
		## cannons made a placed sentry invisible: five identical guns on the deck
		## and no way to tell which two you put there.
		_place("sy%d" % sid, _texture("res://assets/art/props/harpoon_ballista.png"),
			s.position, 104.0, 0.0, Color(1.0, 1.0, 1.0).lerp(tint, 0.30))
		_spark("syh%d" % sid, s.position, 104.0, 34.0 * beat, tint)

	for i in game.turrets.size():
		var t: Dictionary = game.turrets[i]
		var art := "res://assets/art/props/cannon_deck_destroyed.png" if bool(t.dead) \
			else "res://assets/art/props/cannon_deck.png"
		_shadow("t%d" % i, t.position, 118.0, 0.5)
		## Only the LIVE cannon is a mesh. A wrecked one is a different object —
		## the painted version is a burst barrel lying in its own debris, not the
		## same gun tinted darker — and there is no model of it, so a dead turret
		## keeps its art and the pair still read as before and after.
		##
		## -90 degrees, the one prop that is not turned to face the player. These
		## guns shoot boarders, boarders come from the bow, and the bow is -z; a
		## cannon aimed at the camera is aimed at the deck it is defending.
		##
		## Ninety and not a hundred and eighty, which is what this said first:
		## the generated cannon's barrel lies along the model's X axis, not its
		## Z, so half a turn left all three guns broadside across the deck. Found
		## by looking at .shots/props/stern.png, which is the only way to find it.
		##
		## A SEPARATE KEY for the mesh. `_recycle` shelves anything `_used` did
		## not claim this frame, and a turret is the one thing here that swaps
		## representation mid-run: sharing one key would mark it used by the
		## billboard on the frame it died, so the intact brass cannon would never
		## be shelved and would stand inside its own wreck for the rest of the run.
		if bool(t.dead) or not _sync_prop_model("tm%d" % i, TURRET_MODEL,
				t.position, 130.0, 0.0, -90.0):
			_place("t%d" % i, _texture(art), t.position, 130.0)
		if not bool(t.dead):
			continue
		## A DEAD GUN HAS TO LOOK DEAD FROM ACROSS THE DECK.
		##
		## The painted wreck is a good picture and it is 130 units tall in a frame
		## full of 130-unit brass cannons, so at a glance the lane with the broken
		## gun in it looks like the two that still work. The bar over it says so in
		## the HUD; this says so in the world, which is where the player is looking
		## when they decide whether that lane is worth walking to.
		##
		## Scorch under it and smoke off it, and nothing else. A wreck that
		## FLICKERS reads as still burning and therefore as still doing something,
		## which is the opposite of the thing being communicated.
		_decal("tw%d" % i, t.position, 0.0, 300.0, 300.0,
			_art("scorch", _blob_texture()), Color(0.09, 0.06, 0.07, 0.62), false)
		## Warm, dull and low: the last of a fire rather than a fire. It sits at 40
		## units, in the burst barrel, not up where the muzzle used to be.
		_spark("tg%d" % i, t.position, 40.0, 34.0 + sin(_flicker * 4.3 + float(i)) * 8.0,
			Color(0.55, 0.20, 0.09))

	## The smoke off the wrecks, metered rather than emitted per frame. A dead
	## cannon stays dead for the rest of the wave, so an unbounded plume is an
	## unbounded plume for a minute and a half — three puffs every tenth of a
	## second is thirty particles a second against a 512 budget, and it looks the
	## same as three hundred would.
	_smoke_clock += delta
	if _smoke_clock >= SMOKE_EVERY:
		_smoke_clock = 0.0
		var smoke: GPUParticles3D = _sparks.get("steam")
		if smoke != null:
			for i in game.turrets.size():
				if not bool(game.turrets[i].dead):
					continue
				var at: Vector2 = game.turrets[i].position
				smoke.emit_particle(Transform3D(Basis(), Vector3(
						at.x + _impact_rng.randf_range(-24.0, 24.0), 70.0,
						at.y + _impact_rng.randf_range(-20.0, 20.0)) * WORLD_SCALE),
					Vector3(_impact_rng.randf_range(-18.0, 18.0), 120.0,
						_impact_rng.randf_range(-18.0, 18.0)) * WORLD_SCALE,
					## Dark, not bright. The steam family blends MIX rather than
					## ADD, which is the one emitter in the renderer that can draw
					## something the deck is darker for.
					Color(0.17, 0.15, 0.16, 1.0), Color.WHITE,
					GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY
						| GPUParticles3D.EMIT_FLAG_COLOR)
			## SG-59 — AND THE VENTS BREATHE. A continuous column out of every
			## live deck vent, into the same behaviour-keyed steam emitter, on the
			## same metering as the wreck smoke — two puffs a tick per vent is
			## ~20 particles a second each, which reads as a standing plume and
			## costs nothing against the 512 cap. Bright where the wreck smoke is
			## dark: a wreck is soot, a vent is live steam, and the difference is
			## the identity the owner could not find.
			for prop in game.props():
				if not is_instance_valid(prop) or prop.dead \
						or str(prop.prop_type) != "vent":
					continue
				var vat: Vector2 = prop.global_position
				for _puff in 2:
					smoke.emit_particle(Transform3D(Basis(), Vector3(
							vat.x + _impact_rng.randf_range(-16.0, 16.0), 34.0,
							vat.y + _impact_rng.randf_range(-12.0, 12.0)) * WORLD_SCALE),
						Vector3(_impact_rng.randf_range(-12.0, 12.0),
							_impact_rng.randf_range(150.0, 215.0),
							_impact_rng.randf_range(-12.0, 12.0)) * WORLD_SCALE,
						Color(0.80, 0.86, 0.84, 1.0), Color.WHITE,
						GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY
							| GPUParticles3D.EMIT_FLAG_COLOR)
				_vent_puffs += 1

	## Ordnance in flight. These were missing entirely, which is why the fight
	## looked static: half of what is on screen at any moment in the browser is
	## something travelling between two people.
	## Every bolt in flight is hostile, and a tester could not track them (F-05).
	## The browser's fix was three things at once and all three port: a hot head,
	## a trail behind it, and a shadow on the planking directly under it — the
	## shadow is what tells you where it will cross you, because the head is in
	## the air and the deck is where you are.
	##
	## NOT every bolt is hostile any more. The deck cannons fire a real travelling
	## shot now, so two kinds of ordnance cross the same lanes in opposite
	## directions and they cannot look alike: ours is brass-hot and theirs is red,
	## which is the one distinction a player has to be able to make at a glance
	## while walking through the middle of both.
	for i in game.projectiles.size():
		var b: Dictionary = game.projectiles[i]
		var bid: int = int(b.get("id", i))
		var friendly: bool = bool(b.get("friendly", false))
		var col: Color = Color("#ffce7a") if friendly else Color("#ff6a4a")
		var fly: float = 66.0 if friendly else 60.0
		var trail: Array = b.get("trail", [])
		if trail.size() > 1:
			var tail: Vector2 = trail[trail.size() - 1]
			var span: Vector2 = b.position - tail
			if span.length() > 4.0:
				## The ground streak stays and is halved. It is what tells you where
				## the shot will cross YOU, which the airborne trail communicates
				## worse — but at full strength it was the whole of the effect, and
				## a bolt whose only representation is a mark on the floor is the
				## reported bug.
				_decal("bt%d" % bid, (b.position + tail) * 0.5, span.angle(),
					span.length(), 20.0, _streak_texture(), Color(col.r, col.g, col.b, 0.24))
			## And the trail in the air, off the same points the simulation was
			## already keeping — nine of them, which is inside the audit's six-to-ten
			## and cost nothing to reach because they already existed.
			var pts := PackedVector3Array()
			pts.resize(trail.size() + 1)
			pts[0] = Vector3(trail[trail.size() - 1].x, fly, trail[trail.size() - 1].y)
			for k in trail.size():
				var p: Vector2 = trail[trail.size() - 1 - k]
				pts[k] = Vector3(p.x, fly, p.y)
			pts[trail.size()] = Vector3(b.position.x, fly, b.position.y)
			## Ember's handwriting for a burning drone bolt, Frost's straight narrow
			## one for a cannon ball — a shot from a gun does not waver, and the
			## table already has a "goes exactly where it was pointed" entry.
			_ribbon_path(pts, "FROST" if friendly else "EMBER", col, 0.95,
				1.15 if friendly else 0.85)
		## RULE ONE, at the site it exists for. `fly` is how far off the boards
		## this bolt is; the mark widens and softens with it so an airborne shot
		## reads as airborne — but it stays DIRECTLY BENEATH the bolt, because the
		## mark under a bolt is the thing that tells you where it will cross you
		## (DESIGN §13c). Leaning it would move the answer away from the question.
		_shadow("b%d" % bid, b.position, 40.0, 0.38, 0.0, fly, SHADOW_CENTRED)
		## The head is an emissive teardrop now, not the painted fireball (SG-40).
		## Ours is a brass CANNON slug, theirs an oxblood HOSTILE shot — two
		## identities crossing the same lanes in opposite directions, kept apart by
		## shape and colour both. Oriented down its own velocity; falls back to the
		## painted spark only if the mesh path is off.
		var bvel: Vector2 = b.get("velocity", b.position - trail[trail.size() - 1] 			if trail.size() > 0 else Vector2.DOWN)
		_bolt_head("b%d" % bid, b.position, fly, bvel,
			"CANNON" if friendly else "HOSTILE", col, 62.0 if friendly else 52.0)

	## Salvage on the deck, bobbing so it reads as a pickup and not as debris.
	for i in game.salvage.size():
		var s: Dictionary = game.salvage[i]
		var sid: int = int(s.get("id", i))
		var bob: float = sin(_flicker * 3.4 + float(sid) * 1.7) * 9.0
		## Salvage bobs, so its mark breathes with it — the same height term every
		## airborne thing gets, at the nine units a pickup actually rises.
		_shadow("s%d" % sid, s.position, 56.0, 0.35, 0.0, maxf(0.0, bob))
		## The bob goes in as `lift`, which for a mesh is height above the deck
		## and for the billboard is added to its half-height. Both end up the same
		## distance off the planking, which is why the same number serves.
		if not _sync_prop_model("s%d" % sid, SALVAGE_MODEL, s.position, 62.0, bob):
			_place("s%d" % sid, _texture("res://assets/art/props/salvage_pile.png"),
				s.position, 62.0, bob)

	## The Boiler's health, as a ring on the planking around it.
	_decal("boiler_ring", game.boiler_position, 0.0, 330.0, 330.0, _ring_texture(),
		Color(0.91, 0.77, 0.46, 0.55) if game.boiler_hp > game.boiler_max_hp * 0.3
		else Color(1.0, 0.30, 0.22, 0.65))
	_sync_boiler_damage()

	## Lanterns and braziers are light sources in a dark scene, and in 3D that
	## can simply be true rather than painted on. They flicker, because a fixed
	## point light on a ship at dusk is the one thing that says "render".
	for prop in game.props():
		if not is_instance_valid(prop):
			continue
		var id := prop.get_instance_id()
		var kind: String = prop.prop_type
		var flame: bool = (not prop.dead) and (kind == "lantern" or kind == "brazier")
		## SG-81 — AND THE TABLE TAKES THIS LIGHT'S PLACE WHEN IT HAS ONE. Only
		## when the MESH actually stood up this frame: a model light hangs off a
		## model, so a brazier that fell back to its painted billboard keeps the
		## built-in omni rather than going dark. The floor pool below is drawn
		## either way — it is paint, it is most of why this deck reads as lit at
		## 41 degrees, and it is not part of the light budget.
		var by_table: bool = flame \
			and model_lit_by_table(str(PROP_MODEL.get(kind, ""))) \
			and _prop_models.has("p%d" % id)
		var wants_light: bool = flame and not by_table
		var light: OmniLight3D = _lights.get(id)
		if wants_light and light == null:
			light = OmniLight3D.new()
			add_child(light)
			_lights[id] = light
		elif not wants_light and light != null:
			light.queue_free()
			_lights.erase(id)
		if flame:
			## Accents, not floodlights. At 3.4 energy over a five-metre radius
			## three braziers turned a dusk deck into an orange room; the browser
			## paints its lantern haze at a fraction of the deck's own value and
			## that ratio is the whole mood.
			var warm: bool = kind == "brazier"
			var jitter: float = 1.0 + sin(_flicker * (11.0 if warm else 6.0) + float(id % 17)) * 0.12
			if light != null:
				light.light_color = Color("#ff8a3a") if warm else Color("#ffb347")
				light.light_energy = (1.2 if warm else 0.82) * jitter
				light.omni_range = (330.0 if warm else 260.0) * WORLD_SCALE
				light.position = Vector3(prop.global_position.x * WORLD_SCALE,
					(60.0 if warm else 110.0) * WORLD_SCALE, prop.global_position.y * WORLD_SCALE)
			## And the pool on the planking. A point light alone falls off into
			## the deck's own roughness and reads as nothing from this angle; the
			## browser paints a radial gradient under every flame for exactly
			## this reason, and it is most of why its deck looks lit rather than
			## bright. Drawn whichever tier is lighting the flame — the model
			## light replaces the omni, never this.
			_decal("glow%d" % id, prop.global_position, 0.0,
				(430.0 if warm else 330.0), (430.0 if warm else 330.0), _blob_texture(),
				Color(1.0, 0.56, 0.22, 0.26 * jitter) if warm
				else Color(1.0, 0.72, 0.36, 0.18 * jitter))

		## SG-59 — THE VENTS WEAR THEIR JOB. The owner played the Boilerwright and
		## could not FIND one: a vent was a 52-unit grey prop on a grey deck, and
		## the class's whole free-Head mechanic hung off an object with no
		## identity. Three reads, cheapest first:
		##
		##   * a WARM GRATE — a lit pool on the planking and a hot core in the
		##     throat, the lantern loop's own language, because a vent is the
		##     ship's heat coming up through iron and should read as lit from
		##     below (the plume itself is metered into the steam emitter beside
		##     the wreck smoke — see `SMOKE_EVERY`);
		##   * and, ONLY when the man who can drink from it is aboard, the
		##     STAND-HERE RING: the player's teal at `SkyGearData.VENT_STAND` —
		##     the same number `_fill_head` measures — so where the ring is IS
		##     where the bank fills, pinned by the harness. The captain never
		##     sees it; to her a vent is scenery, and a ring she cannot use is
		##     paint teaching a lie.
		if kind == "vent" and not prop.dead:
			var breath: float = 0.72 + 0.28 * sin(_flicker * 2.1 + float(id % 13))
			_decal("glowv%d" % id, prop.global_position, 0.0, 250.0, 250.0,
				_blob_texture(), Color(1.0, 0.60, 0.26, 0.22 * breath))
			_spark("ventf%d" % id, prop.global_position, 24.0,
				36.0 + 8.0 * breath, Color(1.0, 0.55, 0.24, 0.9))
			if str(game.class_id) == "boilerwright":
				## `VENT_STAND` is a table number the class is balanced on, so this
				## is the same rule even though it does not move (SG-63).
				_decal("ventr%d" % id, prop.global_position, 0.0,
					SkyGearData.VENT_STAND * 2.0, SkyGearData.VENT_STAND * 2.0,
					_ring_texture(),
					Color(PLAYER_TEAL.r, PLAYER_TEAL.g, PLAYER_TEAL.b,
						0.30 + 0.10 * breath))

	## The hulk has three painted states and the port only ever drew TWO of them:
	## sealed while it is still grappling on, open while it is disgorging
	## boarders, wrecked once you break it — and `game.gd` set `vulnerable` on
	## the frame it grappled and never cleared it, so the sealed picture was
	## unreachable until SG-76. `hulk_state()` is the one answer now, and it
	## names the painting AND the mesh: the file names are the state names.
	var hulk_state: String = game.hulk_state()
	if hulk_state != "":
		var art := "res://assets/art/props/boarding_hulk_%s.png" % hulk_state
		## THE WRECK GOES OUT (board SG-139, the owner: *"After the boarding
		## Hulk is destroyed, it just sits there and it blocks vision of objects
		## and enemies"*). He is describing four waves of it: `game.gd` empties
		## `hulk` only on a run reset, so a hulk broken on wave 4 stands at the
		## bow until wave 8 replaces it.
		##
		## IT DOES NOT GO TO ZERO, and that is the honest half. `hulk_hull()`
		## answers for all three states ON PURPOSE — "a wreck is exactly as
		## solid to walk into as a sealed one" — and `correct_player_position`
		## pushes the captain out of it, so a wreck faded to nothing is an
		## invisible wall across the bow, which is a worse bug than the one
		## being fixed. The renderer cannot release that hull; only `game.gd`
		## can, and `game.gd` is another agent's file today. So it fades until
		## it stops competing for attention and stays visible enough to explain
		## the wall. WRECK_RESIDUAL is one constant away from 0.0 the moment the
		## simulation drops the hull.
		var solid := 1.0
		if hulk_state == "destroyed":
			_hulk_wreck_age += delta
			solid = lerpf(1.0, WRECK_RESIDUAL,
				clampf(_hulk_wreck_age / WRECK_FADE_TIME, 0.0, 1.0))
		else:
			_hulk_wreck_age = 0.0
		## THE SHADOW IS THE HULL, not a third number (board SG-140). This read
		## a flat 300 under an object the simulation collides with at 380 and
		## the renderer drew at 528.
		_shadow("hulk", game.hulk.position, hulk_hull_width(), 0.5 * solid)
		## A MESH PER STATE, which is the thing this block could not have until
		## 2026-08-02. The comment that stood here said one generation buys the
		## state the player fights in, because three prompts would return three
		## different vehicles and the swap would pop the whole silhouette
		## mid-fight. That was true of a generator and it is not true of these:
		## the owner built all three off one hull, so sealed, open and wrecked
		## are the same wall with a different door — which is exactly what the
		## three PAINTINGS have always been.
		##
		## A KEY PER STATE, not one "hulkm" key. `_sync_prop_model` claims a
		## scene the first time it sees a key and reuses that node forever
		## after; a shared key would hand the sealed node back for the open
		## state and the door would never open. Per state, `_recycle` shelves
		## the face we stopped drawing on its own model's free list — which is
		## also what leaves the wreck standing alone instead of inside itself.
		if not _sync_prop_model("hulkm-" + hulk_state,
				str(HULK_MODELS.get(hulk_state, "")), game.hulk.position,
				hulk_height_units(), 0.0, 0.0, HULK_RULER):
			## The painted tier keeps the old 420: a plate's width comes from
			## its own texture aspect, so the hull ruler below has nothing to
			## solve for it, and this fires only if all three meshes fail to
			## load.
			_place("hulk", _texture(art), game.hulk.position, HULK_PLATE_HEIGHT)
			var plate: Sprite3D = _billboards.get("hulk")
			if plate != null:
				plate.modulate.a = solid
		else:
			_fade_prop_model("hulkm-" + hulk_state, solid)
		if hulk_state == "open":
			## The furnace in its throat, as light rather than as texture. Same
			## argument as the Boiler's lamp: an emissive map cannot throw
			## anything onto the deck the boarders are walking down, and "it is
			## open" is the single most important thing this object says.
			_spark("hulkfire", game.hulk.position + Vector2(0.0, 70.0), 190.0,
				120.0, Color("#ff8a3a"))


## The captain, as a rigged, animated mesh.
##
## Every other figure on this deck is a painted billboard turned to face the
## camera, which is what the browser could do and all it could do. She is the
## one the player looks at for a whole run and the one constantly turning: a
## billboard cannot show which way you are facing, and in a game where a Cleave
## aimed away from a boarder does nothing, which way you are facing is a
## mechanic.
##
## The state machine, the crossfades, the rate-limited turn and the hit
## reactions all live in `SkyGearRig3D`, because none of that is about her —
## the boarders are next and they get the same component.
const USE_MESH_CAPTAIN := true
const CAPTAIN_SCENE := "res://assets/models/captain/captain.tscn"
const CAPTAIN_HEIGHT := 176.0        ## ground units, sole to crown
## THE PLAYER'S MODEL, PER CLASS — board SG-12. `_sync_captain` loaded
## CAPTAIN_SCENE for BOTH classes, so the Boilerwright, a slow heavy engineer,
## rendered as the fast captain. This table is the fix: `game.class_id` picks the
## scene, the height and the weapon fit. Both classes stand the SAME height —
## they share the locked 41 degree camera and its telegraph calibration, and the
## SG-12 guard pins the two within tolerance — so bulk and stance, not scale, do
## the distinguishing. A class whose scene is absent or carries no clips falls
## back to its painted billboard through `SkyGearRig3D.setup()` returning false,
## so this seam is safe to wire before his rigged-and-retargeted scene lands.
const HERO_MODELS := {
	"captain": {"scene": CAPTAIN_SCENE, "height": CAPTAIN_HEIGHT, "fit": "captain"},
	"boilerwright": {
		"scene": "res://assets/models/boilerwright/boilerwright.tscn",
		"height": CAPTAIN_HEIGHT, "fit": "boilerwright"},
}
## WHO WEARS A CAPE — board SG-23, one row per class, like HERO_MODELS. The
## table is data: `wear()` is additive and refuses cleanly, so a class with no
## row renders byte-for-byte the figure that shipped before capes existed.
##
## IT IS EMPTY, AND THAT IS THE SHIPPED STATE — board SG-82, 2026-08-02.
##
## The owner has now given this cape two verdicts, unprompted, on two different
## builds: "looks horrible", and then "atrocious". His 2026-08-02 screenshot is
## why — at the locked camera it reads as a rigid mahogany PLANK bolted to her
## shoulders, not as cloth. The reason is geometry and it is written on the
## SG-82 board row for whoever rebuilds it; the short version is that a 5x5
## vertex grid whose every ring is bound rigidly to one bone has four hinges and
## no cloth in it, and the cut is nearly as wide as it is long.
##
## NOTHING BELOW IS DELETED. `scripts/cloak.gd` — the chain, the spring, the
## dash crack, the clamps, the deterministic rest — stays in the build and stays
## under harness, because SG-63 rebuilds the cape on top of it and the simulation
## half was never what he was looking at. Restoring the captain's cape is
## uncommenting ONE LINE, and it happens when his verdict turns it on and not
## before.
const HERO_CLOAKS := {
	## "captain": {},   ## OFF since 2026-08-02 — SG-82. Re-earn it in SG-63.
}
var _captain: SkyGearRig3D
var _captain_missing := false
var _captain_class := ""             ## which class the current figure was built for
## Her own key light. A standard trick and the honest one: the hero of a dark
## scene is lit for being the hero, not by whatever happens to be burning nearby.
var _hero: OmniLight3D


func _sync_captain(delta: float) -> bool:
	if not USE_MESH_CAPTAIN:
		return false
	## Which class we are drawing, and its model row. Default to the captain for
	## an unknown id so a bad save never leaves the player invisible.
	var who := str(game.class_id)
	var model: Dictionary = HERO_MODELS.get(who, HERO_MODELS["captain"])
	var model_height: float = float(model.get("height", CAPTAIN_HEIGHT))
	## Class changed since the figure was built — a new run, or the other class
	## picked. Drop the old rig and clear the missing latch so the new class gets
	## its own chance to load; the billboard covers the one frame in between.
	if _captain_class != who:
		if _captain != null:
			_captain.queue_free()
			_captain = null
		_captain_missing = false
		_captain_class = who
	if _captain_missing:
		return false
	if _captain == null:
		_captain = SkyGearRig3D.new()
		add_child(_captain)
		if not _captain.setup(str(model.get("scene", CAPTAIN_SCENE)),
				model_height * WORLD_SCALE, LAYER_FIGURES):
			_captain.queue_free()
			_captain = null
			_captain_missing = true
			return false
		## SG-81: the hero wears the lights table too, keyed off her scene's own
		## folder — she has her own key light, but a class whose identity is a
		## lamp or a furnace should be able to say so in the file like anything
		## else. No seeded row today; the seam is one line and no lie.
		_captain.set_meta("model_key",
			str(model.get("scene", CAPTAIN_SCENE)).get_file().get_basename())
		## And put a weapon in the hand if the class has a fit. It is data — see
		## `assets/models/weapons.json` and `tools/weapon_fit.gd` — because it is a
		## dozen small nudges and none of them is worth a build. The Boilerwright's
		## tool is a separate unpriced asset (board row), so his fit is simply
		## absent for now and `weapon_fit` returns {} — an empty hand, not a crash.
		##
		## Not fatal when it fails: an empty hand is a worse captain, but a captain.
		##
		## SG-170 moved the body of this out to `mount_weapon`, unchanged, so the
		## hero and every boarder scale a weapon by ONE arithmetic. The fit table
		## is authored against a 1.8 m figure, so the blade scales with the
		## character rather than being 0.95 m on a figure 1.76 tall — and that
		## sentence was the whole of what a second copy would have got wrong.
		mount_weapon(_captain, str(model.get("fit", who)), model_height)
		## And the cape, if this class has a row (SG-23). Additive only: a
		## class without a row — or a rig `wear()` refuses — is byte-for-byte
		## the figure that shipped before capes existed.
		if HERO_CLOAKS.has(who):
			_captain.wear(HERO_CLOAKS[who], LAYER_FIGURES)
	var player := game.player
	## What she is doing, in the order the rig resolves it. Dash beats run, swing
	## beats dash — and the rig holds a one-shot for its own length rather than
	## having it cancelled on the next frame by the run underneath it.
	var speed: float = player.velocity.length()
	var doing := "idle"
	if player.hurt_time > 0.0:
		doing = "hurt"
	elif player.attack_time > 0.0:
		doing = "swing"
	elif player.dash_time_left > 0.0:
		doing = "dash"
	elif game.tap_cooldown > 0.0 and _captain.has_clip("plant") \
			and float(SkyGearData.TAP.cooldown) - game.tap_cooldown \
				< SkyGearRig3D.PLANT_WINDOW:
		## THE PLANT (CLASS-2 §7's named gap, closed by the native great-sword
		## pack): a Tap Main used to teleport into existence at his feet. The
		## sim's own signal is `tap_cooldown` — `tap_main()` sets it to the full
		## cooldown on the frame the tap lands, so cooldown-minus-remaining IS
		## the time since he cracked it. For the first PLANT_WINDOW of that he
		## kneels, through the same clip-stretched-to-window machinery as the
		## swings. Gated on the clip so the captain (whose pack has no kneel,
		## and whose gauge cannot tap anyway) never freezes into a fallback.
		doing = "plant"
	elif speed > (28.0 if _captain.state == "run" else 62.0):
		## HYSTERESIS. A single threshold at 35 meant a captain drifting near it
		## — which is most of the time, because friction decays speed through
		## that band every time you let go — flipped between run and idle every
		## frame. Each flip restarts a crossfade, and a crossfade restarted every
		## frame never gets anywhere: that is the popping. Enter the run fast,
		## leave it slow, and the band between is where she stays put.
		doing = "run"
	## The window travels with the state, so the rig can fit the clip to it.
	var window := 0.0
	if doing == "swing":
		window = player.attack_time
	elif doing == "dash":
		window = maxf(0.12, player.dash_time_left)
	elif doing == "hurt":
		window = maxf(0.2, player.hurt_time)
	elif doing == "plant":
		window = maxf(0.12, SkyGearRig3D.PLANT_WINDOW
			- (float(SkyGearData.TAP.cooldown) - game.tap_cooldown))
	_captain.want(doing, speed, window)
	## The weapon trail samples the BLADE, not a clock (SG-18): one tip position
	## per swinging frame, read off the hand mount the skeleton is already
	## solving. Gated on the simulation's own attack window, so the trail starts
	## with the swing and stops being fed the instant the swing is over.
	if doing == "swing":
		_sample_blade()
	## A flinch is worth seeing on the model as well as in the numbers.
	if player.hurt_time > 0.30:
		_captain.react_hit(1.0)
	## She turns to her aim rather than to her movement: aim is what the Cleave
	## uses, so aim is what the player has to be able to read off her.
	_captain.place(player.global_position, player.aim_direction, WORLD_SCALE, delta,
		player.velocity)
	## The cape rides the same simulation frame she does (SG-23): the sim's
	## velocity and dash window in, and the RENDERER'S sway flag and clock —
	## the pair the camera itself rocks on — so cape and deck share one
	## metronome, and both go still when a framing check turns the sway off.
	if _captain.cloak != null:
		_captain.cloak.drive(delta, player.velocity, _captain.facing,
			player.dash_time_left > 0.0, sway, _flicker)

	if _hero == null:
		## OUTSIDE her transform. A light parented to a node scaled by 0.009 has
		## its range scaled by 0.009 too, which is a two centimetre lamp.
		_hero = OmniLight3D.new()
		_hero.light_color = Color("#ffd9b0")
		_hero.light_energy = 1.5
		_hero.omni_range = 250.0 * WORLD_SCALE
		_hero.omni_attenuation = 1.5
		_hero.shadow_enabled = false
		add_child(_hero)
	_hero.position = Vector3(player.global_position.x * WORLD_SCALE, 150.0 * WORLD_SCALE,
		(player.global_position.y + 90.0) * WORLD_SCALE)
	return true


## Where an ingested model for a kind would live. `SCRAPPER` -> `scrapper`, and
## `tools/models.json` writes to exactly that path, so adding a boarder model is
## a manifest entry and an ingest run rather than a code change.
## What each boarder's drawn height is multiplied by. One entry per kind that
## is not full size; anything absent stands at what the radius says.
## …and one row that is not a boarder: the CREW. `crew_height` reads the same
## table for the same reason `boarder_height` does, so there is one place a
## figure's drawn height is cut and one arithmetic that cuts it.
const FIGURE_SCALE := {
	"SCRAPPER": 0.5,   ## 186 -> 93, a little over half the captain
	"GUNNER": 0.5,     ## 183 -> 92
	"SWARM": 0.5,      ## 165 -> 83, the smallest thing on the deck
	## THE OWNER'S OWN TEN-TO-FIFTEEN PER CENT (build-44 item 5, board SG-103):
	## *"I think crew can maybe be 10-15% smaller to not be a similar size to
	## the hero?"* 165 -> 144, which is 12.5% — the middle of the band he named
	## rather than either edge of it, because both edges are him guessing too.
	##
	## The 165 was not wrong when it was written: SG-87 took it from the sim's
	## own `120 + CREW.radius*3` and retired a hard-coded 110, and 165 against
	## her 176 is exactly the "a touch under the captain" the handoff spec asked
	## for. It turns out a touch under is too close to read as a DIFFERENT KIND
	## of person, which is what the ask is really about — you are meant to know
	## at a glance which figure on that deck is you. 144 against 176 is 82%: a
	## sailor is now visibly shorter than his captain and still a head and a half
	## over a goblin's 83, so the three tiers stay ordered.
	##
	## HERE rather than in the sim, in the manifest, or in the model: `radius` is
	## the footprint a boarder swings at and moving it is a balance change
	## wearing a visual one (the SG-87 note above says so about the goblins and
	## it is no less true of allies), and the shipped mesh is baked against its
	## own measured `model_height` — every figure in this table is full-size on
	## disk and cut at draw time. Both crew paths, mesh and painted fallback,
	## read `crew_height`, so they still cannot disagree about how tall a sailor
	## is.
	"CREW": 0.875,     ## 165 -> 144, 82% of the captain
}


## FIGURES WITH NO CLIPS, AND WHAT MOVES THEM INSTEAD (board SG-87).
##
## The gunner is the one boarder that was never going to be rigged, and the
## handoff spec said so before there was a file to look at: *"a propeller drone
## that will never pass a humanoid rig — prop-spin/bob procedurally instead"*,
## *"the right shape is a static mesh (rotor as a separate child so the renderer
## can spin it) — no rig, no clips, and the loop animates the spin and bob in
## code."* It has no legs, no spine and no arms to put markers on. The owner
## delivered exactly that shape, and this table is the other half of it.
##
##   spin   radians a second the `Rotor*` children turn about their own +Y
##   bob    ground units of hover, peak to trough
##   beat   radians a second the bob runs at
##   lift   ground units the whole drone floats above the planking
##
## THE COST IS CAPPED BY CONSTRUCTION, which matters because the gunner arrives
## in numbers: the rotor children are found ONCE, when the rig is built, and
## kept on the rig — which is pooled — so a frame with six drones on it is
## eighteen `rotation.y +=` and six `position.y =`, and no tree walk at all. A
## kind with no row here is a static lump exactly as it shipped.
const ROTOR_MOTION := {
	"GUNNER": {"spin": 16.0, "bob": 9.0, "beat": 2.1, "lift": 22.0},
}
## Where a rig keeps the rotor children `ROTOR_MOTION` turns, so the search is
## paid once per figure rather than once per frame.
const ROTOR_META := "rotors"

## Which kinds arrive as a KIT OF PARTS rather than as one skinned surface. The
## Colossus is the only one and probably stays the only one — thirteen rigid
## geometries on hinges is what `tools/segment_parts.py` cuts and what
## `tools/rig_parts.gd` assembles — but the row is a table for the same reason
## ROTOR_MOTION is: a kind not named here is untouched.
const SEGMENTED := {"BOSS": true}
## Where a rig keeps those parts, found ONCE when the rig is built and kept on
## the rig, exactly as ROTOR_META does. A pooled rig pays one tree walk in its
## life; a frame with the boss on it pays none.
const PARTS_META := "parts"

## HOW HIGH A PART MAY BE AND STILL DARKEN THE PLANKING, in metres.
##
## THE BUG THIS NUMBER FIXES. A contact shadow is the renderer saying "this
## touches down HERE", and every figure on this deck gets exactly one, sized off
## the gameplay radius and dropped at the figure's origin. That is right for a
## boarder, who is one object standing in one place, and it is wrong for the
## Colossus twice over. Alive it is a 3.09 m machine wearing a 1.82 m ellipse at
## its middle. DEAD it is thirteen parts that have come apart and thrown
## themselves across two metres of deck, with one blob still sitting at an
## origin none of them occupies any more — the owner's "floating dark and gold
## blobs", which is what a scattered pile with its shadow left behind looks
## like.
##
## ONE RULE COVERS BOTH, and it is the definition of the thing: a contact shadow
## belongs to whatever is in contact. Every part darkens the deck under its own
## footprint, and the darkening falls off with how far off the planking that
## part's underside is. A machine STANDING then shades under its feet and its
## shins and nothing else — the head and the shoulders are two metres up and
## contribute nothing — which is a footprint shadow DERIVED rather than declared.
## The same rule, unchanged, grounds each part of the disassembly as it lands.
##
## 1.0 m because the Colossus's legs start 0.11 m off the deck and its torso
## starts at 0.94 (measured, assets/models/boss/parts.json): a metre is the band
## that takes the feet and the shins and leaves the body out of it.
const CONTACT_FADE_M := 1.0
## What a fully grounded part is worth, against the 0.5 a whole boarder gets.
## Lower because thirteen of them overlap and the eye adds them up.
const CONTACT_ALPHA := 0.34


## Contact shadows for a SEGMENTED figure — one per part, under the part.
##
## Returns false when this rig is not one, so the caller falls back to the
## single blob every other figure on the deck wears.
func _part_shadows(key: String, rig: SkyGearRig3D, fade: float) -> bool:
	if rig == null or not is_instance_valid(rig):
		return false
	var parts: Array = rig.get_meta(PARTS_META, [])
	if parts.is_empty():
		return false
	## Into THIS node's frame, because that is the frame the shadow batch is
	## written in and the rig is only a child of it by convention.
	var into := global_transform.affine_inverse()
	for i in parts.size():
		var mi: MeshInstance3D = parts[i]
		if not is_instance_valid(mi):
			continue
		## The part's own box, where it actually is this frame — so a part
		## swinging on its hinge, falling, or lying where it landed is followed
		## without anything having to be told which of those it is doing.
		var box: AABB = into * (mi.global_transform * mi.get_aabb())
		var lift: float = maxf(0.0, box.position.y)
		var grounded: float = clampf(1.0 - lift / CONTACT_FADE_M, 0.0, 1.0)
		if grounded <= 0.02:
			continue
		var centre := Vector2(box.position.x + box.size.x * 0.5,
			box.position.z + box.size.z * 0.5) / WORLD_SCALE
		_shadow("%s#%d" % [key, i], centre, box.size.x / WORLD_SCALE,
			CONTACT_ALPHA * grounded * fade, box.size.z / WORLD_SCALE)
	return true


static func model_path(kind: String) -> String:
	var slug := kind.to_lower()
	return "res://assets/models/%s/%s.tscn" % [slug, slug]


## HOW TALL A CREWMAN STANDS, in ground units — and it is the same arithmetic
## every boarder gets, `120 + radius*3`, applied to the radius the SIMULATION
## already keeps for a crewman (`SkyGearLanes.CREW.radius` = 15), through the
## same `FIGURE_SCALE` row every shrunk boarder goes through. 165 raw, 144 drawn.
##
## The raw number is not a guess and never was: the handoff spec asked for "a
## touch under the captain — call it ~1.7 m" and the sim's own answer landed
## inside that, so nothing had to be invented. It REPLACES a hard-coded 110 the
## painted crew were drawn at — 110 against a captain of 176 is 62%, a deck of
## children holding the lanes. What the owner then reported (build-44 item 5) is
## that a touch under is too CLOSE: at 94% of the hero a sailor reads as another
## hero. The 12.5% cut lives in `FIGURE_SCALE["CREW"]` with its reasons; this
## function stays the one place both crew paths — mesh and painted fallback —
## ask how tall a sailor is, which is what stops them disagreeing.
##
## The crew share the goblin's 15-unit footprint exactly, incidentally, and the
## FOOTPRINT DOES NOT MOVE with the height: `radius` is what a boarder swings at.
## The goblin is halved and the crewman is cut by an eighth, which is still the
## whole difference between something that scuttles and the man holding the line.
static func crew_height() -> float:
	return (120.0 + float(SkyGearLanes.CREW.radius) * 3.0) \
		* float(FIGURE_SCALE.get("CREW", 1.0))


## WHICH WAY A FIGURE ON THIS DECK IS POINTED — one answer, for everybody who
## has feet (board SG-103).
##
## Owner, build-44: *"Crew members walk backwards, they should face enemies when
## walking."* He was reading a literal constant. The crew branch of `_sync_all`
## passed `Vector2(0, -1)` — up-deck, forever — because the crew push up the
## deck into the boarders and up-deck is true of the MARCH. It is not true of a
## sailor whose lane's nearest boarder is behind him: `_update_crew` sends him
## back down the deck at it and the renderer kept him aimed at the bow, so he
## reversed into the fight. It was not true during his bayonet stab either — he
## thrust at a boarder off his shoulder while facing the horizon.
##
## The boarders have never had this bug, because they were never handed a
## constant: each carries `attack_direction` (where the thing it is fighting is)
## and `velocity` (where it is going), and the renderer picks between them. So
## the fix is not a second rule for allies — it is giving a crewman those same
## two fields (`SkyGearLanes.make_crew`, written every tick by `_update_crew`)
## and asking THIS function, which is the boarder rule hoisted out of the loop
## it was inlined in. Two functions disagreeing about one number is this
## project's second failure mode; two figures disagreeing about which way is
## forward is the same fault wearing a hat.
##
##   travelling  ->  face where you are going
##   engaged     ->  face what you are fighting
##
## which for a crewman IS "face the enemy when walking": `_update_crew` walks
## him in a straight line at the boarder he has picked, so while he closes his
## travel vector and his threat vector are THE SAME VECTOR. That identity is
## also why the crew's four aboard-but-unwired `strafe` clips stay unwired — a
## strafe sells advancing while facing somewhere ELSE, and this mover never
## does. The captain is the one figure that keeps her own path (`_sync_captain`
## hands `place` a separate `travel`), because she faces her cursor rather than
## her feet and is the only thing here that can genuinely walk sideways.
##
## AND THE ASSIST DID NOT CHANGE THAT (SG-187), which is worth writing down
## because it is the obvious place to expect it to. A crewman crossing into the
## next lane is walking in a straight line at the boarder he has claimed, so his
## travel vector and his threat vector are still the same vector and a strafe
## still has nothing to play. The one genuinely new pose the assist creates is
## the opposite of a strafe — a man STANDING at his station, watching the bow,
## which is `idle`. The four clips stay unwired and whether the owner wants them
## is still his open question.
static func figure_heading(attack_direction: Vector2, velocity: Vector2,
		travelling: bool) -> Vector2:
	if travelling and velocity.length_squared() > 1.0:
		return velocity
	return attack_direction


## How tall a boarder of this kind is DRAWN, in ground units — the `_sync_all`
## formula (120 + radius·3, per-kind scaled) with exactly one copy of itself.
## Hoisted for the scrapper pilot (board SG-55): the SG-45 guard has to stand a
## rigged boarder up at the same height the renderer will, and a second copy of
## this arithmetic in the harness is the two-functions-disagreeing-about-one-
## number failure STATUS names.
static func boarder_height(kind: String) -> float:
	var config: Dictionary = SkyGearData.ENEMIES.get(kind, {})
	return (120.0 + float(config.get("radius", 22.0)) * 3.0) \
		* float(FIGURE_SCALE.get(kind, 1.0))


## PUT THE FITTED WEAPON IN A FIGURE'S HAND (SG-170). The one place in this
## renderer that turns a row of `assets/models/weapons.json` into a held object,
## called by the hero path and by `_sync_rig` — which is every boarder and the
## crew — so a pike and a cutlass cannot be scaled by two different arithmetics.
##
## `drawn_height` is GROUND UNITS, the number the figure is actually drawn at
## (`boarder_height`, `crew_height`, or the hero row's `height`), because the
## scale factor below has to be the height on screen and not the height in the
## manifest.
##
## THE SCALING IS THE PART THAT IS EASY TO GET WRONG AND IT IS WHY THIS IS ONE
## FUNCTION. The fit table is authored against a **1.8 m figure** — that is what
## its header says and what the captain's numbers mean. Both the OFFSET and the
## LENGTH therefore scale by the holder's own height: a knight standing 2.16 m
## given the table's metres raw would carry a captain-sized axe held at a
## captain-sized distance from a hand a third again as far from his shoulder.
## The rotation does not scale, being an angle.
##
## Returns false when the figure has no row, which is the normal case for most
## of the roster and is not an error — see the call site in `_sync_rig`.
##
## `override` replaces named fields of the row and is for the FITTING TOOL only
## (`tools/grip_sheet.gd --variants`): the game never passes it. It exists so a
## tool trying twenty candidate grips does not have to restate the 1.8 m scaling
## above — which is the exact arithmetic a fitting tool is most likely to get
## subtly wrong, and would then have you author numbers against a scale the game
## does not use. The seam is one `merge`; the alternative is a second copy.
static func mount_weapon(rig: SkyGearRig3D, who: String,
		drawn_height: float, override: Dictionary = {}) -> bool:
	if rig == null or who == "":
		return false
	var fit := SkyGearRig3D.weapon_fit(who)
	if fit.is_empty():
		return false
	if not override.is_empty():
		fit.merge(override, true)
	var offset: Array = fit.get("offset", [0, 0, 0])
	var turn: Array = fit.get("rotation", [0, 0, 0])
	var to_world: float = drawn_height * WORLD_SCALE / 1.8
	return rig.hold(str(fit.path), str(fit.bone),
		Vector3(float(offset[0]), float(offset[1]), float(offset[2])) * to_world,
		Vector3(float(turn[0]), float(turn[1]), float(turn[2])),
		float(fit.get("length", 0.95)) * to_world, LAYER_FIGURES)


## Drive a rigged figure, if this kind has one. Returns false when it does not,
## so the caller falls back to the painted billboard.
func _sync_rig(key: String, kind: String, ground: Vector2, heading: Vector2,
		height: float, attacking: bool, moving: bool, speed: float,
		attack_clock: float, delta: float, stun: float = 0.0,
		turning: bool = false, airborne: bool = false,
		attack_beat: float = 0.0) -> bool:
	if _no_model.has(kind):
		return false
	var rig: SkyGearRig3D = _rigs.get(key)
	if rig == null:
		var path := model_path(kind)
		if not ResourceLoader.exists(path):
			_no_model[kind] = true
			return false
		rig = SkyGearRig3D.new()
		add_child(rig)
		if not rig.setup(path, height * WORLD_SCALE, LAYER_FIGURES):
			rig.queue_free()
			_no_model[kind] = true
			return false
		## SG-81: which row of the lights table this figure wears. Stamped rather
		## than re-derived at flush time, because `model_path` is the one place
		## that knows a kind's slug and a second copy of `to_lower()` is a second
		## place for it to disagree — and a corpse still playing `die` has left
		## `_rigs` and no longer knows its kind at all.
		rig.set_meta("model_key", model_path(kind).get_file().get_basename())
		## AND PUT SOMETHING IN THE HAND (SG-170).
		##
		## The crew, the furnace knight and the gremlin had empty hands for the
		## whole life of this port while their weapons sat ingested, committed
		## and registered in `weapons.json` — because the ONLY `hold()` call in
		## this renderer was the hero's, in `_sync_captain`. Rows in the table
		## alone would have moved nothing: the code path did not exist. That is
		## STATUS's first failure mode wearing its largest coat — not a field
		## with no reader, a whole ASSET CLASS with no reader.
		##
		## Keyed off the `model_key` stamped one line above rather than off a
		## fresh `kind.to_lower()`, because that slug is decided by `model_path`
		## and a second copy of the derivation is a second place for it to
		## disagree (failure mode two, and the reason `model_key` exists).
		##
		## ONE-TIME, here in the setup block, for the same reason the rotors and
		## the parts are: `hold()` frees and rebuilds a `BoneAttachment3D`, loads
		## a scene and walks the weapon's meshes twice to measure its span. Doing
		## that every frame would rebuild twelve pikes sixty times a second.
		##
		## AN ABSENT ROW IS A CLEAN REFUSAL, NOT A CRASH: `weapon_fit` returns {}
		## for a kind the table has never heard of — SCRAPPER, GUNNER and BOSS
		## today — and such a figure is byte-for-byte the figure that shipped
		## before this block existed. An empty hand stays legal.
		mount_weapon(rig, str(rig.get_meta("model_key", "")), height)
		## SG-87: the rotor children, found once. `Rotor*` is the contract
		## `tools/split_rotors.py` writes and nothing else in the tree answers
		## to it; a kind with no ROTOR_MOTION row never looks.
		if ROTOR_MOTION.has(kind) and rig.model != null:
			rig.set_meta(ROTOR_META, rig.model.find_children("Rotor*", "Node3D",
				true, false))
		## SG-94: the thirteen parts, found once, for the contact shadows. Same
		## bargain as the rotors above — and it must be stamped HERE rather than
		## looked up at draw time, because a corpse mid-disassembly has left
		## `_rigs` and no longer knows what kind it was.
		if SEGMENTED.has(kind) and rig.model != null:
			rig.set_meta(PARTS_META, rig.model.find_children(
				"*", "MeshInstance3D", true, false))
		_rigs[key] = rig
	_used[key] = true
	var doing := "idle"
	## THE CROSSING OUTRANKS EVERYTHING THE SIMULATION CAN STILL BE SAYING (SG-142),
	## and that is the `hurt` suppression the design asks for, done by not asking
	## rather than by adding a suppression flag beside it. A boarder cannot be
	## damaged in this window — `can_be_hit()` is false through the whole of it —
	## so a `stun_time` still counting down here is a leftover, and a flinch played
	## in mid-air is a figure recoiling from nothing on the way over.
	if airborne:
		doing = "jump"
	elif stun > 0.0:
		## THE FLINCH (SG-85). The sim's own signal, not a hit counter kept
		## behind the renderer's back: an ARC proc stuns for 0.45 s and the
		## boarder's whole state machine returns early while it lasts — it is
		## already "this one is reeling, and doing nothing else". A hit that
		## does not stun stays what it always was, a number and a tint; a
		## flinch on every tick of damage would freeze a 180-hp wall solid.
		doing = "hurt"
	elif turning:
		## THE HALF-HEALTH TURN (SG-90). The Colossus's own beat, and the sim
		## already makes it a real one — `enemy.gd` holds `state == "turn"` for
		## `SkyGearEnemy.TURN_TIME` and refuses all damage through it, so it
		## cannot be burst. Until the segmented model landed, 1.6 seconds of
		## invulnerability looked exactly like 1.6 seconds of a figure standing
		## still. A rig with no `turn` clip degrades to idle and is no worse off
		## than it was.
		doing = "turn"
	elif attacking:
		doing = "swing"
	elif moving and speed > 12.0:
		## WALK OR RUN, by the ground speed the simulation is actually giving
		## this kind (SG-85). Every boarder ran, because the scrapper was the
		## only rigged one and he closes at 150. The furnace knight moves at
		## SEVENTY-FIVE — a wall, not a rusher — and a run cycle at that speed
		## is a man sprinting on the spot. `gait` picks whichever cycle has to
		## be stretched less; the crossover leaves the scrapper on his run.
		doing = SkyGearRig3D.gait(speed)
	var window := 0.0
	if doing == "jump":
		## The WHOLE crossing, not the remainder of it. `want` re-reads the window
		## only on the frame the state changes, so this is the value the clip is
		## fitted to for the entire leap — and the same "the beat's OWN length"
		## rule the turn below is written on. Read off the simulation's constant,
		## never restated here.
		window = SkyGearEnemy.ARRIVAL_TIME
	elif doing == "turn":
		## The beat's OWN length, not the countdown the enemy is running. See
		## `SkyGearEnemy.TURN_TIME` — a window that shrinks every frame is a
		## one-shot that accelerates as it plays.
		window = SkyGearEnemy.TURN_TIME
	elif attacking:
		## THE BEAT'S OWN LENGTH, exactly like the turn above it and the crossing
		## above that — and the attack is the one that was NOT written that way
		## (board SG-188, owner: *"Slow down the attack animations on furnace
		## knights it looks too fast now"*).
		##
		## `attack_clock` is `enemy.state_time`, a COUNTDOWN, so fitting the clip
		## to it fitted the swing to whatever was LEFT of the beat and the swing
		## accelerated frame by frame into the 4.00x clamp; and because
		## `swinging` holds this state through the windup AND the recovery, it
		## did it twice per attack. Measured before the change, six consecutive
		## attacks: rate 1.83x rising to the 4.00x clamp in every one of them,
		## and **2.50 full plays of the swing clip per single 34-damage hit**.
		##
		## `attack_beat()` is the SIMULATION's own arithmetic — the windup times
		## the Heat scale, plus the recovery — asked of the enemy rather than
		## restated here, because a renderer that restated `_windup_scale()`
		## would be two functions disagreeing about one number with a difficulty
		## ladder attached. Nothing about the attack's TIMING moves: this changes
		## the number the CLIP is divided by and no number the simulation swings
		## on. The fallback keeps every caller that has no beat to offer — the
		## crew — on exactly the behaviour it had.
		window = attack_beat if attack_beat > 0.0 else attack_clock
	elif doing == "hurt":
		window = maxf(0.12, stun)
	rig.want(doing, speed, window)
	rig.place(ground, heading, WORLD_SCALE, delta)
	_fly(rig, kind, delta)
	return true


## Where a rig remembers that it is off the deck, and what its meshes were
## casting before it left. On the rig itself rather than in a dictionary beside
## `_rigs`, because a dictionary beside `_rigs` is a second thing to sweep and
## the sweep that frees the rig is the one that would have to know about it.
const FLIGHT_META := "airborne"
const FLIGHT_CAST_META := "airborne_cast"


## THE MOON MUST NOT DRAW A SECOND, WRONG MARK — design §8's second risk, and it
## is the half of the shadow work that had no home in `shadow_pose`.
##
## `moon.directional_shadow_max_distance` is 34 m = 3,400 ground units, so an
## airborne boarder is well inside the shadow cascade and casts a real
## silhouette. At the arc's apex the moon puts that silhouette roughly 230 units
## from the landing ring — a second mark, DARKER than the contact blob, under a
## figure that has exactly one thing worth saying about it. Two marks under one
## man pointing different ways is a bug the owner has already reported once.
##
## THIS IS NOT A SECOND COPY OF THE `_shadow` RULE. That one says a mark with
## height under it is never shrunk to a contact core — a property of MARKS, and
## it holds for callers that have no rig at all. This one suppresses the CAST
## shadow, which is a property of the mesh. They are two halves of one picture
## and they happen to agree: with the cast shadow off, `_casts_own_shadow`
## honestly answers false and the blob would have come back whole anyway. The
## rule in `_shadow` is what makes that safe rather than lucky.
##
## The previous setting is remembered per mesh rather than restored to ON,
## because "everything on a rig casts" is an assumption about content and this
## file is not the place to bet on it.
func _arrival_flight(rig: SkyGearRig3D, airborne: bool) -> void:
	if rig == null or not is_instance_valid(rig):
		return
	## Only on the transitions — twice in a boarder's life, not once a frame. The
	## tree walk is paid on the same terms `ROTOR_META` and `PARTS_META` pay it.
	if bool(rig.get_meta(FLIGHT_META, false)) == airborne:
		return
	rig.set_meta(FLIGHT_META, airborne)
	var meshes := rig.find_children("*", "MeshInstance3D", true, false)
	if airborne:
		var kept := {}
		for child in meshes:
			var mi := child as MeshInstance3D
			kept[mi.get_instance_id()] = int(mi.cast_shadow)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rig.set_meta(FLIGHT_CAST_META, kept)
		return
	var was: Dictionary = rig.get_meta(FLIGHT_CAST_META, {})
	for child in meshes:
		var mi := child as MeshInstance3D
		mi.cast_shadow = int(was.get(mi.get_instance_id(),
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON))
	if rig.has_meta(FLIGHT_CAST_META):
		rig.remove_meta(FLIGHT_CAST_META)
	## FEET MEET PLANKING. `react_land` was written for this moment and called
	## from nowhere for as long as it has existed.
	rig.react_land()


## THE DRONE FLIES (board SG-87), and this is the whole of its animation.
##
## Everything else on this deck moves because a clip moves it. The gunner has no
## clips and never will — `_sync_rig` has already asked it to walk, run and
## swing and `SkyGearRig3D.want` returned early on a null AnimationPlayer every
## time, which is the shape the harness's clipless-lump fixture pins. So its
## motion is arithmetic instead: three rotors turning about their own hubs, and
## a hover that carries the whole machine off the planking and breathes.
##
## The rotors are the reason the model was delivered TWICE. The textured export
## is one welded surface with nothing to turn; the part-segmentation export says
## which triangles are blades, and `tools/split_rotors.py` uses the second to cut
## the first into `Body` and three `Rotor*` children with their pivots on their
## own hubs. Turning a node is then the cheapest animation in the renderer.
##
## THE PHASE IS PER DRONE. A wave sends four of these at once and a shared clock
## makes them one object drawn four times — the same lockstep the billboards got
## a `phase` offset for. The rig's instance id is a free, stable, per-drone
## number, and the bob and the spin take different multiples of it so two drones
## that happen to bob together are not also spinning together.
## Where a blade sits after another `delta` of turning. `wrapf`, not an
## unbounded accumulation: a run is ninety minutes and a float that has been
## adding sixteen radians a second for all of it has lost the precision to
## describe a blade angle. Static and pure, the `corpse_drop` idiom — the
## harness pins the cap without standing a deck up.
static func rotor_angle(angle: float, spin: float, delta: float) -> float:
	return wrapf(angle + spin * delta, -PI, PI)


## How far off the planking a hovering figure is, in GROUND units. Never
## negative: `lift` is the floor and the bob is half its peak-to-trough either
## side of it, so a drone cannot bob down through the deck it is flying over.
static func hover_height(motion: Dictionary, clock: float, phase: float) -> float:
	return float(motion.get("lift", 0.0)) \
		+ sin(clock * float(motion.get("beat", 0.0)) + phase) \
			* float(motion.get("bob", 0.0)) * 0.5


func _fly(rig: SkyGearRig3D, kind: String, delta: float) -> void:
	var motion: Dictionary = ROTOR_MOTION.get(kind, {})
	if motion.is_empty():
		return
	var phase: float = float(rig.get_instance_id() % 359) * 0.0175
	for node in rig.get_meta(ROTOR_META, []):
		if is_instance_valid(node):
			var blade := node as Node3D
			blade.rotation.y = rotor_angle(blade.rotation.y,
				float(motion.spin), delta)
	## After `place`, which writes the whole transform and puts y at zero. The
	## shadow stays on the planking under it — a hovering thing with no shadow
	## reads as a decal, and the gap is what says it is in the air.
	rig.position.y = hover_height(motion, _flicker, phase * 2.7) * WORLD_SCALE


## Stand a static generated mesh where a billboard would have gone. Returns false
## when that model is not on disk, so every caller falls back to `_place` and the
## painted art — the same always-both-paths rule `_sync_rig` follows for boarders,
## for the same reason: the props become meshes one at a time.
##
## NOT a `SkyGearRig3D`. That class exists for a skeleton, an AnimationPlayer, a
## blend, a hit flash and a squash, and a crate has none of them. There are
## twenty-eight rows in `PROP_LAYOUT`; running an animation tree on every barrel
## on the deck is twenty-eight of something for nothing.
##
## `yaw_degrees` is about +Y and measured from FACING THE CAMERA. The camera sits
## at +z looking toward -z — `_track_camera` focuses on `p.y + back` with `back`
## positive — and `tools/static_model.gd` has already turned every model so its
## own front is +Z. So zero is right for everything whose read is one face
## pointed at the player, and only the cannon disagrees.
## --- SG-79: the honest ruler learns about the camera --------------------------
##
## Owner, 2026-08-02, over the same screenshot: "some 3D objects once imported
## are too large." He is right, the amount is measurable, and the cause is not
## the exporter — it is that the ruler was measuring the wrong thing.
##
## `PROP_HEIGHT` is the browser's own `PROP_H`, and in the browser every prop is
## a BILLBOARD: camera-facing, so all of its authored height lands on the screen
## as height, and it has no depth at all. Scaling a generated MESH so its AABB is
## `PROP_HEIGHT` tall is therefore not the same picture. At the locked 0.72 rad
## camera a world-vertical edge foreshortens to cos(0.72) = 0.75 of itself, while
## the model's DEPTH — which a card does not have — projects 0.66 of itself back
## on top. A tall, thin prop barely notices. A squat, deep one balloons: the
## steam vent, a 52 x 57 x 64 box and the owner's own prime suspect at the bottom
## of the frame, covered 81 ground units of screen height where its painting
## covered 52. That is 1.56x, and the deck cannon was 2.07x.
##
## So the ruler measures what the CAMERA sees. `height_units` still means exactly
## what it always meant — the screen height of the card this object replaces —
## and a prop is scaled until its projected extent equals it. Tall thin props are
## untouched (the mast, the ballista and the crate stack all move under half a
## percent); the squat deep ones come down to the size of the picture they
## replaced, which is the whole complaint.
const COS_PITCH := 0.751806     ## cos(PITCH), the vertical foreshortening
const SIN_PITCH := 0.659385     ## sin(PITCH), the depth that reads as height


## What a model of extent `span` (model units, unrotated), turned `yaw_degrees`
## about +Y, covers VERTICALLY on screen at the locked camera — in model units,
## so `height_units / camera_span` is the scale that makes it cover a card's
## worth. Static and pure: the harness pins every wired prop through this without
## standing a deck up.
static func camera_span(span: Vector3, yaw_degrees: float = 0.0) -> float:
	var yaw := deg_to_rad(yaw_degrees)
	## The footprint that ends up lying along the view direction. Zero yaw leaves
	## the model's own depth there; the deck cannon's -90 swings its length into
	## it, which is why the cannon was the worst row in the audit.
	var toward: float = absf(sin(yaw)) * span.x + absf(cos(yaw)) * span.z
	return span.y * COS_PITCH + toward * SIN_PITCH


## The union of every mesh in a prop scene, in the scene root's own frame — the
## same measurement `tools/static_model.gd` writes `model_height` from, widened
## to all three axes. Composed by WALKING the local transforms rather than
## reading `global_transform`, so it works on a scene that has just been
## instantiated and is not in a tree yet, and cannot pick up the renderer's own
## transform if it is.
static func measure_span(model: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		var local := Transform3D.IDENTITY
		var walk: Node = mi
		while walk != null and walk != model:
			if walk is Node3D:
				local = (walk as Node3D).transform * local
			walk = walk.get_parent()
		var here: AABB = local * mi.get_aabb()
		box = here if first else box.merge(here)
		first = false
	return box.size


## The span of a model key measured WITHOUT one being on the deck, cached — the
## `ruler_key` half of `_sync_prop_model` (SG-76). One load and one measurement
## per key for the whole session, and it deliberately does not add the node to
## the tree: this is a ruler, not a prop.
var _ruler_spans: Dictionary = {}

func _ruler_span(model_key: String) -> Vector3:
	if _ruler_spans.has(model_key):
		return _ruler_spans[model_key]
	var span := Vector3.ZERO
	var path := model_path(model_key)
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		var probe: Node3D = packed.instantiate() as Node3D if packed != null else null
		if probe != null:
			span = measure_span(probe)
			probe.free()
	_ruler_spans[model_key] = span
	return span


## --- SG-140: THE HULK IS DRAWN AT THE SIZE THE SIMULATION GIVES IT ----------
##
## It was drawn at a flat 420, and 420 is a SCREEN height — SG-79's ruler says a
## prop covers that many ground units of FRAME at the locked camera. That says
## nothing about width, and width is the only dimension that matters for a thing
## parked across a lane. Measured through the renderer's own ruler
## (`tools/hulk_probe.gd`), 420 put the hull on screen **528 ground units wide**
## against a collision radius of **190** — a 380-wide solid wearing a 528-wide
## picture, with a 300-wide shadow under it. Three numbers for one object, which
## is failure mode two; `hulk_hull()`'s own comment had already made exactly
## this argument for the simulation side and the renderer never heard it.
##
## The gap is not cosmetic. The centre lane between the two cargo runs is **440**
## units across, so the drawn hull was **88 units wider than the lane it sits
## in** and overhung the cargo on both sides — which is the owner's "it blocks
## that lane", and why this is filed as a bug and not as a placement note.
##
## So the ruler is INVERTED: ask for the screen height that makes the drawn
## WIDTH equal the hull the simulation collides with. One number, `hulk.radius`,
## the same one `_crew_step`, `hulk_splash` and `correct_player_position` use.
func hulk_hull_width() -> float:
	return float(game.hulk.get("radius", 0.0)) * 2.0


func hulk_height_units() -> float:
	var ruler := _ruler_span(HULK_RULER)
	var want := hulk_hull_width()
	if ruler.x <= 0.0 or ruler.y <= 0.0 or want <= 0.0:
		return HULK_PLATE_HEIGHT
	return want * camera_span(ruler, 0.0) / ruler.x


## Fade a placed prop MESH, the way a corpse fades (SG-103). `transparency` is
## per `GeometryInstance3D` rather than per material, which is the only reason
## this is safe: these meshes share their material with every other instance of
## the same model, and writing the material would take the whole free list with
## it. The mesh list is walked only when the value actually moves, so a wreck
## standing at its residual costs one float compare a frame.
func _fade_prop_model(key: String, solid: float) -> void:
	var node: Node3D = _prop_models.get(key)
	if node == null:
		return
	var want: float = clampf(1.0 - solid, 0.0, 1.0)
	if is_equal_approx(float(node.get_meta("faded", 0.0)), want):
		return
	node.set_meta("faded", want)
	for child in node.find_children("*", "GeometryInstance3D", true, false):
		(child as GeometryInstance3D).transparency = want


## `ruler_key` names ANOTHER model whose span sets this one's scale, and it
## exists for exactly one situation: several scenes that are the same object in
## different states. Empty — every prop on the deck but the hulk — measures
## itself, which is SG-79 unchanged.
func _sync_prop_model(key: String, model_key: String, ground: Vector2,
		height_units: float, lift: float = 0.0, yaw_degrees: float = 0.0,
		ruler_key: String = "") -> bool:
	## An empty key is a prop_type with no row in PROP_MODEL, which is the normal
	## way of saying "this one is still painted" — not an error, and not worth a
	## path lookup on `res://assets/models///.tscn` to discover.
	if model_key == "":
		return false
	var node: Node3D = _prop_models.get(key)
	if node == null:
		node = _claim_prop_model(model_key)
		if node == null:
			return false
		_prop_models[key] = node
	_used[key] = true
	## Written every frame rather than once on claim. The salvage pickups bob, so
	## the position has to move anyway, and PROP_HEIGHT is data another session
	## can edit — a scale cached at claim time would keep the old number for as
	## long as that prop lived, which is the whole run.
	var span: Vector3 = _ruler_span(ruler_key) if ruler_key != "" \
		else node.get_meta("model_span", Vector3.ZERO)
	## `model_height` when there is no span to be had — the pre-SG-79 ruler,
	## verbatim, so a node that somehow arrived without one is the old picture
	## rather than a new wrong one.
	var seen: float = camera_span(span, yaw_degrees) if span.y > 0.0 \
		else float(node.get_meta("model_height", 0.0))
	var s: float = height_units * WORLD_SCALE / maxf(0.0001, seen)
	node.scale = Vector3(s, s, s)
	node.rotation.y = deg_to_rad(yaw_degrees)
	node.position = Vector3(ground.x * WORLD_SCALE, lift * WORLD_SCALE,
		ground.y * WORLD_SCALE)
	return true


## One instance of a generated prop scene, from the free list if one is waiting.
##
## The free list is per MODEL KEY, not one shared pool. A `Sprite3D` is
## interchangeable because `_place` overwrites every property of it; a mesh is
## not — handing a crate's node to a lantern would render a crate.
func _claim_prop_model(model_key: String) -> Node3D:
	var free: Array = _free_prop_models.get(model_key, [])
	if not free.is_empty():
		var reused: Node3D = free.pop_back()
		reused.visible = true
		## A SHELVED NODE CAN CARRY SG-139's WRECK FADE. The hulk's destroyed
		## face is recycled when the next push grapples a fresh one on, and a
		## node handed back still transparent would put the NEXT hulk on the
		## deck already a ghost — at full health, before anybody hit it.
		if float(reused.get_meta("faded", 0.0)) != 0.0:
			reused.set_meta("faded", 0.0)
			for child in reused.find_children("*", "GeometryInstance3D", true, false):
				(child as GeometryInstance3D).transparency = 0.0
		return reused
	if _no_prop_model.has(model_key):
		return null
	var path := model_path(model_key)
	if not ResourceLoader.exists(path):
		_no_prop_model[model_key] = true
		return null
	var packed := load(path) as PackedScene
	var node: Node3D = packed.instantiate() as Node3D if packed != null else null
	if node == null:
		_no_prop_model[model_key] = true
		return null
	## `model_height` is written into the scene by `tools/static_model.gd`, which
	## measures the UNION of every MeshInstance3D. Without it there is no honest
	## number to scale by and the prop would be whatever size the exporter felt
	## like — so fall back to the billboard rather than guess. This is also the
	## symptom of the pruning bug: a .glb.import left on EXTRACT references
	## sibling PNGs that are no longer there and instantiates with NO MESHES.
	if float(node.get_meta("model_height", 0.0)) <= 0.0:
		push_warning("%s: no model_height on %s - re-run tools/static_model.gd"
			% [model_key, path])
		node.queue_free()
		_no_prop_model[model_key] = true
		return null
	## LAYER_FIGURES, exactly like the billboard it replaces. Effect decals are
	## culled against that layer (see `_decal`), so a crate on LAYER_WORLD would
	## suddenly start collecting every mortar ring and scorch mark that crossed
	## it — painted around its sides as though the crate were floor.
	for child in node.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).layers = LAYER_FIGURES
	## Stamped on the node so `_recycle` can shelve it on the right list without
	## carrying a second key -> model map that could disagree with this one.
	node.set_meta("prop_model", model_key)
	## And its full extent, measured HERE rather than read from the scene (SG-79).
	## `static_model.gd` writes only `model_height`; the camera-aware ruler needs
	## the depth as well, and measuring it at claim time — once per model key, not
	## once per prop — means the eight generated scenes on disk do not have to be
	## regenerated to gain a number that was always derivable from their meshes.
	## `model_height` stays the authority it always was: this is asserted against
	## it, so a stale ruler is still a fault rather than a silent disagreement.
	node.set_meta("model_span", measure_span(node))
	add_child(node)
	return node


## One figure: the right painted view, mirrored if it is heading right, running
## its cycle if that cycle has been delivered.
##
## Everything about which picture and which frame lives in `SkyGearSprites`, so
## this is only the part that is about being in a 3D scene. A cycle that has not
## been delivered returns -1 and the still is used, which is why this could be
## written before the art was.
func _draw_figure(key: String, kind: String, ground: Vector2, heading: Vector2,
		height: float, attacking: bool, moving: bool, clock: float,
		attack_clock: float, lift: float = 0.0) -> void:
	var v: Dictionary = SkyGearSprites.view_for(heading, attacking)
	var front: bool = v.front
	## Front views only. The cycles are authored facing the camera; a figure
	## walking away keeps its still, which is what the back view exists for.
	var cycle := ""
	if front:
		if attacking:
			cycle = "%s_attack" % kind
		elif moving:
			cycle = "%s_run" % kind
		else:
			cycle = "%s_idle" % kind
	var time: float = attack_clock if attacking else clock
	var index: int = SkyGearSprites.frame(cycle, time) if cycle != "" else -1
	var texture: Texture2D = SkyGearSprites.strip(cycle) if index >= 0 \
		else SkyGearSprites.still(kind, str(v.view))
	if texture == null:
		return
	_used[key] = true
	var node: Sprite3D = _claim_billboard(key, BILLBOARD_FIGURE)
	node.texture = texture
	node.modulate = Color.WHITE
	node.flip_h = bool(v.mirror)
	var tall: float = float(texture.get_height())
	if index >= 0:
		var rect: Rect2 = SkyGearSprites.frame_rect(cycle, index, texture)
		node.region_enabled = true
		node.region_rect = rect
		tall = rect.size.y
	else:
		node.region_enabled = false
	node.pixel_size = height * WORLD_SCALE / maxf(1.0, tall)
	## `lift` is the arrival drop, and it is added rather than replacing the half
	## height: the sprite is centred on its own middle, so its feet only meet the
	## planking at `height/2`, and a boarder 300 units up has its feet 300 above
	## that. `_xray` copies `source.position` wholesale, so the ghost follows the
	## arc without knowing the arc exists.
	node.position = Vector3(ground.x * WORLD_SCALE,
		(height * 0.5 + maxf(0.0, lift)) * WORLD_SCALE, ground.y * WORLD_SCALE)


## THE BILLBOARD POOL'S IDENTITY, WRITTEN ONCE (board SG-66).
##
## `_place`, `_spark` and `_draw_figure` all draw out of `_billboards` and all
## shelve into `_free_billboards`, and each of the three used to carry its own
## copy of the claim block under the same comment: *"Every property below is set
## unconditionally, which is what makes a reused node safe to hand out: nothing
## carries over from whoever had it last."* That sentence was not true. Between
## them the three kinds disagree about FOUR properties, and only some of them
## were being written:
##
##   * `material_override` — `_spark` installs an ADDITIVE, unshaded material
##     whose `albedo_texture` is the round spark blob. Neither `_place` nor
##     `_draw_figure` ever cleared it, and an override BEATS `node.texture`. So
##     a node that had been a spark and came back through the free list rendered
##     its next owner as a glowing blob in the last spark's colour: the owner's
##     "sentry models seem to vanish and are replaced by just floating colored
##     orbs instead of sprites", exactly. Nothing about the sentry was wrong —
##     `_place("sy%d")` claimed a shelved spark. Sparks churn every frame
##     (`fire%d`, `keg%d`, `lob%d`, the turret glows, and `syh%d`, the sentry's
##     OWN head), the free list is LIFO, and a Sentry build appends a new `sy`
##     key every nine seconds, which is why it read as occasional.
##   * `region_enabled` / `region_rect` — `_draw_figure` crops to one animation
##     frame. `_place` never cleared the crop, so a prop could inherit a cell of
##     somebody's run cycle.
##   * `flip_h` — a mirrored figure's node handed to `_place` drew the prop
##     backwards.
##   * `alpha_cut` / `texture_filter` / `transparent` — set by one kind, not the
##     others.
##
## The fix is to stop having three claim blocks. One dresser writes every
## property the three kinds disagree about, unconditionally, and stamps the kind
## it dressed the node as; one claimer re-dresses whenever the stamp does not
## match what is being asked for. That stamp IS the pool-identity check the
## board asked for: a node cannot be issued as one kind while wearing another.
const BILLBOARD_ART := "art"        ## a painted plate: `_place`
const BILLBOARD_SPARK := "spark"    ## an additive hot point: `_spark`
const BILLBOARD_FIGURE := "figure"  ## a cycling character: `_draw_figure`
const BILLBOARD_GHOST := "ghost"    ## the see-through-cargo silhouette: `_xray`


func _dress_billboard(node: Sprite3D, kind: String) -> void:
	node.visible = true
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	## NOT shaded. Every character sprite in `assets/` was generated with the
	## scene's lighting already painted into it — steel-blue rim from the upper
	## left, warm bounce from below right — which is what the browser composites
	## and what the level-kit brief specifies. Re-lighting them with the same two
	## lamps applies the treatment twice and the result is a deck of silhouettes.
	node.shaded = false
	node.double_sided = true
	node.transparent = true
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.layers = LAYER_FIGURES
	## The three that used to carry over. A fresh `Sprite3D` has none of them, so
	## these lines only ever matter to a REUSED node — which is the whole bug.
	node.region_enabled = false
	node.region_rect = Rect2()
	node.flip_h = false
	node.modulate = Color.WHITE
	## And the ghost's two, which NO other site ever wrote: a shelved silhouette
	## handed to a prop drew that prop through the cargo at priority 8.
	node.no_depth_test = kind == BILLBOARD_GHOST
	node.render_priority = 8 if kind == BILLBOARD_GHOST else 0
	if kind == BILLBOARD_SPARK:
		node.texture = _spark_texture()
		node.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_texture = _spark_texture()
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		node.material_override = mat
	else:
		## A painted plate lights itself through its own texture, so it wants NO
		## override at all — and clearing it is the line that puts the sentry back.
		node.material_override = null
		node.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	node.set_meta("billboard_kind", kind)


## One pooled `Sprite3D` for `key`, dressed as `kind`. `BILLBOARD_ENABLED` is
## what makes a flat sprite stand up and face the camera — which is exactly what
## the browser's renderer does by hand, and what the art is painted for.
func _claim_billboard(key: String, kind: String) -> Sprite3D:
	var node: Sprite3D = _billboards.get(key)
	if node != null:
		## The identity check, on the live node as well as the freshly claimed
		## one. A key that changes representation mid-run (the turrets do it with
		## separate keys on purpose) is re-dressed rather than left mixed.
		if str(node.get_meta("billboard_kind", "")) != kind:
			_dress_billboard(node, kind)
		return node
	node = _free_billboards.pop_back() if not _free_billboards.is_empty() \
		else Sprite3D.new()
	_dress_billboard(node, kind)
	if node.get_parent() == null:
		add_child(node)
	_billboards[key] = node
	_peak_billboards = maxi(_peak_billboards, _billboards.size())
	return node


## One billboard per entity, pooled — the painted plate kind.
func _place(key: String, texture: Texture2D, ground: Vector2, height_units: float,
		lift: float = 0.0, tint: Color = Color.WHITE) -> void:
	if texture == null:
		return
	_used[key] = true
	var node: Sprite3D = _claim_billboard(key, BILLBOARD_ART)
	node.texture = texture
	node.modulate = tint
	# scale so the sprite stands `height_units` tall in ground units, and lift it
	# by half of that so its feet meet the deck rather than its middle
	var pixel_height: float = maxf(1.0, float(texture.get_height()))
	node.pixel_size = height_units * WORLD_SCALE / pixel_height
	node.position = Vector3(ground.x * WORLD_SCALE,
		(height_units * 0.5 + lift) * WORLD_SCALE, ground.y * WORLD_SCALE)


## A hot point in the air — a bolt, a spark. Unshaded and additive, so the bloom
## catches it.
func _spark(key: String, ground: Vector2, height: float, size: float, colour: Color) -> void:
	_used[key] = true
	var node: Sprite3D = _claim_billboard(key, BILLBOARD_SPARK)
	if node.material_override is StandardMaterial3D:
		(node.material_override as StandardMaterial3D).albedo_color = colour
	node.pixel_size = size * WORLD_SCALE / 64.0
	node.position = Vector3(ground.x * WORLD_SCALE, height * WORLD_SCALE,
		ground.y * WORLD_SCALE)


## Where a sight line from the camera LEAVES a rect on the ground plane, as a
## parameter along the line, or -1 if it never crosses it. Slab test.
##
## The far side, not the near one. Looking down at 41 degrees from 760 up, the
## edge of a cargo run that hides anything is its far-top edge — the near face is
## the one you are looking over. Testing the entry point said nothing was ever
## occluded, which was technically a passing test.
static func _exit_t(a: Vector2, b: Vector2, rect: Rect2) -> float:
	var d := b - a
	var t_min := 0.0
	var t_max := 1.0
	for axis in 2:
		var origin: float = a.x if axis == 0 else a.y
		var delta: float = d.x if axis == 0 else d.y
		var lo: float = rect.position.x if axis == 0 else rect.position.y
		var hi: float = rect.end.x if axis == 0 else rect.end.y
		if absf(delta) < 0.0001:
			if origin < lo or origin > hi:
				return -1.0
			continue
		var t1 := (lo - origin) / delta
		var t2 := (hi - origin) / delta
		if t1 > t2:
			var swap := t1
			t1 = t2
			t2 = swap
		t_min = maxf(t_min, t1)
		t_max = minf(t_max, t2)
		if t_min > t_max:
			return -1.0
	if t_max <= 0.0 or t_min >= 1.0:
		return -1.0
	return minf(t_max, 1.0)


## Is this thing standing in the shadow of a cargo run, from where we are
## looking?
##
## The browser calls this its x-ray pass and turns it on for v3 onward, because
## the alternative is that a boarder walks behind a container and stops existing
## for two seconds — which in a game where the thing killing you is usually the
## one you lost track of is not an aesthetic problem. The cargo runs are the only
## geometry tall enough to hide anybody, so this is a handful of rectangles and a
## slab test rather than a physics query.
##
## The probe is the TORSO, not the head. From this camera a 125-tall box hides
## about forty units of deck behind it, so a boarder tucked against one is cut
## off at the chest while their head is still in clear air — which is exactly the
## case worth silhouetting, and the case a head test misses entirely.
func _occluded(ground: Vector2, stand: float) -> bool:
	var eye := Vector2(_focus.x, _focus.y + CAM_NEAR)
	var torso := stand * 0.5
	## `game.cargo_rects()`, NOT the `CARGO_RECTS` const — the one cargo source of
	## truth SG-10 established: the eight fixed lane walls PLUS the live heaved
	## crate. The const missed the ninth, movable rect, so a boarder tucked on the
	## bow face of a deployed crate — where the funnel piles them, in the camera's
	## occlusion shadow — walked behind it and stopped existing (SG-31, failure
	## mode one). Reading the live method moves the occlusion with the crate.
	for rect: Rect2 in game.cargo_rects():
		var t := _exit_t(eye, ground, rect.grow(4.0))
		if t < 0.0 or t >= 0.999:
			continue
		if CAM_HEIGHT + (torso - CAM_HEIGHT) * t < WALL_MODULE_H:
			return true
	## THE HULK IS DELIBERATELY NOT IN THIS LIST, and it was in it for an hour
	## (board SG-141). The reasoning was that the paragraph above — "the cargo
	## runs are the only geometry tall enough to hide anybody" — dated from when
	## the hulk was a painted plate, and it is a solid mesh now. Both halves of
	## that turned out not to survive measurement:
	##
	##   * A boarder SPAWNS at y = -1115 in a lane centre, and the hulk's own
	##     footprint at the SG-140 size is y = -1154..-846. The centre lane's
	##     boarders spawn INSIDE it, and `_exit_t` correctly reports a point
	##     inside a box as un-occluded — the same answer it gives for a captain
	##     standing in a cargo rect. There is no deck BEYOND the hulk to be
	##     hidden: it sits at the bow and the planking ends 6 units past it.
	##   * More decisively, `_xray` returns immediately unless the figure has a
	##     `Sprite3D`, and every figure on this deck is a rigged mesh — so
	##     adding the hulk here changes nothing on screen for anybody. It would
	##     have been dead code calling dead code, and a fix that fixes nothing.
	##
	## SG-141 is the real bug and carries both measurements. What the owner was
	## actually seeing is SCREEN COVERAGE, not occlusion, and that is answered
	## by SG-140 shrinking it and SG-139 fading the wreck.
	return false


## The silhouette itself: the same sprite, flattened to one colour and drawn
## through everything. Pooled alongside the real one and only present while it
## is needed, so a clear deck costs nothing.
func _xray(key: String, ground: Vector2, height_units: float, tint: Color) -> void:
	var hidden := _occluded(ground, height_units)
	## THE MESH PATH, AND THE WHOLE OF SG-141. The sprite branch below cannot run
	## for a figure, because a figure has no `Sprite3D` any more — every enemy
	## archetype and both captains are rigged meshes, so `_billboards.get(key)`
	## is null for all of them and this function used to return on its first
	## line, every frame, for everybody. The silhouette was dead code guarded by
	## dead code, which is why SG-139 measured its own change as doing nothing.
	##
	## `rig.silhouette` owns the how (see the long note in `rig3d.gd`); this
	## function keeps owning the WHEN, so there is still exactly one answer to
	## "is this figure behind cargo" and it is `_occluded`.
	##
	## CLEARED ON THE ELSE, not just set on the if. A ghost that is only ever
	## turned on is a boarder who steps into the open still glowing through the
	## crate he is no longer behind.
	var rig: SkyGearRig3D = _captain if key == "player" else _rigs.get(key)
	if rig != null:
		rig.silhouette(hidden, tint)
		return
	## The painted-plate path, kept for anything genuinely drawn as a sprite.
	var source: Sprite3D = _billboards.get(key)
	if source == null or source.texture == null:
		return
	if not hidden:
		return
	var ghost_key := "xr_" + key
	_used[ghost_key] = true
	var ghost: Sprite3D = _claim_billboard(ghost_key, BILLBOARD_GHOST)
	ghost.texture = source.texture
	ghost.pixel_size = source.pixel_size
	ghost.position = source.position
	ghost.modulate = tint


func _texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _textures.has(path):
		return _textures[path]
	if not ResourceLoader.exists(path):
		_textures[path] = null
		return null
	var tex: Texture2D = load(path)
	_textures[path] = tex
	return tex


func _player_texture() -> Texture2D:
	var sprite := game.player.get_node_or_null("Sprite") as Sprite2D
	if sprite != null and sprite.texture != null:
		return sprite.texture
	return _texture("res://assets/art/heroes/corsair_front_idle.png")


## --- SG-81: MODEL LIGHTS — the accents a generated mesh does not carry --------
##
## The owner's ask, verbatim: "can we add a way to map lighting effects to 3D
## models in the lab? (Add customization around types of lighting, color,
## strength, etc... anything that can be useful here since the models don't have
## baked lighting)".
##
## THE READER IS HERE AND IT CAME FIRST. `assets/models/lights.json` is a table
## keyed by MODEL KEY — one row per directory under `assets/models/` — and every
## LIVE INSTANCE of that key wears it: all three braziers, every furnace knight
## in the wave, the corpse of one still playing `die`. `tools/model_lab.gd`
## writes that file; nothing about the lab is on this path, so a light tuned in
## the lab is a light the game has.
##
## A SIDECAR JSON RATHER THAN METADATA ON THE .tscn, for the reason
## `weapons.json` is a file: those scenes are GENERATED (`tools/static_model.gd`,
## `tools/ingest_model.py`) and a re-ingest — the furnace knight has had two —
## would silently eat anything written into them. A sidecar also diffs, which is
## how anybody but the person who dialled it can see what changed.
##
## AN ABSENT FILE IS TODAY'S RENDERING, EXACTLY. `_model_light_rows` stays empty,
## `_flush_model_lights` returns on its first line, no node is ever made, and the
## two hard-coded accents this table can supersede — the brazier/lantern omni in
## the prop loop, and the Boiler's furnace lamp — are left exactly where they
## were. A key WITH a row REPLACES the built-in rather than adding to it: two
## lights on one flame is the two-functions-disagreeing-about-one-number failure
## STATUS names, with a candle in it.
##
## MODEL LIGHTS ARE ACCENTS, NOT SUNS. That is SG-34's law and here it is
## arithmetic rather than a promise:
##
##   * `MODEL_LIGHT_MAX_ENERGY` / `MODEL_LIGHT_MAX_RANGE` clamp every row AS IT
##     IS READ, so a hand-typed 40 in the file is a 2.0 on the deck and the lab
##     cannot save a sun even by accident;
##   * `MODEL_LIGHT_CAP` is the SG-40 nearest-N-to-camera pattern, second use:
##     the deck asks for ten seeded lights and gets the eight nearest the
##     eye — the far ones keep their painted floor pool, which is most of what
##     reads as "lit" at this camera anyway;
##   * `MODEL_LIGHT_ENERGY_BUDGET` caps the SUM as well as the count, because a
##     cap on count alone is a cap a tuned file walks straight through.
##
## The SG-34 guard itself measures the ENVIRONMENT constants — exposure, ambient,
## the moon, the lantern fill, the furnace emission — and cannot see this table
## at all. Saying so is the honest half: the budget above is guarded separately,
## by `view · model lights are accents, and the budget says so in numbers`, and
## between them the two checks cover what one of them alone cannot.
## ---------------------------------------------- SG-17: the FX constants -----
## THE DIALS HAVE A HOME NOW, and the home was built the same way round as
## SG-81's: THE READER CAME FIRST. `tools/model_lab.gd`'s FX mode could tune
## effect constants on the real renderer and then had nowhere to put the answer,
## so SAVE copied the numbers to the clipboard with a comment saying which
## constant to paste them over. That is honest, and it is also a feature that
## ends in a human retyping a float. A file would have been worse — a table
## nothing reads is the failure this project has committed five times — so the
## renderer got the reader, and only then did SAVE start writing.
##
## WHAT IS IN HERE, AND WHAT DELIBERATELY IS NOT. Three of the lab's nine FX
## dials are RENDERER constants and all three are here. The other six are not
## constants at all and a file would be lying about them:
##
##   radius · arc · life · damage   arguments to the `_fx({...})` and
##                                  `impact_at()` calls, chosen per shape by the
##                                  SIMULATION at the moment it fires. Their home
##                                  is `game.gd`'s call sites and `game_data.gd`,
##                                  and the lab still hands those four to the
##                                  clipboard with the call they belong to.
##   period · slowmo                the LAB's own controls — how often the
##                                  preview re-fires, and `Engine.time_scale`
##                                  while you watch it. Neither exists in a run.
##
## AN ABSENT FILE IS TODAY'S RENDERING, EXACTLY, because `FX_DEFAULT` is the
## number the renderer shipped with in each case: glow 0.32 is what
## `_build_world` set, and the two particle figures are 1.0 multipliers.
const FX_PATH := "res://assets/models/fx.json"

## Every key here is READ by the renderer and the twin-guard walks them one at a
## time — `view · every dial in the fx table is read by the renderer`. A key
## that stops being spent fails the build rather than going quiet.
const FX_DEFAULT := {
	## Environment.glow_intensity — the bloom over every emissive surface.
	"glow": 0.32,
	## A multiplier on all three `PARTICLE_BODY` girths and lengths.
	"spark": 1.0,
	## Seconds a hit particle lives, on all three families.
	"particle_life": 1.0,
}

## Clamped AS THEY ARE READ, the `MODEL_LIGHT_MAX_*` rule: a hand-typed 40 in
## the file is the ceiling on the deck, and the lab cannot save past it either,
## because the lab saves THROUGH this reader. The ceilings are the point at
## which each dial stops being a tuning and starts being a different game:
## bloom that eats the deck, particles the size of the captain, sparks that
## outlive the wave.
const FX_LIMITS := {
	"glow": [0.0, 1.2],
	"spark": [0.2, 4.0],
	"particle_life": [0.1, 4.0],
}

## What the renderer is actually spending. `FX_DEFAULT` until `_build_world`
## reads the file, and `FX_DEFAULT` for ever if there is no file.
var _fx_tuning: Dictionary = FX_DEFAULT.duplicate()


## WHERE EACH DIAL IS SPENT, one function apiece. The builders call these, the
## LAB calls these, and the harness walks these — so a dial has exactly one
## expression in the whole project instead of one in `_build_impacts`, a second
## in `model_lab.gd` and a third in a check that agrees with neither. That is
## the arrangement `SkyGearHUD.rail()` and `ink.gd` exist to enforce elsewhere,
## and it is what makes "every dial is read" a fact rather than a hope.
static func fx_glow(tuning: Dictionary) -> float:
	return float(tuning.get("glow", FX_DEFAULT.glow))


static func fx_particle_life(tuning: Dictionary) -> float:
	return float(tuning.get("particle_life", FX_DEFAULT.particle_life))


## Girth and length of one particle family's body, in WORLD units, with the
## SPARK dial applied as a scale on the authored figures.
static func fx_particle_body(tuning: Dictionary, family: String) -> Vector2:
	var body: Dictionary = PARTICLE_BODY[family]
	var fat: float = float(tuning.get("spark", FX_DEFAULT.spark))
	return Vector2(float(body.girth), float(body.long)) * fat * WORLD_SCALE


## The table, checked. A missing file, an unreadable file, an unparseable file
## and a file that is not an object all mean the same thing, and it is not an
## error: today's rendering.
static func load_fx(path: String = FX_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return FX_DEFAULT.duplicate()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FX_DEFAULT.duplicate()
	var text := file.get_as_text()
	file.close()
	return sanitise_fx(JSON.parse_string(text))


## PER-KEY FALLBACK, the `hud_layout`/lights rule: a malformed or out-of-range
## dial costs THAT DIAL and leaves the two beside it standing. A half-typed file
## costs you the thing you were half-typing, never the frame. An unknown key is
## dropped rather than carried, so a typo cannot masquerade as a feature.
static func sanitise_fx(raw: Variant) -> Dictionary:
	var out: Dictionary = FX_DEFAULT.duplicate()
	if raw is not Dictionary:
		return out
	var dials: Variant = (raw as Dictionary).get("fx")
	if dials is not Dictionary:
		return out
	for key in FX_DEFAULT.keys():
		var value: Variant = (dials as Dictionary).get(key)
		if value is not float and value is not int:
			continue
		var span: Array = FX_LIMITS[key]
		out[key] = clampf(float(value), float(span[0]), float(span[1]))
	return out


## THE WRITE, beside the read so the two cannot drift — `tools/model_lab.gd`
## calls this and nothing else, and it goes back out THROUGH `sanitise_fx`, so
## what is saved is exactly what will be read. Returns "" on success or the
## reason, because a save that quietly does nothing is the shape SG-83 was.
static func save_fx(dials: Dictionary, path: String = FX_PATH) -> String:
	var doc := {"version": 1, "fx": sanitise_fx({"fx": dials})}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "could not open %s for writing" % path
	file.store_string(JSON.stringify(doc, "  ") + "\n")
	file.close()
	return ""


const MODEL_LIGHTS_PATH := "res://assets/models/lights.json"

## Eight live model lights at once. The seeded deck asks for ten (three
## braziers, three lanterns, three vents and the Boiler, plus one per furnace
## knight in the wave) and at this camera you see about half a deck, so the
## nearest eight is every one that reads and none that does not.
const MODEL_LIGHT_CAP := 8
## Per-row ceilings, applied at READ time. 2.0 is a shade over the moon key's
## 1.45: enough for a furnace chest to carry across the deck, nowhere near
## enough to be a second key at a 460-unit reach.
const MODEL_LIGHT_MAX_ENERGY := 2.0
const MODEL_LIGHT_MAX_RANGE := 460.0        ## ground units
const MODEL_LIGHT_MAX_HZ := 40.0
## And the sum. Today's deck carries 7.39 of fixed accent energy (three braziers
## at 1.2, three lanterns at 0.82, the Boiler lamp at 1.33); the seeded table
## asks 10.24 with the vents on top. 7.5 is deliberately just over the number the
## deck already lives at, so the table cannot make the deck brighter than the one
## SG-34 measured and signed off — it can only move that light around.
const MODEL_LIGHT_ENERGY_BUDGET := 7.5
## The Boiler lamp at full health, which is what `_boiler_lamp()` returns for
## `life = 1`. The seeded `boiler` row is authored at exactly this energy so the
## table reproduces the built-in lamp, and `_model_light_gain` divides by it to
## turn the health drive back into a multiplier.
const BOILER_LAMP_FULL := 1.33

## What a row means when it does not say. Every key here is read by
## `_apply_model_light` below — the twin-guard pins that, one field at a time.
const MODEL_LIGHT_DEFAULT := {
	"type": "omni", "color": "ffffff", "energy": 1.0, "range": 200.0,
	"attenuation": 1.0, "offset": [0.0, 0.0, 0.0],
	"angle": 45.0, "aim": [0.0, -1.0, 0.0],
	"hz": 0.0, "depth": 0.0, "shape": "pulse",
}
const MODEL_LIGHT_TYPES := ["omni", "spot"]
## PULSE is a clean sine — the smooth throb the brazier and the vent have always
## had. FLICKER adds a faster out-of-step term so the crest never lands twice in
## the same place: a fire guttering rather than a lamp humming. Both are read.
const MODEL_LIGHT_SHAPES := ["pulse", "flicker"]

## model key -> Array of normalised rows. Empty when there is no file.
var _model_light_rows: Dictionary = {}
## The pools, one per light class — a spot is not an omni, and handing one node
## to the other role would need every property rewritten anyway.
var _model_omnis: Array[OmniLight3D] = []
var _model_spots: Array[SpotLight3D] = []
## Hosts that are neither a pooled prop mesh nor a rig and never move: the
## Boiler. `{"key": model key, "node": Node3D}`.
var _model_light_statics: Array = []
## What the last frame actually spent, for the lab's header and the harness.
var _model_lights_live := 0
var _model_lights_asked := 0
var _model_lights_energy := 0.0


## The table, checked. A missing file, an unreadable file, an unparseable file
## and a file that is not an object all mean the same thing, and it is not an
## error: no model lights, today's rendering.
static func load_model_lights(path: String = MODEL_LIGHTS_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	return sanitise_model_lights(JSON.parse_string(text))


## THE WRITE, living beside the read so the two cannot drift — `tools/model_lab.gd`
## calls this and nothing else. Only the ONE model key handed in is touched: a
## tool that rewrites more than it was asked to is a tool nobody runs twice
## (`weapons.json`, the same rule, the same sentence). Every row goes back out
## through `model_light_row`, so what is saved is exactly what will be read, and
## an empty list ERASES the key rather than leaving `"lights": []` behind.
## Returns "" on success, or the reason, because a save that quietly does
## nothing is the shape of bug SG-83 was.
static func save_model_lights(model_key: String, rows: Array,
		path: String = MODEL_LIGHTS_PATH) -> String:
	var table: Variant = null
	if FileAccess.file_exists(path):
		table = JSON.parse_string(FileAccess.get_file_as_string(path))
	var doc: Dictionary = table as Dictionary if table is Dictionary else {"version": 1}
	if doc.get("models") is not Dictionary:
		doc["models"] = {}
	var models: Dictionary = doc["models"]
	var kept: Array = []
	for raw in rows:
		if raw is Dictionary:
			var row: Variant = model_light_row(raw)
			if row != null:
				kept.append(row)
	if kept.is_empty():
		models.erase(model_key)
	else:
		var was: Variant = models.get(model_key)
		var entry: Dictionary = was as Dictionary if was is Dictionary else {}
		entry["lights"] = kept
		models[model_key] = entry
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "could not open %s for writing" % path
	file.store_string(JSON.stringify(doc, "  ") + "\n")
	file.close()
	return ""


## PER-KEY FALLBACK, and finer than per-key where it can be — the `hud_layout`
## precedent. A model whose entry is not a list of rows loses THAT MODEL and no
## other; a single malformed ROW inside a good model loses that one light and
## leaves its neighbours lit. A half-typed file costs you the thing you were
## half-typing, never the deck.
static func sanitise_model_lights(raw: Variant) -> Dictionary:
	var out := {}
	if raw is not Dictionary:
		return out
	var models: Variant = (raw as Dictionary).get("models")
	if models is not Dictionary:
		return out
	for key in (models as Dictionary).keys():
		var entry: Variant = (models as Dictionary)[key]
		var list: Variant = entry
		## Either `"brazier": [ ... ]` or `"brazier": {"lights": [ ... ]}`. The
		## second is the shape the lab writes, because a model row is where a
		## future per-model field would go and a bare array has nowhere to put one.
		if entry is Dictionary:
			list = (entry as Dictionary).get("lights")
		if list is not Array:
			continue
		var kept: Array = []
		for item in (list as Array):
			var row: Variant = model_light_row(item)
			if row != null:
				kept.append(row)
		if not kept.is_empty():
			out[str(key)] = kept
	return out


## ONE LIGHT, CHECKED AND CLAMPED — or null, which drops it.
##
## The normalised row carries ONLY the keys that are read for its type: an omni
## has no `angle` and no `aim`, because nothing would consume them, and a steady
## light has no `hz`/`depth`/`shape`. That is the `hud_layout` "zero halves are
## ERASED" rule, and it is the same rule for the same reason — a field in a file
## that nothing reads is failure mode one with a colour picker on it.
static func model_light_row(raw: Variant) -> Variant:
	if raw is not Dictionary:
		return null
	var d := raw as Dictionary
	var type := str(d.get("type", MODEL_LIGHT_DEFAULT["type"]))
	if not type in MODEL_LIGHT_TYPES:
		return null
	var colour := str(d.get("color", MODEL_LIGHT_DEFAULT["color"]))
	if not Color.html_is_valid(colour):
		return null
	var offset: Variant = _light_triple(d.get("offset", MODEL_LIGHT_DEFAULT["offset"]))
	if offset == null:
		return null
	var energy: Variant = _light_number(d.get("energy", MODEL_LIGHT_DEFAULT["energy"]))
	var reach: Variant = _light_number(d.get("range", MODEL_LIGHT_DEFAULT["range"]))
	var fall: Variant = _light_number(d.get("attenuation", MODEL_LIGHT_DEFAULT["attenuation"]))
	if energy == null or reach == null or fall == null:
		return null
	var row := {
		"type": type,
		"color": Color(colour).to_html(false),
		"energy": clampf(float(energy), 0.0, MODEL_LIGHT_MAX_ENERGY),
		"range": clampf(float(reach), 1.0, MODEL_LIGHT_MAX_RANGE),
		"attenuation": clampf(float(fall), 0.1, 8.0),
		"offset": offset,
	}
	if type == "spot":
		var angle: Variant = _light_number(d.get("angle", MODEL_LIGHT_DEFAULT["angle"]))
		var aim: Variant = _light_triple(d.get("aim", MODEL_LIGHT_DEFAULT["aim"]))
		if angle == null or aim == null:
			return null
		if Vector3(float(aim[0]), float(aim[1]), float(aim[2])).length_squared() < 1e-6:
			return null
		row["angle"] = clampf(float(angle), 1.0, 89.0)
		row["aim"] = aim
	var hz: Variant = _light_number(d.get("hz", MODEL_LIGHT_DEFAULT["hz"]))
	var depth: Variant = _light_number(d.get("depth", MODEL_LIGHT_DEFAULT["depth"]))
	if hz == null or depth == null:
		return null
	if float(hz) > 0.0 and float(depth) > 0.0:
		var shape := str(d.get("shape", MODEL_LIGHT_DEFAULT["shape"]))
		if not shape in MODEL_LIGHT_SHAPES:
			return null
		row["hz"] = clampf(float(hz), 0.0, MODEL_LIGHT_MAX_HZ)
		row["depth"] = clampf(float(depth), 0.0, 1.0)
		row["shape"] = shape
	return row


static func _light_number(raw: Variant) -> Variant:
	if raw is float or raw is int:
		return float(raw)
	return null


static func _light_triple(raw: Variant) -> Variant:
	if raw is not Array or (raw as Array).size() != 3:
		return null
	for i in 3:
		if _light_number(raw[i]) == null:
			return null
	return [float(raw[0]), float(raw[1]), float(raw[2])]


## A row filled out with the defaults for the keys it dropped — what the applier
## and the lab both read, so the file's sparseness never becomes a second set of
## rules about what a missing key means.
static func model_light_full(row: Dictionary) -> Dictionary:
	var out: Dictionary = MODEL_LIGHT_DEFAULT.duplicate(true)
	for key in row.keys():
		out[key] = row[key]
	return out


## The brightness multiplier a row is riding this instant. `pulse` is the clean
## sine the brazier and the vent have always used — seeded at the same hz and
## depth, so those two objects breathe exactly as they did. `flicker` is a fire.
static func model_light_throb(row: Dictionary, clock: float, phase: float) -> float:
	var hz := float(row.get("hz", 0.0))
	var depth := float(row.get("depth", 0.0))
	if hz <= 0.0 or depth <= 0.0:
		return 1.0
	var wave := sin(clock * hz + phase)
	if str(row.get("shape", "pulse")) == "flicker":
		wave = (wave + 0.5 * sin(clock * hz * 2.37 + phase * 1.7)) / 1.5
	return maxf(0.0, 1.0 + depth * wave)


## Is this model key lit from the table? The prop loop and the Boiler both ask,
## because a key with a row takes the built-in accent's place rather than
## doubling it.
func model_lit_by_table(model_key: String) -> bool:
	return _model_light_rows.has(model_key)


## A live multiplier the SIMULATION owns rather than the file. Exactly one row
## has one — the Boiler, whose lamp goes out as it dies, which is a fact about
## the run and not a number anybody should be able to dial. Everything else is
## 1.0, and `_boiler_lamp()` stays the single copy of that arithmetic.
func _model_light_gain(model_key: String) -> float:
	if model_key == BOILER_MODEL and game != null:
		return _boiler_lamp() / BOILER_LAMP_FULL
	return 1.0


## Every live wearer of a lit model key, this frame: pooled prop meshes, rigged
## boarders, the captain, corpses still playing their death, and the statics.
func _model_light_requests() -> Array:
	var out: Array = []
	if _model_light_rows.is_empty():
		return out
	## `[model key, node, is a figure]`. The third column is the budget's tie
	## break — see `_flush_model_lights`.
	var hosts: Array = []
	for key in _prop_models:
		var node: Node3D = _prop_models[key]
		hosts.append([str(node.get_meta("prop_model", "")), node, false])
	for key in _rigs:
		var rig: SkyGearRig3D = _rigs[key]
		hosts.append([str(rig.get_meta("model_key", "")), rig, true])
	for key in _corpses:
		var corpse: SkyGearRig3D = (_corpses[key] as Dictionary).rig
		if is_instance_valid(corpse):
			hosts.append([str(corpse.get_meta("model_key", "")), corpse, true])
	if _captain != null:
		hosts.append([str(_captain.get_meta("model_key", "")), _captain, true])
	for entry in _model_light_statics:
		var node: Node3D = (entry as Dictionary).node
		if is_instance_valid(node):
			hosts.append([str((entry as Dictionary).key), node, false])
	for host in hosts:
		var model_key: String = str(host[0])
		if not _model_light_rows.has(model_key):
			continue
		var node: Node3D = host[1]
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		## The host's ROTATION without its scale: a prop mesh is scaled by
		## `_sync_prop_model` and a rig by its own fit height, and an offset in
		## ground units must not ride either — the same reason the captain's key
		## light hangs OUTSIDE her transform.
		var xf := node.global_transform
		var turn := xf.basis.orthonormalized()
		var gain := _model_light_gain(model_key)
		var phase := float(node.get_instance_id() % 17)
		for row_any in (_model_light_rows[model_key] as Array):
			var row: Dictionary = row_any as Dictionary
			var offset: Array = row.get("offset", [0.0, 0.0, 0.0])
			var at: Vector3 = xf.origin + turn * (Vector3(float(offset[0]),
				float(offset[1]), float(offset[2])) * WORLD_SCALE)
			out.append({"row": row, "at": at, "turn": turn, "gain": gain,
				"phase": phase, "figure": bool(host[2])})
	return out


## Resolve the frame's model lights against the budget: nearest to the camera
## first, admitted while BOTH the count cap and the summed-energy budget hold.
## A light that does not fit is simply not lit — never half-lit, never scaled
## down to fit, because a lamp that dims as you walk toward it is worse than one
## that was never there. This is the SG-40 pattern, second use.
func _flush_model_lights() -> void:
	if _model_light_rows.is_empty():
		return
	var wanted := _model_light_requests()
	_model_lights_asked = wanted.size()
	var eye: Vector3 = camera.global_position if camera != null else Vector3.ZERO
	## FIGURES FIRST, then nearest to the camera. Not a preference — a rule with
	## a reason: a brazier that loses its light keeps the painted floor pool that
	## has always been most of its read at this camera, and a boarder has nothing
	## to fall back on. Without this the deck's own furniture, which sits behind
	## the captain and is therefore NEARER the eye than anything she is fighting,
	## spends the whole budget on scenery she has her back to (measured: seven
	## props took 7.40 of 7.50 and the three furnace knights up-deck got none).
	wanted.sort_custom(func(a, b):
		if bool(a.figure) != bool(b.figure):
			return bool(a.figure)
		return (a.at as Vector3).distance_squared_to(eye) < (b.at as Vector3).distance_squared_to(eye))
	var omni_at := 0
	var spot_at := 0
	var spent := 0.0
	var live := 0
	for want in wanted:
		var row: Dictionary = want.row
		var energy := float(row.get("energy", 0.0))
		if live >= MODEL_LIGHT_CAP or spent + energy > MODEL_LIGHT_ENERGY_BUDGET:
			continue
		var spot: bool = str(row.get("type", "omni")) == "spot"
		var light: Light3D = _claim_model_light(spot, spot_at if spot else omni_at)
		if light == null:
			continue
		if spot:
			spot_at += 1
		else:
			omni_at += 1
		_apply_model_light(light, want)
		live += 1
		spent += energy
	## Everything the budget did not reach goes dark rather than stale. Kept in
	## the pool, not freed — the lit set changes as the camera walks the deck.
	while omni_at < _model_omnis.size():
		_model_omnis[omni_at].light_energy = 0.0
		omni_at += 1
	while spot_at < _model_spots.size():
		_model_spots[spot_at].light_energy = 0.0
		spot_at += 1
	_model_lights_live = live
	_model_lights_energy = spent


func _claim_model_light(spot: bool, at: int) -> Light3D:
	var pool: Array = _model_spots if spot else _model_omnis
	if at < pool.size():
		return pool[at]
	if pool.size() >= MODEL_LIGHT_CAP:
		return null
	var light: Light3D = SpotLight3D.new() if spot else OmniLight3D.new()
	## No shadows, ever. Eight shadow-casting accents is the frame budget gone
	## on something nobody would name if you asked them what had changed.
	light.shadow_enabled = false
	add_child(light)
	if spot:
		_model_spots.append(light as SpotLight3D)
	else:
		_model_omnis.append(light as OmniLight3D)
	return light


## WHERE EVERY FIELD IS SPENT. The twin-guard walks this function's effects one
## key at a time — move a field in the row, something on the Light3D has to move
## — so a field can never be added to the schema and to the lab without also
## being read here.
func _apply_model_light(light: Light3D, want: Dictionary) -> void:
	apply_model_light(light, want.row, want.at, want.turn, float(want.gain),
		_flicker, float(want.phase))


## STATIC, AND THE ONLY IMPLEMENTATION. `tools/model_lab.gd` calls exactly this
## to light the model you are dialling, so what the lab shows you and what the
## deck draws are the same twelve lines rather than two readings of one schema
## — the failure mode `SkyGearHUD.rail()` and `scripts/ink.gd` both exist over.
static func apply_model_light(light: Light3D, row: Dictionary, at: Vector3,
		turn: Basis, gain: float, clock: float, phase: float) -> void:
	var throb := model_light_throb(row, clock, phase)
	light.position = at
	light.light_color = Color(str(row.get("color", "ffffff")))
	light.light_energy = float(row.get("energy", 1.0)) * throb * gain
	var reach := float(row.get("range", 200.0)) * WORLD_SCALE
	var fall := float(row.get("attenuation", 1.0))
	if light is SpotLight3D:
		var spot := light as SpotLight3D
		spot.spot_range = reach
		spot.spot_attenuation = fall
		spot.spot_angle = float(row.get("angle", 45.0))
		var aim: Array = row.get("aim", [0.0, -1.0, 0.0])
		var dir: Vector3 = (turn * Vector3(float(aim[0]),
			float(aim[1]), float(aim[2]))).normalized()
		## A spot points down its own -Z. `look_at` needs an up that is not the
		## direction itself, and the useful aim for a model light is very often
		## straight down.
		var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.BACK
		spot.look_at_from_position(at, at + dir, up)
	else:
		var omni := light as OmniLight3D
		omni.omni_range = reach
		omni.omni_attenuation = fall
