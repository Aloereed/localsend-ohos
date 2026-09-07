const assert = require('node:assert/strict');
const { load } = require('./host-runtime.cjs');
const { TransferView, TransferFile } = load('model/AppStore');
const { transferTotal, transferredBytes, remainingSeconds } = load('model/TransferMetrics');
const transfer = new TransferView(); transfer.status = 'transferring';
const accepted = new TransferFile(); accepted.size = 100; accepted.transferred = 40;
const skipped = new TransferFile(); skipped.size = 900; skipped.status = 'skipped';
const deselected = new TransferFile(); deselected.size = 500; deselected.selected = false;
transfer.files = [accepted, skipped, deselected];
assert.equal(transferTotal(transfer), 100);
assert.equal(transferredBytes(transfer), 40);
assert.equal(remainingSeconds(transfer, 20), 3);
assert.equal(remainingSeconds(transfer, 0), 0);
for (const status of ['waiting', 'complete', 'error', 'cancelled', 'declined']) {
  transfer.status = status;
  assert.equal(remainingSeconds(transfer, 20), 0, status + ' must not report an active ETA');
}
transfer.status = 'transferring'; accepted.transferred = 100;
assert.equal(transferredBytes(transfer), transferTotal(transfer));
assert.equal(remainingSeconds(transfer, 20), 0);
accepted.selected = false;
assert.equal(transferTotal(transfer), 0); assert.equal(transferredBytes(transfer), 0);
console.log('PASS accepted-subset byte totals and terminal-state ETA');
