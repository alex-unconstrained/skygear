#!/usr/bin/env python3
"""Assemble the Storm-Dusk builds from the ported core + the render layer.

One source, two outputs. The presets below are the only difference between
them, so a gameplay or rendering fix lands in both:

  storm-dusk      v2 — fixed camera over a short deck. The build the first
                  playtest rejected; kept as the control for the v3 comparison.
  storm-dusk-v3   v3 — bounded follow camera over a long deck, with the
                  occlusion x-ray pass. Built in response to that playtest.

Run from anywhere:  python src/storm-dusk/build.py
"""
import io
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))


def R(n):
    return io.open(os.path.join(HERE, n), encoding='utf-8').read()


# --- presets ----------------------------------------------------------------
# `deck` values are ground-plane units and are substituted into the core's
# TUNING block; everything else is handed to the renderer as `PRESET`.
PRESETS = {
    'storm-dusk': {
        'label': 'v2',
        'title': 'SKYGEAR — Storm-Dusk',
        'world_w': 1400, 'deck_cx': 700, 'deck_r': 150, 'deck_w': 900, 'world_h': 1520, 'deck_cy': 760, 'deck_h': 1360, 'boiler_y': 760,
        'js': {
            'name': 'v2',
            'follow': False,      # camera pinned to the deck centre
            'xray': False,        # no see-through pass
            'pitch': 0.72,
            'camBack': 0,
            'boilerH': 210,
            # feel defaults = exactly how v2/v3 shipped; frozen as a record
            'feel': { 'simHz': 60, 'inputBuffer': 0, 'killStop': None,
                      'stopRefractory': 0, 'cdScale': 1.0, 'recoilScale': 1.0,
                      'accel': None, 'friction': None, 'dashCd': None,
                      'camTau': 0.155, 'autoAttack': None, 'keys': None, 'loadout': None },
        },
    },
    'storm-dusk-v3': {
        'label': 'v3',
        'title': 'SKYGEAR — Storm-Dusk v3',
        'world_w': 1400, 'deck_cx': 700, 'deck_r': 150, 'deck_w': 900, 'world_h': 2400, 'deck_cy': 1200, 'deck_h': 2240, 'boiler_y': 1200,
        'js': {
            'name': 'v3',
            'follow': True,       # bounded follow — the objective stays framed
            'xray': True,         # silhouette anything hidden behind tall geometry
            # Back to the spec's 0.72 (41 deg). The steeper 0.86 existed only
            # to shrink the Boiler's occlusion shadow; the x-ray pass and the
            # flattened Boiler solve that properly, and with the real trial art
            # in engine 41 deg frames the fight better and sits better under
            # figures painted near eye level. Override live with ?pitch= or [ ].
            'pitch': 0.72,
            'camBack': 120,       # keeps the captain just below screen centre
            'boilerH': 132,       # a flat engine block, not a tower
            # feel defaults = exactly how v2/v3 shipped; frozen as a record
            'feel': { 'simHz': 60, 'inputBuffer': 0, 'killStop': None,
                      'stopRefractory': 0, 'cdScale': 1.0, 'recoilScale': 1.0,
                      'accel': None, 'friction': None, 'dashCd': None,
                      'camTau': 0.155, 'autoAttack': None, 'keys': None, 'loadout': None },
        },
    },
    'storm-dusk-v4': {
        'label': 'v4',
        'title': 'SKYGEAR — Storm-Dusk v4',
        'world_w': 1400, 'deck_cx': 700, 'deck_r': 150, 'deck_w': 900, 'world_h': 2400, 'deck_cy': 1200, 'deck_h': 2240, 'boiler_y': 1200,
        'js': {
            'name': 'v4',
            'follow': True,
            'xray': True,
            'pitch': 0.72,
            'camBack': 120,
            'boilerH': 132,
            # --- the responsiveness pass ------------------------------------
            'feel': {
                'simHz': 120,         # halves worst-case input-to-action latency
                'inputBuffer': 0.14,  # a press just before ready still fires
                # Per-type freeze on kill. Trash dying must not stop the world:
                # a flat 70ms was freezing the sim ~46% of wall time at wave 11.
                'killStop': {'SWARM': 0, 'SCRAPPER': 0.030, 'GUNNER': 0.030,
                             'ARMORED': 0.055, 'BOSS': 0.10},
                'stopRefractory': 0.10,
                'cdScale': 0.80,      # spec asked to bias shorter than feels right
                'recoilScale': 0.35,  # cast pushback fought the player's intent
                'accel': 3100, 'friction': 2700, 'dashCd': 1.15,
                'camTau': 0.075,      # camera keeps up instead of trailing
                # True auto-attack, MOBA-style: the captain picks the nearest
                # boarder, turns to face it and swings on her own cadence. The
                # four slots stop being something you mash and become abilities.
                # With a real auto-attack the left button is free. Standard
                # ARPG/MOBA hand: two abilities on the mouse, two on Q/E, dash
                # on space where an action-game player expects to find it.
                'keys': {
                    'slots': [
                        {'label': 'LMB', 'mouse': 0, 'alt': '1'},
                        {'label': 'RMB', 'mouse': 2, 'alt': '2'},
                        {'label': 'Q',   'key': 'q', 'alt': '3'},
                        {'label': 'E',   'key': 'e', 'alt': '4'},
                    ],
                    'dash': {'label': 'SPACE', 'key': 'space'},
                },
                # mortar on the left button by default
                'loadout': [['RANGED_AOE', 'FROST'], ['CLOSEHIT', 'EMBER']],
                'autoAttack': {
                    'range': 195,     # comfortably past a boarder's own reach
                    'dmg': 16,
                    'cd': 0.55,
                    'arc': 1.2,       # radians of slack on the facing check
                    'turn': 12,       # radians/sec the captain re-faces
                },
            },
        },
    },
    'storm-dusk-v5': {
        'label': 'v5',
        'title': 'SKYGEAR — Storm-Dusk v5 · Lanes',
        # a lane map: wider, and the objective sits at the STERN, not amidships
        'world_w': 1780, 'deck_cx': 890, 'deck_r': 120,
        'deck_w': 1560, 'world_h': 2560, 'deck_cy': 1240, 'deck_h': 2320, 'boiler_y': 2090,
        'js': {
            'name': 'v5',
            'follow': True,
            'xray': True,
            'pitch': 0.72,
            'camBack': 120,
            'boilerH': 150,
            'lanes': True,
            'feel': {
                'simHz': 120,
                'inputBuffer': 0.14,
                'killStop': {'SWARM': 0, 'SCRAPPER': 0.030, 'GUNNER': 0.030,
                             'ARMORED': 0.055, 'BOSS': 0.10},
                'stopRefractory': 0.10,
                'cdScale': 0.80,
                'recoilScale': 0.35,
                'accel': 3100, 'friction': 2700, 'dashCd': 1.15,
                'camTau': 0.075,
                # With a real auto-attack the left button is free. Standard
                # ARPG/MOBA hand: two abilities on the mouse, two on Q/E, dash
                # on space where an action-game player expects to find it.
                'keys': {
                    'slots': [
                        {'label': 'LMB', 'mouse': 0, 'alt': '1'},
                        {'label': 'RMB', 'mouse': 2, 'alt': '2'},
                        {'label': 'Q',   'key': 'q', 'alt': '3'},
                        {'label': 'E',   'key': 'e', 'alt': '4'},
                    ],
                    'dash': {'label': 'SPACE', 'key': 'space'},
                },
                # mortar on the left button by default
                'loadout': [['RANGED_AOE', 'FROST'], ['CLOSEHIT', 'EMBER']],
                'autoAttack': {'range': 195, 'dmg': 16, 'cd': 0.55,
                               'arc': 1.2, 'turn': 12},
            },
        },
    },
}

