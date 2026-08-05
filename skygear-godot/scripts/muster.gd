class_name SkyGearMuster
extends RefCounted

## A wave plan is a deal, not live state. Everything in this file is pure:
## authored data in, a deep-owned plan out, and one stream that cannot touch the
## run's gameplay or visual streams.
const MUSTER_SALT := 104729
const GRAMMARS: Array[String] = ["ASSAULT", "PINCER", "SCREEN", "SIEGE"]
const ELIGIBLE_WAVES: Array[int] = [3, 5, 6, 7, 9, 10, 11]
const COSTS := {
	"SWARM": 0.35,
	"SCRAPPER": 1.0,
	"GUNNER": 1.25,
	"ARMORED": 4.0,
}


## Expand authored ALL lanes before any budget or grammar arithmetic. One row
## per lane keeps a lane reassignment literal: changing one row changes one
## authored lane allocation, even when the source originally named all three.
static func normalize(authored_batches: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for source in authored_batches.size():
		var batch: Array = authored_batches[source]
		var lane_spec: Variant = batch[3] if batch.size() > 3 else 1
		var lanes: Array = (
			[0, 1, 2] if lane_spec is String and lane_spec == "all"
			else [int(lane_spec)])
		for lane_value in lanes:
			out.append({
				"time": float(batch[0]),
				"type": str(batch[1]),
				"count": int(batch[2]),
				"lanes": [int(lane_value)],
				"source": source,
			})
	return _canonical(out)


static func plan(seed_text: String, wave_number: int, heat: int,
		normalized_batches: Array[Dictionary], is_event: bool, is_push: bool,
		is_boss: bool, flat: bool = false, forced_grammar: String = "") -> Dictionary:
	var authored := _canonical(normalized_batches)
	var before := budget(authored)
	var fallback := _result(wave_number, "AUTHORED", authored, before, before)
	if flat or wave_number not in ELIGIBLE_WAVES or is_event or is_push or is_boss:
		return fallback

	var stream := RandomNumberGenerator.new()
	stream.seed = hash(seed_text) ^ (wave_number * 2654435761 + MUSTER_SALT)
	var candidates := _candidates(authored, wave_number)
	var by_grammar := {}
	for grammar in GRAMMARS:
		by_grammar[grammar] = []
	for candidate in candidates:
		var after := budget(candidate)
		if absf(after - before) > before * 0.10 + 0.0001:
			continue
		for grammar in GRAMMARS:
			if satisfies(grammar, candidate, wave_number):
				(by_grammar[grammar] as Array).append(candidate)

	var available: Array[String] = []
	var forced := forced_grammar.strip_edges().to_upper()
	if forced != "":
		if forced in GRAMMARS and not (by_grammar[forced] as Array).is_empty():
			available.append(forced)
	else:
		for grammar in GRAMMARS:
			if not (by_grammar[grammar] as Array).is_empty():
				available.append(grammar)
	if available.is_empty():
		return fallback

	var picked_grammar: String = available[stream.randi_range(0, available.size() - 1)]
	var pool: Array = by_grammar[picked_grammar]
	## If this grammar can make a real roster/lane change, do so. An authored
	## roster may already be a valid SIEGE or SCREEN and remains a legitimate
	## sole candidate, but it cannot crowd mutations out of a non-empty pool.
	var changed: Array = []
	var authored_key := _signature(authored)
	for candidate in pool:
		if _signature(candidate) != authored_key:
			changed.append(candidate)
	if not changed.is_empty():
		pool = changed
	var picked: Array[Dictionary] = (pool[stream.randi_range(0, pool.size() - 1)]
		as Array).duplicate(true)
	return _result(wave_number, picked_grammar, picked, before, budget(picked))


static func budget(batches: Array) -> float:
	var total := 0.0
	for batch in batches:
		var kind := str(batch.get("type", ""))
		if not COSTS.has(kind):
			continue
		total += (float(COSTS[kind]) * int(batch.get("count", 0))
			* (batch.get("lanes", []) as Array).size())
	return total


static func satisfies(grammar: String, batches: Array, wave_number: int) -> bool:
	var lanes := [0.0, 0.0, 0.0]
	var gunners := [0.0, 0.0, 0.0]
	var melee := [0.0, 0.0, 0.0]
	var armored := 0
	var light_support := 0
	for batch in batches:
		var kind := str(batch.get("type", ""))
		if kind == "BOSS" or not COSTS.has(kind):
			continue
		var count := int(batch.get("count", 0))
		var threat := float(COSTS[kind]) * count
		for lane_value in batch.get("lanes", []):
			var lane := int(lane_value)
			if lane < 0 or lane > 2:
				continue
			lanes[lane] += threat
			if kind == "GUNNER":
				gunners[lane] += threat
			else:
				melee[lane] += threat
		if kind == "ARMORED":
			armored += count * (batch.get("lanes", []) as Array).size()
		else:
			light_support += count * (batch.get("lanes", []) as Array).size()
	var total: float = lanes[0] + lanes[1] + lanes[2]
	if total <= 0.0:
		return false
	match grammar:
		"ASSAULT":
			return maxf(lanes[0], maxf(lanes[1], lanes[2])) >= total * 0.60 - 0.0001
		"PINCER":
			return (lanes[0] >= total * 0.35 - 0.0001
				and lanes[2] >= total * 0.35 - 0.0001
				and lanes[1] <= total * 0.30 + 0.0001)
		"SCREEN":
			for lane in 3:
				if gunners[lane] > 0.0 and melee[lane] >= gunners[lane] * 2.0 - 0.0001:
					return true
			return false
		"SIEGE":
			return wave_number >= 5 and armored == 1 and light_support > 0
	return false


static func _result(wave_number: int, grammar: String, batches: Array[Dictionary],
		before: float, after: float) -> Dictionary:
	return {
		"wave": wave_number,
		"grammar": grammar,
		"batches": batches.duplicate(true),
		"budget_before": before,
		"budget_after": after,
	}


## The finite list is deliberately not an optimizer. Each grammar contributes a
## fixed recipe: two largest whole rows toward an ASSAULT lane, two centre rows
## outward for PINCER, two largest melee rows onto each Gunner's SCREEN lane,
## and the substitution rows below. Every intermediate (one move and two moves)
## is a candidate; the shared budget and postcondition filter decides whether
## it survives.
static func _candidates(authored: Array[Dictionary], wave_number: int) -> Array[Array]:
	var collected: Array[Array] = [authored.duplicate(true)]
	for target_lane in 3:
		var assault: Array[Dictionary] = authored.duplicate(true)
		for _move in 2:
			var index := _largest_row_outside(assault, target_lane, false)
			if index < 0:
				break
			assault[index].lanes = [target_lane]
			assault = _canonical(assault)
			collected.append(assault)

	var pincer: Array[Dictionary] = authored.duplicate(true)
	for _move in 2:
		var index := _largest_row_in_lane(pincer, 1, false)
		if index < 0:
			break
		var lane_threat := _lane_threat(pincer)
		var target_lane := 0 if float(lane_threat[0]) <= float(lane_threat[2]) else 2
		pincer[index].lanes = [target_lane]
		pincer = _canonical(pincer)
		collected.append(pincer)

	for gunner in authored:
		if str(gunner.type) != "GUNNER":
			continue
		var screen_lane := int((gunner.lanes as Array)[0])
		var screen: Array[Dictionary] = authored.duplicate(true)
		for _move in 2:
			var index := _largest_row_outside(screen, screen_lane, true)
			if index < 0:
				break
			screen[index].lanes = [screen_lane]
			screen = _canonical(screen)
			collected.append(screen)

	var type_first := _type_moves(authored, wave_number)
	for candidate in type_first:
		collected.append(candidate)
	## Two Armored-to-Scrapper substitutions are the only two-step type recipe
	## needed by the initial grammar set: they can reduce a multi-anchor wave to
	## SIEGE's exactly one. Other rows still enter as every legal one-step form.
	if wave_number >= 5:
		var siege: Array[Dictionary] = authored.duplicate(true)
		for _move in 2:
			var index := _first_kind(siege, "ARMORED")
			if index < 0:
				break
			siege = _replace(siege, index, 1, [{"type": "SCRAPPER", "count": 4}])
			collected.append(siege)
	return _unique(collected)


static func _largest_row_outside(batches: Array[Dictionary], lane: int,
		melee_only: bool) -> int:
	var best := -1
	var best_threat := -1.0
	for i in batches.size():
		var row: Dictionary = batches[i]
		var kind := str(row.type)
		if int((row.lanes as Array)[0]) == lane or kind == "BOSS":
			continue
		if melee_only and (kind == "GUNNER" or not COSTS.has(kind)):
			continue
		var threat := _row_threat(row)
		if threat > best_threat:
			best = i
			best_threat = threat
	return best


static func _largest_row_in_lane(batches: Array[Dictionary], lane: int,
		melee_only: bool) -> int:
	var best := -1
	var best_threat := -1.0
	for i in batches.size():
		var row: Dictionary = batches[i]
		var kind := str(row.type)
		if int((row.lanes as Array)[0]) != lane or kind == "BOSS":
			continue
		if melee_only and (kind == "GUNNER" or not COSTS.has(kind)):
			continue
		var threat := _row_threat(row)
		if threat > best_threat:
			best = i
			best_threat = threat
	return best


static func _row_threat(row: Dictionary) -> float:
	var kind := str(row.type)
	return (float(COSTS.get(kind, 0.0)) * int(row.count)
		* (row.lanes as Array).size())


static func _lane_threat(batches: Array[Dictionary]) -> Array[float]:
	var out: Array[float] = [0.0, 0.0, 0.0]
	for row in batches:
		var threat := _row_threat(row)
		for lane_value in row.lanes:
			out[int(lane_value)] += threat
	return out


static func _first_kind(batches: Array[Dictionary], kind: String) -> int:
	for i in batches.size():
		if str(batches[i].type) == kind and int(batches[i].count) > 0:
			return i
	return -1


static func _type_moves(batches: Array[Dictionary], wave_number: int) -> Array[Array]:
	var out: Array[Array] = []
	for i in batches.size():
		var kind := str(batches[i].type)
		var count := int(batches[i].count)
		if kind == "SCRAPPER" and count >= 1:
			out.append(_replace(batches, i, 1, [{"type": "SWARM", "count": 3}]))
		if kind == "SWARM" and count >= 3:
			out.append(_replace(batches, i, 3, [{"type": "SCRAPPER", "count": 1}]))
		if kind == "GUNNER" and count >= 1:
			out.append(_replace(batches, i, 1, [
				{"type": "SCRAPPER", "count": 1},
				{"type": "SWARM", "count": 1},
			]))
		if wave_number >= 5 and kind == "SCRAPPER" and count >= 4:
			out.append(_replace(batches, i, 4, [{"type": "ARMORED", "count": 1}]))
		if wave_number >= 5 and kind == "ARMORED" and count >= 1:
			out.append(_replace(batches, i, 1, [{"type": "SCRAPPER", "count": 4}]))
	## Reverse of Gunner <-> Scrapper + Swarm. Both bodies must share the same
	## authored time/source/lane, so a substitution never moves a spawn in time.
	for i in batches.size():
		if str(batches[i].type) != "SCRAPPER" or int(batches[i].count) < 1:
			continue
		for j in batches.size():
			if str(batches[j].type) != "SWARM" or int(batches[j].count) < 1:
				continue
			if not _same_slot(batches[i], batches[j]):
				continue
			var joined: Array[Dictionary] = batches.duplicate(true)
			joined[i].count = int(joined[i].count) - 1
			joined[j].count = int(joined[j].count) - 1
			var add := _row_like(batches[i], "GUNNER", 1)
			joined.append(add)
			out.append(_canonical(joined))
	return _unique(out)


static func _replace(batches: Array[Dictionary], index: int, remove_count: int,
		additions: Array[Dictionary]) -> Array[Dictionary]:
	var changed: Array[Dictionary] = batches.duplicate(true)
	changed[index].count = int(changed[index].count) - remove_count
	for addition in additions:
		changed.append(_row_like(batches[index], str(addition.type), int(addition.count)))
	return _canonical(changed)


static func _row_like(row: Dictionary, kind: String, count: int) -> Dictionary:
	return {
		"time": float(row.time),
		"type": kind,
		"count": count,
		"lanes": (row.lanes as Array).duplicate(),
		"source": int(row.source),
	}


static func _same_slot(a: Dictionary, b: Dictionary) -> bool:
	return (float(a.time) == float(b.time) and int(a.source) == int(b.source)
		and var_to_str(a.lanes) == var_to_str(b.lanes))


static func _canonical(batches: Array) -> Array[Dictionary]:
	var merged := {}
	for untyped in batches:
		var batch: Dictionary = untyped
		var count := int(batch.get("count", 0))
		if count <= 0:
			continue
		var lanes: Array = (batch.get("lanes", []) as Array).duplicate()
		lanes.sort()
		var key := "%d|%.6f|%s|%s" % [
			int(batch.get("source", 0)), float(batch.get("time", 0.0)),
			str(batch.get("type", "")), var_to_str(lanes)]
		if merged.has(key):
			merged[key].count = int(merged[key].count) + count
		else:
			merged[key] = {
				"time": float(batch.get("time", 0.0)),
				"type": str(batch.get("type", "")),
				"count": count,
				"lanes": lanes,
				"source": int(batch.get("source", 0)),
			}
	var out: Array[Dictionary] = []
	for row in merged.values():
		out.append(row)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.source) != int(b.source):
			return int(a.source) < int(b.source)
		var lane_a := int((a.lanes as Array)[0])
		var lane_b := int((b.lanes as Array)[0])
		if lane_a != lane_b:
			return lane_a < lane_b
		return str(a.type) < str(b.type))
	return out


static func _signature(batches: Array) -> String:
	return var_to_str(_canonical(batches))


static func _unique(candidates: Array) -> Array[Array]:
	var seen := {}
	var out: Array[Array] = []
	for candidate in candidates:
		var canonical := _canonical(candidate)
		var key := _signature(canonical)
		if seen.has(key):
			continue
		seen[key] = true
		out.append(canonical)
	return out
