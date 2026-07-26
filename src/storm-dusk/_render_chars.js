/* ---------------------------------------------------------------------------
   PROCEDURAL BILLBOARD ART
   Stand-ins for the §4.1/4.2 character sheets, painted to the same rules:
   chibi proportions, thick near-black ink outline, flat colour fields, the
   standard two-source light applied as a post-pass, feet on the bottom-center
   anchor, no baked contact shadow. Drawn once into a sprite, then blitted.
--------------------------------------------------------------------------- */
const SPR = 256;              // design height for a normal character sprite
const SPR_BOSS = 460;
const OUT = 7;                // ink outline weight (~2.7% of sprite height)

// world height of each billboard, in ground units
const BILLBOARD_H = {
  hero: 128, SCRAPPER: 120, GUNNER: 118, ARMORED: 172, SWARM: 76, BOSS: 360,
};

function limb(x0, y0, x1, y1, w, col){
  ctx.lineCap = 'round';
  ctx.strokeStyle = ink(); ctx.lineWidth = w + OUT;
  ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x1, y1); ctx.stroke();
  ctx.strokeStyle = col; ctx.lineWidth = w;
  ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x1, y1); ctx.stroke();
}
function blob(x, y, rx, ry, col, rot){
  ell(x, y, rx, ry, rot); fillStroke(C(col), ink(), OUT);
}
function plate(x, y, w, h, r, col){
  rr(x - w/2, y - h/2, w, h, r); fillStroke(C(col), ink(), OUT);
}
function rivets(pts, col){
  ctx.fillStyle = C(col || PAL.brass);
  for (const p of pts){ circ(p[0], p[1], 3.4); ctx.fill(); }
}
function specular(x, y, rx, ry, rot, a){
  ctx.save(); ctx.globalAlpha = a === undefined ? 0.5 : a;
  ctx.fillStyle = PAL.brassLite;
  ell(x, y, rx, ry, rot || 0); ctx.fill();
  ctx.restore();
}
function emissive(x, y, r, col, core){
  ctx.save(); ctx.globalCompositeOperation = 'lighter';
  drawGlow(x, y, r * 2.6, col, 0.75);
  ctx.restore();
  circ(x, y, r); fillStroke(col, ink(), OUT * 0.6);
  if (core !== false){ ctx.fillStyle = '#FFFFFF'; circ(x - r*0.2, y - r*0.2, r*0.4); ctx.fill(); }
}

