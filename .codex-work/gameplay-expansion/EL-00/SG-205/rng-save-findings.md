# SG-205 RNG and save findings

- Nonlethal status damage consumes neither `game.rng` nor `visual_rng`.
  The latter matters physically because it also places seeded kegs.
- Arc with `stun_chance == 0` short-circuits before `rng.randf()`.
- The 120-pair G3 includes both RNG states in every physical fingerprint; all
  feature-off/on fingerprints match.
- BAL1 and BAL2 repeat fingerprints match exactly.
- The SG-204 true-non-Ember control keeps both RNG states unchanged and retains
  canonical fingerprint
  `27938549114bed08af8b3f9d36730778421b89acd0f7afc08986c055fad75b44`.
- `runs.json`, `keys.cfg`, `workshop.json`, and `settings.cfg` hashes
  are identical before and after G3. The full harness independently reports
  every protected owner file byte-for-byte unchanged.
- No save key or migration was added.

