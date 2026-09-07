const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { load, mocks } = require('./host-runtime.cjs');
const { AppStore, Peer } = load('model/AppStore');
(async () => {
  const work = path.join(__dirname, '../logs/favorite-edit-' + Date.now());
  await fs.mkdir(work, { recursive: true });
  const context = { filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) };
  const store = new AppStore(); await store.init(context);
  const first = new Peer(); Object.assign(first, { ip: '192.168.1.5', alias: 'Original', protocol: 'https', fingerprint: 'trusted-identity' });
  const second = new Peer(); Object.assign(second, { ip: '192.168.1.6', fingerprint: 'another-identity' });
  store.favorites = [first, second]; store.peers = [first];
  const updated = store.updateFavorite(first, '  工作电脑  ', ' [fe80::1234%wlan0] ', ' 60000 ');
  assert.equal(updated.alias, '工作电脑'); assert.equal(updated.ip, 'fe80::1234%wlan0'); assert.equal(updated.port, 60000);
  assert.equal(updated.fingerprint, first.fingerprint); assert.equal(updated.protocol, 'https');
  assert.equal(first.ip, '192.168.1.5', 'editing a favorite must not mutate an existing peer/transfer reference');
  assert.equal(store.favorites[1], second);
  const snapshot = JSON.stringify(store.favorites);
  for (const [ip, port] of [['999.1.1.1', '53317'], ['https://1.2.3.4/path', '53317'], ['1.2.3.4', '0'], ['1.2.3.4', '65536'], ['1.2.3.4', '5e3'], ['1.2.3.4', ''], ['192.168.1.6', '53317']]) {
    assert.throws(() => store.updateFavorite(updated, 'bad', ip, port));
    assert.equal(JSON.stringify(store.favorites), snapshot, 'invalid edits must leave every favorite unchanged');
  }
  const final = store.updateFavorite(updated, ' ', '192.168.1.20', '1');
  assert.equal(final.alias, '工作电脑'); assert.equal(final.port, 1);
  await store.save();
  const stored = JSON.parse(await store.storage.get('favorites', '[]'));
  assert.equal(stored.length, 2); assert.equal(stored[0].ip, '192.168.1.20');
  const getPreferences = mocks['@kit.ArkData'].preferences.getPreferences;
  mocks['@kit.ArkData'].preferences.getPreferences = async () => store.storage;
  try {
    const restarted = new AppStore(); await restarted.init(context);
    assert.equal(restarted.favorites.length, 2);
    assert.equal(restarted.favorites[0].fingerprint, 'trusted-identity');
    assert.equal(restarted.favorites[0].alias, '工作电脑'); assert.equal(restarted.favorites[0].port, 1);
  } finally { mocks['@kit.ArkData'].preferences.getPreferences = getPreferences; }
  store.favorites = [second];
  assert.throws(() => store.updateFavorite(final, 'gone', '192.168.1.7', '53317'), /不在收藏/);
  assert.equal(store.favorites.length, 1);
  console.log('PASS favorite endpoint edit, identity preservation, validation, duplicate rejection, immutable peers, persistence and deleted favorite');
})().catch(error => { console.error(error); process.exitCode = 1; });
