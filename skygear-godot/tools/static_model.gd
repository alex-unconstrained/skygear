extends SceneTree
## Wrap a generated GLB as a scene the renderer can already drive.
##
##   godot --path . --headless --import                  (once, after downloading)
##   godot --path . --headless --script tools/static_model.gd
##
## `tools/ingest_model.py` exists for RIGGED characters and solves six problems
## none of which a Meshy text-to-3D result has: it has no skeleton, no clips, no
## second rest pose to retarget from and no 190 MB archive. Running it here would
## be most of an afternoon of machinery to move one mesh. What a static model
## does need is four things, and every one of them is a bug we have already paid
## for once:
##
##   1. **A holder.** The imported root carries the exporter's unit scale.
##      `SkyGearRig3D.place()` writes a transform onto the node it was given, so
##      the model goes one level down and the scene root takes the writes. This
##      is the bug that rendered the captain at one hundredth of a metre.
##   2. **Feet at the origin.** Meshy centres a mesh on its own bounding box, and
##      `place()` puts the rig root on the deck at y=0 — so a centred boarder
##      stands in the planking up to the waist. The holder is lifted by the
##      measured floor of the mesh instead.
##   3. **A facing.** `place()` yaws from the aim vector and a yaw of zero looks
##      down +Z. Nothing makes a generator agree, and a boarder charging at you
##      backwards is worse than a billboard that never turns at all. One number
##      per model, in the table below, checked by looking.
##   4. **A measured height.** `setup()` falls back to the TALLEST single
##      MeshInstance3D when there is no `model_height`, which is the whole model
##      only for as long as every model arrives in one piece. A boarder whose
##      weapon or backpack came back as its own mesh would be scaled to the
##      height of the tallest part instead of to its own. The union is measured
##      here, once, and written into the scene as `model_height`.
##
## Output is `assets/models/<key>/<key>.tscn`, which is exactly where
## `SkyGearView3D.model_path()` looks. No renderer change: dropping a boarder in
## is running this.
func _initialize() -> void: call_deferred("_run")


