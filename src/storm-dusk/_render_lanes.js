/* The crossings are the only breaks in the cargo runs, and a gap between two
   boxes does not read as "you may cross here" — especially at the bow, where
   the wall ends and the deck just continues. So each passage gets painted onto
   the deck: hazard chevrons pointing both ways across the lane boundary. Ground
   art, so it goes through the projection and lies flat like everything else. */
function drawLaneCrossings(){
  if (!PRESET.lanes) return;
  const D = TUNING.deck, laneW = D.w / LANE_N;
  const left = D.cx - D.w / 2;
  const gaps = [[FWD_Y0, FWD_Y1], [CROSS_Y0, CROSS_Y1]];
  ctx.save();
  for (const [y0, y1] of gaps){
    const cy = (y0 + y1) / 2, half = (y1 - y0) * 0.5;
    for (let i = 1; i < LANE_N; i++){
      const wx = left + laneW * i;
      // a soft pool marking the opening
      const a = CAM.project(wx - 92, cy, 0), b = CAM.project(wx + 92, cy, 0);
      const t = CAM.project(wx, y0 + 6, 0), u = CAM.project(wx, y1 - 6, 0);
      ctx.beginPath();
      ctx.moveTo(a.x, a.y); ctx.lineTo(t.x, t.y);
      ctx.lineTo(b.x, b.y); ctx.lineTo(u.x, u.y); ctx.closePath();
      ctx.fillStyle = 'rgba(143,166,201,0.055)'; ctx.fill();
      ctx.strokeStyle = 'rgba(143,166,201,0.20)'; ctx.lineWidth = 2; ctx.stroke();
      // chevrons, one set pointing each way
      for (const dir of [-1, 1]){
        for (let k = 0; k < 2; k++){
          const px = wx + dir * (26 + k * 34);
          const p0 = CAM.project(px - dir * 16, cy - half * 0.46, 0);
          const p1 = CAM.project(px,            cy,               0);
          const p2 = CAM.project(px - dir * 16, cy + half * 0.46, 0);
          ctx.beginPath();
          ctx.moveTo(p0.x, p0.y); ctx.lineTo(p1.x, p1.y); ctx.lineTo(p2.x, p2.y);
          ctx.strokeStyle = 'rgba(232,226,210,' + (0.30 - k * 0.11) + ')';
          ctx.lineWidth = 3; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
          ctx.stroke();
        }
      }
    }
  }
  ctx.restore();
}

/* ---------------------------------------------------------------------------
   LANE RENDERING — walls, cannons, crew, the enemy hulk, and the lane readout.
   All inert unless PRESET.lanes.
--------------------------------------------------------------------------- */

// A cargo run drawn as a projected box: top face on the ground plane, plus the
// near vertical face so it reads as something you cannot walk through.
function drawLaneWalls(){
  if (!PRESET.lanes) return;
  const H = 96;
  ctx.save();
  ctx.lineJoin = 'round';
  for (const w of LANE_WALLS){
    const nearY = w.y1, farY = w.y0;
    const bl = CAM.project(w.x0, nearY, 0), br = CAM.project(w.x1, nearY, 0);
    const tl = CAM.project(w.x0, farY, 0),  tr = CAM.project(w.x1, farY, 0);
    const BL = CAM.project(w.x0, nearY, H), BR = CAM.project(w.x1, nearY, H);
    const TL = CAM.project(w.x0, farY, H),  TR = CAM.project(w.x1, farY, H);
    // near face
    ctx.beginPath();
    ctx.moveTo(bl.x, bl.y); ctx.lineTo(br.x, br.y);
    ctx.lineTo(BR.x, BR.y); ctx.lineTo(BL.x, BL.y); ctx.closePath();
    fillStroke('#2A2027', PAL.ink, 4);
    // top face
    ctx.beginPath();
    ctx.moveTo(BL.x, BL.y); ctx.lineTo(BR.x, BR.y);
    ctx.lineTo(TR.x, TR.y); ctx.lineTo(TL.x, TL.y); ctx.closePath();
    fillStroke('#3D2E30', PAL.ink, 4);
    // lashed crates along the run, so it reads as cargo not a wall texture
    const n = Math.max(2, Math.round((nearY - farY) / 150));
    for (let i = 0; i < n; i++){
      const y = lerp(farY + 40, nearY - 40, n === 1 ? 0.5 : i / (n - 1));
      const a = CAM.project(w.x0 + 12, y, H), b = CAM.project(w.x1 - 12, y, H);
      ctx.strokeStyle = hexToRgba(PAL.brass, 0.42); ctx.lineWidth = 3 * a.k;
      ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
      ctx.strokeStyle = hexToRgba(PAL.leather, 0.5); ctx.lineWidth = 2.4 * a.k;
      ctx.beginPath(); ctx.moveTo(a.x, a.y + 5 * a.k); ctx.lineTo(b.x, b.y + 5 * b.k); ctx.stroke();
    }
    // brass capping rail catching the moonlight
    ctx.strokeStyle = hexToRgba(PAL.brass, 0.55); ctx.lineWidth = 3;
    ctx.beginPath(); ctx.moveTo(BL.x, BL.y); ctx.lineTo(TL.x, TL.y); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(BR.x, BR.y); ctx.lineTo(TR.x, TR.y); ctx.stroke();
  }
  ctx.restore();
}

