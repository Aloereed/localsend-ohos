const fs = require('node:fs');
const path = require('node:path');
const names = { be: 'Беларуская', ga: 'Gaeilge', hy: 'Հայերեն' };
function readSupplement(locale) {
  const source = JSON.parse(fs.readFileSync(path.join(__dirname, 'upstream-locales/v1.18.2', locale + '.json'), 'utf8'));
  const flat = {};
  function walk(object, prefix = '') {
    for (const [key, value] of Object.entries(object)) {
      if (key.startsWith('@')) continue;
      const full = prefix ? prefix + '.' + key : key;
      if (typeof value === 'string') flat[full] = value;
      else if (value && typeof value === 'object') walk(value, full);
    }
  }
  walk(source); return flat;
}
function expand(flat, fallback, key, seen = new Set()) {
  if (seen.has(key)) throw new Error('Cyclic upstream translation: ' + key);
  if (key === 'appName') return fallback.appName || 'AloeSend';
  const value = flat[key] ?? fallback[key];
  if (typeof value !== 'string') throw new Error('Missing upstream translation: ' + key);
  const next = new Set(seen); next.add(key);
  return value.replace(/@:([.\w]+)/g, (_, reference) => expand(flat, fallback,
    reference.startsWith('.') ? key.slice(0, key.lastIndexOf('.') + 1) + reference.slice(1) : reference, next));
}
function supplementLabels(base, locale) {
  const flat = readSupplement(locale), output = { ...base, locale: names[locale] };
  for (const key of Object.keys(base)) {
    if (!(key in flat)) continue;
    const value = expand(flat, base, key);
    if (!/\{\w+\}/.test(value)) output[key] = value;
  }
  output.appName = base.appName; return output;
}
function supplementTemplates(base, labels, locale) {
  const flat = readSupplement(locale), output = {};
  for (const [key, template] of Object.entries(base)) {
    const ownForms = template.plural ? ['zero', 'one', 'two', 'few', 'many', 'other'].filter(form => key + '.' + form in flat) : [];
    if (!(key in flat) && !ownForms.length) { output[key] = template; continue; }
    const forms = {};
    for (const form of ownForms.length ? ownForms : ['other']) {
      let value = expand(flat, labels, ownForms.length ? key + '.' + form : key);
      value = value.replace(/\{(\w+)\}/g, (_, name) => {
        if (!template.parameters.includes(name)) throw new Error('Unexpected upstream parameter: ' + key + ':' + name);
        return '\u0001' + name + '\u0002';
      });
      forms[form] = value;
    }
    if (!forms.other) throw new Error('Upstream plural missing other: ' + key);
    output[key] = { ...template, locale, forms };
  }
  return output;
}
module.exports = { names, supplementLabels, supplementTemplates };
