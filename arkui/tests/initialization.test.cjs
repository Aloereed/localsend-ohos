const assert = require('node:assert/strict');
const { load, mocks } = require('./host-runtime.cjs');
const { AppStore } = load('model/AppStore');
(async () => {
  const preferences = mocks['@kit.ArkData'].preferences;
  const context = { filesDir: 'unused', getApplicationContext: () => ({ setColorMode() {} }) };
  const store = new AppStore(); let attempts = 0, writes = 0, failHistory = true;
  const settings = JSON.stringify({ ...store.settings, alias: 'Preserved device' });
  const values = { settings, flutter_import_v1: '{"favorites":0,"history":0,"messages":0,"skipped":[]}', privacy_policy_accepted: true, favorites: '[]', history: '[{"id":"kept","name":"received.txt"}]' };
  preferences.getPreferences = async () => {
    attempts++;
    if (attempts === 1) throw new Error('temporarily unavailable');
    return {
      get: async (key, fallback) => {
        if (key === 'history' && failHistory) throw new Error('history read failed');
        return key in values ? values[key] : fallback;
      },
      put: async () => { writes++; }, flush: async () => { writes++; }
    };
  };
  await Promise.all([store.init(context), store.init(context)]);
  assert.equal(attempts, 1); assert.equal(store.ready, false);
  assert.match(store.initializationError, /temporarily unavailable/);
  await store.init(context);
  assert.equal(attempts, 2); assert.equal(store.ready, false);
  assert.match(store.initializationError, /history read failed/);
  failHistory = false;
  await Promise.all([store.init(context), store.init(context)]);
  assert.equal(attempts, 3); assert.equal(store.ready, true);
  assert.equal(store.initializationError, ''); assert.equal(store.settings.alias, 'Preserved device');
  assert.equal(store.history[0].id, 'kept'); assert.equal(store.privacyAccepted, true);
  assert.equal(writes, 0, 'retrying must not reset or overwrite persistent data');
  await store.init(context); assert.equal(attempts, 3);
  store.error = ''; store.notice = '';
  console.log('PASS shared initialization, initial and partial read failures, retry, and preserved data');
})().catch(error => { console.error(error); process.exitCode = 1; });
