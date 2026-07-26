/* ---------------------------------------------------------------------------
   SCREENS — draft, title, pause, endings
--------------------------------------------------------------------------- */
const CARD_ICON = {
  burnDmg:'flame', burnDur:'flame', slowAmt:'frost', brittle:'frost', stun:'bolt',
  knock:'steam', scald:'steam', hp:'heart', spd:'boot', dashcd:'dash', dashdmg:'dash',
  dashchg:'dash', crit:'crit', critx:'crit', scrap:'scrap', lifesteal:'scrap',
  boilerhp:'boiler', boilerdr:'boiler', fifth:'gear', residue:'burst', autofire:'burst',
  killboom:'burst',
};
function paintCardIcon(kind, r, col, glow){
  ctx.lineJoin = 'round'; ctx.lineCap = 'round';
  ctx.strokeStyle = col; ctx.fillStyle = col;
  ctx.shadowColor = glow || col; ctx.shadowBlur = 14;
  ctx.lineWidth = r * 0.22;
  if (kind === 'flame'){
    ctx.beginPath(); ctx.moveTo(0, -r);
    ctx.bezierCurveTo(r*0.85, -r*0.2, r*0.7, r*0.75, 0, r);
    ctx.bezierCurveTo(-r*0.7, r*0.75, -r*0.85, -r*0.2, 0, -r);
    ctx.closePath(); ctx.fill();
    ctx.fillStyle = PAL.fireCore;
    ctx.beginPath(); ctx.moveTo(0, -r*0.25);
    ctx.bezierCurveTo(r*0.42, r*0.1, r*0.34, r*0.62, 0, r*0.78);
    ctx.bezierCurveTo(-r*0.34, r*0.62, -r*0.42, r*0.1, 0, -r*0.25);
    ctx.closePath(); ctx.fill();
  } else if (kind === 'frost'){
    for (let i = 0; i < 3; i++){
      const a = i / 3 * Math.PI;
      ctx.beginPath();
      ctx.moveTo(-Math.cos(a)*r, -Math.sin(a)*r);
      ctx.lineTo(Math.cos(a)*r, Math.sin(a)*r); ctx.stroke();
      for (const s of [-1, 1]){
        const bx = Math.cos(a)*r*s*0.62, by = Math.sin(a)*r*s*0.62;
        ctx.beginPath(); ctx.moveTo(bx, by);
        ctx.lineTo(bx + Math.cos(a+0.9)*r*0.32*s, by + Math.sin(a+0.9)*r*0.32*s); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(bx, by);
        ctx.lineTo(bx + Math.cos(a-0.9)*r*0.32*s, by + Math.sin(a-0.9)*r*0.32*s); ctx.stroke();
      }
    }
  } else if (kind === 'bolt'){
    ctx.beginPath();
    ctx.moveTo(r*0.28, -r); ctx.lineTo(-r*0.5, r*0.12); ctx.lineTo(-r*0.03, r*0.12);
    ctx.lineTo(-r*0.3, r); ctx.lineTo(r*0.55, -r*0.18); ctx.lineTo(r*0.07, -r*0.18);
    ctx.closePath(); ctx.fill();
  } else if (kind === 'steam'){
    for (let i = 0; i < 3; i++){
      const yy = -r*0.5 + i * r*0.55;
      ctx.beginPath(); ctx.moveTo(-r*0.9, yy);
      ctx.bezierCurveTo(-r*0.3, yy - r*0.4, r*0.3, yy + r*0.4, r*0.9, yy); ctx.stroke();
    }
  } else if (kind === 'heart'){
    ctx.beginPath(); ctx.moveTo(0, r*0.85);
    ctx.bezierCurveTo(-r*1.35, -r*0.1, -r*0.5, -r*1.05, 0, -r*0.35);
    ctx.bezierCurveTo(r*0.5, -r*1.05, r*1.35, -r*0.1, 0, r*0.85);
    ctx.closePath(); ctx.fill();
  } else if (kind === 'boot'){
    ctx.beginPath();
    ctx.moveTo(-r*0.35, -r*0.9); ctx.lineTo(r*0.2, -r*0.9); ctx.lineTo(r*0.2, r*0.15);
    ctx.lineTo(r, r*0.5); ctx.lineTo(r, r*0.85); ctx.lineTo(-r*0.6, r*0.85); ctx.lineTo(-r*0.6, -r*0.55);
    ctx.closePath(); ctx.fill();
  } else if (kind === 'dash'){
    for (let i = 0; i < 3; i++){
      const ox = -r*0.75 + i * r*0.7;
      ctx.globalAlpha = 0.35 + i * 0.32;
      ctx.beginPath();
      ctx.moveTo(ox - r*0.28, -r*0.62); ctx.lineTo(ox + r*0.34, 0); ctx.lineTo(ox - r*0.28, r*0.62);
      ctx.lineWidth = r * 0.26; ctx.stroke();
    }
    ctx.globalAlpha = 1;
  } else if (kind === 'crit'){
    ctx.beginPath();
    for (let i = 0; i < 10; i++){
      const a = i / 10 * TAU - Math.PI/2;
      const rr2 = i % 2 ? r * 0.42 : r;
      i ? ctx.lineTo(Math.cos(a)*rr2, Math.sin(a)*rr2) : ctx.moveTo(Math.cos(a)*rr2, Math.sin(a)*rr2);
    }
    ctx.closePath(); ctx.fill();
  } else if (kind === 'scrap' || kind === 'gear'){
    ctx.beginPath(); circ(0, 0, r*0.6); ctx.lineWidth = r*0.3; ctx.stroke();
    for (let i = 0; i < 8; i++){
      const a = i / 8 * TAU;
      ctx.beginPath();
      ctx.moveTo(Math.cos(a)*r*0.72, Math.sin(a)*r*0.72);
      ctx.lineTo(Math.cos(a)*r, Math.sin(a)*r); ctx.lineWidth = r*0.24; ctx.stroke();
    }
    if (kind === 'scrap'){
      ctx.fillStyle = PAL.teal;
      ctx.fillRect(-r*0.4, -r*0.12, r*0.8, r*0.24);
      ctx.fillRect(-r*0.12, -r*0.4, r*0.24, r*0.8);
    }
  } else if (kind === 'boiler'){
    ctx.beginPath(); circ(0, 0, r*0.8); ctx.lineWidth = r*0.24; ctx.stroke();
    ctx.fillStyle = PAL.fireCore; circ(0, r*0.1, r*0.34); ctx.fill();
    ctx.strokeStyle = col; ctx.lineWidth = r*0.18;
    for (const s of [-1, 1]){
      ctx.beginPath(); ctx.moveTo(s*r*0.8, -r*0.5); ctx.lineTo(s*r*1.15, -r*0.5); ctx.stroke();
    }
  } else {
    for (let i = 0; i < 8; i++){
      const a = i / 8 * TAU;
      ctx.beginPath();
      ctx.moveTo(Math.cos(a)*r*0.34, Math.sin(a)*r*0.34);
      ctx.lineTo(Math.cos(a)*r, Math.sin(a)*r); ctx.lineWidth = r*0.2; ctx.stroke();
    }
    ctx.beginPath(); circ(0, 0, r*0.26); ctx.fill();
  }
}
function drawCardIcon(kind, cx, cy, r, col, glow){
  r = Math.max(1, Math.round(r));
  const half = Math.ceil(r * 1.8 + 18);
  const cn = cachedSprite('i|'+kind+'|'+r+'|'+col, half*2, half*2, (c2, w, h) => {
    c2.translate(w/2, h/2);
    paintCardIcon(kind, r, col, glow);
  });
  ctx.drawImage(cn, cx - half, cy - half);
}

