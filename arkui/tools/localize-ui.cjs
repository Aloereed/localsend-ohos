// Wrap authored UI literals once; never translate user text, paths or messages.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.join(__dirname, '../AloeSend/entry/src/main/ets');
const localePath = path.join(root, 'model/Locale.ets');
let locale = fs.readFileSync(localePath, 'utf8');
const start = locale.indexOf('= {') + 2; const end = locale.indexOf('\n};', start) + 2;
const table = vm.runInNewContext('(' + locale.slice(start, end) + ')');
locale = locale.slice(0, start) + JSON.stringify(table, null, 2) + locale.slice(end);
fs.writeFileSync(localePath, locale);
const missing = new Set();
for (const directory of ['components', 'pages']) {
  for (const name of fs.readdirSync(path.join(root, directory)).filter(name => name.endsWith('.ets'))) {
    if (['AppIcon.ets', 'EmptyState.ets'].includes(name)) continue;
    const file = path.join(root, directory, name); const original = fs.readFileSync(file, 'utf8');
    const updated = original.replace(/'((?:\\.|[^'\\])*)'/g, (literal, body, offset) => {
      if (!/[\u3400-\u9fff]/.test(body)) return literal;
      const before = original.slice(Math.max(0, offset - 30), offset);
      if (/\.(?:t|startsWith|endsWith|includes)\($/.test(before)) return literal;
      const value = body.replace(/\\n/g, '\n').replace(/\\'/g, "'");
      if (!table[value]) { missing.add(value); return literal; }
      return `this.store.t(${literal})`;
    });
    fs.writeFileSync(file, updated);
  }
}
console.log('Unmapped UI literals:', [...missing]);
