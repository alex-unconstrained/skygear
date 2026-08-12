# AB-01 RNG and save findings

- `BEAM1` through `BEAM120` reproduced byte-identical fingerprints on the
  second repetition for all live, explicit and full-stay traces.
- Repetitions are a determinism audit only; effective sample size is 120 per
  comparison arm.
- Tick zero keeps the existing press-time crit opportunity. The three later
  ticks intentionally add independent per-body crit opportunities, exactly as
  design §17.1 requires. No cosmetic or unseeded stream is used by the channel.
- The element-once dictionary is runtime channel state keyed by the production
  spawn serial. It is not persisted.
- No save schema, run-log schema, workshop state or settings path changed.
