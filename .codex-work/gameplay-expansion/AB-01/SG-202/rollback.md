# AB-01 rollback

Candidate commit `508523c` sits on serialization cursor
`af7d8ce76c16f9f405c6aa646b05e4d831a565a4`. Before a human pass, revert
`508523c` whole if any remaining gate fails. After merge, revert the
coordinator-recorded SG-202 merge/closure commit followed by `508523c` if the
code must also leave the queue.

The published test rollback is itch build **65-deck-edge-verdict**
(`#1858433`). Build 66 is a candidate, not a release.

Retain this evidence directory, including the red-first log, G3 traces and G4
plates. Do not revert BASE-00 or the immutable pre-baseline artifacts.
