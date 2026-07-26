/* ============================================================================
   6. RENDER — Cinderia-style presentation layer
   ----------------------------------------------------------------------------
   Everything above this line is the ported simulation: it works on a flat
   ground plane in (x, y) where y is DEPTH. Nothing below changes gameplay.

   Per the visual spec §2, this is a canvas-2D renderer only:
     · fixed-yaw pinhole camera, pitch 0.72 rad, projecting the ground plane
     · entities are billboard sprites, depth-scaled, painter-sorted far -> near
     · ground-flat art is authored as circles and squashed to ellipses (affine)
     · the deck is code-drawn projected quads — no ground texture
     · sky / clouds / envelope are flat screen-space parallax layers
   Image assets drop in by manifest path (§2.1, §4); anything missing is drawn
   procedurally in the same style so the game is always playable.
============================================================================ */

/* ---------------------------------------------------------------------------
   CAMERA — one fixed pinhole. project() is the only place perspective happens.
--------------------------------------------------------------------------- */
const CAM = {
  pitch: 0.72,           // §2 — ~41 degrees above horizontal
  h: 760,                // camera height above the deck, ground units
  near: 460,             // distance from camera to the world's near edge
  f: 1320,               // focal length at reference scale — frames the deck
  cx: 700, cy: 470,      // screen principal point
  _f: 1000, _sin: 0, _cos: 0,

  recompute(){
    this._sin = Math.sin(this.pitch);
    this._cos = Math.cos(this.pitch);
    this._f = this.f * View.unit;
    this.cx = View.w * 0.5;
    this.cy = View.h * 0.55;
  },

  // ground depth in front of the camera for a world y (small y = far)
  depth(y){ return this.near + (TUNING.world.h - y); },

  // (x, y ground, hgt above deck) -> screen. k is the billboard scale factor.
  // x is measured from the ship's centreline, so the camera looks straight
  // down the keel no matter where the deck sits in world coordinates.
  project(x, y, hgt){
    const dy = (hgt || 0) - this.h;
    const dz = this.depth(y);
    const Yc =  dy * this._cos + dz * this._sin;
    const Zc = -dy * this._sin + dz * this._cos;
    const z  = Zc < 1 ? 1 : Zc;
    const k  = this._f / z;
    return { x: this.cx + (x - TUNING.deck.cx) * k, y: this.cy - Yc * k, k, z };
  },

  // vertical squash for ground-flat circles at this depth (see spec §2.5)
  squash(y){
    const dz = this.depth(y);
    const Zc = this.h * this._sin + dz * this._cos;
    return this.h / (Zc < 1 ? 1 : Zc);
  },

  // screen -> ground plane (y = 0). Used for aiming.
  unproject(sx, sy){
    const X = (sx - this.cx) / this._f;
    const Y = -(sy - this.cy) / this._f;
    // solve for depth dz where the ray meets the deck (hgt = 0)
    //   Yc = -h*cos + dz*sin ,  Zc = h*sin + dz*cos ,  Y = Yc/Zc
    const den = (this._sin - Y * this._cos);
    let dz;
    if (Math.abs(den) < 1e-5) dz = 1e6;
    else dz = (Y * this.h * this._sin + this.h * this._cos) / den;
    if (dz < 40) dz = 40;
    const Zc = this.h * this._sin + dz * this._cos;
    return { x: X * Zc + TUNING.deck.cx, y: TUNING.world.h - (dz - this.near) };
  },

  horizonY(){ return this.cy - this._f * (this._sin / this._cos); },
};

// screen-space y for sorting: draw far first
function depthKey(y){ return -y; }

/* Ground-flat circle -> screen ellipse. The only correct way to lay art on the
   deck when the renderer has no perspective warp. */
