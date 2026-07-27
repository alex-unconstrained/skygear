/* ---------------------------------------------------------------------------
   AUDIO — the sample layer, per docs/AUDIO-SPEC.md.

   Everything here is additive. The procedural synth in `Sound`/`SFX` remains
   the fallback and the game is fully audible with no files present, exactly as
   the art pipeline keeps its procedural sprites. Nothing in this file may make
   a cue silent-on-failure.

   Layout:
     1. AUDIO_MANIFEST   what the art side is delivering, and how to treat it
     2. AudioBank        fetch + decode, opt out with ?audio=0
     3. buses            music / sfx / ui / voice under the existing compressor
     4. Sound.sample     playback with pan, distance, detune and voice stealing
     5. SFX wrapping     every named cue prefers its sample, falls back to synth
     6. new cues         the six that were missing or misused, plus ambience
     7. Music            the director: tier by wave, crossfade, duck
--------------------------------------------------------------------------- */

/* 1 ------------------------------------------------------------------------ */
/* `bus`      which fader it lands on
   `vary`     random detune, ±fraction — one file must not sound identical 400×
   `max`      concurrent voices before the oldest is stolen
   `gap`      minimum seconds between retriggers
   `variants` N files named _1.._N, round-robined
   `loop`     sustained; loopStart/loopEnd in seconds once Codex measures them */
