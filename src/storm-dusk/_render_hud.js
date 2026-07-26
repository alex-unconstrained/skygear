/* ---------------------------------------------------------------------------
   HUD — brass gauge plate over the dark base (§4.7)
--------------------------------------------------------------------------- */
function hudScale(){ return clamp(Math.min(View.w / 1400, View.h / 860), 0.6, 1.4); }

function brassPanel(x, y, w, h, r, alpha){
  ctx.save();
  ctx.globalAlpha = alpha === undefined ? 1 : alpha;
  rr(x, y, w, h, r);
  ctx.fillStyle = 'rgba(20,18,27,0.92)'; ctx.fill();
  ctx.strokeStyle = PAL.ink; ctx.lineWidth = 5; ctx.stroke();
  rr(x + 3, y + 3, w - 6, h - 6, Math.max(2, r - 3));
  ctx.strokeStyle = hexToRgba(PAL.brass, 0.85); ctx.lineWidth = 2.2; ctx.stroke();
  ctx.fillStyle = PAL.brass;
  const pd = 9;
  for (const p of [[x+pd,y+pd],[x+w-pd,y+pd],[x+pd,y+h-pd],[x+w-pd,y+h-pd]]){
    ctx.beginPath(); ctx.arc(p[0], p[1], 2.6, 0, TAU); ctx.fill();
  }
  ctx.restore();
}
function gaugeRing(cx, cy, r, col, teeth){
  const asset = Assets.get('ui_gauge');
  if (asset){ ctx.drawImage(asset, cx - r * 1.22, cy - r * 1.22, r * 2.44, r * 2.44); return; }
  ctx.save();
  ctx.translate(cx, cy);
  ctx.strokeStyle = col; ctx.lineWidth = 2.6;
  circ(0, 0, r * 1.1); ctx.stroke();
  ctx.lineWidth = 2;
  for (let i = 0; i < (teeth || 16); i++){
    const a = i / (teeth || 16) * TAU;
    const l = i % 4 === 0 ? 0.2 : 0.11;
    ctx.beginPath();
    ctx.moveTo(Math.cos(a) * r * 1.1, Math.sin(a) * r * 1.1);
    ctx.lineTo(Math.cos(a) * r * (1.1 + l), Math.sin(a) * r * (1.1 + l));
    ctx.stroke();
  }
  ctx.restore();
}

