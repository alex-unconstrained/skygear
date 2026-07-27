# SKYGEAR v10 — the version strangers play

Written 2026-07-27, against v9. Codex is proposing in parallel; §11 says where I
expect its proposal to be better than mine and where I would defer to it.

---

## 1 · What changes about v10

Every version so far was built for two people who already know how it works.
v10 is the first one built for someone who has never seen it, will not read
anything, is on an unknown machine, and will leave the moment it feels broken.

That reframes the work. The biggest wins in v10 are not features. They are the
difference between a stranger reaching wave 3 and a stranger closing the tab.

**One test to hold everything against:** a person you have never met opens the
link on their laptop, plays without asking you a single question, finishes a
run, and can tell someone else what the game is. Nothing below matters more than
that sentence.

The good news is the hard part is done. The game is complete, balanced enough
that a first-time player cleared 12/12, and it has a real hook. What it does not
have is a front door.

---

## 2 · The 24 MB problem — and why it is nearly solved already

Measured today:

| | size | |
|---|---|---|
| build HTML | 0.33 MB | |
| art | 19.07 MB | 32 of 67 stills, plus 3.90 MB of animation |
| audio | 4.59 MB | 6 of 55 cues; 4.0 MB of that is the one music track |
| **first load** | **23.99 MB** | **19 s at 10 Mbit, 64 s at 3 Mbit** |

With "animate everything" approved, animation goes from 3.9 MB to roughly 14 MB.
**First load lands near 34 MB — 27 seconds on a good connection, a minute and a
half on a mediocre one.** Nobody waits that long at a black screen, and right
now that is literally what they get.

**But the architecture already solved this and we have not cashed it in.** Every
asset has a procedural fallback; the game is fully playable with zero files.
So the fix is not a loading screen, it is *not needing one*:

- **Start the game instantly on procedural art.** First frame in under a second.
- **Stream assets in priority order and swap them live** — captain, then enemies,
  then the deck, then props, then fx and ui. The swap is already invisible
  because `charImage()` picks per frame.
- **Load audio the same way.** Cues are already dispatch-on-demand; music is
  already lazy.
- A small unobtrusive indicator while it fills in, and nothing more.

This is maybe a day of work and it is the single highest-value thing in v10. It
turns a 27-second black screen into a game that starts immediately and quietly
gets prettier. **Do this first.** Everything else in the roadmap assumes it.

Secondary payload work, in value order:
- Delete `assets-49/` — 0.98 MB of a decision settled long ago.
- Re-encode the music: 4.0 MB at 64 kbps is both too big and too thin. Either
  ~2 MB at 96 kbps mono, or accept it and lazy-load harder.
- Atlas the animations per the brief — 33-35% measured, already specced.
- Consider dropping still art for anything that has a full animation cycle.

---

## 3 · The first ninety seconds

This is where v10 is won or lost, and it is currently the weakest part of the
game. A stranger today gets a wall of text on the title screen and then a fight.

### 3.1 Choose your opening (high value, low cost)

Right now every run starts with Frost Mortar. **Start instead by choosing one of
three skills** — different shapes, different elements.

Three things fall out of one small change:
- The pitch of the game — *every skill is a shape crossed with an element* — is
  the first thing a player touches instead of something they infer by wave 6.
- Runs stop opening identically, which is most of what replay value is.
- It reuses `rollSkillCards()` wholesale. This is nearly free.

### 3.2 Teach at the moment, not up front

Nobody reads the panel. Replace it with first-time-only prompts fired at the
moment each thing first happens, each one sentence, each dismissed by playing:

| Moment | What it says |
|---|---|
| First boarder climbs the rail | "They board at the bow. Don't let them reach the Boiler." |
| First draft | "Every skill is a shape crossed with an element. Pick one." |
| First slot unlock | "A weapon, not an upgrade. Which, not whether." |
| First passive drafted | "This one fights on its own." |
| First push wave | "Their hulk is open. Break it — the deck can wait." |
| Boiler below 50% | "The Boiler is what you're defending. It does not heal." |

Stored in localStorage so a returning player never sees them again.

### 3.3 The title screen has one job

Not a manual. A name, a look, and a button. Move controls into a pause/settings
panel where someone can go and find them.

---

## 4 · Surviving contact

Everything here is invisible when it works, and fatal when it does not.

### 4.1 The colourblind problem is real and it is central

