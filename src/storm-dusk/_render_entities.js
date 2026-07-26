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
const _xrayOffsets = [[-3,0],[3,0],[0,-3],[0,3],[-2,-2],[2,-2],[-2,2],[2,2]];
function drawXrayPass(){
  if (!_xrayQueue.length) return;
  ctx.save();
  for (const q of _xrayQueue){
    if (!isOccluded(q.x + q.w / 2, q.y, q.w, q.h, q.gy)) continue;
    const rim = tintVersion(q.img, q.col);
    const core = tintVersion(q.img, '#140F1A');
    const s = Math.max(1.5, q.w * 0.020);
    ctx.globalAlpha = 0.5;
    for (const o of _xrayOffsets)
      ctx.drawImage(rim, q.x + o[0] * s, q.y + o[1] * s, q.w, q.h);
    ctx.globalAlpha = 0.82;
    ctx.drawImage(core, q.x, q.y, q.w, q.h);
    ctx.globalAlpha = 0.30;
    ctx.drawImage(rim, q.x, q.y, q.w, q.h);
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
  if (o.mirror){
    ctx.translate(p.x + (o.dx || 0), 0);
    ctx.scale(-1, 1);
    ctx.drawImage(o.flash ? whiteVersion(img) : img, -wpx * (1 - cxf), by, wpx, hpx);
  } else {
    ctx.drawImage(o.flash ? whiteVersion(img) : img, bx, by, wpx, hpx);
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
const PROP_H = { crate: 84, crates: 148, barrel: 82, rope: 30, cannon: 96,
                 mast: 340, lantern: 200, vent: 52, hatch: 44, ballista: 118 };
const PROP_ASSET = { crate:'prop_crate', crates:'prop_crates', barrel:'prop_barrel',
                     rope:'prop_rope', cannon:'prop_cannon', mast:'prop_mast',
                     lantern:'prop_lantern', vent:'prop_vent', hatch:'prop_hatch',
                     ballista:'prop_ballista' };

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
  if (p.r > 0) entityShadow(p.x, p.y, p.r * 1.15, 0.5);
  else entityShadow(p.x, p.y, 34, 0.34);
  const r = drawBillboard(propSprite(p.t), p.x, p.y, PROP_H[p.t] || 80, {});
  const box = OCCLUDE_BOX[p.t];
  if (box) addOccluder(r.p.x, r.p.y, r.wpx * box[0], r.hpx * box[1], p.y);
  if (p.t === 'lantern'){
    const q = CAM.project(p.x, p.y, PROP_H.lantern * 0.86);
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    drawGlow(q.x, q.y, 90 * q.k, PAL.lantern, 0.5 + Math.sin(S.rt * 3 + p.x) * 0.08);
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
  const bob = Math.sin(P.walk * 2.2) * 3;
  const inv = P.iframe > 0 && Math.floor(S.rt * 24) % 2 === 0;
  entityShadow(P.x, P.y, 34, 0.55);
  // dash afterimages
  for (const t of P.trail){
    const k = 1 - t.t / 0.32;
    const v = viewFor(t.a, false, false);
    drawBillboard(charImage('hero', v.view), t.x, t.y, BILLBOARD_H.hero,
                  { mirror: v.mirror, alpha: k * 0.32 });
  }
  const attacking = P.castFlash > 0 || !!P.ray;
  const v = viewFor(P.facing !== undefined ? P.facing : P.aim, true, attacking);
  const hi = charImage('hero', v.view);
  const hr = drawBillboard(hi, P.x, P.y, BILLBOARD_H.hero,
                { mirror: v.mirror, lift: bob, alpha: inv ? 0.55 : 1, flash: P.hurt > 0.18 });
  if (PRESET.xray)
    _xrayQueue.push({ img: hi, col: PAL.teal, x: hr.p.x - hr.wpx/2, y: hr.top,
                      w: hr.wpx, h: hr.hpx, gy: P.y });
  // a soft teal aura so the captain never gets lost in a crowd
  const q = CAM.project(P.x, P.y, 46);
  ctx.save(); ctx.globalCompositeOperation = 'lighter';
  drawGlow(q.x, q.y, 62 * q.k, PAL.teal, 0.16);
  ctx.restore();
  if (P.dashStock > 0 && P.dashT <= 0)
    groundRing(P.x, P.y, 34, PAL.teal, 2.4, 0.20 + Math.sin(S.rt * 5) * 0.06);
}

/* --- enemies ------------------------------------------------------------- */
function drawEnemyBillboard(e){
  const climbing = e.state === 'climb';
  const k = climbing ? e.climb : 1;
  const attacking = e.state === 'windup' || e.swingFx > 0 ||
                    (e.type === 'BOSS' && e.state === 'active');
  const v = viewFor(e.facing, true, attacking);
  const hover = e.type === 'GUNNER' ? 26 + Math.sin(S.rt * 3 + e.anim) * 5 : 0;
  const bob = Math.sin(e.anim * (e.def.speed / 26)) * (e.type === 'SWARM' ? 4 : 2.4);

  if (!climbing) entityShadow(e.x, e.y, e.r * 1.15, 0.5 - (hover ? 0.18 : 0));
  if (e.slowT > 0) groundRing(e.x, e.y, e.r + 10, PAL.teal, 2.6, 0.5);
  if (e.accT > 0)  groundRing(e.x, e.y, e.r + 18, ELEMENTS.STEAM.color, 2.2, 0.32);

  const img = charImage(e.type, v.view);
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
      groundRing(e.spawnX, e.spawnY, 38, PAL.danger, 3, pulse);
      groundRing(e.spawnX, e.spawnY, 26, PAL.dangerIn, 2, pulse * 0.7);
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
        groundRing(e.x, e.y, 260, PAL.danger, 6, 0.9);
        groundRing(e.x, e.y, 260 * kk, PAL.dangerIn, 4, 0.8);
      } else if (e.type === 'BOSS' && e.boss.atk === 'summon'){
        groundRing(e.x, e.y, 150, PAL.danger, 6, flick);
        groundRing(e.x, e.y, 150 * (0.4 + 0.6 * kk), PAL.dangerIn, 3, flick);
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
    if (!groundRuneImage('rune_player', c.x, c.y, st.radius, ready ? 0.55 : 0.2)){
      groundRing(c.x, c.y, st.radius, PAL.teal, 2.6, ready ? 0.45 : 0.16);
      groundRing(c.x, c.y, st.radius * 0.24, PAL.teal, 2, ready ? 0.35 : 0.12);
      const g = groundEllipsePath(c.x, c.y, st.radius);
      ctx.save();
      ctx.globalAlpha = ready ? 0.30 : 0.10;
      ctx.strokeStyle = PAL.teal; ctx.lineWidth = 1.6 * g.p.k;
      for (let t = 0; t < 12; t++){
        const a = t / 12 * TAU;
        ctx.beginPath();
        ctx.moveTo(g.p.x + Math.cos(a) * g.rx * 0.88, g.p.y + Math.sin(a) * g.ry * 0.88);
        ctx.lineTo(g.p.x + Math.cos(a) * g.rx, g.p.y + Math.sin(a) * g.ry);
        ctx.stroke();
      }
      ctx.restore();
    }
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
  entityShadow(p.x, p.y, 16, 0.35 * fade);
  const q = CAM.project(p.x, p.y, 26 + bob);
  ctx.save();
  ctx.globalAlpha = fade;
  ctx.globalCompositeOperation = 'lighter';
  drawGlow(q.x, q.y, 40 * q.k, PAL.relic, 0.7);
  ctx.restore();
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
  ctx.fillStyle = PAL.relic;
  ctx.fillRect(-6, -2.2, 12, 4.4); ctx.fillRect(-2.2, -6, 4.4, 12);
  ctx.restore();
}

function drawBolts(){
  for (const b of S.bolts){
    const q = CAM.project(b.x, b.y, 60);
    const img = Assets.get('fx_bolt');
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    drawGlow(q.x, q.y, 26 * q.k, PAL.tesla, 1);
    if (img){
      ctx.translate(q.x, q.y); ctx.rotate(b.ang);
      const w = 60 * q.k;
      ctx.drawImage(img, -w/2, -w/4, w, w/2);
    } else {
      ctx.translate(q.x, q.y); ctx.rotate(b.ang);
      ctx.strokeStyle = PAL.tesla; ctx.lineWidth = 3.4 * q.k;
      ctx.beginPath();
      ctx.moveTo(-22*q.k, 0); ctx.lineTo(-9*q.k, -5*q.k); ctx.lineTo(1*q.k, 4*q.k); ctx.lineTo(14*q.k, 0);
      ctx.stroke();
      ctx.strokeStyle = '#FFFFFF'; ctx.lineWidth = 1.6 * q.k; ctx.stroke();
    }
    ctx.restore();
  }
}
