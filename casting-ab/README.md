# CAPTAIN CASTING A/B — 2026-08-11

Two complete sets of the Captain's 50 takes, same lines, same pipeline, same
mastering. Board **SG-228** (the Captain is young and male; the previous
casting was a middle-aged British woman and never matched the art).

**This folder is deliberately OUTSIDE `audio/`.** `src/ingest-audio.py` globs
`audio/**` recursively, so a comparison set left in there would be swept into
the delivery index as if it were a second take of every line.

**DECIDED 2026-08-11: WILL.** The owner heard both sets and chose Will. He is
installed and pinned; Charlie is kept here rather than deleted so the decision
can be re-heard instead of re-argued.

| | Voice | ElevenLabs id | Read |
|---|---|---|---|
| `will/` | **Will — CHOSEN, installed** | `bIHbv24MWmeRgasZH58o` | young, relaxed, American |
| `charlie/` | Charlie — runner-up, not installed | `IKne3meq5aSn9XLyUdCD` | young, deep, confident, Australian |

Both sets are `.wav` masters at 24 kHz mono, peak-normalised to −8 dBFS by
`soundforge.py` — the same level as every other master in the game, so a
loudness difference between them is a performance difference, not a mastering
one. Play them at the same volume.

## What is live right now

**Will is installed.** `skygear-godot/assets/audio/voice/captain/*.ogg` are
Will's 50 takes, reimported (exit 0), harness green at **1208/1208**.
`audio/voice/captain/*.wav` is also Will, so the master set matches what ships.
`tools/soundforge.py` is pinned to Will.

Verified by duration rather than assumed — `victory_2` installed at 2.36s
(Will) not 2.08s (Charlie); `wave_start_4` 0.79 not 0.71; `defeat_3` 1.01 not
1.18.

**Charlie is not installed.** His takes are kept here as the runner-up.

## The lines worth judging on

Skip the grunts; they tell you little. These six carry the character:

| Cue | The line(s) | What to listen for |
|---|---|---|
| `wave_start_*` | "Here they come." · "Next lot." · "Hold the deck." · "Again, then." | The brief's core direction — *unhurried under pressure*. "Again, then." should sound bored, not brave. |
| `first_board_*` | "They're over the rail." · "Boarders. Move." | An order, thrown over a shoulder. Not announced. |
| `defeat_*` | "...damn." · "Get to the boats." · "That's it. She's going down." | The hardest read in the sheet. Flat beats mournful. |
| `victory_*` | "Twelve. The deck's ours." · "Let them tell it at home. We held." | Earned, not triumphant. No fist-pump. |
| `hurt_low_*` | "That hurt." · "Bleeding." · "I'm all right." · "Not yet." | Should sound like it costs him something. |
| `vent_*` | "Better." · "Off me." · "Hah." | Half-swallowed by effort. |

## The test that actually decides it

The crew are cast young too, and they shout across a deck in a storm. **The
Captain is separated from them by steadiness, not by age.** Play a captain take
straight after `assets/audio/voice/crew/muster_1.ogg` ("Up the lane!"). If the
captain sounds like one more boarder, that casting is wrong regardless of how
good the take is on its own.

## To switch to Will

One line in `tools/soundforge.py` (`VOICES["captain"]`), then regenerate and
re-encode. Roughly two minutes now that an ffmpeg with `libvorbis` exists. The
`.ogg` conversion is NOT part of the documented pipeline — see the open gap
where `ingest-audio.py` serves only the browser build and has never delivered
into `skygear-godot/`.
