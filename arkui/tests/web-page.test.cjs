const assert = require('node:assert/strict');
const vm = require('node:vm');
const { File } = require('node:buffer');
const { load } = require('./host-runtime.cjs');
const { webPage } = load('network/WebPage');
class Element {
  constructor() { this.children = []; this.value = ''; this.textContent = ''; this.classList = { add() {}, remove() {} }; }
  append(...items) { this.children.push(...items); }
  replaceChildren() { this.children = []; }
  setAttribute() {}
  querySelectorAll() { return this.children.flatMap(item => item.children).filter(item => item.className === 'remove'); }
  click() {}
}
const elements = new Map();
const el = id => { if (!elements.has(id)) elements.set(id, new Element()); return elements.get(id); };
let failUpload = false; let textOnly = false; let observedProgress = 0; const requests = [];
class XHR {
  constructor() { this.upload = {}; this.status = 200; }
  open(method, url) { this.url = url; }
  send(file) {
    assert.equal(el('pick').disabled, true); assert.equal(el('text').readOnly, true);
    assert.equal(el('language').disabled, true, 'language navigation must not interrupt an active upload');
    assert.equal(el('applyLanguage').disabled, true);
    queueMicrotask(() => {
      this.upload.onprogress({ loaded: file.size / 2 }); observedProgress = el('progress').value;
      this.status = failUpload ? 500 : 200; this.onload();
    });
  }
  abort() { this.onabort(); }
}
const context = vm.createContext({
  document: { getElementById: el, createElement: () => new Element(), querySelectorAll: () => [] },
  navigator: { platform: 'host' }, window: {}, XMLHttpRequest: XHR, AbortController, DOMException, File,
  setTimeout, clearTimeout, console,
  fetch: async (url, options) => {
    requests.push([url, options]);
    if (url.includes('/cancel')) return { ok: true };
    return { status: textOnly ? 204 : 200, ok: true, json: async () => ({ sessionId: 'test', files: { f0: 'token' } }) };
  }
});
const html = webPage('Device', [], 'en');
const pinInput = html.match(/<input id="pin"[^>]*>/)[0];
assert.ok(!/inputmode="numeric"|maxlength=/.test(pinInput), 'browser PIN must allow the same text as the native settings');
vm.runInContext(html.match(/<script>([\s\S]*?)<\/script>/)[1], context);
(async () => {
  const fileEntry = (name, bytes) => ({ name, isFile: true, file: resolve => resolve(new File([bytes], name)) });
  const folderEntry = (name, batches) => ({ name, isDirectory: true, createReader() { let index = 0; return { readEntries: resolve => resolve(batches[index++] || []) }; } });
  const mixed = [fileEntry('loose.txt', 'loose'), folderEntry('相册', [[fileEntry('a.txt', 'a')], [folderEntry('nested', [[fileEntry('b.bin', new Uint8Array([0, 255]))]])]])];
  const collected = await context.collectDropped(mixed, [], new AbortController().signal);
  assert.deepEqual(Array.from(collected, file => file.name), ['loose.txt', '相册/a.txt', '相册/nested/b.bin']);
  assert.deepEqual(Buffer.from(await collected[2].arrayBuffer()), Buffer.from([0, 255]));
  const cancelScan = new AbortController(); cancelScan.abort();
  await assert.rejects(context.collectDropped(mixed, [], cancelScan.signal), /Cancelled/);
  const original = new File(['keep'], 'keep.txt'); context.selected([original]);
  const broken = { name: 'broken', isDirectory: true, createReader: () => ({ readEntries: (_, reject) => reject(new Error('unreadable')) }) };
  await el('drop').ondrop({ preventDefault() {}, dataTransfer: { items: [mixed[0], broken].map(entry => ({ kind: 'file', webkitGetAsEntry: () => entry, getAsFile: () => null })) } });
  assert.equal(el('selection').children[0].children[0].textContent, 'keep.txt · 1 KB', 'failed traversal preserves prior selection atomically');
  assert.equal(el('pick').disabled, false);
  const first = new File(['abcdefghij'], 'first.txt'); const skipped = new File(['second'], 'second.txt');
  el('pin').value = 'Long-PIN + 中文 123456';
  context.selected([first, skipped]); await context.send([first, skipped], '');
  assert.equal(new URL(requests[0][0], 'http://localhost').searchParams.get('pin'), el('pin').value);
  assert.equal(observedProgress, 50, 'progress denominator must use accepted files only');
  assert.equal(el('progress').value, 100);
  assert.equal(el('selected').textContent, 'Selected 1 items', 'skipped file remains in selection');
  assert.equal(el('pick').disabled, false);
  assert.equal(el('language').disabled, false); assert.equal(el('applyLanguage').disabled, false);
  failUpload = true; await context.send([skipped], '');
  assert.equal(el('selected').textContent, 'Selected 1 items');
  assert.match(el('status').textContent, /Request failed 500/);
  assert.ok(requests.some(([url]) => url.includes('/cancel')));
  failUpload = false; textOnly = true; el('text').value = 'Hello';
  await context.send([new File(['Hello'], 'message.txt')], 'Hello');
  assert.equal(el('text').value, ''); assert.equal(el('status').textContent, 'Message delivered');
  assert.equal(el('cancel').hidden, true);
  console.log('PASS generated browser script locks input, reports byte progress, preserves skipped/failed files, cancels failed sessions and clears delivered text');
})().catch(error => { console.error(error); process.exitCode = 1; });
