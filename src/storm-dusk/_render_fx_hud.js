/* ---------------------------------------------------------------------------
   SKILL VFX — the shapes live on the ground, so they are projected onto it.
   Saturated pops off the dark base (§1.2).
--------------------------------------------------------------------------- */
function jitterAt(i, seed){
  const n = Math.sin(i * 127.1 + seed * 311.7) * 43758.5453;
  return (n - Math.floor(n)) * 2 - 1;
}

/* The aura is not an effect that fires — it is a state you are in, so it draws
   every frame from the slot rather than from the fx list. Kept faint: it is on
   screen permanently and anything punchy here becomes wallpaper within a wave. */
function drawAuraFields(){
  const P = S.player;
  if (P.hp <= 0) return;
  for (let i = 0; i < 4; i++){
    const sk = S.slots[i];
    if (!sk || SHAPES[sk.shape].kind !== 'aura') continue;
    const st = skillStats(sk), E = ELEMENTS[sk.element];
    const puls = 0.82 + Math.sin(S.t * 2.4) * 0.18;
    groundDisc(P.x, P.y, st.radius, E.color, 0.055 * puls);
    groundRing(P.x, P.y, st.radius, E.color, 3, 0.34 * puls);
    groundRing(P.x, P.y, st.radius * 0.82, E.glow, 1.5, 0.16 * puls);
  }
}

function drawSentries(){
  for (const s of S.sentries){
    const E = ELEMENTS[s.element];
    const p = CAM.project(s.x, s.y, 0);
    const fade = clamp(s.t / 1.2, 0, 1);      // warns before it expires
    ctx.save();
    ctx.globalAlpha = fade;
    groundRing(s.x, s.y, 34, E.color, 2.5, 0.5);
    const top = CAM.project(s.x, s.y, 46);
    // squat tripod + barrel, drawn straight so it reads at any camera angle
    ctx.strokeStyle = PAL.ink; ctx.lineWidth = 6 * p.k;
    ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(top.x, top.y); ctx.stroke();
    ctx.strokeStyle = PAL.brass; ctx.lineWidth = 3.4 * p.k;
    ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(top.x, top.y); ctx.stroke();
    const bl = 26 * top.k;
    ctx.strokeStyle = E.color; ctx.lineWidth = 5 * top.k; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(top.x, top.y);
    ctx.lineTo(top.x + Math.cos(s.ang) * bl, top.y + Math.sin(s.ang) * bl * 0.6);
    ctx.stroke();
    circ(top.x, top.y, 6 * top.k); ctx.fillStyle = PAL.iron; ctx.fill();
    if (s.fire > 0){
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      drawGlow(top.x, top.y, 26 * top.k, E.glow, s.fire / 0.12);
      ctx.restore();
    }
    ctx.restore();
  }
}

