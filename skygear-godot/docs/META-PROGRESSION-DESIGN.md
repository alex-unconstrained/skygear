# Meta-progression — the Workshop and the Articles

Status: design, not built. Written against the port as it stands 2026-07-31.

## 0. What changed, and what has not

`V10-PLAN.md` §0 cut meta-progression and `VERSIONS.md` still parks it beside relics,
currencies and accounts: *"ways to postpone the moment this game becomes excellent."*
Correct when written. The game then had no seed, no run log, no report, 6 of 55 audio
cues, 32 of 67 stills, and had never been played by a stranger. An unlock tree bolted
to that is a retention system standing in for a game.

**Three things changed.** The thing it postponed is built — twelve waves, 41 cards, the
boss's two beats, three endings, slot-attributed telemetry, 76 checks. The persistence
and the tracking exist and are covered: `runlog.gd` writes wave, win, time, seed, build,
cards, vents, healed, salvage, rerolls and close-share to `user://runs.json`, capped,
total on failure, loud when the write misses — **every currency below is computed from
that row, and this adds no new tracking.** And winning produces a `DECK HELD` line and
nothing else, which is a content gap at the top of the curve rather than a retention gap
at the bottom. The brief asks for power arriving *once you have beaten a run or two* —
post-victory content, which does not carry the risk §0 named.

**One thing has not changed: close to zero cold playtests.** So part of the original
"no" stands, and it shapes everything below.

- **The tree does not exist until you have won.** Nothing unlocked, shown or spendable
  before the first `DECK HELD`. Every run up to your first win is *exactly the game
  that ships today*, at today's numbers, pinned by the harness. Not a soft gate — it is
  the whole defence against the failure mode in §1.
- **No talent restores power removed from the baseline.** The captain is frozen; if a
  talent ever looks necessary, the baseline was wrong and gets fixed.
- **Accounts, cloud saves, leaderboards and relics stay parked.** One JSON file in
  `user://`, and the draft is already the relic system.

## 1. Precedent — four answers

**Hades — the Mirror of Night.** Darkness buys ~12 rows, each a mutually exclusive pair;
respec costs a gem. *Buys* a difficulty knob on a game whose story requires you to die a
lot, and a slow decision layer that never competes with the fast one. *Costs:* it is
almost all stat percentages and dull to read — Supergiant's fix was a cast of characters
around it so the between-run screen is somewhere you want to be. *Fails when* the first
several hours are balanced against not having it, which Hades survives only because
dying is the plot. SkyGear has no plot reason to die and no House.

**Dead Cells — runes vs. mutations.** Runes are permanent *access* — vines, teleporters,
breakable floors — with zero combat power; mutations are in-run only. *Buys* a game that
never gets easier, only wider, so the balance surface never moves. *Costs:* geometry
authored behind locks, which SkyGear has not got — one deck, three lanes, no doors.
*Fails when* a player asks "am I stronger?" and the answer is no. Borrowed for the
actives' shape — verbs, not numbers — rejected for the rest.

**Rogue Legacy — the manor.** Gold into a big stat tree, all of it confiscated at each
run's start so banking is impossible. *Buys* the most legible growth of the four.
*Costs:* it is the canonical case of the failure — the early game is *deliberately*
underpowered so the manor has somewhere to go, and balance is tuned to an expected
investment curve. Flat +HP/+damage against flat scaling also goes trivial eventually.

**Slay the Spire — the refusal.** Nothing persists but Ascension and the card pool.
*Buys* a game where run 1 and run 500 are identical, so every loss is legibly yours.
*Costs:* no soft landing at all, and plenty of people bounce. Risk of Rain 2 sits just
short — unlocks add survivors and items rather than power, keeping balance still but
diluting the drop pool and pushing you to play for the unlock, not the win.

**The failure mode, named once: investment debt.** Balance gets tuned to the *expected*
meta state, so a player below it is playing a version built to be unwinnable and the
only fix is runs they do not want to play. Rogue Legacy takes the debt deliberately;
Hades pays it for ten runs; Dead Cells and the Spire refuse it. **SkyGear takes none of
it, structurally**: the tree does not exist for any run balanced against not having it.

## 2. Two currencies

**Scrip — plentiful, small, farm-resistant by shape.**

```
scrip = 8 × wave  +  60 if won  +  1 × vents  +  round(0.4 × close_share)
        ×0.25 if this seed has been played before
```

Four fields the log already writes. The close-share term pays the v11 loop, already the
one number the project judges itself by; the seed clause kills the only real exploit,
replaying a known-good seed forever.

**Sigils — few, large, not farmable at all.** A sigil comes from a **first**, never a
repeat. Eleven exist, all read off the log row: **Held the Deck** (first `won`); **Heat
1/2/3/4** (first `won` at each step); **Quick Passage** (`time` under 6:00); **No
Second Thoughts** (`rerolls` = 0); **Unshaken** (`healed` under 150); **Full Spectrum**
(four elements in `build`); **Monochrome** (one element across all four slots).

