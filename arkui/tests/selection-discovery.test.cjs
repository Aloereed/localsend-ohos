const assert = require('node:assert/strict');
const fs = require('node:fs/promises'), path = require('node:path');
const { load, mocks, handles } = require('./host-runtime.cjs');
const { AppStore } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
(async () => {
  const work = path.join(__dirname, '../logs/selection-discovery-' + Date.now()); await fs.mkdir(work, { recursive: true });
  const uri = path.join(work, 'small.jpg'); await fs.writeFile(uri, Buffer.alloc(1400000, 42));
  const store = new AppStore(); await store.init({ filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) });
  const service = new LocalSendService(store); service.running = true;
  const kit = mocks['@kit.CoreFileKit']; kit.picker.PhotoSelectOptions = class {}; kit.picker.PhotoViewMIMETypes = { IMAGE_VIDEO_TYPE: 0 };
  kit.picker.PhotoViewPicker = class { async select() { return { photoUris: [uri] }; } };
  let active = 0, started = 0, reads = 0, release, entered;
  const gate = new Promise(r => { release = r; }), opening = new Promise(r => { entered = r; });
  const open = kit.fileIo.open;
  kit.fileIo.open = async (...args) => {
    assert.equal(active, 0, 'scan sockets are cancelled before opening the selected file');
    entered(); await gate; return open(...args);
  };
  service.readAddresses = async () => { reads++; }; service.multicast = { async sync() {}, send() {}, async close() {} };
  const scan = service.scan.run([{ name: 'wlan0', ip: '192.168.1.1', prefixLength: 24, ignored: false }], 53317, [], (peer, token) => new Promise((resolve, reject) => {
    active++; started++; token.close = () => { active--; reject(new Error('cancelled')); };
  }), false);
  try {
    assert.equal(active, 2);
    const selection = store.selectFiles('photo'); await opening; await scan;
    assert.equal(started, 2); assert.equal(store.selecting, true);
    await service.discover(false, true); assert.equal(reads, 0, 'foreground discovery defers while the picker/metadata is busy');
    release(); assert.equal(await selection, true); assert.equal(store.files[0].size, 1400000); assert.equal(handles.size, 0);
    await service.discover(false); assert.equal(reads, 0, 'do not immediately restart scans while selected-file UI renders');
    service.discoveryQuietUntil = 0; await service.discover(false); assert.equal(reads, 1, 'automatic discovery resumes after the quiet period');
    kit.picker.PhotoViewPicker = class { async select() { throw new Error('picker failed'); } };
    assert.equal(await store.selectFiles('photo'), false); assert.equal(store.selecting, false); assert.equal(store.busy, false);
    assert.equal(store.files.length, 1);
  } finally { release(); kit.fileIo.open = open; await service.stop(); }
  console.log('PASS selection cancels active scan sockets before file open, foreground deferral, 1.4 MB metadata, render quiet period, automatic resumption and failed-picker cleanup');
})().catch(error => { console.error(error); process.exitCode = 1; });
