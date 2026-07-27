# SKYGEAR — voice and dialogue brief

Everything a generation session needs to produce the game's spoken lines, and
nothing it does not. Companion to `AUDIO-SPEC.md`, which covers the 49
outstanding **sound effects**; this covers **voice**, which the game has none of
yet and which is wired and waiting.

Written 2026-07-27 against v11. **Engine side is already done** — 19 voice cue
keys exist in `AUDIO_MANIFEST`, every call site is live in the simulation, and
the director in `_audio.js` §8 handles priority, cooldowns and channel
occupancy. A delivered file is audible the moment `src/ingest-audio.py` sees it.
No engine work is required to ship any line below.

---

## 1 · The rules, before the lines

**1 · Voice never carries information on its own.** Every line sits on top of a
mechanical cue that already fires — a banner, a lane alert, a hurt sound, a
gauge. Delete the whole layer and the game loses character, not clarity. This is
what makes it safe to cap, cull and cooldown voice aggressively.

**2 · There is no procedural fallback and there must not be one.** An absent
line is silence. A synthesised impression of a human voice is worse than
nothing, and the game already sounds finished without it.

**3 · The captain is not a narrator.** She is busy. Lines are short, thrown over
a shoulder, sometimes half-swallowed by effort. Nothing she says explains a
mechanic to the player — the contextual prompts do that in text, and a voice
line that repeats them makes the game feel like a tutorial that will not end.

**4 · Repetition is the enemy.** Every key needs **three takes minimum** and
four where marked, because the director refuses to repeat the last variant and
falls back to silence rather than saying the same thing twice.

**5 · Nothing shouts.** Delivered peak is −8 dBFS like every other master
(`tools/audio-check.py` enforces it). These sit on their own `voice` bus and are
mixed under the survival tier, not over it.

---

## 2 · The cast

| Voice | Who | Direction |
|---|---|---|
| **CAPTAIN** | The player. A sky-pirate captain, 30s, weathered, dry. | Mid-low, slightly gravelled, unhurried even under pressure. Working, not performing. Think a good pilot on the radio: the worse it gets, the flatter she sounds. Occasional dark amusement. No quips, no catchphrases, no "let's do this". |
| **CREW** | Your boarding crew, several of them. | Rougher, younger, more varied. Half of them are shouting across a deck in a storm. Lines are calls, not sentences. These may be several different voices — variety across takes is a feature here, not an inconsistency. |
| **COLOSSUS** | The Brass Colossus, the wave-12 boss. | Not a person. A voice through a pressure vessel: low, resonant, mechanically processed, with the cadence of something reciting rather than speaking. Two lines only, and both should feel like the ship itself is talking. |

Accent: the captain and crew read as North Atlantic working-class rather than
RP; the setting is industrial, not aristocratic. Do not attempt a specific
regional accent — a generic weathered delivery is safer than a bad one.

---

## 3 · ElevenLabs settings

Use **Text to Speech** (not Voice Design) with a pinned voice ID per character,
so takes stay consistent across sessions. Record the IDs here when chosen.

| Setting | Captain | Crew | Colossus |
|---|---|---|---|
| Model | `eleven_multilingual_v2` | same | same |
| Stability | 0.42 | 0.30 | 0.55 |
| Similarity | 0.80 | 0.72 | 0.85 |
| Style | 0.25 | 0.45 | 0.15 |
| Speaker boost | on | on | on |

Lower stability on the crew is deliberate: it is what makes six takes of the
same call sound like six different people.

**Prompt shape.** ElevenLabs takes direction badly inside the line and well
around it. Put delivery in the text field only as the bracketed tags it
supports, and set everything else with the settings above:

```
[exhales] Rails. Port side.
```

Post-process every take before ingest:

1. Trim to the first and last sample of speech, then leave 60–90ms of air.
2. High-pass at 90 Hz (captain/crew) or 55 Hz (Colossus).
3. Normalise peak to **−8 dBFS**.
4. For the Colossus only: a light ring-modulated doubling an octave down at
   −14 dB, then a short plate at 12% wet. It should sound like it is speaking
   through the hull.
5. Export as WAV 48k mono. Stereo is wasted — the engine pans these positionally.

---

## 4 · The line sheet

Cue key → what fires it → how long → what she says. **Every line is a take, not
a script**: reword freely for delivery, keep the length and the intent.

Files go to `audio/voice/<folder>/<stem>_N.wav`, numbered from 1. The stems are
already in the manifest and must match exactly.

### 4.1 Captain — the run

| Cue | Fires when | Budget | Takes | Lines |
|---|---|---|---|---|
| `vo_wave_start` | a wave begins | 1.4s | 4 | "Here they come." · "Next lot." · "Hold the deck." · "Again, then." |
| `vo_wave_clear` | a wave is cleared | 1.4s | 4 | "Deck's clear." · "That's the lot." · "Still standing." · "Breathe." |
| `vo_first_board` | the first boarder of the run lands | 1.6s | 3 | "They're over the rail." · "Boarders. Move." · "On the deck — go." |
| `vo_draft` | a draft opens | 1.6s | 3 | "Something in the hold." · "Let's see what we've got." · "Salvage worth having." |
| `vo_slot` | a skill slot unlocks | 1.4s | 3 | "Another hand free." · "Room for one more." · "I can carry that." |
| `vo_victory` | twelve waves repelled | 3.0s | 2 | "Twelve. The deck's ours." · "Let them tell it at home. We held." |
| `vo_defeat` | the run ends badly | 3.0s | 3 | "...damn." · "Get to the boats." · "That's it. She's going down." |