## key -> degrees about +Y to turn the model so it faces +Z, which is the rest
## facing every other figure on this deck is placed against.
##
## Checked by rendering both sides, not guessed — the first pass through here
## assumed 180 and put the whole batch on the deck backwards, which at a locked
## 41-degree camera reads as five boarders retreating.
##
## This batch all came back facing +Z already, so every number is zero. The
## column stays because it is per-model: the value is a property of whatever
## exported the file, and the next asset from anywhere else has no reason to
## agree with these five.
##
## It is also the switch for WHICH boarders are meshes. A kind with no entry
## here gets no `.tscn`, `_sync_rig` does not find one, and the renderer keeps
## its painted billboard — which is the right answer whenever a generated model
## reads worse than the art it is replacing.
const MODELS := {
	"scrapper": 0.0,
	## The GUNNER, and it is the only boarder that BELONGS in this table.
	## Everything else here was a lump waiting for a rig; the drone is a lump on
	## purpose — no legs, no spine, no arms to put auto-rig markers on, and the
	## handoff spec called it before a file existed. Its `.glb` is not a Meshy
	## download any more: `tools/split_rotors.py` writes it, cutting the owner's
	## textured export into `Body` plus three `Rotor*` children so
	## `SkyGearView3D.ROTOR_MOTION` can turn them. This wrapper is unchanged by
	## that — it measures a union and stands it on the deck, and a model in four
	## pieces is exactly what its own `_measure` docstring was written for.
	"gunner": 0.0,
	## "swarm" is RIGGED now and its lump is deleted. The goblin was the last
	## handoff-3d figure; the owner modelled and auto-rigged it (board SG-89,
	## `tools/models.json`), so it is an ingest entry rather than a wrap, and
	## `assets/models/swarm/swarm.glb` is gone rather than shadowed — a wrapper
	## row pointing at a file that is not there is a `push_error` on every run
	## of this tool.
	"boss": 0.0,
	## "armored" is generated and on disk and is deliberately NOT here.
	##
	## TWO ATTEMPTS. The first came back a slim red knight with a teal lamp on its
	## belt. The second — after fixing a real prompt contradiction, where PALETTE
	## ended with "no glow" while the same prompt asked for a GLOWING orange
	## furnace grate — came back a heavy plate knight with the right silhouette,
	## a grey-and-yellow palette that is not ours, a dark grille where the furnace
	## should burn, no chimney, and a teal axe blade.
	##
	## The billboard is a barrel-chested hulk in brass and oxblood with an orange
	## furnace burning in its chest, a chimney over one shoulder and a pressure
	## gauge on the pauldron. Both are "an armoured figure with an axe"; only one
	## of them is unmistakably THIS game, and only one reads as the enemy with 180
	## hp that you cannot simply walk through.
	##
	## The generator is good at silhouette and bad at a specific character, and
	## sixty credits was a fair price for finding that out. The painted knight
	## stays. If someone re-rolls again, the bar is the billboard, not the
	## previous mesh.

	## --- the deck props ------------------------------------------------------
	## Same table, same two jobs, and for these the FACING column earns its
	## keep in a way it did not for the boarders. A boarder turns to face
	## whatever it is walking at, so a wrong rest facing is wrong for one frame
	## in ten; a prop never turns at all, so whichever face the generator put on
	## +Z is the face the player looks at for the whole run. The keg's red flame
	## triangle, the vent's gauge and the lantern's lit panes are each on exactly
	## one side of the object.
	##
	## `SkyGearView3D.PROP_MODEL` is the other half of the switch: a model can be
	## wrapped here and still be left painted there, which is the cheap way to
	## park one that came back wrong without deleting the file.
	## The objective. Faces +Z already, which for this one is not luck being
	## relied on but the thing to check first: the furnace door is on one face,
	## the camera never leaves +Z, and a boiler turned round is a brass barrel.
	"boiler": 0.0,

	## "boarding_hulk" is generated THREE times, and deliberately NOT here.
	## The owner reopened the two-rejection verdict for ONE more prompted
	## attempt with hard constraints (board SG-64), it failed on a NEW axis,
	## and by the owner's own condition THE HAND-MODEL VERDICT IS NOW FINAL
	## (board SG-21). Do not prompt a fourth.
	##
	## v1 came back a submarine. v2 came back a good model as deep as it was
	## wide, so at the locked 41-degree camera its mass went up out of frame
	## and what stayed on screen was a pale staircase.
	##
	## v3 (SG-64) said wall, theatre flat, "depth a quarter of its width",
	## ramps as low separate geometry — and the GEOMETRY LESSONS LANDED at the
	## judging pose (.shots/sg64/hulk-after-mid.png against hulk-before-mid):
	## a wall across the top of the frame, the fire door glowing mid-wall, a
	## ramp lying on the planking. Two failures anyway, either one fatal:
	##
	##   * the depth constraint was ignored a third time — measured 1.899 wide
	##     x 1.639 DEEP, 86% against the asked 25%. Three prompts, three
	##     depth failures: text-to-3D will not hold a depth ratio, now known
	##     at ninety credits' certainty.
	##   * "fortress gate" won over the palette: pale cracked STONE MASONRY
	##     where every painted state wears dark iron plate and near-black
	##     timber, battlement crenellations, and a Gothic ARCH for a door
	##     where sealed/open/destroyed all wear the round iris. The renderer
	##     keeps the painted art for the other two states by design, so a
	##     hulk that breaks would pop from a stone arch-gate to a blown iron
	##     iris — a different object mid-fight, which is the crate v1
	##     rejection reason at forty times the size.
	##
	## Ninety credits total, and what they bought is the full shape of the
	## problem: the sprite stays until someone hand-models a wide, shallow,
	## iron-and-timber wall with the iris in it.
	##
	## AND THEN THE OWNER MADE IT HIMSELF (board SG-76, 2026-08-02) — three
	## files, one per painted state, which is the thing three prompted attempts
	## could not buy at any price: the same object wearing three faces. Each
	## state is its own model key because `_sync_prop_model` claims by key and
	## a state swap has to be a different scene, not a different material.
	##
	## FACING 0 IS MEASURED, not assumed. All three came back with the door on
	## +Z: rendered square-on at the game camera each one lands on its painting
	## — chimneys at the top corners, ramps splayed from the bottom corners,
	## the round iris dead centre (.shots/models/hulk-raw/*.png).
	##
	## THE MAPPING IS THE OWNER'S FILE NAMES SWAPPED, and it was verified by
	## looking rather than by reading: "Ironbound Gate" (stated OPEN) is the
	## SEALED face — chevron plate over the door, one thin red seam, and an
	## emission map that is ENTIRELY BLACK — and "Emberforge Core" (stated
	## CLOSED) is the one with the blazing iris and the only emission map in
	## the three with anything alight in it. "Clockwork Gate Fortress" is the
	## wreck it says it is. Names are ambiguous; a furnace either burns or it
	## does not.
	"boarding_hulk_sealed": 0.0,
	"boarding_hulk_open": 0.0,
	"boarding_hulk_destroyed": 0.0,

	"crate_stack": 0.0,
	"powder_keg": 0.0,
	"lantern_post": 0.0,
	"steam_vent": 0.0,
	"cannon_deck": 0.0,
	"salvage_pile": 0.0,

	## The ship's own furniture, board SG-64 — the owner's 2D purge. The mast
	## was the strongest case on the deck: 340 units at dead centre, in frame
	## the whole run, and the billboard reads as a thin translucent smear with
	## rigging that anchors to nothing (.shots/sg64/mast-before.png — note the
	## pole behind the captain, not the brown sheet, which is her SG-63 cape).
	## The mesh is a dark banded timber column with a railed crow's nest, a
	## ladder and a hung rope coil — the house palette, judged on the deck at
	## .shots/sg64/mast-after.png. Two departures recorded: it is a TOWER of a
	## mast (0.887 wide x 1.899 tall — ~159 ground units across at height 340,
	## against the painting's slender pole; "thick upright column" in the
	## prompt bought exactly what it said), and the "spiked brass finial"
	## resolved into a small red mace-like standard leaning off the nest. Both
	## read as steampunk furniture at 636 px; neither loses to a ghost.
	"mast_section": 0.0,

	## The bow-corner harpoon emplacements. FACING 0 IS A MEASURED CHOICE, not
	## a default: the machine is 1.899 long x 0.366 DEEP, so turned to fire
	## up-deck (facing 90, .shots/sg64/ballista-f90.png) the whole silhouette
	## collapses to a 44-unit-wide telescope on a stand. Side-on (facing 0,
	## .shots/sg64/ballista-after.png) it spans ~229 units of bow arms,
	## harpoon and pedestal — the same left-pointing pose the painted
	## billboard has always struck at BOTH corners, so the mesh changes
	## nothing about the fiction, only stops it being a card. The placed
	## SENTRY deliberately keeps the tinted billboard (`_place` at the sentry
	## block): a sentry that looks different from the ship's own emplacements
	## is the point — five identical guns was a filed complaint once.
	"harpoon_ballista": 0.0,

	## v2, board SG-64 — the owner reopened the v1 rejection and the re-roll
	## with v1's two recorded faults written into the prompt CLEARED THE BAR.
	##
	## v1's verdict, kept because it is why the v2 prompt reads as it does: its
	## entire job on this deck is to be a FIRE — one of only two props the
	## renderer hangs an OmniLight on — and v1 came back a bowl of grey-blue
	## rock ("charred black timber" in the texture line was the culprit), 1.898
	## wide by 0.925 tall so PROP_HEIGHT's 116 made it 238 ground units across.
	## v2 removed the timber clause, refused grey stone by name, and led with
	## "upright, taller than it is wide": it measures 1.234 x 1.895 x 1.145 —
	## ~76 units wide on the deck — and at the real 41-degree camera the open
	## basket shows a coal bed blazing hot orange INTO the lens, agreeing with
	## its own light where the painted side-on bowl only implied it
	## (.shots/sg64/deck-brazier.png against deck-before.png). The dangling
	## side-strap greeble reads as tassel-sized at 217 px and was not worth a
	## re-roll against a 200-credit wave cap.
	"brazier": 0.0,

	## v2, board SG-64 — reopened with v1's lesson in the prompt, and CLEARED.
	##
	## v1 came back a bright orange treasure chest with a big gold clasp: "one
	## oxblood leather strap ... with a brass buckle" is a chest fastening, so
	## it was given a chest; and its SURFACE_WOOD frame asked for "warm polished
	## brass corner brackets" against the subject's blue-steel ones — the
	## furnace knight's contradiction hiding in a texture frame. v2 says sealed
	## munitions crate nailed shut, refuses lid/hinges/lock/clasp/gold by name,
	## drops the buckle from both prompts and carries its own SURFACE_CRATE
	## clause. What came back is the crate: warm planks, blue-steel brackets,
	## oxblood banding, no gold anywhere, judged beside the painting at the
	## real camera (.shots/sg64/deck-crate.png). Two departures recorded
	## honestly: two straps where the painting wears one, and 1.896 x 1.374 x
	## 1.499 — a shade oblong against the painted cube. Neither reads at
	## 157 px, and a real cube's corners catching the deck light beats a card
	## that shows the same face from every position.
	"crate_small": 0.0,

	## v2, board SG-72 — the purge's unfunded tail, and the same shape as the
	## SG-64 pair: v1 lost, the fault was named INTO the prompt, and the re-roll
	## cleared the bar.
	##
	## v1's verdict, kept because it is why the v2 prompt reads as it does: it
	## came back STANDING ON A SOLID TIMBER BOARD, because the subject said the
	## stanchions stood "on round bolted base flanges" while the shared DECK
	## frame says "No base, plinth or ground plane" — one prompt carrying both
	## halves of an argument, the fourth time this file has been bitten by
	## exactly that. On the deck it read as a BENCH lying at the rail. Its
	## handrail also arrived pale bare timber against the painting's dark oiled
	## one, and its three rods merged into a single bar — which is the one thing
	## that could not be allowed, because the GAPS are the whole case for paying
	## for this prop rather than keeping the card.
	##
	## v2 measures 1.898 x 0.818 x 0.288 — ~120 ground units across at
	## PROP_HEIGHT 52 — stands on its own two feet, carries a dark rail, and
	## shows planking through three separate rods, lit by the deck's own lamps
	## where the painting carries its lighting baked in and blue-tinted
	## (.shots/sg72/railing-after-v2-crop.png against railing-before-crop.png
	## and the v1 railing-after-crop.png, same pose, same deck edge). One
	## departure recorded: at 2.3:1 it is a lower, wider rail than the
	## painting's ~1.35:1 — nearer a low fence than a waist rail.
	"railing_segment": 0.0,
	## THE EDGE RAIL, and it is NOT a bigger `railing_segment`. That one is a
	## 52-unit scattered deck PROP (view3d.gd PROP_HEIGHT/PROP_MODEL, four of
	## them). This is the module for DECK-IDENTITY item 4 — the continuous run
	## along the port and starboard edges that replaces the two solid
	## 14 x 40 x 2320 bars, specified there as "16 stanchions a side at 145-unit
	## spacing with two horizontal rails at y = 66 and 118". The two can coexist;
	## they are different objects doing different jobs, which is why this gets its
	## own key rather than overwriting a shipped one.
	##
	## MEASURED: 1.898 x 0.902 x 0.224 model units, 3,060 triangles — under the
	## 8,000 ceiling with no decimation, which is why it is the one edge piece
	## registered here. Three stanchions, two rails and a cap; the rail overhangs
	## 0.114 past each end stanchion, so butt-joining bunches stanchions in pairs
	## at every seam. THE TILING IS ARITHMETIC, NOT ART: place instances every TWO
	## stanchion pitches so the end stanchions of neighbouring modules coincide
	## and the pitch stays uniform through the seam. See NEEDS_ALEX and BOARD
	## SG-145 for the scale decision, which is the owner's and is not made here.
	##
	## Facing 0.0 is the measured default for this batch and the module is
	## symmetric about its long axis, so a half turn is the same rail.
	"rail_stanchion": 0.0,
	## THE OTHER THREE EDGE PIECES, registered here by SG-148 — they were left
	## out by SG-145 on the triangle law alone (mast 10,312, bow 30,666, stern
	## 30,410 against an 8,000 ceiling) and they are all three at 8,000 now.
	## `tools/deck_trim.py` did it locally, zero credits, geometry only: the
	## four embedded JPEGs are copied byte-for-byte into the rebuilt glb, so
	## every megabyte saved is a megabyte of vertex data and the maps are the
	## owner's own pixels.
	##
	## THE TARGET IS THE CEILING AND THAT WAS DECIDED BY LOOKING, WHICH IS THE
	## PART WORTH READING. `meshy.py`'s `tri_budget` asks for 3,000 for every
	## one of these — they are 141 to 355 px at the real camera, all below the
	## ~380 px where the area curve starts to bite, so all three land on its
	## FLOOR. Rendered at 3,000 the bow and the mast survive and THE STERN DOES
	## NOT: its planking goes blotchy and its hatch ring turns to mush
	## (.shots/sg148/compare/stern_counter_t3000-y035.png against
	## stern_counter_t8000-y035.png). The reason is a gap in the law rather than
	## a bad model — the budget is derived from an asset's HEIGHT, and the stern
	## is a 190 x 151 x 178 box whose entire interior deck faces a camera
	## looking DOWN at 41 degrees. Its visible area is nothing like its height
	## implies. Filed on the board; the number here is the evidence, not a
	## preference.
	##
	## Facing 0.0: measured, same as the rest of this batch.
	"mast_crowned": 0.0,
	"bow_ram": 0.0,
	"stern_counter": 0.0,
	## THE SECOND PAIR (SG-174). `bow_ram` and `stern_counter` above were REFUSED
	## by SG-157 on proportion — the bow a 3.64:1 fore-and-aft spike, the stern a
	## 1.25:1 near-cube that floated near the deck edge instead of meeting it —
	## and the owner remade both. They are kept side by side rather than
	## overwritten so the comparison stays available, which is the whole reason
	## these two carry new keys.
	##
	## MEASURED off the delivered files, before any trim:
	##   prow_ram          1.897 x 0.930 x 0.832   9,770 tris   2.28:1 WIDE
	##   stern_counter_v2  1.898 x 0.402 x 0.896   9,816 tris   4.72:1 WIDE
	##
	## Both trimmed to 3,000 by `tools/deck_trim.py` — the FLOOR, and the right
	## target for the same reason `rail_stanchion` shipped at 3,060 off the
	## owner's hand: same kit, same 190-unit width, same camera. Open boundary
	## edges 0 -> 0 on both, deviation 0.13% and 0.11% of the diagonal.
	##
	## Facing 0.0 for both, and for these two it is measured rather than
	## inherited: `prow_ram` is symmetric in X and very nearly so in Z (a broad
	## blunt block that tapers DOWNWARD, which is a hull section, not a plan
	## taper), so no yaw can be wrong about which end is the point; and
	## `stern_counter_v2`'s asymmetry is along X, which is the axis that faces
	## aft. See the placement note in `view3d.gd`.
	"prow_ram": 0.0,
	"stern_counter_v2": 0.0,

	## --- THE UPPER-DECK KIT (SG-178) ------------------------------------------
	## Four modules the owner made to `handoff-3d/ship_edge_kit/UPPER-DECK-KIT.md`,
	## and the first entries in this table that are a KIT rather than four objects:
	## the renderer tiles them, so the number of bays and the number of posts are
	## variables in `view3d.gd` and not a hand-placed list.
	##
	## MEASURED off the shipped files, in ground units, before any placement:
	##   upper_bay      189.6 x 107.8 x 152.2   2,688 tris
	##   upper_post      41.6 x 189.9 x  41.5   2,934 tris
	##   upper_stair    119.1 x 172.4 x 189.6   2,920 tris
	##   upper_corner    45.6 x 189.9 x  76.4   2,920 tris
	##
	## NOT DECIMATED, AND THAT IS THE CHANGE FROM SG-174 RATHER THAN AN OVERSIGHT.
	## The owner generates at ~3,000 now, `deck_trim.py`'s `NEAR_ENOUGH` passes
	## anything within 85% of budget straight through, and all four are already
	## there. Running a trim on a piece that does not need one is the SG-155
	## mistake in a new place: every collapse costs UV accuracy and buys nothing.
	## Maps shrunk to the kit budget (512/256/128/128) and `lamplit` clamped all
	## four from glTF's unset-means-1.0 down to 0.34 — `audit` is 0 of 40 over.
	##
	## THE FACINGS ARE MEASURED AND THREE OF THE FOUR ARE NON-ZERO, which is the
	## first batch in this table where the column has actually earned its keep on
	## more than one row. `.shots/sg148/sg178-id/` is the evidence, four yaws each:
	##
	##   upper_bay 180 — the piece is a floor with ONE deep side: its two curved
	##     knees and the beam they brace hang below the planking at -Z as authored,
	##     and the platform's deep side has to face AFT, toward the lens, because
	##     the underside and the beam under the near edge are the whole reason this
	##     kit exists (UPPER-DECK-KIT.md: "the most-seen surface in this whole kit
	##     is the underside of the platform"). At 0 the beam faces the bow and the
	##     player gets a plain plank edge.
	##   upper_post 0 — square in plan (41.6 x 41.5) with its collars and its foot
	##     plate turned all the way round. Every yaw is the same post; 0 is the
	##     honest entry for a piece with no front.
	##   upper_stair 0 — MEASURED, not defaulted: the top of the mesh falls
	##     monotonically from +0.86 at -Z to -0.16 at +Z, so the flight climbs
	##     toward -Z, which is FORWARD on this ship. That is the direction SG-176's
	##     mock proved is the only one that reads (a flight running aft-under the
	##     platform cannot be found in the frame), so the model arrived pointing
	##     the way the placement needs and nothing turns it.
	##   upper_corner 90 — the lantern is bracketed off ONE face: the mesh is
	##     45.6 across and 76.4 deep, and the extra depth is all on +Z, where the
	##     geometry stops at y +0.05 instead of running to the foot. Turning +Z to
	##     +X puts the lantern OUTBOARD, which is what §4 asks for — "a small
	##     bright point at the end of a long dark run is the cheapest way to make
	##     the eye find the corner", and a lantern pointing up-deck is behind the
	##     post from every camera this game has. The placement mirrors it per side.
	"upper_bay": 180.0,
	"upper_post": 0.0,
	"upper_stair": 0.0,
	"upper_corner": 90.0,
	## "hatch_cargo" is absent because it was GENERATED THREE TIMES AND
	## REJECTED — the first entry here that lost on its own merits rather than
	## on budget, and the reason is geometric rather than a prompt that can be
	## fixed:
	##
	##   v1  1.899 x 1.507 x 1.535 — a cube. "cargo deck hatch cover ... much
	##       wider than it is thick" lost the argument to the noun; the
	##       generator hears "cargo hatch" as a container with a lid, the same
	##       way crate_small's v1 heard "leather strap with a brass buckle" as a
	##       treasure chest.
	##   v2  the honest description of a flat panel ("only a hand deep ... not a
	##       box, not a crate, nothing hollow") FAILED AT PREVIEW three
	##       consecutive times, uncharged, at 99%. The preview stage will not
	##       build a near-flat plate.
	##   v3  flatness written as buildable geometry ("four times as wide as it
	##       is thick") came back 1.897 x 1.557 x 0.865 — a box again, standing
	##       proud of the planking with upright sides
	##       (.shots/sg72/hatch-after-v2-crop.png against hatch-before-crop.png).
	##
	## And underneath all three: a hatch cover lies FLAT IN the deck, so at the
	## locked 41-degree camera essentially all of it that reaches the player is
	## its own top face — which is a texture in both worlds. That is the rope
	## coil's standing verdict one size up, and 3D has nothing to add to it
	## except depth the object is not supposed to have. The prompts stay in
	## tools/meshy.py with this history so the decision can be revisited, not
	## re-discovered.
	##
	## "rope_coil" is deliberately absent and was never generated. It is 30
	## ground units tall — the shortest entry in PROP_HEIGHT by a factor of two —
	## and a mesh of a flat coil of rope and a billboard of one are the same
	## forty pixels at a locked 41-degree camera. The prompt is in
	## tools/meshy.py so the decision can be revisited for 30 credits.

	## --- THE TRANSPORT FLEET --------------------------------------------------
	## Five ships the owner generated himself from
	## `handoff-3d/skyship_transports/PROMPTS.md`, and the first entries in this
	## table that are not ON the deck at all: they fly BELOW AND AHEAD of it, in
	## the cloud sea. `tools/skyships.py` writes their `.glb`s — it holds the
	## whole story of what each one turned out to BE, because Meshy's names for
	## them are misleading without exception and the keys here are the roles the
	## sculpts actually fill.
	##
	## FACING 90 IS MEASURED AND IT IS THE SAME FOR ALL FIVE. Every ship came
	## back with its length on +X and its BOW at -X — read off the side and plan
	## renders in `.shots/skyships/id/`, where the skiff's coiled grapple hooks,
	## the cutter's ram prow and the barge's clear foredeck are all at screen
	## left and every engine block, stack and paddle wheel is at screen right.
	## Turning -X to +Z is +90 degrees, and that is the rest facing this table
	## promises. Which WAY a placed ship then points is a property of its
	## station, not of the model, so the extra half-turn that has the fleet
	## flying WITH us rather than at us lives in `view3d.gd`'s own table beside
	## the position it belongs to.
	##
	## The measured height each one gets is its KEEL-to-masthead union, and
	## `_wrap` stands that union's floor at the scene origin — so the y in a
	## station row is the ship's KEEL, which is the number you can reason about
	## when you are asking whether a hull clears the gunwale.
	"skyship_skiff": 90.0,
	"skyship_barge": 90.0,
	"skyship_cutter": 90.0,
	"skyship_tender": 90.0,
	## Ingested, budgeted and checked like the other four, and deliberately NOT
	## placed — see the board. It is the SECOND barge, and four archetypes is
	## what the handoff asked for; a fifth hull in the same sky is traffic
	## rather than a fleet. It costs 1.34 MB to have it ready on disk and one
	## row in `view3d.gd` to fly it, which is the right price for "later".
	"skyship_barge_heavy": 90.0,
}