CORE_SUBS = [
    ('  world:   { w: %(world_w)s, h: %(world_h)s },', '  world:   { w: 1400, h: 1520 },'),
    ('  deck:    { cx: %(deck_cx)s, cy: %(deck_cy)s, w: %(deck_w)s, h: %(deck_h)s, r: %(deck_r)s, bow: 170 },',
     '  deck:    { cx: 700, cy: 760, w: 900, h: 1360, r: 150, bow: 170 },'),
    ('  boiler:  { x: %(deck_cx)s, y: %(boiler_y)s, r: 62, hp: 500 },',
     '  boiler:  { x: 700, y: 760, r: 62, hp: 500 },'),
]

FAVICON = ("<link rel=\"icon\" href=\"data:image/svg+xml,"
           "%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E"
           "%3Crect width='32' height='32' rx='6' fill='%230D0B12'/%3E"
           "%3Cg fill='none' stroke='%23E8C376' stroke-width='2.6'%3E"
           "%3Ccircle cx='16' cy='16' r='6.5'/%3E"
           "%3Cpath d='M16 3.5v3.5M16 25v3.5M3.5 16h3.5M25 16h3.5"
           "M7.2 7.2l2.5 2.5M22.3 22.3l2.5 2.5M24.8 7.2l-2.5 2.5M9.7 22.3l-2.5 2.5'/%3E"
           "%3C/g%3E%3Ccircle cx='16' cy='16' r='2.4' fill='%2337F0C8'/%3E%3C/svg%3E\">")

PARTS = ['_lanes.js', '_render_head.js', '_render_assets.js', '_render_chars.js', '_render_world.js',
         '_render_entities.js', '_render_lanes.js', '_render_fx_hud.js', '_render_hud.js', '_render_screens.js']

BASE_CORE = R('_core_patched.js')
RENDER = '\n\n'.join(R(p) for p in PARTS)

HEAD = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>%(title)s</title>
%(favicon)s
<style>
  html,body{margin:0;padding:0;width:100%%;height:100%%;background:#0D0B12;overflow:hidden;
            font-family:'Trebuchet MS',system-ui,sans-serif;-webkit-user-select:none;user-select:none;}
  canvas{display:block;width:100vw;height:100vh;cursor:none;touch-action:none;}
</style>
</head>
<body>
<canvas id="c"></canvas>
<script>
"use strict";
/* ============================================================================
   SKYGEAR %(label)s — Cinderia-style restyle
   Built to docs/skygear-visual-asset-spec-v1.md.
   Generated by src/storm-dusk/build.py — edit the sources, not this file.
============================================================================ */
const PRESET = %(preset)s;

"""

TAIL = """
</script>
</body>
</html>
"""


def build(key):
    spec = PRESETS[key]
    core = BASE_CORE
    for tmpl, original in CORE_SUBS:
        if original not in core:
            raise SystemExit('core substitution target missing:\n  ' + original)
        core = core.replace(original, tmpl % spec, 1)

    html = (HEAD % {'title': spec['title'], 'favicon': FAVICON, 'label': spec['label'],
                    'preset': json.dumps(spec['js'], indent=2)}
            + core + '\n\n' + RENDER + TAIL)
    out = os.path.join(ROOT, key + '.html')
    io.open(out, 'w', encoding='utf-8').write(html)
    print('built %-24s %5d lines  (deck depth %d, pitch %.2f, follow=%s, xray=%s)' % (
        key + '.html', html.count(chr(10)), spec['deck_h'],
        spec['js']['pitch'], spec['js']['follow'], spec['js']['xray']))


if __name__ == '__main__':
    for k in PRESETS:
        build(k)
