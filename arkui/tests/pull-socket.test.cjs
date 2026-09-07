const assert = require('node:assert/strict');
const net = require('node:net');
const native = require('../logs/native-host/aloetls.node');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(predicate, timeout = 3000) {
  const start = Date.now();
  while (!predicate()) { if (Date.now() - start > timeout) throw new Error('TCP lifecycle timeout'); await delay(5); }
}
(async () => {
  const probe = net.createServer(); await new Promise(resolve => probe.listen(0, '127.0.0.1', resolve));
  const port = probe.address().port; await new Promise(resolve => probe.close(resolve));
  assert.throws(() => native.tcpListen(), /Expected/);
  assert.throws(() => native.tcpSend(), /Expected/);
  for (let round = 0; round < 12; round++) {
    const events = [], peers = [];
    const server = native.tcpListen('127.0.0.1', port, event => {
      events.push(event);
      if (event.kind === 'close') native.tcpClose(event.id);
    });
    try {
      for (let index = 0; index < 4; index++) {
        const peer = net.connect(port, '127.0.0.1'); peers.push(peer);
        peer.on('error', () => {});
        await new Promise(resolve => peer.once('connect', resolve));
      }
      await until(() => events.filter(event => event.kind === 'connect').length === 4);
      const handles = events.filter(event => event.kind === 'connect').map(event => event.id);
      peers[0].write(Buffer.alloc(256 * 1024, 123));
      await delay(20);
      assert.equal(events.filter(event => event.kind === 'message').length, 0, 'no native reads without acknowledgement');
      native.tcpRead(handles[0]);
      await until(() => events.some(event => event.kind === 'message'));
      await delay(20);
      const messages = events.filter(event => event.kind === 'message');
      assert.equal(messages.length, 1); assert.ok(messages[0].data.byteLength <= 65536);
      // Close a peer while the server has no outstanding read credit.
      peers[1].end();
      await until(() => events.some(event => event.kind === 'close' && event.id === handles[1]));
      // A client that stops reading must not prevent server shutdown from
      // releasing queued native writes or rebinding the same port.
      const writes = Array.from({ length: 8 }, () => native.tcpSend(handles[2], new ArrayBuffer(2 * 1024 * 1024)));
      const settled = Promise.allSettled(writes);
      await delay(20); native.tcpStop(server);
      await until(() => events.some(event => event.kind === 'stopped'));
      const outcomes = await Promise.race([settled, delay(3000).then(() => { throw new Error('writes remained blocked after stop'); })]);
      assert.ok(outcomes.some(outcome => outcome.status === 'rejected'));
      native.tcpRead(handles[0]); native.tcpClose(handles[0]); native.tcpStop(server);
    } finally { native.tcpStop(server); for (const peer of peers) peer.destroy(); }
  }
  console.log('PASS 12 native TCP restart cycles: read credits, idle peer EOF, blocked writes released, immediate port reuse');
})().catch(error => { console.error(error); process.exitCode = 1; });
