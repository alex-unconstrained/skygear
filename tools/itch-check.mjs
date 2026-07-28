/* Does the itch upload actually play? Serve the EXTRACTED zip, exactly as
   itch.io would, and assert the landing page links a build that boots, loads
   its art from relative paths, and starts a run. An upload that does not boot
   is the classic way to ship a broken build to strangers. */
import { chromium } from 'playwright';
import http from 'node:http'; import fs from 'node:fs'; import path from 'node:path';
/* Extract the upload somewhere neutral and serve THAT, not the repo: the whole
   point is to test the artifact a stranger downloads, including whether a file
   the game needs was left out of the zip. */
import os from 'node:os';
import { execFileSync } from 'node:child_process';
const ZIP = path.resolve(process.argv[2] || 'skygear-itch.zip');
const ROOT = fs.mkdtempSync(path.join(os.tmpdir(), 'itchcheck-'));
// Windows ships bsdtar at a known path and it reads zips; the msys `tar` that
// shadows it on PATH treats "C:\..." as a remote host and fails to "connect".
const TAR = process.platform === 'win32' ? 'C:/Windows/System32/tar.exe' : 'tar';
execFileSync(TAR, ['-xf', ZIP, '-C', ROOT]);
const MIME = { '.html':'text/html', '.png':'image/png', '.ogg':'audio/ogg', '.mp3':'audio/mpeg' };
const srv = http.createServer((q, r) => {
  const u = decodeURIComponent(q.url.split('?')[0]);
  const p = path.join(ROOT, u === '/' ? 'index.html' : u);
  fs.readFile(p, (e, b) => {
    if (e){ r.writeHead(404).end(); return; }
    r.writeHead(200, { 'content-type': MIME[path.extname(p)] || 'application/octet-stream' });
    r.end(b);
  });
});
await new Promise(r => srv.listen(0, '127.0.0.1', r));
const port = srv.address().port;
const br = await chromium.launch();
const pg = await br.newPage({ viewport: { width: 1280, height: 720 } });
const missing = [];
pg.on('response', r => { if (r.status() === 404) missing.push(r.url().split(`:${port}`)[1]); });
const errors = [];
pg.on('pageerror', e => errors.push(e.message));

const resp = await pg.goto(`http://127.0.0.1:${port}/index.html`, { waitUntil: 'load' });
console.log('index status', resp && resp.status(), 'title', await pg.title());
console.log('html length', (await pg.content()).length);
const href = await pg.evaluate(() => {
  const a = document.querySelector('a.hero') || document.querySelector('a[href*="storm-dusk"]');
  return a ? a.getAttribute('href') : null;
});
if (!href) throw new Error('the landing page links no build');
console.log('landing page offers:', href);
await pg.goto(`http://127.0.0.1:${port}/${href}`, { waitUntil: 'load' });
await pg.waitForFunction(() => !!window.SKYGEAR, null, { timeout: 20000 });
await pg.waitForTimeout(6000);                       // let the art stream in
const out = await pg.evaluate(() => {
  const G = window.SKYGEAR;
  G.startRun();
  if (G.S.mode === 'draft'){ G.pickCard(0); G.closeDraft(); }
  for (let i = 0; i < 240; i++) G.step(G.DT);
  return { mode: G.S.mode, wave: G.S.wave, build: location.search.replace('?b=', ''),
           art: G.Assets.ready, artTotal: G.Assets.total };
});
console.log('build', out.build, '· mode', out.mode, '· wave', out.wave,
            '· art', out.art + '/' + out.artTotal);
console.log('404s:', missing.length ? missing.slice(0, 5).join(', ') : 'none');
console.log('page errors:', errors.length ? errors.slice(0, 3).join(' | ') : 'none');
const ok = out.mode === 'play' && out.art > 30 && missing.length === 0 && errors.length === 0;
console.log(ok ? 'ITCH PACKAGE OK' : 'ITCH PACKAGE PROBLEM');
await br.close(); srv.close();
process.exit(ok ? 0 : 1);
