# Moving the HUD around

Press **F4** in game. Every panel gets an outline and a name; the selected one
lights up and shows its live numbers.

| | |
| --- | --- |
| drag a panel | move it |
| drag its bottom-right corner | resize it |
| **Tab** / **Shift+Tab** | select next / previous |
| **arrows** | nudge 1 px (**Shift** = 10) |
| **Alt+arrows** | resize 1 px |
| **A** | cycle which screen corner it is anchored to |
| **Ctrl+S** | save |
| **Ctrl+R** | back to the shipped layout |
| **Enter** | drop into a panel and edit the things inside it |
| **Esc** | back out to panel level (again to close) |
| **C** | centre the selected element in its panel |
| **F4** | done |

Two levels. At panel level you are moving the six plates. Press **Enter** and you
are moving what is *inside* the selected plate — the portrait, the health bar,
the pressure dial, each skill glyph, each lane row. That is where alignment
problems actually live: a glyph one pixel off-centre in its slot is not something
panel positioning can fix.

The four skill slots share one set of element positions. Four slots that disagree
about where the glyph sits is four bugs, not four decisions — so aligning one
aligns all of them.

The panels underneath are the real panels, with the real content, at the real
resolution — not a mockup. Guide lines appear when an edge lines up with another
panel's edge, and the bar at the top says whether the layout is clean or what is
wrong with it (off screen, overlapping, or crept into the top half where the
boarders come from).

## Anchors, and why they matter

A panel records which screen corner it hangs off and how far in, not an absolute
position. A `bottom_right` panel keeps its right edge 24 px from the right of the
screen whether that screen is 1280 or 2560 wide. Without this a hand-placed HUD
is only correct on the monitor it was placed on.

Changing an anchor never moves the panel — it only changes what the offset is
measured from.

## Where it goes, and how to make it the default

Saving writes `user://hud_layout.json`, which on Windows is:

```
%APPDATA%\Godot\app_userdata\SkyGear Godot\hud_layout.json
```

That file wins over the shipped one. To make a layout the default for everyone,
copy it over `skygear-godot/assets/hud_layout.json` and commit it — or just send
me the file and I will.

## If it goes wrong

Nothing you can do in the editor can break the game. A malformed or missing file
falls back per panel, so a bad edit costs one panel rather than the HUD; a panel
cannot be shrunk below 40x28; and the harness asserts the shipped default is
clean at six window sizes from 1152 up. `Ctrl+R` puts everything back.
