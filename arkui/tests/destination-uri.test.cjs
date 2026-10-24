const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { load, mocks, handles } = require('./host-runtime.cjs');
const { AppStore, HistoryEntry } = load('model/AppStore');

(async () => {
  const root = path.join(__dirname, '../logs/destination-uri-' + Date.now()).replaceAll('\\', '/');
  await fs.mkdir(root, { recursive: true });
  const downloads = root + '/Download/com.aloereed.aloesend';
  const custom = root + '/中文 空格 100% #目录';
  await fs.mkdir(downloads, { recursive: true }); await fs.mkdir(custom);
  const downloadUri = 'file://docs/storage/Users/currentUser/Download/com.aloereed.aloesend';
  const customUri = 'file://docs/storage/Users/currentUser/' + encodeURIComponent('中文 空格 100% #目录');
  const paths = new Map([[downloadUri, downloads], [customUri, custom]]);
  const kit = mocks['@kit.CoreFileKit'];
  // Emulate the system URI-to-path mapping. File I/O deliberately rejects URI
  // arguments so a permissive host adapter cannot hide the original regression.
  kit.fileUri.FileUri = class {
    constructor(uri) { assert.ok(paths.has(uri), 'convert the original picker URI'); this.path = paths.get(uri); }
  };
  for (const operation of ['access', 'stat', 'mkdir', 'open']) {
    const original = kit.fileIo[operation];
    kit.fileIo[operation] = async (target, ...args) => {
      assert.ok(typeof target !== 'string' || !target.startsWith('file://'), operation + ' requires a filesystem path');
      return original(target, ...args);
    };
  }
  const calls = [];
  let selected = downloadUri, revoked = false;
  kit.picker.DocumentSelectOptions = class {};
  kit.picker.DocumentSelectMode = { FOLDER: 1 };
  kit.picker.DocumentViewPicker = class { async select() { return [selected]; } };
  kit.fileShare.persistPermission = async policies => calls.push(['persist', policies[0].uri, policies[0].operationMode]);
  kit.fileShare.activatePermission = async policies => {
    calls.push(['activate', policies[0].uri, policies[0].operationMode]);
    if (revoked) throw new Error('grant revoked');
  };
  const context = { filesDir: root, getApplicationContext: () => ({ setColorMode() {} }) };
  const store = new AppStore(); store.downloadDirectory = downloads; await store.init(context);
  const entry = new HistoryEntry(); entry.name = '子目录/data #100%.bin'; entry.path = root + '/source.bin';
  const bytes = Buffer.from([0, 128, 255, 7]); await fs.writeFile(entry.path, bytes);

  await store.chooseDestination();
  assert.equal(store.settings.destination, downloadUri, 'persist the URI, not its converted path');
  await store.saveReceivedCopy(entry);
  assert.equal(store.error, '', 'a selected download URI must not trigger sandbox-only fallback');
  assert.ok(entry.exportedPath.startsWith(downloads + '/'));
  assert.deepEqual(await fs.readFile(entry.exportedPath), bytes);
  assert.deepEqual(calls, [['persist', downloadUri, 3], ['activate', downloadUri, 3], ['activate', downloadUri, 3]]);

  selected = customUri; await store.chooseDestination(); calls.length = 0;
  // A restored folder setting must activate the exact original URI on the next
  // instance, including encoded characters; no picker or new grant is needed.
  const restarted = new AppStore(); restarted.downloadDirectory = downloads; await restarted.init(context);
  restarted.settings.destinationMode = 'folder'; restarted.settings.destination = store.settings.destination;
  await restarted.saveReceivedCopy(entry, undefined, 'restart');
  assert.equal(restarted.error, '');
  assert.equal(entry.exportedPath, custom + '/AloeSend-restart/子目录/data #100%.bin');
  assert.deepEqual(await fs.readFile(entry.exportedPath), bytes);
  const first = entry.exportedPath;
  await restarted.saveReceivedCopy(entry, customUri, 'restart');
  assert.notEqual(entry.exportedPath, first);
  assert.deepEqual(await fs.readFile(first), bytes);
  assert.deepEqual(await fs.readFile(entry.exportedPath), bytes);
  assert.deepEqual(calls, [['activate', customUri, 3], ['activate', customUri, 3]]);

  const latest = entry.exportedPath;
  revoked = true; await restarted.saveReceivedCopy(entry, customUri, 'revoked');
  assert.equal(entry.exportedPath, latest); assert.match(restarted.error, /文件已接收/);
  assert.equal(restarted.settings.destination, customUri);
  assert.deepEqual(await fs.readFile(entry.path), bytes);
  assert.equal(handles.size, 0);
  console.log('PASS picker download/custom URIs, original policy identity, encoded paths, restart, collision and revoked-grant recovery');
})().catch(error => { console.error(error); process.exitCode = 1; });