const SKILL_ICON_ASSET = {
  CLOSEHIT:'ui_icon_slash', LINE_BURST:'ui_icon_hook', CONE:'ui_icon_cone',
  RANGED_AOE:'ui_icon_aoe', CHAIN:'ui_icon_ult', RAY:'ui_icon_turret',
};
function paintGlyph(shape, r, col, glow){
  ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  ctx.strokeStyle = col; ctx.fillStyle = col;
  ctx.shadowColor = glow; ctx.shadowBlur = 12;
  if (shape === 'CLOSEHIT'){
    ctx.lineWidth = r * 0.30;
    ctx.beginPath(); ctx.arc(-r*0.35, 0, r * 0.82, -1.15, 1.15); ctx.stroke();
    ctx.strokeStyle = glow; ctx.lineWidth = r * 0.15;
    ctx.beginPath(); ctx.arc(-r*0.35, 0, r * 0.82, -0.95, 0.95); ctx.stroke();
  } else if (shape === 'LINE_BURST'){
    ctx.lineWidth = r * 0.28;
    ctx.beginPath(); ctx.moveTo(-r*0.9, 0); ctx.lineTo(r*0.42, 0); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(r*0.92, 0); ctx.lineTo(r*0.30, -r*0.46); ctx.lineTo(r*0.30, r*0.46);
    ctx.closePath(); ctx.fill();
  } else if (shape === 'CONE'){
    ctx.beginPath(); ctx.moveTo(-r*0.85, 0); ctx.arc(-r*0.85, 0, r * 1.6, -0.6, 0.6);
    ctx.closePath(); ctx.globalAlpha = 0.4; ctx.fill();
    ctx.globalAlpha = 1; ctx.lineWidth = r * 0.16; ctx.stroke();
  } else if (shape === 'RANGED_AOE'){
    ctx.lineWidth = r * 0.19;
    ctx.beginPath(); ctx.arc(0, 0, r * 0.76, 0, TAU); ctx.stroke();
    ctx.globalAlpha = 0.32; ctx.fill(); ctx.globalAlpha = 1;
    ctx.strokeStyle = glow; ctx.lineWidth = r * 0.16;
    ctx.beginPath(); ctx.arc(0, 0, r * 0.32, 0, TAU); ctx.stroke();
  } else if (shape === 'CHAIN'){
    ctx.lineWidth = r * 0.2;
    ctx.beginPath();
    ctx.moveTo(-r*0.95, r*0.4); ctx.lineTo(-r*0.25, -r*0.5);
    ctx.lineTo(r*0.15, r*0.25); ctx.lineTo(r*0.95, -r*0.55);
    ctx.stroke();
    ctx.strokeStyle = glow; ctx.lineWidth = r * 0.08; ctx.stroke();
  } else {
    ctx.globalAlpha = 0.5; ctx.lineWidth = r * 0.42;
    ctx.beginPath(); ctx.moveTo(-r*0.8, 0); ctx.lineTo(r*0.95, 0); ctx.stroke();
    ctx.globalAlpha = 1; ctx.strokeStyle = glow; ctx.lineWidth = r * 0.16;
    ctx.beginPath(); ctx.moveTo(-r*0.8, 0); ctx.lineTo(r*0.95, 0); ctx.stroke();
    ctx.fillStyle = col; circ(-r*0.82, 0, r * 0.26); ctx.fill();
  }
}
function drawShapeGlyph(shape, cx, cy, r, col, glow){
  const a = Assets.get(SKILL_ICON_ASSET[shape]);
  if (a){ ctx.drawImage(a, cx - r * 1.5, cy - r * 1.5, r * 3, r * 3); return; }
  r = Math.max(1, Math.round(r));
  const half = Math.ceil(r * 1.9 + 18);
  const cn = cachedSprite('g|'+shape+'|'+r+'|'+col, half*2, half*2, (c2, w, h) => {
    c2.translate(w/2, h/2);
    paintGlyph(shape, r, col, glow);
  });
  ctx.drawImage(cn, cx - half, cy - half);
}

const SLOT_KEYS = ['LMB', 'RMB', 'SPACE', 'SHIFT'];
const SLOT_UNLOCK_WAVE = [1, 1, 3, 6];

