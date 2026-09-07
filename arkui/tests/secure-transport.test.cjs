const assert = require('node:assert/strict');
const net = require('node:net');
const tls = require('node:tls');
const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const { load, mocks } = require('./host-runtime.cjs');
const { TlsIdentity } = load('network/TlsIdentity');
const { SecureConnection } = load(process.env.ALOE_SECURE_SOURCE || 'network/SecureServer');
const native = mocks['libaloetls.so'];
const work = path.join(__dirname, '../logs/tls-burst-' + Date.now());
async function check(mode) {
  let armed = false, queued = [], queuedBytes = 0, timer, connection, failure;
  let receive, rejectReceive;
  const received = new Promise((resolve, reject) => { receive = resolve; rejectReceive = reject; });
  const expected = crypto.randomBytes(8 * 1024 * 1024);
  const digest = crypto.createHash('sha256'); let total = 0, maxBurst = 0;
  const server = net.createServer(socket => {
    const callbacks = {};
    function flush() {
      clearTimeout(timer);
      const chunks = queued; maxBurst = Math.max(maxBurst, queuedBytes);
      queued = []; queuedBytes = 0;
      const packets = mode === 'coalesced' && chunks.length ? [Buffer.concat(chunks)] : chunks;
      for (const packet of packets) callbacks.message?.({ message: Uint8Array.from(packet).buffer, remoteInfo: { address: '127.0.0.1', port: 1 } });
    }
    const adapter = {
      onMessage(callback) { callbacks.message = callback; },
      onClose(callback) { callbacks.close = callback; },
      onError(callback) { callbacks.error = callback; },
      resume() {},
      async send({ data }) { await new Promise((resolve, reject) => socket.write(Buffer.from(data), error => error ? reject(error) : resolve())); },
      async close() { clearTimeout(timer); socket.destroy(); }
    };
    socket.on('data', data => {
      if (!armed) return callbacks.message?.({ message: Uint8Array.from(data).buffer, remoteInfo: { address: '127.0.0.1', port: 1 } });
      queued.push(data); queuedBytes += data.length;
      if (queuedBytes >= 4 * 1024 * 1024) flush();
      else { clearTimeout(timer); timer = setTimeout(flush, 40); }
    });
    socket.on('close', () => callbacks.close?.());
    socket.on('error', error => callbacks.error?.(error));
    connection = new SecureConnection(adapter, identity);
    connection.onMessage = info => {
      digest.update(Buffer.from(info.message)); total += info.message.byteLength;
      if (total === expected.length) receive();
    };
    connection.onError = error => { failure = error; rejectReceive(error); };
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const client = tls.connect({ host: '127.0.0.1', port: server.address().port, rejectUnauthorized: false });
  client.on('error', error => rejectReceive(error));
  const timeout = setTimeout(() => rejectReceive(new Error('TLS burst timeout')), 10000);
  try {
    await new Promise((resolve, reject) => { client.once('secureConnect', resolve); client.once('error', reject); });
    armed = true; client.write(expected);
    await received;
    assert.equal(failure, undefined);
    assert.ok(maxBurst > 2 * 1024 * 1024);
    assert.equal(digest.digest('hex'), crypto.createHash('sha256').update(expected).digest('hex'));
    console.log('PASS actual TLS encrypted input:', mode, '8 MiB binary, bursts above 2 MiB');
  } finally {
    clearTimeout(timeout); clearTimeout(timer); client.destroy(); await connection?.close();
    await new Promise(resolve => server.close(resolve));
  }
}
let identity;
(async () => {
  await fs.mkdir(work, { recursive: true });
  const cert = new TlsIdentity(); await cert.load({ context: { filesDir: work }, settings: {}, log() {}, async save() {} });
  identity = native.createServer(cert.certificate, cert.privateKey);
  try { await check('callbacks'); await check('coalesced'); }
  finally { native.closeServer(identity); }
})().catch(error => { console.error(error); process.exitCode = 1; });