**The four elements are distinguished by colour alone** — teal, orange, blue,
purple. That is not decoration, it is the core mechanic, and roughly 8% of men
cannot reliably separate those pairs. A game about elements that cannot be
played by someone with deuteranopia is not ready to show people.

Fix: give each element a **shape motif** carried on its ground rings, glyphs and
card icons, so element is legible without hue —

| Element | Motif |
|---|---|
| Ember | notched flame / triangular teeth |
| Frost | crystal / hexagonal |
| Arc | zigzag / chevron |
| Steam | round cloud / dotted |

Plus a high-contrast toggle. This is genuinely not much work and it is the
difference between "playable" and "not" for a real slice of players.

### 4.2 Reduced motion

Hit-stop, trauma shake, white flashes and screen-fills are tuned aggressively —
deliberately, and it feels great. It is also exactly the profile that triggers
motion sickness and, at the flash end, is a photosensitivity concern. **A
reduced-motion toggle** that halves trauma, removes full-screen flashes and
shortens hit-stop. Default it on if `prefers-reduced-motion` is set.

### 4.3 Input and settings

- Remappable keys. WASD is not universal — AZERTY exists, and left-handed
  players exist.
- A real pause menu: volume per bus (the buses are already there), the
  accessibility toggles, restart, and the controls reference from §3.3.
- Gamepad would be a genuine delight given the auto-attack already handles
  facing, and is cheap via the Gamepad API. Worth considering.

### 4.4 Devices and browsers

Only ever tested in Chrome on one machine. Before showing anyone:
- Firefox and Safari — Safari especially, its audio and canvas behaviour differ
- A small laptop screen — the HUD scales, but nobody has confirmed at 1366×768
- **Touch: decide deliberately.** Full touch support is a real project. But the
  game has an auto-attack and passives, so a stick-to-move, tap-to-aim build is
  more plausible here than in most action games. If that is not v10, then
  **detect and say so** rather than serving a broken experience.
- Real hardware perf. Measured 1.9 ms per frame on this machine; that number is
  meaningless for a five-year-old laptop. The F3 readout exists — someone needs
  to actually read it on a slow machine.

### 4.5 Failure modes

- What happens if an asset 404s mid-run? (Handled — but never tested under a
  flaky connection.)
- Backgrounding the tab. I flagged this as an unchecked risk and then checked
  it. The **simulation is fine** — the frame delta is clamped to 100 ms, catch-up
  is capped at ten steps and the accumulator is drained, so there is no spiral.
  The **audio was not fine**: `unlock()` returned early once audio had started,
  which made its own `resume()` call unreachable, so a single alt-tab killed all
  sound for the rest of the session — silently, because every cue kept reporting
  success while producing nothing. Fixed in v9 (resume first and unconditionally,
  plus `visibilitychange`/`focus` handlers and a once-a-second retry). The lesson
  generalises: **audio fails quiet, so it needs checking rather than noticing.**
- What happens on a second monitor at 4K? Draw cost scales with viewport.

---

## 5 · Why you would play it twice

A stranger who finishes a run and closes the tab is a failure even if they
enjoyed it. Right now there is nothing at the end.

### 5.1 The run summary

An end screen worth looking at: wave reached, time, kills, best combo, the build
you assembled shown as its shape × element grid, and the cards you took. This
also makes the matrix legible in hindsight — *this is what I built* — which is
the thing that makes someone want to build something else.

### 5.2 Records, locally

localStorage: best wave, fastest clear, runs played, elements mastered. No
server, no account. A returning player has something to beat.

### 5.3 Difficulty tiers

Three. Our one external playtester cleared 12/12 first attempt, which says the
current curve is a good *default* and a poor *ceiling*. A harder tier is the
reason a good player comes back, and an easier one widens who finishes at all.

### 5.4 Endless

After wave 12, keep going with scaling waves until you die. Cheap to build on
the existing wave generator, and it converts "I won" into "how far can I get".

### 5.5 Seeded runs

Same seed, same waves and same draft offers. Enables "try this seed", enables
comparing runs, and makes a daily challenge trivial later. Low cost now,
expensive to retrofit later — **the RNG should be seeded in v10 whether or not
we expose it**, because retrofitting determinism is miserable.

---

## 6 · Content completion — the honest numbers

