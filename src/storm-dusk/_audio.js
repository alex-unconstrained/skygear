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
  // --- deck ordnance and the vent (v11) --------------------------------------
  // Tier 0 by the event sheet: a lit keg is survival information and must be
  // audible with the camera two lanes away, which is why the fuse is a loop-shaped
  // hiss rather than a one-shot tick.
  keg_fuse:         { file:'sfx/prop/keg_fuse',      bus:'sfx', vary:0.05, max:3, gap:0.080 },
  keg_blow:         { file:'sfx/prop/keg_blow',      bus:'sfx', vary:0.04, max:3, gap:0.040 },
  crate_break:      { file:'sfx/prop/crate_break',   bus:'sfx', vary:0.07, max:3, gap:0.050, variants:2 },
  lantern_break:    { file:'sfx/prop/lantern_break', bus:'sfx', vary:0.07, max:2, gap:0.060 },
  vent:             { file:'sfx/player/vent',        bus:'sfx', vary:0.03, max:2 },
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
  // Measured in-engine: the track fades in over ~1s and fades to silence in
  // its last ~2s. Looping the whole file would drop the music out entirely
  // every 2:48, so the loop is taken from the sustained middle.
  m_combat1:  { file:'music/combat_low',    bus:'music', loop:true, lazy:true,
                loopStart:1.0, loopEnd:164.5 },
  m_combat2:  { file:'music/combat_mid',    bus:'music', loop:true, lazy:true },
  // Delivered 2026-07-27. Same treatment as combat_low and for the same reason:
  // both tracks are authored with an ending, so the loop is lifted out of the
  // sustained middle and the join is crossfaded. Measured, not guessed —
  // combat_high runs 88.7s and boss_loop 113.0s, and schedule() reads
  // loopEnd + 2s of crossfade out of the buffer, so neither may sit at the tail.
  m_combat3:  { file:'music/combat_high',   bus:'music', loop:true, lazy:true,
                loopStart:1.0, loopEnd:85.5 },
  m_push:     { file:'music/push_loop',     bus:'music', loop:true, lazy:true },
  m_boss:     { file:'music/boss_loop',     bus:'music', loop:true, lazy:true,
                loopStart:1.0, loopEnd:109.5 },
  m_victory:  { file:'music/victory_sting', bus:'music', lazy:true },
  m_defeat:   { file:'music/defeat_sting',  bus:'music', lazy:true },

  /* --- voice (v11) ---------------------------------------------------------
     The captain, her crew, and the thing that boards you. Written to be spoken,
     specified line by line in VOICE-BRIEF.md, and wired here first so a
     delivered file is live the moment ingest sees it.

     Voice cues have NO procedural fallback, on purpose. A synthesised human
     voice is worse than silence, and every one of these is flavour on top of a
     mechanical cue that already fires — the wave banner, the lane alert, the
     hurt sound. Nothing in the game is only announced by a voice line.

     `n` variants per key come from the delivery, not from here; the director
     below picks between them and refuses to repeat the last one. */
  vo_wave_start:    { file:'voice/captain/wave_start',    bus:'voice', max:1, gain:1.0 },
  vo_wave_clear:    { file:'voice/captain/wave_clear',    bus:'voice', max:1, gain:1.0 },
  vo_first_board:   { file:'voice/captain/first_board',   bus:'voice', max:1 },
  vo_hurt_low:      { file:'voice/captain/hurt_low',      bus:'voice', max:1 },
  vo_vent:          { file:'voice/captain/vent',          bus:'voice', max:1, gain:0.9 },
  vo_keg:           { file:'voice/captain/keg',           bus:'voice', max:1 },
  vo_dash:          { file:'voice/captain/dash_effort',   bus:'voice', max:2, gain:0.7 },
  vo_draft:         { file:'voice/captain/draft',         bus:'voice', max:1 },
  vo_slot:          { file:'voice/captain/slot_unlock',   bus:'voice', max:1 },
  vo_boiler_low:    { file:'voice/captain/boiler_low',    bus:'voice', max:1 },
  vo_lane_critical: { file:'voice/captain/lane_critical', bus:'voice', max:1 },
  vo_push:          { file:'voice/captain/push',          bus:'voice', max:1 },
  vo_victory:       { file:'voice/captain/victory',       bus:'voice', max:1 },
  vo_defeat:        { file:'voice/captain/defeat',        bus:'voice', max:1 },
  vo_crew_muster:   { file:'voice/crew/muster',           bus:'voice', max:1, gain:0.8 },
  vo_crew_down:     { file:'voice/crew/down',             bus:'voice', max:1, gain:0.8 },
  vo_cannon_down:   { file:'voice/crew/cannon_down',      bus:'voice', max:1, gain:0.9 },
  vo_boss_arrive:   { file:'voice/boss/arrive',           bus:'voice', max:1, gain:1.0 },
  vo_boss_turn:     { file:'voice/boss/turn',             bus:'voice', max:1, gain:1.0 },
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
  // The buses do not exist until the first gesture, so stored volumes have had
  // nowhere to land until now. Push them in the moment the graph appears —
  // otherwise a player who turned the music down last session gets one loud
  // bar of it before the settings screen is ever opened.
  Settings.applyAudio();
  AudioBank.start();
  Music.onUnlock();
};
Settings.applyAudio();   // master gain and mute, which do exist before unlock
Sound.dest = function(name){
  return (this.bus && this.bus[name || 'sfx']) || this.master;
};

