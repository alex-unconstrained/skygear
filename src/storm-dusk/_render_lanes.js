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
// Painted cargo runs: the wall module is tiled as billboards down the run,
// far to near, so the painter's sort and the projection do the work. The module
// is authored 120 world units wide and 150 deep — the engine steps by MODULE_D
// and draws each at MODULE_H tall, alternating mirror so a single module does
// not read as a repeating stamp. Falls back to the code-drawn box below.
const WALL_MODULE_W = 120, WALL_MODULE_D = 100, WALL_MODULE_H = 125;
function drawLaneWallsArt(art){
  for (const w of LANE_WALLS){
    const cx = (w.x0 + w.x1) / 2;
    const n = Math.max(1, Math.round((w.y1 - w.y0) / WALL_MODULE_D));
    for (let i = 0; i < n; i++){
      const y = lerp(w.y0 + WALL_MODULE_D * 0.5, w.y1 - WALL_MODULE_D * 0.5,
                     n === 1 ? 0.5 : i / (n - 1));
      entityShadow(cx, y, 62, 0.5);     // without this the run floats off the deck
      const r = drawBillboard(art, cx, y, WALL_MODULE_H, { mirror: (i & 1) === 1 });
      addOccluder(r.p.x, r.p.y, r.wpx * 0.46, r.hpx * 0.52, y);
    }
  }
}

