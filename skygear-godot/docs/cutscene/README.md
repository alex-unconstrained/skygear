# SkyGear — opening cinematic, the planning package (SG-238)

A ≤60-second film that plays at the start of the game and answers, in order:
**who they are** (a young sky-corsair captain and his crew, alone on an airship
in a storm-dusk sky), **why they are doing this** (the Boiler — the ship's
burning heart — is what keeps her aloft, and the machines are coming to tear it
out), and **what the game is** (hold the deck through waves of boarders, fight
beside your crew and cannons, keep the Boiler lit, face the Colossus).

Nothing in this folder renders anything. It is the complete spec for a
generation session: the storyboard, one paste-ready prompt per shot in
`prompts/`, and the reference-image manifest in `refs/README.md`. Someone with
ComfyUI open should be able to execute it without re-deciding anything.

---

## 0 · The generator, and the settings block that works

Clips are made with **MiniMax H3 ref2va running locally in ComfyUI**. The owner
confirmed this exact node configuration produced excellent output — reproduce
it verbatim, do not re-derive it:

- `MiniMaxH3ReferenceToVideo`, `ref_image_size: "match"`
- `BasicGuider` — **NO CFG, guidance-free**. Do NOT use `KSampler` with a cfg
  value; that produced a cooked, over-contrasted look.
- `KSamplerSelect: res_multistep`
- `BasicScheduler: simple, 20 steps, denoise 1.0`
- `RandomNoise` → `SamplerCustomAdvanced`
- **No** `MiniMaxH3SigmaShift` node.
- API note: autogrow reference keys are DOTTED — `ref_images.ref_image_0`,
  not `ref_image_0`. The bare form validates and then dies at execute().

**Native resolution 1344x768. 24 fps. Clip length must sit on the 17k+5 frame
grid** (`(length - 5) % 17 == 0`), minimum 124 frames (~5.17 s), trained range
~124–362 frames. Every length below is on-grid and verified: 124 → 119 = 17×7;
141 → 136 = 17×8.

