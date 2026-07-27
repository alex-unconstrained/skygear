/* ============================================================================
   SKYGEAR  —  a top-down steampunk hero-defense.
   Single file. No assets. No dependencies. Everything below is generated.

   Layout of this file:
     1. TUNING          every balance constant
     2. DATA            palette, shapes, elements, enemies, waves, props, cards
     3. ENGINE          math, rng, input, audio, particles, spatial hash
     4. STATE           game state + reset
     5. SYSTEMS         skills, damage, ai, waves, draft
     6. RENDER          background, deck, entities, vfx, hud, screens
     7. BOOT            fixed-timestep loop
============================================================================ */

/* ---------------------------------------------------------------------------
   1. TUNING — the whole design's numbers live here.
--------------------------------------------------------------------------- */
/* Responsiveness knobs, per build. Defaults reproduce v2/v3 exactly so those
   stay frozen as a record; v4 turns them up. See docs/RESPONSIVENESS.md. */
const FEEL = Object.assign({
  simHz: 60, inputBuffer: 0, killStop: null, stopRefractory: 0,
  cdScale: 1, recoilScale: 1, accel: null, friction: null, dashCd: null,
  camTau: 0.155, autoAttack: null, basic: null, basicTurn: 12, basicArc: 1.2,
  keys: null, loadout: null,
}, (typeof PRESET !== 'undefined' && PRESET.feel) || {});

const TUNING = {
  // NOTE: these are GROUND-PLANE units now, not screen pixels. y is depth:
  // small y = far (the bow), large y = near (the stern, closest to camera).
  world:   { w: 1400, h: 1520 },
  deck:    { cx: 700, cy: 760, w: 900, h: 1360, r: 150, bow: 170 },
  boiler:  { x: 700, y: 760, r: 62, hp: 500 },

  player: {
    hp: 100, radius: 17,
    speed: 260, accel: 2400, friction: 1900,   // accel reaches top speed in ~0.11s
    dashDist: 220, dashTime: 0.16, dashCd: 1.6, dashCharges: 1,
    regenPerWave: 4,
    critChance: 0.12, critMult: 2.0,
    invulnAfterHit: 0.55,
  },

  feel: {
    hitStopThreshold: 25,      // damage at/above this freezes the sim
    hitStopBig: 0.040,
    hitStopKill: 0.070,
    traumaHit: 0.15, traumaKill: 0.25, traumaPlayer: 0.5,
    traumaDecay: 1.6, shakeMax: 14,
    flashTime: 0.06,
    dmgNumberLife: 0.7,
    waveClearSlowmo: 0.35, waveClearSlowmoTime: 0.8,
    maxParticles: 400,
  },

  enemyScaling: 0.06,          // hp multiplier per wave beyond the first
  telegraph: 0.40,             // every enemy attack shows its shape this long first
  spawnClimb: 0.80,            // boarders climb the rail this long before they're live
  maxLiveEnemies: 64,          // spawner throttle — keeps the crowd readable and fast
  totalWaves: 12,
};

/* ---------------------------------------------------------------------------
   2. DATA
--------------------------------------------------------------------------- */
const PAL = {
  // §1.3 base / environment
  ink:        '#0D0B12',   // universal outline & deepest shadow
  base:       '#14121B',   // the tone every asset must read against
  timberDark: '#2A2027',
  timber:     '#3D2E30',
  timberLite: '#54413C',
  skyDeep:    '#1B1830',
  skyMid:     '#2E2A4E',
  moon:       '#8FA6C9',
  // §1.3 materials
  brass:      '#B0813F',
  brassLite:  '#E8C376',
  copper:     '#3E8F83',
  iron:       '#4A4A55',
  leather:    '#6E4A2F',
  lantern:    '#FFB347',
  // §1.3 gameplay pops — used nowhere else
  teal:       '#37F0C8',
  danger:     '#FF3D2E',
  dangerIn:   '#FF8C1A',
  fire:       '#FF7A2F',
  fireCore:   '#FFE08A',
  tesla:      '#7ADCFF',
  crit:       '#FFD52E',
  relic:      '#C77DFF',
  bone:       '#E8E2D2',
  // aliases kept so the ported simulation core needs no edits
  deck:'#3D2E30', deckDark:'#2A2027', deckLite:'#54413C', inkSoft:'#1B1830',
  orange:'#FF7A2F', brown:'#2A2027', sage:'#3E8F83', purple:'#2E2A4E',
  olive:'#54413C', grey:'#4A4A55', oxblood:'#FF3D2E', sky:'#2E2A4E',
};

/* ---------------------------------------------------------------------------
   3. ENGINE — math + rng
--------------------------------------------------------------------------- */
const TAU = Math.PI * 2, DEG = Math.PI / 180;
const clamp = (v,a,b) => v < a ? a : v > b ? b : v;
const lerp  = (a,b,t) => a + (b - a) * t;
const dist  = (ax,ay,bx,by) => Math.hypot(bx-ax, by-ay);
const dist2 = (ax,ay,bx,by) => { const dx=bx-ax, dy=by-ay; return dx*dx+dy*dy; };
function angNorm(a){ a %= TAU; if (a > Math.PI) a -= TAU; if (a < -Math.PI) a += TAU; return a; }
function angDiff(a,b){ return angNorm(b - a); }
function rnd(a,b){ if (b === undefined) { b = a === undefined ? 1 : a; a = 0; } return a + Math.random()*(b-a); }
function rndi(a,b){ return Math.floor(rnd(a,b)); }
function pick(arr){ return arr[rndi(0,arr.length)]; }
function chance(p){ return Math.random() < p; }
function shuffle(a){ for (let i=a.length-1;i>0;i--){ const j=rndi(0,i+1); const t=a[i]; a[i]=a[j]; a[j]=t; } return a; }
const easeOut = t => 1 - Math.pow(1-t, 3);
const easeIn  = t => t*t*t;
function approach(cur, target, delta){ return cur < target ? Math.min(cur+delta, target) : Math.max(cur-delta, target); }

/* ---------------------------------------------------------------------------
   ENGINE — canvas + viewport. Fixed camera: the whole deck is always visible.
--------------------------------------------------------------------------- */
const cv = document.getElementById('c');
let ctx = cv.getContext('2d', { alpha: false });
const View = { scale: 1, ox: 0, oy: 0, w: 0, h: 0, dpr: 1 };

// Draw into an offscreen context using all the same helpers.
function withCtx(c, fn){ const prev = ctx; ctx = c; try { fn(); } finally { ctx = prev; } }

function resize(){
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  const w = window.innerWidth, h = window.innerHeight;
  cv.width  = Math.floor(w * dpr);
  cv.height = Math.floor(h * dpr);
  cv.style.width = w + 'px';
  cv.style.height = h + 'px';
  View.dpr = dpr; View.w = w; View.h = h;
  // the ground plane is projected, so there is no uniform world->screen scale;
  // `unit` only drives HUD and art sizing against a 1400x860 reference frame.
  View.unit = clamp(Math.min(w / 1400, h / 860), 0.55, 1.6);
  View.scale = View.unit; View.ox = 0; View.oy = 0;
  CAM.recompute();
}
window.addEventListener('resize', () => { resize(); onViewportChanged(); });

// Screen -> ground plane. Inverts the pinhole for y = 0 (the deck surface).
function screenToWorld(sx, sy){
  return CAM.unproject(sx, sy);
}

/* ---------------------------------------------------------------------------
   ENGINE — input
--------------------------------------------------------------------------- */
const Input = {
  keys: new Set(),
  pressed: new Set(),          // edge-triggered, cleared each sim step
  mouse: { x: TUNING.world.w/2, y: TUNING.world.h/2, sx: 0, sy: 0 },
  buttons: [false, false, false],
  clicked: false,
  clickX: 0, clickY: 0,        // screen space, for UI
  rightClicked: false,
  wheel: 0,
  anyInput: false,
};

function keyName(e){
  let k = e.key;
  if (k === ' ') return 'space';
  if (k.length === 1) return k.toLowerCase();
  return k.toLowerCase();
}

window.addEventListener('keydown', e => {
  const k = keyName(e);
  if (['space','arrowup','arrowdown','arrowleft','arrowright','tab',"'",'/'].includes(k)) e.preventDefault();
  if (!Input.keys.has(k)) Input.pressed.add(k);
  Input.keys.add(k);
  Input.anyInput = true;
  Sound.unlock();
});
window.addEventListener('keyup', e => { Input.keys.delete(keyName(e)); });
window.addEventListener('blur', () => { Input.keys.clear(); Input.buttons = [false,false,false]; });

cv.addEventListener('contextmenu', e => e.preventDefault());
window.addEventListener('mousemove', e => {
  Input.mouse.sx = e.clientX; Input.mouse.sy = e.clientY;
  const w = screenToWorld(e.clientX, e.clientY);
  Input.mouse.x = w.x; Input.mouse.y = w.y;
});
window.addEventListener('mousedown', e => {
  Input.buttons[e.button] = true;
  if (e.button === 0){ Input.clicked = true; Input.clickX = e.clientX; Input.clickY = e.clientY; }
  if (e.button === 2){ Input.rightClicked = true; }
  Input.anyInput = true;
  Sound.unlock();
  e.preventDefault();
});
window.addEventListener('mouseup', e => { Input.buttons[e.button] = false; });

function keyDown(k){ return Input.keys.has(k); }
function keyHit(k){ return Input.pressed.has(k); }

/* ---------------------------------------------------------------------------
   ENGINE — audio. Everything synthesised: oscillators, noise, filters.
--------------------------------------------------------------------------- */
const Sound = {
  ctx: null, master: null, comp: null, noiseBuf: null,
  vol: 0.65, muted: false, ready: false,

  unlock(){
    if (this.ready) return;
    try {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return;
      this.ctx = new AC();
      this.comp = this.ctx.createDynamicsCompressor();
      this.comp.threshold.value = -14; this.comp.knee.value = 22;
      this.comp.ratio.value = 8; this.comp.attack.value = 0.003; this.comp.release.value = 0.16;
      this.master = this.ctx.createGain();
      this.master.gain.value = this.muted ? 0 : this.vol;
      this.master.connect(this.comp); this.comp.connect(this.ctx.destination);
      // one shared noise buffer
      const n = this.ctx.sampleRate * 1.0;
      const buf = this.ctx.createBuffer(1, n, this.ctx.sampleRate);
      const d = buf.getChannelData(0);
      for (let i=0;i<n;i++) d[i] = Math.random()*2-1;
      this.noiseBuf = buf;
      this.ready = true;
    } catch(err){ /* audio unavailable — the game plays fine silently */ }
    if (this.ctx && this.ctx.state === 'suspended') this.ctx.resume();
  },

  setVol(v){
    this.vol = clamp(v, 0, 1);
    if (this.master) this.master.gain.value = this.muted ? 0 : this.vol;
  },
  toggleMute(){
    this.muted = !this.muted;
    if (this.master) this.master.gain.value = this.muted ? 0 : this.vol;
  },

  // Bus routing. _audio.js installs master-fed buses (music/sfx/ui/voice) and
  // overrides this; before that, and if audio assets are off, every cue lands
  // on master exactly as it always did.
  dest(){ return this.master; },

  // --- primitives -----------------------------------------------------------
  tone(o){
    if (!this.ready || this.muted) return;
    const c = this.ctx, t = c.currentTime + (o.delay || 0);
    const osc = c.createOscillator();
    osc.type = o.type || 'sine';
    osc.frequency.setValueAtTime(o.f0, t);
    if (o.f1 !== undefined) osc.frequency.exponentialRampToValueAtTime(Math.max(1,o.f1), t + o.dur);
    const g = c.createGain();
    const peak = (o.gain === undefined ? 0.3 : o.gain);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(peak, t + Math.min(0.012, o.dur*0.3));
    g.gain.exponentialRampToValueAtTime(0.0001, t + o.dur);
    let node = osc;
    if (o.filter){
      const f = c.createBiquadFilter();
      f.type = o.filter; f.frequency.value = o.ff || 1200; f.Q.value = o.q || 1;
      node.connect(f); node = f;
    }
    node.connect(g); g.connect(o.out || this.dest(o.bus));
    osc.start(t); osc.stop(t + o.dur + 0.02);
  },

  noise(o){
    if (!this.ready || this.muted) return;
    const c = this.ctx, t = c.currentTime + (o.delay || 0);
    const src = c.createBufferSource();
    src.buffer = this.noiseBuf;
    src.playbackRate.value = o.rate || 1;
    const f = c.createBiquadFilter();
    f.type = o.filter || 'bandpass';
    f.frequency.setValueAtTime(o.ff0 || 900, t);
    if (o.ff1 !== undefined) f.frequency.exponentialRampToValueAtTime(Math.max(30,o.ff1), t + o.dur);
    f.Q.value = o.q === undefined ? 1.2 : o.q;
    const g = c.createGain();
    const peak = (o.gain === undefined ? 0.3 : o.gain);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(peak, t + Math.min(0.01, o.dur*0.25));
    g.gain.exponentialRampToValueAtTime(0.0001, t + o.dur);
    src.connect(f); f.connect(g); g.connect(o.out || this.dest(o.bus));
    src.start(t, rnd(0, 0.4)); src.stop(t + o.dur + 0.02);
  },
};

// Named cues. Kept short and punchy on purpose.
const SFX = {
  fire: {
    EMBER: () => { Sound.noise({dur:0.20, ff0:1800, ff1:260, q:0.8, gain:0.26, filter:'lowpass', rate:0.8});
                   Sound.tone({type:'sawtooth', f0:180, f1:60, dur:0.18, gain:0.16}); },
    FROST: () => { Sound.tone({type:'triangle', f0:1500, f1:520, dur:0.20, gain:0.20});
                   Sound.noise({dur:0.16, ff0:5200, ff1:2200, q:3, gain:0.10}); },
    ARC:   () => { Sound.tone({type:'square', f0:820, f1:1900, dur:0.09, gain:0.13});
                   Sound.noise({dur:0.12, ff0:3000, ff1:6500, q:5, gain:0.12}); },
    STEAM: () => { Sound.noise({dur:0.30, ff0:900, ff1:2600, q:0.7, gain:0.22, filter:'bandpass'});
                   Sound.tone({type:'sine', f0:300, f1:140, dur:0.16, gain:0.10}); },
  },
  hit(){        Sound.noise({dur:0.07, ff0:2400, ff1:700, q:0.9, gain:0.20, filter:'lowpass'}); },
  crit(){       Sound.tone({type:'sine', f0:1300, f1:2600, dur:0.13, gain:0.22});
                Sound.tone({type:'triangle', f0:2600, f1:3400, dur:0.10, gain:0.10, delay:0.02}); },
  death(){      Sound.noise({dur:0.24, ff0:1400, ff1:150, q:0.7, gain:0.26, filter:'lowpass'});
                Sound.tone({type:'square', f0:210, f1:48, dur:0.20, gain:0.13}); },
  hurt(){       Sound.tone({type:'sawtooth', f0:220, f1:70, dur:0.30, gain:0.24});
                Sound.noise({dur:0.20, ff0:700, ff1:180, q:0.6, gain:0.20, filter:'lowpass'}); },
  dash(){       Sound.noise({dur:0.24, ff0:400, ff1:3600, q:2.2, gain:0.16}); },
  ready(){      Sound.tone({type:'sine', f0:900, f1:1250, dur:0.07, gain:0.08}); },
  boiler(){     Sound.tone({type:'sine', f0:120, f1:44, dur:0.36, gain:0.26});
                Sound.noise({dur:0.16, ff0:500, ff1:110, q:0.6, gain:0.14, filter:'lowpass'}); },
  waveClear(){  [0,1,2,3].forEach((i)=> Sound.tone({type:'triangle', f0:[523,659,784,1047][i], dur:0.42, gain:0.16, delay:i*0.085})); },
  cardPick(){   Sound.tone({type:'square', f0:620, dur:0.06, gain:0.14});
                Sound.tone({type:'square', f0:940, dur:0.10, gain:0.14, delay:0.06}); },
  uiHover(){    Sound.tone({type:'sine', f0:520, dur:0.04, gain:0.05}); },
  uiClick(){    Sound.tone({type:'square', f0:340, f1:600, dur:0.07, gain:0.11}); },
  enemyShoot(){ Sound.tone({type:'sawtooth', f0:520, f1:170, dur:0.16, gain:0.11});
                Sound.noise({dur:0.10, ff0:1600, ff1:600, q:1.4, gain:0.08}); },
  telegraph(){  Sound.tone({type:'sine', f0:300, f1:420, dur:0.10, gain:0.05}); },
  bossRoar(){   Sound.tone({type:'sawtooth', f0:130, f1:42, dur:1.1, gain:0.30});
                Sound.tone({type:'square', f0:66, f1:30, dur:1.3, gain:0.20});
                Sound.noise({dur:1.0, ff0:600, ff1:120, q:0.5, gain:0.22, filter:'lowpass'}); },
  slam(){       Sound.tone({type:'sine', f0:90, f1:32, dur:0.45, gain:0.32});
                Sound.noise({dur:0.30, ff0:900, ff1:90, q:0.6, gain:0.26, filter:'lowpass'}); },
  pickup(){     Sound.tone({type:'triangle', f0:700, f1:1250, dur:0.14, gain:0.16}); },
  victory(){    [523,659,784,1047,1319].forEach((f,i)=> Sound.tone({type:'triangle', f0:f, dur:0.7, gain:0.16, delay:i*0.12})); },
  defeat(){     [400,330,262,196].forEach((f,i)=> Sound.tone({type:'sawtooth', f0:f, f1:f*0.75, dur:0.7, gain:0.16, delay:i*0.18})); },
};

