/* ============================================================================
   LANES — the MOBA restructure (v4)

   Inert unless PRESET.lanes is true, so v2/v3 are untouched by any of it.

   Topology, straight out of League:
     · the enemy boarding hulk is grappled to the BOW and spawns down 3 lanes
     · cargo walls hard-separate the lanes for most of the deck
     · one deck cannon per lane gates it — boarders must break it to pass
     · your crew spawn at the base and push UP their lane
     · the Boiler sits at the STERN, behind everything, and is what you lose by
     · the base (the rear of the deck) is open across all three lanes, and one
       mid-deck cross-passage lets you rotate. Boarders and crew never use them:
       they are lane-locked, so committing to a lane means something.
============================================================================ */
const LANE_N = 3;
const LANES = [];
const LANE_WALLS = [];       // {x0,x1,y0,y1} solid cargo runs between lanes
let BASE_Y = 0, LANE_TOP = 0, CROSS_Y0 = 0, CROSS_Y1 = 0;

function initLanes(){
  if (!PRESET.lanes) return;
  const D = TUNING.deck;
  const left = D.cx - D.w / 2, right = D.cx + D.w / 2;
  const top = D.cy - D.h / 2, bot = D.cy + D.h / 2;
  LANE_TOP = top + 150;                 // boarders enter here
  BASE_Y   = bot - 430;                 // rear of the deck is open across lanes
  CROSS_Y0 = top + D.h * 0.44;          // mid-deck rotation passage
  CROSS_Y1 = CROSS_Y0 + 210;

  const laneW = D.w / LANE_N;
  LANES.length = 0;
  for (let i = 0; i < LANE_N; i++){
    LANES.push({
      id: i,
      cx: left + laneW * (i + 0.5),
      halfW: laneW * 0.5 - 66,          // walls eat the rest
      name: ['PORT', 'CENTRE', 'STARBOARD'][i],
    });
  }
  LANE_WALLS.length = 0;
  for (let i = 1; i < LANE_N; i++){
    const wx = left + laneW * i;
    // split each wall so a cross-passage opens amidships
    LANE_WALLS.push({ x0: wx - 60, x1: wx + 60, y0: top + 40, y1: CROSS_Y0 });
    LANE_WALLS.push({ x0: wx - 60, x1: wx + 60, y0: CROSS_Y1, y1: BASE_Y });
  }
}

function laneOf(x){
  let best = 0, bd = Infinity;
  for (const L of LANES){ const d = Math.abs(x - L.cx); if (d < bd){ bd = d; best = L.id; } }
  return best;
}
// keep a lane-locked mover inside its own lane while it is north of the base
function clampToLane(o, lane, r){
  if (!PRESET.lanes || o.y > BASE_Y) return;
  const L = LANES[lane];
  if (!L) return;
  const lo = L.cx - L.halfW + r, hi = L.cx + L.halfW - r;
  if (o.x < lo){ o.x = lo; if (o.vx) o.vx *= 0.4; }
  if (o.x > hi){ o.x = hi; if (o.vx) o.vx *= 0.4; }
}
// the captain is not lane-locked, but the cargo walls are solid to everyone
function pushOutWalls(o, r){
  if (!PRESET.lanes) return;
  for (const w of LANE_WALLS){
    if (o.x < w.x0 - r || o.x > w.x1 + r || o.y < w.y0 - r || o.y > w.y1 + r) continue;
    // shortest push out of the box
    const dl = (o.x - (w.x0 - r)), dr = ((w.x1 + r) - o.x);
    const du = (o.y - (w.y0 - r)), dd = ((w.y1 + r) - o.y);
    const m = Math.min(dl, dr, du, dd);
    if (m === dl){ o.x = w.x0 - r; if (o.vx) o.vx = 0; }
    else if (m === dr){ o.x = w.x1 + r; if (o.vx) o.vx = 0; }
    else if (m === du){ o.y = w.y0 - r; if (o.vy) o.vy = 0; }
    else { o.y = w.y1 + r; if (o.vy) o.vy = 0; }
  }
}

/* --- tuning ---------------------------------------------------------------- */
const LANE_TUNING = {
  turret: { hp: 620, range: 430, dmg: 26, cd: 1.15, r: 34 },
  crew:   { hp: 52, dmg: 9, speed: 118, r: 15, reach: 52, windup: 0.35, recover: 0.4,
            every: 7.5, perWave: 3 },
  hulk:   { hp: 3200, r: 190 },
};

