# SKYGEAR · Browser 2D

An isolated browser-first continuation of the original top-down build, matched
to the current Godot game's player-facing systems. It does not modify or build
the Godot project or any archived browser release.

## Run

Serve the repository root so shared art remains available:

```powershell
python -m http.server 4173
```

Then open `http://localhost:4173/skygear-browser-2d/`.

## Parity surface

- Twelve waves, three lanes, cannons, crew, boarding hulks, three named events,
  two-phase Colossus, destructible kegs/crates, salvage and deck repair.
- Captain and Boilerwright, four equipped skills drawn from the complete
  9-shape × 4-element matrix, auto-Cleave, dash, Pressure/Vent and Head/vents.
- Seeded drafts, rerolls, telemetry, results and a persistent ten-run log.
- Persistent Workshop talents, Articles, six Heat rungs, six ship fittings and
  berth selection. Saves use browser `localStorage` under a versioned key.
- Rebindable keyboard controls, volume/reduced-motion settings, pause and
  responsive mouse/touch aiming.

This directory is intentionally self-contained. Shared `../assets` and
`../audio` paths are consumed read-only and procedural rendering is the fallback.