function groundEllipsePath(x, y, r){
  const p = CAM.project(x, y, 0);
  const rx = r * p.k;
  const ry = rx * CAM.squash(y);
  ctx.beginPath();
  ctx.ellipse(p.x, p.y, Math.max(0.2, rx), Math.max(0.2, ry), 0, 0, TAU);
  return { p, rx, ry };
}
function groundRing(x, y, r, stroke, lw, alpha){
  const g = groundEllipsePath(x, y, r);
  ctx.globalAlpha = alpha === undefined ? 1 : alpha;
  ctx.strokeStyle = stroke; ctx.lineWidth = lw * g.p.k;
  ctx.stroke();
  ctx.globalAlpha = 1;
  return g;
}
function groundDisc(x, y, r, fill, alpha){
  const g = groundEllipsePath(x, y, r);
  ctx.globalAlpha = alpha === undefined ? 1 : alpha;
  ctx.fillStyle = fill; ctx.fill();
  ctx.globalAlpha = 1;
  return g;
}
// A ground wedge (cone / arc telegraph) built from projected points — the
// projection of a straight ground line is straight, so a fan of segments is exact.
function groundWedgePath(x, y, r0, r1, a0, a1, steps){
  steps = steps || 14;
  ctx.beginPath();
  for (let i = 0; i <= steps; i++){
    const a = lerp(a0, a1, i / steps);
    const p = CAM.project(x + Math.cos(a) * r1, y + Math.sin(a) * r1, 0);
    i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y);
  }
  for (let i = steps; i >= 0; i--){
    const a = lerp(a0, a1, i / steps);
    const p = CAM.project(x + Math.cos(a) * r0, y + Math.sin(a) * r0, 0);
    ctx.lineTo(p.x, p.y);
  }
  ctx.closePath();
}
// A ground quad along a line (line-burst / beam footprint)
function groundBandPath(x, y, ang, len, wid, from){
  const nx = -Math.sin(ang) * wid * 0.5, ny = Math.cos(ang) * wid * 0.5;
  const dx = Math.cos(ang), dy = Math.sin(ang);
  const x0 = x + dx * (from || 0), y0 = y + dy * (from || 0);
  const x1 = x + dx * len,         y1 = y + dy * len;
  const steps = 10;
  ctx.beginPath();
  for (let i = 0; i <= steps; i++){
    const t = i / steps;
    const p = CAM.project(lerp(x0, x1, t) + nx, lerp(y0, y1, t) + ny, 0);
    i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y);
  }
  for (let i = steps; i >= 0; i--){
    const t = i / steps;
    const p = CAM.project(lerp(x0, x1, t) - nx, lerp(y0, y1, t) - ny, 0);
    ctx.lineTo(p.x, p.y);
  }
  ctx.closePath();
}

/* ---------------------------------------------------------------------------
   RENDER — drawing helpers
--------------------------------------------------------------------------- */
let _flash = false;
function C(c){ return _flash ? '#FFFFFF' : c; }
function ink(){ return _flash ? '#FFFFFF' : PAL.ink; }

function rr(x, y, w, h, r){
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y,     x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x,     y + h, r);
  ctx.arcTo(x,     y + h, x,     y,     r);
  ctx.arcTo(x,     y,     x + w, y,     r);
  ctx.closePath();
}
function fillStroke(fill, stroke, lw){
  if (fill){ ctx.fillStyle = fill; ctx.fill(); }
  if (stroke){ ctx.strokeStyle = stroke; ctx.lineWidth = lw || 3; ctx.stroke(); }
}
function ell(x, y, rx, ry, rot){
  ctx.beginPath(); ctx.ellipse(x, y, Math.max(0.1,rx), Math.max(0.1,ry), rot || 0, 0, TAU);
}
function circ(x, y, r){ ctx.beginPath(); ctx.arc(x, y, Math.max(0.1,r), 0, TAU); }

