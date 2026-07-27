#!/usr/bin/env node
/* SKYGEAR headless harness.
 *
 * Every claim in this project that turned out wrong was a claim nobody checked:
 * audio that reported success while producing silence, a wall tiling that left
 * holes, a benchmark aimed at a fixed point while the targets walked away. This
 * runs the real build in a real browser and asserts against the real simulation
 * — window.SKYGEAR is the seam, and it exposes the actual state object, not a
 * summary of it.
 *
 *   node tools/harness.mjs                     # the live build, all checks
 *   node tools/harness.mjs --build v9          # some other build
 *   node tools/harness.mjs --only boot,waves   # a subset while iterating
 *   node tools/harness.mjs --headed            # watch it
 *
 * Exit code is the number of failed checks, so it composes with && in a shell.
 */
import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

const argv = process.argv.slice(2);
const arg = (name, dflt) => {
  const i = argv.indexOf('--' + name);
  return i >= 0 && argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[i + 1] : dflt;
};
const flag = (name) => argv.includes('--' + name);

const BUILD = arg('build', liveBuildName());
const ONLY = (arg('only', '') || '').split(',').filter(Boolean);
const HEADED = flag('headed');
const VERBOSE = flag('verbose');

/* Which build is live is decided in exactly one place — build.py — so read it
   from there rather than keeping a second copy that can disagree. */
function liveBuildName(){
  const src = fs.readFileSync(path.join(ROOT, 'src/storm-dusk/build.py'), 'utf8');
  const m = /^LIVE = '([^']+)'/m.exec(src);
  if (!m) throw new Error('cannot find LIVE in build.py');
  return m[1];
}

/* ---------------------------------------------------------------------------
   a static server over the repo, so the page is same-origin with its assets
--------------------------------------------------------------------------- */
const MIME = { '.html':'text/html', '.js':'text/javascript', '.css':'text/css',
               '.png':'image/png', '.jpg':'image/jpeg', '.webp':'image/webp',
               '.wav':'audio/wav', '.ogg':'audio/ogg', '.m4a':'audio/mp4',
               '.json':'application/json', '.svg':'image/svg+xml' };

function serve(){
  return new Promise((resolve) => {
    const srv = http.createServer((req, res) => {
      const url = decodeURIComponent(req.url.split('?')[0]);
      const p = path.join(ROOT, url === '/' ? 'index.html' : url);
      if (!p.startsWith(ROOT)) { res.writeHead(403).end(); return; }
      fs.readFile(p, (err, buf) => {
        if (err) { res.writeHead(404).end(); return; }
        res.writeHead(200, { 'content-type': MIME[path.extname(p)] || 'application/octet-stream' });
        res.end(buf);
      });
    });
    srv.listen(0, '127.0.0.1', () => resolve({ srv, port: srv.address().port }));
  });
}

/* ---------------------------------------------------------------------------
   check bookkeeping
--------------------------------------------------------------------------- */
const results = [];
function record(group, name, ok, detail){
  results.push({ group, name, ok, detail });
  const mark = ok ? '  ok  ' : ' FAIL ';
  console.log(mark + group + ' · ' + name + (detail && (!ok || VERBOSE) ? '   ' + detail : ''));
}
const wants = (g) => !ONLY.length || ONLY.includes(g);

/* A check that hangs is worse than one that fails: it looks like progress. Each
   group runs under a wall-clock cap and a blown cap is a recorded failure. */
const GROUP_TIMEOUT = Number(arg('group-timeout', 180)) * 1000;
async function group(name, fn){
  if (!wants(name)) return;
  const t0 = Date.now();
  let timer;
  const bell = new Promise((_, rej) => { timer = setTimeout(
    () => rej(new Error('exceeded ' + (GROUP_TIMEOUT / 1000) + 's')), GROUP_TIMEOUT); });
  try { await Promise.race([fn(), bell]); }
  catch (e){ record(name, 'group completed', false, e.message); }
  finally { clearTimeout(timer); }
  if (VERBOSE) console.log('       (' + name + ' took ' + ((Date.now() - t0) / 1000).toFixed(1) + 's)');
}

/* ---------------------------------------------------------------------------
   the checks. Each takes the page and asserts against the live sim.
--------------------------------------------------------------------------- */

/* Installed into the page once, and used by every check that needs a run.

   `startRun` no longer lands in 'play': v10 opens on a draft for the first
   weapon, so a check that starts a run and then steps the simulation is
   stepping a paused game. Resolving the draft here rather than in each check
   means the harness has one idea of what "begin a run" means, and a future
   change to the opening flow breaks one function instead of six. */
const INSTALL = () => {
  window.__take = (i) => {
    const G = window.SKYGEAR, S = G.S;
    if (S.mode !== 'draft' || !S.draft || S.draft.chosen >= 0) return null;
    const c = S.draft.cards[i || 0];
    G.pickCard(i || 0);
    G.closeDraft();
    return c ? c.title : null;
  };
  window.__begin = (pick) => {
    const G = window.SKYGEAR;
    G.startRun();
    window.__take(pick || 0);
    return G.S.mode;
  };
};

async function checkBoot(page, errors){
  record('boot', 'page has a SKYGEAR global',
    await page.evaluate(() => typeof window.SKYGEAR === 'object'));
  const st = await page.evaluate(() => ({
    mode: SKYGEAR.S.mode, shapes: Object.keys(SKYGEAR.SHAPES).length,
    elements: Object.keys(SKYGEAR.ELEMENTS).length, waves: SKYGEAR.WAVES.length,
    cards: SKYGEAR.CARDS.length, build: SKYGEAR.S && window.PRESET ? window.PRESET.build : null,
  }));
  record('boot', 'starts on the title screen', st.mode === 'title', 'mode=' + st.mode);
  record('boot', 'roster loaded', st.shapes >= 6 && st.elements === 4 && st.waves === 12,
    st.shapes + ' shapes, ' + st.elements + ' elements, ' + st.waves + ' waves');
  record('boot', 'no console errors while booting', errors.length === 0,
    errors.slice(0, 3).join(' | '));
}

