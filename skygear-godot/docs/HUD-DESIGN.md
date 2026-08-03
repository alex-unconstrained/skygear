# The fight HUD, and why the bottom-left corner goes first

**The owner's ask, 2026-08-02, with a Supervive screenshot:** *"I think we should
consider looking at how other mobas have clear UI/HUDs. And while we want the
game to feel themed and steampunk, maybe also using borders, accents, smaller
elements to give the thematic guidance while not sacrificing the player's
readability of the UI elements. For this, and 2D assets, we'd want to use the GUI
tool we built. We also would want to really think and maybe focus on one space
first (character info, bottom left) to see how we can make it look."*

One space. This document is the survey of that space, the vocabulary that came
out of it, and the rebuilt captain cluster. The skill bar, the lane readout and
the objective plate are **deliberately untouched** — the direction gets judged on
one corner before it spreads to five.

`docs/MENU-DESIGN.md` did this job for the menus and its own §5 says the fight
HUD is a different problem: *"it is read at a glance under attack, it is the F4
plate editor's domain rather than the screen editor's, and its housings are
already painted art. Nothing here applies to it."* That is still true. The
vocabulary below is a cousin of the menu's, not a copy of it, and §3 says exactly
where the two part company.

---

## 1 · What the reference actually does

`C:/Users/alexr/Downloads/supervive-between-the-trees.jpg`. Cover the middle of
it and look only at the bottom-left block. Four things are true of it and none of
them are true of ours.

**1. The clusters are bounded, and separated by real gaps.** The character block,
the ability row, the currency readout and the evolution picker are four islands
with dead space between them. Nothing has to be untangled from anything else,
because nothing is touching anything else.

**2. Each cluster answers one question.** The character block says *how am I
doing*. It does not also carry the map, the timer or the shop. The eye that
wants "am I about to die" goes to exactly one place and finds exactly one answer.

**3. The character block is unequal on purpose.** The portrait is a large hard
polygon. The health bar is a long thick horizontal. The resource is a *thinner*
horizontal beneath it. The level is a small hard badge. Four different shapes at
four different sizes, so peripheral vision can tell them apart without resolving
a single glyph. **Nothing in it is a row of the same height as its neighbour.**

**4. Theme lives in the frame; content sits on quiet ground.** The angled corner
cuts, the metal rim, the small notches at the ends — all of that is on the
*outside*. The health bar itself is a flat saturated band on near-black. The
decoration never crosses onto the pixels carrying the number.

### What we take, and what we refuse

| take | refuse |
|---|---|
| bounded clusters, real gaps | its palette — this is a lantern-lit airship, not a neon arena |
| one question per cluster | its density: it carries a shop, an evolution picker and a currency ledger down there and we have four readouts |
| unequal shapes and unequal sizes | its geometry — hard-cut hexagons are a sci-fi mark and every corner on this ship is square or riveted |
| decoration on the frame, data on quiet ground | a literal copy of the arrangement. Ours has a dial and dash charges; theirs has neither |

---

## 2 · What our cluster is FOR, and how fast the answer has to come

Before anything is drawn, the question the cluster exists to answer, and its
deadline. Everything in §4 is measured against these.

The captain stands at the **centre** of the screen and the boarders come down the
frame at her. For the whole fight the player's eye is on the middle of the
screen. **The bottom-left cluster is therefore read peripherally, not looked
at** — which is the single most important fact about it and the one the current
build ignores.

Three questions, in this priority order:

| | question | how it is read | deadline |
|---|---|---|---|
| 1 | **How much life have I got?** | peripheral — no eye movement at all | continuous. It must be answerable *while* looking somewhere else |
| 2 | **What can I spend, and can I move?** | a flick of the eye and back | ~250 ms, once per decision |
| 3 | **Who am I, and what is on me?** | a deliberate look, between waves | seconds. It may cost a glance |

Question 1 is answerable by **shape, size and colour alone**. It has to be: a
glyph read peripherally is not read. Questions 2 and 3 may use words.

