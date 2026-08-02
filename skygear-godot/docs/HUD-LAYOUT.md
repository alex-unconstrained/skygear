# Aligning the UI — press F4

**This is the primary alignment workflow.** See something misaligned, on any
screen — a label a few pixels off, a glyph off-centre in its slot, a button
crowding its neighbour — press **F4** right there and move it. The screen you
are ON is the screen you edit, and the game is one way to pick a screen — but
no longer the only one: press **P** inside the editor and pose ANY of the 23
screens the text audit shoots (board SG-44), without winning to see the results
screen or dying to see GAMEOVER. (The 92-shot batch page — `SkyGear Tools.bat
screens` — stays as the secondary, batch-evidence mode: for auditing everything
at once, not for fixing anything.)

## The screen picker — press P

**P** (inside the editor) lists the audit's own poses — the same screens (24 of them),
by the same names, posed by the same shared poser (`scripts/screen_poser.gd`)
the audit and the batch camera use, so the picker can never cover less than
the tools do (`editor · the picker poses the batch tool's own screens — one
list`, `editor · every audit screen is posable from the picker`). Arrows +
Enter, or click a row.

Picking a screen poses it LIVE — real widgets, real strings — on a **sandbox**:
a second, hidden, silent copy of the game, never your run. Then the editor
works exactly as it does everywhere else: descend, drag, nudge, type offsets,
verdicts, Ctrl+S, F12. Offsets save under the same screen id the
naturally-reached screen reads — one id, one entry, posed or walked to
(`editor · an offset saved on a posed screen moves the real screen`).

**Esc on a posed screen (with nothing selected) hands the game back exactly.**
A player mid-run who opens F4, poses GAMEOVER, edits it and comes back is
exactly mid-run — the run's clock, boarders, props and RNG do not move a tick
while the glass is up (`editor · and the pose freezes the run while the glass
is up`, `editor · and leaving the pose hands the run back exactly` — the
cutscene player's "the gameplay camera comes back exactly" contract, applied
to the editor). Picking another screen from the list swaps the pose in place;
F4 drops the pose and the editor together. A posed ending also never writes a
row to your run log (`editor · a posed ending writes no fake row to the run
log`).

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
| **Shift** while dragging | lock the drag to its dominant axis — the larger travel since the drag began wins, and a guide line through the element shows which axis is locked. Release Shift to move freely again; re-press it and the axis is re-decided from the whole drag so far (SG-58) |
| drag a **handle** | RESIZE it (SG-80). The selected element grows brass grips on the edges it can move: a single-line string gets the right-hand one only — its height is its point size, which belongs to `ink.gd` — while a wrapped block, a button or a mark get the bottom edge and the corner too. **Shift** during a resize locks it to one dimension, the same gesture as a Shift-drag |
| **arrows** | nudge 1 px (**Shift** ×10, **Alt** ×0.1 — the SG-39 steps; arrow-Shift is the step size, never the drag lock) |
| **Ctrl+arrows** | resize by the same steps — Right/Down grow, Left/Up shrink |
| click the offset readout | type it: **Enter** applies, **Esc** cancels, malformed is refused |
| click the **w×h** readout | type a size the same way: "900, 20" is an absolute width and height, and what gets stored is its distance from the size the code chose |
| **Tab** / **Shift+Tab** | next / previous |
| **P** | the screen picker: pose any of the audit's screens right here |
| **Esc** | back out a level (element → panel → closed; on a posed screen, the last Esc hands the game back) |
| **Ctrl+Z** | undo, single level (press again to redo) |
| **Ctrl+S** | save |
| **Ctrl+R** | restore defaults — THIS screen only, outside the fight HUD |
| **F12** | photograph this screen (no editor chrome) into `.shots/screens/` |
| **F4** | done |

