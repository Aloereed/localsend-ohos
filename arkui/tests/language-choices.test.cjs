const assert = require('node:assert/strict');
const { load, mocks } = require('./host-runtime.cjs');
const { languageChoices, filterLanguages } = load('model/LanguageChoices');
const system = mocks['@kit.LocalizationKit'].i18n.System;
const previous = system.getDisplayLanguage;
try {
  system.getDisplayLanguage = (tag, display) => tag === 'de' ? (display === 'zh-CN' ? '德语' : 'German') : tag;
  const choices = languageChoices('zh');
  assert.equal(choices.length, 56);
  for (const query of ['Deutsch', 'German', '德语', '  GERMAN de  ']) {
    assert.equal(filterLanguages(choices, query)[0].id, 'de');
    assert.equal(filterLanguages(choices, query).length, 1);
  }
  assert.equal(filterLanguages(choices, 'zh_CN')[0].id, 'zh');
  assert.equal(filterLanguages(choices, 'zh-Hans')[0].id, 'zh');
  assert.equal(filterLanguages(choices, 'sr_Cyrl')[0].id, 'sr-Cyrl');
  assert.equal(filterLanguages(choices, '   ').length, 56);
  assert.equal(filterLanguages(choices, 'no-such-language').length, 0);
  system.getDisplayLanguage = () => { throw new Error('ICU unavailable'); };
  const fallback = languageChoices('en');
  assert.equal(fallback.length, 56);
  assert.equal(filterLanguages(fallback, 'Deutsch')[0].id, 'de');
  assert.equal(filterLanguages(fallback, 'pt_BR')[0].id, 'pt-BR');
} finally { system.getDisplayLanguage = previous; }
console.log('PASS language search by native/localized/English name, region/script code, multiple words and unavailable ICU');
