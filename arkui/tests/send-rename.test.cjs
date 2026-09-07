const assert = require('node:assert/strict');
const { load } = require('./host-runtime.cjs');
const { AppStore, ShareFile } = load('model/AppStore');
const store = new AppStore();
const file = Object.assign(new ShareFile(), { id: 'one', name: 'trip/day/photo.jpg', uri: 'file://docs/original.jpg', mime: 'image/jpeg', size: 123 });
const other = Object.assign(new ShareFile(), { id: 'two', name: 'other.jpg' });
store.files = [file, other];
const initial = store.files;
for (const invalid of ['', '  ', '../escape', 'new/name', 'bad\u0000name', '.', '..']) {
  assert.equal(store.renameFile(file.id, invalid), false);
  assert.equal(store.files, initial, 'invalid edits must preserve the selection');
}
assert.ok(store.error);
assert.equal(store.renameFile(file.id, ' renamed.png '), true);
assert.equal(store.error, '', 'correcting invalid input clears the old error');
assert.equal(store.files[0].name, 'trip/day/renamed.png');
assert.equal(store.files[0].uri, file.uri);
assert.equal(store.files[0].mime, file.mime);
assert.equal(store.files[0].size, file.size);
assert.equal(file.name, 'trip/day/photo.jpg', 'active send snapshots must not be mutated');
assert.equal(store.files[1], other);
assert.equal(store.renameFile(file.id, 'final'), true);
assert.equal(store.files[0].name, 'trip/day/final');
const beforeMissing = store.files;
assert.equal(store.renameFile('removed', 'name'), false);
assert.equal(store.files, beforeMissing);
console.log('PASS send rename correction, folder preservation, source identity and immutable snapshots');
