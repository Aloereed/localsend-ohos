const assert = require('node:assert/strict');
const { load, mocks, timers } = require('./host-runtime.cjs');
let now = 0, nextId = 0;
const pending = new Map();
function schedule(callback, delay, interval = false) {
  const id = ++nextId; pending.set(id, { callback, at: now + delay, delay, interval }); return id;
}
timers.setTimeout = (fn, ms) => schedule(fn, ms);
timers.setInterval = (fn, ms) => schedule(fn, ms, true);
timers.clearTimeout = timers.clearInterval = id => pending.delete(id);
async function advance(ms) {
  const end = now + ms;
  while (true) {
    const due = [...pending].filter(([, task]) => task.at <= end).sort((a, b) => a[1].at - b[1].at)[0];
    if (!due) break;
    const [id, task] = due; now = task.at;
    if (task.interval) task.at += task.delay; else pending.delete(id);
    task.callback();
    for (let n = 0; n < 12; n++) await Promise.resolve();
  }
  now = end;
}
const { AppStore, TransferView } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
(async () => {
  const store = new AppStore();
  const first = new TransferView(); first.id = 'one';
  const second = new TransferView(); second.id = 'two';
  store.updateTransfer(first); store.updateTransfer(second);
  first.status = 'transferring'; store.updateTransfer(first);
  assert.deepEqual(Array.from(store.transfers, item => item.id), ['two', 'one']);
  store.transfers = [];
  console.log('PASS progress updates preserve transfer order');
  store.notice = 'first'; await advance(3000);
  store.notice = 'second'; await advance(500); assert.equal(store.notice, 'second');
  await advance(3000); assert.equal(store.notice, '');
  store.error = 'error'; await advance(7999); assert.equal(store.error, 'error');
  await advance(1); assert.equal(store.error, '');
  store.notice = 'dismiss'; store.notice = ''; await advance(3500); assert.equal(store.notice, '');
  console.log('PASS notification expiry, replacement, error duration and manual dismissal');

  let scans = 0, announcements = 0;
  const { PullServer } = load('network/PullSocket');
  const { NativeDatagram } = load('network/NativeDatagram');
  PullServer.prototype.listen = async () => {};
  PullServer.prototype.close = async () => {};
  NativeDatagram.prototype.listen = async () => {};
  NativeDatagram.prototype.send = async () => { announcements++; };
  NativeDatagram.prototype.close = async () => {};
  store.ready = true; store.settings.https = false;
  const service = new LocalSendService(store);
  service.readAddresses = async () => { scans++; store.localIps = ['192.168.1.2']; };
  await service.start(); assert.equal(announcements, 1);
  await advance(800); assert.equal(announcements, 2);
  await advance(5200); assert.equal(announcements, 4);
  await advance(9000); assert.equal(announcements, 5); assert.equal(scans, 5);
  assert.equal(store.notice, ''); assert.equal(store.error, '');
  await service.pause(); await service.discover(false); await service.start();
  await advance(30000); assert.equal(announcements, 5); assert.equal(store.listenerRunning, false);
  await service.resume(); assert.equal(store.listenerRunning, true); assert.equal(announcements, 6);
  await service.stop();
  assert.equal(pending.size, 0);
  console.log('PASS automatic discovery burst, recurring address refresh, silent operation, manual pause persistence and resume cleanup');
})().catch(error => { console.error(error); process.exitCode = 1; });
