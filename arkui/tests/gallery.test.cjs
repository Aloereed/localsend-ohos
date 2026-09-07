const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { load, handles, mocks } = require('./host-runtime.cjs');
const { AppStore, HistoryEntry } = load('model/AppStore');
const work = path.join(__dirname, '../logs/gallery-fixture-' + Date.now());
(async () => {
  await fs.mkdir(work, { recursive: true });
  const store = new AppStore(); await store.init({ filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) });
  store.settings.offerGallerySave = true;
  const photo = new HistoryEntry(); photo.name = 'trip/photo.png'; photo.path = path.join(work, 'photo.png');
  const bytes = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aPmQAAAAASUVORK5CYII=', 'base64');
  await fs.writeFile(photo.path, bytes); await store.addHistory(photo);
  assert.equal(store.galleryQueue.length, 1);
  const destination = path.join(work, 'gallery.png'); let released = 0; let cancelled = true;
  const api = mocks['@kit.MediaLibraryKit'].photoAccessHelper;
  api.PhotoType = { IMAGE: 1, VIDEO: 2 };
  api.getPhotoAccessHelper = () => ({
    async showAssetsCreationDialog(sources, configs) {
      assert.equal(sources[0], photo.path); assert.equal(configs[0].title, 'photo');
      assert.equal(configs[0].fileNameExtension, 'png'); assert.equal(configs[0].photoType, 1);
      if (cancelled) return [];
      await fs.writeFile(destination, ''); return [destination];
    },
    async release() { released++; }
  });
  await store.saveToGallery([photo]);
  assert.equal(store.galleryQueue.length, 1); assert.equal(photo.galleryPath, '');
  cancelled = false; await store.saveToGallery([photo]);
  assert.deepEqual(await fs.readFile(destination), bytes);
  assert.equal(photo.galleryPath, destination); assert.equal(store.galleryQueue.length, 0);
  assert.equal(released, 2); assert.equal(handles.size, 0); assert.equal(store.savingToGallery, false);
  const first = Object.assign(new HistoryEntry(), { name: 'first.png', path: photo.path });
  const second = Object.assign(new HistoryEntry(), { name: 'second.png', path: path.join(work, 'missing.png'), exportedPath: destination });
  await store.addHistory(first); await store.addHistory(second);
  const firstOutput = path.join(work, 'first-output.png'), secondOutput = path.join(work, 'second-output.png');
  let dialogs = 0;
  api.getPhotoAccessHelper = () => ({
    async showAssetsCreationDialog(sources) {
      dialogs++; assert.deepEqual(Array.from(sources), [photo.path, destination]);
      await fs.writeFile(firstOutput, ''); await fs.writeFile(secondOutput, '');
      return [firstOutput, secondOutput];
    }, async release() { released++; }
  });
  const disk = mocks['@kit.CoreFileKit'].fileIo, copyFile = disk.copyFile; let copied = 0;
  disk.copyFile = async (...args) => { if (++copied === 2) throw new Error('disk full'); return copyFile(...args); };
  try { await store.saveToGallery([first, second]); } finally { disk.copyFile = copyFile; }
  assert.deepEqual(await fs.readFile(firstOutput), bytes);
  assert.equal(store.galleryQueue.some(entry => entry.id === first.id), false);
  assert.equal(store.galleryQueue.some(entry => entry.id === second.id), true);
  const persisted = JSON.parse(await store.storage.get('history', '[]'));
  assert.equal(persisted.find(entry => entry.id === first.id).galleryPath, firstOutput, 'successful copy is persisted even when the next copy fails');
  assert.equal(persisted.find(entry => entry.id === second.id).galleryPath, '');
  assert.match(store.error, /已保存 1 项/); assert.equal(released, 3);
  assert.equal(handles.size, 0); assert.equal(store.savingToGallery, false);
  await fs.unlink(destination);
  await store.saveToGallery([first, second]);
  assert.equal(dialogs, 1, 'unavailable sources fail before creating gallery assets');
  console.log('PASS gallery cancellation retains app copy and pending item; confirmation copies bytes, records destination and releases resources');
})().catch(error => { console.error(error); process.exitCode = 1; });
