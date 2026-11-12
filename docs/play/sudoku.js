// The web home's board (decision 0055). Plain script, no build step: the page
// carries the markup (see tool/generate_home_pages.dart) and this file fills
// the board and wires the controls. Puzzles come from docs/play/<level>/<n>.json
// (tool/generate_web_puzzles.dart); hints from hints.js, which has to load first.
(function () {
  'use strict';

  const LEVELS = ['easy', 'medium', 'hard', 'expert'];
  const MAX_MISTAKES = 3;
  const MAX_HINTS = 3;
  const SAVE_KEY = 'sl-web-game';
  const PLAYED_KEY = 'sl-web-played';
  const T = window.SLText;

  const $ = (sel) => document.querySelector(sel);
  const boardEl = $('#sb-board');
  if (!boardEl) return;
  // Relative to this script, not the domain root: the same pages are also
  // served from sun970324.github.io/sudoku/.
  const BASE = new URL('.', document.currentScript.src).href;

  const store = {
    get(key) { try { return JSON.parse(localStorage.getItem(key)); } catch (e) { return null; } },
    set(key, v) { try { localStorage.setItem(key, JSON.stringify(v)); } catch (e) { /* private mode */ } },
  };
  const count = (event) => {
    if (window.goatcounter && window.goatcounter.count) {
      window.goatcounter.count({ path: event, event: true });
    }
  };

  const peersOf = [];
  for (let i = 0; i < 81; i++) {
    const r = Math.floor(i / 9), c = i % 9, set = new Set();
    for (let k = 0; k < 9; k++) { set.add(r * 9 + k); set.add(k * 9 + c); }
    const br = r - (r % 3), bc = c - (c % 3);
    for (let k = 0; k < 9; k++) set.add((br + Math.floor(k / 3)) * 9 + bc + (k % 3));
    set.delete(i);
    peersOf.push([...set]);
  }

  // One game. vals holds what the player sees, wrong digits included; notes
  // are 9-bit masks. history holds undo snapshots of (vals, notes) only:
  // mistakes, time and hints used stay spent.
  let game = null;
  let puzzle = null;
  let sel = -1;
  let noteMode = false;
  let ticking = null;
  let paused = false;

  function fresh(level, n, p) {
    return {
      level, n,
      vals: [...p.p].map(Number),
      notes: new Array(81).fill(0),
      mistakes: 0, elapsed: 0, done: false, over: false,
      // Hints opened this game; the three stages of one hint count once.
      hintsUsed: 0,
      // hinted: techniques a hint named; known: [cell, digit] notes a hint
      // said to remove, which the next hint search takes as known.
      hinted: [], known: [], history: [],
    };
  }

  function save() { if (game) store.set(SAVE_KEY, game); }

  function pickNumber(level, total) {
    const played = store.get(PLAYED_KEY) || {};
    const seen = new Set(played[level] || []);
    let pool = [];
    for (let n = 1; n <= total; n++) if (!seen.has(n)) pool.push(n);
    if (!pool.length) { played[level] = []; pool = [...Array(total)].map((_, i) => i + 1); }
    const n = pool[Math.floor(Math.random() * pool.length)];
    played[level] = [...(played[level] || []), n];
    store.set(PLAYED_KEY, played);
    return n;
  }

  let levelCounts = null;
  async function counts() {
    if (!levelCounts) levelCounts = await (await fetch(BASE + 'levels.json')).json();
    return levelCounts;
  }

  async function fetchPuzzle(level, n) {
    const res = await fetch(`${BASE}${level}/${n}.json`);
    if (!res.ok) throw new Error(res.status);
    return res.json();
  }

  async function start(level, opts) {
    opts = opts || {};
    stopClock();
    closeModal();
    closeConfirm(false);
    if (window.SudokuHintUI) window.SudokuHintUI.close();
    boardEl.setAttribute('aria-busy', 'true');
    markLevel(level);
    try {
      const saved = opts.resume ? store.get(SAVE_KEY) : null;
      if (saved && saved.level === level && !saved.done && !saved.over) {
        puzzle = await fetchPuzzle(level, saved.n);
        game = saved;
      } else {
        const n = opts.n || pickNumber(level, (await counts())[level]);
        puzzle = await fetchPuzzle(level, n);
        game = fresh(level, n, puzzle);
        count(`play-start/${level}`);
      }
    } catch (e) {
      boardEl.textContent = T('game.loadFail');
      return;
    }
    boardEl.removeAttribute('aria-busy');
    sel = -1;
    paused = false;
    boardEl.classList.remove('paused');
    const pb = $('[data-act="pause"]');
    if (pb) pb.setAttribute('aria-pressed', 'false');
    save();
    render();
    startClock();
  }

  function markLevel(level) {
    document.querySelectorAll('[data-level]').forEach((a) => {
      if (a.dataset.level === level) a.setAttribute('aria-current', 'page');
      else a.removeAttribute('aria-current');
    });
    const label = $('#sb-level');
    if (label) label.textContent = T('level.' + level);
  }

  // ---- clock ----
  function startClock() {
    stopClock();
    if (game.done || game.over || paused) return;
    ticking = setInterval(() => {
      if (document.hidden) return;
      game.elapsed++;
      showTime();
      if (game.elapsed % 5 === 0) save();
    }, 1000);
  }
  function stopClock() { if (ticking) clearInterval(ticking); ticking = null; }
  function fmt(s) {
    const m = Math.floor(s / 60), r = s % 60;
    return `${String(m).padStart(2, '0')}:${String(r).padStart(2, '0')}`;
  }
  function showTime() { const el = $('#sb-time'); if (el) el.textContent = fmt(game.elapsed); }

  // ---- board ----
  const cells = [];
  for (let i = 0; i < 81; i++) {
    const el = document.createElement('div');
    el.className = 'sb-cell';
    el.setAttribute('role', 'gridcell');
    el.dataset.i = i;
    el.addEventListener('pointerdown', () => select(i));
    cells.push(el);
  }
  boardEl.textContent = '';
  boardEl.setAttribute('role', 'grid');
  boardEl.tabIndex = 0;
  for (let r = 0; r < 9; r++) {
    const row = document.createElement('div');
    row.setAttribute('role', 'row');
    row.className = 'sb-row';
    for (let c = 0; c < 9; c++) row.appendChild(cells[r * 9 + c]);
    boardEl.appendChild(row);
  }

  function isGiven(i) { return puzzle && puzzle.p[i] !== '0'; }
  function isWrong(i) { return game.vals[i] !== 0 && game.vals[i] !== Number(puzzle.s[i]); }

  function render() {
    if (!game || !puzzle) return;
    const selVal = sel >= 0 ? game.vals[sel] : 0;
    const peers = sel >= 0 ? new Set(peersOf[sel]) : new Set();
    for (let i = 0; i < 81; i++) {
      const el = cells[i];
      const v = game.vals[i];
      const cls = ['sb-cell'];
      if (isGiven(i)) cls.push('given');
      else if (v) cls.push(isWrong(i) ? 'wrong' : 'mine');
      if (i === sel) cls.push('sel');
      else if (peers.has(i)) cls.push('peer');
      if (selVal && v === selVal && i !== sel) cls.push('same');
      el.className = cls.join(' ');
      const r = Math.floor(i / 9) + 1, c = (i % 9) + 1;
      if (v) {
        el.textContent = v;
        el.setAttribute('aria-label', `${T('game.cell', { row: r, col: c })}: ${v}`);
      } else if (game.notes[i]) {
        el.textContent = '';
        const grid = document.createElement('span');
        grid.className = 'sb-notes';
        for (let d = 1; d <= 9; d++) {
          const s = document.createElement('span');
          s.textContent = game.notes[i] & (1 << d) ? d : '';
          if (selVal === d && game.notes[i] & (1 << d)) s.className = 'on';
          grid.appendChild(s);
        }
        el.appendChild(grid);
        el.setAttribute('aria-label', T('game.cell', { row: r, col: c }));
      } else {
        el.textContent = '';
        el.setAttribute('aria-label', T('game.cell', { row: r, col: c }));
      }
    }
    if (window.SudokuHintUI) window.SudokuHintUI.paint(cells);
    const m = $('#sb-mistakes');
    if (m) m.textContent = `${game.mistakes}/${MAX_MISTAKES}`;
    showTime();
    const pad = $('.pad');
    if (pad) pad.classList.toggle('notes', noteMode);
    document.querySelectorAll('[data-n]').forEach((b) => {
      const d = Number(b.dataset.n);
      let placed = 0;
      for (let i = 0; i < 81; i++) if (game.vals[i] === d && !isWrong(i)) placed++;
      b.disabled = placed >= 9;
    });
    const nb = $('[data-act="notes"]');
    if (nb) nb.setAttribute('aria-pressed', String(noteMode));
    const left = $('#sb-hints-left');
    if (left) left.textContent = hintsLeft();
    // An open hint can still move on to its next stage with none left.
    const hb = $('[data-act="hint"]');
    if (hb) hb.disabled = !hintsLeft() && !(window.SudokuHintUI && window.SudokuHintUI.open);
  }

  function hintsLeft() { return Math.max(0, MAX_HINTS - (game.hintsUsed || 0)); }

  function select(i) {
    if (!game || paused) return;
    sel = i;
    render();
  }

  function snapshot() {
    game.history.push({ vals: game.vals.slice(), notes: game.notes.slice() });
    if (game.history.length > 200) game.history.shift();
  }

  function input(d) {
    if (!game || game.done || game.over || paused || sel < 0 || isGiven(sel)) return;
    const i = sel;
    if (noteMode) {
      if (game.vals[i]) return;
      snapshot();
      game.notes[i] ^= 1 << d;
    } else {
      if (game.vals[i] === d) return;
      snapshot();
      game.vals[i] = d;
      game.notes[i] = 0;
      if (d !== Number(puzzle.s[i])) {
        game.mistakes++;
        if (game.mistakes >= MAX_MISTAKES) {
          game.over = true;
          stopClock();
          count(`play-over/${game.level}`);
        }
      } else {
        for (const p of peersOf[i]) game.notes[p] &= ~(1 << d);
        if (game.vals.every((v, k) => v === Number(puzzle.s[k]))) {
          game.done = true;
          stopClock();
          count(`play-clear/${game.level}`);
        }
      }
    }
    if (window.SudokuHintUI) window.SudokuHintUI.close();
    save();
    render();
    if (game.done) showClear();
    else if (game.over) showOver();
  }

  function erase() {
    if (!game || game.done || game.over || paused || sel < 0 || isGiven(sel)) return;
    if (!game.vals[sel] && !game.notes[sel]) return;
    snapshot();
    game.vals[sel] = 0;
    game.notes[sel] = 0;
    save();
    render();
  }

  // Every empty cell gets the digits its row, column and box still allow,
  // replacing what was there. Notes a hint said to remove stay removed.
  // One undo step.
  function autoNotes() {
    if (!game || game.done || game.over || paused) return;
    const known = game.known || [];
    const next = game.notes.map((m, i) => {
      if (game.vals[i]) return m;
      let mask = 0b1111111110;
      for (const p of peersOf[i]) if (game.vals[p]) mask &= ~(1 << game.vals[p]);
      for (const [k, d] of known) if (k === i) mask &= ~(1 << d);
      return mask;
    });
    if (next.every((m, i) => m === game.notes[i])) return;
    snapshot();
    game.notes = next;
    if (window.SudokuHintUI) window.SudokuHintUI.close();
    save();
    render();
  }

  function undo() {
    if (!game || game.done || game.over || paused) return;
    const last = game.history.pop();
    if (!last) return;
    game.vals = last.vals;
    game.notes = last.notes;
    save();
    render();
  }

  function setPaused(on) {
    if (!game || game.done || game.over) return;
    paused = on;
    boardEl.classList.toggle('paused', on);
    const b = $('[data-act="pause"]');
    if (b) b.setAttribute('aria-pressed', String(on));
    if (on) stopClock(); else startClock();
  }

  // ---- end screens ----
  const modal = $('#sb-modal');
  function closeModal() { if (modal) { modal.hidden = true; modal.textContent = ''; } }
  function openModal(nodes) {
    if (!modal) return;
    modal.textContent = '';
    const card = document.createElement('div');
    card.className = 'sb-modal-card';
    nodes.forEach((n) => card.appendChild(n));
    modal.appendChild(card);
    modal.hidden = false;
    const first = card.querySelector('button, a');
    if (first) first.focus();
  }
  function h(tag, attrs, text) {
    const el = document.createElement(tag);
    Object.entries(attrs || {}).forEach(([k, v]) => {
      if (k === 'onclick') el.addEventListener('click', v);
      else el.setAttribute(k, v);
    });
    if (text != null) el.textContent = text;
    return el;
  }

  function showOver() {
    openModal([
      h('p', { class: 'sb-modal-eyebrow' }, 'GAME OVER'),
      h('h2', {}, T('game.over')),
      h('p', {}, T('game.overText')),
      h('div', { class: 'sb-modal-actions' }),
    ]);
    const row = modal.querySelector('.sb-modal-actions');
    row.appendChild(h('button', { class: 'primary', onclick: () => start(game.level, { n: game.n }) }, T('game.retry')));
    row.appendChild(h('button', { onclick: () => start(game.level) }, T('game.next')));
  }

  // The app's solo clear times per level, in buckets of `bucket` seconds
  // (tool/web_play/clear_times.sql). Fetched on the first clear only.
  let clearTimes = null;
  async function times() {
    if (!clearTimes) clearTimes = await (await fetch(BASE + 'times.json')).json();
    return clearTimes;
  }

  // "Top N%" against the app's clears, and a histogram up to the 95th
  // percentile with this clear's bar in gold. Filled once times.json loads;
  // stays hidden if it never does.
  function rankCard(level, seconds) {
    const card = h('div', { class: 'sb-rank' });
    card.hidden = true;
    times().then((all) => {
      const counts = all[level];
      const n = counts ? counts.reduce((a, b) => a + b, 0) : 0;
      if (!n) return;
      // The last bucket holds everything slower than the rest.
      const step = all.bucket || 60;
      const last = counts.length - 1;
      const m = Math.min(Math.floor(seconds / step), last);
      let faster = 0;
      for (let i = 0; i < m; i++) faster += counts[i];
      if (m < last) faster += counts[m] * (seconds % step) / step;
      const pct = Math.min(99, Math.max(1, Math.ceil((100 * faster) / n)));
      let w = 0;
      for (let seen = 0; w < last && (seen += counts[w]) < n * 0.95; w++);
      // About 40 bars, so the shape reads as a curve.
      const size = Math.ceil((w + 1) / 40);
      const bins = [];
      for (let i = 0; i <= w; i++) bins[Math.floor(i / size)] = (bins[Math.floor(i / size)] || 0) + counts[i];
      const mine = Math.min(Math.floor(m / size), bins.length - 1);
      const top = Math.max(...bins);
      const head = h('div', { class: 'sb-rank-head' });
      head.appendChild(h('span', {}, T('game.rankOf', { level: T('level.' + level) })));
      head.appendChild(h('b', {}, T('game.rank', { pct })));
      const bars = h('div', { class: 'sb-rank-bars', 'aria-hidden': 'true' });
      bins.forEach((c, i) => {
        const bar = h('i', { class: i === mine ? 'me' : i < mine ? 'fast' : '' });
        bar.style.height = `${Math.max(3, (100 * c) / top)}%`;
        bars.appendChild(bar);
      });
      const axis = h('div', { class: 'sb-rank-axis', 'aria-hidden': 'true' });
      // The marker sits under its bar; an end label it would run into
      // gives way to it.
      const at = Math.min(92, Math.max(8, ((mine + 0.5) * 100) / bins.length));
      const fast = h('span', {}, T('game.fast'));
      const slow = h('span', {}, T('game.slow'));
      if (at < 25) fast.style.visibility = 'hidden';
      if (at > 75) slow.style.visibility = 'hidden';
      const me = h('b', {}, `▲ ${T('game.me')}`);
      me.style.left = `${at}%`;
      axis.appendChild(fast);
      axis.appendChild(me);
      axis.appendChild(slow);
      [head, bars, axis, h('p', { class: 'sb-rank-src' }, T('game.rankSource'))].forEach((el) => card.appendChild(el));
      card.hidden = false;
    }).catch(() => {});
    return card;
  }

  function showClear() {
    const used = [];
    const uses = {};
    for (const st of puzzle.steps) {
      if (!used.includes(st.t)) used.push(st.t);
      uses[st.t] = (uses[st.t] || 0) + 1;
    }
    const stats = h('div', { class: 'sb-modal-stats' });
    [[T('game.level'), T('level.' + game.level)], [T('game.time'), fmt(game.elapsed)], [T('game.mistakes'), String(game.mistakes)]].forEach(([k, v]) => {
      const box = h('div');
      box.appendChild(h('span', {}, k));
      box.appendChild(h('b', {}, v));
      stats.appendChild(box);
    });
    const list = h('ul', { class: 'sb-modal-techs' });
    const names = window.SudokuHints ? window.SudokuHints.names : null;
    used.forEach((t) => {
      const info = names && names(t);
      if (!info) return;
      const li = h('li');
      const label = info.href ? h('a', { href: info.href }, info.name) : h('span', {}, info.name);
      label.appendChild(h('small', {}, ` × ${uses[t]}`));
      li.appendChild(label);
      if (game.hinted.includes(t)) li.appendChild(h('em', {}, T('game.hinted')));
      list.appendChild(li);
    });
    const next = LEVELS[LEVELS.indexOf(game.level) + 1];
    const actions = h('div', { class: 'sb-modal-actions' });
    actions.appendChild(h('button', { class: 'primary', onclick: () => start(game.level) }, T('game.again')));
    if (next) actions.appendChild(h('button', { onclick: () => go(next) }, T('game.harder', { level: T('level.' + next) })));
    // Two columns on a wide screen (record | techniques and buttons), one
    // on a phone; the CSS decides.
    const record = h('div', { class: 'sb-clear-col' });
    record.appendChild(stats);
    record.appendChild(rankCard(game.level, game.elapsed));
    const more = h('div', { class: 'sb-clear-col' });
    [h('p', { class: 'sb-modal-label' }, T('game.used')), list, actions].forEach((el) => more.appendChild(el));
    const cols = h('div', { class: 'sb-clear-cols' });
    cols.appendChild(record);
    cols.appendChild(more);
    const app = $('#sb-app-card');
    const nodes = [
      h('p', { class: 'sb-modal-eyebrow' }, 'STAGE CLEAR'),
      h('h2', {}, T('game.clear')),
      cols,
    ];
    if (app) {
      // A copy, not a second #sb-app-card; counted apart from the panel's.
      const copy = app.cloneNode(true);
      copy.removeAttribute('id');
      copy.dataset.openCoupon = 'clear';
      nodes.push(copy);
    }
    openModal(nodes);
    if (modal) modal.firstChild.classList.add('sb-clear');
    // Focus "play again", not the first technique link.
    actions.firstChild.focus();
  }

  // ---- level from the address ----
  function levelFromHash() {
    const l = location.hash.replace('#', '');
    return LEVELS.includes(l) ? l : null;
  }
  function go(level) {
    if (location.hash !== '#' + level) history.replaceState(null, '', '#' + level);
    start(level);
  }

  // A level tab throws the current game away, so a game the player has
  // touched asks first, over the board the way the pause covers it.
  const confirmEl = h('div', { class: 'sb-confirm', role: 'alertdialog', 'aria-modal': 'false' });
  confirmEl.hidden = true;
  boardEl.parentNode.appendChild(confirmEl);
  let confirmWasPaused = false;
  function touched() {
    return game && !game.done && !game.over && (game.history.length > 0 || game.mistakes > 0 || (game.hintsUsed || 0) > 0);
  }
  function closeConfirm(resume) {
    if (confirmEl.hidden) return;
    confirmEl.hidden = true;
    confirmEl.textContent = '';
    if (resume && !confirmWasPaused) setPaused(false);
  }
  function askLevel(level) {
    if (!touched()) { go(level); return; }
    if (window.SudokuHintUI) window.SudokuHintUI.close();
    if (confirmEl.hidden) confirmWasPaused = paused;
    setPaused(true);
    confirmEl.textContent = '';
    const keep = h('button', { type: 'button', class: 'primary', onclick: () => { closeConfirm(true); backToBoard(); } }, T('game.keep'));
    const row = h('div', { class: 'sb-confirm-actions' });
    row.appendChild(keep);
    row.appendChild(h('button', { type: 'button', onclick: () => { closeConfirm(false); go(level); } }, T('game.leave')));
    confirmEl.appendChild(h('p', { class: 'sb-confirm-title' }, T('game.leaveTitle')));
    confirmEl.appendChild(h('p', {}, T('game.leaveText', { level: T('level.' + level) })));
    confirmEl.appendChild(row);
    confirmEl.hidden = false;
    keep.focus();
  }
  confirmEl.addEventListener('keydown', (e) => { if (e.key === 'Escape') { closeConfirm(true); backToBoard(); } });

  // ---- wiring ----
  // A click on a game button leaves focus on it, so the keyboard would stop
  // reaching the board and the player would have to click the cell again.
  // Hand focus back, unless an end screen has just taken it.
  const backToBoard = () => { if (!modal || modal.hidden) boardEl.focus({ preventScroll: true }); };
  document.querySelectorAll('[data-n]').forEach((b) =>
    b.addEventListener('click', () => { input(Number(b.dataset.n)); backToBoard(); }));
  const act = {
    undo, erase,
    autonotes: autoNotes,
    notes: () => { noteMode = !noteMode; render(); },
    pause: () => { if (confirmEl.hidden) setPaused(!paused); },
    new: () => start(game ? game.level : 'medium'),
    hint: () => {
      if (!game || game.done || game.over || paused || !window.SudokuHintUI) return;
      window.SudokuHintUI.next(api);
    },
  };
  document.querySelectorAll('[data-act]').forEach((b) =>
    b.addEventListener('click', () => {
      if (!act[b.dataset.act]) return;
      act[b.dataset.act]();
      backToBoard();
    }));
  document.querySelectorAll('[data-level]').forEach((a) =>
    a.addEventListener('click', (e) => { e.preventDefault(); askLevel(a.dataset.level); }));
  if (modal) modal.addEventListener('click', (e) => { if (e.target === modal && game && game.done) closeModal(); });

  // Space toggles notes from the board or the page itself (the thumb is
  // already on it while the other fingers type digits). Not from a focused
  // button or link, where Space presses that instead, and not with a
  // modifier held; it stops the page scrolling while a game is on.
  document.addEventListener('keydown', (e) => {
    if (e.code !== 'Space' || e.altKey || e.ctrlKey || e.metaKey || e.shiftKey) return;
    if (e.target !== document.body && e.target !== boardEl) return;
    if (!game || game.done || game.over || !confirmEl.hidden || (modal && !modal.hidden)) return;
    e.preventDefault();
    if (!e.repeat) act.notes();
  });

  // Ctrl+Z (⌘Z on a Mac) undoes from the board or the page itself, as Space
  // does; the undo button shows the key.
  const mac = /Mac|iPhone|iPad/.test(navigator.platform);
  document.querySelectorAll('[data-mac]').forEach((k) => { if (mac) k.textContent = k.dataset.mac; });
  document.addEventListener('keydown', (e) => {
    if (e.key !== 'z' && e.key !== 'Z') return;
    if (!(e.ctrlKey || e.metaKey) || e.altKey || e.shiftKey) return;
    if (e.target !== document.body && e.target !== boardEl) return;
    if (!game || !confirmEl.hidden || (modal && !modal.hidden)) return;
    e.preventDefault();
    undo();
  });

  boardEl.addEventListener('keydown', (e) => {
    if (e.key >= '1' && e.key <= '9') { input(Number(e.key)); e.preventDefault(); return; }
    if (e.key === 'Backspace' || e.key === 'Delete' || e.key === '0') { erase(); e.preventDefault(); return; }
    const move = { ArrowUp: -9, ArrowDown: 9, ArrowLeft: -1, ArrowRight: 1 }[e.key];
    if (move) {
      e.preventDefault();
      if (sel < 0) { select(0); return; }
      const r = Math.floor(sel / 9), c = sel % 9;
      const nr = (r + (move === -9 ? -1 : move === 9 ? 1 : 0) + 9) % 9;
      const nc = (c + (move === -1 ? -1 : move === 1 ? 1 : 0) + 9) % 9;
      select(nr * 9 + nc);
    }
  });
  document.addEventListener('visibilitychange', () => { if (!document.hidden) showTime(); });

  // What hints.js may read and change. It never touches the board otherwise.
  const api = {
    get game() { return game; },
    get puzzle() { return puzzle; },
    get sel() { return sel; },
    count,
    select,
    render,
    // Reveals the solution digit at i, the hint's last stage.
    reveal(i) {
      if (!game || game.done || game.over || isGiven(i)) return;
      snapshot();
      const d = Number(puzzle.s[i]);
      game.vals[i] = d;
      game.notes[i] = 0;
      for (const p of peersOf[i]) game.notes[p] &= ~(1 << d);
      if (game.vals.every((v, k) => v === Number(puzzle.s[k]))) {
        game.done = true;
        stopClock();
        count(`play-clear/${game.level}`);
      }
      save();
      render();
      if (game.done) showClear();
    },
    get hintsLeft() { return hintsLeft(); },
    spendHint() { game.hintsUsed = (game.hintsUsed || 0) + 1; save(); },
    noteHinted(t) { if (!game.hinted.includes(t)) { game.hinted.push(t); save(); } },
    learn(elims) {
      game.known = game.known || [];
      for (const e of elims) if (!game.known.some((k) => k[0] === e[0] && k[1] === e[1])) game.known.push(e);
      save();
    },
    removeNotes(elims) {
      snapshot();
      for (const [i, d] of elims) game.notes[i] &= ~(1 << d);
      save();
      render();
    },
    clearCells(list) {
      snapshot();
      for (const i of list) if (!isGiven(i)) game.vals[i] = 0;
      save();
      render();
    },
  };

  const saved = store.get(SAVE_KEY);
  const initial = levelFromHash() || (saved && !saved.done && !saved.over ? saved.level : 'medium');
  start(initial, { resume: true });
  window.addEventListener('hashchange', () => { const l = levelFromHash(); if (l) start(l); });
})();
