const assert = require('node:assert/strict');
const { load, mocks, timers } = require('./host-runtime.cjs');
let now = 100000, next = 0; const scheduled = new Map();
const originalNow = Date.now; Date.now = () => now;
function schedule(fn, delay, interval = false) { const id = ++next; scheduled.set(id, { fn, due: now + delay, delay, interval }); return id; }
timers.setTimeout = (fn, delay) => schedule(fn, delay);
timers.setInterval = (fn, delay) => schedule(fn, delay, true);
timers.clearTimeout = timers.clearInterval = id => scheduled.delete(id);
async function advance(duration) {
  const end = now + duration;
  while (true) {
    const entry = [...scheduled].filter(([, job]) => job.due <= end).sort((a, b) => a[1].due - b[1].due)[0];
    if (!entry) break;
    const [id, job] = entry; now = job.due;
    if (job.interval) job.due += job.delay; else scheduled.delete(id);
    job.fn(); for (let i = 0; i < 100; i++) await Promise.resolve();
  }
  now = end;
}
const { AppStore, Peer, TransferView } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
mocks['@kit.NetworkKit'].socket.constructTCPSocketServerInstance = () => ({ async listen() {}, on() {}, async close() {} });
(async () => {
  const store = new AppStore(); store.ready = true; store.settings.https = false; store.settings.fingerprint = 'local';
  const service = new LocalSendService(store); service.ensureIdentity = async () => {};
  service.scanPortOpen = async () => true;
  service.readAddresses = async () => { store.interfaces = [{ name: 'ap0', ip: '10.2.3.1', prefixLength: 29, ignored: false }]; store.localIps = ['10.2.3.1']; };
  const peer = (ip, fingerprint) => Object.assign(new Peer(), { ip, fingerprint, protocol: 'http' });
  let lateOnline = false, sweeps = 0, announcements = 0, failNext = false; const renewed = [];
  service.multicast = {
    async sync(links, group, port, v6, force) { if (failNext) { failNext = false; throw new Error('temporary membership failure'); } if (force) renewed.push(now); },
    send() {
      announcements++;
      // An already-known peer answers every announcement before the scan delay.
      timers.setTimeout(() => service.upsertPeer(peer('10.2.3.2', 'known'), true), 10);
    }, async close() {}
  };
  service.probe = async target => {
    if (target.ip === '10.2.3.2' && target.protocol === 'https') sweeps++;
    if (target.ip === '10.2.3.3' && lateOnline) { service.upsertPeer(peer(target.ip, 'late'), true); return; }
    throw new Error('unavailable');
  };
  try {
    await service.start(); await advance(10000);
    assert.equal(sweeps, 1, 'existing device responses must not starve the first automatic sweep');
    assert.equal(store.peers.length, 1); assert.equal(renewed.length, 0);
    lateOnline = true; failNext = true;
    await advance(70000);
    assert.ok(store.peers.some(item => item.fingerprint === 'late'), 'late peer found without any manual discovery call');
    assert.equal(sweeps, 2, 'automatic sweeps retain the one-minute cooldown');
    assert.deepEqual(renewed, [160000]);
    assert.ok(store.logs.some(line => line.includes('temporary membership failure')));
    assert.equal(store.notice, ''); assert.equal(store.error, '');
    const active = new TransferView(); active.status = 'transferring'; store.transfers = [active];
    await advance(70000); assert.equal(sweeps, 2, 'file transfer suppresses expensive scans');
    store.transfers = []; await advance(20000); assert.equal(sweeps, 3, 'automatic scans resume after transfer');
    await service.stop(); const before = announcements; await advance(120000);
    assert.equal(announcements, before); assert.equal(scheduled.size, 0);
  } finally { await service.stop(); Date.now = originalNow; }
  console.log('PASS automatic late-peer discovery despite known responses, periodic rebind, failed-round recovery, cooldown, transfer deferral and stop cleanup');
})().catch(error => { console.error(error); process.exitCode = 1; });
