const assert = require('node:assert/strict');
const { load } = require('./host-runtime.cjs');
const { AppStore, Peer } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const { HttpHead } = load('network/Protocol');
const flush = async () => { for (let i = 0; i < 80; i++) await Promise.resolve(); };
(async () => {
  const store = new AppStore(); store.settings.fingerprint = 'local';
  const service = new LocalSendService(store); service.running = true; service.ensureIdentity = async () => {};
  const remote = { alias: 'Windows', version: '2.2', fingerprint: 'remote', protocol: 'http', port: 53317, announce: true };
  const gateway = '192.168.1.1', actual = '192.168.1.12'; let mode = 'offline'; const requests = [];
  service.request = async (peer, method) => {
    requests.push({ ip: peer.ip, method });
    if (peer.ip === gateway && mode === 'offline') throw Error('not a LocalSend listener');
    const info = peer.ip !== gateway || mode === 'valid' ? remote : mode === 'wrong' ? { ...remote, fingerprint: 'router' } : { alias: 'Router', fingerprint: 'router' };
    return { status: 200, fingerprint: '', body: JSON.stringify(info) };
  };
  const announce = (ip, extras = {}) => service.discovered({ message: Buffer.from(JSON.stringify({ ...remote, ...extras })), remoteInfo: { address: ip } });
  const visible = () => { assert.ok(!store.peers.some(p => p.ip === gateway)); assert.ok(!store.peerEndpoints.some(p => p.ip === gateway)); };
  try {
    announce(gateway); assert.equal(store.displayedPeers.length, 0, 'relayed UDP source is not immediately shown');
    await flush(); visible(); assert.equal(store.discoveryAddresses.length, 0);
    announce(actual); await flush(); assert.equal(store.peers.length, 1); assert.equal(store.peers[0].ip, actual);
    for (const state of ['wrong', 'malformed']) { mode = state; announce(gateway); await flush(); visible(); assert.equal(store.peers[0].ip, actual); }
    for (const tags of [true, false]) { store.settings.showAddressTags = tags; assert.equal(store.displayedPeers.length, 1); }
    mode = 'valid'; announce(gateway); await flush(); assert.ok(store.peerEndpoints.some(p => p.ip === gateway), 'a real hotspot .1 device is supported');
    store.peers = []; store.peerEndpoints = []; store.settings.visible = false; requests.length = 0;
    announce(actual, { announce: false }); await flush(); assert.equal(store.peers.length, 1);
    assert.deepEqual(requests.map(r => r.method), ['GET'], 'hidden device validates without advertising itself');
    store.peers = []; store.peerEndpoints = []; mode = 'offline'; requests.length = 0;
    const channel = { ip: gateway, onBody: undefined, async respond(status) { assert.equal(status, 200); } };
    const head = Object.assign(new HttpHead(), { method: 'POST', target: '/api/localsend/v2/register' });
    const sink = await service.handle(channel, head);
    await sink.write(Buffer.from(JSON.stringify(remote))); await sink.finish(); await flush();
    visible(); assert.deepEqual(requests.map(r => r.method), ['GET'], 'incoming register validates source without reciprocal POST loops');
  } finally { await service.stop(); }
  console.log('PASS forwarded gateway announcement/request rejection, matching identity requirement, real .1 hotspot support, both display modes and hidden read-only validation');
})().catch(error => { console.error(error); process.exitCode = 1; });