/* ---------------------------------------------------------------------------
   DATA — deck geometry
--------------------------------------------------------------------------- */
function inDeck(x, y, m){
  m = m || 0;
  const D = TUNING.deck, hw = D.w/2 - m, hh = D.h/2 - m, r = Math.max(0, D.r - m);
  const ax = Math.abs(x - D.cx), ay = Math.abs(y - D.cy);
  if (ax > hw || ay > hh) return false;
  if (ax <= hw - r || ay <= hh - r) return true;
  const dx = ax - (hw - r), dy = ay - (hh - r);
  return dx*dx + dy*dy <= r*r;
}
function clampToDeck(x, y, m){
  m = m || 0;
  const D = TUNING.deck, hw = D.w/2 - m, hh = D.h/2 - m, r = Math.max(1, D.r - m);
  let px = clamp(x, D.cx - hw, D.cx + hw);
  let py = clamp(y, D.cy - hh, D.cy + hh);
  const ax = Math.abs(px - D.cx), ay = Math.abs(py - D.cy);
  if (ax > hw - r && ay > hh - r){
    const kx = D.cx + Math.sign(px - D.cx) * (hw - r);
    const ky = D.cy + Math.sign(py - D.cy) * (hh - r);
    const dx = px - kx, dy = py - ky, d = Math.hypot(dx, dy);
    if (d > r){ px = kx + dx/d*r; py = ky + dy/d*r; }
  }
  return { x: px, y: py };
}

// Boarding points: over the bow and both rails.
const SPAWN_POINTS = (() => {
  const D = TUNING.deck, pts = [];
  const top = D.cy - D.h/2, bot = D.cy + D.h/2, lef = D.cx - D.w/2, rig = D.cx + D.w/2;
  for (let i = 0; i < 7; i++) pts.push({ x: lerp(lef + 130, rig - 130, i/6), y: top + 20, side: 'bow' });
  for (let i = 0; i < 8; i++){
    const y = lerp(top + 200, bot - 180, i/7);
    pts.push({ x: lef + 14, y, side: 'left' });
    pts.push({ x: rig - 14, y, side: 'right' });
  }
  return pts;
})();

/* ---------------------------------------------------------------------------
   DATA — SHAPES. How a skill delivers. 6 of them.
--------------------------------------------------------------------------- */
const SHAPES = {
  CLOSEHIT: {
    key:'CLOSEHIT', noun:'Cleave', kind:'arc', desc:'140° sweep at melee range',
    // spec says 90px; entities are drawn ~40% larger than the spec implies, so
    // melee reach scales with them or the sweep lands inside the enemy sprite.
    range: 126, arc: 140*DEG, dmg: 22, cd: 0.45, knock: 150,
  },
  LINE_BURST: {
    key:'LINE_BURST', noun:'Lance', kind:'line', desc:'piercing bolt down a line',
    len: 520, width: 26, dmg: 30, cd: 1.1, pierce: 4, knock: 190,
    // Spec says "hits all in path"; capped at 4 targets so the +pierce card is felt.
  },
  CONE: {
    key:'CONE', noun:'Gale', kind:'cone', desc:'expanding frontal cone',
    arc: 65*DEG, range: 300, dmg: 26, cd: 1.4, knock: 210,
  },
  RANGED_AOE: {
    key:'RANGED_AOE', noun:'Mortar', kind:'aoe', desc:'burst placed at the cursor',
    radius: 110, castRange: 420, dmg: 40, cd: 2.6, knock: 260,
  },
  CHAIN: {
    key:'CHAIN', noun:'Whip', kind:'chain', desc:'arcs between nearby enemies',
    dmg: 26, cd: 2.0, jumps: 3, jumpRange: 200, seekRange: 480, falloff: 0.15, knock: 90,
  },
  RAY: {
    key:'RAY', noun:'Beam', kind:'ray', desc:'sustained beam while held',
    len: 480, width: 24, dmg: 7, tickRate: 8, cd: 0.6, maxDur: 2.5, knock: 40,
  },
};
const SHAPE_KEYS = Object.keys(SHAPES);

/* ---------------------------------------------------------------------------
   DATA — ELEMENTS. What a skill does on hit. Applies to every shape.
--------------------------------------------------------------------------- */
const ELEMENTS = {
  EMBER: { key:'EMBER', name:'Ember', color:'#FF7A2F', glow:'#FFE08A', dark:'#4A2410',
           blurb:'burns for 5/s, stacks 3×' },
  FROST: { key:'FROST', name:'Frost', color:'#37F0C8', glow:'#BFFFF0', dark:'#0E3A34',
           blurb:'slows 40% for 2s' },
  ARC:   { key:'ARC',   name:'Arc',   color:'#7ADCFF', glow:'#FFFFFF', dark:'#12384A',
           blurb:'20% stun · +1 chain jump' },
  STEAM: { key:'STEAM', name:'Steam', color:'#C9B6E8', glow:'#F2EAFF', dark:'#2A2340',
           blurb:'knocks back, ruins their aim' },
};
const ELEMENT_KEYS = Object.keys(ELEMENTS);

function skillName(sk){ return ELEMENTS[sk.element].name + ' ' + SHAPES[sk.shape].noun; }

/* ---------------------------------------------------------------------------
   DATA — ENEMIES
--------------------------------------------------------------------------- */
const ENEMIES = {
  SCRAPPER: { key:'SCRAPPER', hp: 60,  speed: 150, dmg: 12, radius: 22, mass: 1.0, art: 1.85, spriteHalf: 64,
              atkRange: 66,  windup: 0.40, recover: 0.42, ai:'melee', swing: 95*DEG, reach: 92, xp: 1 },
  GUNNER:   { key:'GUNNER',   hp: 35,  speed: 110, dmg: 10, radius: 21, mass: 0.8, art: 1.80, spriteHalf: 76,
              atkRange: 340, windup: 0.45, recover: 0.80, ai:'ranged', bolt: 430, xp: 1 },
  ARMORED:  { key:'ARMORED',  hp: 180, speed: 75,  dmg: 20, radius: 32, mass: 2.6, art: 1.70, spriteHalf: 62,
              atkRange: 82,  windup: 0.55, recover: 0.60, ai:'melee', swing: 120*DEG, reach: 118,
              frontDR: 0.40, frontArc: 110*DEG, xp: 3 },
  SWARM:    { key:'SWARM',    hp: 20,  speed: 230, dmg: 6,  radius: 15, mass: 0.45, art: 1.78, spriteHalf: 30,
              atkRange: 46,  windup: 0.40, recover: 0.30, ai:'swarm', swing: 80*DEG, reach: 64, xp: 1 },
  BOSS:     { key:'BOSS',     hp: 900, speed: 95,  dmg: 0,  radius: 70, mass: 24, art: 1.34,
              atkRange: 999, windup: 0.9, recover: 1.0, ai:'boss', xp: 25 },
};

/* ---------------------------------------------------------------------------
   DATA — WAVES. batch = [t seconds into the wave, type, count].
   Adding a wave means adding one object to this array. That's the whole API.
--------------------------------------------------------------------------- */
const WAVES = [
  { batches: [[0,'SCRAPPER',3],[3.0,'SCRAPPER',3]] },
  { batches: [[0,'SCRAPPER',4],[2.5,'GUNNER',3],[6.0,'SCRAPPER',4]] },
  { batches: [[0,'SWARM',8],[2.0,'SCRAPPER',3],[5.0,'GUNNER',4],[8.0,'SCRAPPER',3]] },
  { batches: [[0,'SCRAPPER',5],[2.0,'ARMORED',2],[5.0,'SWARM',6],[8.0,'SCRAPPER',5]] },
  { batches: [[0,'GUNNER',3],[1.5,'SWARM',6],[4.5,'ARMORED',3],[7.0,'GUNNER',3],[9.5,'SWARM',6]] },
  { batches: [[0,'SCRAPPER',6],[2.5,'GUNNER',3],[5.0,'ARMORED',3],[7.5,'SCRAPPER',6],[10,'GUNNER',3]] },
  { batches: [[0,'SWARM',8],[2.0,'ARMORED',2],[4.0,'GUNNER',3],[6.5,'SWARM',8],[9.0,'ARMORED',2],[11,'GUNNER',3]] },
  { batches: [[0,'SCRAPPER',7],[2.0,'GUNNER',4],[4.5,'ARMORED',2],[7.0,'SCRAPPER',7],[9.5,'GUNNER',4],[12,'ARMORED',2]] },
  { batches: [[0,'SWARM',9],[2.0,'SCRAPPER',4],[4.0,'ARMORED',3],[6.0,'SWARM',9],[8.5,'SCRAPPER',4],[11,'ARMORED',2]] },
  { batches: [[0,'SCRAPPER',6],[2.0,'GUNNER',5],[4.0,'SWARM',10],[6.5,'ARMORED',3],[9,'SCRAPPER',6],[11.5,'GUNNER',5],[14,'ARMORED',3]] },
  { batches: [[0,'SWARM',10],[2.0,'GUNNER',6],[4.0,'SCRAPPER',7],[6.0,'ARMORED',4],[8.5,'SWARM',8],[11,'GUNNER',6],[13.5,'SCRAPPER',7],[16,'ARMORED',4]] },
  // Wave 12 — the boss, plus adds forever until it dies.
  { boss: true, batches: [[0,'BOSS',1],[4,'SWARM',6],[9,'SCRAPPER',4]],
    loop: { every: 9.5, sets: [['SWARM',5],['SCRAPPER',4],['GUNNER',3],['SWARM',6],['ARMORED',2]] } },
];

/* Lane campaign. Waves 4 and 8 are pushes: their hulk opens and you have to
   leave the objective to break it. Everything else is a hold. Lane numbers are
   0 = port, 1 = centre, 2 = starboard; 'all' hits every lane; 'rail' climbs a
   side rail amidships as a scripted interruption. */
const LANE_WAVE_TABLE = [
  { batches: [[0,'SCRAPPER',2,1],[4,'SCRAPPER',2,0],[8,'SCRAPPER',2,2]] },
  { batches: [[0,'SCRAPPER',2,'all'],[6,'GUNNER',1,1],[10,'SCRAPPER',3,1]] },
  { batches: [[0,'SWARM',4,'all'],[5,'SCRAPPER',2,0],[9,'GUNNER',2,2],[13,'SWARM',4,1]] },
  { push: true,
    batches: [[0,'SCRAPPER',3,'all'],[7,'GUNNER',2,1],[13,'SWARM',5,'all'],[20,'SCRAPPER',3,'all']],
    loop: { every: 11, sets: [['SCRAPPER',2],['SWARM',4],['GUNNER',2]] } },
  { batches: [[0,'ARMORED',1,1],[4,'SWARM',5,'all'],[9,'GUNNER',2,0],[13,'SCRAPPER',3,2]] },
  { batches: [[0,'SCRAPPER',3,'all'],[6,'ARMORED',1,0],[8,'ARMORED',1,2],[13,'GUNNER',2,1],[17,'SWARM',5,'all']] },
  { batches: [[0,'SWARM',6,'all'],[5,'ARMORED',1,1],[9,'GUNNER',2,'all'],[15,'SCRAPPER',3,'all'],[19,'SCRAPPER',2,'rail']] },
  { push: true,
    batches: [[0,'SCRAPPER',3,'all'],[6,'ARMORED',1,'all'],[13,'GUNNER',2,'all'],[19,'SWARM',6,'all']],
    loop: { every: 10, sets: [['SCRAPPER',3],['SWARM',5],['ARMORED',1],['GUNNER',2]] } },
  { batches: [[0,'SWARM',6,'all'],[5,'ARMORED',2,1],[10,'SCRAPPER',3,'all'],[15,'GUNNER',2,'all'],[20,'SWARM',3,'rail']] },
  { batches: [[0,'ARMORED',1,'all'],[6,'GUNNER',3,'all'],[12,'SCRAPPER',4,'all'],[18,'SWARM',6,'all'],[23,'ARMORED',1,'all']] },
  { batches: [[0,'SWARM',7,'all'],[5,'SCRAPPER',4,'all'],[11,'ARMORED',2,'all'],[17,'GUNNER',3,'all'],[22,'SCRAPPER',3,'rail'],[26,'SWARM',7,'all']] },
  { boss: true, push: true,
    batches: [[0,'BOSS',1,1],[5,'SWARM',4,'all'],[11,'SCRAPPER',3,'all']],
    loop: { every: 10, sets: [['SWARM',5],['SCRAPPER',3],['GUNNER',2],['ARMORED',1]] } },
];
if (PRESET.lanes) for (let i = 0; i < WAVES.length; i++) WAVES[i] = LANE_WAVE_TABLE[i];

/* ---------------------------------------------------------------------------
   DATA — deck props. Visual, and they block movement. Middle stays open.
--------------------------------------------------------------------------- */
// Deck dressing, authored in NORMALISED deck coordinates so the same table
// dresses a short deck and a long one: u is across (-1 port .. +1 starboard),
// v is along the keel (0 at the bow, 1 at the stern).
const PROP_LAYOUT = [
  ['ballista', 0.00, 0.055, 40,  0],
  ['lantern', -0.68, 0.105, 16,  0],
  ['lantern',  0.68, 0.105, 16,  0],
  ['barrel',  -0.52, 0.155, 25,  0],
  ['barrel',   0.52, 0.155, 25,  0],
  ['mast',     0.00, 0.215, 30,  0],
  ['crate',   -0.80, 0.260, 34,  0.14],
  ['crate',   -0.88, 0.310, 27, -0.30],
  ['crates',   0.82, 0.270, 38, -0.10],
  ['vent',    -0.38, 0.375,  0,  0],
  ['vent',     0.38, 0.375,  0,  0],
  ['cannon',  -0.96, 0.450, 38,  Math.PI],
  ['cannon',   0.96, 0.450, 38,  0],
  ['crate',    0.86, 0.520, 30,  0.22],
  ['barrel',  -0.86, 0.545, 25,  0],
  ['lantern', -0.70, 0.600, 16,  0],
  ['lantern',  0.70, 0.600, 16,  0],
  ['rope',    -0.58, 0.665,  0,  0],
  ['rope',     0.58, 0.665,  0,  0],
  ['crates',  -0.84, 0.715, 38,  0.08],
  ['hatch',    0.00, 0.775,  0,  0],
  ['crate',   -0.78, 0.825, 32, -0.22],
  ['barrel',   0.78, 0.825, 25,  0],
  ['cannon',  -0.96, 0.870, 38,  Math.PI],
  ['cannon',   0.96, 0.870, 38,  0],
  ['lantern', -0.62, 0.930, 16,  0],
  ['lantern',  0.62, 0.930, 16,  0],
];
const PROPS = PROP_LAYOUT.map(function(p){
  const D = TUNING.deck;
  return {
    t: p[0],
    x: D.cx + p[1] * (D.w / 2 - 90),
    y: (D.cy - D.h / 2) + p[2] * D.h,
    r: p[3], rot: p[4],
  };
}).filter(function(p){
  // never dress the ground the Boiler stands on
  if (dist(p.x, p.y, TUNING.boiler.x, TUNING.boiler.y) < 190) return false;
  // on a lane map, nothing solid may stand inside a walkable lane — a mast in
  // the middle of the centre lane is a wall you cannot see coming
  if (PRESET.lanes && p.r > 0){
    const D = TUNING.deck, laneW = D.w / 3;
    const left = D.cx - D.w / 2;
    for (let i = 0; i < 3; i++){
      const cx = left + laneW * (i + 0.5), inner = laneW * 0.5 - 66;
      if (Math.abs(p.x - cx) < inner - 40 && p.y < D.cy + D.h / 2 - 430) return false;
    }
  }
  return true;
});
const SOLID_PROPS = PROPS.filter(p => p.r > 0);

/* ---------------------------------------------------------------------------
   DATA — DRAFT CARDS. 34 of them. Every one has a visible effect in play.
   A card declares: can it be offered right now, how much do we want to offer it
   (weighted toward the build you already have), and what a concrete instance is.
--------------------------------------------------------------------------- */
const RARITY = {
  common:    { name:'COMMON',    edge:'#B9AE86', fill:'#3A3226', glow:'rgba(185,174,134,0.35)' },
  rare:      { name:'RARE',      edge:'#7FC7D9', fill:'#243943', glow:'rgba(127,199,217,0.40)' },
  epic:      { name:'EPIC',      edge:'#B9A8C9', fill:'#332B3D', glow:'rgba(185,168,201,0.45)' },
  legendary: { name:'LEGENDARY', edge:'#D9A441', fill:'#453317', glow:'rgba(217,164,65,0.55)' },
};