## NAME KEYS TO REBUILD ONLY THOSE. With no arguments this still rebuilds all of
## them, which is the behaviour every existing caller has.
##
## THIS ARGUMENT EXISTS BECAUSE THE DEFAULT IS A RECORDED FOOT-GUN (board SG-72).
## `MODELS` is not a list of static props — it is also the switch for which
## boarders are meshes, so it carries `boss`, `scrapper` and `gunner`, whose
## scenes are built by OTHER tools: `tools/rig_parts.gd` writes the boss's
## thirteen-part scene and `tools/ingest_model.py` writes the rigged figures'.
## A blanket run overwrites those with dumb static holders built from whatever
## `<key>.glb` happens to sit beside them. It has happened once already: it
## clobbered `scrapper.tscn` and took the harness to 725/729, and it is written
## up in `NEEDS_ALEX.md` as something to remember rather than as something fixed.
##
## Adding one prop should not require re-deriving twenty-two other scenes and
## hoping none of them was authored by a different tool this week. So:
##
##   godot --path . --headless --script tools/static_model.gd -- railing_segment
##
## An unknown key is a FAILURE rather than a silent no-op, because the whole
## point of naming keys is that you believed you named a real one.
func _run() -> void:
	var only := OS.get_cmdline_user_args()
	var keys: Array = []
	if only.is_empty():
		keys = MODELS.keys()
		print("static_model: rebuilding ALL %d keys — this includes scenes other "
			% keys.size() + "tools own (boss, scrapper, gunner). See SG-72.")
	else:
		var bad_key := 0
		for a in only:
			if MODELS.has(a):
				keys.append(a)
			else:
				push_error("static_model: no such key %s" % a)
				bad_key += 1
		if bad_key > 0:
			quit(bad_key)
			return
		print("static_model: rebuilding %d named key(s): %s" % [keys.size(), str(keys)])
	var bad := 0
	for key in keys:
		if not _wrap(str(key), float(MODELS[key])):
			bad += 1
	quit(bad)


