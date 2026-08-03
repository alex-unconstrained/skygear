# The menus, and why only the header belongs to the ship

**The owner's ask, 2026-08-02, with a screenshot of the title screen:** *"I want
another agent investigating how we can get a more interesting and dynamic
looking menu system. Right now the header UI element feels on-theme but the rest
are just simple text boxes."*

He is describing one screen and one split, and both are real. This document is
the survey, the vocabulary that came out of it, and the order to build it in.
The title screen is built to it (board SG-91); everything else is a row.

---

## 1. What the split actually is

Open `.shots/sg91/title-1920x1080-before.png` and cover the top fifth. What is
left is a stack of rectangles.

The SKYGEAR header is `assets/art/ui/frame_hud.png`, drawn through `_banner` as
a 391x117 painted region stretched 600 wide. One `draw_texture_rect_region`
call, and it carries:

| | |
|---|---|
| **material** | painted brass with grain, scratches and a verdigris field |
| **depth** | a lit bevel along the top, a shadow along the bottom — a solid lit from above |
| **ironwork** | two corner brackets and fourteen rivets: it is *bolted to something* |
| **weight** | its frame is thick relative to its content — it is furniture, not a border |

Everything below it is `SkyGearUI.button`, which is **two shape calls**:

```gdscript
_canvas.draw_rect(rect, fill)                       # a flat tint
_canvas.draw_rect(rect, edge, false, 1.4)           # a hairline
```

That is the whole object. No material, no bevel, no fastener, and its state is
carried entirely by swapping two colours and a border from 1.4px to 2.0px. There
are **fourteen** of them on the fullest title (five Heat rungs, WHO IS ABOARD,
COMPARE THE TWO, THE WORKSHOP, THE BERTHS, BEGIN RUN, HOW TO PLAY, SETTINGS,
CONTROLS, QUIT). Fourteen identical hairline rectangles with centred text is the
visual grammar of a preferences dialog, and the eye is right to read it that way.

Three further things the screenshot shows that nobody filed:

- **The column is ragged.** COMPARE THE TWO is 480 wide; everything under it is
  300. Two widths, no rule, so the block has no edge to read down.
- **BEGIN RUN is not the door.** It differs from QUIT by six pixels of height
  and a hue. The most important control on the screen and the most destructive
  one are the same object in two colours.
- **The menu floats.** It has no ground. The header is bolted to the sheet in its
  own art; the fourteen rectangles are bolted to nothing and sit directly on the
  planking, which is why the screen reads as an overlay rather than as part of
  the ship.

**This is not a legibility problem and must not be solved as one.**
`tools/text_audit.gd` reports CONTAINMENT and LEGIBILITY clean at all four
widths on every title pose, and it was clean before this pass and has to be
clean after. Nothing here buys a prettier box by shrinking a word;
`scripts/ink.gd` keeps the point size and the contrast floors and is never
routed around.

---

## 2. The game already owns the answer

Nothing below needs new art. Every idiom named here is already drawn somewhere
in this build, which is the reason to reach for it — a menu vocabulary invented
from scratch would be a fifth visual language in a game that already has four.

**The Workshop (board SG a-81xx) is the precedent, and the owner liked it.** Its
header note is the brief for this pass: *"the Workshop is a board with pipes on
it, not a list of rows."* It is a brass sheet with the banner riveted into its
head, a ledger strip, and columns of fittings with pipework running down them —
`_pipe`, `_collar`, `_valve`, `_rivets`, `_fitting`, `_seal`, `_branch_glyph` in
`scripts/hud.gd`. Look at `.shots/sg91/the-workshop-1920x1080.png` beside the
title and the two screens plainly do not come from the same game.

| already built | what it lends a menu |
|---|---|
| `_panel` / `_nine` + `plate_wide.png` | a nine-sliced painted brass sheet at any size, rivets unsmeared |
| `_banner` + `frame_hud.png` | the crown — the one element the owner already likes |
| `_fitting` | a dark field, a state-coloured rim, an inner glow once it is yours, rivets in the edge |
| `_rivets` | rank as fasteners, and **unfilled ones drawn as empty holes** rather than omitted |
| `_padlock` | locked, as hardware |
| `_valve` | a shut gate that reads shut *by its shape*, not only by its colour |
| `_seal` | the Articles' wax — proof this palette can carry a second material |
| `_card_frame` / `_emblem` (SG-35) | a slim rail, corner rivets, and a lit anchor the eye lands on |
| the Heat ladder (SG-14) | five rungs whose cleared / next / locked / selected states already render distinctly |
| `SkyGearInk.recess` | **a dark channel stamped into the plate under text** — the engraving |

