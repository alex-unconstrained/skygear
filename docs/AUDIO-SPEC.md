# SKYGEAR — audio specification

Everything the game needs to hear, what makes it, and what the engine does with
it. Companion to `skygear-visual-asset-spec-v1.md` and `LEVEL-KIT-BRIEF.md`.

**Three tools, three jobs.**

| | |
|---|---|
| **Suno** | Music. 7 tracks, all loops. |
| **ElevenLabs** | SFX (text-to-sound-effect) and the captain's voice. |
| **Codex** | The pipeline: encode, loudness-match, find loop points, write the manifest, wire the loader. |

---

## 1 · Where the audio is today

All sound is synthesised live in WebAudio — oscillators, a shared noise buffer,
biquad filters, one compressor on the master bus. No files, no network, no
licence. `Sound` (engine) and `SFX` (the 20 named cues) in `_core_patched.js`.

**This is not a placeholder to be deleted.** It is the fallback. Every cue below
keeps its procedural version, exactly as the art pipeline keeps procedural
sprites. If a file is missing, fails to decode, or the player is offline, that
cue still fires. Nothing added here may make the game silent-on-failure.

### What is actually wrong right now

Found while inventorying call sites — worth fixing regardless of new assets:

| Problem | Where | Why it matters |
|---|---|---|
| **Your deck cannon sounds like incoming fire** | `_lanes.js:135` — the turret fires `SFX.enemyShoot()` | Friendly artillery and enemy artillery are the same sound. The single most confusing thing in the current mix. |
| **Crew reinforcements arrive on a UI blip** | `_lanes.js:172` — `SFX.ready()` | The same 70ms sine as an ability coming off cooldown. A wave of allies deserves its own signal. |
| **The boarding hulk breaking reuses the boss roar** | `_lanes.js:268` | Two very different events, one sound. |
| **Chip damage on the hulk is silent** | `damageHulk()` | You hit a 1500 HP objective and hear nothing back. |
| **Crew dying is silent** | `hurtCrew()` | Your side takes losses inaudibly. |
| **Turret damage is silent** until it dies | `damageTurret()` | No warning that a lane is being lost. |

These are new cues in §7, marked **NEW**.

---

## 2 · What the audio has to do

The game is a hero-defense on an airship deck at dusk, in a storm, at 10,000
feet. Steampunk: brass, steam, coal, clockwork. The enemy is automaton — the
sound of a machine army boarding a working ship.

Three jobs, in priority order when they compete:

1. **Tell the player what is happening off-screen.** Three lanes, a following
   camera, and a deck longer than the viewport. Sound is the only channel that
   reaches a lane the player is not looking at.
2. **Sell the hit.** The game runs hit-stop, trauma shake and damage numbers on
   impact; audio is the fourth element of that and the one that carries weight.
3. **Sit under it all without fatigue.** Twelve waves is a 20+ minute session.

---

## 3 · Delivery spec

**Format.** Deliver every file twice: **`.ogg`** (Vorbis, q5 for SFX, q6 for
music) and **`.m4a`** (AAC-LC, 128 kbps mono SFX / 160 kbps stereo music). The
loader picks with `canPlayType`. Everything is decoded to an `AudioBuffer`, so
after load there is no format difference.

**Channels.** SFX mono — they get positioned in the stereo field by the engine
from world coordinates, and a stereo source cannot be panned honestly. Music
stereo.

**Sample rate.** 48 kHz, 24-bit masters. The pipeline downconverts.

**Loudness.**

| | Integrated | True peak |
|---|---|---|
| Music loops | **−16 LUFS** | −1.5 dBTP |
| SFX, one-shots | **−18 LUFS** momentary | −3.0 dBTP |
| Voice barks | **−16 LUFS** | −3.0 dBTP |

Deliver **unnormalised masters too**. Codex loudness-matches; do not pre-limit
SFX into a brick or the engine's compressor has nothing to work with.

**Length discipline.** Combat one-shots must be **short**. A cleave that swings
every 0.36 s cannot have a 900 ms tail — it will pile into mud within two
seconds. Per-cue budgets are in §7 and they are limits, not suggestions.

**Naming.** `audio/<category>/<name>.<ext>`, lowercase, underscores.
Categories: `music/ sfx/ui/ sfx/player/ sfx/enemy/ sfx/lane/ sfx/world/ vo/`.