/* --- H1 · Sky-Corsair (the player) --------------------------------------- */
function paintHero(back, attack){
  const COAT = '#241F2E', COATL = '#332B3E', LINING = PAL.copper, SKIN = '#D8A87C';
  // boots
  limb(-14, -14, -16, -2, 15, '#241C22');
  limb( 14, -14,  16, -2, 15, '#241C22');
  // coat body — wide skirt, compact torso
  ctx.beginPath();
  ctx.moveTo(-20, -108);
  ctx.quadraticCurveTo(-40, -60, -34, -8);
  ctx.lineTo(34, -8);
  ctx.quadraticCurveTo(40, -60, 20, -108);
  ctx.closePath();
  fillStroke(C(COAT), ink(), OUT);
  if (!back){
    // open front showing the oxidised-copper lining
    ctx.beginPath();
    ctx.moveTo(-9, -104); ctx.quadraticCurveTo(-15, -55, -11, -10);
    ctx.lineTo(11, -10); ctx.quadraticCurveTo(15, -55, 9, -104);
    ctx.closePath();
    fillStroke(C(LINING), ink(), OUT * 0.7);
    ctx.fillStyle = C(PAL.brass);
    for (let i = 0; i < 3; i++){ circ(0, -88 + i * 22, 3.6); ctx.fill(); }
  }
  // harness
  ctx.strokeStyle = C(PAL.leather); ctx.lineWidth = 7;
  ctx.beginPath(); ctx.moveTo(-18, -96); ctx.lineTo(16, -62); ctx.stroke();
  ctx.fillStyle = C(PAL.brass); rr(10, -70, 12, 12, 3); ctx.fill();
  // shoulders
  blob(-22, -104, 13, 11, COATL);
  blob( 22, -104, 13, 11, COATL);
  // arms + the heavy brass gauntlet
  if (attack){
    limb(22, -102, 52, -128, 12, COATL);
    blob(56, -132, 12, 12, PAL.brass);
    // sabre, gear-toothed guard
    ctx.save(); ctx.translate(56, -132); ctx.rotate(-0.5);
    ctx.beginPath();
    ctx.moveTo(6, -6); ctx.quadraticCurveTo(62, -22, 96, 2);
    ctx.quadraticCurveTo(60, 6, 6, 6); ctx.closePath();
    fillStroke(C('#C6CBD6'), ink(), OUT * 0.7);
    ctx.strokeStyle = C(PAL.brass); ctx.lineWidth = 8;
    ctx.beginPath(); ctx.arc(2, 0, 12, -1.3, 1.3); ctx.stroke();
    ctx.restore();
  } else {
    limb(22, -102, 34, -58, 12, COATL);
    blob(37, -50, 11, 11, PAL.brass);
    specular(34, -54, 5, 3, -0.6, 0.45);
    // sabre held low
    ctx.save(); ctx.translate(37, -50); ctx.rotate(0.55);
    ctx.beginPath();
    ctx.moveTo(4, -4); ctx.quadraticCurveTo(44, -14, 70, 2);
    ctx.quadraticCurveTo(42, 5, 4, 4); ctx.closePath();
    fillStroke(C('#C6CBD6'), ink(), OUT * 0.6);
    ctx.restore();
  }
  limb(-22, -102, -34, -62, 12, COAT);
  blob(-37, -56, 10, 10, PAL.leather);
  // oversized head
  blob(0, -136, 28, 27, SKIN);
  // wind-blown hair
  ctx.beginPath();
  ctx.moveTo(-27, -146);
  ctx.quadraticCurveTo(-40, -178, -8, -170);
  ctx.quadraticCurveTo(18, -184, 30, -156);
  ctx.quadraticCurveTo(40, -150, 26, -142);
  ctx.quadraticCurveTo(0, -156, -27, -146);
  ctx.closePath();
  fillStroke(C('#3A2A22'), ink(), OUT);
  // goggles pushed up into the hair
  ctx.strokeStyle = C(PAL.leather); ctx.lineWidth = 8;
  ctx.beginPath(); ctx.moveTo(-26, -152); ctx.lineTo(26, -152); ctx.stroke();
  ctx.fillStyle = C(PAL.brass);
  circ(-13, -153, 9); fillStroke(C(PAL.brass), ink(), OUT * 0.7);
  circ( 13, -153, 9); fillStroke(C(PAL.brass), ink(), OUT * 0.7);
  specular(-15, -156, 3.5, 2.5, -0.5, 0.7);
  if (!back){
    // face
    ctx.fillStyle = C(PAL.ink);
    circ(-10, -132, 3.4); ctx.fill(); circ(10, -132, 3.4); ctx.fill();
    ctx.strokeStyle = C('#8A5B45'); ctx.lineWidth = 3;
    ctx.beginPath(); ctx.arc(0, -124, 8, 0.35, Math.PI - 0.35); ctx.stroke();
  }
}

