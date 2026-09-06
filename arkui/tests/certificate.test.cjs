const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const ts = require(process.env.TYPESCRIPT_PATH || 'E:/Huawei/DevEco_Studio/tools/hvigor/hvigor/node_modules/typescript');
const source = fs.readFileSync(path.join(__dirname, '../AloeSend/entry/src/main/ets/network/CertificateDer.ets'), 'utf8');
const exportsObject = {};
vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } }).outputText, { exports: exportsObject, Uint8Array, Date });
const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
for (const now of [Date.now(), Date.UTC(2045, 0, 1)]) {
  const tbs = exportsObject.makeTbsCertificate(new Uint8Array(publicKey.export({ format: 'der', type: 'spki' })), new Uint8Array(crypto.randomBytes(16)), now);
  const signature = crypto.sign('sha256', tbs, privateKey);
  const raw = exportsObject.assembleCertificate(tbs, new Uint8Array(signature));
  const cert = new crypto.X509Certificate(raw);
  assert.equal(cert.subject, 'CN=LocalSend ArkUI');
  assert.equal(cert.verify(publicKey), true);
  assert.equal(cert.ca, false);
  assert.ok(Date.parse(cert.validFrom) < now);
  assert.ok(Date.parse(cert.validTo) > now);
  assert.ok(cert.keyUsage.includes('1.3.6.1.5.5.7.3.1'));
  console.log('PASS generated DER certificate: RSA signature, identity, validity and TLS EKU', cert.fingerprint256);
}