function drawLaneWalls(){
  if (!PRESET.lanes) return;
  const art = Assets.get('prop_cargo_wall');
  if (art){ drawLaneWallsArt(art); return; }
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
  const art = Assets.get(dead ? 'prop_cannon_dead' : 'prop_cannon');
  if (art) return art;
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
function crewSprite(view, attacking){
  const art = Assets.get(attacking ? 'CREW_front_attack' : 'CREW_' + view + '_idle');
  if (art) return art;
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
  const swinging = c.state === 'windup' || c.state === 'recover';
  drawBillboard(crewSprite(front ? 'front' : 'back', swinging && front), c.x, c.y, 96,
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
  const H = S.hulk;
  const art = Assets.get(H && H.dead ? 'prop_hulk_wreck'
                       : H && H.vulnerable ? 'prop_hulk_open' : 'prop_hulk_sealed');
  if (art) return art;
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

/* --- lane status: the minimap equivalent ----------------------------------
   Three lanes, and the decision the player makes over and over is which one to
   be in. The v9 readout answered it with a headcount and a coloured dot, which
   is the wrong question twice: a lane with nine boarders at the rail is safer
   than a lane with one at the Boiler, and a red dot is invisible to about one
   man in twelve.

   So: depth is a position on the bar, count is a number, heavy boarders get a
   filled marker rather than a darker one, your crew get their own tick, and
   every colour is carried by a shape as well. Nothing here is colour alone.
--------------------------------------------------------------------------- */
function drawLaneStatus(){
  if (!PRESET.lanes) return;
  const HS = hudScale();
  const w = 244 * HS, rowH = 46 * HS;
  const x = View.w - w - 18 * HS;
  const y = (S.showFps ? 96 : 22) * HS;
  brassPanel(x, y, w, 30 * HS + LANE_N * rowH, 9 * HS, 0.92);
  setFont(Math.round(11 * HS), 800, true);
  textOut('LANES', x + w / 2, y + 15 * HS, PAL.brass);
  // Which end of the bar is which. Without this the bar is an abstraction.
  setFont(Math.round(8.5 * HS), 700, false);
  textOut('BOW', x + 16 * HS, y + 15 * HS, '#5A5366', null, 0, 'left');
  textOut('BOILER', x + w - 16 * HS, y + 15 * HS, '#5A5366', null, 0, 'right');

  const here = laneOf(S.player.x);
  const marks = crossingMarks();
  for (let i = 0; i < LANE_N; i++){
    const t = laneThreat(i);
    const ry = y + 30 * HS + i * rowH;
    // you are here — a bracket as well as a wash, so it survives greyscale
    if (S.player.y < BASE_Y && here === i){
      ctx.fillStyle = hexToRgba(PAL.teal, 0.12);
      rr(x + 6 * HS, ry, w - 12 * HS, rowH - 4 * HS, 5); ctx.fill();
      ctx.fillStyle = PAL.teal;
      rr(x + 6 * HS, ry + 4 * HS, 3 * HS, rowH - 12 * HS, 1.5 * HS); ctx.fill();
    }
    setFont(Math.round(10.5 * HS), 800, true);
    textOut(LANES[i].name, x + 16 * HS, ry + 13 * HS,
            here === i ? PAL.teal : '#9C93A8', null, 0, 'left');

    // headcount, and a filled square when something armoured is in there
    if (t.count){
      setFont(Math.round(10 * HS), 800, true);
      const col = t.critical ? PAL.danger : '#9C93A8';
      textOut(t.count + '', x + w - 16 * HS, ry + 13 * HS, col, null, 0, 'right');
      if (t.heavy){
        ctx.fillStyle = col;
        const hx = x + w - 34 * HS;
        ctx.fillRect(hx - 4 * HS, ry + 9 * HS, 8 * HS, 8 * HS);
      }
    }
    // crew holding the lane, as ticks
    for (let c = 0; c < Math.min(4, t.crew); c++){
      ctx.fillStyle = hexToRgba(PAL.teal, 0.85);
      ctx.fillRect(x + 62 * HS + c * 6 * HS, ry + 9 * HS, 2.5 * HS, 8 * HS);
    }

    const bx = x + 16 * HS, bw = w - 32 * HS, by = ry + 26 * HS, bh = 7 * HS;
    ctx.fillStyle = '#0B0910'; rr(bx, by, bw, bh, 3); ctx.fill();
    // the crossings, as notches in the track — the same two gaps that are
    // painted on the deck, in the same relative place
    for (const m of marks){
      ctx.fillStyle = 'rgba(143,166,201,0.5)';
      ctx.fillRect(bx + bw * m - 1 * HS, by - 3 * HS, 2 * HS, bh + 6 * HS);
    }
    // the cannon, as a segment of the track it actually gates
    if (t.turret){
      ctx.fillStyle = hexToRgba(t.turretFrac > 0.4 ? PAL.teal : PAL.dangerIn, 0.6);
      rr(bx, by, bw * clamp(t.turretFrac, 0, 1) * 0.32, bh, 3); ctx.fill();
    } else {
      // A gap in the track, plus the words. A lane with no cannon is the single
      // most important fact on this panel and it used to be red text alone.
      ctx.strokeStyle = PAL.danger; ctx.lineWidth = 1.6 * HS;
      ctx.setLineDash([3 * HS, 3 * HS]);
      ctx.beginPath();
      ctx.moveTo(bx, by + bh / 2); ctx.lineTo(bx + bw * 0.32, by + bh / 2);
      ctx.stroke();
      ctx.setLineDash([]);
      setFont(Math.round(8.5 * HS), 800, true);
      textOut('NO CANNON', x + w - 16 * HS, ry + 39 * HS, PAL.danger, null, 0, 'right');
    }
    // the deepest boarder — a triangle pointing at the Boiler, filled when
    // critical, hollow when not
    if (t.count){
      const px = bx + bw * clamp(t.prog, 0, 1);
      const cy = by + bh / 2, s2 = 5.5 * HS;
      ctx.beginPath();
      ctx.moveTo(px + s2, cy);
      ctx.lineTo(px - s2, cy - s2);
      ctx.lineTo(px - s2, cy + s2);
      ctx.closePath();
      // Outlined in ink first. Against the dark track a mid-value orange
      // triangle is nearly the same value as the track itself — checked on a
      // greyscale capture, where the whole readout went flat.
      ctx.strokeStyle = PAL.ink; ctx.lineWidth = 3.4 * HS; ctx.stroke();
      if (t.critical){ ctx.fillStyle = PAL.danger; ctx.fill(); }
      else { ctx.fillStyle = PAL.base; ctx.fill();
             ctx.strokeStyle = PAL.dangerIn; ctx.lineWidth = 2 * HS; ctx.stroke(); }
    }
  }

  // The push, when there is one. It belongs on this panel because it is the
  // reason to leave a lane you would otherwise hold.
  if (S.hulk && !S.hulk.dead && S.hulk.vulnerable){
    const py = y + 30 * HS + LANE_N * rowH - 2 * HS;
    setFont(Math.round(9.5 * HS), 800, true);
    textOut('PUSH — HULK OPEN AT THE BOW', x + w / 2, py + 6 * HS,
            PAL.fireCore, PAL.ink, 3);
  }
}

/* One alert, and only when a lane crosses into critical. A HUD that shouts
   every time a number changes is a HUD nobody reads; this fires on the edge,
   not on the state, and holds its tongue for a while afterwards. */
const LANE_ALERT = { lane: -1, t: 0, cool: 0, was: [false, false, false] };
function updateLaneAlerts(rt){
  if (!PRESET.lanes || S.mode !== 'play') return;
  LANE_ALERT.t = Math.max(0, LANE_ALERT.t - rt);
  LANE_ALERT.cool = Math.max(0, LANE_ALERT.cool - rt);
  for (let i = 0; i < LANE_N; i++){
    const crit = laneThreat(i).critical;
    if (crit && !LANE_ALERT.was[i] && LANE_ALERT.cool <= 0){
      LANE_ALERT.lane = i; LANE_ALERT.t = 2.4; LANE_ALERT.cool = 7;
      SFX.laneCritical();
    }
    LANE_ALERT.was[i] = crit;
  }
}
function drawLaneAlert(){
  if (LANE_ALERT.t <= 0 || LANE_ALERT.lane < 0) return;
  const HS = hudScale();
  const a = Math.min(1, LANE_ALERT.t / 0.4) * Math.min(1, (2.4 - LANE_ALERT.t) / 0.18 + 0.2);
  ctx.save();
  ctx.globalAlpha = clamp(a, 0, 1);
  setFont(Math.round(20 * HS), 900, true);
  const name = LANES[LANE_ALERT.lane].name;
  textOut(name + '  LANE  BREAKING', View.w / 2, View.h * 0.30, PAL.danger, PAL.ink, 6);
  // an arrow toward the lane, so the words are not the only carrier
  const dir = LANE_ALERT.lane === 0 ? -1 : LANE_ALERT.lane === LANE_N - 1 ? 1 : 0;
  if (dir){
    const ax = View.w / 2 + dir * (ctx.measureText(name + '  LANE  BREAKING').width / 2 + 26 * HS);
    ctx.fillStyle = PAL.danger;
    ctx.beginPath();
    ctx.moveTo(ax + dir * 10 * HS, View.h * 0.30);
    ctx.lineTo(ax - dir * 6 * HS, View.h * 0.30 - 9 * HS);
    ctx.lineTo(ax - dir * 6 * HS, View.h * 0.30 + 9 * HS);
    ctx.closePath(); ctx.fill();
  }
  ctx.restore();
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
