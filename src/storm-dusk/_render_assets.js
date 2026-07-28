/* ---------------------------------------------------------------------------
   ASSETS — the §4 manifest. Every entry names the exact file the art pipeline
   is expected to deliver (§2.1 naming). If the file is absent — or the page was
   opened straight off the filesystem, where browsers refuse file:// image reads
   — the renderer falls back to the procedural painter registered beside it, in
   the same style. The game is fully playable either way.
--------------------------------------------------------------------------- */
const ASSET_MANIFEST = {
  // 4.1 hero — our captain fills the H1 Sky-Corsair slot
  hero_front_idle:   { file:'assets/heroes/corsair_front_idle.png',   w:512,  h:512  },
  hero_back_idle:    { file:'assets/heroes/corsair_back_idle.png',    w:512,  h:512  },
  hero_front_attack: { file:'assets/heroes/corsair_front_attack.png', w:512,  h:512  },

  // 4.2 enemies — SKYGEAR's roster mapped onto the spec archetypes (§6.1)
  SCRAPPER_front_idle:   { file:'assets/enemies/automaton_front_idle.png',   w:512, h:512 },
  SCRAPPER_back_idle:    { file:'assets/enemies/automaton_back_idle.png',    w:512, h:512 },
  SCRAPPER_front_attack: { file:'assets/enemies/automaton_front_attack.png', w:512, h:512 },
  SWARM_front_idle:      { file:'assets/enemies/gremlin_front_idle.png',     w:384, h:384 },
  SWARM_front_attack:    { file:'assets/enemies/gremlin_front_attack.png',   w:384, h:384 },
  GUNNER_front_idle:     { file:'assets/enemies/drone_front_idle.png',       w:448, h:448 },
  GUNNER_front_attack:   { file:'assets/enemies/drone_front_attack.png',     w:448, h:448 },
  ARMORED_front_idle:    { file:'assets/enemies/furnace_knight_front_idle.png',   w:640, h:640 },
  ARMORED_back_idle:     { file:'assets/enemies/furnace_knight_back_idle.png',    w:640, h:640 },
  ARMORED_front_attack:  { file:'assets/enemies/furnace_knight_front_attack.png', w:640, h:640 },
  BOSS_front_idle:       { file:'assets/enemies/colossus_front_idle.png',    w:1024, h:1024 },
  BOSS_back_idle:        { file:'assets/enemies/colossus_back_idle.png',     w:1024, h:1024 },
  BOSS_front_attack:     { file:'assets/enemies/colossus_front_attack.png',  w:1024, h:1024 },

  // 4.3 props
  prop_crate:    { file:'assets/props/crate_small.png',      w:384, h:384 },
  prop_crates:   { file:'assets/props/crate_stack.png',      w:512, h:640 },
  prop_barrel:   { file:'assets/props/barrel.png',           w:320, h:384 },
  prop_rope:     { file:'assets/props/rope_coil.png',        w:320, h:256 },
  prop_cannon:   { file:'assets/props/cannon_deck.png',      w:640, h:512 },
  prop_mast:     { file:'assets/props/mast_section.png',     w:512, h:1024 },
  prop_railing:  { file:'assets/props/railing_segment.png',  w:512, h:384 },
  prop_lantern:  { file:'assets/props/lantern_post.png',     w:384, h:768 },
  prop_vent:     { file:'assets/props/steam_vent.png',       w:384, h:320 },
  prop_hatch:    { file:'assets/props/hatch_cargo.png',      w:512, h:384 },
  prop_ballista: { file:'assets/props/harpoon_ballista.png', w:640, h:512 },
  prop_wreck:    { file:'assets/props/colossus_wreck.png',   w:1024, h:768 },

  // 4.4 environment
  env_sky:       { file:'assets/env/sky_backdrop.png',     w:2048, h:1024 },
  env_clouds_far:{ file:'assets/env/clouds_far.png',       w:2048, h:512  },
  env_clouds_near:{file:'assets/env/clouds_near.png',      w:2048, h:512  },
  env_airship:   { file:'assets/env/airship_distant.png',  w:512,  h:256  },
  env_envelope:  { file:'assets/env/envelope_top.png',     w:2048, h:768  },
  env_bow:       { file:'assets/env/bow_prow.png',         w:1024, h:640  },

  // 4.5 ground circles
  rune_enemy:        { file:'assets/ground/rune_enemy.png',        w:512, h:512 },
  rune_enemy_filled: { file:'assets/ground/rune_enemy_filled.png', w:512, h:512 },
  rune_player:       { file:'assets/ground/rune_player.png',       w:512, h:512 },
  decal_scorch:      { file:'assets/ground/decal_scorch.png',      w:384, h:384 },
  decal_oil:         { file:'assets/ground/decal_oil.png',         w:384, h:384 },
  decal_gears:       { file:'assets/ground/decal_gear_scatter.png',w:384, h:384 },
  shadow_blob:       { file:'assets/ground/shadow_blob.png',       w:256, h:256 },

  // V5 lane amendment — the systems that were still wholly procedural: the
  // cargo runs that make lane commitment real, your own crew, and the boarding
  // hulk with its sealed/open/destroyed states. Wired here first so the art
  // drops straight in; until the files exist every one falls back as usual.
  prop_cargo_wall:    { file:'assets/props/cargo_wall_module.png',      w:512,  h:512 },
  prop_hulk_sealed:   { file:'assets/props/boarding_hulk_sealed.png',   w:1024, h:640 },
  prop_hulk_open:     { file:'assets/props/boarding_hulk_open.png',     w:1024, h:640 },
  prop_hulk_wreck:    { file:'assets/props/boarding_hulk_destroyed.png',w:1024, h:640 },
  prop_cannon_dead:   { file:'assets/props/cannon_deck_destroyed.png',  w:640,  h:512 },
  CREW_front_idle:    { file:'assets/allies/crew_front_idle.png',       w:384,  h:384 },
  CREW_back_idle:     { file:'assets/allies/crew_back_idle.png',        w:384,  h:384 },
  CREW_front_attack:  { file:'assets/allies/crew_front_attack.png',     w:384,  h:384 },

  // 4.6 fx
  fx_steam:  { file:'assets/fx/puff_steam.png',      w:256, h:256 },
  fx_smoke:  { file:'assets/fx/puff_smoke_dark.png', w:256, h:256 },
  fx_impact: { file:'assets/fx/burst_impact.png',    w:320, h:320 },
  fx_bolt:   { file:'assets/fx/bolt_tesla.png',      w:256, h:128 },
  fx_slash:  { file:'assets/fx/slash_arc.png',       w:384, h:256 },
  fx_ember:  { file:'assets/fx/ember_particle.png',  w:64,  h:64  },

  // 4.7 ui
  ui_portrait: { file:'assets/ui/portrait_corsair.png', w:512,  h:512 },
  ui_frame:    { file:'assets/ui/frame_hud.png',        w:1024, h:256 },
  ui_gauge:    { file:'assets/ui/gauge_ring.png',       w:256,  h:256 },
  // skill icons — SKYGEAR's six shapes mapped onto the spec's icon set
  ui_icon_slash:   { file:'assets/ui/icon_skill_slash.png',   w:256, h:256 },  // CLOSEHIT
  ui_icon_hook:    { file:'assets/ui/icon_skill_hook.png',    w:256, h:256 },  // LINE_BURST
  ui_icon_cone:    { file:'assets/ui/icon_skill_cone.png',    w:256, h:256 },  // CONE
  ui_icon_aoe:     { file:'assets/ui/icon_skill_aoe.png',     w:256, h:256 },  // RANGED_AOE
  ui_icon_ult:     { file:'assets/ui/icon_skill_ult.png',     w:256, h:256 },  // CHAIN
  ui_icon_turret:  { file:'assets/ui/icon_skill_turret.png',  w:256, h:256 },  // RAY
  // The three passive shapes had no icon slot, so painted art had nowhere to go.
  ui_icon_field:   { file:'assets/ui/icon_skill_field.png',   w:256, h:256 },  // AURA
  ui_icon_pulse:   { file:'assets/ui/icon_skill_pulse.png',   w:256, h:256 },  // PULSE
  ui_icon_sentry:  { file:'assets/ui/icon_skill_sentry.png',  w:256, h:256 },  // SENTRY
  // These three have no draw site. `dash` and `barrier` were speculative icons
  // for a UI that never used them, and `cog` was for a currency v10 explicitly
  // does not have. They stayed in the manifest, loaded, and counted toward the
  // "32/67 art" badge on the title — which is how that badge came to overstate
  // how much of the game was painted. `unused` keeps the slot documented and
  // keeps it out of the count; delete the flag the day something draws them.
  // v11 — the close-quarters loop's own art. The gauge and the vent are new
  // verbs, so they get icons rather than borrowing a shape glyph, and salvage
  // gets a real pile on the deck instead of the spinning procedural cog.
  ui_icon_pressure:{ file:'assets/ui/icon_pressure.png',      w:256, h:256 },
  ui_icon_vent:    { file:'assets/ui/icon_vent.png',          w:256, h:256 },
  ui_icon_salvage: { file:'assets/ui/icon_salvage.png',       w:256, h:256 },
  prop_scrap:      { file:'assets/props/salvage_pile.png',    w:256, h:256 },
  prop_brazier:    { file:'assets/props/brazier.png',         w:384, h:512 },

  ui_icon_dash:    { file:'assets/ui/icon_skill_dash.png',    w:256, h:256, unused:true },
  ui_icon_barrier: { file:'assets/ui/icon_skill_barrier.png', w:256, h:256, unused:true },
  ui_icon_cog:     { file:'assets/ui/icon_currency_cog.png',  w:128, h:128, unused:true },
};

