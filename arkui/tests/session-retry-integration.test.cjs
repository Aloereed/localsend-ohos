const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const net = require('node:net');
const { load, mocks, handles } = require('./host-runtime.cjs');
const { AppStore, Peer, ShareFile } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const work = path.join(__dirname, '../logs/session-retry-' + Date.now());
async function create(name, encrypted) {
  const root = path.join(work, name); await fs.mkdir(root, { recursive: true });
  const probe = net.createServer(); await new Promise(resolve => probe.listen(0, '127.0.0.1', resolve));
  const port = probe.address().port; await new Promise(resolve => probe.close(resolve));
  const store = new AppStore(); await store.init({ filesDir: root, getApplicationContext: () => ({ setColorMode() {} }) });
  store.settings.port = port; store.settings.quickSave = true; store.settings.https = encrypted;
  const service = new LocalSendService(store); await service.start(); assert.equal(store.listenerRunning, true);
  return { store, service };
}
(async () => {
  for (const encrypted of [true, false]) {
    const sender = await create('sender-' + encrypted, encrypted);
    const receiver = await create('receiver-' + encrypted, encrypted);
    const disk = mocks['@kit.CoreFileKit'].fileIo, write = disk.write;
    try {
      let offers = 0;
      const prepare = receiver.service.prepare.bind(receiver.service);
      receiver.service.prepare = async (...args) => { offers++; return prepare(...args); };
      const bytes = Buffer.alloc(256 * 1024, 0x71);
      const source = path.join(work, 'source-' + encrypted); await fs.writeFile(source, bytes);
      const files = ['first', 'second'].map(id => Object.assign(new ShareFile(), { id, name: id + '.bin', uri: source, size: bytes.length }));
      let fail = true;
      disk.write = async (fd, bytes) => {
        if (fail) { fail = false; throw Object.assign(new Error('No space left'), { code: 13900025 }); }
        return write(fd, bytes);
      };
      const peer = Object.assign(new Peer(), receiver.service.info(), { ip: '127.0.0.1' });
      const id = await sender.service.send(peer, files);
      assert.deepEqual(sender.store.transfers[0].files.map(file => file.status), ['error', 'complete']);
      assert.deepEqual(receiver.store.transfers[0].files.map(file => file.status), ['error', 'complete']);
      const receiveId = receiver.store.transfers[0].id;
      await sender.service.retry(id, 'first');
      assert.equal(sender.store.transfers[0].id, id);
      assert.equal(receiver.store.transfers[0].id, receiveId);
      assert.equal(sender.store.transfers[0].status, 'complete');
      assert.equal(receiver.store.transfers[0].status, 'complete');
      assert.equal(offers, 1, 'retry must not repeat receive confirmation');
      assert.equal(receiver.store.history.length, 2);
      assert.equal(sender.store.history.length, 2);
      for (const item of receiver.store.history) {
        assert.equal(item.status, 'complete'); assert.equal(item.error, '');
        assert.deepEqual(await fs.readFile(item.path), bytes);
      }
      assert.equal(handles.size, 0);
      console.log(`PASS ${encrypted ? 'HTTPS' : 'HTTP'} native peers recover disk failure in original session with exact files and consent once`);
    } finally { disk.write = write; await sender.service.stop(); await receiver.service.stop(); }
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