/* --- the lane cannon ------------------------------------------------------ */
function turretSprite(dead){
  return cachedSprite('turret|' + (dead ? 1 : 0), 260, 260, (c2, w, h) => {
    c2.save();
    c2.translate(w / 2, h * ANCHOR);
    c2.scale(h * FIG / 160, h * FIG / 160);
    c2.lineJoin = 'round'; c2.lineCap = 'round';
    if (dead){
      // a broken mount: barrel dropped, still smoking
      plate(0, -16, 96, 30, 6, '#2A2530');
      ctx.save(); ctx.translate(6, -30); ctx.rotate(0.5);
      plate(0, 0, 84, 24, 10, '#3A3640');
      ctx.restore();
      ctx.strokeStyle = C(PAL.ink); ctx.lineWidth = 6;
      ctx.beginPath(); ctx.moveTo(-40, -6); ctx.lineTo(-24, -34); ctx.stroke();
    } else {
      limb(-26, -8, -26, -40, 18, '#3A2C2A');
      limb( 26, -8,  26, -40, 18, '#3A2C2A');
      plate(0, -54, 92, 32, 7, '#54413C');
      rivets([[-38,-54],[38,-54]]);
      plate(0, -84, 54, 40, 10, PAL.iron);
      // barrel
      ctx.save(); ctx.translate(0, -96); ctx.rotate(-0.16);
      plate(0, 0, 112, 30, 14, PAL.brass);
      specular(-20, -9, 30, 4, -0.16, 0.5);
      circ(58, 0, 15); fillStroke(C(PAL.ink), ink(), OUT * 0.7);
      ctx.strokeStyle = C(PAL.copper); ctx.lineWidth = 6;
      ctx.beginPath(); ctx.moveTo(-34, -16); ctx.lineTo(-34, 16); ctx.stroke();
      ctx.restore();
      // an aether coil so it reads as friendly, not another boarder gun
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      drawGlow(0, -84, 46, PAL.teal, 0.55); ctx.restore();
      circ(0, -84, 11); fillStroke(PAL.teal, ink(), OUT * 0.7);
    }
    c2.restore();
    applyTwoSourceLight(c2, w, h);
  });
}
function drawTurretBillboard(t){
  entityShadow(t.x, t.y, t.r * 1.25, 0.55);
  const r = drawBillboard(turretSprite(t.dead), t.x, t.y, t.dead ? 74 : 138,
                          { flash: t.flash > 0 });
  addOccluder(r.p.x, r.p.y, r.wpx * 0.42, r.hpx * 0.58, t.y);
  if (t.dead) return;
  if (t.fireFx > 0){
    const m = CAM.project(t.x + Math.cos(t.ang) * 60, t.y + Math.sin(t.ang) * 60, 96);
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    drawGlow(m.x, m.y, 34 * m.k, PAL.teal, t.fireFx / 0.14);
    ctx.restore();
  }
  // health, always legible: losing a cannon opens the lane
  const top = CAM.project(t.x, t.y, 168);
  const frac = clamp(t.hp / t.maxHp, 0, 1);
  const w = 76 * top.k, h = 7 * top.k;
  ctx.fillStyle = 'rgba(13,11,18,0.85)';
  rr(top.x - w/2 - 2, top.y - 2, w + 4, h + 4, 3); ctx.fill();
  ctx.fillStyle = frac > 0.4 ? PAL.teal : PAL.dangerIn;
  rr(top.x - w/2, top.y, w * frac, h, 2); ctx.fill();
}

