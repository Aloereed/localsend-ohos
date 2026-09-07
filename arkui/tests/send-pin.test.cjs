const assert = require('node:assert/strict');
const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');
const { load } = require('./host-runtime.cjs');
const { AppStore, Peer, ShareFile } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(predicate) {
  const start = Date.now();
  while (!predicate()) { if (Date.now() - start > 3000) throw new Error('PIN prompt timeout'); await delay(5); }
}
(async () => {
  const work = path.join(__dirname, '../logs/send-pin-' + Date.now()); await fs.mkdir(work, { recursive: true });
  const store = new AppStore(); await store.init({ filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) });
  const service = new LocalSendService(store), correct = 'Ab9+ /?中文-long-PIN-123', pins = [];
  const server = http.createServer((req, res) => {
    req.resume(); req.on('end', () => {
      const pin = new URL(req.url, 'http://localhost').searchParams.get('pin'); pins.push(pin);
      res.writeHead(pin === correct ? 204 : 401, { 'content-length': 0 }); res.end();
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const peer = Object.assign(new Peer(), { ip: '127.0.0.1', port: server.address().port, protocol: 'http', alias: 'PIN peer' });
    const file = Object.assign(new ShareFile(), { text: 'hello', size: 5, name: 'message' });
    const sending = service.send(peer, [file]);
    await until(() => store.pendingPin); assert.equal(store.pendingPinInvalid, false);
    service.submitPin('wrong'); await until(() => store.pendingPinInvalid);
    assert.ok(store.pendingPin); service.submitPin(correct); await sending;
    assert.deepEqual(pins, [null, 'wrong', correct], 'PIN must survive URL encoding without trimming or truncation');
    assert.equal(store.transfers[0].status, 'complete');
    assert.equal(store.pendingPin, ''); assert.equal(store.pendingPinInvalid, false);
    const cancelled = service.send(peer, [file]); await until(() => store.pendingPin);
    assert.equal(store.pendingPinInvalid, false, 'a new prompt must not inherit invalid-PIN feedback');
    service.submitPin(''); await cancelled;
    assert.equal(store.transfers[0].status, 'cancelled'); assert.equal(store.pendingPin, '');
    assert.equal(pins.length, 4, 'cancel must not submit an empty PIN to the peer');
    console.log('PASS alphanumeric/Unicode PIN, incorrect retry feedback and prompt cancellation reset');
  } finally { service.cancelAll(); await new Promise(resolve => server.close(resolve)); }
})().catch(error => { console.error(error); process.exitCode = 1; });
