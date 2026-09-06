const assert = require('node:assert/strict');
const { load } = require('./host-runtime.cjs');
const { readableColor, contrast } = load('model/Colors');
for (const color of ['#168A75', '#2473E8', '#7454C9', '#BB5C36', '#BD4F78', '#C44747']) {
  for (const surface of ['#FFFFFF', '#F1F3F5', '#383838', '#E9EEF5', '#343A43']) {
    const result = readableColor(color, surface);
    assert.ok(contrast(result, surface) >= 4.6, `${color} on ${surface}: ${result}`);
  }
}
console.log('PASS all theme accents meet 4.6:1 for white labels and nominal light/dark text surfaces');
const { AppStore } = load('model/AppStore');
const store = new AppStore();
store.settings.pureBlack = true; store.settings.theme = 'dark';
assert.equal(store.canvasColor, '#000000'); assert.equal(store.ambientColor, '#000000');
store.settings.theme = 'light'; assert.notEqual(store.canvasColor, '#000000', 'OLED preference only affects dark mode');
store.settings.reduceEffects = true;
for (const theme of ['light', 'dark']) {
  store.settings.theme = theme;
  assert.match(store.surfaceColor, /^#[0-9A-F]{6}$/i, 'reduced effects use opaque content');
  assert.match(store.glassColor, /^#[0-9A-F]{6}$/i, 'reduced effects use opaque overlays');
  assert.equal(store.ambientColor, store.canvasColor);
  assert.ok(contrast(store.accentText, store.controlSurface) >= 4.6);
}
console.log('PASS OLED mode keeps the light palette and reduced effects use readable opaque surfaces');
