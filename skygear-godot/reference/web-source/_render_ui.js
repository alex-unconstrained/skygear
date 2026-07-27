/* ============================================================================
   WIDGETS — an immediate-mode layer for the screens that have controls
   ----------------------------------------------------------------------------
   Everything before v10 was a screen you dismissed with any key, so there was
   nothing to click and no need for this. v10 has a results screen, a pause
   menu, a settings panel and a key rebinder, and those need buttons that can
   be hovered, clicked, focused and reached from the keyboard.

   Immediate mode rather than retained: a widget is a function call inside the
   draw pass, identified by where it is on screen. There is no widget tree to
   keep in step with game state, which is the whole class of bug this avoids —
   a menu can never show a stale value because there is nowhere to cache one.

   Keyboard focus is the one piece of state that has to persist between frames,
   because "which control is selected" is not derivable from the mouse. It is
   stored per screen id and reset when the screen changes, so opening settings
   and coming back does not land you on a control you cannot see.
============================================================================ */
const UI = {
  screen: null,        // id of the screen currently drawing
  focus: 0,            // index of the keyboard-focused control on this screen
  count: 0,            // controls drawn so far this frame
  lastCount: 0,        // how many the previous frame had, for wrapping
  hot: -1,             // index the mouse is over
  activated: -1,       // index activated this frame (click or Enter)
  usingKeys: false,    // hides the focus ring until the keyboard is used
  _hoverWas: -1,

  /* Call once at the top of a screen's draw. Changing screens resets focus. */
  begin(id){
    if (this.screen !== id){ this.screen = id; this.focus = 0; this.usingKeys = false; }
    this.count = 0;
    this.hot = -1;
    this.activated = -1;
    // Arrow keys and Tab move focus; Enter and Space fire it. Mouse users never
    // see any of this because the ring only appears once a key has been used.
    const dn = keyHit('arrowdown') || keyHit('s') || (keyHit('tab') && !keyDown('shift'));
    const up = keyHit('arrowup')   || keyHit('w') || (keyHit('tab') &&  keyDown('shift'));
    if (dn || up){
      this.usingKeys = true;
      const n = Math.max(1, this.lastCount);
      this.focus = ((this.focus + (dn ? 1 : -1)) % n + n) % n;
      SFX.uiHover();
    }
    this._fire = keyHit('enter') || keyHit(' ') || keyHit('space');
    this._left = keyHit('arrowleft') || keyHit('a');
    this._right = keyHit('arrowright') || keyHit('d');
  },
  end(){
    this.lastCount = this.count;
    if (this.hot !== this._hoverWas){
      if (this.hot >= 0) SFX.uiHover();
      this._hoverWas = this.hot;
    }
  },
  /* Reserve an index without drawing anything — used by controls that draw
     themselves, like the volume rows. */
  next(){ return this.count++; },

  inside(r){
    return Input.mouse.sx >= r.x && Input.mouse.sx <= r.x + r.w &&
           Input.mouse.sy >= r.y && Input.mouse.sy <= r.y + r.h;
  },
  /* Returns { hover, focused, fired } for a rect. `fired` is true on the frame
     the control is activated by either device. */
  probe(r){
    const i = this.count++;
    const hover = this.inside(r);
    if (hover){
      this.hot = i;
      // Moving the mouse takes focus back from the keyboard, so Enter always
      // fires whatever is visibly highlighted.
      if (Input.mouse.sx !== this._mx || Input.mouse.sy !== this._my){
        this.focus = i; this.usingKeys = false;
      }
    }
    const focused = this.focus === i;
    const fired = (hover && Input.clicked) || (focused && this.usingKeys && this._fire);
    if (fired) this.activated = i;
    return { i, hover, focused, fired };
  },
  frameEnd(){ this._mx = Input.mouse.sx; this._my = Input.mouse.sy; },
};

/* A button. `kind` picks the weight: 'primary' is the one thing the screen
   wants you to do, and there is never more than one on a screen. */
