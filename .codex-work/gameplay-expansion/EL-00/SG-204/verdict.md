# SG-204 verdict

Result: **PASS**

The focused control uses the accepted AB-01 production damage funnel with a
Frost auto and one Frost Mortar row. Props and fire fields are absent by
construction. Two independent runs emitted byte-identical report records and
fingerprint
`27938549114bed08af8b3f9d36730778421b89acd0f7afc08986c055fad75b44`.

Both player buckets recorded their exact damage once (basic `0.5`, slot zero
`0.4`); every player element was non-Ember; burn stacks and BURN rows were
zero. Main and visual RNG states were unchanged.

The negative leg added one real production `fire_field`. The identical no-burn
assertion then failed with one burn stack, proving the control excludes the
environmental source SG-203 discovered rather than merely failing to observe
it.

SG-203's valid production arm remains immutable at SHA-256
`65F183243A8912D1D8005464EF9B2627E19BB4E6BF5D2D90A6C937A9794C3C7A`.
Driver SHA-256:
`C174E0F8C06C2BDFE51E0899BFEFD54C753A2DB3AB33585D98975982ADCC44F0`.

Godot printed its known external-script teardown resource warnings after the
PASS line; there were no parse, script, assertion, or runtime-path errors.
No tracked/project file changed.
