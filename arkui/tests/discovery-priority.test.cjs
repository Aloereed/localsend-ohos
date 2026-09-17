const assert = require('node:assert/strict');
const { load, timers } = require('./host-runtime.cjs');
let now = 100000, next = 0; const scheduled = new Map();
const realNow = Date.now; Date.now = () => now;
timers.setTimeout = (fn, delay) => { const id = ++next; scheduled.set(id, { fn, due: now + delay, interval: 0 }); return id; };
timers.setInterval = (fn, delay) => { const id = ++next; scheduled.set(id, { fn, due: now + delay, interval: delay }); return id; };
timers.clearTimeout = timers.clearInterval = id => scheduled.delete(id);
async function advance(ms) {
  const end = now + ms;
  for (let i = 0; i < 30; i++) await Promise.resolve();
  while (true) {
    const entry = [...scheduled].filter(([, job]) => job.due <= end).sort((a, b) => a[1].due - b[1].due)[0];
    if (!entry) break;
    const [id, job] = entry; now = job.due;
    if (job.interval) job.due += job.interval; else scheduled.delete(id);
    job.fn(); for (let i = 0; i < 30; i++) await Promise.resolve();
  }
  now = end;
}
const { DiscoveryScan, discoveryTargets } = load('network/DiscoveryScan');
const { AppStore, TransferView } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const links = ['192.168.1.1', '172.20.10.1'].map((ip, i) => ({ name: 'net' + i, ip, prefixLength: 28, ignored: false }));
(async () => {
  const scan = new DiscoveryScan(); let active = 0, maximum = 0, allowed = true;
  const requests = [], completed = new Set();
  const fast = async peer => {
    active++; maximum = Math.max(maximum, active); requests.push({ ip: peer.ip, time: now });
    try { await Promise.resolve(); completed.add(peer.ip); throw new Error('not listening'); }
    finally { active--; }
  };
  try {
    const first = scan.run(links, 53317, [], fast, false, () => allowed); await advance(6000); await first;
    assert.equal(maximum, 2); assert.equal(completed.size, 16);
    assert.equal([...completed].filter(ip => ip.startsWith('192.')).length, 8, 'both interfaces get coverage in the first batch');
    const buckets = new Map(); for (const req of requests) { const key = Math.floor(req.time / 100); buckets.set(key, (buckets.get(key) || 0) + 1); }
    assert.ok([...buckets.values()].every(count => count <= 2), 'instant failures cannot flood the event loop');
    await scan.run(links, 53317, [], fast, false); assert.equal(completed.size, 16, 'short batch cooldown');
    await advance(6000);
    const blocked = [];
    const slow = (peer, token) => new Promise((resolve, reject) => {
      active++; blocked.push(peer.ip); token.close = () => { active--; reject(new Error('cancelled')); };
    });
    const second = scan.run(links, 53317, [], slow, false, () => allowed);
    assert.equal(active, 2); allowed = false; await advance(100); await second;
    assert.equal(active, 0); assert.equal(scheduled.size, 0, 'busy state closes in-flight work within one monitor tick');
    allowed = true; await advance(10000);
    const resumed = scan.run(links, 53317, [], fast, false, () => allowed); await advance(6000); await resumed;
    assert.equal(completed.size, discoveryTargets(links).length, 'resume includes interrupted hosts and does not restart completed hosts');
    assert.equal(requests.filter(req => [...completed][0] === req.ip).length, 2);
    const count = requests.length; await scan.run(links, 53317, [], fast, false); assert.equal(requests.length, count, 'completed sweep retains minute cooldown');
    scan.cancel(); const timed = scan.run(links, 53317, [], slow, false); await advance(6000); await timed;
    assert.equal(active, 0); assert.equal(scheduled.size, 0, 'six-second slice cancels unresponsive sockets');
    await advance(10000); const newBlocked = blocked.length;
    const following = scan.run(links, 53317, [], slow, false); assert.notEqual(blocked[newBlocked], blocked[newBlocked - 2], 'timed-out hosts move behind unvisited hosts');
    scan.cancel(); await following; assert.equal(scheduled.size, 0);
    const store = new AppStore(), service = new LocalSendService(store);
    assert.equal(service.scanAvailable(), true);
    for (const flag of ['busy', 'selecting', 'webStarting', 'webTemplateBusy']) {
      store[flag] = true; assert.equal(service.scanAvailable(), false, flag); store[flag] = false;
    }
    store.webRequests = [{}]; assert.equal(service.scanAvailable(), false); store.webRequests = [];
    for (const status of ['waiting', 'transferring']) { const item = new TransferView(); item.status = status; store.transfers = [item]; assert.equal(service.scanAvailable(), false); }
    const hashing = new TransferView(); hashing.status = 'error'; hashing.hashing = true; store.transfers = [hashing]; assert.equal(service.scanAvailable(), false);
    store.transfers = []; assert.equal(service.scanAvailable(), true);
    console.log('PASS two automatic workers, paced refusals, 16-host batches, interface fairness, busy interruption, resume, six-second budget, minute full-sweep cooldown and normal-operation priority');
  } finally { scan.cancel(); Date.now = realNow; }
})().catch(error => { console.error(error); process.exitCode = 1; });
