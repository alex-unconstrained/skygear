/* ---------------------------------------------------------------------------
   ENVIRONMENT — flat screen-space parallax layers (§2.7, §4.4)
--------------------------------------------------------------------------- */
let _skyCv = null, _cloudFar = null, _cloudNear = null, _vigCv = null, _redCv = null;

function buildSky(){
  const w = Math.max(2, Math.round(View.w)), h = Math.max(2, Math.round(View.h));
  _skyCv = document.createElement('canvas'); _skyCv.width = w; _skyCv.height = h;
  const c = _skyCv.getContext('2d');
  const g = c.createLinearGradient(0, 0, 0, h);
  g.addColorStop(0.00, '#100E1C');
  g.addColorStop(0.22, PAL.skyDeep);
  g.addColorStop(0.55, PAL.skyMid);
  g.addColorStop(0.80, '#3A3358');
  g.addColorStop(1.00, '#4A3A4E');
  c.fillStyle = g; c.fillRect(0, 0, w, h);
  // one dramatic moonbreak, upper-left — the cool key light of the whole scene
  const mx = w * 0.24, my = h * 0.16;
  const mg = c.createRadialGradient(mx, my, 4, mx, my, Math.max(w, h) * 0.5);
  mg.addColorStop(0,    hexToRgba(PAL.moon, 0.75));
  mg.addColorStop(0.10, hexToRgba(PAL.moon, 0.28));
  mg.addColorStop(0.34, hexToRgba(PAL.moon, 0.07));
  mg.addColorStop(1,    hexToRgba(PAL.moon, 0));
  c.fillStyle = mg; c.fillRect(0, 0, w, h);
  c.fillStyle = hexToRgba('#E8EEF8', 0.9);
  c.beginPath(); c.arc(mx, my, Math.max(9, h * 0.026), 0, TAU); c.fill();
  // warm horizon ember, lower-right
  const eg = c.createRadialGradient(w * 0.86, h * 0.74, 4, w * 0.86, h * 0.74, w * 0.5);
  eg.addColorStop(0, hexToRgba(PAL.lantern, 0.20));
  eg.addColorStop(1, hexToRgba(PAL.lantern, 0));
  c.fillStyle = eg; c.fillRect(0, 0, w, h);
  // darkest at the top corners for a natural vignette
  const cg = c.createRadialGradient(w/2, h*0.55, Math.min(w,h)*0.25, w/2, h*0.55, Math.max(w,h)*0.8);
  cg.addColorStop(0, 'rgba(13,11,18,0)'); cg.addColorStop(1, 'rgba(13,11,18,0.72)');
  c.fillStyle = cg; c.fillRect(0, 0, w, h);

  const strip = (hh, tint, alpha, bold) => {
    const cn = document.createElement('canvas');
    cn.width = 1024; cn.height = hh;
    const c2 = cn.getContext('2d');
    for (let i = 0; i < (bold ? 16 : 22); i++){
      const x = (i * 137.5) % 1024, y = hh * (bold ? 0.55 : 0.6) + Math.sin(i * 2.3) * hh * 0.2;
      const s = (bold ? 90 : 58) * (0.6 + ((i * 37) % 10) / 10);
      c2.globalAlpha = alpha * (0.5 + ((i * 53) % 10) / 20);
      c2.fillStyle = tint;
      c2.beginPath();
      for (let p = 0; p < 5; p++)
        c2.ellipse(x + (p - 2) * s * 0.5, y + Math.sin(p * 1.7 + i) * s * 0.12,
                   s * (0.5 + (p % 3) * 0.22), s * 0.34, 0, 0, TAU);
      c2.fill();
    }
    return cn;
  };
  _cloudFar  = strip(160, '#3E3A5E', 0.55, false);
  _cloudNear = strip(200, '#4A3F5C', 0.6, true);

  const mk = (inner, outer, r0, r1) => {
    const cn = document.createElement('canvas'); cn.width = w; cn.height = h;
    const c2 = cn.getContext('2d');
    const vg = c2.createRadialGradient(w/2, h/2, Math.min(w,h)*r0, w/2, h/2, Math.max(w,h)*r1);
    vg.addColorStop(0, inner); vg.addColorStop(1, outer);
    c2.fillStyle = vg; c2.fillRect(0, 0, w, h);
    return cn;
  };
  _vigCv = mk('rgba(13,11,18,0)', 'rgba(13,11,18,0.66)', 0.30, 0.76);
  _redCv = mk('rgba(255,61,46,0)', 'rgba(255,61,46,1)', 0.24, 0.70);
}

