# SkyGear: Godot port

This folder is an isolated Godot 4.5 project based on the latest shipped
SkyGear build, v11. It does not import from, write to, or require any file
outside this directory.

## Run

1. Install Godot 4.5 or later.
2. Import this directory by selecting `project.godot`.
3. Press F6/F5, or run:

   ```powershell
   godot --path . --editor
   godot --path . --headless --quit-after 3
   ```

Controls: WASD moves, mouse aims, LMB/RMB/Q/E use skill slots, Space dashes,
1/2/3 chooses a draft card, and Esc or P pauses.

## What is playable now

- title and opening weapon draft;
- the v11-sized three-lane deck and Boiler objective;
- automatic Ember Cleave;
- nine skill shapes crossed with four elements in data;
- active Cleave, Lance, Gale, Mortar, Whip, and Beam behavior;
- two-charge dash with contact damage;
- four regular enemy archetypes, melee attacks, and readable hostile bolts;
- wave spawning and inter-wave three-card drafts;
- destructible steam kegs, crates, and lanterns;
- close-range pressure, vent damage/healing, salvage, and game-over flow.

This is an initial vertical slice, not yet a claim of v11 feature parity. The
living scope and parity record is in [DESIGN.md](DESIGN.md).

## Isolation rule

`reference/` is a copied snapshot used only for comparison. `assets/` contains
copied runtime assets. All Godot code and derived files live here. Never point a
Godot importer, converter, or editor operation at the parent project.

