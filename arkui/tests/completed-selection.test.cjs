const assert = require('node:assert/strict');
const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');
const { load } = require('./host-runtime.cjs');
const { AppStore, Peer } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
(async () => {
  const work = path.join(__dirname, '../logs/completed-selection-' + Date.now()); await fs.mkdir(work, { recursive: true });
  const store = new AppStore(); await store.init({ filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) });
  const service = new LocalSendService(store); let status = 204;
  const server = http.createServer((req, res) => { req.resume(); req.on('end', () => { res.writeHead(status, { 'content-length': 0 }); res.end(); }); });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const peer = Object.assign(new Peer(), { ip: '127.0.0.1', port: server.address().port, protocol: 'http', alias: 'Selection peer' });
    store.settings.sendMode = 'single'; store.addText('first'); store.addText('second');
    const second = store.files[1].id;
    const id = await service.send(peer);
    assert.equal(store.files.length, 2, 'successful transfer keeps selection until its result page is closed');
    store.editText(second, 'edited'); store.addText('new draft');
    service.finishCompletedSelections();
    assert.deepEqual(Array.from(store.files, file => file.text), ['edited', 'new draft']);
    assert.equal(store.transfers.find(item => item.id === id).selectionClosed, true);
    store.editText(second, 'second'); service.finishCompletedSelections();
    assert.equal(store.files.length, 2, 'a previously closed result cannot clear a later edit');
    await service.sendMany([peer, peer]); service.finishCompletedSelections();
    assert.equal(store.files.length, 2, 'multi-device queue retains selection even when the global preference is single');
    store.settings.sendMode = 'multiple'; await service.send(peer); service.finishCompletedSelections();
    assert.equal(store.files.length, 2);
    store.settings.sendMode = 'single'; status = 403;
    await service.send(peer); service.finishCompletedSelections(); assert.equal(store.files.length, 2, 'decline retains selection');
    status = 500; await service.send(peer); service.finishCompletedSelections(); assert.equal(store.files.length, 2, 'failure retains selection');
    status = 204; await service.send(peer); service.finishCompletedSelections(); assert.equal(store.files.length, 0);
    console.log('PASS successful single-mode close, edited/new content protection, one-time cleanup and multi-device retention');
  } finally { await new Promise(resolve => server.close(resolve)); }
})().catch(error => { console.error(error); process.exitCode = 1; });