/* --- turrets --------------------------------------------------------------- */
function spawnTurrets(){
  S.turrets = [];
  if (!PRESET.lanes) return;
  const T = LANE_TUNING.turret;
  for (const L of LANES){
    S.turrets.push({ lane: L.id, x: L.cx, y: BASE_Y - 210, hp: T.hp, maxHp: T.hp,
                     cd: rnd(0, T.cd), r: T.r, ang: -Math.PI/2, flash: 0, dead: false,
                     fireFx: 0 });
  }
}
function updateTurrets(dt){
  if (!PRESET.lanes) return;
  const T = LANE_TUNING.turret;
  for (const t of S.turrets){
    if (t.flash > 0) t.flash -= dt;
    if (t.fireFx > 0) t.fireFx -= dt;
    if (t.dead) continue;
    t.cd -= dt;
    // shoot the boarder nearest the Boiler in this lane
    let best = null, bestY = -Infinity;
    for (const e of S.enemies){
      if (e.dead || e.state === 'climb' || e.lane !== t.lane) continue;
      if (dist2(t.x, t.y, e.x, e.y) > T.range * T.range) continue;
      if (e.y > bestY){ bestY = e.y; best = e; }
    }
    if (!best) continue;
    t.ang = Math.atan2(best.y - t.y, best.x - t.x);
    if (t.cd <= 0){
      t.cd = T.cd;
      t.fireFx = 0.14;
      hitEnemy(best, T.dmg, { ang: t.ang, knock: 90, noCrit: true });
      SFX.enemyShoot();
      pSparks(t.x + Math.cos(t.ang) * 30, t.y + Math.sin(t.ang) * 30, 5, PAL.teal, 200, t.ang, 0.4);
    }
  }
}
function damageTurret(t, dmg){
  if (t.dead) return;
  t.hp -= dmg;
  t.flash = 0.12;
  if (t.hp <= 0){
    t.hp = 0; t.dead = true;
    addTrauma(0.4); SFX.slam();
    pGibs(t.x, t.y, 22, PAL.brass, PAL.iron);
    pSmoke(t.x, t.y, 10, 'rgba(40,36,48,0.65)', 90);
    S.banner = { kind:'lane', text: LANES[t.lane].name + ' CANNON DOWN', t: 0, life: 2.4 };
  }
}
function turretInLane(lane){
  for (const t of S.turrets) if (t.lane === lane && !t.dead) return t;
  return null;
}

/* --- your crew ------------------------------------------------------------- */
function spawnCrewWave(){
  if (!PRESET.lanes) return;
  const C = LANE_TUNING.crew;
  for (const L of LANES){
    for (let i = 0; i < C.perWave; i++){
      S.crew.push({
        lane: L.id,
        x: L.cx + rnd(-70, 70), y: BASE_Y + 120 + i * 26,
        vx: 0, vy: 0, hp: C.hp, maxHp: C.hp, r: C.r,
        facing: -Math.PI/2, state: 'move', st: 0, anim: rnd(TAU),
        flash: 0, dead: false, atkAng: 0, target: null,
      });
    }
  }
  SFX.ready();
}
function updateCrew(dt){
  if (!PRESET.lanes) return;
  const C = LANE_TUNING.crew;
  for (const c of S.crew){
    if (c.flash > 0) c.flash -= dt;
    if (c.dead) continue;
    c.anim += dt;

    // nearest boarder in my lane, ahead of me
    let tgt = null, bd = Infinity;
    for (const e of S.enemies){
      if (e.dead || e.state === 'climb' || e.lane !== c.lane) continue;
      const d = dist2(c.x, c.y, e.x, e.y);
      if (d < bd){ bd = d; tgt = e; }
    }
    const hasTgt = tgt && bd < 320 * 320;
    let gx, gy;
    if (hasTgt){ gx = tgt.x; gy = tgt.y; }
    else { gx = LANES[c.lane].cx; gy = LANE_TOP + 60; }   // else push up the lane

    if (c.state === 'move'){
      const d = dist(c.x, c.y, gx, gy);
      const a = Math.atan2(gy - c.y, gx - c.x);
      c.facing = angNorm(c.facing + clamp(angDiff(c.facing, a), -8*dt, 8*dt));
      if (!hasTgt || d > C.reach){
        c.vx = lerp(c.vx, Math.cos(a) * C.speed, 1 - Math.pow(0.004, dt));
        c.vy = lerp(c.vy, Math.sin(a) * C.speed, 1 - Math.pow(0.004, dt));
      } else {
        c.vx *= Math.pow(0.02, dt); c.vy *= Math.pow(0.02, dt);
        c.state = 'windup'; c.st = C.windup; c.atkAng = a; c.target = tgt;
      }
    } else if (c.state === 'windup'){
      c.st -= dt;
      c.vx *= Math.pow(0.05, dt); c.vy *= Math.pow(0.05, dt);
      if (c.st <= 0){
        const e = c.target;
        if (e && !e.dead && dist(c.x, c.y, e.x, e.y) < C.reach + e.r)
          hitEnemy(e, C.dmg, { ang: c.atkAng, knock: 60, noCrit: true, silent: true });
        c.state = 'recover'; c.st = C.recover;
      }
    } else {
      c.st -= dt;
      c.vx *= Math.pow(0.3, dt); c.vy *= Math.pow(0.3, dt);
      if (c.st <= 0) c.state = 'move';
    }

    c.x += c.vx * dt; c.y += c.vy * dt;
    const p = clampToDeck(c.x, c.y, c.r + 4); c.x = p.x; c.y = p.y;
    clampToLane(c, c.lane, c.r);
    pushOutWalls(c, c.r);
  }
  for (let i = S.crew.length - 1; i >= 0; i--) if (S.crew[i].dead) S.crew.splice(i, 1);
}
function hurtCrew(c, dmg, ang){
  if (c.dead) return;
  c.hp -= dmg;
  c.flash = 0.06;
  if (c.hp <= 0){
    c.dead = true;
    pGibs(c.x, c.y, 8, '#7A6E5A', PAL.iron);
    pSparks(c.x, c.y, 5, PAL.bone, 160);
  }
}