/* Belt and braces on suspension. visibilitychange and focus cover the normal
   case, but browsers suspend for reasons beyond tab switching and a resume()
   issued too close to a suspend() can be swallowed. Since a suspended context
   fails silently — every cue still reports success while producing nothing —
   the loop checks once a second rather than trusting any single event. */
Sound._wakeT = 0;
Sound.keepAwake = function(){
  if (!this.ctx) return;
  // NOT ctx.currentTime — that clock stops while the context is suspended, so
  // using it to decide when to un-suspend can never fire. Wall clock only.
  const now = performance.now();
  if (now - this._wakeT < 1000) return;
  this._wakeT = now;
  if (this.ctx.state === 'suspended') this.ctx.resume();
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
/* Made and freed, cumulative. Not diagnostics for their own sake: the harness
   asserts the difference stays bounded over hundreds of cues, which is the
   check that would have caught the leak in F-01 the day it was written. */
Sound.nodesMade = 0;
Sound.nodesFreed = 0;
Sound.liveNodes = function(){ return this.nodesMade - this.nodesFreed; };
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
    this.release(old);
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
  const rec = { src, g, pan: (node === src ? null : node), done: false };
  Sound.nodesMade++;
  /* Disconnect on end, not just mark done (v12).

     This was a leak, and a measured one. Every cue builds a BufferSource, a
     GainNode and sometimes a StereoPanner and wires them to a bus. Marking the
     record `done` let it be pruned from `_voices`, but the gain node stayed
     connected to a live destination — so it stayed reachable, so it was never
     collected, and Web Audio pays for every connected node every render quantum
     whether or not it is making sound.

     `tools/profile.mjs` puts the rate at ~515 cues per second under a saturated
     wave-11 fight. A five-minute run is tens of thousands of orphaned nodes,
     which is exactly the reported symptom: progressively worse with sound on,
     unaffected by muting (mute returns before creating nodes but cannot release
     the ones already made), and cleared by a reload. FEEDBACK.md F-01. */
  src.onended = () => {
    if (!rec.released){ rec.released = true; Sound.nodesFreed++; }
    rec.done = true;
    try { g.disconnect(); } catch (e) {}
    try { if (rec.pan) rec.pan.disconnect(); } catch (e) {}
    try { src.disconnect(); } catch (e) {}
  };
  src.start(0);
  live.push(rec);
  return rec;
};

/* Anything stopped by hand — a stolen voice, a stopped loop — never fires
   `onended` in every browser, so the same teardown is available directly. */
