import { fileIo as fs } from '@kit.CoreFileKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { Cancellation, encodeText } from './Transport';

export async function fileChecksum(uri: string, size: number, text: string, cancellation: Cancellation,
  progress: (bytes: number) => void = () => {}): Promise<string> {
  cancellation.check();
  const hash = cryptoFramework.createMd('SHA256');
  if (text) {
    const bytes = encodeText(text);
    if (bytes.byteLength !== size) throw new Error('源文件大小已改变，请重新选择');
    await hash.update({ data: bytes }); progress(size);
  } else {
    const source = await fs.open(uri, fs.OpenMode.READ_ONLY);
    try {
      let count = 0;
      while (count < size) {
        cancellation.check();
        const buffer = new ArrayBuffer(Math.min(65536, size - count));
        const read = await fs.read(source.fd, buffer);
        if (read <= 0) throw new Error('源文件读取不完整');
        await hash.update({ data: new Uint8Array(buffer).slice(0, read) });
        count += read; progress(count);
      }
      if (await fs.read(source.fd, new ArrayBuffer(1)) !== 0) throw new Error('源文件大小已改变，请重新选择');
    } finally { await fs.close(source); }
  }
  cancellation.check();
  const digest = await hash.digest();
  return digest.data.reduce((value: string, byte: number) => value + byte.toString(16).padStart(2, '0'), '');
}
