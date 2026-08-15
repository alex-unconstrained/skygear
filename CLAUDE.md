# Godot rules

Derived from Alex's own past sessions, mined from the vault at
`C:\Users\alexr\ClaudeVault`. Each rule cites the sessions it came from.

**Exit code 0 does not mean the run passed — unless the harness watches for
raises, and here it does.** A GDScript runtime error is not an exception: it
prints, abandons the rest of the function it was raised in, and returns to the
caller as if the call completed. So a fixture that raises mid-`_process` gives
you a simulation that stopped stepping halfway through the frame, and a check
that then asserts the number it expected passes for the wrong reason.

**Do not build a log-and-grep wrapper. One already exists inside the harness.**
`class ErrorWatch extends Logger`, installed via `OS.add_logger` before the
first deferred call, so it watches the whole run from the inside. It gates
`script_errors` to zero as a check and ratchets `engine_errors` against a
budget, and the harness exits with the failure count. Grep for `ErrorWatch`
before writing any error detection — reimplementing it is how you end up with
two detectors that disagree.

**What is actually required of you: run the harness before you claim done.**

```
godot --path . --headless --script tests/parity_test.gd
```

(Blackstone's equivalent is `tests/smoke_test.gd`; grep for the harness rather
than assuming the filename.)

That is now enforced rather than requested. A `Stop` hook reads
`.parity-verdict.json` — written by the harness on every run — and blocks
completion when `.gd` files have changed since the last verified run, or when
that run had failures or script errors. The hook fails open on anything it
cannot parse, and stands down after repeated blocks, so it cannot trap you.
If it blocks you, run the harness; do not work around it.

**In a fresh clone or worktree, run `godot --headless --path <project> --import`
before the first test run.** Without a `.godot` cache, `class_name` globals do
not resolve. If a symbol still will not resolve after the import pass, use
`const X := preload("res://...")` rather than debugging the symbol.

(skygear 08-04: *"no .godot cache, so global class names don't resolve"*;
skygear 08-02; Card-Game 08-13.)

**Read `rendering/renderer/rendering_method` in `project.godot` before proposing
any visual effect.** Under `gl_compatibility` the following compile and do
nothing:

- `Viewport.use_debanding`
- glow and HDR in 2D
- `GeometryInstance3D.transparency`
- skinned-mesh material swaps — only `visible` works

Implement the effect in a shader yourself, or choose another approach. Run any
unfamiliar API snippet headless before writing it into a file: it will compile in
prose and raise at runtime.

(Hearthhold 07-16: *"a silent no-op under the gl_compatibility renderer this
project ships on every platform"*; Card-Game 08-13: *"debanding does not exist in
the Compatibility renderer… you must do it yourself"*, and a verified
`StyleBoxFlat.get_draw_rect()` raising *"Nonexistent function"*.)

**Check every new `const`, `var` and `func` name against `ClassDB` and the node's
inherited API before writing it.** Name preload constants for their role in caps
— `SHADER_LIVERY`, not `Shader`. Prefix accessors — `plate_material()`, not
`get_material()`. A member that shadows an engine class or an inherited method
breaks compilation of the **entire file**, and `--headless --import` reports it
only as a warning.

(Blackstone 08-11: *"shadows Godot's built-in Shader class, which breaks
compilation of the whole file (silently…)"*; Card-Game 08-13:
*"ReadingPlate.get_material() shadowed CanvasItem.get_material()"*.)
