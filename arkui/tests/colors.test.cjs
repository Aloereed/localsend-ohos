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