function drawEnvironment(){
  const w = View.w, h = View.h;
  const sky = Assets.get('env_sky');
  if (sky) ctx.drawImage(sky, 0, 0, w, h);
  else ctx.drawImage(_skyCv, 0, 0, w, h);

  const hz = CAM.horizonY();
  // parallax cloud seas, drifting past the ship
  const band = (img, key, y, hh, spd, alpha) => {
    const a = Assets.get(key) || img;
    const tw = w * 1.6;
    let off = (S.rt * spd) % tw;
    ctx.save(); ctx.globalAlpha = alpha;
    ctx.drawImage(a, -off, y, tw, hh);
    ctx.drawImage(a, -off + tw, y, tw, hh);
    ctx.restore();
  };
  /* v12 — the ship reads as moving, or it does not.
     Asked directly after the first v11 playthrough: what am I supposed to be
     looking at to see that this thing is flying? The honest answer was "two
     cloud bands drifting at 7 and 17 pixels a second, and a distant escort" —
     which is to say, nothing. Speeds roughly doubled, and they now bob, so the
     horizon is never still. */
  band(_cloudFar,  'env_clouds_far',  hz - h * 0.10 + Math.sin(S.rt * 0.13) * h * 0.006,
       h * 0.20, 16, 0.75);
  band(_cloudNear, 'env_clouds_near', hz - h * 0.02 + Math.sin(S.rt * 0.21 + 1.7) * h * 0.010,
       h * 0.26, 34, 0.85);

  // a distant escort, running with us
  const esc = Assets.get('env_airship');
  ctx.save();
  ctx.globalAlpha = 0.55;
  const ex = w * 0.5 + Math.sin(S.rt * 0.06) * w * 0.3, ey = hz - h * 0.09;
  if (esc) ctx.drawImage(esc, ex - 90, ey - 45, 180, 90);
  else {
    ctx.fillStyle = '#171425';
    ell(ex, ey, 76, 26, -0.06); ctx.fill();
    ell(ex + 6, ey + 22, 40, 9, -0.06); ctx.fill();
    ctx.fillStyle = PAL.lantern;
    for (let i = -2; i <= 2; i++){ circ(ex + i * 17, ey + 22, 1.8); ctx.fill(); }
  }
  ctx.restore();
}

/* THE AIRSTREAM (v12).

   The strongest available cue that a vehicle is moving is not the scenery — it
   is stuff going past you. Streaks of vapour and grit blow along the keel from
   bow to stern, in screen space, over the planking. Cheap: one path, a few dozen
   line segments, no allocation, no per-entity cost.

   Direction is deliberate. Everything here travels TOWARD the camera, which is
   the same direction the deck's own perspective flows, so it reinforces depth
   instead of fighting it. Speed is tied to nothing in the simulation — the ship
   has one speed and it is "fast" — but the streaks thin out with the VFX
   setting and stop entirely under reduced motion, because a permanent
   full-screen drift is exactly the thing that setting exists for. */
const AIRSTREAM = { n: 46, len: 0.10, speed: 1.55 };
function drawAirstream(over){
  const q = Settings.get('vfx');
  if (q <= 0.25 || Settings.motionReduced()) return;
  const w = View.w, h = View.h;
  const hz = CAM.horizonY();
  const n = Math.round(AIRSTREAM.n * q * (over ? 0.35 : 1));
  const y0 = over ? hz + h * 0.04 : hz;
  const span = (h - y0) * (over ? 1.0 : 0.98);
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  ctx.lineCap = 'round';
  for (let i = 0; i < n; i++){
    // a stable pseudo-random lane per streak, cycling down the screen
    const seed = i * 0.6180339887;
    const lane = (seed % 1);
    const speed = AIRSTREAM.speed * (0.55 + (i % 7) / 7 * 0.9);
    const t = (S.rt * speed * 0.35 + lane) % 1;
    // perspective: slow and short near the horizon, fast and long near the camera
    const depth = Math.pow(t, 1.7);
    const y = y0 + span * depth;
    const spread = 0.06 + depth * 0.94;
    const x = w * (0.5 + (lane - 0.5) * 2.15 * spread) + Math.sin(seed * 31.7) * w * 0.04;
    const L = h * AIRSTREAM.len * (0.25 + depth);
    const a = (over ? 0.10 : 0.16) * (1 - Math.abs(depth - 0.55) * 0.9) * q;
    if (a <= 0.004) continue;
    ctx.globalAlpha = a;
    ctx.strokeStyle = i % 5 === 0 ? '#C6D4EA' : '#8FA6C9';
    ctx.lineWidth = 1 + depth * 2.4;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x + (x - w * 0.5) * 0.06, y + L);
    ctx.stroke();
  }
  ctx.restore();
}

