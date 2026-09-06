const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { load, mocks } = require('./host-runtime.cjs');
mocks['@kit.AbilityKit'].UIAbility = class {};
mocks['@kit.ArkData'].preferences.getPreferences = async context => {
  const file = path.join(context.filesDir, 'preferences.json');
  const values = JSON.parse(await fs.readFile(file, 'utf8').catch(() => '{}'));
  return { get: async (key, fallback) => key in values ? values[key] : fallback,
    put: async (key, value) => { values[key] = value; },
    flush: async () => fs.writeFile(file, JSON.stringify(values)) };
};
const { AppStore, appStore } = load('model/AppStore');
const { localSend } = load('network/LocalSendService');
const EntryAbility = load('entryability/EntryAbility').default;
const work = path.join(__dirname, '../logs/privacy-fixture-' + Date.now());
const context = { filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) };
const tick = () => new Promise(resolve => setImmediate(resolve));
(async () => {
  await fs.mkdir(work, { recursive: true });
  const store = new AppStore(); await store.init(context);
  assert.equal(store.privacyAccepted, false, 'new installs must make an explicit choice');
  const originalFlush = store.storage.flush;
  store.storage.flush = async () => { throw new Error('disk full'); };
  assert.equal(await store.acceptPrivacy(), false); assert.equal(store.privacyAccepted, false);
  const afterFailure = new AppStore(); await afterFailure.init(context); assert.equal(afterFailure.privacyAccepted, false);
  store.storage.flush = originalFlush;
  assert.equal(await store.acceptPrivacy(), true);
  const restarted = new AppStore(); await restarted.init(context);
  assert.equal(restarted.privacyAccepted, true, 'acceptance survives restart');
  // Separate fresh preference store for entry lifecycle and deferred system shares.
  const fresh = { ...context, filesDir: work + '/fresh' }; await fs.mkdir(fresh.filesDir);
  let discoveries = 0, imports = 0;
  localSend.discover = async () => discoveries++;
  mocks['@kit.ShareKit'].systemShare.getSharedData = async () => { imports++; return { getRecords: () => [] }; };
  const ability = new EntryAbility(); ability.context = fresh;
  ability.onCreate({ action: 'ohos.want.action.sendData' }, {});
  await appStore.init(fresh); await tick();
  ability.onForeground(); await tick();
  assert.equal(discoveries, 0); assert.equal(imports, 0);
  await appStore.acceptPrivacy(); await appStore.onPrivacyAccepted();
  assert.equal(imports, 1); await appStore.onPrivacyAccepted(); assert.equal(imports, 1, 'deferred share is consumed once');
  ability.onForeground(); await tick(); assert.equal(discoveries, 1);
  ability.onNewWant({ action: 'ohos.want.action.sendData' }, {}); await tick(); assert.equal(imports, 2);
  console.log('PASS explicit consent, persistence failure, restart, foreground gating and deferred system shares');
})().catch(error => { console.error(error); process.exitCode = 1; });
