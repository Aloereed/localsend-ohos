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
  const offers = [], uploads = []; let failSecond = true, cancels = 0, expired = '';
  const server = http.createServer((req, res) => {
    const chunks = []; req.on('data', chunk => chunks.push(chunk)); req.on('end', () => {
      if (req.url.includes('prepare-upload')) {
        const payload = JSON.parse(Buffer.concat(chunks)); offers.push(Object.keys(payload.files));
        const body = JSON.stringify({ sessionId: 'attempt-' + offers.length, files: Object.fromEntries(Object.keys(payload.files).map(id => [id, 'token'])) });
        res.writeHead(200, { 'content-length': Buffer.byteLength(body) }); res.end(body);
      } else {
        if (req.url.includes('/cancel')) cancels++;
        else uploads.push(new URL(req.url, 'http://localhost').searchParams.get('fileId'));
        if (expired && new URL(req.url, 'http://localhost').searchParams.get('sessionId') === expired) {
          res.writeHead(403, { 'content-length': 0 }); res.end(); return;
        }
        res.writeHead(failSecond && (req.url.includes('fileId=second') || req.url.includes('fileId=fourth')) ? 500 : 200, { 'content-length': 0 }); res.end();
      }
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const peer = Object.assign(new Peer(), { ip: '127.0.0.1', port: server.address().port, protocol: 'http', alias: 'File retry' });
    const files = ['first', 'second', 'third', 'fourth'].map(id => Object.assign(new ShareFile(), { id, name: id, text: id, size: id.length }));
    const original = await service.send(peer, files);
    assert.equal(store.transfers[0].status, 'error');
    assert.equal(store.transfers[0].files[0].error, '');
    assert.equal(store.transfers[0].files[1].error, '文件发送失败 500');
    assert.equal(store.transfers[0].files[2].status, 'complete', 'receiver file failure must not stop the next file');
    assert.equal(cancels, 0, 'file failure must not cancel the accepted batch');
    assert.equal(store.history.find(item => item.id === `send:${original}:second`).error, '文件发送失败 500');
    assert.equal(store.history.find(item => item.id === `send:${original}:third`).error, '');
    await service.retry(original, 'missing'); await service.retry(original, 'first');
    assert.equal(offers.length, 1, 'unknown and completed file IDs must not create an offer');
    await service.retry(original, 'second');
    assert.equal(store.transfers[0].id, original, 'retry updates the original task');
    assert.equal(store.transfers[0].status, 'error', 'a failed retry remains independently retryable');
    assert.equal(store.transfers[0].retryTransferId, '');
    assert.equal(store.transfers[0].retrying, false);
    assert.equal(offers.length, 1, 'same-session retry must not request consent again');
    failSecond = false;
    await Promise.all([service.retry(original), service.retry(original)]);
    assert.equal(store.transfers[0].status, 'complete');
    assert.equal(store.transfers[0].id, original);
    assert.ok(store.transfers[0].files.every(file => file.status === 'complete' && !file.error));
    assert.deepEqual(offers, [['first', 'second', 'third', 'fourth']]);
    assert.deepEqual(uploads, ['first', 'second', 'third', 'fourth', 'second', 'second', 'fourth']);
    await service.retry(original); assert.equal(uploads.length, 7);
    assert.equal(service.sendSessions.size, 0);
    failSecond = true;
    const cancelled = await service.send(peer, [files[1]]);
    assert.equal(service.cancelByPeer('192.0.2.1', 'attempt-2', false), false);
    assert.equal(service.cancelByPeer('127.0.0.1', 'wrong-session', false), false);
    assert.equal(service.cancelByPeer('127.0.0.1', 'attempt-2', false), true,
      'receiver can cancel the idle failed session between retry attempts');
    assert.equal(service.cancelByPeer('127.0.0.1', 'attempt-2', false), false);
    assert.equal(store.transfers[0].status, 'cancelled');
    assert.equal(service.sendSessions.size, 0);
    failSecond = false; await service.retry(cancelled);
    assert.equal(offers.length, 3, 'explicit retry after cancellation requires fresh consent');
    assert.notEqual(store.transfers[0].id, cancelled);
    assert.equal(store.transfers[0].status, 'complete');
    assert.equal(store.transfers.find(item => item.id === cancelled).retryTransferId, store.transfers[0].id);
    failSecond = true;
    const outdated = await service.send(peer, [files[1]]);
    expired = 'attempt-4'; failSecond = false;
    const cancelsBefore = cancels;
    await service.retry(outdated);
    assert.equal(offers.length, 5, 'expired token retry falls back to a new consent request');
    assert.equal(store.transfers[0].status, 'complete');
    assert.notEqual(store.transfers[0].id, outdated);
    assert.equal(cancels, cancelsBefore, 'rejected stale credentials must not cancel another receiver session');
    assert.equal(store.transfers.find(item => item.id === outdated).retryTransferId, store.transfers[0].id);
    failSecond = true;
    const stopped = await service.send(peer, [files[1]]);
    assert.equal(service.sendSessions.size, 1);
    await service.stop();
    assert.equal(service.sendSessions.size, 0, 'stop releases retained remote sessions');
    assert.equal(service.retryContexts.get(stopped).accepted, undefined);
    failSecond = false; await service.retry(stopped);
    assert.equal(offers.length, 7, 'retry after stopping needs fresh consent');
    assert.equal(store.transfers[0].status, 'complete');
    console.log('PASS original-session per-file and bulk retry, preserved successes, consent once and duplicate guards');
  } finally { await new Promise(resolve => server.close(resolve)); }
})().catch(error => { console.error(error); process.exitCode = 1; });