/* Load order. Everything has a procedural fallback, so nothing here decides
   whether the game runs — it decides what a player on a slow line sees painted
   first. The order is by how much of the screen the asset owns and how early it
   is on screen: the captain before the enemies she is fighting, the fight
   before the deck it happens on, the deck before the props scattered on it.

   Anything not named falls into the last tier, so a new manifest entry loads
   late rather than silently jumping the queue. */
const ASSET_PRIORITY = [
  // 1 · the captain. On screen from the first frame and never off it.
  ['hero_front_idle', 'hero_front_attack', 'hero_back_idle'],
  // 2 · what wave 1 sends at her, plus the crew standing beside her.
  ['SCRAPPER_front_idle', 'SCRAPPER_front_attack', 'SCRAPPER_back_idle',
   'CREW_front_idle', 'CREW_front_attack', 'CREW_back_idle'],
  // 3 · the structures that make the map readable.
  ['prop_cargo_wall', 'prop_cannon', 'prop_cannon_dead',
   'prop_hulk_sealed', 'prop_hulk_open', 'prop_hulk_wreck'],
  // 4 · ground marks. Telegraphs are read every second of every fight.
  ['rune_enemy', 'rune_enemy_filled', 'rune_player', 'shadow_blob',
   'decal_scorch', 'decal_oil', 'decal_gears'],
  // 5 · the rest of the roster, in the order the waves introduce it.
  ['SWARM_front_idle', 'SWARM_front_attack',
   'GUNNER_front_idle', 'GUNNER_front_attack',
   'ARMORED_front_idle', 'ARMORED_front_attack', 'ARMORED_back_idle',
   'BOSS_front_idle', 'BOSS_front_attack', 'BOSS_back_idle'],
  // 6 · the HUD.
  ['ui_portrait', 'ui_frame', 'ui_gauge',
   'ui_icon_slash', 'ui_icon_hook', 'ui_icon_cone', 'ui_icon_aoe',
   'ui_icon_ult', 'ui_icon_turret', 'ui_icon_field', 'ui_icon_pulse', 'ui_icon_sentry'],
  // 7 · the sky. Big files, and the procedural sky is good.
  ['env_sky', 'env_clouds_far', 'env_clouds_near', 'env_envelope', 'env_bow', 'env_airship'],
];