**Silence.** Zero-crossing starts. No leading silence on one-shots — every
millisecond of pad is latency the player feels as sloppiness. Trim to the
transient.

**Total budget.** Music ≤ 6 MB (lazy-loaded, see §5). SFX ≤ 2.5 MB (loaded
up-front). Voice ≤ 1.5 MB.

---

## 4 · The mix

Four buses under the existing master compressor:

```
  master (comp: -14 thr, 8:1, 3ms/160ms)
   ├── music     0.55   ducked by combat, see below
   ├── sfx       1.00   world + player + enemy
   ├── ui        0.85   never ducked, never positioned
   └── voice     1.00   ducks music -6 dB while speaking
```

**Positioning.** Every world-space SFX is panned and attenuated from its
distance to the camera focus. Pan = `clamp((x - focusX) / (worldW * 0.5), -1, 1) * 0.7`
— hard-panning a lane fight to 1.0 is disorienting when the camera follows.
Attenuation: full to 600 units, rolling to 0.35 at 1600, never zero. **A lane
you cannot see must still be audible** — that is the whole point.

**Ducking.** Music drops 4 dB for 250 ms on any BOSS or PUSH cue, and 6 dB
while voice plays. Nothing else ducks music; per-hit ducking pumps.

**Voice limiting.** This is a horde game — 20+ enemies can die in a second.
Per-cue caps, oldest-stolen:

| Cue class | Max concurrent | Retrigger floor |
|---|---|---|
| `hit`, `crit` | 4 | 30 ms |
| `death` | 3 | 60 ms |
| enemy footfall/idle | 2 | — |
| player ability | 6 | — |
| everything else | 2 | 80 ms |

**Pitch variance.** The loader applies ±6% random detune to any cue tagged
`vary` (all combat one-shots). One `hit.ogg` heard 400 times a wave must not be
identical 400 times. This means **you do not need to author variations** for
most cues — where genuine variants are wanted they are listed explicitly.

---

## 5 · Music — Suno

Seven loops. **All must loop seamlessly.** Deliver each as a single continuous
render with the loop boundary *inside* the file, plus a note of intended
loop points in seconds; Codex finds sample-exact `loopStart`/`loopEnd` and
stores them in the manifest, so the engine loops the decoded buffer rather than
relying on encoder padding.

Music is lazy-loaded: title track up front, combat tracks fetched during the
title screen, boss/victory/defeat on first need. No track blocks the game.

**House style for every prompt:** *dark steampunk orchestral, storm at
altitude, brass and low strings, clockwork percussion, no vocals, no modern
drum kit, loopable.*

### M1 · `music/title_loop` — title screen
**2:00 · slow · brooding, wide**

> Dark steampunk orchestral instrumental. Slow, brooding, wide. Low strings and
> distant brass over a storm. Sparse ticking clockwork percussion like a great
> engine idling. A lone melancholy horn motif. Airship at anchor above a
> thunderhead at dusk. No vocals. No drum kit. Seamless loop.

### M2 · `music/combat_low` — waves 1–4
**1:45 · 100 BPM · driving, restrained**

> Dark steampunk orchestral battle instrumental, 100 BPM. Driving but
> restrained — holding something back. Staccato low strings, iron percussion,
> hammer-on-anvil accents, a brass ostinato underneath. Machines boarding a
> ship. No vocals. No modern drums. Seamless loop.

### M3 · `music/combat_mid` — waves 5–8
**1:45 · 116 BPM · same DNA, more weight**

> Dark steampunk orchestral battle instrumental, 116 BPM. Same brass ostinato
> as before but heavier and more insistent. Full low strings, timpani, chains
> and steam bursts as percussion, a rising four-note brass figure. Losing
> ground. No vocals. Seamless loop.

### M4 · `music/combat_high` — waves 9–12
**1:45 · 132 BPM · desperate**

> Dark steampunk orchestral battle instrumental, 132 BPM. Desperate and
> relentless. Tremolo strings, full brass section, war drums and clanging
> metal, a descending chromatic line under it. The deck is being overrun. No
> vocals. Seamless loop.

*M2/M3/M4 should be recognisably the same piece escalating — same key, same
core motif. Codex crossfades between them over 2 s on wave change, so they must
share a tonal centre. Give them all the same key and tempo family (100/116/132
are all workable at a 4-bar crossfade).*