/* --- your crew ------------------------------------------------------------ */
function crewSprite(view){
  return cachedSprite('crew|' + view, 190, 210, (c2, w, h) => {
    c2.save();
    c2.translate(w / 2, h * ANCHOR);
    c2.scale(h * FIG / 175, h * FIG / 175);
    c2.lineJoin = 'round'; c2.lineCap = 'round';
    const COAT = '#3A4450', COATL = '#4C5866';
    limb(-11, -12, -13, -2, 13, '#241C22');
    limb( 11, -12,  13, -2, 13, '#241C22');
    // deck-hand: shorter than the captain, teal sash so they read as friendly
    ctx.beginPath();
    ctx.moveTo(-16, -86); ctx.quadraticCurveTo(-30, -46, -26, -8);
    ctx.lineTo(26, -8); ctx.quadraticCurveTo(30, -46, 16, -86);
    ctx.closePath();
    fillStroke(C(COAT), ink(), OUT);
    ctx.strokeStyle = C(PAL.teal); ctx.lineWidth = 7;
    ctx.beginPath(); ctx.moveTo(-15, -74); ctx.lineTo(14, -46); ctx.stroke();
    blob(-18, -82, 11, 9, COATL);
    blob( 18, -82, 11, 9, COATL);
    if (view === 'front'){
      // boarding pike
      ctx.save(); ctx.translate(20, -80); ctx.rotate(-0.55);
      limb(0, 0, 46, 0, 7, PAL.leather);
      ctx.beginPath();
      ctx.moveTo(46, -5); ctx.lineTo(66, 0); ctx.lineTo(46, 5); ctx.closePath();
      fillStroke(C('#C6CBD6'), ink(), OUT * 0.6);
      ctx.restore();
    }
    blob(0, -108, 21, 20, '#C89A72');
    // watch cap
    ctx.beginPath();
    ctx.moveTo(-21, -114); ctx.quadraticCurveTo(0, -140, 21, -114);
    ctx.quadraticCurveTo(0, -124, -21, -114); ctx.closePath();
    fillStroke(C('#2A3038'), ink(), OUT);
    if (view === 'front'){
      ctx.fillStyle = C(PAL.ink);
      circ(-7, -106, 2.6); ctx.fill(); circ(7, -106, 2.6); ctx.fill();
    }
    c2.restore();
    applyTwoSourceLight(c2, w, h);
  });
}
function drawCrewBillboard(c){
  entityShadow(c.x, c.y, c.r * 1.1, 0.45);
  const front = Math.sin(c.facing) > -0.15;
  const bob = Math.sin(c.anim * 6) * 2.5;
  drawBillboard(crewSprite(front ? 'front' : 'back'), c.x, c.y, 96,
                { mirror: Math.cos(c.facing) > 0, lift: bob, flash: c.flash > 0 });
  if (c.hp < c.maxHp){
    const top = CAM.project(c.x, c.y, 112);
    const w = 26 * top.k, h = 4 * top.k;
    ctx.fillStyle = 'rgba(13,11,18,0.8)';
    rr(top.x - w/2 - 1.5, top.y - 1.5, w + 3, h + 3, 2); ctx.fill();
    ctx.fillStyle = PAL.teal;
    rr(top.x - w/2, top.y, w * clamp(c.hp/c.maxHp, 0, 1), h, 2); ctx.fill();
  }
}

