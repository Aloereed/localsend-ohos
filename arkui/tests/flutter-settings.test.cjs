const assert = require('node:assert/strict');
const { load, mocks } = require('./host-runtime.cjs');
const { importFlutterSettings } = load('platform/FlutterSettings');
const { AppStore } = load('model/AppStore');
let old = {}, values = {}, fail = false, sourceWrites = 0;
const target = {
  get: async (key, fallback) => key in values ? values[key] : fallback,
  put: async (key, value) => { values[key] = value; },
  flush: async () => { if (fail) { fail = false; throw new Error('disk full'); } }
};
mocks['@kit.ArkData'].preferences.getPreferences = async (_, name) => name === 'FlutterSharedPreferences' ? {
  get: async (key, fallback) => key in old ? old[key] : fallback,
  put: async () => { sourceWrites++; throw new Error('read only'); }
} : target;
const context = { getApplicationContext() { return this; }, setColorMode() {} };
const legacy = input => Object.fromEntries(Object.entries(input).map(([key, value]) => ['flutter.ls_' + key, value]));
(async () => {
  old = legacy({ version: 2, alias: '旧设备 🌿', theme: 'dark', color: 'oled', locale: 'zh-Hant-TW',
    port: 54321, timeout: 2200, multicast_group: '239.1.2.3', destination: '/storage/Users/currentUser/Download/com.aloereed.aloesend/接收',
    quick_save: true, quick_save_from_favorites: true, save_to_history: false, auto_finish: false,
    save_to_gallery: true, enable_animations: false, lightweight_effects: true, https: false, advanced_settings: true,
    share_via_link_auto_accept: true, open_message_tab_on_incoming_files: true,
    receive_pin: '文字 PIN $🌿', send_mode: 'multiple', device_type: 'desktop', device_model: 'Old model',
    network_whitelist: 'VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu' + Buffer.from(JSON.stringify(['192.168.*.*'])).toString('base64'),
    security_context: 'MUST NOT IMPORT', legacy_ui_mode: true
  });
  const before = JSON.stringify(old);
  values = { flutter_import_v1: '{"favorites":1}', history: '[{"id":"keep"}]' };
  const report = await importFlutterSettings(context, target);
  let result = JSON.parse(values.settings);
  assert.ok(report.imported.length >= 25);
  assert.equal(result.alias, '旧设备 🌿'); assert.equal(result.language, 'zh-TW');
  assert.equal(result.theme, 'dark'); assert.equal(result.themePreset, 'oled');
  assert.equal(result.https, false); assert.equal(result.saveHistory, false); assert.equal(result.animations, false);
  assert.equal(result.pin, '文字 PIN $🌿'); assert.equal(result.port, 54321); assert.equal(result.discoveryTimeout, 2200);
  assert.equal(result.multicast, '239.1.2.3'); assert.equal(result.sendMode, 'multiple');
  assert.equal(result.destinationMode, 'folder'); assert.match(result.destination, /接收$/);
  assert.equal(result.networkFilter, 'allow'); assert.deepEqual(result.networkPatterns, ['192.168.*.*']);
  assert.equal(result.fingerprint, undefined); assert.equal(result.legacyUiMode, undefined);
  assert.equal(values.history, '[{"id":"keep"}]'); assert.equal(JSON.stringify(old), before);
  old['flutter.ls_alias'] = 'changed later'; await importFlutterSettings(context, target);
  assert.equal(JSON.parse(values.settings).alias, '旧设备 🌿', 'migration is idempotent');
  values = { settings: JSON.stringify({ alias: 'Native', quickSave: false, port: 55555, destination: '', destinationMode: 'private',
    networkFilter: 'none', networkPatterns: [], fingerprint: 'native-certificate' }) };
  await importFlutterSettings(context, target); result = JSON.parse(values.settings);
  assert.equal(result.alias, 'Native'); assert.equal(result.quickSave, false); assert.equal(result.port, 55555);
  assert.equal(result.destinationMode, 'private'); assert.equal(result.networkFilter, 'none');
  assert.equal(result.theme, 'dark', 'only missing native keys are filled');
  const saved = values.settings, marker = values.flutter_settings_import_v1;
  fail = true;
  await assert.rejects(importFlutterSettings(context, target, true, saved), /disk full/);
  assert.equal(values.settings, saved); assert.equal(values.flutter_settings_import_v1, marker);
  await importFlutterSettings(context, target, true, saved); result = JSON.parse(values.settings);
  assert.equal(result.alias, 'changed later'); assert.equal(result.fingerprint, 'native-certificate');
  old = legacy({ version: 2, alias: '', port: '54321', timeout: 1, https: 'false', theme: 'bad', locale: 'bad',
    multicast_group: '1.2.3.4', destination: '/storage/../secret', network_blacklist: ['bad regex['], receive_pin: '\u0000' });
  values = {}; const invalid = await importFlutterSettings(context, target); result = JSON.parse(values.settings);
  assert.ok(invalid.skipped.length >= 10);
  assert.equal(result.port, undefined); assert.equal(result.https, undefined); assert.equal(result.destination, undefined);
  assert.equal(result.autoFinish, false); assert.equal(result.offerGallerySave, true); assert.equal(result.reduceEffects, true);
  old = legacy({ version: 2 }); values = {}; await importFlutterSettings(context, target);
  assert.equal(JSON.parse(values.settings).language, 'system');
  old = legacy({ network_whitelist: [], network_blacklist: [] }); values = {}; await importFlutterSettings(context, target);
  assert.equal(JSON.parse(values.settings).networkFilter, 'allow', 'empty whitelist still blocks discovery');
  old = legacy({ network_whitelist: ['10.*.*.*'], network_blacklist: ['10.1.*.*'] }); values = {};
  assert.ok((await importFlutterSettings(context, target)).skipped.includes('network_filter'));
  old = {}; values = {}; await importFlutterSettings(context, target); assert.equal(values.settings, undefined);
  old = legacy({ network_whitelist: true }); values = {};
  assert.ok((await importFlutterSettings(context, target)).skipped.includes('network_filter'));
  assert.equal(values.settings, undefined);
  old = legacy({ alias: 'First upgrade', https: false, color: 'yaru', locale: 'en' });
  values = { flutter_import_v1: '{"favorites":0,"history":0,"messages":0,"skipped":[]}' };
  const first = new AppStore(); await first.init(context);
  assert.equal(first.ready, true); assert.equal(first.settings.alias, 'First upgrade');
  assert.equal(first.settings.https, false); assert.equal(first.settings.themePreset, 'yaru');
  assert.match(first.flutterSettingsSummary, /Flutter settings/);
  first.settings.alias = 'User changed'; await first.save();
  const reboot = new AppStore(); await reboot.init(context); assert.equal(reboot.settings.alias, 'User changed');
  old = legacy({ alias: 'Manual', https: false }); values = {};
  const store = new AppStore(); store.context = context; store.storage = target;
  const fingerprint = store.settings.fingerprint;
  store.webUrl = 'active'; assert.equal(await store.inheritFlutterSettings(), false); assert.equal(values.settings, undefined);
  store.webUrl = ''; assert.equal(await store.inheritFlutterSettings(), true);
  assert.equal(store.settings.alias, 'Manual'); assert.equal(store.settings.https, false); assert.equal(store.settings.fingerprint, fingerprint);
  assert.equal(store.settings.port, 53317, 'manual import keeps native-only and absent preferences');
  store.notice = ''; store.error = ''; assert.equal(sourceWrites, 0);
  console.log('PASS Flutter settings mappings, legacy marker upgrade, native overrides, invalid values, defaults, rollback, explicit import and source preservation');
})().catch(error => { console.error(error); process.exitCode = 1; });