function wrapText(text, maxW){
  const words = String(text).split(' ');
  const lines = []; let cur = '';
  for (const w of words){
    const t = cur ? cur + ' ' + w : w;
    if (ctx.measureText(t).width > maxW && cur){ lines.push(cur); cur = w; }
    else cur = t;
  }
  if (cur) lines.push(cur);
  return lines;
}
function dimScreen(a){ ctx.fillStyle = 'rgba(9,8,14,' + a + ')'; ctx.fillRect(0, 0, View.w, View.h); }

const RARITY_UI = {
  common:    { name:'COMMON',    edge:'#7E778C', fill:'#1C1926' },
  rare:      { name:'RARE',      edge:PAL.teal,  fill:'#12262A' },
  epic:      { name:'EPIC',      edge:PAL.relic, fill:'#211A31' },
  legendary: { name:'LEGENDARY', edge:PAL.brassLite, fill:'#2A2018' },
};
function cardRects(){
  const HS = hudScale();
  const cw = 286*HS, ch = 384*HS, gap = 26*HS;
  const total = cw*3 + gap*2;
  const scale = Math.min(1, (View.w - 60) / total);
  const cw2 = cw*scale, ch2 = ch*scale, gap2 = gap*scale;
  const t2 = cw2*3 + gap2*2;
  const x0 = (View.w - t2)/2, y0 = (View.h - ch2)/2 + 22*HS;
  const out = [];
  for (let i = 0; i < 3; i++) out.push({ x: x0 + i*(cw2+gap2), y: y0, w: cw2, h: ch2, s: scale });
  return out;
}
function updateDraftHover(){
  if (!S.draft) return;
  const rects = cardRects();
  S.draft.hover = -1;
  for (let i = 0; i < S.draft.cards.length; i++){
    const r = rects[i];
    if (Input.mouse.sx >= r.x && Input.mouse.sx <= r.x + r.w &&
        Input.mouse.sy >= r.y && Input.mouse.sy <= r.y + r.h){
      if (S.draft.lastHover !== i){ S.draft.lastHover = i; SFX.uiHover(); }
      S.draft.hover = i;
    }
  }
  if (S.draft.hover < 0) S.draft.lastHover = -1;
}

