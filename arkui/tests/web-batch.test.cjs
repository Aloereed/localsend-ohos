const assert = require('node:assert/strict');
const http = require('node:http'), https = require('node:https'), net = require('node:net');
const fs = require('node:fs/promises'), path = require('node:path'), crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const { load, handles, mocks } = require('./host-runtime.cjs');
const { AppStore, ShareFile } = load('model/AppStore');
const { WebShareService } = load('network/WebShareService');
const { LocalSendService } = load('network/LocalSendService');
const { ZipDownload } = load('network/ZipDownload');
function get(url) { return new Promise((resolve, reject) => {
  const req = (url.startsWith('https:') ? https : http).get(url, { rejectUnauthorized: false }, res => {
    const chunks = []; res.on('data', b => chunks.push(b)); res.on('aborted', () => reject(new Error('aborted')));
    res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: Buffer.concat(chunks) }));
  }); req.on('error', reject); req.setTimeout(8000, () => req.destroy(new Error('timeout')));
}); }
async function until(predicate) { const start = Date.now(); while (!predicate()) {
  if (Date.now() - start > 5000) throw new Error('condition timeout'); await new Promise(r => setTimeout(r, 10));
} }
(async () => {
  const work = path.join(__dirname, '../logs/web-batch-' + Date.now()); await fs.mkdir(work, { recursive: true });
  const reserve = net.createServer(); await new Promise(r => reserve.listen(0, '127.0.0.1', r));
  const port = reserve.address().port; await new Promise(r => reserve.close(r));
  const store = new AppStore(); await store.init({ filesDir: work, getApplicationContext: () => ({ setColorMode() {} }) });
  store.settings.port = port - 1; store.localIps = ['127.0.0.1'];
  const names = ['../照片.bin', '照片.bin', 'empty.txt', 'CON.txt'];
  const payloads = [crypto.randomBytes(180003), Buffer.from('第二份\0内容'), Buffer.alloc(0), Buffer.from('reserved')];
  const files = [];
  for (let i = 0; i < names.length; i++) {
    const uri = path.join(work, 'source' + i); await fs.writeFile(uri, payloads[i]);
    files.push(Object.assign(new ShareFile(), { id: 'f' + i, uri, name: names[i], size: payloads[i].length }));
  }
  store.files = [...files, Object.assign(new ShareFile(), { id: 'text', text: 'message', name: 'message.txt', size: 7 })];
  const protocol = new LocalSendService(store), web = new WebShareService(store, protocol);
  const expected = ['照片.bin', '照片 (1).bin', 'empty.txt', '_CON.txt'].map((name, i) => ({ name, hash: crypto.createHash('sha256').update(payloads[i]).digest('hex') }));
  const expectedPath = path.join(work, 'expected.json'); await fs.writeFile(expectedPath, JSON.stringify(expected));
  function verifyZip(file) {
    const result = spawnSync(process.env.PYTHON || 'python', ['-c',
      "import sys,json,zipfile,hashlib; z=zipfile.ZipFile(sys.argv[1]); expected=json.load(open(sys.argv[2],encoding='utf-8')); assert z.testzip() is None; assert z.namelist()==[e['name'] for e in expected]; assert all(hashlib.sha256(z.read(e['name'])).hexdigest()==e['hash'] for e in expected)", file, expectedPath], { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr || String(result.error));
  }
  try {
    for (const encrypted of [false, true]) {
      store.settings.webAutoAccept = false; await web.start(encrypted); assert.ok(store.webUrl, store.error);
      const base = store.webUrl;
      for (const [lang, label] of [['zh', '全部下载（ZIP）'], ['zh-TW', '全部下載（ZIP）'], ['en', 'Download all (ZIP)']]) {
        const page = (await get(base + '?lang=' + lang)).body.toString(); assert.ok(page.includes(label)); assert.ok(page.includes('href="archive.zip" download'));
      }
      const denied = get(base + 'archive.zip'); await until(() => store.webRequests.length === 1);
      assert.equal(store.webRequests[0].fileName, 'AloeSend-4.zip'); web.respond(store.webRequests[0].id, false);
      assert.equal((await denied).status, 403); assert.equal(handles.size, 0);
      const pending = get(base + 'archive.zip'); await until(() => store.webRequests.length === 1);
      web.respond(store.webRequests[0].id, true); const result = await pending;
      assert.equal(result.status, 200); assert.equal(result.headers['content-type'], 'application/zip');
      assert.equal(Number(result.headers['content-length']), result.body.length);
      const archivePath = path.join(work, encrypted ? 'https.zip' : 'http.zip'); await fs.writeFile(archivePath, result.body); verifyZip(archivePath);
      await until(() => store.transfers[0].status === 'complete');
      assert.equal(store.transfers[0].files[0].transferred, result.body.length);
      store.settings.webAutoAccept = true; assert.equal((await get(base + 'archive.zip')).status, 200);
      assert.equal(store.webRequests.length, 0);
      const io = mocks['@kit.CoreFileKit'].fileIo, originalRead = io.read;
      let release; let entered = false;
      const gate = new Promise(resolve => { release = resolve; });
      const active = (() => {
        io.read = async (...args) => { entered = true; await gate; return originalRead(...args); };
        return get(base + 'archive.zip').catch(() => ({ status: 0 }));
      })();
      try {
        await until(() => entered); const transfer = store.transfers.find(item => item.status === 'transferring');
        assert.ok(transfer); assert.equal(web.cancel(transfer.id), true); release();
        assert.notEqual((await active).status, 200); await until(() => store.transfers.find(item => item.id === transfer.id)?.status === 'cancelled');
        await until(() => handles.size === 0);
      } finally { release(); io.read = originalRead; await active; }
      assert.equal((await get(new URL('/s/wrong/archive.zip', base).href)).status, 404);
      store.settings.webAutoAccept = false;
      const stopping = get(base + 'archive.zip').catch(() => ({ status: 0 })); await until(() => store.webRequests.length === 1);
      await web.stop(); assert.notEqual((await stopping).status, 200); assert.equal(store.webRequests.length, 0);
      await web.start(encrypted); assert.equal((await get(base + 'archive.zip')).status, 404); await web.stop();
    }
    store.files = []; await web.start(false);
    assert.equal((await get(store.webUrl + 'archive.zip')).status, 404);
    assert.ok(!(await get(store.webUrl)).body.toString().includes('href="archive.zip"')); await web.stop();
    const io = mocks['@kit.CoreFileKit'].fileIo, read = io.read;
    try {
      io.read = async (fd, buffer) => { const tiny = new ArrayBuffer(Math.min(997, buffer.byteLength)); const n = await read(fd, tiny); new Uint8Array(buffer).set(new Uint8Array(tiny, 0, n)); return n; };
      const archive = new ZipDownload(files); const chunks = [];
      await archive.send(async bytes => { assert.equal(bytes.byteLength, bytes.buffer.byteLength); assert.ok(bytes.length <= 65536); chunks.push(Buffer.from(bytes)); });
      const result = Buffer.concat(chunks); assert.equal(result.length, archive.size);
      const file = path.join(work, 'short-reads.zip'); await fs.writeFile(file, result); verifyZip(file);
    } finally { io.read = read; }
    let writes = 0;
    await assert.rejects(new ZipDownload(files).send(async () => { if (++writes === 2) throw new Error('cancel'); }), /cancel/);
    assert.equal(handles.size, 0);
    await assert.rejects(new ZipDownload([Object.assign(new ShareFile(), { uri: path.join(work, 'missing'), size: 1, name: 'missing' })]).send(async () => {}));
    await assert.rejects(new ZipDownload([Object.assign(new ShareFile(), { uri: files[2].uri, size: 1, name: 'truncated' })]).send(async () => {}), /读取源文件失败/);
    const large = new ZipDownload([Object.assign(new ShareFile(), { size: 4294967301, name: 'large' })]);
    assert.ok(large.size > 4294967301);
    await assert.rejects(large.send(async bytes => { const extra = 30 + Buffer.from(bytes).readUInt16LE(26); assert.equal(Buffer.from(bytes).readBigUInt64LE(extra + 4), 4294967301n); throw new Error('header checked'); }), /header checked/);
  } finally { await web.stop(); await protocol.stop(); }
  await until(() => handles.size === 0);
  console.log('PASS HTTP/HTTPS ZIP batches, native consent, auto accept, expiry, empty lists, independent unzip/CRC/content, safe duplicate names, bounded short reads, cancellation and ZIP64 size');
})().catch(error => { console.error(error); process.exitCode = 1; });
