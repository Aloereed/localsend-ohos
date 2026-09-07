const assert = require('node:assert/strict');
const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');
const { load, mocks } = require('./host-runtime.cjs');
const { AppStore, Peer } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
(async () => {
  const work = path.join(__dirname, '../logs/favorite-discovery-' + Date.now()); await fs.mkdir(work, { recursive: true });
  const context = { filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) };
  const store = new AppStore(); await store.init(context); store.settings.visible = false;
  const service = new LocalSendService(store);
  const favorite = Object.assign(new Peer(), { alias: 'Old', fingerprint: 'peer', ip: '127.0.0.1', protocol: 'http' });
  const server = http.createServer((req, res) => { res.setHeader('content-type', 'application/json'); res.end(JSON.stringify({ alias: 'New device name', fingerprint: 'peer', version: '2.1', protocol: 'http' })); });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  favorite.port = server.address().port; store.favorites = [favorite];
  try {
    await service.probe(favorite);
    assert.equal(store.favorites[0].alias, 'New device name', 'successful HTTP discovery refreshes an automatic name at the same endpoint');
    assert.equal(store.favorites[0].customAlias, false);
    const custom = store.updateFavorite(store.favorites[0], 'My computer', favorite.ip, String(favorite.port));
    assert.equal(custom.customAlias, true);
    await service.probe(custom); assert.equal(store.favorites[0].alias, 'My computer');
    const trusted = Object.assign(new Peer(), { alias: 'Secure old', fingerprint: 'secure', ip: '10.0.0.1', protocol: 'https' });
    store.favorites = [trusted];
    const changed = Object.assign(new Peer(), trusted, { alias: 'Secure new', ip: '10.0.0.2' });
    service.upsertPeer(changed, false); assert.equal(store.favorites[0], trusted, 'UDP announcements alone cannot rewrite saved endpoints');
    service.upsertPeer(changed, true); assert.equal(store.favorites[0].ip, changed.ip); assert.equal(store.favorites[0].alias, changed.alias);
    const secure = store.favorites[0];
    service.upsertPeer(Object.assign(new Peer(), changed, { protocol: 'http', alias: 'downgrade' }), true);
    assert.equal(store.favorites[0], secure, 'HTTP discovery cannot downgrade an HTTPS favorite');
    service.upsertPeer(Object.assign(new Peer(), changed, { fingerprint: 'different' }), true);
    assert.equal(store.favorites[0], secure, 'a different identity cannot replace the favorite');
    await store.save();
    await store.storage.put('favorites', JSON.stringify([{ alias: 'Legacy remark', ip: '10.0.0.3', port: 53317, fingerprint: 'legacy', protocol: 'https' }]));
    const original = mocks['@kit.ArkData'].preferences.getPreferences;
    mocks['@kit.ArkData'].preferences.getPreferences = async () => store.storage;
    try {
      const restarted = new AppStore(); await restarted.init(context);
      assert.equal(restarted.favorites.length, 1); assert.equal(restarted.favorites[0].alias, 'Legacy remark');
      assert.equal(restarted.favorites[0].customAlias, true);
    } finally { mocks['@kit.ArkData'].preferences.getPreferences = original; }
  } finally { await new Promise(resolve => server.close(resolve)); }
  console.log('PASS actual HTTP favorite name refresh, custom remark preservation, verified identity/address updates, downgrade rejection and legacy remarks');
})().catch(error => { console.error(error); process.exitCode = 1; });
