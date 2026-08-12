#!/usr/bin/env python3
"""Batch-forge the missing stills through Aether Loom, then ingest them.

The Loom's HTTP API is reliable unattended and returns job ids you can poll,
which is what makes a thirty-five-asset run possible at all — the workbench is
for looking at results, not for producing them (ASSET-GENERATION.md §2).

What this adds on top of the API is the thing that actually matters: the prompt
for each asset lives beside the manifest key it fills, the ingest arguments
(chroma, fill, anchor) live there too, and both are in version control. Every
asset in this game before now was produced by a prompt typed into a box and
then lost, so "why does this one look different" had no answer.

  python tools/forge.py list                  # what is missing, and its batch
  python tools/forge.py run ground            # forge one batch and ingest it
  python tools/forge.py run ground --dry      # print what it would send
  python tools/forge.py ingest ground         # ingest already-forged jobs

State lives in tools/forge-state.json so a run can be resumed after a crash
without paying for the same generation twice.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOOM = "http://127.0.0.1:8765"
# The Loom moved on 2026-08-11 (board SG-105: the old path below did not exist,
# which is why `ingest` could not find a single already-paid candidate).
LOOM_DIR = Path(r"C:/Users/alexr/OneDrive/Documents/GitHub/AetherLoom")
STATE = Path(__file__).resolve().parent / "forge-state.json"

# --- the house style --------------------------------------------------------
# Load-bearing, per ASSET-GENERATION.md §4. Every prompt below ends with one of
# these, so a change to the look is a change in one place rather than in
# thirty-five. Do not rewrite them from scratch; change the subject line.
STYLE = (
    "Painterly cel rendering with crisp, slightly irregular near-black ink outlines. "
    "Two-source lighting: steel-blue moon rim from the upper-left and warm amber "
    "lantern fill from the lower-right. Deep indigo, teal, brass, oxblood and warm "
    "leather palette. No photorealism, no 3D render, no flat vector style, no text, "
    "no lettering, no watermark, no motion blur, no extra objects."
)
# For anything that stands on the deck: the camera bake is settled and locked
# (LEVEL-KIT-BRIEF.md), so it is stated the same way every time.
BILLBOARD = (
    "Use a 40-degree high three-quarter view, facing camera lower-left. Preserve the "
    "complete silhouette — every extremity visible, nothing cropped. The subject "
    "occupies at most 68% of the canvas height with at least 15% empty margin above "
    "and below, centred, and no part may touch a canvas edge. "
    "No ground, no floor, no contact shadow, no cast shadow. " + STYLE
)
# For anything painted flat ON the deck. The engine squashes a circle into an
# ellipse through the projection, so the art must be authored straight down.
GROUND = (
    "Viewed straight down from directly overhead, orthographic, no perspective and "
    "no thickness. Perfectly centred and filling 92% of the square canvas. "
    "No characters, no props, no deck planking outside the mark itself, "
    "no cast shadow. " + STYLE
)
# For anything that lives in the HUD rather than the world.
ICON = (
    "A single flat game-UI icon, centred, filling 78% of the square canvas, "
    "read straight on with no perspective. Bold readable silhouette that stays "
    "legible at 32 pixels. No background plate, no frame, no border ring, "
    "no cast shadow. " + STYLE
)


# For HUD FURNITURE: the plates, housings and bezels that other things sit in.
# Distinct from ICON because an icon is a symbol and these are containers — the
# middle has to be empty or the value drawn into it is unreadable. And they are
# authored straight-on: the deck's three-quarter bake is settled and locked, but
# a HUD in perspective is a HUD you cannot read, so this is the one place it does
# not apply. See docs/HUD-PLAN.md §3.
PLATE = (
    "A piece of game-UI furniture from a steampunk airship: brass housing with "
    "visible rivets and honest wear at the corners, dark iron or smoked-glass "
    "recess where a value would be displayed, oxblood leather backing. Read "
    "straight on, orthographic, no perspective, no tilt. Centred and filling 96% "
    "of the canvas. The interior must be EMPTY — no text, no numerals, no icons, "
    "no needle, no fill, no gauge markings inside the recess. No cast shadow, "
    "no drop shadow, no background scene. " + STYLE
)


# The FILL that goes inside a housing. It is the one HUD piece that must NOT be
# empty in the middle, so it cannot take the PLATE clause — which says the
# interior is bare and would contradict the subject line.
BAND = (
    "A seamless horizontal band of light for a game gauge, read straight on, "
    "orthographic. It fills the canvas edge to edge with no margin, and it is "
    "even along its whole length so it can be cut at any point. No frame, no "
    "housing, no end caps, no rivets, no text, no markings. " + STYLE
)


# For a REFERENCE SHEET that a 3D generator turns into a mesh, rather than for
# anything the game draws. Different rules from every other frame here: a
# painterly billboard makes a terrible image-to-3D input, because the model
# inherits the brush strokes as geometry. Flat orthographic side-on, even
# lighting, no drama.
CONCEPT = (
    "A single weapon presented as a clean orthographic side-on concept sheet for "
    "3D modelling: the whole object in frame, perfectly level, blade pointing "
    "left and pommel right, filling 92% of the canvas width. Even neutral studio "
    "lighting with no strong shadow, no rim light, no glow, no motion, no hand "
    "holding it, no background scene, no ground plane. Crisp readable silhouette "
    "with every part distinguishable — blade, guard, grip, pommel. Steampunk "
    "airship-captain weapon: blackened steel, brass fittings, riveted plates, "
    "oxblood leather wrap, honest wear at the edges. Deep indigo, teal, brass, "
    "oxblood and warm leather palette. No text, no lettering, no watermark, no "
    "extra objects, no duplicate views."
)


# The Loom appends its own background clause from the `chroma_key` form field,
# and that clause wins. The first job sent from here asked for green in the
# prompt text, was submitted with the default magenta key, and came back on
# magenta — so saying it twice can only ever contradict itself. Say it once,
# in the field.


# --- what to make -----------------------------------------------------------
# key            manifest key the result is ingested under
# subject        the only part that changes between assets
# frame          BILLBOARD | GROUND | ICON
# chroma         pick against the SUBJECT's colours (§3): magenta for teal/brass/
#                neutral subjects, green for red/violet ones, blue for fire.
# n              4 candidates only for things a player looks at (§8)
# fill/anchor    how loom-ingest fits it into the manifest box
def A(key, subject, frame, chroma="#FF00FF", n=1, fill=0.88, anchor=0.92, batch="misc"):
    return dict(key=key, subject=subject, frame=frame, chroma=chroma, n=n,
                fill=fill, anchor=anchor, batch=batch)


ASSETS = [
    # --- 1 · ground -----------------------------------------------------------
    # Read every second of every fight and still pure code. Highest priority in
    # the queue (§6) for exactly that reason.
    A("rune_enemy",
      "A hostile summoning rune scorched into an airship deck: concentric iron and "
      "oxblood rings with BROKEN outward-pointing barbed teeth around the outer edge, "
      "riveted plate segments, cracked grooves lit by a dull ember glow from beneath. "
      "Threatening, unfinished, reaching outward.",
      GROUND, "#FF00FF", n=1, fill=1.0, anchor=0.5, batch="ground"),
    A("rune_enemy_filled",
      "The same hostile deck rune at the moment it fires: the same concentric iron and "
      "oxblood rings with broken outward barbed teeth, now flooded with molten orange "
      "light so the whole disc glows, grooves running white-hot, sparks at the teeth.",
      GROUND, "#FF00FF", n=1, fill=1.0, anchor=0.5, batch="ground"),
    A("rune_player",
      "A friendly aetheric targeting rune projected onto an airship deck: one CONTINUOUS "
      "unbroken teal ring with small tick marks pointing inward, a fine brass compass "
      "reticle across the middle, clean geometric engraving. Contained, precise, "
      "deliberate — the opposite of ragged.",
      GROUND, "#00FF00", n=1, fill=1.0, anchor=0.5, batch="ground"),
    A("decal_scorch",
      "A soft irregular scorch mark burned into dark timber decking: charred black "
      "centre, brown-grey ash at the edges, a few faint ember specks. Organic, "
      "asymmetric, no ring and no geometry.",
      GROUND, "#FF00FF", fill=1.0, anchor=0.5, batch="ground"),
    A("decal_oil",
      "A spilled machine-oil slick on dark timber decking: a glossy near-black puddle "
      "with an iridescent teal-violet sheen across it and a thin ragged edge.",
      GROUND, "#FF00FF", fill=1.0, anchor=0.5, batch="ground"),
    A("decal_gears",
      "A small scatter of dropped brass clockwork on dark timber decking: a few loose "
      "cogs, a bent spring, two washers and a snapped chain link, lying flat and "
      "slightly tarnished.",
      GROUND, "#FF00FF", fill=1.0, anchor=0.5, batch="ground"),
    A("shadow_blob",
      "A soft round contact shadow: dense near-black at the centre fading smoothly to "
      "fully transparent at the rim, slightly irregular so it does not read as a "
      "perfect circle. Nothing else in frame.",
      GROUND, "#00FF00", fill=1.0, anchor=0.5, batch="ground"),

    # --- 2 · ui ---------------------------------------------------------------
    # Includes the three passive icons that now have slots waiting for them.
    A("ui_icon_slash",
      "A sweeping crescent sabre arc, the blade's cut drawn as a broad tapering "
      "brass-edged crescent with a bright inner core.",
      ICON, "#FF00FF", batch="ui"),
    A("ui_icon_hook",
      "A heavy piercing bolt: a long straight brass lance shaft with a barbed head, "
      "seen side-on, driving to the right, with a short speed streak behind it.",
      ICON, "#FF00FF", batch="ui"),
    A("ui_icon_cone",
      "A widening blast cone: a solid wedge of pressure spreading from a small brass "
      "nozzle at the narrow end, with two lighter arcs inside it.",
      ICON, "#FF00FF", batch="ui"),
    A("ui_icon_aoe",
      "A mortar impact ring seen from above: a bright central charge inside two "
      "concentric shockwave rings, with four short radiating marks.",
      ICON, "#FF00FF", batch="ui"),
    A("ui_icon_ult",
      "A branching chain of lightning: one jagged bolt splitting into three shorter "
      "forks, each ending in a small spark node.",
      ICON, "#FF00FF", batch="ui"),
    A("ui_icon_turret",
      "A sustained beam emitter: a brass lens on the left throwing one thick straight "
      "beam to the right, with a bright core line down its middle.",
      ICON, "#FF00FF", batch="ui"),
    A("ui_icon_field",
      "A standing aura field: three concentric rings around a glowing core, the outer "
      "ring softest, with no direction and no point — it radiates evenly.",
      ICON, "#FF00FF", batch="ui"),
    A("ui_icon_pulse",
      "A detonation pulse: a dense bright core throwing three expanding broken arcs "
      "outward to left and right, caught mid-burst.",
      ICON, "#FF00FF", batch="ui"),
    A("ui_icon_sentry",
      "A planted clockwork sentry gun: a small tripod base, a short brass post and a "
      "single barrel angled up to the right, seen from the side.",
      ICON, "#FF00FF", batch="ui"),
    A("ui_gauge",
      "An ornate brass gauge bezel: a toothed ring of brass with fine graduation marks "
      "and four rivets, completely empty and transparent in the middle. A frame only, "
      "with no dial face, no needle and no numbers.",
      ICON, "#FF00FF", fill=1.0, anchor=0.5, batch="ui"),
    A("ui_portrait",
      "A head-and-shoulders portrait of a steampunk sky-pirate captain: dark auburn "
      "wind-swept hair, brass goggles pushed up on the forehead, weathered dark navy "
      "greatcoat with rich teal lining, a confident readable face turned slightly to "
      "her left. Framed from the collarbone up, filling the canvas.",
      "A head-and-shoulders portrait, read straight on, filling 88% of the square "
      "canvas, centred. No background scene, no frame, no border. " + STYLE,
      "#00FF00", n=4, fill=0.98, anchor=0.5, batch="ui"),
    A("ui_frame",
      "A wide ornate brass HUD plate: a long horizontal riveted brass bar with dark "
      "iron inlay, corner brackets at both ends and a shallow recess along its length. "
      "Empty — nothing mounted on it.",
      "A single wide game-UI plate, read straight on with no perspective, filling the "
      "full width of a 4:1 landscape canvas and centred vertically. No background "
      "scene, no cast shadow. " + STYLE,
      "#FF00FF", fill=1.0, anchor=0.5, batch="ui"),

    # --- 3 · fx ---------------------------------------------------------------
    A("fx_impact",
      "A single impact burst: a hot white-gold core with eight uneven radiating spikes "
      "and a thin ring of debris sparks, caught at its widest frame.",
      ICON, "#006BFF", fill=1.0, anchor=0.5, batch="fx"),
    A("fx_slash",
      "A single curved slash trail: a broad tapering crescent of light, thick at the "
      "start of the stroke and fining to nothing at the tip, with a bright inner edge.",
      "A single effect sprite on its own, read straight on, filling a 3:2 landscape "
      "canvas, centred. No background scene, no cast shadow. " + STYLE,
      "#006BFF", fill=1.0, anchor=0.5, batch="fx"),
    A("fx_bolt",
      "A single horizontal lightning bolt: one jagged branching arc of pale blue-white "
      "electricity running left to right with a hot core and two small side forks.",
      "A single effect sprite on its own, read straight on, filling a 2:1 landscape "
      "canvas edge to edge, centred vertically. No background scene, no cast shadow. "
      + STYLE,
      "#FF00FF", fill=1.0, anchor=0.5, batch="fx"),
    A("fx_steam",
      "A single billowing puff of white steam: soft rounded lobes, dense and bright at "
      "the centre, wispy and thinning at the edges.",
      ICON, "#FF00FF", fill=1.0, anchor=0.5, batch="fx"),
    A("fx_smoke",
      "A single billowing puff of dark oily smoke: soft rounded lobes in charcoal and "
      "brown-grey, dense at the centre, ragged and thinning at the edges.",
      ICON, "#00FF00", fill=1.0, anchor=0.5, batch="fx"),
    A("fx_ember",
      "One single small glowing ember: a hot white-gold centre with a soft orange halo "
      "and a very short trailing wisp. Simple enough to read at 16 pixels.",
      ICON, "#006BFF", fill=1.0, anchor=0.5, batch="fx"),

    # --- 4 · the Colossus -----------------------------------------------------
    # Wave 12 only, but it is the finale, so four candidates each.
    A("BOSS_front_idle",
      "A colossal steampunk siege automaton, the boss of an airship boarding fight: "
      "three times the height of a man, a riveted iron torso with a glowing furnace "
      "chest hatch, huge counterweighted piston arms ending in a wrecking claw and a "
      "spiked ram, short heavy legs, exhaust stacks over its shoulders venting embers, "
      "a narrow visor slit glowing hot. Standing at rest, weight settled, arms low.",
      BILLBOARD, "#FF00FF", n=4, batch="colossus"),
    A("BOSS_front_attack",
      "The same colossal steampunk siege automaton mid-attack: the same riveted iron "
      "torso, glowing furnace chest hatch, counterweighted piston arms, exhaust stacks "
      "and glowing visor slit — now with the wrecking claw hauled back and up and the "
      "torso twisted into the swing, furnace hatch flaring, exhausts venting hard.",
      BILLBOARD, "#FF00FF", n=4, batch="colossus"),
    A("BOSS_back_idle",
      "The same colossal steampunk siege automaton seen FROM BEHIND: the back of the "
      "riveted iron torso with its spine of pressure pipes and a large brass boiler "
      "housing, the two exhaust stacks venting embers over its shoulders, the backs of "
      "the counterweighted piston arms, short heavy legs. No face visible.",
      BILLBOARD, "#FF00FF", n=4, batch="colossus"),

    # --- 5 · props ------------------------------------------------------------
    # v11 — re-forged. The barrel used to be scenery and was painted as scenery;
    # it is now live ordnance that a player is expected to shoot on purpose, and
    # the first tester's note was literally "the kegs are there but dont do
    # anything". So the art has to say "pressurised, volatile, aim here" from
    # across the deck, and it gets four candidates because it is now something
    # a player looks at rather than walks past.
    A("prop_barrel", "A squat riveted STEAM KEG: an iron pressure vessel banded with "
      "heavy brass hoops, a small round pressure gauge on the shoulder with its "
      "needle in the red, a brass relief valve on top wisping a thread of white "
      "steam, hazard stencilling on the belly, seams weeping faint condensation. "
      "It reads as volatile, not as storage.", BILLBOARD, n=4, batch="props"),
    A("prop_brazier", "A cast-iron deck brazier: a shallow riveted iron fire-basket "
      "on three splayed legs, filled with glowing coals throwing warm light upward, "
      "a few small flames and a thread of smoke, soot on the rim. Squat and heavy, "
      "standing on its own.",
      # Blue, not magenta — §3's rule, which the first attempt broke. A brazier
      # is an ORANGE subject: keyed against magenta, the flame tips came back
      # with a pink fringe the keyer cannot separate from fire.
      BILLBOARD, "#006BFF", n=4, batch="v11"),
    A("prop_scrap", "A small heap of salvaged clockwork on the deck: loose brass cogs, "
      "a cracked pressure dial, a coiled spring and two lengths of copper pipe, "
      "piled low and catching a faint warm glint. No container, no crate.",
      BILLBOARD, batch="v11"),
    A("ui_icon_pressure", "A pressure gauge read straight on: a brass bezel, a plain "
      "dial face with graduation ticks, and a single needle swung hard over into "
      "the red at the top right.", ICON, batch="v11"),
    A("ui_icon_vent", "A brass relief valve venting: a short pipe elbow at the bottom "
      "throwing one broad plume of pressurised steam upward and outward, drawn as "
      "three stacked billowing arcs with a bright core.", ICON, batch="v11"),
    A("ui_icon_salvage", "Three brass cogs of different sizes overlapping, with a small "
      "bright spark glint at the top right, read straight on.", ICON, batch="v11"),
    A("prop_crate", "A single small wooden cargo crate with iron corner brackets and "
      "a lashing strap across it.", BILLBOARD, batch="props"),
    A("prop_rope", "A neat coil of thick tarred rope lying on its side, one loose end "
      "tucked under.", BILLBOARD, fill=0.8, batch="props"),
    A("prop_hatch", "A closed deck cargo hatch: a low timber and iron hatch cover with "
      "a brass ring pull and four heavy hinges.", BILLBOARD, fill=0.82, batch="props"),
    A("prop_ballista", "A deck-mounted harpoon ballista: a heavy brass and timber frame "
      "on a swivel base with a barbed harpoon loaded and a coiled chain beside it.",
      BILLBOARD, batch="props"),
    A("prop_railing", "A short section of airship deck railing: two turned brass "
      "stanchions with three taut cables between them and a worn wooden cap rail.",
      BILLBOARD, fill=0.86, batch="props"),
    A("prop_mast", "A tall section of airship mast: a riveted iron and timber column "
      "with brass banding, a cleat, and rigging lines running off it.",
      BILLBOARD, fill=0.94, batch="props"),
    A("prop_cargo_wall",
      "A modular cargo run for an airship deck: a stack of lashed timber crates and "
      "iron-banded chests roughly as wide as it is tall, strapped down with leather "
      "belts and a brass capping rail along the top. It must look deliberate when the "
      "run stops, so both ends are finished rather than sheared off.",
      BILLBOARD, n=4, fill=0.94, anchor=0.94, batch="props"),

    # --- 6 · env --------------------------------------------------------------
    A("env_airship",
      "A distant steampunk escort airship in silhouette: a long gas envelope over a "
      "narrow hull, small brass engine nacelles, running lights along the flank, seen "
      "broadside and slightly below. Small and far away, hazy with distance.",
      "Seen from a distance, side-on, centred, filling 82% of a 2:1 landscape canvas. "
      "No foreground, no ground, no cast shadow. " + STYLE,
      "#FF00FF", fill=0.95, anchor=0.5, batch="env"),
    A("env_clouds_far",
      "A long horizontal band of distant storm cloud at dusk: layered indigo and "
      "slate-violet masses with pale steel-blue tops, flat-bottomed and drifting, "
      "seen at eye level. Soft, hazy, low contrast.",
      "One continuous horizontal band filling a 4:1 landscape canvas edge to edge, "
      "with the cloud mass in the middle and clear space above and below. " + STYLE,
      "#FF00FF", fill=1.0, anchor=0.5, batch="env"),
    A("env_clouds_near",
      "A long horizontal band of nearer storm cloud at dusk: heavier indigo and "
      "charcoal masses with amber underlighting from below and torn wispy edges, "
      "higher contrast and more detail than a distant bank.",
      "One continuous horizontal band filling a 4:1 landscape canvas edge to edge, "
      "with the cloud mass in the middle and clear space above and below. " + STYLE,
      "#FF00FF", fill=1.0, anchor=0.5, batch="env"),

    # --- 8 · hud --------------------------------------------------------------
    # The whole HUD moved into a bottom band so the top of the frame — which is
    # where boarders come from — stops being covered by panels. The layout is
    # right and the material is code: every plate is a `draw_rect` approximating
    # a painted one. These are the painted ones. docs/HUD-PLAN.md is the brief.
    A("ui_plate_wide",
      "A wide riveted brass instrument housing bolted to an airship bulkhead: a "
      "heavy brass frame with rivets along every edge and reinforced corner "
      "brackets, surrounding a large EMPTY recessed panel of dark smoked iron. "
      "Built to have gauges mounted in it. The recess is flat, dark and "
      "completely bare.",
      PLATE, "#00FF00", n=4, fill=0.98, anchor=0.5, batch="hud"),
    A("ui_plate_slot",
      "A single square brass instrument bezel for one control: a chunky riveted "
      "brass square frame with a small raised tab across the top edge where a key "
      "label would be stamped, surrounding an EMPTY deep recess of dark smoked "
      "glass. Nothing mounted in it, nothing written on it.",
      PLATE, "#00FF00", n=4, fill=0.96, anchor=0.5, batch="hud"),
    A("ui_bar_housing",
      "A long horizontal brass gauge channel, empty: a narrow riveted brass trough "
      "with rounded end caps at both ends and a bare dark iron interior running "
      "the full length. The trough is completely empty — no liquid, no fill, no "
      "markings, no needle.",
      PLATE, "#00FF00", n=4, fill=0.98, anchor=0.5, batch="hud"),
    A("ui_bar_fill_hot",
      "A horizontal band of molten orange furnace light with a bright lit upper "
      "edge and a deeper oxblood lower edge, even along its whole length so it "
      "can be cut anywhere. Just the glowing band, edge to edge.",
      BAND, "#00FF00", n=1, fill=1.0, anchor=0.5, batch="hud"),
    A("ui_bar_fill_cold",
      "A horizontal band of verdigris teal aetheric light with a bright lit upper "
      "edge and a deeper blue-green lower edge, even along its whole length so it "
      "can be cut anywhere. Just the glowing band, edge to edge.",
      BAND, "#FF00FF", n=1, fill=1.0, anchor=0.5, batch="hud"),
    A("ui_pressure_dial",
      "A round steampunk pressure dial FACE with no needle: a brass bezel ring "
      "with rivets, an iron dial plate inside it, fine tick marks around the rim, "
      "and a dull red danger arc across the last third of the sweep. Absolutely "
      "no needle, no pointer, no numbers, no lettering — the face only.",
      PLATE, "#00FF00", n=4, fill=0.96, anchor=0.5, batch="hud"),
    A("ui_cooldown_sweep",
      "A radial clock-wipe mask: a solid white circle on transparency with one "
      "clean wedge removed from twelve o'clock clockwise, like a pie chart with a "
      "quarter missing. Pure flat white, hard edges, no shading, no colour, no "
      "detail of any kind. A mask, not an illustration.",
      "A flat white radial mask shape on a plain background, centred, filling 96% "
      "of the square canvas, orthographic. No text, no lettering, no watermark.",
      "#00FF00", n=1, fill=0.96, anchor=0.5, batch="hud"),
    A("ui_dash_pip",
      "A single small round charge indicator: a brass ring with four rivets around "
      "a domed glass centre lit from within by pale aether light. One pip only, "
      "centred, nothing else in frame.",
      PLATE, "#00FF00", n=1, fill=0.86, anchor=0.5, batch="hud"),
    A("ui_lane_track",
      "A long narrow horizontal iron rail channel with a brass end stop at each "
      "end and rivets along its length, the channel between them completely "
      "empty and dark. A track for a marker to slide along. No marker, no fill, "
      "no markings.",
      PLATE, "#00FF00", n=1, fill=0.98, anchor=0.5, batch="hud"),

    # --- 9 · weapon -----------------------------------------------------------
    # NOT a game asset. The melee pack animates a weapon the captain does not
    # have, and these are reference sheets to put through image-to-3D. Four
    # candidates because the whole point is choosing.
    A("weapon_cutlass",
      "A sky-pirate captain's cutlass: a broad slightly curved single-edged "
      "blade of blackened steel with a brass fuller down its length, a heavy "
      "riveted brass knuckle-bow guard, an oxblood leather-wrapped grip and a "
      "geared brass pommel.",
      CONCEPT, "#00FF00", n=4, fill=0.94, anchor=0.5, batch="weapon"),
    A("weapon_gearblade",
      "A steampunk mechanical sword: a straight heavy blade with an exposed "
      "brass gear and chain mechanism running along its spine, vents cut into "
      "the flat that glow faintly amber, a compact brass crossguard and a "
      "leather-bound grip.",
      CONCEPT, "#00FF00", n=4, fill=0.94, anchor=0.5, batch="weapon"),
    A("weapon_boarding_axe",
      "A boarding axe for an airship crew: a broad blackened steel head with a "
      "brass-reinforced cheek and a back-spike, mounted on a short riveted haft "
      "wrapped in oxblood leather, with a brass butt cap.",
      CONCEPT, "#00FF00", n=4, fill=0.94, anchor=0.5, batch="weapon"),
]

BATCHES = ["ground", "ui", "fx", "colossus", "props", "env", "v11", "hud", "weapon"]


# --- plumbing ---------------------------------------------------------------
def post(path: str, fields: dict) -> dict:
    boundary = "----skygearforge"
    parts = []
    for k, v in fields.items():
        parts.append("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n"
                     % (boundary, k, v))
    body = ("".join(parts) + "--%s--\r\n" % boundary).encode("utf-8")
    req = urllib.request.Request(LOOM + path, data=body, method="POST")
    req.add_header("Content-Type", "multipart/form-data; boundary=" + boundary)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))


def get(path: str) -> dict:
    with urllib.request.urlopen(LOOM + path, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def load_state() -> dict:
    if STATE.exists():
        return json.loads(STATE.read_text(encoding="utf-8"))
    return {}


def save_state(st: dict) -> None:
    STATE.write_text(json.dumps(st, indent=1), encoding="utf-8")


def prompt_for(a: dict) -> str:
    return a["subject"] + " " + a["frame"]


## Where a manifest key lands in the GODOT tree, for the keys the browser's
## `_render_assets.js` has never heard of.
##
## THIS IS THE OTHER HALF OF SG-239's FAILURE (board SG-240). `existing()` asked
## the BROWSER build's asset manifest and only that, so the `hud` and `weapon`
## batches — Godot-era assets the browser never had — could not report delivered
## no matter what was on disk. `forge.py list` therefore said "0 delivered, 21
## generations" for four HUD pieces whose target files have been in
## `skygear-godot/assets/art/ui/` and in use since 2026-08-01, which is the
## contradiction that stopped the owner ingesting 33 already-paid generations:
## he was being asked to overwrite live art on the strength of a report that
## could not be right.
##
## The tool now asks BOTH trees. Nothing about generation, cost or delivery
## changes — only the sentence the tool prints about what is already there.
GODOT_TARGETS = {
    "ui_plate_wide":     "skygear-godot/assets/art/ui/plate_wide.png",
    "ui_plate_slot":     "skygear-godot/assets/art/ui/plate_slot.png",
    "ui_bar_housing":    "skygear-godot/assets/art/ui/bar_housing.png",
    "ui_pressure_dial":  "skygear-godot/assets/art/ui/pressure_dial.png",
    ## The three weapons landed as MODELS rather than paintings — the owner's
    ## prompt-to-image-to-3D route (SG-170: "your three weapons are in hands").
    ## A batch whose output took a different shape is still delivered, and a
    ## report that says otherwise is asking someone to pay for it twice.
    "weapon_cutlass":      "skygear-godot/assets/models/sword_cutlass",
    "weapon_gearblade":    "skygear-godot/assets/models/sword_gearblade",
    "weapon_boarding_axe": "skygear-godot/assets/models/axe_furnace",
}


def existing(key: str) -> bool:
    """Is this manifest key already delivered — to EITHER shipping tree?"""
    target = GODOT_TARGETS.get(key)
    if target and (ROOT / target).exists():
        return True
    src = (ROOT / "src" / "storm-dusk" / "_render_assets.js").read_text(encoding="utf-8")
    import re
    m = re.search(r"%s:\s*\{\s*file:'(assets/[^']+)'" % re.escape(key), src)
    return bool(m) and (ROOT / m.group(1)).exists()


# --- commands ---------------------------------------------------------------
def cmd_list(a):
    st = load_state()
    for b in BATCHES:
        rows = [x for x in ASSETS if x["batch"] == b]
        done = sum(1 for x in rows if existing(x["key"]))
        print("%-10s %2d assets, %2d delivered, %2d generations"
              % (b, len(rows), done, sum(x["n"] for x in rows if not existing(x["key"]))))
        for x in rows:
            job = st.get(x["key"], {})
            mark = "OK " if existing(x["key"]) else ("job" if job.get("id") else "   ")
            print("   %s %-22s x%d  %s  %s"
                  % (mark, x["key"], x["n"], x["chroma"], job.get("id", "")))
    return 0


def cmd_run(a):
    st = load_state()
    # --force re-forges something already delivered. It exists for the case that
    # actually came up: a prop whose ROLE changed (the barrel became live
    # ordnance in v11) and whose old art is now wrong rather than missing.
    todo = [x for x in ASSETS
            if (a.batch == "all" or x["batch"] == a.batch)
            and (a.force or (not existing(x["key"])
                             and not st.get(x["key"], {}).get("id")))]
    if a.only:
        todo = [x for x in todo if x["key"] in a.only.split(",")]
    if not todo:
        print("nothing to forge in '%s'" % a.batch)
        return 0
    total = sum(x["n"] for x in todo)
    print("forging %d assets, %d image generations" % (len(todo), total))
    if a.dry:
        for x in todo:
            print("\n=== %s  (x%d, %s) ===\n%s" % (x["key"], x["n"], x["chroma"], prompt_for(x)))
        return 0

    for x in todo:
        try:
            r = post("/api/forge-jobs", {
                "image_prompt": prompt_for(x),
                "quality": "high",
                "candidate_count": str(x["n"]),
                "chroma_key": x["chroma"],
            })
        except Exception as e:                      # noqa: BLE001
            print("  %-22s SUBMIT FAILED  %s" % (x["key"], e))
            continue
        st[x["key"]] = {"id": r["id"], "chroma": x["chroma"], "n": x["n"]}
        save_state(st)
        print("  %-22s -> %s" % (x["key"], r["id"]))
        time.sleep(a.gap)
    return 0


def poll(job_id: str, timeout: int = 900) -> dict:
    t0 = time.time()
    while time.time() - t0 < timeout:
        try:
            j = get("/api/forge-jobs/" + job_id)
        except Exception:                            # noqa: BLE001
            time.sleep(5)
            continue
        if j.get("status") in ("done", "complete", "completed", "error", "failed"):
            return j
        if j.get("candidates"):
            return j
        time.sleep(6)
    return {"status": "timeout"}


def cmd_ingest(a):
    st = load_state()
    rows = [x for x in ASSETS if (a.batch == "all" or x["batch"] == a.batch)]
    if a.only:
        rows = [x for x in rows if x["key"] in a.only.split(",")]
    for x in rows:
        rec = st.get(x["key"])
        if not rec or not rec.get("id"):
            continue
        if existing(x["key"]) and not a.force:
            continue
        j = poll(rec["id"])
        cands = j.get("candidates") or []
        if not cands:
            print("  %-22s no candidates (status=%s)" % (x["key"], j.get("status")))
            continue
        # Candidate 0 unless told otherwise. With four candidates the workbench
        # is the right place to choose; --pick records that choice here so the
        # decision survives in version control with everything else.
        idx = int(rec.get("pick", 0))
        c = cands[min(idx, len(cands) - 1)]
        # The API returns a browser URL (/forges/<job>/candidate_01.png); the
        # file itself is under the Loom's own output tree, which is where
        # loom-ingest.py expects to be pointed.
        name = Path(str(c.get("url") or c.get("path") or c)).name
        p = LOOM_DIR / "output" / "forge_jobs" / rec["id"] / name
        cmd = [sys.executable, str(ROOT / "src" / "loom-ingest.py"), "still",
               str(p), x["key"], "--chroma", x["chroma"],
               "--fill", str(x["fill"]), "--anchor", str(x["anchor"])]
        print("  %-22s <- %s" % (x["key"], p.name))
        subprocess.call(cmd)
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list").set_defaults(fn=cmd_list)
    r = sub.add_parser("run")
    r.add_argument("batch", choices=BATCHES + ["all"])
    r.add_argument("--dry", action="store_true")
    r.add_argument("--only", default="")
    r.add_argument("--force", action="store_true")
    r.add_argument("--gap", type=float, default=1.5, help="seconds between submissions")
    r.set_defaults(fn=cmd_run)
    i = sub.add_parser("ingest")
    i.add_argument("batch", choices=BATCHES + ["all"])
    i.add_argument("--only", default="")
    i.add_argument("--force", action="store_true")
    i.set_defaults(fn=cmd_ingest)
    a = ap.parse_args()
    return a.fn(a)


if __name__ == "__main__":
    raise SystemExit(main())