/* --- E1 · Boarding Automaton  (SCRAPPER) --------------------------------- */
function paintAutomaton(back, attack){
  const IRON = '#5A5A68', IRON_D = '#43434F';
  limb(-13, -16, -15, -2, 14, IRON_D);
  limb( 13, -16,  15, -2, 14, IRON_D);
  plate(0, -60, 62, 74, 12, IRON);
  rivets([[-24,-90],[24,-90],[-24,-30],[24,-30]]);
  // exposed brass gear heart
  if (!back){
    circ(0, -62, 17); fillStroke(C(PAL.ink), ink(), OUT * 0.7);
    ctx.save(); ctx.translate(0, -62); ctx.rotate(0.3);
    ctx.strokeStyle = C(PAL.brass); ctx.lineWidth = 6;
    circ(0, 0, 10); ctx.stroke();
    for (let i = 0; i < 8; i++){
      const a = i / 8 * TAU;
      ctx.beginPath();
      ctx.moveTo(Math.cos(a)*10, Math.sin(a)*10);
      ctx.lineTo(Math.cos(a)*15, Math.sin(a)*15); ctx.stroke();
    }
    ctx.restore();
  }
  // shoulders + hook-blade arms
  blob(-32, -96, 13, 12, IRON_D);
  blob( 32, -96, 13, 12, IRON_D);
  const lift = attack ? -46 : 0;
  for (const s of [-1, 1]){
    limb(s*32, -94, s*46, -52 + lift, 11, IRON_D);
    ctx.save(); ctx.translate(s*48, -46 + lift); ctx.scale(s, 1);
    ctx.strokeStyle = ink(); ctx.lineWidth = 13;
    ctx.beginPath(); ctx.arc(0, 0, 15, -1.9, 1.1); ctx.stroke();
    ctx.strokeStyle = C('#C6CBD6'); ctx.lineWidth = 7;
    ctx.beginPath(); ctx.arc(0, 0, 15, -1.9, 1.1); ctx.stroke();
    ctx.restore();
  }
  // head, single ember lens
  plate(0, -118, 46, 40, 11, '#4E4E5A');
  ctx.strokeStyle = C(PAL.brass); ctx.lineWidth = 5;
  ctx.beginPath(); ctx.moveTo(-20, -136); ctx.lineTo(20, -136); ctx.stroke();
  if (!back) emissive(0, -118, 9, PAL.fire);
  else { ctx.fillStyle = C('#2C2C35'); rr(-14, -128, 28, 20, 5); ctx.fill(); }
  // steam wisps at the joints
  ctx.save(); ctx.globalAlpha = 0.25; ctx.fillStyle = PAL.moon;
  ell(-38, -102, 11, 7, -0.4); ctx.fill();
  ell( 38, -104, 9, 6, 0.4); ctx.fill();
  ctx.restore();
}

/* --- E2 · Cog-Gremlin  (SWARM) ------------------------------------------- */
function paintGremlin(back, attack){
  limb(-11, -14, -14, -2, 12, '#2E2A26');
  limb( 11, -14,  14, -2, 12, '#2E2A26');
  // hunched body in scrap brass
  blob(0, -52, 30, 30, '#6E5B40');
  plate(0, -56, 40, 30, 8, PAL.brass);
  specular(-8, -64, 11, 4, -0.3, 0.4);
  rivets([[-15,-46],[15,-46]]);
  // head, wild ember eyes
  blob(0, -96, 26, 24, '#87704E');
  ctx.beginPath();
  ctx.moveTo(-24, -104); ctx.lineTo(-40, -128); ctx.lineTo(-14, -114); ctx.closePath();
  fillStroke(C('#6E5A3E'), ink(), OUT * 0.7);
  ctx.beginPath();
  ctx.moveTo(24, -104); ctx.lineTo(40, -128); ctx.lineTo(14, -114); ctx.closePath();
  fillStroke(C('#6E5A3E'), ink(), OUT * 0.7);
  if (!back){
    emissive(-9, -98, 5, PAL.fire, false);
    emissive( 9, -98, 5, PAL.fire, false);
    ctx.strokeStyle = ink(); ctx.lineWidth = 3;
    ctx.beginPath(); ctx.moveTo(-9, -84); ctx.lineTo(9, -84); ctx.stroke();
  }
  // oversized wrench
  ctx.save();
  ctx.translate(attack ? 28 : 30, attack ? -104 : -54);
  ctx.rotate(attack ? -1.15 : 0.5);
  limb(0, 0, 0, -46, 11, '#8A8A95');
  ctx.strokeStyle = ink(); ctx.lineWidth = 20;
  ctx.beginPath(); ctx.arc(0, -54, 13, 0.5, Math.PI - 0.5, true); ctx.stroke();
  ctx.strokeStyle = C('#9AA0AB'); ctx.lineWidth = 12;
  ctx.beginPath(); ctx.arc(0, -54, 13, 0.5, Math.PI - 0.5, true); ctx.stroke();
  ctx.restore();
  limb(-26, -60, -34, -34, 10, '#6E5A3E');
}