// helpers used by cards ------------------------------------------------------
function filledSlots(S){ const o=[]; for (let i=0;i<4;i++) if (S.slots[i]) o.push(i); return o; }
function slotsWhere(S, fn){ const o=[]; for (let i=0;i<4;i++) if (S.slots[i] && fn(S.slots[i], i)) o.push(i); return o; }
function emptyUnlocked(S){ const o=[]; for (let i=0;i<S.unlockedSlots;i++) if (!S.slots[i]) o.push(i); return o; }
function hasElement(S, e){ return slotsWhere(S, sk => sk.element === e).length > 0; }
function elemTag(S, e){ return hasElement(S, e) ? 3.0 : 0.45; }   // build weighting
function newSkill(shape, element){
  return { shape, element, mods:{ aoe:1, range:1, cd:1, dmg:1, pierce:0, jumps:0, knock:1, multi:1 }, cdLeft:0, casts:0, readyPulse:0 };
}
function randomSkill(avoid){
  const shapes = SHAPE_KEYS.filter(s => !avoid || !avoid.includes(s));
  return newSkill(pick(shapes.length ? shapes : SHAPE_KEYS), pick(ELEMENT_KEYS));
}

const CARDS = [
  // ---- shape mods -----------------------------------------------------------
  { id:'aoe', rarity:'common', weight:S => 10,
    can:S => slotsWhere(S, sk => sk.shape !== 'LINE_BURST' && sk.shape !== 'CHAIN').length > 0,
    make:S => { const i = pick(slotsWhere(S, sk => sk.shape !== 'LINE_BURST' && sk.shape !== 'CHAIN'));
      return { title:'WIDE BLAST', text:'+35% area on ' + skillName(S.slots[i]) + '.', slot:i,
               apply:S => { S.slots[i].mods.aoe *= 1.35; } }; } },

  { id:'range', rarity:'common', weight:S => 10,
    can:S => filledSlots(S).length > 0,
    make:S => { const i = pick(filledSlots(S));
      return { title:'LONG REACH', text:'+30% range on ' + skillName(S.slots[i]) + '.', slot:i,
               apply:S => { S.slots[i].mods.range *= 1.30; } }; } },

  { id:'cd', rarity:'common', weight:S => 12,
    can:S => slotsWhere(S, sk => sk.mods.cd > 0.42).length > 0,
    make:S => { const i = pick(slotsWhere(S, sk => sk.mods.cd > 0.42));
      return { title:'QUICK HANDS', text:'−20% cooldown on ' + skillName(S.slots[i]) + '.', slot:i,
               apply:S => { S.slots[i].mods.cd *= 0.80; } }; } },

  { id:'dmg', rarity:'common', weight:S => 12,
    can:S => filledSlots(S).length > 0,
    make:S => { const i = pick(filledSlots(S));
      return { title:'HEAVY HIT', text:'+25% damage on ' + skillName(S.slots[i]) + '.', slot:i,
               apply:S => { S.slots[i].mods.dmg *= 1.25; } }; } },

  { id:'jump', rarity:'rare', weight:S => 14,
    can:S => slotsWhere(S, sk => sk.shape === 'CHAIN').length > 0,
    make:S => { const i = pick(slotsWhere(S, sk => sk.shape === 'CHAIN'));
      return { title:'FORKED CURRENT', text:'+1 chain jump on ' + skillName(S.slots[i]) + '.', slot:i,
               apply:S => { S.slots[i].mods.jumps += 1; } }; } },

  { id:'pierce', rarity:'rare', weight:S => 14,
    can:S => slotsWhere(S, sk => sk.shape === 'LINE_BURST').length > 0,
    make:S => { const i = pick(slotsWhere(S, sk => sk.shape === 'LINE_BURST'));
      return { title:'ARMOUR-PIERCER', text:'+2 pierce on ' + skillName(S.slots[i]) + '.', slot:i,
               apply:S => { S.slots[i].mods.pierce += 2; } }; } },

  { id:'widecone', rarity:'rare', weight:S => 14,
    can:S => slotsWhere(S, sk => sk.shape === 'CONE' && !sk.mods.wideCone).length > 0,
    make:S => { const i = pick(slotsWhere(S, sk => sk.shape === 'CONE' && !sk.mods.wideCone));
      return { title:'FULL SPREAD', text:skillName(S.slots[i]) + ' widens to 95°.', slot:i,
               apply:S => { S.slots[i].mods.wideCone = true; } }; } },

  { id:'knockskill', rarity:'common', weight:S => 7,
    can:S => filledSlots(S).length > 0,
    make:S => { const i = pick(filledSlots(S));
      return { title:'OVERPRESSURE', text:'Double knockback on ' + skillName(S.slots[i]) + '.', slot:i,
               apply:S => { S.slots[i].mods.knock *= 2; } }; } },

  { id:'twin', rarity:'epic', weight:S => 9,
    can:S => slotsWhere(S, sk => sk.mods.multi < 2 && sk.shape !== 'RAY').length > 0,
    make:S => { const i = pick(slotsWhere(S, sk => sk.mods.multi < 2 && sk.shape !== 'RAY'));
      return { title:'TWIN CAST', text:skillName(S.slots[i]) + ' fires twice, 70% damage each.', slot:i,
               apply:S => { S.slots[i].mods.multi = 2; } }; } },

  // ---- element mods ---------------------------------------------------------
  { id:'burnDmg', rarity:'common', weight:S => 6 * elemTag(S,'EMBER'), can:S => true,
    make:S => ({ title:'ACCELERANT', text:'Burn deals +50% damage.',
                 apply:S => { S.mods.burnDmg += 0.5; } }) },
  { id:'burnDur', rarity:'common', weight:S => 4 * elemTag(S,'EMBER'), can:S => true,
    make:S => ({ title:'SLOW BURN', text:'Burn lasts 2 seconds longer.',
                 apply:S => { S.mods.burnDur += 2; } }) },
  { id:'slowAmt', rarity:'common', weight:S => 6 * elemTag(S,'FROST'), can:S => S.mods.slowAmt < 0.64,
    make:S => ({ title:'DEEP FREEZE', text:'Frost slow becomes 65%.',
                 apply:S => { S.mods.slowAmt = 0.65; } }) },
  { id:'brittle', rarity:'rare', weight:S => 5 * elemTag(S,'FROST'), can:S => S.mods.slowDmg < 0.5,
    make:S => ({ title:'BRITTLE', text:'Slowed enemies take +25% damage.',
                 apply:S => { S.mods.slowDmg += 0.25; } }) },
  { id:'stun', rarity:'rare', weight:S => 6 * elemTag(S,'ARC'), can:S => S.mods.stunChance < 0.40,
    make:S => ({ title:'OVERCHARGE', text:'Arc stun chance rises to 40%.',
                 apply:S => { S.mods.stunChance = 0.40; } }) },
  { id:'knock', rarity:'common', weight:S => 5 * elemTag(S,'STEAM'), can:S => true,
    make:S => ({ title:'PRESSURE VALVE', text:'Steam knockback +80%.',
                 apply:S => { S.mods.knockMult += 0.8; } }) },
  { id:'scald', rarity:'rare', weight:S => 5 * elemTag(S,'STEAM'), can:S => S.mods.scald < 1,
    make:S => ({ title:'SCALDING', text:'Steam also scalds for 8/s for 2s.',
                 apply:S => { S.mods.scald = 1; } }) },

  // ---- rebuilds -------------------------------------------------------------
  { id:'reelem', rarity:'rare', weight:S => 9, can:S => filledSlots(S).length > 0,
    make:S => { const i = pick(filledSlots(S));
      const cur = S.slots[i].element;
      const nxt = pick(ELEMENT_KEYS.filter(e => e !== cur));
      return { title:'RETUNE CORE', text:'Slot ' + (i+1) + ' becomes ' + ELEMENTS[nxt].name + ' ' +
                     SHAPES[S.slots[i].shape].noun + ' — ' + ELEMENTS[nxt].blurb + '.', slot:i,
               apply:S => { S.slots[i].element = nxt; } }; } },

  { id:'reshape', rarity:'epic', weight:S => 7, can:S => filledSlots(S).length > 0,
    make:S => { const i = pick(filledSlots(S));
      const cur = S.slots[i].shape;
      const nxt = pick(SHAPE_KEYS.filter(k => k !== cur));
      return { title:'REFIT', text:'Slot ' + (i+1) + ' becomes ' + ELEMENTS[S.slots[i].element].name + ' ' +
                     SHAPES[nxt].noun + ' — ' + SHAPES[nxt].desc + '.', slot:i,
               apply:S => { S.slots[i].shape = nxt; S.slots[i].mods = newSkill(nxt, S.slots[i].element).mods; } }; } },

  // Superseded by the slot-unlock skill draft, which fills empty slots directly.
  // Kept unreachable rather than deleted so the card ids stay stable.
  { id:'newskill', rarity:'epic', weight:S => 200,
    can:S => false && emptyUnlocked(S).length > 0,
    make:S => { const i = emptyUnlocked(S)[0];
      const sk = randomSkill();
      return { title:'SALVAGED GEAR', text:'Slot ' + (i+1) + ': ' + skillName(sk) + ' — ' +
                     SHAPES[sk.shape].desc + ', ' + ELEMENTS[sk.element].blurb + '.', slot:i,
               apply:S => { S.slots[i] = sk; } }; } },

  // ---- element-wide: the reward for building down a colour ------------------
  { id:'elemdmg', rarity:'rare', weight:S => 9 * (slotsWhere(S, sk => true).length > 1 ? 2 : 1),
    can:S => ELEMENT_KEYS.some(e => hasElement(S, e)),
    make:S => { const e = pick(ELEMENT_KEYS.filter(k => hasElement(S, k)));
      const n = slotsWhere(S, sk => sk.element === e).length;
      return { title: ELEMENTS[e].name.toUpperCase() + ' CONVERGENCE',
               text: '+30% damage on every ' + ELEMENTS[e].name + ' skill' +
                     (n > 1 ? ' — you run ' + n + '.' : '.'),
               apply:S => { S.mods.elemDmg[e] *= 1.30; } }; } },

  { id:'elemcd', rarity:'rare', weight:S => 7 * (slotsWhere(S, sk => true).length > 1 ? 2 : 1),
    can:S => ELEMENT_KEYS.some(e => hasElement(S, e)),
    make:S => { const e = pick(ELEMENT_KEYS.filter(k => hasElement(S, k)));
      return { title: ELEMENTS[e].name.toUpperCase() + ' CADENCE',
               text: '-20% cooldown on every ' + ELEMENTS[e].name + ' skill.',
               apply:S => { S.mods.elemCd[e] *= 0.80; } }; } },

  // ---- player ---------------------------------------------------------------
  { id:'hp', rarity:'common', weight:S => 10, can:S => true,
    make:S => ({ title:'REINFORCED RIBS', text:'+20 max health, and heal 20.',
                 apply:S => { S.player.maxHp += 20; S.player.hp += 20; } }) },
  { id:'spd', rarity:'common', weight:S => 9, can:S => S.mods.moveMult < 1.9,
    make:S => ({ title:'LIGHT BOOTS', text:'+12% movement speed.',
                 apply:S => { S.mods.moveMult *= 1.12; } }) },
  { id:'dashcd', rarity:'common', weight:S => 9, can:S => S.mods.dashCdBonus < 0.9,
    make:S => ({ title:'SPRING COILS', text:'Dash cooldown −0.4s.',
                 apply:S => { S.mods.dashCdBonus += 0.4; } }) },
  { id:'dashdmg', rarity:'rare', weight:S => 10, can:S => S.mods.dashDamage < 200,
    make:S => ({ title:'RAMMING GEAR', text:'Dash deals 60 damage to everything you pass through.',
                 apply:S => { S.mods.dashDamage += 60; } }) },
  { id:'dashchg', rarity:'epic', weight:S => 8, can:S => S.mods.dashCharges < 3,
    make:S => ({ title:'SECOND WIND', text:'+1 dash charge.',
                 apply:S => { S.mods.dashCharges += 1; S.player.dashStock += 1; } }) },
  { id:'crit', rarity:'common', weight:S => 10, can:S => S.mods.critChance < 0.75,
    make:S => ({ title:'KEEN EYE', text:'+8% critical hit chance.',
                 apply:S => { S.mods.critChance += 0.08; } }) },
  { id:'critx', rarity:'rare', weight:S => 9, can:S => S.mods.critExplode < 1,
    make:S => ({ title:'OVERKILL', text:'Crits detonate for 20 damage around the target.',
                 apply:S => { S.mods.critExplode = 1; } }) },
  { id:'scrap', rarity:'common', weight:S => 9, can:S => S.mods.scrapChance < 0.5,
    make:S => ({ title:"SCRAPPER'S LUCK", text:'Kills have a 15% chance to drop 15 health.',
                 apply:S => { S.mods.scrapChance += 0.15; } }) },
  { id:'lifesteal', rarity:'rare', weight:S => 8, can:S => S.mods.lifesteal < 0.09,
    make:S => ({ title:'BLOODSTEAM', text:'Heal for 3% of the damage you deal.',
                 apply:S => { S.mods.lifesteal += 0.03; } }) },

  // ---- the Boiler -----------------------------------------------------------
  { id:'boilerhp', rarity:'common', weight:S => S.boiler.hp < S.boiler.maxHp * 0.8 ? 22 : 9, can:S => true,
    make:S => ({ title:'SPARE TANK', text:'Boiler gains 150 max HP and repairs 150.',
                 apply:S => { S.boiler.maxHp += 150; S.boiler.hp = Math.min(S.boiler.maxHp, S.boiler.hp + 150); } }) },
  { id:'boilerdr', rarity:'rare', weight:S => 10, can:S => S.mods.boilerDR < 0.5,
    make:S => ({ title:'BOILER PLATING', text:'The Boiler takes 25% less damage.',
                 apply:S => { S.mods.boilerDR += 0.25; } }) },

  // ---- spicy ----------------------------------------------------------------
  { id:'fifth', rarity:'epic', weight:S => 8, can:S => !S.mods.fifthGear,
    make:S => ({ title:'FIFTH GEAR', text:'Every 5th cast of a skill is free and deals double.',
                 apply:S => { S.mods.fifthGear = true; } }) },
  { id:'residue', rarity:'epic', weight:S => 8, can:S => S.mods.residue < 2,
    make:S => ({ title:'RESIDUE', text:'Skills leave a burning field for 2s where they land.',
                 apply:S => { S.mods.residue += 1; } }) },
  { id:'autofire', rarity:'epic', weight:S => 8, can:S => S.mods.killAutoFire < 0.4,
    make:S => ({ title:'DEAD MAN’S TRIGGER', text:'On kill, 10% chance to fire slot 1 at a random enemy.',
                 apply:S => { S.mods.killAutoFire += 0.10; } }) },
  { id:'killboom', rarity:'rare', weight:S => 9, can:S => S.mods.killExplode < 60,
    make:S => ({ title:'DETONATOR', text:'Kills burst for 18 damage nearby.',
                 apply:S => { S.mods.killExplode += 18; } }) },
];

/* ---------------------------------------------------------------------------
   4. STATE
--------------------------------------------------------------------------- */
const S = {
  mode: 'title',            // title | play | draft | pause | gameover | victory
  t: 0, dtScale: 1, slowmo: 0, hitStop: 0,
  trauma: 0, shakeX: 0, shakeY: 0, shakeR: 0,
  flashWhite: 0, flashRed: 0,
  player: null, boiler: null,
  enemies: [], bolts: [], fx: [], nums: [], pickups: [], fields: [],
  crew: [], turrets: [], hulk: null, crewT: 0,
  slots: [null, null, null, null],
  unlockedSlots: 2,
  mods: null,
  wave: 0, waveActive: false, waveT: 0, queue: [], loopT: 0, spawned: 0, remaining: 0,
  interT: 0, banner: null,
  draft: null,
  stats: null,
  hintT: 0,
  intro: 0,
  bossRef: null,
  seenTypes: null,
};

function freshMods(){
  return {
    // Per-element multipliers. The game is a shape x element matrix, so the
    // interesting way to specialise is down a colour across several shapes —
    // Frost Mortar and Frost Lance as one build — rather than pouring every
    // upgrade into a single ability because that is where they all land.
    elemDmg: { EMBER: 1, FROST: 1, ARC: 1, STEAM: 1 },
    elemCd:  { EMBER: 1, FROST: 1, ARC: 1, STEAM: 1 },
    burnDmg: 1, burnDur: 0,
    slowAmt: 0.40, slowDmg: 0,
    stunChance: 0.20,
    knockMult: 1, scald: 0,
    critChance: TUNING.player.critChance, critExplode: 0,
    moveMult: 1,
    dashCdBonus: 0, dashCharges: TUNING.player.dashCharges, dashDamage: 0,
    scrapChance: 0, lifesteal: 0,
    fifthGear: false, residue: 0, killAutoFire: 0, killExplode: 0,
    boilerDR: 0,
  };
}

