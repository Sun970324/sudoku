// The coupon popup on the web home (decision 0055): the claim logic the old
// landing page carried in its coupon section, moved into a <dialog>. Anything
// with data-open-coupon opens it, and so does arriving at #coupon (the
// technique pages' coupon tickets link there).
//
// One code per device per store, from the claim-coupon edge function. The
// browser keeps the claim token it was given; sending it back returns the
// same code instead of spending another. Counts are never shown (owner's
// call), so the stock check only flips a button to "gone" at zero. There is
// deliberately no link to the stores' redeem pages: redeeming before signing
// in attaches the free month to a guest, so the code goes into the app's own
// "프로모션 코드 사용" button, which sits behind sign-in.
(function () {
  'use strict';
  const dialog = document.getElementById('coupon');
  if (!dialog) return;
  const FUNCTION_URL = 'https://nxzbgkyemozqalhdtbuy.supabase.co/functions/v1/claim-coupon';
  const ko = document.documentElement.lang === 'ko';
  const PLATFORMS = {
    ios: { suffix: 'Ios', tokenKey: 'sl_coupon_token_ios', name: 'iPhone' },
    android: { suffix: 'Android', tokenKey: 'sl_coupon_token_android', name: 'Android' },
  };
  const LABELS = {
    claiming: () => (ko ? '받는 중…' : 'Getting…'),
    soldout: (n) => (ko ? `${n} 쿠폰 소진` : `${n} sold out`),
    claimed: (n) => (ko ? `${n} 쿠폰 받음` : `Got ${n} code`),
    copy: ko ? '복사' : 'Copy',
    copied: ko ? '복사했어요' : 'Copied',
  };
  const el = (id) => document.getElementById(id);
  const idle = {};
  const count = (event) => {
    if (window.goatcounter && window.goatcounter.count) window.goatcounter.count({ path: event, event: true });
  };

  // The pre-Clipboard-API copy: a hidden textarea, selected, execCommand.
  // readonly keeps iOS from raising the keyboard; the font size keeps it
  // from zooming in.
  function copyBySelection(text) {
    const area = document.createElement('textarea');
    area.value = text;
    area.setAttribute('readonly', '');
    area.style.cssText = 'position:fixed;top:0;left:0;opacity:0;font-size:16px;';
    document.body.appendChild(area);
    area.select();
    area.setSelectionRange(0, text.length);
    let ok = false;
    try { ok = document.execCommand('copy'); } catch (e) { /* no copy */ }
    document.body.removeChild(area);
    return ok;
  }

  function readToken(p) { try { return localStorage.getItem(PLATFORMS[p].tokenKey); } catch (e) { return null; } }
  function writeToken(p, t) { try { localStorage.setItem(PLATFORMS[p].tokenKey, t); } catch (e) { /* private mode */ } }

  function setButton(p, state) {
    const b = el('claim' + PLATFORMS[p].suffix);
    b.disabled = state !== 'idle';
    b.classList.toggle('done', state === 'claimed');
    b.textContent = state === 'idle' ? idle[p] : LABELS[state](PLATFORMS[p].name);
  }

  function showCode(p, code) {
    const s = PLATFORMS[p].suffix;
    el('code' + s).textContent = code;
    el('copy' + s).textContent = LABELS.copy;
    el('box' + s).hidden = false;
    el('couponError').hidden = true;
    setButton(p, 'claimed');
  }

  function claim(p) {
    const token = readToken(p);
    setButton(p, 'claiming');
    fetch(FUNCTION_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token, platform: p }),
    })
      .then((r) => r.json())
      .then((data) => {
        if (data.error) throw new Error(data.error);
        if (data.soldOut || !data.code) { setButton(p, 'soldout'); return; }
        if (data.token) writeToken(p, data.token);
        showCode(p, data.code);
        count(`coupon-claim/${p}`);
      })
      .catch(() => {
        setButton(p, 'idle');
        el('couponError').hidden = false;
      });
  }

  Object.keys(PLATFORMS).forEach((p) => {
    const s = PLATFORMS[p].suffix;
    idle[p] = el('claim' + s).textContent;
    el('claim' + s).addEventListener('click', () => claim(p));
    el('copy' + s).addEventListener('click', () => {
      const code = el('code' + s);
      const done = () => { el('copy' + s).textContent = LABELS.copied; };
      // In-app browsers (KakaoTalk, Instagram, …) often have no Clipboard
      // API or refuse it. The old execCommand path goes first because it must
      // run inside the tap itself (iOS refuses it once a promise has
      // resolved); the API is the second try, and failing both, the code is
      // left selected for a long-press copy.
      const selectCode = () => {
        const range = document.createRange();
        range.selectNodeContents(code);
        const sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
      };
      if (copyBySelection(code.textContent)) done();
      else if (navigator.clipboard && window.isSecureContext) navigator.clipboard.writeText(code.textContent).then(done, selectCode);
      else selectCode();
    });
  });

  // Checked when the popup first opens rather than on every page load. A
  // failed check is not fatal: a claim on an empty stock answers sold out.
  let stockChecked = false;
  function checkStock() {
    if (stockChecked) return;
    stockChecked = true;
    fetch(FUNCTION_URL, { method: 'GET' })
      .then((r) => r.json())
      .then((stock) => {
        Object.keys(PLATFORMS).forEach((p) => {
          // Only a real count of zero: an error body has no counts at all.
          if (typeof stock[p] === 'number' && stock[p] <= 0 && el('box' + PLATFORMS[p].suffix).hidden) setButton(p, 'soldout');
        });
      })
      .catch(() => {});
  }

  function open(where) {
    if (dialog.open) return;
    checkStock();
    if (dialog.showModal) dialog.showModal(); else dialog.setAttribute('open', '');
    count(`coupon-open/${where}`);
  }
  document.addEventListener('click', (e) => {
    const t = e.target.closest('[data-open-coupon]');
    if (t) { e.preventDefault(); open(t.dataset.openCoupon || 'home'); }
  });
  el('couponClose').addEventListener('click', () => dialog.close());
  dialog.addEventListener('click', (e) => { if (e.target === dialog) dialog.close(); });
  if (location.hash === '#coupon') open('link');
})();