const AUDIO_MANIFEST = {
  // --- player: shape bodies -------------------------------------------------
  shape_cleave:     { file:'sfx/player/shape_cleave',     bus:'sfx', vary:0.06, max:6 },
  shape_lance:      { file:'sfx/player/shape_lance',      bus:'sfx', vary:0.06, max:4 },
  shape_gale:       { file:'sfx/player/shape_gale',       bus:'sfx', vary:0.05, max:3 },
  shape_mortar:     { file:'sfx/player/shape_mortar',     bus:'sfx', vary:0.05, max:3 },
  shape_mortar_land:{ file:'sfx/player/shape_mortar_land',bus:'sfx', vary:0.07, max:4 },
  shape_whip:       { file:'sfx/player/shape_whip',       bus:'sfx', vary:0.06, max:4 },
  shape_beam_start: { file:'sfx/player/shape_beam_start', bus:'sfx', max:2 },
  shape_beam_loop:  { file:'sfx/player/shape_beam_loop',  bus:'sfx', loop:true },
  shape_beam_end:   { file:'sfx/player/shape_beam_end',   bus:'sfx', max:2 },
  // --- player: element tails ------------------------------------------------
  elem_EMBER:       { file:'sfx/player/elem_ember',       bus:'sfx', vary:0.06, max:6 },
  elem_FROST:       { file:'sfx/player/elem_frost',       bus:'sfx', vary:0.06, max:6 },
  elem_ARC:         { file:'sfx/player/elem_arc',         bus:'sfx', vary:0.06, max:6 },
  elem_STEAM:       { file:'sfx/player/elem_steam',       bus:'sfx', vary:0.06, max:6 },
  // --- impact ---------------------------------------------------------------
  hit:              { file:'sfx/player/hit',   bus:'sfx', vary:0.06, max:4, gap:0.030, variants:3, gain:0.55 },
  crit:             { file:'sfx/player/crit',  bus:'sfx', vary:0.05, max:3, gap:0.030, variants:3 },
  hurt:             { file:'sfx/player/hurt',  bus:'sfx', vary:0.04, max:2, gap:0.080 },
  dash:             { file:'sfx/player/dash',  bus:'sfx', vary:0.05, max:2 },
  ready:            { file:'sfx/player/ready', bus:'ui',  vary:0.03, max:2 },
  pickup:           { file:'sfx/player/pickup',bus:'ui',  vary:0.07, max:3, gap:0.040 },
  // --- enemies --------------------------------------------------------------
  death_light:      { file:'sfx/enemy/death_light', bus:'sfx', vary:0.07, max:3, gap:0.060, variants:3 },
  death_heavy:      { file:'sfx/enemy/death_heavy', bus:'sfx', vary:0.05, max:2, variants:2 },
  shoot_drone:      { file:'sfx/enemy/shoot_drone', bus:'sfx', vary:0.06, max:4, gap:0.040 },
  telegraph:        { file:'sfx/enemy/telegraph',   bus:'sfx', vary:0.05, max:3, gap:0.080 },
  slam:             { file:'sfx/enemy/slam',        bus:'sfx', vary:0.04, max:2 },
  boss_roar:        { file:'sfx/enemy/boss_roar',   bus:'sfx', max:1 },
  climb:            { file:'sfx/enemy/climb',       bus:'sfx', vary:0.08, max:3, gap:0.100 },
  // --- lanes ----------------------------------------------------------------
  cannon_fire:      { file:'sfx/lane/cannon_fire', bus:'sfx', vary:0.05, max:3, gap:0.050, gain:0.9 },
  cannon_hurt:      { file:'sfx/lane/cannon_hurt', bus:'sfx', vary:0.06, max:2, gap:0.120, gain:0.7 },
  cannon_down:      { file:'sfx/lane/cannon_down', bus:'sfx', max:2 },
  crew_muster:      { file:'sfx/lane/crew_muster', bus:'sfx', max:1, gain:0.8 },
  crew_attack:      { file:'sfx/lane/crew_attack', bus:'sfx', vary:0.08, max:3, gap:0.060, variants:3 },
  crew_down:        { file:'sfx/lane/crew_down',   bus:'sfx', vary:0.06, max:2, gap:0.090, variants:2 },
  hulk_grapple:     { file:'sfx/lane/hulk_grapple',bus:'sfx', max:1 },
  hulk_hit:         { file:'sfx/lane/hulk_hit',    bus:'sfx', vary:0.06, max:3, gap:0.050 },
  hulk_break:       { file:'sfx/lane/hulk_break',  bus:'sfx', max:1 },
  crossing:         { file:'sfx/lane/crossing',    bus:'sfx', vary:0.07, max:1, gap:0.500 },
  // --- world ----------------------------------------------------------------
  boiler_hurt:      { file:'sfx/world/boiler_hurt',     bus:'sfx', vary:0.04, max:2, gap:0.100 },
  boiler_critical:  { file:'sfx/world/boiler_critical', bus:'sfx', loop:true },
  wave_clear:       { file:'sfx/world/wave_clear',      bus:'ui',  max:1 },
  wave_start:       { file:'sfx/world/wave_start',      bus:'ui',  max:1 },
  amb_storm:        { file:'sfx/world/amb_storm',       bus:'sfx', loop:true },
  amb_ship:         { file:'sfx/world/amb_ship',        bus:'sfx', loop:true },
  // --- ui -------------------------------------------------------------------
  ui_hover:         { file:'sfx/ui/hover',       bus:'ui', vary:0.04, max:2, gap:0.040 },
  ui_click:         { file:'sfx/ui/click',       bus:'ui', max:2 },
  card_pick:        { file:'sfx/ui/card_pick',   bus:'ui', max:1 },
  card_deal:        { file:'sfx/ui/card_deal',   bus:'ui', max:1 },
  slot_unlock:      { file:'sfx/ui/slot_unlock', bus:'ui', max:1 },
  // --- music ----------------------------------------------------------------
  m_title:    { file:'music/title_loop',    bus:'music', loop:true, lazy:true },
  m_combat1:  { file:'music/combat_low',    bus:'music', loop:true, lazy:true },
  m_combat2:  { file:'music/combat_mid',    bus:'music', loop:true, lazy:true },
  m_combat3:  { file:'music/combat_high',   bus:'music', loop:true, lazy:true },
  m_push:     { file:'music/push_loop',     bus:'music', loop:true, lazy:true },
  m_boss:     { file:'music/boss_loop',     bus:'music', loop:true, lazy:true },
  m_victory:  { file:'music/victory_sting', bus:'music', lazy:true },
  m_defeat:   { file:'music/defeat_sting',  bus:'music', lazy:true },
};