`recess` is the load-bearing one and it is worth being explicit about why. Its
own header says it exists because *"the plate art has its own bright rivets and
scratches running THROUGH the line of text."* That is the exact hazard a
material menu creates: the moment a button stops being a flat tint, its label is
standing on texture. The channel is what makes lettering on brass legible, and
it is also, conveniently, what makes a label look **engraved** rather than
printed.

---

## 3. The vocabulary

A menu in this game is **hardware bolted to the ship**. Seven nouns.

### 3.1 The board
The ground a menu stands on. A dark iron field with a brass edge, rivets down
its stiles and a bracket at each corner, with the banner riveted into its head
exactly as the Workshop rivets its own. Not the 48px `_panel` nine-slice — that
frame is right for a full screen and eats a hundred pixels of a column — but the
same object one weight lighter.

**The board is the single biggest change and the cheapest.** It is what stops
the menu floating on the planking, and it is why the header currently looks like
it comes from a different game: the header is bolted to something and nothing
else is.

### 3.2 The plate
Every menu item. Five layers, in this order, and the order is the whole trick:

1. a shadow beneath it, so it sits *on* the board rather than *in* it
2. a dark stamped field
3. **a bevel** — a light stroke along the top and left inner edge, a dark one
   along the bottom and right. Two lines. This is the difference between a solid
   and an outline, and it costs nothing
4. a brass surround, and **two rivets in each short end**
5. **the engraved channel** — `SkyGearInk.recess` — and the label in it

### 3.3 The lamp
The lit state: hovered, or holding the keyboard focus. **Not a tint.** The lamp
above the plate comes on: a warm wash falls down the plate from its top edge,
the bevel brightens, the brass surround goes to `BRASS_LIT`, the rivets catch a
highlight, and the shadow beneath deepens so the plate reads as *raised*.

A lamp in this game flickers — the fire fields do it at
`0.82 + 0.12 * sin(t * 0.012 + seed)` (`game.gd:4589`), and the deck is lit by
things that burn. The menu may breathe with it.

> **THE RULE THAT MAKES THE FLICKER SAFE.** The engraved channel is stamped
> **after every light**, and the flicker is allowed to touch only the bevel, the
> rivets and the glow *outside* the channel — never the pixels a word stands on.
> This is not decoration policy, it is what keeps the audit honest: the
> legibility pass renders each screen twice, once normally and once with
> `hud.hide_text`, and samples the second frame under each string's box. A lamp
> that flickered *under the label* would make the two frames disagree and the
> contrast figure would be noise. Nothing under a glyph moves.

### 3.4 The door
`BEGIN RUN` is not a menu item. It is the way out onto the deck, and it should be
obviously that: taller, its own ironwork borrowed from the banner's corners, teal
where the column is brass, and **its lamp is always lit** — the door is never
dark. Hierarchy is the ask's third bullet and this is the whole of it.