function hexToRgba(hex, a){
  if (hex[0] !== '#') return hex;
  let h = hex.slice(1);
  if (h.length === 3) h = h[0]+h[0]+h[1]+h[1]+h[2]+h[2];
  const n = parseInt(h, 16);
  return 'rgba(' + ((n>>16)&255) + ',' + ((n>>8)&255) + ',' + (n&255) + ',' + a + ')';
}
const _glowCache = new Map();
const GLOW_R = 64;
function glowSprite(col){
  let cn = _glowCache.get(col);
  if (cn) return cn;
  cn = document.createElement('canvas');
  cn.width = cn.height = GLOW_R * 2;
  const g2 = cn.getContext('2d');
  const gr = g2.createRadialGradient(GLOW_R, GLOW_R, 0, GLOW_R, GLOW_R, GLOW_R);
  gr.addColorStop(0,    hexToRgba(col, 1));
  gr.addColorStop(0.26, hexToRgba(col, 0.7));
  gr.addColorStop(0.6,  hexToRgba(col, 0.2));
  gr.addColorStop(1,    hexToRgba(col, 0));
  g2.fillStyle = gr; g2.fillRect(0, 0, GLOW_R*2, GLOW_R*2);
  _glowCache.set(col, cn);
  return cn;
}
function drawGlow(x, y, r, col, alpha){
  if (r <= 0) return;
  const a = alpha === undefined ? 1 : alpha;
  if (a <= 0) return;
  const prev = ctx.globalAlpha;
  ctx.globalAlpha = prev * Math.min(1, a);
  ctx.drawImage(glowSprite(col), x - r, y - r, r * 2, r * 2);
  ctx.globalAlpha = prev;
}

function setFont(px, weight, condensed){
  ctx.font = (weight || 700) + ' ' + px + 'px ' +
    (condensed ? "Impact, Haettenschweiler, 'Arial Narrow', 'Franklin Gothic Bold', sans-serif"
               : "'Trebuchet MS', system-ui, sans-serif");
}
function textOut(t, x, y, fill, outline, lw, align){
  ctx.textAlign = align || 'center';
  ctx.textBaseline = 'middle';
  if (outline){ ctx.lineWidth = lw || 5; ctx.lineJoin = 'round'; ctx.strokeStyle = outline; ctx.strokeText(t, x, y); }
  ctx.fillStyle = fill; ctx.fillText(t, x, y);
}

const _spriteCache = new Map();
function withCtx(c, fn){ const prev = ctx; ctx = c; try { fn(); } finally { ctx = prev; } }
function cachedSprite(key, w, h, draw){
  let cn = _spriteCache.get(key);
  if (cn) return cn;
  cn = document.createElement('canvas');
  cn.width = Math.max(2, Math.ceil(w)); cn.height = Math.max(2, Math.ceil(h));
  const c2 = cn.getContext('2d');
  withCtx(c2, () => draw(c2, cn.width, cn.height));
  _spriteCache.set(key, cn);
  return cn;
}

/* The two-source lighting rule from §1.2, applied as a post-pass so every
   procedurally drawn asset is lit identically and they all sit in one world:
   cool steel-blue rim from upper-left, warm lantern amber from lower-right. */
function applyTwoSourceLight(c2, w, h){
  c2.save();
  c2.globalCompositeOperation = 'source-atop';
  const cool = c2.createLinearGradient(0, 0, w * 0.9, h * 0.9);
  cool.addColorStop(0,    hexToRgba(PAL.moon, 0.60));
  cool.addColorStop(0.35, hexToRgba(PAL.moon, 0.18));
  cool.addColorStop(1,    hexToRgba(PAL.moon, 0));
  c2.fillStyle = cool; c2.fillRect(0, 0, w, h);
  const warm = c2.createLinearGradient(w, h, w * 0.15, h * 0.1);
  warm.addColorStop(0,    hexToRgba(PAL.lantern, 0.52));
  warm.addColorStop(0.42, hexToRgba(PAL.lantern, 0.14));
  warm.addColorStop(1,    hexToRgba(PAL.lantern, 0));
  c2.fillStyle = warm; c2.fillRect(0, 0, w, h);
  // just enough base darkening to keep them anchored, not enough to lose them
  const deep = c2.createLinearGradient(0, 0, 0, h);
  deep.addColorStop(0, 'rgba(13,11,18,0)');
  deep.addColorStop(1, 'rgba(13,11,18,0.18)');
  c2.fillStyle = deep; c2.fillRect(0, 0, w, h);
  c2.restore();
}