/* 2 ------------------------------------------------------------------------ */
const AudioBank = {
  buf: {}, enabled: false, base: 'audio/', ext: '.ogg',
  ready: 0, total: 0, pending: 0,

  init(){
    const q = (typeof location !== 'undefined' && location.search) || '';
    this.enabled = !/[?&]audio=0/.test(q) && window.SKYGEAR_USE_AUDIO !== false;
    // Only what src/ingest-audio.py actually found in the repo. Guessing per
    // manifest entry would mean a request and a 404 for every cue nobody has
    // made yet; an undelivered cue should cost nothing and simply keep its
    // procedural voice.
    this.delivered = (typeof AUDIO_DELIVERED !== 'undefined') ? AUDIO_DELIVERED : {};
    this.total = Object.keys(this.delivered).length;
  },

  // Deferred until the AudioContext exists — decodeAudioData needs it, and the
  // context cannot be created before a user gesture.
  start(){
    if (!this.enabled || this.started || !Sound.ready) return;
    this.started = true;
    for (const k in this.delivered) if (!AUDIO_MANIFEST[k] || !AUDIO_MANIFEST[k].lazy) this.fetch(k);
  },

  fetch(k){
    const m = AUDIO_MANIFEST[k], d = this.delivered[k];
    if (!m || !d || this.buf[k] !== undefined) return;
    this.buf[k] = null;                       // claim the slot; null = in flight
    const ext = d.ext || this.ext;
    const names = d.n > 1
      ? Array.from({ length: d.n }, (_, i) => m.file + '_' + (i + 1))
      : [m.file];
    const got = [];
    let left = names.length;
    names.forEach((n, i) => {
      fetch(this.base + n + ext)
        .then(r => (r.ok ? r.arrayBuffer() : Promise.reject()))
        .then(b => new Promise((res, rej) => Sound.ctx.decodeAudioData(b, res, rej)))
        .then(dec => { got[i] = dec; })
        .catch(() => {})                      // absent or undecodable: stay procedural
        .then(() => {
          if (--left) return;
          const list = got.filter(Boolean);
          if (list.length){ this.buf[k] = list; this.ready++; }
          else this.buf[k] = false;           // false = tried and failed, do not retry
        });
    });
  },

  get(k){
    const b = this.buf[k];
    if (b && b.length) return b[(Math.random() * b.length) | 0];
    if (b === undefined && this.delivered[k]) this.fetch(k);
    return null;
  },
  has(k){ const b = this.buf[k]; return !!(b && b.length); },
};
AudioBank.init();

/* 3 ------------------------------------------------------------------------ */
/* Buses sit between the cues and the existing master gain, so mute and the
   volume keys keep working untouched and each family gets its own trim. */
const _soundUnlock = Sound.unlock.bind(Sound);
Sound.unlock = function(){
  _soundUnlock();
  if (!this.ready || this.bus) return;
  const c = this.ctx, mk = (v) => { const g = c.createGain(); g.gain.value = v; g.connect(this.master); return g; };
  this.bus = { music: mk(0.55), sfx: mk(1.0), ui: mk(0.85), voice: mk(1.0) };
  this.duckT = 0;
  AudioBank.start();
  Music.onUnlock();
};
Sound.dest = function(name){
  return (this.bus && this.bus[name || 'sfx']) || this.master;
};

/* Music ducks under the big moments, and only those — per-hit ducking pumps. */
Sound.duck = function(db, secs){
  if (!this.bus) return;
  const g = this.bus.music.gain, c = this.ctx, t = c.currentTime;
  const base = 0.55, to = base * Math.pow(10, -Math.abs(db) / 20);
  g.cancelScheduledValues(t);
  g.setValueAtTime(g.value, t);
  g.linearRampToValueAtTime(to, t + 0.05);
  g.linearRampToValueAtTime(base, t + 0.05 + (secs || 0.25));
};

/* 4 ------------------------------------------------------------------------ */
const _voices = {};        // key -> array of {node, t}
const _lastAt = {};        // key -> last start time, for the retrigger floor

/* Pan and attenuate from the camera focus. A lane you cannot see must still be
   audible — that is the entire reason positional audio is here — so distance
   rolls off to a floor, never to zero, and pan never goes fully hard. */
function _place(x, y){
  const fx = (typeof CAM !== 'undefined' && CAM.focusX !== undefined)
    ? CAM.focusX : TUNING.deck.cx;
  const fy = (typeof CAM !== 'undefined' && CAM.focusY !== undefined)
    ? CAM.focusY : TUNING.deck.cy;
  const half = Math.max(1, TUNING.world.w * 0.5);
  const pan = clamp((x - fx) / half, -1, 1) * 0.7;
  const d = Math.hypot(x - fx, y - fy);
  const gain = d <= 600 ? 1 : Math.max(0.35, 1 - (d - 600) / 1000 * 0.65);
  return { pan, gain };
}