function drawDraft(){
  if (!S.draft) return;
  const HS = hudScale();
  dimScreen(0.74);
  const rects = cardRects();
  ctx.save();
  ctx.globalAlpha = clamp(S.draft.t / 0.35, 0, 1);
  setFont(Math.round(46*HS), 900, true);
  textOut('DRAFT AN UPGRADE', View.w/2, rects[0].y - 74*HS, PAL.bone, PAL.ink, 8);
  setFont(Math.round(15*HS), 700, true);
  textOut('PICK ONE  —  CLICK OR PRESS 1 / 2 / 3', View.w/2, rects[0].y - 42*HS, PAL.teal, PAL.ink, 4);
  ctx.restore();

  for (let i = 0; i < S.draft.cards.length; i++){
    const c = S.draft.cards[i], r = rects[i];
    const R = RARITY_UI[c.rarity] || RARITY_UI.common;
    const hov = S.draft.hover === i, chosen = S.draft.chosen === i;
    const rejected = S.draft.chosen >= 0 && !chosen;
    const s = r.s;
    ctx.save();
    const t = clamp((S.draft.t - i * 0.07) / 0.32, 0, 1);
    ctx.globalAlpha = (rejected ? clamp(S.draft.chooseT / 0.45, 0, 1) * 0.35 : 1) * easeOut(t);
    ctx.translate(r.x + r.w/2, r.y + r.h/2 + (1 - easeOut(t)) * 50);
    const sc = (hov && !rejected ? 1.045 : 1) * (chosen ? 1 + (1 - S.draft.chooseT/0.45) * 0.10 : 1);
    ctx.scale(sc, sc);
    ctx.translate(-r.w/2, -r.h/2);
    if (hov || chosen){
      ctx.save(); ctx.shadowColor = R.edge; ctx.shadowBlur = 36;
      rr(0, 0, r.w, r.h, 14*s); ctx.fillStyle = R.fill; ctx.fill(); ctx.restore();
    }
    rr(0, 0, r.w, r.h, 14*s);
    const g = ctx.createLinearGradient(0, 0, 0, r.h);
    g.addColorStop(0, R.fill); g.addColorStop(1, '#100E17');
    ctx.fillStyle = g; ctx.fill();
    ctx.strokeStyle = PAL.ink; ctx.lineWidth = 6*s; ctx.stroke();
    rr(5*s, 5*s, r.w - 10*s, r.h - 10*s, 10*s);
    ctx.strokeStyle = R.edge; ctx.lineWidth = 3*s; ctx.stroke();
    ctx.fillStyle = R.edge;
    for (const p of [[17*s,17*s],[r.w-17*s,17*s],[17*s,r.h-17*s],[r.w-17*s,r.h-17*s]]){
      ctx.beginPath(); ctx.arc(p[0], p[1], 3.2*s, 0, TAU); ctx.fill();
    }
    rr(r.w/2 - 58*s, -10*s, 116*s, 24*s, 6*s);
    ctx.fillStyle = R.edge; ctx.fill();
    ctx.strokeStyle = PAL.ink; ctx.lineWidth = 3*s; ctx.stroke();
    setFont(Math.round(12*s), 800, true);
    textOut(R.name, r.w/2, 2*s, PAL.ink);

    const iconY = 84*s;
    gaugeRing(r.w/2, iconY, 40*s, hexToRgba(PAL.brass, 0.55), 16);
    if (c.slot !== undefined && S.slots[c.slot]){
      const sk = S.slots[c.slot], E = ELEMENTS[sk.element];
      drawShapeGlyph(sk.shape, r.w/2, iconY, 25*s, E.color, E.glow);
      setFont(Math.round(11*s), 700, true);
      textOut('SLOT ' + (c.slot + 1), r.w/2, iconY + 56*s, E.color, PAL.ink, 3);
    } else {
      const ic = CARD_ICON[c.id] || 'gear';
      const tint = { flame:PAL.fire, frost:PAL.teal, bolt:PAL.tesla, steam:'#C9B6E8',
                     heart:'#E8542E', boot:'#9C93A8', dash:PAL.teal, crit:PAL.crit,
                     scrap:PAL.teal, boiler:PAL.brassLite, burst:PAL.fire }[ic] || R.edge;
      drawCardIcon(ic, r.w/2, iconY, 25*s, tint, '#FFFFFF');
    }
    setFont(Math.round(25*s), 900, true);
    const tl = wrapText(c.title, r.w - 40*s);
    tl.forEach((ln, j) => textOut(ln, r.w/2, 174*s + j*27*s, PAL.bone, PAL.ink, 5*s));
    ctx.strokeStyle = hexToRgba(PAL.brass, 0.5); ctx.lineWidth = 2*s;
    ctx.beginPath();
    ctx.moveTo(34*s, 174*s + tl.length*27*s + 6*s);
    ctx.lineTo(r.w - 34*s, 174*s + tl.length*27*s + 6*s); ctx.stroke();
    setFont(Math.round(15.5*s), 600, false);
    wrapText(c.text, r.w - 46*s).forEach((ln, j) =>
      textOut(ln, r.w/2, 174*s + tl.length*27*s + 32*s + j*22*s, '#B8B0C4'));
    rr(r.w/2 - 20*s, r.h - 44*s, 40*s, 30*s, 6*s);
    ctx.fillStyle = '#0B0910'; ctx.fill();
    ctx.strokeStyle = R.edge; ctx.lineWidth = 2.4*s; ctx.stroke();
    setFont(Math.round(17*s), 800, true);
    textOut((i + 1) + '', r.w/2, r.h - 29*s, R.edge);
    ctx.restore();
  }
}

