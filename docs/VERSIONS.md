# SKYGEAR — the running log

**One page, kept current.** What each version did, why it did it, and what is
being considered for the next one. Every version gets an entry when it is cut;
the "Next" section at the bottom is edited continuously and is the only part
that is speculation.

The rule for an entry: **what changed, and what it was an answer to.** A change
nobody asked for and no measurement demanded is worth writing down as exactly
that, so the next person can tell taste from evidence.

Live: <https://alex-unconstrained.github.io/skygear/> · **v11** ·
earlier builds at `archive.html`, pinned to the bytes they shipped.

---

## v11 · The deck fights back — 2026-07-27 *(live)*

**Answered:** the first outside playtest of v10. One message: won with ~12%
lifesteal and "unkillable", wanted more space and more dashing, and "the kegs
are there but dont do anything". Then, separately: enemy projectiles are hard to
track. And after the cut: enemies group up too much.

- **Pressure and the vent.** A gauge that fills from hits landed inside your own
  reach and from being crowded. Full, it vents — 40 damage and 340 knock in a
  215 ring, and 15 health back. Healing is now earned by closing.
- **Healing rebuilt.** Bloodsteam is close-range only (210 units) and all
  healing from damage is capped at 9 hp/s as a refilling budget. The vent
  deliberately does not build its own pressure; the first working version
  refilled the gauge from its own blast, which was the v10 failure in new parts.
- **A destructible deck.** Steam kegs (34 hp, a 0.45s fuse, 78 damage in 175
  units, to everything including you), crates that spill salvage, lanterns and
  braziers that spill fire and take their light with them. Sixteen more props
  stowed *in* the lanes, which v10 could not do because props were permanent
  walls. The crew re-stow the deck between waves.
- **More open, more dashing.** Deck 1560 → 1680, cargo runs 120 → 96 thick, a
  third cross-passage aft, walkable lane 388 → 452. Two dash charges from the
  first second, 1.00s cooldown minus 0.30s per close kill, 30 base dash damage,
  and dashing through a keg lights it.
- **Readable enemy fire.** Bolts were tesla blue — the player's own colour
  family — with no ground shadow and no trail. Now hostile-coloured, 18% slower,
  shadowed on the deck, trailed over nine samples, and a shooter draws its
  firing line for the whole windup. Damage unchanged.
- **Crowds that read as crowds.** Separation now has a pad of personal space
  outside the bodies (gentle inside it, hard inside each other), and enemies
  approach a target's shoulder rather than its centre, so a pack arrives as an
  arc instead of a column.
- **Audio, most of it.** 54 SFX cues and 67 voice takes generated and edited to
  the spec's budgets; two music tracks placed as the boss loop and waves 9–11.
  Everything encoded to Vorbis, which took the delivered audio from 23.8 MB to
  10.7 MB.
- **Front page.** One build on offer; v2–v10 moved to `archive.html`.

**Harness: 42 → 58 checks.** New groups: `deck` (ordnance), `close` (the
pressure loop), `crowd` (measured spacing), `audio` (the index decodes, nothing
404s).

**Known open:** total payload 34.7 MB against a 30 MB target — art is 24 MB of
it and has not had a compression pass since the manifest filled up. 15
animation cycles outstanding. Five music slots outstanding. Zero cold
playtests of v11.

---

## v10 · For a stranger — 2026-07-27

**Answered:** every build so far had been made for two people who already knew
how it worked.

Instant start on procedural art with assets streaming in priority order; seeded
runs (`?seed=`) with the seed on the results screen; a run report and a local
log of the last ten runs; an opening weapon you choose rather than are issued;
contextual first-run prompts; a real title screen; a pause menu with per-bus
volume, remappable keys, reduced motion and HUD scale; a results screen with the
build shown as its shape × element grid; lane readout with redundant shape;
before → after numbers on draft cards; a two-beat boss.

Also fixed: audio dying silently after a tab switch (`unlock()` returned before
its own `resume()`); the game reporting "24 combinations" for three versions;
four shapes sharing one HUD icon.

**First outside playtest happened here.** Everything in v11 comes from it.

---

## v9 · Score & passives — 2026-07-26