// The bow rises at the far end of the deck; the envelope hangs over the near edge.
function drawBowPiece(){
  const bow = Assets.get('env_bow');
  const D = TUNING.deck;
  const p = CAM.project(D.cx, D.cy - D.h/2 - D.bow, 0);
  const wpx = D.w * p.k * 2.0, hpx = wpx * 0.62;
  if (bow){ ctx.drawImage(bow, p.x - wpx/2, p.y - hpx * 0.92, wpx, hpx); return; }
  ctx.save();
  ctx.translate(p.x, p.y);
  ctx.lineJoin = 'round';
  const s = p.k * 2.1;
  ctx.scale(s, s);
  // prow mass
  ctx.beginPath();
  ctx.moveTo(-150, 8); ctx.quadraticCurveTo(-96, -74, 0, -92);
  ctx.quadraticCurveTo(96, -74, 150, 8);
  ctx.quadraticCurveTo(0, 30, -150, 8);
  ctx.closePath();
  fillStroke('#221B22', PAL.ink, 5);
  ctx.strokeStyle = PAL.brass; ctx.lineWidth = 4;
  ctx.beginPath(); ctx.moveTo(-132, 0); ctx.quadraticCurveTo(0, -66, 132, 0); ctx.stroke();
  // figurehead
  ctx.beginPath();
  ctx.moveTo(0, -92); ctx.quadraticCurveTo(-20, -128, 0, -150);
  ctx.quadraticCurveTo(20, -128, 0, -92); ctx.closePath();
  fillStroke(PAL.brass, PAL.ink, 5);
  // navigation lanterns
  for (const lx of [-112, 112]){
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    drawGlow(lx, -14, 34, lx < 0 ? PAL.danger : PAL.copper, 0.8);
    ctx.restore();
    circ(lx, -14, 7); fillStroke(lx < 0 ? PAL.danger : PAL.copper, PAL.ink, 4);
  }
  ctx.restore();
}

/* The envelope hangs over the top of the frame, which is also where the far end
   of the deck is — and the far end is where boarders come from. So its lower
   edge is faded out in a cached pass rather than trusting the asset to do it:
   the ship still frames the shot, but you can always see what is walking at you. */
let _envCv = null, _envKey = '';
function envelopeSprite(img, w, h){
  const key = w + 'x' + h;
  if (_envCv && _envKey === key) return _envCv;
  _envKey = key;
  _envCv = document.createElement('canvas');
  _envCv.width = Math.max(2, Math.round(w)); _envCv.height = Math.max(2, Math.round(h));
  const c = _envCv.getContext('2d');
  c.drawImage(img, 0, 0, _envCv.width, _envCv.height);
  const g = c.createLinearGradient(0, _envCv.height * 0.42, 0, _envCv.height);
  g.addColorStop(0, 'rgba(0,0,0,1)');
  g.addColorStop(1, 'rgba(0,0,0,0)');
  c.globalCompositeOperation = 'destination-in';
  c.fillStyle = g;
  c.fillRect(0, 0, _envCv.width, _envCv.height);
  return _envCv;
}
/* How much of the frame our own gas bag is allowed to own (v12).

   Reported after the first v11 playthrough: the envelope sits across the upper
   third and obscures the view as you move down the deck. It is worse than it
   sounds, because the top of the screen is the BOW — the direction boarders
   arrive from. So the thing framing the shot was hiding the threat.

   It is not removed, because it is most of what says "you are standing on an
   airship". It is now tied to the camera: at the bow, where the envelope really
   is overhead, it draws in full; as the camera moves toward the stern it thins
   and lifts out of frame. At the far end of the deck it is a suggestion.

   The player can also turn it down to nothing in Settings — it rides the same
   VFX dial as everything else cosmetic. */
function envelopeFade(){
  const D = TUNING.deck;
  const top = D.cy - D.h / 2, bot = D.cy + D.h / 2;
  const t = clamp((CAM.focusY - top) / Math.max(1, bot - top), 0, 1);
  // 1 at the bow, 0.28 at the stern; eased so the change is not a wipe
  const k = 1 - Math.pow(t, 0.85);
  return { a: 0.28 + 0.72 * k, h: 0.20 + 0.14 * k };
}