function resetGame(){
  S.t = 0; S.dtScale = 1; S.slowmo = 0; S.hitStop = 0;
  S.trauma = 0; S.shakeX = S.shakeY = S.shakeR = 0; S.stopUntil = 0;
  S.flashWhite = 0; S.flashRed = 0;
  S.enemies.length = 0; S.bolts.length = 0; S.fx.length = 0;
  S.crew.length = 0; S.crewT = 2.5;
  S.nums.length = 0; S.pickups.length = 0; S.fields.length = 0;
  Particles.reset();

  S.mods = freshMods();
  S.player = {
    x: TUNING.deck.cx, y: TUNING.deck.cy + TUNING.deck.h * (PRESET.lanes ? 0.29 : 0.20),
    vx: 0, vy: 0, aim: -Math.PI/2,
    hp: TUNING.player.hp, maxHp: TUNING.player.hp,
    dashT: 0, dashAng: 0, dashCd: 0, dashStock: TUNING.player.dashCharges,
    iframe: 0, hurt: 0, walk: 0, hitList: null, trail: [],
    stepT: 0, coatSway: 0, castFlash: 0, ray: null,
    facing: -Math.PI/2, atkCd: 0, atkTarget: null, atkSwing: 0, dashBuf: 0,
  };
  S.boiler = { x: TUNING.boiler.x, y: TUNING.boiler.y, r: TUNING.boiler.r,
               hp: TUNING.boiler.hp, maxHp: TUNING.boiler.hp, flash: 0, shake: 0, gauge: 0 };

  S.slots = [null, null, null, null];
  const LD = FEEL.loadout || [['CLOSEHIT', 'EMBER'], ['RANGED_AOE', 'FROST']];
  for (let i = 0; i < Math.min(4, LD.length); i++) S.slots[i] = newSkill(LD[i][0], LD[i][1]);
  S.unlockedSlots = Math.max(2, LD.length);   // a free slot to draft into from wave 1
  // v6: the basic attack is a real skill — the same Ember Cleave, with the same
  // shape code, element and crit — rather than a generic sabre flick bolted on
  // beside it. It swings itself; the four slots stay for drafted abilities.
  S.basic = FEEL.basic ? newSkill(FEEL.basic[0], FEEL.basic[1]) : null;

  S.wave = 0; S.waveActive = false; S.waveT = 0; S.queue = []; S.loopT = 0;
  S.spawned = 0; S.remaining = 0; S.interT = 0; S.banner = null;
  S.draft = null; S.bossRef = null;
  S.hintT = 9; S.intro = 1;
  S.seenTypes = {};
  initLanes();
  spawnTurrets();
  spawnHulk();
  S.stats = { kills: 0, damage: 0, combo: 0, comboT: 0, bestCombo: 0, waves: 0, dashes: 0, cards: [] };
}

/* ---------------------------------------------------------------------------
   ENGINE — particles. Fixed pool, ring-allocated, hard cap.
--------------------------------------------------------------------------- */
const Particles = {
  pool: [], head: 0, max: TUNING.feel.maxParticles,
  init(){
    for (let i = 0; i < this.max; i++)
      this.pool.push({ live:false, x:0,y:0,vx:0,vy:0,life:0,max:1,size:2,col:'#fff',
                       kind:'spark', grav:0, drag:0.9, rot:0, vr:0, add:false, w:1 });
  },
  reset(){ for (const p of this.pool) p.live = false; this.head = 0; },
  spawn(o){
    const p = this.pool[this.head];
    this.head = (this.head + 1) % this.max;
    p.live = true;
    p.x = o.x; p.y = o.y;
    p.vx = o.vx || 0; p.vy = o.vy || 0;
    p.max = p.life = o.life || 0.4;
    p.size = o.size || 3;
    p.col = o.col || '#fff';
    p.kind = o.kind || 'spark';
    p.grav = o.grav || 0;
    p.drag = o.drag === undefined ? 0.86 : o.drag;
    p.rot = o.rot || 0; p.vr = o.vr || 0;
    p.add = !!o.add; p.w = o.w || 1;
    return p;
  },
  step(dt){
    for (const p of this.pool){
      if (!p.live) continue;
      p.life -= dt;
      if (p.life <= 0){ p.live = false; continue; }
      p.vy += p.grav * dt;
      const d = Math.pow(p.drag, dt * 60);
      p.vx *= d; p.vy *= d;
      p.x += p.vx * dt; p.y += p.vy * dt;
      p.rot += p.vr * dt;
    }
  },
};
Particles.init();

// --- shorthand emitters -----------------------------------------------------
function pSparks(x, y, n, col, spd, ang, spread){
  for (let i = 0; i < n; i++){
    const a = ang === undefined ? rnd(TAU) : ang + rnd(-(spread||TAU/2), (spread||TAU/2));
    const v = rnd(spd*0.35, spd);
    Particles.spawn({ x, y, vx: Math.cos(a)*v, vy: Math.sin(a)*v, life: rnd(0.16,0.42),
                      size: rnd(1.6,3.4), col, kind:'spark', drag:0.82, add:true, w: rnd(4,11) });
  }
}
function pGibs(x, y, n, col, col2){
  for (let i = 0; i < n; i++){
    const a = rnd(TAU), v = rnd(70, 320);
    Particles.spawn({ x, y, vx: Math.cos(a)*v, vy: Math.sin(a)*v - rnd(20,90), life: rnd(0.45,0.95),
                      size: rnd(3,7.5), col: chance(0.5)?col:col2, kind:'shard',
                      grav: 620, drag: 0.965, rot: rnd(TAU), vr: rnd(-11,11) });
  }
}
function pSmoke(x, y, n, col, spd){
  for (let i = 0; i < n; i++){
    const a = rnd(TAU), v = rnd(6, spd||45);
    Particles.spawn({ x, y: y - rnd(0,6), vx: Math.cos(a)*v, vy: Math.sin(a)*v - rnd(8,30),
                      life: rnd(0.5,1.1), size: rnd(7,17), col: col||'rgba(190,180,170,0.5)',
                      kind:'smoke', drag: 0.94 });
  }
}
function pDust(x, y, n){
  for (let i = 0; i < n; i++){
    const a = rnd(TAU), v = rnd(8, 46);
    Particles.spawn({ x, y, vx: Math.cos(a)*v, vy: Math.sin(a)*v*0.5, life: rnd(0.22,0.5),
                      size: rnd(2.5,6), col:'rgba(196,186,152,0.55)', kind:'smoke', drag:0.9 });
  }
}
function pGold(x, y, n){
  for (let i = 0; i < n; i++){
    const a = rnd(TAU), v = rnd(60, 300);
    Particles.spawn({ x, y, vx: Math.cos(a)*v, vy: Math.sin(a)*v - rnd(40,150), life: rnd(0.7,1.5),
                      size: rnd(2.5,5.5), col: chance(0.4)? PAL.bone : PAL.brass, kind:'glow',
                      grav: 240, drag: 0.97, add:true });
  }
}

/* ---------------------------------------------------------------------------
   ENGINE — spatial hash. Rebuilt every sim step; enemy counts stay under ~200.
--------------------------------------------------------------------------- */
const Hash = {
  cell: 96, map: new Map(),
  key(cx, cy){ return cx * 4093 + cy; },
  build(list){
    this.map.clear();
    for (let i = 0; i < list.length; i++){
      const e = list[i];
      const cx = Math.floor(e.x / this.cell), cy = Math.floor(e.y / this.cell);
      const k = this.key(cx, cy);
      let b = this.map.get(k);
      if (!b){ b = []; this.map.set(k, b); }
      b.push(e);
    }
  },
  query(x, y, r, out){
    out.length = 0;
    const c = this.cell;
    const x0 = Math.floor((x-r)/c), x1 = Math.floor((x+r)/c);
    const y0 = Math.floor((y-r)/c), y1 = Math.floor((y+r)/c);
    for (let cx = x0; cx <= x1; cx++) for (let cy = y0; cy <= y1; cy++){
      const b = this.map.get(this.key(cx, cy));
      if (b) for (let i = 0; i < b.length; i++) out.push(b[i]);
    }
    return out;
  },
};
const _q = [];

/* ---------------------------------------------------------------------------
   5. SYSTEMS — feel helpers
--------------------------------------------------------------------------- */
function addTrauma(v){ S.trauma = Math.min(1, S.trauma + v); }
function hitStop(v){
  if (v <= 0) return;
  // A big hit always lands; small ones respect a refractory window so that
  // clearing a horde does not leave the sim frozen a large part of the time.
  if (v < 0.06 && FEEL.stopRefractory > 0 && S.t < S.stopUntil) return;
  S.hitStop = Math.max(S.hitStop, v);
  S.stopUntil = S.t + FEEL.stopRefractory;
}

const MAX_NUMBERS = 64;
function dmgNumber(x, y, text, col, size, crit){
  // Hard cap. A 95° cone into forty boarders would otherwise queue forty
  // strokeText calls a frame, and readability dies long before the frame does.
  if (S.nums.length >= MAX_NUMBERS){
    if (!crit) return;
    S.nums.shift();
  }
  S.nums.push({ x: x + rnd(-8,8), y: y - 10, vx: rnd(-26,26), vy: rnd(-92,-64),
                t: 0, life: TUNING.feel.dmgNumberLife * (crit ? 1.25 : 1),
                text, col: col || PAL.bone, size: size || 17, crit: !!crit });
}
function fx(o){ o.t = 0; S.fx.push(o); return o; }

/* ---------------------------------------------------------------------------
   SYSTEMS — resolved skill stats. Base table × per-slot mods × global mods.
--------------------------------------------------------------------------- */
function skillStats(sk){
  const b = SHAPES[sk.shape], m = sk.mods;
  const eD = (S.mods.elemDmg && S.mods.elemDmg[sk.element]) || 1;
  const eC = (S.mods.elemCd && S.mods.elemCd[sk.element]) || 1;
  const st = { kind: b.kind, shape: sk.shape, element: sk.element,
               dmg: b.dmg * m.dmg * eD, cd: b.cd * m.cd * eC * FEEL.cdScale,
               knock: (b.knock||0) * m.knock * S.mods.knockMult,
               multi: m.multi };
  switch (b.kind){
    case 'arc':
      st.range = b.range * m.range;
      st.arc   = Math.min(TAU*0.92, b.arc * (1 + (m.aoe-1) * 0.55));
      break;
    case 'line':
      st.len = b.len * m.range; st.width = b.width * m.aoe;
      st.pierce = b.pierce + m.pierce;
      break;
    case 'cone':
      st.range = b.range * m.range;
      st.arc   = Math.min(TAU*0.9, (m.wideCone ? 95*DEG : b.arc) * (1 + (m.aoe-1) * 0.55));
      break;
    case 'aoe':
      st.radius = b.radius * m.aoe; st.castRange = b.castRange * m.range;
      break;
    case 'chain':
      st.jumps = b.jumps + m.jumps + (sk.element === 'ARC' ? 1 : 0);
      st.jumpRange = b.jumpRange * m.range; st.seekRange = b.seekRange * m.range;
      st.falloff = b.falloff;
      break;
    case 'ray':
      st.len = b.len * m.range; st.width = b.width * m.aoe;
      st.tickRate = b.tickRate; st.maxDur = b.maxDur;
      break;
  }
  return st;
}
function effCd(sk){ return skillStats(sk).cd; }

/* ---------------------------------------------------------------------------
   SYSTEMS — status effects and damage
--------------------------------------------------------------------------- */
function applyElement(e, elem, ang, knock){
  const M = S.mods;
  switch (elem){
    case 'EMBER':
      e.burnStacks = Math.min(3, e.burnStacks + 1);
      e.burnT = 3 + M.burnDur;
      break;
    case 'FROST':
      e.slowT = 2; e.slowAmt = Math.max(e.slowAmt, M.slowAmt);
      pSparks(e.x, e.y, 3, ELEMENTS.FROST.glow, 90);
      break;
    case 'ARC':
      if (chance(M.stunChance)){
        e.stunT = Math.max(e.stunT, 0.6);
        fx({ kind:'stun', x:e.x, y:e.y, life:0.6, ref:e });
      }
      break;
    case 'STEAM': {
      const k = 120 * M.knockMult;
      e.kx += Math.cos(ang) * k / e.def.mass;
      e.ky += Math.sin(ang) * k / e.def.mass;
      e.accT = 2;
      if (M.scald){ e.scaldT = 2; }
      pSmoke(e.x, e.y, 4, 'rgba(220,210,235,0.55)', 70);
      break;
    }
  }
  if (knock){
    e.kx += Math.cos(ang) * knock / e.def.mass;
    e.ky += Math.sin(ang) * knock / e.def.mass;
  }
}

// The single funnel for all damage dealt to enemies.
function hitEnemy(e, dmg, o){
  if (!e || e.dead || e.state === 'climb') return 0;
  o = o || {};
  const M = S.mods;
  const ang = (o.ang !== undefined) ? o.ang : Math.atan2(e.y - S.player.y, e.x - S.player.x);

  // ARMORED soaks damage from the front only — flank it.
  if (e.def.frontDR){
    const toSrc = angNorm(ang + Math.PI);
    if (Math.abs(angDiff(e.facing, toSrc)) < e.def.frontArc/2){
      dmg *= (1 - e.def.frontDR);
      e.blockFlash = 0.18;
    }
  }
  if (e.slowT > 0) dmg *= (1 + M.slowDmg);

  let crit = false;
  if (!o.noCrit && chance(M.critChance)){ crit = true; dmg *= TUNING.player.critMult; }
  dmg = Math.max(1, dmg);

  e.hp -= dmg;
  e.flash = TUNING.feel.flashTime;
  S.stats.damage += dmg;

  if (M.lifesteal > 0 && S.player.hp > 0)
    S.player.hp = Math.min(S.player.maxHp, S.player.hp + dmg * M.lifesteal);

  const col = o.element ? ELEMENTS[o.element].glow : PAL.bone;
  if (!o.silent){
    dmgNumber(e.x, e.y - e.r, Math.round(dmg), crit ? '#FFD36B' : col, crit ? 36 : 22, crit);
    pSparks(e.x, e.y, crit ? 9 : 4, col, crit ? 340 : 190, ang, 1.0);
  }

  // knockback scales with the size of the hit — a ray tick nudges, a mortar throws
  const kn = (o.knock || 0) * (0.55 + dmg / 45);
  if (o.element) applyElement(e, o.element, ang, kn);
  else if (kn){
    e.kx += Math.cos(ang) * kn / e.def.mass;
    e.ky += Math.sin(ang) * kn / e.def.mass;
  }

  if (crit){
    SFX.crit();
    addTrauma(0.10);
    if (M.critExplode){
      fx({ kind:'aoe', x:e.x, y:e.y, r:70, life:0.30, col:'#FFD36B' });
      damageArea(e.x, e.y, 70, 20, null, { noCrit:true, silent:true, skip:e, knock:60 });
    }
  }

  if (dmg >= TUNING.feel.hitStopThreshold) hitStop(TUNING.feel.hitStopBig);
  addTrauma(TUNING.feel.traumaHit * Math.min(1.6, dmg / 30));
  if (!o.silent) SFX.hit();

  if (e.hp <= 0) killEnemy(e, ang);
  return dmg;
}

function damageArea(x, y, r, dmg, element, o){
  o = o || {};
  if (PRESET.lanes && S.hulk && !S.hulk.dead &&
      dist2(x, y, S.hulk.x, S.hulk.y) < (r + S.hulk.r) * (r + S.hulk.r))
    damageHulk(dmg);
  Hash.query(x, y, r + 40, _q);
  let n = 0;
  for (const e of _q){
    if (e === o.skip || e.dead || e.state === 'climb') continue;
    if (dist2(x, y, e.x, e.y) > (r + e.r) * (r + e.r)) continue;
    const ang = Math.atan2(e.y - y, e.x - x) || 0;
    // past a dozen targets the numbers are noise anyway — keep the hits, drop the chatter
    hitEnemy(e, dmg, { element, ang, knock: o.knock || 0, noCrit: o.noCrit,
                       silent: o.silent || n >= 12 });
    n++;
  }
  return n;
}

function killEnemy(e, ang){
  if (e.dead) return;
  e.dead = true;
  const M = S.mods;
  S.stats.kills++;
  S.stats.combo++; S.stats.comboT = 2.6;
  if (S.stats.combo > S.stats.bestCombo) S.stats.bestCombo = S.stats.combo;

  hitStop(FEEL.killStop ? (FEEL.killStop[e.type] || 0) : TUNING.feel.hitStopKill);
  addTrauma(TUNING.feel.traumaKill * (e.type === 'BOSS' ? 3 : 1));
  SFX.death();

  pGibs(e.x, e.y, e.type === 'BOSS' ? 40 : (8 + Math.floor(e.r/3)), PAL.brass, PAL.grey);
  pSmoke(e.x, e.y, e.type === 'BOSS' ? 24 : 5, 'rgba(120,110,100,0.55)', 80);
  pSparks(e.x, e.y, 8, PAL.brass, 260);
  fx({ kind:'pop', x:e.x, y:e.y, r:e.r*1.4, life:0.26, col: PAL.brass });

  if (M.killExplode > 0){
    fx({ kind:'aoe', x:e.x, y:e.y, r:80, life:0.32, col:'#E2691E' });
    damageArea(e.x, e.y, 80, M.killExplode, 'EMBER', { skip:e, noCrit:true, knock:70 });
  }
  if (M.scrapChance > 0 && chance(M.scrapChance)){
    S.pickups.push({ x:e.x, y:e.y, vx:rnd(-60,60), vy:rnd(-90,-30), t:0, life:14, heal:15, bob:rnd(TAU) });
  }
  if (M.killAutoFire > 0 && chance(M.killAutoFire) && S.slots[0]){
    const tgt = randomLiveEnemy(e);
    if (tgt) castSlot(0, { free:true, atX:tgt.x, atY:tgt.y, from:{x:e.x,y:e.y} });
  }
  if (e.type === 'BOSS'){
    S.bossRef = null;
    S.flashWhite = 0.9;
    for (let i = 0; i < 7; i++)
      fx({ kind:'delayPop', x: e.x + rnd(-80,80), y: e.y + rnd(-80,80),
           life: 0.5, delay: i * 0.13, r: rnd(40,90), col: i%2 ? PAL.brass : '#FFD36B' });
  }
}
function randomLiveEnemy(skip){
  const live = S.enemies.filter(e => !e.dead && e !== skip && e.state !== 'climb');
  return live.length ? pick(live) : null;
}

