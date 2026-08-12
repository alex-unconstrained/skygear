# RNG and save findings

- G3 used one observation from each distinct `PULSE1`…`PULSE120` seed. PULSE1/PULSE2 repeats audit determinism only and contribute zero effective observations.
- Both paired arms perform the identical accepted Lance cast, which deals zero active damage. The feature-off evidence seam restores only the 0.35 timer subtraction that the serialized SG-206 baseline did not perform.
- The candidate Pulse hits the three-figure crossing group for 102.0 total. That group leaves before the feature-off scheduler becomes due; a matched three-figure group then enters and receives the same three production Pulse hits. Aggregate HP, control HP, pressure, player HP, Pulse attribution, hit count, cast count, effect/floater count, gameplay RNG, and visual RNG are identical in all 120 pairs.
- The intended physical differences are the Pulse time and which matched group receives the unchanged 34.0-per-target discharge. No unrelated fingerprint differs.
- Production adds no RNG draw. `cast_advance` is static skill data and `passive_timer` remains runtime-only; no save/workshop schema or migration changes.
- The shared-advance deletion negative failed exactly six Pulse advance/timing checks and no unrelated checks. The mutation was restored before the final run.
- Harness scratch stores remained isolated; the restored final harness is 1,187/1,187 with zero script errors and the pinned 56 engine errors.
