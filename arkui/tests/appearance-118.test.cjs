const assert = require('node:assert/strict');
const { load, mocks } = require('./host-runtime.cjs');
const { normalizeColor, colorChannel, changeColorChannel } = load('model/Colors');
const { formatRemaining } = load('model/TransferMetrics');
const { AppStore, AppSettings } = load('model/AppStore');
(async () => {
  assert.equal(normalizeColor(' ab12ef '), '#AB12EF');
  for (const value of ['#12345', '#1234567', '#GG0000', 'red', '']) assert.equal(normalizeColor(value), '');
  for (let channel = 0; channel < 3; channel++) {
    for (let value = 0; value <= 255; value++) {
      const result = changeColorChannel('#123456', channel, value);
      assert.equal(colorChannel(result, channel), value);
      for (let other = 0; other < 3; other++) if (channel !== other) assert.equal(colorChannel(result, other), colorChannel('#123456', other));
    }
  }
  for (const [seconds, result] of [[0, '0:00'], [59, '0:59'], [60, '1:00'], [3599, '59:59'], [3600, '1:00:00'], [86399, '23:59:59'], [86400, '1d 0:00:00'], [90061, '1d 1:01:01']]) {
    assert.equal(formatRemaining(seconds), result);
  }
  assert.equal(formatRemaining(86400, '天'), '1天 0:00:00');
  assert.equal(new AppSettings().favoriteQuickSave, true);
  const values = new Map([['settings', JSON.stringify({ favoriteQuickSave: false, createChecksums: false, verifyChecksums: false, accent: '#AB12EF', themePreset: 'custom' })]]);
  mocks['@kit.ArkData'].preferences.getPreferences = async () => ({
    get: async (key, fallback) => values.has(key) ? values.get(key) : fallback,
    put: async (key, value) => values.set(key, value), flush: async () => {},
  });
  const context = { filesDir: 'unused', getApplicationContext: () => ({ setColorMode() {} }) };
  const store = new AppStore(); await store.init(context);
  assert.equal(store.settings.favoriteQuickSave, false);
  assert.equal(store.settings.createChecksums, false); assert.equal(store.settings.verifyChecksums, false);
  assert.equal(store.settings.accent, '#AB12EF');
  values.set('settings', '{}'); const upgrade = new AppStore(); await upgrade.init(context);
  assert.equal(upgrade.settings.favoriteQuickSave, true);
  const basic = mocks['@kit.BasicServicesKit'];
  basic.deviceInfo.sdkApiVersion = 23;
  mocks['@kit.AccessibilityKit'].accessibility.isAnimationReduceEnabled = async () => true;
  values.delete('initial_animations'); values.set('settings', '{}'); const reduced = new AppStore(); await reduced.init(context);
  assert.equal(reduced.settings.animations, false);
  mocks['@kit.AccessibilityKit'].accessibility.isAnimationReduceEnabled = async () => false;
  const restarted = new AppStore(); await restarted.init(context);
  assert.equal(restarted.settings.animations, false, 'later system changes do not overwrite saved preference');
  basic.deviceInfo.sdkApiVersion = 22; basic.settings.getValue = async () => '0';
  values.delete('initial_animations'); values.set('settings', '{}'); const older = new AppStore(); await older.init(context);
  assert.equal(older.settings.animations, false);
  basic.settings.getValue = async () => { throw new Error('unsupported'); };
  values.delete('initial_animations'); values.set('settings', '{}'); const unavailable = new AppStore(); await unavailable.init(context);
  assert.equal(unavailable.settings.animations, true);
  console.log('PASS RGB range, hex validation, duration boundaries and explicit saved preference preservation');
})().catch(error => { console.error(error); process.exitCode = 1; });
