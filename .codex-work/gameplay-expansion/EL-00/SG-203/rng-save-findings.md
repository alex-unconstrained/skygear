# SG-203 RNG and save findings

- The 120-row arm used generated names `BAL1` through `BAL120`, one observation
  per distinct name, after the same explicit excluded `BAL-WARMUP` as BASE-00.
- BAL1 and BAL2 were run once more only as a fingerprint audit. Both repeated
  fingerprints exactly matched their population observations. Effective n
  remained 120.
- Assigning `game.auto_element = "FROST"` is the existing named pre-run seam and
  performs no RNG draw. It was assigned before `begin_run` as required.
- The forced-Frost arm is expected to have a different whole-run fingerprint
  from default BAL2 because changing the auto element changes combat outcomes,
  later RNG consumption, and eventually the draft/loadout. That difference is
  not evidence of nondeterminism.
- The five burn acquisitions are deterministic: the independent source probe
  reproduced all five on the same waves, spawn serials, field ids, and times.
- `log_runs` was false; the driver used `SkyGearWorkshop.fresh(true)` and made no
  save/load or `user://` write. `auto_element` existed only on the in-memory game
  instance. No save schema or persisted owner state changed.

Core source SHA-256 at verdict:

- `scripts/game.gd` `73538FD2BB998BD7ED4E16381E5560813E71AFE01948FB810732FBA764381573`
- `scripts/enemy.gd` `CE86BACC3326B8F6D7FAE3D2796E51F840928D44EE506EF57704DDB24EBDCD17`
- `scripts/game_data.gd` `D42F7C81E54FAC094E3F1CD6BB163D4049C8E8C95DB725BA5A9EC81146201BC2`
- `scripts/player.gd` `851BDDA99FC54EDE52AB62BAF5572F1912C28A14AAD9347A68BD8333756A42E6`
- `scripts/telemetry.gd` `25B9C501F3344AB8268691942B76BA61D3E456F725AC0DF23FC37A96B33A4D09`
- `tools/bot.gd` `3529DB11154A3AA03EC8632A1F4D96FEAB6AD653582ED177D832535D15F23D99`
- `tools/balance.gd` `F6CA7261F168458F2918CD8C5E40E7B58F46DF63BF27F4E656048DFF3F95065A`

At coordinator HEAD `20048e79ef44dbdc67b10b352c9860a3b8fca3fe`, both
`git diff --name-only` and
`git diff --name-only 508523c..HEAD -- scripts tools tests scenes` were empty.