function drawEnvelope(){
  const env = Assets.get('env_envelope');
  const w = View.w, h = View.h;
  const fade = envelopeFade();
  if (env){
    const eh = h * fade.h;
    ctx.save();
    ctx.globalAlpha = fade.a;
    ctx.drawImage(envelopeSprite(env, w, eh), 0, 0, w, eh);
    ctx.restore();
    return;
  }
  ctx.save();
  ctx.globalAlpha = fade.a;
  drawEnvelopeProcedural(w, h, fade);
  ctx.restore();
}
function drawEnvelopeProcedural(w, h, fade){
  ctx.save();
  // the underside of our own gas bag, filling the top of the frame
  const eh = h * (fade.h * 1.3);
  const g = ctx.createLinearGradient(0, -eh * 0.4, 0, eh);
  g.addColorStop(0, '#241E33'); g.addColorStop(0.6, '#1C1828'); g.addColorStop(1, 'rgba(20,18,27,0)');
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.moveTo(-w * 0.1, -eh);
  ctx.quadraticCurveTo(w * 0.5, eh * 1.5, w * 1.1, -eh);
  ctx.lineTo(w * 1.1, -eh * 1.2); ctx.lineTo(-w * 0.1, -eh * 1.2);
  ctx.closePath(); ctx.fill();
  // brass ribs
  ctx.strokeStyle = hexToRgba(PAL.brass, 0.5); ctx.lineWidth = 5;
  for (let i = -3; i <= 3; i++){
    const x = w * 0.5 + i * w * 0.15;
    ctx.beginPath();
    ctx.moveTo(x, -eh);
    ctx.quadraticCurveTo(x + i * 8, eh * 0.55, x + i * 16, eh * (1 - Math.abs(i) * 0.13));
    ctx.stroke();
  }
  // netting + rigging dropping toward the viewer
  ctx.strokeStyle = 'rgba(13,11,18,0.7)'; ctx.lineWidth = 3;
  for (let i = -6; i <= 6; i++){
    const x = w * 0.5 + i * w * 0.085;
    ctx.beginPath();
    ctx.moveTo(x, -eh * 0.2); ctx.lineTo(x + i * 30, eh * 1.35);
    ctx.stroke();
  }
  // netting across the canvas
  ctx.strokeStyle = 'rgba(13,11,18,0.35)'; ctx.lineWidth = 2;
  for (let i = 0; i < 5; i++){
    const y = -eh * 0.5 + i * eh * 0.34;
    ctx.beginPath();
    ctx.moveTo(-w * 0.1, y);
    ctx.quadraticCurveTo(w * 0.5, y + eh * 0.55, w * 1.1, y);
    ctx.stroke();
  }
  // storm light grazing the canvas
  const lg = ctx.createLinearGradient(0, -eh, w * 0.7, eh);
  lg.addColorStop(0, hexToRgba(PAL.moon, 0.16)); lg.addColorStop(1, hexToRgba(PAL.moon, 0));
  ctx.fillStyle = lg;
  ctx.beginPath();
  ctx.moveTo(-w * 0.1, -eh);
  ctx.quadraticCurveTo(w * 0.5, eh * 1.5, w * 1.1, -eh);
  ctx.lineTo(w * 1.1, -eh * 1.2); ctx.lineTo(-w * 0.1, -eh * 1.2);
  ctx.closePath(); ctx.fill();
  ctx.restore();
}

/* ---------------------------------------------------------------------------
   THE DECK — code-drawn projected quads (§2.6). Static under a fixed camera,
   so it is baked to a screen-sized layer and rebuilt only on resize.
--------------------------------------------------------------------------- */
function deckOutline(inset){
  const D = TUNING.deck;
  const hw = D.w/2 - inset, hh = D.h/2 - inset, r = Math.max(4, D.r - inset);
  const pts = [];
  const arc = (cx, cy, a0, a1) => {
    for (let i = 0; i <= 5; i++){
      const a = lerp(a0, a1, i/5);
      pts.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]);
    }
  };
  const L = D.cx - hw, R = D.cx + hw, T = D.cy - hh, B = D.cy + hh;
  // far edge: a prow that comes to a soft point
  pts.push([L + r, T]);
  for (let i = 1; i <= 8; i++){
    const t = i / 8;
    const x = lerp(L + r, R - r, t);
    const bulge = Math.sin(t * Math.PI) * (D.bow - inset * 0.6);
    pts.push([x, T - bulge]);
  }
  arc(R - r, T + r, -Math.PI/2, 0);
  pts.push([R, B - r]);
  arc(R - r, B - r, 0, Math.PI/2);
  // near edge: shallow transom
  for (let i = 1; i <= 5; i++){
    const t = i / 5;
    pts.push([lerp(R - r, L + r, t), B + Math.sin(t * Math.PI) * 26]);
  }
  arc(L + r, B - r, Math.PI/2, Math.PI);
  pts.push([L, T + r]);
  arc(L + r, T + r, Math.PI, Math.PI * 1.5);
  return pts;
}
function pathGround(pts){
  ctx.beginPath();
  for (let i = 0; i < pts.length; i++){
    const p = CAM.project(pts[i][0], pts[i][1], 0);
    i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y);
  }
  ctx.closePath();
}

