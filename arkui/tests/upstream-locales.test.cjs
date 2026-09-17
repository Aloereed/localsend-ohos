const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { load } = require('./host-runtime.cjs');
const { uiText, resolvedLanguage } = load('model/Locale');
const { flutterText } = load('model/DynamicLocale');
const { flutterLanguages } = load('model/FlutterLocales');
const { readCatalog } = require('../flutter-translations.cjs');
const catalog = readCatalog();
for (const [locale, region] of [['be', 'BY'], ['ga', 'IE'], ['hy', 'AM']]) {
  const json = JSON.parse(fs.readFileSync(path.join(__dirname, '../upstream-locales/v1.18.2', locale + '.json'), 'utf8'));
  assert.equal(resolvedLanguage(locale + '-' + region), locale);
  assert.ok(flutterLanguages.some(item => item.id === locale));
  assert.equal(uiText('取消', locale), json.general.cancel);
  assert.equal(uiText('接收', locale), json.receiveTab.title);
  assert.equal(flutterText('webSharePage.pendingRequests', locale, { n: '3' }), json.webSharePage.pendingRequests.replace('{n}', '3'));
  assert.equal(flutterText('webSharePage.openLink', locale, { n: '1' }), json.webSharePage.openLink.one);
  assert.equal(flutterText('settingsTab.network.portWarning', locale, { defaultPort: '54321' }), json.settingsTab.network.portWarning.replace('{defaultPort}', '54321'));
  assert.ok(Object.keys(catalog.locales.en).filter(key => catalog.locales[locale][key] !== catalog.locales.en[key]).length > 100,
    locale + ' must include actual translated content, not only a language option');
}
console.log('PASS new locale text and parameterized messages match pinned official JSON sources');