**Grinding is stopped by shape, not by rules.** The impactful currency has no repeatable
source at all. The farmable one is dominated by `wave` and `won`, maximised by playing
well rather than long; there is no endless mode, so no farm loop; a repeated seed pays a
quarter; the Workshop is *finite*. No dailies, no streaks, no bonus for a fast restart.

| | earned | banked | sigils |
|---|---|---|---|
| after run 1 (lost wave 4) | 49 | 49 | tree not open |
| after run 3 (lost wave 8) | 96 | 217 | tree not open |
| first win, run 5 | 199 | 416 | 1 |
| after run 10 | ~150/run | ~1,170 | 3 |

Scrip accrues **before** the first win and banks silently, so the victory reveal hands
you 400 scrip and a spec rather than an empty screen and a chore — and whoever struggled
to that first win arrives with more help for the second, a self-correcting curve for
free. The full Workshop is 2,760 scrip, roughly run 25.

## 3. The tree

Two panels, because they are two objects. **The rule against duplicating `cards.gd`: the
draft moves rates and multipliers during a run; the tree moves what you begin with, plus
flat capped amounts and out-of-combat information.** Talents are front-loaded and decay
across twelve waves; cards are back-loaded and compound.

**The Workshop — 25 nodes, 35 steps, scrip.** Four branches off a hub; a branch's next
tier opens at two nodes bought. Cost after each node, ranks in brackets.

| Branch | Nodes |
|---|---|
| **A · The Captain's Kit** | Bootblacking +4% move [×2] 40 · Sea Legs dash recharge −0.08s [×2] 40 · Padded Coat +8 max HP [×3] 40 · Deep Pockets +1 starting reroll [×2] 60 · Steady Hand +3% crit [×2] 60 · Wound Kit restore 6 HP at each wave start 100 · Long Arms +5% range on every skill [×2] 100 |
| **B · The Gauge** | Hair Spring pressure +6% [×2] 40 · Salvager salvage heals +2 [×2] 40 · Relief Valve vent heals +2 [×2] 60 · Wide Blow vent radius +6% [×2] 60 · Cold Start begin each wave at 15 pressure 100 · Second Breath +12% move for 2s after a vent 160 |
| **C · The Ship** | Shot Locker cannons +15% health [×2] 40 · Spare Plate Boiler +60 max HP [×3] 60 · Gun Crew cannons fire 8% faster [×2] 60 · Rivet Gun the Boiler repairs 25 HP between waves [×2] 100 · Powder Store one extra keg stowed each wave 100 · Muster Roll one extra crewman per wave 160 |
| **D · The Log** | Manifest next wave's composition listed during the draft 40 · Tally enemy health bars carry numbers 40 · Ledger results shown against your best three 40 · Quartermaster the opening draft always contains a NEW SKILL 60 · Foresight one card of each draft shown a wave early 100 · Fourth Card the opening draft offers four cards 160 |

**The Articles — 9 nodes, sigils.** Sixteen sigils to own them all against eleven in
existence, so **you can never have the whole side.** Two mutual exclusions.

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

Brace and Recall answer the two things the game has no answer for — the hit you saw
coming, and the lane that broke on the far side of the deck. Same key, different game.

**First spec** (1 sigil, ~400 scrip): Brace; Padded Coat ×2, Bootblacking, Deep Pockets,
Spare Plate, Manifest, Hair Spring — 320 spent. **Third** (~run 10, 3 sigils): Second
Shift + Keel Hauling, Brace respecced away; Kit through tier 2, The Ship opened.
**Tenth** (~run 30, 8 sigils): The Second Hand + Second Shift + Scuttle + Keel Hauling —
five of nine actives unowned, one permanently, because The Second Hand locked out The
Opening Bid.

## 4. Keeping the draft the thing that decides the run

1. **The whole Workshop, fully bought, is worth less than three draft cards.** Every
   talent is additive against a base the cards multiply. A check compares resolved stats:
   full tree and no cards, against no tree and a typical wave-6 card set.
2. **No talent may be a multiplier**, and none may grant a card's exclusive. Fifth Gear,
   Residue, Twin Cast, the wide cone, pierce and chain jumps stay the draft's — a talent
   handing you an epic on run 1 deletes the best moment the game has.
3. **No card may become worse than a skip.** Two are at risk and both survive: SPARE
   PARTS is +2 rerolls against Deep Pockets' +1 at start; SPARE TANK is +150 Boiler HP
   against Spare Plate's +60.
4. **The best talents widen the draft rather than replace it.** Quartermaster, Foresight,
   Fourth Card and The Opening Bid make the existing progression bigger, which is the
   strongest single argument for building this at all.

## 5. Difficulty — Heat, opened by the same victory

