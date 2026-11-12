// The words the web home's scripts (decision 0055) and the technique pages'
// lesson player (lesson.js) show, in the page's language.
// tool/generate_home_pages.dart and tool/generate_technique_pages.dart write
// them into the page as one JSON table (#sl-text), so the scripts carry no
// language of their own and a new language is a new page, not a new branch
// here. Loads first.
//
// A template names its values in braces: {level}, {digit}. A Korean template
// may follow a value with its particle pair, {digit:이/가}: the first form
// after a final consonant, the second after a vowel.
(function () {
  'use strict';
  const el = document.getElementById('sl-text');
  const table = el ? JSON.parse(el.textContent) : {};

  // Digits are read 일 이 삼 사 오 육 칠 팔 구: 2, 4, 5 and 9 end in a vowel.
  function endsInConsonant(word) {
    const last = word[word.length - 1];
    if (/[0-9]/.test(last)) return !['2', '4', '5', '9'].includes(last);
    if (/[가-힣]/.test(last)) return (last.charCodeAt(0) - 0xac00) % 28 !== 0;
    return false;
  }

  function text(key, values) {
    const template = table[key];
    if (template == null) return key;
    return template.replace(/\{(\w+)(?::([^/{}]*)\/([^{}]*))?\}/g, (whole, name, afterConsonant, afterVowel) => {
      if (!values || !(name in values)) return whole;
      const v = String(values[name]);
      if (afterConsonant === undefined) return v;
      return v + (endsInConsonant(v) ? afterConsonant : afterVowel);
    });
  }
  // Where this page's technique pages are, relative to the page.
  text.techniques = (el && el.dataset.techniques) || 'techniques/';
  window.SLText = text;
})();
