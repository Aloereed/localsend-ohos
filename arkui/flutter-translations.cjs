const fs = require('node:fs');
const path = require('node:path');

function classes(source) {
  const starts = [...source.matchAll(/^class\s+(\w+)(?:\s+extends\s+(\w+))?/gm)];
  return starts.map((match, index) => ({ name: match[1], base: match[2],
    body: source.slice(match.index, starts[index + 1]?.index ?? source.length) }));
}

function dartString(literal) {
  const quote = literal[0];
  if ((quote !== "'" && quote !== '"') || literal.at(-1) !== quote) throw new Error('Expected a Dart string literal');
  let value = '';
  for (let index = 1; index < literal.length - 1; index++) {
    let char = literal[index];
    if (char !== '\\') { value += char; continue; }
    char = literal[++index];
    const escapes = { n: '\n', r: '\r', t: '\t', b: '\b', f: '\f', '\\': '\\', "'": "'", '"': '"', '$': '\u0000' };
    if (char in escapes) { value += escapes[char]; continue; }
    if (char === 'u') {
      const match = literal.slice(index + 1).match(/^(?:\{([0-9a-fA-F]+)\}|([0-9a-fA-F]{4}))/);
      if (!match) throw new Error('Invalid Dart Unicode escape');
      value += String.fromCodePoint(parseInt(match[1] || match[2], 16)); index += match[0].length; continue;
    }
    throw new Error('Unsupported Dart escape: ' + char);
  }
  return value;
}

function classPaths(englishClasses) {
  const paths = new Map([['Translations', '']]);
  let changed = true;
  while (changed) {
    changed = false;
    for (const item of englishClasses) {
      if (!paths.has(item.name)) continue;
      for (const child of item.body.matchAll(/late final (\w+) (\w+)\s*=/g)) {
        if (!paths.has(child[1])) {
          paths.set(child[1], [paths.get(item.name), child[2]].filter(Boolean).join('.')); changed = true;
        }
      }
    }
  }
  return paths;
}

function getters(source, paths, english = false) {
  const result = {}, unsupported = [];
  for (const item of classes(source)) {
    const prefix = paths.get(english ? item.name : item.base);
    if (prefix === undefined) throw new Error('Unmapped translation class: ' + item.name);
    for (const getter of item.body.matchAll(/String get (\w+)\s*=>\s*/g)) {
      const start = getter.index + getter[0].length;
      let quote = '', escaped = false, end = start;
      for (; end < item.body.length; end++) {
        const char = item.body[end];
        if (escaped) { escaped = false; continue; }
        if (quote && char === '\\') { escaped = true; continue; }
        if (quote) { if (char === quote) quote = ''; continue; }
        if (char === "'" || char === '"') quote = char;
        else if (char === ';') break;
      }
      const expression = item.body.slice(start, end).trim();
      const key = [prefix, getter[1]].filter(Boolean).join('.');
      if (/^_root\.[\w.]+$/.test(expression)) result[key] = { reference: expression.slice(6) };
      else if (/^(?:'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")$/.test(expression)) result[key] = { value: dartString(expression) };
      else unsupported.push(key);
    }
  }
  return { values: result, unsupported };
}

function resolve(values) {
  const result = {};
  function read(key, seen = new Set()) {
    if (key in result) return result[key];
    if (seen.has(key)) throw new Error('Cyclic translation reference: ' + key);
    if (!values[key]) throw new Error('Missing translation reference: ' + key);
    const next = new Set(seen); next.add(key);
    const entry = values[key];
    let value = entry.reference ? read(entry.reference, next) : entry.value.replace(/\$\{_root\.([\w.]+)\}/g, (_, reference) => read(reference, next));
    if (/\$\{|\$[a-zA-Z_]/.test(value)) throw new Error('Unresolved interpolation: ' + key);
    result[key] = value; return value;
  }
  for (const key of Object.keys(values)) read(key);
  return Object.fromEntries(Object.entries(result).map(([key, value]) => [key, value.replaceAll('\u0000', '$')]));
}

function readCatalog(directory = path.join(__dirname, '../app/lib/gen')) {
  const englishSource = fs.readFileSync(path.join(directory, 'strings_en.g.dart'), 'utf8');
  const paths = classPaths(classes(englishSource));
  const base = getters(englishSource, paths, true);
  const locales = {}, unsupported = {};
  for (const file of fs.readdirSync(directory).filter(file => /^strings_[\w]+\.g\.dart$/.test(file)).sort()) {
    const locale = file.slice(8, -7).replaceAll('_', '-');
    const parsed = locale === 'en' ? base : getters(fs.readFileSync(path.join(directory, file), 'utf8'), paths);
    locales[locale] = resolve({ ...base.values, ...parsed.values });
    unsupported[locale] = parsed.unsupported;
  }
  if (directory === path.join(__dirname, '../app/lib/gen')) {
    const { names, supplementLabels } = require('./upstream-locales.cjs');
    for (const locale of Object.keys(names)) { locales[locale] = supplementLabels(locales.en, locale); unsupported[locale] = []; }
  }
  return { locales, unsupported };
}

module.exports = { readCatalog, classes, classPaths, getters, resolve, dartString };
if (require.main === module) {
  const catalog = readCatalog();
  const destination = path.join(__dirname, 'logs/flutter-runtime-locales.json');
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.writeFileSync(destination, JSON.stringify(catalog, null, 2));
  console.log(JSON.stringify({ locales: Object.keys(catalog.locales).length, englishLabels: Object.keys(catalog.locales.en).length, unsupported: catalog.unsupported }));
}
