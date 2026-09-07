const assert = require('node:assert/strict');
const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');
const { load } = require('./host-runtime.cjs');
const { AppStore, Peer, ShareFile } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const { transferTotal, transferredBytes } = load('model/TransferMetrics');
(async () => {
  const work = path.join(__dirname, '../logs/send-subset-' + Date.now());
  await fs.mkdir(work, { recursive: true });
  const store = new AppStore();
  await store.init({ filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) });
  const service = new LocalSendService(store);
  let previewOnly = false, observed, uploaded = [];
  const server = http.createServer((req, res) => {
    const parts = []; req.on('data', part => parts.push(part));
    req.on('end', () => {
      if (req.url.includes('prepare-upload')) {
        if (previewOnly) { res.writeHead(204); res.end(); return; }
        const body = JSON.stringify({ sessionId: 'subset', files: { small: 'token' } });
        res.writeHead(200, { 'content-length': Buffer.byteLength(body) }); res.end(body);
      } else {
        const transfer = store.transfers[0];
        observed = { total: transferTotal(transfer), flags: Array.from(transfer.files, file => [file.id, file.selected, file.status]) };
        uploaded.push(Buffer.concat(parts).toString());
        res.writeHead(200, { 'content-length': 0 }); res.end();
      }
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const peer = Object.assign(new Peer(), { ip: '127.0.0.1', port: server.address().port, protocol: 'http', alias: 'Subset receiver' });
    const small = Object.assign(new ShareFile(), { id: 'small', name: 'message', text: 'hello', size: 5 });
    // An unaccepted file must never be opened, even when its source is unavailable.
    const large = Object.assign(new ShareFile(), { id: 'large', name: 'large.bin', uri: path.join(work, 'missing.bin'), size: 3 * 1024 ** 3 });
    await service.send(peer, [small, large]);
    assert.equal(observed.total, 5, 'accepted total must be known before the first upload finishes');
    assert.deepEqual(observed.flags, [['small', true, 'transferring'], ['large', false, 'skipped']]);
    assert.deepEqual(uploaded, ['hello']);
    assert.equal(store.transfers[0].status, 'complete');
    assert.equal(transferredBytes(store.transfers[0]), transferTotal(store.transfers[0]));
    previewOnly = true; await service.send(peer, [small, large]);
    assert.equal(store.transfers[0].status, 'complete');
    assert.equal(transferTotal(store.transfers[0]), 5);
    assert.equal(transferredBytes(store.transfers[0]), 5);
    assert.equal(store.transfers[0].files[1].selected, false);
    assert.deepEqual(uploaded, ['hello'], '204 preview acceptance must not open another upload');
    console.log('PASS partial acceptance freezes progress denominator and 204 preview excludes skipped files');
  } finally { await new Promise(resolve => server.close(resolve)); }
})().catch(error => { console.error(error); process.exitCode = 1; });
