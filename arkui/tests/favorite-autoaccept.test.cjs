const assert = require('node:assert/strict');
const net = require('node:net');
const fs = require('node:fs/promises');
const path = require('node:path');
const { load } = require('./host-runtime.cjs');
const { AppStore, Peer, ShareFile } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
async function create(root) {
  await fs.mkdir(root, { recursive: true }); const socket = net.createServer();
  await new Promise(resolve => socket.listen(0, '127.0.0.1', resolve)); const port = socket.address().port;
  await new Promise(resolve => socket.close(resolve));
  const store = new AppStore(); await store.init({ filesDir: root, getApplicationContext: () => ({ setColorMode() {} }) });
  store.settings.port = port; const service = new LocalSendService(store); await service.start(); return { store, service };
}
(async () => {
  const root = path.join(__dirname, '../logs/favorite-autoaccept-' + Date.now());
  const receiver = await create(path.join(root, 'receiver')), sender = await create(path.join(root, 'sender'));
  const guard = setTimeout(() => receiver.service.acceptReceive(false), 12000);
  try {
    receiver.store.favorites = [Object.assign(new Peer(), sender.service.info(), { ip: '127.0.0.1' })];
    const peer = Object.assign(new Peer(), receiver.service.info(), { ip: '127.0.0.1' });
    const text = 'Favorite 中文 🙂'; const file = Object.assign(new ShareFile(), { text, name: 'message.txt', mime: 'text/plain', size: Buffer.byteLength(text) });
    await sender.service.send(peer, [file]);
    assert.equal(sender.store.transfers[0].status, 'complete', sender.store.transfers[0].error);
    assert.equal(receiver.store.pendingReceive, '');
    receiver.store.settings.favoriteQuickSave = false;
    const pending = sender.service.send(peer, [file]);
    const started = Date.now();
    while (!receiver.store.pendingReceive) { if (Date.now() - started > 6000) throw new Error('Missing manual confirmation'); await new Promise(resolve => setTimeout(resolve, 10)); }
    receiver.service.acceptReceive(false); await pending;
    assert.equal(sender.store.transfers[0].status, 'declined');
    console.log('PASS favorite TLS identity automatically accepts by default; explicit opt-out requires consent');
  } finally { clearTimeout(guard); await sender.service.stop(); await receiver.service.stop(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
