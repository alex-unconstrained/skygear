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
await group('endings', () => checkEndings(page));
await group('seed',    () => checkSeed(browser, port));
await group('perf',    () => checkPerf(page, errors));
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
