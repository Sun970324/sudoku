// Hints for the web board (decision 0055). Loads before sudoku.js.
//
// The page has no solver of the app's size, so a hint comes from one of two
// places:
//   1. the basics, found here on the board as it stands: full house, naked
//      and hidden singles, pointing, claiming, naked and hidden subsets;
//   2. past the basics, the app's own hint path that ships with the puzzle
//      (tool/generate_web_puzzles.dart): the first step whose notes are still
//      on the board and whose pattern cells are all still empty.
// The basics run first because a player who has solved in another order than
// the path can always be ahead or behind it; whatever the path did before an
// advanced step is either done on the board or findable as a basic. When
// nothing fits (it should not happen) the hint fills the emptiest cell.
//
// The candidates the search sees are the board's own (digits placed so far),
// minus the notes earlier hints told the player to remove (game.known), and
// minus what the player has taken off a cell's notes, except the answer: a
// wrong removal is theirs, and the hint still treats the answer as possible.
//
// tool/web_play/hints_test.js drives this file under node.
(function (root) {
  'use strict';

  const ALL = 0x3fe; // bits 1..9
  const bits = (m) => { const out = []; for (let d = 1; d <= 9; d++) if (m & (1 << d)) out.push(d); return out; };
  const popcount = (m) => bits(m).length;

  // Units: 0-8 rows, 9-17 columns, 18-26 boxes.
  const UNITS = [];
  for (let r = 0; r < 9; r++) UNITS.push([...Array(9)].map((_, c) => r * 9 + c));
  for (let c = 0; c < 9; c++) UNITS.push([...Array(9)].map((_, r) => r * 9 + c));
  for (let b = 0; b < 9; b++) {
    const br = Math.floor(b / 3) * 3, bc = (b % 3) * 3;
    UNITS.push([...Array(9)].map((_, k) => (br + Math.floor(k / 3)) * 9 + bc + (k % 3)));
  }
  const kindOf = (u) => (u < 9 ? 'row' : u < 18 ? 'col' : 'box');
  const boxOf = (i) => Math.floor(Math.floor(i / 9) / 3) * 3 + Math.floor((i % 9) / 3);
  const PEERS = [];
  for (let i = 0; i < 81; i++) {
    const s = new Set([...UNITS[Math.floor(i / 9)], ...UNITS[9 + (i % 9)], ...UNITS[18 + boxOf(i)]]);
    s.delete(i);
    PEERS.push([...s]);
  }

  // A note the player took off an empty cell that still has notes counts as
  // removed too, unless it was the cell's answer: a wrong removal is theirs,
  // a right one should not come back as a hint to remove it again.
  function candidates(vals, known, notes, sol) {
    const C = new Array(81).fill(0);
    for (let i = 0; i < 81; i++) {
      if (vals[i]) continue;
      let m = ALL;
      for (const p of PEERS[i]) if (vals[p]) m &= ~(1 << vals[p]);
      if (notes && notes[i]) m &= notes[i] | (1 << sol[i]);
      C[i] = m;
    }
    for (const [i, d] of known || []) C[i] &= ~(1 << d);
    return C;
  }

  function combos(arr, k) {
    const out = [];
    (function go(start, pick) {
      if (pick.length === k) { out.push(pick.slice()); return; }
      for (let i = start; i < arr.length; i++) { pick.push(arr[i]); go(i + 1, pick); pick.pop(); }
    })(0, []);
    return out;
  }

  // ---- the basics ----
  function basic(C, vals) {
    // Full house: a unit with one empty cell.
    for (let u = 0; u < 27; u++) {
      const empty = UNITS[u].filter((i) => !vals[i]);
      if (empty.length === 1 && popcount(C[empty[0]]) === 1) {
        return { t: 'fullHouse', kind: 'reveal', cell: empty[0], digit: bits(C[empty[0]])[0], unit: u, cells: [empty[0]] };
      }
    }
    for (let i = 0; i < 81; i++) {
      if (!vals[i] && popcount(C[i]) === 1) {
        return { t: 'nakedSingle', kind: 'reveal', cell: i, digit: bits(C[i])[0], cells: [i] };
      }
    }
    // Boxes first: they read more easily than lines.
    for (const u of [...Array(9)].map((_, k) => 18 + k).concat([...Array(18)].map((_, k) => k))) {
      for (let d = 1; d <= 9; d++) {
        const spots = UNITS[u].filter((i) => C[i] & (1 << d));
        if (spots.length === 1) {
          return { t: 'hiddenSingle', kind: 'reveal', cell: spots[0], digit: d, unit: u, cells: [spots[0]] };
        }
      }
    }
    // Pointing: in a box, d only in one line; claiming: in a line, d only in one box.
    for (let b = 18; b < 27; b++) {
      for (let d = 1; d <= 9; d++) {
        const spots = UNITS[b].filter((i) => C[i] & (1 << d));
        if (spots.length < 2) continue;
        for (const [line, key] of [[(i) => Math.floor(i / 9), 0], [(i) => i % 9, 9]]) {
          const l = line(spots[0]);
          if (!spots.every((i) => line(i) === l)) continue;
          const elims = UNITS[key + l].filter((i) => boxOf(i) !== b - 18 && C[i] & (1 << d)).map((i) => [i, d]);
          if (elims.length) return { t: 'intersectionPointing', kind: 'elim', digit: d, unit: b, line: key + l, cells: spots, elims };
        }
      }
    }
    for (let u = 0; u < 18; u++) {
      for (let d = 1; d <= 9; d++) {
        const spots = UNITS[u].filter((i) => C[i] & (1 << d));
        if (spots.length < 2) continue;
        const b = boxOf(spots[0]);
        if (!spots.every((i) => boxOf(i) === b)) continue;
        const elims = UNITS[18 + b].filter((i) => !UNITS[u].includes(i) && C[i] & (1 << d)).map((i) => [i, d]);
        if (elims.length) return { t: 'intersectionClaiming', kind: 'elim', digit: d, unit: u, line: u, box: 18 + b, cells: spots, elims };
      }
    }
    // Subsets, smallest first, naked before hidden at each size.
    const NAMES = { 2: ['nakedPair', 'hiddenPair'], 3: ['nakedTriple', 'hiddenTriple'], 4: ['nakedQuad', 'hiddenQuad'] };
    for (const k of [2, 3, 4]) {
      for (let u = 0; u < 27; u++) {
        const empty = UNITS[u].filter((i) => !vals[i]);
        if (empty.length <= k) continue;
        for (const set of combos(empty.filter((i) => popcount(C[i]) <= k), k)) {
          const m = set.reduce((acc, i) => acc | C[i], 0);
          if (popcount(m) !== k) continue;
          const elims = [];
          for (const i of empty) {
            if (set.includes(i)) continue;
            for (const d of bits(C[i] & m)) elims.push([i, d]);
          }
          if (elims.length) return { t: NAMES[k][0], kind: 'elim', unit: u, digits: bits(m), cells: set, elims };
        }
        const digits = [];
        for (let d = 1; d <= 9; d++) {
          const n = empty.filter((i) => C[i] & (1 << d)).length;
          if (n >= 2 && n <= k) digits.push(d);
        }
        for (const ds of combos(digits, k)) {
          const m = ds.reduce((acc, d) => acc | (1 << d), 0);
          const set = empty.filter((i) => C[i] & m);
          if (set.length !== k) continue;
          const elims = [];
          for (const i of set) for (const d of bits(C[i] & ~m)) elims.push([i, d]);
          if (elims.length) return { t: NAMES[k][1], kind: 'elim', unit: u, digits: ds, cells: set, elims };
        }
      }
    }
    return null;
  }

  const BASIC = new Set(['fullHouse', 'nakedSingle', 'hiddenSingle', 'intersectionPointing', 'intersectionClaiming',
    'lockedPair', 'lockedTriple', 'nakedPair', 'nakedTriple', 'nakedQuad', 'hiddenPair', 'hiddenTriple', 'hiddenQuad']);

  const BLOCKED = { blocked: true };

  // The hint for a path step on this board; null when the board has already
  // done what the step does; BLOCKED when it has not, but one of the
  // pattern's cells has since been filled, so the pattern can no longer be
  // shown as it was found.
  function fromStep(st, C, vals) {
    const idx = (rc) => rc[0] * 9 + rc[1];
    const pattern = [...(st.p || []), ...(st.a || []), ...(st.b || []), ...(st.c || []), ...(st.d || [])].map(idx);
    let h;
    if (st.v) {
      const i = idx(st.v);
      if (vals[i]) return null;
      h = { t: st.t, kind: 'reveal', cell: i, digit: st.v[2], cells: pattern.length ? pattern : [i], step: st };
    } else {
      const elims = (st.e || []).map(([r, c, d]) => [r * 9 + c, d]).filter(([i, d]) => C[i] & (1 << d));
      if (!elims.length) return null;
      h = { t: st.t, kind: 'elim', cells: [...new Set(pattern)], sec: (st.s || []).map(idx), digits: st.n || [], elims, step: st };
    }
    return pattern.some((i) => vals[i]) ? BLOCKED : h;
  }

  // The next hint for this board. state: {puzzle: {p, s, steps}, vals, known}.
  function findHint(state) {
    const { puzzle, vals } = state;
    const wrong = [];
    for (let i = 0; i < 81; i++) if (vals[i] && vals[i] !== Number(puzzle.s[i])) wrong.push(i);
    if (wrong.length) return { t: 'wrong', kind: 'wrong', cells: wrong };
    const C = candidates(vals, state.known, state.notes, [...puzzle.s].map(Number));
    const b = basic(C, vals);
    if (b) return b;
    for (const st of puzzle.steps) {
      if (BASIC.has(st.t)) continue;
      const h = fromStep(st, C, vals);
      if (h === BLOCKED) break;
      if (h) return h;
    }
    // Nothing explainable: fill the next cell the path fills, or failing
    // that the cell with the fewest candidates.
    let best = -1;
    for (const st of puzzle.steps) {
      if (st.v && !vals[st.v[0] * 9 + st.v[1]]) { best = st.v[0] * 9 + st.v[1]; break; }
    }
    if (best < 0) {
      for (let i = 0; i < 81; i++) if (!vals[i] && (best < 0 || popcount(C[i]) < popcount(C[best]))) best = i;
    }
    if (best < 0) return null;
    return { t: 'fallback', kind: 'reveal', cell: best, digit: Number(puzzle.s[best]), cells: [best] };
  }

  // ---- names and pages ----
  // Each technique's page; the name is the page's own (text.js, tech.<t>).
  const SLUG = {
    fullHouse: 'naked-single',
    nakedSingle: 'naked-single',
    hiddenSingle: 'hidden-single',
    intersectionPointing: 'pointing',
    intersectionClaiming: 'claiming',
    lockedPair: 'naked-pair',
    lockedTriple: 'naked-pair',
    nakedPair: 'naked-pair',
    nakedTriple: 'naked-pair',
    nakedQuad: 'naked-pair',
    hiddenPair: 'hidden-pair',
    hiddenTriple: 'hidden-pair',
    hiddenQuad: 'hidden-pair',
    xWing: 'x-wing',
    finnedXWing: 'finned-x-wing',
    sashimiXWing: 'sashimi-x-wing',
    swordfish: 'swordfish',
    finnedSwordfish: 'swordfish',
    jellyfish: 'jellyfish',
    skyscraper: 'skyscraper',
    twoStringKite: 'two-string-kite',
    turbotFish: 'skyscraper',
    simpleColoring: 'simple-coloring',
    multiColoring: 'multi-coloring',
    remotePair: 'remote-pair',
    xyWing: 'xy-wing',
    xyzWing: 'xyz-wing',
    wWing: 'w-wing',
    sueDeCoq: 'sue-de-coq',
    tripleFirework: 'triple-firework',
  };
  function names(t) {
    const slug = SLUG[t];
    if (!slug) return null;
    const text = root.SLText;
    return { name: text('tech.' + t), href: `${text.techniques}${slug}.html` };
  }

  const api = { findHint, basic, candidates, names, SLUG, UNITS };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.SudokuHints = api;
})(typeof window !== 'undefined' ? window : this);