/* Generated motion is deliberately narrower than the still-art manifest:
   these are proven cycles, not substitutes for every attack/back state. All
   frames of a cycle share one measured crop so the figure cannot jitter as its
   silhouette changes — which is why `meta` is authored per cycle rather than
   measured per frame the way stills are.

   One horizontal strip per cycle, not loose frames. The two delivered cycles
   were 28 files and 3.9 MB, more than every still in the game combined; packed
   they are 33-35% smaller (measured) and one request instead of thirteen.
   `python src/pack-animations.py` produces them. */
/* `fig` is how much of the frame the FIGURE fills, and it is per cycle rather
   than one shared constant because the takes are not framed identically:
   python src/check-animations.py measures 71% for the captain's run and 78%
   for her idle. Sharing one number would have drawn the idle about ten percent
   larger, so she would visibly grow the moment she stopped running. The number
   below is the measured one — run check-animations.py after ingesting a cycle
   and copy what it reports. */
const ANIMATION_MANIFEST = {
  hero_run: {
    strip:'assets/animations/hero_run.png', count:13, fps:12,
    meta:{ anchor:0.920, cx:0.500, fig:0.710 },
  },
  hero_idle: {
    strip:'assets/animations/hero_idle.png', count:12, fps:12, pingpong:true,
    meta:{ anchor:0.920, cx:0.500, fig:0.780 },
  },
  SCRAPPER_run: {
    strip:'assets/animations/scrapper_run.png', count:15, fps:12,
    meta:{ anchor:0.920, cx:0.500, fig:0.660 },
  },
  /* Delivered 2026-07-27, the first cycle forged after the v11 playthrough
     asked where the missing animation was going to come from. TEN frames, not
     the twelve ANIMATION-BRIEF asks for: loom-ingest writes whatever the cut
     loop produced and the manifest has to agree with the file, or the slicer
     reads frames that are not there. Measured swing 0.3%, and it is pingpong
     anyway, so the loop boundary is exact by construction (§6b). */
  SCRAPPER_idle: {
    strip:'assets/animations/scrapper_idle.png', count:10, fps:10, pingpong:true,
    meta:{ anchor:0.920, cx:0.500, fig:0.790 },
  },
};

