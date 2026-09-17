const assert = require('node:assert/strict');
const http = require('node:http');
const https = require('node:https');
const net = require('node:net');
const fs = require('node:fs/promises');
const path = require('node:path');
const { load, handles, mocks } = require('./host-runtime.cjs');
const { AppStore, ShareFile } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const { WebShareService } = load('network/WebShareService');
function get(url) { return new Promise((resolve, reject) => {
  const req = (url.startsWith('https:') ? https : http).get(url, { rejectUnauthorized: false }, res => {
    const chunks = []; res.on('data', b => chunks.push(b)); res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(chunks) }));
  }); req.on('error', reject); req.setTimeout(6000, () => req.destroy(new Error('timeout')));
}); }
(async () => {
  const work = path.join(__dirname, '../logs/web-ipv6-' + Date.now()); await fs.mkdir(work, { recursive: true });
  const reserve = net.createServer(); await new Promise(resolve => reserve.listen(0, '127.0.0.1', resolve));
  const port = reserve.address().port; await new Promise(resolve => reserve.close(resolve));
  const store = new AppStore(); await store.init({ filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) });
  store.settings.port = port - 1; store.localIps = []; store.interfaces = [{ ip: '::1', ignored: false }]; store.settings.webAutoAccept = true;
  const protocol = new LocalSendService(store), web = new WebShareService(store, protocol);
  try {
    for (const encrypted of [false, true]) {
      store.files = []; await web.start(encrypted);
      assert.ok(store.webUrl.includes('[::1]'), store.error);
      const empty = await get(store.webUrl); assert.equal(empty.status, 200); assert.match(empty.body.toString(), /prepare-upload/);
      assert.equal((await get(store.webUrl.replace('[::1]', '127.0.0.1'))).status, 200);
      await web.stop(); await assert.rejects(get(store.webUrl || `${encrypted ? 'https' : 'http'}://[::1]:${port}/`));
      const uri = path.join(work, 'binary'); const bytes = Buffer.from([0, 1, 128, 255]); await fs.writeFile(uri, bytes);
      store.files = [Object.assign(new ShareFile(), { id: 'f', uri, name: 'binary', size: bytes.length })];
      await web.start(encrypted); const download = await get(store.webUrl + 'file/f');
      assert.equal(download.status, 200); assert.deepEqual(download.body, bytes); await web.stop();
    }
    const sockets = mocks['@kit.NetworkKit'].socket, construct = sockets.constructTCPSocketServerInstance;
    try {
      for (const unavailable of [1, 2]) {
        sockets.constructTCPSocketServerInstance = () => {
          const server = construct(), listen = server.listen.bind(server);
          server.listen = async address => { if (address.family === unavailable) throw new Error('family unavailable'); await listen(address); };
          return server;
        };
        store.localIps = ['127.0.0.1']; await web.start(false);
        assert.ok(store.webUrl.includes(unavailable === 1 ? '[::1]' : '127.0.0.1'), store.error);
        assert.equal((await get(store.webUrl)).status, 200); await web.stop();
      }
    } finally { sockets.constructTCPSocketServerInstance = construct; }
  } finally { await web.stop(); await protocol.stop(); }
  assert.equal(handles.size, 0); console.log('PASS IPv6 browser URLs, HTTP/HTTPS empty receive page, concurrent IPv4, binary download and listener cleanup');
})().catch(error => { console.error(error); process.exitCode = 1; });
