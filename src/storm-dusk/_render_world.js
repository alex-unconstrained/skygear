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
  band(_cloudFar,  'env_clouds_far',  hz - h * 0.10, h * 0.20, 7,  0.75);
  band(_cloudNear, 'env_clouds_near', hz - h * 0.02, h * 0.26, 17, 0.85);

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

function drawEnvelope(){
  const env = Assets.get('env_envelope');
  const w = View.w, h = View.h;
  if (env){ ctx.drawImage(env, 0, 0, w, h * 0.42); return; }
  ctx.save();
  // the underside of our own gas bag, filling the top of the frame
  const eh = h * 0.44;
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
      if (p.t !== 'lantern') continue;
      const g = groundEllipsePath(p.x, p.y + 30, 210);
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      const rg = ctx.createRadialGradient(g.p.x, g.p.y, 1, g.p.x, g.p.y, Math.max(g.rx, 1));
      rg.addColorStop(0, hexToRgba(PAL.lantern, 0.30));
      rg.addColorStop(1, hexToRgba(PAL.lantern, 0));
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
