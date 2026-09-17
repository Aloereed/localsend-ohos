const assert = require('node:assert/strict');
const { load } = require('./host-runtime.cjs');
const { formatSize } = load('model/AppStore');
const { uniqueName } = load('network/Protocol');
for (const [bytes, label] of [[0, '0 B'], [999, '999 B'], [1000, '1.0 KB'], [1e6, '1.0 MB'], [1e9, '1.00 GB'], [1e12, '1.00 TB'], [1e15, '1.00 PB']]) assert.equal(formatSize(bytes), label);
assert.equal(uniqueName('file.txt', ['file.txt', 'file (1).txt']), 'file (2).txt');
assert.equal(uniqueName('.hidden', ['.hidden']), '.hidden (1)');
assert.equal(uniqueName('dir/file.txt', ['dir/file.txt']), 'dir/file (1).txt');
console.log('PASS decimal size units through PB and duplicate filename boundaries');
