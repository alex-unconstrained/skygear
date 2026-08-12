# SG-204 RNG and save findings

- Main RNG state before/after the two non-Ember production-funnel hits:
  unchanged.
- Visual RNG state before/after: unchanged. The fixture disables the optional
  view reader and uses sub-one damage, so this attribution control does not
  enter the seeded cosmetic floater branch.
- `runs.json`, `keys.cfg`, `workshop.json`, and `settings.cfg` were
  SHA-256 fingerprinted before and after the entire fixture. All four hashes
  were byte-identical.
- No save method was called and no save schema was introduced.