/* --- the enemy hulk (their nexus) ------------------------------------------ */
function spawnHulk(){
  if (!PRESET.lanes){ S.hulk = null; return; }
  const D = TUNING.deck, H = LANE_TUNING.hulk;
  S.hulk = { x: D.cx, y: D.cy - D.h/2 - 130, r: H.r,
             hp: H.hp, maxHp: H.hp, flash: 0, vulnerable: false, dead: false };
}
function damageHulk(dmg){
  const H = S.hulk;
  if (!H || H.dead) return 0;
  if (!H.vulnerable) return 0;                 // plating sealed on hold waves
  H.hp -= dmg; H.flash = 0.1;
  S.stats.damage += dmg;
  if (H.hp <= 0){
    H.hp = 0; H.dead = true;
    addTrauma(1); S.flashWhite = 0.9; SFX.bossRoar();
    for (let i = 0; i < 10; i++)
      fx({ kind:'delayPop', x: H.x + rnd(-190,190), y: H.y + rnd(-70,70),
           life: 0.5, delay: i * 0.12, r: rnd(50,110), col: i%2 ? PAL.fire : PAL.fireCore });
  }
  return dmg;
}

/* --- lane-aware targeting -------------------------------------------------- */
// Boarders walk their lane and hit whatever is in front of them, League-style:
// crew first, then the lane's cannon, then the Boiler.
function laneEnemyTarget(e){
  const P = S.player;
  // the captain, if she is right on top of them
  if (P.hp > 0 && dist2(e.x, e.y, P.x, P.y) < 230 * 230)
    return { x: P.x, y: P.y, r: TUNING.player.radius, kind: 'player' };
  // crew in the way
  let c = null, bd = 220 * 220;
  for (const q of S.crew){
    if (q.dead || q.lane !== e.lane) continue;
    const d = dist2(e.x, e.y, q.x, q.y);
    if (d < bd){ bd = d; c = q; }
  }
  if (c) return { x: c.x, y: c.y, r: c.r, kind: 'crew', ref: c };
  // the lane's cannon gates progress
  const t = turretInLane(e.lane);
  if (t && e.y < t.y + 90) return { x: t.x, y: t.y, r: t.r, kind: 'turret', ref: t };
  return { x: S.boiler.x, y: S.boiler.y, r: S.boiler.r, kind: 'boiler' };
}
// route damage from a boarder's swing to whatever it actually hit
function laneResolveHit(e, tgtKind, ref, dmg, ang){
  if (tgtKind === 'player') hurtPlayer(dmg, ang);
  else if (tgtKind === 'crew') hurtCrew(ref, dmg, ang);
  else if (tgtKind === 'turret') damageTurret(ref, dmg);
  else hurtBoiler(dmg, Math.atan2(e.y - S.boiler.y, e.x - S.boiler.x));
}

/* --- lane status, and the hulk's wave loop --------------------------------- */
function laneThreat(i){
  let n = 0, nearest = -Infinity;
  for (const e of S.enemies){
    if (e.dead || e.lane !== i) continue;
    n++;
    if (e.y > nearest) nearest = e.y;
  }
  const t = turretInLane(i);
  // 0..1, how far the lane has been pushed toward the Boiler
  const prog = nearest === -Infinity ? 0
    : clamp((nearest - LANE_TOP) / Math.max(1, S.boiler.y - LANE_TOP), 0, 1);
  return { count: n, prog, turret: t, turretFrac: t ? t.hp / t.maxHp : 0 };
}

function updateLanes(dt){
  if (!PRESET.lanes) return;
  updateTurrets(dt);
  updateCrew(dt);
  if (S.hulk && S.hulk.flash > 0) S.hulk.flash -= dt;
  // crew reinforcements arrive on a drumbeat, like minion waves
  S.crewT -= dt;
  if (S.crewT <= 0){ S.crewT = LANE_TUNING.crew.every; spawnCrewWave(); }
}
