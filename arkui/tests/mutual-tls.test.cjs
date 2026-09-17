const assert = require('node:assert/strict');
const https = require('node:https');
const crypto = require('node:crypto');
const fs = require('node:fs/promises');
const path = require('node:path');
const { load } = require('./host-runtime.cjs');
const { AppStore, Peer, ShareFile } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const { TlsIdentity } = load('network/TlsIdentity');
const { request, Cancellation } = load('network/Transport');

(async () => {
  const work = path.join(__dirname, '../logs/mutual-tls-' + Date.now());
  await fs.mkdir(path.join(work, 'receiver'), { recursive: true });
  const remote = new TlsIdentity();
  await remote.load({ context: { filesDir: path.join(work, 'receiver') }, settings: {}, log() {}, async save() {} });
  const store = new AppStore();
  await store.init({ filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) });
  store.settings.https = false; store.settings.visible = false;
  const sender = new TlsIdentity(); await sender.load(store);
  const bodies = [], routes = [];
  const server = https.createServer({ cert: remote.certificate, key: remote.privateKey,
    requestCert: true, rejectUnauthorized: true, ca: sender.certificate }, (req, res) => {
    assert.equal(crypto.createHash('sha256').update(req.socket.getPeerCertificate().raw).digest('hex'), store.settings.fingerprint);
    routes.push(req.url);
    const chunks = [];
    req.on('data', chunk => chunks.push(chunk));
    req.on('end', () => {
      const bytes = Buffer.concat(chunks);
      if (req.url.endsWith('/info') || req.url.endsWith('/register')) {
        if (req.url.endsWith('/register')) assert.equal(JSON.parse(bytes).fingerprint, store.settings.fingerprint);
        res.end(JSON.stringify({ alias: 'mTLS receiver', version: '2.1', fingerprint: remote.fingerprint }));
      } else if (req.url.endsWith('/prepare-upload')) {
        const payload = JSON.parse(bytes);
        assert.equal(payload.info.fingerprint, store.settings.fingerprint);
        res.end(JSON.stringify({ sessionId: 'session', files: Object.fromEntries(Object.keys(payload.files).map(id => [id, 'token'])) }));
      } else { if (req.url.includes('/upload?')) bodies.push(bytes); res.end('{}'); }
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const peer = Object.assign(new Peer(), { alias: 'mTLS receiver', ip: '127.0.0.1', port: server.address().port, protocol: 'https', fingerprint: remote.fingerprint });
  const service = new LocalSendService(store);
  try {
    await assert.rejects(request(peer, 'GET', '/api/localsend/v2/info', '', new Cancellation(), 3000));
    assert.equal(routes.length, 0, 'missing client certificate never reaches HTTP');
    await service.probe(peer); await service.register(peer);
    store.settings.visible = true;
    const discoveryStart = routes.length;
    await service.probe(peer);
    assert.deepEqual(routes.slice(discoveryStart), ['/api/localsend/v2/register'], 'visible discovery exchanges both identities in one mTLS request');
    const bytes = crypto.randomBytes(150003);
    const uri = path.join(work, 'payload.bin'); await fs.writeFile(uri, bytes);
    const file = Object.assign(new ShareFile(), { id: 'f', name: 'payload.bin', uri, size: bytes.length });
    await service.send(peer, [file]);
    assert.equal(store.transfers[0].status, 'complete', store.transfers[0].error);
    assert.deepEqual(bodies, [bytes]);
    await service.notifyCancel(peer, 'session', false);
    assert.ok(routes.some(route => route.includes('/cancel?')));
    const before = routes.length;
    await assert.rejects(service.probe(Object.assign(new Peer(), peer, { fingerprint: '00'.repeat(32) })), /证书指纹已改变/);
    assert.equal(routes.length, before);
    console.log('PASS mandatory client certificate: negative control, discovery, register, binary upload, cancel, server pinning, HTTP listener setting');
  } finally { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); }
})().catch(error => { console.error(error); process.exitCode = 1; });
