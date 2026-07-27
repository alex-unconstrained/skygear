/* ---------------------------------------------------------------------------
   BILLBOARDS — every entity is a depth-scaled sprite standing on the deck,
   drawn far -> near (painter's algorithm, §2).
--------------------------------------------------------------------------- */
const ANCHOR = 0.92;      // feet sit here in the sprite, per §2.4
const FIG = 0.86;         // fraction of sprite height the figure occupies

const _tintCache = new Map();
function tintVersion(img, col){
  let byCol = _tintCache.get(img);
  if (!byCol){ byCol = new Map(); _tintCache.set(img, byCol); }
  let cn = byCol.get(col);
  if (cn) return cn;
  cn = document.createElement('canvas');
  cn.width = img.width || img.naturalWidth; cn.height = img.height || img.naturalHeight;
  const c = cn.getContext('2d');
  c.drawImage(img, 0, 0, cn.width, cn.height);
  c.globalCompositeOperation = 'source-atop';
  c.fillStyle = col; c.fillRect(0, 0, cn.width, cn.height);
  byCol.set(col, cn);
  return cn;
}
function whiteVersion(img){ return tintVersion(img, '#FFFFFF'); }

/* A "sprite" here is either a whole image (a still, or a procedural canvas) or
   one cell of an animation strip. Strips are kept whole — one decoded image
   per cycle rather than thirteen — so a frame is described by a source rect
   into it. Slicing the frames into their own canvases instead would cost about
   7 MB of RAM per cycle and there are nineteen of them.

   `width`/`height` on a frame are the FRAME's, not the strip's, so every
   aspect-ratio and anchor calculation downstream is unchanged. */
function spriteSrc(s){ return s.strip ? s.strip : s; }
function drawSprite(s, dx, dy, dw, dh, tint){
  if (s.strip){
    const img = tint ? tintVersion(s.strip, tint) : s.strip;
    ctx.drawImage(img, s.sx, 0, s.width, s.height, dx, dy, dw, dh);
  } else {
    ctx.drawImage(tint ? tintVersion(s, tint) : s, dx, dy, dw, dh);
  }
}

/* ---------------------------------------------------------------------------
   OCCLUSION X-RAY
   The first playtest killed v2 on exactly this: the Boiler you are defending
   stood between you and the boarders attacking its far side, so the fight you
   most needed to see was the one you could not. Tall geometry now registers as
   an occluder, and anything hidden behind it is re-drawn on top as a flat
   silhouette. Standard for any three-quarter action game; not optional here.
--------------------------------------------------------------------------- */
const _occluders = [];      // {x0,x1,y0,y1, depth} screen rects, rebuilt per frame
const _xrayQueue = [];      // entities to re-draw as silhouettes

function resetOccluders(){ _occluders.length = 0; _xrayQueue.length = 0; }

// register a screen-space box that hides what is behind it
function addOccluder(sx, sy, w, h, groundY){
  if (!PRESET.xray) return;
  _occluders.push({ x0: sx - w * 0.5, x1: sx + w * 0.5, y0: sy - h, y1: sy, gy: groundY });
}

// is this entity's silhouette meaningfully covered by nearer, taller geometry?
function isOccluded(sx, top, w, h, groundY){
  if (!PRESET.xray || !_occluders.length) return false;
  const ax0 = sx - w * 0.30, ax1 = sx + w * 0.30;
  const ay0 = top + h * 0.12, ay1 = top + h * 0.92;
  const area = Math.max(1, (ax1 - ax0) * (ay1 - ay0));
  let covered = 0;
  for (const o of _occluders){
    if (o.gy <= groundY) continue;                 // only things NEARER can occlude
    const ox = Math.min(ax1, o.x1) - Math.max(ax0, o.x0);
    if (ox <= 0) continue;
    const oy = Math.min(ay1, o.y1) - Math.max(ay0, o.y0);
    if (oy <= 0) continue;
    covered += ox * oy;
    if (covered / area > 0.32) return true;        // a third hidden is enough
  }
  return false;
}

/* Solid silhouettes merge into one unreadable mass the moment two boarders
   overlap — which is exactly when you need to count them. So each hidden body
   is drawn as a coloured RIM around a dark interior: the outline is built from
   offset copies, then the middle is punched back out. Shapes stay countable
   even in a pile, and it never reads as a real, in-front enemy. */
const _xrayOffsets = [[-1,0],[1,0],[0,-1],[0,1]];
function drawXrayPass(){
  if (!_xrayQueue.length) return;
  ctx.save();
  for (const q of _xrayQueue){
    if (!isOccluded(q.x + q.w / 2, q.y, q.w, q.h, q.gy)) continue;
    // Outline width is CAPPED in screen pixels. Scaling it with the sprite made
    // a close-up boarder's rim spread ~18px in eight directions, which stacked
    // into one solid orange blob instead of an outline.
    const s = clamp(q.w * 0.012, 1.5, 4.5);
    ctx.globalAlpha = 0.42;
    for (const o of _xrayOffsets)
      drawSprite(q.img, q.x + o[0] * s, q.y + o[1] * s, q.w, q.h, q.col);
    ctx.globalAlpha = 0.88;
    drawSprite(q.img, q.x, q.y, q.w, q.h, '#140F1A');
    ctx.globalAlpha = 0.22;
    drawSprite(q.img, q.x, q.y, q.w, q.h, q.col);
  }
  ctx.restore();
}