/* Every draftable shape x element must deal damage, apply its element and
   terminate. A cell that silently does nothing is the failure this catches:
   the code path exists, the cooldown ticks, and no damage is ever dealt. */
async function checkMatrix(page){
  const out = await page.evaluate(async () => {
    const G = window.SKYGEAR, S = G.S;
    const bad = [], zero = [];
    const shapes = Object.keys(G.SHAPES), elements = Object.keys(G.ELEMENTS);
    for (const shape of shapes){
      for (const element of elements){
        window.__begin();
        S.slots[0] = G.newSkill(shape, element);
        S.slots[0].cd = 0;
        // A stationary target well inside every shape's reach. spawnEnemy's
        // second argument is a spawn POINT, not a boolean — passing `true`
        // gives an enemy at NaN and a render loop that throws every frame.
        const at = { x: S.player.x + 60, y: S.player.y - 10, side: 'bow' };
        const e = G.spawnEnemy('SCRAPPER', at);
        if (!e){ bad.push(shape + '/' + element + ': no target'); continue; }
        e.x = at.x; e.y = at.y; e.hp = 1e6; e.maxHp = 1e6;
        e.state = 'move'; e.st = 0; e.climb = 1;   // past the spawn climb, hittable
        S.player.aim = Math.atan2(e.y - S.player.y, e.x - S.player.x);
        const before = e.hp;
        try { G.castSlot(0, { atX: e.x, atY: e.y }); }
        catch (err){ bad.push(shape + '/' + element + ': threw ' + err.message); continue; }
        // let lingering shapes (ray, sentry, field, pulse) run for two seconds
        for (let i = 0; i < 2 / G.DT; i++) G.step(G.DT);
        if (e.hp >= before) zero.push(shape + '/' + element);
        if (S.player.ray) G.endRay();
      }
    }
    return { bad, zero, n: shapes.length * elements.length };
  });
  record('matrix', 'every shape x element executes without throwing',
    out.bad.length === 0, out.bad.slice(0, 4).join(' | '));
  record('matrix', 'every shape x element deals damage',
    out.zero.length === 0, out.zero.length ? out.zero.join(', ') : out.n + ' cells');
}

/* Twelve waves, played out. Asserts each wave starts and clears, that the push
   waves grapple a fresh hulk, and that victory resolves. */
async function checkWaves(page){
  const out = await page.evaluate(async () => {
    const G = window.SKYGEAR, S = G.S;
    window.__begin();
    S.player.hp = S.player.maxHp = 1e9;      // the harness is testing waves, not balance
    S.boiler.hp = S.boiler.maxHp = 1e9;
    const seen = [], hulks = [];
    let lastWave = 0, guard = 0;
    const MAXSTEPS = 60 * 60 * 12 / G.DT;    // twelve minutes of sim, a hard stop
    while (S.mode !== 'victory' && S.mode !== 'gameover' && guard < MAXSTEPS){
      if (S.mode === 'draft'){
        // take the first card; the harness is not testing card choice here
        G.S.draft && G.S.draft.cards.length ? window.SKYGEAR.S : null;
        if (S.draft && S.draft.chosen < 0){
          const c = S.draft.cards[0];
          if (c){ c.apply(S); S.stats.cards.push(c.title); }
          S.draft = null; S.mode = 'play'; S.phase = 'ready'; S.interT = 0.4;
        }
        continue;
      }
      if (S.mode !== 'play') break;
      G.step(G.DT); guard++;
      if (S.wave !== lastWave){
        lastWave = S.wave;
        seen.push(S.wave);
        if (S.hulk) hulks.push({ wave: S.wave, state: S.hulk.state, hp: S.hulk.hp });
      }
      // enemies chew the boiler forever if nothing kills them; the harness is
      // the player, so clear whatever is alive once a wave has fully spawned
      if (S.queue.length === 0 && S.enemies.length){
        for (const e of S.enemies) if (!e.dead) e.hp = -1;
      }
    }
    return { mode: S.mode, seen, hulks, wave: S.wave, steps: guard, max: MAXSTEPS };
  });
  record('waves', 'all twelve waves start',
    out.seen.length >= 12, 'started ' + out.seen.length + ': [' + out.seen.join(',') + ']');
  record('waves', 'the run reaches victory',
    out.mode === 'victory', 'ended in mode=' + out.mode + ' at wave ' + out.wave);
  record('waves', 'the run terminates well inside the step budget',
    out.steps < out.max, out.steps + ' steps');

  /* "90% of completed runs finish with 3-4 skills" is an acceptance criterion
     (V10-PLAN §5) and it is checkable without a tester: the draft decides it,
     not the player's aim. Ten seeds, each played to victory taking whatever the
     draft offers first — if the slots do not fill, the schedule is wrong. */
  const builds = await page.evaluate(() => {
    const G = window.SKYGEAR, S = G.S;
    const out = [];
    for (let r = 0; r < 10; r++){
      window.__begin(r % 3);
      S.player.hp = S.player.maxHp = 1e9;
      S.boiler.hp = S.boiler.maxHp = 1e9;
      let guard = 0;
      while (S.mode !== 'victory' && S.mode !== 'gameover' && guard < 60 * 60 * 12 / G.DT){
        if (S.mode === 'draft'){ window.__take(r % 3); continue; }
        if (S.mode !== 'play') break;
        G.step(G.DT); guard++;
        if (S.queue.length === 0 && S.enemies.length)
          for (const e of S.enemies) if (!e.dead) e.hp = -1;
      }
      let n = 0; const elems = {}, shapes = {};
      for (let i = 0; i < 4; i++) if (S.slots[i]){
        n++; elems[S.slots[i].element] = 1; shapes[S.slots[i].shape] = 1;
      }
      out.push({ won: S.mode === 'victory', n,
                 elems: Object.keys(elems), shapes: Object.keys(shapes) });
    }
    return out;
  });
  const won = builds.filter(b => b.won);
  const good = won.filter(b => b.n >= 3 && b.n <= 4);
  record('waves', 'completed runs finish holding 3 or 4 skills',
    won.length > 0 && good.length / won.length >= 0.9,
    good.length + '/' + won.length + ' runs, slot counts [' +
    won.map(b => b.n).join(',') + ']');

  /* NOT "every build spans two elements". Committing to one colour across
     several shapes is a deliberate, available build — V10-PLAN §1 says so — and
     a check that forbids it would be asserting against the design. What is
     worth asserting is that the matrix is actually being used: across a set of
     runs the draft reaches all four elements and a good spread of shapes.
     Anything less means the offering is narrow, whatever the player picks. */
  const el = new Set(), sh = new Set();
  for (const b of won){ b.elems.forEach(e => el.add(e)); b.shapes.forEach(s => sh.add(s)); }
  record('waves', 'the draft reaches every element and most shapes across runs',
    el.size === 4 && sh.size >= 6,
    el.size + '/4 elements, ' + sh.size + '/8 draftable shapes over ' +
    won.length + ' runs');
}