function uiButton(x, y, w, h, label, kind, opt){
  opt = opt || {};
  const HS = hudScale();
  const st = UI.probe({ x, y, w, h });
  const primary = kind === 'primary';
  const disabled = !!opt.disabled;
  const lit = (st.hover || (st.focused && UI.usingKeys)) && !disabled;

  const edge = disabled ? '#4A4655' : primary ? PAL.crit : PAL.brass;
  const fill = primary ? (lit ? '#3A2E14' : '#241D0F') : (lit ? '#241F30' : '#171522');

  ctx.save();
  if (lit){ ctx.shadowColor = edge; ctx.shadowBlur = 18; }
  rr(x, y, w, h, 9 * HS);
  ctx.fillStyle = fill; ctx.fill();
  ctx.restore();
  rr(x, y, w, h, 9 * HS);
  ctx.strokeStyle = PAL.ink; ctx.lineWidth = 4 * HS; ctx.stroke();
  rr(x + 3 * HS, y + 3 * HS, w - 6 * HS, h - 6 * HS, 7 * HS);
  ctx.strokeStyle = edge; ctx.lineWidth = (primary ? 2.6 : 2) * HS; ctx.stroke();

  setFont(Math.round((primary ? 20 : 17) * HS), primary ? 900 : 800, true);
  textOut(label, x + w / 2, y + h / 2,
          disabled ? '#6A6478' : primary ? PAL.crit : PAL.bone, PAL.ink, 4 * HS);
  if (opt.hint){
    setFont(Math.round(11 * HS), 700, false);
    textOut(opt.hint, x + w / 2, y + h - 9 * HS, '#7E778C');
  }
  if (st.fired && !disabled) SFX.uiClick();
  return st.fired && !disabled;
}

/* A labelled row that steps through a list of choices with < >. Used for every
   setting that is not a volume: VFX level, HUD scale, reduced motion. Discrete
   steps rather than a slider because they are the values worth having and a
   slider invites hunting for a value that does not exist. */
function uiChoice(x, y, w, label, values, current, onPick){
  const HS = hudScale();
  const h = 34 * HS;
  const st = UI.probe({ x, y, w, h });
  const lit = st.hover || (st.focused && UI.usingKeys);
  let idx = Math.max(0, values.findIndex(v => v.value === current));

  setFont(Math.round(14.5 * HS), 700, false);
  textOut(label, x, y + h / 2, lit ? PAL.bone : '#A79EB4', null, 0, 'left');

  const bw = 26 * HS, vx = x + w - 190 * HS;
  const step = (d) => {
    const n = (idx + d + values.length) % values.length;
    onPick(values[n].value);
    SFX.uiClick();
  };
  // The arrows are their own hit targets; the row itself cycles forward, so a
  // click anywhere on it still does the obvious thing. Drawn as triangles
  // rather than typed as < > — the condensed display face renders those as
  // something much closer to brackets.
  const lHit = { x: vx - bw, y, w: bw, h }, rHit = { x: x + w - bw, y, w: bw, h };
  const arrow = (cx, dir) => {
    const s2 = 5 * HS;
    ctx.fillStyle = lit ? PAL.teal : '#6E667A';
    ctx.beginPath();
    ctx.moveTo(cx + dir * s2, y + h / 2 - s2);
    ctx.lineTo(cx + dir * s2, y + h / 2 + s2);
    ctx.lineTo(cx - dir * s2 * 0.9, y + h / 2);
    ctx.closePath(); ctx.fill();
  };
  arrow(lHit.x + bw / 2, 1);
  arrow(rHit.x + bw / 2, -1);
  setFont(Math.round(15 * HS), 800, true);
  textOut(values[idx].label, (vx + x + w - bw) / 2, y + h / 2, PAL.teal, PAL.ink, 3 * HS);

  if (st.hover && Input.clicked) step(UI.inside(lHit) ? -1 : 1);
  else if (st.focused && UI.usingKeys){
    if (UI._left) step(-1);
    else if (UI._right || UI._fire) step(1);
  }
  return h;
}

