const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const net = require('node:net');
const https = require('node:https');
const { load } = require('./host-runtime.cjs');
const { AppStore } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
function post(port, route, body) {
  return new Promise((resolve, reject) => {
    const req = https.request({ hostname: '127.0.0.1', port, path: route, method: 'POST', rejectUnauthorized: false,
      headers: { 'content-length': body.length } }, res => {
      const chunks = []; res.on('data', chunk => chunks.push(chunk)); res.on('error', reject);
      res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(chunks).toString() }));
    });
    req.on('error', reject); req.setTimeout(5000, () => req.destroy(new Error('response timeout'))); req.end(body);
  });
}
(async () => {
  const work = path.join(__dirname, '../logs/early-tls-' + Date.now()); await fs.mkdir(work, { recursive: true });
  const probe = net.createServer(); await new Promise(resolve => probe.listen(0, '127.0.0.1', resolve));
  const port = probe.address().port; await new Promise(resolve => probe.close(resolve));
  const store = new AppStore(); await store.init({ filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) });
  store.settings.port = port; store.settings.quickSave = true;
  const service = new LocalSendService(store); await service.start();
  try {
    const body = Buffer.alloc(4 * 1024 * 1024, 17);
    const offered = await post(port, '/api/localsend/v2/prepare-upload', Buffer.from(JSON.stringify({
      info: { alias: 'Early response', version: '2.1', protocol: 'http', port: 1 },
      files: { f1: { id: 'f1', fileName: 'rejected.bin', fileType: 'application/octet-stream', size: body.length } }
    })));
    assert.equal(offered.status, 200); const session = JSON.parse(offered.body);
    for (let index = 0; index < 20; index++) {
      const response = await post(port, `/api/localsend/v2/upload?sessionId=${session.sessionId}&fileId=f1&token=invalid`, body);
      assert.equal(response.status, 403, `attempt ${index}`);
      assert.equal(response.body, '{}');
    }
    assert.equal(store.transfers[0].files[0].transferred, 0);
    service.cancel(session.sessionId);
    console.log('PASS 20 early HTTPS rejections during 4 MiB uploads return complete 403 responses');
  } finally { await service.stop(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
