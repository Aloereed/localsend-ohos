const assert = require('node:assert/strict');
const { load } = require('./host-runtime.cjs');
const { uiText } = load('model/Locale');
const { AppStore } = load('model/AppStore');
assert.equal(uiText('接收', 'en'), 'Receive');
assert.equal(uiText('接收', 'zh'), '接收');
assert.equal(uiText('接收', 'system'), '接收');
assert.equal(uiText('已发送到 我的电脑', 'en'), 'Sent to 我的电脑');
assert.equal(uiText('已收到 小王 的文件', 'en'), 'Received files from 小王');
const store = new AppStore(); store.settings.language = 'en';
assert.equal(store.tf('共 {0} 项 · {1}', ['3', '12 MB']), '3 items · 12 MB');
assert.equal(store.tf('移除 {0}', ['我的照片.jpg']), 'Remove 我的照片.jpg');
for (const name of ['$&', '$`', "$'", '$$', 'file {1}.txt', '照片 🌿 {0}']) {
  assert.equal(store.tf('移除 {0}', [name]), 'Remove ' + name);
  assert.equal(uiText('已发送到 ' + name, 'en'), 'Sent to ' + name);
  assert.equal(uiText('已收到 ' + name + ' 的文件', 'en'), 'Received files from ' + name);
}
assert.equal(store.tf('{0} / {0} / {1}', ['literal {1}', '$&']), 'literal {1} / literal {1} / $&', 'replace each template slot once without interpreting inserted values');
assert.equal(store.tf('{0} {2}', ['known']), 'known {2}', 'missing values remain visible');
assert.equal(uiText('Unrecognized native error 801', 'en'), 'Unrecognized native error 801');
console.log('PASS locale selection, parameterized labels and verbatim device/file names');
