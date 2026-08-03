# SkyGear on Steam — page live, demo playable, wishlists accumulating

Written 2026-08-03. Every factual claim below carries a source; claims I could
not verify against Valve's own documentation are marked **[unverified]** and
collected again in §10. Nothing here is asserted from memory — that is this
project's standing rule and it applies to research as much as to code.

Primary sources are `partner.steamgames.com/doc/...` (Steamworks Documentation).
Some Steamworks pages require a partner login and could not be reached at all;
those are named in §10 with a description of what he will find behind them.

---

## 0. The recommendation, up front

The ask was *"create a Steam page where I could upload this as a demo and share
it with some friends and then with a wider community to start having people
playtest it and wishlist it."* That is **three different products** on Steam,
and conflating them is what makes this take three months instead of six weeks.

| The thing you said | What Steam calls it | What it costs | What it waits on |
|---|---|---|---|
| "share it with some friends" | **not a Steam problem** — use itch.io, which already works | $0, 0 days | nothing |
| "playtest with a wider community" | **Steam Playtest** (free child app) or a **demo** | $0 on top of the base fee | the base store page being public |
| "strangers can wishlist it" | **Coming Soon store page** on a paid app ID | $100 USD once | ~2–5 weeks of paperwork + 3–5 business days review |

### The shortest path, in order

