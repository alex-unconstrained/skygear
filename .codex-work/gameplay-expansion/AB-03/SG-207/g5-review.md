# Human G5 review

Status: **PENDING — no human verdict claimed.** SG-207 also remains held behind the pending SG-206 human verdict.

Review the normal-camera sequence in `g4/`:

1. `01-pulse-before-cast-0.3.png` — the passive Pulse face reads about 0.3 seconds before due.
2. `02-accepted-cast-pulse-due-now.png` — the accepted Lance misses the side target, advances Pulse, and the same scheduler-owned face reads 0.0 while retaining a raw -0.05 remainder.
3. `03-pulse-fires-on-crossing-target.png` — Pulse discharges for the unchanged 34.0 damage and the face returns to the carried 3.42-second remainder.
4. `04-same-state-repeat.png` — exact frozen-state duplicate of frame 3.

The paired frozen frames have identical SHA-256 hashes and 0 of 11,059,200 RGB bytes differ (0.00% same-state noise). Required human question: does a normal cast visibly and satisfyingly pull Pulse toward an earlier useful discharge, while Pulse still reads as one passive/keyless skill with one understandable timer?

Artifact hashes:

- `01-pulse-before-cast-0.3.png`: `C9E13414F80323D5E1A95BB2C14BEA08BE20A6DF8545571751612AA2B8650453`
- `02-accepted-cast-pulse-due-now.png`: `DB592E5C114D62F7393684BC91E1A1076C8C2221A7299B8A2B8EF37221B491DF`
- `03-pulse-fires-on-crossing-target.png`: `EE09DF81E85023AA9C399B3458F814C9C85206DFA7D51C233CD334604E435451`
- `04-same-state-repeat.png`: `EE09DF81E85023AA9C399B3458F814C9C85206DFA7D51C233CD334604E435451`
- `g4-fixture.json`: `85454B77D451C05091A295BE23481E87D4FDDFC9DD9DE19EC2109C5DF35F256B`
- `sg207_g4_fixture.gd`: `B4FF0330E4851800FD095BBBC6A6D0433EEE1D043187BFD3B3B97D982469B827`
- `g4.log`: `9B02A1022AB9718926AE550727FC6EE32B4B0B3B21833087B92DD5DC5CDB74CE`

The fixture was captured and machine-checked successfully, but this worker's image-review helper could not open workspace images because of the Windows restricted-token sandbox. This is a local review limitation only; it neither alters the artifacts nor claims a G5 verdict.