/* The rest of the cast, wired but not yet delivered. A cycle listed here is
   requested the moment the file exists and ignored until then, exactly like a
   still — so a strip can be dropped into assets/animations/ and appear in the
   game on the next build with no engine change.

   `once: true` marks a cycle that plays through and stops rather than looping.
   An attack is not a loop: its readable frame lands in the first third and
   holding the last frame is what makes the recovery read.

   Frame counts are what ANIMATION-BRIEF asks for. loom-ingest writes whatever
   the cut loop produced, and check-animations.py compares the two, so a
   mismatch is caught at ingest rather than as a sprite that jitters in game. */
const ANIMATION_PENDING = {
  hero_attack:      { strip:'assets/animations/hero_attack.png',   count:10, fps:14, once:true },
  SCRAPPER_attack:  { strip:'assets/animations/scrapper_attack.png', count:10, fps:14, once:true },
  CREW_idle:        { strip:'assets/animations/crew_idle.png',   count:12, fps:12, pingpong:true },
  CREW_run:         { strip:'assets/animations/crew_run.png',    count:13, fps:12 },
  CREW_attack:      { strip:'assets/animations/crew_attack.png', count:10, fps:14, once:true },
  ARMORED_idle:     { strip:'assets/animations/armored_idle.png',   count:12, fps:12, pingpong:true },
  ARMORED_run:      { strip:'assets/animations/armored_run.png',    count:14, fps:12 },
  ARMORED_attack:   { strip:'assets/animations/armored_attack.png', count:10, fps:14, once:true },
  SWARM_run:        { strip:'assets/animations/swarm_run.png',    count:12, fps:14 },
  SWARM_attack:     { strip:'assets/animations/swarm_attack.png', count:8,  fps:16, once:true },
  GUNNER_idle:      { strip:'assets/animations/gunner_idle.png',   count:12, fps:12, pingpong:true },
  GUNNER_attack:    { strip:'assets/animations/gunner_attack.png', count:10, fps:14, once:true },
  BOSS_idle:        { strip:'assets/animations/colossus_idle.png',   count:14, fps:10, pingpong:true },
  BOSS_attack:      { strip:'assets/animations/colossus_attack.png', count:12, fps:12, once:true },
};
/* Wired, but NOT requested (v12.1).

   These entries exist so the engine already knows how to draw every cycle: a
   delivered strip needs no code, only its entry moved up into the manifest
   above. What they must not do is generate a network request. Packaging the
   game for itch and watching the console showed fourteen 404s on every single
   load — one per undelivered cycle — which is exactly the failure the audio
   side has a generated delivery index to avoid, and which nobody had ever
   looked for on the art side because a 404 on a fallback-covered asset is
   invisible while playing.

   `pending: true` keeps the slot documented and keeps the loader off it. The
   delivery step is: ingest the strip, move its entry into ANIMATION_MANIFEST
   with the frame count the cut loop actually produced. */
for (const k in ANIMATION_PENDING){
  const spec = ANIMATION_PENDING[k];
  spec.meta = { anchor:0.920, cx:0.500, fig:0.840 };
  spec.pending = true;
  ANIMATION_MANIFEST[k] = spec;
}

/* V5 loads production art by default; ?assets=0 is the clean procedural
   fallback. Older builds remain opt-in and can turn art on with
       skygear.html?assets=1
   or by setting window.SKYGEAR_USE_ASSETS = true before this script runs.
   (Note: browsers block file:// image reads, so serving over http is required
   once real PNGs are in place — the procedural build needs no server at all.) */
