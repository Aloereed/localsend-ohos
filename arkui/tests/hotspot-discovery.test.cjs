const assert = require('node:assert/strict');
const { load, mocks } = require('./host-runtime.cjs');
const native = Object.create(mocks['libaloetls.so']); mocks['libaloetls.so'] = native;
let osLinks = [], osError = false, handles = [], netError = false;
const opened = [], sent = [], stopped = [], callbacks = new Map(); let next = 0;
Object.defineProperties(native, {
  networkInterfaces: { value() { if (osError) throw new Error('OS failure'); return osLinks; } },
  multicastOpen: { value(group, port, address, callback) { const id = ++next; opened.push(address); callbacks.set(id, callback); return id; } },
  multicastStop: { value(id) { stopped.push(id); callbacks.get(id)({ kind: 'stopped' }); } },
  multicastSend: { value(id) { sent.push(id); } }
});
const connection = mocks['@kit.NetworkKit'].connection;
connection.getAllNets = async () => { if (netError) throw new Error('NetHandle failure'); return handles; };
connection.getConnectionProperties = async net => { if (net.fail) throw new Error('lost upstream'); return net; };
const { AppStore } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const { DiscoveryMulticast } = load('network/DiscoveryMulticast');
const { discoveryTargets } = load('network/DiscoveryScan');
const link = (name, ip, prefixLength = 24) => ({ name, ip, prefixLength });
const props = (name, ips) => ({ interfaceName: name, linkAddresses: ips.map(ip => ({ address: { address: ip }, prefixLength: 24 })) });
(async () => {
  const store = new AppStore(), service = new LocalSendService(store);
  const multicast = new DiscoveryMulticast(() => {}, () => {});
  try {
    // Hotspot has no NetHandle, with or without mobile upstream connectivity.
    osLinks = [link('ap0', '192.168.43.1'), link('ap0', 'fe80::1%ap0', 64)];
    await service.readAddresses(); assert.deepEqual(Array.from(store.localIps), ['192.168.43.1']);
    assert.ok(discoveryTargets(store.interfaces).includes('192.168.43.2'));
    assert.ok(!discoveryTargets(store.interfaces).includes('192.168.43.1'));
    await multicast.sync(store.interfaces, '224.0.0.167', 53317, true);
    assert.deepEqual(opened, ['192.168.43.1', 'ap0']); multicast.send(new Uint8Array([1])); assert.equal(sent.length, 2);
    handles = [props('rmnet0', ['10.1.2.3']), { fail: true }]; await service.readAddresses();
    assert.deepEqual(Array.from(store.localIps), ['10.1.2.3', '192.168.43.1']);
    // Merge both providers without duplicate joins, retain native IPv6 scope/mask.
    handles.push(props('ap0', ['192.168.43.1', 'fe80::1'])); await service.readAddresses();
    assert.equal(store.interfaces.filter(item => item.name === 'ap0').length, 2);
    assert.equal(store.interfaces.find(item => item.ip.includes(':')).ip, 'fe80::1%ap0');
    assert.equal(store.interfaces.find(item => item.ip.includes(':')).prefixLength, 64);
    await multicast.sync(store.interfaces, '224.0.0.167', 53317, true); assert.equal(opened.length, 3);
    store.settings.networkFilter = 'allow'; store.settings.networkPatterns = ['192.168.43.*'];
    await service.readAddresses(); assert.deepEqual(Array.from(store.localIps), ['192.168.43.1']);
    assert.ok(store.interfaces.filter(item => item.name === 'ap0').every(item => !item.ignored));
    store.settings.networkFilter = 'deny'; await service.readAddresses();
    assert.deepEqual(Array.from(store.localIps), ['10.1.2.3']); assert.ok(store.interfaces.filter(item => item.name === 'ap0').every(item => item.ignored));
    store.settings.networkFilter = 'none'; netError = true; await service.readAddresses();
    assert.deepEqual(Array.from(store.localIps), ['192.168.43.1']);
    netError = false; osError = true; handles = [props('wlan0', ['192.168.1.2'])]; await service.readAddresses();
    assert.deepEqual(Array.from(store.localIps), ['192.168.1.2']);
    netError = true; await assert.rejects(service.readAddresses()); assert.deepEqual(Array.from(store.localIps), ['192.168.1.2']);
    netError = false; osError = false; handles = []; osLinks = [];
    await service.readAddresses(); assert.equal(store.interfaces.length, 0);
    await multicast.sync(store.interfaces, '224.0.0.167', 53317, true); assert.equal(stopped.length, 3);
    osLinks = [link('ap1', '172.20.10.1', 28), link('lo', '127.0.0.1'), link('none', '0.0.0.0'), link('bad', '::')];
    await service.readAddresses(); assert.deepEqual(Array.from(store.localIps), ['172.20.10.1']);
    assert.equal(discoveryTargets(store.interfaces).length, 13);
    await multicast.sync(store.interfaces, '224.0.0.167', 53317, false); assert.equal(opened.at(-1), '172.20.10.1');
  } finally { await multicast.close(); }
  console.log('PASS hotspot without NetHandle/upstream, merged scope/prefix, filters, provider failures, removed/replaced hotspot, multicast joins and scan targets');
})().catch(error => { console.error(error); process.exitCode = 1; });
