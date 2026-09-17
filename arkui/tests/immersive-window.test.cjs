const assert = require('node:assert/strict');
const { load, mocks } = require('./host-runtime.cjs');
mocks['@kit.AbilityKit'].UIAbility = class {};
mocks['@kit.ArkUI'] = { window: { AvoidAreaType: { TYPE_SYSTEM: 0, TYPE_CUTOUT: 1, TYPE_NAVIGATION_INDICATOR: 2 } } };
const { appStore } = load('model/AppStore');
const EntryAbility = load('entryability/EntryAbility').default;
const tick = () => new Promise(resolve => setImmediate(resolve));
(async () => {
  const ability = new EntryAbility();
  const bars = [], fullscreen = [], backgrounds = [], indicators = []; let listener, removed = false;
  const areas = [[40, 0], [48, 0], [0, 24]];
  const mainWindow = {
    setSpecificSystemBarEnabled: async (name, enabled) => { indicators.push([name, enabled]); },
    setWindowLayoutFullScreen: async value => { fullscreen.push(value); },
    setWindowBackgroundColor: value => backgrounds.push(value),
    setWindowSystemBarProperties: async value => { bars.push(value); },
    getWindowAvoidArea: type => ({ topRect: { height: areas[type][0] }, bottomRect: { height: areas[type][1] } }),
    on: (name, callback) => { assert.equal(name, 'avoidAreaChange'); listener = callback; },
    off: name => { assert.equal(name, 'avoidAreaChange'); removed = true; },
    setWindowKeepScreenOn: async () => {}
  };
  ability.onWindowStageCreate({ getMainWindow: async () => mainWindow, loadContent: () => {} });
  await tick();
  assert.deepEqual(fullscreen, [true]);
  assert.deepEqual(indicators.at(-1), ['navigationIndicator', false]);
  assert.equal(appStore.safeTopPx, 48); assert.equal(appStore.safeBottomPx, 24);
  assert.equal(bars.at(-1).statusBarColor, '#00000000');
  assert.equal(bars.at(-1).statusBarContentColor, '#182431');
  assert.equal(bars.at(-1).navigationBarColor, '#00000000');
  assert.equal(bars.at(-1).navigationBarContentColor, '#182431');
  assert.equal(backgrounds.at(-1), appStore.canvasColor);
  appStore.settings.theme = 'dark'; appStore.applyTheme();
  assert.equal(bars.at(-1).statusBarContentColor, '#FFFFFF');
  assert.equal(bars.at(-1).navigationBarContentColor, '#FFFFFF');
  assert.equal(backgrounds.at(-1), appStore.canvasColor);
  areas[0] = [32, 30]; areas[1] = [0, 0]; listener();
  assert.equal(appStore.safeTopPx, 32); assert.equal(appStore.safeBottomPx, 30);
  areas[1] = [0, 36]; listener(); assert.equal(appStore.safeBottomPx, 36);
  ability.onWindowStageDestroy(); assert.equal(removed, true);
  const count = bars.length; appStore.applyTheme(); assert.equal(bars.length, count);
  let resolveWindow;
  ability.onWindowStageCreate({ getMainWindow: () => new Promise(resolve => { resolveWindow = resolve; }), loadContent: () => {} });
  ability.onWindowStageDestroy(); resolveWindow(mainWindow); await tick();
  assert.equal(fullscreen.length, 1, 'destroyed stage must not configure a stale window');
  console.log('PASS full-screen transparent system bars, theme contrast, changing safe areas, and destroyed-window callbacks');
})().catch(error => { console.error(error); process.exitCode = 1; });