**The current build answers them in exactly the wrong order**, and the
proportions say so. Photograph `playing` at 1920 (`.shots/screens/hud-before/`)
and measure the captain plate:

| | before |
|---|---|
| lit health band, at 100/100 | **2 rows of a 200 × 14 bed — 359 px².** A hairline (§7: it is a bug, and it had been on screen since the art landed) |
| portrait disc | 60 across = 2 827 px² of glass |
| pressure dial | 40 × 40 |
| every text row | 12 pt, four of them, all the same weight |
| gap between the health readout, the gauge and the dashes | **0 px.** They share one undifferentiated brass field |

So the least important thing on the plate (identity) is nearly eight times the
area of the most important one (life), the four readouts are indistinguishable in
weight, and there is no boundary anywhere. It is question 3 drawn largest and
question 1 drawn smallest.

Two consequences visible in the before frames and reported by nobody, because
nobody plays looking at this corner:

- **The two dash pips read as belonging to PRESSURE.** `dash_pips` is anchored 44
  px right of `dash_label`, which puts it past the end of the word PRESSURE on
  the row above. The row reads `PRESSURE ⬤ ⬤ / DASH`.
- **The Boilerwright's `SPC JET` is printed onto the plate's right bracket**, and
  his gauge — a flat damage multiplier, the whole of his class — is a 40 px dial
  and two words.

---

## 3 · The vocabulary of the fight HUD

The menus are *hardware bolted to the ship*: a board, plates, a lamp, a door,
cold iron, rungs. The fight HUD is a cousin, and the difference is a rule:

> **A menu is furniture you look at. A HUD is an instrument panel you read
> without looking.** The menu may spend contrast on material; the HUD spends it
> on the value. So the fight HUD inherits the menu's *materials* — brass, cold
> iron, rivets, bevels, the engraved channel — and **none of its lighting.**
> Nothing in the fight HUD flickers, breathes, or lights on hover. There is no
> lamp. The only thing on this panel that moves is data.

Six nouns. The first three are the cluster; the last three are the grammar.

### 3.1 The bulkhead
The plate a cluster is bolted to — `plate_wide.png` through `_panel`, already
painted, already nine-sliced. The frame is the theme; **nothing is ever drawn on
it.** Everything lives in `interior()`.

### 3.2 The porthole
Identity. A single round window at the left end of the bulkhead, big enough to be
the largest object in the cluster, with the live auto-attack arc swept round its
rim and four rivets holding it into the plate. It is the only round thing in the
cluster after §3.5, so "round" now means "this is her".

`portrait_corsair.png` is a **cut-out bust on transparency** — not a disc and not
a framed portrait — so something has always had to frame it, and what was doing
the job was `gauge_ring.png` drawn at `grow(6)`: a thin *instrument* bezel with
graduation marks, the wrong object at this size, fighting the live auto-attack
arc for the same rim. Three concentric rings on one element, one of them
carrying information.

Four layers now, each with one job: the glass she is behind, her, the brass rim,
and the live arc outside all of it. **The only ring that moves is the one
carrying information.**

### 3.3 The gauge
Any quantity, as a horizontal trough with a band in it. Two weights and the
difference is load-bearing:

- **The heavy gauge** — life. The painted `bar_housing.png` trough, its band at
  full authored height, segment ticks, name and number in an engraved channel
  *inside* the trough. This is the loudest object in the cluster and it is
  supposed to be.
- **The light gauge** — everything else. Half the height, no painted housing, a
  stamped channel with a hard ink edge and a flat band. It reads as a *different
  kind of object* at a glance, which is how "this is not your health" gets said
  without a word.

### 3.4 The instrument
A small round dial, needle-driven, bolted to the **left end of a light gauge** as
its cap. `pressure_dial.png`, 26 px. It is the accent — it says steampunk, it
says at-a-glance-full-or-empty, and it carries no number. The gauge beside it
carries the number. This is the reference's fourth lesson applied literally:
the decoration is on the end of the object, not across the value.