| | delivered | remaining |
|---|---|---|
| Art stills | 32 / 67 | **35** — ui 12, props 8, ground 7, fx 6, colossus 3, env 3 |
| Animation cycles | 2 | **17** per the approved scope |
| SFX cues | 5 / 47 | **42** |
| Music | 1 / 7 | **6** |

**`ground/` is the priority I would argue hardest for.** Telegraphs, runes and
AoE markers are read constantly during every second of combat and are still pure
code. They are also where the element-motif work from §4.1 lands, so the two
jobs are the same job.

`ui/` is 12 files and the HUD is the most-looked-at surface in the game.

The Colossus is three files and it is the finale — a stranger who reaches wave
12 should meet something that looks like a boss.

---

## 7 · Learning what actually happened

We have shipped nine versions on the feedback of two people. For v10 that has to
scale without building infrastructure.

**A "copy run report" button on the end screen.** Puts a JSON blob on the
clipboard: version, seed, wave reached, build, cards taken, deaths, frame-time
percentiles, browser, viewport. A playtester pastes it into a message. Zero
server, zero privacy questions, and it turns "it felt hard" into data.

If we ever want it automatic, that same payload posts to anything. But not in
v10 — a link that phones home is a different conversation with strangers.

---

## 8 · What I would cut

Being explicit, because this list is long and v10 should ship.

- **A second hero.** Under "animate everything" that is a full character plus
  three cycles plus a balance pass. It is a v11 headline, not a v10 line item.
- **Full touch support**, unless reach is the point. Detect-and-inform instead.
- **Multiplayer, meta-progression between runs, unlocks.** All plausible; none
  of them make a stranger's first run better.
- **New enemy types.** Each one now costs three animation cycles. The roster of
  five plus a boss is enough for 12 waves.
- **More waves.** 12 with an endless tail is the right shape. Length is not the
  problem.

---

## 9 · Proposed sequencing

Each block is independently shippable. If v10 shipped after block 2 it would
already be dramatically better than v9.

| # | Block | Why here |
|---|---|---|
| **1** | Instant start + streaming assets; delete `assets-49`; seed the RNG | Unblocks everything, removes the worst failure, and seeding is cheapest now |
| **2** | Opening skill choice; contextual first-time prompts; title screen | The first ninety seconds — the highest-leverage design work in the release |
| **3** | Element motifs + high-contrast; reduced motion; pause/settings; remappable keys | Playable by people who currently cannot play it |
| **4** | Run summary; local records; copy-run-report | Closes the loop, for the player and for us |
| **5** | Difficulty tiers; endless | Reasons to return |
| **6** | `ground/` and `ui/` art; the Colossus; animation cycles as they land | Continuous, parallel with everything above |
| **7** | Browser/device pass; perf on real hardware; background-tab bug | Last, because it needs the finished thing |

Blocks 1–5 are mine. Block 6 is Codex's. Block 7 is both of us plus a human with
a slow laptop.

---

## 10 · Open questions I need answered

1. **Is v10 the public one?** If it goes on itch.io or anywhere with a real
   audience, §4 stops being optional and touch detection becomes mandatory.
2. **How much do you care about mobile?** Cheapest honest answer is a "best on
   desktop" notice. Real support is a project of its own.
3. **Difficulty tiers — three, or one well-tuned curve?** Tiers cost balance
   work across every wave, and our sample is two players.
4. **Is the 12-wave run the product**, or is endless the real game and the 12
   waves a tutorial for it?
5. **Do you want a seed/daily challenge surfaced**, or just seeded internally so
   we can reproduce bugs?
6. **How long is v10 allowed to take?** Blocks 1–2 are days. All seven is weeks.
   I would rather ship 1–4 well than all of it thinly.

---

## 11 · Where Codex should lead

Its proposal will be better than mine on:

- **Art direction and what "awesome" looks like.** I can measure payload and
  wire slots; I cannot tell you whether the deck reads as a place. The
  vertical-slice question — do sky, deck, props, characters and effects speak one
  language yet — is theirs.
- **The animation plan**, which it is already executing and understands better
  than I do.
- **Audio identity.** I built the mixer. What the game should *sound* like — one
  combat theme or a score, how present the ambience is — is not an engineering
  question.
- **The Colossus as a set piece**, rather than as three files.

Where I would push back on anything either of us proposes: if it does not
survive §1's test — a stranger, alone, finishing a run and being able to
describe it — it is v11.
