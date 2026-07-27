#!/usr/bin/env node
/* Screenshot every screen in the game, so they can be looked at.
 *
 * A renderer is the one part of this project a headless assertion cannot check:
 * "no console errors" is compatible with text off the bottom of the panel, a
 * button under another button, and white-on-white. So this drives the real
 * build into each state and writes a PNG.
 *
 *   node tools/shots.mjs                       # every scene, 1366x768
 *   node tools/shots.mjs --size 2560x1440      # another resolution
 *   node tools/shots.mjs --only results,pause
 *   node tools/shots.mjs --dpr 2
 *
 * Output goes to .shots/ (gitignored) — these are for looking at, not for
 * committing.
 */
import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const argv = process.argv.slice(2);
const arg = (n, d) => { const i = argv.indexOf('--' + n); return i >= 0 && argv[i+1] && !argv[i+1].startsWith('--') ? argv[i+1] : d; };

const SIZE = arg('size', '1366x768').split('x').map(Number);
const DPR = Number(arg('dpr', 1));
const ONLY = (arg('only', '') || '').split(',').filter(Boolean);
const OUT = path.join(ROOT, '.shots');
const BUILD = (() => {
  const m = /^LIVE = '([^']+)'/m.exec(fs.readFileSync(path.join(ROOT, 'src/storm-dusk/build.py'), 'utf8'));
  return m[1];
})();

const MIME = { '.html':'text/html', '.js':'text/javascript', '.png':'image/png',
               '.wav':'audio/wav', '.ogg':'audio/ogg', '.json':'application/json' };
const srv = http.createServer((req, res) => {
  const p = path.join(ROOT, decodeURIComponent(req.url.split('?')[0]));
  fs.readFile(p, (e, b) => {
    if (e){ res.writeHead(404).end(); return; }
    res.writeHead(200, { 'content-type': MIME[path.extname(p)] || 'application/octet-stream' });
    res.end(b);
  });
});
const port = await new Promise(r => srv.listen(0, '127.0.0.1', () => r(srv.address().port)));

/* Each scene puts the game into a state and returns. The frame loop keeps
   drawing, so the screenshot is of the renderer's real output — not of a
   canvas the harness painted itself. */
const SCENES = {
  title: () => { SKYGEAR.S.mode = 'title'; },

  fight: () => {
    const G = SKYGEAR, S = G.S;
    G.startRun();
    S.slots[1] = G.newSkill('LINE_BURST', 'ARC');
    S.slots[2] = G.newSkill('AURA', 'STEAM');
    S.unlockedSlots = 4;
    S.wave = 5; S.waveActive = true;
    for (let i = 0; i < 14; i++){
      const e = G.spawnEnemy(['SCRAPPER','SWARM','GUNNER','ARMORED'][i % 4]);
      if (e){ e.state = 'move'; e.climb = 1; e.y = S.player.y - 120 - i * 34; }
    }
    for (let i = 0; i < 90; i++) G.step(G.DT);
    S.player.hp = S.player.maxHp * 0.55;
    S.boiler.hp = S.boiler.maxHp * 0.72;
  },

  draft: () => {
    const G = SKYGEAR, S = G.S;
    G.startRun();
    S.unlockedSlots = 4;
    G.openDraft();
    S.draft.t = 2;
  },

  upgrades: () => {
    const G = SKYGEAR, S = G.S;
    G.startRun();
    S.slots[1] = G.newSkill('CONE', 'FROST');
    S.slots[2] = G.newSkill('CHAIN', 'ARC');
    S.slots[3] = G.newSkill('SENTRY', 'STEAM');
    S.unlockedSlots = 4;
    G.openDraft();
    S.draft.t = 2;
  },

  victory: () => {
    const G = SKYGEAR, S = G.S;
    G.startRun();
    S.slots[1] = G.newSkill('LINE_BURST', 'ARC');
    S.slots[2] = G.newSkill('AURA', 'STEAM');
    S.stats.kills = 214; S.stats.damage = 18402; S.stats.bestCombo = 19; S.stats.dashes = 41;
    S.stats.cards = ['DEEPER BURN', 'FIFTH GEAR', 'STORM COIL', 'HAIR TRIGGER'];
    S.t = 461; S.wave = 13;
    window.__endRun(true, 'DECK HELD', 'Twelve waves repelled. The deck is yours.');
    S.endT = 3;
  },

  defeat: () => {
    const G = SKYGEAR, S = G.S;
    G.startRun();
    S.slots[1] = G.newSkill('CONE', 'FROST');
    S.stats.kills = 63; S.stats.damage = 4120; S.stats.bestCombo = 7; S.stats.dashes = 11;
    S.stats.cards = ['DEEPER BURN', 'BRITTLE ICE'];
    S.t = 168; S.wave = 6;
    window.__endRun(false, 'BOILER LOST', 'The engine core is gone. The ship falls.');
    S.endT = 3;
  },

  pause: () => {
    const G = SKYGEAR, S = G.S;
    G.startRun();
    S.slots[1] = G.newSkill('CONE', 'FROST');
    S.slots[2] = G.newSkill('PULSE', 'ARC');
    S.unlockedSlots = 4;
    for (let i = 0; i < 60; i++) G.step(G.DT);
    S.mode = 'pause';
  },

  settings: () => { SKYGEAR.S.mode = 'title'; SKYGEAR.openSettings('title'); },
  howto:    () => { SKYGEAR.S.mode = 'title'; SKYGEAR.openHowTo('title'); },
  binds:    () => { SKYGEAR.S.mode = 'title'; SKYGEAR.openBinds(); },

  opening: () => {
    const G = SKYGEAR, S = G.S;
    G.startRun();
    S.draft.t = 2;
  },
};

fs.mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({
  viewport: { width: SIZE[0], height: SIZE[1] }, deviceScaleFactor: DPR });
const errs = [];
page.on('pageerror', e => errs.push(e.message));

await page.goto(`http://127.0.0.1:${port}/${BUILD}.html?assets=0&audio=0&seed=SHOT01`,
                { waitUntil: 'domcontentloaded' });
await page.waitForFunction(() => !!window.SKYGEAR, null, { timeout: 15000 });
// A seam for scenes that need to end a run without pretending to be the sim.
await page.evaluate(() => {
  window.__endRun = (win, title, reason) => {
    const S = SKYGEAR.S;
    S.mode = win ? 'victory' : 'gameover';
    S.endTitle = title; S.endReason = reason; S.endT = 0;
    S.result = SKYGEAR.RunLog.record(SKYGEAR.buildRunRecord(win));
  };
});

const names = Object.keys(SCENES).filter(n => !ONLY.length || ONLY.includes(n));
for (const name of names){
  const before = errs.length;
  try { await page.evaluate(new Function('(' + SCENES[name].toString() + ')()')); }
  catch (e){ console.log('  scene ' + name + ' threw: ' + e.message.split('\n')[0]); continue; }
  // Two frames: one to settle the state, one to draw it. The renderer is slow
  // here (software raster) so this is deliberately patient.
  await page.evaluate(() => new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r))))
            .catch(() => {});
  const file = path.join(OUT, `${name}-${SIZE[0]}x${SIZE[1]}${DPR > 1 ? '@' + DPR + 'x' : ''}.png`);
  await page.screenshot({ path: file });
  console.log((errs.length > before ? 'ERR  ' : 'shot ') + path.relative(ROOT, file) +
              (errs.length > before ? '   ' + errs[before].split('\n')[0] : ''));
}

await browser.close();
srv.close();
if (errs.length) console.log('\n' + errs.length + ' page error(s):\n  ' + [...new Set(errs)].join('\n  '));