/* The finale has two beats, and the second one has to actually arrive.

   A phase change is the easiest thing in a game to write and never see: if the
   threshold is wrong, or the turn state never exits, or the player kills it
   through the transition, the encounter silently becomes one long first beat.
   So this drives the Colossus down through half health and asserts the turn
   fires, is untouchable while it lasts, exits, and unlocks the attack that was
   not available before. */
async function checkBoss(page){
  const out = await page.evaluate(() => {
    const G = window.SKYGEAR, S = G.S;
    window.__begin();
    S.player.hp = S.player.maxHp = 1e9;
    S.boiler.hp = S.boiler.maxHp = 1e9;
    const e = G.spawnEnemy('BOSS');
    if (!e) return { err: 'no boss' };
    e.state = 'move'; e.climb = 1; e.st = 0;

    const seen1 = new Set();
    for (let i = 0; i < 30 / G.DT; i++){
      G.step(G.DT);
      if (e.boss.atk) seen1.add(e.boss.atk);
    }
    const beat1 = { beat: e.boss.beat, atks: [...seen1] };

    // Bring it down through half with REAL damage, so the turn fires the way it
    // fires in a game rather than from a poke at the state.
    let turned = false, immune = null, guard = 0;
    while (!turned && guard++ < 20 / G.DT){
      if (e.hp > e.maxHp * 0.5) G.hitEnemy(e, e.maxHp * 0.02, { ang: 0 });
      G.step(G.DT);
      if (e.state === 'turn'){
        turned = true;
        // and it must not be possible to burst through the turn
        const before = e.hp;
        G.hitEnemy(e, e.maxHp * 0.4, { ang: 0 });
        immune = { before, after: e.hp };
      }
    }
    const seen2 = new Set();
    for (let i = 0; i < 40 / G.DT; i++){
      G.step(G.DT);
      if (e.boss.atk) seen2.add(e.boss.atk);
    }
    return { err: null, beat1, beat2: { beat: e.boss.beat, atks: [...seen2] },
             turned, immune, state: e.state, hp: e.hp / e.maxHp };
  });
  if (out.err){ record('boss', 'the Colossus fights', false, out.err); return; }
  record('boss', 'the first beat is position, not reach',
    out.beat1.beat === 0 && out.beat1.atks.length > 0 &&
    out.beat1.atks.indexOf('ray') < 0,
    'beat ' + out.beat1.beat + ', used [' + out.beat1.atks.join(',') + ']');
  record('boss', 'it turns at half health and comes out of it',
    out.turned && out.beat2.beat === 1 && out.state !== 'turn',
    'turned=' + out.turned + ', beat ' + out.beat2.beat + ', state=' + out.state);
  record('boss', 'it cannot be burst through the turn',
    !!out.immune && out.immune.after === out.immune.before,
    out.immune ? (out.immune.before.toFixed(0) + ' -> ' + out.immune.after.toFixed(0))
               : 'never entered the turn');
  record('boss', 'the second beat reaches the whole deck',
    out.beat2.atks.indexOf('ray') >= 0,
    'used [' + out.beat2.atks.join(',') + ']');
}

