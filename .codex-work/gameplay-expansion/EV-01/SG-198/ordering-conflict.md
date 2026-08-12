# SG-199 ordering-contract conflict

Full harness after implementation: 1142/1143.

Remaining red check:

`tempo · STEADY deals today's queue byte-identically`

Wave 3, flat Tempo and flat Muster:

- legacy time-only equal-time lane order: `012 / 021 / 210 / 102`
- required time/source/lane/member order: `012 / 012 / 012 / 012`

The packet requires both byte identity and the new stable sort. They cannot
both hold. Recommended resolution: flat uses the legacy time-only sort; live
Muster uses the required stable sort. SG-198 is blocked before G3 and merge.