/* ---------------------------------------------------------------------------
   SYSTEMS — casting. Six shapes × four elements, resolved through one path.
--------------------------------------------------------------------------- */
function castSlot(idx, opt){
  opt = opt || {};
  const sk = (typeof idx === 'number') ? S.slots[idx] : idx;
  if (!sk) return false;
  const st = skillStats(sk);
  if (st.kind === 'ray' && typeof idx === 'number') return startRay(idx, sk, st);
  if (!opt.free && sk.cdLeft > 0) return false;

  const P = opt.from || S.player;
  const E = ELEMENTS[sk.element];

  sk.casts++;
  let dmgMult = 1, free = !!opt.free;
  if (S.mods.fifthGear && sk.casts % 5 === 0){
    dmgMult *= 2; free = true;
    fx({ kind:'gear', x:P.x, y:P.y, life:0.55 });
  }
  if (!free) sk.cdLeft = st.cd;

  let aim = (opt.atX !== undefined) ? Math.atan2(opt.atY - P.y, opt.atX - P.x) : S.player.aim;

  if (!opt.from){ S.player.castFlash = 0.12; S.player.lastElem = sk.element; }
  SFX.fire[sk.element]();

  const mx = P.x + Math.cos(aim) * 20, my = P.y + Math.sin(aim) * 20 - 4;
  pSparks(mx, my, 6, E.glow, 240, aim, 0.5);
  fx({ kind:'muzzle', x:mx, y:my, a:aim, life:0.15, col:E.color, glow:E.glow });

  const shots = st.multi;
  const spread = 8 * DEG;
  const per = dmgMult * (shots > 1 ? 0.7 : 1);
  let land = null;

  for (let s = 0; s < shots; s++){
    const a = shots > 1 ? aim + lerp(-spread, spread, s/(shots-1)) : aim;
    switch (st.kind){
      case 'arc':  land = shapeArc(P, a, st, sk, per); break;
      case 'line': land = shapeLine(P, a, st, sk, per); break;
      case 'cone': land = shapeCone(P, a, st, sk, per); break;
      case 'aoe': {
        let tx, ty;
        if (opt.atX !== undefined){ tx = opt.atX; ty = opt.atY; }
        else { tx = Input.mouse.x; ty = Input.mouse.y; }
        if (shots > 1){ const pa = a + Math.PI/2; tx += Math.cos(pa)*(s?46:-46); ty += Math.sin(pa)*(s?46:-46); }
        land = shapeAoe(P, tx, ty, st, sk, per);
        break;
      }
      case 'chain': land = shapeChain(P, a, st, sk, per) || land; break;
    }
  }

  // recoil — small, but it sells the weight of the big shapes
  if (!opt.from && (st.kind === 'line' || st.kind === 'cone')){
    S.player.vx -= Math.cos(aim) * 90 * FEEL.recoilScale;
    S.player.vy -= Math.sin(aim) * 90 * FEEL.recoilScale;
  }
  if (st.kind === 'aoe' || st.kind === 'line') addTrauma(0.10);

  if (S.mods.residue > 0 && land) spawnField(land.x, land.y, sk.element);
  // Every shape must be able to bite the hulk. AoE already routes through
  // damageArea for each shot, so applying the universal splash as well would
  // double its hulk damage.
  if (st.kind !== 'aoe')
    hulkSplash(land, st.dmg * dmgMult * (shots > 1 ? shots * 0.7 : 1));
  return true;
}

// a shape that lands on or near the hulk hurts it
function hulkSplash(land, dmg){
  if (!PRESET.lanes || !land) return;
  const H = S.hulk;
  if (!H || H.dead || !H.vulnerable) return;
  if (dist(land.x, land.y, H.x, H.y) < H.r + 150) damageHulk(dmg);
}

function spawnField(x, y, elem){
  const c = clampToDeck(x, y, 8);
  S.fields.push({ x:c.x, y:c.y, r: 62 + 22 * S.mods.residue, life: 2, t: 0,
                  elem, dps: 13 * S.mods.residue, tick: 0, seed: rnd(TAU) });
}

// --- CLOSEHIT ---------------------------------------------------------------
function shapeArc(P, aim, st, sk, mult){
  const half = st.arc / 2;
  let n = 0;
  Hash.query(P.x, P.y, st.range + 50, _q);
  for (const e of _q){
    if (e.dead || e.state === 'climb') continue;
    const d = dist(P.x, P.y, e.x, e.y);
    if (d > st.range + e.r) continue;
    const a = Math.atan2(e.y - P.y, e.x - P.x);
    const slack = Math.atan2(e.r, Math.max(24, d));
    if (Math.abs(angDiff(aim, a)) > half + slack) continue;
    hitEnemy(e, st.dmg * mult, { element: sk.element, ang: a, knock: st.knock, silent: n >= 12 });
    n++;
  }
  const E = ELEMENTS[sk.element];
  fx({ kind:'arc', x:P.x, y:P.y, a:aim, arc:st.arc, r:st.range, life:0.28, col:E.color, glow:E.glow, follow:true });
  return { x: P.x + Math.cos(aim)*st.range*0.62, y: P.y + Math.sin(aim)*st.range*0.62 };
}

// --- LINE_BURST -------------------------------------------------------------
function shapeLine(P, aim, st, sk, mult){
  const dx = Math.cos(aim), dy = Math.sin(aim);
  const cand = [];
  Hash.query(P.x + dx*st.len/2, P.y + dy*st.len/2, st.len/2 + 70, _q);
  for (const e of _q){
    if (e.dead || e.state === 'climb') continue;
    const rx = e.x - P.x, ry = e.y - P.y;
    const t = rx*dx + ry*dy;
    if (t < -e.r || t > st.len + e.r) continue;
    if (Math.abs(-rx*dy + ry*dx) > st.width/2 + e.r) continue;
    cand.push({ e, t });
  }
  cand.sort((a,b) => a.t - b.t);
  const n = Math.min(cand.length, st.pierce);
  for (let i = 0; i < n; i++)
    hitEnemy(cand[i].e, st.dmg * mult, { element: sk.element, ang: aim, knock: st.knock });
  const E = ELEMENTS[sk.element];
  fx({ kind:'line', x:P.x, y:P.y, a:aim, len:st.len, w:st.width, life:0.26, col:E.color, glow:E.glow });
  return { x: P.x + dx*st.len*0.5, y: P.y + dy*st.len*0.5 };
}

// --- CONE -------------------------------------------------------------------
function shapeCone(P, aim, st, sk, mult){
  const half = st.arc / 2;
  let n = 0;
  Hash.query(P.x, P.y, st.range + 60, _q);
  for (const e of _q){
    if (e.dead || e.state === 'climb') continue;
    const d = dist(P.x, P.y, e.x, e.y);
    if (d > st.range + e.r) continue;
    const a = Math.atan2(e.y - P.y, e.x - P.x);
    const slack = Math.atan2(e.r, Math.max(30, d));
    if (Math.abs(angDiff(aim, a)) > half + slack) continue;
    hitEnemy(e, st.dmg * mult, { element: sk.element, ang: a, knock: st.knock, silent: n >= 12 });
    n++;
  }
  const E = ELEMENTS[sk.element];
  fx({ kind:'cone', x:P.x, y:P.y, a:aim, arc:st.arc, r:st.range, life:0.34, col:E.color, glow:E.glow });
  return { x: P.x + Math.cos(aim)*st.range*0.55, y: P.y + Math.sin(aim)*st.range*0.55 };
}

// --- RANGED_AOE -------------------------------------------------------------
function shapeAoe(P, tx, ty, st, sk, mult){
  const d = dist(P.x, P.y, tx, ty);
  if (d > st.castRange){
    tx = P.x + (tx - P.x) / d * st.castRange;
    ty = P.y + (ty - P.y) / d * st.castRange;
  }
  const c = clampToDeck(tx, ty, 6);
  const E = ELEMENTS[sk.element];
  damageArea(c.x, c.y, st.radius, st.dmg * mult, sk.element, { knock: st.knock });
  fx({ kind:'aoe', x:c.x, y:c.y, r:st.radius, life:0.45, col:E.color, glow:E.glow });
  pSparks(c.x, c.y, 14, E.glow, 300);
  addTrauma(0.08);
  return c;
}

// --- CHAIN ------------------------------------------------------------------
function shapeChain(P, aim, st, sk, mult){
  const E = ELEMENTS[sk.element];
  let cur = null, best = Infinity;
  Hash.query(P.x, P.y, st.seekRange, _q);
  for (const e of _q){
    if (e.dead || e.state === 'climb') continue;
    const d = dist(P.x, P.y, e.x, e.y);
    if (d > st.seekRange) continue;
    const a = Math.atan2(e.y - P.y, e.x - P.x);
    const score = d + Math.abs(angDiff(aim, a)) * 250;   // bias toward where you're pointing
    if (score < best){ best = score; cur = e; }
  }
  if (!cur){
    // nothing to arc between — but a vulnerable hulk is a perfectly good ground
    const H = S.hulk;
    if (PRESET.lanes && H && !H.dead && H.vulnerable &&
        dist(P.x, P.y, H.x, H.y) < st.seekRange + H.r){
      fx({ kind:'chain', pts: [{x:P.x, y:P.y}, {x:H.x, y:H.y}], life:0.36,
           col:E.color, glow:E.glow });
      return { x: H.x, y: H.y };
    }
    fx({ kind:'fizzle', x: P.x + Math.cos(aim)*40, y: P.y + Math.sin(aim)*40, life:0.28, col:E.color });
    return null;
  }
  const pts = [{ x:P.x, y:P.y }];
  const seen = [];
  let cx = P.x, cy = P.y, dmg = st.dmg * mult;
  const total = 1 + st.jumps;
  for (let j = 0; j < total && cur; j++){
    pts.push({ x: cur.x, y: cur.y });
    seen.push(cur);
    hitEnemy(cur, dmg, { element: sk.element, ang: Math.atan2(cur.y - cy, cur.x - cx), knock: st.knock });
    dmg *= (1 - st.falloff);
    cx = cur.x; cy = cur.y;
    let nxt = null, nb = Infinity;
    Hash.query(cx, cy, st.jumpRange, _q);
    for (const e of _q){
      if (e.dead || e.state === 'climb' || seen.indexOf(e) >= 0) continue;
      const d = dist(cx, cy, e.x, e.y);
      if (d <= st.jumpRange && d < nb){ nb = d; nxt = e; }
    }
    cur = nxt;
  }
  fx({ kind:'chain', pts, life:0.36, col:E.color, glow:E.glow });
  return pts[pts.length - 1];
}

// --- RAY --------------------------------------------------------------------
function startRay(idx, sk, st){
  if (S.player.ray || sk.cdLeft > 0) return false;
  sk.casts++;
  let dmgMult = 1, free = false;
  if (S.mods.fifthGear && sk.casts % 5 === 0){ dmgMult = 2; free = true; }
  S.player.ray = { slot: idx, t: 0, tick: 0, dmgMult, free, len: 0 };
  S.player.lastElem = sk.element;
  S.player.castFlash = 0.12;
  SFX.fire[sk.element]();
  return true;
}
function endRay(){
  const R = S.player.ray;
  if (!R) return;
  const sk = S.slots[R.slot];
  if (sk && !R.free) sk.cdLeft = skillStats(sk).cd;
  S.player.ray = null;
}
function updateRay(dt){
  const R = S.player.ray;
  if (!R) return;
  const sk = S.slots[R.slot];
  if (!sk || S.mode !== 'play'){ endRay(); return; }
  const st = skillStats(sk);
  R.t += dt;
  if (!slotHeld(R.slot) || R.t >= st.maxDur){ endRay(); return; }

  const P = S.player, aim = P.aim, E = ELEMENTS[sk.element];
  R.len = lerp(R.len, st.len, 1 - Math.pow(0.0001, dt));   // beam extends fast on start
  const dx = Math.cos(aim), dy = Math.sin(aim);
  const ex = P.x + dx * R.len, ey = P.y + dy * R.len;

  if (rnd() < dt * 40) pSparks(ex, ey, 1, E.glow, 160, aim + Math.PI, 1.2);

  R.tick -= dt;
  if (R.tick <= 0){
    R.tick += 1 / st.tickRate;
    Hash.query(P.x + dx*st.len/2, P.y + dy*st.len/2, st.len/2 + 70, _q);
    for (const e of _q){
      if (e.dead || e.state === 'climb') continue;
      const rx = e.x - P.x, ry = e.y - P.y;
      const t = rx*dx + ry*dy;
      if (t < -e.r || t > R.len + e.r) continue;
      if (Math.abs(-rx*dy + ry*dx) > st.width/2 + e.r) continue;
      hitEnemy(e, st.dmg * R.dmgMult, { element: sk.element, ang: aim, knock: st.knock, silent: rnd() > 0.5 });
    }
    if (S.mods.residue > 0 && rnd() < 0.25) spawnField(ex, ey, sk.element);
    hulkSplash({ x: ex, y: ey }, st.dmg * R.dmgMult);
  }
}

/* ---------------------------------------------------------------------------
   SYSTEMS — player
--------------------------------------------------------------------------- */
/* Bindings are per build. v2/v3 keep the original hand; the auto-attack builds
   free up the left button, so the mouse carries two abilities and dash moves to
   space where an action-game player expects it. */
const KEYS = FEEL.keys || {
  slots: [{ label:'LMB', mouse:0, alt:'1' }, { label:'RMB', mouse:2, alt:'2' },
          { label:'SPACE', key:'space', alt:'3' }, { label:'SHIFT', key:'shift', alt:'4' }],
  dash: { label:'E', key:'e' },
};
function slotHeld(i){
  const k = KEYS.slots[i];
  if (!k) return false;
  if (k.mouse !== undefined && Input.buttons[k.mouse]) return true;
  if (k.key && keyDown(k.key)) return true;
  if (k.alt && keyDown(k.alt)) return true;
  return false;
}
function dashCdMax(){ return Math.max(0.30, (FEEL.dashCd || TUNING.player.dashCd) - S.mods.dashCdBonus); }

function hurtPlayer(dmg, ang){
  const P = S.player;
  if (P.iframe > 0 || P.dashT > 0 || P.hp <= 0) return;
  P.hp -= dmg;
  P.iframe = TUNING.player.invulnAfterHit;
  P.hurt = 0.32;
  P.vx += Math.cos(ang) * 200; P.vy += Math.sin(ang) * 200;
  addTrauma(TUNING.feel.traumaPlayer);
  hitStop(0.05);
  S.flashRed = 0.5;
  S.stats.combo = 0;
  SFX.hurt();
  pSparks(P.x, P.y, 12, PAL.oxblood, 300);
  dmgNumber(P.x, P.y - 26, '-' + Math.round(dmg), '#FF6B6B', 22);
  if (P.hp <= 0){ P.hp = 0; endGame(false, 'Cut down on your own deck.', 'CAPTAIN DOWN'); }
}

function hurtBoiler(dmg, ang){
  const B = S.boiler;
  if (B.hp <= 0) return;
  dmg *= (1 - S.mods.boilerDR);
  B.hp -= dmg;
  B.flash = 0.14; B.shake = 0.3;
  addTrauma(0.18);
  S.flashRed = Math.max(S.flashRed, 0.22);
  SFX.boiler();
  pSparks(B.x + Math.cos(ang||0)*B.r, B.y + Math.sin(ang||0)*B.r, 8, PAL.brass, 220);
  pSmoke(B.x, B.y - 20, 4, 'rgba(60,55,50,0.6)', 60);
  dmgNumber(B.x, B.y - B.r, '-' + Math.round(dmg), '#FF9A5B', 18);
  if (B.hp <= 0){ B.hp = 0; endGame(false, 'The engine core is gone. The ship falls.', 'BOILER LOST'); }
}