/* Both loss conditions and a clean restart. */
async function checkEndings(page){
  // Damage must go through the game's own damage entry points. Zeroing `hp`
  // directly never reaches the code that decides a run is over.
  const boiler = await page.evaluate(() => {
    const G = window.SKYGEAR, S = G.S;
    window.__begin();
    for (let i = 0; i < 40; i++) G.step(G.DT);
    G.hurtBoiler(S.boiler.maxHp * 2, 0);
    for (let i = 0; i < 10 && S.mode === 'play'; i++) G.step(G.DT);
    return { mode: S.mode, title: S.endTitle, reason: S.endReason };
  });
  record('endings', 'the Boiler reaching zero ends the run',
    boiler.mode === 'gameover', boiler.title + ' — ' + boiler.reason);

  const player = await page.evaluate(() => {
    const G = window.SKYGEAR, S = G.S;
    window.__begin();
    for (let i = 0; i < 40; i++) G.step(G.DT);
    S.player.iframe = 0; S.player.dashT = 0;
    G.hurtPlayer(S.player.maxHp * 2, 0);
    for (let i = 0; i < 10 && S.mode === 'play'; i++) G.step(G.DT);
    return { mode: S.mode, title: S.endTitle, reason: S.endReason };
  });
  record('endings', 'the captain dying ends the run',
    player.mode === 'gameover', player.title + ' — ' + player.reason);

  const restart = await page.evaluate(() => {
    const G = window.SKYGEAR, S = G.S;
    window.__begin();
    for (let i = 0; i < 600; i++) G.step(G.DT);
    const dirty = { enemies: S.enemies.length, fx: S.fx.length, nums: S.nums.length };
    window.__begin();
    return { dirty, clean: {
      mode: S.mode, wave: S.wave, enemies: S.enemies.length, bolts: S.bolts.length,
      fx: S.fx.length, nums: S.nums.length, fields: S.fields.length,
      kills: S.stats.kills, damage: S.stats.damage, cards: S.stats.cards.length,
      hp: S.player.hp, boiler: S.boiler.hp, t: S.t,
    }};
  });
  const c = restart.clean;
  // One card, not none: the opening weapon is a real draft pick and is recorded
  // as one. Anything above one would be a card surviving from the run before.
  record('endings', 'restart is clean',
    c.mode === 'play' && c.wave === 0 && c.enemies === 0 && c.bolts === 0 &&
    c.fx === 0 && c.nums === 0 && c.kills === 0 && c.damage === 0 &&
    c.cards === 1 && c.t === 0,
    JSON.stringify(c));
}

/* A fixed seed must reproduce a run. Two runs on the same seed, driven by the
   same inputs, must agree on every number the player can see. */
/* Runs on its own page. Reloading the shared one to change ?seed= means every
   later check inherits whatever the reload left behind, and navigating away
   from a page whose frame loop is mid-render is slow enough to look broken. */
async function checkSeed(browser, port){
  const tab = await browser.newPage({ viewport: { width: 800, height: 600 } });
  try {
    const trace = async (seed) => {
      await tab.goto(`http://127.0.0.1:${port}/${BUILD}.html?seed=${seed}&assets=0&audio=0`,
                     { waitUntil: 'domcontentloaded' });
      await tab.waitForFunction(() => !!window.SKYGEAR, null, { timeout: 15000 });
      await tab.evaluate(INSTALL);
      return tab.evaluate(() => {
        const G = window.SKYGEAR, S = G.S;
        if (!G.Rng) return null;
        window.__begin();
        S.player.hp = S.player.maxHp = 1e9;
        S.boiler.hp = S.boiler.maxHp = 1e9;
        // Sample the whole observable state periodically rather than at the end:
        // two runs that diverge and reconverge would compare equal at the end.
        const sig = [];
        for (let i = 0; i < 45 / G.DT; i++){
          if (S.mode !== 'play') break;
          G.step(G.DT);
          if (i % 300 === 0){
            sig.push([S.wave, S.enemies.length, Math.round(S.stats.damage),
                      S.enemies.map(e => e.type + ':' + Math.round(e.x) + ',' + Math.round(e.y)).join('|')].join(';'));
          }
        }
        const r = { seed: G.seedText(G.S.seed), sig: sig.join('\n') };
        G.S.mode = 'title';                 // stop the frame loop drawing a fight
        return r;
      });
    };
    const a = await trace('SEED01');
    if (a === null){ record('seed', 'seeded RNG is present', false, 'no SKYGEAR.Rng'); return; }
    const b = await trace('SEED01');
    const c = await trace('SEED02');
    record('seed', 'the same seed reproduces a run', a.sig === b.sig,
      a.sig === b.sig ? ('seed ' + a.seed + ', ' + a.sig.split('\n').length + ' samples')
                      : 'traces diverged');
    record('seed', '?seed= is what the game reports', a.seed === 'SEED01', 'reported ' + a.seed);
    record('seed', 'a different seed produces a different run', a.sig !== c.sig);
  } finally {
    await tab.close();
  }
}

/* Settings, prompts and the run log survive a reload.

   "Everything persists" is a promise the settings screen makes implicitly, and
   before v10 it was false of the volume keys — they changed the session and the
   game came back loud every time. It is also the promise most likely to break
   silently, because nothing in the game reads a setting back except the setting
   itself. So: change everything, reload, and check.

   The storage is also checked for being absent-safe, because localStorage
   throws rather than returning null in Safari private browsing and on file://,
   and neither is a reason for the game not to run. */