let _deckCv = null, _grainCv = null;

/* The deck is code-drawn (spec §2.6) but it has to speak the same language as
   the painted assets standing on it. Flat fills read as vector next to hand-
   painted brass, so the planks get a baked grain tile, softened seams and
   irregular wear. Same idea as the two-source light pass on the sprites: one
   treatment applied everywhere so the layers agree. */
function grainTile(){
  if (_grainCv) return _grainCv;
  const N = 256;
  _grainCv = document.createElement('canvas');
  _grainCv.width = _grainCv.height = N;
  const c = _grainCv.getContext('2d');
  // long directional strokes, like brushed timber
  for (let i = 0; i < 900; i++){
    const x = Math.random() * N, y = Math.random() * N;
    const len = 12 + Math.random() * 46;
    const a = (Math.random() - 0.5) * 0.22 + Math.PI / 2;
    const dark = Math.random() < 0.55;
    c.globalAlpha = 0.018 + Math.random() * 0.05;
    c.strokeStyle = dark ? '#0D0B12' : '#8A7A6E';
    c.lineWidth = 0.6 + Math.random() * 2.2;
    c.beginPath();
    c.moveTo(x, y);
    c.lineTo(x + Math.cos(a) * len, y + Math.sin(a) * len);
    c.stroke();
  }
  // knots and scuffs
  for (let i = 0; i < 90; i++){
    c.globalAlpha = 0.03 + Math.random() * 0.06;
    c.fillStyle = Math.random() < 0.5 ? '#0D0B12' : '#6E4A2F';
    c.beginPath();
    c.ellipse(Math.random()*N, Math.random()*N, 1.5 + Math.random()*7,
              1 + Math.random()*3, Math.random()*3.14, 0, Math.PI*2);
    c.fill();
  }
  return _grainCv;
}

