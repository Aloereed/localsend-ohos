const fs = require('node:fs');
const path = require('node:path');
const { classes, classPaths, dartString, readCatalog } = require('./flutter-translations.cjs');
const literalPattern = String.raw`(?:'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")`;

function expressionAt(source, start) {
  let quote = '', escaped = false;
  for (let end = start; end < source.length; end++) {
    const char = source[end];
    if (escaped) { escaped = false; continue; }
    if (quote && char === '\\') { escaped = true; continue; }
    if (quote) { if (char === quote) quote = ''; continue; }
    if (char === "'" || char === '"') quote = char;
    else if (char === ';') return source.slice(start, end).trim();
  }
  throw new Error('Unterminated translation expression');
}

function templateLiteral(literal, parameters, labels) {
  if (!new RegExp('^' + literalPattern + '$').test(literal)) throw new Error('Unsupported template literal');
  return dartString(literal).replace(/\$\{([^}]+)\}|\$([a-zA-Z_]\w*)/g, (_, braced, plain) => {
    const name = braced || plain;
    if (parameters.includes(name)) return '\u0001' + name + '\u0002';
    if (name.startsWith('_root.') && Object.hasOwn(labels, name.slice(6))) return labels[name.slice(6)];
    throw new Error('Unknown template parameter: ' + name);
  }).replaceAll('\u0000', '$');
}

function parseTemplate(expression, parameters, labels) {
  if (new RegExp('^' + literalPattern + '$').test(expression)) {
    return { parameters, plural: '', locale: '', forms: { other: templateLiteral(expression, parameters, labels) } };
  }
  const plural = expression.match(/^\(_root\.\$meta\.cardinalResolver\s*\?\?\s*PluralResolvers\.cardinal\('([^']+)'\)\)\(\s*(\w+)\s*,([\s\S]*)\)$/);
  if (!plural || !parameters.includes(plural[2])) throw new Error('Unsupported template expression');
  const forms = {}; let remaining = plural[3].trim();
  const branch = new RegExp('^(zero|one|two|few|many|other)\\s*:\\s*(' + literalPattern + ')\\s*,?\\s*');
  while (remaining) {
    const match = remaining.match(branch);
    if (!match || Object.hasOwn(forms, match[1])) throw new Error('Unsupported plural branch');
    forms[match[1]] = templateLiteral(match[2], parameters, labels); remaining = remaining.slice(match[0].length);
  }
  if (!Object.hasOwn(forms, 'other')) throw new Error('Plural requires other');
  return { parameters, plural: plural[2], locale: plural[1], forms };
}

function methods(source, paths, labels, english = false) {
  const values = {}, unsupported = {};
  for (const item of classes(source)) {
    const prefix = paths.get(english ? item.name : item.base);
    if (prefix === undefined) throw new Error('Unmapped translation class: ' + item.name);
    for (const method of item.body.matchAll(/String\s+(\w+)\(\{([^}]+)\}\)\s*=>\s*/g)) {
      const key = [prefix, method[1]].filter(Boolean).join('.');
      try {
        const parameters = method[2].split(',').map(part => part.trim()).filter(Boolean).map(part => {
          const match = part.match(/^required\s+(?:Object|num|String|int|double)\s+(\w+)$/);
          if (!match) throw new Error('Unsupported parameter declaration'); return match[1];
        });
        values[key] = parseTemplate(expressionAt(item.body, method.index + method[0].length), parameters, labels);
      } catch (error) { unsupported[key] = error.message; }
    }
  }
  return { values, unsupported };
}

function readTemplates(directory = path.join(__dirname, '../app/lib/gen')) {
  const staticCatalog = readCatalog(directory);
  const english = fs.readFileSync(path.join(directory, 'strings_en.g.dart'), 'utf8');
  const paths = classPaths(classes(english));
  const locales = {}, unsupported = {};
  for (const locale of Object.keys(staticCatalog.locales)) {
    const { names } = require('./upstream-locales.cjs');
    if (locale in names && !fs.existsSync(path.join(directory, 'strings_' + locale + '.g.dart'))) continue;
    // Inherited Dart methods resolve _root references on the localized instance.
    const base = methods(english, paths, staticCatalog.locales[locale], true);
    const source = fs.readFileSync(path.join(directory, 'strings_' + locale.replaceAll('-', '_') + '.g.dart'), 'utf8');
    const own = locale === 'en' ? base : methods(source, paths, staticCatalog.locales[locale]);
    locales[locale] = { ...base.values, ...own.values };
    // Unsupported overrides must never quietly inherit a different English method.
    for (const key of Object.keys(own.unsupported)) delete locales[locale][key];
    unsupported[locale] = own.unsupported;
  }
  if (directory === path.join(__dirname, '../app/lib/gen')) {
    const { names, supplementTemplates } = require('./upstream-locales.cjs');
    for (const locale of Object.keys(names)) {
      locales[locale] = supplementTemplates(locales.en, staticCatalog.locales[locale], locale); unsupported[locale] = {};
    }
  }
  return { locales, unsupported };
}

function renderTemplate(template, values) {
  for (const name of template.parameters) if (!Object.hasOwn(values, name)) throw new Error('Missing parameter: ' + name);
  const number = Number(values[template.plural]);
  if (template.plural && !Number.isFinite(number)) throw new Error('Invalid plural number');
  const category = template.plural ? new Intl.PluralRules(template.locale).select(number) : 'other';
  return (template.forms[category] ?? template.forms.other).replace(/\u0001(\w+)\u0002/g, (_, name) => String(values[name]));
}

module.exports = { expressionAt, templateLiteral, parseTemplate, methods, readTemplates, renderTemplate };
if (require.main === module) {
  const catalog = readTemplates();
  fs.mkdirSync(path.join(__dirname, 'logs'), { recursive: true });
  fs.writeFileSync(path.join(__dirname, 'logs/flutter-runtime-templates.json'), JSON.stringify(catalog, null, 2));
  console.log(JSON.stringify({ locales: Object.keys(catalog.locales).length, englishTemplates: Object.keys(catalog.locales.en).length,
    unsupported: Object.fromEntries(Object.entries(catalog.unsupported).filter(([, values]) => Object.keys(values).length)) }));
}
