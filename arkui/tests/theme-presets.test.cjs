const assert = require('node:assert/strict');
const { load, mocks } = require('./host-runtime.cjs');
const { AppStore } = load('model/AppStore');
const { contrast } = load('model/Colors');
(async () => {
  let dark = false, color = 0xFF5865A0;
  const context = { filesDir: 'theme-presets', getApplicationContext: () => ({ setColorMode() {} }), resourceManager: {
    getConfigurationSync: () => ({ colorMode: dark ? 0 : 1 }),
    getColorSync: resource => { assert.equal(resource.params[0], 'sys.color.brand'); return color; }
  } };
  const store = new AppStore(); await store.init(context);
  store.settings.accent = '#7454C9';
  for (const preset of ['system', 'localsend', 'oled', 'yaru', 'custom']) {
    store.settings.themePreset = preset;
    for (const theme of ['light', 'dark']) {
      store.settings.theme = theme;
      assert.ok(contrast(store.accentText, store.controlSurface) >= 4.6, preset + ' text contrast');
      assert.ok(contrast(store.accentFill, '#FFFFFF') >= 4.6, preset + ' white button labels');
    }
  }
  store.settings.themePreset = 'system'; assert.equal(store.accent, '#5865A0');
  dark = true; color = 0xFFAABBCC; store.settings.theme = 'system'; store.refreshSystemTheme();
  assert.equal(store.dark, true); assert.equal(store.accent, '#AABBCC');
  store.settings.themePreset = 'custom'; assert.equal(store.accent, '#7454C9', 'system/preset changes preserve the custom color');
  store.settings.themePreset = 'oled'; assert.equal(store.canvasColor, '#000000'); assert.equal(store.surfaceColor, '#000000');
  store.settings.theme = 'light'; assert.notEqual(store.canvasColor, '#000000');
  store.settings.themePreset = 'yaru'; assert.equal(store.accent, '#E95420'); assert.equal(store.canvasColor, '#FFFFFF');
  store.settings.theme = 'dark'; assert.equal(store.canvasColor, '#252525');
  await store.save();
  const preferences = mocks['@kit.ArkData'].preferences, original = preferences.getPreferences;
  preferences.getPreferences = async () => store.storage;
  try {
    const restored = new AppStore(); await restored.init(context);
    assert.equal(restored.settings.themePreset, 'yaru'); assert.equal(restored.settings.accent, '#7454C9');
    const legacy = { ...store.settings }; delete legacy.themePreset;
    await store.storage.put('settings', JSON.stringify(legacy));
    const upgraded = new AppStore(); await upgraded.init(context);
    assert.equal(upgraded.settings.themePreset, 'custom'); assert.equal(upgraded.accent, '#7454C9', 'upgrade must preserve the old selected color');
  } finally { preferences.getPreferences = original; }
  console.log('PASS preset contrast, dynamic system color, OLED/light behavior, Yaru colors, custom preservation, reload and legacy upgrade');
})().catch(error => { console.error(error); process.exitCode = 1; });