### M5 · `music/push_loop` — push waves (4, 8, 12)
**1:30 · 128 BPM · alarm**

> Dark steampunk orchestral, 128 BPM, alarm and urgency. A repeating
> low brass warning figure like a ship's horn, industrial percussion, strings
> stabbing on the offbeat. Something enormous has grappled onto the hull. No
> vocals. Seamless loop.

### M6 · `music/boss_loop` — wave 12, the Colossus
**2:00 · 140 BPM · enormous**

> Dark steampunk orchestral boss battle, 140 BPM. Enormous and mechanical.
> Huge low brass, choir-like sustained strings (no actual voices), colossal
> slow percussion under fast string runs, a grinding metallic drone. A war
> machine the size of a building. No vocals. Seamless loop.

### M7 · `music/outcome_sting` — two one-shots, not loops
**Victory 0:12 · Defeat 0:10**

> **Victory:** Triumphant steampunk orchestral sting, 12 seconds. Brass fanfare
> resolving to a warm major chord, steam whistle flourish, clockwork settling.
> Ends clean.
>
> **Defeat:** Bleak steampunk orchestral sting, 10 seconds. Descending low
> brass, a great engine winding down and stopping, one last struck bell.
> Ends clean.

---

## 6 · The shape × element trick

The game is a 6 × 4 matrix — six shapes crossed with four elements, 24 casts.
**Do not author 24 sounds.** Author **6 shape bodies + 4 element tails** and let
the engine layer them, exactly the way the game itself is built. Ten files
covering twenty-four combinations, and every future shape or element costs one
file instead of four or six.

The engine plays them together from one call: body at t=0, element layer at
t=0 with its own gain, both detuned together by the `vary` amount so they stay
coherent.

**Shape body** = the mechanism. Metal, air, force. **No elemental colour at
all** — no fire, no ice, no electricity, no steam in these.

**Element tail** = the magic. Short, bright, layered on top. **No mechanism** —
no swing, no thump, no launch in these.

If a body sounds complete on its own it is wrong; if a tail sounds like a
weapon on its own it is wrong.

---

## 7 · SFX — ElevenLabs

ElevenLabs text-to-SFX. Ask for **3 variations of each**, pick the best, unless
marked *pick 3* — those ship as genuine variants and the engine round-robins.

Prompt discipline: name the material, the size and the space. "Metal" is
useless; "heavy brass mechanism, short, dry, close-mic'd" is a sound.

### 7.1 Shape bodies — `sfx/player/shape_*`

| File | Cue | Len | Prompt |
|---|---|---|---|
| `shape_cleave` | CLOSEHIT, 140° sweep, fires every ~0.36 s | **≤180 ms** | *Short heavy blade sweeping through air, close and dry, brass-weighted sabre, sharp whoosh with a metallic edge, no impact, no reverb tail* |
| `shape_lance` | LINE_BURST, piercing bolt | ≤260 ms | *A pneumatic harpoon launcher firing, sharp compressed-air punch with a metal rail ring, dry and close* |
| `shape_gale` | CONE, frontal cone | ≤400 ms | *A wide pressure blast venting forward, low airy whump broadening into a hiss, brass valve opening hard* |
| `shape_mortar` | RANGED_AOE, launch | ≤240 ms | *A short mortar tube firing a shell, hollow brass thunk with a rising departure, no explosion* |
| `shape_mortar_land` | RANGED_AOE, impact | ≤450 ms | *A heavy shell impacting a wooden ship deck, deep thud with splintering timber and a brief debris scatter* |
| `shape_whip` | CHAIN, arcs between targets | ≤200 ms | *A taut metal chain snapping out and catching, quick whip-crack with chain-link rattle, dry* |
| `shape_beam_start` | RAY, held beam onset | ≤200 ms | *A pressure valve opening into a sustained release, sharp charge-up snap into steady flow* |
| `shape_beam_loop` | RAY, sustains while held | **loop, 1.0 s** | *Sustained high-pressure steam jet under load, steady and even, seamless loop, no start or stop* |
| `shape_beam_end` | RAY, release | ≤300 ms | *A pressure valve slamming shut, steam cutting off with a metallic clank and a short decaying hiss* |

