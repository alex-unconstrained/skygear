#!/usr/bin/env node
/* What does one SKYGEAR frame ASK THE CANVAS FOR?
 *
 * "It lags when a lot is going on" is a real report and a useless bug report,
 * and timing it in headless Chromium is worse than useless: software
 * rasterisation has a completely different cost curve from the GPU-composited
 * canvas a player has, so the numbers would be confident and wrong.
 *
 * What IS hardware-independent is the work the frame asks for. Every 2D context
 * method is counted, attributed to the subsystem that called it, over exactly
 * one frame of the heaviest honest state in the game. Canvas 2D cost is
 * dominated by three things — draw calls, state changes, and per-call object
 * allocation (createRadialGradient / createLinearGradient / createPattern) —
 * so those are what this counts.
 *
 *   node tools/profile.mjs                 # wave 11, a full deck
 *   node tools/profile.mjs --wave 12 --n 60 --art
 */
import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const argv = process.argv.slice(2);
const arg = (n, d) => { const i = argv.indexOf('--' + n); return i >= 0 && argv[i+1] && !argv[i+1].startsWith('--') ? argv[i+1] : d; };
const flag = (n) => argv.includes('--' + n);
const WAVE = Number(arg('wave', 11));
const N = Number(arg('n', 46));
const BUILD = (() => {
  const m = /^LIVE = '([^']+)'/m.exec(fs.readFileSync(path.join(ROOT, 'src/storm-dusk/build.py'), 'utf8'));
  return m[1];
})();

const MIME = { '.html':'text/html', '.js':'text/javascript', '.png':'image/png',
               '.ogg':'audio/ogg', '.mp3':'audio/mpeg', '.wav':'audio/wav' };
const srv = http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0]);
  const p = path.join(ROOT, url === '/' ? 'index.html' : url);
  fs.readFile(p, (e, b) => {
    if (e){ res.writeHead(404).end(); return; }
    res.writeHead(200, { 'content-type': MIME[path.extname(p)] || 'application/octet-stream' });
    res.end(b);
  });
});
await new Promise(r => srv.listen(0, '127.0.0.1', r));
const port = srv.address().port;

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1366, height: 768 } });
await page.goto(`http://127.0.0.1:${port}/${BUILD}.html?audio=0${flag('art') ? '' : '&assets=0'}`);
await page.waitForFunction(() => !!window.SKYGEAR, null, { timeout: 20000 });
if (flag('art')) await page.waitForTimeout(6000);

