const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { load, mocks } = require('./host-runtime.cjs');
const { AppStore, HistoryEntry } = load('model/AppStore');
const { decodeFlutterList } = load('platform/FlutterImport');
const prefix = 'VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu';
const encode = rows => prefix + Buffer.from(JSON.stringify(rows.map(row => typeof row === 'string' ? row : JSON.stringify(row)))).toString('base64');
const work = path.join(__dirname, '../logs/flutter-import-' + Date.now());
const stores = new Map(); let failFlush = false;
mocks['@kit.ArkData'].preferences.getPreferences = async (context, name) => {
  const file = path.join(context.filesDir, name + '.json');
  if (!stores.has(file)) {
    const values = JSON.parse(await fs.readFile(file, 'utf8').catch(() => '{}'));
    stores.set(file, { values,
      get: async (key, fallback) => key in values ? values[key] : fallback,
      put: async (key, value) => { if (name === 'FlutterSharedPreferences') throw new Error('Must never write Flutter preferences'); values[key] = value; },
      flush: async () => { if (failFlush && name === 'aloesend-native-v1') { failFlush = false; throw new Error('disk full'); } await fs.writeFile(file, JSON.stringify(values)); }
    });
  }
  return stores.get(file);
};
const context = { filesDir: work, getApplicationContext() { return this; }, setColorMode() {} };
(async () => {
  await fs.mkdir(work, { recursive: true });
  const time = '2025-12-10T03:04:05.000Z';
  const peer = { conversationId: 'fingerprint:peer1', fingerprint: 'peer1', alias: '朋友', ip: '192.168.1.8', port: 53317, deviceType: 'desktop' };
  const legacy = {
    'flutter.ls_favorites': encode([{ ...peer, id: 'favorite1', customAlias: true }, { ...peer, id: 'duplicate' }, '{broken']),
    'flutter.ls_receive_history': encode([
      { id: 'text1', fileName: '你好 🌿', isMessage: true, fileType: 'text', fileSize: 11, senderAlias: '朋友', timestamp: time },
      { id: 'file1', fileName: '旅行.png', path: '/storage/Users/currentUser/Download/com.aloereed.aloesend/旅行.png', savedToGallery: true, fileType: 'image', fileSize: 1024, senderAlias: '朋友', timestamp: time }
    ]),
    'flutter.ls_message_history': encode([
      { id: 'text1', conversationId: peer.conversationId, peer, direction: 'incoming', kind: 'text', state: 'completed', text: '你好 🌿', items: [], createdAt: time, updatedAt: time },
      { id: 'file1', conversationId: peer.conversationId, peer, direction: 'incoming', kind: 'transferBatch', state: 'completed', items: [{ id: 'file1', fileName: '旅行.png', fileType: 'image', size: 1024, path: '/storage/Users/currentUser/Download/com.aloereed.aloesend/旅行.png', savedToGallery: true }], createdAt: time, updatedAt: time },
      { id: 'outgoing', conversationId: peer.conversationId, peer, direction: 'outgoing', kind: 'text', state: 'completed', text: '发出的消息', items: [], createdAt: time, updatedAt: time },
      ...Array.from({ length: 1100 }, (_, index) => ({ id: 'old-' + index, conversationId: peer.conversationId, peer, direction: 'incoming', kind: 'text', state: 'completed', text: '历史消息 ' + index, items: [], createdAt: time, updatedAt: time }))
    ]), 'flutter.ls_https': false
  };
  const sourceFile = path.join(work, 'FlutterSharedPreferences.json'); await fs.writeFile(sourceFile, JSON.stringify(legacy));
  const before = await fs.readFile(sourceFile, 'utf8');
  const nativeFile = path.join(work, 'aloesend-native-v1.json');
  await fs.writeFile(nativeFile, JSON.stringify({ history: '[{"id":"native-kept","name":"kept.txt","time":1}]', favorites: '[]' }));
  failFlush = true;
  const failed = new AppStore(); await failed.init(context); assert.equal(failed.ready, false);
  assert.match(failed.initializationError, /disk full/);
  const rolledBack = JSON.parse(await fs.readFile(nativeFile, 'utf8'));
  assert.equal(JSON.parse(rolledBack.history).length, 1); assert.equal(rolledBack.flutter_import_v1, '');
  await failed.init(context); assert.equal(failed.ready, true);
  assert.equal(failed.favorites.length, 1); assert.equal(failed.favorites[0].protocol, 'http');
  assert.equal(failed.favorites[0].customAlias, true, 'Flutter custom remarks survive migration');
  assert.equal(failed.history.length, 1104, 'receive compatibility rows must not duplicate richer messages');
  const photo = failed.history.find(item => item.name === '旅行.png');
  assert.equal(photo.galleryPath, photo.path); assert.equal(photo.exportedPath, photo.path);
  assert.equal(photo.peerInfo.fingerprint, 'peer1'); assert.equal(photo.time, Date.parse(time));
  assert.equal(failed.history.find(item => item.text === '发出的消息').direction, 'send');
  assert.equal(await fs.readFile(sourceFile, 'utf8'), before);
  const record = new HistoryEntry(); record.name = 'new'; await failed.addHistory(record);
  assert.equal(failed.history.length, 1105, 'adding new history must not truncate imported messages');
  stores.clear(); const restarted = new AppStore(); await restarted.init(context);
  assert.equal(restarted.history.length, 1105); assert.equal(restarted.favorites.length, 1);
  const report = JSON.parse((await mocks['@kit.ArkData'].preferences.getPreferences(context, 'aloesend-native-v1')).values.flutter_import_v1);
  assert.equal(report.skipped.length, 1); assert.equal(report.messages, 1103);
  assert.deepEqual(Array.from(decodeFlutterList(encode(['a', 'b']))), ['a', 'b']);
  assert.throws(() => decodeFlutterList('{}'));
  failed.error = ''; restarted.error = '';
  console.log('PASS Flutter plugin encoding, first-launch import, deduplication, Unicode, paths, directions, >1000 messages, rollback, idempotency and source preservation');
})().catch(error => { console.error(error); process.exitCode = 1; });