### 4.2 Captain — the close-quarters loop (v11)

These are the ones that carry the new system, and the ones most at risk of
becoming annoying. Keep them **short, low, and half under the breath.**

| Cue | Fires when | Budget | Takes | Lines |
|---|---|---|---|---|
| `vo_vent` | the pressure gauge fills and vents | 1.2s | 4 | "[exhales] Better." · "Off me." · "Hah." · a hard breath out, no words |
| `vo_keg` | a steam keg is lit anywhere on the deck | 1.2s | 4 | "Keg!" · "That's lit." · "Move — move." · "Down!" |
| `vo_dash` | 17% of dashes | 0.6s | 6 | Effort only. Six distinct short exhales/grunts. **No words at all.** |
| `vo_hurt_low` | dropping under 30% health | 1.4s | 4 | "[exhales] That hurt." · "Bleeding." · "I'm all right." · "Not yet." |

### 4.3 Captain — the objective

Higher priority than anything above; these cut in over other lines.

| Cue | Fires when | Budget | Takes | Lines |
|---|---|---|---|---|
| `vo_boiler_low` | the Boiler drops under half | 2.0s | 3 | "Boiler's taking it. Get them off her." · "She won't hold at this." · "Half the core's gone." |
| `vo_lane_critical` | a lane goes critical | 1.8s | 4 | "Port's breaking." · "Starboard — now." · "Centre's gone soft." · "They're through." |
| `vo_push` | a boarding hulk grapples on | 2.2s | 3 | "They've grappled on. Break it." · "That thing keeps feeding them — kill it." · "Hulk on the hull." |

Note: `vo_lane_critical` is the one line in the game that would benefit from
naming the lane, and the engine knows which one. Record the three named takes
above in that order and they can be selected by lane later; the director will
pick between them at random until then, which is why all three are written to be
correct in any lane.

### 4.4 Crew

| Cue | Fires when | Budget | Takes | Lines |
|---|---|---|---|---|
| `vo_crew_muster` | reinforcements arrive | 1.6s | 4 | "Up the lane!" · "With you, Captain!" · "Forward!" · "Crew up!" |
| `vo_crew_down` | 25% of crew deaths | 1.2s | 6 | Short cries and grunts. One or two words at most: "Ah—!" · "Man down!" |
| `vo_cannon_down` | a deck cannon is destroyed | 1.6s | 3 | "Cannon's gone!" · "We've lost the gun!" · "She's down, Captain!" |

### 4.5 The Colossus

| Cue | Fires when | Budget | Takes | Lines |
|---|---|---|---|---|
| `vo_boss_arrive` | it comes over the bow | 3.0s | 2 | "YOUR DECK IS SCRAP." · "GIVE ME THE ENGINE." |
| `vo_boss_turn` | it turns at half health | 2.4s | 2 | "NOT ENOUGH." · "AGAIN, THEN." |

Two lines each and no more. A boss that talks through the fight becomes
furniture; a boss that speaks twice is remembered.

---

## 5 · What NOT to record

Written down because every one of these will look like a good idea during a
session:

- **Lines on every cast, kill or crit.** The captain casts ~400 times a run.
- **Lines on picking a card.** The draft is a menu; a voice line makes it slow.
- **Lines explaining a mechanic.** "Pressure builds when you fight close!" — the
  contextual prompt already says it, once, in text, and can be turned off.
- **A narrator or announcer.** No wave-number readouts, no "FIRST BLOOD".
- **Boarder chatter.** They are machines. They have SFX, not voices.
- **Anything referencing the player by a name.** There is no player name.

---

## 6 · Ingest

```bash
# put the takes in a staging tree that mirrors audio/
#   voice/captain/wave_start_1.wav ... _4.wav
python src/ingest-audio.py --from <staging>   # copies, validates, rewrites the index
python tools/audio-check.py                   # peak, clipping, cut-off tails
python src/storm-dusk/build.py && npm test
```

`ingest-audio.py` rewrites `_audio_index.js` from **the whole staging tree**, so
stage everything (existing masters included) or the index will drop what is not
there. The index is what the loader reads; a cue not in it costs no request and
logs no 404.

---

## 7 · The SFX queue, for the same session

Voice is 19 keys. The other 49 outstanding cues are specified in
`AUDIO-SPEC.md` §7 and unchanged, except that **v11 adds five** which are wired
with procedural voices and want real ones:

| Cue | Budget | Character |
|---|---|---|
| `keg_fuse` | 0.45s | A bright pressurised hiss that RISES. Must be identifiable across a deck — this is the game's only "get out of the way" sound. |
| `keg_blow` | 0.60s | A dull, low, wet steam burst. Deliberately duller and lower than the player's own STEAM cue so a chain reaction does not mask the player's own casts. |
| `crate_break` | 0.30s | Splintering timber and a scatter of small brass parts landing. |
| `lantern_break` | 0.25s | Thin glass, then a soft whump of oil catching. |
| `vent` | 0.55s | The player's reward: a rising pressure release with a bright top. Should feel like relief. Tier 1 — it must cut through a wave-11 crowd. |

Priority order for a session with a budget: **the five above**, then
`AUDIO-SPEC.md` §7's batch 1 (the six misused cues), then §4.2's close-quarters
voice lines, then everything else. The reason is coverage per generation: those
five and the close-quarters lines are the only sounds in the game attached to a
system nobody has heard yet.