async function checkPersistence(browser, port){
  const tab = await browser.newPage({ viewport: { width: 1366, height: 768 } });
  const errs = [];
  tab.on('pageerror', e => errs.push(e.message));
  const url = `http://127.0.0.1:${port}/${BUILD}.html?assets=0&audio=0&seed=STORE1`;
  try {
    await tab.goto(url, { waitUntil: 'domcontentloaded' });
    await tab.waitForFunction(() => !!window.SKYGEAR, null, { timeout: 15000 });
    await tab.evaluate(INSTALL);
    await tab.evaluate(() => {
      const G = window.SKYGEAR;
      G.Settings.reset();
      G.Settings.set('volMusic', 0.15);
      G.Settings.set('vfx', 0.25);
      G.Settings.set('hudScale', 1.2);
      G.Settings.set('reducedMotion', true);
      G.Settings.set('keys', { dash: 'f', slot3: 'r' });
      G.Settings.markSeen('boarder');
      // finish a run so there is something in the log to come back to
      window.__begin();
      G.hurtBoiler(1e9, 0);
      for (let i = 0; i < 10 && G.S.mode === 'play'; i++) G.step(G.DT);
    });

    await tab.goto(url, { waitUntil: 'domcontentloaded' });
    await tab.waitForFunction(() => !!window.SKYGEAR, null, { timeout: 15000 });
    const back = await tab.evaluate(() => {
      const G = window.SKYGEAR;
      return {
        music: G.Settings.get('volMusic'),
        vfx: G.Settings.get('vfx'),
        hud: G.Settings.get('hudScale'),
        motion: G.Settings.motionReduced(),
        dash: G.Settings.get('keys') && G.Settings.get('keys').dash,
        seen: G.Settings.hintSeen('boarder'),
        runs: G.RunLog.all().length,
        best: !!G.RunLog.best(),
      };
    });
    record('store', 'settings survive a reload',
      back.music === 0.15 && back.vfx === 0.25 && back.hud === 1.2 && back.motion === true,
      JSON.stringify({ music: back.music, vfx: back.vfx, hud: back.hud, motion: back.motion }));
    record('store', 'key bindings survive a reload', back.dash === 'f', 'dash=' + back.dash);
    record('store', 'a prompt already seen stays seen', back.seen === true);
    record('store', 'the finished run is in the log', back.runs >= 1 && back.best,
      back.runs + ' run(s) recorded');

    // Storage refused. The game must boot, play and simply forget.
    const denied = await browser.newContext();
    await denied.addInitScript(() => {
      Object.defineProperty(window, 'localStorage', {
        get(){ throw new DOMException('denied', 'SecurityError'); },
      });
    });
    const t2 = await denied.newPage();
    const derr = [];
    t2.on('pageerror', e => derr.push(e.message));
    await t2.goto(url, { waitUntil: 'domcontentloaded' });
    await t2.waitForFunction(() => !!window.SKYGEAR, null, { timeout: 15000 });
    await t2.evaluate(INSTALL);
    const survived = await t2.evaluate(() => {
      const G = window.SKYGEAR;
      window.__begin();
      for (let i = 0; i < 600; i++) G.step(G.DT);
      G.Settings.set('volMusic', 0.5);        // must not throw
      return { mode: G.S.mode, wave: G.S.wave, ok: G.Store.ok };
    });
    record('store', 'the game runs with storage denied',
      derr.length === 0 && survived.mode === 'play',
      'mode=' + survived.mode + ', Store.ok=' + survived.ok +
      (derr.length ? ' · ' + derr[0].split('\n')[0] : ''));
    await denied.close();
  } catch (e){
    record('store', 'persistence works', false, e.message.split('\n')[0]);
  } finally {
    await tab.close();
  }
}

/* A cold cache on a slow line.

   "Interactive in under 2 s on a cold cache" is an acceptance criterion, and
   the whole point of streaming art in priority order is that it holds at any
   speed. So this serves the page with every asset request throttled to roughly
   3 Mbit — the figure the plan uses for a bad connection — and measures when
   the game is actually playable rather than when the network goes quiet.

   Playable means: the title screen is up, START RUN works, and a run reaches
   the fight. Whether the art has arrived is deliberately not part of it; that
   is what the procedural fallback is for. What IS asserted is that the art
   keeps arriving afterwards, because a loader that stalls once the game starts
   would pass a naive timing test and leave the player on stand-ins forever. */
async function checkSlowStart(browser, port){
  const tab = await browser.newPage({ viewport: { width: 1366, height: 768 } });
  const errs = [];
  tab.on('pageerror', e => errs.push(e.message));
  try {
    // ~3 Mbit: 375 KB/s. Delay each asset response in proportion to its size.
    // Read the file directly rather than round-tripping through route.fetch():
    // the harness's own server answers with chunked transfer-encoding, and
    // replaying that response through fulfill() fails. A route handler that
    // throws is an unhandled rejection, not a failed check, so it catches.
    await tab.route('**/assets/**', async (route) => {
      try {
        const u = new URL(route.request().url());
        const file = path.join(ROOT, decodeURIComponent(u.pathname));
        if (!file.startsWith(ROOT)){ await route.abort(); return; }
        const body = fs.readFileSync(file);
        await new Promise(r => setTimeout(r, Math.min(4000, body.length / 375)));
        await route.fulfill({ status: 200, body,
          headers: { 'content-type': MIME[path.extname(file)] || 'application/octet-stream' } });
      } catch (e){
        try { await route.abort(); } catch (e2) {}
      }
    });
    const t0 = Date.now();
    await tab.goto(`http://127.0.0.1:${port}/${BUILD}.html?audio=0&seed=SLOW01`,
                   { waitUntil: 'commit' });
    await tab.waitForFunction(() => !!window.SKYGEAR && SKYGEAR.S.mode === 'title',
                              null, { timeout: 20000 });
    const titleMs = Date.now() - t0;
    record('slow', 'the title screen is up in under 2 s on a 3 Mbit line',
      titleMs < 2000, titleMs + ' ms');

    await tab.evaluate(INSTALL);
    const t1 = Date.now();
    const mode = await tab.evaluate(() => window.__begin());
    record('slow', 'a run starts while the art is still downloading',
      mode === 'play', 'mode=' + mode + ' after ' + (Date.now() - t1) + ' ms');

    const early = await tab.evaluate(() => ({ ready: SKYGEAR.Assets.ready,
                                              total: SKYGEAR.Assets.total }));
    await tab.waitForTimeout(4000);
    const later = await tab.evaluate(() => ({ ready: SKYGEAR.Assets.ready,
                                              total: SKYGEAR.Assets.total }));
    record('slow', 'art keeps arriving after the run has started',
      later.ready > early.ready || later.ready === later.total,
      early.ready + '/' + early.total + ' -> ' + later.ready + '/' + later.total);
    record('slow', 'nothing threw while loading slowly', errs.length === 0,
      errs.slice(0, 2).join(' | '));
  } catch (e){
    record('slow', 'the game is playable on a slow line', false, e.message.split('\n')[0]);
  } finally {
    await tab.close();
  }
}

