import { fileIo as fs } from '@kit.CoreFileKit';
import { ShareFile } from '../model/AppStore';
import { encodeText } from './Transport';

// Stored ZIP64 with streaming CRC/data descriptors (PKWARE APPNOTE 4.3).
class ZipEntry {
  file: ShareFile;
  name: Uint8Array;
  offset: number;
  crc: number = 0;
  constructor(file: ShareFile, name: string, offset: number) {
    this.file = file; this.name = encodeText(name); this.offset = offset;
  }
}
function put64(view: DataView, offset: number, value: number): void {
  view.setUint32(offset, value >>> 0, true);
  view.setUint32(offset + 4, Math.floor(value / 4294967296), true);
}
const crcTable: number[] = [];
for (let i = 0; i < 256; i++) {
  let value = i;
  for (let bit = 0; bit < 8; bit++) value = (value >>> 1) ^ ((value & 1) ? 0xEDB88320 : 0);
  crcTable.push(value >>> 0);
}
export class ZipDownload {
  size: number = 0;
  private entries: ZipEntry[] = [];
  private directoryOffset: number = 0;
  private directorySize: number = 0;
  constructor(files: ShareFile[]) {
    const used = new Set<string>();
    for (const file of files) {
      if (!Number.isSafeInteger(file.size) || file.size < 0) throw new Error('Invalid file size');
      const base = (file.name.split(/[\\/]/).pop() || 'file').replace(/[\x00-\x1f<>:"|?*]/g, '_').replace(/[. ]+$/g, '') || 'file';
      const safe = /^(con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\.|$)/i.test(base) ? '_' + base : base;
      let name = safe; let suffix = 1;
      const dot = safe.lastIndexOf('.');
      while (used.has(name.toLowerCase())) {
        name = dot > 0 ? `${safe.slice(0, dot)} (${suffix++})${safe.slice(dot)}` : `${safe} (${suffix++})`;
      }
      used.add(name.toLowerCase());
      const entry = new ZipEntry(file, name, this.size);
      if (entry.name.length > 65535) throw new Error('File name too long');
      this.entries.push(entry);
      this.size += 30 + entry.name.length + 20 + file.size + 24;
      this.directorySize += 46 + entry.name.length + 28;
    }
    this.directoryOffset = this.size;
    this.size += this.directorySize + 56 + 20 + 22;
    if (!Number.isSafeInteger(this.size)) throw new Error('Archive too large');
  }
  async send(write: (bytes: Uint8Array) => Promise<void>): Promise<void> {
    for (const entry of this.entries) {
      const header = new Uint8Array(30 + entry.name.length + 20); const view = new DataView(header.buffer);
      view.setUint32(0, 0x04034b50, true); view.setUint16(4, 45, true); view.setUint16(6, 0x808, true);
      view.setUint16(12, 33, true); // 1980-01-01
      view.setUint32(18, 0xFFFFFFFF, true); view.setUint32(22, 0xFFFFFFFF, true);
      view.setUint16(26, entry.name.length, true); view.setUint16(28, 20, true); header.set(entry.name, 30);
      const extra = 30 + entry.name.length;
      view.setUint16(extra, 1, true); view.setUint16(extra + 2, 16, true);
      put64(view, extra + 4, entry.file.size); put64(view, extra + 12, entry.file.size);
      await write(header);
      let crc = 0xFFFFFFFF;
      const source = await fs.open(entry.file.uri, fs.OpenMode.READ_ONLY);
      try {
        let remaining = entry.file.size;
        while (remaining > 0) {
          const buffer = new ArrayBuffer(Math.min(65536, remaining));
          const read = await fs.read(source.fd, buffer);
          if (read <= 0) throw new Error('读取源文件失败');
          const bytes = new Uint8Array(buffer).slice(0, read);
          for (let i = 0; i < read; i++) crc = (crc >>> 8) ^ crcTable[(crc ^ bytes[i]) & 255];
          await write(bytes); remaining -= read;
        }
      } finally { await fs.close(source); }
      entry.crc = (crc ^ 0xFFFFFFFF) >>> 0;
      const descriptor = new Uint8Array(24); const data = new DataView(descriptor.buffer);
      data.setUint32(0, 0x08074b50, true); data.setUint32(4, entry.crc, true);
      put64(data, 8, entry.file.size); put64(data, 16, entry.file.size); await write(descriptor);
    }
    for (const entry of this.entries) {
      const header = new Uint8Array(46 + entry.name.length + 28); const view = new DataView(header.buffer);
      view.setUint32(0, 0x02014b50, true); view.setUint16(4, 45, true); view.setUint16(6, 45, true);
      view.setUint16(8, 0x808, true); view.setUint16(14, 33, true); view.setUint32(16, entry.crc, true);
      view.setUint32(20, 0xFFFFFFFF, true); view.setUint32(24, 0xFFFFFFFF, true);
      view.setUint16(28, entry.name.length, true); view.setUint16(30, 28, true); view.setUint32(42, 0xFFFFFFFF, true);
      header.set(entry.name, 46); const extra = 46 + entry.name.length;
      view.setUint16(extra, 1, true); view.setUint16(extra + 2, 24, true);
      put64(view, extra + 4, entry.file.size); put64(view, extra + 12, entry.file.size); put64(view, extra + 20, entry.offset);
      await write(header);
    }
    const end = new Uint8Array(98); const view = new DataView(end.buffer);
    view.setUint32(0, 0x06064b50, true); put64(view, 4, 44); view.setUint16(12, 45, true); view.setUint16(14, 45, true);
    put64(view, 24, this.entries.length); put64(view, 32, this.entries.length);
    put64(view, 40, this.directorySize); put64(view, 48, this.directoryOffset);
    view.setUint32(56, 0x07064b50, true); put64(view, 64, this.directoryOffset + this.directorySize); view.setUint32(72, 1, true);
    view.setUint32(76, 0x06054b50, true); view.setUint16(84, 65535, true); view.setUint16(86, 65535, true);
    view.setUint32(88, 0xFFFFFFFF, true); view.setUint32(92, 0xFFFFFFFF, true); await write(end);
  }
}
