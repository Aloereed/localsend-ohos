const assert = require('node:assert/strict');
const { load } = require('./host-runtime.cjs');
const { TransferFile } = load('model/AppStore');
const { batchReceiveNames } = load('model/ReceiveNames');
const files = Array.from({ length: 12 }, (_, i) => {
  const file = new TransferFile(); file.id = String(i); file.name = `trip/${String(12 - i).padStart(2, '0')}.jpg`; return file;
});
files[0].selected = false;
const renamed = batchReceiveNames(files, 'counter', 'Photo-', true, true);
assert.equal(renamed[0].name, files[0].name);
assert.equal(renamed[11].name, 'trip/Photo-01.jpg'); assert.equal(renamed[1].name, 'trip/Photo-11.jpg');
assert.equal(files[11].name, 'trip/01.jpg', 'input must remain unchanged');
assert.deepEqual(renamed.map(f => f.id), files.map(f => f.id));
assert.throws(() => batchReceiveNames(files, 'counter', '../escape', false, false));
const random = batchReceiveNames(files, 'random', '', false, false);
assert.match(random[1].name, /^trip\/[a-f0-9-]{36}\.jpg$/);
const text = new TransferFile(); text.id = 'text'; text.name = 'message.txt'; text.preview = 'Hello';
assert.equal(batchReceiveNames([text], 'random', '', false, false)[0].name, 'message.txt');
console.log('PASS batch naming preserves identity, folder structure, extensions and unselected files; sorting, padding and random names are valid');
