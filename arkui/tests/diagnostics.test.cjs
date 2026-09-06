const assert = require('node:assert/strict');
const { load } = require('./host-runtime.cjs');
const { AppStore } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const { HttpHead } = load('network/Protocol');
(async () => {
  const store = new AppStore();
  for (let i = 0; i < 305; i++) store.networkLog('discovery', 'peer\n' + i);
  assert.equal(store.networkLogs.length, 300); assert.equal(store.networkLogs[0].message, 'peer 304');
  const service = new LocalSendService(store);
  const head = new HttpHead(); head.method = 'POST'; head.target = '/api/localsend/v2/prepare-upload?pin=123456&token=private-token';
  await service.handle({ ip: '192.168.1.2' }, head);
  const line = store.networkLogs[0].message;
  assert.match(line, /POST \/api\/localsend\/v2\/prepare-upload/);
  assert.ok(!line.includes('123456') && !line.includes('private-token'));
  head.target = '/secret-user-path'; await service.handle({ ip: '192.168.1.2' }, head);
  assert.ok(!store.networkLogs[0].message.includes('secret-user-path'));
  console.log('PASS bounded diagnostic records, single-line device input and omission of query secrets and arbitrary paths');
})().catch(error => { console.error(error); process.exitCode = 1; });
