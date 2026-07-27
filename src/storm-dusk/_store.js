/* ============================================================================
   PERSISTENCE — settings, first-run prompts, and the run log
   ----------------------------------------------------------------------------
   One key in localStorage holding one JSON object. Several keys would be
   tidier to read in devtools and worse everywhere else: a partial write leaves
   the settings and the run history disagreeing about which version of the game
   wrote them, and clearing "just the hints" becomes three call sites.

   Every access is wrapped. localStorage throws rather than returns null in a
   few real situations — Safari private browsing, a file:// origin, storage
   disabled by policy — and none of them are a reason for the game not to run.
   If storage is unavailable the game keeps working with defaults and simply
   forgets between sessions.
============================================================================ */
const Store = {
  KEY: 'skygear.v10',
  data: null,
  ok: true,

  load(){
    if (this.data) return this.data;
    this.data = {};
    try {
      const raw = window.localStorage.getItem(this.KEY);
      if (raw) this.data = JSON.parse(raw) || {};
    } catch (e){ this.ok = false; }
    return this.data;
  },
  save(){
    if (!this.ok) return;
    try { window.localStorage.setItem(this.KEY, JSON.stringify(this.data)); }
    catch (e){ this.ok = false; }
  },
  get(k, dflt){
    const d = this.load();
    return (k in d) ? d[k] : dflt;
  },
  set(k, v){ this.load()[k] = v; this.save(); return v; },
  clear(){
    this.data = {};
    try { window.localStorage.removeItem(this.KEY); } catch (e){}
  },
};

/* ---------------------------------------------------------------------------
   SETTINGS
   Defaults are chosen so that a stranger who never opens this menu gets the
   right experience: full volume, full effects, and reduced motion already on if
   their operating system says they want it.
--------------------------------------------------------------------------- */
const SETTING_DEFAULTS = {
  volMaster: 0.85,
  volMusic: 0.55,
  volSfx: 1.0,
  volUi: 0.85,
  muted: false,
  vfx: 1,                 // 1 full · 0.5 fewer · 0.25 fewest
  reducedMotion: null,    // null = follow the OS; true/false = the player chose
  hudScale: 1,            // multiplies the resolution-derived scale
  hints: true,            // contextual first-run prompts
  seen: {},               // which prompts have fired
  keys: null,             // remaps, { action: 'key' }
};

const Settings = {
  v: null,

  init(){
    this.v = Object.assign({}, SETTING_DEFAULTS, Store.get('settings', {}));
    // seen/keys are objects; a stale shape from an older build must not throw
    if (!this.v.seen || typeof this.v.seen !== 'object') this.v.seen = {};
    return this;
  },
  get(k){ return this.v ? this.v[k] : SETTING_DEFAULTS[k]; },
  set(k, val){
    this.v[k] = val;
    Store.set('settings', this.v);
    this.apply(k);
    return val;
  },
  reset(){
    this.v = Object.assign({}, SETTING_DEFAULTS);
    this.v.seen = {};
    Store.set('settings', this.v);
    this.applyAll();
  },

  /* The OS preference is the default, not the law: a player who explicitly
     turns motion back on keeps it on even though their system asks for less. */
  motionReduced(){
    if (this.v.reducedMotion !== null) return !!this.v.reducedMotion;
    try { return window.matchMedia('(prefers-reduced-motion: reduce)').matches; }
    catch (e){ return false; }
  },
  // Trauma shake, full-screen flashes and hit-stop all read these rather than
  // testing the flag themselves, so there is one place to change the strength.
  shakeScale(){ return this.motionReduced() ? 0.5 : 1; },
  flashScale(){ return this.motionReduced() ? 0 : 1; },
  stopScale(){ return this.motionReduced() ? 0.5 : 1; },

  apply(k){
    if (k === undefined || /^vol|^muted/.test(k)) this.applyAudio();
  },
  applyAll(){ this.applyAudio(); },
  applyAudio(){
    if (typeof Sound === 'undefined') return;
    Sound.muted = !!this.v.muted;
    Sound.vol = this.v.volMaster;
    if (Sound.master) Sound.master.gain.value = this.v.muted ? 0 : this.v.volMaster;
    if (Sound.bus){
      Sound.bus.music.gain.value = this.v.volMusic;
      Sound.bus.sfx.gain.value   = this.v.volSfx;
      Sound.bus.ui.gain.value    = this.v.volUi;
      Sound.bus.voice.gain.value = this.v.volSfx;
    }
  },

  /* First-run prompts. `fire` is idempotent per id and per player, so a call
     site can simply say "this just happened" every time it happens. */
  hintSeen(id){ return !!this.v.seen[id]; },
  markSeen(id){ this.v.seen[id] = 1; Store.set('settings', this.v); },
  forgetHints(){ this.v.seen = {}; Store.set('settings', this.v); },
};
Settings.init();