Music, crossfade-looped from the sustained middle so it never drops to silence.
Passive skills — Field, Pulse, Sentry — which take a slot and cross with all
four elements, so a four-skill build no longer means four buttons.

## v8 · Builds — 2026-07-26

**Answered:** a playtester finished all twelve waves using exactly one ability,
because every upgrade funnelled into it. A slot unlocking now offers three
*weapons* — you pick which, not whether — and element-wide cards make committing
to one colour a build rather than a dilution.

## v7 · Sound — 2026-07-26

The audio pass: a sample layer over the synth, and six cues that were plain
wrong. Your own deck cannon had been firing the *enemy* gunshot.

## v6 · Real basic attack — 2026-07-26

The auto-attack became the Ember Cleave itself — same arc, element and crit —
rather than a weaker generic flick beside it. Both mouse buttons freed. A second
cargo passage opened forward. First build with the painted art on by default.

## v5 · Lanes — 2026-07-26

The MOBA restructure: three hard-separated lanes, a deck cannon gating each,
your crew pushing up them, the Boiler moved to the stern like a nexus, and two
push waves where a boarding hulk grapples on and has to be broken.

## v4 · Snappy — 2026-07-26

The responsiveness pass: 120 Hz sim, input buffering, per-type hit-stop (a flat
70ms was freezing 46% of wall time at wave 11), a true auto-attack, dash on
Space.

## v3 · See-through — 2026-07-26

**Answered:** the first playtest, which rejected v2 on one thing — the Boiler you
were defending hid the fight on its far side. Longer deck, bounded follow
camera, and an x-ray pass drawing anything occluded as a silhouette.

## v2 · First restyle — 2026-07-26

The first three-quarter attempt. Fixed camera, short deck, no see-through. Kept
as the control for the v3 comparison.

## Classic · the benchmark

Straight top-down, daylight brass-and-khaki, whole deck always visible. The
build the first tester preferred, and still the thing to beat on legibility.

---

## Next · v12, under consideration

**Nothing here is committed.** The playtests decide the order, and the first
question they answer is whether v11's central bet — that close range is now the
better way to play — actually landed.

### If the close-quarters loop worked

Then v12 is **content, not systems**:

1. **Animation.** 15 cycles outstanding, all wired: a delivered strip needs no
   code. Priority is `scrapper_attack`/`idle`, then crew, then armoured/swarm,
   then gunner, then the Colossus. Read `ASSET-GENERATION.md` §6b before
   spending a video generation — idles do not close their loops and are
   `pingpong` by design.
2. **The five remaining music slots** — `title_loop` first, `combat_mid` second.
   Briefs and lyric starters are in `MUSIC-BRIEF.md`; these are made by hand.
3. **A compression pass on the art.** 24 MB of PNG against a 30 MB total
   budget, and the audio just proved what an encode is worth (23.8 → 10.7 MB).
4. **The Colossus encounter, properly.** Two beats exist; the second beat reuses
   telegraph and push rules rather than having anything of its own.

### If it did not

Then v12 is a **balance rework**, and the specific things to look at are: the
vent's cadence (1.1s floor, 15 hp — probably too generous if it landed at all),
whether the idle pressure build makes closing free, and whether kegs made ranged
play *stronger* by letting a mortar detonate the deck from safety.

### Carried, regardless of the answer

- **The human work.** Five cold playtests, a slow laptop, loudness on three
  output systems, photosensitivity review of the keg chains. This has been the
  largest item in the project for two versions.
- **Safari.** The harness covers Chromium and Firefox; Safari is "if available"
  and has never run.
- **`crew_muster` variants.** Regenerated in v11 as a single take; it wants
  three so the muster call does not repeat.
- **Element legibility without hue** was addressed with shape motifs in v10 and
  has never been checked by anyone who cannot see colour.

### Ideas parked deliberately

Not rejected, not scheduled: a second captain, endless mode, meta-progression,
relics, currencies, accounts, leaderboards, multiplayer, touch controls,
procedural maps, a renderer rewrite. The reasoning in `V10-PLAN.md` §0 still
holds — they are ways to postpone the moment this game becomes excellent.

**A port to Godot** was asked about directly and answered in `V11-PLAN.md` §6:
stay in the browser, with four named triggers that would change the answer.
