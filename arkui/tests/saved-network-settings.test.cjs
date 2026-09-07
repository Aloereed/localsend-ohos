const assert = require('node:assert/strict');
const { load, mocks } = require('./host-runtime.cjs');
const { AppStore, AppSettings } = load('model/AppStore');
(async () => {
  const defaults = new AppSettings();
  let saved;
  mocks['@kit.ArkData'].preferences.getPreferences = async () => ({
    get: async (key, fallback) => key === 'settings' ? saved : key === 'flutter_import_v1'
      ? '{"favorites":0,"history":0,"messages":0,"skipped":[]}' : fallback,
    put: async () => { throw new Error('Loading must not overwrite stored data'); }, flush: async () => {}
  });
  async function read(network) {
    saved = JSON.stringify({ ...defaults, alias: 'Keep my name', fingerprint: 'keep-identity', https: false, ...network });
    const store = new AppStore();
    await store.init({ filesDir: 'unused', getApplicationContext: () => ({ setColorMode() {} }) });
    assert.equal(store.ready, true, store.initializationError);
    assert.equal(store.settings.alias, 'Keep my name');
    assert.equal(store.settings.fingerprint, 'keep-identity');
    assert.equal(store.settings.https, false);
    return store.settings;
  }
  for (const bad of [undefined, null, -1, 0, 1.5, '53317', 999999]) {
    const settings = await read({ port: bad, discoveryTimeout: bad, multicast: bad });
    assert.equal(settings.port, defaults.port);
    assert.equal(settings.discoveryTimeout, defaults.discoveryTimeout);
    assert.equal(settings.multicast, defaults.multicast);
  }
  for (const group of ['224..0.167', '192.168.1.1', '240.0.0.1']) {
    assert.equal((await read({ multicast: group })).multicast, defaults.multicast);
  }
  for (const [port, timeout] of [[1024, 500], [65535, 30000]]) {
    const settings = await read({ port, discoveryTimeout: timeout, multicast: ' 239.001.002.003 ' });
    assert.equal(settings.port, port); assert.equal(settings.discoveryTimeout, timeout);
    assert.equal(settings.multicast, '239.1.2.3');
  }
  console.log('PASS saved network recovery, valid boundaries, canonical multicast and preserved user identity');
})().catch(error => { console.error(error); process.exitCode = 1; });