function drawSkillBar(){
  const HS = hudScale();
  const size = 78 * HS, gap = 14 * HS;
  const total = size * 4 + gap * 3;
  const x0 = (View.w - total) / 2;
  const y0 = View.h - size - 46 * HS;

  const frame = Assets.get('ui_frame');
  if (frame) ctx.drawImage(frame, x0 - 40*HS, y0 - 26*HS, total + 80*HS, size + 72*HS);
  else brassPanel(x0 - 16*HS, y0 - 14*HS, total + 32*HS, size + 46*HS, 12*HS, 0.94);

  for (let i = 0; i < 4; i++){
    const x = x0 + i * (size + gap), y = y0;
    const sk = S.slots[i];
    const locked = i >= S.unlockedSlots;
    ctx.save();
    ctx.translate(x + size/2, y + size/2);
    circ(0, 0, size * 0.46);
    ctx.fillStyle = locked ? 'rgba(13,11,18,0.95)' : PAL.base;
    fillStroke(null, PAL.ink, 5);
    ctx.fillStyle = locked ? 'rgba(13,11,18,0.95)' : PAL.base; ctx.fill();
    gaugeRing(0, 0, size * 0.46, locked ? '#3A3440' : hexToRgba(PAL.brass, 0.9), 16);

    if (locked){
      ctx.strokeStyle = '#4A4450'; ctx.lineWidth = 4;
      rr(-size*0.16, -size*0.05, size*0.32, size*0.24, 4); ctx.stroke();
      ctx.beginPath(); ctx.arc(0, -size*0.05, size*0.12, Math.PI, 0); ctx.stroke();
      setFont(Math.round(12*HS), 700, true);
      textOut('WAVE ' + SLOT_UNLOCK_WAVE[i], 0, size*0.32, '#6E667A');
    } else if (!sk){
      setFont(Math.round(13*HS), 700, true);
      textOut('EMPTY', 0, 0, '#5E5668');
    } else {
      const E = ELEMENTS[sk.element], st = skillStats(sk);
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      drawGlow(0, 0, size * 0.5, E.color, 0.22);
      ctx.restore();
      drawShapeGlyph(sk.shape, 0, -2*HS, size * 0.28, E.color, E.glow);
      if (sk.cdLeft > 0){
        const frac = clamp(sk.cdLeft / Math.max(0.001, st.cd), 0, 1);
        ctx.save();
        circ(0, 0, size * 0.45); ctx.clip();
        ctx.globalAlpha = 0.76; ctx.fillStyle = '#0B0910';
        ctx.beginPath(); ctx.moveTo(0, 0);
        ctx.arc(0, 0, size, -Math.PI/2, -Math.PI/2 + TAU * frac);
        ctx.closePath(); ctx.fill();
        ctx.restore();
        setFont(Math.round(19*HS), 800, true);
        textOut(sk.cdLeft.toFixed(1), 0, -2*HS, PAL.bone, PAL.ink, 4);
      }
      if (S.player.ray && S.player.ray.slot === i){
        const kk = 1 - S.player.ray.t / st.maxDur;
        ctx.strokeStyle = E.glow; ctx.lineWidth = 4;
        ctx.beginPath();
        ctx.arc(0, 0, size * 0.46, -Math.PI/2, -Math.PI/2 + TAU * clamp(kk, 0, 1));
        ctx.stroke();
      }
      if (sk.readyPulse > 0){
        const kk = sk.readyPulse / 0.35;
        ctx.save();
        ctx.globalAlpha = kk * 0.9;
        ctx.strokeStyle = PAL.teal; ctx.lineWidth = 2 + 6 * kk;
        circ(0, 0, size * 0.46 + kk * 12); ctx.stroke();
        ctx.restore();
      }
      if (slotHeld(i) && sk.cdLeft <= 0){
        ctx.strokeStyle = E.glow; ctx.lineWidth = 3;
        circ(0, 0, size * 0.42); ctx.stroke();
      }
      setFont(Math.round(11.5*HS), 700, true);
      textOut(skillName(sk).toUpperCase(), 0, size/2 + 14*HS, E.color, PAL.ink, 3.5);
    }
    setFont(Math.round(11*HS), 800, true);
    const kw = ctx.measureText(SLOT_KEYS[i]).width + 12*HS;
    rr(-kw/2, -size/2 - 12*HS, kw, 16*HS, 4*HS);
    ctx.fillStyle = PAL.ink; ctx.fill();
    ctx.strokeStyle = locked ? '#4A4450' : PAL.brass; ctx.lineWidth = 1.8; ctx.stroke();
    textOut(SLOT_KEYS[i], 0, -size/2 - 4*HS, locked ? '#6E667A' : PAL.bone);
    ctx.restore();
  }
}