const out = await page.evaluate(({ WAVE, N, ARC }) => {
  const G = window.SKYGEAR, S = G.S;
  G.startRun();
  if (S.mode === 'draft'){ G.pickCard(0); G.closeDraft(); }
  // A REALISTIC wave-11 build, not an invincible one. Setting maxHp to 1e9 to
  // take health out of the measurement put 50 million health-bar tick marks in
  // the frame and hid everything else — the measurement has to be of the game.
  S.player.maxHp = 220; S.player.hp = 180;
  S.boiler.maxHp = 800; S.boiler.hp = 620;
  S.wave = WAVE;
  /* The build the tester actually ran, when asked for it: all Arc, chain-heavy.
     `--arc` reproduces it, because CHAIN is by far the most expensive effect in
     the game to draw — every link is two passes of five jittered segments — and
     the report guessed "lightning or screen shake". Guesses are worth testing
     directly rather than around. */
  const arc = !!ARC;
  const shapes = Object.keys(G.SHAPES).filter(k => !G.SHAPES[k].passive);
  for (let i = 0; i < 4; i++)
    S.slots[i] = arc ? G.newSkill(['CHAIN','CONE','PULSE','CHAIN'][i], 'ARC')
                     : G.newSkill(shapes[i % shapes.length], ['EMBER','FROST','ARC','STEAM'][i]);
  if (arc) S.trauma = 1;                       // and shake the frame while measuring
  const D = G.TUNING.deck;
  for (let i = 0; i < N; i++){
    const e = G.spawnEnemy(['SCRAPPER','SWARM','GUNNER','ARMORED'][i % 4], {
      x: D.cx + (i % 9 - 4) * 90, y: D.cy - D.h/2 + 240 + (i % 7) * 70, side: 'bow' });
    e.state = 'move'; e.st = 0;
  }
  /* Saturate. The first version of this profiler stepped 30 idle frames and
     measured a frame with ZERO particles, damage numbers or transient fx in it —
     i.e. it measured the cheapest frame in the game and called it the worst.
     What the report describes is the opposite: everything happening at once. So
     cast on every frame, let kills happen, light every keg, and measure the
     frame where the particle pool is full. */
  /* Count what the AUDIO layer is asked to do, not just the canvas. Every
     Sound.sample() call builds a BufferSource, a GainNode and sometimes a
     panner, connects them to a bus, and never disconnects them (FEEDBACK.md
     F-01) — so this number is the leak rate, and it is the one measurement that
     tells apart "chain lightning is expensive to draw" from "chain lightning
     hits eight things per cast and each hit makes a sound". */
  let sfxCalls = 0;
  const origSample = G.Sound.sample.bind(G.Sound);
  G.Sound.sample = function (...a){ sfxCalls++; return origSample(...a); };

  for (const pr of G.LIVE_PROPS) if (pr.kind === 'keg') G.hitProp(pr, 999, 0);
  for (let i = 0; i < 200; i++){
    for (let sl = 0; sl < 4; sl++) if (S.slots[sl]) S.slots[sl].cdLeft = 0;
    G.castSlot(0, {}); G.castSlot(1, {}); G.castSlot(2, {}); G.castSlot(3, {});
    G.step(G.DT);
    // keep the deck full: the spawner is off, so respawn what died
    if (S.enemies.filter(e => !e.dead).length < N * 0.6){
      for (let k = 0; k < 8; k++){
        const e = G.spawnEnemy(['SCRAPPER','SWARM','GUNNER','ARMORED'][k % 4], {
          x: D.cx + (k % 7 - 3) * 100, y: D.cy - D.h/2 + 300 + (k % 5) * 60, side: 'bow' });
        e.state = 'move'; e.st = 0;
      }
    }
  }

  // --- count everything the frame asks the context for ----------------------
  G.Sound.sample = origSample;
  const simSeconds = 200 * G.DT;

  const ctx = document.querySelector('canvas').getContext('2d');
  const proto = Object.getPrototypeOf(ctx);
  const counts = {};                       // method -> calls
  const patched = [];
  let bucket = 'other';
  const buckets = {};                      // subsystem -> {calls, alloc}
  let sample = null, seen = 0;
  const bump = (m) => {
    if (m === 'stroke'){
      seen++;
      if (seen === 5000 || seen === 300000){
        try {
          sample = (sample ? sample + ' ||| ' : '') + seen + ': ' +
            String(new Error().stack).split(String.fromCharCode(10)).slice(2, 6).join(' <- ');
        } catch (err){ sample = 'stack failed: ' + err.message; }
      }
    }
    counts[m] = (counts[m] || 0) + 1;
    const b = buckets[bucket] || (buckets[bucket] = { calls: 0, alloc: 0, save: 0 });
    b.calls++;
    if (/^create(Radial|Linear|Conic)Gradient|createPattern$/.test(m)) b.alloc++;
    if (m === 'save') b.save++;
  };
  for (const m of Object.getOwnPropertyNames(proto)){
    let d;
    try { d = Object.getOwnPropertyDescriptor(proto, m); } catch (e){ continue; }
    if (!d || typeof d.value !== 'function' || m === 'constructor') continue;
    const orig = d.value;
    patched.push([m, orig]);
    proto[m] = function (...a){ bump(m); return orig.apply(this, a); };
  }

  // Attribute to subsystems by wrapping the top-level draw functions. Anything
  // a wrapped function calls is charged to it, which is what we want: the cost
  // of drawGroundFx includes the gradients drawGlow makes on its behalf.
  const SUBSYSTEMS = ['drawEnvironment', 'drawBowPiece', 'drawDeckLive', 'drawHulk',
                      'drawFields', 'drawLaneCrossings', 'drawLaneWalls', 'drawTelegraphs',
                      'drawAimLines', 'drawAoePreview', 'drawGroundFx', 'drawSentries',
                      'drawPropBillboard', 'drawEnemyBillboard', 'drawBoilerBillboard',
                      'drawPlayerBillboard', 'drawCrewBillboard', 'drawTurretBillboard',
                      'drawPickupBillboard', 'drawXrayPass', 'drawBolts', 'drawFx',
                      'drawEnvelope', 'drawLaneAlert',
                      // the second half of render(), which the first pass left
                      // in "other" and which turned out to be where all of it was
                      'drawAirFx', 'drawRay', 'drawParticles', 'drawNums',
                      'drawScreenFx', 'drawHUD', 'drawObjectiveMarker',
                      'drawLaneStatus', 'drawHulkBar', 'drawFps', 'drawCursor',
                      'drawOverlay', 'drawDeck', 'buildDeck', 'drawGunwale'];
  const wrapped = [];
  for (const n of SUBSYSTEMS){
    const orig = window[n];
    if (typeof orig !== 'function') continue;
    wrapped.push([n, orig]);
    window[n] = function (...a){
      const prev = bucket; bucket = n;
      try { return orig.apply(this, a); } finally { bucket = prev; }
    };
  }
  if (G.Particles && typeof G.Particles.draw === 'function'){
    const orig = G.Particles.draw.bind(G.Particles);
    G.Particles.draw = function (...a){
      const prev = bucket; bucket = 'Particles.draw';
      try { return orig(...a); } finally { bucket = prev; }
    };
  }

  G.render();                              // exactly one frame

  for (const [m, orig] of patched) proto[m] = orig;
  for (const [n, orig] of wrapped) window[n] = orig;

  const total = Object.values(counts).reduce((a, b) => a + b, 0);
  const alloc = Object.entries(counts)
    .filter(([m]) => /^create(Radial|Linear|Conic)Gradient|createPattern$/.test(m))
    .reduce((a, [, v]) => a + v, 0);
  return {
    counts: { enemies: S.enemies.length, particles: G.Particles.live || 0,
              fields: S.fields.length, fx: S.fx.length, crew: S.crew.length,
              props: G.LIVE_PROPS.filter(p => !p.dead).length, bolts: S.bolts.length },
    total, alloc, sample, seen, sfxCalls, simSeconds,
    methods: Object.entries(counts).sort((a, b) => b[1] - a[1]).slice(0, 14),
    buckets: Object.entries(buckets).sort((a, b) => b[1].calls - a[1].calls),
  };
}, { WAVE, N, ARC: flag('arc') });

console.log(`\nSKYGEAR ${BUILD} · wave ${WAVE} · one frame · ${flag('art') ? 'delivered art' : 'procedural art'}`);
console.log('on deck: ' + Object.entries(out.counts).map(([k, v]) => `${v} ${k}`).join(', '));
console.log(`\ncanvas calls this frame: ${out.total}   of which gradient/pattern allocations: ${out.alloc}`);
console.log('');
console.log('audio: ' + out.sfxCalls + ' Sound.sample() calls over ' + out.simSeconds.toFixed(1) +
            's of simulation = ' + (out.sfxCalls / out.simSeconds).toFixed(0) + '/s.');
console.log('       Every one builds a source, a gain and sometimes a panner, connects them');
console.log('       to a bus, and never disconnects them. See FEEDBACK.md F-01.');
console.log('\n  by subsystem                calls    alloc   saves');
for (const [k, v] of out.buckets)
  console.log('    ' + k.padEnd(24) + String(v.calls).padStart(6) + '   ' +
              String(v.alloc).padStart(6) + '  ' + String(v.save).padStart(6));
console.log('\n  by method');
for (const [m, v] of out.methods)
  console.log('    ' + m.padEnd(24) + String(v).padStart(6));

await browser.close();
srv.close();
