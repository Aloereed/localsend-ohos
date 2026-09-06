const assert = require('node:assert/strict');
const https = require('node:https');
const http = require('node:http');
const tls = require('node:tls');
const net = require('node:net');
const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const { load, handles } = require('./host-runtime.cjs');
const { AppStore, Peer, ShareFile } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const { request } = load('network/Transport');
const work = path.join(__dirname, '../logs/service-fixture-' + Date.now());
let checks = 0;
async function check(name, action) { await action(); checks++; console.log('PASS', name); }
async function freePort() { const server = net.createServer(); await new Promise(r => server.listen(0, '127.0.0.1', r)); const port = server.address().port; await new Promise(r => server.close(r)); return port; }
function call(port, route, data, method = 'POST', chunked = false) {
  const bytes = data === undefined ? Buffer.alloc(0) : Buffer.isBuffer(data) ? data : Buffer.from(JSON.stringify(data));
  return new Promise((resolve, reject) => {
    const headers = { 'content-type': 'application/json' };
    if (!chunked) headers['content-length'] = bytes.length;
    const req = https.request({ host: '127.0.0.1', port, path: route, method, rejectUnauthorized: false, headers }, res => {
      const parts = []; res.on('data', b => parts.push(b)); res.on('end', () => resolve({ status: res.statusCode, bytes: Buffer.concat(parts), json: () => JSON.parse(Buffer.concat(parts).toString()) }));
    });
    req.setTimeout(10000, () => req.destroy(new Error('test timeout'))); req.on('error', reject);
    if (chunked) { req.write(bytes.subarray(0, 7)); req.write(bytes.subarray(7)); req.end(); } else req.end(bytes);
  });
}
const peerInfo = { alias: 'Independent client', version: '2.1', deviceModel: 'Node', deviceType: 'desktop', fingerprint: 'test-peer', port: 53317, protocol: 'http', download: false };
function offer(name, data, extra = {}) { return { info: peerInfo, files: { f1: { id: 'f1', fileName: name, size: data.length, fileType: 'application/octet-stream', ...extra } } }; }
async function until(predicate, timeout = 2000) { const started = Date.now(); while (!(await predicate())) { if (Date.now() - started > timeout) throw new Error('condition timeout'); await new Promise(r => setTimeout(r, 10)); } }