function drawTitle(){
  const HS = hudScale();
  dimScreen(0.5);
  const t = S.titleT;
  ctx.save();
  ctx.translate(View.w/2, View.h * 0.245);
  ctx.translate(0, Math.sin(t * 1.3) * 4);
  ctx.save(); ctx.globalAlpha = 0.4;
  for (let i = 0; i < 3; i++){
    const rr2 = [96, 62, 44][i] * HS;
    ctx.save();
    ctx.translate([-250, 258, 300][i] * HS, [12, -22, 34][i] * HS);
    ctx.rotate(t * (i % 2 ? -0.35 : 0.28));
    ctx.strokeStyle = PAL.brass; ctx.lineWidth = 7*HS;
    circ(0, 0, rr2); ctx.stroke();
    circ(0, 0, rr2 * 0.42); ctx.stroke();
    for (let j = 0; j < 12; j++){
      const a = j / 12 * TAU;
      ctx.beginPath();
      ctx.moveTo(Math.cos(a)*rr2, Math.sin(a)*rr2);
      ctx.lineTo(Math.cos(a)*rr2*1.16, Math.sin(a)*rr2*1.16); ctx.stroke();
    }
    ctx.restore();
  }
  ctx.restore();
  setFont(Math.round(116*HS), 900, true);
  ctx.letterSpacing = '10px';
  ctx.save(); ctx.shadowColor = PAL.teal; ctx.shadowBlur = 26;
  textOut('SKYGEAR', 0, 0, PAL.brassLite, PAL.ink, 16);
  ctx.restore();
  ctx.letterSpacing = '0px';
  setFont(Math.round(18*HS), 700, true);
  textOut('S T O R M - D U S K   ·   1 0 , 0 0 0   F E E T', 0, 74*HS, PAL.moon, PAL.ink, 5);
  ctx.restore();

  const pw = Math.min(View.w - 60, 860*HS), ph = 224*HS;
  const px = (View.w - pw)/2, py = View.h * 0.44;
  brassPanel(px, py, pw, ph, 12*HS, 0.95);
  setFont(Math.round(17*HS), 800, true);
  textOut('HOW TO PLAY', px + pw/2, py + 24*HS, PAL.brass, PAL.ink, 3);
  const rows1 = [['W A S D','move the captain'],['MOUSE','aim — you always face the cursor'],
                 ['LEFT / RIGHT MOUSE','fire skill 1 and 2'],['SPACE / SHIFT','skill 3 and 4 (unlocked later)']];
  const rows2 = [['E','dash — invulnerable, use it constantly'],
                 ['ESC','pause  ·  M mute  ·  − / = volume  ·  F3 stats'],
                 ['DEFEND','the Boiler amidships. If it dies, you lose.'],
                 ['DRAFT','a card after every wave. 12 waves to win.']];
  const draw = (rows, x) => rows.forEach((r, i) => {
    const y = py + 62*HS + i * 38*HS;
    setFont(Math.round(14*HS), 800, true);
    textOut(r[0], x, y, PAL.teal, null, 0, 'left');
    setFont(Math.round(13.5*HS), 600, false);
    textOut(r[1], x, y + 17*HS, '#9C93A8', null, 0, 'left');
  });
  draw(rows1, px + 34*HS); draw(rows2, px + pw * 0.54);

  ctx.save();
  ctx.globalAlpha = 0.7 + Math.sin(t * 3.4) * 0.3;
  setFont(Math.round(34*HS), 900, true);
  textOut('CLICK  TO  BOARD', View.w/2, View.h * 0.86, PAL.crit, PAL.ink, 8);
  ctx.restore();
  setFont(Math.round(12.5*HS), 600, false);
  textOut('every skill is a SHAPE × an ELEMENT — 24 combinations, and the draft rewrites them',
          View.w/2, View.h * 0.93, '#6E667A');
}