/* --- their hulk, grappled to the bow -------------------------------------- */
function hulkSprite(){
  return cachedSprite('hulk', 900, 520, (c2, w, h) => {
    c2.save();
    c2.translate(w / 2, h * 0.96);
    c2.scale(h / 470, h / 470);
    c2.lineJoin = 'round'; c2.lineCap = 'round';
    // hull
    ctx.beginPath();
    ctx.moveTo(-400, 0); ctx.quadraticCurveTo(-330, -230, 0, -270);
    ctx.quadraticCurveTo(330, -230, 400, 0);
    ctx.closePath();
    fillStroke(C('#241C28'), ink(), 9);
    // ribs
    ctx.strokeStyle = hexToRgba(PAL.iron, 0.7); ctx.lineWidth = 8;
    for (let i = -3; i <= 3; i++){
      ctx.beginPath();
      ctx.moveTo(i * 92, -12); ctx.lineTo(i * 76, -218 + Math.abs(i) * 26); ctx.stroke();
    }
    // boarding ramps clawing onto our deck
    for (const s of [-1, 0, 1]){
      ctx.save(); ctx.translate(s * 250, -6); ctx.rotate(s * 0.06);
      plate(0, 20, 120, 54, 6, '#3A3038');
      ctx.strokeStyle = C(PAL.iron); ctx.lineWidth = 6;
      for (let i = -1; i <= 1; i++){
        ctx.beginPath(); ctx.moveTo(-52, 20 + i * 16); ctx.lineTo(52, 20 + i * 16); ctx.stroke();
      }
      ctx.restore();
    }
    // furnace maw
    ctx.beginPath();
    ctx.moveTo(-120, -80); ctx.lineTo(120, -80);
    ctx.lineTo(90, -196); ctx.lineTo(-90, -196); ctx.closePath();
    fillStroke(C('#4A1C08'), ink(), 8);
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    drawGlow(0, -140, 210, PAL.fire, 0.75); ctx.restore();
    ctx.fillStyle = PAL.fire;
    ctx.beginPath();
    ctx.moveTo(-104, -90); ctx.lineTo(104, -90);
    ctx.lineTo(80, -186); ctx.lineTo(-80, -186); ctx.closePath(); ctx.fill();
    ctx.strokeStyle = C(PAL.ink); ctx.lineWidth = 10;
    for (let i = 0; i < 3; i++){
      ctx.beginPath(); ctx.moveTo(-100 + i * 4, -110 - i * 30);
      ctx.lineTo(100 - i * 4, -110 - i * 30); ctx.stroke();
    }
    // gantries + lamps
    for (const s of [-1, 1]){
      ctx.save(); ctx.translate(s * 300, -130);
      plate(0, 0, 60, 90, 10, '#3A3038');
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      drawGlow(0, -20, 60, PAL.danger, 0.7); ctx.restore();
      circ(0, -20, 13); fillStroke(PAL.danger, ink(), 6);
      ctx.restore();
    }
    c2.restore();
    applyTwoSourceLight(c2, w, h);
  });
}
function drawHulk(){
  const H = S.hulk;
  if (!H || H.dead) return;
  const p = CAM.project(H.x, H.y, 0);
  const img = hulkSprite();
  const hpx = 560 * p.k, wpx = hpx * (img.width / img.height);
  ctx.save();
  if (H.flash > 0){
    ctx.drawImage(img, p.x - wpx/2, p.y - hpx * 0.96, wpx, hpx);
    ctx.globalCompositeOperation = 'lighter';
    ctx.globalAlpha = clamp(H.flash / 0.1, 0, 1) * 0.5;
    ctx.drawImage(tintVersion(img, '#FFD9A0'), p.x - wpx/2, p.y - hpx * 0.96, wpx, hpx);
  } else {
    ctx.drawImage(img, p.x - wpx/2, p.y - hpx * 0.96, wpx, hpx);
  }
  ctx.restore();
  // sealed vs open plating — the whole push/hold read depends on this
  if (H.vulnerable){
    const q = CAM.project(H.x, H.y, 260);
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    drawGlow(q.x, q.y, 150 * q.k, PAL.fireCore, 0.30 + Math.sin(S.rt * 6) * 0.12);
    ctx.restore();
  }
  if (rnd() < 0.3) pSmoke(H.x + rnd(-200, 200), H.y + 40, 1, 'rgba(40,36,48,0.5)', 60);
}