A permanently stronger captain makes twelve waves permanently easier. The answer is an
earned, opt-in, per-run **Heat** ladder chosen at the title, unlocked by the same first
victory that opens the tree — so there is exactly one difficulty until you have beaten
the game, and every balance claim the harness makes is against that one. **Rejected:
scaling enemies to talent points spent.** It removes exactly what it grants, which the
player can feel; it makes buying a talent ambiguous; and it hands the harness a moving
target. Each step is one *named* modifier, not a multiplier, and all are data.

| Heat 1 | **Rust** | wave HP scaling 0.06 → 0.09 (wave 12: ×1.66 → ×1.99) |
|---|---|---|
| Heat 2 | **Short Fuse** | enemy windups 15% faster — still readable, pillar 6 |
| Heat 3 | **Cold Deck** | drafts offer two cards, and you start with one reroll |
| Heat 4 | **Boarders Aloft** | push waves at 4, 6, 8 and 10 |
| Heat 5 | **Skeleton Crew** | no crew muster, cannons at half health |

Heat 1–4 each pay a sigil on first clear; Heat 5 pays only the record, so the top of
the mountain is not a power reward. **Ship Heat 1 and 2 only** — each step needs a real
playthrough to be worth having, and five of them is more work than the tree is.

## 6. Respec

**Passives: free, always, between runs.** There is no interesting decision in "which
+4% did I commit to three weeks ago"; a cost only produces a wiki-copied build and
punishes whoever experimented. Free respec also lets the numbers be retuned after ship
without invalidating anyone's spend.

**Actives: free, and only between runs.** A cost exists to create scarcity and the
sigils are *already* scarce — at most seven of sixteen. Charging twice for one scarcity
has one real effect: players never try the actives they have not tried. **Never
mid-run**, hard: an active you can swap between waves is an inventory, not a spec.

## 7. Cost to build

**One correction to the brief.** `scripts/ui.gd` exists — 256 lines of immediate-mode
widgets with retained focus: buttons, rows, sliders, choices — with **zero call sites
anywhere in the project** and no checks. The widget layer is written and completely
unproven; the tree screen should be what proves it, not what waits for it.

| Piece | Kind | Note |
|---|---|---|
| `meta.gd`, `user://meta.json` | persistence | small; `runlog.gd` is the template, including that every method is total and a failed write is said out loud |
| Award computation | data, ~40 lines | computed **from the log row**, not live state, so it is reproducible from a fixture |
| `apply_talents(mods, player, game)` | simulation | called straight after `fresh_mods()`. **The gate on every future talent: if it cannot be expressed as a change to `mods`, `player` or a starting value, it is not a talent.** |
| Nine actives | simulation | ~250–350 lines, the expensive half. Brace, Keel Hauling, Press-Gang and Second Shift are 10–30 each. **The Second Hand is the big one**: a fifth slot touches `skills`, the four HUD skill plates, `hud_layout.json`, `cards.gd`'s slot loops, and `telemetry.gd`, which hardcodes `for _i in 4`. |
| Heat 1–2 | data | `game_data.gd` plus a title-screen choice |
| The tree screen | **UI, the largest item** | two panels, 35 steps, costs, gates, exclusions, confirm, respec, keyboard and mouse — on a widget layer that has never run |
| 34 node icons | art | `tools/forge.py` exists, but **ship on typography and shape glyphs.** 34 tiny icons is the most expensive art item in the project relative to what it buys. |
| ~15 checks | test | meta round-trips and survives a denied write; scrip is exact for a fixture row; a repeated seed pays a quarter; no sigil twice; the tree is inert before the first win; an empty spec reproduces today's baseline exactly; full tree < three cards; exclusions hold; respec returns exactly what was spent; Heat modifiers apply |

## 8. The one thing most likely to make this worse

Not the balance and not the grind — both are handled structurally above. **It is that
the between-run screen becomes the game's front door, and the front door is worse than
the game.** Today you press Enter and are fighting in four seconds; after this, every
run opens with a spreadsheet. Hades survives its between-run screen because the House
is a place worth being. SkyGear has no House, and a thirty-four node tree with
placeholder icons standing in front of the one thing this project has proven is good is
a net loss even if every number in it is right.

**The cheapest way to find out, in order.**

1. **Before any game code**, run the scrip formula over the sixty rows already in
   `runs.json` and look at the curve for runs that were actually played. A script, not
   a feature, and it settles the earn rate for free.
2. **Ship the whole system with no tree UI at all.** Scrip and sigils accrue, the
   results screen gains one line saying what the run paid, and the spec is hand-edited
   into `user://meta.json`. Play ten runs. That tests every question that matters —
   does she feel stronger, does the draft still decide the run, is the rate right — for
   the cost of persistence and `apply_talents`, and zero UI. If ten runs with a
   hand-edited file are not better runs, no tree screen was going to fix that.
3. Only then the screen, and start with the smallest that works: a **SPEND (3)** button
   on the results screen walking you through the nodes you can afford, one at a time.
   No map, no panning. Someone who wants a map will ask, and then you will know.