function drawBillboard(img, x, y, worldH, o){
  o = o || {};
  const p = CAM.project(x, y, 0);
  // Procedural sprites are authored to a known frame; delivered art is measured
  // on load. Either way `worldH` is the height of the FIGURE, not the canvas,
  // so a generous crop never renders smaller than a tight one.
  const m = img.__meta;
  const fig = m ? m.fig : FIG, anch = m ? m.anchor : ANCHOR, cxf = m ? m.cx : 0.5;
  const hpx = (worldH / fig) * p.k * (o.scale || 1);
  const wpx = hpx * (img.width / img.height);
  const bx = p.x - wpx * cxf + (o.dx || 0);
  const by = p.y - hpx * anch - (o.lift || 0) * p.k;
  ctx.save();
  if (o.alpha !== undefined) ctx.globalAlpha = o.alpha;
  const tint = o.flash ? '#FFFFFF' : null;
  if (o.mirror){
    ctx.translate(p.x + (o.dx || 0), 0);
    ctx.scale(-1, 1);
    drawSprite(img, -wpx * (1 - cxf), by, wpx, hpx, tint);
  } else {
    drawSprite(img, bx, by, wpx, hpx, tint);
  }
  ctx.restore();
  return { p, wpx, hpx, top: by };
}

function entityShadow(x, y, r, alpha){
  const sh = Assets.get('shadow_blob');
  const g = groundEllipsePath(x, y, r);
  if (sh){
    ctx.save();
    ctx.globalAlpha = (alpha === undefined ? 0.55 : alpha);
    ctx.drawImage(sh, g.p.x - g.rx, g.p.y - g.ry, g.rx * 2, g.ry * 2);
    ctx.restore();
    return;
  }
  ctx.save();
  ctx.globalAlpha = alpha === undefined ? 0.5 : alpha;
  const rg = ctx.createRadialGradient(g.p.x, g.p.y, 0, g.p.x, g.p.y, Math.max(1, g.rx));
  rg.addColorStop(0, 'rgba(6,5,10,0.85)');
  rg.addColorStop(0.65, 'rgba(6,5,10,0.42)');
  rg.addColorStop(1, 'rgba(6,5,10,0)');
  ctx.fillStyle = rg; ctx.fill();
  ctx.restore();
}

// which of the two authored views, and do we mirror? (§2.2)
function viewFor(facing, canAttack, attacking){
  const front = Math.sin(facing) > -0.15;      // +y is toward the camera
  const mirror = Math.cos(facing) > 0;         // art faces left by default
  let view = front ? 'front_idle' : 'back_idle';
  if (attacking && canAttack) view = front ? 'front_attack' : 'back_idle';
  return { view, mirror };
}

/* --- props --------------------------------------------------------------- */
// v11 stands the keg up: 82 -> 100. It is tier-0 survival information now
// rather than dressing, and at 82 it read as a footstool next to an 84-unit
// crate that does far less to you.
const PROP_H = { crate: 84, crates: 148, barrel: V11 ? 100 : 82, rope: 30, cannon: 96,
                 mast: 340, lantern: 200, vent: 52, hatch: 44, ballista: 118,
                 brazier: 116 };
const PROP_ASSET = { crate:'prop_crate', crates:'prop_crates', barrel:'prop_barrel',
                     rope:'prop_rope', cannon:'prop_cannon', mast:'prop_mast',
                     lantern:'prop_lantern', vent:'prop_vent', hatch:'prop_hatch',
                     ballista:'prop_ballista', brazier:'prop_brazier' };
// Props that throw light onto the deck. Both are destructible in v11, and the
// deck going dark where one stood is the cheapest consequence in the game.
const LIGHT_PROPS = { lantern: 210, brazier: 150 };