function drawGroundFx(){
  drawAuraFields();
  ctx.save();
  ctx.lineJoin = 'round'; ctx.lineCap = 'round';
  for (const f of S.fx){
    if (f.delay > 0) continue;
    const k = clamp(f.t / f.life, 0, 1), inv = 1 - k, e = easeOut(k);

    if (f.kind === 'arc'){
      const R = f.r * (0.6 + 0.44 * e), R0 = R * (0.4 + 0.2 * e);
      const half = f.arc/2 * (0.3 + 0.7 * e);
      groundWedgePath(f.x, f.y, R0, R, f.a - half, f.a + half);
      ctx.globalAlpha = inv * 0.55; ctx.fillStyle = f.col; ctx.fill();
      ctx.globalAlpha = inv * 0.95;
      ctx.strokeStyle = f.glow; ctx.lineWidth = 3; ctx.stroke();
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      groundWedgePath(f.x, f.y, R0, R, f.a - half, f.a + half);
      ctx.globalAlpha = inv * 0.5; ctx.fillStyle = f.glow; ctx.fill();
      ctx.restore();

    } else if (f.kind === 'cone'){
      const R = f.r * (0.35 + 0.75 * e);
      groundWedgePath(f.x, f.y, 8, R, f.a - f.arc/2, f.a + f.arc/2);
      ctx.globalAlpha = inv * 0.42; ctx.fillStyle = f.col; ctx.fill();
      ctx.globalAlpha = inv * 0.85; ctx.strokeStyle = f.glow; ctx.lineWidth = 3; ctx.stroke();
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      groundWedgePath(f.x, f.y, R * 0.5, R, f.a - f.arc/2, f.a + f.arc/2);
      ctx.globalAlpha = inv * 0.45; ctx.fillStyle = f.glow; ctx.fill();
      ctx.restore();

    } else if (f.kind === 'line'){
      groundBandPath(f.x, f.y, f.a, f.len, f.w * (0.7 + 0.5 * inv), 0);
      ctx.globalAlpha = inv * 0.5; ctx.fillStyle = f.col; ctx.fill();
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      groundBandPath(f.x, f.y, f.a, f.len, f.w * 0.34, 0);
      ctx.globalAlpha = inv * 0.9; ctx.fillStyle = f.glow; ctx.fill();
      ctx.restore();

    } else if (f.kind === 'aoe'){
      const R = f.r * (0.45 + 0.55 * e);
      groundDisc(f.x, f.y, R, f.col, inv * 0.30);
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      const g = groundEllipsePath(f.x, f.y, R * 0.7);
      const rg = ctx.createRadialGradient(g.p.x, g.p.y, 1, g.p.x, g.p.y, Math.max(1, g.rx));
      rg.addColorStop(0, hexToRgba('#FFFFFF', Math.max(0, 1 - k * 2.4)));
      rg.addColorStop(0.4, hexToRgba(f.glow || f.col, inv * 0.7));
      rg.addColorStop(1, hexToRgba(f.col, 0));
      ctx.fillStyle = rg; ctx.fill();
      ctx.restore();
      groundRing(f.x, f.y, f.r * (0.55 + 0.45 * e), f.col, 8 * inv + 3, inv * 0.95);
      groundRing(f.x, f.y, f.r * (0.55 + 0.45 * e), f.glow || '#FFF', 3 * inv + 1, inv * 0.7);
      const gg = groundEllipsePath(f.x, f.y, R);
      ctx.save();
      ctx.globalAlpha = inv * 0.4; ctx.strokeStyle = f.glow || f.col; ctx.lineWidth = 2.4 * gg.p.k;
      for (let i = 0; i < 8; i++){
        const a = i / 8 * TAU + (f.x + f.y) * 0.01;
        ctx.beginPath();
        ctx.moveTo(gg.p.x + Math.cos(a) * gg.rx * 0.35, gg.p.y + Math.sin(a) * gg.ry * 0.35);
        ctx.lineTo(gg.p.x + Math.cos(a) * gg.rx * 1.05, gg.p.y + Math.sin(a) * gg.ry * 1.05);
        ctx.stroke();
      }
      ctx.restore();

    } else if (f.kind === 'pop' || f.kind === 'fizzle'){
      groundRing(f.x, f.y, (f.r || 20) * (0.4 + 1.3 * e), f.col,
                 5 * inv + 1, inv * (f.kind === 'pop' ? 0.8 : 0.35));

    } else if (f.kind === 'swing'){
      groundWedgePath(f.x, f.y, f.r * 0.55, f.r * 0.95, f.a - f.arc/2, f.a + f.arc/2);
      ctx.globalAlpha = inv * 0.4; ctx.fillStyle = '#D8D2E4'; ctx.fill();
    }
  }
  ctx.restore();
}