/* --- E3 · Tesla Drone  (GUNNER, hovers) ---------------------------------- */
function paintDrone(back, attack){
  // dangling grounding chains — anchor sits below them, with an air gap
  ctx.strokeStyle = ink(); ctx.lineWidth = 6;
  for (const s of [-1, 0, 1]){
    ctx.beginPath();
    ctx.moveTo(s * 14, -60);
    ctx.quadraticCurveTo(s * 20, -34, s * 16 + 4, -8);
    ctx.stroke();
  }
  ctx.strokeStyle = C(PAL.leather); ctx.lineWidth = 3.5;
  for (const s of [-1, 0, 1]){
    ctx.beginPath();
    ctx.moveTo(s * 14, -60);
    ctx.quadraticCurveTo(s * 20, -34, s * 16 + 4, -8);
    ctx.stroke();
  }
  // brass sphere
  blob(0, -96, 38, 38, PAL.brass);
  specular(-13, -112, 14, 8, -0.6, 0.5);
  ctx.strokeStyle = C(PAL.ink); ctx.lineWidth = 5;
  ctx.beginPath(); ctx.arc(0, -96, 38, 0.5, Math.PI - 0.5); ctx.stroke();
  rivets([[-30,-96],[30,-96],[0,-130]]);
  // cracked glass core
  if (!back){
    emissive(0, -96, 15, PAL.tesla);
    ctx.strokeStyle = C(PAL.ink); ctx.lineWidth = 2.4;
    ctx.beginPath();
    ctx.moveTo(-12, -104); ctx.lineTo(-2, -96); ctx.lineTo(-9, -88);
    ctx.moveTo(6, -108); ctx.lineTo(2, -97); ctx.lineTo(11, -90);
    ctx.stroke();
  }
  // three gimballed propellers
  for (const s of [-1, 1]){
    limb(s * 30, -114, s * 50, -134, 8, '#5A5A66');
    ctx.strokeStyle = ink(); ctx.lineWidth = 9;
    ctx.beginPath(); ctx.moveTo(s*50 - 24, -136); ctx.lineTo(s*50 + 24, -132); ctx.stroke();
    ctx.strokeStyle = C('#8A8A95'); ctx.lineWidth = 5;
    ctx.beginPath(); ctx.moveTo(s*50 - 24, -136); ctx.lineTo(s*50 + 24, -132); ctx.stroke();
  }
  limb(0, -132, 0, -152, 8, '#5A5A66');
  ctx.strokeStyle = ink(); ctx.lineWidth = 9;
  ctx.beginPath(); ctx.moveTo(-26, -154); ctx.lineTo(26, -150); ctx.stroke();
  ctx.strokeStyle = C('#8A8A95'); ctx.lineWidth = 5;
  ctx.beginPath(); ctx.moveTo(-26, -154); ctx.lineTo(26, -150); ctx.stroke();
  if (attack){
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    drawGlow(0, -96, 56, PAL.tesla, 0.85);
    ctx.restore();
    ctx.strokeStyle = '#FFFFFF'; ctx.lineWidth = 3;
    for (const s of [-1, 1]){
      ctx.beginPath();
      ctx.moveTo(s*16, -96); ctx.lineTo(s*34, -108); ctx.lineTo(s*28, -86); ctx.lineTo(s*46, -98);
      ctx.stroke();
    }
  }
}