Plate-mode extras during the fight: drag the bottom-right corner to resize,
**A** cycles the anchor, **C** centres an item in its plate, **Alt+arrows**
resize, and the w×h readout takes a typed absolute size (a plate stores its
size outright; a screen element stores a delta from the code's own).

## Anchors and offsets, and why they matter

A plate records which screen corner it hangs off and how far in, not an
absolute position — a `bottom_right` plate keeps its right edge 24 px from the
right of the screen whether that screen is 1280 or 2560 wide. Changing an
anchor never moves the plate; it only changes what the offset is measured from
(`layout · changing an anchor leaves the plate where it was`, and one level
down `layout · re-anchoring an element leaves it where it was`).

## Resizing a text box (SG-80)

The owner's ask: *"can we add the ability to reduce or increase the width of
text boxes, not just nudge, align them."* A selected element carries resize
grips; drag one, or type into the **w×h** readout, or hold Ctrl and use the
arrows. What is stored is a **size delta** — the difference from the size the
drawing code chose — beside the offset, in the same entry:

```
"screens": { "title": { "skygear": { "o": [2, -4], "s": [-120, 0] } } }
```

An entry with no size stays the bare `[dx, dy]` pair it has always been, so a
layout file written before this feature — and one that never resizes anything —
is byte for byte the same file (`layout · an entry older than sizes loads
unchanged, and still saves as a pair`, `layout · screen size deltas survive a
save and a load`). A malformed size costs the size and leaves the offset beside
it standing (`layout · a malformed size entry falls back alone`); a delta of
zero is erased.

What each dimension means depends on what the element is. For a **string** the
width is the box it is laid out and aligned in — narrow it and the string is
measured against the smaller box; its height is its point size and cannot be
edited here. For a **wrapped block** the width is the wrap width (narrow a card
body and it reflows) and the height is a line count. For a **button or a mark**
both are simply the rectangle.

**Narrowing a box past its own words is allowed, and the verdict says so** the
frame it happens (`editor · and a box narrowed past its own words fires the
live verdict`) — that is information, not something to prevent. What is refused
is a box narrower than one `MIN_PT` glyph, which could hold no readable
character at all (`layout · a floor refuses a resize below the ink minimum`,
`editor · a resize past the floor is refused, not obeyed`). Plates keep their
own 40×28 floor. **Ctrl+Z** covers a resize like any other step, and **Ctrl+R**
clears an element's size with its position — one entry, one erase.

A size delta is home-relative exactly as an offset is: widen the window, the
title's own box widens, and a saved −400 still means "four hundred narrower
than the code drew it" (`editor · the size delta is measured from the home size
— reflow and it follows`).

A screen element's offset is the same idea one step further: it is measured
from the element's COMPUTED HOME — wherever the drawing code was about to put
it. Recentre a column, reflow a screen, and the saved offset rides along
instead of pinning stale pixels (`editor · the offset is measured from the
home — move the home and it follows`). Elements are keyed by what they SAY,
digits excluded, so a readout keeps its key while its number ticks
(`layout · a readout's number is not part of its key`).

## Where it goes, and how to make it the default

**Ctrl+S tells you what it did.** On success the bar reads `SAVED ·` and the
real path on disk, so "did it save" is answerable by looking; on a refused
write it reads `COULD NOT SAVE to … — nothing was written` in the alarm
colour. It used to print "layout is clean" when nothing had been written at
all. Saving is also never modal — Ctrl+S commits with the typed readout open
and with the screen picker up, both of which used to swallow it
(`editor · Ctrl+S writes the file, and a fresh load reads the edit back`,
`editor · and Ctrl+S is never modal — the typed box and the picker both let it
through`).

**And nothing else may delete it.** The harness used to remove
`user://hud_layout.json` six times a run and write its own fixtures over it, so
every `SkyGear Tools.bat harness` quietly destroyed a hand-alignment pass that
had been saved correctly minutes earlier — the reported "I hit Ctrl+S but it
looks like they didn't save" (board SG-83). Test runs are pointed at a scratch
file now, and the last check of every harness run compares the player's own
file byte for byte against what it was before the first check ran
(`editor · the harness never touches the player's own saved layout`).

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
