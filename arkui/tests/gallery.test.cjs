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
  console.log('PASS gallery cancellation retains app copy and pending item; confirmation copies bytes, records destination and releases resources');
})().catch(error => { console.error(error); process.exitCode = 1; });
