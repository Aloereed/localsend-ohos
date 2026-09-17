const assert = require('node:assert/strict');
const http = require('node:http'), https = require('node:https');
const fs = require('node:fs/promises'), path = require('node:path');
const { load, mocks } = require('./host-runtime.cjs');
const { AppStore, Peer } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const { TlsIdentity } = load('network/TlsIdentity');
const { request, encodeText, decodeText } = load('network/Transport');
(async () => {
  const work = path.join(__dirname, '../logs/add-address-' + Date.now()); await fs.mkdir(work, { recursive: true });
  const store = new AppStore(); await store.init({ filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) });
  const remoteDir = path.join(work, 'remote'); await fs.mkdir(remoteDir);
  const identity = new TlsIdentity(); await identity.load({ context: { filesDir: remoteDir }, settings: {}, log() {}, async save() {} });
  const service = new LocalSendService(store);
  const util = mocks['@kit.ArkTS'].util, Encoder = util.TextEncoder;
  // Model a native encoder returning no value for zero-byte input, unlike Node.
  util.TextEncoder = class { encodeInto(value) { return value === '' ? undefined : new Encoder().encodeInto(value); } };
  let legacy = false, infoCount = 0, registers = 0; const routes = [];
  function handle(req, res) {
    const chunks = []; req.on('data', b => chunks.push(b)); req.on('end', () => {
      routes.push(`${req.method} ${req.url}`);
      if (legacy && req.url.includes('/v2/')) { res.writeHead(404); res.end(); return; }
      if (req.method === 'GET') {
        assert.equal(Buffer.concat(chunks).length, 0); assert.equal(req.headers['content-length'], '0'); infoCount++;
      } else { assert.ok(JSON.parse(Buffer.concat(chunks)).fingerprint); registers++; }
      res.end(JSON.stringify({ alias: 'Test device', fingerprint: identity.fingerprint, version: legacy ? '1.0' : '2.1' }));
    });
  }
  const plain = http.createServer(handle), secure = https.createServer({ cert: identity.certificate, key: identity.privateKey }, handle);
  await Promise.all([new Promise(r => plain.listen(0, '127.0.0.1', r)), new Promise(r => secure.listen(0, '127.0.0.1', r))]);
  try {
    for (const address of [`http://127.0.0.1:${plain.address().port}`, `https://127.0.0.1:${secure.address().port}`, `127.0.0.1:${plain.address().port}`, `127.0.0.1:${secure.address().port}`]) {
      store.peers = []; store.notice = ''; store.error = '';
      await service.addAddress(address); assert.equal(store.notice, '设备已添加', store.error); assert.equal(store.peers.length, 1);
    }
    legacy = true; store.peers = []; store.notice = ''; await service.addAddress(`http://127.0.0.1:${plain.address().port}`);
    assert.equal(store.notice, '设备已添加', store.error); assert.equal(store.peers[0].version, '1.0'); assert.equal(registers, 5);
    assert.deepEqual(routes, [...Array(5).fill('POST /api/localsend/v2/register'), 'POST /api/localsend/v1/register']);
    store.settings.visible = false;
    await service.probe(Object.assign(new Peer(), { ip: '127.0.0.1', port: plain.address().port, protocol: 'http' }));
    assert.equal(registers, 5, 'hidden discovery never registers'); assert.equal(infoCount, 1);
    store.settings.visible = true;
    assert.equal(encodeText('').length, 0); assert.equal(decodeText(new Uint8Array()), '');
    assert.deepEqual(Buffer.from(encodeText('中文😀')), Buffer.from('中文😀'));
    const sockets = mocks['@kit.NetworkKit'].socket, construct = sockets.constructTLSSocketInstance;
    let certResult = undefined;
    sockets.constructTLSSocketInstance = () => { const socket = construct(); socket.getRemoteCertificate = async () => certResult; return socket; };
    try {
      for (const invalid of [undefined, {}, { data: undefined }, { data: new Uint8Array() }]) {
        certResult = invalid; const before = infoCount;
        const peer = Object.assign(new Peer(), { ip: '127.0.0.1', port: secure.address().port, protocol: 'https' });
        await assert.rejects(request(peer, 'GET', '/api/localsend/v2/info'), /无法读取设备证书/);
        assert.equal(infoCount, before, 'missing identity must send no HTTP data');
      }
      const constructTcp = sockets.constructTCPSocketInstance; let plaintext = 0;
      sockets.constructTCPSocketInstance = () => { plaintext++; return constructTcp(); };
      try {
        store.notice = ''; store.peers = []; store.error = '';
        await service.addAddress(`127.0.0.1:${secure.address().port}`);
        assert.match(store.error, /无法读取设备证书/); assert.equal(store.notice, '');
        assert.equal(plaintext, 0); assert.equal(store.peers.length, 0);
      } finally { sockets.constructTCPSocketInstance = constructTcp; }
    } finally { sockets.constructTLSSocketInstance = construct; }
  } finally {
    util.TextEncoder = Encoder; plain.closeAllConnections(); secure.closeAllConnections();
    await Promise.all([new Promise(r => plain.close(r)), new Promise(r => secure.close(r))]);
  }
  console.log('PASS manual HTTP/HTTPS and bare address addition, empty native encoding, v1 fallback, reciprocal register, UTF-8 and missing certificate rejection');
})().catch(error => { console.error(error); process.exitCode = 1; });