function paintProp(t){
  const TIM = '#3A2C2A', TIM_L = '#54413C';
  if (t === 'crate' || t === 'crates'){
    const n = t === 'crates' ? 3 : 1;
    for (let i = 0; i < n; i++){
      const s = 1 - i * 0.12, yy = -i * 52;
      ctx.save(); ctx.translate((i % 2 ? 8 : -6) * (i ? 1 : 0), yy); ctx.rotate((i % 2 ? 0.05 : -0.04) * i);
      plate(0, -30 * s, 74 * s, 60 * s, 5, TIM);
      ctx.strokeStyle = C(PAL.brass); ctx.lineWidth = 5;
      ctx.beginPath();
      ctx.moveTo(-30*s, -56*s); ctx.lineTo(30*s, -6*s);
      ctx.moveTo(30*s, -56*s);  ctx.lineTo(-30*s, -6*s); ctx.stroke();
      rivets([[-32*s,-56*s],[32*s,-56*s],[-32*s,-6*s],[32*s,-6*s]]);
      ctx.restore();
    }
    if (n > 1){
      ctx.strokeStyle = C(PAL.leather); ctx.lineWidth = 6;
      ctx.beginPath(); ctx.moveTo(-36, -140); ctx.lineTo(34, -20); ctx.stroke();
    }
  } else if (t === 'barrel'){
    plate(0, -34, 56, 66, 16, '#40302A');
    ctx.strokeStyle = C(PAL.iron); ctx.lineWidth = 7;
    for (const yy of [-56, -34, -12]){
      ctx.beginPath(); ctx.moveTo(-27, yy); ctx.lineTo(27, yy); ctx.stroke();
    }
    ell(0, -66, 27, 8); fillStroke(C('#241C1A'), ink(), OUT * 0.7);
    specular(-12, -48, 5, 16, 0.05, 0.22);
  } else if (t === 'rope'){
    for (let i = 0; i < 3; i++){
      ell(0, -8 - i * 7, 46 - i * 8, 15 - i * 3);
      fillStroke(C(PAL.leather), ink(), OUT * 0.7);
    }
  } else if (t === 'cannon'){
    limb(-20, -6, -20, -34, 16, '#3A2C2A');
    limb( 20, -6,  20, -34, 16, '#3A2C2A');
    plate(0, -44, 74, 26, 6, TIM_L);
    ctx.save(); ctx.translate(0, -60); ctx.rotate(-0.14);
    plate(0, 0, 96, 30, 14, PAL.brass);
    specular(-16, -9, 26, 4, -0.14, 0.5);
    circ(50, 0, 15); fillStroke(C(PAL.ink), ink(), OUT * 0.7);
    ctx.strokeStyle = C(PAL.copper); ctx.lineWidth = 6;
    ctx.beginPath(); ctx.moveTo(-30, -16); ctx.lineTo(-30, 16); ctx.stroke();
    ctx.restore();
  } else if (t === 'mast'){
    plate(0, -170, 44, 340, 10, TIM);
    ctx.strokeStyle = C(PAL.brass); ctx.lineWidth = 8;
    for (const yy of [-58, -190, -300]){
      ctx.beginPath(); ctx.moveTo(-24, yy); ctx.lineTo(24, yy); ctx.stroke();
    }
    ctx.strokeStyle = C(PAL.leather); ctx.lineWidth = 5;
    for (const s of [-1, 1]){
      ctx.beginPath(); ctx.moveTo(s * 20, -300); ctx.lineTo(s * 74, -10); ctx.stroke();
    }
    specular(-11, -200, 5, 110, 0, 0.16);
  } else if (t === 'lantern'){
    limb(0, -4, 0, -150, 13, '#2A2530');
    ctx.strokeStyle = C(PAL.ink); ctx.lineWidth = 6;
    ctx.beginPath(); ctx.arc(0, -150, 26, Math.PI, TAU); ctx.stroke();
    // caged amber flame — the warm source of the scene
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    drawGlow(0, -168, 96, PAL.lantern, 0.85);
    ctx.restore();
    plate(0, -170, 40, 46, 8, hexToRgba(PAL.lantern, 0.95));
    ctx.strokeStyle = C(PAL.brass); ctx.lineWidth = 5;
    for (const xx of [-13, 0, 13]){
      ctx.beginPath(); ctx.moveTo(xx, -192); ctx.lineTo(xx, -148); ctx.stroke();
    }
    ctx.fillStyle = '#FFFFFF'; ell(0, -170, 8, 13); ctx.fill();
    plate(0, -200, 46, 16, 5, PAL.brass);
  } else if (t === 'brazier'){
    // an iron fire-basket on three splayed legs, coals live in it
    for (const sx of [-1, 0, 1]){
      limb(sx * 15, -6, sx * 7, -44, 9, '#2E2A2E');
    }
    plate(0, -58, 62, 30, 8, PAL.iron);
    ctx.strokeStyle = C(PAL.ink); ctx.lineWidth = 5;
    for (const xx of [-20, -7, 7, 20]){
      ctx.beginPath(); ctx.moveTo(xx, -72); ctx.lineTo(xx, -46); ctx.stroke();
    }
    ell(0, -72, 31, 10); fillStroke(C('#3A1A08'), ink(), OUT * 0.7);
    ctx.fillStyle = PAL.fire; ell(0, -74, 24, 7); ctx.fill();
    ctx.fillStyle = PAL.fireCore; ell(0, -76, 13, 4); ctx.fill();
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    drawGlow(0, -84, 78, PAL.fire, 0.7);
    ctx.restore();
  } else if (t === 'vent'){
    plate(0, -22, 66, 40, 8, PAL.iron);
    ctx.strokeStyle = C(PAL.ink); ctx.lineWidth = 5;
    for (const yy of [-34, -24, -14]){
      ctx.beginPath(); ctx.moveTo(-26, yy); ctx.lineTo(26, yy); ctx.stroke();
    }
    circ(22, -44, 12); fillStroke(C(PAL.brassLite), ink(), OUT * 0.7);
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    drawGlow(0, -20, 44, PAL.fire, 0.4); ctx.restore();
  } else if (t === 'hatch'){
    plate(0, -18, 96, 34, 7, TIM);
    ctx.strokeStyle = C(PAL.iron); ctx.lineWidth = 7;
    ctx.beginPath(); ctx.moveTo(-40, -18); ctx.lineTo(40, -18); ctx.stroke();
    rivets([[-40,-30],[40,-30],[-40,-6],[40,-6]]);
  } else if (t === 'ballista'){
    limb(-22, -6, 0, -52, 14, TIM);
    limb( 22, -6,  0, -52, 14, TIM);
    plate(0, -62, 30, 64, 8, PAL.iron);
    ctx.strokeStyle = C(PAL.brass); ctx.lineWidth = 9;
    ctx.beginPath(); ctx.arc(0, -78, 52, Math.PI + 0.5, TAU - 0.5); ctx.stroke();
    ctx.strokeStyle = C(PAL.leather); ctx.lineWidth = 4;
    ctx.beginPath(); ctx.moveTo(-46, -100); ctx.lineTo(0, -70); ctx.lineTo(46, -100); ctx.stroke();
    plate(0, -96, 12, 84, 4, PAL.brassLite);
    ell(0, -18, 24, 9); fillStroke(C(PAL.leather), ink(), OUT * 0.7);
  }
}
function propSprite(t){
  const asset = Assets.get(PROP_ASSET[t]);
  if (asset) return asset;
  const tall = t === 'mast' || t === 'lantern' || t === 'crates';
  const H = tall ? 420 : 220, W = Math.round(H * (t === 'rope' ? 1.3 : (t === 'mast' ? 0.55 : 0.9)));
  return cachedSprite('prop|' + t, W, H, (c2, w, h) => {
    c2.save();
    c2.translate(w / 2, h * ANCHOR);
    const src = tall ? 360 : 130;
    const s = (h * FIG) / src;
    c2.scale(s, s);
    c2.lineJoin = 'round'; c2.lineCap = 'round';
    paintProp(t);
    c2.restore();
    applyTwoSourceLight(c2, w, h);
  });
}
// width/height of the sprite box that is actually SOLID, per prop type.
// Anything not listed here does not occlude at all.
const OCCLUDE_BOX = { mast: [0.20, 0.86], crates: [0.52, 0.66], ballista: [0.44, 0.50] };
function drawPropBillboard(p){
  if (p.dead) return;
  if (p.r > 0) entityShadow(p.x, p.y, p.r * 1.15, 0.5);
  else entityShadow(p.x, p.y, 34, 0.34);
  /* v11 — a keg has to look like ordnance before it goes off, and like it is
     going off while the fuse burns. Three states, all cheap: intact, hurt
     (white flash on the hit), and lit (shaking, rimmed in steam-violet, with a
     ring on the deck showing exactly how much of the floor the blast owns). */
  let sx = 0, sy = 0;
  if (p.fuse > 0){
    const K = TUNING.props.keg;
    const f = 1 - p.fuse / K.fuse;                 // 0 -> 1 across the fuse
    sx = Math.sin(S.rt * 46) * (2 + f * 7);
    sy = Math.cos(S.rt * 39) * (1 + f * 3);
    const g = groundEllipsePath(p.x, p.y, K.radius);
    ctx.save();
    ctx.globalAlpha = 0.20 + 0.28 * f + Math.sin(S.rt * 22) * 0.06;
    ctx.strokeStyle = '#F2EAFF';
    ctx.lineWidth = (3 + f * 4) * g.p.k;
    ctx.stroke();
    ctx.globalAlpha = 0.06 + 0.10 * f;
    ctx.fillStyle = '#C9B6E8'; ctx.fill();
    ctx.restore();
    const q = CAM.project(p.x, p.y, 40);
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    drawGlow(q.x + sx, q.y, (30 + f * 44) * q.k, '#F2EAFF', 0.5 + f * 0.4);
    ctx.restore();
  }
  if (sx || sy){ ctx.save(); ctx.translate(sx, sy); }
  // the same white hit-flash every damageable thing in the game already gets
  const r = drawBillboard(propSprite(p.t), p.x, p.y, PROP_H[p.t] || 80,
                          { flash: p.flash > 0 || (p.fuse > 0 && Math.sin(S.rt * 44) > 0) });
  if (sx || sy) ctx.restore();
  const box = OCCLUDE_BOX[p.t];
  if (box) addOccluder(r.p.x, r.p.y, r.wpx * box[0], r.hpx * box[1], p.y);
  if (LIGHT_PROPS[p.t]){
    const q = CAM.project(p.x, p.y, PROP_H[p.t] * 0.86);
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    drawGlow(q.x, q.y, (p.t === 'brazier' ? 74 : 90) * q.k,
             p.t === 'brazier' ? PAL.fire : PAL.lantern,
             0.5 + Math.sin(S.rt * 3 + p.x) * 0.08);
    ctx.restore();
  }
}