/* A volume row: a bar you can click or drag, with the percentage beside it.
   Dragging matters — setting a mix by clicking one point at a time is how you
   end up never touching it. */
function uiSlider(x, y, w, label, value, onSet){
  const HS = hudScale();
  const h = 34 * HS;
  const st = UI.probe({ x, y, w, h });
  const lit = st.hover || (st.focused && UI.usingKeys);

  setFont(Math.round(14.5 * HS), 700, false);
  textOut(label, x, y + h / 2, lit ? PAL.bone : '#A79EB4', null, 0, 'left');

  const bx = x + w - 232 * HS, bw = 160 * HS, by = y + h / 2 - 5 * HS, bh = 10 * HS;
  rr(bx, by, bw, bh, bh / 2);
  ctx.fillStyle = '#100E17'; ctx.fill();
  ctx.strokeStyle = PAL.ink; ctx.lineWidth = 2 * HS; ctx.stroke();
  rr(bx, by, Math.max(bh, bw * value), bh, bh / 2);
  ctx.fillStyle = lit ? PAL.teal : '#2E9E8A'; ctx.fill();
  circ(bx + bw * value, by + bh / 2, 7 * HS);
  ctx.fillStyle = PAL.bone; ctx.fill();
  ctx.strokeStyle = PAL.ink; ctx.lineWidth = 2.4 * HS; ctx.stroke();

  setFont(Math.round(13 * HS), 800, true);
  textOut(Math.round(value * 100) + '%', x + w - 20 * HS, y + h / 2, PAL.bone, null, 0, 'right');

  // Held, not clicked: this is the drag.
  if (st.hover && Input.buttons[0]){
    onSet(clamp((Input.mouse.sx - bx) / bw, 0, 1));
  } else if (st.focused && UI.usingKeys){
    if (UI._left) onSet(clamp(value - 0.05, 0, 1));
    else if (UI._right) onSet(clamp(value + 0.05, 0, 1));
  }
  return h;
}

/* A checkbox row. */
function uiToggle(x, y, w, label, value, onSet){
  const HS = hudScale();
  const h = 34 * HS;
  const st = UI.probe({ x, y, w, h });
  const lit = st.hover || (st.focused && UI.usingKeys);
  setFont(Math.round(14.5 * HS), 700, false);
  textOut(label, x, y + h / 2, lit ? PAL.bone : '#A79EB4', null, 0, 'left');
  const bs = 20 * HS, bx = x + w - bs - 8 * HS, by = y + h / 2 - bs / 2;
  rr(bx, by, bs, bs, 5 * HS);
  ctx.fillStyle = '#100E17'; ctx.fill();
  ctx.strokeStyle = value ? PAL.teal : '#5A5366'; ctx.lineWidth = 2.4 * HS; ctx.stroke();
  if (value){
    ctx.strokeStyle = PAL.teal; ctx.lineWidth = 3 * HS; ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(bx + bs * 0.24, by + bs * 0.52);
    ctx.lineTo(bx + bs * 0.44, by + bs * 0.74);
    ctx.lineTo(bx + bs * 0.78, by + bs * 0.26);
    ctx.stroke();
  }
  if (st.fired){ onSet(!value); SFX.uiClick(); }
  return h;
}

/* Section heading inside a panel. Not a control — it takes no focus index. */
function uiHeading(x, y, w, text){
  const HS = hudScale();
  setFont(Math.round(12 * HS), 800, true);
  ctx.letterSpacing = '2px';
  textOut(text, x, y + 12 * HS, PAL.brass, null, 0, 'left');
  ctx.letterSpacing = '0px';
  ctx.strokeStyle = hexToRgba(PAL.brass, 0.28); ctx.lineWidth = 1.5 * HS;
  ctx.beginPath();
  ctx.moveTo(x + ctx.measureText(text).width + 14 * HS, y + 12 * HS);
  ctx.lineTo(x + w, y + 12 * HS);
  ctx.stroke();
  return 28 * HS;
}
