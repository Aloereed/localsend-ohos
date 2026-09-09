const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const { load, mocks, handles } = require('./host-runtime.cjs');
const { AppStore } = load('model/AppStore');
const { receiveSystemShare } = load('platform/IncomingShare');

(async () => {
  const root = path.join(__dirname, '../logs/incoming-share-' + Date.now());
  await fs.mkdir(root, { recursive: true });
  const cases = [
    [{ name: 'README', utd: 'general.file' }],
    [{ name: 'backup.unknownformat', utd: 'general.file' }],
    [{ name: 'photo.png', utd: 'general.png' }, { name: 'README', utd: 'general.file' },
      { name: 'backup.unknownformat', utd: 'general.file' }, { name: 'notes.txt', utd: 'general.plain-text' }]
  ];
  for (const [index, files] of cases.entries()) {
    const folder = path.join(root, String(index)); await fs.mkdir(folder);
    const store = new AppStore(); store.context = { cacheDir: folder };
    const expected = new Map(), records = [];
    for (const file of files) {
      const uri = path.join(folder, file.name), bytes = crypto.randomBytes(1027);
      await fs.writeFile(uri, bytes); expected.set(file.name, bytes);
      records.push({ uri, utd: file.utd });
    }
    mocks['@kit.ShareKit'].systemShare.getSharedData = async () => ({ getRecords: () => records });
    await receiveSystemShare({ action: 'ohos.want.action.sendData' }, store);
    assert.equal(store.incomingShare, true);
    assert.equal(store.files.length, files.length);
    assert.deepEqual(Array.from(store.files, file => file.name), files.map(file => file.name));
    for (const file of store.files) {
      assert.deepEqual(await fs.readFile(file.uri), expected.get(file.name));
      assert.equal(file.size, expected.get(file.name).length);
    }
    assert.equal(handles.size, 0);
  }
  console.log('PASS incoming system share imports extensionless, unknown extension and mixed files with exact names/bytes and no leaked handles');
})().catch(error => { console.error(error); process.exitCode = 1; });