/* --- the Boiler ---------------------------------------------------------- */
function boilerSprite(){
  return cachedSprite('boiler', 300, 300, (c2, w, h) => {
    c2.save();
    c2.translate(w / 2, h * ANCHOR);
    c2.scale(h * FIG / 190, h * FIG / 190);
    c2.lineJoin = 'round'; c2.lineCap = 'round';
    // riveted drum on a plinth, pipes and gauge
    plate(0, -18, 150, 36, 8, PAL.iron);
    for (const s of [-1, 1]){
      limb(s * 62, -50, s * 96, -34, 18, '#4A4A55');
      plate(s * 104, -34, 22, 34, 6, PAL.brass);
    }
    plate(0, -104, 120, 132, 22, PAL.brass);
    specular(-34, -140, 16, 34, 0.06, 0.42);
    rivets([[-48,-158],[0,-162],[48,-158],[-48,-52],[0,-48],[48,-52]], PAL.brassLite);
    // furnace grate
    plate(0, -92, 74, 66, 8, '#3A1A08');
    ctx.fillStyle = PAL.fire; rr(-32, -122, 64, 58, 5); ctx.fill();
    ctx.strokeStyle = C(PAL.ink); ctx.lineWidth = 7;
    for (let i = 0; i < 4; i++){
      ctx.beginPath(); ctx.moveTo(-34, -116 + i * 15); ctx.lineTo(34, -116 + i * 15); ctx.stroke();
    }
    // gauge on top
    circ(0, -178, 22); fillStroke(C(PAL.brassLite), ink(), OUT);
    ctx.strokeStyle = ink(); ctx.lineWidth = 4;
    ctx.beginPath(); ctx.moveTo(0, -178); ctx.lineTo(13, -188); ctx.stroke();
    // chimney
    plate(-44, -196, 26, 44, 5, '#4A4A55');
    c2.restore();
    applyTwoSourceLight(c2, w, h);
  });
}
function drawBoilerBillboard(){
  const B = S.boiler;
  const frac = clamp(B.hp / B.maxHp, 0, 1);
  const sh = B.shake > 0 ? B.shake * 6 : 0;
  entityShadow(B.x, B.y, B.r * 1.5, 0.62);
  // the furnace throws the deck's other warm light
  const q = CAM.project(B.x, B.y, 100);
  ctx.save(); ctx.globalCompositeOperation = 'lighter';
  drawGlow(q.x, q.y, (120 + Math.sin(S.rt * 5) * 10) * q.k,
           frac > 0.35 ? PAL.fire : PAL.danger, 0.35 + 0.3 * frac);
  ctx.restore();
  // Never white-silhouette the Boiler on hit: it is scenery you read constantly,
  // and a full flash makes the thing you are defending unreadable mid-fight.
  const r = drawBillboard(boilerSprite(), B.x + rnd(-sh, sh), B.y, PRESET.boilerH, {});
  if (B.flash > 0){
    const c = CAM.project(B.x, B.y, PRESET.boilerH * 0.5);
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    drawGlow(c.x, c.y, r.wpx * 0.42, '#FFE9C0', clamp(B.flash / 0.14, 0, 1) * 0.45);
    ctx.restore();
  }
  addOccluder(r.p.x, r.p.y, r.wpx * 0.58, r.hpx * 0.70, B.y);
  if (frac < 0.6 && rnd() < 0.12) pSmoke(B.x + rnd(-30, 30), B.y, 1, 'rgba(40,36,48,0.6)', 40);
  if (rnd() < 0.05) pSmoke(B.x - 30, B.y, 1, 'rgba(200,196,210,0.30)', 26);
}