/* An image model will not crop 66 assets to a consistent frame, and the first
   four proved it: the figure's feet landed anywhere from 79.7% to 88.7% down
   the canvas. Rather than bounce them back for a re-crop, the engine measures
   each sprite's real alpha bounds on load and derives its own anchor, centre
   and figure height. Every asset then sits on the deck at the right size no
   matter how it was framed. */
function measureSprite(img){
  const N = 96;                                  // downsample; we only need bounds
  const cn = document.createElement('canvas');
  cn.width = cn.height = N;
  const c = cn.getContext('2d', { willReadFrequently: true });
  c.drawImage(img, 0, 0, N, N);
  let data;
  try { data = c.getImageData(0, 0, N, N).data; }
  catch (e) { return { anchor: 0.92, cx: 0.5, fig: 0.86 }; }   // tainted; fall back
  let top = -1, bot = -1, minX = N, maxX = -1;
  for (let y = 0; y < N; y++){
    let rowHas = false;
    for (let x = 0; x < N; x++){
      if (data[(y * N + x) * 4 + 3] > 40){
        rowHas = true;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
      }
    }
    if (rowHas){ if (top < 0) top = y; bot = y; }
  }
  if (top < 0) return { anchor: 0.92, cx: 0.5, fig: 0.86 };
  return {
    anchor: (bot + 1) / N,                       // where the feet are
    cx: ((minX + maxX + 1) / 2) / N,             // horizontal centre of the figure
    fig: Math.max(0.15, (bot - top + 1) / N),    // how much canvas the figure fills
  };
}

/* The loader.

   The game has always booted instantly — every asset has a procedural painter
   beside it, so a missing file degrades one sprite. What it did not do was
   *arrive* instantly: it fired sixty-odd image requests in one go, and the
   browser served them in manifest order over whatever bandwidth was going. On
   a 3 Mbit line that means the 2048x512 cloud plates and a currency icon
   nobody draws compete with the captain, and the thing the player is looking
   at is among the last to appear.

   So requests are issued in priority order, a few at a time, and each one swaps
   in the moment it decodes. Nothing waits for anything else, there is no
   loading screen, and the first thing to stop being a stand-in is the captain.

   The window is small on purpose. Browsers cap connections per origin anyway;
   the point of the cap here is that the queue stays a queue — with all of them
   in flight at once, priority is a suggestion. */