/* --- lane status: the minimap equivalent ---------------------------------- */
function drawLaneStatus(){
  if (!PRESET.lanes) return;
  const HS = hudScale();
  const w = 210 * HS, rowH = 40 * HS;
  const x = View.w - w - 18 * HS;
  const y = (S.showFps ? 96 : 22) * HS;
  brassPanel(x, y, w, 26 * HS + LANE_N * rowH, 9 * HS, 0.92);
  setFont(Math.round(11 * HS), 800, true);
  textOut('LANES', x + w / 2, y + 14 * HS, PAL.brass);
  const here = laneOf(S.player.x);
  for (let i = 0; i < LANE_N; i++){
    const t = laneThreat(i);
    const ry = y + 26 * HS + i * rowH;
    // you are here
    if (S.player.y < BASE_Y && here === i){
      ctx.fillStyle = hexToRgba(PAL.teal, 0.12);
      rr(x + 6 * HS, ry, w - 12 * HS, rowH - 4 * HS, 5); ctx.fill();
    }
    setFont(Math.round(10.5 * HS), 800, true);
    textOut(LANES[i].name, x + 14 * HS, ry + 12 * HS,
            here === i ? PAL.teal : '#9C93A8', null, 0, 'left');
    // how far they have pushed toward the Boiler
    const bx = x + 14 * HS, bw = w - 28 * HS, by = ry + 24 * HS, bh = 6 * HS;
    ctx.fillStyle = '#0B0910'; rr(bx, by, bw, bh, 3); ctx.fill();
    if (t.turret){
      ctx.fillStyle = hexToRgba(PAL.teal, 0.55);
      rr(bx, by, bw * clamp(t.turretFrac, 0, 1) * 0.32, bh, 3); ctx.fill();
    }
    if (t.count){
      const px = bx + bw * clamp(t.prog, 0, 1);
      ctx.fillStyle = t.prog > 0.7 ? PAL.danger : PAL.dangerIn;
      circ(px, by + bh / 2, 4.5 * HS); ctx.fill();
      setFont(Math.round(10 * HS), 800, true);
      textOut(t.count + '', x + w - 14 * HS, ry + 12 * HS,
              t.prog > 0.7 ? PAL.danger : '#9C93A8', null, 0, 'right');
    }
    if (!t.turret){
      setFont(Math.round(9 * HS), 800, true);
      textOut('CANNON DOWN', x + w - 14 * HS, ry + 33 * HS, PAL.danger, null, 0, 'right');
    }
  }
}

// hulk health, when it is the thing you are supposed to be breaking
function drawHulkBar(){
  if (!PRESET.lanes || !S.hulk || S.hulk.dead || !S.hulk.vulnerable) return;
  const HS = hudScale();
  const w = Math.min(View.w * 0.5, 620 * HS), h = 18 * HS;
  const x = (View.w - w) / 2, y = 132 * HS;
  rr(x - 4, y - 4, w + 8, h + 8, 6);
  ctx.fillStyle = 'rgba(13,11,18,0.9)'; ctx.fill();
  ctx.strokeStyle = PAL.ink; ctx.lineWidth = 4; ctx.stroke();
  const g = ctx.createLinearGradient(x, y, x, y + h);
  g.addColorStop(0, PAL.fireCore); g.addColorStop(1, PAL.fire);
  rr(x, y, w * clamp(S.hulk.hp / S.hulk.maxHp, 0, 1), h, 4);
  ctx.fillStyle = g; ctx.fill();
  ctx.strokeStyle = PAL.brass; ctx.lineWidth = 2; rr(x, y, w, h, 4); ctx.stroke();
  setFont(Math.round(12 * HS), 800, true);
  textOut('BOARDING HULK — PLATING OPEN', View.w / 2, y - 12 * HS, PAL.fireCore, PAL.ink, 4);
}
