// Requires local multicast access (run outside the network-restricted sandbox).
const assert = require('node:assert/strict');
const dgram = require('node:dgram');
const os = require('node:os');
const native = require('../logs/native-host/aloetls.node');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(predicate) {
  const started = Date.now();
  while (!predicate()) { if (Date.now() - started > 2500) throw new Error('native multicast deadline'); await delay(5); }
}
(async () => {
  const interfaces = native.networkInterfaces();
  const hostIps = Object.values(os.networkInterfaces()).flat().filter(ip => !ip.internal);
  assert.ok(interfaces.length > 0);
  for (const local of interfaces) {
    assert.ok(local.name); const match = hostIps.find(ip => ip.address.split('%')[0] === local.ip.split('%')[0]);
    assert.ok(match, local.ip); assert.equal(local.prefixLength, Number(match.cidr.split('/')[1]));
  }
  for (const ip of hostIps.filter(ip => ip.family === 'IPv4')) assert.ok(interfaces.some(local => local.ip === ip.address), ip.address);
  console.log('PASS native OS interface enumeration matches host addresses and prefix lengths');
  const probe = dgram.createSocket('udp4'); await new Promise(resolve => probe.bind(0, '127.0.0.1', resolve));
  const port = probe.address().port; await new Promise(resolve => probe.close(resolve));
  assert.throws(() => native.multicastOpen(), /Expected/);
  assert.throws(() => native.multicastOpen('127.0.0.1', port, '127.0.0.1', () => {}), /Invalid/);
  assert.throws(() => native.multicastOpen('224.0.0.167', port, 'bad', () => {}), /Invalid/);
  const lan = Object.values(os.networkInterfaces()).flat().find(ip => ip.family === 'IPv4' && /^192\.168\./.test(ip.address));
  assert.ok(lan, 'this integration test needs a LAN IPv4 interface in addition to loopback');
  for (let round = 0; round < 6; round++) {
    const events = []; const ids = [];
    try {
      for (const address of ['127.0.0.1', lan.address]) ids.push(native.multicastOpen('224.0.0.167', port, address, event => events.push(event)));
      const bytes = Uint8Array.from(Buffer.from('LocalSend discovery ' + round));
      for (const id of ids) native.multicastSend(id, bytes.buffer);
      await until(() => events.some(e => e.ip === '127.0.0.1') && events.some(e => e.ip === lan.address));
      for (const event of events.filter(e => e.kind === 'message')) assert.deepEqual(Buffer.from(event.data), Buffer.from(bytes));
    } finally { for (const id of ids) native.multicastStop(id); await until(() => events.filter(e => e.kind === 'stopped').length === ids.length); }
    for (const id of ids) assert.throws(() => native.multicastSend(id, new ArrayBuffer(1)), /closed/);
  }
  const link = Object.values(os.networkInterfaces()).flat().find(ip => ip.family === 'IPv6' && ip.scopeid > 0 && ip.mac === lan.mac);
  assert.ok(link, 'LAN interface must have an IPv6 scope for the IPv6 multicast check');
  const events6 = [];
  const id6 = native.multicastOpen('ff12::fd3a:e420', port, String(link.scopeid), event => events6.push(event));
  try {
    const bytes = Uint8Array.from(Buffer.from('IPv6 discovery'));
    native.multicastSend(id6, bytes.buffer);
    await until(() => events6.some(event => event.kind === 'message'));
    const event = events6.find(event => event.kind === 'message');
    assert.ok(event.ip.endsWith('%' + link.scopeid)); assert.deepEqual(Buffer.from(event.data), Buffer.from(bytes));
  } finally { native.multicastStop(id6); await until(() => events6.some(event => event.kind === 'stopped')); }
  console.log('PASS native multicast: two explicit source interfaces, real datagrams, shared port, six stop/rebind cycles and retired handles');
  console.log('PASS native IPv6 multicast: per-interface join/send/receive and scope preservation');
})().catch(error => { console.error(error); process.exitCode = 1; });
