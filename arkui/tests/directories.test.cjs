const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { load } = require('./host-runtime.cjs');
const { ensureDirectory } = load('platform/Directories');
(async () => {
  const root = path.join(__dirname, '../logs/directory-fixture-' + Date.now());
  await fs.mkdir(root, { recursive: true });
  await ensureDirectory(root);
  await Promise.all([ensureDirectory(root + '/shared/child'), ensureDirectory(root + '/shared/child')]);
  await ensureDirectory(root + '/shared/child');
  assert.equal((await fs.stat(root + '/shared/child')).isDirectory(), true);
  await fs.writeFile(root + '/file', 'keep');
  await assert.rejects(ensureDirectory(root + '/file'));
  assert.equal(await fs.readFile(root + '/file', 'utf8'), 'keep');
  console.log('PASS existing and concurrent directory creation under HarmonyOS EEXIST behavior, file collision preservation');
})().catch(error => { console.error(error); process.exitCode = 1; });
