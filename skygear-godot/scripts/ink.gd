class_name SkyGearInk
extends RefCounted

## Text you can read. One file, because three bugs in this port came from two
## functions disagreeing about the same number.
##
## Reported: "we should be able to make written in-game text on skills and cards
## and HUD elements easier while still aesthetically pleasing." That is not a
## layout complaint — `tools/text_audit.gd` already proves every string sits
## inside its frame. It is a LEGIBILITY complaint, and legibility is two numbers:
## how big the glyph is, and how far its colour is from whatever is behind it.
##
## Both numbers live here. `_fits` reads MIN_PT so it can never shrink a label
## into unreadability; `write` reads OUTLINE so every string on the screen is
## separated from its background the same way; `tools/text_audit.gd` reads
## CONTRAST_FLOOR so the check and the renderer cannot drift apart. The old
## arrangement had a floor of 7 in one call site, 8 in another, 9 in the default
## and 11 in a fifth, and the 7 was the one on the skill slots.


## THE SMALLEST TEXT THE GAME IS ALLOWED TO DRAW.
##
## Measured, not chosen. The audit found "draft a weapon" rendering at 7pt in the
## empty skill slots and the Workshop node blurbs at 7-8pt in a 240px column.
## The project renders a 1920x1080 canvas into whatever window it is given, so a
## 10pt glyph in a 1600-wide window is 8.3 physical pixels tall — at that size
## the fallback font's stems are sub-pixel and the whole word reads as a smudge
## of brass. 12 survives the 0.83 downscale with a whole pixel of stem left.
##
## Everything that picks a size clamps to this: `_fits`, and `write` itself, so a
## call site that hard-codes 10 is corrected rather than obeyed. ONE number, not
## a tier list — the tempting design is a floor for body and a lower one for
## hints, and that is exactly the shape of the bug this project keeps having: the
## hint floor quietly becomes the number everyone reaches for.
const MIN_PT := 12

## HOW THE GLYPH IS SEPARATED FROM WHAT IS BEHIND IT.
##
## It was a one-pixel offset drop shadow — `draw_string` at +1,+1 in near-black,
## then the glyph. On a flat panel that is enough. On the painted brass housings
## it is worth almost nothing: the shadow covers the lower-right of each stem and
## leaves the other three sides of every stroke sitting directly on a lit,
## textured, mid-value plate. The audit measured BONE on the captain plate at 2.4
## and the shadow moved it to 2.4, because a shadow on one side is not a
## surround.
##
## A real outline is. Two pixels of the same near-black, all the way round, which
## is what the browser build does and what every HUD on textured art does.
const OUTLINE := 2.0

## The colour of that outline. Not pure black — the palette is warm and a pure
## black halo reads as a sticker cut out and laid on the brass.
const INK := Color(0.035, 0.025, 0.05, 0.94)

## WCAG AA for body text. The audit fails anything under it.
##
## AA rather than AAA because this is a game HUD read at a glance and not a page
## of prose, and because the whole palette is warm brass on dark violet — a 7:1
## floor would force every label to bone white and take the steampunk with it.
const CONTRAST_FLOOR := 4.5

## Text that is SUPPOSED to recede: a disabled Workshop node, a struck-through
## "before" value, an empty slot. Low contrast is the message there, so holding it
## to the body floor would mean drawing "you cannot afford this" as brightly as
## "you can". Still a floor, because invisible is not the message either.
const CONTRAST_FLOOR_MUTED := 2.6

## The colours the game uses to mean "receded". Named here rather than tested for
## at the audit's end, so adding a fifth grey to the palette does not silently
## buy an exemption.
const MUTED := ["#5f5863", "#6a6478", "#6f6878", "#8f8697", "#8b8296"]


## WCAG relative luminance. The sRGB transfer curve matters: linearising the
## channels first is the difference between "brass on dark violet is fine" and
## the truth, which is that it is not.
static func luminance(c: Color) -> float:
	var parts := [c.r, c.g, c.b]
	var lin: Array[float] = []
	for v in parts:
		var f: float = float(v)
		lin.append(f / 12.92 if f <= 0.04045 else pow((f + 0.055) / 1.055, 2.4))
	return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


## The WCAG ratio, 1.0 (identical) to 21.0 (black on white).
static func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## `top` composited onto `under`. Half the HUD's tints carry an alpha — the event
## card fades, the coach line is drawn over the deck — and a contrast figure that
## ignores alpha reports a string that has faded to nothing as perfectly legible.
static func over(top: Color, under: Color) -> Color:
	var a: float = clampf(top.a, 0.0, 1.0)
	return Color(top.r * a + under.r * (1.0 - a), top.g * a + under.g * (1.0 - a),
		top.b * a + under.b * (1.0 - a), 1.0)


