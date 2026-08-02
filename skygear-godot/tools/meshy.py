#!/usr/bin/env python3
"""Generate 3D props through the Meshy API, from a manifest, resumably.

The melee animation pack swings a weapon the captain does not own. Modelling
one by hand is a day; Meshy's text-to-3D turns a written description into a
textured GLB in about four minutes, which is the right trade for a prop that is
a hundred and eighty pixels tall and mostly seen in motion.

This follows tools/forge.py and tools/ingest_model.py rather than inventing a
third shape:

  * every prompt lives in the ASSETS manifest below, in version control, next
    to the key it fills. Nothing is typed into a box and lost, so "why does
    this one look different" has an answer;
  * state lives in tools/meshy-state.json, so a crashed or interrupted run
    resumes against the task ids it already paid for instead of paying twice;
  * results land in assets/models/<key>/, next to the ingested captain.

  python tools/meshy.py list                    # manifest, task ids, what is on disk
  python tools/meshy.py balance                 # credits left
  python tools/meshy.py run sword --dry         # print exactly what would be sent
  python tools/meshy.py run sword               # generate the whole batch and download
  python tools/meshy.py run all --only sword_cutlass
  python tools/meshy.py fetch sword             # re-poll and download, submit nothing
  python tools/meshy.py remesh props            # cut it down to what the screen shows
  python tools/meshy.py prune props             # drop the 67 MB per asset we never load
  python tools/meshy.py show sword_cutlass      # raw task JSON from the API

THE API, as of the docs at docs.meshy.ai (checked before this was written):

  base            https://api.meshy.ai
  auth            Authorization: Bearer <key>          (no other scheme offered)
  text-to-3D      POST /openapi/v2/text-to-3d          two-stage: preview, then refine
  image-to-3D     POST /openapi/v1/image-to-3d         also multi-image, smart-topology
  text-to-image   POST /openapi/v1/text-to-image       nano-banana / gpt-image-2
  retexture       POST /openapi/v1/retexture           re-skin an existing mesh
  also            remesh, convert, resize, uv-unwrap, rigging, animation, printability
  balance         GET  /openapi/v1/balance             -> {"balance": <int>}
  create returns  {"result": "<task-id>"}              — the id, not the task
  poll            GET  /openapi/v2/text-to-3d/<id>     (or .../<id>/stream for SSE)
  states          PENDING -> IN_PROGRESS -> SUCCEEDED | FAILED | CANCELED
  prompt length   800 characters, hard 400 on the create call. The docs say 600.
  formats         model_urls: glb, fbx, obj+mtl, usdz, stl, 3mf — ask via target_formats
  PBR             refine with enable_pbr: true -> texture_urls[]: base_color,
                  metallic, normal, roughness (+ emission on meshy-6)
  rate limits     20 req/s; 10-100 concurrent generation tasks depending on plan.
                  429 = RateLimitExceeded (per second) or NoMoreConcurrentTasks.
  cost            meshy-6 preview 20 credits, refine 10 (2k/4k) or 15 (8k).
                  meshy-5 preview is 5. So one finished asset here is 30 credits.
  remesh          POST /openapi/v1/remesh, GET /openapi/v1/remesh/<id>, 5 credits.
                  input_task_id (a SUCCEEDED text-to-3d/image-to-3d/retexture
                  task) or model_url; target_polycount 100..300000, default
                  30000; topology triangle|quad; decimation_mode 1-4 OVERRIDES
                  target_polycount; target_formats as above. resize_height,
                  resize_longest_side, auto_size and origin_at are deprecated in
                  favour of the Resize API. Takes about 2.5 minutes.

WHAT THE REMESH DOCS DO NOT TELL YOU, measured here on steam_vent:

  Remesh does its job on geometry and quietly UNDOES it on texture. 10,196
  triangles came back as 1,532 (0.55 MB of vertex data down to 0.09 MB) — and
  the same file went from 11.04 MB to 30.35 MB, because the task re-encodes the
  four 2048x2048 JPEG maps as PNG and UPSCALES two of them to 4096x4096:

      original   4 x JPEG 2048        10.49 MB of images,  0.55 MB of geometry
      remeshed   PNG 4096 emission    15.58 MB
                 PNG 2048 normal       7.43 MB
                 PNG 2048 base_color   6.43 MB
                 PNG 4096 metal/rough  0.82 MB
                                      30.26 MB of images,  0.09 MB of geometry

  So `remesh` on its own is a 2.75x size REGRESSION and there is no request
  parameter that prevents it — texture_resolution is a text-to-3d field and the
  remesh schema has no equivalent. The command below therefore does two things
  and is only worth running as both: it remeshes, and then it repacks the maps
  locally. See SHRINKING, below.

The key is read from $MESHY_API_KEY, falling back to tools/.meshy_key, which is
gitignored. It is never written to state, never printed, and never committed.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATE = Path(__file__).resolve().parent / "meshy-state.json"
KEYFILE = Path(__file__).resolve().parent / ".meshy_key"
API = "https://api.meshy.ai"


# --- the house style, translated for a 3D generator --------------------------
# The source is tools/forge.py's STYLE constant and its CONCEPT frame, which was
# written for the same weapon batch as 2D reference sheets. This is not a paste.
# What changed, and why:
#
#  * DROPPED the two-source lighting clause ("steel-blue moon rim from the
#    upper-left, warm amber lantern fill from the lower-right"). A 3D generator
#    bakes described light into the albedo map, and then Godot lights the mesh
#    again — you would get the lantern twice, from the wrong side, forever. We
#    ask for flat unlit albedo instead, and say the same thing again in a field:
#    `remove_lighting` on the refine call.
#  * DROPPED "crisp near-black ink outlines". An outline painted into a texture
#    is only correct from the angle it was painted at. This game's cel outline
#    comes from the shader, on every silhouette, at every angle.
#  * DROPPED "no photorealism, no 3D render". It is the one clause that cannot
#    survive the trip: to this API a 3D render is the deliverable. The cel look
#    is asked for here as a MATERIAL property — broad flat colour areas, low
#    micro-detail — which is what actually makes a mesh sit next to the painted
#    billboards without looking imported.
#  * DROPPED every framing clause in CONCEPT — "92% of the canvas width", "blade
#    pointing left and pommel right", "no background scene", the chroma key.
#    There is no canvas. The mesh equivalents replace them: one object, no
#    stand, no scabbard, no hand, closed silhouette, blade along one axis.
#  * KEPT, close to verbatim, the only part that is genuinely the house style:
#    the material and palette vocabulary. Blackened steel, brass fittings,
#    riveted plates, oxblood leather, honest wear, indigo/teal/brass. Changing
#    that here would put this prop out of step with thirty painted assets.
#  * SHORTENED, hard. The 2D Loom takes prompts of any length and forge.py's
#    frames run to 400 words. This API rejects anything over MAX_PROMPT with a
#    400 and no partial credit — the first run from this file died on exactly
#    that. So every clause here has to earn its place, and the redundant
#    negatives that are cheap in a 2D prompt ("no pedestal" AND "no base" AND
#    "no ground plane") are collapsed to one.
# TWO WORDS IN HERE COST US THE FURNACE KNIGHT AND THE COLOSSUS.
#
# "verdigris teal accents" was read by the refine pass as GLOWING teal rather
# than as oxidised copper — so the one colour in the palette that means "cold and
# old" became the one that means "powered", and both furnaces came back green.
#
# And the trailing "no glow" flatly contradicted the per-asset clause asking for
# a glowing orange furnace grate, which is the only thing in this art direction
# that is SUPPOSED to emit. A prompt that contains both instructions resolves
# whichever way it likes; ours resolved against the furnace twice.
#
# The negative it was trying to express is "do not bake a bloom into the albedo",
# which "flat albedo, no baked lighting" already says.
PALETTE = (
    "blackened steel, riveted brass "
    "fittings, oxblood leather, oxidised copper accents, honest wear at the "
    "edges. Chunky readable forms and broad flat colour areas, not photoreal, "
    "no micro-detail. Flat albedo, no baked lighting, no baked shadow."
)

# Two nouns, one vocabulary. Split out when the boarders arrived: calling a
# character a "prop" got Meshy to hand back a suit of armour on a display stand
# rather than a knight. The palette sentence is deliberately shared and
# deliberately not re-typed — it is the one clause that has to stay identical
# across thirty painted assets and everything generated beside them.
STYLE_3D = "Stylised game-ready steampunk airship prop: " + PALETTE
STYLE_FIGURE = "Stylised game-ready steampunk airship character: " + PALETTE
# Three nouns now. The boarding hulk is the enemy's siege engine and NOT a ship,
# and the first draft of its frame said "No airship" while this line two hundred
# characters later said "airship prop" — the third time in this file that one
# prompt has carried both halves of an argument. The word is removed rather than
# negated; see HULK.
STYLE_VEHICLE = "Stylised game-ready steampunk siege vehicle: " + PALETTE

# The frame every weapon in this manifest is generated in. CONCEPT's job in the
# 2D tool was to keep the reference sheet legible; this one's job is to keep the
# mesh clean — a stand or a scabbard is geometry you then have to delete, and a
# hand is geometry you cannot.
PROP = (
    "One weapon alone, upright, blade up. No stand, no base, no scabbard, no "
    "hand, no duplicate, no text, no gems. Blade, guard, grip and pommel "
    "clearly separated. " + STYLE_3D
)

# The texture pass gets its own prompt. The refine stage is only painting an
# existing mesh, so geometry words ("no stand", "symmetrical") are wasted tokens
# there — it takes colour and material direction instead.
SURFACE = (
    "Hand-painted stylised game texture: blackened gunmetal, warm polished brass, "
    "deep oxblood leather, dull oxidised-copper patina settled in the recesses, "
    "bare worn metal along the working edges. Any furnace, grate, vent, ember or "
    "lamp flame is hot orange; nothing else emits light. Broad flat colour areas, "
    "no baked lighting, no baked shadow, no text, no logos."
)

# "or lamp flame" was added for the deck props. The list is the ONE place this
# prompt says what is allowed to emit, and the lantern post is a lamp — without
# it the per-asset line asking for lit amber panes and this line saying "nothing
# else emits light" are the furnace knight's contradiction again, one asset later.
# Inert for the five boarders: none of them owns a lamp, and their prompts are
# already recorded verbatim in their own meshy.json sidecars.

# The one prop family that is not made of metal. Same failure as the gremlin:
# SURFACE names five metals and no timber, and a crate textured from it comes
# back as a riveted brass strongbox — which is a different prop. Rope is named
# here too, because crate_stack is lashed with it and "cord" painted in brass is
# the same mistake in miniature.
SURFACE_WOOD = (
    "Hand-painted stylised game texture: weathered dark timber planks with open "
    "grain, warm polished brass corner brackets and rivets, deep oxblood leather "
    "strapping, coarse pale hemp rope, dull oxidised-copper patina in the "
    "recesses. Nothing emits light. Broad flat colour areas, no baked lighting, "
    "no baked shadow, no text, no logos."
)

# The one boarder that is not made of metal. SURFACE names five metals and no
# skin, and a texture prompt that never says "skin" paints the gremlin as a
# small brass statue — which is a different enemy.
SURFACE_SKIN = (
    "Hand-painted stylised game texture: mottled green skin, worn oxblood "
    "leather, warm polished brass, faded crimson cloth, dull oxidised-copper "
    "patina in the recesses. Any furnace, grate, vent or ember is hot orange; "
    "nothing else emits light. Broad flat colour areas, no baked lighting, no "
    "baked shadow, no text, no logos."
)


# The one PLAYER character we generate, and the one human. SURFACE_SKIN paints a
# GOBLIN (mottled green); the captain dodged the "human face comes back brass"
# trap by keeping her own Meshy archive maps, but the Boilerwright is generated
# fresh, so his texture has to NAME human skin the way SURFACE_SKIN names green
# skin — or the refine pass paints his face as a bronze bust. Human tones, the
# rest of the house palette unchanged.
SURFACE_HUMAN = (
    "Hand-painted stylised game texture: weathered sun-browned human skin, a "
    "greying beard, worn oxblood and dark-brown leather, warm polished brass, "
    "blackened steel, dull oxidised-copper patina in the recesses, soot smudged "
    "into the leather. Any furnace, grate, vent or ember is hot orange; nothing "
    "else emits light. Broad flat colour areas, no baked lighting, no baked "
    "shadow, no text, no logos."
)


# The frame for a boarder. PROP's clauses are all about a single object on no
# stand; a character needs the opposite half of the same argument — one figure,
# both feet down, arms out of the torso's silhouette. That last clause is the
# one that matters at this camera: the deck is seen from 41 degrees and an arm
# folded across the chest disappears into the body at that angle.
FIGURE = (
    "One character alone, standing upright, facing forward, feet flat on the "
    "ground, arms clear of the body. No base, no plinth, no ground plane, no "
    "scenery, no duplicate, no text. " + STYLE_FIGURE
)

# The frame for the PLAYER'S OWN character — the Boilerwright. FIGURE is written
# for a boarder seen mid-fight; this one is written for a mesh that will be
# AUTO-RIGGED and RETARGETED, and the owner's standing rules (STATUS.md) are hard
# requirements rather than preferences here, because a posed or cloaked or
# armed generation is credits spent on a rig the animation pipeline cannot use.
# So the neutral rest pose is stated three ways (relaxed A-pose, arms down and
# away, both hands open and empty), and the three bake-in traps are refused
# outright: no cape or cloth (added back as a bone chain, SG-23), no weapon in
# the hands (a separate bone-mounted mesh, the cutlass pattern), no dangling
# ornament (identity rides on bulk and texture, CLASS-2 §7).
HERO_FIGURE = (
    "One character alone in a clean neutral A-pose, feet apart, both arms "
    "straight and held well out from the sides, hands open and empty. Nothing "
    "held or hanging: no weapon, tool, pouch, bag or strap. No cape, cloak, "
    "loose cloth or tattered edges. No base, ground or text. " + STYLE_FIGURE
)

# The frame for a piece of deck furniture. PROP is about a weapon in a hand that
# does not exist yet; this is about an object that already sits on planking in
# thirty painted assets, and its clauses are the three ways a generator ruins one:
#
#   * it invents a display base. Every prop here is placed by PROP_LAYOUT at a
#     measured y=0 and `static_model.gd` stands it on its own measured floor, so
#     a plinth is 40 units of nothing lifting the object off the deck.
#   * it invents a SCENE — a crate wants a warehouse, a lamp post wants a street.
#     Anything that arrives with the object is geometry inside the same GLB and
#     inside the AABB the height is measured from.
#   * "no text" is NOT said the way PROP says it. The powder keg's read at a
#     41-degree camera is a red flame triangle on a blue-black belly; banning
#     text outright bans the one marking that tells a keg from a barrel. So the
#     negative here is lettering and numbers, which is what we actually mean.
DECK = (
    "One object alone, whole and complete, standing on nothing. No base, plinth "
    "or ground plane, no wall or scenery, no duplicate, no lettering or "
    "numbers. " + STYLE_3D
)

# The boarding hulk gets its own frame for one reason: it must not come back as
# a ship. It is the enemy's boarding craft, rammed against our rail, and the
# thing it replaces is a battering ram with two ramps down — a handsome vessel
# would be wrong here even if it were beautiful.
#
# The way that is asked for matters, and the first draft got it wrong in the
# way this file has already been burned by twice. It said "No airship" and then
# inherited STYLE_3D, which says "airship prop" two hundred characters later.
# One prompt, both halves of the argument, resolved whichever way it likes.
#
# So the word is REMOVED rather than negated — STYLE_VEHICLE says siege vehicle
# and nothing here says ship at all — and the only negatives left are pieces of
# geometry that are unambiguously separable: a balloon, a sail, a mast, rigging.
# Those four are what "handsome airship" actually looks like.
#
# DECK's "standing on nothing" is kept and its "upright and level" is not. This
# thing is rammed in against a rail, and the one proportion that has to survive
# is that it is far wider than it is tall.
#
# "One VEHICLE alone" in v1, and that word did most of the damage on its own —
# see the v2 note at the asset. It is a siege machine now, which is a thing that
# has a front and sits still.
HULK = (
    "One siege machine alone, standing on nothing. No balloon, no sail, no mast, "
    "no rigging, no ground plane, no scenery, no duplicate, no lettering. "
    + STYLE_VEHICLE
)

# The gunner is the one boarder with nothing to stand on. Telling a flying
# machine its feet are flat on the ground is how you get feet.
FLYER = (
    "One flying machine alone, hovering level, facing forward, symmetrical. No "
    "legs, no feet, no base, no stand, no ground plane, no scenery, no "
    "duplicate, no text. " + STYLE_FIGURE
)


# --- what to make -----------------------------------------------------------
# key         directory under assets/models/ and the state key
# subject     the only part that changes between assets
# texture     subject line for the refine pass; SURFACE is appended
# batch       what `run <batch>` selects
# polycount   a weapon held by a 176-unit character; 30k (the API default) is
#             three times more triangles than the silhouette can show
# frame       the shared clauses appended to `subject`: PROP, FIGURE or FLYER
# surface     the shared clauses appended to `texture`: SURFACE or SURFACE_SKIN
# screen      how tall this thing stands on the deck, in GROUND UNITS, copied
#             from the renderer rather than guessed. It is the only input to
#             both budgets below, so it has to be the number the game uses:
#               PROP_HEIGHT / BOILER_HEIGHT / CAPTAIN_HEIGHT in view3d.gd,
#               120 + radius*3 for a boarder (the `_sync_all` enemy line),
#               weapons.json `length` in metres * 100 for a weapon.
#             A wrong number here does not break anything; it buys the wrong
#             amount of detail, which is the whole thing this file is about.
# tris        OVERRIDES the derived triangle budget. Empty for sixteen of the
#             seventeen; see `tri_budget` for why one asset needs it and why
#             the answer is not to move the floor again for everyone.
def A(key, subject, texture, batch, polycount=12000, frame=None, surface=None,
      screen=100.0, tris=0):
    return dict(key=key, subject=subject, texture=texture, batch=batch,
                polycount=polycount, frame=frame or PROP,
                surface=surface or SURFACE, screen=screen, tris=tris)


ASSETS = [
    # --- swords -------------------------------------------------------------
    # Two, because the point is choosing. The captain's right arm carries a
    # heavy brass gauntlet, so both grips are called out as sized for it — a
    # normal grip reads as too small the moment the melee pack puts her hand
    # on it.
    A("sword_cutlass",
      "A sky-pirate airship captain's cutlass: a broad, slightly curved "
      "single-edged blackened steel blade with a brass fuller and a bright worn "
      "edge; a heavy riveted brass knuckle-bow guard curving from crossguard to "
      "pommel; a long oxblood leather grip sized for a heavy gauntleted hand; a "
      "geared brass pommel cap.",
      "Blackened gunmetal blade, polished brass fuller and knuckle-bow, deep "
      "oxblood leather grip wrap, verdigris settled in the recesses of the "
      "guard, bare bright steel along the cutting edge.",
      "sword", screen=95.0),

    # v2. The first generation of this one came back wrong and is worth
    # recording, because the failures were all in the prompt rather than the
    # model: "an exposed brass gear train along its spine" produced a SECOND
    # crossguard halfway up the blade, and "a valve-shaped counterweight
    # pommel" produced something the size of a sledgehammer head. Both are the
    # same mistake — naming a mechanism the generator has no image of, which it
    # then resolves into the nearest big familiar shape. v2 names ordinary
    # sword parts and puts the machinery on as small detail instead.
    A("sword_gearblade",
      "A steampunk mechanical sword: one straight slim tapering single-edged "
      "blackened steel blade, with three narrow vents cut through the flat "
      "near the base and small brass cogs inset beside them; exactly one short "
      "riveted brass crossguard and no second guard higher up; a long oxblood "
      "leather grip for a gauntleted hand; a small round brass pommel.",
      "Blackened steel blade with brass gears and chain along the spine, dark "
      "iron vents, brass crossguard and valve pommel, worn oxblood leather "
      "grip binding, verdigris around the rivets.",
      "sword", screen=95.0),

    # --- axe ----------------------------------------------------------------
    # The melee pack animates an axe OR a sword. Kept in the manifest so the
    # other half of that choice is one command away, but not in the `sword`
    # batch, so it is not paid for by accident.
    A("axe_boarding",
      "A boarding axe for an airship crew. A broad blackened steel head with a "
      "brass-reinforced cheek plate and a heavy back-spike, mounted on a short "
      "riveted haft wrapped in oxblood leather, with a brass butt cap.",
      "Blackened steel head with a brass cheek plate, oxblood leather haft "
      "wrap, brass butt cap, bare worn steel along the cutting edge.",
      "axe", screen=95.0),

    # --- the five boarders ----------------------------------------------------
    # These are not new characters. Every one of them already exists as a
    # painted billboard in assets/art/enemies/, the player has been fighting
    # them for twelve waves, and the ONLY job of these prompts is to describe
    # the picture that is already on disk well enough that the mesh reads as the
    # same enemy. So each subject is written off the billboard, feature by
    # feature, and the distinguishing feature is named first: the player tells a
    # scrapper from a swarm at a locked 41-degree camera by the silhouette and
    # one colour, not by the rivets.
    #
    # The key is the enemy kind in lower case, because that is what
    # SkyGearView3D.model_path() looks for. Renaming one of these silently turns
    # its boarder back into a billboard.
    #
    # Polycount is up from the weapons' 12k: these are 165 to 330 ground units
    # tall against a sword's 95, and the boss is the one thing on the deck the
    # camera ever gets close to.
    # v2. The first one came back a spindly red spider-legged thing with two
    # amber eyes, and all three failures were in the prompt:
    #
    #   * "one large exposed cog set into the chest" became a SECOND glowing
    #     lens. A round thing on the chest, described one clause after a round
    #     glowing thing on the head, is read as a matching pair. Same mistake as
    #     sword_gearblade's second crossguard: the generator resolves an
    #     unfamiliar part into the nearest familiar shape, and the nearest
    #     familiar shape was the one in the previous sentence. The cog is gone —
    #     it was never how you tell a scrapper from anything else.
    #   * "boarding hooks" alone became small crab pincers. v1 of this line said
    #     "instead of hands" and it was cut to get under 800 characters, which
    #     is the single clause that was doing the work. One hook, per arm,
    #     instead of a hand.
    #   * proportion was described once, at the front, and lost. "Hunched" and
    #     "stubby" against the frame's "standing upright" is one word against
    #     two; it now leads and is repeated as mass rather than as posture.
    A("scrapper",
      "A hunched, top-heavy steampunk salvage automaton. A huge riveted "
      "spherical brass and steel torso; the head sunk low between the "
      "shoulders, a small dome with a single amber lens and no other light; two "
      "long thick arms, each ending in one big curved steel boarding hook "
      "instead of a hand; short thick legs and wide flat feet.",
      "Blackened steel plating with warm polished brass rivets, a hot amber "
      "glass lens, verdigris in the seams, bare worn steel on the hooks.",
      "boarders", 15000, FIGURE, screen=186.0),

    A("gunner",
      "A small steampunk airship drone: a riveted brass disc-shaped body with "
      "one round glowing pale blue lens in the centre of its face; four short "
      "arms, one on top and one to each side and one below, each ending in a "
      "two-blade brass propeller in a ring mount; two short chains hanging "
      "underneath with pointed iron weights.",
      "Polished brass shell with blackened steel banding, a cool pale blue "
      "glass lens, verdigris in the recesses, dark iron chains and weights.",
      # tris: four propellers made of thin flat blades. See tri_budget.
      "boarders", 15000, FLYER, screen=183.0, tris=7000),

    A("armored",
      "A huge armoured steampunk furnace knight: heavy riveted plate armour "
      "over a barrel chest with a glowing orange furnace grate in it; a domed "
      "helmet with a slotted visor and a spike on top; a brass chimney stack "
      "rising from the right shoulder; a pressure gauge on the left pauldron; a "
      "big double-bladed axe held across the body.",
      "Blackened steel plate with warm brass trim and rivets, a hot orange "
      "furnace grate, oxblood leather straps, verdigris on the chimney, bare "
      "worn steel on the axe heads.",
      "boarders", 18000, FIGURE, screen=216.0),

    A("swarm",
      "A small scrawny green goblin sky-pirate: huge pointed ears, a worn "
      "leather flight cap with brass goggles pushed up on it, a torn crimson "
      "hood and short cape, one riveted brass shoulder plate, a little brass "
      "pressure tank strapped to its back, bare clawed feet, and an oversized "
      "brass pipe wrench gripped in both hands.",
      "Mottled green skin, worn oxblood leather cap and straps, faded crimson "
      "cloth hood, warm polished brass goggles and wrench, verdigris on the "
      "brass.",
      "boarders", 15000, FIGURE, SURFACE_SKIN, screen=165.0),

    A("boss",
      "A colossal steampunk siege mech: a vast riveted brass and iron barrel "
      "torso with a glowing orange furnace grate at its centre; a tiny domed "
      "head with one amber lens; two enormous cannon barrels over the shoulders "
      "angled up and outward; huge oversized armoured fists on short arms; "
      "thick armoured legs with anchor-shaped feet.",
      "Blackened iron plate with heavy polished brass banding and rivets, a hot "
      "orange furnace grate, verdigris teal in the seams, bare worn steel "
      "around the cannon mouths.",
      "boarders", 20000, FIGURE, screen=330.0),

    # --- the Boilerwright, the second player class ----------------------------
    # The one PLAYER character generated here, and the whole of board SG-12: the
    # second class currently renders as the captain because `_sync_captain` loads
    # one CAPTAIN_SCENE constant for both. Route 2 (owner-approved, commit
    # 788aff8): generate his mesh, auto-rig it, retarget the axe-pack clips onto
    # it so both classes move on the SAME clock.
    #
    # He is CLASS-2-DESIGN's heavy engineer — "he built the Boiler, has kept it
    # lit for thirty years", fights by cracking steam mains open. §7 wants a
    # silhouette that reads distinct from the fast red-coated captain at the 41°
    # camera: BULK, stance and colour mass — heavy leathers, brass fittings ON
    # the body not dangling, work gauntlets. Bulk is width, not height: he stands
    # the captain's 176 units (they share a camera and a telegraph calibration,
    # SG-12 guard), so `screen` is hers and the budget comes out the same.
    #
    # The three standing-rule traps are refused in HERO_FIGURE, not here, so this
    # subject is free to be all identity. `tris` is left derived (3000 at 329 px,
    # the floor) — but note the remesh must run BEFORE the rig, or he becomes the
    # captain's SG-13 all over again (a 30k rigged mesh no remesh can safely
    # decimate). See `rig` in this file.
    A("boilerwright",
      "A heavy steampunk boiler engineer: a broad, thickset, barrel-chested man "
      "in heavy oxblood leather, riveted brass shoulder plates and forearm "
      "gauntlets, plain smooth iron-toed boots, cropped hair, a greying beard, "
      "a round gauge on his chest.",
      "Weathered tanned skin and a short greying beard, heavy oxblood and "
      "dark-brown leather work gear, blackened steel and warm brass shoulder and "
      "forearm plates, a cream gauge dial on the chest, soot smudged into the "
      "leather.",
      "boilerwright", 12000, HERO_FIGURE, SURFACE_HUMAN, screen=176.0),

    # --- the Boiler -----------------------------------------------------------
    # The objective. `boiler_hp` reaching zero ends the run, it sits at the
    # bottom centre of frame for the entire game at the largest apparent size of
    # anything on the deck, and until now it was the ONLY object in the port with
    # no art at all — `SkyGearView3D._build_boiler` assembles it out of four
    # cylinders, two toruses, a box and a quad. Everything around it is
    # hand-painted; it is smooth primitives, and at that size the difference is
    # unmissable.
    #
    # THE ONE CONSTRAINT THAT IS NOT NEGOTIABLE IS THE PROPORTION, and it is a
    # gameplay constraint rather than a taste one. The browser sets `boilerH` to
    # 132 with the note "a flat engine block, not a tower", and the port's own
    # comment records what happened when that was ignored: a 300-unit drum with a
    # funnel hid the captain for the first second of every run, because she
    # spawns 130 units in front of it. So "wider than it is tall" leads the
    # subject, is the first thing said, and is worth more here than any detail.
    #
    # The furnace mouth is called out as being in ONE FACE for the same reason
    # the deck props are: this thing is seen from directly astern at a locked
    # 41-degree camera and is never rotated, so a mouth on the far side is a
    # mouth nobody ever sees. Everything expensive goes on the face that shows.
    # v2. v1 came back a WINE CASK: a horizontal wooden barrel lying on rollers,
    # no furnace mouth, no fire, no chimneys, brown instead of brass. Three
    # mistakes, and all three are ones this file has already made once:
    #
    #   * "a broad riveted brass DRUM" plus "wider than it is tall" was read as a
    #     cylinder lying DOWN. Both clauses point that way and neither says which
    #     end is up. The reference is a squat potbelly stove standing on its flat
    #     end, and v1 never said "upright" once. Same failure as the scrapper's
    #     proportion: described in one word, against a frame, and lost.
    #   * the furnace mouth — the ONE feature that makes this a boiler rather
    #     than a barrel, and the only thing the browser's procedural version
    #     actually draws — was the third clause. It now leads the detail, right
    #     after the posture.
    #   * "a bolted iron BASE ring" in the first draft, against DECK's "No base".
    #     Caught on the dry run before it was sent. The lantern's "stepped square
    #     flared foot" and the keg's "short vented feet" both came back correct
    #     from the same frame, so the clash is with the WORD, not with the idea
    #     of something to stand on. There is no such clause now at all.
    A("boiler",
      "A squat steampunk furnace boiler: a fat upright riveted brass barrel "
      "standing on its flat end, wider than it is tall. A big arched furnace "
      "door low in its front with a slatted iron grate and fire blazing behind "
      "it; two iron hoops round the barrel; a round gauge and a valve wheel "
      "above the door; two short chimney pipes rising at the back.",
      "Warm polished brass barrel with dark riveted iron hoops, heavy soot "
      "blackening around the furnace door, hot orange fire burning behind the "
      "grate, oxidised copper patina on the chimney pipes, a cream gauge dial.",
      "props", 20000, DECK, screen=168.0),

    # --- the boarding hulk ----------------------------------------------------
    # The largest sprite in the game after the Colossus, sitting at the bow
    # directly above the three lanes the player is watching, which is why it is
    # the most visible remaining one and the best return per credit here.
    #
    # ONE MESH FOR THREE PAINTED STATES, and the reason is in the simulation
    # rather than in the art. `game.gd` sets `hulk.vulnerable = true` on the
    # frame the hulk grapples on and never sets it false, so SEALED is a state
    # nothing can currently reach; and the destroyed hulk is a different object,
    # not a darker one — the centre plating is blown out and hanging. So this
    # prompt describes the state the player actually fights, OPEN, and
    # `SkyGearView3D` keeps the painted art for the other two. See the comment
    # at the switch there.
    #
    # Three generations would be worse than one, not better: Meshy would return
    # three different vehicles from three prompts, and swapping between them
    # would pop the whole silhouette mid-fight. What changes between the painted
    # states is the iris in the middle, and a glow is something the renderer can
    # already do.
    #
    # Written for SILHOUETTE, deliberately. It is seen almost edge-on from a
    # locked 41-degree camera and is partly off the top of frame most of the
    # time, so the two funnels, the two dropped ramps and the low wide wedge are
    # the whole read; the rivets are not.
    # v2. v1 came back a SUBMARINE: a long cigar-shaped gondola lying on its
    # side, an oval hole in the TOP, two little fins where the ramps should be.
    # Exactly the handsome-vessel failure the frame was written against, which
    # arrived anyway, and the frame was part of the reason:
    #
    #   * "craft" and "vehicle" both mean a thing that travels, and a steampunk
    #     thing that travels and is longer than it is tall is a gondola. Both
    #     words are gone; it is a siege machine and a fortress gate now.
    #   * "far wider than it is tall" does not say WHICH horizontal axis, so it
    #     grew along the one pointing away from the camera. What is actually
    #     true of the painted hulk is that it is a broad flat FRONT WALL — you
    #     only ever see its face — so v2 says wall, and says twice as wide as
    #     tall against that wall rather than against the object.
    #   * "an iris hatch in its front" put a hatch in the top, because nothing
    #     had established where the front was. The wall establishes it, and the
    #     door is now in the middle of the wall rather than in "its front".
    A("boarding_hulk",
      "A wide armoured siege ram front, like a fortress gate: a broad flat front "
      "wall of dark iron plate and dark timber planking, twice as wide as it is "
      "tall, bound by vertical brass straps; a large round iron door in the "
      "middle of that wall, standing open with fire inside; a heavy timber ramp "
      "lowered flat on each side; a short chimney at each top corner.",
      "Dark blue-grey iron plate and near-black weathered timber planking, warm "
      "polished brass strap bands and rivets, oxidised copper pipework, bare "
      "worn steel along the ramp edges, a hot orange furnace burning inside the "
      "open round door.",
      "props", 20000, HULK, screen=420.0),

    # --- the deck props -------------------------------------------------------
    # Same argument as the boarders and it is worth restating, because it is the
    # only thing that decides whether one of these ships: every one of these
    # already exists as a painted billboard in assets/art/props/ and has been on
    # the deck for the whole port. The job of the prompt is NOT to design a
    # crate. It is to describe the crate that is already on disk closely enough
    # that a player cannot tell which of the two they are looking at, because a
    # deck with eight generated props and twelve painted ones is only coherent if
    # they are the same objects.
    #
    # So each subject is written off the PNG, feature by feature, in the order
    # you would notice them at a locked 41-degree camera. Nothing is "improved".
    #
    # The keys are the ART filenames rather than the prop_type strings, because
    # the PNG is the thing being matched and the review is "hold them side by
    # side". `SkyGearView3D.PROP_MODEL` maps prop_type to these, and that table
    # is the per-prop mesh/billboard switch.
    #
    # WHY THERE IS NO SEPARATE "barrel": barrel.png IS the powder keg. It has the
    # fuse chimney, the pressure gauge and the red flame triangle painted on it,
    # and `prop.gd` loads it for prop_type "keg". Generating a plain barrel as
    # well would have been 30 credits for a prop nothing on the deck references.
    #
    # Polycounts are well under the weapons' 12k: a keg is 100 ground units tall
    # against the captain's 176, and there are four of them on the deck at once.
    A("crate_stack",
      "Three wooden shipping crates stacked one on another into a tall tower, "
      "each a plank box with brass corner brackets and rivets; a thick rope "
      "lashing knotted over the top and running down two faces; one square "
      "copper patch plate on the bottom crate.",
      "Weathered dark timber planks with open grain, warm polished brass corner "
      "brackets and rivets, coarse pale hemp rope lashing, one green oxidised "
      "copper patch plate.",
      "props", 8000, DECK, SURFACE_WOOD, screen=148.0),

    A("crate_small",
      "One small wooden shipping crate, a plank cube with dark blue-steel corner "
      "brackets and rivets on every corner, and one oxblood leather strap "
      "running over the top and down the front face with a brass buckle.",
      "Warm brown timber planks with open grain, dark blue-steel corner brackets "
      "with brass rivets, a deep oxblood leather strap and a polished brass "
      "buckle.",
      "props", 6000, DECK, SURFACE_WOOD, screen=84.0),

    A("powder_keg",
      "A steampunk explosive powder keg: a squat egg-shaped riveted iron barrel; "
      "two wide brass hoops around its belly; a brass valve stack and short fuse "
      "chimney on top; a round brass pressure gauge on one shoulder; a brass "
      "carrying handle on each side; a red painted flame hazard triangle on the "
      "front; short vented feet.",
      "Dark blue-black riveted iron shell, two broad polished brass hoops, brass "
      "valve stack and gauge bezel, a bright red painted flame hazard triangle, "
      "oxidised copper patina in the seams.",
      "props", 8000, DECK, screen=100.0),

    A("lantern_post",
      "A cast-iron airship deck lamp post: a stepped square flared foot; a tall "
      "slim fluted column banded with brass; a small round gauge and a brass "
      "valve wheel partway up it; a six-sided lantern head with a brass frame "
      "and warm amber glass panes lit from within; a small finial spike on the "
      "cap.",
      "Blackened cast iron column with warm polished brass bands and fittings, "
      "glowing warm amber glass panes in the lantern head, oxidised copper "
      "patina in the recesses.",
      "props", 10000, DECK, screen=200.0),

    A("brazier",
      "A wide shallow iron fire bowl on three splayed iron legs, the bowl bound "
      "by two riveted iron bands, heaped with burning coals that glow hot "
      "orange.",
      "Rust-brown weathered iron bowl with dark riveted bands, charred black "
      "timber, and coals burning hot orange in the centre.",
      "props", 6000, DECK, screen=116.0),

    A("steam_vent",
      "A squat brass airship deck vent: a round riveted brass drum standing on a "
      "wide bolted flange plate; a dark ribbed cap on top; two copper pipes "
      "arcing up out of the base and back into the drum's sides; a round gauge "
      "on the front; a valve wheel on each side; a row of tall louvre slots "
      "glowing hot orange at the bottom.",
      "Warm polished brass drum with blackened steel cap and banding, bright "
      "copper pipes, oxidised copper patina in the recesses, hot orange light in "
      "the louvre slots at the base.",
      "props", 10000, DECK, screen=52.0),

    A("cannon_deck",
      "A short steampunk deck cannon on a pivot mount: a heavy blackened steel "
      "barrel with a wide brass muzzle ring and two brass reinforcing bands, "
      "cradled in a steel yoke; a large brass elevation gear wheel on one side; "
      "a small pressure gauge; an octagonal riveted base carrying a rope winch "
      "drum.",
      "Blackened gunmetal barrel with warm polished brass muzzle ring, bands and "
      "gear wheel, oxidised copper patina in the recesses, bare worn steel at "
      "the muzzle, dark red-brown iron base.",
      "props", 12000, DECK, screen=130.0),

    A("salvage_pile",
      "A low loose heap of salvaged machinery lying flat: a dozen brass cogs of "
      "different sizes leaning against each other; one length of copper pipe "
      "across them; a round brass gauge face on top; a coiled blue-steel spring "
      "at one side.",
      "Warm polished brass cogs of varying tarnish, bright copper pipe, "
      "blue-steel spring, oxidised copper patina in the recesses, a cream gauge "
      "dial.",
      "props", 8000, DECK, screen=62.0),

    # In the manifest, deliberately NOT generated, and the reason is the same one
    # that keeps the furnace knight painted: it would not be an improvement.
    # rope_coil is 30 ground units tall — the flattest, smallest thing on the
    # deck, PROP_HEIGHT's minimum by a factor of two. A camera-facing billboard
    # of a coil of rope and a mesh of a coil of rope are the same forty pixels.
    # It is here so the next person does not have to write the prompt; running
    # `run props` after the other eight are on disk generates exactly this one.
    A("rope_coil",
      "One thick coil of ship's rope lying flat, wound in three or four loose "
      "concentric turns, the free end tucked under the outermost turn.",
      "Coarse dark tarred hemp rope with a visible three-strand twist, pale "
      "worn fibres on the high points.",
      "props", 6000, DECK, SURFACE_WOOD, screen=30.0),
]

BATCHES = ["sword", "axe", "boarders", "props", "boilerwright"]

# Generation settings. meshy-6 costs 20 credits at preview against meshy-5's 5,
# and is the difference between a sword and a sword-shaped lump at this
# polycount. 2k maps: the captain's own albedo is downscaled to 1024 by
# ingest_model.py because she is 176 pixels tall, and the sword is smaller.
AI_MODEL = "meshy-6"
TEXTURE_RESOLUTION = "2k"
TARGET_FORMATS = ["glb", "fbx"]

# The docs say 600. The API actually enforces 800 and returns
#   400 {"message":"Invalid values: Prompt must be a maximum of 800 characters"}
# with nothing generated and nothing charged. Checked here instead, because
# finding out from a 400 halfway through a batch is a worse way to find out.
MAX_PROMPT = 800


# --- how big any of this actually gets on screen ------------------------------
# THE MEASUREMENT THAT STARTED THIS. Seventeen finished assets came to 182 MB of
# .glb, and the Windows build went from 170 MB to 308 MB when ten of them landed.
# Taking the files apart says where it went, and it is not where the file name
# suggests:
#
#     218,332 triangles across all seventeen  ->    11.5 MB of vertex data
#     68 embedded 2048x2048 JPEG maps         ->   170.6 MB of images
#
# 94% of every one of these files is texture. A rope coil and a Colossus cost
# about the same because they are both wearing four 2048x2048 maps, and 2048 is
# the smallest thing Meshy's refine stage will paint (`texture_resolution: 2k`).
# So target_polycount alone could not have fixed this: remesh every asset to a
# tenth of its triangles and you save 10 MB of 182.
#
# Both budgets below therefore come off ONE number — how many pixels of the
# screen this object actually covers — because that is the thing that makes a
# 30-unit rope coil and a 330-unit Colossus different, and nothing else here
# does.
#
# PX_PER_UNIT is that conversion, solved from the renderer's own camera rather
# than eyeballed, so it moves if the camera does:
#
#     view3d.gd sets camera.fov = 2*atan(REF_HEIGHT/2 / FOCAL), so one ground
#     unit at distance d is FOCAL/REF_HEIGHT * viewport_height / d pixels.
#     FOCAL 1320, REF_HEIGHT 860, viewport_height 1080 (project.godot), and the
#     camera sits CAM_HEIGHT 760 up and CAM_NEAR 460 back from its focus point,
#     so d = hypot(760, 460) = 888.
#
#     1320/860 * 1080 / 888 = 1.87 pixels per ground unit at the focus point.
#
# Everything further up the deck is smaller than that, so this is the generous
# end of the range and every budget derived from it is an over-estimate on
# purpose.
PX_PER_UNIT = 1.87


def screen_px(a: dict) -> float:
    return a["screen"] * PX_PER_UNIT


# --- the triangle budget ------------------------------------------------------
# Triangles pay for silhouette, and silhouette is an AREA on the screen, so the
# budget goes with the square of the on-screen height. The constant is set from
# the one asset nobody would argue is over-budget: the Colossus at 330 ground
# units is 616 pixels tall and 8,000 triangles is a generous figure at that
# size — tools/model_lab.gd draws its HEAVY warning at 20k, and 8k is well
# inside it. Everything else scales down from there.
#
# THE FLOOR IS NOT AREA, and it is the number this file got wrong first time.
# Below about 380 pixels the area rule asks for fewer than 3,000 triangles, and
# what breaks at that point is not fidelity but FEATURES: the cannon's elevation
# gear, the steam vent's flange rings, the lantern's six-sided head, the keg's
# brass hoops. Those are what tell one prop from another at a glance, they are
# separate pieces of geometry rather than detail on a surface, and area has
# nothing to say about how many of them an object has.
#
# THE FLOOR WAS 1,500 AND THE DECK CANNON PROVED IT TOO LOW. Three of the five
# assets that landed on that floor came back measurably worse at the real camera
# distance — checked with tests/_shot_models.gd, not off a thumbnail:
#
#   cannon_deck   1,547 tris: the brass elevation gear lost its teeth and became
#                 a smooth disc, the muzzle crown went to a lump, the base studs
#                 rounded off. THE WORST OF THE BATCH and it is a prop the
#                 player looks at all game.
#   steam_vent    1,532 tris: the two side flange rings stopped being round.
#   salvage_pile  1,541 tris: the thin plates and rods in the heap merged.
#
# The same cannon at 3,085 has the gear back as a ring with a hub, a crisp
# muzzle crown and proper studs. So 3,000, and the reason it is affordable is
# the other half of this file: once the maps are 512 instead of 2048, geometry
# is about 0.1 MB of a 0.3 MB prop, and doubling it costs less than a tenth of
# what one 2048 map cost. Triangles stopped being the expensive thing.
#
# Which means the area curve only actually bites above ~380 pixels — the boss,
# the hulk, the furnace knight. Everything else is on the floor. That is the
# honest shape of this problem at a locked 41-degree camera and it is worth
# saying out loud rather than dressing up in a formula that looks per-asset.
TRI_PER_PX2 = 0.021
TRI_FLOOR = 3000
TRI_CEIL = 8000


# THE ONE OVERRIDE, and it is here rather than as a third rule because it is a
# property of one model's geometry and not of any measurable thing about the
# asset. The gunner is 342 pixels — mid-table, nothing special — and it came back
# from 3,000 with its four propellers turned into thick faceted paddles, one with
# a hole punched through a blade. Everything else on it survived: the body rings,
# the ring mount on top, the blue lens, the hanging chains.
#
# The reason is that a propeller blade is a THIN FLAT PLATE, which is the one
# shape a decimator cannot cheapen. Its two faces are a few millimetres apart, so
# collapsing an edge across the plate does not lose a little accuracy, it welds
# the front of the blade to the back. Area does not see that and the floor does
# not either; both would have to move for all seventeen assets to catch it, and
# sixteen of them do not need it. This is the cheapest honest answer: name the
# asset, say what is thin about it, pay for the edges that keep it thin.
def tri_budget(a: dict) -> int:
    if a.get("tris"):
        return int(a["tris"])
    px = screen_px(a)
    n = int(round(TRI_PER_PX2 * px * px / 500.0)) * 500
    return max(TRI_FLOOR, min(TRI_CEIL, n))


# --- SHRINKING: the texture budget --------------------------------------------
# The other 94%, and the only lever we have for it is local: Meshy will not
# paint below 2k and remesh makes the maps bigger still (see the header). So the
# maps are re-encoded here, after download, to a side length set by the same
# screen height.
#
# The precedent is already in this repo and it is the captain: ingest_model.py
# downscales her albedo to 1024 because she is 176 ground units tall. This
# file's own header has cited that since the first weapon batch — "the captain's
# own albedo is downscaled to 1024 ... and the sword is smaller" — and then
# shipped 2k anyway, seventeen times. TEX_FULL is that decision finally applied.
#
# So 1024 is the number a 176-unit figure was already agreed to be worth, and
# the split below is deliberately MORE conservative than she is: anything from
# 260 pixels up (about 140 ground units) keeps a full 1024 base colour, and only
# the genuinely small deck furniture drops to 512.
#
# The other three maps are not base colour and are not judged the same way:
#
#   * normal at half. At 200-600 pixels a normal map is contributing broad
#     shading across a rivet, not the rivet. Halving it is the cheapest 3 MB in
#     the file and it is not visible at this camera.
#   * metallic/roughness and emission at a quarter. Both are lighting
#     modulators over broad regions — there is no such thing as a one-pixel
#     change in roughness that anyone can see here. The emission map is
#     already 0.07-0.13 MB in every asset because it is almost entirely black
#     with one hot grate or lamp in it, and a hot grate is a blob.
#
# JPEG, not PNG, and at quality 88/92: the ORIGINALS Meshy ships are JPEG, so
# this is not introducing a lossy stage that was not already there — it is
# refusing the PNG the remesh task substitutes. Normals get the higher quality
# because a chroma-subsampled normal map is the one map where JPEG ringing
# turns into visible shading noise.
TEX_FULL = 1024
TEX_SMALL = 512
TEX_FULL_ABOVE_PX = 260.0
# role -> (fraction of the base side, JPEG quality). Roles are read out of the
# glTF material rather than off the file name, because the remesh task hands
# back its images in a DIFFERENT ORDER from the refine task (emission first) and
# an index-order assumption would downscale the base colour to 256.
TEX_ROLES = {
    "base_color": (1.0, 88),
    "normal": (0.5, 92),
    "metallic_roughness": (0.25, 90),
    "emission": (0.25, 88),
}
TEX_MIN_SIDE = 128


def tex_budget(a: dict) -> dict:
    base = TEX_FULL if screen_px(a) >= TEX_FULL_ABOVE_PX else TEX_SMALL
    return {role: max(TEX_MIN_SIDE, int(base * frac))
            for role, (frac, _q) in TEX_ROLES.items()}


# --- plumbing ---------------------------------------------------------------
class MeshyError(RuntimeError):
    def __init__(self, code: int, detail: str):
        super().__init__("HTTP %d: %s" % (code, detail))
        self.code = code
        self.detail = detail


def api_key() -> str:
    key = os.environ.get("MESHY_API_KEY", "").strip()
    if key:
        return key
    if KEYFILE.exists():
        key = KEYFILE.read_text(encoding="utf-8").strip()
        if key:
            return key
    raise SystemExit(
        "no Meshy API key. Set MESHY_API_KEY, or put the key in %s "
        "(that path is gitignored)." % KEYFILE)


def api(method: str, path: str, body: dict | None = None, timeout: int = 60) -> dict:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method)
    req.add_header("Authorization", "Bearer " + api_key())
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        raise MeshyError(e.code, e.read().decode("utf-8", "replace")[:500]) from None


def load_state() -> dict:
    if STATE.exists():
        return json.loads(STATE.read_text(encoding="utf-8"))
    return {}


def save_state(st: dict) -> None:
    STATE.write_text(json.dumps(st, indent=1), encoding="utf-8")


def outdir(key: str) -> Path:
    return ROOT / "assets" / "models" / key


def delivered(key: str) -> bool:
    return (outdir(key) / (key + ".glb")).exists()


def select(batch: str, only: str) -> list[dict]:
    rows = [x for x in ASSETS if batch in ("all", x["batch"])]
    if only:
        want = [s.strip() for s in only.split(",") if s.strip()]
        rows = [x for x in rows if x["key"] in want]
    return rows


def bounded(text: str, key: str, field: str) -> str:
    if len(text) > MAX_PROMPT:
        raise SystemExit("%s: %s is %d characters, limit is %d. Shorten the "
                         "subject line in ASSETS, not the shared frame."
                         % (key, field, len(text), MAX_PROMPT))
    return text


def prompt_for(a: dict) -> str:
    return bounded(a["subject"] + " " + a["frame"], a["key"], "prompt")


def texture_prompt_for(a: dict) -> str:
    return bounded(a["texture"] + " " + a["surface"], a["key"], "texture_prompt")


# --- tasks ------------------------------------------------------------------
def submit_preview(a: dict) -> str:
    return api("POST", "/openapi/v2/text-to-3d", {
        "mode": "preview",
        "prompt": prompt_for(a),
        "ai_model": AI_MODEL,
        "topology": "triangle",
        "target_polycount": a["polycount"],
        "should_remesh": True,
        # No symmetry_mode: it exists in older Meshy versions but is not in the
        # current v2 text-to-3d schema, and an unknown field is a 400.
        "target_formats": TARGET_FORMATS,
    })["result"]


def submit_refine(a: dict, preview_id: str) -> str:
    return api("POST", "/openapi/v2/text-to-3d", {
        "mode": "refine",
        "preview_task_id": preview_id,
        "ai_model": AI_MODEL,
        "enable_pbr": True,               # we want metallic/normal/roughness, not one albedo
        "texture_resolution": TEXTURE_RESOLUTION,
        "texture_prompt": texture_prompt_for(a),
        "remove_lighting": True,          # the engine lights this, not the map
        "target_formats": TARGET_FORMATS,
    })["result"]


def poll(task_id: str, label: str, timeout: int = 1800, gap: int = 10,
         endpoint: str = "/openapi/v2/text-to-3d/") -> dict:
    """Wait for one task. Reports progress; returns the terminal task object.

    `endpoint` because remesh is a v1 task type with its own path and polling a
    remesh id against /v2/text-to-3d/ returns a 404, not a status.
    """
    t0 = time.time()
    last = -1
    while time.time() - t0 < timeout:
        try:
            task = api("GET", endpoint + task_id)
        except MeshyError as e:
            if e.code == 429:
                time.sleep(15)
                continue
            raise
        status = task.get("status", "?")
        progress = int(task.get("progress") or 0)
        if progress != last or status in ("PENDING",):
            queued = task.get("preceding_tasks")
            note = "  (%d ahead)" % queued if queued else ""
            print("    %-8s %-12s %3d%%%s" % (label, status, progress, note))
            last = progress
        if status in ("SUCCEEDED", "FAILED", "CANCELED"):
            return task
        time.sleep(gap)
    return {"status": "TIMEOUT", "id": task_id}


def download(url: str, dest: Path) -> int:
    dest.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url, timeout=300) as r:
        data = r.read()
    dest.write_bytes(data)
    return len(data)


def collect(a: dict, task: dict) -> list[str]:
    """Pull the mesh, the maps and the thumbnail down beside each other."""
    out = outdir(a["key"])
    got = []
    for fmt, url in (task.get("model_urls") or {}).items():
        if not url or fmt not in ("glb", "fbx", "obj", "mtl", "usdz"):
            continue
        dest = out / ("%s.%s" % (a["key"], fmt))
        print("    %-28s %6.2f MB" % (dest.name, download(url, dest) / 1e6))
        got.append(dest.name)
    for i, maps in enumerate(task.get("texture_urls") or []):
        for role, url in (maps or {}).items():
            if not url or not isinstance(url, str):
                continue
            suffix = "" if i == 0 else "_%d" % i
            dest = out / ("%s_%s%s.png" % (a["key"], role, suffix))
            print("    %-28s %6.2f MB" % (dest.name, download(url, dest) / 1e6))
            got.append(dest.name)
    if task.get("thumbnail_url"):
        dest = out / ("%s_thumb.png" % a["key"])
        download(task["thumbnail_url"], dest)
        got.append(dest.name)
    return got


def write_sidecar(a: dict, st: dict) -> None:
    """Everything needed to explain or repeat this asset, minus the key."""
    rec = st[a["key"]]
    (outdir(a["key"]) / "meshy.json").write_text(json.dumps({
        "key": a["key"],
        "ai_model": AI_MODEL,
        "prompt": prompt_for(a),
        "texture_prompt": texture_prompt_for(a),
        "target_polycount": a["polycount"],
        "texture_resolution": TEXTURE_RESOLUTION,
        "preview_task": rec.get("preview"),
        "refine_task": rec.get("refine"),
        "credits": rec.get("credits"),
        "files": rec.get("files", []),
        # What it was cut down to, and the one number both budgets come off.
        # Without this the sidecar describes a 20,000-triangle 2k asset that is
        # not the file sitting next to it.
        "screen_units": a["screen"],
        "remesh_task": rec.get("remesh"),
        "remesh_credits": rec.get("remesh_credits"),
        "remeshed": rec.get("remeshed"),
    }, indent=2), encoding="utf-8")


# --- commands ---------------------------------------------------------------
def cmd_balance(args) -> int:
    print("%d credits" % api("GET", "/openapi/v1/balance")["balance"])
    return 0


def cmd_list(args) -> int:
    st = load_state()
    for b in BATCHES:
        rows = [x for x in ASSETS if x["batch"] == b]
        print("%-8s %d assets, %d on disk" % (b, len(rows),
                                              sum(1 for x in rows if delivered(x["key"]))))
        for x in rows:
            rec = st.get(x["key"], {})
            mark = "OK " if delivered(x["key"]) else ("job" if rec.get("preview") else "   ")
            glb = outdir(x["key"]) / (x["key"] + ".glb")
            cut = rec.get("remeshed")
            print("   %s %-16s %6.2f MB %-22s preview=%-38s refine=%-38s %s credits"
                  % (mark, x["key"], glb.stat().st_size / 1e6 if glb.exists() else 0.0,
                     ("%d tris, %d px" % (cut["tris"], round(screen_px(x)))) if cut
                     else "FULL SIZE, not remeshed",
                     rec.get("preview") or "-", rec.get("refine") or "-",
                     (rec.get("credits") or 0) + (rec.get("remesh_credits") or 0) or "-"))
    return 0


def cmd_show(args) -> int:
    st = load_state()
    rec = st.get(args.key)
    if not rec:
        raise SystemExit("nothing generated for %r yet" % args.key)
    tid = rec.get("refine") or rec.get("preview")
    print(json.dumps(api("GET", "/openapi/v2/text-to-3d/" + tid), indent=2))
    return 0


def run_one(a: dict, st: dict, args) -> bool:
    key = a["key"]
    rec = st.setdefault(key, {})
    print("== %s" % key)

    # --- preview: geometry ---------------------------------------------------
    if not rec.get("preview"):
        rec["preview"] = submit_preview(a)
        save_state(st)          # written BEFORE the wait, so a crash mid-poll
        print("    preview  -> %s" % rec["preview"])   # does not re-submit it
    else:
        print("    preview  resuming %s" % rec["preview"])
    task = poll(rec["preview"], "preview", args.timeout)
    if task.get("status") != "SUCCEEDED":
        print("    FAILED at preview: %s %s"
              % (task.get("status"), (task.get("task_error") or {}).get("message", "")))
        return False
    credits = int(task.get("consumed_credits") or 0)

    # --- refine: texture -----------------------------------------------------
    if not rec.get("refine"):
        rec["refine"] = submit_refine(a, rec["preview"])
        save_state(st)
        print("    refine   -> %s" % rec["refine"])
    else:
        print("    refine   resuming %s" % rec["refine"])
    task = poll(rec["refine"], "refine", args.timeout)
    if task.get("status") != "SUCCEEDED":
        print("    FAILED at refine: %s %s"
              % (task.get("status"), (task.get("task_error") or {}).get("message", "")))
        return False
    credits += int(task.get("consumed_credits") or 0)

    rec["credits"] = credits
    rec["files"] = collect(a, task)
    save_state(st)
    write_sidecar(a, st)
    print("    %d credits, %d files in assets/models/%s/" % (credits, len(rec["files"]), key))

    # --- remesh: the size the screen actually asks for -----------------------
    # Third stage, in `run` rather than left to be remembered, because it was
    # forgotten seventeen times: every asset before this shipped at 20,000
    # triangles and four 2048x2048 maps for an object 60 to 200 pixels tall, and
    # ten of them took the Windows build from 170 MB to 308 MB. Five credits on
    # top of thirty, and the alternative is finding out at export time.
    if not args.no_remesh:
        if not remesh_one(a, st, args):
            print("    remesh failed - the full-size mesh is on disk and usable;"
                  " `remesh all --only %s` retries without regenerating" % key)
        write_sidecar(a, st)
    return True


def cmd_run(args) -> int:
    st = load_state()
    rows = [x for x in select(args.batch, args.only)
            if args.force or not delivered(x["key"])]
    if not rows:
        print("nothing to generate in '%s' (use --force to redo)" % args.batch)
        return 0

    # --force means "this generation came back wrong, do it again". Without
    # clearing the ids it would do the opposite: run_one resumes any task
    # already in state, so --force would re-download the very result you are
    # trying to replace and charge nothing while appearing to work.
    if args.force and not args.dry:
        for a in rows:
            st.pop(a["key"], None)
        save_state(st)

    if args.dry:
        for a in rows:
            p, t = prompt_for(a), texture_prompt_for(a)
            print("\n=== %s  (%s, %d tris, %s PBR) ===" %
                  (a["key"], AI_MODEL, a["polycount"], TEXTURE_RESOLUTION))
            print("-- prompt (%d/%d) --\n%s" % (len(p), MAX_PROMPT, p))
            print("-- texture_prompt (%d/%d) --\n%s" % (len(t), MAX_PROMPT, t))
            print("-- then remeshed to %d tris for %.0f px on screen --"
                  % (tri_budget(a), screen_px(a)))
        # 20 preview + 10 refine + 5 remesh.
        print("\n%d assets, roughly %d credits" % (len(rows), 35 * len(rows)))
        return 0

    try:
        print("balance %d credits" % api("GET", "/openapi/v1/balance")["balance"])
    except MeshyError as e:
        raise SystemExit("cannot reach the Meshy API: %s" % e)

    failed = []
    for a in rows:
        try:
            if not run_one(a, st, args):
                failed.append(a["key"])
        except MeshyError as e:
            # 402 and 401 are not worth retrying against the next asset.
            print("    ERROR %s" % e)
            failed.append(a["key"])
            if e.code in (401, 402):
                break
    print("\nbalance %d credits" % api("GET", "/openapi/v1/balance")["balance"])
    if failed:
        print("failed: %s" % ", ".join(failed))
        return 1
    return 0


def cmd_fetch(args) -> int:
    """Download from tasks already submitted. Never spends anything."""
    st = load_state()
    rc = 0
    for a in select(args.batch, args.only):
        rec = st.get(a["key"], {})
        tid = rec.get("refine") or rec.get("preview")
        if not tid:
            continue
        print("== %s" % a["key"])
        task = poll(tid, "fetch", args.timeout)
        if task.get("status") != "SUCCEEDED":
            print("    not ready: %s" % task.get("status"))
            rc = 1
            continue
        rec["credits"] = rec.get("credits") or int(task.get("consumed_credits") or 0)
        rec["files"] = collect(a, task)
        save_state(st)
        write_sidecar(a, st)
    return rc


# --- remeshing ----------------------------------------------------------------
# NEVER DELETE AN ORIGINAL. A remesh that comes back worse has to be walked away
# from, and there are three independent ways back, deliberately, because the one
# that is easiest to reach is the one with an expiry date on it:
#
#   1. the previous .glb is copied here before it is overwritten. Leading dot so
#      Godot skips the directory (it ignores anything starting with '.'), and
#      gitignored so 182 MB of superseded meshes never reaches a commit.
#   2. git. These files are committed, so `git checkout -- assets/models` is the
#      whole undo as long as the remesh is still in the working tree.
#   3. the Meshy task ids in meshy-state.json. `fetch all` re-downloads every
#      original from the refine tasks that were already paid for, for nothing —
#      but the signed URLs expire (the task carries `expires_at`, 30 days out),
#      so this is the backstop and not the plan.
ORIGINALS = ROOT / ".model_originals"


def keep_original(key: str) -> Path | None:
    """Copy the current .glb aside before anything overwrites it."""
    src = outdir(key) / (key + ".glb")
    if not src.exists():
        return None
    dest = ORIGINALS / key / (key + ".glb")
    if dest.exists():
        # Already kept. Do NOT refresh it: running remesh twice would otherwise
        # overwrite the true original with the first remesh and lose the thing
        # this directory exists for.
        return dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(src.read_bytes())
    return dest


# --- glTF surgery -------------------------------------------------------------
# A .glb is a 12-byte header and then length-prefixed chunks: one JSON chunk
# describing the scene and one BIN chunk holding every buffer view end to end —
# vertex data and embedded images in the same blob, told apart only by which
# bufferView index the JSON points at them with.
GLB_MAGIC = 0x46546C67
GLB_JSON = 0x4E4F534A          # 'JSON'
GLB_BIN = 0x004E4942           # 'BIN\0'


def glb_read(path: Path) -> tuple[dict, bytes]:
    raw = path.read_bytes()
    import struct
    magic, _ver, _len = struct.unpack_from("<III", raw, 0)
    if magic != GLB_MAGIC:
        raise SystemExit("%s is not a binary glTF" % path)
    js: dict = {}
    blob = b""
    off = 12
    while off < len(raw):
        clen, ctype = struct.unpack_from("<II", raw, off)
        chunk = raw[off + 8:off + 8 + clen]
        if ctype == GLB_JSON:
            js = json.loads(chunk.decode("utf-8").rstrip("\x00 "))
        elif ctype == GLB_BIN:
            blob = chunk
        off += 8 + clen
    return js, blob


def glb_write(path: Path, js: dict, blob: bytes) -> int:
    import struct
    js_bytes = json.dumps(js, separators=(",", ":")).encode("utf-8")
    js_bytes += b" " * ((4 - len(js_bytes) % 4) % 4)      # chunks are 4-aligned,
    blob = blob + b"\x00" * ((4 - len(blob) % 4) % 4)     # JSON with spaces, BIN
    total = 12 + 8 + len(js_bytes) + (8 + len(blob) if blob else 0)
    out = bytearray()
    out += struct.pack("<III", GLB_MAGIC, 2, total)
    out += struct.pack("<II", len(js_bytes), GLB_JSON) + js_bytes
    if blob:
        out += struct.pack("<II", len(blob), GLB_BIN) + blob
    path.write_bytes(bytes(out))
    return len(out)


def image_roles(js: dict) -> dict:
    """image index -> which PBR channel it is, read off the materials.

    By material, never by order. The refine task hands images back as
    base_color, metallic, normal, emission; the remesh task hands the SAME four
    back as emission, normal, base_color, metallic. Downscaling by index would
    put the base colour at 256 on every remeshed asset and nothing would say so.
    """
    roles: dict = {}

    def mark(info, role):
        if not isinstance(info, dict):
            return
        tex = (js.get("textures") or [])[info["index"]]
        src = tex.get("source")
        if src is not None:
            roles.setdefault(src, role)

    for m in js.get("materials") or []:
        pbr = m.get("pbrMetallicRoughness") or {}
        mark(pbr.get("baseColorTexture"), "base_color")
        mark(pbr.get("metallicRoughnessTexture"), "metallic_roughness")
        mark(m.get("normalTexture"), "normal")
        mark(m.get("emissiveTexture"), "emission")
        # Ambient occlusion rides in the same texture as metallic/roughness in
        # every Meshy asset so far, but if it ever arrives on its own it is a
        # broad low-frequency map and belongs in the same bucket.
        mark(m.get("occlusionTexture"), "metallic_roughness")
    return roles


def shrink_glb(path: Path, sides: dict, verbose: bool = True) -> tuple[int, int]:
    """Re-encode every embedded map down to its budget. Returns (before, after).

    Rebuilds the BIN chunk from the buffer views in offset order, which is the
    only safe way to change one view's length: every accessor addresses its data
    as an offset INSIDE a view, so as long as the views keep their indices and
    their contents the geometry is untouched by construction.
    """
    try:
        from PIL import Image, ImageFile
    except ImportError:
        raise SystemExit(
            "shrinking the maps needs Pillow (`pip install Pillow`). Without it "
            "a remesh is a 2.75x size REGRESSION - see the header - so this "
            "stops here rather than writing the bigger file.")
    import io

    # Pillow's JPEG encoder writes through a fixed buffer, MAXBLOCK bytes at a
    # time, and `optimize=True` needs the WHOLE scan in one block to build its
    # Huffman tables. With subsampling off — which is what a normal map gets —
    # a scan can exceed it, and the encoder does not grow the buffer, it raises
    #   OSError: broken data stream when writing image file
    # from a libjpeg "Suspension not allowed here". steam_vent's normal map died
    # on exactly this, 2048 -> 256, after eleven assets had gone through
    # untouched. Raising the block is the documented way out and costs 16 MB of
    # transient memory.
    ImageFile.MAXBLOCK = max(getattr(ImageFile, "MAXBLOCK", 65536), 16 * 1024 * 1024)

    before = path.stat().st_size
    js, blob = glb_read(path)
    views = js.get("bufferViews") or []
    roles = image_roles(js)

    new_data: dict = {}
    for i, img in enumerate(js.get("images") or []):
        bv = img.get("bufferView")
        if bv is None:
            continue                       # a URI image; nothing embedded to shrink
        role = roles.get(i, "metallic_roughness")
        side = sides.get(role, TEX_SMALL)
        quality = TEX_ROLES.get(role, (1.0, 88))[1]
        view = views[bv]
        start = view.get("byteOffset", 0)
        raw = blob[start:start + view["byteLength"]]
        pic = Image.open(io.BytesIO(raw))
        was = pic.size
        if pic.width > side or pic.height > side:
            pic = pic.resize((min(side, pic.width), min(side, pic.height)),
                             Image.LANCZOS)
        # JPEG has no alpha and every one of these materials is alphaMode
        # OPAQUE, so dropping it is dropping a channel nothing reads.
        if pic.mode != "RGB":
            pic = pic.convert("RGB")
        buf = io.BytesIO()
        pic.save(buf, format="JPEG", quality=quality, optimize=True,
                 subsampling=0 if role == "normal" else 2)
        new_data[bv] = buf.getvalue()
        img["mimeType"] = "image/jpeg"
        if verbose:
            print("    %-20s %s -> %s  %6.2f -> %5.2f MB"
                  % (role, "%dx%d" % was, "%dx%d" % pic.size,
                     len(raw) / 1e6, len(new_data[bv]) / 1e6))

    if not new_data:
        return (before, before)

    # Repack. Views are walked in their ON-DISK order so anything that relied on
    # adjacency keeps it, and every one is 4-aligned because accessor component
    # types up to 4 bytes must be aligned inside the buffer.
    out = bytearray()
    for idx in sorted(range(len(views)), key=lambda i: views[i].get("byteOffset", 0)):
        view = views[idx]
        if len(out) % 4:
            out += b"\x00" * (4 - len(out) % 4)
        data = new_data.get(idx)
        if data is None:
            start = view.get("byteOffset", 0)
            data = blob[start:start + view["byteLength"]]
        view["byteOffset"] = len(out)
        view["byteLength"] = len(data)
        out += data
    js["buffers"][0]["byteLength"] = len(out)
    after = glb_write(path, js, bytes(out))
    return (before, after)


def submit_remesh(a: dict, source_task: str) -> str:
    return api("POST", "/openapi/v1/remesh", {
        "input_task_id": source_task,
        "topology": "triangle",           # quad would double the index data
        "target_polycount": tri_budget(a),
        # glb only. The fbx nobody imports is 30 MB of the same thing and
        # `prune` deletes it four lines later anyway.
        "target_formats": ["glb"],
    })["result"]


def remesh_one(a: dict, st: dict, args) -> bool:
    """Remesh from the task already paid for, then shrink the maps it inflates.

    Reads the REFINE task id out of state rather than re-generating from the
    prompt: the refine task is the textured result and it is the thing we want
    fewer triangles of. Nothing here re-runs a prompt, so nothing here can come
    back a different object.
    """
    key = a["key"]
    rec = st.setdefault(key, {})
    source = rec.get("refine") or rec.get("preview")
    if not source:
        print("== %s\n    no task in state - `run` it first, or `remesh` has "
              "nothing to remesh FROM" % key)
        return False
    print("== %s  %d tris, %s" % (key, tri_budget(a),
                                  " ".join("%s %d" % (r, s) for r, s
                                           in sorted(tex_budget(a).items()))))

    if not rec.get("remesh"):
        rec["remesh"] = submit_remesh(a, source)
        save_state(st)          # before the wait, same rule as run_one: a crash
        print("    remesh   -> %s" % rec["remesh"])   # must not re-submit and re-charge
    else:
        print("    remesh   resuming %s" % rec["remesh"])
    task = poll(rec["remesh"], "remesh", args.timeout, endpoint="/openapi/v1/remesh/")
    if task.get("status") != "SUCCEEDED":
        print("    FAILED: %s %s" % (task.get("status"),
                                     (task.get("task_error") or {}).get("message", "")))
        return False
    rec["remesh_credits"] = int(task.get("consumed_credits") or 0)

    url = (task.get("model_urls") or {}).get("glb")
    if not url:
        print("    FAILED: the task succeeded with no glb in model_urls")
        return False
    kept = keep_original(key)
    if kept is None:
        print("    !! nothing on disk to keep a copy of; downloading anyway")
    dest = outdir(key) / (key + ".glb")
    got = download(url, dest)
    print("    downloaded %6.2f MB" % (got / 1e6))
    was, now = shrink_glb(dest, tex_budget(a))
    rec["remeshed"] = {"tris": tri_budget(a), "tex": tex_budget(a),
                       "bytes": now, "original_bytes": kept.stat().st_size if kept else None}
    save_state(st)
    # The sidecar too, or `remesh` leaves a meshy.json next to the file that
    # describes a 20,000-triangle 2k asset which is no longer what is there.
    # `run` calls this after us as well; writing it twice is free and forgetting
    # it once is a file that lies.
    write_sidecar(a, st)
    print("    %-20s %6.2f -> %5.2f MB   (%d credits)"
          % ("TOTAL", was / 1e6, now / 1e6, rec["remesh_credits"]))
    return True


def cmd_remesh(args) -> int:
    st = load_state()
    rows = [x for x in select(args.batch, args.only)
            if args.force or not (st.get(x["key"], {}).get("remeshed"))]
    rows = [x for x in rows if delivered(x["key"])]
    if not rows:
        print("nothing to remesh in '%s' (use --force to do it again)" % args.batch)
        return 0

    if args.dry:
        print("%-16s %7s %7s  %-42s" % ("key", "units", "px", "budget"))
        for a in rows:
            t = tex_budget(a)
            print("%-16s %7.0f %7.0f  %5d tris  base %d  normal %d  mr/em %d"
                  % (a["key"], a["screen"], screen_px(a), tri_budget(a),
                     t["base_color"], t["normal"], t["metallic_roughness"]))
        print("\n%d assets, %d credits (5 each)" % (len(rows), 5 * len(rows)))
        return 0

    if args.force:
        # Same trap as `run --force`: leaving the old remesh id in state makes
        # --force re-download the very result you are replacing, for free, while
        # looking like it worked.
        for a in rows:
            st.get(a["key"], {}).pop("remesh", None)
        save_state(st)

    print("balance %d credits" % api("GET", "/openapi/v1/balance")["balance"])
    print("%d assets x 5 = %d credits\n" % (len(rows), 5 * len(rows)))

    # Submitted in one pass and polled in a second. `run` is strictly serial
    # because its two stages depend on each other; these seventeen do not, and
    # serially they are 45 minutes of waiting for a queue that takes 10 at once.
    for a in rows:
        rec = st.setdefault(a["key"], {})
        if rec.get("remesh"):
            continue
        # 429 here is NoMoreConcurrentTasks, not a rate limit on the request:
        # the plan allows a fixed number of tasks IN FLIGHT and seventeen
        # submitted back to back walks straight into it. The first run of this
        # dropped cannon_deck and salvage_pile on the floor that way — they were
        # reported and skipped, and only picked up because the poll loop
        # re-submits anything still missing an id. Waiting is the whole fix.
        for attempt in range(6):
            try:
                rec["remesh"] = submit_remesh(a, rec.get("refine") or rec.get("preview"))
                save_state(st)
                print("submitted %-16s %5d tris  -> %s"
                      % (a["key"], tri_budget(a), rec["remesh"]))
                break
            except MeshyError as e:
                if e.code in (401, 402):
                    print("submit %-16s ERROR %s" % (a["key"], e))
                    return 1
                if e.code != 429 or attempt == 5:
                    print("submit %-16s ERROR %s" % (a["key"], e))
                    break
                print("submit %-16s queue full, waiting" % a["key"])
                time.sleep(30)
    print()

    failed = []
    for a in rows:
        try:
            if not remesh_one(a, st, args):
                failed.append(a["key"])
        except MeshyError as e:
            print("    ERROR %s" % e)
            failed.append(a["key"])
            if e.code in (401, 402):
                break
    print("\nbalance %d credits" % api("GET", "/openapi/v1/balance")["balance"])
    print("originals kept in %s (gitignored, Godot skips dot-directories)"
          % ORIGINALS.relative_to(ROOT))
    print("now: godot --path . --headless --import\n"
          "     python tools/meshy.py prune %s\n"
          "     godot --path . --headless --script tools/static_model.gd" % args.batch)
    if failed:
        print("failed: %s" % ", ".join(failed))
        return 1
    return 0


# --- rigging: the character grows a skeleton ---------------------------------
# Route 2 for the Boilerwright (board SG-12): a generated character has a mesh
# and no bones, and a mesh cannot be retargeted. Meshy's rigging endpoint binds
# a humanoid skeleton to it — POST /openapi/v1/rigging, 5 credits, in about the
# same wait as a preview — and hands back rigged_character_{glb,fbx}_url.
#
# TWO THINGS THIS FILE CARES ABOUT that the endpoint does not decide for you:
#
#   1. REMESH BEFORE RIG, or repeat the captain's SG-13. A skinned mesh cannot be
#      safely decimated afterwards — the skin weights ride the vertices the
#      remesh collapses — so the low-poly pass has to happen on the bare mesh and
#      the rig binds to THAT. The endpoint takes `input_task_id` (a Meshy task)
#      or `model_url` (a public URL or a Data URI). Our remeshed glb is a local
#      file at ~0.6 MB, so `--from datauri` inlines it as a Data URI and rigs the
#      3000-triangle mesh; `--from refine` rigs the full-size refine task instead
#      (simpler, but the rigged character is then the refine's ~12k triangles).
#      The rig accepts up to 300k faces, so either is under the ceiling; the
#      difference is only which triangle count you keep.
#
#   2. THE BONE NAMES ARE NOT DOCUMENTED, and route 2 lives or dies on them: the
#      axe-pack clips are Mixamo-named, so if the auto-rig comes back Mixamo the
#      retarget is one command, and if it comes back with Meshy's own names it is
#      a name map in the manifest (never an edit to the clips). This command does
#      not judge that — it downloads the rig and prints where to read the bones
#      (`tools/mesh_pose.gd` / the lab). The manifest carries the verdict.
def _data_uri(path: Path) -> str:
    import base64
    b64 = base64.b64encode(path.read_bytes()).decode("ascii")
    return "data:model/gltf-binary;base64," + b64


def submit_rig(source_task: str | None, model_url: str | None,
               height_m: float) -> str:
    body: dict = {"height_meters": height_m}
    if source_task:
        body["input_task_id"] = source_task
    elif model_url:
        body["model_url"] = model_url
    else:
        raise SystemExit("submit_rig needs a source task or a model_url")
    return api("POST", "/openapi/v1/rigging", body)["result"]


def rig_one(a: dict, st: dict, args) -> bool:
    key = a["key"]
    rec = st.setdefault(key, {})
    src_task = None
    model_url = None
    frm = getattr(args, "frm", "datauri")
    if frm == "refine":
        src_task = rec.get("refine")
        if not src_task:
            print("== %s\n    no refine task to rig from; `run` it first" % key)
            return False
    elif frm == "remesh_task":
        src_task = rec.get("remesh")
        if not src_task:
            print("== %s\n    no remesh task in state" % key)
            return False
    else:  # datauri: rig the low-poly glb actually on disk
        glb = outdir(key) / (key + ".glb")
        if not glb.exists():
            print("== %s\n    no %s on disk to rig" % (key, glb.name))
            return False
        model_url = _data_uri(glb)
    # ~1.8 units crown to sole is what a usable export is (DESIGN 13f); the rig's
    # height only sets the skeleton's proportion, ingest re-measures anyway.
    height_m = float(a.get("rig_height_m", 1.8))
    print("== %s  rig from %s  (height %.2f m)" % (key, frm, height_m))

    if not rec.get("rig"):
        rec["rig"] = submit_rig(src_task, model_url, height_m)
        save_state(st)          # before the wait, same rule as run_one
        print("    rig      -> %s" % rec["rig"])
    else:
        print("    rig      resuming %s" % rec["rig"])
    task = poll(rec["rig"], "rig", args.timeout, endpoint="/openapi/v1/rigging/")
    if task.get("status") != "SUCCEEDED":
        print("    FAILED: %s %s" % (task.get("status"),
                                     (task.get("task_error") or {}).get("message", "")))
        return False
    rec["rig_credits"] = int(task.get("consumed_credits") or 0)

    result = task.get("result") or task
    glb_url = result.get("rigged_character_glb_url") or (task.get("model_urls") or {}).get("glb")
    fbx_url = result.get("rigged_character_fbx_url") or (task.get("model_urls") or {}).get("fbx")
    if not glb_url:
        print("    FAILED: no rigged_character_glb_url in the result")
        print("    keys: %s" % ", ".join(sorted((result or {}).keys())))
        return False
    out = outdir(key)
    dest = out / (key + "_rigged.glb")
    print("    %-28s %6.2f MB" % (dest.name, download(glb_url, dest) / 1e6))
    got = [dest.name]
    if fbx_url:
        d2 = out / (key + "_rigged.fbx")
        print("    %-28s %6.2f MB" % (d2.name, download(fbx_url, d2) / 1e6))
        got.append(d2.name)
    rec["rig_files"] = got
    save_state(st)
    print("    %d credits. Read the bones with:\n"
          "      godot --path . --headless --script tools/mesh_pose.gd -- "
          "res://assets/models/%s/%s_rigged.glb --bones" % (rec["rig_credits"], key, key))
    return True


def cmd_rig(args) -> int:
    st = load_state()
    rows = [x for x in select(args.batch, args.only) if delivered(x["key"])]
    if not rows:
        print("nothing on disk to rig in '%s'" % args.batch)
        return 0
    if args.force:
        for a in rows:
            st.get(a["key"], {}).pop("rig", None)
        save_state(st)
    print("balance %d credits" % api("GET", "/openapi/v1/balance")["balance"])
    failed = []
    for a in rows:
        try:
            if not rig_one(a, st, args):
                failed.append(a["key"])
        except MeshyError as e:
            print("    ERROR %s" % e)
            failed.append(a["key"])
            if e.code in (401, 402):
                break
    print("\nbalance %d credits" % api("GET", "/openapi/v1/balance")["balance"])
    if failed:
        print("failed: %s" % ", ".join(failed))
        return 1
    return 0


# --- pruning ----------------------------------------------------------------
# One finished asset arrives as about 77 MB across eight files and the renderer
# loads exactly one of them. The other 67 MB is an FBX nobody imports and four
# PBR maps that are ALREADY INSIDE the .glb — Meshy embeds them and also ships
# them loose, so committing both is committing the same textures twice.
#
# This was done by hand for the boarders and it is four steps, one of which is
# silent when you get it wrong, so it is a command now:
#
#   python tools/meshy.py prune props            # after godot --headless --import
#
# THE SILENT ONE is `gltf/embedded_image_handling`. Godot's default is 1,
# EXTRACT: the importer writes the embedded textures out as PNGs beside the .glb
# and the imported scene points at those files. Prune them and the next reimport
# produces a scene that loads, instantiates, and contains NO MESHES — no error,
# no warning, just a prop that is not there. 2 keeps the images inside the .glb
# where nothing can delete them.
#
# The rule is a whitelist rather than a list of things to delete, because the
# next Meshy change adds a file we have never seen and a blacklist keeps it.
KEEP_SUFFIXES = (".glb", ".glb.import", ".tscn", ".tscn.uid",
                 "_thumb.png", "_thumb.png.import")
KEEP_NAMES = ("meshy.json",)
EMBED_IMAGES = "gltf/embedded_image_handling=2"


def prune_one(key: str, dry: bool) -> tuple[int, int]:
    """Delete everything but the mesh. Returns (files removed, bytes freed)."""
    out = outdir(key)
    if not out.is_dir():
        return (0, 0)
    gone = freed = 0
    for path in sorted(out.iterdir()):
        if not path.is_file():
            continue
        name = path.name
        keep = name in KEEP_NAMES or any(
            name == key + suffix for suffix in KEEP_SUFFIXES)
        if keep:
            continue
        size = path.stat().st_size
        print("    %-6s %-30s %6.2f MB" % ("would" if dry else "rm", name, size / 1e6))
        if not dry:
            path.unlink()
        gone += 1
        freed += size

    imp = out / (key + ".glb.import")
    if not imp.exists():
        print("    !! no %s - run `godot --path . --headless --import` FIRST, "
              "then prune. Without the .import there is nothing to fix and the "
              "next import will extract the textures you just deleted."
              % imp.name)
        return (gone, freed)
    text = imp.read_text(encoding="utf-8")
    if EMBED_IMAGES in text:
        print("    ok     %s already embeds its images" % imp.name)
    elif "gltf/embedded_image_handling=" in text:
        fixed = re.sub(r"gltf/embedded_image_handling=\d+", EMBED_IMAGES, text)
        print("    %-6s %s -> %s" % ("would" if dry else "set", imp.name, EMBED_IMAGES))
        if not dry:
            imp.write_text(fixed, encoding="utf-8")
    else:
        print("    %-6s %s += %s" % ("would" if dry else "add", imp.name, EMBED_IMAGES))
        if not dry:
            imp.write_text(text.rstrip("\n") + "\n" + EMBED_IMAGES + "\n",
                           encoding="utf-8")
    return (gone, freed)


def cmd_prune(args) -> int:
    total_files = total_bytes = 0
    for a in select(args.batch, args.only):
        if not delivered(a["key"]):
            continue
        print("== %s" % a["key"])
        gone, freed = prune_one(a["key"], args.dry)
        total_files += gone
        total_bytes += freed
    print("\n%s %d files, %.1f MB" %
          ("would remove" if args.dry else "removed", total_files, total_bytes / 1e6))
    if not args.dry:
        print("now: godot --path . --headless --import      (forced reimport)\n"
              "     godot --path . --headless --script tools/static_model.gd\n"
              "     and CHECK the .tscn still has meshes - an empty one is silent.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("list").set_defaults(fn=cmd_list)
    sub.add_parser("balance").set_defaults(fn=cmd_balance)

    s = sub.add_parser("show")
    s.add_argument("key")
    s.set_defaults(fn=cmd_show)

    for name, fn in (("run", cmd_run), ("fetch", cmd_fetch),
                     ("remesh", cmd_remesh), ("rig", cmd_rig), ("prune", cmd_prune)):
        p = sub.add_parser(name)
        p.add_argument("batch", choices=BATCHES + ["all"])
        p.add_argument("--only", default="", help="comma-separated keys")
        if name != "prune":
            p.add_argument("--timeout", type=int, default=1800,
                           help="seconds per task")
        if name in ("run", "remesh", "prune"):
            p.add_argument("--dry", action="store_true",
                           help="print, change nothing")
        if name in ("run", "remesh", "rig"):
            p.add_argument("--force", action="store_true",
                           help="do it again and pay again")
        if name == "rig":
            # Which mesh the skeleton binds to. `datauri` rigs the low-poly glb
            # ACTUALLY ON DISK (remesh-before-rig, SG-13); `refine` rigs the
            # full-size refine task; `remesh_task` tries the Meshy remesh task id.
            p.add_argument("--from", dest="frm", default="datauri",
                           choices=["datauri", "refine", "remesh_task"],
                           help="which mesh to bind the skeleton to")
        if name == "run":
            p.add_argument("--no-remesh", action="store_true",
                           help="stop after refine, leaving the full-size mesh")
        else:
            # run_one reads this; nothing else has the flag to turn it off.
            p.set_defaults(no_remesh=(name != "run"))
        p.set_defaults(fn=fn)

    args = ap.parse_args()
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