1. **Today — friends play the game.** Send them the itch.io build you already
   ship (`tools/pack_itch.py` → butler → `alex-unconstrained.itch.io/skygear-godot-test`).
   Every Steam mechanism for "a few friends" is *slower* than the one you have:
   Steam keys require a three-week wait after AppID creation for a first-time
   developer ([Steam Keys](https://partner.steamgames.com/doc/features/keys)),
   a password-protected beta branch requires the friend to already **own** the
   app (which for an unreleased paid game means a key), and Steam Playtest
   requires your base store page to be public first. **Do not put the friends
   round behind Steam.** This is the single biggest time saving in this document.
2. **Today — start the Steamworks paperwork.** It is pure waiting and it is
   entirely yours (§1). Nothing else can start until the app ID exists.
3. **Week 1–3, in parallel — the loop builds the asset manifest** (§4). Capsules,
   screenshots, trailer, copy. None of this needs a Steamworks account.
4. **Once the account clears — pay $100, create ONE app: "SkyGear."** Not a
   demo app, not a playtest app. One paid app ID; the demo and playtest hang off
   it for free (§2).
5. **Submit the store page for review**, get it approved, hit **Post as Coming
   Soon**. Wishlists start here, and only here. This is the moment "strangers can
   wishlist it" becomes true.
6. **Then add the demo** — a free child app ID created from the base game's page
   — upload its build via SteamPipe, get it reviewed, release it. Now the wider
   community can play, and each demo install is a chance at a wishlist.
7. **Steam Playtest is the fallback, not the plan.** Use it only if you want a
   gated build with *no* store presence of its own — e.g. testing a Heat-6 build
   or a class rework after the demo is out. It doesn't drive wishlists at all
   (Valve: "A customer's wishlist for your game won't be impacted when they join
   or leave your playtest" — [Playtest](https://partner.steamgames.com/doc/features/playtest)).

### The Next Fest fork, and it is time-critical

Steam Next Fest **October 2026** has a **registration deadline of August 31,
2026 at 11:59pm PDT**, demo builds due **September 21**, all required items due
**October 5**, and the fest itself runs **October 19–26, 2026**
([Next Fest: October 2026](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/2026october)).
Today is August 3. To register you need a **published, public store page** by
August 31 — which means paperwork, fee, assets, and a 3–5 business day store
review all completed in four weeks, with zero slack.

**It is possible and I would not plan on it.** A game may only ever join
**one** Next Fest ("titles may only participate in ONE Next Fest"), so burning
it on a rushed entry is the expensive mistake. **Target February 2027**
(the next edition after October 2026 per Valve's own event list), which gives
the demo months of live feedback first. Chase October only if the store page is
approved by roughly August 24.

---

## 1. Your checklist — the things nobody can do for you

Anything touching money, identity, a legal agreement, or a Valve login is
yours. The loop cannot and must not touch these.

| # | Step | Where | Time it actually takes |
|---|---|---|---|
| 1.1 | Create/choose the Steam account that will own the partner group. Enable Steam Guard Mobile Authenticator — a build account needs a phone or the mobile app attached to publish ([Uploading](https://partner.steamgames.com/doc/sdk/uploading)) | store.steampowered.com | minutes |
| 1.2 | Sign up as a Steamworks partner; sign the Steam Distribution Agreement (electronic) | partner.steamgames.com | same day |
| 1.3 | Legal name / entity. "Enter your legal first and last name. Do not enter an alias or nickname." If you are a sole proprietor, use your legal name, **not** a DBA ([Onboarding](https://partner.steamgames.com/doc/gettingstarted/onboarding)) | Steamworks | minutes — but get it right, it must match the bank and tax records |
| 1.4 | **Tax interview.** As a Canadian individual you complete a **W-8BEN**, not a W-9. Claiming the Canada–US treaty requires a TIN: "In order to exercise the benefits under the tax treaty, you will need to complete a Form W-8BEN and that requires either a **foreign TIN or a US TIN**" ([Taxes FAQ](https://partner.steamgames.com/doc/finance/taxfaq)). Your Canadian SIN is normally the foreign TIN. **[unverified]** that Valve accepts a SIN specifically — the doc says "foreign TIN" and does not enumerate. Withholding "may range from 0% to 30%"; a correctly-claimed treaty position on copyright royalties should land at 0%, but **[unverified]** — Valve does not state the Canadian rate and I am not your accountant | Steamworks | interview is 5–10 min; Valve's processing is **"2-7 business days"**, with possible requests for more documents |
| 1.5 | **Banking.** "We'll need accurate bank information, such as routing number, bank account number, and bank address." Critically: **"The account holder name on your bank account must match the name you provide when onboarding"** ([Onboarding](https://partner.steamgames.com/doc/gettingstarted/onboarding)). A CAD account at a Canadian bank is fine | Steamworks | see the warning below |
| 1.6 | Identity verification. Valve's docs mention "identity verification" as part of onboarding without detailing it **[unverified]** — expect to upload government photo ID | Steamworks | **[unverified]**, commonly days |
| 1.7 | **Pay the $100 USD Steam Direct fee.** "The Steam Direct Fee is not refundable" but is "recoupable in the payment made after your product has at least $1,000.00 Adjusted Gross Revenue" ([Steam Direct Fee](https://partner.steamgames.com/doc/gettingstarted/appfee)). You cannot pay it until "bank, tax and company information has been verified" ([Getting Started](https://partner.steamgames.com/doc/gettingstarted)) | Steamworks | instant, once unblocked |
| 1.8 | Create the app. Name it **SkyGear** | Steamworks | minutes |
| 1.9 | **Complete the Content Survey** — three mandatory sections: General Content, Mature Content, and **Generative AI Content** ([Content Survey](https://partner.steamgames.com/doc/gettingstarted/contentsurvey)). See §4.6 — the AI section is a real decision for this project, not a formality |
| 1.10 | Set price. SkyGear's *demo* is free; the base game needs a price set before the page can go live. You are not committing to a launch date |
| 1.11 | Hit **"Mark As Ready For Review"**, then after approval **"Post as Coming Soon"** | Steamworks | see §5 |

### The two waits that catch people out

- **Verification gates the fee, and the fee gates everything.** You cannot
  create an app until bank/tax/identity are verified. This is the front-loaded
  wait and there is nothing to do but start it early. Valve documents **2–7
  business days** for the tax questionnaire alone. The commonly-reported bank
  micro-deposit verification adds more; Valve does not document a duration and
  I could not find a primary source, so treat **1–3 weeks end to end** as the
  planning figure and **[unverified]** as its status.
- **The 30-day rule.** "There is a **30-day waiting period between when you paid
  the app fee and when you can release your game**"
  ([Onboarding](https://partner.steamgames.com/doc/gettingstarted/onboarding)).
  **[unverified]** whether this also gates *releasing a free demo* — Valve's
  demo documentation does not mention it. Assume it does; it is the safe
  assumption and it is the one that would break an October Next Fest run.
- **The 2-week Coming Soon rule.** "You must have a Coming Soon page up for at
  least two weeks before releasing"
  ([Coming Soon](https://partner.steamgames.com/doc/store/coming_soon)). This
  applies to the full game's release, and it runs concurrently with the 30 days.

### What the loop can do without your account

Everything in §4 (art, copy, screenshots, trailer capture), everything in §6
(`tools/pack_steam.py`, depot layout, VDF), and all of the wording drafts. The
handoff points where it needs you are exactly: uploading assets into Steamworks,
pressing review/publish buttons, and the build account credentials.

---

## 2. The three distribution mechanisms, compared

| | **Steam Playtest** | **Demo** | **Beta branch** | **Steam keys** |
|---|---|---|---|---|
| Own app ID? | Yes — a "child appID" | Yes — a separate App ID associated with the full game | No — a branch of the main app | No |
| Extra $100? | **No** — "completely free feature for both customers and Steam developers" | **No** per multiple secondary sources; Valve's demo doc mentions no fee **[unverified — not stated either way in primary docs]** | No | No |
| Needs review? | Yes, simplified: "The store review checklist for a Playtest only consists of capsule images and icons" | **Yes** — store presence review + a build review | Not documented; builds go to a branch without the default-branch gate | Requests are reviewed case-by-case |
| Own store page? | **No.** "Instead of having its own separate store page, your Steam Playtest signup will live right on your main game" | **Optional.** You may "configure an entire store page for your demo, or just provide some assets for your demo to appear on your base game's store page" | No | No |
| Public discoverability | Signup button on your page only | **Yes, and this is the 2024 change** — demos now behave like free products: they appear in New & Trending, tag and category lists, and can be featured | None | None |
| Drives wishlists? | **No.** "A customer's wishlist for your game won't be impacted when they join or leave your playtest" | **Yes** — shares the base game's wishlist funnel, and you get a one-time notification blast (see below) | No | No |
| Access model | Request-and-approve in batches, or open signup | Anyone, free, forever | Password-protectable | Manual distribution |
| Gotcha | Requires the base store page to be public | Needs its own depots and builds | Player must already own the app | **Three-week wait after AppID creation for a first-time developer**; Release-State-Override keys capped around 2,500 |

Sources: [Playtest](https://partner.steamgames.com/doc/features/playtest),
[Demos](https://partner.steamgames.com/doc/store/application/demos),
[Testing On Steam](https://partner.steamgames.com/doc/store/testing),
[Branches](https://partner.steamgames.com/doc/store/application/branches),
[Steam Keys](https://partner.steamgames.com/doc/features/keys).

### The demo rules that changed, and the one that didn't

The thing worth knowing: **a demo has always needed its own App ID, and still
does.** What changed in *The Great Steam Demo Update* (July 2024) is that the
demo App ID stopped being a hidden appendage. Demos now show in the store's
regular surfaces like free games, get their own optional store page and reviews,
and the "Demo" state is surfaced on wishlists.

I could not fetch the announcement body itself — both the Steam Community and
Steam News copies returned only chrome — so the discoverability specifics above
rest on **secondary summaries** and are marked accordingly. What *is* from
Valve's own docs:

- Demos are created from the base game: "All associated packages, DLC, demos and
  tools" → **"Add Demo"**. Application type must be set to **Demo** and the base
  game's App ID entered in General Application Settings.
- **"Demos are a separate App ID... The demo will need to be configured with
  depots, and builds must be created just like a full app."**
- A demo can release **before** the full game: you need the base game's page set
  to Coming Soon so players can wishlist it.
- **The one-shot wishlist blast.** On first release of the demo you "can trigger
  sending notifications (emails and mobile app notifications) to players who
  have the associated full game on their wishlist... available... for two weeks
  following the initial launch of your demo. **You can only take this action
  once.**" — meaning it is worthless if you fire it at 40 wishlists. Bank it.
- **The step everyone forgets:** "After releasing the demo, you need to manually
  re-publish the base game's store page for the Download Demo button to appear."

### Recommendation per audience

- **Friends: itch.io.** You already have the pipeline, the build, and the URL.
  Steam adds three weeks and a key-approval request for zero benefit at this
  scale. Revisit only if you specifically want the Steam overlay/controller
  layer in front of them.
- **Wider community: a public demo on a free child App ID**, launched a few
  weeks *after* the Coming Soon page so the page has some wishlists to convert
  and so you can spend the one-shot notification on a non-empty list. A demo is
  the only one of the four mechanisms that is both public and wishlist-driving.

---

## 3. What SkyGear is, for store-facing copy

Grounded in `DESIGN.md` and `STATUS.md`, not invented. **Do not publish any of
this without reading it back against the current build** — `STATUS.md` moves
weekly and store copy that overstates is a review-rejection and a refund risk.

Facts that are true as of 2026-08-02 (`STATUS.md`):

- Single-player, top-down steampunk **hero defense**. A sky-pirate captain
  defends her airship's **Boiler** across **twelve boarding waves**.
- Skills are a **9 shapes × 4 elements** matrix (Cleave, Lance, Gale, Mortar,
  Whip, Beam, Field, Pulse, Sentry × Ember, Frost, Arc, Steam) — 36 cells, all
  live.
- **A draft between waves**: 41 cards across seven scopes, with reroll and
  seeded rolls.
- **Two classes** that do not play alike: the Captain (two dashes, ranged) and
  the Boilerwright (no dash; banks Head off the Boiler and spends it).
- A **close-quarters pressure loop** — fight close, build pressure, vent.
- **Every fourth wave is not a wave** (events), and a **Colossus** boss.
- Between runs: a **difficulty ladder (Heat)**, persistent progression gated
  behind a first victory, and **six ship fittings chosen into six berths**.
- A **reactive deck**: powder kegs with fuses that chain, crates, lanterns,
  lane cannons you can repair.
- Rendered in real 3D at a locked 41° camera, with a cutscene system and a
  run report.

Things that are **not** true and must not appear in copy: multiplayer, controller
support (unverified in the repo), Steam Deck verification, achievements, cloud
saves, Linux/Mac builds, or a release date.

### Draft short description (300 characters — see §4.5 for the limit caveat)

> Hold the Boiler. A sky-pirate captain defends her airship across twelve
> boarding waves, drafting skills from a matrix of nine shapes and four
> elements. Fight close to build pressure, then vent it. Powder kegs chain.
> Lanes break. Every fourth wave is not a wave.

(291 characters. Verify in the Steamworks editor, which counts for you.)

---

## 4. The asset manifest — this is the work queue

**Every dimension below is pixel-exact.** Wrong dimensions are among the most
common causes of a bounced review, and each bounce costs another 3–5 business
day cycle. Valve updated the accepted sizes in **August 2024** and states plainly
that **"Old dimensions are no longer accepted"**
([Graphical Assets Overview](https://partner.steamgames.com/doc/store/assets)).

### 4.1 Store capsules — all four REQUIRED

| Asset | Exact size | Format | Where it shows |
|---|---|---|---|
| **Header capsule** | **920 × 430** | PNG/JPG **[unverified — Valve's page does not state a format for store capsules]** | Top of the store page, recommended sections, Big Picture |
| **Small capsule** | **462 × 174** | as above | Search results, top sellers, new releases. Valve auto-generates 120×45 and 184×69 from it — **your logo must survive 120×45** |
| **Main capsule** | **1232 × 706** | as above | Front-page carousels and featured sections |
| **Vertical capsule** | **748 × 896** | as above | Seasonal sales and sale pages |
| Page background *(optional)* | **1438 × 810** | | Auto-generated from your last screenshot if omitted |

Source: [Store Graphical Assets](https://partner.steamgames.com/doc/store/assets/standard).

### 4.2 Library assets — all four REQUIRED

| Asset | Exact size | Format | Notes |
|---|---|---|---|
| **Library capsule** | **600 × 900** | PNG | Vertical. "Graphically-centric" |
| **Library header** | **920 × 430** | PNG | Falls back to the store header capsule if omitted |
| **Library hero** | **3840 × 1240** | PNG | Safe area **860 × 380** stays uncropped. **"This image cannot include any text"** |
| **Library logo** | **1280 wide and/or 720 tall** | PNG, **transparent background** | Overlaid on the hero. Choose an anchor: left-bottom, centered-top, centered-middle, or centered-bottom |

Source: [Library Assets](https://partner.steamgames.com/doc/store/assets/libraryassets).
Note: "Library Assets are only visible for applications that have a published
store page" — so they can't be previewed until step 1.11 lands.

### 4.3 Icons — both REQUIRED

| Asset | Exact size | Format |
|---|---|---|
| **Shortcut icon** | **256 × 256** or **512 × 512** | .ico or .png (Valve generates the .ico from a png) |
| **App icon** | **184 × 184** | **.jpg** |

Source: [Community and Client Icons](https://partner.steamgames.com/doc/store/assets/community).
The app icon "will not appear properly on your store page until your app is
published as 'Coming Soon' or as fully released" — don't debug a missing icon
before then.

### 4.4 Screenshots and trailer

- **Screenshots: minimum 5, minimum 1920 × 1080, 16:9.** Valve requires
  **gameplay footage only** — "no concept art or cinematics." This matters for
  SkyGear: **do not use the cutscene shots** as store screenshots. The `screens`
  tool (`SkyGear Tools.bat screens`) already photographs 25 screens at 4 widths;
  the 1920-wide fight frames are the source. Plan on **8–10**, ordered so the
  first three read as: a full deck under boarding pressure, the draft, and a
  vent/keg chain.
- **Trailer: MANDATORY.** "As part of the release process on Steam, you will be
  required to upload a trailer for your product"
  ([Trailers](https://partner.steamgames.com/doc/store/trailer)).
  - Up to **1920 × 1080**, **30/29.97 or 60/59.94 fps**
  - **16:9 preferred**, 4:3 accepted
  - **5,000+ Kbps**, **H.264 video + AAC audio preferred**
  - **.mov, .wmv, or .mp4**
  - Poster image **600 × 380**, thumbnail **232 × 130** — auto-generated, but a
    custom one must be **1920 × 1080** .jpg/.png **and must be an actual frame
    from the video**
  - Practical: lead with gameplay in the first five seconds. **[secondary source]**
- **Total embedded images/GIFs in the description must stay under 15 MB**
  ([Written Description](https://partner.steamgames.com/doc/store/page/description)).

### 4.5 Text fields

| Field | Limit | Status |
|---|---|---|
| **Short description** | Valve says only "limited to a few hundred characters." Widely reported as **300** | **[unverified against a primary source]** — the editor enforces it; write to 300 and check |
| **About This Game** | No character limit documented. 15 MB cap on all embedded media | Verified: the 15 MB figure is Valve's |
| Developer / Publisher | — | Your legal name from §1.3 |
| Release date | "Coming Soon" is a valid answer, and you can give a quarter or year | |
| Genres / Tags | Choose from Valve's lists in the editor. For SkyGear: Action, Indie; tags like Roguelike, Twin Stick Shooter, Tower Defense, Steampunk, Bullet Hell, Singleplayer, Deckbuilding | Tag lists are login-gated; §10 |
| **System requirements** | Free text per OS. Windows only. State Windows 10 64-bit, a **Vulkan-capable GPU** (the Forward+ requirement from `DESIGN.md` §12), ~250 MB disk (build is ~216 MB unpacked), and note the D3D12 fallback measured under SG-25 | |
| Languages | English only | |

**Valve announced changes to store page written descriptions** — I found the
announcement in search but **could not fetch its body** ([announcement
4201376568915048836](https://steamcommunity.com/groups/steamworks/announcements/detail/4201376568915048836)).
Read it before writing final copy; it may have changed the limits above.

### 4.6 The content survey and age rating

Three mandatory sections ([Content Survey](https://partner.steamgames.com/doc/gettingstarted/contentsurvey)):

1. **General Content** — generates regional age ratings shown on the page.
   SkyGear is fantasy violence against boarders, no gore claims to make.
   Germany has a **mandatory USK rating** requirement with its own doc.
2. **Mature Content** — "You must disclose all the adult content you've uploaded
   in your builds, even if it's not accessible or presented in your product."
   Nothing applies here.
3. **Generative AI Content** — **this one is a real decision for SkyGear.** The
   survey distinguishes **Pre-Generated** (AI-created content shipped at launch)
   from **Live-Generated** (created during play). SkyGear's art comes from
   `tools/forge.py` and its 3D models from Meshy — that is **pre-generated AI
   content and must be disclosed.** Disclose it accurately and specifically
   (which assets, which tools); Valve permits it, and a false negative here is
   a genuine takedown risk rather than a rejection you can patch.

### 4.7 Capsule content rules — the ones that get art rejected

In force since **September 1, 2022** ([Graphical Asset Rules](https://partner.steamgames.com/doc/store/assets/rules)).
Base capsules are limited to **"game artwork, the game name, and any official
subtitle."** Explicitly prohibited:

- Review scores of any kind, including Steam's own
- Award names, symbols, or logos
- Discount or promotional copy — no "On Sale Now", no "% off"
- Text or imagery promoting a different product
- **"Any other miscellaneous text"** — this is the one that catches indies.
  **No "DEMO OUT NOW" on the capsule.** **[secondary sources report Valve
  actively rejecting exactly that string since 2024.]**

Requirements: **"a readable product logo/name"** and **"accurate dimensions."**
Non-compliance risks reduced store visibility and ineligibility for Steam sales
and events — so this is not merely a review gate.

Library capsule: logo and optional subtitle, **no other text**. Library hero:
**no text at all**.

### 4.8 The manifest as a queue

Fourteen required images plus one video. This is a work queue for the existing
2D pipeline; the 3D pipeline (Meshy) contributes renders for the hero and
vertical capsule.

```
[ ] header capsule        920 x 430
[ ] small capsule         462 x 174   (test legibility at 120x45)
[ ] main capsule         1232 x 706
[ ] vertical capsule      748 x 896
[ ] library capsule       600 x 900
[ ] library header        920 x 430
[ ] library hero         3840 x 1240  (no text; 860x380 safe area)
[ ] library logo         1280 w / 720 h  PNG alpha
[ ] shortcut icon         256 x 256   .png
[ ] app icon              184 x 184   .jpg
[ ] screenshots x8+      1920 x 1080  16:9, gameplay only, no cutscenes
[ ] trailer              1920 x 1080  H.264/AAC mp4, 5000+ Kbps
[ ] page background      1438 x 810   (optional)
[ ] short description    <= 300 chars
[ ] About This Game      (< 15 MB embedded media)
```

If a demo gets its **own** store page (optional), it needs its own copy of the
capsule set, and Valve requires the content be "specific to the demo and not the
full game." **Recommendation: skip the separate demo page initially.** Take the
minimal-presence option — the demo appears as a button on the SkyGear page —
and add a demo page later if it earns one. That halves this manifest.

---

## 5. Review, timing, and a realistic calendar

### The documented numbers

- **Store page review: "typically takes 3-5 business days to complete, but
  you'll want to submit your page for review at least 7 business days before you
  want it live."**
- **Build review: "typically takes 3-5 business days... we ask that you plan for
  at least 7 business days."**
- **Order is fixed: "you'll need to submit your store page for review before you
  can submit your build for review."**
- **"Once your game has been reviewed and approved, there is no need to go
  through review again. You are free to update your game as much as you need
  to."** — this is the good news for the loop: after the demo is approved,
  SteamPipe pushes are as frictionless as butler pushes.
- Approved titles do not release themselves; you press the button.

Sources: [Review Process](https://partner.steamgames.com/doc/store/review_process),
[Releasing](https://partner.steamgames.com/doc/store/releasing).

### What gets rejected

Valve does not publish a rejection list. From the rules that *are* published,
plus **[secondary sources]**:

- **Wrong pixel dimensions** — pixel-exact or bounced. Cheapest failure to avoid.
- **Text on capsules** beyond logo and subtitle (§4.7).
- **Illegible logo at 120 × 45.**
- **Non-gameplay screenshots** — cutscenes and concept art are disallowed by the
  screenshot requirement.
- Store copy that describes features the build does not have. Given how fast
  `STATUS.md` moves, re-read the copy against the shipping build before
  submitting.
- Build review checks the game "starts up properly" — a Vulkan-only Forward+
  build on a reviewer's machine is a real risk. `scripts/renderer_check.gd`
  already reports the driver; make sure the D3D12 path (verified working under
  SG-25) is reachable and that the Compatibility warning is legible, because a
  reviewer who lands on Compatibility gets a game with the Decal telegraphs
  missing (`DESIGN.md` §13m).

### Calendar from nothing, starting 2026-08-03

Business days, with the waits called out. Two columns because the paperwork wait
is the only real unknown.

| Phase | Optimistic | Realistic | Blocking on |
|---|---|---|---|
| Steamworks signup, agreement | Aug 3 | Aug 3 | you |
| Tax + bank + identity verification | Aug 10 | **Aug 24** | **Valve — 2–7 business days documented for tax alone; bank verification undocumented** |
| Pay $100, create app "SkyGear" | Aug 10 | Aug 24 | you. **Starts the 30-day clock** |
| Asset manifest built (§4) | Aug 17 | Aug 28 | the loop — **runs in parallel from Aug 3, do not serialize this** |
| Store page filled, marked ready for review | Aug 18 | Aug 31 | you upload, loop supplies |
| **Store review** | Aug 25 | **Sep 9** | Valve, 3–5 business days, plan 7 |
| **Post as Coming Soon → wishlists begin** | **Aug 25** | **Sep 9** | you |
| Demo app created, depots configured, build uploaded | Aug 27 | Sep 11 | loop (`pack_steam.py`) |
| Demo store presence marked ready | Aug 28 | Sep 14 | you |
| **Demo review (store + build)** | Sep 4 | **Sep 23** | Valve |
| 30 days from fee payment elapses | Sep 9 | **Sep 23** | calendar |
| **Demo released, wider community playing** | **Sep 9** | **Sep 24** | you press it |
| Full game release earliest | — | any time ≥2 weeks after Coming Soon and ≥30 days after fee | |

**Read across:** "page live with a demo" is **five to seven weeks** from a
standing start, of which roughly three weeks is pure waiting. The loop's work
(assets, build tooling) is not the critical path and never will be. **Your
paperwork is.**

Against that calendar, **Next Fest October 2026 (register by Aug 31) requires
the optimistic column to hold at every step.** February 2027 is the sane target.

---

## 6. Build upload — SteamPipe vs. the butler flow you have

### What is the same

Both are a CLI that logs in, diffs against the last upload, and ships only what
changed. Both want a *directory*, not a zip. Both are scriptable.

### What is different, and it matters

| | **butler (itch)** | **SteamPipe (Steam)** |
|---|---|---|
| Artifact | you push `SkyGear-Windows.zip` | you push a **directory** — Steam does its own compression and delta-chunking at ~1 MB granularity. **Do not zip.** This is the single biggest change to `pack_itch.py`'s logic |
| Destination | a *channel* (`user/game:windows`) | a **depot** (a numeric ID under your App ID) |
| Config | none, flags on the command line | **`.vdf` script files** — an app-build VDF and optionally per-depot VDFs |
| Credentials | butler API key | a **dedicated build Steam account** with "Edit App Metadata" and "Publish App Changes To Steam", plus a phone or Steam Mobile App attached to set a build live |
| Going live | immediate | build lands, then you **manually** set it live on the default branch in App Admin. `"SetLive" "branchname"` works for **beta branches only** |
| First push | just works | needs **build review** the first time |
| Dry run | — | **`"Preview" "1"`** generates logs and manifests without uploading. Use it |

Source: [Uploading to Steam](https://partner.steamgames.com/doc/sdk/uploading).

### Depot layout for SkyGear

Simple, because the game is one file. The demo is a *separate App ID with its
own depot* — it does not share the base game's depot.

```
App 0000000  SkyGear            depot 0000001  windows content
App 0000002  SkyGear Demo       depot 0000003  windows demo content
```

### `tools/pack_steam.py` — concrete sketch

Parallel to `pack_itch.py`, sharing its export step. **Not written yet — this is
the spec, not the code.**

```
python tools/pack_steam.py --app demo            # export + stage + build vdf + upload
python tools/pack_steam.py --app demo --preview  # everything except the upload
python tools/pack_steam.py --app game --no-export
```

What it does, in order:

1. **Export**, byte-identical to `pack_itch.py`: same `--export-release
   "Windows Desktop"` invocation, same `GODOT` env override, same
   "Godot will not create the export directory for you" guard. Reuse the
   function; do not fork it.
2. **Stage a directory**, not a zip:
   `builds/steam/<app>/content/SkyGear-Godot.exe` plus `README.txt`. Wipe the
   directory first — SteamPipe ships what is in `content/`, so a stale file from
   a previous build silently ships forever.
3. **Refuse to ship a dirty tree.** `STATUS.md` records this being bitten three
   times in one day: build from a clean `git worktree` of HEAD or you ship a
   half-written file. Make this a hard failure, not a warning, and record the
   commit SHA into the staged `README.txt` so a bug report names a build.
4. **Gate on the harness.** `SkyGear Tools.bat harness` must be green — 926
   checks, and a store build is exactly the artifact that should never ship red.
5. **Generate the VDFs** from `tools/steam.json` (app IDs, depot IDs, branch
   names — App IDs are *not* secret, but keep the build account password out of
   the repo the way `MESHY_API_KEY` already is; read from `STEAM_BUILD_PASSWORD`
   or a gitignored `tools/.steam_key`, and add `steamcmd` credentials to the
   `git grep` pre-commit habit).

   ```
   "AppBuild"
   {
     "AppID"       "0000002"
     "Desc"        "SkyGear Demo — <git sha> — <n> harness checks"
     "ContentRoot" "..\\..\\builds\\steam\\demo\\content\\"
     "BuildOutput" "..\\..\\builds\\steam\\demo\\output\\"
     "Preview"     "0"
     "SetLive"     ""
     "Depots"
     {
       "0000003"
       {
         "FileMapping" { "LocalPath" "*"  "DepotPath" "."  "recursive" "1" }
       }
     }
   }
   ```

6. **Upload**:
   `steamcmd.exe +login <build_account> <password> +run_app_build <path>.vdf +quit`
7. **Report, and refuse to lie.** Print the BuildID, the depot manifest ID, the
   staged byte count, and — critically — **"this is NOT live; set it live in App
   Admin"**, mirroring the way `pack_itch.py` prints its "do NOT tick 'played in
   the browser'" reminder. A script that implies it shipped when it staged is the
   *data with no reader* failure mode wearing a different hat.
8. **Default `SetLive` to a beta branch**, never blank-to-default. Setting live
   on default is a web-UI action anyway, so the script should never pretend to.

Size note: the itch zip is 94.5 MB (`STATUS.md`, 2026-08-02); the task brief
cites ~135 MB / ~216 MB unpacked. **These disagree and should be measured before
anyone quotes a download size on the store page.** Either way, SteamPipe's
chunked deltas mean subsequent pushes are far smaller than the butler zip
re-upload.

### Do you need the Steamworks SDK in the game?

**No, not for this.** Nothing in the store-page or demo path requires calling
Steam's API. Achievements, cloud saves, the overlay's rich presence and the
Steam Input layer all do, and Godot needs the third-party **GodotSteam** module
for any of it. **Keep that out of scope until the demo is live** — it is a
native module that changes how the project builds, and it is not on the critical
path to a single wishlist.

---

## 7. Wishlists, and getting real feedback

### How wishlists actually work

I **could not reach Valve's wishlist documentation** — the marketing doc index
resolved but not the page body (§10). So this section is deliberately thin on
Valve-sourced mechanics, and what follows is what the *demo* doc supports plus
clearly-labelled general knowledge.

From primary sources:

- Wishlists become possible **only once the page is public as Coming Soon**
  ([Coming Soon](https://partner.steamgames.com/doc/store/coming_soon): the page
  "Allows players to add your game to their Wishlist").
- Valve: **"there's not a strong downside to having a store page up for a long
  time ahead of release,"** provided the game does not change significantly.
  This is an explicit endorsement of putting the page up early — do it.
- The demo's **one-time wishlist notification** (§2), available for two weeks
  after the demo first goes live, once ever.
- Valve rate-limits notifications: a **two-week cooldown between wishlist
  notifications per App ID**, to avoid oversaturation.

### Does a demo help or hurt wishlists?

**[This is genuinely contested and I will not pretend otherwise.]** The
mechanical case for a demo since 2024 is strong: demos get independent store
surfaces, appear in New & Trending, and are the entry requirement for Next Fest.
The counter-argument circulating among developers is that a satisfying demo can
substitute for the purchase. I found no Valve data either way. For SkyGear
specifically — a run-based game where the loop *is* the pitch — a demo that ends
at wave 4 or 6, or caps at Heat 0 and one class, is the obvious shape: it shows
the shape×element matrix and the draft, and stops before the Colossus.

**Concretely, the demo cut I would propose:** waves 1–6, Captain only, Heat 0,
no fittings/berths, results screen intact, and an end card that says what the
full game has. That withholds the second class, the boss, and all of the
between-run meta — the three things that make someone want the rest.

### Practical playtest feedback from friends

Since the friends round runs on itch.io, the feedback machinery is yours to
build and does not touch Steam:

- **The run log already exists.** `scripts/runlog.gd` writes
  `user://runs.json`, last 60 runs, with per-slot damage attribution and range
  buckets. Ask friends to send that file. It is worth ten survey responses,
  and it is the thing `STATUS.md` says the telemetry was built for: *"one run is
  an anecdote; the reason v11 tracks damage per skill and time at each range is
  so ten of them read as a shape."*
- **The results screen is already a copyable run report** — tell them the copy
  key exists, because a screenshot loses the numbers.
- Three questions, not a form: *what wave did you die on, what did you not
  understand, and when were you bored.*
- Once the demo is public, Steam gives you the **Community Hub** on the Coming
  Soon page (Valve names this as a Coming Soon benefit) and demo playtime
  statistics — but a Steam demo has no built-in feedback channel beyond
  discussions and reviews.

### Next Fest, in one paragraph

Eligibility ([Next Fest: October 2026](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/2026october)):
a Steamworks account in good standing; a **published, public store page**; **not**
a prologue or chapter of existing content; **"includes a publicly playable demo
by the time the festival begins"**; the game must not release before the fest
ends; and **"titles may only participate in ONE Next Fest."** Registration is
done **from the base game, not the demo**. It is the single largest free
visibility event available to an unknown indie game, and you get exactly one
shot, which is the whole argument for not rushing it.

---

## 8. Order of operations, condensed

```
NOW (you)      Steamworks signup -> agreement -> tax (W-8BEN) -> bank -> ID
NOW (you)      send friends the itch.io link.  Do not wait for Steam.
NOW (loop)     build the 14-image asset manifest + trailer + copy drafts
NOW (loop)     write tools/pack_steam.py against the spec in section 6

WAIT           verification clears (1-3 weeks, mostly Valve)

THEN (you)     pay $100 -> create ONE app "SkyGear"   [30-day clock starts]
THEN (you)     content survey (disclose pre-generated AI assets)
THEN (you)     upload assets, write the page, set a price
THEN (you)     Mark As Ready For Review

WAIT           3-5 business days (plan 7)

THEN (you)     Post as Coming Soon        <-- WISHLISTS START HERE
THEN (loop)    cut the demo build (waves 1-6, Captain, Heat 0)
THEN (you)     Add Demo -> free child App ID -> depots
THEN (loop)    pack_steam.py --app demo
THEN (you)     mark demo ready for review

WAIT           3-5 business days, and the 30-day clock

THEN (you)     Release Demo
THEN (you)     RE-PUBLISH the base store page or the button won't appear
THEN (you)     fire the one-time wishlist notification -- but only once the
               wishlist number is worth spending it on

LATER          Next Fest, February 2027.  One shot, ever.
```

---

## 9. Risks specific to this project

1. **Vulkan-only is a review risk and a player risk.** Forward+ is a deliberate
   choice (`DESIGN.md` §12) and the right one, but the store page must state a
   Vulkan-capable GPU in system requirements, and a reviewer who lands on the
   Compatibility fallback gets a game **missing every telegraph** because
   Compatibility cannot draw `Decal` (`DESIGN.md` §13m). Verify
   `scripts/renderer_check.gd`'s warning is impossible to miss before submitting.
2. **Store copy drifting ahead of the build.** `STATUS.md` changes weekly and
   several sections record features that were later cut (the stowage spine,
   deckwork's crate family) or turned off (the cape). Copy written today may
   describe a game that no longer exists in three weeks. Re-read before submit.
3. **The generative-AI disclosure is not optional and not cosmetic.** Meshy
   models and `forge.py` art are pre-generated AI content. Disclose precisely.
4. **The one-time levers.** The demo wishlist notification (once, ever) and Next
   Fest (once, ever). Both are easy to waste early.
5. **Legal name consistency.** §1.3 and §1.5 must match, and the store page's
   Developer field will show it. Decide now whether that is "Alex R" or a
   business name, because changing it later touches banking.
6. **A build-account password in the repo.** `pack_steam.py` introduces exactly
   the hazard `tools/meshy.py` already guards against. Same rule, same
   `git grep` habit, extended.

---

## 10. What I could not verify

Stated plainly, per this project's rule that a claim is measured or sourced.

**Pages that require a Steamworks partner login and that I could not reach.**
Everything behind `partner.steamgames.com` that is not public documentation —
the app landing page, the release checklist itself, the tag and genre pickers,
the pricing matrix, the key request form, the build upload page, and the
Playtest configuration. **What he will find there:** the release checklist is a
literal list of green/grey checkboxes on the app's landing page, each linking to
the editor for that item; "Mark As Ready For Review" is a button in the top
section of that page; the tag picker offers Valve's fixed tag list with a
suggestion field; and the builds page lives at
`partner.steamgames.com/apps/builds/<AppID>`, which is where a SteamPipe build is
promoted to a branch.

**Specific claims I could not source to Valve:**

- **Whether creating a demo App ID costs a second $100.** Valve's demo doc
  mentions no fee; the Steam Direct doc says the fee applies to "each new app you
  wish to distribute." Secondary sources say demos are exempt. **This is the
  single most consequential unverified item in this document** and it is a
  one-question support ticket. Ask before budgeting.
- **Whether the 30-day post-fee waiting period gates a free demo's release**, or
  only the paid game's. Not addressed in the demo docs. Assume it does.
- **The exact short-description character limit.** Valve says "a few hundred";
  300 is from secondary sources and from the editor's own counter.
- **File formats for the store capsules.** Valve's standard-assets page states
  dimensions but not formats. Library assets and icons *are* format-specified.
- **The bank verification duration.** Not documented by Valve anywhere I could
  reach. The 1–3 week planning figure is inference from the documented 2–7
  business day tax step plus community reports.
- **Whether Valve accepts a Canadian SIN as the "foreign TIN"** for W-8BEN
  treaty benefits, and **whether Canadian copyright royalties land at 0%**. The
  doc gives a 0–30% range and says a foreign or US TIN is required, nothing more.
  This is an accountant question, not a research question.
- **The body of "The Great Steam Demo Update, 2024."** Both the Community and
  Steam News copies returned page chrome only across repeated attempts. The
  discoverability claims in §2 rest on secondary summaries; the demo mechanics
  in §2 are from Valve's demo documentation and are solid.
- **The body of "Changes Coming to Store Page Written Descriptions."** Same
  problem. Read it before finalising copy — it may supersede §4.5.
- **Valve's wishlist documentation.** The marketing index resolved, the page did
  not. §7's mechanics are thinner than they should be as a result.
- **Whether SkyGear currently has controller support.** Not established from the
  repo in this pass; `scripts/keybinds.gd` covers keyboard rebinding only. Do
  not tick "Full Controller Support" without checking.
- **The build's actual size.** `STATUS.md` says the itch zip is 94.5 MB; the
  brief says ~135 MB / ~216 MB unpacked. Measure before publishing a number.

---

## Sources

- [Steamworks Onboarding](https://partner.steamgames.com/doc/gettingstarted/onboarding)
- [Getting Started](https://partner.steamgames.com/doc/gettingstarted)
- [Steam Direct Fee](https://partner.steamgames.com/doc/gettingstarted/appfee)
- [Taxes FAQ](https://partner.steamgames.com/doc/finance/taxfaq)
- [Content Survey](https://partner.steamgames.com/doc/gettingstarted/contentsurvey)
- [Demos](https://partner.steamgames.com/doc/store/application/demos)
- [Applications](https://partner.steamgames.com/doc/store/application)
- [Steam Playtest](https://partner.steamgames.com/doc/features/playtest)
- [Testing On Steam](https://partner.steamgames.com/doc/store/testing)
- [Branches](https://partner.steamgames.com/doc/store/application/branches)
- [Steam Keys](https://partner.steamgames.com/doc/features/keys)
- [Coming Soon](https://partner.steamgames.com/doc/store/coming_soon)
- [Releasing](https://partner.steamgames.com/doc/store/releasing)
- [Review Process](https://partner.steamgames.com/doc/store/review_process)
- [Store Page, Building and Editing](https://partner.steamgames.com/doc/store/editing)
- [Store Page Written Description](https://partner.steamgames.com/doc/store/page/description)
- [Graphical Assets — Overview](https://partner.steamgames.com/doc/store/assets)
- [Store Graphical Assets](https://partner.steamgames.com/doc/store/assets/standard)
- [Library Assets](https://partner.steamgames.com/doc/store/assets/libraryassets)
- [Community and Client Icons](https://partner.steamgames.com/doc/store/assets/community)
- [Graphical Asset Rules](https://partner.steamgames.com/doc/store/assets/rules)
- [Trailers](https://partner.steamgames.com/doc/store/trailer)
- [Uploading to Steam (SteamPipe)](https://partner.steamgames.com/doc/sdk/uploading)
- [Steam Next Fest](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest)
- [Steam Next Fest: October 2026](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/2026october)
- [The Great Steam Demo Update, 2024](https://steamcommunity.com/groups/steamworks/announcements/detail/4155211502162971563) — body unreachable
- [Changes Coming to Store Page Written Descriptions](https://steamcommunity.com/groups/steamworks/announcements/detail/4201376568915048836) — body unreachable