// chain arcs, muzzle flashes and the sustained ray live above the deck
function drawAirFx(){
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  for (const f of S.fx){
    if (f.delay > 0) continue;
    const k = clamp(f.t / f.life, 0, 1), inv = 1 - k;
    if (f.kind === 'chain'){
      const seed = Math.floor(f.t * 34);
      const pts = f.pts.map(p => CAM.project(p.x, p.y, 56));
      for (let pass = 0; pass < 2; pass++){
        ctx.globalAlpha = inv * (pass ? 0.95 : 0.32);
        ctx.strokeStyle = pass ? (f.glow || '#FFF') : f.col;
        ctx.lineWidth = pass ? (3.4 * inv + 1.4) : (14 * inv + 5);
        ctx.beginPath();
        for (let s = 0; s < pts.length - 1; s++){
          const a = pts[s], b = pts[s+1];
          const dx = b.x - a.x, dy = b.y - a.y;
          const L = Math.hypot(dx, dy) || 1;
          const nx = -dy / L, ny = dx / L;
          ctx.moveTo(a.x, a.y);
          for (let i = 1; i <= 5; i++){
            const t = i / 5;
            const amp = (i === 5 ? 0 : 12 * inv);
            const j = jitterAt(s * 11 + i, seed) * amp;
            ctx.lineTo(a.x + dx * t + nx * j, a.y + dy * t + ny * j);
          }
        }
        ctx.stroke();
      }
      ctx.globalAlpha = inv;
      for (let i = 1; i < pts.length; i++)
        drawGlow(pts[i].x, pts[i].y, 24 * inv + 6, f.glow || '#FFFFFF', 1);

    } else if (f.kind === 'muzzle'){
      const q = CAM.project(f.x, f.y, 70);
      ctx.globalAlpha = inv;
      drawGlow(q.x, q.y, (26 * inv + 8) * q.k, f.glow || f.col, 1);
      drawGlow(q.x, q.y, (12 * inv + 4) * q.k, '#FFFFFF', 0.9);
      const im = Assets.get('fx_impact');
      if (im){
        const s = (70 * inv + 26) * q.k;
        ctx.drawImage(im, q.x - s/2, q.y - s/2, s, s);
      }

    } else if (f.kind === 'gear'){
      const q = CAM.project(f.x, f.y, 60);
      ctx.save(); ctx.translate(q.x, q.y); ctx.rotate(f.t * 6); ctx.scale(q.k, q.k);
      ctx.globalAlpha = inv * 0.9;
      ctx.strokeStyle = PAL.brassLite; ctx.lineWidth = 5 * inv + 2;
      const R = 30 + 40 * easeOut(k);
      circ(0, 0, R); ctx.stroke();
      for (let i = 0; i < 8; i++){
        const a = i / 8 * TAU;
        ctx.beginPath();
        ctx.moveTo(Math.cos(a) * R, Math.sin(a) * R);
        ctx.lineTo(Math.cos(a) * (R + 10), Math.sin(a) * (R + 10)); ctx.stroke();
      }
      ctx.restore();
    }
  }
  ctx.restore();
}

function drawRay(){
  const R = S.player.ray;
  if (!R) return;
  const sk = S.slots[R.slot];
  if (!sk) return;
  const st = skillStats(sk), E = ELEMENTS[sk.element];
  const P = S.player, a = P.aim;
  const pulse = 0.85 + Math.sin(S.rt * 40) * 0.15;
  // scorch band on the deck
  groundBandPath(P.x, P.y, a, R.len, st.width * 1.1, 12);
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  ctx.globalAlpha = 0.35; ctx.fillStyle = E.color; ctx.fill();
  // the beam itself, at chest height
  const A = CAM.project(P.x + Math.cos(a) * 16, P.y + Math.sin(a) * 16, 62);
  const B = CAM.project(P.x + Math.cos(a) * R.len, P.y + Math.sin(a) * R.len, 62);
  const wA = st.width * 0.5 * pulse * A.k, wB = st.width * 0.5 * pulse * B.k;
  const nx = -(B.y - A.y), ny = (B.x - A.x);
  const L = Math.hypot(nx, ny) || 1;
  const ux = nx / L, uy = ny / L;
  const quad = (sa, sb, col, al) => {
    ctx.globalAlpha = al;
    ctx.fillStyle = col;
    ctx.beginPath();
    ctx.moveTo(A.x + ux*sa, A.y + uy*sa); ctx.lineTo(B.x + ux*sb, B.y + uy*sb);
    ctx.lineTo(B.x - ux*sb, B.y - uy*sb); ctx.lineTo(A.x - ux*sa, A.y - uy*sa);
    ctx.closePath(); ctx.fill();
  };
  quad(wA, wB, E.color, 0.6);
  quad(wA * 0.44, wB * 0.44, E.glow, 0.75);
  quad(wA * 0.16, wB * 0.16, '#FFFFFF', 0.85);
  ctx.globalAlpha = 1;
  drawGlow(A.x, A.y, 30 * A.k, E.glow, 0.9);
  drawGlow(B.x, B.y, 44 * B.k * pulse, E.glow, 1);
  drawGlow(B.x, B.y, 20 * B.k * pulse, '#FFFFFF', 0.9);
  ctx.restore();
}