function drawHealthPanel(){
  const HS = hudScale();
  const w = 262 * HS, h = 84 * HS;
  const x = 20 * HS, y = View.h - h - 20 * HS;
  brassPanel(x, y, w, h, 10*HS, 0.94);
  const P = S.player;

  const port = Assets.get('ui_portrait');
  const pr = 26 * HS;
  ctx.save();
  circ(x + 16*HS + pr, y + h/2, pr); ctx.clip();
  if (port) ctx.drawImage(port, x + 16*HS, y + h/2 - pr, pr*2, pr*2);
  else {
    ctx.fillStyle = '#241F2E'; ctx.fillRect(x + 16*HS, y + h/2 - pr, pr*2, pr*2);
    withCtxNone(() => {});
    ctx.save();
    ctx.translate(x + 16*HS + pr, y + h/2 + pr * 1.5);
    ctx.scale(pr / 62, pr / 62);
    ctx.lineJoin = 'round';
    paintHero(false, false);
    ctx.restore();
  }
  ctx.restore();
  ctx.strokeStyle = PAL.brass; ctx.lineWidth = 2.4;
  circ(x + 16*HS + pr, y + h/2, pr); ctx.stroke();

  const bx = x + 16*HS + pr*2 + 12*HS, bw = w - (bx - x) - 16*HS;
  const frac = clamp(P.hp / P.maxHp, 0, 1);
  const by = y + 22*HS, bh = 20*HS;
  rr(bx, by, bw, bh, 4*HS);
  ctx.fillStyle = '#0B0910'; ctx.fill();
  ctx.strokeStyle = PAL.ink; ctx.lineWidth = 3; ctx.stroke();
  const g = ctx.createLinearGradient(bx, by, bx, by + bh);
  g.addColorStop(0, frac > 0.3 ? '#E8542E' : '#FF7A5A');
  g.addColorStop(1, frac > 0.3 ? '#8B2418' : '#B0301A');
  rr(bx + 1, by + 1, Math.max(0, (bw - 2) * frac), bh - 2, 3*HS);
  ctx.fillStyle = g; ctx.fill();
  ctx.strokeStyle = hexToRgba(PAL.ink, 0.5); ctx.lineWidth = 2;
  const segs = Math.max(1, Math.round(P.maxHp / 20));
  for (let i = 1; i < segs; i++){
    const sx = bx + bw * (i / segs);
    ctx.beginPath(); ctx.moveTo(sx, by + 2); ctx.lineTo(sx, by + bh - 2); ctx.stroke();
  }
  setFont(Math.round(12*HS), 700, true);
  textOut('CAPTAIN', bx, y + 12*HS, '#8B8296', null, 0, 'left');
  setFont(Math.round(14*HS), 800, true);
  textOut(Math.ceil(P.hp) + ' / ' + Math.round(P.maxHp), bx + bw, y + 12*HS, PAL.bone, PAL.ink, 3, 'right');

  const py = y + h - 18*HS;
  setFont(Math.round(11*HS), 700, true);
  textOut('DASH [E]', bx, py, '#8B8296', null, 0, 'left');
  for (let i = 0; i < S.mods.dashCharges; i++){
    const px = bx + 62*HS + i * 22*HS;
    const filled = i < P.dashStock;
    ctx.beginPath(); ctx.arc(px, py, 7*HS, 0, TAU);
    ctx.fillStyle = filled ? PAL.teal : '#201C28'; ctx.fill();
    ctx.strokeStyle = PAL.ink; ctx.lineWidth = 2.4; ctx.stroke();
    if (!filled && i === P.dashStock && P.dashCd > 0){
      const kk = 1 - clamp(P.dashCd / dashCdMax(), 0, 1);
      ctx.beginPath(); ctx.moveTo(px, py);
      ctx.arc(px, py, 7*HS, -Math.PI/2, -Math.PI/2 + TAU * kk); ctx.closePath();
      ctx.fillStyle = hexToRgba(PAL.teal, 0.45); ctx.fill();
    }
  }
}
function withCtxNone(f){ f(); }

