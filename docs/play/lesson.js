// The technique pages' lesson player: plays an app lesson file
// (assets/data/lessons/<id>.json, copied to docs/play/lessons/ by
// tool/generate_technique_pages.dart) the way the app's ScriptedLessonScreen
// does, from the same data (decision 0066; the contract is
// tool/lesson_export/SCHEMA.md). Plain script, no build step, loaded only when
// the reader presses the page's start button.
//
// The board is the mockup's own CSS: every primitive item becomes an
// absolutely positioned div carrying the item's box, borders, backgrounds and
// animations, so the browser paints it as it painted the approved mockup.
// tool/lesson_compare/web_candidate.js renders it settled for diff.js.
(function () {
  'use strict';

  const BOX_W = 358, BOX_H = 380;
  const BASE = ['bg', 'grid', 'border'];
  const PAIRS = [['r', 'c'], ['r1', 'c1'], ['r2', 'c2']];
  const BOARD_CELL = /^[0-8],[0-8]$/;
  const HANGUL = /[가-힣]/;

  // ------------------------------------------------------------ lesson file

  // Puts every string the lesson shows through its English table
  // (assets/data/lessons/en/<id>.json), as lib/lesson_script/lesson.dart's
  // _translate does. A string the table lacks stays Korean.
  function translate(j, en) {
    const tr = (s) => (typeof s === 'string' && HANGUL.test(s) && en[s] ? en[s] : s);
    const view = (v) => {
      for (const k of ['body', 'msg']) if (k in v) v[k] = tr(v[k]);
      for (const s of v.steps || []) s.text = tr(s.text);
    };
    for (const k of ['appTitle', 'stageLabel', 'lastLabel']) j[k] = tr(j[k]);
    for (const p of j.pages) {
      for (const b of p.beats) {
        if (b.kind === 'static') view(b);
        else if (b.exploded) view(b.opening);
        else for (const a of [b.automaton, b.then]) if (a) a.views.forEach(view);
      }
    }
    for (const refs of Object.values(j.prims)) {
      for (const items of Object.values(refs)) for (const it of items) if ('text' in it) it.text = tr(it.text);
    }
  }

  function wholeView(v) {
    return {
      body: v.body,
      steps: v.steps || [],
      hl: v.hl || null,
      msg: v.msg || '',
      ok: v.msg ? v.ok : true,
      done: v.done === undefined ? true : v.done,
      draw: v.draw,
    };
  }

  // A find machine (SCHEMA.md section 8). `canon` caches each state's
  // canonical view, built in state order on demand.
  function machine(a) {
    if (!a.views[a.initial[0]].draw) throw new Error('the opening view is not whole');
    return { initial: a.initial, states: a.states, views: a.views, canon: [wholeView(a.views[a.initial[0]])] };
  }

  function parseBeat(b) {
    if (b.kind === 'static') return { kind: 'static', view: wholeView(b) };
    if (b.kind !== 'task' || b.task !== true) throw new Error('beat kind ' + b.kind);
    if (b.exploded) return { kind: 'exploded', view: wholeView(b.opening) };
    return { kind: 'task', a: machine(b.automaton), b: b.then ? machine(b.then) : null };
  }

  function parseLesson(j, en) {
    if (en) translate(j, en);
    const lesson = {
      id: j.id,
      appTitle: j.appTitle,
      stageLabel: j.stageLabel,
      msgPreLine: !!j.msgPreLine,
      layers: j.layers,
      recapGlow: j.recapGlow || null,
      coupling: j.coupling || {},
      keyframes: j.keyframes,
      prims: j.prims,
      pages: j.pages.map((p) => p.beats.map(parseBeat)),
    };
    for (const beats of lesson.pages) {
      for (const b of beats) {
        const opening = b.kind === 'task' ? b.a.canon[0] : b.view;
        for (const ref of composeRefs(lesson, opening.draw, opening.hl)) itemsOf(lesson, opening.draw, ref);
      }
    }
    return lesson;
  }

  // ------------------------------------------------------------ views and the find machine

  function editDraw(draw, diff, cell) {
    const [R, C] = cell.split(',').map(Number);
    const place = (e) => {
      let o = e;
      for (const [rk, ck] of PAIRS) {
        if (e[rk] !== '@r') continue;
        if (o === e) o = Object.assign({}, e);
        o[rk] = R;
        o[ck] = C;
      }
      return o;
    };
    const out = Object.assign({}, draw);
    for (const [k, op] of Object.entries(diff)) {
      if (op === null) delete out[k];
      else if (!Array.isArray(op)) out[k] = op.set;
      else {
        const list = (out[k] || []).slice();
        list.splice(op[0], op[1], ...op[2].map(place));
        out[k] = list;
      }
    }
    return out;
  }

  function applyEdit(base, e, cell) {
    return {
      body: 'body' in e ? e.body : base.body,
      steps: 'steps' in e ? e.steps || [] : base.steps,
      hl: 'hl' in e ? e.hl : base.hl,
      msg: e.msg,
      ok: e.msg ? e.ok : true,
      done: e.done,
      draw: editDraw(base.draw, e.diff, cell),
    };
  }

  function edgeAt(st, cell) {
    const e = cell in st.taps ? st.taps[cell] : BOARD_CELL.test(cell) ? st.taps['*'] : undefined;
    if (!e || e === '.') return null;
    return { view: e[0], state: e[1], restart: e.length < 3 };
  }

  function canonical(m, s) {
    while (m.canon.length <= s) {
      const [q, cell] = m.states[m.canon.length].from;
      m.canon.push(showEdge(m, q, edgeAt(m.states[q], cell), cell));
    }
    return m.canon[s];
  }

  function showEdge(m, q, edge, cell) {
    const spec = m.views[edge.view];
    return spec.draw ? wholeView(spec) : applyEdit(canonical(m, q), spec, cell);
  }

  const withCarry = (v, carry) => Object.assign({}, v, { draw: Object.assign({}, v.draw, carry) });

  // A find beat in play: {phase: 'a' | 'b', state, carry, shown}. Phase b
  // is the second machine of a two-phase beat (SCHEMA.md section 8.1).
  function findStart(beat) {
    const state = beat.a.initial[1];
    return { phase: 'a', state, carry: null, shown: canonical(beat.a, state) };
  }

  // The find after a tap on `cell`, or null when the tap does nothing.
  function findTap(beat, f, cell) {
    const m = beat[f.phase];
    const edge = edgeAt(m.states[f.state], cell);
    if (!edge) return null;
    const v = showEdge(m, f.state, edge, cell);
    const shown = f.carry ? withCarry(v, f.carry) : v;
    const carry = m.states[edge.state].carry;
    const next = carry
      ? { phase: 'b', state: beat.b.initial[1], carry, shown }
      : { phase: f.phase, state: edge.state, carry: f.carry, shown };
    return { f: next, restart: edge.restart };
  }

  // The button under (x, y), board css px: a board cell, or a button the
  // state lists off the board (the 1~9 strip), each the S x S square at (cS, rS).
  function cellAt(beat, f, x, y) {
    const S = f.shown.draw.S;
    const r = Math.floor(y / S), c = Math.floor(x / S);
    if (r >= 0 && r <= 8 && c >= 0 && c <= 8) return r + ',' + c;
    for (const cell of Object.keys(beat[f.phase].states[f.state].taps)) {
      const rc = cell.split(',');
      if (rc.length !== 2) continue;
      const top = +rc[0] * S, left = +rc[1] * S;
      if (x >= left && x < left + S && y >= top && y < top + S) return cell;
    }
    return null;
  }

  // ------------------------------------------------------------ navigation

  // The page as a reducer: {page, beat, find, taps}. `find` is the find beat
  // in play (null elsewhere); `taps` keeps every find beat's handled taps by
  // "page,beat", replayed when the reader comes back so a finished find
  // shows finished.
  function enterBeat(lesson, page, beat, taps) {
    const b = lesson.pages[page][beat];
    let find = null;
    if (b.kind === 'task') {
      find = findStart(b);
      for (const cell of taps[page + ',' + beat] || []) find = findTap(b, find, cell).f;
    }
    return { page, beat, find, taps };
  }

  const beatOf = (lesson, s) => lesson.pages[s.page][s.beat];
  const viewOf = (lesson, s) => (s.find ? s.find.shown : beatOf(lesson, s).view);
  const blocked = (lesson, s) => beatOf(lesson, s).kind !== 'static' && !viewOf(lesson, s).done;
  const onLast = (lesson, s) => s.page === lesson.pages.length - 1 && s.beat === lesson.pages[s.page].length - 1;

  // {s, enter} after an action, or null when it changes nothing. `enter`:
  // a new beat, every motion from the start; otherwise `restart` says
  // whether a tap replays the motion of the view it shows.
  function reduce(lesson, s, action) {
    switch (action.type) {
      case 'next': {
        if (blocked(lesson, s) || onLast(lesson, s)) return null;
        const last = s.beat + 1 >= lesson.pages[s.page].length;
        return { s: enterBeat(lesson, last ? s.page + 1 : s.page, last ? 0 : s.beat + 1, s.taps), enter: true };
      }
      case 'prev':
        if (s.beat > 0) return { s: enterBeat(lesson, s.page, s.beat - 1, s.taps), enter: true };
        if (s.page > 0) return { s: enterBeat(lesson, s.page - 1, lesson.pages[s.page - 1].length - 1, s.taps), enter: true };
        return null;
      case 'tap': {
        if (!s.find) return null;
        const r = findTap(beatOf(lesson, s), s.find, action.cell);
        if (!r) return null;
        const key = s.page + ',' + s.beat;
        const taps = Object.assign({}, s.taps, { [key]: (s.taps[key] || []).concat([action.cell]) });
        return { s: { page: s.page, beat: s.beat, find: r.f, taps }, enter: false, restart: r.restart };
      }
      case 'restart':
        return { s: enterBeat(lesson, 0, 0, {}), enter: true };
      case 'goto':
        return { s: enterBeat(lesson, action.page, action.beat, s.taps), enter: true };
      default:
        throw new Error('action ' + action.type);
    }
  }

  // ------------------------------------------------------------ refs and scenes

  const globalsKey = (draw) => [draw.S, draw.x || 0, draw.y || 0, draw.dimGivens ? 1 : 0].join('|');

  function itemsOf(lesson, draw, ref) {
    const items = (lesson.prims[globalsKey(draw)] || {})[ref];
    if (!items) throw new Error(lesson.id + ': ref ' + ref + ' is not in prims[' + globalsKey(draw) + ']');
    return items;
  }

  // From tool/lesson_export/prims.js, which the exporter proves equal to the
  // mockup's drawBoard. The two must agree string for string.
  const passFilter = {
    above: (e) => !!(e.a && e.a.above),
    '!above': (e) => !(e.a && e.a.above),
    red: (e) => e.kind === 'red',
    '!red': (e) => e.kind !== 'red',
  };

  function coupledNote(entry, draw, coupling) {
    if (!coupling) return null;
    const [rk, ck] = coupling.at;
    return (draw[coupling.from] || []).find((n) => n.r === entry[rk] && n.c === entry[ck]) || null;
  }

  function stripDigit(strip, d) {
    const s = {};
    if (strip.crossed && strip.crossed[d] !== undefined) s.crossed = { [d]: strip.crossed[d] };
    if (strip.hi === d) {
      s.hi = d;
      if (strip.hiAnim !== undefined) s.hiAnim = strip.hiAnim;
    }
    return s;
  }

  function composeRefs(lesson, draw, hl) {
    const refs = [];
    for (const layer of lesson.layers) {
      if (BASE.includes(layer)) {
        refs.push(layer);
        continue;
      }
      const [key, pass] = layer.split(':');
      if (key === 'strip') {
        if (draw.strip) for (let d = 1; d <= 9; d++) refs.push('strip|' + d + '|' + JSON.stringify(stripDigit(draw.strip, d)));
        continue;
      }
      const keep = pass ? passFilter[pass] : null;
      if (pass && !keep) throw new Error('layer pass ' + layer);
      for (const e of draw[key] || []) {
        if (keep && !keep(e)) continue;
        const dep = coupledNote(e, draw, lesson.coupling[key]);
        refs.push(key + '|' + JSON.stringify(e) + (dep ? '|' + JSON.stringify(dep) : ''));
      }
    }
    if (hl && lesson.recapGlow) {
      hl.forEach((line, k) => line.forEach((piece) => refs.push('hl|' + k + '|' + hl.length + '|' + JSON.stringify(piece))));
    }
    return refs;
  }

  // A view's refs with two clocks each (seconds): `started`, when its
  // motions last (re)started, and `appeared`, when it first showed in an
  // unbroken run of views, which `fixed` motions count from.
  function sceneEnter(lesson, view, now) {
    return { view, placed: composeRefs(lesson, view.draw, view.hl).map((ref) => ({ ref, started: now, appeared: now })) };
  }

  function sceneShow(lesson, scene, view, restart, now) {
    const before = new Map();
    for (const p of scene.placed) {
      if (!before.has(p.ref)) before.set(p.ref, []);
      before.get(p.ref).push(p);
    }
    return {
      view,
      placed: composeRefs(lesson, view.draw, view.hl).map((ref) => {
        const old = before.has(ref) ? before.get(ref).shift() : undefined;
        if (!old) return { ref, started: now, appeared: now };
        return { ref, started: restart ? now : old.started, appeared: old.appeared };
      }),
    };
  }

  // ------------------------------------------------------------ motion

  // tool/lesson_compare/README.md, "The final-state rule".
  const REST = ['twinkle', 'doom', 'stepb', 'stepc'];
  const SHOWN = ['hl', 'hlb', 'cyc', 'altA', 'altFA', 'blinkA'];
  const PARTNER = { altB: 'altA', altFB: 'altFA', blinkB: 'blinkA' };

  function plateau(keyframes, name) {
    const pts = [];
    for (const f of keyframes[name]) for (const at of f.at) pts.push([at / 100, f.props.opacity]);
    pts.sort((a, b) => a[0] - b[0]);
    for (let i = 0; i + 1 < pts.length; i++) if (pts[i][1] === 1 && pts[i + 1][1] === 1) return (pts[i][0] + pts[i + 1][0]) / 2;
    throw new Error('@keyframes ' + name + ' never holds opacity 1');
  }

  // The settled moment, seconds into the motion: every finite motion at its
  // end, every infinite one at the phase the comparison harness names.
  function settledTime(keyframes, a) {
    if (a.count !== null) return a.delay + a.dur * a.count;
    let phase;
    if (REST.includes(a.name)) phase = 0;
    else if (SHOWN.includes(a.name)) phase = plateau(keyframes, a.name);
    else if (PARTNER[a.name]) phase = plateau(keyframes, PARTNER[a.name]);
    else throw new Error('no final-state rule for infinite animation ' + a.name);
    return a.delay + phase * a.dur;
  }

  // The live board's emphasis, lib/lesson_script/motion.dart: finite motions
  // a little slower, lines easing in and out, a stronger swell for pop and
  // erase, and a halo when a highlight lands. Every change keeps a motion's
  // first and last keyframe, so a piece rests exactly as the mockup leaves it.
  const STRETCH = 1.3;
  const TRAVEL = [0.4, 0, 0.2, 1];
  const MIDDLES = {
    pop: [{ at: [55], props: { opacity: 1, transform: [{ op: 'scale', v: 1.4 }] } }, { at: [80], props: { transform: [{ op: 'scale', v: 0.94 }] } }],
    erase: [{ at: [30], props: { opacity: 1, transform: [{ op: 'scale', v: 1.85 }] } }],
  };
  const HALO_KEYS = ['rings', 'frames', 'marks', 'groups', 'rects'];
  const ARRIVALS = ['pop', 'drawbox', 'grp', 'fade'];

  function liveAnim(a) {
    if (a.count === null) return a;
    return Object.assign({}, a, {
      live: !!MIDDLES[a.name],
      dur: a.dur * STRETCH,
      delay: a.delay * STRETCH,
      ease: a.name === 'grow' ? TRAVEL : a.ease,
    });
  }

  // The halo's start (seconds after the motion started) and colour, or null.
  function haloOf(ref, it) {
    if (!HALO_KEYS.includes(ref.split('|')[0])) return null;
    const side = (it.border || []).find((s) => s);
    const arrivals = (it.an || []).filter((a) => a.count !== null && ARRIVALS.includes(a.name));
    if (!side || !arrivals.length) return null;
    return { at: Math.max(...arrivals.map((a) => (a.delay + a.dur * a.count * 0.6) * STRETCH)), c: side.c };
  }

  // ------------------------------------------------------------ CSS from the typed items (SCHEMA.md 11.3)

  function colour(c, alpha) {
    const a = ((c >>> 24) / 255) * (alpha === undefined ? 1 : alpha);
    const rgb = ((c >>> 16) & 255) + ',' + ((c >>> 8) & 255) + ',' + (c & 255);
    return a >= 1 ? 'rgb(' + rgb + ')' : 'rgba(' + rgb + ',' + +a.toFixed(4) + ')';
  }

  const len = (l) => l[0] + (l[1] ? '%' : 'px');

  function tfCss(ops) {
    if (!ops.length) return 'none';
    return ops.map((o) => {
      if (o.op === 'rotate') return 'rotate(' + (typeof o.v === 'object' ? 'var(' + o.v.var + ')' : o.v + 'deg') + ')';
      if (o.op === 'scale' || o.op === 'scaleX') return o.op + '(' + o.v + ')';
      throw new Error('transform ' + o.op);
    }).join(' ');
  }

  function bgCss(layers) {
    return layers.map((l, i) => {
      if (l.k === 'solid') return i === layers.length - 1 ? colour(l.c) : 'linear-gradient(' + colour(l.c) + ',' + colour(l.c) + ')';
      const stops = l.stops.map(([c, pos, pct]) => colour(c) + (pos === null ? '' : ' ' + pos + (pct ? '%' : 'px')));
      return (l.k === 'rep' ? 'repeating-' : '') + 'linear-gradient(' + l.deg + 'deg,' + stops.join(',') + ')';
    }).join(',');
  }

  function propsCss(p) {
    const out = [];
    for (const [k, v] of Object.entries(p)) {
      if (k === 'opacity') out.push('opacity:' + v);
      else if (k === 'transform') out.push('transform:' + tfCss(v));
      else if (k === 'color') out.push('color:' + (typeof v === 'object' ? 'var(' + v.var + ')' : colour(v)));
      else if (k === 'fontWeight') out.push('font-weight:' + v);
      else if (k === 'clip') out.push('clip-path:inset(' + v.map((x) => x + '%').join(' ') + ')');
      else if (k === 'boxShadow') out.push('box-shadow:' + v.map((s) => s.dx + 'px ' + s.dy + 'px ' + s.blur + 'px ' + s.spread + 'px ' + colour(s.c)).join(','));
      else throw new Error('keyframe property ' + k);
    }
    return out.join(';');
  }

  const framesCss = (name, frames) =>
    '@keyframes ' + name + '{' + frames.map((f) => f.at.map((a) => a + '%').join(',') + '{' + propsCss(f.props) + '}').join('') + '}';

  // Keyframe names are per lesson ([kp] is the lesson id): two lessons on one
  // page can define the same name with different frames.
  function keyframesSheet(keyframes, kp) {
    let css = '';
    for (const [name, frames] of Object.entries(keyframes)) {
      css += framesCss('sl-' + kp + name, frames);
      if (MIDDLES[name]) css += framesCss('sl-live-' + kp + name, [frames[0]].concat(MIDDLES[name], [frames[frames.length - 1]]));
    }
    return css;
  }

  const animCss = (a, kp) =>
    (a.live ? 'sl-live-' : 'sl-') + kp + a.name + ' ' + a.dur + 's cubic-bezier(' + a.ease.join(',') + ') ' + a.delay + 's ' +
    (a.count === null ? 'infinite' : a.count) + ' ' + a.fill;

  function itemCss(it, anims, kp) {
    const s = ['left:' + (it.x || 0) + 'px', 'top:' + (it.y || 0) + 'px', 'width:' + (it.w || 0) + 'px', 'height:' + (it.h || 0) + 'px'];
    if (it.bb) s.push('box-sizing:border-box');
    if (it.bg) s.push('background:' + bgCss(it.bg));
    if (it.border) {
      ['top', 'right', 'bottom', 'left'].forEach((side, i) => {
        const b = it.border[i];
        if (b) s.push('border-' + side + ':' + b.w + 'px ' + b.s + ' ' + colour(b.c));
      });
    }
    if (it.rad) s.push('border-radius:' + it.rad.slice(0, 4).map(len).join(' ') + '/' + it.rad.slice(4).map(len).join(' '));
    if (it.o !== undefined) s.push('opacity:' + it.o);
    for (const [k, v] of Object.entries(it.vars || {})) s.push(k + ':' + (k === '--a' ? v + 'deg' : colour(v)));
    if (it.tf) s.push('transform:' + tfCss(it.tf));
    if (it.org) s.push('transform-origin:' + it.org.map(len).join(' '));
    const f = it.font;
    if (f) {
      s.push('font-size:' + f.size + 'px');
      if (f.weight !== undefined) s.push('font-weight:' + f.weight);
      if (f.color !== undefined) s.push('color:' + colour(f.color));
      if (f.lh !== undefined) s.push('line-height:' + f.lh);
      if (f.center) s.push('text-align:center');
      if (f.ws) s.push('white-space:' + f.ws);
      if (f.flex) s.push('display:flex;align-items:center;justify-content:center');
    }
    if (it.padT) s.push('padding-top:' + it.padT + 'px');
    if (it.shadow) s.push('text-shadow:' + it.shadow.map((h) => h.dx + 'px ' + h.dy + 'px ' + h.blur + 'px ' + colour(h.c)).join(','));
    if (anims.length) s.push('animation:' + anims.map((a) => animCss(a, kp)).join(','));
    return s.join(';');
  }

  // ------------------------------------------------------------ the app's deviations from the mockup

  // The part of the box the app shows (lib/lesson_script/painter.dart
  // boardFrame, SCHEMA.md 11.6): a full board fills the box; a small one is
  // shown alone, with the strip's row when the lesson has a strip.
  function boardFrame(lesson, draw) {
    const side = 9 * draw.S;
    if (side > BOX_W - 8) return { x: 0, y: 0, w: BOX_W, h: BOX_H };
    const under = lesson.layers.includes('strip') ? 12 + draw.S - 4 + 2 : 0;
    return { x: draw.x || 0, y: draw.y || 0, w: side, h: side + under };
  }

  const FRAME_KEYS = ['outlines', 'frames', 'marks', 'groups'];
  const framesCells = (ref) => FRAME_KEYS.includes(ref.split('|')[0]) || /^hl\|\d+\|\d+\|\["(cell|unit)"/.test(ref);
  const painted = (w) => (w <= 0 ? 0 : w < 1 ? 1 : Math.floor(w));

  // An item's border box: Chrome lays a border out at its floored width.
  function borderBox(it) {
    if (it.bb) return { w: it.w || 0, h: it.h || 0 };
    const b = it.border || [], bw = (i) => (b[i] ? painted(b[i].w) : 0);
    return { w: (it.w || 0) + bw(1) + bw(3), h: (it.h || 0) + bw(0) + bw(2) + (it.padT || 0) };
  }

  // A frame round cells drawn less round (SCHEMA.md 11.5): the mockup's own
  // border box, every corner 0.6 as round.
  function lessRoundFrame(it) {
    if (!it.rad) return it;
    if (it.rad.some((r) => r[1])) throw new Error('a frame with a percentage radius');
    return Object.assign({}, it, borderBox(it), { bb: 1, rad: it.rad.map((r) => [r[0] * 0.6, 0]) });
  }

  // A fish lesson's row tag right of the board, drawn as the app draws it
  // (SCHEMA.md 11.6, painter.dart fishTagBadge): a badge in the top right
  // corner of the row's last cell carrying the tag's count, or null.
  function fishTagBadge(lesson, draw, ref, items) {
    if (!ref.startsWith('tags|') || items.length !== 1 || items[0].x < 9 * draw.S) return null;
    const S = draw.S;
    const tag = JSON.parse(ref.slice(5));
    const count = /^\d+/.exec(tag.text);
    if (!count) throw new Error(lesson.id + ': tag ' + tag.text + ' has no count');
    const col = (0xff000000 | parseInt(tag.col.slice(1), 16)) >>> 0;
    const d = Math.round(0.42 * S);
    const side = { w: 1.5, s: 'solid', c: col };
    const badge = {
      x: (draw.x || 0) + 9 * S - d - 2, y: (draw.y || 0) + tag.r * S + 2, w: d, h: d, bb: 1,
      font: { center: 1, size: Math.round(0.3 * S), weight: 800, color: col, flex: 1 },
      bg: [{ k: 'solid', c: 0xffffffff }],
      rad: Array(8).fill([d / 2, 0]),
      border: [side, side, side, side],
      text: count[0],
    };
    if (tag.a) badge.an = [{ name: 'pop', dur: 0.4, ease: [0, 0, 0.58, 1], delay: tag.a.delay, count: 1, fill: 'both' }];
    return [badge];
  }

  // ------------------------------------------------------------ the board

  // The board in `host`: the mockup's 358 x 380 box, scaled to the host's
  // width. opts: fitted (show boardFrame, else the whole box), lessRound
  // (11.5), settled (draw the final state, still), textOff (glyphs
  // transparent, for the geometry diff).
  function makeBoard(host, lesson, opts) {
    const port = document.createElement('div');
    port.className = 'sl-port';
    const box = document.createElement('div');
    box.className = 'sl-box' + (opts.textOff ? ' sl-textoff' : '');
    port.appendChild(box);
    host.appendChild(port);
    let frame = { x: 0, y: 0, w: BOX_W, h: BOX_H }, scale = 1;

    function fit() {
      scale = opts.fixedScale || port.clientWidth / frame.w || 1;
      if (opts.fixedScale) port.style.width = frame.w * scale + 'px';
      port.style.height = frame.h * scale + 'px';
      box.style.transform = 'scale(' + scale + ') translate(' + -frame.x + 'px,' + -frame.y + 'px)';
    }
    if (window.ResizeObserver && !opts.fixedScale) new ResizeObserver(fit).observe(port);

    function render(scene, now) {
      frame = opts.fitted ? boardFrame(lesson, scene.view.draw) : { x: 0, y: 0, w: BOX_W, h: BOX_H };
      fit();
      const draw = scene.view.draw;
      const clocks = [];
      const frag = document.createDocumentFragment();
      for (const p of scene.placed) {
        let items = itemsOf(lesson, draw, p.ref);
        if (opts.fitted) items = fishTagBadge(lesson, draw, p.ref, items) || items;
        if (opts.lessRound && framesCells(p.ref)) items = items.map(lessRoundFrame);
        for (const it of items) {
          const anims = opts.settled ? it.an || [] : (it.an || []).map(liveAnim);
          const halo = opts.settled ? null : haloOf(p.ref, it);
          if (halo) {
            const h = document.createElement('div');
            h.style.cssText = itemCss(Object.assign({ x: it.x, y: it.y, bb: 1, rad: it.rad, tf: it.tf, org: it.org, vars: it.vars }, borderBox(it)), []) +
              ';--hc:' + colour(halo.c, 0.6) + ';--hc0:' + colour(halo.c, 0) + ';animation:sl-halo .7s cubic-bezier(.33,1,.68,1) ' + halo.at + 's 1 none';
            frag.appendChild(h);
            clocks.push({ el: h, anims: [{ count: 1 }], p });
          }
          const el = document.createElement('div');
          el.style.cssText = itemCss(it, anims, lesson.id + '-');
          if (it.text !== undefined) el.textContent = it.text;
          frag.appendChild(el);
          if (anims.length) clocks.push({ el, anims, p });
        }
      }
      box.replaceChildren(frag);
      for (const { el, anims, p } of clocks) {
        el.getAnimations().forEach((run, i) => {
          const a = anims[i];
          if (opts.settled) {
            run.pause();
            run.currentTime = settledTime(lesson.keyframes, a) * 1000;
          } else run.currentTime = (now - (a.fixed ? p.appeared : p.started)) * 1000;
        });
      }
    }

    // The board css px under a viewport point.
    function at(clientX, clientY) {
      const r = port.getBoundingClientRect();
      return { x: (clientX - r.left) / scale + frame.x, y: (clientY - r.top) / scale + frame.y };
    }

    return { port, render, at };
  }

  // ------------------------------------------------------------ the card

  const ko = document.documentElement.lang !== 'en';
  const T = ko
    ? { prev: '이전', next: '다음', find: '찾아서 눌러 보세요', restart: '처음부터 다시', nextTech: '다음 기법', app: '앱에서 실전 판 풀기' }
    : { prev: 'Back', next: 'Next', find: 'Find it and tap', restart: 'Start over', nextTech: 'Next technique', app: 'Real puzzles in the app' };

  const esc = (t) => t.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

  // opts: next ({href, name} of the page's next technique, or null), app
  // (the app button's href), onApp (called on its click), plus the board's
  // options. boardOnly draws the board alone (the comparison harness).
  function mount(host, json, opts) {
    opts = Object.assign({ fitted: true, lessRound: true, settled: false, textOff: false }, opts);
    if (!opts.settled && window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches) opts.settled = true;
    const lesson = parseLesson(json, opts.strings);
    injectKeyframes(lesson);

    host.textContent = '';
    const root = document.createElement('div');
    root.className = opts.boardOnly ? 'sl-only' : 'sl';
    host.appendChild(root);
    let card = null;
    if (!opts.boardOnly) {
      root.innerHTML = '<div class="sl-head"><b>' + esc(lesson.appTitle) + '</b><span class="sl-stage">' + esc(lesson.stageLabel) + '</span></div>' +
        '<div class="sl-main"><div class="sl-boardcol"></div><div class="sl-card"></div></div>';
      card = root.querySelector('.sl-card');
    }
    const board = makeBoard(opts.boardOnly ? root : root.querySelector('.sl-boardcol'), lesson, opts);
    const clock = () => performance.now() / 1000;

    let s = enterBeat(lesson, 0, 0, {});
    let now = clock();
    let scene = sceneEnter(lesson, viewOf(lesson, s), now);
    let stepsFrom = now;

    function dispatch(action) {
      const r = reduce(lesson, s, action);
      if (!r) return false;
      s = r.s;
      now = clock();
      const view = viewOf(lesson, s);
      if (r.enter) {
        scene = sceneEnter(lesson, view, now);
        stepsFrom = now;
      } else scene = sceneShow(lesson, scene, view, r.restart, now);
      paint();
      return true;
    }

    function paint() {
      board.render(scene, now);
      board.port.classList.toggle('sl-tap', !!s.find);
      if (card) renderCard();
    }

    function renderCard() {
      const view = viewOf(lesson, s);
      const beats = lesson.pages[s.page].length;
      const isBlocked = blocked(lesson, s);
      const ending = onLast(lesson, s) && !isBlocked;
      const dots = beats > 1 ? Array.from({ length: beats }, (_, k) => '<i' + (k <= s.beat ? ' class="on"' : '') + '></i>').join('') : '';
      const msg = lesson.msgPreLine ? view.msg : view.msg.replace(/\n/g, ' ');
      let html = '<div class="sl-top"><span class="sl-pill">' + (s.page + 1) + '/' + lesson.pages.length + '</span><span class="sl-dots">' + dots + '</span></div>' +
        '<div class="sl-text" aria-live="polite">';
      if (view.body) html += '<p class="sl-body">' + esc(view.body) + '</p>';
      for (const st of view.steps) html += '<p class="sl-step">' + esc(st.text) + '</p>';
      if (msg) html += '<p class="sl-msg ' + (view.ok ? 'ok' : 'no') + '">' + esc(msg) + '</p>';
      html += '</div>';
      if (ending) {
        html += '<div class="sl-row"><button type="button" class="sl-btn line" data-act="restart">' + T.restart + '</button>' +
          (opts.next ? '<a class="sl-btn line" href="' + esc(opts.next.href) + '">' + T.nextTech + '</a>' : '') + '</div>';
      }
      html += '<div class="sl-row"><button type="button" class="sl-btn line" data-act="prev"' + (s.page === 0 && s.beat === 0 ? ' disabled' : '') + '>' + T.prev + '</button>';
      if (ending) html += '<a class="sl-btn main" data-act="app" href="' + esc(opts.app || '#app') + '">' + T.app + '</a>';
      else if (isBlocked) html += '<button type="button" class="sl-btn main" disabled>' + T.find + '</button>';
      else html += '<button type="button" class="sl-btn main" data-act="next">' + T.next + '</button>';
      card.innerHTML = html + '</div>';
      card.querySelectorAll('.sl-step').forEach((el, i) => {
        if (opts.settled) return;
        const a = view.steps[i].anim;
        el.style.animation = 'sl-' + a.name + ' ' + a.dur + 's linear ' + a.delay + 's infinite';
        el.getAnimations().forEach((run) => { run.currentTime = (now - stepsFrom) * 1000; });
      });
    }

    if (card) {
      card.addEventListener('click', (e) => {
        const t = e.target.closest('[data-act]');
        if (!t) return;
        const act = t.dataset.act;
        if (act === 'app') {
          if (opts.onApp) opts.onApp();
          return;
        }
        dispatch({ type: act });
        // The card was redrawn: keep the keyboard where it was.
        const again = card.querySelector('[data-act="' + act + '"]:not(:disabled)') || card.querySelector('.sl-btn.main:not(:disabled)');
        if (again) again.focus({ preventScroll: true });
      });
    }
    board.port.addEventListener('click', (e) => {
      if (!s.find) return;
      const p = board.at(e.clientX, e.clientY);
      const cell = cellAt(beatOf(lesson, s), s.find, p.x, p.y);
      if (cell) dispatch({ type: 'tap', cell });
    });

    paint();

    // The test hook (tool/lesson_compare/web_candidate.js and the live drive).
    return {
      goto: (page, beat) => dispatch({ type: 'goto', page, beat }),
      next: () => dispatch({ type: 'next' }),
      prev: () => dispatch({ type: 'prev' }),
      restart: () => dispatch({ type: 'restart' }),
      tap: (cell) => dispatch({ type: 'tap', cell }),
      // Taps the button at the centre of the cell (r, c), as a finger would.
      tapCentre(r, c) {
        if (!s.find) return false;
        const S = s.find.shown.draw.S;
        const cell = cellAt(beatOf(lesson, s), s.find, (c + 0.5) * S, (r + 0.5) * S);
        return cell ? dispatch({ type: 'tap', cell }) : false;
      },
      view: () => viewOf(lesson, s),
      state: () => ({ page: s.page, beat: s.beat, blocked: blocked(lesson, s), last: onLast(lesson, s), pages: lesson.pages.map((b) => b.length) }),
      // Where cell (r, c)'s centre is on screen, for a real click.
      cellPoint(r, c) {
        const S = viewOf(lesson, s).draw.S;
        const rect = board.port.getBoundingClientRect();
        const f = opts.fitted ? boardFrame(lesson, viewOf(lesson, s).draw) : { x: 0, y: 0, w: BOX_W };
        const k = rect.width / f.w;
        return { x: rect.left + ((c + 0.5) * S - f.x) * k, y: rect.top + ((r + 0.5) * S - f.y) * k };
      },
    };
  }

  const sheets = {};
  function injectKeyframes(lesson) {
    const add = (key, css) => {
      if (sheets[key]) return;
      sheets[key] = document.createElement('style');
      sheets[key].textContent = css;
      document.head.appendChild(sheets[key]);
    };
    add('', FONT_CSS + BOARD_CSS + '@keyframes sl-halo{from{box-shadow:0 0 3px 0 var(--hc)}to{box-shadow:0 0 3px 7px var(--hc0)}}');
    add(lesson.id, keyframesSheet(lesson.keyframes, lesson.id + '-'));
  }

  // The board's own face, Pretendard at the four weights the app loads
  // (painter.dart: 800 and 900 draw Bold). Medium and SemiBold are cut to
  // the board's text by tool/subset_web_fonts.sh; the page never asks for
  // them, so they load only with a lesson. Next to this script: fonts/.
  const SCRIPT = document.currentScript && document.currentScript.src;
  const FONT_CSS = !SCRIPT ? '' : [[400, 'regular'], [500, 'medium'], [600, 'semibold'], [700, 'bold']]
    .map(([w, f]) => '@font-face{font-family:"SLBoard";src:url("' + new URL('../fonts/pretendard-' + f + '.woff', SCRIPT) + '") format("woff");font-weight:' + w + ';font-display:swap}')
    .join('');

  // The card keeps the mockup's light look (SCHEMA.md section 3) on the
  // dark page: the app's card colours, its 15px/1.65 body and 14px message.
  const CARD_CSS =
    '.sl{background:#EEF3FB;color:#1F2A44;padding:14px;display:flex;flex-direction:column;gap:12px}' +
    '.sl-head{display:flex;align-items:center;justify-content:space-between;gap:10px;font-size:16px;line-height:1.4}' +
    '.sl-stage{flex:none;font-size:12px;line-height:1.5;padding:3px 10px;border-radius:999px;background:#fff;border:1px solid #D3DBEA;color:#6B7A99}' +
    '.sl-main{display:grid;grid-template-columns:minmax(0,1fr);gap:12px;align-items:start}' +
    '@media (min-width:720px){.sl-main{grid-template-columns:minmax(0,1fr) 290px;align-items:stretch}}' +
    '.sl-boardcol{min-width:0}' +
    '.sl-card{background:#fff;border-radius:14px;padding:16px 18px;display:flex;flex-direction:column;gap:8px;min-height:250px;min-width:0}' +
    '.sl-top{display:flex;align-items:center;justify-content:space-between;gap:10px}' +
    '.sl-pill{background:#E3ECFD;color:#2F6FED;font-size:12px;font-weight:800;line-height:1.5;padding:3px 8px;border-radius:8px}' +
    '.sl-dots{display:flex;gap:5px}' +
    '.sl-dots i{width:8px;height:8px;border-radius:50%;border:1.5px solid #2F6FED}' +
    '.sl-dots i.on{background:#2F6FED}' +
    '.sl-text{flex:1;padding-top:2px}' +
    '.sl .sl-text p{margin:0;font-size:15px;line-height:1.65;white-space:pre-line;color:#1F2A44}' +
    '.sl .sl-text p.sl-msg{margin-top:8px;font-size:14px;line-height:1.5;font-weight:700;white-space:normal}' +
    '.sl .sl-text p.ok{color:#1E7B34}.sl .sl-text p.no{color:#E5484D}' +
    '.sl-row{display:flex;gap:10px}' +
    '.sl-btn{flex:1;min-width:0;display:flex;align-items:center;justify-content:center;min-height:48px;padding:8px 10px;border:2px solid #2F6FED;border-radius:12px;' +
    'font-family:inherit;font-size:16px;font-weight:700;line-height:1.3;text-align:center;text-decoration:none;cursor:pointer}' +
    '.sl .sl-btn.main,.sl .sl-btn.main:hover{flex:2;background:#2F6FED;color:#fff}' +
    '.sl .sl-btn.line,.sl .sl-btn.line:hover{background:#fff;color:#2F6FED}' +
    '.sl .sl-btn.main:disabled{background:#A9BCE8;border-color:#A9BCE8;cursor:default}' +
    '.sl .sl-btn.line:disabled{opacity:.4;cursor:default}' +
    '.sl-btn:focus-visible{outline:3px solid #FFC83D;outline-offset:2px}';

  // The board resets every page style a div could inherit: the mockup's
  // page set none, so its divs saw the browser's defaults.
  const BOARD_CSS =
    '.sl-port{position:relative;overflow:hidden;width:100%}' +
    '.sl-box{position:absolute;left:0;top:0;width:358px;height:380px;transform-origin:0 0;' +
    'font:16px/normal var(--sl-font,"SLBoard","PretendardSub",-apple-system,"Apple SD Gothic Neo","Noto Sans KR",sans-serif);' +
    'color:#1F2A44;word-break:normal;overflow-wrap:normal;letter-spacing:normal;text-align:left;white-space:normal}' +
    '.sl-box>div{position:absolute;box-sizing:content-box;margin:0;padding:0}' +
    '.sl-textoff>div{-webkit-text-fill-color:transparent!important;text-shadow:none!important}' +
    '.sl-tap{cursor:pointer;-webkit-tap-highlight-color:transparent}' +
    CARD_CSS;

  // ------------------------------------------------------------ the page

  // Plays the lesson an `.sl-host` element names (data-src), once the page's
  // loader has fetched this script. The player's controller is left on the
  // host as `lesson` for tool/lesson_compare/web_drive.js.
  function start(host) {
    const d = host.dataset;
    const ua = navigator.userAgent;
    const ios = /iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
    const app = ios && d.ios ? d.ios : /Android/.test(ua) && d.android ? d.android : d.desktop || '#app';
    const get = (src) =>
      fetch(src).then((r) => {
        if (!r.ok) throw new Error(src + ': ' + r.status);
        return r.json();
      });
    // data-strings: the lesson's English table, on English pages.
    return Promise.all([get(d.src), d.strings ? get(d.strings) : null])
      .then(([json, strings]) =>
        (host.lesson = mount(host, json, {
          strings,
          next: d.next ? { href: d.next } : null,
          app,
          onApp() {
            if (window.goatcounter && window.goatcounter.count) window.goatcounter.count({ path: 'lesson-app/' + d.where, event: true });
          },
        })));
  }

  window.SudokuLesson = { start, mount };
})();
