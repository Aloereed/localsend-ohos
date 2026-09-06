import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { AppStore } from '../model/AppStore';
import { makeTbsCertificate, assembleCertificate } from './CertificateDer';

class IdentityMaterial {
  certificate: string = '';
  privateKey: string = '';
}

export class TlsIdentity {
  certificate: string = '';
  privateKey: string = '';
  fingerprint: string = '';

  async load(store: AppStore): Promise<void> {
    if (!store.context) throw new Error('Application context unavailable');
    const root = store.context.filesDir;
    if (await fs.access(`${root}/identity.json`)) {
      const material = JSON.parse(await fs.readText(`${root}/identity.json`)) as IdentityMaterial;
      if (!material.certificate?.startsWith('-----BEGIN CERTIFICATE-----') || !material.privateKey?.startsWith('-----BEGIN PRIVATE KEY-----')) throw new Error('TLS 身份文件损坏');
      this.certificate = material.certificate; this.privateKey = material.privateKey;
    } else {
    try {
      this.certificate = await fs.readText(`${root}/identity-cert.pem`);
      this.privateKey = await fs.readText(`${root}/identity-key.pem`);
    } catch (_) {
      store.log('生成本机独立 TLS 身份');
      const material = await generateIdentity();
      this.certificate = material.certificate; this.privateKey = material.privateKey;
      await writePrivate(`${root}/identity-key.pem`, this.privateKey);
      await writePrivate(`${root}/identity-cert.pem`, this.certificate);
    }
    }
    const raw = new util.Base64Helper().decodeSync(this.certificate.replace(/-----[^-]+-----/g, '').replace(/\s/g, ''));
    this.fingerprint = await sha256(raw);
    store.settings.fingerprint = this.fingerprint;
    await store.save();
  }

  async reset(store: AppStore): Promise<void> {
    if (!store.context) throw new Error('Application context unavailable');
    const material = await generateIdentity();
    const temporary = `${store.context.filesDir}/identity-${util.generateRandomUUID()}.tmp`;
    try {
      // One atomic bundle avoids pairing a new certificate with the old key.
      await writePrivate(temporary, JSON.stringify(material));
      await fs.rename(temporary, `${store.context.filesDir}/identity.json`);
    } catch (error) { await fs.unlink(temporary).catch(() => {}); throw error as Error; }
    await this.load(store);
  }
}

async function generateIdentity(): Promise<IdentityMaterial> {
  const pair = await cryptoFramework.createAsyKeyGenerator('RSA2048').generateKeyPair();
  const random = await cryptoFramework.createRandom().generateRandom(16);
  const tbs = makeTbsCertificate(pair.pubKey.getEncoded().data, random.data, Date.now());
  const signer = cryptoFramework.createSign('RSA2048|PKCS1|SHA256');
  await signer.init(pair.priKey);
  const signature = await signer.sign({ data: tbs });
  const material = new IdentityMaterial();
  material.certificate = pem('CERTIFICATE', assembleCertificate(tbs, signature.data));
  material.privateKey = pem('PRIVATE KEY', pair.priKey.getEncoded().data);
  return material;
}

export async function sha256(bytes: Uint8Array): Promise<string> {
  const digest = cryptoFramework.createMd('SHA256');
  await digest.update({ data: bytes });
  return (await digest.digest()).data.reduce((value: string, byte: number) => value + byte.toString(16).padStart(2, '0'), '');
}

function pem(label: string, data: Uint8Array): string {
  const base64 = new util.Base64Helper().encodeToStringSync(data);
  const lines: string[] = [];
  for (let i = 0; i < base64.length; i += 64) lines.push(base64.slice(i, i + 64));
  return `-----BEGIN ${label}-----\n${lines.join('\n')}\n-----END ${label}-----\n`;
}

async function writePrivate(path: string, content: string): Promise<void> {
  const file = await fs.open(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
  try {
    const bytes = new util.TextEncoder().encodeInto(content); let offset = 0;
    while (offset < bytes.length) {
      const written = await fs.write(file.fd, bytes.slice(offset).buffer as ArrayBuffer);
      if (written <= 0) throw new Error('TLS 身份写入失败');
      offset += written;
    }
  }
  finally { await fs.close(file); }
}