/* --- the player ---------------------------------------------------------- */
function drawPlayerBillboard(){
  const P = S.player;
  if (P.hp <= 0) return;
  let bob = Math.sin(P.walk * 2.2) * 3;
  const inv = P.iframe > 0 && Math.floor(S.rt * 24) % 2 === 0;
  entityShadow(P.x, P.y, 34, 0.55);
  /* v11 — the vent, on the deck. The ring travels out at the speed the damage
     did, so what you see is exactly what was hit; it is drawn under the captain
     rather than over her because she is the one thing never allowed to be
     obscured, and because steam leaving her reads better from below. */
  if (V11 && P.ventFlash > 0){
    const V = TUNING.close.vent;
    const k = 1 - P.ventFlash / 0.42;
    const g = groundEllipsePath(P.x, P.y, V.radius * S.mods.ventRadius * (0.32 + k * 0.68));
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    ctx.globalAlpha = (1 - k) * 0.8;
    ctx.strokeStyle = '#F2EAFF';
    ctx.lineWidth = (10 - k * 7) * g.p.k;
    ctx.stroke();
    ctx.globalAlpha = (1 - k) * 0.16;
    ctx.fillStyle = '#C9B6E8'; ctx.fill();
    ctx.restore();
  }
  // and the pressure itself, as a tightening ring at her feet — the only place
  // a player looking at the fight will actually see it
  if (V11 && P.pressure > 12 && P.hp > 0){
    const pf = clamp(P.pressure / 100, 0, 1);
    const g = groundEllipsePath(P.x, P.y, 46 - pf * 12);
    ctx.save();
    ctx.globalAlpha = 0.10 + pf * 0.40;
    ctx.strokeStyle = pf >= 1 ? '#F2EAFF' : '#C9B6E8';
    ctx.lineWidth = (1.5 + pf * 3) * g.p.k;
    ctx.setLineDash([]);
    ctx.stroke();
    ctx.restore();
  }
  // dash afterimages
  for (const t of P.trail){
    const k = 1 - t.t / 0.32;
    const v = viewFor(t.a, false, false);
    drawBillboard(charImage('hero', v.view), t.x, t.y, BILLBOARD_H.hero,
                  { mirror: v.mirror, alpha: k * 0.32 });
  }
  const attacking = P.castFlash > 0 || !!P.ray;
  const v = viewFor(P.facing !== undefined ? P.facing : P.aim, true, attacking);
  const running = !attacking && P.dashT <= 0 && v.view === 'front_idle' &&
                  Math.hypot(P.vx, P.vy) > 35;
  // Front views only. The cycles are authored facing the camera; a back-facing
  // captain keeps her still, which is what the back still exists for.
  const front = v.view !== 'back_idle';
  const frame =
      (front && P.atkAnimT !== undefined && P.atkAnimT >= 0
        && Assets.animation('hero_attack', P.atkAnimT))
   || (running && front && Assets.animation('hero_run', S.rt))
   || (!running && !attacking && front && P.dashT <= 0 && Assets.animation('hero_idle', S.rt));
  const hi = frame || charImage('hero', v.view);
  if (frame) bob = 0;
  const hr = drawBillboard(hi, P.x, P.y, BILLBOARD_H.hero,
                { mirror: v.mirror, lift: bob, alpha: inv ? 0.55 : 1, flash: P.hurt > 0.18 });
  // No x-ray for the captain: she is drawn above everything, so she can never
  // be hidden and a silhouette of her would just be a teal blob over herself.
  //
  // She does need to be findable in a crowd, and "she is the teal one" fails
  // exactly when it matters — a greyscale capture of a wave-5 fight had her
  // standing directly in front of an Armoured and the two were one shape. So
  // the mark under her feet is permanent, bright, and in the player language:
  // a continuous rim with ticks pointing inward, the same grammar as her own
  // ability areas and the opposite of every hostile mark on the deck. That
  // reads as value and shape, not as hue.
  playerRing(P.x, P.y, 30, PAL.bone, 2.2, 0.5, 10);
  playerRing(P.x, P.y, 34, PAL.teal, 2.6, 0.75, 10);
  const q = CAM.project(P.x, P.y, 46);
  ctx.save(); ctx.globalCompositeOperation = 'lighter';
  drawGlow(q.x, q.y, 62 * q.k, PAL.teal, 0.22);
  ctx.restore();
  // A second, wider ring while a dash is banked — so the ring says both "this
  // is you" and "you can still get out of this".
  if (P.dashStock > 0 && P.dashT <= 0)
    playerRing(P.x, P.y, 44, PAL.teal, 1.8, 0.24 + Math.sin(S.rt * 5) * 0.07, 16);
}

