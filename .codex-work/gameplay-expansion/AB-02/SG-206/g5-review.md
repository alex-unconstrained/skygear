# Human G5 review

Status: **PENDING — no human verdict claimed.**

Review the normal-camera sequence in `g4/`:

1. `01-initial-live-follow.png` — unset Field centered on the captain.
2. `02-committed-active-landing.png` — accepted Lance landing claims the Field.
3. `03-captain-leaves-useful-field.png` — captain is 380 units away; Field remains on the target and its next tick deals exactly 4.0.
4. `04-same-state-repeat.png` — exact frozen-state duplicate of frame 3.

The paired frozen frames have identical SHA-256 hashes and 0 of 11,059,200 RGB bytes differ (0.00% same-state noise). Required human question: does the normal-camera sequence clearly communicate that the captain deliberately left a useful Field behind without making the Field appear active or key-bound?

Artifact hashes:

- `01-initial-live-follow.png`: `96C8F5EA9E6DC852818DE012122A698763125EE0B23B71C49B794DBD86AFE96E`
- `02-committed-active-landing.png`: `95C40F31573A95036521BB89E8652341904FE3D0EAABB6A910BD4A0B5A9B0A63`
- `03-captain-leaves-useful-field.png`: `1DD9232FEC2E42117179323BF53281BCA9AD9E3E02CAEB318383FDED2BAF1AC6`
- `04-same-state-repeat.png`: `1DD9232FEC2E42117179323BF53281BCA9AD9E3E02CAEB318383FDED2BAF1AC6`
- `g4-fixture.json`: `6A20634D685ED7F6EB09E8B8DD68603E01C6B32B578781EFCD5F62D863C57C9B`
- `sg206_g4_fixture.gd`: `EE05F8EA04B031C7E6D5CD0A52CAB606811E2321C3A8B7CDCD68432B8689EA3B`
- `g4.log`: `759E22E1392D02842F75AF035F1C7DA6F81D39C1F74030DD62862986D318A7F1`

The fixture was captured successfully and machine-checked, but this worker's local image-review helper could not open workspace images because of the Windows restricted-token sandbox. This is a coordinator-side review limitation only; it does not alter the artifacts or claim a G5 verdict.
