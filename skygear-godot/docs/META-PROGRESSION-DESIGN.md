# Meta-progression — the Workshop and the Articles

Status: **BUILT**, both sides. The gate, both currencies, 24 Workshop nodes,
7 Articles, respec, and the whole thing on one screen behind a first victory.
Every field is wired — two harness checks fail the build if a node or an article
is ever added without a reader.

Where the build departs from what is written below, and why:

- **Quartermaster is gone.** "The opening draft always holds a new skill" is a
  no-op: below four skills `open_draft` already offers only weapons. Replaced by
  **Watch Bill** — the lane readout counts who is still queued, read straight off
  `spawn_queue`.
- **Foresight is gone.** It needs the next draft pre-rolled without disturbing
  the seeded stream. Real work, not started.
- **The Opening Bid and The Second Hand are not built.** The Second Hand is the
  most expensive node on the board — `telemetry.gd` hardcodes four slots, and so
  do the HUD plates, `hud_layout.json` and the slot loops in `cards.gd` — and the
  design says so itself. The Opening Bid needs a matrix picker screen.
- **The keyed Articles are captain-only.** `F` is the Boilerwright's Tap Main and
  `V` is his Blowdown; those are the class, not a binding. Rebinding his
  signature or inventing a third key nobody remembers were both worse than
  saying so on the node.
- **Head does not cost Boiler HP** — see `CLASS-2-DESIGN.md` for that one.
- **Heat is not built.** §5 is untouched.

Written against the port as it stands 2026-07-31.

## 0. What changed, and what has not

`V10-PLAN.md` §0 cut meta-progression and `VERSIONS.md` still parks it beside relics,
currencies and accounts: *"ways to postpone the moment this game becomes excellent."* Correct
when written. The game then had no seed, no run log, no report, 6 of 55 audio cues, 32 of 67
stills, and had never been played by a stranger; an unlock tree on that is a retention system
standing in for a game.

**Three things changed.** The thing it postponed is built — twelve waves, 41 cards, the boss's
two beats, three endings, slot-attributed telemetry, 76 checks. The persistence and the
tracking exist and are covered: `runlog.gd` writes wave, win, time, seed, build, cards, vents,
healed, salvage, rerolls and close-share to `user://runs.json`, capped, total on failure, loud
when the write misses — **every currency below is computed from that row, and this adds no new
tracking.** And winning produces a `DECK HELD` line and nothing else: a content gap at the top
of the curve, not a retention gap at the bottom. The brief asks for power arriving *once you
have beaten a run or two*, which is post-victory content and does not carry the risk §0 named.

**One thing has not changed: close to zero cold playtests.** So part of the original "no"
stands, and it shapes everything below.

- **The tree does not exist until you have won.** Nothing unlocked, shown or spendable before
  the first `DECK HELD`. Every run up to your first win is *exactly the game that ships
  today*, at today's numbers, pinned by the harness. Not a soft gate — it is the whole defence
  against the failure mode in §1.
- **No talent restores power removed from the baseline.** The captain is frozen; if a talent
  ever looks necessary, the baseline was wrong and gets fixed.
- **Accounts, cloud saves, leaderboards and relics stay parked.** One JSON file in `user://`;
  the draft is already the relic system.

## 1. Precedent — four answers

**Hades — the Mirror of Night.** Darkness buys ~12 rows, each a mutually exclusive pair;
respec costs a gem. *Buys* a difficulty knob on a game whose story needs you to die a lot.
*Costs:* it is almost all stat percentages and dull to read — Supergiant's fix was a cast of
characters around it. *Fails when* the first several hours are balanced against not having it,
which Hades survives only because dying is the plot. SkyGear has no plot reason to die.

**Dead Cells — runes vs. mutations.** Runes are permanent *access* — vines, teleporters,
breakable floors — with no combat power; mutations are in-run only. *Buys* a game that never
gets easier, only wider, so the balance surface never moves. *Costs:* geometry authored behind
locks, which SkyGear has not got. *Fails when* a player asks "am I stronger?" and the answer
is no. Borrowed for the actives — verbs, not numbers — rejected for the rest.