(async () => {
  await fs.mkdir(work, { recursive: true });
  const store = new AppStore(); await store.init({ filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) });
  store.settings.port = await freePort(); store.settings.quickSave = true;
  const service = new LocalSendService(store);
  try {
    await service.start(); assert.match(store.serverStatus, /已就绪/);
    const port = store.settings.port;
    await check('TLS info from independent HTTPS client and persistent certificate fingerprint', async () => {
      const result = await call(port, '/api/localsend/v2/info', undefined, 'GET');
      assert.equal(result.status, 200); assert.equal(result.json().alias, store.settings.alias);
      const cert = new crypto.X509Certificate(await fs.readFile(path.join(work, 'identity-cert.pem')));
      assert.equal(result.json().fingerprint, cert.fingerprint256.replaceAll(':', '').toLowerCase());
      assert.equal(cert.verify(cert.publicKey), true);
    });
    await check('pending settings keep advertised transport consistent with the running listener', async () => {
      const group = store.settings.multicast;
      store.settings.port = await freePort(); store.settings.https = false; store.settings.multicast = '224.0.0.168';
      assert.equal(store.networkPending, true);
      const active = (await call(port, '/api/localsend/v2/info', undefined, 'GET')).json();
      assert.equal(active.port, port); assert.equal(active.protocol, 'https');
      assert.equal(store.listenerMulticast, group);
      store.transfers = [{ id: 'guard', status: 'waiting' }];
      await service.restart(); assert.equal(store.listenerPort, port); assert.equal(store.listenerRunning, true);
      store.transfers = []; store.settings.port = port; store.settings.https = true; store.settings.multicast = group;
      assert.equal(store.networkPending, false);
    });
    await check('native transport pins certificate and rejects a changed identity', async () => {
      const peer = new Peer(); peer.ip = '127.0.0.1'; peer.port = port; peer.protocol = 'https'; peer.fingerprint = store.settings.fingerprint;
      assert.equal((await request(peer, 'GET', '/api/localsend/v2/info')).status, 200);
      peer.fingerprint = '0'.repeat(64);
      await assert.rejects(request(peer, 'GET', '/api/localsend/v2/info'), /指纹/);
    });
    await check('native transport connects to IPv6 and honors discovery response timeout', async () => {
      const sockets = new Set();
      const remote = http.createServer((req, res) => {
        if (req.url === '/slow') return;
        res.writeHead(200, { 'content-length': 2 }); res.end('{}');
      });
      remote.on('connection', socket => { sockets.add(socket); socket.on('close', () => sockets.delete(socket)); });
      await new Promise((resolve, reject) => { remote.once('error', reject); remote.listen(0, '::1', resolve); });
      try {
        const peer = new Peer(); peer.ip = '::1'; peer.port = remote.address().port; peer.protocol = 'http';
        assert.equal((await request(peer, 'GET', '/')).status, 200);
        const { Cancellation } = load('network/Transport'); const started = Date.now();
        await assert.rejects(request(peer, 'GET', '/slow', '', new Cancellation(), 100), /超时/);
        assert.ok(Date.now() - started < 1500);
      } finally { for (const socket of sockets) socket.destroy(); await new Promise(r => remote.close(r)); }
    });
    await check('register populates actual device state', async () => {
      const result = await call(port, '/api/localsend/v2/register', peerInfo); assert.equal(result.status, 200);
      assert.ok(store.peers.some(p => p.alias === peerInfo.alias));
    });
    const data = crypto.randomBytes(180000);
    await check('prepare, tokenized chunked binary upload, checksum and actual file contents', async () => {
      const prepared = await call(port, '/api/localsend/v2/prepare-upload', offer('相册/test.bin', data, { hash: crypto.createHash('sha256').update(data).digest('hex') }));
      assert.equal(prepared.status, 200); const session = prepared.json();
      const uploadPath = `/api/localsend/v2/upload?sessionId=${session.sessionId}&fileId=f1&token=${session.files.f1}`;
      assert.equal((await call(port, uploadPath, data, 'POST', true)).status, 200);
      assert.deepEqual(await fs.readFile(store.history[0].path), data);
      assert.equal(store.transfers[0].status, 'complete');
      assert.equal((await call(port, uploadPath, data)).status, 400, 'token cannot replay completed file');
    });
    await check('invalid upload token rejected without writing a file', async () => {
      const prepared = (await call(port, '/api/localsend/v2/prepare-upload', offer('test.bin', data))).json();
      const result = await call(port, `/api/localsend/v2/upload?sessionId=${prepared.sessionId}&fileId=f1&token=invalid`, data);
      assert.equal(result.status, 403); service.cancel(prepared.sessionId);
    });
    await check('incoming path traversal rejected before consent or file writes', async () => {
      assert.equal((await call(port, '/api/localsend/v2/prepare-upload', offer('../outside', data))).status, 400);
    });
    await check('checksum mismatch removes partial output and never records success', async () => {
      const count = store.history.length;
      const session = (await call(port, '/api/localsend/v2/prepare-upload', offer('bad-hash.bin', data, { hash: '0'.repeat(64) }))).json();
      const result = await call(port, `/api/localsend/v2/upload?sessionId=${session.sessionId}&fileId=f1&token=${session.files.f1}`, data);
      assert.equal(result.status, 400); assert.equal(store.history.length, count);
      await until(() => handles.size === 0);
      await assert.rejects(fs.access(path.join(work, 'received', session.sessionId, 'bad-hash.bin')));
      await assert.rejects(fs.access(path.join(work, 'received', session.sessionId, 'bad-hash.bin.part')));
    });
    await check('cancellation closes active uploads and removes incomplete files', async () => {
      const session = (await call(port, '/api/localsend/v2/prepare-upload', offer('cancel.bin', data))).json();
      const client = tls.connect({ host: '127.0.0.1', port, rejectUnauthorized: false });
      client.on('error', () => {}); await new Promise(r => client.once('secureConnect', r));
      client.write(`POST /api/localsend/v2/upload?sessionId=${session.sessionId}&fileId=f1&token=${session.files.f1} HTTP/1.1\r\nHost: localhost\r\nContent-Length: ${data.length}\r\n\r\n`);
      client.write(data.subarray(0, 1000));
      await until(() => store.transfers[0].files[0].transferred === 1000);
      service.cancel(session.sessionId);
      await until(() => handles.size === 0); client.destroy();
      assert.equal(store.transfers[0].status, 'cancelled');
      await until(async () => { try { await fs.access(path.join(work, 'received', session.sessionId, 'cancel.bin.part')); return false; } catch (_) { return true; } });
      await assert.rejects(fs.access(path.join(work, 'received', session.sessionId, 'cancel.bin.part')));
    });
    await check('explicit decline and selective consent', async () => {
      store.settings.quickSave = false;
      let response = call(port, '/api/localsend/v2/prepare-upload', offer('decline.bin', data));
      await until(() => !!store.pendingReceive); service.acceptReceive(false); assert.equal((await response).status, 403);
      response = call(port, '/api/localsend/v2/prepare-upload', offer('accept.bin', data));
      await until(() => !!store.pendingReceive); service.selectReceiveFile('f1', false); service.acceptReceive(true);
      assert.equal((await response).status, 403); store.settings.quickSave = true;
    });
    await check('PIN required and valid PIN accepts a request', async () => {
      store.settings.pin = '123456';
      assert.equal((await call(port, '/api/localsend/v2/prepare-upload', offer('pin.bin', data))).status, 401);
      const response = await call(port, '/api/localsend/v2/prepare-upload?pin=123456', offer('pin.bin', data));
      assert.equal(response.status, 200); service.cancel(response.json().sessionId); store.settings.pin = '';
    });
    await check('receive consent supports preview, rename and batch selection without changing file identity', async () => {
      store.settings.quickSave = false;
      const pending = call(port, '/api/localsend/v2/prepare-upload', offer('original.bin', data));
      await until(() => !!store.pendingReceive);
      assert.equal(service.batchRenameReceive('counter', 'Batch-', true, false), true);
      assert.equal(store.transfers[0].files[0].name, 'Batch-1.bin');
      service.selectAllReceive('none'); service.resetReceiveNames();
      assert.equal(store.transfers[0].files[0].name, 'original.bin');
      assert.equal(store.transfers[0].files[0].selected, false);
      service.selectAllReceive('all');
      assert.equal(service.renameReceive('f1', '../escape'), false);
      assert.equal(service.renameReceive('f1', 'chosen/renamed.bin'), true);
      service.selectAllReceive('none'); assert.equal(store.transfers[0].files[0].selected, false);
      service.selectAllReceive('invert'); assert.equal(store.transfers[0].files[0].selected, true);
      service.acceptReceive(true); const session = (await pending).json();
      assert.equal((await call(port, `/api/localsend/v2/upload?sessionId=${session.sessionId}&fileId=f1&token=${session.files.f1}`, data)).status, 200);
      assert.match(store.history[0].path, /chosen\/renamed\.bin$/); assert.equal(store.history[0].peerInfo.fingerprint, 'test-peer');
      assert.deepEqual(await fs.readFile(store.history[0].path), data); store.settings.quickSave = true;
    });
    await check('disconnecting a prepare request dismisses native consent immediately', async () => {
      store.settings.quickSave = false;
      const bytes = Buffer.from(JSON.stringify(offer('cancel-before-consent.bin', data)));
      const req = https.request({ host: '127.0.0.1', port, path: '/api/localsend/v2/prepare-upload', method: 'POST', rejectUnauthorized: false,
        headers: { 'content-length': bytes.length } });
      req.on('error', () => {}); req.end(bytes);
      await until(() => !!store.pendingReceive); const id = store.pendingReceive;
      req.destroy(); await until(() => !store.pendingReceive);
      assert.equal(store.transfers.find(item => item.id === id).status, 'cancelled');
      store.settings.quickSave = true;
    });
    await check('text preview creates message history and sends 204', async () => {
      const text = '你好，HarmonyOS 👋'; const bytes = Buffer.from(text);
      const result = await call(port, '/api/localsend/v2/prepare-upload', offer('message.txt', bytes, { fileType: 'text/plain', preview: text }));
      assert.equal(result.status, 204); assert.equal(store.history[0].text, text);
    });
    await check('native sender sends real binary and text to an independent Node server', async () => {
      const seen = []; let received = Buffer.alloc(0);
      const remote = http.createServer((req, res) => {
        const chunks = []; req.on('data', chunk => chunks.push(chunk)); req.on('end', () => {
          if (req.url.includes('prepare-upload')) {
            const payload = JSON.parse(Buffer.concat(chunks)); const files = {};
            for (const id of Object.keys(payload.files)) files[id] = 'node-token';
            seen.push(payload); const body = JSON.stringify({ sessionId: 'node-session', files });
            res.writeHead(200, { 'content-length': Buffer.byteLength(body) }); res.end(body);
          } else { received = Buffer.concat([received, ...chunks]); res.writeHead(200, { 'content-length': 2 }); res.end('{}'); }
        });
      });
      await new Promise(r => remote.listen(0, '127.0.0.1', r));
      try {
        const source = path.join(work, 'outgoing.bin'); await fs.writeFile(source, data);
        const file = new ShareFile(); file.name = 'outgoing.bin'; file.uri = source; file.size = data.length;
        store.files = [file]; const peer = new Peer(); peer.ip = '127.0.0.1'; peer.port = remote.address().port; peer.protocol = 'http'; peer.alias = 'Node receiver';
        await service.send(peer); assert.equal(store.transfers[0].status, 'complete'); assert.deepEqual(received, data);
        assert.equal(seen[0].files[file.id].size, data.length);
      } finally { await new Promise(r => remote.close(r)); }
    });
    await check('legacy v1 uses original send-request/send routes and token-map response', async () => {
      const prepared = await call(port, '/api/localsend/v1/send-request', offer('legacy.bin', data));
      assert.equal(prepared.status, 200); const tokens = prepared.json(); assert.equal(typeof tokens.f1, 'string');
      const received = await call(port, `/api/localsend/v1/send?fileId=f1&token=${tokens.f1}`, data);
      assert.equal(received.status, 200); assert.deepEqual(await fs.readFile(store.history[0].path), data);
      let uploaded = Buffer.alloc(0); let fallback = false;
      const remote = http.createServer((req, res) => {
        const chunks = []; req.on('data', chunk => chunks.push(chunk)); req.on('end', () => {
          let body = '{}'; let status = 200;
          if (req.url === '/api/localsend/v2/prepare-upload') { status = 404; fallback = true; }
          else if (req.url === '/api/localsend/v1/send-request') {
            const offer = JSON.parse(Buffer.concat(chunks)); body = JSON.stringify(Object.fromEntries(Object.keys(offer.files).map(id => [id, 'v1-token'])));
          } else if (req.url.startsWith('/api/localsend/v1/send?')) uploaded = Buffer.concat(chunks);
          else status = 404;
          res.writeHead(status, { 'content-length': Buffer.byteLength(body) }); res.end(body);
        });
      });
      await new Promise(r => remote.listen(0, '127.0.0.1', r));
      try {
        const peer = new Peer(); peer.ip = '127.0.0.1'; peer.port = remote.address().port; peer.protocol = 'http'; peer.alias = 'Legacy';
        const file = new ShareFile(); file.name = 'legacy.bin'; file.uri = store.history[0].path; file.size = data.length;
        await service.send(peer, [file]); assert.equal(store.transfers[0].status, 'complete'); assert.equal(fallback, true); assert.deepEqual(uploaded, data);
      } finally { await new Promise(r => remote.close(r)); }
    });
    await check('retry sends only incomplete files and multi-device queue preserves its selection', async () => {
      const offers = []; let failSecond = true;
      const remote = http.createServer((req, res) => {
        const chunks = []; req.on('data', chunk => chunks.push(chunk)); req.on('end', () => {
          if (req.url.includes('prepare-upload')) {
            const payload = JSON.parse(Buffer.concat(chunks)); offers.push(Object.keys(payload.files));
            const files = Object.fromEntries(Object.keys(payload.files).map(id => [id, 'token']));
            const body = JSON.stringify({ sessionId: 'retry-session', files });
            res.writeHead(200, { 'content-length': Buffer.byteLength(body) }); res.end(body);
          } else {
            const bad = req.url.includes('fileId=second') && failSecond;
            res.writeHead(bad ? 500 : 200, { 'content-length': 2 }); res.end('{}');
          }
        });
      });
      await new Promise(r => remote.listen(0, '127.0.0.1', r));
      try {
        const first = new ShareFile(); first.id = 'first'; first.name = 'one'; first.text = '1'; first.size = 1;
        const second = new ShareFile(); second.id = 'second'; second.name = 'two'; second.text = '2'; second.size = 1;
        store.files = [first, second]; const peer = new Peer(); peer.ip = '127.0.0.1'; peer.port = remote.address().port; peer.protocol = 'http'; peer.alias = 'Retry peer';
        await service.send(peer); const previous = store.transfers[0];
        assert.equal(previous.status, 'error'); assert.equal(previous.files[0].status, 'complete');
        failSecond = false; await service.retry(previous.id);
        assert.equal(store.transfers[0].status, 'complete'); assert.deepEqual(offers[1], ['second']);
        const queue = service.sendMany([peer, peer]); store.files = [];
        await queue; assert.equal(store.batchRemaining, 0);
        assert.deepEqual(offers.slice(2), [['first', 'second'], ['first', 'second']]);
      } finally { await new Promise(r => remote.close(r)); }
    });
  } finally { await service.stop(); }
  await until(() => handles.size === 0);
  console.log(`${checks} service integration groups passed; zero open file handles`);
})().catch(error => { console.error(error); process.exitCode = 1; });
