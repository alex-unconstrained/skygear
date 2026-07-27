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
let BASE_Y = 0, LANE_TOP = 0, CROSS_Y0 = 0, CROSS_Y1 = 0, FWD_Y0 = 0, FWD_Y1 = 0;
let AFT_Y0 = 0, AFT_Y1 = 0;

/* v11 — "I wish it was more open."

   The lane skeleton is not the problem and is not being touched: three lanes,
   lane-locked boarders, cannons gating each one. What was cramped is the
   player's half of it. The cargo runs were 120 units thick with two gaps in
   2320 units of deck, so a captain who wanted to rotate had one decision point
   every 40 metres and spent the rest of the fight in a corridor.

   Two numbers move. The runs go from 120 thick to 96, which widens every lane
   by 24 either side, and a third passage opens aft. Boarders and crew are still
   lane-clamped, so this is the player's mobility budget and nobody else's. */
const WALL_HALF = 48, WALL_HALF_V10 = 60;

function initLanes(){
  if (!PRESET.lanes) return;
  const D = TUNING.deck;
  const left = D.cx - D.w / 2, right = D.cx + D.w / 2;
  const top = D.cy - D.h / 2, bot = D.cy + D.h / 2;
  LANE_TOP = top + 150;                 // boarders enter here
  BASE_Y   = bot - 430;                 // rear of the deck is open across lanes
  CROSS_Y0 = top + D.h * 0.44;          // mid-deck rotation passage
  CROSS_Y1 = CROSS_Y0 + 210;
  // A second passage well forward. With only the mid-deck one, a captain who
  // committed to the bow of a lane had to walk the length of the deck to answer
  // a push two lanes over — the front line was three separate fights that never
  // talked to each other. Enemies and crew are still lane-clamped, so this is
  // the player's rotation, not a leak in the lane structure.
  FWD_Y0 = LANE_TOP + 200;
  FWD_Y1 = FWD_Y0 + (V11 ? 230 : 190);
  if (V11){ CROSS_Y1 = CROSS_Y0 + 250; }
  // v11's third passage, between the cross-passage and the open base. It is the
  // one that matters when a lane collapses late: from amidships you can now
  // answer a stern-side break without walking the whole deck.
  AFT_Y0 = CROSS_Y1 + 230;
  AFT_Y1 = AFT_Y0 + 210;

  const half = V11 ? WALL_HALF : WALL_HALF_V10;
  const laneW = D.w / LANE_N;
  LANES.length = 0;
  for (let i = 0; i < LANE_N; i++){
    LANES.push({
      id: i,
      cx: left + laneW * (i + 0.5),
      halfW: laneW * 0.5 - (half + 6),   // walls eat the rest
      name: ['PORT', 'CENTRE', 'STARBOARD'][i],
    });
  }
  LANE_WALLS.length = 0;
  for (let i = 1; i < LANE_N; i++){
    const wx = left + laneW * i;
    // split each wall so a cross-passage opens amidships
    // Runs start at the boarding line, not the deck's far edge: modules placed
    // out there hung over the bow with no deck behind them. It also opens the
    // bow strip as a third crossing, which is the player's alone — enemies and
    // crew are lane-clamped either way.
    LANE_WALLS.push({ x0: wx - half, x1: wx + half, y0: LANE_TOP + 10, y1: FWD_Y0 });
    LANE_WALLS.push({ x0: wx - half, x1: wx + half, y0: FWD_Y1,   y1: CROSS_Y0 });
    if (V11 && AFT_Y1 < BASE_Y - 40){
      LANE_WALLS.push({ x0: wx - half, x1: wx + half, y0: CROSS_Y1, y1: AFT_Y0 });
      LANE_WALLS.push({ x0: wx - half, x1: wx + half, y0: AFT_Y1,   y1: BASE_Y });
    } else {
      LANE_WALLS.push({ x0: wx - half, x1: wx + half, y0: CROSS_Y1, y1: BASE_Y });
    }
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
/* Tuned down hard after the first v5 pass: the allies were doing the work.
   Crew were arriving 9-at-a-time every 7.5s (~36 alive across a wave) at 52 HP
   and 9 damage, and three cannons added ~68 dps between them. The lanes held
   themselves and there was nothing to decide. */
const LANE_TUNING = {
  turret: { hp: 480, range: 400, dmg: 15, cd: 1.45, r: 34 },   // ~10 dps each
  crew:   { hp: 34, dmg: 5, siege: 22, speed: 118, r: 15, reach: 52,
            windup: 0.40, recover: 0.5, every: 14, pushEvery: 9, perWave: 2 },
            // 6 per 14s. `siege` is what they do to the hulk: minions are
            // supposed to break a nexus, and on the first push wave they walked
            // to the bow and stood there while the player did all of it.
  hulk:   { hp: 1500, r: 190 },                                 // was 3200 and unkillable
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
      SFX.cannonFire({ x: t.x, y: t.y });
      pSparks(t.x + Math.cos(t.ang) * 30, t.y + Math.sin(t.ang) * 30, 5, PAL.teal, 200, t.ang, 0.4);
    }
  }
}
function damageTurret(t, dmg){
  if (t.dead) return;
  t.hp -= dmg;
  SFX.turretHurt({ x: t.x, y: t.y });
  t.flash = 0.12;
  if (t.hp <= 0){
    t.hp = 0; t.dead = true;
    SFX.turretDown({ x: t.x, y: t.y });
    Voice.say('vo_cannon_down', 2, { x: t.x, y: t.y });
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
        x: L.cx + rnd(-70, 70), y: BASE_Y + 50 + i * 26,
        vx: 0, vy: 0, hp: C.hp, maxHp: C.hp, r: C.r,
        facing: -Math.PI/2, state: 'move', st: 0, anim: rnd(TAU),
        flash: 0, dead: false, atkAng: 0, target: null,
      });
    }
  }
  SFX.crewMuster();
  Voice.say('vo_crew_muster', 0);
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
    // with the lane clear and their plating open, go break the hulk
    const H = S.hulk;
    const siege = !hasTgt && H && !H.dead && H.vulnerable;
    let gx, gy;
    if (hasTgt){ gx = tgt.x; gy = tgt.y; }
    else if (siege){ gx = H.x + (LANES[c.lane].cx - H.x) * 0.30; gy = H.y; }
    else { gx = LANES[c.lane].cx; gy = LANE_TOP + 60; }   // else push up the lane

    if (c.state === 'move'){
      const d = dist(c.x, c.y, gx, gy);
      const a = Math.atan2(gy - c.y, gx - c.x);
      c.facing = angNorm(c.facing + clamp(angDiff(c.facing, a), -8*dt, 8*dt));
      const reach = siege ? C.reach + H.r * 0.85 : C.reach;
      if ((!hasTgt && !siege) || d > reach){
        c.vx = lerp(c.vx, Math.cos(a) * C.speed, 1 - Math.pow(0.004, dt));
        c.vy = lerp(c.vy, Math.sin(a) * C.speed, 1 - Math.pow(0.004, dt));
      } else {
        c.vx *= Math.pow(0.02, dt); c.vy *= Math.pow(0.02, dt);
        c.state = 'windup'; c.st = C.windup; c.atkAng = a;
        c.target = tgt; c.siegeing = siege && !hasTgt;
      }
    } else if (c.state === 'windup'){
      c.st -= dt;
      c.vx *= Math.pow(0.05, dt); c.vy *= Math.pow(0.05, dt);
      if (c.st <= 0){
        if (c.siegeing){
          const HH = S.hulk;
          if (HH && !HH.dead && HH.vulnerable &&
              dist(c.x, c.y, HH.x, HH.y) < C.reach + HH.r * 1.1){
            damageHulk(C.siege);
            pSparks(c.x, c.y - 20, 3, PAL.fireCore, 150, -Math.PI/2, 0.6);
          }
        } else {
          const e = c.target;
          if (e && !e.dead && dist(c.x, c.y, e.x, e.y) < C.reach + e.r){
            hitEnemy(e, C.dmg, { ang: c.atkAng, knock: 60, noCrit: true, silent: true });
            SFX.crewAttack({ x: c.x, y: c.y });
          }
        }
        c.state = 'recover'; c.st = C.recover;
      }
    } else {
      c.st -= dt;
      c.vx *= Math.pow(0.3, dt); c.vy *= Math.pow(0.3, dt);
      if (c.st <= 0) c.state = 'move';
    }

    c.x += c.vx * dt; c.y += c.vy * dt;
    const p = clampToDeck(c.x, c.y, c.r + 4); c.x = p.x; c.y = p.y;
    if (!siege) clampToLane(c, c.lane, c.r);
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
    SFX.crewDown({ x: c.x, y: c.y });
    if (chance(0.25)) Voice.say('vo_crew_down', 0, { x: c.x, y: c.y });
    pGibs(c.x, c.y, 8, '#7A6E5A', PAL.iron);
    pSparks(c.x, c.y, 5, PAL.bone, 160);
  }
}

