# Aligning the UI — press F4

**This is the primary alignment workflow.** See something misaligned, on any
screen — a label a few pixels off, a glyph off-centre in its slot, a button
crowding its neighbour — press **F4** right there and move it. The screen you
are ON is the screen you edit: there is no screen picker in the editor because
the game is the screen picker. Close the editor, walk to the screen that is
wrong, press F4 again. (The 84-shot batch page — `SkyGear Tools.bat screens` —
stays as the secondary, batch-evidence mode: for auditing everything at once,
not for fixing anything.)

The panels underneath are the real panels, with the real content, at the real
resolution — not a mockup. Guide lines appear when an edge or a centre lines up
with a sibling's, and the bar at the top says whether the layout is clean or
what is wrong with it — measured by the same detectors `text_audit` runs
(escaping a frame, printed through another string, two widgets colliding), so
an edit that breaks containment is in the verdict before the mouse button is
back up.

## The two modes, by where you are

**During the fight** (the gameplay HUD): you are moving the six PLATES and the
items inside them — the portrait, the health bar, each skill glyph, each lane
row. The four skill slots share one set of element positions: aligning one
glyph aligns all four, because four slots that disagree is four bugs, not four
decisions.

**Everywhere else** (title, draft, pause, settings, workshop, results, the
class comparison, the controls sheet): the editor captures every element as the
screen draws it — text rows, value readouts, widgets, a card's emblem. Click a
panel; click again (or double-click) to reach what is inside it. A selected
element shows its bounds and its NAME, which is the key its offset saves under.

## The keys

| | |
| --- | --- |
| click a panel | select it |
| click again / double-click | descend to the element under the cursor |
| drag | move it |
| **arrows** | nudge 1 px (**Shift** ×10, **Alt** ×0.1 — the SG-39 steps) |
| click the offset readout | type it: **Enter** applies, **Esc** cancels, malformed is refused |
| **Tab** / **Shift+Tab** | next / previous |
| **Esc** | back out a level (element → panel → closed) |
| **Ctrl+Z** | undo, single level (press again to redo) |
| **Ctrl+S** | save |
| **Ctrl+R** | restore defaults — THIS screen only, outside the fight HUD |
| **F12** | photograph this screen (no editor chrome) into `.shots/screens/` |
| **F4** | done |

Plate-mode extras during the fight: drag the bottom-right corner to resize,
**A** cycles the anchor, **C** centres an item in its plate, **Alt+arrows**
resize (a plate has a size to edit; a screen element only has a position).

## Anchors and offsets, and why they matter

A plate records which screen corner it hangs off and how far in, not an
absolute position — a `bottom_right` plate keeps its right edge 24 px from the
right of the screen whether that screen is 1280 or 2560 wide. Changing an
anchor never moves the plate; it only changes what the offset is measured from
(`layout · changing an anchor leaves the plate where it was`, and one level
down `layout · re-anchoring an element leaves it where it was`).

A screen element's offset is the same idea one step further: it is measured
from the element's COMPUTED HOME — wherever the drawing code was about to put
it. Recentre a column, reflow a screen, and the saved offset rides along
instead of pinning stale pixels (`editor · the offset is measured from the
home — move the home and it follows`). Elements are keyed by what they SAY,
digits excluded, so a readout keeps its key while its number ticks
(`layout · a readout's number is not part of its key`).

## Where it goes, and how to make it the default

Saving writes `user://hud_layout.json`, which on Windows is:

```
%APPDATA%\Godot\app_userdata\SkyGear Godot\hud_layout.json
```

That file wins over the shipped `assets/hud_layout.json`. To make your
alignment the default for everyone, run `SkyGear Tools.bat layout` — it
validates at four widths and `-- write` promotes it into the repo. That step is
what makes a hand-alignment pass real; without it the pass lives in AppData and
exists for nobody else.

## If it goes wrong

Nothing you can do in the editor can break the game. A malformed or missing
file falls back per entry — one bad plate costs one plate (`layout · a
malformed plate falls back rather than taking the HUD with it`), one bad screen
offset costs one element (`layout · a malformed screen entry falls back
alone`). A plate cannot be shrunk below 40x28 (`layout · and a plate cannot be
edited down to nothing`). The shipped default is asserted clean at six window
sizes (`layout · the shipped default is a clean layout`, `layout · every HUD
plate fits, and none overlap, at six sizes`), edits round-trip (`layout · an
edit survives a save and a load`, `layout · screen offsets survive a save and a
load`), and every key in the shipped file must resolve to something the game
draws (`editor · every key in the shipped file resolves to something drawn`).
`Ctrl+R` puts the screen you are on back; `Ctrl+Z` takes back the last step.
