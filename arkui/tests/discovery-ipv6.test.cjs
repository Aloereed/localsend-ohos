const assert = require('node:assert/strict');
const net = require('node:net');
const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const { load, handles } = require('./host-runtime.cjs');
const { AppStore, Peer, ShareFile } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
async function create(root, https) {
  await fs.mkdir(root, { recursive: true });
  const test = net.createServer(); await new Promise(resolve => test.listen(0, '127.0.0.1', resolve));
  const port = test.address().port; await new Promise(resolve => test.close(resolve));
  const store = new AppStore(); await store.init({ filesDir: root, getApplicationContext: () => ({ setColorMode() {} }) });
  store.settings.port = port; store.settings.https = https; store.settings.quickSave = true;
  const service = new LocalSendService(store); await service.start();
  return { service, store };
}
(async () => {
  const root = path.join(__dirname, '../logs/discovery-ipv6-' + Date.now());
  for (const encrypted of [false, true]) {
    const receiver = await create(path.join(root, 'receiver-' + encrypted), encrypted);
    const sender = await create(path.join(root, 'sender-' + encrypted), !encrypted);
    try {
      assert.ok(encrypted ? receiver.service.tls6 : receiver.service.tcp6, 'IPv6 listener must bind alongside IPv4');
      const peer = Object.assign(new Peer(), receiver.service.info(), { ip: '::1' });
      await sender.service.probe(peer);
      assert.ok(sender.store.peers.some(p => p.fingerprint === receiver.store.settings.fingerprint));
      assert.ok(receiver.store.peers.some(p => p.fingerprint === sender.store.settings.fingerprint), 'reciprocal IPv6 discovery');
      const bytes = crypto.randomBytes(1048593); const uri = path.join(root, 'sample-' + encrypted);
      await fs.writeFile(uri, bytes);
      const file = Object.assign(new ShareFile(), { id: 'ipv6', name: 'ipv6.bin', uri, size: bytes.length });
      await sender.service.send(peer, [file]);
      assert.equal(sender.store.transfers[0].status, 'complete', sender.store.transfers[0].error);
      const saved = receiver.store.history.find(item => item.status === 'complete');
      assert.ok(saved); assert.deepEqual(await fs.readFile(saved.path), bytes);
      await sender.service.probe(Object.assign(new Peer(), peer, { ip: '127.0.0.1' }));
      assert.equal(handles.size, 0);
      console.log('PASS simultaneous IPv4/IPv6 ' + (encrypted ? 'HTTPS' : 'HTTP') + ', reciprocal discovery, mixed local encryption and exact 1 MiB upload');
    } finally { await sender.service.stop(); await receiver.service.stop(); }
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
