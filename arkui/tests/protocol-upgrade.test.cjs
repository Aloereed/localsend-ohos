const assert = require('node:assert/strict');
const https = require('node:https');
const fs = require('node:fs/promises');
const path = require('node:path');
const { load } = require('./host-runtime.cjs');
const { AppStore, Peer, ShareFile } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const { TlsIdentity } = load('network/TlsIdentity');

(async () => {
  const work = path.join(__dirname, '../logs/protocol-upgrade-' + Date.now());
  await fs.mkdir(work, { recursive: true });
  const store = new AppStore();
  await store.init({ filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) });
  store.settings.visible = false;
  const identity = new TlsIdentity(); await identity.load(store);
  const crypto = require('node:crypto');
  const fingerprint = new crypto.X509Certificate(identity.certificate).fingerprint256.replaceAll(':', '').toLowerCase();
  // The test endpoint is a different device with the generated certificate.
  store.settings.fingerprint = 'local-sender';
  let offers = 0, uploaded = Buffer.alloc(0), infoRequests = 0;
  const server = https.createServer({ cert: identity.certificate, key: identity.privateKey }, (req, res) => {
    const chunks = [];
    req.on('data', chunk => chunks.push(chunk));
    req.on('end', () => {
      if (req.url.endsWith('/info')) {
        infoRequests++;
        // A stale protocol field must not override the verified TLS transport.
        res.end(JSON.stringify({ alias: 'Android', version: '2.1', protocol: 'http', fingerprint }));
      } else if (req.url.endsWith('/prepare-upload')) {
        offers++;
        const payload = JSON.parse(Buffer.concat(chunks));
        res.end(JSON.stringify({ sessionId: 'secure-session', files: Object.fromEntries(Object.keys(payload.files).map(id => [id, 'token'])) }));
      } else { uploaded = Buffer.concat(chunks); res.end('{}'); }
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const stale = () => Object.assign(new Peer(), { alias: 'Android', ip: '127.0.0.1', port: server.address().port, fingerprint, protocol: 'http' });
  const service = new LocalSendService(store);
  try {
    store.favorites = [stale()];
    await service.probe(stale());
    assert.equal(store.peers[0].protocol, 'https');
    assert.equal(store.favorites[0].protocol, 'https');
    store.peers = []; store.favorites = [];
    await service.register(stale());
    assert.equal(store.peers[0].protocol, 'https');
    const file = Object.assign(new ShareFile(), { id: 'file', name: 'sample.bin', uri: path.join(work, 'sample.bin'), size: 65536 });
    const bytes = crypto.randomBytes(file.size); await fs.writeFile(file.uri, bytes);
    await service.send(stale(), [file]);
    assert.equal(store.transfers[0].status, 'complete', store.transfers[0].error);
    assert.equal(store.transfers[0].encrypted, true);
    assert.equal(store.transfers[0].peerInfo.protocol, 'https');
    assert.equal(offers, 1); assert.deepEqual(uploaded, bytes);
    const before = infoRequests;
    await assert.rejects(service.probe(Object.assign(stale(), { fingerprint: '00'.repeat(32) })), /证书指纹已改变/);
    assert.equal(infoRequests, before, 'identity mismatch sends no HTTP application bytes over TLS');
    assert.equal(offers, 1);
    console.log('PASS stale HTTP discovery/register/send upgrade to verified HTTPS, exact binary upload, single offer, fingerprint mismatch blocked');
  } finally { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); }
})().catch(error => { console.error(error); process.exitCode = 1; });