/* Play it the way a person does.

   Every other check reaches into window.SKYGEAR and moves the state itself,
   which is the only way to test twelve waves in a second — but it means none of
   them ever presses a key. This one uses real mouse and keyboard events through
   the browser, so it exercises the parts nothing else touches: that the title
   button is where the click lands, that a draft card responds to a click, that
   WASD reaches the captain, that Escape opens the pause menu and Escape closes
   it again. A stranger who cannot get past the title screen has no opinion
   about wave balance. */
async function checkInput(browser, port){
  const tab = await browser.newPage({ viewport: { width: 1366, height: 768 } });
  const errs = [];
  tab.on('pageerror', e => errs.push(e.message));
  try {
    await tab.goto(`http://127.0.0.1:${port}/${BUILD}.html?assets=0&audio=0&seed=INPUT1`,
                   { waitUntil: 'domcontentloaded' });
    await tab.waitForFunction(() => !!window.SKYGEAR, null, { timeout: 15000 });

    // Where is the primary button? Ask the game, do not guess: the answer is
    // whatever hudScale and the viewport produced, which is the point.
    const startBtn = await tab.evaluate(() => {
      const G = window.SKYGEAR;
      const seen = [];
      const probe = G.UI.probe.bind(G.UI);
      G.UI.probe = function(r){ seen.push({ ...r }); return probe(r); };
      G.S.mode = 'title';
      G.render(1 / 60);
      G.UI.probe = probe;
      return seen[0] || null;
    });
    record('input', 'the title screen has a button to press', !!startBtn,
      startBtn ? Math.round(startBtn.w) + 'x' + Math.round(startBtn.h) + ' at ' +
                 Math.round(startBtn.x) + ',' + Math.round(startBtn.y) : 'none drawn');
    if (!startBtn) return;

    // Move first, then click. UI.probe only takes focus when the pointer has
    // actually moved, which is exactly the behaviour being tested.
    await tab.mouse.move(startBtn.x + startBtn.w / 2, startBtn.y + startBtn.h / 2);
    await tab.mouse.move(startBtn.x + startBtn.w / 2, startBtn.y + startBtn.h / 2 + 1);
    await tab.mouse.down(); await tab.mouse.up();
    await tab.waitForFunction(() => SKYGEAR.S.mode !== 'title', null, { timeout: 5000 })
             .catch(() => {});
    const afterStart = await tab.evaluate(() => SKYGEAR.S.mode);
    record('input', 'clicking START RUN starts a run',
      afterStart === 'draft' || afterStart === 'play', 'mode=' + afterStart);

    // The opening draft, by keyboard.
    await tab.keyboard.press('2');
    await tab.waitForFunction(() => SKYGEAR.S.mode === 'play', null, { timeout: 5000 })
             .catch(() => {});
    const armed = await tab.evaluate(() => ({
      mode: SKYGEAR.S.mode,
      slot0: SKYGEAR.S.slots[0] ? SKYGEAR.S.slots[0].shape + '/' + SKYGEAR.S.slots[0].element : null,
    }));
    record('input', 'pressing 2 takes the middle card and starts the fight',
      armed.mode === 'play' && !!armed.slot0, armed.slot0 || ('mode=' + armed.mode));

    // WASD has to reach the captain.
    const before = await tab.evaluate(() => ({ x: SKYGEAR.S.player.x, y: SKYGEAR.S.player.y }));
    await tab.keyboard.down('a');
    await tab.waitForTimeout(500);
    await tab.keyboard.up('a');
    const after = await tab.evaluate(() => ({ x: SKYGEAR.S.player.x, y: SKYGEAR.S.player.y }));
    record('input', 'holding A moves the captain to port',
      after.x < before.x - 20,
      'moved ' + Math.round(after.x - before.x) + ' units in x');

    // Escape opens the pause menu, and closes it.
    await tab.keyboard.press('Escape');
    await tab.waitForTimeout(120);
    const paused = await tab.evaluate(() => SKYGEAR.S.mode);
    await tab.keyboard.press('Escape');
    await tab.waitForTimeout(120);
    const resumed = await tab.evaluate(() => SKYGEAR.S.mode);
    record('input', 'Escape pauses and Escape resumes',
      paused === 'pause' && resumed === 'play', paused + ' -> ' + resumed);

    record('input', 'nothing threw while a person played it', errs.length === 0,
      errs.slice(0, 2).join(' | '));
  } catch (e){
    record('input', 'the game is playable with real input', false, e.message.split('\n')[0]);
  } finally {
    await tab.close();
  }
}

/* The resolution and DPI matrix, and the browser matrix.

   V10-PLAN §7 asks for 1280x720 through 2560x1440 at DPR 1 and 2, in Chrome and
   Firefox. The failure this catches is not a crash — it is a HUD that is
   correct at the developer's window size and off the bottom of the screen at
   someone else's. So each size boots the game, opens each screen that has a
   layout, and asserts that every drawn control is inside the viewport, that
   nothing overlaps, and that no frame threw.

   Widget rectangles come from the game itself rather than from a screenshot:
   UI.probe already knows where every control is, so recording them costs one
   array and is exact. */