### 7.2 Element tails — `sfx/player/elem_*`

Layered over any body. Bright, short, no mechanism.

| File | Element | Len | Prompt |
|---|---|---|---|
| `elem_ember` | EMBER — burns 5/s, 3 stacks | ≤300 ms | *A burst of fire igniting, sharp fuel whoomph with crackling embers, close and dry, no wind, no impact* |
| `elem_frost` | FROST — slows 40% | ≤350 ms | *Ice crystallising fast, sharp glassy crackle with a bright shimmer, brittle and clean, no wind* |
| `elem_arc` | ARC — 20% stun, +1 jump | ≤250 ms | *A high-voltage electrical discharge, tight crackling zap with a bright snap, dry, no thunder* |
| `elem_steam` | STEAM — knockback | ≤320 ms | *A sharp burst of pressurised steam venting, quick hiss with a wet edge, close, no machinery* |

### 7.3 Impact and damage — `sfx/player/`

The most-heard sounds in the game. Get these right before anything else.

| File | Cue | Len | Notes / prompt |
|---|---|---|---|
| `hit` *(pick 3)* | `SFX.hit()` — every damaging connection | **≤120 ms** | *A solid impact on riveted metal plate, short dry thud with a brief metallic ring, close-mic'd, no reverb* |
| `crit` *(pick 3)* | `SFX.crit()` | ≤200 ms | *A sharp critical strike on metal, bright piercing ring over a hard impact, satisfying and clean* |
| `hurt` | `SFX.hurt()` — the captain is hit | ≤350 ms | *A heavy blow landing on leather and metal armour, dull impact with a strained creak, no voice* |
| `dash` | `SFX.dash()` — i-frame dash | ≤250 ms | *A short burst of compressed air propelling something fast, sharp whoosh with a mechanical release click* |
| `ready` | `SFX.ready()` — ability off cooldown | **≤90 ms** | *A small brass mechanism clicking into place, single crisp tick with a faint ring, very short* |
| `pickup` | `SFX.pickup()` — cog pickup | ≤200 ms | *Small brass gears and coins collected, bright pleasant metallic chime, quick* |

### 7.4 Enemies — `sfx/enemy/`

Roster: **SWARM** (gremlin, fast/fragile), **SCRAPPER** (automaton, melee grunt),
**GUNNER** (drone, ranged), **ARMORED** (furnace knight, slow tank),
**BOSS** (colossus).

| File | Cue | Len | Prompt |
|---|---|---|---|
| `death_light` *(pick 3)* | SWARM / SCRAPPER die | ≤300 ms | *A small clockwork automaton breaking apart, springs and gears scattering on a wooden deck, short* |
| `death_heavy` *(pick 2)* | ARMORED dies | ≤600 ms | *A large armoured machine collapsing, heavy metal crash with escaping steam and a dying furnace roar* |
| `shoot_drone` | GUNNER fires — `SFX.enemyShoot()` | ≤200 ms | *A small mechanical gun firing a bolt, tight compressed snap with an electric edge, dry* |
| `telegraph` | wind-up before an attack — `SFX.telegraph()` | ≤400 ms | *A mechanism winding up under tension, rising metallic strain, ominous, ends unresolved* |
| `slam` | ARMORED/BOSS ground slam — `SFX.slam()` | ≤700 ms | *An enormous metal foot slamming onto a ship deck, deep body-felt impact with timber groan and debris* |
| `boss_roar` | BOSS spawn / hulk break — `SFX.bossRoar()` | ≤1.8 s | *A colossal steam-powered war machine bellowing, vast metallic roar with furnace blast and grinding gears, terrifying scale* |
| `climb` **NEW** | a boarder cresting the rail | ≤400 ms | *Metal hooks and claws scraping over a wooden ship rail, scrabbling grip, short* |

### 7.5 Lanes — `sfx/lane/`

**Everything here is NEW.** These are the cues that make three lanes legible
when you can only look at one.