/* --- enemies ------------------------------------------------------------- */
function drawEnemyBillboard(e){
  const climbing = e.state === 'climb';
  const k = climbing ? e.climb : 1;
  const attacking = e.state === 'windup' || e.swingFx > 0 ||
                    (e.type === 'BOSS' && e.state === 'active');
  const v = viewFor(e.facing, true, attacking);
  const hover = e.type === 'GUNNER' ? 26 + Math.sin(S.rt * 3 + e.anim) * 5 : 0;
  let bob = Math.sin(e.anim * (e.def.speed / 26)) * (e.type === 'SWARM' ? 4 : 2.4);

  if (!climbing) entityShadow(e.x, e.y, e.r * 1.15, 0.5 - (hover ? 0.18 : 0));
  if (e.slowT > 0) groundRing(e.x, e.y, e.r + 10, PAL.teal, 2.6, 0.5);
  if (e.accT > 0)  groundRing(e.x, e.y, e.r + 18, ELEMENTS.STEAM.color, 2.2, 0.32);

  // Same three states for every enemy type, so a delivered cycle for any of
  // them drops in without another branch here. `e.anim` offsets the clock per
  // entity, so six Scrappers do not march in lockstep.
  const front = v.view !== 'back_idle';
  const moving = e.state === 'move' && Math.hypot(e.vx, e.vy) > 15;
  const t = S.rt + e.anim * 0.137;
  const frame = climbing ? null : (
      (front && attacking && e.atkAnimT >= 0 && Assets.animation(e.type + '_attack', e.atkAnimT))
   || (front && moving && Assets.animation(e.type + '_run', t))
   || (front && !moving && !attacking && Assets.animation(e.type + '_idle', t)));
  const img = frame || charImage(e.type, v.view);
  if (frame) bob = 0;
  const r = drawBillboard(img, e.x, e.y, BILLBOARD_H[e.type] || 110, {
    mirror: v.mirror,
    lift: hover + bob,
    alpha: climbing ? 0.25 + 0.75 * k : 1,
    scale: climbing ? 0.55 + 0.45 * k : 1,
    flash: e.flash > 0,
  });
  if (!climbing && PRESET.xray){
    _xrayQueue.push({ img, col: e.type === 'BOSS' ? PAL.danger : PAL.dangerIn,
                      x: r.p.x - r.wpx/2, y: r.top, w: r.wpx, h: r.hpx, gy: e.y });
  }

  const top = CAM.project(e.x, e.y, (BILLBOARD_H[e.type] || 110) + hover + 22);
  if (e.burnStacks > 0 && !climbing){
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    drawGlow(CAM.project(e.x, e.y, 40).x, CAM.project(e.x, e.y, 40).y,
             e.r * 2.4 * CAM.project(e.x, e.y, 0).k, PAL.fire, 0.10 * e.burnStacks);
    ctx.restore();
  }
  if (e.stunT > 0){
    for (let i = 0; i < 3; i++){
      const a = S.rt * 7 + i / 3 * TAU;
      ctx.fillStyle = PAL.tesla;
      circ(top.x + Math.cos(a) * 13 * top.k, top.y + Math.sin(a) * 5 * top.k, 3.2 * top.k);
      ctx.fill();
    }
  }
  if (e.blockFlash > 0){
    const c = CAM.project(e.x, e.y, 70);
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    drawGlow(c.x, c.y, 44 * c.k, PAL.brassLite, e.blockFlash / 0.18);
    ctx.restore();
  }
  if (!climbing && e.hp < e.maxHp && e.type !== 'BOSS'){
    const w = Math.max(26, e.r * 2.0) * top.k, h = 5 * top.k;
    const x = top.x - w/2, y = top.y;
    ctx.fillStyle = 'rgba(13,11,18,0.85)'; rr(x-2, y-2, w+4, h+4, 3); ctx.fill();
    ctx.fillStyle = e.hp / e.maxHp > 0.4 ? PAL.danger : PAL.dangerIn;
    rr(x, y, w * clamp(e.hp/e.maxHp, 0, 1), h, 2); ctx.fill();
  }
}

/* --- boarding markers + telegraphs (§2.9 — code-drawn, ground-projected) -- */
function groundRuneImage(key, x, y, r, alpha, tint){
  const img = Assets.get(key);
  if (!img) return false;
  const g = groundEllipsePath(x, y, r);
  ctx.save();
  ctx.globalAlpha = alpha === undefined ? 1 : alpha;
  ctx.drawImage(img, g.p.x - g.rx, g.p.y - g.ry, g.rx * 2, g.ry * 2);
  ctx.restore();
  return true;
}