Sound.release = function(rec){
  if (!rec || rec.released) return;
  rec.released = true;
  Sound.nodesFreed++;
  try { rec.src.stop(); } catch (e) {}
  try { rec.g.disconnect(); } catch (e) {}
  try { if (rec.pan) rec.pan.disconnect(); } catch (e) {}
  try { rec.src.disconnect(); } catch (e) {}
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
  // and let go of the graph once the fade has finished. A stopped loop that
  // stays connected is the same leak as an ended one-shot that stays connected.
  setTimeout(() => Sound.release(rec), 400);
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
/* v11 — the deck's own voices. Same rule as everything above: a procedural
   stand-in now, a sample slot for when ElevenLabs delivers (VOICE-BRIEF.md §4).
   A lit keg has to be heard before it is seen, so the fuse is bright and rises;
   the blast is deliberately duller and lower than the player's own STEAM cue so
   the two never compete when a Steam build sets off a chain. */
_newCue('kegFuse', 'keg_fuse', (o) => {
  Sound.noise({ dur:0.42, ff0:1800, ff1:5200, q:3.2, gain:0.13, filter:'bandpass', bus:'sfx' });
  Sound.tone({ type:'triangle', f0:640, f1:1180, dur:0.40, gain:0.06, bus:'sfx' });
});
_newCue('kegBlow', 'keg_blow', (o) => {
  Sound.tone({ type:'sine', f0:150, f1:42, dur:0.52, gain:0.28, bus:'sfx' });
  Sound.noise({ dur:0.60, ff0:3200, ff1:260, q:0.6, gain:0.26, filter:'lowpass', bus:'sfx' });
  Sound.noise({ dur:0.90, ff0:900, ff1:300, q:0.8, gain:0.10, filter:'bandpass', delay:0.10, bus:'sfx' });
  Sound.duck(3, 0.5);
});
_newCue('crateBreak', 'crate_break', () => {
  Sound.noise({ dur:0.22, ff0:2600, ff1:700, q:1.1, gain:0.16, filter:'lowpass', bus:'sfx' });
  [0, 0.06, 0.13].forEach(d =>
    Sound.tone({ type:'square', f0:300 - d*400, f1:120, dur:0.10, gain:0.07, delay:d, bus:'sfx' }));
});
_newCue('lanternBreak', 'lantern_break', () => {
  Sound.noise({ dur:0.16, ff0:5200, ff1:2200, q:2.6, gain:0.12, filter:'bandpass', bus:'sfx' });
  Sound.noise({ dur:0.55, ff0:700, ff1:1500, q:0.7, gain:0.09, filter:'bandpass', delay:0.08, bus:'sfx' });
});
// The vent is the player's reward cue and sits in tier 1: it must cut through a
// wave-11 crowd, so it gets a rising body and its own small duck.
_newCue('vent', 'vent', () => {
  Sound.noise({ dur:0.55, ff0:600, ff1:4200, q:1.1, gain:0.24, filter:'bandpass', bus:'sfx' });
  Sound.tone({ type:'triangle', f0:220, f1:660, dur:0.36, gain:0.14, bus:'sfx' });
  Sound.tone({ type:'sine', f0:110, f1:70, dur:0.5, gain:0.16, bus:'sfx' });
  Sound.duck(2, 0.35);
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

  /* With a partial score, asking for a track that does not exist must not mean
     silence. Each state falls back along a chain to whatever has been
     delivered, so a single combat loop covers the whole game and every new
     track slots into its own tier without any other change. */
  resolve(k){
    const chain = {
      m_combat3: ['m_combat3', 'm_combat2', 'm_combat1'],
      m_combat2: ['m_combat2', 'm_combat1', 'm_combat3'],
      m_combat1: ['m_combat1', 'm_combat2', 'm_combat3'],
      m_push:    ['m_push', 'm_combat3', 'm_combat2', 'm_combat1'],
      m_boss:    ['m_boss', 'm_push', 'm_combat3', 'm_combat2', 'm_combat1'],
      m_title:   ['m_title', 'm_combat1'],
    }[k] || [k];
    for (const c of chain){ if (AudioBank.get(c)) return c; }
    return chain[0];
  },

  want(){
    const k = this.resolve(this.trackFor());
    if (k === this.cur) return;
    const buf = AudioBank.get(k);          // triggers the lazy fetch
    // Do NOT record the intent here. Setting cur to a track that has not
    // finished downloading makes the next call think it is already playing, so
    // the moment the buffer arrives it is skipped and the music never starts.
    // Leave cur alone and let the next frame retry; get() will not re-fetch.
    if (!buf) return;
    this.cur = k;
    const c = Sound.ctx, t = c.currentTime, XF = 2.0;
    if (this.gain){
      const og = this.gain, on = this.node;
      og.gain.cancelScheduledValues(t);
      og.gain.setValueAtTime(og.gain.value, t);
      og.gain.linearRampToValueAtTime(0.0001, t + XF);
      try { on.stop(t + XF + 0.1); } catch (e) {}
    }
    const m = AUDIO_MANIFEST[k];
    if (m.loop && m.loopStart !== undefined){
      // crossfade-looped: scheduled in passes rather than handed to src.loop
      this.loopSpec = { key: k, buf, start: m.loopStart, end: m.loopEnd };
      const bus = c.createGain();
      bus.gain.setValueAtTime(0.0001, t);
      bus.gain.linearRampToValueAtTime(1, t + XF);
      bus.connect(Sound.dest('music'));
      this.gain = bus; this.node = null;
      this.nextAt = t;
      this.schedule(t);
      return;
    }
    this.loopSpec = null;
    const rec = Sound.sample(k, { gain: 0.0001 });
    if (!rec) { this.gain = null; this.node = null; return; }
    this.gain = rec.g; this.node = rec.src;
    rec.g.gain.setValueAtTime(0.0001, t);
    rec.g.gain.linearRampToValueAtTime(1, t + XF);
  },

  update(){
    if (!Sound.ready) return;
    Sound.keepAwake();
    this.want();
    this.reloop();
  },

  /* Web Audio's own looping is a hard splice, which on generated music lands as
     an audible cut — and these tracks are not authored to loop. So each pass is
     scheduled as its own source with a crossfade over the join: the next one
     starts before the current ends and they trade gain. Costs one extra voice
     for the length of the fade and makes any track loop acceptably, which
     matters with six more still to come. */
  XF: 2.0,

  reloop(){
    if (!this.loopSpec || !this.gain) return;
    const c = Sound.ctx;
    if (c.currentTime < this.nextAt - 0.5) return;
    this.schedule(this.nextAt);
  },

  schedule(at){
    const { key, buf, start, end } = this.loopSpec;
    const c = Sound.ctx, XF = this.XF, len = end - start;
    const src = c.createBufferSource();
    src.buffer = buf;
    const g = c.createGain();
    g.gain.setValueAtTime(0.0001, at);
    g.gain.linearRampToValueAtTime(1, at + XF);
    g.gain.setValueAtTime(1, at + len - XF);
    g.gain.linearRampToValueAtTime(0.0001, at + len);
    src.connect(g); g.connect(Sound.dest('music'));
    src.start(at, start, len + XF);
    src.stop(at + len + 0.05);
    this.nextAt = at + len - XF;
  },
};

/* 8 ------------------------------------------------------------------------ */
/* The voice director (v11).

   Voice is the one layer where more is worse. A line that fires on every wave,
   every draft and every dash stops being character and becomes a notification
   sound with words in it, and there is no volume slider for "say less".

   So three rules, and they are the whole system:

     1. **One line at a time.** A line in flight blocks anything of equal or
        lower priority for its own length plus a gap. Higher priority cuts in.
     2. **Every key has its own cooldown**, and the noisy ones have long ones.
        `vo_dash` is 1-in-6 with an 8s floor, so effort grunts stay incidental.
     3. **Nothing is ever announced only by voice.** Every call site below sits
        on top of a mechanical cue that already fires. Delete the whole layer
        and the game loses flavour, not information.

   No procedural fallback, deliberately: an absent line is silence, not a synth
   impression of a human being. See docs/VOICE-BRIEF.md for the line sheet. */
const Voice = {
  busyUntil: 0, prio: -1, last: {},
  // seconds before the same key may fire again
  CD: {
    vo_wave_start: 20, vo_wave_clear: 20, vo_first_board: 999, vo_hurt_low: 26,
    vo_vent: 22, vo_keg: 30, vo_dash: 8, vo_draft: 30, vo_slot: 20,
    vo_boiler_low: 45, vo_lane_critical: 24, vo_push: 40,
    vo_crew_muster: 30, vo_crew_down: 22, vo_cannon_down: 18,
    vo_boss_arrive: 999, vo_boss_turn: 999, vo_victory: 999, vo_defeat: 999,
  },
  // rough spoken length per key, used to hold the channel without needing the
  // buffer — the director must behave identically before the files land
  LEN: { vo_boss_arrive: 3.0, vo_boss_turn: 2.4, vo_victory: 3.0, vo_defeat: 3.0,
         vo_dash: 0.6, vo_hurt_low: 1.2 },

  say(key, prio, at){
    if (!Sound.ready || Sound.muted) return false;
    if (!AudioBank.has(key)) return false;             // nothing delivered yet
    const t = Sound.ctx.currentTime;
    prio = prio || 0;
    if (t < this.busyUntil && prio <= this.prio) return false;
    const cd = this.CD[key] || 12;
    if (this.last[key] !== undefined && t - this.last[key] < cd) return false;
    const played = Sound.sample(key, at || {});
    if (!played) return false;
    this.last[key] = t;
    this.busyUntil = t + (this.LEN[key] || 1.6) + 0.35;
    this.prio = prio;
    return true;
  },
  reset(){ this.busyUntil = 0; this.prio = -1; this.last = {}; },
};