function drawPause(){
  const HS = hudScale();
  dimScreen(0.7);
  setFont(Math.round(70*HS), 900, true);
  textOut('PAUSED', View.w/2, View.h * 0.34, PAL.bone, PAL.ink, 10);
  setFont(Math.round(17*HS), 700, true);
  textOut('ESC  RESUME        Q  QUIT TO TITLE', View.w/2, View.h * 0.34 + 56*HS, PAL.teal, PAL.ink, 5);
  const rows = [];
  for (let i = 0; i < 4; i++){
    const sk = S.slots[i];
    if (!sk) continue;
    const st = skillStats(sk);
    rows.push([(i+1) + '.  ' + skillName(sk).toUpperCase(),
               SHAPES[sk.shape].desc + '  ·  ' + ELEMENTS[sk.element].blurb + '  ·  ' + st.cd.toFixed(2) + 's cd',
               ELEMENTS[sk.element].color]);
  }
  const pw = Math.min(View.w - 60, 760*HS), ph = 44*HS + rows.length * 46*HS;
  const px = (View.w - pw)/2, py = View.h * 0.50;
  brassPanel(px, py, pw, ph, 12*HS, 0.95);
  setFont(Math.round(14*HS), 800, true);
  textOut('LOADOUT', px + pw/2, py + 20*HS, PAL.brass);
  rows.forEach((r, i) => {
    const y = py + 52*HS + i * 46*HS;
    setFont(Math.round(16*HS), 800, true);
    textOut(r[0], px + 28*HS, y, r[2], PAL.ink, 3, 'left');
    setFont(Math.round(13*HS), 600, false);
    textOut(r[1], px + 28*HS, y + 19*HS, '#9C93A8', null, 0, 'left');
  });
}