/* --- the enemy hulk (their nexus) ------------------------------------------ */
function spawnHulk(scale){
  if (!PRESET.lanes){ S.hulk = null; return; }
  const D = TUNING.deck, H = LANE_TUNING.hulk;
  const hp = Math.round(H.hp * (scale || 1));
  S.hulk = { x: D.cx, y: D.cy - D.h/2 - 130, r: H.r,
             hp: hp, maxHp: hp, flash: 0, vulnerable: false, dead: false };
}
function damageHulk(dmg){
  const H = S.hulk;
  if (!H || H.dead) return 0;
  if (!H.vulnerable) return 0;                 // plating sealed on hold waves
  H.hp -= dmg; H.flash = 0.1;
  SFX.hulkHit({ x: H.x, y: H.y });
  S.stats.damage += dmg;
  if (H.hp <= 0){
    H.hp = 0; H.dead = true;
    addTrauma(1); S.flashWhite = 0.9; SFX.hulkBreak();
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
/* Everything the lane readout needs, measured in one pass.

   `prog` — the DEEPEST boarder, not the average and not the count. How far in
   the worst one has got is the number that decides where you go next; a lane
   with nine at the rail is safer than a lane with one at the Boiler.
   `heavy`  — is any of them an Armoured or the boss, which changes what you
   need to bring rather than how fast you need to get there.
   `crew`   — your own side holding it. A lane with crew in it is one you can
   leave for a few seconds and one you cannot is not. */
function laneThreat(i){
  let n = 0, nearest = -Infinity, heavy = false, crew = 0;
  for (const e of S.enemies){
    if (e.dead || e.lane !== i) continue;
    n++;
    if (e.type === 'ARMORED' || e.type === 'BOSS') heavy = true;
    if (e.y > nearest) nearest = e.y;
  }
  for (const c of S.crew) if (!c.dead && laneOf(c.x) === i && c.y < BASE_Y) crew++;
  const t = turretInLane(i);
  // 0..1, how far the lane has been pushed toward the Boiler
  const prog = nearest === -Infinity ? 0
    : clamp((nearest - LANE_TOP) / Math.max(1, S.boiler.y - LANE_TOP), 0, 1);
  return { count: n, prog, heavy, crew,
           turret: t, turretFrac: t ? t.hp / t.maxHp : 0,
           // Critical is about depth, not headcount: past the cannon line and
           // closing on the objective.
           critical: prog > 0.72 || (!t && prog > 0.45) };
}

/* Where the crossings are, as fractions down the same 0..1 axis the lane bar
   uses, so the readout can mark them in the same space as the threat pip. */
function crossingGaps(){
  const g = [[FWD_Y0, FWD_Y1], [CROSS_Y0, CROSS_Y1]];
  if (V11 && AFT_Y1 < BASE_Y - 40) g.push([AFT_Y0, AFT_Y1]);
  return g;
}
function crossingMarks(){
  const span = Math.max(1, S.boiler.y - LANE_TOP);
  return crossingGaps().map(g => ((g[0] + g[1]) / 2 - LANE_TOP) / span);
}

function updateLanes(dt){
  if (!PRESET.lanes) return;
  updateTurrets(dt);
  updateCrew(dt);
  if (S.hulk && S.hulk.flash > 0) S.hulk.flash -= dt;
  // crew reinforcements arrive on a drumbeat, like minion waves. On a push the
  // drumbeat quickens — they have the length of the deck to walk before they
  // reach the hulk, and at the normal cadence the captain breaks it alone.
  const pushing = S.hulk && !S.hulk.dead && S.hulk.vulnerable;
  S.crewT -= dt;
  if (S.crewT <= 0){
    S.crewT = pushing ? LANE_TUNING.crew.pushEvery : LANE_TUNING.crew.every;
    spawnCrewWave();
  }
}
