const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');
const { load, handles } = require('./host-runtime.cjs');
const { fileChecksum } = load('network/FileChecksum');
const { Cancellation } = load('network/Transport');
const { AppStore, AppSettings, ShareFile, Peer } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
(async () => {
  const work = path.join(__dirname, '../logs/checksum-' + Date.now()); await fs.mkdir(work, { recursive: true });
  const bytes = crypto.randomBytes(65536 * 3 + 17), uri = path.join(work, 'source.bin'); await fs.writeFile(uri, bytes);
  const updates = [];
  assert.equal(await fileChecksum(uri, bytes.length, '', new Cancellation(), n => updates.push(n)), sha(bytes));
  assert.deepEqual(updates, [65536, 131072, 196608, bytes.length]);
  const text = '汉字 🙂\n'; assert.equal(await fileChecksum('', Buffer.byteLength(text), text, new Cancellation()), sha(text));
  const empty = path.join(work, 'empty'); await fs.writeFile(empty, '');
  assert.equal(await fileChecksum(empty, 0, '', new Cancellation()), sha(''));
  await assert.rejects(fileChecksum(uri, bytes.length + 1, '', new Cancellation()), /读取不完整/);
  await assert.rejects(fileChecksum(uri, bytes.length - 1, '', new Cancellation()), /大小已改变/);
  const cancel = new Cancellation();
  await assert.rejects(fileChecksum(uri, bytes.length, '', cancel, () => cancel.cancel()), /取消/);
  assert.equal(handles.size, 0);
  assert.equal(new AppSettings().createChecksums, true); assert.equal(new AppSettings().verifyChecksums, true);
  const store = new AppStore(); await store.init({ filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) });
  const offers = [], uploads = [];
  let rejectUploads = 0;
  const server = http.createServer((req, res) => {
    const chunks = []; req.on('data', b => chunks.push(b)); req.on('end', () => {
      const body = Buffer.concat(chunks);
      if (req.url.endsWith('prepare-upload')) {
        const offer = JSON.parse(body); offers.push(offer);
        res.end(JSON.stringify({ sessionId: 'session', files: { file: 'token' } }));
      } else { uploads.push(body); if (rejectUploads > 0) { rejectUploads--; res.statusCode = 422; } res.end('{}'); }
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const service = new LocalSendService(store);
  const peer = Object.assign(new Peer(), { ip: '127.0.0.1', port: server.address().port, protocol: 'http' });
  const file = Object.assign(new ShareFile(), { id: 'file', name: 'source.bin', uri, size: bytes.length });
  try {
    await service.send(peer, [file]);
    assert.equal(store.transfers[0].status, 'complete', store.transfers[0].error);
    assert.equal(offers[0].files.file.sha256, sha(bytes)); assert.equal(offers[0].files.file.hash, undefined);
    assert.equal(store.transfers[0].hashing, false); assert.equal(store.transfers[0].hashedBytes, bytes.length);
    store.settings.createChecksums = false; await service.send(peer, [file]);
    assert.equal(offers[1].files.file.sha256, undefined);
    assert.deepEqual(uploads, [bytes, bytes]);
    rejectUploads = 2; store.settings.createChecksums = true;
    await service.send(peer, [file]); assert.equal(store.transfers[0].status, 'complete');
    assert.equal(uploads.length, 5, 'checksum mismatch retries the same upload at most three times');
    rejectUploads = 5; await service.send(peer, [file]);
    assert.equal(store.transfers[0].status, 'error'); assert.match(store.transfers[0].error, /校验和/);
    assert.equal(uploads.length, 8, 'persistent mismatch stops after three attempts');
  } finally { await service.stop(); await new Promise(resolve => server.close(resolve)); }
  assert.equal(handles.size, 0);
  console.log('PASS SHA-256 chunks, empty/text files, changed files, cancellation, official wire field and disabled sending');
})().catch(error => { console.error(error); process.exitCode = 1; });