function drawEndScreen(){
  const HS = hudScale();
  const win = S.mode === 'victory';
  const k = clamp(S.endT / 0.8, 0, 1);
  dimScreen(0.55 + 0.26 * k);
  ctx.save();
  ctx.globalAlpha = k;
  ctx.translate(View.w/2, View.h * 0.22);
  ctx.scale(lerp(1.7, 1, easeOut(k)), lerp(1.7, 1, easeOut(k)));
  setFont(Math.round(84*HS), 900, true);
  ctx.shadowColor = win ? PAL.crit : PAL.danger; ctx.shadowBlur = 30;
  textOut(S.endTitle || (win ? 'DECK HELD' : 'BOARDED'), 0, 0,
          win ? PAL.crit : PAL.danger, PAL.ink, 12);
  ctx.restore();
  setFont(Math.round(19*HS), 700, true);
  textOut(S.endReason || '', View.w/2, View.h * 0.22 + 62*HS, PAL.bone, PAL.ink, 5);
  const stats = [
    ['WAVES SURVIVED', (win ? TUNING.totalWaves : Math.max(0, S.wave - 1)) + ' / ' + TUNING.totalWaves],
    ['BOARDERS DESTROYED', S.stats.kills + ''],
    ['DAMAGE DEALT', Math.round(S.stats.damage).toLocaleString()],
    ['BEST CHAIN', S.stats.bestCombo + ''],
    ['DASHES', S.stats.dashes + ''],
    ['UPGRADES DRAFTED', S.stats.cards.length + ''],
  ];
  const pw = Math.min(View.w - 60, 640*HS), ph = 60*HS + stats.length * 34*HS;
  const px = (View.w - pw)/2, py = View.h * 0.38;
  ctx.save();
  ctx.globalAlpha = clamp((S.endT - 0.3) / 0.5, 0, 1);
  brassPanel(px, py, pw, ph, 12*HS, 0.96);
  setFont(Math.round(15*HS), 800, true);
  textOut('AFTER ACTION', px + pw/2, py + 26*HS, PAL.brass);
  stats.forEach((s, i) => {
    const y = py + 60*HS + i * 34*HS;
    setFont(Math.round(14.5*HS), 700, true);
    textOut(s[0], px + 34*HS, y, '#9C93A8', null, 0, 'left');
    setFont(Math.round(19*HS), 900, true);
    textOut(s[1], px + pw - 34*HS, y, PAL.bone, PAL.ink, 3, 'right');
  });
  const ly = py + ph + 26*HS;
  let n = 0;
  for (let i = 0; i < 4; i++) if (S.slots[i]) n++;
  const gw = 58*HS, gx = View.w/2 - (n * gw)/2;
  let gi = 0;
  for (let i = 0; i < 4; i++){
    const sk = S.slots[i];
    if (!sk) continue;
    const E = ELEMENTS[sk.element];
    const cx = gx + gi * gw + gw/2;
    circ(cx, ly, 24*HS);
    ctx.fillStyle = PAL.base; ctx.fill();
    ctx.strokeStyle = E.color; ctx.lineWidth = 2.4; ctx.stroke();
    drawShapeGlyph(sk.shape, cx, ly, 15*HS, E.color, E.glow);
    gi++;
  }
  ctx.restore();
  if (S.endT > 0.8){
    ctx.save();
    ctx.globalAlpha = 0.65 + Math.sin(S.rt * 3.6) * 0.35;
    setFont(Math.round(26*HS), 900, true);
    textOut('CLICK  OR  PRESS  R  TO  SAIL  AGAIN', View.w/2, View.h * 0.92, PAL.crit, PAL.ink, 7);
    ctx.restore();
  }
}

function drawCursor(){
  const x = Input.mouse.sx, y = Input.mouse.sy;
  ctx.save();
  ctx.translate(x, y);
  ctx.globalCompositeOperation = 'lighter';
  drawGlow(0, 0, 20, PAL.teal, 0.35);
  ctx.globalCompositeOperation = 'source-over';
  ctx.rotate(S.rt * 0.7);
  ctx.strokeStyle = PAL.ink; ctx.lineWidth = 4.5;
  circ(0, 0, 12); ctx.stroke();
  ctx.strokeStyle = PAL.teal; ctx.lineWidth = 2.2;
  circ(0, 0, 12); ctx.stroke();
  for (let i = 0; i < 4; i++){
    const a = i / 4 * TAU;
    ctx.beginPath();
    ctx.moveTo(Math.cos(a)*5, Math.sin(a)*5);
    ctx.lineTo(Math.cos(a)*9, Math.sin(a)*9); ctx.stroke();
  }
  ctx.rotate(-S.rt * 0.7);
  ctx.fillStyle = PAL.teal; circ(0, 0, 2.4); ctx.fill();
  ctx.restore();
}

