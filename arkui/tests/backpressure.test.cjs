const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const net = require('node:net');
const https = require('node:https');
const crypto = require('node:crypto');
const { load, mocks, handles } = require('./host-runtime.cjs');
if (process.env.ALOE_NETWORK_BASELINE) load('network/SecureServer').SecureServer = load(process.env.ALOE_NETWORK_BASELINE).SecureServer;
const { AppStore } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const { NativeConnection } = load('network/NativeServer');
const work = path.join(__dirname, '../logs/backpressure-' + Date.now());
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(predicate, timeout = 3000) {
  const started = Date.now();
  while (!predicate()) { if (Date.now() - started > timeout) throw new Error('condition timeout'); await delay(5); }
}
function request(port, route, data) {
  return new Promise((resolve, reject) => {
    const req = https.request({ host: '127.0.0.1', port, path: route, method: 'POST', rejectUnauthorized: false,
      headers: { 'content-length': data.length } }, response => {
      const chunks = []; response.on('data', chunk => chunks.push(chunk));
      response.on('end', () => resolve({ status: response.statusCode, body: Buffer.concat(chunks).toString() }));
    });
    req.on('error', reject); req.end(data);
  });
}
function streamUpload(port, route, block, count) {
  let req, produced = 0;
  const result = new Promise((resolve, reject) => {
    req = https.request({ host: '127.0.0.1', port, path: route, method: 'POST', rejectUnauthorized: false,
      headers: { 'content-length': block.length * count } }, response => {
      response.resume(); response.on('end', () => resolve(response.statusCode));
    });
    req.on('error', reject);
    req.setTimeout(30000, () => req.destroy(new Error('upload idle timeout')));
    async function produce() {
      for (let index = 0; index < count; index++) {
        if (!req.write(block)) await new Promise((resolve, reject) => {
          const cleanup = () => { req.off('drain', drained); req.off('error', failed); req.off('close', closed); };
          const drained = () => { cleanup(); resolve(); };
          const failed = error => { cleanup(); reject(error); };
          const closed = () => failed(new Error('upload closed'));
          req.once('drain', drained); req.once('error', failed); req.once('close', closed);
        });
        produced += block.length;
      }
      req.end();
    }
    produce().catch(error => req.destroy(error));
  });
  result.catch(() => {});
  return { result, close: () => req.destroy(), produced: () => produced };
}
(async () => {
  await fs.mkdir(work, { recursive: true });
  const probe = net.createServer(); await new Promise(resolve => probe.listen(0, '127.0.0.1', resolve));
  const port = probe.address().port; await new Promise(resolve => probe.close(resolve));
  const store = new AppStore(); await store.init({ filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) });
  store.settings.port = port; store.settings.quickSave = true;
  const service = new LocalSendService(store); await service.start();
  const disk = mocks['@kit.CoreFileKit'].fileIo, write = disk.write;
  const enqueue = NativeConnection.prototype.enqueue; let peak = 0, waiting = false, release, upload;
  NativeConnection.prototype.enqueue = function(bytes) { const result = enqueue.call(this, bytes); peak = Math.max(peak, this.queuedBytes); return result; };
  const paused = new Promise(resolve => { release = resolve; });
  disk.write = async (fd, bytes) => { if (!waiting) { waiting = true; await paused; } return write(fd, bytes); };
  try {
    const block = crypto.randomBytes(65536);
    const mib = Number(process.env.ALOE_LARGE_MIB || 128), count = mib * 16;
    const hash = crypto.createHash('sha256'); for (let index = 0; index < count; index++) hash.update(block);
    const expected = hash.digest('hex');
    const payload = Buffer.from(JSON.stringify({ info: { alias: 'Backpressure client', version: '2.1', protocol: 'http', port: 1 },
      files: { file: { id: 'file', fileName: 'backpressure.bin', fileType: 'application/octet-stream', size: block.length * count, hash: expected } } }));
    const prepared = await request(port, '/api/localsend/v2/prepare-upload', payload);
    assert.equal(prepared.status, 200); const session = JSON.parse(prepared.body);
    upload = streamUpload(port, `/api/localsend/v2/upload?sessionId=${session.sessionId}&fileId=file&token=${session.files.file}`, block, count);
    await until(() => waiting); await delay(1000);
    assert.ok(peak <= 131072, `disk pause must bound the application queue; observed ${peak} bytes`);
    assert.ok(upload.produced() < block.length * count, 'the sender must encounter TCP backpressure while disk writes are paused');
    release(); assert.equal(await upload.result, 200);
    assert.equal(store.transfers[0].status, 'complete');
    assert.equal((await fs.stat(store.history[0].path)).size, block.length * count);
    const actual = crypto.createHash('sha256');
    for await (const bytes of require('node:fs').createReadStream(store.history[0].path)) actual.update(bytes);
    assert.equal(actual.digest('hex'), expected);
    await until(() => handles.size === 0);
    console.log(`PASS ${mib} MiB real TLS receive after one-second disk stall; SHA-256 matches, peak queue ${peak} bytes, zero file handles`);
  } finally {
    release(); upload?.close(); disk.write = write; NativeConnection.prototype.enqueue = enqueue; await service.stop();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
