#!/usr/bin/env python3
"""Assemble skygear.html (Cinderia fork) from the ported core + render layer."""
import io, os
HERE = os.path.dirname(os.path.abspath(__file__))
def R(n): return io.open(os.path.join(HERE, n), encoding='utf-8').read()

core = R('_core_patched.js')
parts = ['_render_head.js','_render_assets.js','_render_chars.js','_render_world.js',
         '_render_entities.js','_render_fx_hud.js','_render_hud.js','_render_screens.js']
render = '\n\n'.join(R(p) for p in parts)

html = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>SKYGEAR \u2014 Storm-Dusk</title>
<style>
  html,body{margin:0;padding:0;width:100%;height:100%;background:#0D0B12;overflow:hidden;
            font-family:'Trebuchet MS',system-ui,sans-serif;-webkit-user-select:none;user-select:none;}
  canvas{display:block;width:100vw;height:100vh;cursor:none;touch-action:none;}
</style>
</head>
<body>
<canvas id="c"></canvas>
<script>
"use strict";
/* ============================================================================
   SKYGEAR \u2014 Cinderia-style restyle (fork)
   Built to skygear-visual-asset-spec-v1.md.

   Same game, new presentation layer:
     \u00b7 high three-quarter pinhole camera over a projected ground plane
     \u00b7 billboard sprites, depth-scaled, painter-sorted far -> near
     \u00b7 storm-dusk palette: dark base, saturated gameplay pops
     \u00b7 deck drawn as projected quads; ground art authored as circles
     \u00b7 every \u00a74 image asset slots in by manifest path, with a procedural
       stand-in painted to the same rules wherever a file is missing

   Layout: TUNING -> data -> engine -> state -> systems -> RENDER -> boot
============================================================================ */

""" + core + "\n\n" + render + """
</script>
</body>
</html>
"""
OUT = os.path.normpath(os.path.join(HERE, '..', '..', 'storm-dusk.html'))
io.open(OUT, 'w', encoding='utf-8').write(html)
print('built', OUT, '-', html.count(chr(10)), 'lines')