/* ---------------------------------------------------------------------------
   RENDER — top level composition
--------------------------------------------------------------------------- */
function drawScreenFx(){
  const w = View.w, h = View.h;
  if (!_vigCv) buildSky();
  const hpFrac = S.player ? S.player.hp / S.player.maxHp : 1;
  if (S.mode !== 'title' && hpFrac < 0.3 && S.player.hp > 0){
    const pulse = 0.35 + Math.sin(S.rt * 5.5) * 0.22;
    ctx.save();
    ctx.globalAlpha = clamp(pulse * (1 - hpFrac/0.3) * 0.9, 0, 1);
    ctx.drawImage(_redCv, 0, 0, w, h);
    ctx.restore();
  }
  ctx.drawImage(_vigCv, 0, 0, w, h);
  if (S.flashRed > 0){
    ctx.fillStyle = 'rgba(255,61,46,' + (S.flashRed * 0.3).toFixed(3) + ')';
    ctx.fillRect(0, 0, w, h);
  }
  if (S.flashWhite > 0){
    ctx.fillStyle = 'rgba(255,236,200,' + (S.flashWhite * 0.7).toFixed(3) + ')';
    ctx.fillRect(0, 0, w, h);
  }
}

function render(){
  ctx.setTransform(View.dpr, 0, 0, View.dpr, 0, 0);
  resetOccluders();
  ctx.save();
  // trauma shake is applied to the whole projected frame
  ctx.translate(S.shakeX, S.shakeY);
  ctx.translate(View.w/2, View.h/2); ctx.rotate(S.shakeR); ctx.translate(-View.w/2, -View.h/2);

  drawEnvironment();
  drawBowPiece();
  if (CAM.follow) drawDeckLive();
  else { if (!_deckCv) buildDeck(); ctx.drawImage(_deckCv, 0, 0, View.w, View.h); }

  // --- flat on the deck
  drawFields();
  drawTelegraphs();
  drawAoePreview();
  drawGroundFx();

  // --- billboards, far to near
  const list = [];
  for (const p of PROPS)     list.push({ y: p.y, k: 0, o: p });
  for (const e of S.enemies) list.push({ y: e.y, k: 1, o: e });
  list.push({ y: S.boiler.y, k: 2 });
  for (const p of S.pickups) list.push({ y: p.y, k: 4, o: p });
  if (S.player.hp > 0)       list.push({ y: S.player.y, k: 3 });
  list.sort((a, b) => a.y - b.y);
  for (const it of list){
    if (it.k === 0) drawPropBillboard(it.o);
    else if (it.k === 1) drawEnemyBillboard(it.o);
    else if (it.k === 2) drawBoilerBillboard();
    else if (it.k === 3) drawPlayerBillboard();
    else drawPickupBillboard(it.o);
  }

  drawXrayPass();

  // --- above the deck
  drawBolts();
  drawAirFx();
  drawRay();
  drawParticles();
  drawNums();
  drawEnvelope();
  ctx.restore();
  if (S.mode === 'play' || S.mode === 'pause') drawObjectiveMarker();

  drawScreenFx();
  const ended = S.mode === 'gameover' || S.mode === 'victory';
  if (S.mode !== 'title' && !ended) drawHUD();
  if (S.mode === 'draft') drawDraft();
  if (S.mode === 'pause') drawPause();
  if (S.mode === 'title') drawTitle();
  if (ended) drawEndScreen();
  if (S.showFps) drawFps();
  drawCursor();
}

/* ---------------------------------------------------------------------------
   BOOT
--------------------------------------------------------------------------- */
resize();
resetGame();
onViewportChanged();
S.mode = 'title';
S.phase = 'idle';
requestAnimationFrame(frame);

window.SKYGEAR = { S, TUNING, SHAPES, ELEMENTS, ENEMIES, WAVES, CARDS, CAM, Assets, FEEL, DT,
                   startRun, startWave, spawnEnemy, openDraft, newSkill, castSlot,
                   skillStats, step, rollCards, updateRay, endRay, render, Particles,
                   jump(w){ startRun(); S.wave = w - 1; S.interT = 0.05; } };