/* --- E4 · Furnace Knight  (ARMORED) -------------------------------------- */
function paintKnight(back, attack){
  const IRON = '#4E4E5C', IRON_L = '#6A6A7A';
  limb(-20, -22, -24, -2, 20, '#2A2A34');
  limb( 20, -22,  24, -2, 20, '#2A2A34');
  // pot-belly furnace body
  blob(0, -78, 50, 52, IRON);
  plate(0, -122, 66, 30, 10, IRON_L);
  rivets([[-34,-122],[34,-122],[-38,-70],[38,-70]]);
  if (!back){
    // grated chest spilling ember light
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    drawGlow(0, -74, 56, PAL.fire, 0.7);
    ctx.restore();
    rr(-24, -96, 48, 46, 8); fillStroke(C('#5A2308'), ink(), OUT);
    ctx.fillStyle = PAL.fire; rr(-20, -92, 40, 38, 5); ctx.fill();
    ctx.strokeStyle = C(PAL.ink); ctx.lineWidth = 6;
    for (let i = 0; i < 4; i++){
      ctx.beginPath(); ctx.moveTo(-22, -88 + i * 10); ctx.lineTo(22, -88 + i * 10); ctx.stroke();
    }
    ctx.fillStyle = PAL.fireCore; rr(-14, -70, 28, 12, 4); ctx.fill();
  }
  // chimney shoulder
  ctx.save(); ctx.translate(-40, -136);
  plate(0, 0, 24, 34, 6, '#4A4A55');
  ctx.strokeStyle = C(PAL.brass); ctx.lineWidth = 4;
  ctx.beginPath(); ctx.moveTo(-11, -12); ctx.lineTo(11, -12); ctx.stroke();
  ctx.restore();
  blob(40, -132, 20, 17, IRON_L);
  // anchor-hammer
  ctx.save();
  if (attack){ ctx.translate(30, -176); ctx.rotate(-0.25); }
  else { ctx.translate(46, -92); ctx.rotate(0.35); }
  limb(0, 0, 6, -70, 13, PAL.leather);
  ctx.save(); ctx.translate(6, -80);
  plate(0, 0, 62, 38, 8, '#5A5A66');
  rivets([[-22,-10],[22,-10],[-22,10],[22,10]]);
  specular(-14, -12, 16, 5, -0.15, 0.35);
  ctx.restore();
  ctx.restore();
  limb(-40, -128, -52, -84, 14, IRON);
  // head, recessed behind the collar
  blob(0, -150, 22, 20, '#2E2E38');
  if (!back){
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    drawGlow(0, -150, 30, PAL.fire, 0.5);
    ctx.restore();
    ctx.fillStyle = PAL.fire;
    rr(-13, -154, 26, 7, 3); ctx.fill();
  }
}