func _wrap(key: String, facing_degrees: float) -> bool:
	var glb_path := "res://assets/models/%s/%s.glb" % [key, key]
	if not ResourceLoader.exists(glb_path):
		push_error("%s: no %s - generate it first (python tools/meshy.py run boarders)"
			% [key, glb_path])
		return false
	var packed_glb := load(glb_path) as PackedScene
	if packed_glb == null:
		push_error("%s: %s did not load as a scene" % [key, glb_path])
		return false

	var root := Node3D.new()
	root.name = key.capitalize()
	## IN THE TREE while we measure. `global_transform` on a detached node returns
	## an identity and a warning, so the first version of this measured every model
	## unrotated and stood the boss on his own chin.
	get_root().add_child(root)
	var holder := Node3D.new()
	holder.name = "Holder"
	root.add_child(holder)
	holder.owner = root
	var model := packed_glb.instantiate()
	model.name = "Model"
	holder.add_child(model)
	## Owned by the ROOT, not by the holder, or `pack()` drops it: a node whose
	## owner is not the scene root is not part of the scene being packed.
	model.owner = root

	holder.rotation.y = deg_to_rad(facing_degrees)
	## Force the transforms down the tree before measuring. `get_global_transform`
	## on a node added this frame is still the value it was created with, and the
	## first measurement written this way was of an unrotated model.
	root.force_update_transform()
	holder.force_update_transform()

	var box := _measure(model, root)
	if box.size.y <= 0.0:
		push_error("%s: no mesh in the GLB, nothing to measure" % key)
		root.queue_free()
		return false
	## Stand it on the deck and centre it over its own feet. Both are measured
	## AFTER the yaw, because turning a model that was not centred moves it.
	holder.position = Vector3(-box.position.x - box.size.x * 0.5, -box.position.y,
		-box.position.z - box.size.z * 0.5)
	root.set_meta("model_height", box.size.y)

	var out := "res://assets/models/%s/%s.tscn" % [key, key]
	var scene := PackedScene.new()
	var packed_ok: bool = scene.pack(root) == OK
	var saved_ok: bool = packed_ok and ResourceSaver.save(scene, out) == OK
	root.queue_free()
	if not packed_ok:
		push_error("%s: pack failed" % key)
		return false
	if not saved_ok:
		push_error("%s: could not write %s" % [key, out])
		return false
	print("%-9s %5.3f x %5.3f x %5.3f model units, facing %+.0f deg -> %s"
		% [key, box.size.x, box.size.y, box.size.z, facing_degrees, out])
	return true


## The union of every mesh, in the scene root's frame — which is the frame
## `SkyGearRig3D` then scales. The max of the individual heights is not the same
## number as soon as a model arrives in more than one piece.
func _measure(model: Node, relative_to: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var inverse := relative_to.global_transform.affine_inverse()
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		var here := (inverse * mi.global_transform) * mi.get_aabb()
		box = here if first else box.merge(here)
		first = false
	return box