### 3.5 The channel
`SkyGearInk.recess`, under **every** string in the cluster, without exception.
The plates are painted with bright rivets and scratches running through the line
of text and the recess is what makes a word on brass legible. In the menus it was
also an aesthetic — an engraved label. Here it is purely mechanical: it is what
lets the contrast figure be a number rather than a coin toss.

### 3.6 The divider
Two lines — one dark, one lit brass — with **≥ 8 px of dead plate on either
side**. This is the reference's first lesson and it is two `draw_line` calls.

One divider, horizontal, between life and means. A *vertical* one between the
porthole and the readouts was drafted and cut: the auto-attack arc swings out to
`seat + 7` and a rule the live ring crosses reads as a mistake rather than as a
boundary. The porthole's own brass rim is the boundary on that side, which is
more the reference's idiom anyway — its clusters are bounded by their own frames,
not by rules drawn between them.

### The rule that outranks all six

**Nothing in the cluster moves when the state changes.** Not when a status
appears, not when the class changes, not when a dash recharges. Every element has
a fixed bay, and the two things that are only sometimes there — the status chips
and the overpressure ring — **overlay** rather than occupy. A readout that
reflows is a readout that has to be re-found, and re-finding costs the 250 ms
that question 2's whole budget is made of.

---

## 4 · The design: the captain's station

The plate grows from **350 × 132** to **380 × 146** and everything inside it is
re-laid. It stays anchored `bottom_left [24, -24]`; it stays inside the bottom
band; it still gives way to the hand on a narrow window through
`hud_plates()`'s existing clamp.

Interior at 1920 is **316 × 82**. Two bays:

