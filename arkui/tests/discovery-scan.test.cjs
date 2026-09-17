const assert = require('node:assert/strict');
const { load } = require('./host-runtime.cjs');
const { discoveryTargets, DiscoveryScan } = load('network/DiscoveryScan');
const { PeerIdentityError } = load('network/Transport');
const { sameSubnet } = load('network/Addresses');
const iface = (ip, prefixLength = 24, ignored = false) => ({ name: 'wlan0', ip, prefixLength, ignored });
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
(async () => {
  assert.deepEqual(Array.from(discoveryTargets([iface('10.2.3.1', 30)])), ['10.2.3.2']);
  assert.deepEqual(Array.from(discoveryTargets([iface('10.2.3.0', 31)])), ['10.2.3.1']);
  assert.equal(discoveryTargets([iface('10.2.3.1', 32)]).length, 0);
  assert.equal(discoveryTargets([iface('10.2.3.1', 8)]).length, 255);
  assert.equal(discoveryTargets([iface('10.2.3.1'), iface('10.2.3.2')]).length, 252);
  assert.equal(discoveryTargets([iface('10.2.3.1', 24, true), iface('::1'), iface('127.0.0.1')]).length, 0);
  assert.equal(sameSubnet('fe80::1234%wlan0', 'fe80:0:0:0:ffff::1%7', 64), true);
  assert.equal(sameSubnet('2001:db8:1::1', '2001:db8:2::1', 64), false);
  assert.equal(sameSubnet('::ffff:192.168.1.1', '::ffff:c0a8:102', 120), true);
  let active = 0, maximum = 0; const seen = [];
  const scan = new DiscoveryScan();
  const probe = async peer => {
    active++; maximum = Math.max(maximum, active); seen.push(peer.ip + '/' + peer.protocol);
    try { await delay(1); if (peer.protocol === 'https' && !peer.ip.endsWith('.2')) throw new Error('HTTP only'); }
    finally { active--; }
  };
  const running = scan.run([iface('10.2.3.1')], 53317, [], probe, true);
  assert.equal(scan.run([iface('10.2.3.1')], 53317, [], probe, true), running);
  await running;
  assert.equal(maximum, 4);
  assert.ok(seen.includes('10.2.3.3/http')); assert.ok(!seen.includes('10.2.3.2/http'));
  const count = seen.length; await scan.run([iface('10.2.3.1')], 53317, [], probe, false); assert.equal(seen.length, count);
  const secure = { ip: '10.2.3.2', port: 53317, protocol: 'https', fingerprint: 'pinned' };
  const attempts = [];
  await new DiscoveryScan().run([iface('10.2.3.1', 30)], 53317, [secure], async peer => {
    attempts.push(peer.protocol); assert.equal(peer.fingerprint, 'pinned'); throw new PeerIdentityError('mismatch');
  }, true);
  assert.deepEqual(attempts, ['https']);
  const stopped = new DiscoveryScan(); let starts = 0;
  const pending = stopped.run([iface('10.2.3.1')], 53317, [], (peer, token) => new Promise((resolve, reject) => {
    starts++; token.close = () => reject(new Error('cancelled'));
  }), true);
  stopped.cancel(); await pending; assert.equal(starts, 4);
  console.log('PASS bounded subnet targets, dual protocol, four-worker manual limit, deduplication, cooldown, pinning and cancellation');
})().catch(error => { console.error(error); process.exitCode = 1; });