/* ---------------------------------------------------------------------------
   RUN LOG
   The last ten runs and a personal best, kept locally. No account, no server,
   nothing leaves the machine — which is also why the run report is a block of
   text the player copies themselves rather than anything that gets sent.
--------------------------------------------------------------------------- */
const RunLog = {
  MAX: 10,

  all(){
    const a = Store.get('runs', []);
    return Array.isArray(a) ? a : [];
  },
  best(){
    let b = null;
    for (const r of this.all()) if (!b || this.better(r, b)) b = r;
    return b;
  },
  /* Furthest wave first, then kills. Duration is deliberately not a tiebreak:
     rewarding a faster run would push toward skipping the draft, and the draft
     is the game. */
  better(a, b){
    if (!b) return true;
    if (a.won !== b.won) return !!a.won;
    if (a.wave !== b.wave) return a.wave > b.wave;
    return a.kills > b.kills;
  },

  record(run){
    const prev = this.best();
    run.pb = this.better(run, prev);
    const list = this.all();
    list.unshift(run);
    Store.set('runs', list.slice(0, this.MAX));
    return run;
  },
};

function fmtDuration(sec){
  sec = Math.max(0, Math.round(sec));
  const m = Math.floor(sec / 60), s = sec % 60;
  return m + ':' + (s < 10 ? '0' : '') + s;
}

/* Build the record of a finished run. Reads the live state rather than being
   handed a summary, so it cannot drift from what the results screen shows. */
function buildRunRecord(win){
  const build = [];
  if (S.basic) build.push(skillName(S.basic) + ' (auto)');
  for (let i = 0; i < 4; i++) if (S.slots[i]) build.push(skillName(S.slots[i]));
  return {
    v: PRESET.name,
    build: PRESET.build || 'dev',
    won: !!win,
    title: S.endTitle,
    cause: S.endReason,
    wave: win ? TUNING.totalWaves : Math.max(0, S.wave - 1),
    waves: TUNING.totalWaves,
    time: S.t,
    kills: S.stats.kills,
    damage: Math.round(S.stats.damage),
    chain: S.stats.bestCombo,
    dashes: S.stats.dashes,
    seed: seedText(S.seed),
    loadout: build,
    cards: S.stats.cards.slice(),
  };
}

/* One block of text a player can paste into a message. Everything needed to
   reproduce and to argue about is in it: the build id, the seed, the cause of
   death and the whole draft. */
function runReportText(r){
  const L = [];
  L.push('SKYGEAR ' + r.v + ' · build ' + r.build);
  L.push((r.title || (r.won ? 'DECK HELD' : 'BOARDED')) + ' — ' + (r.cause || ''));
  L.push('wave ' + r.wave + '/' + r.waves + ' · ' + fmtDuration(r.time) + ' · seed ' + r.seed);
  L.push('kills ' + r.kills + ' · damage ' + r.damage.toLocaleString() +
         ' · best chain ' + r.chain + ' · dashes ' + r.dashes);
  L.push('build: ' + (r.loadout.length ? r.loadout.join('  /  ') : '—'));
  if (r.cards.length) L.push('draft: ' + r.cards.join(', '));
  L.push('replay: ' + location.origin + location.pathname + '?seed=' + r.seed);
  return L.join('\n');
}

/* Clipboard, with a fallback. navigator.clipboard is unavailable on insecure
   origins, which includes the http://127.0.0.1 the game is developed on and
   any playtester served over plain http — exactly the people most likely to be
   asked for a run report. */
function copyText(text){
  const legacy = () => {
    try {
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.style.cssText = 'position:fixed;left:-9999px;top:0;opacity:0';
      document.body.appendChild(ta);
      ta.focus(); ta.select();
      const ok = document.execCommand('copy');
      document.body.removeChild(ta);
      return ok;
    } catch (e){ return false; }
  };
  try {
    if (navigator.clipboard && window.isSecureContext){
      navigator.clipboard.writeText(text).then(
        () => { S.copyToast = { t: 0, ok: true }; },
        () => { S.copyToast = { t: 0, ok: legacy() }; });
      return true;
    }
  } catch (e){}
  const ok = legacy();
  S.copyToast = { t: 0, ok };
  return ok;
}
