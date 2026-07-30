class_name SkyGearProfiler
extends Node

## What the frame actually costs, and what is in it.
##
## The port has never been profiled. Every performance conversation on this
## project so far has been conducted without a number: a tester reported lag and
## blamed the lightning, the browser build was measured and the lightning turned
## out to be innocent — it was an uncapped effect list and a leaked audio node.
## That took a day to find because nothing was counting.
##
## So this counts, all the time, and costs almost nothing to leave on:
##
##   * **Frame time** as a rolling window, with the 1% worst kept separately.
##     An average frame time hides exactly the thing players notice. A stutter
##     is a 99th percentile problem and an average will never show it.
##   * **What is on the deck** — draw calls, live particles, decals, billboards,
##     pooled nodes — because "it got slow" is not a bug report and "it got slow
##     at 340 decals" is.
##   * **The renderer and driver**, since Forward+ can be Vulkan or D3D12 and
##     the two do not perform alike.
##
## F3 shows it. `--headless --script tests/bench.gd` runs it without a person.

const WINDOW := 240                  ## frames kept, four seconds at sixty
const SPIKE_THRESHOLD_MS := 33.4     ## anything over two frames at 60 is a spike

var frames: PackedFloat32Array = PackedFloat32Array()
var spikes := 0
var worst_ms := 0.0
var _at := 0
var _elapsed := 0.0


func _ready() -> void:
	frames.resize(WINDOW)
	frames.fill(0.0)


func _process(delta: float) -> void:
	var ms := delta * 1000.0
	frames[_at] = ms
	_at = (_at + 1) % WINDOW
	_elapsed += delta
	worst_ms = maxf(worst_ms, ms)
	if ms > SPIKE_THRESHOLD_MS:
		spikes += 1


## Average, median and the 99th percentile of the window.
##
## The 99th is the one that matters. A build that runs at a beautiful 4 ms
## average and hitches to 40 twice a second is a build people call laggy, and
## the average says it is four times faster than it needs to be.
func timings() -> Dictionary:
	var live: Array[float] = []
	for value in frames:
		if value > 0.0:
			live.append(value)
	if live.is_empty():
		return {"avg": 0.0, "median": 0.0, "p99": 0.0, "fps": 0.0, "samples": 0}
	live.sort()
	var total := 0.0
	for value in live:
		total += value
	var avg: float = total / float(live.size())
	return {
		"avg": avg,
		"median": live[live.size() / 2],
		"p99": live[mini(live.size() - 1, int(float(live.size()) * 0.99))],
		"fps": 1000.0 / maxf(0.001, avg),
		"samples": live.size(),
	}


## What is currently on the deck, from the renderer rather than from our own
## bookkeeping — our bookkeeping is what would be wrong if there were a leak.
static func scene_counts(view: SkyGearView3D) -> Dictionary:
	var out := {
		"draw_calls": RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"video_mem": RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),
		"objects": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
	}
	if view != null:
		out["decals"] = view._decals.size()
		out["decals_free"] = view._free_decals.size()
		out["billboards"] = view._billboards.size()
		out["billboards_free"] = view._free_billboards.size()
		out["rigs"] = view._rigs.size()
		out["emitters"] = view._sparks.size()
	return out


## One block of text for F3, a bug report, or the run log. Deliberately the same
## text in all three, so a number a tester quotes is a number that can be looked
## up rather than re-derived.
func report(view: SkyGearView3D, game: SkyGearGame) -> String:
	var t := timings()
	var c := scene_counts(view)
	var lines: Array[String] = []
	lines.append("%s   %.1f fps   avg %.2f  median %.2f  p99 %.2f ms"
		% [SkyGearRendererCheck.describe(), float(t.fps), float(t.avg),
			float(t.median), float(t.p99)])
	lines.append("spikes over %.0f ms: %d in %.0fs   worst %.1f ms"
		% [SPIKE_THRESHOLD_MS, spikes, _elapsed, worst_ms])
	lines.append("draws %d   prims %s   vram %.0f MB   nodes %d"
		% [int(c.draw_calls), _thousands(int(c.primitives)),
			float(c.video_mem) / 1048576.0, int(c.objects)])
	if view != null:
		lines.append("decals %d (+%d free)   billboards %d (+%d free)   rigs %d"
			% [int(c.decals), int(c.decals_free), int(c.billboards),
				int(c.billboards_free), int(c.rigs)])
	if game != null:
		lines.append("boarders %d   effects %d   bolts %d   floaters %d   wave %d"
			% [game.enemy_count(), game.effects.size(), game.projectiles.size(),
				game.floaters.size(), game.wave])
	return "\n".join(lines)


static func _thousands(value: int) -> String:
	var text := str(value)
	var out := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out


func reset() -> void:
	frames.fill(0.0)
	spikes = 0
	worst_ms = 0.0
	_elapsed = 0.0
	_at = 0