function drawTopBar(){
  const HS = hudScale();
  const w = 470 * HS, h = 84 * HS;
  const x = (View.w - w) / 2, y = 14 * HS;
  brassPanel(x, y, w, h, 10*HS, 0.94);
  const B = S.boiler;
  const frac = clamp(B.hp / B.maxHp, 0, 1);
  const bx = x + 18*HS, by = y + 44*HS, bw = w - 36*HS, bh = 20*HS;
  rr(bx, by, bw, bh, 4*HS);
  ctx.fillStyle = '#0B0910'; ctx.fill();
  ctx.strokeStyle = PAL.ink; ctx.lineWidth = 3; ctx.stroke();
  const hot = frac > 0.35;
  const g = ctx.createLinearGradient(bx, by, bx, by + bh);
  g.addColorStop(0, hot ? PAL.fireCore : '#FF7A5A');
  g.addColorStop(1, hot ? PAL.fire : '#B0301A');
  rr(bx + 1, by + 1, Math.max(0, (bw - 2) * frac), bh - 2, 3*HS);
  ctx.fillStyle = g; ctx.fill();
  if (!hot){
    ctx.save(); ctx.globalAlpha = 0.3 + Math.sin(S.rt * 7) * 0.2;
    ctx.fillStyle = PAL.danger;
    rr(bx + 1, by + 1, Math.max(0, (bw - 2) * frac), bh - 2, 3*HS); ctx.fill();
    ctx.restore();
  }
  setFont(Math.round(12.5*HS), 700, true);
  textOut('BOILER', bx, by - 9*HS, PAL.brass, null, 0, 'left');
  setFont(Math.round(13*HS), 800, true);
  textOut(Math.ceil(B.hp) + ' / ' + Math.round(B.maxHp), bx + bw, by - 9*HS, PAL.bone, PAL.ink, 3, 'right');
  setFont(Math.round(30*HS), 900, true);
  const wv = Math.max(1, S.wave);
  textOut('WAVE ' + wv + (WAVES[wv-1] && WAVES[wv-1].boss ? '' : ' / ' + TUNING.totalWaves),
          x + w/2, y + 24*HS, PAL.bone, PAL.ink, 5);
  const left = S.phase === 'fight' ? pendingCount() : 0;
  setFont(Math.round(12.5*HS), 700, true);
  if (S.bossRef) textOut('THE BRASS COLOSSUS', x + w/2, y + h + 12*HS, PAL.danger, PAL.ink, 4);
  else if (left > 0) textOut(left + ' BOARDER' + (left === 1 ? '' : 'S') + ' REMAINING',
                             x + w/2, y + h + 12*HS, '#9C93A8', PAL.ink, 4);
  if (S.bossRef){
    const bw2 = Math.min(View.w * 0.62, 760 * HS), bh2 = 20 * HS;
    const bx2 = (View.w - bw2)/2, by2 = y + h + 26*HS;
    rr(bx2 - 4, by2 - 4, bw2 + 8, bh2 + 8, 6);
    ctx.fillStyle = 'rgba(13,11,18,0.9)'; ctx.fill();
    ctx.strokeStyle = PAL.ink; ctx.lineWidth = 4; ctx.stroke();
    const bf = clamp(S.bossRef.hp / S.bossRef.maxHp, 0, 1);
    const bg = ctx.createLinearGradient(bx2, by2, bx2, by2 + bh2);
    bg.addColorStop(0, PAL.fire); bg.addColorStop(1, '#8B2418');
    rr(bx2, by2, bw2 * bf, bh2, 4); ctx.fillStyle = bg; ctx.fill();
    ctx.strokeStyle = PAL.brass; ctx.lineWidth = 2;
    rr(bx2, by2, bw2, bh2, 4); ctx.stroke();
  }
}