function updatePlayer(dt){
  const P = S.player, T = TUNING.player;
  if (P.hp <= 0) return;

  P.aim = Math.atan2(Input.mouse.y - P.y, Input.mouse.x - P.x);

  // --- auto-attack ----------------------------------------------------------
  // The cursor still AIMS the four abilities; the captain's basic swing picks
  // its own target and fires on its own cadence. Facing follows that target so
  // she reads as engaged, and falls back to the cursor when nothing is in range.
  const AA = FEEL.autoAttack;
  if (S.basic){
    // v6 — the basic IS the Ember Cleave. Same arc, same element, same crit and
    // knockback as when it sat on a slot; it just picks its own target and its
    // own moment. Reach comes from the skill, so LONG REACH cards lengthen it.
    const bst = skillStats(S.basic);
    const reach = bst.range + 30;
    let best = null, bd = reach * reach;
    Hash.query(P.x, P.y, reach + 60, _q);
    for (const e of _q){
      if (e.dead || e.state === 'climb') continue;
      const d = dist2(P.x, P.y, e.x, e.y);
      if (d < bd - e.r * e.r){ bd = d; best = e; }
    }
    // a vulnerable hulk is a legitimate target too, or the captain stands at the
    // boarding vessel swinging at nothing
    const H = (PRESET.lanes && S.hulk && !S.hulk.dead && S.hulk.vulnerable) ? S.hulk : null;
    const hIn = H && dist(P.x, P.y, H.x, H.y) < H.r + reach;
    P.atkTarget = best;
    const tx = best ? best.x : (hIn ? H.x : null);
    const ty = best ? best.y : (hIn ? H.y : null);
    const want = (tx !== null) ? Math.atan2(ty - P.y, tx - P.x) : P.aim;
    P.facing = angNorm(P.facing + clamp(angDiff(P.facing, want), -FEEL.basicTurn * dt, FEEL.basicTurn * dt));
    P.atkSwing = Math.max(0, P.atkSwing - dt);
    if (tx !== null && S.basic.cdLeft <= 0 && P.dashT <= 0 &&
        Math.abs(angDiff(P.facing, want)) < FEEL.basicArc){
      P.atkSwing = 0.18;
      castSlot(S.basic, { atX: tx, atY: ty });
    }
  } else if (AA){
    P.atkCd = Math.max(0, P.atkCd - dt);
    P.atkSwing = Math.max(0, P.atkSwing - dt);
    let best = null, bd = AA.range * AA.range;
    Hash.query(P.x, P.y, AA.range + 60, _q);
    for (const e of _q){
      if (e.dead || e.state === 'climb') continue;
      const d = dist2(P.x, P.y, e.x, e.y);
      if (d < bd){ bd = d; best = e; }
    }
    if (!best && PRESET.lanes && S.hulk && !S.hulk.dead && S.hulk.vulnerable &&
        dist(P.x, P.y, S.hulk.x, S.hulk.y) < S.hulk.r + AA.range){
      if (P.atkCd <= 0 && P.dashT <= 0){
        P.atkCd = AA.cd; P.atkSwing = 0.18;
        const a = Math.atan2(S.hulk.y - P.y, S.hulk.x - P.x);
        damageHulk(AA.dmg);
        fx({ kind:'arc', x:P.x, y:P.y, a, arc: 52*DEG, r: 92,
             life: 0.15, col: '#8FA6C9', glow: '#E8E2D2' });
        SFX.hit();
      }
    }
    P.atkTarget = best;
    const want = best ? Math.atan2(best.y - P.y, best.x - P.x) : P.aim;
    P.facing = angNorm(P.facing + clamp(angDiff(P.facing, want), -AA.turn*dt, AA.turn*dt));
    if (best && P.atkCd <= 0 && P.dashT <= 0 && Math.abs(angDiff(P.facing, want)) < AA.arc){
      P.atkCd = AA.cd;
      P.atkSwing = 0.18;
      const a = Math.atan2(best.y - P.y, best.x - P.x);
      hitEnemy(best, AA.dmg, { ang: a, knock: 110 });
      hulkSplash({ x: P.x + Math.cos(a) * 90, y: P.y + Math.sin(a) * 90 }, AA.dmg);
      const E = ELEMENTS[P.lastElem || 'EMBER'];
      // a sabre flick, not a cleave — it hits one target, so it must not read
      // as a wide AoE sweep or it will be mistaken for the slot-1 ability
      fx({ kind:'arc', x:P.x, y:P.y, a, arc: 52*DEG, r: 92,
           life: 0.15, col: '#8FA6C9', glow: '#E8E2D2' });
      pSparks(P.x + Math.cos(a)*40, P.y + Math.sin(a)*40, 3, '#E8E2D2', 150, a, 0.5);
      SFX.hit();
    }
  } else {
    P.facing = P.aim;
  }

  // --- input direction
  let ix = 0, iy = 0;
  if (keyDown('a') || keyDown('arrowleft'))  ix -= 1;
  if (keyDown('d') || keyDown('arrowright')) ix += 1;
  if (keyDown('w') || keyDown('arrowup'))    iy -= 1;
  if (keyDown('s') || keyDown('arrowdown'))  iy += 1;
  const il = Math.hypot(ix, iy);
  if (il > 0){ ix /= il; iy /= il; }

  // --- dash: the most important verb. i-frames the whole way.
  P.dashCd -= dt;
  if (P.dashCd <= 0 && P.dashStock < S.mods.dashCharges){
    P.dashStock++;
    P.dashCd = P.dashStock < S.mods.dashCharges ? dashCdMax() : 0;
    SFX.ready();
  }
  // buffer must be tested BEFORE it decays, or a zero-length buffer (v2/v3)
  // would expire in the same step it was set and the dash would never fire
  if (keyHit(KEYS.dash.key)) P.dashBuf = Math.max(FEEL.inputBuffer, DT * 2);
  if (P.dashBuf > 0 && P.dashT <= 0 && P.dashStock > 0){
    P.dashBuf = 0;
    P.dashStock--;
    if (P.dashCd <= 0) P.dashCd = dashCdMax();
    P.dashT = T.dashTime;
    P.dashAng = il > 0 ? Math.atan2(iy, ix) : P.aim;
    P.hitList = [];
    P.trail.length = 0;
    S.stats.dashes++;
    SFX.dash();
    pDust(P.x, P.y, 10);
    addTrauma(0.06);
  }

  const speed = T.speed * S.mods.moveMult;
  if (P.dashT > 0){
    P.dashT -= dt;
    const v = T.dashDist / T.dashTime;
    P.vx = Math.cos(P.dashAng) * v;
    P.vy = Math.sin(P.dashAng) * v;
    if (P.trail.length === 0 || dist(P.trail[P.trail.length-1].x, P.trail[P.trail.length-1].y, P.x, P.y) > 12)
      P.trail.push({ x:P.x, y:P.y, a: P.facing !== undefined ? P.facing : P.aim, t:0 });
    if (S.mods.dashDamage > 0){
      Hash.query(P.x, P.y, 44, _q);
      for (const e of _q){
        if (e.dead || e.state === 'climb' || P.hitList.indexOf(e) >= 0) continue;
        if (dist2(P.x, P.y, e.x, e.y) < (30 + e.r)*(30 + e.r)){
          P.hitList.push(e);
          hitEnemy(e, S.mods.dashDamage, { ang: P.dashAng, knock: 240 });
        }
      }
    }
    if (P.dashT <= 0){ P.vx *= 0.35; P.vy *= 0.35; }
  } else {
    const ACC = FEEL.accel || T.accel;
    const ax = ix * ACC * S.mods.moveMult, ay = iy * ACC * S.mods.moveMult;
    P.vx += ax * dt; P.vy += ay * dt;
    if (il === 0){
      // slide, never a dead stop
      const sp = Math.hypot(P.vx, P.vy);
      const ns = Math.max(0, sp - (FEEL.friction || T.friction) * dt);
      if (sp > 0.001){ P.vx = P.vx / sp * ns; P.vy = P.vy / sp * ns; }
    }
    const sp = Math.hypot(P.vx, P.vy);
    if (sp > speed){ P.vx = P.vx/sp*speed; P.vy = P.vy/sp*speed; }
  }

  P.x += P.vx * dt; P.y += P.vy * dt;

  // deck + props
  const c = clampToDeck(P.x, P.y, T.radius + 8);
  if (c.x !== P.x || c.y !== P.y){ P.x = c.x; P.y = c.y; P.vx *= 0.4; P.vy *= 0.4; }
  for (const pr of SOLID_PROPS) pushOut(P, pr.x, pr.y, pr.r + T.radius);
  pushOut(P, S.boiler.x, S.boiler.y, S.boiler.r + T.radius);
  pushOutWalls(P, T.radius);
  if (PRESET.lanes) for (const t of S.turrets) if (!t.dead) pushOut(P, t.x, t.y, t.r + T.radius);

  // footfalls
  const sp = Math.hypot(P.vx, P.vy);
  P.walk += sp * dt * 0.045;
  if (sp > 40){
    P.stepT -= dt;
    if (P.stepT <= 0){ P.stepT = 0.16; pDust(P.x, P.y + 10, 2); }
  }
  P.coatSway = lerp(P.coatSway, clamp(-P.vx * 0.0016, -0.5, 0.5), 1 - Math.pow(0.001, dt));

  // timers
  P.dashBuf = Math.max(0, (P.dashBuf || 0) - dt);
  P.iframe = Math.max(0, P.iframe - dt);
  P.hurt = Math.max(0, P.hurt - dt);
  P.castFlash = Math.max(0, P.castFlash - dt);
  for (let i = P.trail.length - 1; i >= 0; i--){
    P.trail[i].t += dt;
    if (P.trail[i].t > 0.32) P.trail.splice(i, 1);
  }

  if (S.basic) S.basic.cdLeft = Math.max(0, S.basic.cdLeft - dt);

  // --- fire
  for (let i = 0; i < 4; i++){
    const sk = S.slots[i];
    if (!sk) continue;
    const wasDown = sk.cdLeft > 0;
    sk.cdLeft = Math.max(0, sk.cdLeft - dt);
    if (wasDown && sk.cdLeft <= 0){ sk.readyPulse = 0.35; SFX.ready(); }
    sk.readyPulse = Math.max(0, sk.readyPulse - dt);
    sk.blocked = Math.max(0, (sk.blocked || 0) - dt);
    // Remember a press that arrived while blocked, and spend it the instant the
    // skill comes up. Without this, tapping 20ms early is simply swallowed —
    // the single biggest thing that makes an action game feel unresponsive.
    if (slotHeld(i)) sk.buf = FEEL.inputBuffer;
    else sk.buf = Math.max(0, (sk.buf || 0) - dt);
    if (slotHeld(i) || sk.buf > 0){
      if (castSlot(i, {})) sk.buf = 0;
      else if (slotHeld(i) && sk.cdLeft > 0) sk.blocked = 0.12;
    }
  }
  updateRay(dt);
}

function pushOut(o, cx, cy, minD){
  const dx = o.x - cx, dy = o.y - cy;
  const d = Math.hypot(dx, dy);
  if (d < minD && d > 0.0001){
    const k = (minD - d) / d;
    o.x += dx * k; o.y += dy * k;
    if (o.vx !== undefined){ o.vx *= 0.86; o.vy *= 0.86; }
  } else if (d <= 0.0001){ o.x += rnd(-1,1); o.y += rnd(-1,1); }
}

/* ---------------------------------------------------------------------------
   SYSTEMS — enemies
--------------------------------------------------------------------------- */
function spawnEnemy(type, forced, lane){
  const def = ENEMIES[type];
  const scale = 1 + TUNING.enemyScaling * (S.wave - 1);

  let pt = forced;
  if (PRESET.lanes && !pt){
    if (lane === 'rail'){
      // the occasional rail boarder: climbs amidships, then joins that lane
      const side = chance(0.5) ? -1 : 1;
      const D = TUNING.deck;
      const y = rnd(LANE_TOP + 240, BASE_Y - 260);
      pt = { x: D.cx + side * (D.w/2 - 26), y, side: side < 0 ? 'left' : 'right' };
      lane = laneOf(pt.x);
    } else {
      if (typeof lane !== 'number') lane = rndi(0, LANE_N);
      const L = LANES[lane];
      pt = { x: L.cx + rnd(-L.halfW * 0.55, L.halfW * 0.55), y: LANE_TOP, side: 'bow' };
    }
  }
  if (!pt){
    // Never drop a boarder on top of the player.
    let best = null, bestD = -1;
    for (let i = 0; i < 12; i++){
      const p = pick(SPAWN_POINTS);
      const d = dist(p.x, p.y, S.player.x, S.player.y);
      if (d > 300){ best = p; break; }
      if (d > bestD){ bestD = d; best = p; }
    }
    pt = best;
  }
  if (type === 'BOSS') pt = { x: TUNING.deck.cx, y: TUNING.deck.cy - TUNING.deck.h/2 + 40, side:'bow' };

  const inward = clampToDeck(
    pt.x + (TUNING.deck.cx - pt.x) * 0.06,
    pt.y + (TUNING.deck.cy - pt.y) * 0.06, def.radius + 6);

  const e = {
    type, def, x: inward.x, y: inward.y, vx: 0, vy: 0, kx: 0, ky: 0,
    hp: def.hp * scale, maxHp: def.hp * scale, r: def.radius,
    facing: Math.atan2(TUNING.deck.cy - pt.y, TUNING.deck.cx - pt.x),
    state: 'climb', st: TUNING.spawnClimb, climb: 0,
    burnStacks: 0, burnT: 0, burnTick: 0, slowT: 0, slowAmt: 0, stunT: 0, accT: 0, scaldT: 0, scaldTick: 0,
    flash: 0, blockFlash: 0, anim: rnd(TAU), dead: false,
    atkAng: 0, atkTarget: null, shootT: rnd(0.4, 1.4), swingFx: 0,
    spawnX: pt.x, spawnY: pt.y, side: pt.side,
    boss: type === 'BOSS' ? { seq: 0, cool: 2.4, atk: null, sweep: 0, dir: 1, tick: 0 } : null,
  };
  e.lane = PRESET.lanes ? (typeof lane === 'number' ? lane : laneOf(e.x)) : 0;
  S.enemies.push(e);
  if (type === 'BOSS'){ S.bossRef = e; SFX.bossRoar(); addTrauma(0.6); }
  if (!S.seenTypes[type] && type !== 'BOSS'){
    S.seenTypes[type] = true;
    S.banner = { kind:'type', type, t: 0, life: 3.2 };
  }
  return e;
}

function enemyTarget(e){
  if (PRESET.lanes) return laneEnemyTarget(e);
  const P = S.player;
  if (e.def.ai === 'swarm' || P.hp <= 0)
    return { x: S.boiler.x, y: S.boiler.y, r: S.boiler.r, isPlayer: false };
  const pref = e.type === 'BOSS' ? 420 : 260;
  if (dist(e.x, e.y, P.x, P.y) < pref)
    return { x: P.x, y: P.y, r: TUNING.player.radius, isPlayer: true };
  return { x: S.boiler.x, y: S.boiler.y, r: S.boiler.r, isPlayer: false };
}

function tickDamage(e, dmg, col){
  if (e.dead) return;
  e.hp -= dmg;
  S.stats.damage += dmg;
  if (chance(0.30)) dmgNumber(e.x + rnd(-6,6), e.y - e.r, Math.round(dmg), col, 13);
  if (e.hp <= 0) killEnemy(e, rnd(TAU));
}

function updateEnemy(e, dt){
  const def = e.def;

  // --- status effects (these run even mid-climb so nothing feels cheated)
  if (e.burnT > 0){
    e.burnT -= dt;
    e.burnTick -= dt;
    if (e.burnTick <= 0){
      e.burnTick += 0.25;
      tickDamage(e, 5 * e.burnStacks * S.mods.burnDmg * 0.25, '#FFB05A');
      if (chance(0.6)) Particles.spawn({ x:e.x + rnd(-e.r,e.r), y:e.y + rnd(-e.r,e.r*0.5),
        vx:rnd(-14,14), vy:rnd(-56,-22), life:rnd(0.25,0.5), size:rnd(2,4.5),
        col:chance(0.5)?'#E2691E':'#FFC168', kind:'glow', add:true, drag:0.93 });
    }
    if (e.burnT <= 0) e.burnStacks = 0;
  }
  if (e.scaldT > 0){
    e.scaldT -= dt; e.scaldTick -= dt;
    if (e.scaldTick <= 0){ e.scaldTick += 0.25; tickDamage(e, 2, '#E4DAF0'); }
  }
  if (e.slowT > 0) e.slowT -= dt;
  if (e.stunT > 0) e.stunT -= dt;
  if (e.accT > 0)  e.accT  -= dt;
  if (e.flash > 0) e.flash -= dt;
  if (e.blockFlash > 0) e.blockFlash -= dt;
  if (e.swingFx > 0) e.swingFx -= dt;
  e.anim += dt;
  if (e.dead) return;

  // --- knockback always applies, even while stunned or winding up
  const kd = Math.pow(0.86, dt * 60);
  e.x += e.kx * dt; e.y += e.ky * dt;
  e.kx *= kd; e.ky *= kd;

  if (e.state === 'climb'){
    e.st -= dt;
    e.climb = 1 - Math.max(0, e.st) / TUNING.spawnClimb;
    if (e.st <= 0){ e.state = 'move'; e.climb = 1; }
    return;
  }

  const slowF = e.slowT > 0 ? (1 - e.slowAmt) : 1;
  const stunned = e.stunT > 0;
  const tgt = enemyTarget(e);
  e.tgtKind = tgt.kind; e.tgtRef = tgt.ref;
  const d = dist(e.x, e.y, tgt.x, tgt.y);
  const toT = Math.atan2(tgt.y - e.y, tgt.x - e.x);

  if (!stunned){
    if (def.ai === 'boss') updateBoss(e, dt, tgt, d, toT, slowF);
    else if (def.ai === 'ranged') updateRanged(e, dt, tgt, d, toT, slowF);
    else updateMelee(e, dt, tgt, d, toT, slowF);
  } else {
    e.vx *= 0.86; e.vy *= 0.86;
  }

  e.x += e.vx * dt; e.y += e.vy * dt;

  // deck + props
  const c = clampToDeck(e.x, e.y, e.r + 4);
  e.x = c.x; e.y = c.y;
  if (PRESET.lanes){ clampToLane(e, e.lane, e.r); pushOutWalls(e, e.r); }
  if (e.type !== 'BOSS'){
    for (const pr of SOLID_PROPS) pushOut(e, pr.x, pr.y, pr.r + e.r);
  }
  pushOut(e, S.boiler.x, S.boiler.y, S.boiler.r + e.r);
}