**Rogue Legacy — the manor.** Gold into a big stat tree, confiscated at each run's start so
banking is impossible. *Buys* the most legible growth of the four. *Costs:* it is the canonical
case of the failure — the early game is *deliberately* underpowered so the manor has somewhere
to go, and balance is tuned to an expected investment curve.

**Slay the Spire — the refusal.** Nothing persists but Ascension and the card pool. *Buys* a
game where run 1 and run 500 are identical, so every loss is legibly yours. *Costs:* no soft
landing, and plenty of people bounce. Risk of Rain 2 sits just short: unlocks add survivors and
items rather than power, holding balance still but diluting the pool.

**The failure mode, named once: investment debt.** Balance gets tuned to the *expected* meta
state, so a player below it is playing a version built to be unwinnable, fixable only by runs
they do not want to play. Rogue Legacy takes it deliberately, Hades pays it for ten runs, Dead
Cells and the Spire refuse it. **SkyGear takes none of it, structurally**: the tree does not
exist for a run balanced against not having it.

## 2. Two currencies

**Scrip — plentiful, small, farm-resistant by shape.** `scrip = 8 × wave + 60 if won + 1 ×
vents + round(0.4 × close_share)`, **quartered if this seed has been played before.** Four
fields the log already writes. The close-share term pays the v11 loop, already the one number
the project judges itself by; the seed clause kills the only real exploit.

**Sigils — few, large, not farmable at all.** A sigil comes from a **first**, never a repeat.
Eleven exist, all read off the log row: **Held the Deck** (first `won`); **Heat 1/2/3/4**
(first `won` at each step); **Quick Passage** (`time` under 6:00); **No Second Thoughts**
(`rerolls` = 0); **Unshaken** (`healed` under 150); **Full Spectrum** (four elements in
`build`); **Monochrome** (one element in all four slots).

**Grinding is stopped by shape, not by rules.** Sigils have no repeatable source. Scrip is
dominated by `wave` and `won`, maximised by playing well rather than long; there is no endless
mode, so no farm loop; a repeated seed pays a quarter; the Workshop is *finite*.

| | earned | banked | sigils |
|---|---|---|---|
| after run 1 (lost wave 4) | 49 | 49 | tree not open |
| after run 3 (lost wave 8) | 96 | 217 | tree not open |
| first win, run 5 | 199 | 416 | 1 |
| after run 10 | ~150/run | ~1,170 | 3 |

Scrip accrues **before** the first win and banks silently, so the victory reveal hands you 400
scrip and a spec rather than an empty screen and a chore — and whoever struggled to that win
arrives with more help for the next, a self-correcting curve for free. The full Workshop is
2,760 scrip, roughly run 25.

## 3. The tree

Two panels, because they are two objects. **The rule against duplicating `cards.gd`: the draft
moves rates and multipliers during a run; the tree moves what you begin with, plus flat capped
amounts and out-of-combat information.** Talents front-load and decay across twelve waves;
cards back-load and compound.

**The Workshop — 25 nodes, 35 steps, scrip.** Four branches off a hub, next tier at two nodes
bought. Cost after each node, ranks in brackets.

| Branch | Nodes |
|---|---|
| **A · The Captain's Kit** | Bootblacking +4% move [×2] 40 · Sea Legs dash recharge −0.08s [×2] 40 · Padded Coat +8 max HP [×3] 40 · Deep Pockets +1 starting reroll [×2] 60 · Steady Hand +3% crit [×2] 60 · Wound Kit restore 6 HP at each wave start 100 · Long Arms +5% range on every skill [×2] 100 |
| **B · The Gauge** | Hair Spring pressure +6% [×2] 40 · Salvager salvage heals +2 [×2] 40 · Relief Valve vent heals +2 [×2] 60 · Wide Blow vent radius +6% [×2] 60 · Cold Start begin each wave at 15 pressure 100 · Second Breath +12% move for 2s after a vent 160 |
| **C · The Ship** | Shot Locker cannons +15% health [×2] 40 · Spare Plate Boiler +60 max HP [×3] 60 · Gun Crew cannons fire 8% faster [×2] 60 · Rivet Gun the Boiler repairs 25 HP between waves [×2] 100 · Powder Store one extra keg stowed each wave 100 · Muster Roll one extra crewman per wave 160 |
| **D · The Log** | Manifest next wave's composition listed during the draft 40 · Tally enemy health bars carry numbers 40 · Ledger results shown against your best three 40 · Quartermaster the opening draft always contains a NEW SKILL 60 · Foresight one card of each draft shown a wave early 100 · Fourth Card the opening draft offers four cards 160 |