// With a follow camera the deck cannot be baked to a screen-space layer, so it
// is drawn live. It is ~60 path ops — trivial next to the billboard crowd.
function drawDeckLive(){
  withCtx(ctx, () => paintDeck(View.w, View.h));
}
function buildDeck(){
  const w = Math.max(2, Math.round(View.w)), h = Math.max(2, Math.round(View.h));
  _deckCv = document.createElement('canvas'); _deckCv.width = w; _deckCv.height = h;
  withCtx(_deckCv.getContext('2d'), () => paintDeck(w, h));
}
function paintDeck(w, h){
  {
    const D = TUNING.deck;
    ctx.lineJoin = 'round';
    // hull mass below the deck line, so the ship reads as a solid object in air
    ctx.save();
    pathGround(deckOutline(-30));
    ctx.translate(0, 26);
    fillStroke('#161220', PAL.ink, 9);
    ctx.restore();

    // deck surface
    pathGround(deckOutline(0));
    ctx.save();
    ctx.clip();
    ctx.fillStyle = PAL.timber;
    ctx.fillRect(0, 0, w, h);
    // planks run bow -> stern, drawn as projected quads
    const step = 46;
    for (let x = D.cx - D.w/2; x < D.cx + D.w/2; x += step){
      const v = ((Math.abs(x * 7919)) % 100) / 100;
      const a = CAM.project(x, D.cy - D.h/2 - D.bow, 0);
      const b = CAM.project(x + step, D.cy - D.h/2 - D.bow, 0);
      const c = CAM.project(x + step, D.cy + D.h/2 + 40, 0);
      const d = CAM.project(x, D.cy + D.h/2 + 40, 0);
      ctx.beginPath();
      ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.lineTo(c.x, c.y); ctx.lineTo(d.x, d.y);
      ctx.closePath();
      ctx.fillStyle = v > 0.66 ? PAL.timberLite : (v > 0.33 ? PAL.timber : PAL.timberDark);
      ctx.globalAlpha = 0.55; ctx.fill(); ctx.globalAlpha = 1;
      ctx.strokeStyle = hexToRgba(PAL.ink, 0.55); ctx.lineWidth = 2.6;
      ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(d.x, d.y); ctx.stroke();
      ctx.strokeStyle = hexToRgba('#8A7A6E', 0.10); ctx.lineWidth = 1.2;
      ctx.beginPath(); ctx.moveTo(a.x + 1.5, a.y); ctx.lineTo(d.x + 1.5, d.y); ctx.stroke();
    }
    // painterly grain over the whole deck, tiled in screen space
    const g = grainTile();
    ctx.save();
    ctx.globalAlpha = 0.5;
    const pat = ctx.createPattern(g, 'repeat');
    if (pat){ ctx.fillStyle = pat; ctx.fillRect(0, 0, w, h); }
    ctx.restore();

    // butt joints
    ctx.strokeStyle = hexToRgba(PAL.ink, 0.45); ctx.lineWidth = 1.6;
    for (let y = D.cy - D.h/2; y < D.cy + D.h/2; y += 150){
      const a = CAM.project(D.cx - D.w/2, y, 0), b = CAM.project(D.cx + D.w/2, y, 0);
      ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
    }
    // brass inlay ring amidships, marking the Boiler's ground
    for (const r of [150, 162]){
      const g = groundEllipsePath(TUNING.boiler.x, TUNING.boiler.y, r);
      ctx.strokeStyle = hexToRgba(PAL.brass, r === 150 ? 0.30 : 0.14);
      ctx.lineWidth = (r === 150 ? 7 : 3) * g.p.k;
      ctx.stroke();
    }
    // the deck sits dark; light pools only under the lanterns
    const dark = ctx.createLinearGradient(0, CAM.horizonY(), 0, h);
    dark.addColorStop(0, 'rgba(13,11,18,0.80)');
    dark.addColorStop(0.45, 'rgba(13,11,18,0.48)');
    dark.addColorStop(1, 'rgba(13,11,18,0.64)');
    ctx.fillStyle = dark; ctx.fillRect(0, 0, w, h);
    for (const p of PROPS){
      const lit = LIGHT_PROPS[p.t];
      if (!lit || p.dead) continue;
      const g = groundEllipsePath(p.x, p.y + 30, lit);
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      const rg = ctx.createRadialGradient(g.p.x, g.p.y, 1, g.p.x, g.p.y, Math.max(g.rx, 1));
      const warm = p.t === 'brazier' ? PAL.fire : PAL.lantern;
      rg.addColorStop(0, hexToRgba(warm, p.t === 'brazier' ? 0.26 : 0.30));
      rg.addColorStop(1, hexToRgba(warm, 0));
      ctx.fillStyle = rg; ctx.fill();
      ctx.restore();
    }
    ctx.restore();

    // gunwale
    pathGround(deckOutline(0));
    ctx.strokeStyle = PAL.ink; ctx.lineWidth = 10; ctx.stroke();
    pathGround(deckOutline(7));
    ctx.strokeStyle = '#3A2A2E'; ctx.lineWidth = 7; ctx.stroke();
    pathGround(deckOutline(11));
    ctx.strokeStyle = hexToRgba(PAL.brass, 0.7); ctx.lineWidth = 2.6; ctx.stroke();

    // railing stanchions along both rails
    for (const side of [-1, 1]){
      const x = D.cx + side * (D.w/2 - 4);
      for (let y = D.cy - D.h/2 + 150; y < D.cy + D.h/2 - 120; y += 110){
        const b = CAM.project(x, y, 0), t = CAM.project(x, y, 34);
        ctx.strokeStyle = PAL.ink; ctx.lineWidth = 7 * b.k;
        ctx.beginPath(); ctx.moveTo(b.x, b.y); ctx.lineTo(t.x, t.y); ctx.stroke();
        ctx.strokeStyle = PAL.brass; ctx.lineWidth = 3 * b.k;
        ctx.beginPath(); ctx.moveTo(b.x, b.y); ctx.lineTo(t.x, t.y); ctx.stroke();
      }
    }
  }
}
function onViewportChanged(){
  _spriteCache.clear();
  buildSky();
  CAM.recompute();
  if (!CAM.follow) buildDeck();   // a moving camera draws the deck live instead
}