| File | Cue | Len | Prompt |
|---|---|---|---|
| `cannon_fire` | **your** deck cannon — *replaces the misused `enemyShoot`* | ≤450 ms | *A brass deck cannon firing, meaty percussive boom with a steam release and mechanical recoil, close and powerful* |
| `cannon_hurt` | turret taking damage | ≤250 ms | *Heavy impacts denting thick brass plate, dull structural clang, no destruction* |
| `cannon_down` | turret destroyed | ≤900 ms | *A brass cannon emplacement destroyed, structural collapse with a steam burst and metal debris, final* |
| `crew_muster` | reinforcements arrive — *replaces the misused `ready`* | ≤700 ms | *A ship's crew mustering below deck, boots on timber and a short brass whistle call, distant, purposeful* |
| `crew_attack` *(pick 3)* | crew swing | ≤180 ms | *A short cutlass swing and hit on metal, light and quick, dry* |
| `crew_down` *(pick 2)* | a crewman dies | ≤400 ms | *A body falling onto a wooden deck with dropped equipment, brief, no voice* |
| `hulk_grapple` | push wave begins, hulk latches on | ≤1.4 s | *Enormous iron grappling hooks biting into a ship's hull, deep structural groan with straining chains and splintering timber* |
| `hulk_hit` | chip damage on the hulk | ≤200 ms | *An impact on thick iron plating, deep dull clang with a long low ring, heavy* |
| `hulk_break` | hulk destroyed — *stops reusing `bossRoar`* | ≤2.0 s | *A massive iron boarding vessel breaking apart and falling away, catastrophic structural failure, tearing metal and collapsing timber, then a long drop* |
| `crossing` **NEW** | player passes through a cargo-run gap | ≤200 ms | *Footsteps passing quickly between stacked cargo crates, brief wooden creak, subtle* |

### 7.6 World and objective — `sfx/world/`

| File | Cue | Len | Prompt |
|---|---|---|---|
| `boiler_hurt` | `SFX.boiler()` — the objective is struck | ≤500 ms | *A large brass boiler struck hard, deep resonant bong with a pressure warning hiss, alarming* |
| `boiler_critical` **NEW** | Boiler below 25% — **loop, 2 s** | loop | *A steam boiler under critical pressure, urgent rhythmic hissing with a warning bell, seamless loop, anxious* |
| `wave_clear` | `SFX.waveClear()` | ≤1.2 s | *A ship's brass bell rung three times in triumph, clean and bright, resolving* |
| `wave_start` **NEW** | wave begins | ≤900 ms | *A ship's alarm klaxon sounding once, brass and urgent, storm wind behind it* |
| `amb_storm` **NEW** | bed — **loop, 30 s** | loop | *High-altitude storm wind with distant thunder, constant and wide, no rain, seamless loop* |
| `amb_ship` **NEW** | bed — **loop, 20 s** | loop | *An airship's engine room hum with rhythmic clockwork and creaking rigging, steady, seamless loop* |

*The two beds run continuously under everything at low gain (storm 0.22, ship
0.18) and are the single biggest cheap win for atmosphere.*

### 7.7 UI — `sfx/ui/`

Never positioned, never ducked. Dry, small, instant.

| File | Cue | Len | Prompt |
|---|---|---|---|
| `hover` | `SFX.uiHover()` | ≤70 ms | *A tiny brass tick, single soft mechanical click, very quiet and short* |
| `click` | `SFX.uiClick()` | ≤110 ms | *A brass toggle switch clicking firmly, single positive mechanical action* |
| `card_pick` | `SFX.cardPick()` — draft choice | ≤500 ms | *A heavy brass card locking into a mechanism, satisfying mechanical clunk with a bright confirming chime* |
| `card_deal` **NEW** | draft cards appear | ≤400 ms | *Three heavy cards dealt onto a wooden table with a mechanical whirr, quick succession* |
| `slot_unlock` **NEW** | ability slot unlocks (waves 3, 6) | ≤600 ms | *A brass lock mechanism releasing and a panel sliding open, rewarding, mechanical* |

---

## 8 · Voice — ElevenLabs

**The captain.** A woman, 30s, weathered, dry, unimpressed by danger. Not a
superhero; a working sky-pirate who has done this before. Think a ship's
officer under fire — clipped, competent, occasionally sardonic.

Suggested direction for voice selection: *mid-range female, slight rasp, dry
delivery, British or transatlantic, understated rather than heroic.*

Barks are **optional polish, lowest priority** — ship the game without them.
When they land, they are hard-limited: **one bark per 8 s minimum**, never
during a boss roar, never stacked. Nothing fatigues faster than a hero who
comments on everything.