function drawTelegraphs(){
  ctx.save();
  ctx.lineJoin = 'round';

  for (const e of S.enemies){
    if (e.state !== 'climb') continue;
    const pulse = 0.4 + 0.35 * Math.sin(S.rt * 12);
    if (!groundRuneImage('rune_enemy', e.spawnX, e.spawnY, 40, pulse)){
      hostileRing(e.spawnX, e.spawnY, 38, PAL.danger, 3, pulse, 12);
      hostileRing(e.spawnX, e.spawnY, 26, PAL.dangerIn, 2, pulse * 0.7, 9);
    }
    const g = groundEllipsePath(e.spawnX, e.spawnY, 38);
    ctx.save();
    ctx.strokeStyle = PAL.dangerIn; ctx.lineWidth = 4 * g.p.k;
    ctx.beginPath();
    ctx.ellipse(g.p.x, g.p.y, g.rx, g.ry, 0, -Math.PI/2, -Math.PI/2 + TAU * e.climb);
    ctx.stroke();
    ctx.restore();
  }

  for (const e of S.enemies){
    if (e.dead) continue;
    const def = e.def;
    if (e.state === 'windup'){
      const total = e.type === 'BOSS'
        ? (e.boss.atk === 'slam' ? 0.9 : e.boss.atk === 'summon' ? 0.7 : 0.8)
        : def.windup;
      const kk = 1 - clamp(e.st / total, 0, 1);
      const flick = 0.34 + 0.30 * kk + Math.sin(S.rt * 26) * 0.05;

      if (e.type === 'BOSS' && e.boss.atk === 'slam'){
        if (!groundRuneImage('rune_enemy_filled', e.x, e.y, 260, flick))
          groundDisc(e.x, e.y, 260 * kk, PAL.danger, flick * 0.4);
        hostileRing(e.x, e.y, 260, PAL.danger, 6, 0.9, 22);
        hostileRing(e.x, e.y, 260 * kk, PAL.dangerIn, 4, 0.8, 22);
      } else if (e.type === 'BOSS' && e.boss.atk === 'summon'){
        hostileRing(e.x, e.y, 150, PAL.danger, 6, flick, 16);
        hostileRing(e.x, e.y, 150 * (0.4 + 0.6 * kk), PAL.dangerIn, 3, flick, 16);
      } else if (e.type === 'BOSS'){
        groundBandPath(e.x, e.y, e.atkAng, 660, 60, 0);
        ctx.fillStyle = hexToRgba(PAL.danger, flick * 0.45); ctx.fill();
        ctx.strokeStyle = PAL.danger; ctx.lineWidth = 3; ctx.stroke();
        groundBandPath(e.x, e.y, e.atkAng, 660 * kk, 60, 0);
        ctx.fillStyle = hexToRgba(PAL.dangerIn, 0.4); ctx.fill();
      } else if (def.ai === 'ranged'){
        groundBandPath(e.x, e.y, e.atkAng, def.atkRange + 70, 16, 20);
        ctx.fillStyle = hexToRgba(PAL.danger, flick * 0.55); ctx.fill();
        groundBandPath(e.x, e.y, e.atkAng, (def.atkRange + 70) * kk, 9, 20);
        ctx.fillStyle = hexToRgba(PAL.dangerIn, 0.9); ctx.fill();
      } else {
        groundWedgePath(e.x, e.y, 0, def.reach, e.atkAng - def.swing/2, e.atkAng + def.swing/2);
        ctx.fillStyle = hexToRgba(PAL.danger, flick * 0.5); ctx.fill();
        ctx.strokeStyle = hexToRgba(PAL.danger, 0.9); ctx.lineWidth = 2.5; ctx.stroke();
        groundWedgePath(e.x, e.y, def.reach * 0.72, def.reach,
                        e.atkAng - def.swing/2, e.atkAng - def.swing/2 + def.swing * kk);
        ctx.fillStyle = hexToRgba(PAL.dangerIn, 0.85); ctx.fill();
      }
    }
    if (e.type === 'BOSS' && e.state === 'active'){
      const a = e.facing;
      groundBandPath(e.x, e.y, a, 660, 56, 0);
      ctx.save();
      ctx.globalCompositeOperation = 'lighter';
      ctx.fillStyle = hexToRgba(PAL.fire, 0.55); ctx.fill();
      groundBandPath(e.x, e.y, a, 660, 20, 0);
      ctx.fillStyle = hexToRgba(PAL.fireCore, 0.9); ctx.fill();
      ctx.restore();
      const m = CAM.project(e.x + Math.cos(a) * 120, e.y + Math.sin(a) * 120, 150);
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      drawGlow(m.x, m.y, 60 * m.k, PAL.fireCore, 0.9);
      ctx.restore();
    }
  }
  ctx.restore();
}

function drawAoePreview(){
  for (let i = 0; i < 4; i++){
    const sk = S.slots[i];
    if (!sk || SHAPES[sk.shape].kind !== 'aoe') continue;
    const st = skillStats(sk);
    let tx = Input.mouse.x, ty = Input.mouse.y;
    const d = dist(S.player.x, S.player.y, tx, ty);
    if (d > st.castRange){
      tx = S.player.x + (tx - S.player.x) / d * st.castRange;
      ty = S.player.y + (ty - S.player.y) / d * st.castRange;
    }
    const c = clampToDeck(tx, ty, 6);
    const ready = sk.cdLeft <= 0;
    // Yours: a closed rim with inward ticks, in the skill's own element colour
    // and carrying that element's motif at the centre. A hostile area is the
    // same idea inverted — broken rim, teeth outward — so which is which
    // survives greyscale and a colour-blind eye.
    const E = ELEMENTS[sk.element];
    if (!groundRuneImage('rune_player', c.x, c.y, st.radius, ready ? 0.55 : 0.2)){
      playerRing(c.x, c.y, st.radius, E.color, 2.6, ready ? 0.5 : 0.18, 14);
      playerRing(c.x, c.y, st.radius * 0.24, E.color, 2, ready ? 0.35 : 0.12, 6);
    }
    const gm = CAM.project(c.x, c.y, 0);
    elementMotif(sk.element, gm.x, gm.y, 9 * gm.k, E.glow, true);
    return;
  }
}

function drawFields(){
  for (const f of S.fields){
    const E = ELEMENTS[f.elem];
    const k = clamp(f.life / 2, 0, 1);
    const g = groundEllipsePath(f.x, f.y, f.r);
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    ctx.globalAlpha = 0.34 * k;
    const rg = ctx.createRadialGradient(g.p.x, g.p.y, 1, g.p.x, g.p.y, Math.max(1, g.rx));
    rg.addColorStop(0, hexToRgba(E.glow, 0.8));
    rg.addColorStop(0.6, hexToRgba(E.color, 0.5));
    rg.addColorStop(1, hexToRgba(E.color, 0));
    ctx.fillStyle = rg; ctx.fill();
    ctx.restore();
    groundRing(f.x, f.y, f.r * (0.92 + Math.sin(S.rt * 3 + f.seed) * 0.05), E.color, 3, 0.6 * k);
  }
}

function drawPickupBillboard(p){
  const bob = Math.sin(p.bob) * 5;
  const fade = p.life < 3 ? (0.4 + 0.6 * Math.abs(Math.sin(p.life * 8))) : 1;
  // v11 salvage reads green-brass rather than the relic violet of a card drop:
  // it is a small, common, walk-over-it heal and must not promise a card.
  const col = p.salvage ? '#8CE07A' : PAL.relic;
  entityShadow(p.x, p.y, 16, 0.35 * fade);
  const q = CAM.project(p.x, p.y, 26 + bob);
  ctx.save();
  ctx.globalAlpha = fade;
  ctx.globalCompositeOperation = 'lighter';
  drawGlow(q.x, q.y, (p.salvage ? 30 : 40) * q.k, col, 0.7);
  ctx.restore();
  const pile = p.salvage ? Assets.get('prop_scrap') : null;
  if (pile){
    // a real heap of clockwork on the deck, when the art is there
    ctx.save();
    ctx.globalAlpha = fade;
    drawBillboard(pile, p.x, p.y, 46, { lift: bob });
    ctx.restore();
    return;
  }
  ctx.save();
  ctx.globalAlpha = fade;
  ctx.translate(q.x, q.y);
  ctx.scale(q.k, q.k);
  ctx.rotate(S.rt * 1.4);
  ctx.lineJoin = 'round';
  circ(0, 0, 11); fillStroke(PAL.brass, PAL.ink, 4);
  ctx.strokeStyle = PAL.ink; ctx.lineWidth = 4;
  for (let i = 0; i < 6; i++){
    const a = i / 6 * TAU;
    ctx.beginPath();
    ctx.moveTo(Math.cos(a) * 10, Math.sin(a) * 10);
    ctx.lineTo(Math.cos(a) * 15, Math.sin(a) * 15); ctx.stroke();
  }
  ctx.rotate(-S.rt * 1.4);
  ctx.fillStyle = col;
  ctx.fillRect(-6, -2.2, 12, 4.4); ctx.fillRect(-2.2, -6, 4.4, 12);
  ctx.restore();
}