// ---- the hint card on the page ----
(function () {
  'use strict';
  if (typeof document === 'undefined') return;
  const H = window.SudokuHints;
  const card = document.getElementById('sb-hint');
  if (!card) return;

  let hint = null;
  let stage = 0;
  let api = null;

  const T = window.SLText;
  const list = (ds) => ds.join(', ');

  // The three stages' sentences. A sentence that names a row, column or box
  // has one template per kind, so each language can agree with the noun.
  function texts(h) {
    if (h.kind === 'wrong') return [T('hint.wrong1'), T('hint.wrong2'), T('hint.wrong3')];
    if (h.t === 'fallback') return [T('hint.fallback1'), T('hint.fallback2'), T('hint.fallback3', { digit: h.digit })];
    const n = H.names(h.t);
    const name = n ? n.name : '';
    const kind = (u) => (u < 9 ? 'row' : u < 18 ? 'col' : 'box');
    const v = { name, digit: h.digit, count: h.cells.length, digits: h.digits && list(h.digits) };
    let where;
    if (h.t === 'fullHouse') where = T(`hint.fullHouse.${kind(h.unit)}`);
    else if (h.t === 'nakedSingle') where = T('hint.nakedSingle');
    else if (h.t === 'hiddenSingle') where = T(`hint.hiddenSingle.${kind(h.unit)}`, v);
    else if (h.t === 'intersectionPointing') where = T(`hint.pointing.${kind(h.line)}`, v);
    else if (h.t === 'intersectionClaiming') where = T(`hint.claiming.${kind(h.line)}`, v);
    else if (/^naked/.test(h.t) || /^locked/.test(h.t)) where = T('hint.naked', v);
    else if (/^hidden/.test(h.t)) where = T(`hint.hidden.${kind(h.unit)}`, v);
    else where = T('hint.pattern', v);
    let answer;
    if (h.kind === 'reveal') answer = T('hint.answerReveal', v);
    else {
      const elimDigits = [...new Set(h.elims.map((e) => e[1]))];
      answer = T(elimDigits.length === 1 ? 'hint.answerElimOne' : 'hint.answerElimMany', { digits: list(elimDigits) });
    }
    return [T('hint.use', v), where, answer];
  }

  function render() {
    card.textContent = '';
    if (!hint) { card.hidden = true; return; }
    card.hidden = false;
    const [t1, t2, t3] = texts(hint);
    const n = H.names(hint.t);
    const head = document.createElement('div');
    head.className = 'sb-hint-head';
    const eyebrow = document.createElement('span');
    eyebrow.textContent = `HINT ${stage}/3` + (n ? ` · ${n.name}` : '');
    const x = document.createElement('button');
    x.type = 'button';
    x.className = 'sb-hint-close';
    x.setAttribute('aria-label', T('hint.close'));
    x.textContent = '×';
    x.addEventListener('click', close);
    head.append(eyebrow, x);
    const p = document.createElement('p');
    p.textContent = stage === 1 ? t1 : stage === 2 ? t2 : t3;
    const row = document.createElement('div');
    row.className = 'sb-hint-actions';
    const btn = document.createElement('button');
    btn.type = 'button';
    if (stage < 3) {
      btn.textContent = T(stage === 1 ? 'hint.showWhere' : 'hint.showAnswer');
      btn.addEventListener('click', () => advance());
    } else if (hint.kind === 'reveal') {
      btn.textContent = T('hint.fill');
      btn.addEventListener('click', () => { const i = hint.cell; close(); api.reveal(i); });
    } else if (hint.kind === 'wrong') {
      btn.textContent = T('hint.clear');
      btn.addEventListener('click', () => { const cells = hint.cells; close(); api.clearCells(cells); });
    } else {
      btn.textContent = T('hint.removeNotes');
      btn.addEventListener('click', () => { const e = hint.elims; close(); api.removeNotes(e); });
    }
    row.appendChild(btn);
    card.append(head, p, row);
    // A small link under the button: the hint's own step comes first.
    if (n && n.href && hint.kind !== 'wrong') {
      const a = document.createElement('a');
      a.href = n.href;
      a.className = 'sb-hint-learn';
      a.textContent = T('hint.learn', { name: n.name });
      a.addEventListener('click', () => api.count(`hint-learn/${hint.t}`));
      card.appendChild(a);
    }
  }

  function advance() {
    stage++;
    if (stage === 3 && hint.kind === 'elim') api.learn(hint.elims);
    api.count(`hint/${hint.t}/${stage}`);
    render();
    api.render();
  }

  function close() {
    if (!hint) return;
    hint = null;
    stage = 0;
    render();
    if (api) api.render();
  }

  window.SudokuHintUI = {
    next(a) {
      api = a;
      if (hint) { if (stage < 3) advance(); return; }
      if (!a.hintsLeft) return;
      const g = a.game;
      hint = H.findHint({ puzzle: a.puzzle, vals: g.vals, known: g.known || [], notes: g.notes });
      if (!hint) return;
      a.spendHint();
      stage = 0;
      if (hint.kind !== 'wrong') a.noteHinted(hint.t);
      advance();
    },
    close,
    get open() { return !!hint; },
    // Adds hint classes to the board cells for the current stage.
    paint(cells) {
      if (!hint || stage < 2) return;
      const mark = (i, c) => cells[i] && cells[i].classList.add(c);
      if (hint.unit != null && stage >= 2) H.UNITS[hint.unit].forEach((i) => mark(i, 'h-unit'));
      if (hint.line != null && hint.t === 'intersectionPointing') H.UNITS[hint.line].forEach((i) => mark(i, 'h-unit'));
      if (hint.box != null) H.UNITS[hint.box].forEach((i) => mark(i, 'h-unit'));
      if (hint.kind === 'wrong') { hint.cells.forEach((i) => mark(i, 'h-wrong')); return; }
      hint.cells.forEach((i) => mark(i, 'h-key'));
      (hint.sec || []).forEach((i) => mark(i, 'h-sec'));
      if (stage >= 3) {
        if (hint.kind === 'reveal') mark(hint.cell, 'h-answer');
        else hint.elims.forEach(([i]) => mark(i, 'h-elim'));
      }
    },
  };
})();