| File | Trigger | Line |
|---|---|---|
| `vo/wave_start_1` | wave begins | "Here they come." |
| `vo/wave_start_2` | wave begins | "More of them. Lovely." |
| `vo/push_warning` | push wave | "They've grappled on — that thing has to go." |
| `vo/boiler_low` | Boiler < 25% | "The Boiler's taking it — get back here!" |
| `vo/lane_lost` | a turret falls | "Lane's open! Somebody cover it!" |
| `vo/low_health` | captain < 25% | "I'm hurt. Not done." |
| `vo/boss_spawn` | wave 12 | "...That's a big one." |
| `vo/victory` | run won | "Still flying. Good crew." |
| `vo/defeat` | run lost | "She's going down. I'm sorry." |

Deliver dry, no processing — the engine adds a short deck reverb so voice sits
in the same space as everything else.

---

## 9 · Integration — what Codex builds

Mirror the art pipeline exactly; it already works and the patterns are proven.

**9.1 `AUDIO_MANIFEST`** in a new `_audio_assets.js`, shaped like
`ASSET_MANIFEST`:

```js
const AUDIO_MANIFEST = {
  hit:  { file:'audio/sfx/player/hit.ogg', bus:'sfx', vary:0.06, max:4, variants:3 },
  m_combat_low: { file:'audio/music/combat_low.ogg', bus:'music',
                  loop:true, loopStart:0.000, loopEnd:105.000 },
  // ...
};
```

**9.2 Loader.** Fetch → `decodeAudioData` → `AudioBuffer`. Same opt-out flag
as art (`?audio=0`). **A failed fetch or decode must fall through to the
procedural cue silently** — no console spam, no missing-sound holes. Load SFX
up front, music lazily.

**9.3 Dispatch.** `SFX.hit()` and friends keep their names and call sites — all
20 of them, plus the new cues. Internally each becomes: *play the buffer if
loaded, else run the existing synth*. **No call site changes**, which means no
risk to gameplay code and the fallback is structural rather than remembered.

**9.4 Positioning.** `SFX.at(x, y, cue)` for world-space cues, computing pan
and attenuation per §4. Existing call sites that have coordinates available
should migrate to it; ones that do not keep playing centred.

**9.5 Music director.** A small state machine: title → combat tier by wave →
push → boss → outcome. 2 s equal-power crossfades. Duck per §4.

**9.6 Build integration.** Audio is external files like art, so it is subject
to the same rule as everything else: **only the live build gets it.** Frozen
builds keep their procedural audio, because that is how they shipped. Do not
touch `_core_patched.js` in a way that would force a rebuild of a frozen
version — the pin in `build.py` will refuse it, correctly.

---

## 10 · QA checklist

- [ ] Every cue fires with files **absent** — game is fully playable and audible
- [ ] Every cue fires with files **present** — no doubled procedural + sample
- [ ] Wave 11 with 25+ enemies: no clipping, no mud, voice caps holding
- [ ] Music loops with no seam, no click, no gap (check the decoded buffer, not the file)
- [ ] Crossfade between combat tiers is inaudible as a "change"
- [ ] A fight in the port lane is audible and correctly panned while looking at starboard
- [ ] Boiler critical loop starts and stops cleanly at the 25% boundary, no flutter at the threshold
- [ ] Mute (`M`) and volume (`−`/`=`) affect every bus including music and voice
- [ ] Tab away and back: `AudioContext` suspends and resumes, no stuck loops
- [ ] Total download within budget (§3); game is interactive before music finishes loading

---

## 11 · Order of work

Highest value first. Each row is shippable on its own.

| # | Work | Why first |
|---|---|---|
| 1 | Fix the six misused/missing cues in §1 | Costs nothing, removes active confusion. Deck cannon especially. |
| 2 | `amb_storm` + `amb_ship` beds | Two files, largest atmosphere gain per byte. |
| 3 | `hit`, `crit`, `death_light` | The most-heard sounds in the game. |
| 4 | Shape bodies + element tails (10 files) | Covers all 24 casts. |
| 5 | M2/M3/M4 combat tiers + director | The session gets a shape. |
| 6 | Lane cues (§7.5) | Makes the MOBA structure legible. |
| 7 | M1/M5/M6/M7, UI, remaining enemy cues | Completion. |
| 8 | Voice barks | Polish, cuttable. |
