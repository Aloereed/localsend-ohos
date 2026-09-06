const assert = require('node:assert/strict');
const http = require('node:http');
const net = require('node:net');
const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const vm = require('node:vm');
const { load, handles } = require('./host-runtime.cjs');
const { AppStore, ShareFile } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const { WebShareService } = load('network/WebShareService');
const work = path.join(__dirname, '../logs/web-fixture-' + Date.now());
let checks = 0;
async function check(name, action) { await action(); checks++; console.log('PASS', name); }
function call(url, method = 'GET', data = '', origin = '') {
  const bytes = Buffer.isBuffer(data) ? data : Buffer.from(data);
  return new Promise((resolve, reject) => {
    const headers = { 'content-length': bytes.length }; if (origin) headers.origin = origin;
    const req = http.request(url, { method, headers }, res => {
      const chunks = []; res.on('data', b => chunks.push(b)); res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(chunks), headers: res.headers }));
    }); req.on('error', reject); req.setTimeout(8000, () => req.destroy(new Error('request timeout'))); req.end(bytes);
  });
}
async function until(predicate) { const start = Date.now(); while (!(await predicate())) { if (Date.now() - start > 3000) throw new Error('condition timeout'); await new Promise(r => setTimeout(r, 10)); } }
(async () => {
  await fs.mkdir(work, { recursive: true });
  const reservation = net.createServer(); await new Promise(r => reservation.listen(0, '127.0.0.1', r));
  const port = reservation.address().port; await new Promise(r => reservation.close(r));
  const store = new AppStore(); await store.init({ filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) });
  store.settings.port = port - 1; store.localIps = ['127.0.0.1']; store.settings.alias = '<script>alert(1)</script>';
  const data = crypto.randomBytes(100000); const source = path.join(work, 'source.bin'); await fs.writeFile(source, data);
  const file = new ShareFile(); file.uri = source; file.size = data.length; file.name = 'hello <world>.bin'; store.files = [file];
  const protocol = new LocalSendService(store); const web = new WebShareService(store, protocol);
  try {
    await web.start(false); assert.ok(store.webUrl);
    const base = store.webUrl; const origin = new URL(base).origin;
    await check('real browser page contains files and escapes peer-supplied HTML', async () => {
      const page = await call(base); assert.equal(page.status, 200); const html = page.body.toString();
      assert.ok(html.includes('&lt;script&gt;')); assert.ok(!html.includes('<script>alert(1)</script>'));
      assert.ok(html.includes('hello &lt;world&gt;.bin')); assert.ok(html.includes('ondrop'));
      assert.match(page.headers['content-type'], /^text\/html/);
      new vm.Script(html.match(/<script>([\s\S]*?)<\/script>/)[1]);
      const english = (await call(base + '?lang=en')).body.toString();
      assert.ok(english.includes('Shared with you')); assert.ok(english.includes('lang="en"'));
      new vm.Script(english.match(/<script>([\s\S]*?)<\/script>/)[1]);
    });
    await check('invalid capability and cross-origin POST are rejected', async () => {
      assert.equal((await call(origin + '/s/wrong/')).status, 404);
      assert.equal((await call(base + 'api/localsend/v2/prepare-upload', 'POST', '{}', 'https://evil.invalid')).status, 403);
    });
    await check('download waits for native permission and streams original bytes', async () => {
      const downloading = call(base + 'file/' + file.id);
      await until(() => store.webRequests.length === 1); web.respond(store.webRequests[0].id, true);
      const result = await downloading; assert.equal(result.status, 200); assert.deepEqual(result.body, data);
      assert.match(result.headers['content-disposition'], /attachment/);
      await until(() => store.transfers[0].status === 'complete');
    });
    await check('closed browser tab dismisses a pending download request', async () => {
      const req = http.get(base + 'file/' + file.id); req.on('error', () => {});
      await until(() => store.webRequests.length === 1); req.destroy();
      await until(() => store.webRequests.length === 0);
    });
    await check('native decline prevents browser download', async () => {
      const downloading = call(base + 'file/' + file.id);
      await until(() => store.webRequests.length === 1); web.respond(store.webRequests[0].id, false);
      assert.equal((await downloading).status, 403);
    });
    await check('browser upload reuses receive consent, PIN and binary validation', async () => {
      store.settings.quickSave = true; store.settings.pin = '7788';
      const info = { alias: 'Browser test', fingerprint: 'browser', protocol: 'http', port: 53317 };
      const offer = JSON.stringify({ info, files: { x: { id: 'x', fileName: 'from-browser.bin', size: data.length, fileType: 'application/octet-stream' } } });
      assert.equal((await call(base + 'api/localsend/v2/prepare-upload', 'POST', offer, origin)).status, 401);
      const prepared = await call(base + 'api/localsend/v2/prepare-upload?pin=7788', 'POST', offer, origin);
      assert.equal(prepared.status, 200); const session = JSON.parse(prepared.body);
      const result = await call(base + `api/localsend/v2/upload?sessionId=${session.sessionId}&fileId=x&token=${session.files.x}`, 'POST', data, origin);
      assert.equal(result.status, 200); assert.deepEqual(await fs.readFile(store.history[0].path), data);
    });
    await check('stopping share invalidates pending permissions and closes server', async () => {
      const downloading = call(base + 'file/' + file.id).catch(() => ({ status: 0 }));
      await until(() => store.webRequests.length === 1); await web.stop(); await downloading;
      assert.equal(store.webUrl, ''); assert.equal(store.webRequests.length, 0);
      await assert.rejects(call(base));
    });
  } finally { await web.stop(); await protocol.stop(); }
  await until(() => handles.size === 0);
  console.log(`${checks} browser sharing groups passed; zero open file handles`);
})().catch(e => { console.error(e); process.exitCode = 1; });
