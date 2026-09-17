const assert = require('node:assert/strict');
const { load } = require('./host-runtime.cjs');
const { AppStore } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const { PeerIdentityError } = load('network/Transport');
const flush = async () => { for (let i = 0; i < 30; i++) await Promise.resolve(); };
(async () => {
  const store = new AppStore(); store.settings.fingerprint = 'local'; store.settings.visible = true;
  const service = new LocalSendService(store); service.running = true;
  service.readAddresses = async () => {}; service.multicast = { async sync() {}, send() {}, async close() {} };
  service.scan = { cancel() {}, async run() {} };
  let attempts = 0, fail = true, blocked = false;
  service.register = async (peer, token) => {
    attempts++;
    if (blocked) { await new Promise(resolve => { token.close = resolve; }); token.check(); }
    if (fail) throw new Error('startup connection lost');
  };
  const announce = ip => service.discovered({ message: Buffer.from(JSON.stringify({ alias: 'LocalSend', fingerprint: ip, version: '2.2', port: 53317, protocol: 'https', announce: true })), remoteInfo: { address: ip } });
  try {
    announce('10.0.0.2'); announce('10.0.0.2'); await flush();
    assert.equal(attempts, 1, 'duplicate in-flight announcements coalesce');
    assert.equal(service.registrationRetries.size, 1);
    store.selecting = true; await service.discover(false); assert.equal(attempts, 1);
    store.selecting = false; store.busy = true; await service.discover(false); assert.equal(attempts, 1);
    store.busy = false; fail = false; await service.discover(false); await flush();
    assert.equal(attempts, 2, 'retry succeeds without a second remote announcement');
    assert.equal(service.registrationRetries.size, 0);
    fail = true; for (let i = 3; i < 23; i++) announce(`10.0.0.${i}`); await flush();
    assert.equal(service.registrationRetries.size, 16, 'failed peer queue stays bounded');
    const before = attempts; service.lastRegistrationRetry = 0;
    await service.discover(false); await flush(); assert.equal(attempts, before + 2);
    await service.discover(false); await flush(); assert.equal(attempts, before + 2, 'repeated refresh does not accelerate retries');
    blocked = true; service.lastRegistrationRetry = 0;
    await service.discover(false); store.selecting = true;
    await new Promise(resolve => setTimeout(resolve, 160)); await flush();
    assert.equal(service.registering.size, 0, 'in-flight retries yield to file selection');
    store.selecting = false; blocked = false;
    await service.stop(); assert.equal(service.registrationRetries.size, 0);
    service.running = true; service.register = async () => { throw new PeerIdentityError('changed'); };
    announce('10.0.0.25'); await flush(); assert.equal(service.registrationRetries.size, 0, 'identity errors are not retried');
    service.register = async (peer, token) => { await new Promise(resolve => { token.close = resolve; }); token.check(); };
    announce('10.0.0.26'); await service.stop(); await flush();
    assert.equal(service.registrationRetries.size, 0, 'cancelled old generation cannot repopulate retries');
  } finally { await service.stop(); }
  console.log('PASS reciprocal registration retry without remote refresh, deduplication, bounds, cooldown, busy cancellation, pinning errors and stop cleanup');
})().catch(error => { console.error(error); process.exitCode = 1; });
