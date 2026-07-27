# SKYGEAR — music brief for Suno

There is no Suno API, so music is the one part of this pipeline a person makes
by hand. This file is written to be **used at the keyboard**: every track below
has a style prompt to paste, a length, and — where a track should have words — a
lyric *starter* rather than a finished lyric, because the generator writes
better from a seed than from a script.

Updated 2026-07-27, after `boss_loop` and `combat_high` landed.

---

## 1 · What exists, what is missing

| Slot | File | State |
|---|---|---|
| M2 · waves 1–4 | `music/combat_low.mp3` | **delivered** — "Brass Skies Up", 2:48, looped 1.0→164.5s |
| M4 · waves 9–11 | `music/combat_high.mp3` | **delivered** — "The Final Stand" (sparse), 1:29, looped 1.0→85.5s |
| M6 · wave 12, the Colossus | `music/boss_loop.mp3` | **delivered** — "The Final Stand" (full), 1:53, looped 1.0→109.5s |
| M1 · title screen | `music/title_loop` | **needed** |
| M3 · waves 5–8 | `music/combat_mid` | **needed** |
| M5 · push waves 4, 8, 12 | `music/push_loop` | **needed** |
| M7a · victory | `music/victory_sting` | **needed** |
| M7b · defeat | `music/defeat_sting` | **needed** |

Nothing is blocked by their absence: the director falls back down a chain, so
a missing `push_loop` plays `combat_high` and a missing `title_loop` plays
`combat_low`. Every one of these is an improvement, not a fix.

---

## 2 · How to deliver

1. Render, download the MP3.
2. Drop it in `audio/music/` **named exactly as the slot above** —
   `title_loop.mp3`, `combat_mid.mp3`, `push_loop.mp3`, `victory_sting.mp3`,
   `defeat_sting.mp3`.
3. Tell me it is there. I measure the real duration, find where the intro fade
   ends and the outro fade begins, set `loopStart`/`loopEnd` in the manifest,
   re-index and rebuild.

**Do not try to make it loop.** Suno tracks are authored with an ending, and
the engine does not use the file's own loop — it schedules each pass as its own
source and crossfades 2 seconds over the join, taken from the sustained middle.
A track that fades in over a bar and out over four is completely fine. What is
*not* fine is a track that changes character halfway through, because the loop
is lifted from one section and the rest is never heard.

**Two minutes is plenty.** The loop is 60–100 seconds of the middle; anything
longer is paid for in download size and never heard.

---

## 3 · The house style, unchanged

Paste this into every style prompt, then the per-track line:

> dark steampunk orchestral, storm at altitude, brass and low strings,
> clockwork percussion, no modern drum kit

M2/M3/M4 are meant to be **recognisably the same piece escalating** — same key,
same core motif, more weight each tier. `combat_low` and `combat_high` are
already delivered and set that key, so `combat_mid` is the one that has to sit
between two existing tracks rather than invent anything.

### Where words belong, and where they do not

| Track | Vocals? | Why |
|---|---|---|
| Title, victory, defeat | **yes, if you want them** | Nothing else is competing. A voice here is the strongest identity the game can have for the cost. |
| Boss | **already has them** | It is the finale; a vocal is an event. |
| Combat beds, push | **no, or wordless only** | The captain's voice lines, lane alerts and the keg fuse all live in the same 300 Hz–3 kHz band. A sung lyric under a fight makes the survival cues harder to hear, which is the one thing the mix is not allowed to do. Ooohs, chants and non-lexical vocals are fine. |

---

## 4 · The five tracks

### M1 · `title_loop` — the title screen
**~2:00 · slow · brooding, wide · vocals welcome**

**Style prompt**
> Dark steampunk orchestral, storm at altitude, brass and low strings,
> clockwork percussion, no modern drum kit. Slow, brooding, wide. Low strings
> and distant brass over thunder. Sparse ticking clockwork like a great engine
> idling. A lone melancholy horn motif. An airship at anchor above a
> thunderhead at dusk. Patient, unresolved.

**Lyric starter** — a verse and a hook seed; let Suno finish it.
```
[Verse]
Ten thousand feet and the lamps are lit
Her boiler breathing slow
There's iron in the cloud tonight
And nowhere left to go

[Hook]
Hold the deck, hold the deck
```

### M3 · `combat_mid` — waves 5–8
**~1:45 · 116 BPM · instrumental**

This one has to sit *between* two tracks that already exist: heavier than
`combat_low`, not yet as desperate as `combat_high`. If Suno gives you something
that could open the game, it is too light; if it could end it, too heavy.

**Style prompt**
> Dark steampunk orchestral battle instrumental, 116 BPM, storm at altitude,
> brass and low strings, clockwork percussion, no modern drum kit, no vocals.
> The same brass ostinato as the earlier waves but heavier and more insistent.
> Full low strings, timpani, chains and steam bursts as percussion, a rising
> four-note brass figure. Losing ground but still fighting for it.

**Lyrics:** none. Instrumental.

### M5 · `push_loop` — push waves (4, 8, 12)
**~1:30 · 128 BPM · alarm · wordless vocals only**

Plays only while a boarding hulk is grappled to the hull and the player has to
leave the objective to break it. It should feel like a countdown.

**Style prompt**
> Dark steampunk orchestral, 128 BPM, alarm and urgency, brass and low strings,
> industrial percussion, no modern drum kit, no lyrics. A repeating low brass
> warning figure like a ship's horn. Strings stabbing on the offbeat. Something
> enormous has grappled onto the hull and is not letting go. Relentless,
> circular, never resolving.

**If you want voices:** a low wordless male chant on the downbeat, no words.

### M7a · `victory_sting` — twelve waves repelled
**0:12 · one-shot, not a loop · vocals welcome**

**Style prompt**
> Triumphant steampunk orchestral sting, 12 seconds. Brass fanfare resolving to
> a warm major chord, a steam whistle flourish, clockwork settling into rest.
> Ends clean and stops.

**Lyric starter** — one line, sung once, over the fanfare:
```
[Outro]
Still standing, still flying, still ours
```

### M7b · `defeat_sting` — the deck is lost
**0:10 · one-shot, not a loop · vocals welcome**

**Style prompt**
> Bleak steampunk orchestral sting, 10 seconds. Descending low brass, a great
> engine winding down and stopping, one last struck bell in the silence after.
> Ends clean and stops.

**Lyric starter** — spoken or half-sung, once:
```
[Outro]
The lamps go out one at a time
```

---

## 5 · If you only make one

`title_loop`. It is the first thing a stranger hears, it plays while the art is
still streaming in, and it is the only track that gets listened to rather than
fought over. `combat_mid` is second — waves 5–8 currently reuse the wave 1–4
bed, which is the longest stretch of the game with no escalation in it.