function drawCombo(){
  if (S.stats.combo < 3) return;
  const HS = hudScale();
  const x = View.w - 26*HS, y = 40*HS;
  const k = clamp(S.stats.comboT / 2.6, 0, 1);
  const pop = 1 + Math.max(0, 0.35 - (2.6 - S.stats.comboT) * 1.6);
  ctx.save();
  ctx.globalAlpha = 0.35 + k * 0.65;
  setFont(Math.round(46*HS*pop), 900, true);
  textOut(S.stats.combo + '', x, y, PAL.crit, PAL.ink, 6, 'right');
  setFont(Math.round(14*HS), 700, true);
  textOut('CHAIN', x, y + 30*HS, '#9C93A8', PAL.ink, 4, 'right');
  ctx.fillStyle = hexToRgba(PAL.crit, 0.8);
  ctx.fillRect(x - 90*HS, y + 44*HS, 90*HS * k, 3*HS);
  ctx.restore();
}

function drawBanner(){
  if (!S.banner) return;
  const b = S.banner, HS = hudScale();
  const k = b.t / b.life;
  let scale = 1, alpha = 1;
  if (k < 0.16){ scale = lerp(2.6, 1, easeOut(k / 0.16)); alpha = k / 0.16; }
  else if (k > 0.78){ alpha = 1 - (k - 0.78) / 0.22; scale = 1 + (k - 0.78) * 0.4; }
  ctx.save();
  ctx.globalAlpha = clamp(alpha, 0, 1);
  ctx.translate(View.w / 2, View.h * 0.28);
  ctx.scale(scale, scale);
  if (b.kind === 'wave'){
    setFont(Math.round(64*HS), 900, true);
    textOut('WAVE ' + b.n, 0, 0, PAL.bone, PAL.ink, 9);
    setFont(Math.round(17*HS), 700, true);
    textOut('BOARDERS INBOUND', 0, 42*HS, PAL.teal, PAL.ink, 5);
  } else if (b.kind === 'clear'){
    setFont(Math.round(64*HS), 900, true);
    textOut('WAVE ' + b.n + ' COMPLETE', 0, 0, PAL.crit, PAL.ink, 10);
    setFont(Math.round(17*HS), 700, true);
    textOut('DRAFT AN UPGRADE', 0, 44*HS, PAL.bone, PAL.ink, 5);
  } else if (b.kind === 'boss'){
    setFont(Math.round(38*HS), 900, true);
    textOut('FINAL WAVE', 0, -34*HS, PAL.danger, PAL.ink, 8);
    setFont(Math.round(66*HS), 900, true);
    textOut('THE BRASS COLOSSUS', 0, 8*HS, PAL.crit, PAL.ink, 10);
    setFont(Math.round(17*HS), 700, true);
    textOut('BOARDS YOUR SHIP', 0, 52*HS, PAL.bone, PAL.ink, 5);
  }
  ctx.restore();
  if (b.kind === 'type'){
    const blurb = { SCRAPPER:'boarding automaton — closes and swings',
                    GUNNER:'tesla drone — shoots from range',
                    ARMORED:'furnace knight — plated at the front, flank it',
                    SWARM:'cog-gremlins — ignore you, run at the Boiler' }[b.type] || '';
    const name = { SCRAPPER:'BOARDING AUTOMATON', GUNNER:'TESLA DRONE',
                   ARMORED:'FURNACE KNIGHT', SWARM:'COG-GREMLIN' }[b.type] || b.type;
    const slide = easeOut(clamp(b.t / 0.3, 0, 1)) * (1 - clamp((b.t - (b.life - 0.35)) / 0.35, 0, 1));
    ctx.save();
    ctx.globalAlpha = clamp(slide, 0, 1);
    const pw = 350*HS, ph = 58*HS;
    const px = 20*HS, py = View.h - 138*HS - ph;
    brassPanel(px, py, pw, ph, 9*HS, 0.95);
    ctx.fillStyle = PAL.danger;
    ctx.fillRect(px + 6*HS, py + 8*HS, 4*HS, ph - 16*HS);
    setFont(Math.round(18*HS), 900, true);
    textOut('NEW  ·  ' + name, px + 22*HS, py + 20*HS, PAL.danger, PAL.ink, 4, 'left');
    setFont(Math.round(12.5*HS), 600, false);
    textOut(blurb, px + 22*HS, py + 40*HS, '#9C93A8', null, 0, 'left');
    ctx.restore();
  }
}