```
+- bulkhead 380x146 -----------------------------------------+
|    .------.   +-------------------------------------+      |
|   ( porthole ) |#########################...........|  30  |   LIFE
|   ( 76 + arc ) | CAPTAIN                    82 / 100 |      |
|   ( [!] [~]  ) +-------------------------------------+      |
|    `------'   ------------------------------------- divider |
|               (o) |#######.....................| [=]   16   |   MEANS
|                22 | PRESSURE                 41 |           |
|               ::: DASH  (o)(o)( ) ::::::::::::::::::   14    |   CHARGE
+------------------------------------------------------------+
```

| bay | what | size | why that size |
|---|---|---|---|
| porthole | glass + bust + brass rim + 4 rivets + the auto arc | 76 across | the largest object, because it is the only one identifiable at zero resolution. Status chips are set into its lower glass as lamps — overlaid, so nothing shifts when one lights |
| life | heavy gauge, name + value in-channel | 194 × 30 | the widest single band in the cluster; six times the lit band area it had |
| means | instrument cap + light gauge | 22 + 140 × 16 | the gauge is a little over **half** the life bar's height. "Not your health", said by proportion |
| charge | DASH + pips, or his three key chips, on a stamped rail | 194 × 14 | the quietest row; the pips sit six pixels after the word, not forty-four |

### How each choice is measured

Readability outranks theme, so every claim above is a number that can be taken
off a PNG rather than an assertion. Measured on `.shots/screens/hud-before/` and
`.shots/screens/hud-after/`, `playing-1920x1080.png`, inside the health gauge's
own bed:

| what | measure | before | floor | after |
|---|---|---|---|---|
| life, peripheral | height of the lit band | **2 px** | **≥ 14 px** (≥ 11.6 physical at the 1600 minimum) | **15.6 px** |
| life, peripheral | lit band area at 100 % | **359 px²** | **≥ 2 000** | **2 156 px²** (6.0 ×) |
| hierarchy | lit band area ÷ porthole glass | 0.13 | **> 0.45** | 0.48 |
| separation | gap, life gauge to light gauge | 0 px | **≥ 10 px** | 13 px |
| separation | gap, light gauge to charge rail | 0 px | **≥ 8 px** | 8 px |
| legibility | strings in the cluster under `CONTRAST_FLOOR` | 0 | **0** | 0 |
| legibility | smallest point size in the cluster | 12 | **≥ `SkyGearInk.MIN_PT` = 12** | 12 |
| stability | elements that move when a status appears | 2 | **0** | 0 |
| containment | strings printed on the painted brass frame | 1 (`SPC JET`) | **0** | 0 |
| the whole audit | `tools/text_audit.gd`, 24 screens × 4 widths | clean | **clean** | clean; worst 2.84 against a 2.6 muted floor |

The floors that were *chosen* rather than inherited, and the reasoning:

- **band height ≥ 14 px.** `ink.gd` fixes the smallest glyph at 10 physical
  pixels (`MIN_PHYS_PX`) and pins the minimum window at 1600 to guarantee it. A
  bar is not a glyph, but the same downscale applies, and a band under about a
  dozen physical pixels stops registering as a *quantity* in peripheral vision
  and starts registering as a *line*. 14 design px is 11.7 at the 1600 floor —
  the same side of the same cliff `MIN_PT` was put on.
- **hierarchy > 0.45.** Not 1.0, and deliberately not: the porthole is dark navy
  glass with a muted bust in it, and the band is saturated ember on near-black,
  so equal areas would not be equal salience. What the ratio has to rule out is
  the *before* case, where identity outweighed life eight to one.
- **gaps ≥ 8–10 px.** Under about eight, the audit's own collision detector is
  the only thing that can tell two bays apart, which is a fair sign the eye
  cannot either.

Three things measured and **not** taken:

- **The life gauge is 30 tall, not 44.** `bar_housing.png` spends about a quarter
  of its height on brass at each edge, so the last 14 px of growth buys 7 px of
  band and 7 px of frame — and the plate has three more things to hold.
- **The plate is 146 tall, not the 168 the design wanted.** The audit caught the
  health bar's own name printed through the opening bid's bottom row at
  1280×720: the bid matrix runs to a fixed y = 600 at every window height, so at
  720 it is the HUD's head that has to give way. The arithmetic is in
  `hud_layout.gd`'s `DEFAULT`; the ceiling is h ≤ 151 and 146 takes it with three
  pixels rather than one. A dedicated status-chip line went with those 22 px,
  which is how the chips ended up on the porthole glass — a better answer anyway.
- **The channel under a gauge's strings is stamped at 0.50**, not `recess`'s 0.55
  or the nameplates' 0.62. At 0.62 the Boilerwright's bar goes dark: his name is
  110 px of a 194 px gauge, so the channel takes most of the band with it and the
  loudest object in the cluster stops being loud. 0.50 composites the ember to
  0.062 luminance, which puts `BRASS_LIT` at 5.6:1 — past the 4.5 floor with a
  margin — and leaves the band plainly a band. Legibility first, and then as much
  of the gauge back as legibility allows.


### What each class gets, without a second layout

The Boilerwright has no dash, and that row has been his three bindings since he
arrived. That stays — one row, two meanings — but it now has a full 210 px bay
instead of the 92 px tail that put `SPC JET` on the bracket. His light gauge
carries `x1.45 DAMAGE` in the value slot where hers carries `41`, which is the
thing his class does and which has never been legible.

---

## 5 · What was considered and rejected

- **A hexagonal portrait.** It is the reference's own mark and it would have
  given the cluster a second silhouette for free. Refused: every corner on this
  ship is square, riveted or bevelled, and a hard-cut hex is the one shape that
  says *sci-fi arena* out loud. A porthole is the airship's answer to the same
  problem and it is already the shape of the art we have.
- **Replacing the dial with a bar.** Cleanest possible readout; also throws away
  the single most characterful object in the HUD. The compromise in §3.4 keeps
  both and gives each one job: the dial says *roughly*, the gauge says *exactly*.
- **A lamp on the cluster.** The menu's lit state is the best thing in
  `MENU-DESIGN.md` and it has no business here. See §3: nothing in the fight HUD
  moves except data, and a HUD that pulses under fire is a HUD competing with the
  fire.
- **Letting the porthole break the plate's top edge.** Visually the best version
  of §4 — the reference's portrait does exactly this. Refused mechanically: HUD
  items are `_clamped` to their plate's interior by `SkyGearHudLayout.item`, and
  routing around that clamp for one element would mean a hand-nudge in F4 could
  push a portrait off its own plate with nothing to catch it. The clamp is worth
  more than the overhang.
- **Growing the plate to 400+.** It clamps to the hand at 1280 anyway
  (`hud_plates` gives the side plates whatever is left), so past ~380 the extra
  width exists only on wide monitors and the layout would be tuned for a size
  half the players do not have.
- **A second row of text explaining the gauge.** The strip right of the dial used
  to be two rows. One row, two facts (name, value) is the whole content, and the
  second row was there because the first one was too small to hold both.
- **A vertical divider between the porthole and the readouts.** Drawn, looked at,
  cut. The auto-attack arc swings out to `seat + 7` and crosses it, and a rule the
  live ring cuts through reads as a mistake rather than as a boundary. The
  porthole's own brass rim does the job, which is what the reference does anyway.
- **A reserved status-chip line under the porthole.** The best version of §3's
  no-reflow rule, and it went with the 22 px the 1280×720 bid collision took off
  the plate. The chips are set into the porthole's lower glass instead, which
  costs no row at all and is arguably better: a chip already carries its own dark
  box and coloured rim, so it does not need a bay to be legible in.

---

## 6 · The art

**The Aether Loom was not running.** `curl http://127.0.0.1:8765/api/config`
refused the connection, and `ASSET-GENERATION.md`'s install path —
`C:/Users/alexr/Documents/Codex/2026-07-26/done-66-images-fully-specced-for` —
does not exist on this machine, so `.\run_aether_loom.ps1` could not be found to
start it either. **Nothing here was faked.** The cluster in §4 is built entirely
from art already in `assets/art/ui/`, exactly as the menu rebuild was, and that
is the point: *a cluster blocked on an art order is a cluster that does not
ship.*

