const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const http = require('node:http');
const { load, mocks } = require('./host-runtime.cjs');
const { AppStore, Peer, ShareFile, historyStatus } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const work = path.join(__dirname, '../logs/message-status-' + Date.now());
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(predicate) {
  const start = Date.now();
  while (!predicate()) { if (Date.now() - start > 3000) throw new Error('message state timeout'); await delay(5); }
}
(async () => {
  await fs.mkdir(work, { recursive: true });
  const context = { filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) };
  const store = new AppStore(); await store.init(context);
  const service = new LocalSendService(store);
  let prepared, payload, uploadCount = 0, failSecond = false;
  const server = http.createServer((req, res) => {
    const chunks = []; req.on('data', bytes => chunks.push(bytes));
    req.on('end', () => {
      if (req.url.includes('prepare-upload')) {
        payload = JSON.parse(Buffer.concat(chunks)); prepared = res;
      } else if (req.url.includes('/upload?')) {
        uploadCount++; res.writeHead(failSecond && uploadCount === 2 ? 500 : 200); res.end('{}');
      } else { res.writeHead(200); res.end('{}'); }
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const peer = new Peer(); peer.ip = '127.0.0.1'; peer.port = server.address().port; peer.protocol = 'http'; peer.alias = 'Independent peer';
  function files() {
    return ['First message', 'Second message'].map(text => {
      const file = new ShareFile(); file.name = text; file.text = text; file.mime = 'text/plain'; file.size = Buffer.byteLength(text); return file;
    });
  }
  async function start() {
    prepared = null; payload = null; uploadCount = 0;
    const done = service.send(peer, files()); await until(() => prepared);
    const id = store.transfers[0].id;
    return { done, id, rows: () => store.history.filter(entry => entry.transferId === id) };
  }
  function accept() { prepared.writeHead(200); prepared.end(JSON.stringify({ sessionId: 'fixture', files: Object.fromEntries(Object.keys(payload.files).map(id => [id, 'token'])) })); }
  try {
    const refused = await start(); const ids = refused.rows().map(entry => entry.id);
    assert.equal(ids.length, 2); assert.ok(refused.rows().every(entry => entry.status === 'waiting'));
    assert.ok(JSON.parse(await store.storage.get('history', '[]')).some(entry => entry.transferId === refused.id));
    prepared.writeHead(403); prepared.end('{}'); await refused.done;
    assert.deepEqual(refused.rows().map(entry => entry.id), ids);
    assert.ok(refused.rows().every(entry => entry.status === 'declined' && entry.error.includes('拒绝')));
    assert.equal(historyStatus(refused.rows()[0]), '已拒绝');
    const refusedTransfer = store.transfers.find(item => item.id === refused.id);
    assert.equal(refusedTransfer.status, 'declined');
    assert.ok(refusedTransfer.files.every(file => file.status === 'declined'));
    await service.retry(refused.id);
    assert.equal(store.transfers[0].id, refused.id, 'declined requests must not expose failure retry semantics');

    const partial = await start(); failSecond = true; accept(); await partial.done;
    assert.equal(partial.rows().find(entry => entry.text === 'First message').status, 'complete');
    assert.equal(partial.rows().find(entry => entry.text === 'Second message').status, 'error');
    assert.match(partial.rows().find(entry => entry.status === 'error').error, /500/); failSecond = false;

    const cancelled = await start(); service.cancel(cancelled.id); await cancelled.done;
    assert.ok(cancelled.rows().every(entry => entry.status === 'cancelled'));
    prepared.end('{}');

    const deleted = await start(); for (const entry of deleted.rows()) store.removeHistory(entry.id);
    await store.save(); prepared.writeHead(204); prepared.end(); await deleted.done;
    assert.equal(deleted.rows().length, 0, 'completion must not resurrect messages deleted during transfer');

    store.settings.saveHistory = false; const privateSession = await start();
    store.settings.saveHistory = true; accept(); await privateSession.done;
    assert.ok(privateSession.rows().every(entry => entry.status === 'complete'));
    assert.ok(!JSON.parse(await store.storage.get('history', '[]')).some(entry => entry.transferId === privateSession.id), 'status updates must not persist a private session after the setting changes');

    const interrupted = await start();
    const preferences = mocks['@kit.ArkData'].preferences, openPreferences = preferences.getPreferences;
    const restarted = new AppStore();
    // The general host adapter returns a fresh store per init. Reopen the
    // actual saved values here so the restart assertion cannot pass on [] .
    preferences.getPreferences = async () => store.storage;
    try { await restarted.init(context); } finally { preferences.getPreferences = openPreferences; }
    const recovered = restarted.history.filter(entry => entry.transferId === interrupted.id);
    assert.equal(recovered.length, 2); assert.ok(recovered.every(entry => entry.status === 'error' && entry.error.includes('未完成')));
    const persisted = JSON.parse(await restarted.storage.get('history', '[]')).filter(entry => entry.transferId === interrupted.id);
    assert.equal(persisted.length, 2); assert.ok(persisted.every(entry => entry.status === 'error'));
    service.cancel(interrupted.id); await interrupted.done; prepared.end('{}');
    console.log('PASS real outgoing messages: pending persistence, rejection, partial failure, cancellation, deletion, private history and interrupted restart');
  } finally { await service.stop(); server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); }
})().catch(error => { console.error(error); process.exitCode = 1; });