const SIZES = [
  { w: 1280, h: 720,  dpr: 1 },
  { w: 1366, h: 768,  dpr: 1 },
  { w: 1600, h: 900,  dpr: 2 },
  { w: 1920, h: 1080, dpr: 1 },
  { w: 2560, h: 1440, dpr: 2 },
];
const SCREENS = ['title', 'settings', 'howto', 'binds', 'pause', 'results', 'draft'];

async function checkLayout(browser, port){
  const bad = [];
  for (const s of SIZES){
    const tab = await browser.newPage({
      viewport: { width: s.w, height: s.h }, deviceScaleFactor: s.dpr });
    const errs = [];
    tab.on('pageerror', e => errs.push(e.message));
    try {
      await tab.goto(`http://127.0.0.1:${port}/${BUILD}.html?assets=0&audio=0&seed=LAYOUT`,
                     { waitUntil: 'domcontentloaded' });
      await tab.waitForFunction(() => !!window.SKYGEAR, null, { timeout: 15000 });
      await tab.evaluate(INSTALL);
      const out = await tab.evaluate((screens) => {
        const G = window.SKYGEAR, S = G.S;
        // Record every control rect the next draw produces.
        const seen = [];
        const probe = G.UI.probe.bind(G.UI);
        G.UI.probe = function(r){ seen.push({ ...r }); return probe(r); };
        const res = {};
        for (const name of screens){
          seen.length = 0;
          if (name === 'title'){ S.mode = 'title'; S.overlay = null; }
          else if (name === 'settings'){ S.mode = 'title'; G.openSettings('title'); }
          else if (name === 'howto'){ S.mode = 'title'; G.openHowTo('title'); }
          else if (name === 'binds'){ S.mode = 'title'; G.openBinds(); }
          else if (name === 'pause'){ window.__begin(); S.overlay = null; S.mode = 'pause'; }
          else if (name === 'draft'){ window.__begin(); S.unlockedSlots = 4; G.openDraft(); S.draft.t = 2; }
          else if (name === 'results'){
            window.__begin();
            S.result = G.RunLog.record(G.buildRunRecord(true));
            S.mode = 'victory'; S.endTitle = 'DECK HELD';
            S.endReason = 'Twelve waves repelled. The deck is yours.'; S.endT = 3;
          }
          G.render(1 / 60);
          const W = window.innerWidth, H = window.innerHeight;
          const off = seen.filter(r => r.x < -1 || r.y < -1 ||
                                       r.x + r.w > W + 1 || r.y + r.h > H + 1);
          // Overlapping hit targets mean a click lands on whichever was drawn
          // last, which is not what the player aimed at.
          const over = [];
          for (let i = 0; i < seen.length; i++)
            for (let j = i + 1; j < seen.length; j++){
              const a = seen[i], b = seen[j];
              if (a.x < b.x + b.w && b.x < a.x + a.w &&
                  a.y < b.y + b.h && b.y < a.y + a.h) over.push([i, j]);
            }
          res[name] = { n: seen.length, off: off.length, over: over.length };
        }
        S.overlay = null; S.mode = 'title';
        return res;
      }, SCREENS);
      for (const name of SCREENS){
        const r = out[name];
        if (!r) continue;
        if (r.off) bad.push(`${s.w}x${s.h}@${s.dpr} ${name}: ${r.off} control(s) off-screen`);
        if (r.over) bad.push(`${s.w}x${s.h}@${s.dpr} ${name}: ${r.over} overlapping control(s)`);
        if (!r.n && name !== 'draft') bad.push(`${s.w}x${s.h}@${s.dpr} ${name}: no controls drawn`);
      }
      if (errs.length) bad.push(`${s.w}x${s.h}@${s.dpr}: ${errs[0].split('\n')[0]}`);
    } catch (e){
      bad.push(`${s.w}x${s.h}@${s.dpr}: ${e.message.split('\n')[0]}`);
    } finally {
      await tab.close();
    }
  }
  record('layout', 'every screen fits and no controls overlap, 1280x720 to 2560x1440',
    bad.length === 0, bad.length ? bad.slice(0, 4).join(' | ') : SIZES.length + ' sizes x ' + SCREENS.length + ' screens');
}

/* Firefox. The rule is one engine's quirks must not be the only thing the game
   has ever run on: Gecko differs from Blink on canvas letterSpacing, on
   AudioContext construction before a gesture, and on how it reports
   prefers-reduced-motion. A boot plus a wave is enough to catch all three. */
async function checkFirefox(port){
  let fx;
  try {
    const { firefox } = await import('playwright');
    fx = await firefox.launch({ headless: true });
  } catch (e){
    record('firefox', 'the build runs in Firefox', true,
      'SKIPPED — no Firefox build installed (npx playwright install firefox)');
    return;
  }
  const tab = await fx.newPage({ viewport: { width: 1366, height: 768 } });
  const errs = [];
  tab.on('pageerror', e => errs.push(e.message));
  try {
    await tab.goto(`http://127.0.0.1:${port}/${BUILD}.html?assets=0&audio=0&seed=GECKO1`,
                   { waitUntil: 'domcontentloaded' });
    await tab.waitForFunction(() => !!window.SKYGEAR, null, { timeout: 20000 });
    await tab.evaluate(INSTALL);
    const out = await tab.evaluate(() => {
      const G = window.SKYGEAR, S = G.S;
      window.__begin();
      S.player.hp = S.player.maxHp = 1e9; S.boiler.hp = S.boiler.maxHp = 1e9;
      for (let i = 0; i < 30 / G.DT && S.mode === 'play'; i++) G.step(G.DT);
      G.render(1 / 60);
      S.mode = 'title';
      return { wave: S.wave, kills: S.stats.kills, seed: G.seedText(S.seed) };
    });
    record('firefox', 'the build runs in Firefox', errs.length === 0 && out.wave > 0,
      errs.length ? errs[0].split('\n')[0] : 'reached wave ' + out.wave + ', seed ' + out.seed);
  } catch (e){
    record('firefox', 'the build runs in Firefox', false, e.message.split('\n')[0]);
  } finally {
    await tab.close();
    await fx.close();
  }
}

