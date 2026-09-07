const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { readTemplates, parseTemplate, renderTemplate, expressionAt } = require('../flutter-templates.cjs');

const catalog = readTemplates();
const { load } = require('./host-runtime.cjs');
const { flutterText } = load('model/DynamicLocale');
const { AppStore } = load('model/AppStore');
const { execFileSync } = require('node:child_process');
execFileSync(process.execPath, [path.join(__dirname, '../sync-templates.cjs'), '--check']);
assert.equal(Object.keys(catalog.locales).length, 53);
assert.equal(Object.keys(catalog.locales.en).length, 29);
for (const [locale, templates] of Object.entries(catalog.locales)) {
  assert.deepEqual(catalog.unsupported[locale], {}, locale);
  assert.deepEqual(Object.keys(templates).sort(), Object.keys(catalog.locales.en).sort(), locale);
  for (const [key, template] of Object.entries(templates)) {
    for (const count of [0, 1, 2, 3, 11, 101]) {
      const values = Object.fromEntries(template.parameters.map(name => [name, name === template.plural ? count : 'value $& {0}']));
      assert.equal(typeof renderTemplate(template, values), 'string', locale + ':' + key);
      assert.ok(!/[\u0001\u0002]/.test(renderTemplate(template, values)), locale + ':' + key);
    }
  }
}
const subtitle = catalog.locales.en['receivePage.subTitle'];
for (const [locale, templates] of Object.entries(catalog.locales)) {
  for (const n of ['0', '1', '2', '11']) {
    assert.equal(flutterText('webSharePage.openLink', locale, { n }), renderTemplate(templates['webSharePage.openLink'], { n }));
    for (const key of ['webSharePage.pendingRequests', 'webSharePage.filesCount']) {
      assert.equal(flutterText(key, locale, { n }), renderTemplate(templates[key], { n }), `${locale}:${key}:${n}`);
    }
    const store = new AppStore(); store.settings.language = locale;
    const expected = renderTemplate(templates['receivePage.filesCard.selected'], { n });
    assert.equal(store.tf('已选 {0} 项', [n]), expected);
    assert.equal(store.tf('已选 {0} 项 · {1}', [n, '$& {0} MB']), expected + ' · $& {0} MB');
  }
}
assert.equal(renderTemplate(subtitle, { n: 1 }), 'wants to send you a file');
assert.equal(renderTemplate(subtitle, { n: 2 }), 'wants to send you 2 files');
assert.throws(() => renderTemplate(subtitle, {}), /Missing parameter/);
assert.throws(() => renderTemplate(subtitle, { n: 'invalid' }), /Invalid plural/);
const name = '$& $` $\' {0} ${n} 🌿';
assert.equal(renderTemplate(catalog.locales.en['progressPage.header.receivingFrom'], { device: name }), `Receiving files from ${name}.`);
assert.equal(expressionAt("'a; b'; next()", 0), "'a; b'");
assert.throws(() => expressionAt("'unfinished'", 0), /Unterminated/);
const literal = parseTemplate("'cost \\$n; ${n}; ${_root.title}'", ['n'], { title: 'Title' });
assert.equal(renderTemplate(literal, { n: name }), `cost $n; ${name}; Title`);
assert.throws(() => parseTemplate("'${unknown}'", ['n'], {}), /Unknown template parameter/);
assert.throws(() => parseTemplate('executeCode()', [], {}), /Unsupported/);
const pluralExpression = "(_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, zero: 'zero', one: 'one', two: 'two', few: 'few', many: 'many', other: 'other',)";
const arabic = parseTemplate(pluralExpression, ['n'], {});
assert.deepEqual([0, 1, 2, 3, 11, 100].map(n => renderTemplate(arabic, { n })), ['zero', 'one', 'two', 'few', 'many', 'other']);
assert.throws(() => parseTemplate(pluralExpression.replace("other: 'other',", ''), ['n'], {}), /requires other/);
assert.throws(() => parseTemplate(pluralExpression.replace("zero: 'zero',", "one: 'duplicate',"), ['n'], {}), /Unsupported plural branch/);

// A generated subclass can inherit the method while overriding a referenced getter.
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'aloe-template-fixture-'));
fs.writeFileSync(path.join(directory, 'strings_en.g.dart'), "class Translations { String get title => 'English'; String message({required Object n}) => '${_root.title}: ${n}'; String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: 'one', other: 'other'); }");
fs.writeFileSync(path.join(directory, 'strings_de.g.dart'), "class TranslationsDe extends Translations { String get title => 'Deutsch'; }");
fs.writeFileSync(path.join(directory, 'strings_fr.g.dart'), "class TranslationsFr extends Translations { String message({required Object n}) => unsupported(n); }");
const fixture = readTemplates(directory);
assert.equal(renderTemplate(fixture.locales.de.message, { n: 3 }), 'Deutsch: 3');
assert.equal(fixture.locales.de.count.locale, 'en', 'inherited plural resolver retains its source locale');
assert.equal(fixture.locales.fr.message, undefined, 'unsupported localized overrides cannot silently inherit English');
assert.match(fixture.unsupported.fr.message, /Unsupported/);
console.log('PASS 53 locales × 29 dynamic templates, six plural categories, localized inheritance, literal parameters and unsupported override detection');