function drawHints(){
  if (S.hintT <= 0 || S.wave > 1) return;
  const HS = hudScale();
  const a = clamp(S.hintT / 2.5, 0, 1);
  ctx.save();
  ctx.globalAlpha = a;
  const rows = [['W A S D','move'],['MOUSE','aim'],['E','dash — invulnerable'],
                ['LMB / RMB','fire your two skills']];
  const pw = 234*HS, ph = 30*HS + rows.length * 26*HS;
  const px = 20*HS, py = 120*HS;
  brassPanel(px, py, pw, ph, 9*HS, 0.92 * a);
  rows.forEach((r, i) => {
    const y = py + 26*HS + i * 26*HS;
    setFont(Math.round(13*HS), 800, true);
    textOut(r[0], px + 16*HS, y, PAL.teal, null, 0, 'left');
    setFont(Math.round(13*HS), 600, false);
    textOut(r[1], px + 108*HS, y, '#9C93A8', null, 0, 'left');
  });
  const b = CAM.project(S.boiler.x, S.boiler.y, PRESET.boilerH + 90);
  const bob = Math.sin(S.rt * 4) * 4;
  ctx.globalAlpha = a * (0.72 + Math.sin(S.rt * 4) * 0.2);
  setFont(Math.round(17*HS), 800, true);
  textOut('DEFEND THE BOILER', b.x, b.y - 26*HS + bob, PAL.fireCore, PAL.ink, 6);
  ctx.fillStyle = PAL.fireCore;
  ctx.beginPath();
  ctx.moveTo(b.x, b.y - 4*HS + bob); ctx.lineTo(b.x - 9*HS, b.y - 17*HS + bob);
  ctx.lineTo(b.x + 9*HS, b.y - 17*HS + bob); ctx.closePath(); ctx.fill();
  ctx.restore();
}

function drawVolToast(){
  if (S.volToast <= 0) return;
  const HS = hudScale();
  ctx.save();
  ctx.globalAlpha = clamp(S.volToast, 0, 1);
  const w = 190*HS, h = 40*HS, x = View.w - w - 18*HS, y = View.h - h - 18*HS;
  brassPanel(x, y, w, h, 8*HS, 0.94);
  setFont(Math.round(13*HS), 700, true);
  if (Sound.muted) textOut('MUTED  [M]', x + w/2, y + h/2, PAL.danger);
  else {
    textOut('VOLUME  ' + Math.round(Sound.vol * 100) + '%', x + w/2 - 30*HS, y + h/2, PAL.bone);
    ctx.fillStyle = '#2A2434'; ctx.fillRect(x + w/2 + 8*HS, y + h/2 - 4*HS, 60*HS, 8*HS);
    ctx.fillStyle = PAL.brass; ctx.fillRect(x + w/2 + 8*HS, y + h/2 - 4*HS, 60*HS * Sound.vol, 8*HS);
  }
  ctx.restore();
}