/* The frozen builds are the site's history. build.py enforces this too; the
   harness repeats it so one command answers "is the site correct". */
async function checkFrozen(){
  const { execFileSync } = await import('node:child_process');
  let ok = true, out = '';
  try { out = execFileSync('python', [path.join(ROOT, 'src/storm-dusk/build.py')], { encoding: 'utf8' }); }
  catch (e){ ok = false; out = String(e.stdout || e.message); }
  record('frozen', 'frozen builds are byte-identical', ok && /frozen\s+\d+ build/.test(out),
    out.split('\n').filter(Boolean).slice(-2).join(' / '));
}

/* Simulation cost with a real crowd on the deck.
   This gates on step() alone and reports render() separately, on purpose.
   Headless Chromium rasterises canvas in software, so a render number measured
   here says something about SwiftShader, not about the player's machine — the
   60 fps target in the plan is explicitly human work on real hardware. step()
   is pure CPU and its cost is the same everywhere, so it is the half that can
   honestly be a pass/fail gate; the render figure is a relative tripwire. */
/* The crowd is built, measured and torn down inside ONE evaluate, and that is
   load-bearing rather than tidiness. Headless Chromium rasterises this scene in
   software at roughly three seconds a frame; leave forty enemies standing when
   the evaluate returns and the page's own frame loop hogs the main thread so
   completely that the next evaluate never gets scheduled. The first version of
   this check looked like a hang and was really a starved message queue.

   Only step() is gated. Render cost here is a fact about SwiftShader, not about
   the player's machine, so real frame rate stays human work on real hardware
   (V10-PLAN §5). The renderer is still covered — the page's frame loop runs for
   the whole session and the boot group asserts nothing threw, which is how the
   non-finite-gradient crash in the very first harness run surfaced. */
async function checkPerf(page, errorLog){
  const before = errorLog.length;
  const sim = await page.evaluate(() => {
    const G = window.SKYGEAR, S = G.S;
    window.__begin();
    S.player.hp = S.player.maxHp = 1e9; S.boiler.hp = S.boiler.maxHp = 1e9;
    for (let i = 0; i < 40; i++){
      const e = G.spawnEnemy(['SCRAPPER','SWARM','GUNNER','ARMORED'][i % 4]);
      if (e){ e.hp = e.maxHp = 1e6; e.state = 'move'; e.climb = 1; }
    }
    const n = S.enemies.length;
    const N = 1200, t = [];
    for (let i = 0; i < N; i++){
      const t0 = performance.now();
      G.step(G.DT);
      t.push(performance.now() - t0);
    }
    t.sort((a, b) => a - b);
    window.__begin();                   // clear the deck before yielding
    return { n, med: t[N >> 1], p95: t[Math.floor(N * 0.95)] };
  });
  // 120 Hz sim: two steps per displayed frame, so one step must fit in half a
  // 60 fps budget and still leave the renderer room beside it.
  record('perf', 'simulation step with a crowd stays under budget', sim.p95 < 4.0,
    sim.n + ' enemies · median ' + sim.med.toFixed(3) + ' ms · p95 ' + sim.p95.toFixed(3) + ' ms');
  record('perf', 'a crowded deck raises no errors', errorLog.length === before,
    errorLog.length > before ? errorLog[before] : '');
}

/* ---------------------------------------------------------------------------
   main
--------------------------------------------------------------------------- */
const { srv, port } = await serve();
const browser = await chromium.launch({ headless: !HEADED });
const page = await browser.newPage({ viewport: { width: 1366, height: 768 } });

const errors = [];
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', e => errors.push('pageerror: ' + e.message));

console.log('harness · ' + BUILD + ' · http://127.0.0.1:' + port);
await page.goto(`http://127.0.0.1:${port}/${BUILD}.html?assets=0&audio=0`);
await page.waitForFunction(() => !!window.SKYGEAR, null, { timeout: 15000 });
await page.evaluate(INSTALL);

await group('boot',    () => checkBoot(page, errors));
await group('matrix',  () => checkMatrix(page));
await group('waves',   () => checkWaves(page));
await group('boss',    () => checkBoss(page));
await group('endings', () => checkEndings(page));
await group('seed',    () => checkSeed(browser, port));
await group('perf',    () => checkPerf(page, errors));
await group('input',   () => checkInput(browser, port));
await group('store',   () => checkPersistence(browser, port));
await group('slow',    () => checkSlowStart(browser, port));
await group('layout',  () => checkLayout(browser, port));
await group('firefox', () => checkFirefox(port));
await group('frozen',  () => checkFrozen());

// Console errors are collected across every check, not just boot: a throw
// inside a wave is exactly the class of defect this harness exists to find.
if (wants('boot')){
  const late = errors.filter(e => !/favicon|net::ERR/.test(e));
  record('boot', 'no console errors across the whole run', late.length === 0,
    late.slice(0, 3).join(' | '));
}

await browser.close();
srv.close();

const failed = results.filter(r => !r.ok);
console.log('');
console.log(`${results.length - failed.length}/${results.length} checks passed` +
            (failed.length ? '  —  ' + failed.map(f => f.group + '/' + f.name).join(', ') : ''));
process.exit(failed.length);