/* v11 — enemy fire you can actually read.

   Reported by the v10 tester: "enemy projectiles feel hard to track and avoid".
   Three separate reasons, all fixed here rather than by slowing the game down:

     1. It was drawn in tesla blue — the same family as the player's own teal.
        Everything hostile in this game is supposed to be oxblood-to-orange, and
        this was the one thing shooting at you that wasn't.
     2. It had no ground shadow. In a three-quarter view an unshadowed sprite
        has no position on the deck: you cannot tell whether it passes in front
        of you or through you until it has.
     3. It had no history. A dot moving at 300 u/s reads as a flicker; the same
        dot with nine samples of tail reads as a direction you can step out of.

   The bolt's speed (−18%) and hitbox are the core's business; this is the read.
*/
function drawBolts(){
  const HOT = '#FFD08A', BODY = PAL.dangerIn, EDGE = PAL.danger;
  for (const b of S.bolts){
    const q = CAM.project(b.x, b.y, 60);
    const img = Assets.get('fx_bolt');
    if (b.trail){
      // where it is ON THE DECK, not where it is in the air
      const g = groundEllipsePath(b.x, b.y, 15);
      ctx.save();
      ctx.globalAlpha = 0.42; ctx.fillStyle = PAL.ink; ctx.fill();
      ctx.restore();
      if (b.trail.length > 1){
        ctx.save();
        ctx.globalCompositeOperation = 'lighter';
        ctx.lineCap = 'round';
        for (let i = 1; i < b.trail.length; i++){
          const a = CAM.project(b.trail[i-1].x, b.trail[i-1].y, 60);
          const c = CAM.project(b.trail[i].x, b.trail[i].y, 60);
          const f = i / b.trail.length;
          ctx.globalAlpha = 0.10 + f * 0.42;
          ctx.strokeStyle = f > 0.7 ? HOT : BODY;
          ctx.lineWidth = (1.5 + f * 4.5) * q.k;
          ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(c.x, c.y); ctx.stroke();
        }
        ctx.restore();
      }
    }
    ctx.save();
    // a hard dark rim first, so the bolt keeps its silhouette over fire and steam
    if (b.trail){
      ctx.strokeStyle = PAL.ink;
      ctx.lineWidth = 2.6 * q.k;
      ctx.beginPath(); ctx.arc(q.x, q.y, 7.5 * q.k, 0, TAU); ctx.stroke();
      ctx.fillStyle = EDGE;
      ctx.beginPath(); ctx.arc(q.x, q.y, 7 * q.k, 0, TAU); ctx.fill();
    }
    ctx.globalCompositeOperation = 'lighter';
    drawGlow(q.x, q.y, (b.trail ? 34 : 26) * q.k, b.trail ? BODY : PAL.tesla, 1);
    if (img){
      ctx.translate(q.x, q.y); ctx.rotate(b.ang);
      const w = (b.trail ? 72 : 60) * q.k;
      ctx.drawImage(img, -w/2, -w/4, w, w/2);
    } else {
      ctx.translate(q.x, q.y); ctx.rotate(b.ang);
      ctx.strokeStyle = b.trail ? BODY : PAL.tesla; ctx.lineWidth = (b.trail ? 4.6 : 3.4) * q.k;
      ctx.beginPath();
      ctx.moveTo(-22*q.k, 0); ctx.lineTo(-9*q.k, -5*q.k); ctx.lineTo(1*q.k, 4*q.k); ctx.lineTo(14*q.k, 0);
      ctx.stroke();
      ctx.strokeStyle = b.trail ? HOT : '#FFFFFF'; ctx.lineWidth = 1.8 * q.k; ctx.stroke();
    }
    ctx.restore();
  }
}

/* The other half of the same note. A shooter already stands still for its
   windup, but nothing on screen said where the shot was going to go. This is
   the firing line, drawn only while the windup runs, dashed and broken the way
   every hostile telegraph in the game is. */
function drawAimLines(){
  if (!V11) return;
  ctx.save();
  for (const e of S.enemies){
    if (e.dead || e.state !== 'windup' || !e.def.bolt) continue;
    const f = e.def.windup > 0 ? 1 - clamp(e.st / e.def.windup, 0, 1) : 1;
    const len = e.def.atkRange + 80;
    const a = CAM.project(e.x, e.y, 46);
    const c = CAM.project(e.x + Math.cos(e.atkAng) * len, e.y + Math.sin(e.atkAng) * len, 46);
    ctx.globalAlpha = 0.16 + f * 0.42;
    ctx.strokeStyle = PAL.danger;
    ctx.lineWidth = (1.6 + f * 2.2) * a.k;
    ctx.setLineDash([14 * a.k, 12 * a.k]);
    ctx.lineDashOffset = -S.rt * 90;
    ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(c.x, c.y); ctx.stroke();
  }
  ctx.setLineDash([]);
  ctx.restore();
}