What follows is what the Loom **should** make when it is up, in the house frames
from `tools/forge.py`, in the form `handoff-3d/skyship_transports/PROMPTS.md`
uses. Each is a drop-in improvement to something §4 already draws with an
existing asset — none of them is a blocker.

Every prompt below ends with the `PLATE`, `ICON` or `BAND` frame verbatim from
`tools/forge.py`. **Do not reword the frames; change only the subject line.**

### 6.1 `ui_portrait_boilerwright` → `assets/art/ui/portrait_boilerwright.png`

**The one real bug in this list.** `_draw_game_hud` loads
`portrait_corsair.png` unconditionally, so the Boilerwright wears the Corsair's
face — visible in `.shots/screens/hud-before/playing-the-boilerwright-1920x1080.png`.
The cluster's whole job in §2's question 3 is identity and it is currently
answering it wrong. `forge.py` entry: frame `ICON`-style portrait clause (the
same one `ui_portrait` uses), chroma `#00FF00`, `n=4`, `fill=0.98`, `anchor=0.5`,
batch `ui`.

```
A head-and-shoulders portrait of a steampunk airship boilerwright: a broad
weather-beaten man in his fifties, close-cropped grey beard, a heavy brass
respirator hanging unbuckled at his throat, one smoked-glass goggle lens pushed
up onto a soot-streaked brow, oxblood leather apron over a rolled shirtsleeve,
a faint amber glow on the underside of his jaw from the boiler he is standing
over. Steady, unhurried, unimpressed. Framed from the collarbone up, filling the
canvas.
A head-and-shoulders portrait, read straight on, filling 88% of the square
canvas, centred. No background scene, no frame, no border. Painterly cel
rendering with crisp, slightly irregular near-black ink outlines. Two-source
lighting: steel-blue moon rim from the upper-left and warm amber lantern fill
from the lower-right. Deep indigo, teal, brass, oxblood and warm leather
palette. No photorealism, no 3D render, no flat vector style, no text, no
lettering, no watermark, no motion blur, no extra objects.
```