### 3.5 Cold iron, and the padlock
Locked is a **material**, not an opacity. Cold iron-violet where the brass would
be (`FIT_RIM[0]`, `#4a4356`, already the Workshop's LOCKED metal), rivets drawn
as **empty holes** rather than filled ones, and `_padlock` on the plate. The
label stays legible — `CONTRAST_FLOOR_MUTED` is 2.6, not zero, and *"invisible
is not the message either."*

A locked plate is **hoverable**, states its unlock rule, and refuses the click
through a gate rather than through `disabled` — the Heat ladder's own rule,
because *"a disabled widget refuses the hover and the unlock rule would go
silent over exactly the rungs a player most wants to read."*

> **AND "SHOW EVERYTHING LOCKED" IS REFUSED HERE, DELIBERATELY.** The obvious
> next move — stop hiding THE WORKSHOP and THE BERTHS before the first victory
> and show them as cold iron instead — is a direct violation of
> `scripts/workshop.gd`'s first hard constraint: *"NONE OF THIS EXISTS UNTIL YOU
> HAVE WON. **Not unlocked, not shown, not earned.**"* That rule is load-bearing
> — it is what *"structurally forecloses the Rogue Legacy failure, because you
> cannot be behind a curve that has not started"* — and it is worth more than a
> fuller-looking title screen. This pass drafted the change, found the rule, and
> dropped it. The locked hardware on the title is therefore the Heat ladder's
> rungs, which is where it belongs: they are locked by something you can see how
> to unlock.

### 3.6 The hatch
`QUIT` is not part of the column. It leaves the board entirely, sits below its
foot, and is small and iron. A destructive control that looks exactly like
SETTINGS is a misclick waiting to happen, and the fix is that it should not be
made of the same stuff.

### 3.7 The rungs
`DIFFICULTY` is already a ladder in behaviour (SG-14) and a row of chips in
appearance. Make the appearance agree: a brass rail with iron rungs bolted
across it, end rivets on every rung, cleared rungs lit and filled, the next one
teal, locked ones cold with a padlock, and the selected one **seated** — its
bevel inverted, so it reads as pressed in rather than merely tinted.

---

## 4. What was considered and rejected

- **A two-column board.** More interesting on paper; wrong for a keyboard menu.
  `SkyGearUI` focus is a flat list in declaration order, so Up/Down across two
  columns steps in an order the eye cannot predict. The screen also has a
  standing rule against multi-anchor layout — *"ONE CURSOR DOWN THE PAGE, not
  six offsets from a shared anchor"* — written after adding the Heat picker put
  three overlapping widgets on this exact screen and every check passed. The
  interest comes from material and light, not from scattering the controls.
- **Rounded corners.** Nothing on this ship is rounded. The rounding is part of
  why the current buttons read as a web form.
- **A hover animation that moves the plate.** The rectangle input is tested
  against is last frame's (`SkyGearUI.begin`), deliberately, so a click cannot
  land on a button that moved. A plate that slides under the cursor would fight
  that. It brightens and raises; its rectangle never moves.
- **New art.** Every idiom in §3 is drawable with the primitives already in
  `hud.gd`. A menu blocked on an art order is a menu that does not ship.

---

## 5. The order to build it in

| | | |
|---|---|---|
| 1 | **the vocabulary + the title screen** | SG-91 — **BUILT.** `_menu_board`, `_menu_plate`, `_menu_rung` in `hud.gd`, and `_draw_title` rebuilt on them |
| 2 | SETTINGS, HOW TO PLAY, CONTROLS | cheap once §3 exists — they are already `ui.row` / `ui.button` columns on a `_sheet`, so it is a call swap per row |
| 3 | PAUSE | the same four buttons as the title's tail; same swap |
| 4 | the run report (GAMEOVER / VICTORY) | its own furniture; judge after 2 and 3 land |

**Not the fight HUD.** It is a different job with different rules — it is read at
a glance under attack, it is the F4 plate editor's domain rather than the screen
editor's, and its housings are already painted art. Nothing here applies to it.

## 6. What any of this has to survive

Not negotiable, and all four were green before the pass and are green after:

- every string goes through `_say` / `_says`; `ink.gd` owns point size and the
  contrast floors, and is never bypassed
- `tools/text_audit.gd` CLEAN at all four widths — no shrinking text to fit a
  prettier box
- the F4 editor and its saved layouts work on every element touched. A `bare`
  widget must be routed through `_widget_adjust` **by its caller**, or the saved
  offset moves the hit target and leaves the art behind — which is what the Heat
  ladder was doing before this pass (§7)
- keyboard and mouse both work, focus stays visible, nothing needs a key a
  laptop lacks
- animation allocates nothing per frame and is bounded

## 7. One bug this survey found

**The Heat ladder's art did not move with its own widget.** `_draw_heat_ladder`
declares each rung as `ui.button(box, "", {"bare": true})` and then draws with
`box` — the rectangle *before* `SkyGearUI._adjusted` applied any saved F4 offset.
`ui.button` adjusts the rect it declares and hit-tests, so a nudged rung moved
its click target and left its painted rung behind. Nothing caught it because the
shipped `assets/hud_layout.json` has no `title` entries at all, so the offset
that would expose it is always zero.

Filed and fixed with this pass: a `bare` widget is adjusted by its caller through
`_widget_adjust` and drawn into what comes back, with `{"adjusted": true}` so the
widget layer does not adjust it twice.
