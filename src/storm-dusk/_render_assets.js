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
  ui_icon_dash:    { file:'assets/ui/icon_skill_dash.png',    w:256, h:256 },
  ui_icon_barrier: { file:'assets/ui/icon_skill_barrier.png', w:256, h:256 },
  ui_icon_cog:     { file:'assets/ui/icon_currency_cog.png',  w:128, h:128 },
};

/* Loading is opt-in so that an asset-less checkout has a clean console and
   still plays: the procedural stand-ins are complete. Turn art on with
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

const Assets = {
  loaded: {}, meta: {}, ready: 0, total: 0, enabled: false, set: 'production', base: 'assets/',

  init(){
    const q = (typeof location !== 'undefined' && location.search) || '';
    const am = /[?&]art=([a-z0-9-]+)/i.exec(q);
    // Art used to be opt-in behind ?assets=1, which meant anyone opening the
    // build from the site got the procedural stand-ins and never saw a single
    // delivered asset. Painted art is the default now; ?assets=0 restores the
    // all-procedural look for comparison. Missing files still fall back
    // individually, so a part-delivered manifest degrades sprite by sprite.
    const off = /[?&]assets=0/.test(q);
    this.enabled = !off && (window.SKYGEAR_USE_ASSETS !== false);
    // V5+ production art is the upright billboard set under assets/. The
    // archived ?art=49 set remains available only for explicit comparison.
    this.set = am ? am[1] : 'production';
    this.base = this.set === '49' ? 'assets-49/' : 'assets/';
    const keys = Object.keys(ASSET_MANIFEST);
    this.total = keys.length;
    if (!this.enabled) return;
    for (const k of keys){
      const im = new Image();
      im.onload = () => {
        if (im.naturalWidth > 0){
          this.loaded[k] = im;
          this.meta[k] = measureSprite(im);
          im.__meta = this.meta[k];
          this.ready++;
        }
      };
      im.onerror = () => {};
      im.src = this.base + ASSET_MANIFEST[k].file.replace(/^assets\//, '');
    }
  },
  get(k){ return this.loaded[k] || null; },
  has(k){ return !!this.loaded[k]; },
};
Assets.init();
