#!/usr/bin/env python3
"""Assemble the live Storm-Dusk build from the ported core + the render layer.

One source, many versions — but only ONE of them is ever written. Every shipped
version stays playable on the site as a record of how the game got here, so a
build that has shipped is an artifact, not an output: it is pinned by hash in
FROZEN and this script refuses to regenerate it. Only LIVE is emitted.

That matters because all versions come off the same core. Without the pin, an
engine edit aimed at the current build silently re-emits every previous one —
which is how v2 and v3 ended up carrying lane code they never ran, and how v4's
controls changed months after anyone played it.

  storm-dusk      v2 — fixed camera over a short deck. The build the first
                  playtest rejected; kept as the control for the v3 comparison.
  storm-dusk-v3   v3 — bounded follow camera over a long deck, with the
                  occlusion x-ray pass. Built in response to that playtest.
  storm-dusk-v4   v4 — the responsiveness pass and the first auto-attack.
  storm-dusk-v5   v5 — the MOBA lane restructure.
  storm-dusk-v6   v6 — the Ember Cleave as the real basic attack.
  storm-dusk-v7   v7 — the audio pass: sample layer over the synth.
  storm-dusk-v8   v8 — skills guaranteed, elements as builds.
  storm-dusk-v9   v9 — music, and content.
  storm-dusk-v10  v10 — the build made for a stranger.
  storm-dusk-v11  v11 — the deck fights back.  [LIVE]

Run from anywhere:  python src/storm-dusk/build.py
Retiring a build:   python src/storm-dusk/build.py --freeze   (prints its pin)
"""
import hashlib
import io
import json
import os
import re
import sys

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
    'storm-dusk-v6': {
        'label': 'v6',
        'title': 'SKYGEAR — Storm-Dusk v6 · Lanes',
        # a lane map: wider, and the objective sits at the STERN, not amidships
        'world_w': 1780, 'deck_cx': 890, 'deck_r': 120,
        'deck_w': 1560, 'world_h': 2560, 'deck_cy': 1240, 'deck_h': 2320, 'boiler_y': 2090,
        'js': {
            'name': 'v6',
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
                # The basic swings itself, so both mouse buttons are free
                # for abilities: two on the mouse, two on Q/E, dash on space.
                'keys': {
                    'slots': [
                        {'label': 'LMB', 'mouse': 0, 'alt': '1'},
                        {'label': 'RMB', 'mouse': 2, 'alt': '2'},
                        {'label': 'Q',   'key': 'q', 'alt': '3'},
                        {'label': 'E',   'key': 'e', 'alt': '4'},
                    ],
                    'dash': {'label': 'SPACE', 'key': 'space'},
                },
                # The basic attack is the Ember Cleave itself — the real
                # shape, element and crit, swung automatically at whatever the
                # captain is facing. v4/v5 used a generic sabre flick alongside
                # it, which read as a second, weaker weapon.
                'basic': ['CLOSEHIT', 'EMBER'],
                'basicTurn': 12, 'basicArc': 1.2,
                # mortar on the left button; RMB/Q/E fill from the draft
                'loadout': [['RANGED_AOE', 'FROST']],
            },
        },
    },
    'storm-dusk-v7': {
        'label': 'v7',
        'title': 'SKYGEAR — Storm-Dusk v7 · Lanes',
        # a lane map: wider, and the objective sits at the STERN, not amidships
        'world_w': 1780, 'deck_cx': 890, 'deck_r': 120,
        'deck_w': 1560, 'world_h': 2560, 'deck_cy': 1240, 'deck_h': 2320, 'boiler_y': 2090,
        'js': {
            'name': 'v7',
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
                # The basic swings itself, so both mouse buttons are free
                # for abilities: two on the mouse, two on Q/E, dash on space.
                'keys': {
                    'slots': [
                        {'label': 'LMB', 'mouse': 0, 'alt': '1'},
                        {'label': 'RMB', 'mouse': 2, 'alt': '2'},
                        {'label': 'Q',   'key': 'q', 'alt': '3'},
                        {'label': 'E',   'key': 'e', 'alt': '4'},
                    ],
                    'dash': {'label': 'SPACE', 'key': 'space'},
                },
                # The basic attack is the Ember Cleave itself — the real
                # shape, element and crit, swung automatically at whatever the
                # captain is facing. v4/v5 used a generic sabre flick alongside
                # it, which read as a second, weaker weapon.
                'basic': ['CLOSEHIT', 'EMBER'],
                'basicTurn': 12, 'basicArc': 1.2,
                # mortar on the left button; RMB/Q/E fill from the draft
                'loadout': [['RANGED_AOE', 'FROST']],
            },
        },
    },
    'storm-dusk-v8': {
        'label': 'v8',
        'title': 'SKYGEAR — Storm-Dusk v8 · Lanes',
        # a lane map: wider, and the objective sits at the STERN, not amidships
        'world_w': 1780, 'deck_cx': 890, 'deck_r': 120,
        'deck_w': 1560, 'world_h': 2560, 'deck_cy': 1240, 'deck_h': 2320, 'boiler_y': 2090,
        'js': {
            'name': 'v8',
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
                # The basic swings itself, so both mouse buttons are free
                # for abilities: two on the mouse, two on Q/E, dash on space.
                'keys': {
                    'slots': [
                        {'label': 'LMB', 'mouse': 0, 'alt': '1'},
                        {'label': 'RMB', 'mouse': 2, 'alt': '2'},
                        {'label': 'Q',   'key': 'q', 'alt': '3'},
                        {'label': 'E',   'key': 'e', 'alt': '4'},
                    ],
                    'dash': {'label': 'SPACE', 'key': 'space'},
                },
                # The basic attack is the Ember Cleave itself — the real
                # shape, element and crit, swung automatically at whatever the
                # captain is facing. v4/v5 used a generic sabre flick alongside
                # it, which read as a second, weaker weapon.
                'basic': ['CLOSEHIT', 'EMBER'],
                'basicTurn': 12, 'basicArc': 1.2,
                # mortar on the left button; RMB/Q/E fill from the draft
                'loadout': [['RANGED_AOE', 'FROST']],
            },
        },
    },
    'storm-dusk-v9': {
        'label': 'v9',
        'title': 'SKYGEAR — Storm-Dusk v9 · Lanes',
        # a lane map: wider, and the objective sits at the STERN, not amidships
        'world_w': 1780, 'deck_cx': 890, 'deck_r': 120,
        'deck_w': 1560, 'world_h': 2560, 'deck_cy': 1240, 'deck_h': 2320, 'boiler_y': 2090,
        'js': {
            'name': 'v9',
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
                # The basic swings itself, so both mouse buttons are free
                # for abilities: two on the mouse, two on Q/E, dash on space.
                'keys': {
                    'slots': [
                        {'label': 'LMB', 'mouse': 0, 'alt': '1'},
                        {'label': 'RMB', 'mouse': 2, 'alt': '2'},
                        {'label': 'Q',   'key': 'q', 'alt': '3'},
                        {'label': 'E',   'key': 'e', 'alt': '4'},
                    ],
                    'dash': {'label': 'SPACE', 'key': 'space'},
                },
                # The basic attack is the Ember Cleave itself — the real
                # shape, element and crit, swung automatically at whatever the
                # captain is facing. v4/v5 used a generic sabre flick alongside
                # it, which read as a second, weaker weapon.
                'basic': ['CLOSEHIT', 'EMBER'],
                'basicTurn': 12, 'basicArc': 1.2,
                # mortar on the left button; RMB/Q/E fill from the draft
                'loadout': [['RANGED_AOE', 'FROST']],
            },
        },
    },
    'storm-dusk-v10': {
        'label': 'v10',
        'title': 'SKYGEAR — Storm-Dusk',
        # a lane map: wider, and the objective sits at the STERN, not amidships
        'world_w': 1780, 'deck_cx': 890, 'deck_r': 120,
        'deck_w': 1560, 'world_h': 2560, 'deck_cy': 1240, 'deck_h': 2320, 'boiler_y': 2090,
        'js': {
            'name': 'v10',
            'follow': True,
            'xray': True,
            'pitch': 0.72,
            'camBack': 120,
            'boilerH': 150,
            'lanes': True,
            # v10 is the first build made for someone who has never seen the
            # game. The opening weapon is chosen rather than issued, so the
            # loadout starts empty and startRun opens a draft for slot 0.
            'openingDraft': True,
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
                # The basic swings itself, so both mouse buttons are free
                # for abilities: two on the mouse, two on Q/E, dash on space.
                'keys': {
                    'slots': [
                        {'label': 'LMB', 'mouse': 0, 'alt': '1'},
                        {'label': 'RMB', 'mouse': 2, 'alt': '2'},
                        {'label': 'Q',   'key': 'q', 'alt': '3'},
                        {'label': 'E',   'key': 'e', 'alt': '4'},
                    ],
                    'dash': {'label': 'SPACE', 'key': 'space'},
                },
                # The basic attack is the Ember Cleave itself — the real
                # shape, element and crit, swung automatically at whatever the
                # captain is facing.
                'basic': ['CLOSEHIT', 'EMBER'],
                'basicTurn': 12, 'basicArc': 1.2,
                # Empty: v9 issued a Frost Mortar to everyone. The opening
                # draft fills slot 0 before the first wave.
                'loadout': [],
            },
        },
    },
    'storm-dusk-v11': {
        'label': 'v11',
        'title': 'SKYGEAR — Storm-Dusk',
        # v11 widens the deck. The playtest note was "I wish it was more open",
        # and the lane skeleton is not what was cramped — the walkable width
        # was. 1560 -> 1680 across, which after the thinner cargo runs
        # (_lanes.js) is a lane 226 units wide where v10's was 194.
        'world_w': 1900, 'deck_cx': 950, 'deck_r': 120,
        'deck_w': 1680, 'world_h': 2560, 'deck_cy': 1240, 'deck_h': 2320, 'boiler_y': 2090,
        'js': {
            'name': 'v11',
            'follow': True,
            'xray': True,
            'pitch': 0.72,
            'camBack': 120,
            'boilerH': 150,
            'lanes': True,
            'openingDraft': True,
            # The v11 layer: reactive deck props, the pressure gauge and vent,
            # salvage, close-range lifesteal, readable enemy fire. One flag, so
            # every build before this one still describes what it shipped as.
            'reactive': True,
            'feel': {
                'simHz': 120,
                'inputBuffer': 0.14,
                'killStop': {'SWARM': 0, 'SCRAPPER': 0.030, 'GUNNER': 0.030,
                             'ARMORED': 0.055, 'BOSS': 0.10},
                'stopRefractory': 0.10,
                'cdScale': 0.80,
                'recoilScale': 0.35,
                'accel': 3100, 'friction': 2700,
                # "more dashing". Two charges from the first second of the run
                # rather than one bought with an epic card, a shorter refill, and
                # a dash that always does something when it lands on a body.
                'dashCd': 1.00, 'dashCharges': 2, 'dashDamage': 30,
                'camTau': 0.075,
                'keys': {
                    'slots': [
                        {'label': 'LMB', 'mouse': 0, 'alt': '1'},
                        {'label': 'RMB', 'mouse': 2, 'alt': '2'},
                        {'label': 'Q',   'key': 'q', 'alt': '3'},
                        {'label': 'E',   'key': 'e', 'alt': '4'},
                    ],
                    'dash': {'label': 'SPACE', 'key': 'space'},
                },
                'basic': ['CLOSEHIT', 'EMBER'],
                'basicTurn': 12, 'basicArc': 1.2,
                'loadout': [],
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

# _store.js first: settings and the run log are referenced by the audio layer
# and by the renderer, and nothing in them depends on either.
PARTS = ['_store.js', '_audio_index.js', '_audio.js', '_lanes.js', '_render_head.js', '_render_assets.js', '_render_chars.js', '_render_world.js',
         '_render_entities.js', '_render_lanes.js', '_render_fx_hud.js', '_render_hud.js', '_render_ui.js', '_render_screens.js']

BASE_CORE = R('_core_patched.js')
RENDER = '\n\n'.join(R(p) for p in PARTS)

# A short, deterministic id for the assembled sources. GitHub Pages serves HTML
# with max-age=600, so a returning player can be handed a ten-minute-old build
# and reasonably conclude a change never shipped. This stamps the build into the
# page and into the index link, so the URL changes whenever the sources do and
# "which build am I actually running" is answerable from the title screen.
# Derived from content, never the clock, so rebuilding unchanged sources stays a
# no-op and the frozen-hash check keeps its meaning.
BUILD_ID = hashlib.sha256(
    (BASE_CORE + RENDER + repr(sorted(PRESETS.items()))).encode('utf-8')
).hexdigest()[:7]

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


def stamp_index():
    """Point the landing page at the live build with its current stamp. Without
    it the index can be fresh while the build it links to is served from a
    ten-minute-old cache."""
    p = os.path.join(ROOT, 'index.html')
    if not os.path.exists(p):
        return
    src = io.open(p, encoding='utf-8').read()
    pat = re.compile(r'href="' + re.escape(LIVE) + r'\.html(?:\?b=[0-9a-f]+)?"')
    if not pat.search(src):
        print('note: index.html has no link to %s.html' % LIVE)
        return
    new = pat.sub('href="%s.html?b=%s"' % (LIVE, BUILD_ID), src)
    if new != src:
        io.open(p, 'w', encoding='utf-8').write(new)
        print('stamped   index.html -> %s.html?b=%s' % (LIVE, BUILD_ID))


def build(key):
    spec = PRESETS[key]
    core = BASE_CORE
    for tmpl, original in CORE_SUBS:
        if original not in core:
            raise SystemExit('core substitution target missing:\n  ' + original)
        core = core.replace(original, tmpl % spec, 1)

    js = dict(spec['js'])
    js['build'] = BUILD_ID
    html = (HEAD % {'title': spec['title'], 'favicon': FAVICON, 'label': spec['label'],
                    'preset': json.dumps(js, indent=2)}
            + core + '\n\n' + RENDER + TAIL)
    out = os.path.join(ROOT, key + '.html')
    io.open(out, 'w', encoding='utf-8').write(html)
    print('built %-24s %5d lines  (deck depth %d, pitch %.2f, follow=%s, xray=%s)' % (
        key + '.html', html.count(chr(10)), spec['deck_h'],
        spec['js']['pitch'], spec['js']['follow'], spec['js']['xray']))


# --- what is frozen ---------------------------------------------------------
# A shipped build is a record of what the game was on the day it shipped, and
# every version stays playable on the site. But all builds are emitted from one
# shared core, so an engine edit silently re-emits every one of them — which is
# how v2 and v3 kept getting rewritten by changes that had nothing to do with
# them. So: only LIVE is ever written. Everything else is frozen at the bytes
# below and the build refuses to touch it.
#
# To start a new version: add its preset, set LIVE to it, and move the version
# it succeeded into FROZEN with its hash (python build.py --freeze prints it).
LIVE = 'storm-dusk-v11'

# v2, v3 and v4 are pinned to their state at 2e15353 — the commit where v4
# shipped and the last moment all three were as their playtesters saw them.
# They had since drifted: 650 lines of lane and keybind machinery leaked into
# v2/v3 (inert, but not code they ever ran), and v4 had picked up the LMB/SPACE
# rebind, so its controls were no longer the ones it shipped with.
# v5 keeps the wave-4, ally and hotkey fixes that were asked for while it was
# the live build.
FROZEN = {
    'storm-dusk':    '51744068df5e3da6a0d927efe8ee66de8cec21f469b8a9da8783a05b88839392',
    'storm-dusk-v3': 'c378898a91a464b48c8ad08d153a6fbea2dfc32f7e71575da0e132a6c34cf251',
    'storm-dusk-v4': '247208416ac48fffa2e3b3aba808cb26a69eaa522cb1698f838b4737078eb9f7',
    'storm-dusk-v5': '21bb12981dbfdb9681c6632da8361c97afef7f63572b9726a371321c76f58b55',
    'storm-dusk-v8': 'd66417f911f8c78bf2a143edb5a91cfc18b56ccbc2bda1a86a6685937cb99afc',
    'storm-dusk-v7': 'fcd1e50f8e24321833c50dc9e6b66b89be4adce4e15b81accc55d416871baa5e',
    'storm-dusk-v6': '9eec030eaa2dc100c74b5f93aa866bc7838d2951c112f97d4af65c2d2d91e5db',
    # v9 retired 2026-07-27 when v10 was cut. It is the build people were
    # actually playing while v10 was being built, so it is pinned at exactly
    # the bytes that were live.
    'storm-dusk-v9': '4030c9c74ac9c3c8cc6f8f9972ff96303a7823c425ebdc98a877aae31a82f69f',
    # v10 retired 2026-07-27 when v11 was cut, pinned at the bytes the first
    # public tester played — the run that produced the note this version is an
    # answer to. It stays on the archive page.
    'storm-dusk-v10': 'd023e211970dad3e3a031b1f76fa7bb289b7e9e3383e1bbd1efa7cc89828e3c8',
}


def sha(path):
    return hashlib.sha256(io.open(path, 'rb').read()).hexdigest()


def verify_frozen():
    """Frozen builds must be byte-identical to what shipped. If one has drifted,
    say so loudly and name the command that restores it — a silently rewritten
    old version is worse than a failed build."""
    bad = []
    for k, want in sorted(FROZEN.items()):
        p = os.path.join(ROOT, k + '.html')
        if not os.path.exists(p):
            bad.append((k, 'MISSING'))
        else:
            got = sha(p)
            if got != want:
                bad.append((k, got))
    for k, got in bad:
        print('DRIFTED  %s.html  (%s)' % (k, got[:16]))
    if bad:
        print('')
        print('Frozen builds must not change. Restore them with:')
        print('  git checkout HEAD -- ' + ' '.join(k + '.html' for k, _ in bad))
        return False
    print('frozen   %d build(s) verified unchanged' % len(FROZEN))
    return True


if __name__ == '__main__':
    if '--freeze' in sys.argv:
        # print the hash line for whichever build is being retired
        for k in sorted(set(PRESETS) - set(FROZEN)):
            p = os.path.join(ROOT, k + '.html')
            if os.path.exists(p):
                print("    '%s': '%s'," % (k, sha(p)))
        raise SystemExit(0)

    ok = verify_frozen()
    build(LIVE)
    stamp_index()
    if not ok:
        raise SystemExit(1)
