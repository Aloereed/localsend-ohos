const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const ts = require(process.env.TYPESCRIPT_PATH || 'E:/Huawei/DevEco_Studio/tools/hvigor/hvigor/node_modules/typescript');
const file = path.join(__dirname, '../AloeSend/entry/src/main/ets/network/Protocol.ets');
const compiled = ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } });
const moduleState = { exports: {} };
vm.runInNewContext(compiled.outputText, { exports: moduleState.exports, module: moduleState, Uint8Array, Error, Number, Object, String, parseInt, decodeURIComponent });
const p = moduleState.exports;
const bytes = s => new Uint8Array(Buffer.from(s));
let checks = 0;
function test(name, action) { action(); checks++; console.log('PASS', name); }

test('request fields, header casing and query decoding', () => {
  const head = p.parseHttpHead(bytes('POST /api/localsend/v2/upload?sessionId=a%2Bb HTTP/1.1\r\nContent-Length: 12\r\nX-Test: value'));
  assert.equal(head.method, 'POST'); assert.equal(head.contentLength, 12); assert.equal(head.headers['x-test'], 'value');
  assert.equal(p.queryValue(head.target, 'sessionId'), 'a+b');
});
test('reject request smuggling framing', () => {
  for (const headers of ['Content-Length: 2\r\nContent-Length: 2', 'Content-Length: 2\r\nTransfer-Encoding: chunked', 'Content-Length: -1', 'Content-Length: 1e5', 'Content-Length: 9007199254740992', 'Transfer-Encoding: gzip', ' Foo: bar']) {
    assert.throws(() => p.parseHttpHead(bytes('POST / HTTP/1.1\r\n' + headers)));
  }
});
test('fixed body handles every byte split and rejects overflow', () => {
  for (let split = 0; split <= 5; split++) {
    const h = p.parseHttpHead(bytes('POST / HTTP/1.1\r\nContent-Length: 5'));
    const decoder = new p.HttpBodyDecoder(h);
    const output = [...decoder.push(bytes('hello'.slice(0, split))), ...decoder.push(bytes('hello'.slice(split)))];
    assert.equal(Buffer.concat(output).toString(), 'hello'); assert.equal(decoder.done, true); assert.equal(decoder.received, 5);
    assert.throws(() => decoder.push(bytes('extra')));
  }
});
test('chunked response handles every split including extensions and trailers', () => {
  const wire = '5;foo=bar\r\nhello\r\n6\r\n world\r\n0\r\nX-Result: ok\r\n\r\n';
  for (let split = 0; split <= wire.length; split++) {
    const h = p.parseHttpHead(bytes('HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked'));
    const decoder = new p.HttpBodyDecoder(h);
    const output = [...decoder.push(bytes(wire.slice(0, split))), ...decoder.push(bytes(wire.slice(split)))];
    assert.equal(Buffer.concat(output).toString(), 'hello world'); assert.equal(decoder.done, true);
  }
});
test('chunked body streams byte-by-byte', () => {
  const h = p.parseHttpHead(bytes('HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked'));
  const decoder = new p.HttpBodyDecoder(h); const output = [];
  for (const byte of bytes('3\r\nabc\r\n0\r\n\r\n')) output.push(...decoder.push(new Uint8Array([byte])));
  assert.equal(Buffer.concat(output).toString(), 'abc'); assert.equal(decoder.done, true);
});
test('malformed chunk framing fails', () => {
  for (const wire of ['z\r\n', '1\r\naXX', '0\r\n\r\nextra']) {
    const h = p.parseHttpHead(bytes('HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked'));
    assert.throws(() => new p.HttpBodyDecoder(h).push(bytes(wire)));
  }
});
test('path traversal and absolute paths rejected', () => {
  for (const name of ['../secret', 'a/../../secret', '/root', '\\root', 'C:\\secret', 'a//b', 'a/./b', 'a\0b', '']) assert.throws(() => p.safeRelativePath(name));
  assert.equal(p.safeRelativePath('相册/旅行.jpg'), '相册/旅行.jpg');
  assert.equal(p.safeRelativePath('folder\\name?.txt'), 'folder/name_.txt');
});
test('browser content cannot inject HTML', () => assert.equal(p.htmlEscape('<img onerror="x">&'), '&lt;img onerror=&quot;x&quot;&gt;&amp;'));
test('oversized headers rejected', () => assert.throws(() => p.parseHttpHead(new Uint8Array(32769))));
test('duplicate names preserve folders and extensions without overwriting', () => {
  assert.equal(p.uniqueName('folder/a.txt', ['folder/a.txt', 'folder/a (1).txt']), 'folder/a (2).txt');
  assert.equal(p.uniqueName('.hidden', ['.hidden']), '.hidden (1)');
});
console.log(`${checks} protocol test groups passed`);