function faceToward(e, ang, dt, rate){
  e.facing = angNorm(e.facing + clamp(angDiff(e.facing, ang), -rate*dt, rate*dt));
}

function moveTo(e, tgt, dt, slowF, stopAt){
  const dx = tgt.x - e.x, dy = tgt.y - e.y;
  const d = Math.hypot(dx, dy) || 1;
  const sp = e.def.speed * slowF;
  if (d > stopAt){
    // a little lateral wobble so packs don't form a laser-straight line
    const wob = Math.sin(e.anim * 2.4 + e.spawnX) * 0.22;
    const a = Math.atan2(dy, dx) + wob;
    e.vx = lerp(e.vx, Math.cos(a) * sp, 1 - Math.pow(0.0015, dt));
    e.vy = lerp(e.vy, Math.sin(a) * sp, 1 - Math.pow(0.0015, dt));
  } else {
    e.vx *= Math.pow(0.02, dt); e.vy *= Math.pow(0.02, dt);
  }
}

function updateMelee(e, dt, tgt, d, toT, slowF){
  const def = e.def;
  if (e.state === 'move'){
    faceToward(e, toT, dt, 7);
    moveTo(e, tgt, dt, slowF, def.atkRange + tgt.r - e.r);
    if (d <= def.atkRange + tgt.r){
      e.state = 'windup'; e.st = def.windup;
      e.atkAng = toT; e.atkTarget = tgt.isPlayer ? 'player' : 'boiler';
      e.laneTgt = { x: tgt.x, y: tgt.y, r: tgt.r };
      SFX.telegraph();
    }
  } else if (e.state === 'windup'){
    e.st -= dt;
    e.vx *= Math.pow(0.05, dt); e.vy *= Math.pow(0.05, dt);
    if (e.st > def.windup * 0.45){ e.atkAng = angNorm(e.atkAng + clamp(angDiff(e.atkAng, toT), -3.2*dt, 3.2*dt)); }
    faceToward(e, e.atkAng, dt, 9);
    if (e.st <= 0){
      resolveMelee(e);
      e.state = 'recover'; e.st = def.recover;
    }
  } else {
    e.st -= dt;
    e.vx *= Math.pow(0.3, dt); e.vy *= Math.pow(0.3, dt);
    if (e.st <= 0) e.state = 'move';
  }
}

function resolveMelee(e){
  const def = e.def;
  if (PRESET.lanes && e.tgtKind){
    e.swingFx = 0.22;
    fx({ kind:'swing', x:e.x, y:e.y, a:e.atkAng, r:def.reach, arc:def.swing, life:0.2 });
    const t = e.laneTgt;
    if (t && dist(e.x, e.y, t.x, t.y) <= def.reach + t.r + 10)
      laneResolveHit(e, e.tgtKind, e.tgtRef, def.dmg, e.atkAng);
    return;
  }
  const T = e.atkTarget === 'player' ? S.player : S.boiler;
  const tr = e.atkTarget === 'player' ? TUNING.player.radius : S.boiler.r;
  e.swingFx = 0.22;
  fx({ kind:'swing', x:e.x, y:e.y, a:e.atkAng, r:def.reach, arc:def.swing, life:0.2 });
  pSparks(e.x + Math.cos(e.atkAng)*def.reach*0.7, e.y + Math.sin(e.atkAng)*def.reach*0.7, 3, PAL.grey, 120);
  const d = dist(e.x, e.y, T.x, T.y);
  if (d > def.reach + tr) return;
  const a = Math.atan2(T.y - e.y, T.x - e.x);
  if (Math.abs(angDiff(e.atkAng, a)) > def.swing / 2) return;
  if (e.atkTarget === 'player') hurtPlayer(def.dmg, e.atkAng);
  else hurtBoiler(def.dmg, Math.atan2(e.y - S.boiler.y, e.x - S.boiler.x));
}

function updateRanged(e, dt, tgt, d, toT, slowF){
  const def = e.def;
  const want = def.atkRange * 0.88;
  if (e.state === 'move'){
    faceToward(e, toT, dt, 5.5);
    if (d > want + 40){
      moveTo(e, tgt, dt, slowF, 0);
    } else if (d < want - 80){
      const a = toT + Math.PI;
      e.vx = lerp(e.vx, Math.cos(a) * def.speed * slowF, 1 - Math.pow(0.004, dt));
      e.vy = lerp(e.vy, Math.sin(a) * def.speed * slowF, 1 - Math.pow(0.004, dt));
    } else {
      const a = toT + Math.PI/2 * (Math.sin(e.anim * 0.8 + e.spawnY) > 0 ? 1 : -1);
      e.vx = lerp(e.vx, Math.cos(a) * def.speed * 0.5 * slowF, 1 - Math.pow(0.01, dt));
      e.vy = lerp(e.vy, Math.sin(a) * def.speed * 0.5 * slowF, 1 - Math.pow(0.01, dt));
    }
    e.shootT -= dt;
    if (e.shootT <= 0 && d < def.atkRange + 60){
      e.state = 'windup'; e.st = def.windup; e.atkAng = toT;
      e.atkTarget = tgt.isPlayer ? 'player' : 'boiler';
      SFX.telegraph();
    }
  } else if (e.state === 'windup'){
    e.st -= dt;
    e.vx *= Math.pow(0.02, dt); e.vy *= Math.pow(0.02, dt);
    e.atkAng = angNorm(e.atkAng + clamp(angDiff(e.atkAng, toT), -2.0*dt, 2.0*dt));
    faceToward(e, e.atkAng, dt, 8);
    if (e.st <= 0){
      // STEAM's accuracy debuff shows up right here
      const err = e.accT > 0 ? rnd(-0.30, 0.30) : rnd(-0.045, 0.045);
      const a = e.atkAng + err;
      S.bolts.push({ x: e.x + Math.cos(a)*20, y: e.y + Math.sin(a)*20,
                     vx: Math.cos(a)*def.bolt, vy: Math.sin(a)*def.bolt,
                     dmg: def.dmg, r: 7, life: 3.2, t: 0, ang: a, lane: e.lane });
      SFX.enemyShoot();
      pSparks(e.x + Math.cos(a)*22, e.y + Math.sin(a)*22, 4, '#FFC168', 160, a, 0.4);
      e.shootT = rnd(1.5, 2.4);
      e.state = 'recover'; e.st = def.recover;
    }
  } else {
    e.st -= dt;
    e.vx *= Math.pow(0.25, dt); e.vy *= Math.pow(0.25, dt);
    if (e.st <= 0) e.state = 'move';
  }
}

/* --- the wave-12 boss: slam / summon / sweeping ray, all telegraphed ------- */
const BOSS_ATTACKS = ['slam', 'summon', 'ray'];
function updateBoss(e, dt, tgt, d, toT, slowF){
  const B = e.boss;
  if (e.state === 'move'){
    faceToward(e, toT, dt, 2.4);
    moveTo(e, tgt, dt, slowF, 150 + tgt.r);
    B.cool -= dt;
    if (B.cool <= 0){
      B.atk = BOSS_ATTACKS[B.seq % BOSS_ATTACKS.length];
      B.seq++;
      e.state = 'windup';
      e.st = B.atk === 'slam' ? 0.9 : B.atk === 'summon' ? 0.7 : 0.8;
      e.atkAng = toT;
      SFX.telegraph();
    }
  } else if (e.state === 'windup'){
    e.st -= dt;
    e.vx *= Math.pow(0.02, dt); e.vy *= Math.pow(0.02, dt);
    if (B.atk === 'ray') e.atkAng = angNorm(e.atkAng + clamp(angDiff(e.atkAng, toT), -1.4*dt, 1.4*dt));
    faceToward(e, e.atkAng, dt, 3.4);
    if (e.st <= 0){
      if (B.atk === 'slam'){
        SFX.slam(); addTrauma(0.7); hitStop(0.06);
        fx({ kind:'aoe', x:e.x, y:e.y, r:240, life:0.5, col:'#C86A2E', glow:'#FFC168' });
        pSmoke(e.x, e.y, 18, 'rgba(150,140,125,0.5)', 190);
        pSparks(e.x, e.y, 22, PAL.brass, 420);
        const dp = dist(e.x, e.y, S.player.x, S.player.y);
        if (dp < 240 + TUNING.player.radius) hurtPlayer(26, Math.atan2(S.player.y - e.y, S.player.x - e.x));
        // the slam is how Grimwheel threatens the Boiler — intercept him or lose it
        if (dist(e.x, e.y, S.boiler.x, S.boiler.y) < 240 + S.boiler.r)
          hurtBoiler(40, Math.atan2(e.y - S.boiler.y, e.x - S.boiler.x));
        e.state = 'recover'; e.st = 0.85;
      } else if (B.atk === 'summon'){
        SFX.bossRoar();
        for (let i = 0; i < 6; i++){
          const a = (i/6)*TAU + rnd(0.2);
          const p = clampToDeck(e.x + Math.cos(a)*130, e.y + Math.sin(a)*130, 30);
          const s = spawnEnemy('SWARM', { x:p.x, y:p.y, side:'boss' });
          s.st = 0.5;
        }
        e.state = 'recover'; e.st = 0.7;
      } else {
        e.state = 'active'; e.st = 2.2;
        B.sweep = -55*DEG; B.dir = chance(0.5) ? 1 : -1; B.tick = 0;
        B.baseAng = e.atkAng;
      }
    }
  } else if (e.state === 'active'){
    // sustained sweeping ray
    e.st -= dt;
    e.vx *= Math.pow(0.02, dt); e.vy *= Math.pow(0.02, dt);
    B.sweep += B.dir * (110*DEG / 2.2) * dt;
    const a = B.baseAng + B.sweep;
    e.facing = a;
    const len = 620;
    const ex = e.x + Math.cos(a)*len, ey = e.y + Math.sin(a)*len;
    if (rnd() < dt*60) pSparks(ex, ey, 1, '#FFC168', 200, a + Math.PI, 1.2);
    B.tick -= dt;
    if (B.tick <= 0){
      B.tick += 0.2;
      const P = S.player;
      const rx = P.x - e.x, ry = P.y - e.y;
      const tproj = rx*Math.cos(a) + ry*Math.sin(a);
      const perp = Math.abs(-rx*Math.sin(a) + ry*Math.cos(a));
      if (tproj > 0 && tproj < len && perp < 26 + TUNING.player.radius) hurtPlayer(9, a);
      const bx = S.boiler.x - e.x, by = S.boiler.y - e.y;
      const bt = bx*Math.cos(a) + by*Math.sin(a);
      const bp = Math.abs(-bx*Math.sin(a) + by*Math.cos(a));
      if (bt > 0 && bt < len && bp < 26 + S.boiler.r)
        hurtBoiler(7, Math.atan2(e.y - S.boiler.y, e.x - S.boiler.x));
    }
    if (e.st <= 0){ e.state = 'recover'; e.st = 0.6; }
  } else {
    e.st -= dt;
    e.vx *= Math.pow(0.3, dt); e.vy *= Math.pow(0.3, dt);
    if (e.st <= 0){ e.state = 'move'; B.cool = rnd(2.2, 3.4); B.atk = null; }
  }
}

/* --- separation: keeps a crowd legible without turning into a shove-fest -- */
function separate(dt){
  const list = S.enemies;
  for (let i = 0; i < list.length; i++){
    const a = list[i];
    if (a.dead || a.state === 'climb' || a.type === 'BOSS') continue;
    Hash.query(a.x, a.y, a.r + 34, _q);
    for (let j = 0; j < _q.length; j++){
      const b = _q[j];
      if (b === a || b.dead || b.state === 'climb') continue;
      const dx = b.x - a.x, dy = b.y - a.y;
      const md = a.r + b.r;
      const d2 = dx*dx + dy*dy;
      if (d2 >= md*md || d2 < 0.0001) continue;
      const d = Math.sqrt(d2);
      const push = (md - d) / d * 0.5;
      const mr = b.def.mass / (a.def.mass + b.def.mass);
      a.x -= dx * push * mr * 1.6; a.y -= dy * push * mr * 1.6;
      if (b.type !== 'BOSS'){ b.x += dx * push * (1-mr) * 1.6; b.y += dy * push * (1-mr) * 1.6; }
    }
  }
}

/* ---------------------------------------------------------------------------
   SYSTEMS — projectiles, pickups, lingering fields, transient vfx
--------------------------------------------------------------------------- */
function updateBolts(dt){
  const P = S.player;
  for (let i = S.bolts.length - 1; i >= 0; i--){
    const b = S.bolts[i];
    b.t += dt; b.life -= dt;
    b.x += b.vx * dt; b.y += b.vy * dt;
    if (rnd() < dt * 26)
      Particles.spawn({ x:b.x, y:b.y, vx:rnd(-12,12), vy:rnd(-12,12), life:0.22, size:2.4,
                        col:'#FFC168', kind:'glow', add:true, drag:0.9 });
    let hit = false;
    if (P.hp > 0 && P.dashT <= 0 && P.iframe <= 0 &&
        dist2(b.x, b.y, P.x, P.y) < (b.r + TUNING.player.radius)**2){
      hurtPlayer(b.dmg, b.ang); hit = true;
    }
    if (!hit && PRESET.lanes){
      for (const c of S.crew){
        if (c.dead) continue;
        if (dist2(b.x, b.y, c.x, c.y) < (b.r + c.r)**2){ hurtCrew(c, b.dmg, b.ang); hit = true; break; }
      }
      if (!hit) for (const t of S.turrets){
        if (t.dead) continue;
        if (dist2(b.x, b.y, t.x, t.y) < (b.r + t.r)**2){ damageTurret(t, b.dmg); hit = true; break; }
      }
    }
    if (!hit && dist2(b.x, b.y, S.boiler.x, S.boiler.y) < (b.r + S.boiler.r)**2){
      hurtBoiler(b.dmg, Math.atan2(b.y - S.boiler.y, b.x - S.boiler.x)); hit = true;
    }
    if (hit || b.life <= 0 || !inDeck(b.x, b.y, -40)){
      if (!hit) pSparks(b.x, b.y, 4, '#FFC168', 120);
      S.bolts.splice(i, 1);
    }
  }
}

function updatePickups(dt){
  const P = S.player;
  for (let i = S.pickups.length - 1; i >= 0; i--){
    const p = S.pickups[i];
    p.t += dt; p.life -= dt; p.bob += dt * 4;
    p.x += p.vx * dt; p.y += p.vy * dt;
    p.vx *= Math.pow(0.1, dt); p.vy *= Math.pow(0.1, dt);
    const d = dist(p.x, p.y, P.x, P.y);
    if (d < 150 && P.hp > 0){   // gentle magnetism, it feels generous
      const a = Math.atan2(P.y - p.y, P.x - p.x);
      const pull = 380 * (1 - d/150);
      p.x += Math.cos(a) * pull * dt; p.y += Math.sin(a) * pull * dt;
    }
    if (d < 26 && P.hp > 0){
      P.hp = Math.min(P.maxHp, P.hp + p.heal);
      dmgNumber(P.x, P.y - 30, '+' + p.heal, '#8CE07A', 20);
      pSparks(p.x, p.y, 10, '#8CE07A', 200);
      SFX.pickup();
      S.pickups.splice(i, 1); continue;
    }
    if (p.life <= 0) S.pickups.splice(i, 1);
  }
}

function updateFields(dt){
  for (let i = S.fields.length - 1; i >= 0; i--){
    const f = S.fields[i];
    f.t += dt; f.life -= dt;
    f.tick -= dt;
    if (f.tick <= 0){
      f.tick += 0.25;
      damageArea(f.x, f.y, f.r, f.dps * 0.25, f.elem, { noCrit:true, silent:true });
    }
    if (rnd() < dt * 30){
      const a = rnd(TAU), rr = Math.sqrt(rnd()) * f.r;
      Particles.spawn({ x:f.x + Math.cos(a)*rr, y:f.y + Math.sin(a)*rr, vx:rnd(-10,10), vy:rnd(-40,-12),
                        life:rnd(0.3,0.7), size:rnd(2,5), col:ELEMENTS[f.elem].glow, kind:'glow', add:true, drag:0.94 });
    }
    if (f.life <= 0) S.fields.splice(i, 1);
  }
}

function updateFx(dt){
  for (let i = S.fx.length - 1; i >= 0; i--){
    const f = S.fx[i];
    if (f.delay > 0){ f.delay -= dt; continue; }
    if (f.kind === 'delayPop' && !f.popped){
      f.popped = true;
      pGibs(f.x, f.y, 12, PAL.brass, '#FFD36B');
      pSmoke(f.x, f.y, 6, 'rgba(150,140,125,0.5)', 90);
      addTrauma(0.2); SFX.death();
    }
    f.t += dt;
    if (f.t >= f.life) S.fx.splice(i, 1);
  }
  for (let i = S.nums.length - 1; i >= 0; i--){
    const n = S.nums[i];
    n.t += dt;
    n.x += n.vx * dt; n.y += n.vy * dt;
    n.vy += 190 * dt; n.vx *= Math.pow(0.15, dt);
    if (n.t >= n.life) S.nums.splice(i, 1);
  }
}