/* --- particles & floating numbers, both billboarded ---------------------- */
function drawParticles(){
  const pool = Particles.pool;
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  for (const p of pool){
    if (!p.live || !p.add) continue;
    const k = p.life / p.max;
    const gy = p.gy === undefined ? p.y : p.gy;
    const q = CAM.project(p.x, gy, Math.max(0, gy - p.y));
    ctx.globalAlpha = clamp(k, 0, 1);
    if (p.kind === 'spark'){
      ctx.strokeStyle = p.col; ctx.lineWidth = p.size * k * q.k;
      ctx.beginPath();
      ctx.moveTo(q.x, q.y);
      ctx.lineTo(q.x - p.vx * 0.014 * p.w * q.k, q.y - p.vy * 0.014 * p.w * q.k);
      ctx.stroke();
    } else {
      ctx.fillStyle = p.col; circ(q.x, q.y, p.size * k * q.k); ctx.fill();
    }
  }
  ctx.globalCompositeOperation = 'source-over';
  const smoke = Assets.get('fx_smoke');
  for (const p of pool){
    if (!p.live || p.add) continue;
    const k = p.life / p.max;
    const gy = p.gy === undefined ? p.y : p.gy;
    const q = CAM.project(p.x, gy, Math.max(0, gy - p.y));
    if (p.kind === 'shard'){
      ctx.save();
      ctx.globalAlpha = clamp(k * 1.4, 0, 1);
      ctx.translate(q.x, q.y); ctx.rotate(p.rot); ctx.scale(q.k, q.k);
      ctx.fillStyle = p.col;
      ctx.fillRect(-p.size/2, -p.size/2, p.size, p.size * 0.7);
      ctx.strokeStyle = PAL.ink; ctx.lineWidth = 1.6;
      ctx.strokeRect(-p.size/2, -p.size/2, p.size, p.size * 0.7);
      ctx.restore();
    } else if (p.kind === 'smoke'){
      const r = p.size * (1.6 - k * 0.6) * q.k;
      ctx.globalAlpha = clamp(k * 0.7, 0, 1);
      if (smoke) ctx.drawImage(smoke, q.x - r, q.y - r, r * 2, r * 2);
      else { ctx.fillStyle = p.col; circ(q.x, q.y, r); ctx.fill(); }
    } else {
      ctx.globalAlpha = clamp(k, 0, 1);
      ctx.fillStyle = p.col; circ(q.x, q.y, p.size * k * q.k); ctx.fill();
    }
  }
  ctx.restore();
}

function drawNums(){
  ctx.save();
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  ctx.lineWidth = 5; ctx.lineJoin = 'round';
  let lastPx = -1;
  for (const n of S.nums){
    const k = n.t / n.life;
    const pop = n.crit ? (1 + Math.max(0, 0.5 - k * 4)) : 1;
    const gy = n.gy === undefined ? n.y : n.gy;
    const q = CAM.project(n.x, gy, Math.max(0, gy - n.y) + 40);
    ctx.globalAlpha = k < 0.7 ? 1 : (1 - (k - 0.7) / 0.3);
    const px = Math.max(8, Math.round(n.size * pop * q.k));
    if (px !== lastPx){ setFont(px, 800, true); lastPx = px; }
    // §2.9 — crit numbers are yellow with a bang
    const txt = n.crit ? n.text + '!!' : n.text;
    ctx.strokeStyle = PAL.ink; ctx.strokeText(txt, q.x, q.y);
    ctx.fillStyle = n.crit ? PAL.crit : n.col;
    ctx.fillText(txt, q.x, q.y);
  }
  ctx.restore();
}
