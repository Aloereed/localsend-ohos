const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const net = require('node:net');
const { load, mocks, handles } = require('./host-runtime.cjs');
const { AppStore, Peer, ShareFile } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const work = path.join(__dirname, '../logs/peer-cancel-' + Date.now());
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(predicate, timeout = 3000) {
  const started = Date.now();
  while (!predicate()) { if (Date.now() - started > timeout) throw new Error('condition timeout'); await delay(5); }
}
async function freePort() {
  const socket = net.createServer(); await new Promise(resolve => socket.listen(0, '127.0.0.1', resolve));
  const port = socket.address().port; await new Promise(resolve => socket.close(resolve)); return port;
}
async function create(name, https) {
  const root = path.join(work, name); await fs.mkdir(root, { recursive: true });
  const store = new AppStore(); await store.init({ filesDir: root, getApplicationContext: () => ({ setColorMode() {} }) });
  store.settings.port = await freePort(); store.settings.quickSave = true; store.settings.https = https;
  const service = new LocalSendService(store); await service.start();
  assert.equal(store.listenerRunning, true);
  return { store, service };
}
(async () => {
  const disk = mocks['@kit.CoreFileKit'].fileIo;
  const open = disk.open, write = disk.write, receiveHandles = new Set();
  disk.open = async (file, mode) => {
    const result = await open(file, mode);
    if (file.endsWith('.part')) receiveHandles.add(result.fd);
    return result;
  };
  disk.write = async (fd, bytes) => { if (receiveHandles.has(fd)) await delay(10); return write(fd, bytes); };
  for (const encrypted of [true, false]) {
    const sender = await create('sender-' + encrypted, encrypted);
    const receiver = await create('receiver-' + encrypted, encrypted);
    try {
      const source = path.join(work, 'source-' + encrypted + '.bin'); await fs.writeFile(source, Buffer.alloc(16 * 1024 * 1024, 0x53));
      const file = new ShareFile(); file.uri = source; file.name = 'large.bin'; file.size = 16 * 1024 * 1024;
      const second = new ShareFile(); second.uri = source; second.name = 'pending.bin'; second.size = file.size;
      const peer = new Peer(); Object.assign(peer, receiver.service.info()); peer.ip = '127.0.0.1';
      const sending = sender.service.send(peer, [file, second]);
      await until(() => receiver.store.transfers[0]?.files[0].transferred > 0);
      const started = Date.now(); receiver.service.cancel(receiver.store.transfers[0].id);
      await until(() => sender.service.sending.size === 0, 1500); await sending;
      assert.equal(sender.store.transfers[0].status, 'cancelled');
      assert.equal(sender.store.transfers[0].files[1].status, 'cancelled');
      assert.ok(Date.now() - started < 1500);
      await until(() => handles.size === 0);
      console.log('PASS two real services receiver cancellation:', encrypted ? 'HTTPS' : 'HTTP', 'sender stopped in', Date.now() - started, 'ms');
      const next = new ShareFile(); next.text = 'retry'; next.name = 'retry.txt'; next.size = 5; next.mime = 'text/plain';
      await sender.service.send(peer, [next]);
      assert.equal(sender.store.transfers[0].status, 'complete');
      assert.equal(receiver.store.history[0].text, 'retry');
      console.log('PASS next transfer immediately succeeds after cancellation');
    } finally { await sender.service.stop(); await receiver.service.stop(); }
  }
  disk.open = open; disk.write = write;
})().catch(error => { console.error(error); process.exitCode = 1; });
