const assert = require('node:assert/strict');
const { load } = require('./host-runtime.cjs');
const { multicastAddress } = load('network/Addresses');
assert.equal(multicastAddress(' 224.0.0.167 '), '224.0.0.167');
assert.equal(multicastAddress('239.255.255.255'), '239.255.255.255');
assert.equal(multicastAddress('224.000.000.167'), '224.0.0.167');
for (const value of ['', '224..0.167', '224. .0.167', '224.0.0.', '224.0.0.1e2', '224.0.0.+1',
  '224.0.0.-1', '223.255.255.255', '240.0.0.1', '224.0.0.256', '224.0.0.1.2', 'ff02::1']) {
  assert.throws(() => multicastAddress(value), /组播地址/, value);
}
console.log('PASS multicast syntax, range, empty segments and canonical decimal form');
