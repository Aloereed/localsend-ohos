const assert = require('node:assert/strict');
const net = require('node:net');
const { load, mocks } = require('./host-runtime.cjs');
const { discoveryPortOpen, Cancellation } = load('network/Transport');
const { DiscoveryScan } = load('network/DiscoveryScan');
const { Peer } = load('model/AppStore');
(async () => {
  let bytes = 0;
  const server = net.createServer(socket => socket.on('data', data => bytes += data.length));
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const peer = Object.assign(new Peer(), { ip: '127.0.0.1', port: server.address().port });
  assert.equal(await discoveryPortOpen(peer, new Cancellation()), true);
  await new Promise(resolve => server.close(resolve));
  assert.equal(bytes, 0, 'quick check never sends application data');
  assert.equal(await discoveryPortOpen(peer, new Cancellation()), false);
  const sockets = mocks['@kit.NetworkKit'].socket, original = sockets.constructTCPSocketInstance;
  let closed = 0;
  sockets.constructTCPSocketInstance = () => ({ async bind() {}, on() {}, connect: () => new Promise(() => {}), async close() { closed++; } });
  try {
    assert.equal(await discoveryPortOpen(peer, new Cancellation(), 20), false); assert.equal(closed, 1);
    const token = new Cancellation(), pending = discoveryPortOpen(peer, token); token.cancel();
    await assert.rejects(pending, /取消/); assert.ok(closed >= 2);
  } finally { sockets.constructTCPSocketInstance = original; }
  let now = Date.now(); const realNow = Date.now; Date.now = () => now;
  const links = [{ name: 'lan', ip: '10.1.2.1', prefixLength: 29, ignored: false }];
  const scan = new DiscoveryScan(); const checks = [], probes = [];
  const check = async target => { checks.push(target.ip); return target.ip.endsWith('.2'); };
  const probe = async target => { probes.push(target.ip); };
  try {
    await scan.run(links, 53317, [], probe, false, () => true, [], check);
    assert.deepEqual(probes, ['10.1.2.2']); assert.equal(checks.length, 5);
    assert.equal(scan.fastPass, false); assert.equal(scan.remaining.length, 4);
    now += 11000;
    await scan.run(links, 53317, [], probe, false, () => true, [], check);
    assert.equal(new Set(probes).size, 5, 'quick-check misses get full protocol probes');
    assert.equal(checks.length, 5, 'slow pass does not repeat the short gate');
    const known = new DiscoveryScan(); let gated = 0;
    await known.run(links, 53317, [], probe, false, () => true, ['10.1.2.2'], async () => { gated++; return true; });
    assert.equal(gated, 4, 'saved endpoints bypass short timeout');
    const manual = new DiscoveryScan();
    await manual.run(links, 53317, [], probe, true, () => true, [], async () => { throw Error('manual must bypass'); });
    const stopped = new DiscoveryScan(); let active = 0;
    const work = stopped.run(links, 53317, [], probe, false, () => true, [], (p, t) => new Promise((resolve, reject) => {
      active++; t.close = () => { active--; reject(Error('cancelled')); };
    }));
    assert.equal(active, 2); stopped.cancel(); await work;
    assert.equal(active, 0); assert.equal(stopped.deferred.length, 0);
    assert.equal(stopped.remaining.length, 0, 'old pass cannot resurrect targets after reset');
  } finally { Date.now = realNow; scan.cancel(); }
  console.log('PASS zero-byte TCP check, refused/timeout/cancel cleanup, fast open-port discovery, full-timeout deferred recovery, known/manual bypass and scan cancellation');
})().catch(error => { console.error(error); process.exitCode = 1; });
