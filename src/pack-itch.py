#!/usr/bin/env python3
"""Pack the playable site into an itch.io HTML5 upload.

itch.io serves the zip root, so index.html must sit at the top level and every
path inside the page has to stay relative — which they are, because the game is
a single self-contained HTML file per build plus an asset tree.

  python src/pack-itch.py            # -> skygear-itch.zip

WHAT GOES IN, AND WHAT DOES NOT. The first version of this script shipped v2
through v5 and an empty asset folder, and was never updated as the game grew —
so the itch upload sat five versions and 24 MB of art behind the site. It now
derives the list from what is actually in the repo:

  · every *.html at the root, so the landing page and the archive both work
  · assets/, minus assets/_masters — 50 MB of chroma-keyed source plates the
    game never loads and nobody should have to download
  · audio/, minus *.orig — the untrimmed raw takes soundforge keeps so a
    re-edit costs no generations, also never fetched at runtime

The result is checked before the script exits: index.html at the root, the live
build present, and nothing under _masters or *.orig inside it.
"""
import io
import os
import re
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'skygear-itch.zip')


def live_build():
    src = io.open(os.path.join(ROOT, 'src', 'storm-dusk', 'build.py'),
                  encoding='utf-8').read()
    m = re.search(r"^LIVE = '([^']+)'", src, re.M)
    return m.group(1) + '.html'


def pages():
    return sorted(n for n in os.listdir(ROOT) if n.endswith('.html'))


def tree(folder, skip_dirs=(), skip_ext=()):
    out = []
    for d, _dirs, files in os.walk(os.path.join(ROOT, folder)):
        rel_dir = os.path.relpath(d, ROOT).replace(os.sep, '/')
        if any(part in rel_dir.split('/') for part in skip_dirs):
            continue
        for f in files:
            if skip_ext and f.endswith(skip_ext):
                continue
            out.append((rel_dir + '/' + f) if rel_dir != '.' else f)
    return out


def main():
    names = pages()
    names += tree('assets', skip_dirs=('_masters',))
    names += tree('audio', skip_ext=('.orig',))

    with zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED) as z:
        for rel in names:
            z.write(os.path.join(ROOT, rel), rel)

    inside = zipfile.ZipFile(OUT).namelist()
    live = live_build()
    problems = []
    if 'index.html' not in inside:
        problems.append('index.html is not at the zip root')
    if live not in inside:
        problems.append('the live build (%s) is missing' % live)
    if any('_masters' in n for n in inside):
        problems.append('chroma masters leaked into the upload')
    if any(n.endswith('.orig') for n in inside):
        problems.append('raw audio takes leaked into the upload')
    for p in problems:
        print('PROBLEM: ' + p)

    print('built %s — %d files, %.1f MB (live build %s)'
          % (os.path.basename(OUT), len(inside),
             os.path.getsize(OUT) / 1e6, live))
    print('upload as an HTML5 project; tick "This file will be played in the browser".')
    print('viewport 1280x720 or larger, and allow fullscreen.')
    return 1 if problems else 0


if __name__ == '__main__':
    raise SystemExit(main())
