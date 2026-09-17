const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const http = require('node:http');
const { load, mocks, handles } = require('./host-runtime.cjs');
const { readWebTemplate, installWebTemplate, renderWebTemplate } = load('network/WebTemplate');
const { AppStore } = load('model/AppStore');
const { LocalSendService } = load('network/LocalSendService');
const { WebShareService } = load('network/WebShareService');
const { uiText } = load('model/Locale');
const get = url => new Promise((resolve, reject) => {
  http.get(url, res => { const chunks = []; res.on('data', b => chunks.push(b)); res.on('end', () => resolve(Buffer.concat(chunks).toString())); }).on('error', reject);
});
(async () => {
  const root = path.join(__dirname, '../logs/web-template-' + Date.now()); await fs.mkdir(root, { recursive: true });
  const source = path.join(root, 'source.html'), destination = path.join(root, 'web-template.html');
  const template = '<!doctype html><title>{{ALIAS}}</title><main>自定义页面</main>{{PAGE}}';
  await fs.writeFile(source, template); await installWebTemplate(source, destination);
  assert.equal(await readWebTemplate(destination), template);
  assert.equal(renderWebTemplate('{{ALIAS}} {{PAGE}}', '{{ALIAS}}', '<&{{PAGE}}>'), '&lt;&amp;{{PAGE}}&gt; {{ALIAS}}', 'inserted content is never re-expanded');
  await fs.writeFile(source, Buffer.alloc(2 * 1024 * 1024 + 1, 65));
  await assert.rejects(installWebTemplate(source, destination), /2 MB/); assert.equal(await fs.readFile(destination, 'utf8'), template);
  await fs.writeFile(source, ''); await assert.rejects(installWebTemplate(source, destination), /有效/);
  const store = new AppStore(); await store.init({ filesDir: root, getApplicationContext: () => ({ setColorMode() {} }) });
  const reserve = http.createServer(); await new Promise(resolve => reserve.listen(0, '127.0.0.1', resolve));
  store.settings.port = reserve.address().port - 1; await new Promise(resolve => reserve.close(resolve)); store.localIps = ['127.0.0.1'];
  const protocol = new LocalSendService(store), web = new WebShareService(store, protocol);
  const picker = mocks['@kit.CoreFileKit'].picker; picker.DocumentSelectOptions = class {}; picker.DocumentSaveOptions = class {}; picker.DocumentSelectMode = { FILE: 0 };
  let selection = []; const exported = path.join(root, 'export.html');
  picker.DocumentViewPicker = class { async select() { return selection; } async save() { return [exported]; } };
  try {
    await web.refreshTemplate(); assert.equal(store.webTemplateConfigured, true);
    await web.configureTemplate('import'); assert.equal(await fs.readFile(destination, 'utf8'), template, 'cancel preserves old template');
    await web.configureTemplate('export'); assert.equal(await fs.readFile(exported, 'utf8'), template);
    await web.start(false); const page = await get(store.webUrl);
    assert.ok(page.includes('自定义页面')); assert.ok(page.includes('prepare-upload'));
    await web.configureTemplate('reset'); assert.equal(await fs.readFile(destination, 'utf8'), template, 'active share cannot change its template');
    await web.stop(); await web.configureTemplate('reset'); assert.equal(store.webTemplateConfigured, false);
    await web.start(false); assert.ok(!(await get(store.webUrl)).includes('自定义页面')); await web.stop();
    await web.configureTemplate('export'); const example = await fs.readFile(exported, 'utf8');
    assert.equal((example.match(/\{\{PAGE\}\}/g) || []).length, 1);
    assert.equal(store.webTemplateBusy, false);
  } finally { await web.stop(); await protocol.stop(); }
  assert.equal(uiText('导入网页', 'zh-TW'), '匯入網頁'); assert.equal(uiText('导入网页', 'en'), 'Import web page');
  assert.equal(handles.size, 0); console.log('PASS template persistence, atomic validation, literal rendering, picker cancel/export/reset and real HTTP integration');
})().catch(error => { console.error(error); process.exitCode = 1; });