**Prompt style: directive.** Tell the model what each reference is FOR, then
describe the shot ("Use ref_image_0 for the exact sky, palette and painting
style. Use ref_image_1 for the exact character and costume — same face, same
coat, no drifting features. The video: ..."). This is what keeps identity
locked across a multi-shot film. Every file in `prompts/` is written this way.

---

## 1 · The storyboard

Nine shots. **Generated footage: 1201 frames = 50.04 s at 24 fps.** The editor
adds a black title card (a still, not a generated clip) of at most 6 s at the
end; cross-dissolves eat footage rather than adding it. **Worst-case assembled
runtime ≈ 56 s — under the 60 s hard ceiling, with ~4 s of slack for the edit.**

Grid check per shot: 124 = 17×7+5 ✓ · 141 = 17×8+5 ✓. Sum:
124+141+141+141+124+141+124+141+124 = **1201 frames**.

| # | Frames | Sec | The viewer sees | Answers | References (see `refs/README.md`) | Audio (game assets; H3 audio per §3) | Cut into next |
|---|--------|-----|-----------------|---------|-----------------------------------|--------------------------------------|---------------|
| 1 | 124 | 5.17 | Cold open. The painted storm-dusk sky itself: moon burning through a well of cloud upper-left, violet mid-field, ember fire on the low horizon. Clouds drift; far below the moon a tiny airship crosses, lanterns lit. | WHO (the world) | R0 sky_backdrop (style+content), R3 airship_distant | `sfx/world/amb_storm.ogg` under everything; no music yet. H3 audio: audition, duck to −18 dB if the wind is good. | Slow drift ends on the distant ship; **dissolve** (12f) into shot 2, which begins on the same ship much closer — the dissolve sells the approach. |
| 2 | 141 | 5.88 | The ship. Camera glides along her lamplit flank toward the bow; the brass dragon figurehead passes close, lanterns glowing, rigging taut in the wind, the ember horizon behind her. | WHO (the ship) | R0 sky_backdrop, R3 airship_distant, R4 bow_prow | `sfx/world/amb_ship.ogg` fades in over the storm; **`music/combat_low.mp3` starts here**, low. | Glide carries forward past the figurehead; **hard cut on motion** to shot 3 (the rail from on deck) — cutting mid-move hides the switch from painted ship to deck-scale detail. |
| 3 | 141 | 5.88 | The Captain. A young man at the bow rail in a red brass-buckled greatcoat, brass goggles pushed up into spiked brown hair, ornate brass gauntlet resting on the rail, large curved cutlass at his hip. Wind in the coat. He turns his head, past the camera, toward the stern. | WHO (the hero) | R0 sky_backdrop, R1a corsair_front_idle, R1b corsair_front_attack | Music continues. No VO — the brief's rule holds: the captain is not a narrator. H3 audio muted. | His head-turn toward the stern **motivates the cut**: shot 4 is what he is looking at. Cut at the end of the turn. |
| 4 | 141 | 5.88 | The Boiler. The ship's heart at the stern: a riveted iron furnace, firebox blazing orange through its grate, gauges trembling, two crewmen tending it. The captain's brass gauntlet comes to rest on the warm casing. Firelight on brass. | WHY (what must be kept alit) | R0 sky_backdrop, R5 staged boiler frame, R2 crew_front_attack, R1a corsair (gauntlet/costume) | Music `combat_low` continues; `sfx/world/boiler_hurt.ogg` is NOT used (it's damage) — instead low `amb_ship.ogg` close-up bed. H3 audio muted. | **Cut on impact**: the first frame of shot 5 is the hulk SLAMMING the rail — the loudest cut in the film, placed exactly where the story turns. `sfx/lane/hulk_grapple.ogg` on the cut. |
| 5 | 124 | 5.17 | The threat. An armoured boarding hulk — black iron, brass straps, twin stacks — slams onto the ship's rail; its plates hinge open on a furnace-red core, ramps drop, and brass automatons pour over the gunwale onto the deck. | WHY → WHAT (they come for the engine) | R0 sky_backdrop, R6a hulk_sealed, R6b hulk_open, R7 automaton_front_attack | `hulk_grapple.ogg` on frame 1, `hulk_break.ogg` as plates open, `sfx/enemy/climb.ogg`. **VO `first_board`** (sheet line: "They're over the rail.") — see §4, pending SG-228 recast. **`music/combat_high.mp3` takes over here.** H3 audio: audition the metal impact, duck under the game SFX. | Automatons surge toward camera; **hard cut on their charge** into shot 6, the captain already mid-swing — the collision happens across the cut, so the two casts never share a frame and cannot drift against each other. |
| 6 | 141 | 5.88 | The fight. The captain carves an ember-orange crescent through two automatons — sparks, embers, the cutlass trailing fire; behind him crewmen charge up the lane and a deck cannon fires, muzzle flash lighting the smoke. | WHAT (hold the deck, fight beside crew and cannons) | R0 sky_backdrop, R1b corsair_front_attack, R7 automaton_front_attack, R2 crew_front_attack, R8 cannon_deck, R5b staged deck frame | `combat_high` driving; `sfx/player/hit_*.ogg` ×2 on the swing beats, `sfx/lane/cannon_fire_1.ogg` on the flash, **VO `crew_muster`** (sheet line: "With you, Captain!") — crew takes are unaffected by SG-228. H3 audio muted. | Cannon flash whites the right of frame; **cut on the flash** to shot 7 — a flash cut absorbs any palette wobble between the two busiest shots. |
| 7 | 124 | 5.17 | The heavy. A furnace knight — dome-helmed boiler armour, firebox chest, huge bearded axe — bears down and swings; the captain dashes under the arc, coat streaming, embers off the blade's wake. | WHAT (readable danger, dodge it) | R0 sky_backdrop, R9 furnace_knight_front_attack, R1b corsair_front_attack | `combat_high` continues; `sfx/enemy/telegraph.ogg` as the axe winds, `sfx/enemy/slam.ogg` on the miss, `sfx/player/dash.ogg`. H3 audio muted. | The axe hits the deck in a burst of steam and embers; **cut inside the steam** to shot 8 — the whiteout hides the scale jump to the Colossus. |
| 8 | 141 | 5.88 | The Colossus. Over the bow it rises — a brass-and-iron giant, furnace grate blazing in its chest, single orange eye, shoulder cannons against the storm. It plants one anchor-clawed foot on the deck; everything shakes. | WHAT + WHY made explicit | R0 sky_backdrop, R10 colossus_front_idle, R4 bow_prow, R5c staged colossus_arrival frame | **`music/boss_loop.mp3` slams in.** `sfx/enemy/boss_roar.ogg` as it crests. **VO `boss_arrive`** — sheet line: **"GIVE ME THE ENGINE."** (audition `voice/boss/arrive_1.ogg` and `arrive_2.ogg` for the take that carries this line; the other sheet line is "YOUR DECK IS SCRAP."). This one recorded line is the film's whole motive, said by the enemy. H3 audio: audition its rumble, duck under boss_loop. | The Colossus's eye flares; **cut on the flare** to shot 9, the reverse: the one standing against it. |
| 9 | 124 | 5.17 | The stand. The captain plants himself between the Colossus (soft, huge, out of focus in the foreground edges) and the Boiler's glow behind him, raises the cutlass — ember light down the blade — and the camera pushes slowly in on his set face. Cut to black. | WHAT (this is the fight) / WHO (bookend) | R0 sky_backdrop, R1b corsair_front_attack, R1c corsair_back_idle, R5 staged boiler frame | `boss_loop` continues under; **VO `wave_start`** (sheet line: "Hold the deck.") as his answer to the Colossus — pending SG-228 recast. On the cut to black: `sfx/world/wave_start.ogg`. | **Cut to black.** Title card (editor-made still, not generated): SKYGEAR in the game's brass lettering over black, `boss_loop` tail ringing out, ≤6 s. Then the title screen — whose music entry point should feel continuous. |

### The three questions, mapped

- **Who they are** — shots 1–3 (a lone lamplit airship in an endless storm-dusk;
  a young captain in a red greatcoat), bookended by shot 9.
- **Why they are doing this** — shots 4–5 set it (the Boiler is the ship's
  burning heart; the machines board to take it), and shot 8 says it out loud in
  the enemy's own recorded line: **"GIVE ME THE ENGINE."** The captain's answer
  is `wave_start`'s "Hold the deck."
- **What the game is** — shots 5–9: twelve waves of boarders off hulks, cleave
  and dash, crew and deck cannons fighting beside you, the Boiler behind you,
  the Colossus at the end.

---

## 2 · Continuity — how the shots hold together

**Palette and style.** `assets/art/env/sky_backdrop.png` is `ref_image_0` in
every single prompt, always with the same directive sentence, and every prompt
repeats the same light recipe in words: *moonlight cool and silver from the
upper left, ember-orange glow from the lower right, violet storm-dusk
mid-field*. On deck the ember key is re-motivated by braziers, the Boiler and
firebox chests, so the warm/cool split never has to change direction between
sky shots and deck shots.

**The captain's identity.** He appears in five shots (3, 4, 6, 7, 9) and every
one of them carries the SAME two references — `corsair_front_idle.png` and
`corsair_front_attack.png` (plus `back_idle` where he is seen from behind) —
with the same directive sentence: same face, same red brass-buckled greatcoat,
same goggles pushed up into spiked brown hair, same brass gauntlet, same curved
cutlass, no drifting features. Do not paraphrase the costume differently
between prompts; the wording is part of the lock.

**Geography.** One rule, held in every deck shot: **the threat comes from the
bow (far/up-screen), the Boiler is astern (near/down-screen), and the captain
faces up-screen.** This matches the game's own orientation (boarders arrive at
the spawn line, the Boiler is the stern objective), so the film teaches the
player the map before they touch it.

**Where the cuts hide the seams.** Every transition is placed on an event, and
each hides a specific discontinuity: the shot 1→2 dissolve hides the change in
the ship's rendered scale; 2→3 cuts on camera motion to hide painted-ship →
deck-detail; 3→4 is a motivated eyeline cut (his turn) so the two interiors
never need to match; 4→5 cuts on the hulk's impact so the calm and the violence
never share a lighting state; 5→6 cuts on the charge so the automatons'
approach and the captain's swing are never in one continuous cast; 6→7 cuts on
a muzzle flash; 7→8 cuts inside a steam burst to hide the Colossus scale jump;
8→9 cuts on the eye-flare to the reverse angle. **No two adjacent shots depend
on H3 matching motion across the cut** — only palette and identity, which the
references carry.

**What NOT to feed it.** Gameplay screenshots with HUD, and anything with flat
deck lighting, dragged an earlier attempt down — the aesthetic target is the
hand-authored art. The two staged frames specified in `refs/README.md` are
allowed because `cutscene_lab.gd` renders the real deck through the real lens
with no interface; they are composition/geometry references, always subordinate
to `sky_backdrop.png` for palette. And `assets/art/ui/portrait_corsair.png` is
**banned** — see §5.

---

## 3 · Audio plan

H3 generates audio with every clip. **Default: MUTE it and build the mix from
the game's own audio.** Exceptions, all "audition, keep only if good, duck to
−18 dB under the game mix": shot 1 (wind), shot 5 (the metal impact), shot 8
(the rumble). Nothing generated ever carries a voice — if H3 invents speech or
vocal-ish sound, mute that clip's audio unconditionally.

**Music arc — the three tracks that exist, all three used:**

| Span | Track | Note |
|---|---|---|
| Shots 1–2a | none — `amb_storm.ogg` / `amb_ship.ogg` only | Cold open earns the music's entrance. |
| Shots 2–4 | `music/combat_low.mp3` | Fade in under shot 2, hold low. |
| Shots 5–7 | `music/combat_high.mp3` | Enters ON the hulk impact cut. |
| Shots 8–9 + title | `music/boss_loop.mp3` | Slams in with the Colossus; its tail rings over the title card. |

**SFX pulls** (all real files in `assets/audio/sfx/`): `world/amb_storm.ogg`,
`world/amb_ship.ogg`, `lane/hulk_grapple.ogg`, `lane/hulk_break.ogg`,
`enemy/climb.ogg`, `player/hit_1..5.ogg`, `lane/cannon_fire_1.ogg`,
`enemy/telegraph.ogg`, `enemy/slam.ogg`, `player/dash.ogg`,
`enemy/boss_roar.ogg`, `world/wave_start.ogg`.

**Voice — assigned by KEY, with the sheet line quoted.** The line sheet is
`docs/VOICE-BRIEF.md` §4 (repo root `docs/`, not this project's) — the engine
key map is `scripts/voice.gd::LINES`. The sheet's own rule: every file is *a
take, not a script* — deliveries may be reworded — so **audition the actual
.ogg before locking a subtitle or an edit point.**

| Shot | Key | Files | Sheet line used | Status |
|---|---|---|---|---|
| 5 | `first_board` | `voice/captain/first_board_1..3.ogg` | "They're over the rail." | **PENDING SG-228** — see below |
| 6 | `crew_muster` | `voice/crew/muster_1..4.ogg` | "With you, Captain!" | Usable now — crew casting is unaffected |
| 8 | `boss_arrive` | `voice/boss/arrive_1.ogg`, `arrive_2.ogg` | **"GIVE ME THE ENGINE."** (alternate take: "YOUR DECK IS SCRAP.") | Usable now |
| 9 | `wave_start` | `voice/captain/wave_start_1..4.ogg` | "Hold the deck." | **PENDING SG-228** |

**The SG-228 dependency, said plainly:** the owner ruled 2026-08-11 that the
captain is **male and young**, matching the sprite and model; all 50 existing
`voice/captain/` takes are the retired female casting and are queued for
regeneration (board SG-228, gated on the owner's go — it costs ElevenLabs
money). **Do not cut the film's final audio with the current captain takes.**
The two captain lines above are assigned by key so the regenerated takes drop
straight in. If the recast has not happened when the film is cut, ship the film
with only `crew_muster` and `boss_arrive` — it works without the captain
speaking (two lines were chosen, not load-bearing narration, for exactly this
reason). **The Boilerwright has no voice folder at all** (every player-facing
key points at `captain/`), so nothing in this film uses Boilerwright VO.

**NEW VO NEEDED — none required.** The film closes on recorded material. One
optional line is flagged for the owner in §6 if he wants a spoken motive in the
captain's own voice; it does not exist as a take and is NOT storyboarded.

---

## 4 · Generation order and identity risk

Generate in this order: **3 → 6 → 9 → 7 → 4** (the five captain shots, so his
identity can be judged early and re-rolled cheaply), then **5 → 8** (creature
shots), then **1 → 2** (the safest, sky and ship). If the captain drifts across
3/6/9, re-roll the drifter before generating anything else — five consistent
captains is the film's hardest requirement. Per the Meshy two-strike rule's
spirit: two failed rolls on the same shot → stop and escalate with the frames
rather than burning the night on seeds.

**A proportion decision the owner must make before shot 3 is generated** — see
§6, question 1.

---

## 5 · Flagged inconsistency — the portrait

`assets/art/ui/portrait_corsair.png` (a blue-coated, red-haired woman) does
**not** match the hero. `assets/art/heroes/corsair_front_attack.png` and the 3D
`captain` model agree with each other — a red brass-buckled greatcoat, brass
goggles pushed up into spiked brown hair, an ornate brass gauntlet, a large
curved cutlass, and a young **male** figure, which the owner confirmed as
correct on 2026-08-11 (board **SG-228**: *"The captain is supposed to be male
throughout"*; the portrait needs replacing, not recolouring). **The
sprite/model look is the identity reference for this film. The portrait must
not be used as a style or identity reference for anything.**

---

## 6 · Open questions for the owner

1. **Proportions.** The hero sprite is stylized/chibi-proportioned (large head,
   compact body). Keeping it means the film's captain reads exactly like the
   game's art and identity-locks trivially — but a 60 s cinematic of a chibi
   hero has a different tone than the painted sky suggests. Options:
   **(a) keep the sprite proportions** (default — the prompts as written do
   this, and it is the identity-safe choice), or **(b)** add one sentence to
   the captain prompts asking for "naturalistic heroic proportions, same face,
   same costume" — tonal win, real drift risk across five shots. Pick before
   shot 3 is rolled.
2. **The motive, canonically.** No design doc states WHY the machines board or
   who the captain is beyond "a sky-pirate captain" (VOICE-BRIEF §2) — the
   only recorded motive in the game is the Colossus's own line, "GIVE ME THE
   ENGINE," and the film is built so that line carries it. If you want more
   canon than that, pick one (the film as storyboarded is compatible with all
   three, so this does not block generation): **(a) The last fires** — Boilers
   are scarce and dying, the machine fleets strip living ships for engines;
   hers is one of the last lit. **(b) The prize** — he stole this ship (he IS
   a sky-corsair) and its former masters, the machines, have come to take
   their engine back. **(c) The storm** — below the cloud deck there is no
   landing left; the Boiler is simply survival, and the hulks are wreckers who
   live on what falls.
3. **Captain VO timing.** Cut the film without captain lines now, or wait for
   the SG-228 recast so "They're over the rail." and "Hold the deck." are in
   it from the first assembly? (§3 makes it drop-in either way.)
4. **Title card.** The plan ends on an editor-made SKYGEAR card over black
   (≤6 s inside the ceiling). Approve, or supply/commission a title treatment
   — the menu's painted brass banner style (`docs/MENU-DESIGN.md`) is the
   obvious source.
5. **The two staged reference frames** (`refs/README.md` §staged) need ~2
   minutes of GPU to capture with `cutscene_lab.gd` / `model_lab.gd` when the
   GPU is free. Shots 4, 6 and 8 want them; shots 1–3, 5, 7, 9 can generate
   without them.

---

## 7 · Editing notes

- Assemble at 1344×768/24 fps (the generator's native raster); master the
  final to 1920×1080 by upscale-letterbox or a 2× lattice upscaler AFTER the
  cut is locked, never per-clip.
- Dissolve only at 1→2 (12 frames). Every other cut is hard, on the event
  named in the storyboard table.
- Duck `combat_*`/`boss_loop` 4 dB under any VO line (matching
  `voice.gd`'s own ducking behaviour in-game, `audio.speaking`).
- The film should hand off to the title screen with `boss_loop`'s tail still
  ringing — audition whether the title's own music entry needs a beat of
  silence first.
- Trims to enforce the ceiling come out of shots 2 and 4 first (each has ~1 s
  of air by design); never trim shot 8.