## Is this one of the tints that means "receded"?
static func muted(c: Color) -> bool:
	for hex in MUTED:
		if c.to_html(false) == Color(hex).to_html(false):
			return true
	## Anything mostly transparent is receding whether it meant to or not.
	return c.a < 0.55


## The floor this colour has to clear.
static func floor_for(c: Color) -> float:
	return CONTRAST_FLOOR_MUTED if muted(c) else CONTRAST_FLOOR


## The rectangle a string will occupy, given where it was put, how wide a box it
## was handed and how it is aligned. Shared with the containment audit, because a
## right-aligned string at x with width w ends at x + w and begins wherever it is
## long enough to begin — which is not the rectangle it was handed.
static func box(font: Font, text: String, at: Vector2, width: float, align: int,
		pt: int) -> Rect2:
	var measured: float = font.get_string_size(text, align, -1, pt).x
	var left := at.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		left = at.x + (width - measured) * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		left = at.x + width - measured
	return Rect2(left, at.y - pt, minf(measured, width), float(pt) * 1.3)


## EVERY GLYPH IN THE GAME GOES THROUGH HERE.
##
## Outline first, then the fill. `draw_string_outline` asks the font for a real
## stroked contour rather than smearing four offset copies, so a two-pixel halo
## costs one extra draw call instead of eight and does not fatten the letterform.
##
## Returns the box it drew into, so the caller does not measure the string a
## second time and get a different answer.
static func write(canvas: CanvasItem, font: Font, at: Vector2, text: String,
		align: int, width: float, pt: int, tint: Color,
		outline: float = OUTLINE) -> Rect2:
	var size_pt: int = maxi(pt, MIN_PT)
	if outline > 0.0:
		## The halo inherits the text's alpha, or a fading banner keeps a hard
		## black edge after the words it belongs to have gone.
		var halo := Color(INK.r, INK.g, INK.b, INK.a * clampf(tint.a, 0.0, 1.0))
		canvas.draw_string_outline(font, at, text, align, width, size_pt,
			int(round(outline)), halo)
	canvas.draw_string(font, at, text, align, width, size_pt, tint)
	return box(font, text, at, width, align, size_pt)


## The wrapped version. Same contract.
static func write_lines(canvas: CanvasItem, font: Font, at: Vector2, text: String,
		align: int, width: float, pt: int, lines: int, tint: Color,
		outline: float = OUTLINE) -> int:
	var size_pt: int = maxi(pt, MIN_PT)
	if outline > 0.0:
		var halo := Color(INK.r, INK.g, INK.b, INK.a * clampf(tint.a, 0.0, 1.0))
		canvas.draw_multiline_string_outline(font, at, text, align, width, size_pt,
			lines, int(round(outline)), halo)
	canvas.draw_multiline_string(font, at, text, align, width, size_pt, lines, tint)
	return size_pt


## A RECESS UNDER TEXT THAT SITS ON PAINTED BRASS.
##
## The outline fixes the letterform against the plate. It does not fix the other
## half of the problem, which is that the plate art has its own bright rivets and
## scratches running THROUGH the line of text — the eye reads the brass detail as
## part of the word. The browser build puts every HUD readout in a dark inset
## channel for this reason, and the plates are painted expecting one.
##
## Deliberately not a grey box: a soft-cornered darkening of the plate at 0.55,
## which reads as depth in the metal rather than as a label stuck on top of it.
## The brass still shows through — measured at 0.55 it drops a lit rivet from
## 0.42 luminance to 0.19, which is under the tint of every label we draw on it.
static func recess(canvas: CanvasItem, area: Rect2, strength: float = 0.55) -> void:
	var box_r := area.grow(3.0)
	canvas.draw_rect(box_r, Color(0.05, 0.04, 0.075, strength))
	## A one-pixel lip along the top and left, which is what turns a dark
	## rectangle into a hole. Costs two lines and does most of the work.
	canvas.draw_line(box_r.position, Vector2(box_r.end.x, box_r.position.y),
		Color(0.0, 0.0, 0.0, strength * 0.5), 1.0)
	canvas.draw_line(box_r.position, Vector2(box_r.position.x, box_r.end.y),
		Color(0.0, 0.0, 0.0, strength * 0.5), 1.0)