Sound.sample = function(key, opt){
  if (!this.ready || this.muted) return false;
  const m = AUDIO_MANIFEST[key];
  const buf = AudioBank.get(key);
  if (!m || !buf) return false;
  opt = opt || {};
  const c = this.ctx, now = c.currentTime;

  if (m.gap && _lastAt[key] !== undefined && now - _lastAt[key] < m.gap) return true;
  _lastAt[key] = now;

  const live = _voices[key] || (_voices[key] = []);
  for (let i = live.length - 1; i >= 0; i--) if (live[i].done) live.splice(i, 1);
  const cap = opt.loop ? 1 : (m.max || 2);
  while (live.length >= cap){
    const old = live.shift();
    try { old.src.stop(); } catch (e) {}
  }

  const src = c.createBufferSource();
  src.buffer = buf;
  if (m.vary) src.detune.value = (Math.random() * 2 - 1) * m.vary * 1200;
  if (m.loop || opt.loop){
    src.loop = true;
    if (m.loopStart !== undefined){ src.loopStart = m.loopStart; src.loopEnd = m.loopEnd; }
  }
  const g = c.createGain();
  // three factors: the caller's, the cue's designed weight, and the ingest's
  // delivery correction for masters that arrived at inconsistent levels
  const d = AudioBank.delivered[key];
  g.gain.value = (opt.gain === undefined ? 1 : opt.gain)
               * (m.gain === undefined ? 1 : m.gain)
               * ((d && d.g) || 1);
  let node = src;
  if (opt.x !== undefined && c.createStereoPanner){
    const p = _place(opt.x, opt.y);
    const pan = c.createStereoPanner();
    pan.pan.value = p.pan;
    g.gain.value *= p.gain;
    node.connect(pan); node = pan;
  }
  node.connect(g);
  g.connect(this.dest(opt.bus || m.bus));
  const rec = { src, g, done: false };
  src.onended = () => { rec.done = true; };
  src.start(0);
  live.push(rec);
  return rec;
};

/* Sustained cues: ambience, the beam, the boiler alarm. Idempotent both ways. */
const _loops = {};
Sound.startLoop = function(key, gain){
  if (_loops[key] || !AudioBank.has(key)) return;
  const rec = this.sample(key, { loop: true, gain: gain === undefined ? 1 : gain });
  if (rec) _loops[key] = rec;
};
Sound.stopLoop = function(key){
  const rec = _loops[key];
  if (!rec) return;
  delete _loops[key];
  try {
    const t = this.ctx.currentTime;
    rec.g.gain.setValueAtTime(rec.g.gain.value, t);
    rec.g.gain.linearRampToValueAtTime(0.0001, t + 0.25);
    rec.src.stop(t + 0.3);
  } catch (e) {}
};

/* 5 ------------------------------------------------------------------------ */
/* Every named cue becomes: play the sample if it loaded, otherwise run exactly
   the synth that has always been there. Call sites are untouched — all 20 of
   them keep their names and signatures — which is what makes the fallback
   structural rather than something anyone has to remember. */
function _wrapCue(obj, name, key){
  const synth = obj[name].bind(obj);
  obj[name] = function(opt){
    if (Sound.sample(key, opt)) return;
    synth(opt);
  };
}
['hit','crit','hurt','dash','ready','pickup','telegraph','slam']
  .forEach(n => _wrapCue(SFX, n, n));
_wrapCue(SFX, 'death', 'death_light');
_wrapCue(SFX, 'enemyShoot', 'shoot_drone');
_wrapCue(SFX, 'bossRoar', 'boss_roar');
_wrapCue(SFX, 'boiler', 'boiler_hurt');
_wrapCue(SFX, 'waveClear', 'wave_clear');
_wrapCue(SFX, 'cardPick', 'card_pick');
_wrapCue(SFX, 'uiHover', 'ui_hover');
_wrapCue(SFX, 'uiClick', 'ui_click');
for (const el of ELEMENT_KEYS) _wrapCue(SFX.fire, el, 'elem_' + el);

/* A cast is its shape crossed with its element, in sound as in code: one body,
   one tail, layered. Six bodies and four tails cover all twenty-four casts. */
const SHAPE_CUE = {
  CLOSEHIT:'shape_cleave', LINE_BURST:'shape_lance', CONE:'shape_gale',
  RANGED_AOE:'shape_mortar', CHAIN:'shape_whip', RAY:'shape_beam_start',
};
SFX.cast = function(shape, element, x, y){
  const at = (x === undefined) ? {} : { x, y };
  const body = SHAPE_CUE[shape];
  const played = body ? Sound.sample(body, at) : false;
  SFX.fire[element](at);            // the tail, or its synth if absent
  if (!played && body) return;      // synth already covered it via fire[]
};

