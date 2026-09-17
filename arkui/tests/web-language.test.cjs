const assert = require('node:assert/strict');
const { load } = require('./host-runtime.cjs');
const { webPage } = load('network/WebPage');
const { flutterLanguages, flutterLabels } = load('model/FlutterLocales');
const { isRtlLanguage } = load('model/Locale');
const { htmlEscape } = load('network/Protocol');
for (const language of flutterLanguages) {
  const html = webPage('My device', [], language.id);
  assert.ok(html.includes(`lang="${language.id === 'zh' ? 'zh-CN' : language.id}"`));
  assert.ok(html.includes(`dir="${isRtlLanguage(language.id) ? 'rtl' : 'ltr'}"`));
  assert.equal((html.match(/<option /g) || []).length, 56);
  assert.ok(html.includes(`value="${language.id}" selected`));
  if (language.id !== 'zh') assert.ok(html.includes(htmlEscape(flutterLabels[language.id]['取消'])));
  const words = JSON.parse(html.match(/const words=(.*);/)[1]);
  if (language.id !== 'zh') assert.equal(words.pin, flutterLabels[language.id]['PIN 不正确']);
}
const original = flutterLabels.de['已复制'];
try {
  const unsafe = '</script><script>alert("translation")</script>';
  flutterLabels.de['已复制'] = unsafe;
  const html = webPage('<script>name</script>', [], 'de');
  assert.equal((html.match(/<\/script>/g) || []).length, 1);
  assert.ok(html.includes('&lt;script&gt;name&lt;/script&gt;'));
  assert.equal(JSON.parse(html.match(/const words=(.*);/)[1]).copied, unsafe);
} finally { flutterLabels.de['已复制'] = original; }
console.log('PASS 56 web locale choices, language tags, RTL, source labels and safe HTML/script embedding');
