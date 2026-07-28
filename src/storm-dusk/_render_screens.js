/* ---------------------------------------------------------------------------
   SCREENS — draft, title, pause, endings
--------------------------------------------------------------------------- */
const CARD_ICON = {
  burnDmg:'flame', burnDur:'flame', slowAmt:'frost', brittle:'frost', stun:'bolt',
  knock:'steam', scald:'steam', hp:'heart', spd:'boot', dashcd:'dash', dashdmg:'dash',
  dashchg:'dash', crit:'crit', critx:'crit', scrap:'scrap', lifesteal:'scrap',
  boilerhp:'boiler', boilerdr:'boiler', fifth:'gear', residue:'burst', autofire:'burst',
  killboom:'burst',
  // v11
  ventheal:'heart', ventdmg:'steam', pressrate:'steam', dressing:'heart', kegs:'burst',
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
  // Taller than v9's 384: the cards now carry a before -> after block above
  // the badge, and at the width three of them fit into on a 1366 laptop the
  // description was running into it. Scaled down to fit the viewport in both
  // axes, so a short window shrinks them rather than clipping them.
  const cw = 286*HS, ch = 432*HS, gap = 26*HS;
  const total = cw*3 + gap*2;
  const scale = Math.min(1, (View.w - 60) / total, (View.h - 210*HS) / ch);
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


/* WHAT KIND OF CARD IS THIS, AND WHAT DOES IT TOUCH (v12).

   Reported after the second playthrough: it is not visually clear whether an
   upgrade enhances a skill you already have or hands you a new one. Both looked
   like a card with a title on it, and the only difference was reading the prose.

   So every card now declares itself twice — a coloured band across the top that
   names the class of thing it is, and a row of small shape glyphs at the bottom
   showing exactly which of your four slots it lands on, with the untouched ones
   drawn dim. An element card lights every skill of that colour; a captain card
   lights none of them and shows her portrait pip instead.

   The scope comes from CARD_SCOPE in the core — declared data, not inferred
   here, because a renderer inferring it is how it goes wrong the first time
   somebody adds a card. */
const CARD_ELEMENT = { burnDmg:'EMBER', burnDur:'EMBER', slowAmt:'FROST',
                       brittle:'FROST', stun:'ARC', knock:'STEAM', scald:'STEAM' };
const CARD_CLASS = {
  new:     { label:'NEW SKILL',     col:'#FFD52E' },
  skill:   { label:'SKILL UPGRADE', col:PAL.teal },
  element: { label:'ELEMENT',       col:'#C9B6E8' },
  captain: { label:'CAPTAIN',       col:'#E8542E' },
  ship:    { label:'THE BOILER',    col:PAL.brassLite },
  deck:    { label:'THE DECK',      col:'#FF9A4A' },
  all:     { label:'EVERY SKILL',   col:'#9BE8D2' },
  meta:    { label:'THE DRAFT',     col:'#8FA6C9' },
};
function cardScope(c){
  if (c.skill) return 'new';
  if (CARD_SCOPE[c.id]) return CARD_SCOPE[c.id];
  return (c.slot !== undefined) ? 'skill' : 'captain';
}
/* Which of the four slots this card lands on. Empty means it does not touch a
   skill at all, which is itself the useful thing to show. */
function cardAffects(c){
  const scope = cardScope(c);
  if (scope === 'new' || scope === 'skill')
    return (c.slot === undefined) ? [] : [c.slot];
  if (scope === 'element'){
    const e = c.element || CARD_ELEMENT[c.id];
    const out = [];
    for (let i = 0; i < 4; i++) if (S.slots[i] && (!e || S.slots[i].element === e)) out.push(i);
    return out;
  }
  if (scope === 'all'){
    const out = [];
    for (let i = 0; i < 4; i++) if (S.slots[i]) out.push(i);
    return out;
  }
  return [];
}

/* The row of slot glyphs. Four positions, always in slot order, so the row
   reads as "your loadout" and the lit ones read as "these". */
function drawAffectedRow(cx, cy, s, c){
  const scope = cardScope(c);
  const hit = cardAffects(c);
  const cls = CARD_CLASS[scope] || CARD_CLASS.captain;
  const slots = [];
  for (let i = 0; i < 4; i++) if (S.slots[i] || hit.indexOf(i) >= 0) slots.push(i);
  // A card that touches no skill draws no loadout row. Drawing four dim glyphs
  // with none lit reads as "affects nothing"; the point is that it affects
  // something else, so say which.
  if (!hit.length || !slots.length){
    // nothing in the loadout is touched — say what IS, with one pip
    setFont(Math.round(10*s), 800, true);
    textOut(scope === 'ship' ? 'AFFECTS THE BOILER'
          : scope === 'deck' ? 'AFFECTS THE DECK'
          : scope === 'meta' ? 'AFFECTS FUTURE DRAFTS'
          : 'AFFECTS THE CAPTAIN', cx, cy + 4*s, cls.col, PAL.ink, 3*s);
    return;
  }
  const step = 30*s, x0 = cx - (slots.length - 1) * step / 2;
  for (let k = 0; k < slots.length; k++){
    const i = slots[k], sk = S.slots[i];
    const on = hit.indexOf(i) >= 0;
    const x = x0 + k * step;
    ctx.save();
    ctx.globalAlpha = on ? 1 : 0.26;
    if (on){
      ctx.beginPath(); ctx.arc(x, cy, 13*s, 0, TAU);
      ctx.fillStyle = hexToRgba(cls.col, 0.16); ctx.fill();
      ctx.strokeStyle = cls.col; ctx.lineWidth = 1.6*s; ctx.stroke();
    }
    if (sk){
      const E = ELEMENTS[sk.element];
      drawShapeGlyph(sk.shape, x, cy, 8.5*s, on ? E.color : '#6E667A', E.glow);
    } else {
      // the empty slot this card would fill
      ctx.beginPath(); ctx.arc(x, cy, 6*s, 0, TAU);
      ctx.strokeStyle = cls.col; ctx.lineWidth = 1.6*s; ctx.setLineDash([3*s, 3*s]);
      ctx.stroke(); ctx.setLineDash([]);
    }
    ctx.restore();
  }
}

function drawDraft(){
  if (!S.draft) return;
  const HS = hudScale();
  dimScreen(0.74);
  const rects = cardRects();
  ctx.save();
  ctx.globalAlpha = clamp(S.draft.t / 0.35, 0, 1);
  setFont(Math.round(46*HS), 900, true);
  const opening = S.draft.kind === 'opening';
  const isSkill = opening || S.draft.kind === 'skill';
  textOut(opening ? 'CHOOSE YOUR OPENING WEAPON'
                  : isSkill ? 'ARM A NEW SLOT' : 'DRAFT AN UPGRADE',
          View.w/2, rects[0].y - 74*HS, PAL.bone, PAL.ink, 8);
  setFont(Math.round(15*HS), 700, true);
  // The opening draft is the one place the game gets to state its premise while
  // the player is looking directly at three examples of it.
  const sub = opening
    ? 'EVERY SKILL IS A SHAPE × AN ELEMENT  —  CLICK OR PRESS 1 / 2 / 3'
    : isSkill
      ? (SLOT_KEYS[S.draft.slot] || ('SLOT ' + (S.draft.slot + 1))) +
        '  —  WHICH WEAPON, NOT WHETHER'
      : 'PICK ONE  —  CLICK OR PRESS 1 / 2 / 3';
  textOut(sub, View.w/2, rects[0].y - 42*HS, PAL.teal, PAL.ink, 4);
  ctx.restore();

  for (let i = 0; i < S.draft.cards.length; i++){
    const c = S.draft.cards[i], r = rects[i];
    // A weapon card is edged in its element's colour rather than its rarity's.
    // Rarity is the wrong axis for a card whose entire point is which element
    // it is, and three identically grey cards is what made the opening choice
    // read as "pick one" instead of "pick a colour".
    const R = c.skill
      ? { name: ELEMENTS[c.skill.element].name.toUpperCase(),
          edge: ELEMENTS[c.skill.element].color,
          fill: hexToRgba(ELEMENTS[c.skill.element].color, 0.10) }
      : (RARITY_UI[c.rarity] || RARITY_UI.common);
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
    if (c.skill){
      // The element's motif rides its own ribbon. Four coloured labels are four
      // colours; four silhouettes are learnable and survive greyscale.
      const lw = ctx.measureText(R.name).width;
      textOut(R.name, r.w/2 + 8*s, 2*s, PAL.ink);
      elementMotif(c.skill.element, r.w/2 - lw/2 - 3*s, 2*s, 6*s, PAL.ink, true);
    } else {
      textOut(R.name, r.w/2, 2*s, PAL.ink);
    }

    // the class band: what KIND of thing this card is, before any reading
    {
      const cls = CARD_CLASS[cardScope(c)] || CARD_CLASS.captain;
      const bw = r.w - 44*s;
      rr(r.w/2 - bw/2, 24*s, bw, 20*s, 5*s);
      ctx.fillStyle = hexToRgba(cls.col, 0.14); ctx.fill();
      ctx.strokeStyle = hexToRgba(cls.col, 0.75); ctx.lineWidth = 1.6*s; ctx.stroke();
      setFont(Math.round(11*s), 800, true);
      textOut(cls.label, r.w/2, 38*s, cls.col, PAL.ink, 3*s);
    }

    const iconY = 92*s;
    gaugeRing(r.w/2, iconY, 40*s, hexToRgba(PAL.brass, 0.55), 16);
    // A skill card draws its OWN shape and element. It used to look up whatever
    // was already in the target slot — which is null for every skill draft,
    // since a skill draft only ever fires for an EMPTY slot — so every weapon
    // card in the game fell through to the generic gear icon. The one screen
    // whose whole job is to show that a skill is a shape crossed with an
    // element was showing neither.
    if (c.skill){
      const E = ELEMENTS[c.skill.element];
      drawShapeGlyph(c.skill.shape, r.w/2, iconY, 25*s, E.color, E.glow);
      setFont(Math.round(10.5*s), 800, true);
      textOut(SHAPES[c.skill.shape].passive ? 'AUTO — NO BUTTON'
                                            : (SLOT_KEYS[c.slot] || ('SLOT ' + (c.slot + 1))),
              r.w/2, iconY + 56*s, E.color, PAL.ink, 3);
    } else if (c.slot !== undefined && S.slots[c.slot]){
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
    let ty = 174*s + tl.length*27*s + 32*s;
    wrapText(c.text, r.w - 46*s).forEach((ln, j) =>
      textOut(ln, r.w/2, ty + j*22*s, '#B8B0C4'));
    ty += wrapText(c.text, r.w - 46*s).length * 22*s + 10*s;

    // Before → after, anchored to the bottom of the card rather than flowing
    // after the prose. Flowing put a three-row preview under a three-line
    // description straight through the card's number badge — and how many rows
    // a card has is not something the layout should have to know.
    // The prose says what the card does; these say what it is worth. Without
    // them "+2 pierce" and "burn +50%" are two sentences with no way to compare
    // them, which is how a draft becomes a coin toss.
    if (c.preview && c.preview.length){
      ty = r.h - 104*s - (c.preview.length - 1) * 18*s;
      for (const p of c.preview){
        setFont(Math.round(11*s), 700, false);
        textOut(p.label, 24*s, ty, '#7E778C', null, 0, 'left');
        setFont(Math.round(12.5*s), 800, true);
        const tw = ctx.measureText(p.to).width;
        textOut(p.to, r.w - 24*s, ty, p.better ? PAL.teal : PAL.dangerIn, PAL.ink, 3*s, 'right');
        setFont(Math.round(11.5*s), 700, false);
        const aw = ctx.measureText(' → ').width;
        textOut('→', r.w - 26*s - tw - aw/2, ty, '#5A5366');
        textOut(p.from, r.w - 26*s - tw - aw, ty, '#6E667A', null, 0, 'right');
        ty += 18*s;
      }
    }

    // Whether it is something you press. A passive in a slot is the single
    // thing new players misread, and the card is where to say so.
    if (!c.skill) drawAffectedRow(r.w/2, r.h - 68*s, s, c);
    if (c.skill){
      const passive = SHAPES[c.skill.shape].passive;
      setFont(Math.round(10.5*s), 800, true);
      const tag = passive ? 'AUTO' : 'ACTIVE';
      const tw = ctx.measureText(tag).width + 16*s;
      rr(r.w/2 - tw/2, r.h - 78*s, tw, 18*s, 4*s);
      ctx.fillStyle = passive ? hexToRgba(PAL.relic, 0.22) : hexToRgba(PAL.teal, 0.16);
      ctx.fill();
      ctx.strokeStyle = passive ? PAL.relic : PAL.teal; ctx.lineWidth = 1.4*s; ctx.stroke();
      textOut(tag, r.w/2, r.h - 69*s, passive ? PAL.relic : PAL.teal);
    }

    rr(r.w/2 - 20*s, r.h - 44*s, 40*s, 30*s, 6*s);
    ctx.fillStyle = '#0B0910'; ctx.fill();
    ctx.strokeStyle = R.edge; ctx.lineWidth = 2.4*s; ctx.stroke();
    setFont(Math.round(17*s), 800, true);
    textOut((i + 1) + '', r.w/2, r.h - 29*s, R.edge);
    ctx.restore();
  }

  /* Reroll. Run-wide and scarce, so the interesting question is which hand is
     bad enough to spend one on. Drawn under the cards rather than on them: it
     is not a fourth option, it is a thing you do to the three. */
  if (S.draft.chosen < 0){
    const r0 = rects[0], last = rects[rects.length - 1];
    const bw = 240*HS, bh = 46*HS;
    const bx = (r0.x + last.x + last.w) / 2 - bw / 2;
    const by = r0.y + r0.h + 20*HS;
    const none = S.rerolls <= 0;
    if (uiButton(bx, by, bw, bh,
                 none ? 'NO REROLLS LEFT' : ('REROLL  ×' + S.rerolls),
                 null, { disabled: none, hint: none ? null : 'R' }) && !none){
      rerollDraft();
    }
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

  // The promise, in one line, above the fold. A title screen that opens with a
  // four-column control reference is telling a stranger how before it has told
  // them what — and the controls are two of them anyway, since the captain
  // attacks by herself.
  setFont(Math.round(17*HS), 600, false);
  textOut('Twelve waves board your airship. Keep the Boiler alive.',
          View.w/2, View.h * 0.40, '#C6BFD2');
  setFont(Math.round(14*HS), 700, false);
  // Counted, not written down. This read "24 combinations" for three versions
  // after passives took the roster to eight draftable shapes.
  textOut('Every skill is a SHAPE × an ELEMENT — ' + comboCount() +
          ' combinations, and the draft after each wave rewrites them.',
          View.w/2, View.h * 0.40 + 26*HS, '#7E778C');

  const bw = 300*HS, bh = 62*HS, gap = 12*HS;
  let by = View.h * 0.53;
  if (uiButton(View.w/2 - bw/2, by, bw, bh, 'START RUN', 'primary')) startRun();
  by += bh + gap;
  const half = (bw - gap) / 2;
  if (uiButton(View.w/2 - bw/2, by, half, 46*HS, 'HOW TO PLAY')) openHowTo();
  if (uiButton(View.w/2 + gap/2, by, half, 46*HS, 'SETTINGS')) openSettings('title');
  by += 46*HS + gap;

  const best = RunLog.best();
  if (best){
    setFont(Math.round(12.5*HS), 700, false);
    textOut('your best: wave ' + best.wave + ' of ' + best.waves + ' · ' +
            best.kills + ' boarders · ' + fmtDuration(best.time),
            View.w/2, by + 16*HS, '#6E667A');
  }
  if (FORCED_SEED !== null){
    setFont(Math.round(12*HS), 800, true);
    textOut('FIXED SEED ' + seedText(FORCED_SEED), View.w/2, by + 38*HS, PAL.teal, PAL.ink, 3);
  }

  // Build stamp. The site is served with a ten-minute cache, so "is this the
  // change I just shipped?" needs an answer that does not depend on trusting
  // the browser. Also reports how much painted art actually resolved.
  setFont(Math.round(11*HS), 700, false);
  const art = Assets.enabled ? (Assets.ready + '/' + Assets.total + ' art')
                             : 'procedural';
  textOut(PRESET.name + ' · ' + (PRESET.build || 'dev') + ' · ' + art,
          View.w - 14*HS, View.h - 12*HS, '#5A5366', null, 0, 'right');
}

/* Derived, never written down. The title said "24 combinations" for three
   versions after passives took the roster to nine shapes, because it was a
   string. Cleave is the fixed basic and is excluded from drafts, so it is the
   draftable shapes that count. */
function comboCount(){
  return (SHAPE_KEYS.length - (FEEL.basic ? 1 : 0)) * ELEMENT_KEYS.length;
}

/* ---------------------------------------------------------------------------
   OVERLAYS — settings, how to play, key binding
   These are not modes. Making them modes would mean every piece of code that
   asks "are we playing?" has to learn two more answers, and the pause menu and
   the title screen would each need their own copy of the settings panel.
   They are a layer on top of whatever is already there, and they remember
   where they were opened from so Back goes somewhere sensible.
--------------------------------------------------------------------------- */
function openSettings(from){ S.overlay = { kind:'settings', from, t:0 }; SFX.uiClick(); }
function openHowTo(from){ S.overlay = { kind:'howto', from: from || 'title', t:0 }; SFX.uiClick(); }
function openBinds(){ S.overlay = { kind:'binds', from:'settings', t:0, listen:null }; SFX.uiClick(); }
function closeOverlay(){
  const o = S.overlay;
  if (!o) return;
  // Back from the rebinder returns to settings, not to the game underneath it.
  if (o.from === 'settings') S.overlay = { kind:'settings', from:'pause-or-title', t:0 };
  else S.overlay = null;
  SFX.uiClick();
}

function drawPause(){
  const HS = hudScale();
  dimScreen(0.72);
  UI.begin('pause');
  setFont(Math.round(58*HS), 900, true);
  textOut('PAUSED', View.w/2, View.h * 0.17, PAL.bone, PAL.ink, 10);

  const bw = 280*HS, bh = 52*HS, gap = 10*HS;
  let by = View.h * 0.25;
  if (uiButton(View.w/2 - bw/2, by, bw, bh, 'RESUME', 'primary', { hint: 'ESC' })) S.mode = 'play';
  by += bh + gap;
  const half = (bw - gap) / 2;
  if (uiButton(View.w/2 - bw/2, by, half, 42*HS, 'SETTINGS')) openSettings('pause');
  if (uiButton(View.w/2 + gap/2, by, half, 42*HS, 'HOW TO PLAY')) openHowTo('pause');
  by += 42*HS + gap;
  if (uiButton(View.w/2 - bw/2, by, half, 42*HS, 'RESTART RUN')) startRun();
  if (uiButton(View.w/2 + gap/2, by, half, 42*HS, 'QUIT TO TITLE')){ S.mode = 'title'; S.overlay = null; }
  by += 42*HS + 26*HS;

  // The loadout, with its real numbers. This is the only place in the game a
  // player can read what their build actually does without being shot at.
  const rows = [];
  if (S.basic) rows.push([S.basic, 'AUTO']);
  for (let i = 0; i < 4; i++) if (S.slots[i]) rows.push([S.slots[i], SLOT_KEYS[i]]);
  if (rows.length){
    const pw = Math.min(View.w - 60, 720*HS), ph = 40*HS + rows.length * 44*HS;
    const px = (View.w - pw)/2;
    brassPanel(px, by, pw, ph, 12*HS, 0.95);
    setFont(Math.round(13*HS), 800, true);
    textOut('LOADOUT', px + pw/2, by + 19*HS, PAL.brass);
    rows.forEach((row, i) => {
      const sk = row[0], E = ELEMENTS[sk.element], st = skillStats(sk);
      const y = by + 48*HS + i * 44*HS;
      drawShapeGlyph(sk.shape, px + 30*HS, y + 6*HS, 13*HS, E.color, E.glow);
      setFont(Math.round(15*HS), 800, true);
      textOut(skillName(sk).toUpperCase(), px + 52*HS, y, E.color, PAL.ink, 3, 'left');
      setFont(Math.round(12.5*HS), 600, false);
      textOut(SHAPES[sk.shape].desc + '  ·  ' + ELEMENTS[sk.element].blurb,
              px + 52*HS, y + 18*HS, '#9C93A8', null, 0, 'left');
      setFont(Math.round(12*HS), 800, true);
      textOut(row[1], px + pw - 26*HS, y, PAL.bone, null, 0, 'right');
      setFont(Math.round(11.5*HS), 700, false);
      textOut(SHAPES[sk.shape].passive ? 'no button' : st.cd.toFixed(2) + 's cooldown',
              px + pw - 26*HS, y + 18*HS, '#7E778C', null, 0, 'right');
    });
  }
  UI.end();
}

/* One scrollless panel that fits on a 1366x768 laptop, because that is the
   machine the acceptance criteria name. Nothing here is behind a submenu
   except rebinding, which needs a whole screen to itself. */
function drawSettings(){
  const HS = hudScale();
  dimScreen(0.82);
  UI.begin('settings');
  setFont(Math.round(40*HS), 900, true);
  textOut('SETTINGS', View.w/2, View.h * 0.10, PAL.bone, PAL.ink, 8);

  const pw = Math.min(View.w - 48, 700*HS);
  const px = (View.w - pw)/2;
  let y = View.h * 0.10 + 40*HS;
  const iw = pw - 56*HS, ix = px + 28*HS;
  // Height from content, not from a fraction of the viewport: a panel sized to
  // the window has to be sized for the tallest window, and on every other one
  // it is mostly empty. 5 sound rows, 3 display rows, 2 button rows, three
  // headings and the padding around them.
  const ph = 38*HS + (28*HS + 5*34*HS + 10*HS)
                   + (28*HS + 3*34*HS + 10*HS)
                   + (28*HS + 34*HS + 8*HS + 34*HS);
  brassPanel(px, y, pw, ph, 12*HS, 0.96);
  y += 18*HS;

  y += uiHeading(ix, y, iw, 'SOUND');
  y += uiSlider(ix, y, iw, 'Master volume', Settings.get('volMaster'),
                v => { Settings.set('volMaster', v); Sound.vol = v; });
  y += uiSlider(ix, y, iw, 'Music', Settings.get('volMusic'), v => Settings.set('volMusic', v));
  y += uiSlider(ix, y, iw, 'Effects', Settings.get('volSfx'), v => Settings.set('volSfx', v));
  y += uiSlider(ix, y, iw, 'Interface', Settings.get('volUi'), v => Settings.set('volUi', v));
  y += uiToggle(ix, y, iw, 'Mute everything', Settings.get('muted'),
                v => { Settings.set('muted', v); Sound.muted = v; });
  y += 10*HS;

  y += uiHeading(ix, y, iw, 'DISPLAY');
  y += uiChoice(ix, y, iw, 'Effects', [
    { value: 1,    label: 'FULL' },
    { value: 0.5,  label: 'FEWER' },
    { value: 0.25, label: 'FEWEST' },
  ], Settings.get('vfx'), v => Settings.set('vfx', v));
  // Three states, not two: "follow the system" is the honest default and a
  // player who has never opened this menu is already in it.
  y += uiChoice(ix, y, iw, 'Reduced motion', [
    { value: null,  label: Settings.motionReduced() ? 'SYSTEM (ON)' : 'SYSTEM (OFF)' },
    { value: true,  label: 'ON' },
    { value: false, label: 'OFF' },
  ], Settings.get('reducedMotion'), v => Settings.set('reducedMotion', v));
  y += uiChoice(ix, y, iw, 'Interface size', [
    { value: 0.85, label: 'SMALL' },
    { value: 1,    label: 'NORMAL' },
    { value: 1.2,  label: 'LARGE' },
    { value: 1.45, label: 'LARGEST' },
  ], Settings.get('hudScale'), v => Settings.set('hudScale', v));
  y += 10*HS;

  y += uiHeading(ix, y, iw, 'CONTROLS AND PROMPTS');
  const bh = 34*HS;
  if (uiButton(ix, y, iw * 0.48, bh, 'REBIND KEYS')) openBinds();
  if (uiButton(ix + iw * 0.52, y, iw * 0.48, bh,
               Settings.get('hints') ? 'PROMPTS: ON' : 'PROMPTS: OFF'))
    Settings.set('hints', !Settings.get('hints'));
  y += bh + 8*HS;
  if (uiButton(ix, y, iw * 0.48, bh, 'SHOW PROMPTS AGAIN')){ Settings.forgetHints(); Hints.reset(); }
  if (uiButton(ix + iw * 0.52, y, iw * 0.48, bh, 'RESET EVERYTHING')){ Settings.reset(); Hints.reset(); }

  const byy = View.h * 0.10 + 40*HS + ph + 18*HS;
  if (uiButton(View.w/2 - 130*HS, byy, 260*HS, 46*HS, 'BACK', 'primary', { hint: 'ESC' }))
    closeOverlay();
  UI.end();
}

function drawHowTo(){
  const HS = hudScale();
  dimScreen(0.86);
  UI.begin('howto');
  setFont(Math.round(40*HS), 900, true);
  textOut('HOW TO PLAY', View.w/2, View.h * 0.10, PAL.bone, PAL.ink, 8);

  const pw = Math.min(View.w - 48, 860*HS);
  const px = (View.w - pw)/2;
  let y = View.h * 0.10 + 36*HS;
  const ph = View.h * 0.66;
  brassPanel(px, y, pw, ph, 12*HS, 0.96);
  const ix = px + 30*HS, iw = pw - 60*HS;
  y += 20*HS;

  y += uiHeading(ix, y, iw, 'THE JOB');
  setFont(Math.round(14.5*HS), 600, false);
  const intro = [
    'Twelve waves of boarders climb your rails. They are heading for the Boiler at ' +
    'the stern. If the Boiler dies, the ship falls and the run is over.',
    'Your captain swings her ' + (FEEL.basic ? ELEMENTS[FEEL.basic[1]].name + ' ' +
      SHAPES[FEEL.basic[0]].noun : 'weapon') + ' by herself at whatever is nearest — ' +
    'you never click to attack. Your job is where to stand and when to spend an ability.',
  ];
  intro.forEach(p => {
    wrapText(p, iw).forEach(ln => { textOut(ln, ix, y + 8*HS, '#C6BFD2', null, 0, 'left'); y += 19*HS; });
    y += 7*HS;
  });
  y += 6*HS;

  y += uiHeading(ix, y, iw, 'CONTROLS');
  const rows = [
    ['W A S D', 'move'],
    ['MOUSE', 'aim — abilities go where the cursor is'],
    [bindLabel('dash'), 'dash. Invulnerable while it lasts. Use it constantly.'],
    [SLOT_KEYS[0] + '  ·  ' + SLOT_KEYS[1], 'abilities 1 and 2'],
    [SLOT_KEYS[2] + '  ·  ' + SLOT_KEYS[3], 'abilities 3 and 4, once those slots open'],
    ['1 2 3', 'pick a card in the draft'],
    ['ESC', 'pause, settings, and this screen again'],
  ];
  rows.forEach((r) => {
    setFont(Math.round(13.5*HS), 800, true);
    textOut(r[0], ix, y + 9*HS, PAL.teal, null, 0, 'left');
    setFont(Math.round(13.5*HS), 600, false);
    textOut(r[1], ix + 150*HS, y + 9*HS, '#9C93A8', null, 0, 'left');
    y += 24*HS;
  });
  y += 8*HS;

  y += uiHeading(ix, y, iw, 'SHAPE × ELEMENT');
  setFont(Math.round(14.5*HS), 600, false);
  const matrix = 'Every skill is a shape crossed with an element: the shape is where the ' +
    'damage lands, the element is what it does when it gets there. ' + comboCount() +
    ' combinations. After each wave the draft offers three, and taking a second ' +
    'skill in an element you already have is a build, not a dilution.';
  wrapText(matrix, iw).forEach(ln => { textOut(ln, ix, y + 8*HS, '#C6BFD2', null, 0, 'left'); y += 19*HS; });
  y += 12*HS;

  // Show the two axes rather than describing them. Four elements down one row,
  // the shapes across — the same glyphs and colours used everywhere else, so
  // this screen teaches the vocabulary the HUD then uses.
  const gx = ix, gy = y + 4*HS, cell = Math.min(38*HS, iw / (SHAPE_KEYS.length + 1));
  SHAPE_KEYS.forEach((sh, i) => {
    const E = ELEMENTS[ELEMENT_KEYS[i % ELEMENT_KEYS.length]];
    drawShapeGlyph(sh, gx + i * cell + cell/2, gy + cell/2, cell * 0.30, E.color, E.glow);
    setFont(Math.round(9.5*HS), 700, true);
    textOut(SHAPES[sh].noun.toUpperCase(), gx + i * cell + cell/2, gy + cell + 2*HS, '#7E778C');
  });
  ELEMENT_KEYS.forEach((el, i) => {
    const E = ELEMENTS[el];
    const cx2 = gx + iw * 0.62 + i * (iw * 0.095);
    circ(cx2, gy + cell/2, cell * 0.22);
    ctx.fillStyle = hexToRgba(E.color, 0.28); ctx.fill();
    ctx.strokeStyle = E.color; ctx.lineWidth = 2*HS; ctx.stroke();
    setFont(Math.round(9.5*HS), 700, true);
    textOut(E.name.toUpperCase(), cx2, gy + cell + 2*HS, E.color);
  });

  const byy = View.h * 0.10 + 36*HS + ph + 18*HS;
  if (uiButton(View.w/2 - 130*HS, byy, 260*HS, 46*HS, 'BACK', 'primary', { hint: 'ESC' }))
    closeOverlay();
  UI.end();
}

/* Rebinding. Click a row, press a key. The defaults stay printed beside the
   current binding, because "what was this before I changed it" is the question
   every remap screen that hides them makes unanswerable. */
const BIND_ROWS = [
  ['slot1', 'Ability 1', 'also LEFT MOUSE'],
  ['slot2', 'Ability 2', 'also RIGHT MOUSE'],
  ['slot3', 'Ability 3', ''],
  ['slot4', 'Ability 4', ''],
  ['dash',  'Dash', ''],
];
function drawBinds(){
  const HS = hudScale();
  dimScreen(0.86);
  UI.begin('binds');
  setFont(Math.round(40*HS), 900, true);
  textOut('KEYS', View.w/2, View.h * 0.14, PAL.bone, PAL.ink, 8);
  setFont(Math.round(13.5*HS), 600, false);
  textOut(S.overlay.listen ? 'press a key  ·  ESC to cancel'
                           : 'click a binding, then press the key you want',
          View.w/2, View.h * 0.14 + 32*HS, S.overlay.listen ? PAL.crit : '#9C93A8');

  const pw = Math.min(View.w - 48, 560*HS);
  const px = (View.w - pw)/2;
  let y = View.h * 0.25;
  const ph = 30*HS + BIND_ROWS.length * 44*HS;
  brassPanel(px, y, pw, ph, 12*HS, 0.96);
  y += 20*HS;

  const custom = Settings.get('keys') || {};
  for (const row of BIND_ROWS){
    const rh = 40*HS;
    const listening = S.overlay.listen === row[0];
    const st = UI.probe({ x: px + 20*HS, y, w: pw - 40*HS, h: rh });
    if (st.hover || (st.focused && UI.usingKeys) || listening){
      rr(px + 20*HS, y, pw - 40*HS, rh, 7*HS);
      ctx.fillStyle = listening ? 'rgba(255,213,46,0.12)' : 'rgba(55,240,200,0.07)'; ctx.fill();
    }
    setFont(Math.round(14.5*HS), 700, false);
    textOut(row[1], px + 34*HS, y + rh/2, PAL.bone, null, 0, 'left');
    if (row[2]){
      setFont(Math.round(11*HS), 600, false);
      textOut(row[2], px + 34*HS + 110*HS, y + rh/2, '#6E667A', null, 0, 'left');
    }
    setFont(Math.round(14*HS), 800, true);
    textOut(listening ? '…' : keyLabel(bindKey(row[0])),
            px + pw - 34*HS, y + rh/2, listening ? PAL.crit : PAL.teal, PAL.ink, 3, 'right');
    if (custom[row[0]]){
      setFont(Math.round(10.5*HS), 600, false);
      textOut('default ' + keyLabel(row[0] === 'dash' ? KEYS.dash.key
                 : (KEYS.slots[BINDS.indexOf(row[0])].key || KEYS.slots[BINDS.indexOf(row[0])].alt)),
              px + pw - 34*HS, y + rh/2 + 14*HS, '#6E667A', null, 0, 'right');
    }
    if (st.fired && !S.overlay.listen){ S.overlay.listen = row[0]; SFX.uiClick(); }
    y += 44*HS;
  }

  y += 18*HS;
  const bw = (pw - 12*HS) / 2;
  if (uiButton(px, y, bw, 46*HS, 'RESET TO DEFAULTS')) Settings.set('keys', null);
  if (uiButton(px + bw + 12*HS, y, bw, 46*HS, 'BACK', 'primary', { hint: 'ESC' })) closeOverlay();
  UI.end();
}

function drawOverlay(){
  if (!S.overlay) return;
  if (S.overlay.kind === 'settings') drawSettings();
  else if (S.overlay.kind === 'howto') drawHowTo();
  else if (S.overlay.kind === 'binds') drawBinds();
}

/* The results screen.

   A run used to end on six numbers and "press R". That is enough for someone
   who already knows the game and nothing at all for a stranger: it never said
   what killed them, never showed what they had built, and gave them no way to
   tell anyone else about the run. This screen answers, in order: what happened,
   why, how far you got, what you were holding when it ended, and what to do
   next. Play Again is the primary action and it is a real button. */
function drawEndScreen(){
  const HS = hudScale();
  const win = S.mode === 'victory';
  const k = clamp(S.endT / 0.8, 0, 1);
  const r = S.result;
  dimScreen(0.55 + 0.3 * k);
  UI.begin('results');

  ctx.save();
  ctx.globalAlpha = k;
  ctx.translate(View.w/2, View.h * 0.135);
  const pop = Settings.motionReduced() ? 1 : lerp(1.7, 1, easeOut(k));
  ctx.scale(pop, pop);
  setFont(Math.round(72*HS), 900, true);
  ctx.shadowColor = win ? PAL.crit : PAL.danger; ctx.shadowBlur = 30;
  textOut(S.endTitle || (win ? 'DECK HELD' : 'BOARDED'), 0, 0,
          win ? PAL.crit : PAL.danger, PAL.ink, 12);
  ctx.restore();
  setFont(Math.round(18*HS), 700, true);
  textOut(S.endReason || '', View.w/2, View.h * 0.135 + 52*HS, PAL.bone, PAL.ink, 5);

  const stats = [
    ['WAVES SURVIVED', (r ? r.wave : 0) + ' / ' + TUNING.totalWaves],
    ['TIME ON DECK', fmtDuration(r ? r.time : S.t)],
    ['BOARDERS DESTROYED', (r ? r.kills : S.stats.kills) + ''],
    ['DAMAGE DEALT', (r ? r.damage : Math.round(S.stats.damage)).toLocaleString()],
    ['BEST CHAIN', (r ? r.chain : S.stats.bestCombo) + ''],
    ['DASHES', (r ? r.dashes : S.stats.dashes) + ''],
  ];
  // The build is the thing a player most wants to look at afterwards, and the
  // thing that makes the shape x element pitch land in hindsight — so it gets
  // named rows, not six anonymous glyphs.
  const loadout = [];
  if (S.basic) loadout.push({ sk: S.basic, tag: 'AUTO' });
  for (let i = 0; i < 4; i++) if (S.slots[i]) loadout.push({ sk: S.slots[i], tag: SLOT_KEYS[i] || ('SLOT ' + (i+1)) });

  const pw = Math.min(View.w - 48, 760*HS);
  const rows = Math.max(stats.length, loadout.length);
  const ph = 74*HS + rows * 31*HS;
  const px = (View.w - pw)/2, py = View.h * 0.265;

  ctx.save();
  ctx.globalAlpha = clamp((S.endT - 0.25) / 0.5, 0, 1);
  brassPanel(px, py, pw, ph, 12*HS, 0.96);
  const colW = (pw - 68*HS) / 2, cx1 = px + 34*HS, cx2 = px + pw/2 + 6*HS;

  setFont(Math.round(12*HS), 800, true);
  textOut('AFTER ACTION', cx1, py + 26*HS, PAL.brass, null, 0, 'left');
  textOut('THE BUILD YOU ENDED WITH', cx2, py + 26*HS, PAL.brass, null, 0, 'left');

  stats.forEach((s, i) => {
    const y = py + 58*HS + i * 31*HS;
    setFont(Math.round(13*HS), 700, true);
    textOut(s[0], cx1, y, '#9C93A8', null, 0, 'left');
    setFont(Math.round(17*HS), 900, true);
    textOut(s[1], cx1 + colW - 10*HS, y, PAL.bone, PAL.ink, 3, 'right');
  });

  loadout.forEach((L, i) => {
    const y = py + 58*HS + i * 31*HS;
    const E = ELEMENTS[L.sk.element];
    drawShapeGlyph(L.sk.shape, cx2 + 11*HS, y, 11*HS, E.color, E.glow);
    setFont(Math.round(14*HS), 800, true);
    textOut(skillName(L.sk).toUpperCase(), cx2 + 28*HS, y, E.color, PAL.ink, 3, 'left');
    setFont(Math.round(11*HS), 800, true);
    textOut(L.tag, cx2 + colW - 6*HS, y, '#7E778C', null, 0, 'right');
  });
  if (!loadout.length){
    setFont(Math.round(13*HS), 600, false);
    textOut('nothing drafted', cx2, py + 58*HS, '#6E667A', null, 0, 'left');
  }

  // Seed and personal best, on one line under the panel. The seed is the whole
  // point of the determinism work: it is what lets one player hand another the
  // exact run they just had.
  const sy = py + ph - 22*HS;
  setFont(Math.round(12.5*HS), 700, false);
  const seedLine = 'SEED ' + (r ? r.seed : seedText(S.seed)) +
                   (FORCED_SEED !== null ? '  (fixed by ?seed=)' : '');
  textOut(seedLine, cx1, sy, '#7E778C', null, 0, 'left');
  const best = RunLog.best();
  if (r && r.pb){
    setFont(Math.round(12.5*HS), 800, true);
    textOut('NEW PERSONAL BEST', px + pw - 34*HS, sy, PAL.crit, PAL.ink, 3, 'right');
  } else if (best){
    setFont(Math.round(12.5*HS), 700, false);
    textOut('BEST: wave ' + best.wave + ' · ' + best.kills + ' kills',
            px + pw - 34*HS, sy, '#7E778C', null, 0, 'right');
  }
  ctx.restore();

  // What the draft actually gave you, in the order you took it. Without this
  // the run summary describes an outcome and never the choices behind it.
  let cardsH = 0;
  if (r && r.cards.length){
    ctx.save();
    ctx.globalAlpha = clamp((S.endT - 0.4) / 0.5, 0, 1);
    setFont(Math.round(12.5*HS), 600, false);
    const lines = wrapText(r.cards.join('  ·  '), pw - 40*HS);
    setFont(Math.round(11*HS), 800, true);
    textOut('DRAFTED', View.w/2, py + ph + 16*HS, PAL.brass);
    setFont(Math.round(12.5*HS), 600, false);
    lines.forEach((ln, i) => textOut(ln, View.w/2, py + ph + 36*HS + i * 18*HS, '#A79EB4'));
    cardsH = 30*HS + lines.length * 18*HS;
    ctx.restore();
  }

  if (S.endT > 0.6){
    ctx.save();
    ctx.globalAlpha = clamp((S.endT - 0.6) / 0.4, 0, 1);
    const by = py + ph + cardsH + 26*HS;
    const bw = 232*HS, bh = 54*HS, gap = 14*HS;
    const bx = View.w/2 - (bw * 2 + gap) / 2;
    if (uiButton(bx, by, bw, bh, 'PLAY AGAIN', 'primary', { hint: 'ENTER  ·  R' })) startRun();
    if (uiButton(bx + bw + gap, by, bw, bh, 'COPY RUN REPORT', null, { hint: 'C' }) && r)
      copyText(runReportText(r));
    ctx.restore();
  }

  // Confirmation that the copy actually happened. Clipboard writes fail
  // silently on insecure origins, which is most playtest setups, so "did that
  // work" must not be a guess.
  if (S.copyToast){
    S.copyToast.t += 1/60;
    const a = clamp(2.2 - S.copyToast.t, 0, 1);
    if (a > 0){
      setFont(Math.round(14*HS), 800, true);
      textOut(S.copyToast.ok ? 'run report copied to clipboard'
                             : 'could not reach the clipboard — press C again after clicking the page',
              View.w/2, View.h - 26*HS,
              S.copyToast.ok ? PAL.teal : PAL.dangerIn, PAL.ink, 4);
    } else S.copyToast = null;
  }
  UI.end();
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
    // The low-health vignette stays — it is the only warning that you are one
    // hit from the end — but reduced motion holds it steady instead of pulsing.
    const pulse = Settings.motionReduced() ? 0.32 : 0.35 + Math.sin(S.rt * 5.5) * 0.22;
    ctx.save();
    ctx.globalAlpha = clamp(pulse * (1 - hpFrac/0.3) * 0.9, 0, 1);
    ctx.drawImage(_redCv, 0, 0, w, h);
    ctx.restore();
  }
  ctx.drawImage(_vigCv, 0, 0, w, h);
  // Full-screen flashes are gated in one place. Reduced motion removes them
  // entirely — this is the photosensitivity-relevant effect in the game, and a
  // setting that removes it only from the call sites someone remembered is
  // worse than none. The simulation still sets the values; they simply do not
  // reach the screen.
  const fs = Settings.flashScale();
  if (S.flashRed > 0 && fs > 0){
    ctx.fillStyle = 'rgba(255,61,46,' + (S.flashRed * 0.3 * fs).toFixed(3) + ')';
    ctx.fillRect(0, 0, w, h);
  }
  if (S.flashWhite > 0 && fs > 0){
    ctx.fillStyle = 'rgba(255,236,200,' + (S.flashWhite * 0.7 * fs).toFixed(3) + ')';
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

  if (PRESET.lanes) drawHulk();

  // air moving over the planking, under everything that stands on it
  drawAirstream(false);

  // --- flat on the deck
  drawFields();
  if (PRESET.lanes){ drawLaneCrossings(); drawLaneWalls(); }
  drawTelegraphs();
  drawAimLines();
  drawAoePreview();
  drawGroundFx();
  drawSentries();

  // --- billboards, far to near
  const list = [];
  for (const p of PROPS)     if (!p.dead) list.push({ y: p.y, k: 0, o: p });
  if (PRESET.lanes){
    for (const t of S.turrets) list.push({ y: t.y, k: 5, o: t });
    for (const c of S.crew)    if (!c.dead) list.push({ y: c.y, k: 6, o: c });
  }
  for (const e of S.enemies) list.push({ y: e.y, k: 1, o: e });
  list.push({ y: S.boiler.y, k: 2 });
  for (const p of S.pickups) list.push({ y: p.y, k: 4, o: p });
  list.sort((a, b) => a.y - b.y);
  for (const it of list){
    if (it.k === 0) drawPropBillboard(it.o);
    else if (it.k === 1) drawEnemyBillboard(it.o);
    else if (it.k === 2) drawBoilerBillboard();
    else if (it.k === 3) drawPlayerBillboard();
    else if (it.k === 5) drawTurretBillboard(it.o);
    else if (it.k === 6) drawCrewBillboard(it.o);
    else drawPickupBillboard(it.o);
  }

  // the captain last, over everything — she is never allowed to be occluded
  if (S.player.hp > 0) drawPlayerBillboard();
  drawXrayPass();

  // --- above the deck
  drawBolts();
  drawAirstream(true);          // and a few streaks in front of the fight
  drawAirFx();
  drawRay();
  drawParticles();
  drawNums();
  drawEnvelope();
  ctx.restore();
  if (S.mode === 'play' || S.mode === 'pause'){
    drawObjectiveMarker();
    if (PRESET.lanes && S.mode === 'play'){ drawLaneStatus(); drawHulkBar(); drawLaneAlert(); }
  }

  drawScreenFx();
  const ended = S.mode === 'gameover' || S.mode === 'victory';
  if (S.mode !== 'title' && !ended) drawHUD();
  // An overlay replaces the screen underneath rather than stacking on it: two
  // panels of controls at once is two sets of hit targets, and the one you
  // cannot see still takes clicks.
  if (S.overlay) drawOverlay();
  else if (S.mode === 'draft') drawDraft();
  else if (S.mode === 'pause') drawPause();
  else if (S.mode === 'title') drawTitle();
  else if (ended) drawEndScreen();
  if (S.showFps) drawFps();
  drawCursor();
  // Remember where the mouse was, so a widget can tell "the pointer moved onto
  // me" from "the pointer happens to be resting on me while I use the keyboard".
  UI.frameEnd();
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

/* The seam the headless harness drives (tools/harness.mjs). It hands out the
   real state object and the real functions rather than a summary, because a
   harness that tests a summary tests the summary. hurtPlayer/hurtBoiler are
   here specifically so a test can end a run the way the game ends one —
   setting `hp = 0` directly skips the code that decides the run is over, and a
   test that does that is asserting about a state the game never reaches. */
window.SKYGEAR = { S, TUNING, SHAPES, ELEMENTS, ENEMIES, WAVES, CARDS, CAM, Assets, FEEL, DT,
                   startRun, startWave, spawnEnemy, openDraft, newSkill, castSlot,
                   skillStats, step, rollCards, rollSkillCards, updateRay, endRay,
                   render, Particles, hurtPlayer, hurtBoiler, hitEnemy, pickCard, closeDraft,
                   Rng, Settings, Store, RunLog, runReportText, seedText, buildRunRecord, UI,
                   Hints, openSettings, openHowTo, openBinds, closeOverlay,
                   // v11 — the close-quarters layer, exposed so the harness can
                   // assert against the real systems rather than a re-implementation
                   // of them. PROPS is the live array the renderer and the
                   // collision pass both hold references into.
                   PROPS, LIVE_PROPS, hitProp, popProp, restowProps, damageArea,
                   damagePropsArea, gainPressure, ventNow, healPlayer, Voice,
                   // the delivery layer, so the harness can assert that the
                   // files a build claims to have are files it can actually
                   // decode — the failure this project has already had twice
                   AudioBank, Sound, AUDIO_MANIFEST, fxCap,
                   Telemetry, rerollDraft, cardScope, cardAffects, CARD_SCOPE,
                   openDraft,
                   jump(w){ startRun(); S.wave = w - 1; S.interT = 0.05; } };