function drawFps(){
  const b = S.ftBuf, n = Math.min(S.ftIdx, b.length);
  if (n < 4) return;
  let sum = 0, worst = 0;
  for (let i = 0; i < n; i++){ sum += b[i]; if (b[i] > worst) worst = b[i]; }
  const avg = sum / n;
  let live = 0, parts = 0;
  for (const e of S.enemies) if (!e.dead) live++;
  for (const p of Particles.pool) if (p.live) parts++;
  const HS = hudScale();
  ctx.save();
  const lines = [
    Math.round(1/avg) + ' fps   ' + (avg*1000).toFixed(1) + ' ms   peak ' + (worst*1000).toFixed(0) + ' ms',
    live + ' boarders   ' + parts + ' particles   assets ' + Assets.ready + '/' + Assets.total,
    PRESET.name + '   pitch ' + CAM.pitch.toFixed(2) + '   ' +
      (CAM.follow ? 'follow' : 'fixed') + (PRESET.xray ? '   xray' : ''),
  ];
  setFont(Math.round(13*HS), 700, false);
  const w = Math.max(ctx.measureText(lines[0]).width, ctx.measureText(lines[1]).width) + 22*HS;
  brassPanel(View.w - w - 16*HS, 16*HS, w, 68*HS, 7*HS, 0.92);
  const cols = [1/avg > 55 ? PAL.teal : PAL.dangerIn, '#9C93A8', PAL.brass];
  lines.forEach((l, i) => textOut(l, View.w - w - 5*HS, 30*HS + i * 19*HS,
                                  cols[i], null, 0, 'left'));
  ctx.restore();
}

/* With a moving camera the Boiler can drift to the edge of frame. It is the
   thing you lose the run by ignoring, so it gets a persistent marker: a health
   pip on screen when visible, an arrow pinned to the edge when it is not. */
function drawObjectiveMarker(){
  if (!CAM.follow || !S.boiler) return;
  const B = S.boiler;
  const p = CAM.project(B.x, B.y, 150);
  const HS = hudScale();
  const m = 74 * HS;
  const onScreen = p.x > m && p.x < View.w - m && p.y > m * 1.4 && p.y < View.h - m;
  const frac = clamp(B.hp / B.maxHp, 0, 1);
  const hurt = frac < 0.5;

  ctx.save();
  if (onScreen){
    // a slim pip above the Boiler, only once it has taken a hit
    if (frac >= 0.999){ ctx.restore(); return; }
    const w = 74 * HS, h = 7 * HS;
    ctx.globalAlpha = 0.9;
    rr(p.x - w/2 - 2, p.y - 2, w + 4, h + 4, 3);
    ctx.fillStyle = 'rgba(13,11,18,0.85)'; ctx.fill();
    ctx.fillStyle = hurt ? PAL.danger : PAL.fire;
    rr(p.x - w/2, p.y, w * frac, h, 2); ctx.fill();
    ctx.restore();
    return;
  }
  // off frame: clamp to the edge and point at it
  const cx = View.w / 2, cy = View.h / 2;
  let dx = p.x - cx, dy = p.y - cy;
  const len = Math.hypot(dx, dy) || 1;
  dx /= len; dy /= len;
  const ex = clamp(cx + dx * View.w, m, View.w - m);
  const ey = clamp(cy + dy * View.h, m * 1.4, View.h - m);
  const pulse = 0.72 + Math.sin(S.rt * (hurt ? 9 : 4)) * 0.24;
  ctx.globalAlpha = pulse;
  ctx.translate(ex, ey);
  ctx.globalCompositeOperation = 'lighter';
  drawGlow(0, 0, 44 * HS, hurt ? PAL.danger : PAL.fire, 0.55);
  ctx.globalCompositeOperation = 'source-over';
  ctx.rotate(Math.atan2(dy, dx));
  ctx.beginPath();
  ctx.moveTo(20 * HS, 0); ctx.lineTo(-8 * HS, -14 * HS); ctx.lineTo(-2 * HS, 0);
  ctx.lineTo(-8 * HS, 14 * HS); ctx.closePath();
  fillStroke(hurt ? PAL.danger : PAL.fire, PAL.ink, 4);
  ctx.rotate(-Math.atan2(dy, dx));
  setFont(Math.round(11 * HS), 800, true);
  textOut('BOILER ' + Math.round(frac * 100) + '%', 0, 28 * HS,
          hurt ? PAL.danger : PAL.bone, PAL.ink, 4);
  ctx.restore();
}

function drawHUD(){
  drawTopBar(); drawHealthPanel(); drawSkillBar();
  drawCombo(); drawBanner(); drawHints(); drawVolToast();
}
