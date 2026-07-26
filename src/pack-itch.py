#!/usr/bin/env python3
"""Pack the playable site into an itch.io HTML5 upload.

itch.io serves the zip root, so index.html must sit at the top level.
Run from the repo root:  python src/pack-itch.py
"""
import os
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'skygear-itch.zip')
PAGES = ['index.html', 'classic.html', 'storm-dusk.html', 'storm-dusk-v3.html']

with zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED) as z:
    for name in PAGES:
        z.write(os.path.join(ROOT, name), name)
    # ship the (currently empty) asset tree so ?assets=1 works once art lands
    for base, _dirs, files in os.walk(os.path.join(ROOT, 'assets')):
        for f in files:
            full = os.path.join(base, f)
            arc = os.path.relpath(full, ROOT).replace(os.sep, '/')
            z.write(full, arc)

names = zipfile.ZipFile(OUT).namelist()
print('built %s — %d files, %d KB' % (
    os.path.basename(OUT), len(names), round(os.path.getsize(OUT) / 1024)))
print('upload as an HTML5 project; tick "This file will be played in the browser".')
