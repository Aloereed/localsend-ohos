const assert = require('node:assert/strict');
const { load, mocks } = require('./host-runtime.cjs');
const original = mocks['libaloetls.so'];
const native = Object.create(original); mocks['libaloetls.so'] = native;
const opened = [], stopped = [], sent = [], callbacks = new Map(); let sequence = 0, fail = true;
Object.defineProperties(native, {
  multicastOpen: { value(group, port, address, cb) {
    opened.push([group, port, address]);
    if (address === '10.0.0.2' && fail) throw new Error('network not ready');
    const id = ++sequence; callbacks.set(id, cb); return id;
  } },
  multicastStop: { value(id) { stopped.push(id); setImmediate(() => callbacks.get(id)?.({ kind: 'stopped', error: '' })); } },
  multicastSend: { value(id) { sent.push(id); } }
});
const { DiscoveryMulticast } = load('network/DiscoveryMulticast');
const { LocalSendService } = load('network/LocalSendService');
const { AppStore, Peer } = load('model/AppStore');
const iface = (name, ip, ignored = false) => ({ name, ip, ignored, prefixLength: 24 });
(async () => {
  let messages = 0; const logs = [];
  const manager = new DiscoveryMulticast(() => messages++, text => logs.push(text));
  const networks = [iface('wlan0', '10.0.0.2'), iface('eth0', '192.168.2.2'), iface('vpn', '172.16.0.1', true),
    iface('wlan0', 'fe80::1'), iface('wlan0', '2001:db8::1')];
  await manager.sync(networks, '224.0.0.167', 53317, true);
  assert.equal(opened.length, 3); // failure on one IPv4 network preserves eth0 and one IPv6 socket
  manager.send(new Uint8Array([1])); assert.equal(sent.length, 2);
  fail = false; await manager.sync(networks, '224.0.0.167', 53317, true);
  assert.equal(opened.length, 4); assert.equal(stopped.length, 0);
  await manager.sync([networks[0]], '224.0.0.167', 53317, false);
  assert.equal(stopped.length, 2);
  const old = sequence;
  await manager.sync([networks[0]], '224.0.0.167', 53317, false, true);
  assert.ok(stopped.includes(old)); assert.equal(sequence, old + 1);
  callbacks.get(old)({ kind: 'message', data: new ArrayBuffer(1), ip: '10.0.0.3', port: 53317 });
  assert.equal(messages, 0, 'retired listener must not deliver stale packets');
  callbacks.get(sequence)({ kind: 'stopped', error: 'socket reclaimed' });
  await manager.sync([networks[0]], '224.0.0.167', 53317, false);
  assert.equal(sequence, old + 2);
  const created = sequence;
  const sync = manager.sync(networks, '224.0.0.167', 53317, true);
  const closing = manager.close(); await Promise.all([sync, closing]);
  assert.equal(sequence, created, 'queued sync cannot resurrect a stopped discovery');
  const store = new AppStore(); const service = new LocalSendService(store);
  mocks['@kit.NetworkKit'].connection.getAllNets = async () => [{ netId: 1 }, { netId: 2 }];
  mocks['@kit.NetworkKit'].connection.getConnectionProperties = async net => {
    if (net.netId === 1) throw new Error('obsolete cellular network');
    return { interfaceName: 'wlan0', linkAddresses: [{ address: { address: '192.168.1.2' }, prefixLength: 24 }] };
  };
  await service.readAddresses(); assert.deepEqual(Array.from(store.localIps), ['192.168.1.2']);
  store.settings.fingerprint = 'local'; service.ensureIdentity = async () => {};
  const routes = [];
  service.request = async (peer, method, path) => {
    routes.push(peer.protocol + ' ' + method);
    if (peer.protocol === 'http') throw new Error('设备提前关闭了连接');
    return { status: 200, fingerprint: 'remote', body: JSON.stringify({ alias: 'remote', version: '2.2' }) };
  };
  await service.register(Object.assign(new Peer(), { ip: '192.168.1.3', protocol: 'http', fingerprint: 'remote' }));
  assert.deepEqual(routes, ['http POST', 'https GET', 'https POST']);
  service.running = true; let registered = 0; service.register = async () => { registered++; };
  const packet = info => ({ message: Uint8Array.from(Buffer.from(JSON.stringify(info))).buffer, remoteInfo: { address: '192.168.1.3' } });
  const info = { alias: 'v2.2 peer', version: '2.2', fingerprint: 'other', protocol: 'http' };
  service.discovered(packet(info)); service.discovered(packet(info)); assert.equal(registered, 1);
  store.settings.visible = false; service.discovered(packet({ ...info, fingerprint: 'hidden' })); assert.equal(registered, 1);
  console.log('PASS per-interface joins, partial failure/retry, rebind, IPv6 deduplication, stale callbacks, healthy network after failed net, reciprocal HTTPS registration, hidden state');
})().catch(error => { console.error(error); process.exitCode = 1; });
