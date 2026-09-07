const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const http = require('node:http');
const net = require('node:net');
const { load } = require('./host-runtime.cjs');
const { AppStore } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const work = path.join(__dirname, '../logs/incoming-messages-' + Date.now());
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(predicate) {
  const start = Date.now();
  while (!predicate()) { if (Date.now() - start > 3000) throw new Error('incoming state timeout'); await delay(5); }
}
function post(port, target, body) {
  const bytes = Buffer.isBuffer(body) ? body : Buffer.from(JSON.stringify(body));
  return new Promise((resolve, reject) => {
    const req = http.request({ host: '127.0.0.1', port, path: target, method: 'POST', headers: { 'content-length': bytes.length } }, res => {
      const chunks = []; res.on('data', bytes => chunks.push(bytes));
      res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(chunks).toString() }));
    });
    req.on('error', reject); req.end(bytes);
  });
}
(async () => {
  await fs.mkdir(work, { recursive: true });
  const probe = net.createServer(); await new Promise(resolve => probe.listen(0, '127.0.0.1', resolve));
  const port = probe.address().port; await new Promise(resolve => probe.close(resolve));
  const store = new AppStore(); await store.init({ filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) });
  store.settings.https = false; store.settings.port = port; store.settings.quickSave = false;
  const service = new LocalSendService(store); await service.start();
  const bytes = Buffer.from('complete content');
  function offer(text = '') {
    const file = id => ({ id, fileName: id + '.txt', fileType: 'text/plain', size: text ? Buffer.byteLength(text) : bytes.length, ...(text ? { preview: text } : {}) });
    return { info: { alias: 'Independent sender', version: '2.1', protocol: 'http', port: 1 }, files: { first: file('first'), second: file('second') } };
  }
  async function pending(payload = offer()) {
    const response = post(port, '/api/localsend/v2/prepare-upload', payload);
    await until(() => store.pendingReceive);
    const id = store.pendingReceive;
    return { id, response, rows: () => store.history.filter(entry => entry.transferId === id) };
  }
  try {
    const batch = await pending(); const originalIds = batch.rows().map(entry => entry.id);
    assert.equal(originalIds.length, 2); assert.ok(batch.rows().every(entry => entry.status === 'waiting' && !entry.path));
    service.renameReceive('first', 'temporary.txt'); service.selectReceiveFile('second', false);
    service.resetReceiveNames();
    const restored = store.transfers.find(transfer => transfer.id === batch.id);
    assert.equal(restored.files.find(file => file.id === 'first').name, 'first.txt');
    assert.ok(restored.files.every(file => file.selected), 'reset restores the complete original selection like Flutter');
    service.renameReceive('first', 'renamed.txt'); service.selectReceiveFile('second', false); service.acceptReceive(true);
    const accepted = await batch.response; assert.equal(accepted.status, 200); const session = JSON.parse(accepted.body);
    assert.deepEqual(Object.keys(session.files), ['first']);
    service.selectReceiveFile('first', false); service.selectReceiveFile('second', true); service.resetReceiveNames();
    const locked = store.transfers.find(transfer => transfer.id === batch.id);
    assert.equal(locked.files.find(file => file.id === 'first').selected, true);
    assert.equal(locked.files.find(file => file.id === 'first').name, 'renamed.txt');
    assert.equal(locked.files.find(file => file.id === 'second').selected, false, 'late UI callbacks cannot change accepted files');
    const upload = await post(port, `/api/localsend/v2/upload?sessionId=${session.sessionId}&fileId=first&token=${session.files.first}`, bytes);
    assert.equal(upload.status, 200); assert.deepEqual(batch.rows().map(entry => entry.id), originalIds);
    const complete = batch.rows().find(entry => entry.status === 'complete'), skipped = batch.rows().find(entry => entry.status === 'skipped');
    assert.equal(complete.name, 'renamed.txt'); assert.deepEqual(await fs.readFile(complete.path), bytes); assert.equal(skipped.path, '');

    const refused = await pending(); service.acceptReceive(false); assert.equal((await refused.response).status, 403);
    assert.equal(refused.rows().length, 2); assert.ok(refused.rows().every(entry => entry.status === 'declined' && !entry.path));
    const cancelled = await pending(); service.cancel(cancelled.id); await cancelled.response;
    assert.equal(cancelled.rows().length, 2); assert.ok(cancelled.rows().every(entry => entry.status === 'cancelled' && !entry.path));

    const deleted = await pending(); for (const entry of deleted.rows()) store.removeHistory(entry.id);
    service.acceptReceive(false); await deleted.response; assert.equal(deleted.rows().length, 0);

    store.settings.saveHistory = false; const temporary = await pending(offer('消息 🌿'));
    store.settings.saveHistory = true; service.acceptReceive(true); assert.equal((await temporary.response).status, 204);
    assert.equal(temporary.rows().length, 2); assert.ok(temporary.rows().every(entry => entry.status === 'complete' && entry.text === '消息 🌿'));
    assert.ok(!JSON.parse(await store.storage.get('history', '[]')).some(entry => entry.transferId === temporary.id));

    const partial = await pending(); service.acceptReceive(true); const partialSession = JSON.parse((await partial.response).body);
    assert.equal((await post(port, `/api/localsend/v2/upload?sessionId=${partialSession.sessionId}&fileId=first&token=${partialSession.files.first}`, bytes)).status, 200);
    service.cancel(partial.id); await store.save();
    const outcomes = partial.rows(); assert.equal(outcomes.length, 2);
    assert.equal(outcomes.find(entry => entry.id.endsWith(':first')).status, 'complete');
    assert.equal(outcomes.find(entry => entry.id.endsWith(':second')).status, 'cancelled');
    assert.equal(outcomes.find(entry => entry.id.endsWith(':second')).path, '');
    assert.equal(JSON.parse(await store.storage.get('history', '[]')).filter(entry => entry.transferId === partial.id).length, 2);
    console.log('PASS real incoming history: consent, rename, subset, rejection, cancellation, deleted/private records, text completion and partial batch');
  } finally { await service.stop(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
