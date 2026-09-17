import { fileIo as fs } from '@kit.CoreFileKit';
import { encodeText, decodeText } from './Transport';
import { htmlEscape } from './Protocol';

const LIMIT: number = 2 * 1024 * 1024;
export const exampleWebTemplate: string = '<!-- AloeSend: the PAGE directive below inserts the current built-in page. Add your CSS below, or replace this with your own HTML. -->\n{{PAGE}}\n<style>/* Example: body { max-width: 900px; } */</style>\n';

export async function readWebTemplate(path: string): Promise<string> {
  const file = await fs.open(path, fs.OpenMode.READ_ONLY);
  try {
    const buffer = new ArrayBuffer(LIMIT + 1); let count = 0;
    while (count < buffer.byteLength) {
      const part = new ArrayBuffer(Math.min(65536, buffer.byteLength - count));
      const read = await fs.read(file.fd, part);
      if (!read) break;
      new Uint8Array(buffer).set(new Uint8Array(part, 0, read), count); count += read;
    }
    if (count > LIMIT) throw new Error('网页模板不能超过 2 MB');
    const text = decodeText(new Uint8Array(buffer, 0, count));
    if (!text.trim() || text.includes('\u0000')) throw new Error('请选择有效的 HTML 网页模板');
    return text;
  } finally { await fs.close(file); }
}

export async function writeWebTemplate(path: string, text: string): Promise<void> {
  const bytes = encodeText(text);
  const file = await fs.open(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
  try {
    let offset = 0;
    while (offset < bytes.byteLength) {
      const written = await fs.write(file.fd, bytes.slice(offset).buffer);
      if (written <= 0) throw new Error('网页模板写入失败');
      offset += written;
    }
  } finally { await fs.close(file); }
}

export async function installWebTemplate(source: string, destination: string): Promise<void> {
  const text = await readWebTemplate(source);
  const temporary = destination + '.tmp';
  try { await writeWebTemplate(temporary, text); await fs.rename(temporary, destination); }
  finally { if (await fs.access(temporary)) await fs.unlink(temporary); }
}

export function renderWebTemplate(template: string, page: string, alias: string): string {
  if (!template) return page;
  // A single pass prevents names and inserted page content from becoming directives.
  return template.replace(/\{\{(PAGE|ALIAS)\}\}/g, (_match: string, name: string) => name === 'PAGE' ? page : htmlEscape(alias));
}