/* --- E6 · The Brass Colossus  (BOSS) ------------------------------------- */
function paintColossus(back, attack){
  const IRON = '#3E3E4A';
  const s2 = attack ? 1.12 : 1;
  ctx.save(); ctx.scale(s2, 1);
  // legs
  limb(-46, -60, -56, -4, 40, '#2A2A34');
  limb( 46, -60,  56, -4, 40, '#2A2A34');
  ctx.restore();
  // cathedral-of-pipes torso
  plate(0, -190, 168, 190, 24, IRON);
  ctx.strokeStyle = C(PAL.brass); ctx.lineWidth = 9;
  for (let i = -2; i <= 2; i++){
    ctx.beginPath();
    ctx.moveTo(i * 30, -278); ctx.lineTo(i * 30, -110); ctx.stroke();
  }
  rivets([[-72,-272],[72,-272],[-72,-110],[72,-110]], PAL.brassLite);
  // gauges
  for (const gx of [-52, 52]){
    circ(gx, -252, 15); fillStroke(C(PAL.brassLite), ink(), OUT);
    ctx.strokeStyle = ink(); ctx.lineWidth = 3.5;
    ctx.beginPath(); ctx.moveTo(gx, -252); ctx.lineTo(gx + 9, -260); ctx.stroke();
  }
  // furnace maw
  if (!back){
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    drawGlow(0, -170, attack ? 150 : 110, PAL.fire, attack ? 0.95 : 0.7);
    ctx.restore();
    ctx.beginPath();
    ctx.moveTo(-46, -200); ctx.lineTo(46, -200);
    ctx.lineTo(34, -132); ctx.lineTo(-34, -132); ctx.closePath();
    fillStroke(C('#5A2308'), ink(), OUT);
    ctx.fillStyle = attack ? PAL.fireCore : PAL.fire;
    ctx.beginPath();
    ctx.moveTo(-36, -194); ctx.lineTo(36, -194);
    ctx.lineTo(26, -140); ctx.lineTo(-26, -140); ctx.closePath(); ctx.fill();
    // teeth
    ctx.fillStyle = C('#C6CBD6');
    for (let i = -2; i <= 2; i++){
      ctx.beginPath();
      ctx.moveTo(i * 16 - 7, -194); ctx.lineTo(i * 16 + 7, -194); ctx.lineTo(i * 16, -176);
      ctx.closePath(); ctx.fill();
    }
  }
  // four arms: two fists, two cannon barrels
  const spread = attack ? 1.35 : 1;
  for (const s of [-1, 1]){
    // upper — cannon
    ctx.save();
    ctx.translate(s * 84, -256);
    ctx.rotate(s * (attack ? -0.55 : -0.15));
    limb(0, 0, s * 46, 10, 24, IRON);
    ctx.save(); ctx.translate(s * 66, 14);
    plate(0, 0, 62, 40, 10, '#5A5A66');
    circ(s * 26, 0, 15); fillStroke(C(PAL.ink), ink(), OUT * 0.7);
    if (attack) emissive(s * 26, 0, 9, PAL.fireCore);
    ctx.restore();
    ctx.restore();
    // lower — fist
    ctx.save();
    ctx.translate(s * 82, -170);
    ctx.rotate(s * (attack ? 0.5 : 0.2) * spread);
    limb(0, 0, s * 40, 44, 26, IRON);
    blob(s * 52, 60, 30, 28, '#5A5A66');
    rivets([[s*44, 50],[s*60, 68]], PAL.brassLite);
    ctx.restore();
  }
  // shoulder stacks
  for (const s of [-1, 1]){
    ctx.save(); ctx.translate(s * 76, -318);
    plate(0, 0, 40, 56, 8, '#4A4A55');
    ctx.strokeStyle = C(PAL.brass); ctx.lineWidth = 6;
    ctx.beginPath(); ctx.moveTo(-18, -20); ctx.lineTo(18, -20); ctx.stroke();
    ctx.restore();
  }
  // head
  plate(0, -320, 86, 62, 16, '#33333D');
  ctx.strokeStyle = C(PAL.brass); ctx.lineWidth = 7;
  ctx.beginPath(); ctx.moveTo(-40, -348); ctx.lineTo(40, -348); ctx.stroke();
  if (!back){
    emissive(-20, -320, 9, PAL.danger, false);
    emissive( 20, -320, 9, PAL.danger, false);
    emissive(  0, -300, 6, PAL.danger, false);
  }
  // captain's brass tricorn — this is still a pirate
  ctx.beginPath();
  ctx.moveTo(-72, -352); ctx.quadraticCurveTo(0, -420, 72, -352);
  ctx.quadraticCurveTo(0, -374, -72, -352);
  ctx.closePath();
  fillStroke(C('#241F2E'), ink(), OUT);
  ctx.fillStyle = C(PAL.brass); circ(0, -368, 11); ctx.fill();
}

/* --- sprite bake + lookup ------------------------------------------------ */
const CHAR_PAINT = {
  hero: paintHero, SCRAPPER: paintAutomaton, SWARM: paintGremlin,
  GUNNER: paintDrone, ARMORED: paintKnight, BOSS: paintColossus,
};
function charSprite(kind, view){        // view: 'front_idle' | 'back_idle' | 'front_attack'
  const key = 'char|' + kind + '|' + view;
  const boss = kind === 'BOSS';
  const H = boss ? SPR_BOSS : SPR;
  const W = Math.round(H * (boss ? 1.15 : 0.95));
  return cachedSprite(key, W, H, (c2, w, h) => {
    c2.save();
    c2.translate(w / 2, h * 0.94);
    const src = boss ? 420 : 190;                 // painter units -> sprite height
    const s = (h * 0.86) / src;
    c2.scale(s, s);
    c2.lineJoin = 'round'; c2.lineCap = 'round';
    CHAR_PAINT[kind](view === 'back_idle', view === 'front_attack');
    c2.restore();
    applyTwoSourceLight(c2, w, h);
  });
}
// asset first, procedural stand-in second
function charImage(kind, view){
  const assetKey = (kind === 'hero' ? 'hero' : kind) + '_' + view;
  return Assets.get(assetKey) || charSprite(kind, view);
}
