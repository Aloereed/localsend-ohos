const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { load, mocks } = require('./host-runtime.cjs');
const { AppStore, Peer } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const { discoveryTargets, DiscoveryScan } = load('network/DiscoveryScan');
(async () => {
  const links = [
    { name: 'wlan0', ip: '192.168.124.15', prefixLength: 24, ignored: false },
    { name: 'ap0', ip: '172.17.1.1', prefixLength: 24, ignored: false }
  ];
  const targets = Array.from(discoveryTargets(links));
  assert.equal(targets.length, 506); assert.equal(new Set(targets).size, targets.length);
  assert.ok(targets.indexOf('192.168.124.12') < 12, 'nearby PC is early without adding concurrency');
  assert.ok(targets.indexOf('172.17.1.2') < 2, 'hotspot still receives early coverage');
  const work = path.join(__dirname, '../logs/discovery-hints-' + Date.now()); await fs.mkdir(work, { recursive: true });
  const context = { filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) };
  const store = new AppStore(); await store.init(context);
  const service = new LocalSendService(store);
  const peer = Object.assign(new Peer(), { ip: '192.168.124.240', fingerprint: 'remote', protocol: 'https' });
  service.upsertPeer(peer, false); assert.equal(store.discoveryAddresses.length, 0, 'UDP claims cannot seed persistent hints');
  service.upsertPeer(peer, true); await store.persistence;
  // Default host preferences are isolated per open; model reopening the same
  // device's persisted store rather than creating a fresh empty preferences DB.
  mocks['@kit.ArkData'].preferences.getPreferences = async () => store.storage;
  const restored = new AppStore(); await restored.init(context);
  assert.deepEqual(Array.from(restored.discoveryAddresses), ['192.168.124.240:53317']);
  assert.equal(restored.peers.length, 0, 'persisted hint is never displayed as an online device');
  const scan = new DiscoveryScan(), seen = [];
  await scan.run(links, 53317, [], async target => {
    seen.push(target.ip); assert.equal(target.fingerprint, '', 'DHCP hint does not pin an obsolete identity');
  }, false, () => true, ['192.168.124.240', '192.168.124.240', '10.0.0.2', '192.168.124.15']);
  assert.equal(seen[0], '192.168.124.240'); assert.equal(seen.length, 16);
  assert.ok(!seen.includes('10.0.0.2') && !seen.includes('192.168.124.15'));
  for (let i = 1; i <= 20; i++) await store.rememberDiscoveryAddress(`10.0.0.${i}:53317`);
  assert.equal(store.discoveryAddresses.length, 16);
  const before = store.discoveryAddresses.join(','); await store.rememberDiscoveryAddress('10.0.0.20:53317');
  assert.equal(store.discoveryAddresses.join(','), before);
  store.favorites = [peer];
  const events = [];
  service.running = true;
  service.stopNow = async () => { events.push('stop'); service.running = false; };
  service.startNow = async () => { events.push('start'); assert.equal(store.discoveryAddresses.length, 0); service.running = true; };
  store.selecting = true; await service.resetDiscovery(); assert.equal(events.length, 0);
  store.selecting = false; await service.resetDiscovery();
  assert.deepEqual(events, ['stop', 'start']); assert.equal(store.peers.length, 0);
  assert.equal(store.favorites[0], peer, 'reset only affects discovery cache/list');
  assert.equal(await store.storage.get('discoveryAddresses', 'missing'), '[]');
  console.log('PASS nearby-address order, interface fairness, full coverage, verified-only bounded persistence, no stale online devices, preferred revalidation and network filtering');
})().catch(error => { console.error(error); process.exitCode = 1; });