### 6.2 `ui_porthole` → `assets/art/ui/bezel_porthole.png`

§3.2's ring. Today the porthole's rim is whatever ring is baked into the portrait
art plus four code-drawn rivets. `gauge_ring.png` was tried and removed: it is a
thin *instrument* bezel with graduation marks, which is the wrong object at 84 px
and fights the auto-attack arc for the same rim. A real porthole is heavier, has
its rivets in the casting, and has a dark inner lip that seats the portrait
behind glass. `PLATE` frame — it is furniture with an empty middle — chroma
`#FF00FF`, `n=4`, `fill=1.0`, `anchor=0.5`, batch `ui`.

```
A heavy circular ship's porthole seen straight on, empty: a thick cast brass ring
with eight evenly spaced rivets set into the casting, a narrow dark iron inner
lip inside it, honest verdigris in the recesses and bright wear on the upper
left of the rim. Completely open and transparent through the middle — a frame
only, with no glass, no reflection, no hinge and nothing behind it.
A piece of game-UI furniture from a steampunk airship: brass housing with
visible rivets and honest wear at the corners, dark iron or smoked-glass recess
where a value would be displayed, oxblood leather backing. Read straight on,
orthographic, no perspective, no tilt. Centred and filling 96% of the canvas.
The interior must be EMPTY — no text, no numerals, no icons, no needle, no fill,
no gauge markings inside the recess. No cast shadow, no drop shadow, no
background scene. Painterly cel rendering with crisp, slightly irregular
near-black ink outlines. Two-source lighting: steel-blue moon rim from the
upper-left and warm amber lantern fill from the lower-right. Deep indigo, teal,
brass, oxblood and warm leather palette. No photorealism, no 3D render, no flat
vector style, no text, no lettering, no watermark, no motion blur, no extra
objects.
```

### 6.3 `ui_trough_slim` → `assets/art/ui/bar_housing_slim.png`

