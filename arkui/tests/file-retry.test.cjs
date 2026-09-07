const assert = require('node:assert/strict');
const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');
const { load } = require('./host-runtime.cjs');
const { AppStore, Peer, ShareFile } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
(async () => {
  const work = path.join(__dirname, '../logs/file-retry-' + Date.now()); await fs.mkdir(work, { recursive: true });
  const store = new AppStore(); await store.init({ filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) });
  const service = new LocalSendService(store);
  const offers = []; let failSecond = true;
  const server = http.createServer((req, res) => {
    const chunks = []; req.on('data', chunk => chunks.push(chunk)); req.on('end', () => {
      if (req.url.includes('prepare-upload')) {
        const payload = JSON.parse(Buffer.concat(chunks)); offers.push(Object.keys(payload.files));
        const body = JSON.stringify({ sessionId: 'attempt-' + offers.length, files: Object.fromEntries(Object.keys(payload.files).map(id => [id, 'token'])) });
        res.writeHead(200, { 'content-length': Buffer.byteLength(body) }); res.end(body);
      } else { res.writeHead(failSecond && req.url.includes('fileId=second') ? 500 : 200, { 'content-length': 0 }); res.end(); }
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const peer = Object.assign(new Peer(), { ip: '127.0.0.1', port: server.address().port, protocol: 'http', alias: 'File retry' });
    const files = ['first', 'second', 'third'].map(id => Object.assign(new ShareFile(), { id, name: id, text: id, size: id.length }));
    const original = await service.send(peer, files);
    assert.equal(store.transfers[0].status, 'error');
    assert.equal(store.transfers[0].files[0].error, '');
    assert.equal(store.transfers[0].files[1].error, '文件发送失败 500');
    assert.equal(store.transfers[0].files[2].error, '任务已停止，此文件尚未开始传输');
    assert.equal(store.history.find(item => item.id === `send:${original}:second`).error, '文件发送失败 500');
    assert.equal(store.history.find(item => item.id === `send:${original}:third`).error, '任务已停止，此文件尚未开始传输');
    await service.retry(original, 'missing'); await service.retry(original, 'first');
    assert.equal(offers.length, 1, 'unknown and completed file IDs must not create an offer');
    await service.retry(original, 'second');
    const secondAttempt = store.transfers[0].id;
    assert.equal(store.transfers[0].status, 'error', 'a failed retry remains independently retryable');
    let old = store.transfers.find(item => item.id === original);
    assert.equal(old.retryTransferId, '', 'the other failed file remains available in the original task');
    assert.equal(old.files[1].retryTransferId, secondAttempt); assert.equal(old.files[2].retryTransferId, '');
    await service.retry(original, 'second'); assert.equal(offers.length, 2, 'a handed-off file is not retried twice from the old task');
    await service.retry(original);
    assert.equal(store.transfers[0].status, 'complete');
    assert.equal(store.transfers[0].files[0].error, '', 'a new successful retry must not inherit the old error');
    old = store.transfers.find(item => item.id === original);
    assert.equal(old.retryTransferId, store.transfers[0].id);
    failSecond = false; await service.retry(secondAttempt, 'second');
    assert.equal(store.transfers[0].status, 'complete');
    assert.deepEqual(offers, [['first', 'second', 'third'], ['second'], ['third'], ['second']]);
    console.log('PASS per-file retry, remaining-file bulk retry, completed/unknown guards and failed-child retry');
  } finally { await new Promise(resolve => server.close(resolve)); }
})().catch(error => { console.error(error); process.exitCode = 1; });