**The Articles — 9 nodes, sigils.** Sixteen sigils to own them all against eleven in existence,
so **you can never have the whole side.** Two mutual exclusions.

| Node | Cost | Effect |
|---|---|---|
| **Keel Hauling** | 1 | Your dash drags anything it passes through with you for 0.2s. |
| **Press-Gang** | 1 | Close kills have a 6% chance to raise the body as a crewman, 12s. |
| **Brace** (`F`) | 1 | 0.35s of no damage and no displacement, 18s cooldown. *Excludes Recall.* |
| **Recall** (`F`) | 2 | Return to the Boiler instantly, 45s cooldown. *Excludes Brace.* |
| **Scuttle** (`V`) | 2 | Detonate every keg on the deck at once. Once a wave. |
| **Second Shift** | 2 | The first lethal blow leaves you at 1 HP, a free full vent, 1.5s invulnerable. Once a run. |
| **Deadman's Switch** | 2 | Below 25% the Boiler vents itself: 200 damage in 700 units. Once a wave. |
| **The Opening Bid** | 2 | Choose all three starting skills from the 32-cell matrix. *Excludes The Second Hand.* |
| **The Second Hand** | 3 | A fifth skill slot, drafted at wave 3. *Excludes The Opening Bid.* |

Brace and Recall answer the two things the game has no answer for — the hit you saw coming and
the lane that broke on the far side of the deck. Same key, different game.

**First spec** (1 sigil, ~400 scrip): Brace; Padded Coat ×2, Bootblacking, Deep Pockets, Spare
Plate, Manifest, Hair Spring — 320 spent. **Third** (~run 10, 3 sigils): Second Shift + Keel
Hauling, Brace respecced away; Kit through tier 2, The Ship opened. **Tenth** (~run 30, 8
sigils): The Second Hand + Second Shift + Scuttle + Keel Hauling — five of nine actives
unowned, one of them permanently.

## 4. Keeping the draft the thing that decides the run

1. **The whole Workshop, fully bought, is worth less than three draft cards.** Every talent is
   additive against a base the cards multiply, and a check compares resolved stats: full tree
   without cards, against no tree with a typical wave-6 card set.
2. **No talent may be a multiplier**, or grant a card's exclusive: Fifth Gear, Residue, Twin
   Cast, the wide cone, pierce and chain jumps stay the draft's. A talent handing you an epic
   on run 1 deletes the best moment the game has.
3. **No card may become worse than a skip.** Two are at risk, both survive: SPARE PARTS is +2
   rerolls against Deep Pockets' +1 at start, SPARE TANK +150 Boiler HP against Plate's +60.
4. **The best talents widen the draft rather than replace it.** Quartermaster, Foresight,
   Fourth Card and The Opening Bid make the existing progression bigger — the strongest single
   argument for building any of this.

## 5. Difficulty — Heat, opened by the same victory

A permanently stronger captain makes twelve waves permanently easier. The answer is an earned,
opt-in, per-run **Heat** ladder chosen at the title, unlocked by the same first victory that
opens the tree — so there is exactly one difficulty until you have beaten the game, and every
balance claim the harness makes is against that one. **Rejected: scaling enemies to talent
points spent** — it removes exactly what it grants, makes buying a talent ambiguous, and hands
the harness a moving target. Each step below is one *named* modifier rather than a multiplier,
and all are data.

| | | |
|---|---|---|
| Heat 1 | **Rust** | wave HP scaling 0.06 → 0.09 (wave 12: ×1.66 → ×1.99) |
| Heat 2 | **Short Fuse** | enemy windups 15% faster — still readable, pillar 6 |
| Heat 3 | **Cold Deck** | drafts offer two cards, and you start with one reroll |
| Heat 4 | **Boarders Aloft** | push waves at 4, 6, 8 and 10 |
| Heat 5 | **Skeleton Crew** | no crew muster, cannons at half health |