/* 6 ------------------------------------------------------------------------ */
/* The cues that were missing or borrowed someone else's sound. Each gets a
   procedural voice now, so these are audible improvements before a single file
   exists, and a sample slot for when one does. */
function _newCue(name, key, synth){
  SFX[name] = function(opt){
    if (Sound.sample(key, opt)) return;
    if (Sound.ready && !Sound.muted) synth(opt || {});
  };
}

// Your own artillery. Was firing SFX.enemyShoot() — friendly and enemy fire
// were literally the same sound, the most confusing thing in the mix.
_newCue('cannonFire', 'cannon_fire', (o) => {
  Sound.noise({ dur:0.30, ff0:1400, ff1:180, q:0.7, gain:0.24, filter:'lowpass', rate:0.7, bus:'sfx' });
  Sound.tone({ type:'sine', f0:180, f1:58, dur:0.26, gain:0.22, bus:'sfx' });
  Sound.noise({ dur:0.22, ff0:2600, ff1:900, q:1.4, gain:0.08, delay:0.05, bus:'sfx' });
});
_newCue('turretHurt', 'cannon_hurt', () => {
  Sound.tone({ type:'triangle', f0:300, f1:120, dur:0.16, gain:0.16, bus:'sfx' });
  Sound.noise({ dur:0.10, ff0:1800, ff1:600, q:1.0, gain:0.10, filter:'lowpass', bus:'sfx' });
});
_newCue('turretDown', 'cannon_down', () => {
  Sound.tone({ type:'sawtooth', f0:200, f1:40, dur:0.55, gain:0.26, bus:'sfx' });
  Sound.noise({ dur:0.60, ff0:2200, ff1:200, q:0.6, gain:0.22, filter:'lowpass', bus:'sfx' });
});
// Reinforcements. Was SFX.ready() — the same 70ms blip as a cooldown coming up.
_newCue('crewMuster', 'crew_muster', () => {
  [520, 660, 784].forEach((f, i) =>
    Sound.tone({ type:'triangle', f0:f, dur:0.20, gain:0.10, delay:i*0.075, bus:'sfx' }));
  Sound.noise({ dur:0.34, ff0:300, ff1:900, q:0.8, gain:0.07, delay:0.05, bus:'sfx' });
});
_newCue('crewAttack', 'crew_attack', (o) => {
  Sound.noise({ dur:0.09, ff0:2000, ff1:800, q:1.2, gain:0.10, filter:'lowpass', bus:'sfx' });
});
_newCue('crewDown', 'crew_down', () => {
  Sound.tone({ type:'sawtooth', f0:180, f1:60, dur:0.22, gain:0.14, bus:'sfx' });
  Sound.noise({ dur:0.20, ff0:900, ff1:200, q:0.7, gain:0.12, filter:'lowpass', bus:'sfx' });
});
// The hulk. Chip damage was silent; breaking it borrowed the boss roar.
_newCue('hulkHit', 'hulk_hit', () => {
  Sound.tone({ type:'sine', f0:150, f1:70, dur:0.24, gain:0.16, bus:'sfx' });
  Sound.noise({ dur:0.09, ff0:1600, ff1:500, q:1.6, gain:0.09, filter:'lowpass', bus:'sfx' });
});
_newCue('hulkGrapple', 'hulk_grapple', () => {
  Sound.tone({ type:'sawtooth', f0:90, f1:38, dur:1.1, gain:0.28, bus:'sfx' });
  Sound.noise({ dur:1.2, ff0:400, ff1:120, q:0.5, gain:0.18, filter:'lowpass', bus:'sfx' });
  Sound.duck(4, 0.6);
});
_newCue('hulkBreak', 'hulk_break', () => {
  Sound.tone({ type:'sawtooth', f0:150, f1:30, dur:1.5, gain:0.30, bus:'sfx' });
  Sound.noise({ dur:1.6, ff0:2400, ff1:110, q:0.5, gain:0.26, filter:'lowpass', bus:'sfx' });
  [0.15, 0.42, 0.78].forEach(d =>
    Sound.tone({ type:'sine', f0:110, f1:44, dur:0.4, gain:0.16, delay:d, bus:'sfx' }));
  Sound.duck(4, 1.2);
});
_newCue('waveStart', 'wave_start', () => {
  Sound.tone({ type:'square', f0:420, f1:300, dur:0.42, gain:0.12, bus:'ui' });
  Sound.tone({ type:'square', f0:315, f1:225, dur:0.42, gain:0.10, delay:0.20, bus:'ui' });
});
_newCue('climb', 'climb', () => {
  Sound.noise({ dur:0.22, ff0:1200, ff1:2600, q:2.0, gain:0.08, bus:'sfx' });
});
_newCue('crossing', 'crossing', () => {
  Sound.noise({ dur:0.14, ff0:600, ff1:260, q:1.4, gain:0.06, filter:'lowpass', bus:'sfx' });
});
_newCue('cardDeal', 'card_deal', () => {
  [0, 0.07, 0.14].forEach(d =>
    Sound.noise({ dur:0.10, ff0:1500, ff1:600, q:1.2, gain:0.09, delay:d, filter:'lowpass', bus:'ui' }));
});
_newCue('slotUnlock', 'slot_unlock', () => {
  Sound.tone({ type:'square', f0:300, f1:520, dur:0.12, gain:0.12, bus:'ui' });
  Sound.tone({ type:'triangle', f0:780, f1:1040, dur:0.30, gain:0.12, delay:0.10, bus:'ui' });
});

