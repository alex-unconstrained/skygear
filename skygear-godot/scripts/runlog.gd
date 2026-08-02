class_name SkyGearRunLog
extends RefCounted

## Every run this machine has finished, kept on disk.
##
## The port could produce a run report and then throw it away the moment you
## pressed Enter. That is the one thing a roguelike must not do: the whole reason
## v11 tracks damage per skill, casts per skill and time at each range is so a
## player — and a designer reading a tester's folder — can look at ten runs and
## see a shape. One run in isolation is an anecdote.
##
## Deliberately small and boring: a JSON array of flat dictionaries, newest last,
## capped. No schema versioning, because a field this project stops writing is a
## field this reader simply will not find, and `get()` with a default handles it.
##
## Storage can fail. A locked profile, a read-only drive, a sandbox — the browser
## build has a check for exactly this because a game that crashes when it cannot
## write a leaderboard entry is a game that crashes. Every method here is total.

const PATH := "user://runs.json"
const KEEP := 60


static func load_all() -> Array:
	if not FileAccess.file_exists(PATH):
		return []
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Array:
		return parsed
	return []


## Append one run. Returns whether it reached the disk, so a caller that cares
## can say so — and the harness can assert the failure path without a real
## read-only drive.
static func record(entry: Dictionary) -> bool:
	var all := load_all()
	all.append(entry)
	while all.size() > KEEP:
		all.remove_at(0)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(all))
	f.close()
	return true


static func clear() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("[]")
		f.close()


## What the title screen shows: runs, best wave reached, and whether the deck has
## ever been held. Three numbers, because a title screen that lists sixty runs is
## a spreadsheet.
static func summary() -> Dictionary:
	var all := load_all()
	var best := 0
	var best_heat := 0
	var wins := 0
	var best_time := ""
	for row in all:
		if row is not Dictionary:
			continue
		var row_wave := int(row.get("wave", 0))
		## The heat the best wave was reached AT — the row's own, never a max
		## across rows, because "best wave 12 (Heat 3)" must be one run's feat.
		## Per-key fallback: a row written before `heat` existed reads as 0, the
		## only heat it could have been played at.
		if row_wave > best or (row_wave == best and int(row.get("heat", 0)) > best_heat):
			best_heat = int(row.get("heat", 0))
		best = maxi(best, row_wave)
		if bool(row.get("won", false)):
			wins += 1
			if best_time == "" or str(row.get("time", "")) < best_time:
				best_time = str(row.get("time", ""))
	return {"runs": all.size(), "best_wave": best, "wins": wins,
		"best_time": best_time, "best_heat": best_heat}