Heat 1–4 pay a sigil on first clear; Heat 5 pays only the record, so the top of the ladder is
not a power reward. **Ship Heat 1 and 2 only** — each step needs a playthrough to be worth
having, and five is more work than the tree is.

## 6. Respec

**Passives: free, always, between runs.** There is no interesting decision in "which +4% did I
commit to three weeks ago"; a cost only produces a wiki-copied build and punishes whoever
experimented. Free respec also lets the numbers be retuned after ship without invalidating
anyone's spend.

**Actives: free, and only between runs.** A cost exists to create scarcity and the sigils are
*already* scarce — at most seven of sixteen. Charging twice for one scarcity has one real
effect: players never try the actives they have not tried. **Never mid-run**, hard — an active
you can swap between waves is an inventory, not a spec.

## 7. Cost to build

**One correction to the brief.** `scripts/ui.gd` exists — 256 lines of immediate-mode widgets
with retained focus, and **zero call sites anywhere in the project.** The widget layer is
written and wholly unproven; the tree screen should prove it, not wait for it.

| Piece | Kind | Note |
|---|---|---|
| `meta.gd`, `user://meta.json`, award computation | persistence, ~40 lines | `runlog.gd` is the template, including that every method is total and a failed write is said out loud. Awards computed **from the log row**, not live state, so they are reproducible from a fixture |
| `apply_talents(mods, player, game)` | simulation | called straight after `fresh_mods()`. **The gate on every future talent: if it cannot be expressed as a change to `mods`, `player` or a starting value, it is not a talent.** |
| Nine actives | simulation | ~250–350 lines, the expensive half. Brace, Keel Hauling, Press-Gang and Second Shift are 10–30 each. **The Second Hand is the big one**: a fifth slot touches `skills`, the four HUD skill plates, `hud_layout.json`, `cards.gd`'s slot loops, and `telemetry.gd`, which hardcodes `for _i in 4`. |
| Heat 1–2 | data | `game_data.gd` plus a title-screen choice |
| The tree screen | **UI, the largest item** | two panels, 35 steps, costs, gates, exclusions, confirm, respec, keyboard and mouse — on a widget layer that has never run |
| 34 node icons | art | `tools/forge.py` exists, but **ship on typography and shape glyphs.** 34 tiny icons is the most expensive art item in the project relative to what it buys. |
| ~15 checks | test | meta round-trips and survives a denied write; scrip is exact for a fixture row; a repeated seed pays a quarter; no sigil twice; the tree is inert before the first win; an empty spec reproduces today's baseline exactly; full tree < three cards; exclusions hold; respec returns exactly what was spent; Heat modifiers apply |

## 8. The one thing most likely to make this worse

Not the balance and not the grind — both are handled structurally above. **It is that the
between-run screen becomes the game's front door, and the front door is worse than the game.**
Today you press Enter and are fighting in four seconds; after this, every run opens with a
spreadsheet. Hades survives its screen because the House is worth being in; SkyGear has no
House, and a thirty-four node tree with placeholder icons in front of the one thing this
project has proven is good is a net loss however right its numbers are.

**The cheapest way to find out, in order.**

1. **Before any game code**, run the scrip formula over the sixty rows already in `runs.json`
   and look at the curve for runs actually played. A script, not a feature, and it settles the
   earn rate for free.
2. **Ship the whole system with no tree UI at all.** Scrip and sigils accrue, the results
   screen says what the run paid, the spec is hand-edited into `user://meta.json`. Play ten
   runs. That tests every question that matters — does she feel stronger, does the draft still
   decide the run, is the rate right — for the cost of persistence and `apply_talents`, and
   zero UI. If ten hand-edited runs are not better runs, no tree screen was going to fix that.
3. Only then the screen, and start with the smallest that works: a **SPEND (3)** button on the
   results screen walking you through the nodes you can afford, one at a time. No map, no
   panning. Someone who wants a map will ask, and then you will know.