/* ---------------------------------------------------------------------------
   SYSTEMS — waves
--------------------------------------------------------------------------- */
// batch = [t, type, count] or [t, type, count, lane] where lane is 0..2,
// 'all' (that count into EVERY lane) or 'rail' (climbs a side rail amidships)
function buildQueue(w){
  const def = WAVES[w-1], q = [];
  for (const b of def.batches){
    const lanes = !PRESET.lanes ? [undefined]
      : b[3] === 'all' ? [0, 1, 2]
      : b[3] === undefined ? [undefined] : [b[3]];
    for (const ln of lanes)
      for (let i = 0; i < b[2]; i++)
        q.push({ t: b[0] + i * 0.22, type: b[1], lane: ln });
  }
  q.sort((a,b) => a.t - b.t);
  return q;
}
function countLive(){ let n = 0; for (const e of S.enemies) if (!e.dead) n++; return n; }
function pendingCount(){ return S.queue.length + countLive(); }

function startWave(n){
  S.wave = n;
  if (PRESET.lanes && S.hulk){
    const isPush = !!(WAVES[n-1] && WAVES[n-1].push);
    if (isPush){
      // A fresh vessel grapples on for every push. Without this the hulk was
      // spawned once at run start and never reset, so breaking it on wave 4
      // left it permanently dead — wave 8 then satisfied its "ends when their
      // hulk does" condition on the first frame and completed in 3 seconds,
      // and wave 12 lost its push half entirely. Each one is a little tougher
      // than the last, but only a little: the first one already reads as long.
      const idx = WAVES.slice(0, n).filter(w => w.push).length - 1;
      spawnHulk(1 + idx * 0.20);
      S.hulk.vulnerable = true;
      S.banner = { kind:'push', n, t:0, life: 3.0 };
      SFX.hulkGrapple();
      S.crewT = 0.5;            // send a wave with the horn, not 14s after it
    } else {
      S.hulk.vulnerable = false;
    }
  }
  SFX.waveStart();
  S.queue = buildQueue(n);
  S.waveT = 0; S.loopT = 0; S.loopIdx = 0;
  S.phase = 'fight';
  S.bossSpawned = false;
  S.banner = { kind:'wave', n, t:0, life: 2.4 };
  if (WAVES[n-1].boss) S.banner = { kind:'boss', n, t:0, life: 3.0 };
}

function waveComplete(){
  S.phase = 'clear';
  S.interT = 1.7;
  S.slowmo = TUNING.feel.waveClearSlowmoTime;
  S.stats.waves = S.wave;
  S.banner = { kind:'clear', n:S.wave, t:0, life: 2.2 };
  SFX.waveClear();
  pGold(S.player.x, S.player.y, 30);
  pGold(S.boiler.x, S.boiler.y, 24);
  S.player.hp = Math.min(S.player.maxHp, S.player.hp + TUNING.player.regenPerWave);
  S.bolts.length = 0;
  // slots open up as the run escalates
  if (S.wave >= 2 && S.unlockedSlots < 3) S.unlockedSlots = 3;
  if (S.wave >= 5 && S.unlockedSlots < 4) S.unlockedSlots = 4;
}

function updateWave(dt){
  if (S.winSeq > 0){
    S.winSeq -= dt;
    S.slowmo = Math.max(S.slowmo, 0.2);
    S.killT -= dt;
    if (S.killT <= 0){
      S.killT = 0.09;
      const alive = S.enemies.filter(e => !e.dead);
      if (alive.length) killEnemy(pick(alive), rnd(TAU));
    }
    if (S.winSeq <= 0) endGame(true, 'Twelve waves repelled. The deck is yours.', 'DECK HELD');
    return;
  }

  if (S.phase === 'fight'){
    S.waveT += dt;
    const def = WAVES[S.wave-1];
    let live = countLive();
    while (S.queue.length && S.queue[0].t <= S.waveT && live < TUNING.maxLiveEnemies){
      const nx = S.queue.shift();
      spawnEnemy(nx.type, null, nx.lane);
      live++;
      if (S.enemies[S.enemies.length-1].type === 'BOSS') S.bossSpawned = true;
    }
    // A push wave ends when their hulk dies, not when the deck clears, so it
    // MUST keep feeding — this was gated on the boss and stalled wave 4 dead.
    const loopLive = def.loop && (
      def.boss ? (S.bossSpawned && S.bossRef)
      : def.push ? (S.hulk && !S.hulk.dead)
      : true);
    if (loopLive){
      S.loopT += dt;
      if (S.loopT >= def.loop.every){
        S.loopT = 0;
        const set = def.loop.sets[S.loopIdx % def.loop.sets.length];
        S.loopIdx++;
        for (let i = 0; i < set[1]; i++)
          S.queue.push({ t: S.waveT + i*0.25, type: set[0],
                         lane: PRESET.lanes ? rndi(0, LANE_N) : undefined });
        S.queue.sort((a,b) => a.t - b.t);
      }
    }
    if (def.boss){
      if (S.bossSpawned && !S.bossRef){ S.winSeq = 2.3; S.killT = 0; S.stats.waves = 12; }
    } else if (def.push && PRESET.lanes){
      // a push wave ends when their hulk does, not when the deck is clear
      if (S.hulk && S.hulk.dead){ S.hulk.vulnerable = false; waveComplete(); }
    } else if (S.queue.length === 0 && live === 0){
      waveComplete();
    }
  } else if (S.phase === 'clear'){
    S.interT -= dt;
    if (S.interT <= 0) openDraft();
  } else if (S.phase === 'ready'){
    S.interT -= dt;
    if (S.interT <= 0) startWave(S.wave + 1);
  }
}

/* ---------------------------------------------------------------------------
   SYSTEMS — the draft
--------------------------------------------------------------------------- */
function rollCards(n){
  const avail = CARDS.filter(c => { try { return c.can(S); } catch(e){ return false; } });
  const out = [], used = {};
  for (let k = 0; k < n; k++){
    let pool = avail.filter(c => !used[c.id]);
    if (!pool.length) pool = avail;
    if (!pool.length) break;
    let total = 0;
    const ws = pool.map(c => { const w = Math.max(0.01, c.weight(S)); total += w; return w; });
    let r = Math.random() * total, idx = pool.length - 1;
    for (let i = 0; i < pool.length; i++){ r -= ws[i]; if (r <= 0){ idx = i; break; } }
    const c = pool[idx];
    used[c.id] = true;
    const inst = c.make(S);
    inst.rarity = c.rarity; inst.id = c.id;
    out.push(inst);
  }
  return out;
}
/* Three skills for one empty slot. The player picks WHICH, never WHETHER.
   Before this, a new skill was a card competing against upgrades — and losing,
   correctly: every upgrade card targets a random FILLED slot, so with one skill
   100% of upgrades landed on it and taking a second halved that while handing
   you something unupgraded. Passing was the dominant line, and a whole run
   could be played with a single ability out of a 24-combination matrix. */
function rollSkillCards(slot, n){
  const have = filledSlots(S).map(i => S.slots[i].shape);
  // never offer the shape she already swings automatically — a Cleave in a slot
  // beside the auto-attacking Cleave reads as a duplicate, not a choice
  if (S.basic) have.push(S.basic.shape);
  const shapes = SHAPE_KEYS.filter(k => have.indexOf(k) < 0);
  const pool = (shapes.length >= n ? shapes : SHAPE_KEYS).slice();
  // one option deliberately matches the element you have most of, so committing
  // to a colour across several shapes is an available build rather than a
  // consolation prize
  const counts = {};
  for (const i of filledSlots(S)) counts[S.slots[i].element] = (counts[S.slots[i].element] || 0) + 1;
  const fav = ELEMENT_KEYS.slice().sort((a, b) => (counts[b] || 0) - (counts[a] || 0))[0];
  const out = [];
  for (let k = 0; k < n && pool.length; k++){
    const shape = pool.splice((Math.random() * pool.length) | 0, 1)[0];
    const element = (k === 0 && counts[fav]) ? fav : pick(ELEMENT_KEYS);
    const sk = newSkill(shape, element);
    out.push({ id:'skillpick', rarity: k === 0 && counts[fav] ? 'rare' : 'common',
               title: skillName(sk).toUpperCase(), slot: slot, skill: sk,
               text: SHAPES[shape].desc + ', ' + ELEMENTS[element].blurb + '.',
               apply: (S) => { S.slots[slot] = sk; } });
  }
  // Shuffle: the themed option is generated first, and leaving it first would
  // mean anyone who habitually takes the left-hand card ends up mono-element by
  // accident rather than by choosing it.
  for (let i = out.length - 1; i > 0; i--){
    const j = (Math.random() * (i + 1)) | 0;
    const t = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}

function openDraft(){
  S.mode = 'draft';
  const empty = emptyUnlocked(S);
  const skillDraft = empty.length > 0;
  S.draft = { cards: skillDraft ? rollSkillCards(empty[0], 3) : rollCards(3),
              hover: -1, t: 0, chosen: -1, chooseT: 0,
              kind: skillDraft ? 'skill' : 'upgrade', slot: skillDraft ? empty[0] : -1 };
  SFX.cardDeal();
}
function pickCard(i){
  if (!S.draft || S.draft.chosen >= 0) return;
  const c = S.draft.cards[i];
  if (!c) return;
  S.draft.chosen = i; S.draft.chooseT = 0.45;
  c.apply(S);
  S.stats.cards.push(c.title);
  SFX.cardPick();
}
function closeDraft(){
  S.draft = null;
  S.mode = 'play';
  S.phase = 'ready';
  S.interT = 0.9;
}

/* ---------------------------------------------------------------------------
   SYSTEMS — run lifecycle
--------------------------------------------------------------------------- */
function startRun(){
  resetGame();
  S.mode = 'play';
  S.phase = 'ready';
  S.interT = 1.0;
  S.winSeq = 0; S.killT = 0;
  S.wave = 0;
  S.endT = 0;
  Sound.unlock();
}
function endGame(win, reason, title){
  if (S.mode === 'gameover' || S.mode === 'victory') return;
  S.mode = win ? 'victory' : 'gameover';
  S.endReason = reason;
  S.endTitle = title || (win ? 'DECK HELD' : 'BOARDED');
  S.endT = 0;
  S.player.ray = null;
  if (win){ SFX.victory(); for (let i=0;i<8;i++) pGold(rnd(300,1100), rnd(250,700), 20); }
  else { SFX.defeat(); addTrauma(0.8); S.flashRed = 0.7; }
}

/* ---------------------------------------------------------------------------
   SYSTEMS — the fixed 60Hz simulation step
--------------------------------------------------------------------------- */
function step(dt){
  S.t += dt;
  Hash.build(S.enemies);
  updatePlayer(dt);
  for (let i = 0; i < S.enemies.length; i++) updateEnemy(S.enemies[i], dt);
  separate(dt);
  for (let i = S.enemies.length - 1; i >= 0; i--) if (S.enemies[i].dead) S.enemies.splice(i, 1);
  updateLanes(dt);
  updateBolts(dt);
  updatePickups(dt);
  updateFields(dt);
  updateFx(dt);
  Particles.step(dt);
  updateWave(dt);

  // ambient life on deck: idle steam from the vents
  if (rnd() < dt * 1.6){
    const v = pick(PROPS.filter(p => p.t === 'vent' || p.t === 'lantern'));
    if (v) pSmoke(v.x, v.y, 1, 'rgba(220,215,210,0.35)', 22);
  }
  S.boiler.flash = Math.max(0, S.boiler.flash - dt);
  S.boiler.shake = Math.max(0, S.boiler.shake - dt * 1.6);
  S.boiler.gauge += dt;
  if (S.stats.comboT > 0){
    S.stats.comboT -= dt;
    if (S.stats.comboT <= 0) S.stats.combo = 0;
  }
}

/* ---------------------------------------------------------------------------
   SYSTEMS — real-time updates (run even while the sim is frozen)
--------------------------------------------------------------------------- */
function updateUI(rt){
  S.rt += rt;
  CAM.step(rt);
  // rolling frame-time readout, toggled with F3
  S.ftBuf[S.ftIdx++ % S.ftBuf.length] = rt;
  if (S.ftIdx > 1e9) S.ftIdx = 0;
  // trauma-based screen shake
  S.trauma = Math.max(0, S.trauma - TUNING.feel.traumaDecay * rt);
  const amp = S.trauma * S.trauma * TUNING.feel.shakeMax;
  const a = rnd(TAU);
  S.shakeX = Math.cos(a) * amp; S.shakeY = Math.sin(a) * amp;
  S.shakeR = (rnd(-1,1)) * S.trauma * S.trauma * 0.018;

  S.flashWhite = Math.max(0, S.flashWhite - rt * 3.2);
  S.flashRed   = Math.max(0, S.flashRed   - rt * 2.4);
  S.hintT = Math.max(0, S.hintT - rt);
  S.intro  = Math.max(0, S.intro - rt * 0.7);
  if (S.banner){
    S.banner.t += rt;
    if (S.banner.t >= S.banner.life) S.banner = null;
  }
  if (S.mode === 'draft' && S.draft){
    S.draft.t += rt;
    if (S.draft.chosen >= 0){
      S.draft.chooseT -= rt;
      if (S.draft.chooseT <= 0) closeDraft();
    }
  }
  if (typeof Ambience !== 'undefined'){ Ambience.update(rt); Music.update(); }
  if (S.mode === 'gameover' || S.mode === 'victory') S.endT += rt;
  if (S.mode === 'title') S.titleT = (S.titleT || 0) + rt;
}

/* ---------------------------------------------------------------------------
   SYSTEMS — top-level input handling per mode
--------------------------------------------------------------------------- */
function handleModeInput(){
  if (keyHit('f3')) S.showFps = !S.showFps;
  // nudge the camera bake live — one degree a press
  if (keyHit('[') || keyHit(']')){
    CAM.pitch = clamp(CAM.pitch + (keyHit(']') ? 1 : -1) * (Math.PI / 180), 0.35, 1.35);
    CAM.recompute();
    if (!CAM.follow) buildDeck();
    S.showFps = true;
    S.volToast = 0;
  }
  if (keyHit('m')){ Sound.toggleMute(); S.volToast = 1.6; }
  if (keyHit('-') || keyHit('_')){ Sound.setVol(Sound.vol - 0.1); S.volToast = 1.6; }
  if (keyHit('=') || keyHit('+')){ Sound.setVol(Sound.vol + 0.1); S.volToast = 1.6; }
  S.volToast = Math.max(0, (S.volToast || 0) - 0.016);

  if (S.mode === 'title'){
    if (keyHit('enter') || keyHit('space') || Input.clicked) startRun();
  } else if (S.mode === 'play'){
    if (keyHit('escape') || keyHit('p')){ S.mode = 'pause'; endRay(); }
  } else if (S.mode === 'pause'){
    if (keyHit('escape') || keyHit('p')) S.mode = 'play';
    if (keyHit('q')){ S.mode = 'title'; }
  } else if (S.mode === 'draft'){
    updateDraftHover();
    if (S.draft && S.draft.chosen < 0){
      if (keyHit('1')) pickCard(0);
      if (keyHit('2')) pickCard(1);
      if (keyHit('3')) pickCard(2);
      if (Input.clicked && S.draft.hover >= 0) pickCard(S.draft.hover);
    }
  } else if (S.mode === 'gameover' || S.mode === 'victory'){
    if (S.endT > 0.8 && (keyHit('r') || keyHit('enter') || keyHit('space') || Input.clicked)) startRun();
  }
}

/* ---------------------------------------------------------------------------
   7. BOOT — fixed timestep with an accumulator, render decoupled
--------------------------------------------------------------------------- */
const DT = 1 / FEEL.simHz;
let lastT = 0, acc = 0;
S.rt = 0; S.titleT = 0; S.winSeq = 0; S.killT = 0; S.endT = 0; S.phase = 'idle';
S.endReason = ''; S.endTitle = ''; S.bossSpawned = false; S.stopUntil = 0;
S.ftBuf = new Float32Array(90); S.ftIdx = 0; S.showFps = false; S.loopIdx = 0; S.volToast = 0;

function frame(now){
  requestAnimationFrame(frame);
  if (!lastT) lastT = now;
  let real = (now - lastT) / 1000;
  lastT = now;
  if (real > 0.1) real = 0.1;

  handleModeInput();

  let ran = 0;
  if (S.mode === 'play'){
    if (S.hitStop > 0){
      S.hitStop -= real;                       // freezes the sim, not the frame
    } else {
      let scale = 1;
      if (S.slowmo > 0){ S.slowmo -= real; scale = TUNING.feel.waveClearSlowmo; }
      acc += real * scale;
      while (acc >= DT && ran < 10){ step(DT); acc -= DT; ran++; }
      if (acc > DT * 10) acc = 0;
    }
  } else {
    acc = 0;
  }

  updateUI(real);
  render(real);

  if (ran > 0 || S.mode !== 'play') Input.pressed.clear();
  Input.clicked = false;
  Input.rightClicked = false;
}
