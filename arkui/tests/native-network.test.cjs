const assert = require('node:assert/strict');
const net = require('node:net');
const dgram = require('node:dgram');
const crypto = require('node:crypto');
const { load, mocks } = require('./host-runtime.cjs');
const { NativeClient } = load('network/NativeClient');
const { NativeDatagram } = load('network/NativeDatagram');
const { request, exchange, Cancellation } = load('network/Transport');
const native = mocks['libaloetls.so'];
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(predicate, timeout = 3000) {
  const start = Date.now();
  while (!predicate()) { if (Date.now() - start > timeout) throw new Error('Native network lifecycle timeout'); await delay(5); }
}
async function listen(server, host = '127.0.0.1') {
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, host, resolve); });
  return server.address().port;
}
const watchdog = setTimeout(() => { console.error('Native network tests leaked a handle or hung'); process.exit(1); }, 45000);
(async () => {
  assert.throws(() => native.tcpConnect(), /Expected/);
  assert.throws(() => native.tcpConnect('bad', 1, () => {}), /Invalid/);
  assert.throws(() => native.udpListen('0.0.0.0', 1, '127.0.0.1', () => {}), /multicast/);
  const probe = net.createServer(); const unused = await listen(probe); await new Promise(resolve => probe.close(resolve));
  // More than the native connection registry limit: both failure and cancellation
  // must release their handles, including cancellation before connect completes.
  for (let round = 0; round < 8; round++) await Promise.all(Array.from({ length: 10 }, async () => {
    const client = new NativeClient();
    await assert.rejects(client.connect('127.0.0.1', unused, false), /TCP connection/);
    client.close();
    const cancelled = new NativeClient(); const connecting = cancelled.connect('127.0.0.1', unused, true);
    cancelled.close(); await assert.rejects(connecting, /连接已结束/);
  }));
  console.log('PASS 80 refused TCP connections and 80 immediate TLS cancellations release native registries');

  const v6 = net.createServer(socket => { socket.on('error', () => {}); socket.end('IPv6'); });
  const port6 = await listen(v6, '::1');
  try {
    const client = new NativeClient(); let body = '';
    client.onMessage = bytes => { body += Buffer.from(bytes).toString(); };
    await client.connect('::1%0', port6, false); client.startReading();
    await until(() => body === 'IPv6'); client.close();
  } finally { await new Promise(resolve => v6.close(resolve)); }
  console.log('PASS native IPv6 connection with numeric scope and pull receive');

  let peer, gone = false;
  const hanging = net.createServer(socket => {
    peer = socket; socket.on('error', () => {}); socket.on('data', () => {});
    socket.on('close', () => { gone = true; });
  });
  const hangingPort = await listen(hanging);
  try {
    const token = new Cancellation();
    const pending = request({ ip: '127.0.0.1', port: hangingPort, protocol: 'https' }, 'POST', '/', '', token);
    const rejected = assert.rejects(pending, /stop handshake/);
    await until(() => peer); token.cancel('stop handshake'); await rejected;
    await until(() => gone, 1500);
  } finally { peer?.destroy(); await new Promise(resolve => hanging.close(resolve)); }
  console.log('PASS cancelling stalled TLS handshake closes the real peer promptly');

  peer = undefined; gone = false;
  const blocked = net.createServer(socket => {
    peer = socket; socket.pause(); socket.on('error', () => {});
    socket.on('close', () => { gone = true; });
  });
  const blockedPort = await listen(blocked); let produced = 0, producerEnded = false;
  try {
    const token = new Cancellation(), block = new Uint8Array(65536);
    const pending = exchange({ ip: '127.0.0.1', port: blockedPort, protocol: 'http' }, 'POST', '/', 64 * 1024 * 1024,
      async write => { try { for (let i = 0; i < 1024; i++) { await write(block); produced += block.length; } } finally { producerEnded = true; } }, token);
    const rejected = assert.rejects(pending, /stop blocked writer/);
    await until(() => produced >= 65536); await delay(100);
    assert.ok(produced < 64 * 1024 * 1024, 'native sends must block at the TCP window');
    token.cancel('stop blocked writer'); await rejected;
    await until(() => producerEnded, 1500);
    const stoppedAt = produced; peer.resume(); await until(() => gone, 1500);
    assert.equal(produced, stoppedAt);
  } finally { peer?.destroy(); await new Promise(resolve => blocked.close(resolve)); }
  console.log('PASS native send backpressure and cancellation release producer and peer');

  const node = dgram.createSocket({ type: 'udp4', reuseAddr: true });
  node.on('error', () => {});
  await new Promise(resolve => node.bind(0, '0.0.0.0', resolve));
  const udpProbe = dgram.createSocket('udp4'); await new Promise(resolve => udpProbe.bind(0, '0.0.0.0', resolve));
  const udpPort = udpProbe.address().port; await new Promise(resolve => udpProbe.close(resolve));
  const group = '224.0.0.167';
  try {
    // Some Windows hosts route/filter multicast without local loopback. Check
    // an independent implementation before relying on that host capability.
    node.addMembership(group); node.setMulticastLoopback(true); node.setMulticastTTL(1);
    const multicastAvailable = await new Promise((resolve, reject) => {
      const marker = 'independent multicast probe';
      const received = bytes => { if (bytes.toString() === marker) finish(true); };
      const finish = value => { clearTimeout(timer); node.off('message', received); resolve(value); };
      const timer = setTimeout(() => finish(false), 1500);
      node.on('message', received);
      node.send(marker, node.address().port, group, error => { if (error) { finish(false); reject(error); } });
    });
    if (!multicastAvailable) console.log('LIMIT: independent Node multicast loopback also unavailable on this host; LAN discovery remains a device check');
    for (let round = 0; round < 12; round++) {
      const socket = new NativeDatagram(), received = [];
      const payload = crypto.randomBytes(8192);
      await socket.listen({ address: '0.0.0.0', port: udpPort }, group, info => received.push(info));
      try {
        await new Promise((resolve, reject) => node.send(payload, udpPort, '127.0.0.1', error => error ? reject(error) : resolve()));
        await until(() => received.length);
        assert.equal(received[0].remoteInfo.address, '127.0.0.1');
        assert.equal(received[0].remoteInfo.port, node.address().port);
        assert.deepEqual(Buffer.from(received[0].message), payload);
        const response = new Promise(resolve => node.once('message', data => resolve(data)));
        await socket.send({ address: { address: '127.0.0.1', port: node.address().port }, data: Uint8Array.from(payload).buffer });
        assert.deepEqual(await response, payload);
        await socket.send({ address: { address: group, port: udpPort }, data: 'native multicast' });
        if (multicastAvailable) await until(() => received.some(info => Buffer.from(info.message).toString() === 'native multicast'));
      } finally { await socket.close(); await socket.close(); }
      await assert.rejects(socket.send({ address: { address: group, port: udpPort }, data: 'closed' }), /停止/);
    }
  } finally { await new Promise(resolve => node.close(resolve)); }
  console.log('PASS 12 native UDP cycles: independent binary receive/send, multicast membership/send, close/rebind');
  clearTimeout(watchdog);
})().catch(error => { clearTimeout(watchdog); console.error(error); process.exitCode = 1; });
