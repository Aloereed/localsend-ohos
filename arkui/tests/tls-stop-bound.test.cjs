const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const net = require('node:net');
const tls = require('node:tls');
const { load } = require('./host-runtime.cjs');
const { AppStore } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
(async () => {
  const work = path.join(__dirname, '../logs/tls-stop-' + Date.now()); await fs.mkdir(work, { recursive: true });
  const probe = net.createServer(); await new Promise(resolve => probe.listen(0, '127.0.0.1', resolve));
  const port = probe.address().port; await new Promise(resolve => probe.close(resolve));
  const store = new AppStore(); await store.init({ filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) });
  store.settings.port = port;
  const service = new LocalSendService(store), clients = []; await service.start();
  const server = service.tls;
  try {
    for (let index = 0; index < 6; index++) {
      const client = tls.connect({ host: '127.0.0.1', port, rejectUnauthorized: false, allowHalfOpen: true });
      clients.push(client); client.on('error', () => {}); client.on('data', () => {});
      await new Promise((resolve, reject) => { client.once('secureConnect', resolve); client.once('error', reject); });
    }
    assert.equal(server.clients.size, 6);
    const started = Date.now(); const stopped = server.close();
    const late = tls.connect({ host: '127.0.0.1', port, rejectUnauthorized: false }); clients.push(late);
    await new Promise((resolve, reject) => {
      late.once('secureConnect', () => reject(new Error('a stopping TLS server must not accept another handshake')));
      late.once('error', resolve); late.once('close', resolve);
    });
    await stopped; const elapsed = Date.now() - started;
    assert.equal(server.clients.size, 0, 'all TLS sessions must be disposed');
    assert.ok(elapsed < 2500, `six uncooperative peers must share the close deadline; observed ${elapsed} ms`);
    await service.stop(); await service.start(); assert.equal(store.listenerRunning, true, 'listener can rebind immediately');
    console.log(`PASS six half-open TLS peers stop in ${elapsed} ms, release sessions and allow immediate restart`);
  } finally { clients.forEach(client => client.destroy()); await service.stop(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
