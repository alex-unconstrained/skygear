class_name SkyGearRendererCheck
extends RefCounted

## What renderer and driver are we actually on, and does the game work there?
##
## The design document claimed "Forward+ (Vulkan)". **The renderer and the
## driver are separate settings** — Forward+ runs over Vulkan *or* Direct3D 12 on
## Windows, and the project never selected one, so that claim was an assumption
## rather than a fact. On this machine it happens to be Vulkan. On a machine with
## a different driver situation it may not be.
##
## The reason this matters is not tidiness. **Compatibility does not support
## `Decal`**, and every gameplay telegraph in this game is a Decal: the enemy
## windup rune, the aura edge, the mortar ring, the contact shadows. A player
## dropped to Compatibility does not get a slightly worse-looking game, they get
## a game with the tells missing and no indication that anything is wrong.
##
## So: report it, and if the renderer cannot draw the telegraphs, say so out loud
## rather than letting someone lose a run to an invisible windup.

const SUPPORTS_DECALS := ["forward_plus", "mobile"]


static func method() -> String:
	return RenderingServer.get_current_rendering_method()


static func driver() -> String:
	return RenderingServer.get_current_rendering_driver_name()


## Can this renderer draw the things the fight is read from?
static func can_draw_telegraphs() -> bool:
	return method() in SUPPORTS_DECALS


## One line for the boot log and the run report, so a bug report from a tester
## carries the renderer it happened on. Every previous performance complaint on
## this project was diagnosed without knowing that.
static func describe() -> String:
	return "%s / %s%s" % [method(), driver(),
		"" if can_draw_telegraphs() else "  (NO DECAL SUPPORT)"]


## Can a frame be read back off the GPU at all?
##
## Under `--headless` the answer is NO, by engine design, not by bug — measured
## for SG-29 on this machine (Godot 4.7.1, RTX 5080): the headless display
## server creates NO rendering device (`RenderingServer.get_rendering_device()`
## is null, the adapter name is empty), so no viewport is ever drawn.
## `get_image()` does not even hang — it returns null instantly. The hang every
## capture tool actually hit is `await RenderingServer.frame_post_draw`: the
## headless main loop skips the draw step, so that signal never fires and the
## await never resolves. `force_draw()` emits the signal but paints nothing,
## `--rendering-driver vulkan` is ignored under `--headless`, and
## `--write-movie` headless produces zero frames and an empty .wav. Upstream:
## godotengine/godot-proposals#5790 (off-screen rendering), still open.
##
## So a tool that needs pixels asks this FIRST and refuses loudly, instead of
## stalling silently until someone kills it 20 minutes later.
static func can_capture() -> bool:
	return DisplayServer.get_name() != "headless"


## The one-line refusal, same text everywhere so it is searchable.
static func capture_refusal() -> String:
	return ("no GPU under --headless: frames cannot be rendered or read back "
		+ "(no rendering device exists — SG-29). Re-run WITHOUT --headless.")


## What to tell the player, or "" when there is nothing to tell them.
static func warning() -> String:
	if can_draw_telegraphs():
		return ""
	return ("This renderer (%s) cannot draw the deck markings.\n"
		+ "Enemy windups, ability ranges and shadows will be missing.\n"
		+ "Launch with --rendering-method forward_plus for the real game.") % method()
