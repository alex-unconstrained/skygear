# RNG and save findings

- G3 used one observation from each distinct `BAL1`…`BAL120` seed. BAL1/BAL2 repeats audit determinism only and contribute zero effective observations.
- Both G3 arms receive exactly one authored Field hit through matched boarders. Gameplay RNG, visual RNG, aggregate affected HP, pressure, player HP, control HP, passive timer, floater count, and effect count are identical between arms.
- The only intended physical difference is which in-scope boarder receives the 4.0 Field tick: the left-behind target under the candidate and the captain-side matched target under feature-off live follow.
- `make_skill()` adds runtime-only `Vector2`/boolean fields. No save schema or workshop data is read or written by the feature.
- Harness scratch stores remained isolated; final harness reports zero script errors and the pinned 56 engine errors.