/* Ambience. Two beds under everything — the largest atmosphere gain per byte,
   and until the files land these are a filtered-noise stand-in that still
   beats silence. Driven from Ambience.update() each frame. */
const Ambience = {
  on: false, t: 0,
  update(dt){
    const want = S.mode === 'play' || S.mode === 'draft';
    if (want && !this.on){
      this.on = true;
      Sound.startLoop('amb_storm', 0.22);
      Sound.startLoop('amb_ship', 0.18);
    } else if (!want && this.on){
      this.on = false;
      Sound.stopLoop('amb_storm'); Sound.stopLoop('amb_ship');
    }
    // procedural stand-in: an occasional gust, only when no bed is loaded
    if (this.on && !AudioBank.has('amb_storm')){
      this.t -= dt;
      if (this.t <= 0){
        this.t = 2.2 + Math.random() * 2.6;
        Sound.noise({ dur:1.8, ff0:220, ff1:520, q:0.5, gain:0.035, filter:'bandpass', bus:'sfx' });
      }
    }
    // the Boiler's alarm, tied to the actual threshold
    const crit = S.boiler && S.boiler.hp / S.boiler.maxHp < 0.25 && want;
    if (crit && !this._crit){ this._crit = true; Sound.startLoop('boiler_critical', 0.5); }
    else if (!crit && this._crit){ this._crit = false; Sound.stopLoop('boiler_critical'); }
  },
};

/* 7 ------------------------------------------------------------------------ */
/* The director. Picks a track from game state, crossfades over 2s. Dormant and
   harmless until the files exist — every call is a no-op without a buffer. */
const Music = {
  cur: null, node: null, gain: null,

  onUnlock(){ this.want(); },

  trackFor(){
    if (S.mode === 'title') return 'm_title';
    if (S.mode === 'victory') return 'm_victory';
    if (S.mode === 'gameover') return 'm_defeat';
    const def = WAVES[S.wave - 1];
    if (def && def.boss) return 'm_boss';
    if (def && def.push && S.hulk && !S.hulk.dead && S.hulk.vulnerable) return 'm_push';
    if (S.wave >= 9) return 'm_combat3';
    if (S.wave >= 5) return 'm_combat2';
    return 'm_combat1';
  },

  want(){
    const k = this.trackFor();
    if (k === this.cur) return;
    const buf = AudioBank.get(k);          // triggers the lazy fetch
    if (!buf) { this.cur = k; return; }    // nothing to play yet; remember intent
    this.cur = k;
    const c = Sound.ctx, t = c.currentTime, XF = 2.0;
    if (this.gain){
      const og = this.gain, on = this.node;
      og.gain.cancelScheduledValues(t);
      og.gain.setValueAtTime(og.gain.value, t);
      og.gain.linearRampToValueAtTime(0.0001, t + XF);
      try { on.stop(t + XF + 0.1); } catch (e) {}
    }
    const rec = Sound.sample(k, { gain: 0.0001 });
    if (!rec) { this.gain = null; this.node = null; return; }
    this.gain = rec.g; this.node = rec.src;
    rec.g.gain.setValueAtTime(0.0001, t);
    rec.g.gain.linearRampToValueAtTime(1, t + XF);
  },

  update(){ if (Sound.ready) this.want(); },
};