const Assets = {
  loaded: {}, meta: {}, animations: {}, ready: 0, total: 0,
  enabled: false, base: 'assets/',
  queue: [], inflight: 0, WINDOW: 6, requested: 0,

  init(){
    const q = (typeof location !== 'undefined' && location.search) || '';
    // Art used to be opt-in behind ?assets=1, which meant anyone opening the
    // build from the site got the procedural stand-ins and never saw a single
    // delivered asset. Painted art is the default now; ?assets=0 restores the
    // all-procedural look for comparison. Missing files still fall back
    // individually, so a part-delivered manifest degrades sprite by sprite.
    this.enabled = !/[?&]assets=0/.test(q) && (window.SKYGEAR_USE_ASSETS !== false);

    // Only assets that something actually draws are counted. The badge on the
    // title is a claim about how finished the game looks, and three icons that
    // load and are never drawn made that claim wrong in the flattering
    // direction.
    const keys = Object.keys(ASSET_MANIFEST).filter(k => !ASSET_MANIFEST[k].unused);
    // only cycles that have actually been delivered — a pending entry is a
    // wired slot, not a file, and requesting it is fourteen 404s a session
    const animKeys = Object.keys(ANIMATION_MANIFEST).filter(k => !ANIMATION_MANIFEST[k].pending);
    this.total = keys.length + animKeys.length;
    if (!this.enabled) return;

    // ordered: everything named in ASSET_PRIORITY, then everything else
    const named = [];
    for (const tier of ASSET_PRIORITY)
      for (const k of tier) if (ASSET_MANIFEST[k] && !ASSET_MANIFEST[k].unused) named.push(k);
    const rest = keys.filter(k => named.indexOf(k) < 0);

    for (const k of named.concat(rest)) this.queue.push({ kind: 'still', key: k });
    // Strips are one request each and land behind the stills they replace,
    // because a still is what draws until its cycle decodes.
    for (const k of animKeys) this.queue.push({ kind: 'anim', key: k });
    this.pump();
  },

  pump(){
    while (this.inflight < this.WINDOW && this.queue.length){
      const job = this.queue.shift();
      this.requested++;
      this.inflight++;
      if (job.kind === 'still') this.loadStill(job.key);
      else this.loadAnimation(job.key, ANIMATION_MANIFEST[job.key]);
    }
  },
  // One slot, released exactly once whether the image arrived or 404'd. A
  // handler that forgets to release stalls the whole queue behind it.
  done(){ this.inflight--; this.pump(); },

  loadStill(k){
    const im = new Image();
    let settled = false;
    const finish = (ok) => {
      if (settled) return;
      settled = true;
      if (ok && im.naturalWidth > 0){
        this.loaded[k] = im;
        this.meta[k] = measureSprite(im);
        im.__meta = this.meta[k];
        this.ready++;
      }
      this.done();
    };
    im.onload = () => finish(true);
    im.onerror = () => finish(false);
    im.src = this.base + ASSET_MANIFEST[k].file.replace(/^assets\//, '');
  },

  /* Strips, not loose frames: one PNG per cycle, sliced on demand. The two
     delivered cycles were 28 separate files and 3.9 MB — more than every still
     in the game combined — and the full cast in that shape would have been ~270
     requests. A strip is one request and one decode.

     `frames` is left empty until the strip has loaded; `animation()` returns
     null until then and the caller draws the still, which is exactly the
     behaviour that makes a part-delivered manifest safe. */
  loadAnimation(k, spec){
    const sequence = this.animations[k] = {
      img: null, frames: null, count: spec.count, fps: spec.fps,
      ready: 0, meta: spec.meta,
    };
    const im = new Image();
    let settled = false;
    const finish = (ok) => {
      if (settled) return;
      settled = true;
      if (ok && im.naturalWidth > 0){
        sequence.img = im;
        sequence.once = !!spec.once;
        sequence.pingpong = !!spec.pingpong;
        sequence.fw = Math.round(im.naturalWidth / spec.count);
        sequence.fh = im.naturalHeight;
        sequence.ready = spec.count;
        this.ready++;
      }
      this.done();
    };
    im.onload = () => finish(true);
    im.onerror = () => finish(false);
    im.src = spec.strip;
  },
  get(k){ return this.loaded[k] || null; },
  has(k){ return !!this.loaded[k]; },

  /* Returns a frame descriptor into the strip, or null if the cycle has not
     arrived. Null is the normal case for most of a session's first seconds and
     every caller already handles it by drawing the still — which is the whole
     reason stills are never deleted once a cycle exists. */
  /* `time` is seconds. Three playback modes, and which one a cycle uses is a
     fact about how the cycle was authored, not a preference:

       loop      frame 0..n-1, wrapping. For anything with a natural period.
       once      plays through and holds, then hands back to the still.
       pingpong  0..n-1..0. For anything with NO natural period.

     Ping-pong exists because of a measured failure. Gemini Omni closes a RUN
     cycle reliably — the two shipped run strips score 0.014 and 0.039 on
     first-versus-last-frame agreement — and does not close an IDLE at all:
     four attempts at the captain's idle scored 0.19, 0.20, 0.37 and 0.41,
     against a 0.05 threshold. That is not a prompt problem, it is structural.
     A run has a period the model can land on; a breath does not, so it drifts.

     Under ping-pong the metric stops mattering: the sequence returns through
     the frames it came from, so the boundary is exact by construction. It is
     also what an idle actually is — a breath in and a breath out — so this is
     the right playback for the content and not a way around a bad take. */
  animation(k, time){
    const seq = this.animations[k];
    if (!seq || !seq.img) return null;
    let i;
    if (seq.pingpong){
      const span = seq.count * 2 - 2;                 // 0..n-1..1
      const j = Math.floor(Math.max(0, time) * seq.fps) % Math.max(1, span);
      i = j < seq.count ? j : span - j;
    } else if (seq.once){
      // Plays through and holds its last frame. `time` is seconds since the
      // action started, so a caller that keeps its own clock gets a one-shot;
      // one that passes a free-running clock would get a loop, which is why
      // every `once` caller passes an elapsed time and not S.rt.
      i = Math.floor(Math.max(0, time) * seq.fps);
      if (i >= seq.count) return null;          // finished — fall back to the still
    } else {
      i = Math.floor(Math.max(0, time) * seq.fps) % seq.count;
    }
    return { strip: seq.img, sx: i * seq.fw, width: seq.fw, height: seq.fh, __meta: seq.meta };
  },
  hasAnim(k){ const s = this.animations[k]; return !!(s && s.img); },
};
Assets.init();