§3.3's light gauge is currently code-drawn — a stamped channel and a hard ink
edge — because `bar_housing.png` is authored as a 512×158 chunky trough and
nine-slicing it into an 18 px bar squeezes 26 px of brass corner into four
(`_bar`'s own note). A trough authored *slim*, at about 8:1, would let the light
gauge be painted too. **Lowest priority of the four**: the code-drawn channel is
genuinely good at this size, and the difference between the two gauges being
material rather than merely proportional is a small win.

```
A long slim empty gauge trough from a steampunk airship instrument panel: a
shallow dark iron channel running the full width, framed top and bottom by a
narrow brass rail with a small rivet at each of the four corners and nothing
else along its length. Eight times wider than it is tall. The channel is
completely empty — no fill, no light, no graduations, no numbers.
A piece of game-UI furniture from a steampunk airship: brass housing with
visible rivets and honest wear at the corners, dark iron or smoked-glass recess
where a value would be displayed, oxblood leather backing. Read straight on,
orthographic, no perspective, no tilt. Centred and filling 96% of the canvas.
The interior must be EMPTY — no text, no numerals, no icons, no needle, no fill,
no gauge markings inside the recess. No cast shadow, no drop shadow, no
background scene. Painterly cel rendering with crisp, slightly irregular
near-black ink outlines. Two-source lighting: steel-blue moon rim from the
upper-left and warm amber lantern fill from the lower-right. Deep indigo, teal,
brass, oxblood and warm leather palette. No photorealism, no 3D render, no flat
vector style, no text, no lettering, no watermark, no motion blur, no extra
objects.
```

### 6.4 `ui_band_hot_v2` / `ui_band_cold_v2` — re-forge, at full canvas height

See §7. The existing bands are correct art delivered into a wrong assumption, and
§7 fixes the code rather than the art, so **this is optional.** If they are ever
re-forged, the `BAND` frame's *"fills the canvas edge to edge with no margin"*
clause is the one that was not honoured, and it should be restated in the subject
line as well as the frame:

```
A seamless horizontal band of hot ember light for a game gauge: a bright
white-gold core line low in the band, falling to deep orange above it and to
oxblood at the top and bottom edges, with a fine irregular grain along its
length. It fills the entire canvas from the very top edge to the very bottom
edge with no transparent margin anywhere.
A seamless horizontal band of light for a game gauge, read straight on,
orthographic. It fills the canvas edge to edge with no margin, and it is even
along its whole length so it can be cut at any point. No frame, no housing, no
end caps, no rivets, no text, no markings. Painterly cel rendering with crisp,
slightly irregular near-black ink outlines. Two-source lighting: steel-blue moon
rim from the upper-left and warm amber lantern fill from the lower-right. Deep
indigo, teal, brass, oxblood and warm leather palette. No photorealism, no 3D
render, no flat vector style, no text, no lettering, no watermark, no motion
blur, no extra objects.
```

---

## 7 · The bug this pass found: the health bar has been drawing at a fifth height

`_bar` draws the fill band with

```gdscript
draw_texture_rect_region(fill, filled, Rect2(0, 0, cut, fill.get_height()), ...)
```

— the **whole** 256 px height of `bar_fill_hot.png` stretched into the bar's bed.
But the band is not 256 px tall. Measured off the asset, in both bands:

```
bar_fill_hot .png   256x256   painted rows 102..153   (52 of 256 — 20.3%)
bar_fill_cold.png   256x256   painted rows 102..153
```

Everything above and below is transparent. So a 13.5 px bed received a 2.7 px
band floating in the middle of it with dark bed showing through above and below,
which is precisely what the before frame measures: **a 199 × 2 hairline at
100/100 health**, and the same on the boiler's bar at the top of the screen.

This is the `frame_hud.png` mistake again, and that asset's own note says it:
*"which is what happens when you use an asset for the thing its filename suggests
instead of the thing its pixels are."* The fix is the same fix — name the region:

```gdscript
const BAND_REGION := Rect2(0, 102, 256, 52)
```

Fixed in `_bar`, so it lands on the boiler bar too. That is not scope creep into
the objective plate: it is one asset drawn correctly in the one function that
draws it, and a boiler bar that reads as empty when it is full is the same bug
with a worse consequence.

---

## 8 · What this had to survive, and did

Not negotiable, all green before and after:

- every string through `_say` / `_says`; `ink.gd` owns point size and the
  contrast floors and is never bypassed. Nothing in §4 shrinks a word to fit a
  frame — where a string did not fit, the **bay** grew
- `tools/text_audit.gd` CLEAN at all four widths, 1280 through 2560
- `tests/parity_test.gd` at baseline or better
- the F4 editor and its saved layouts work on every element touched. All seven
  `captain` items keep their keys, so a hand-placed layout still resolves; the
  shipped `assets/hud_layout.json` is updated in step with `hud_layout.gd`'s
  `DEFAULT`, because the shipped file wins and a `DEFAULT` it disagrees with is a
  `DEFAULT` nobody ever sees
- nothing in the top 60 % of the screen. The plate grew downward-anchored: at
  1080 its head is at y = 910 against a 648 line, and at 720 it is 550 against 432
- the cluster allocates nothing per frame and animates nothing

## 9 · If the direction is right, where it goes next

In this order, and **not before the owner has looked at one corner**:

| | | |
|---|---|---|
| 1 | **the captain cluster** | this pass |
| 2 | the hand | §3.3's two gauge weights do not apply; the wells need §3.6's gaps and §3.5's channel, and the four slots are currently one undivided strip |
| 3 | the ship plate | three lane rows of identical weight — the same §2 inversion, one plate over |
| 4 | the objective | last, and least: it is already one question, one plate, and it is the only thing above the line |
