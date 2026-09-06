// Platform-independent HTTP framing and protocol validation. Host-side tests run
// this exact source after TypeScript transpilation; no mock protocol implementation.
export class HttpHead {
  method: string = '';
  target: string = '';
  status: number = 0;
  headers: Record<string, string> = {};
  contentLength: number = 0;
  chunked: boolean = false;
}

export function concatBytes(a: Uint8Array, b: Uint8Array): Uint8Array {
  const result = new Uint8Array(a.length + b.length);
  result.set(a); result.set(b, a.length); return result;
}

export function ascii(bytes: Uint8Array): string {
  let result = '';
  for (let i = 0; i < bytes.length; i++) result += String.fromCharCode(bytes[i]);
  return result;
}

export function headerEnd(bytes: Uint8Array): number {
  for (let i = 0; i + 3 < bytes.length; i++) {
    if (bytes[i] === 13 && bytes[i + 1] === 10 && bytes[i + 2] === 13 && bytes[i + 3] === 10) return i;
  }
  return -1;
}

export function parseHttpHead(bytes: Uint8Array): HttpHead {
  if (bytes.length > 32768) throw new Error('HTTP header exceeds 32 KiB');
  const lines = ascii(bytes).split('\r\n');
  const first = lines.shift() || '';
  const result = new HttpHead();
  if (first.startsWith('HTTP/1.')) {
    const parts = first.split(' ');
    if (parts.length < 2 || !/^\d{3}$/.test(parts[1])) throw new Error('Invalid HTTP status');
    result.status = Number(parts[1]);
  } else {
    const parts = first.split(' ');
    if (parts.length !== 3 || !/^HTTP\/1\.[01]$/.test(parts[2]) || !/^[A-Z]+$/.test(parts[0]) || !parts[1].startsWith('/')) throw new Error('Invalid HTTP request');
    result.method = parts[0]; result.target = parts[1];
  }
  for (const line of lines) {
    const colon = line.indexOf(':');
    if (colon < 1 || /^[ \t]/.test(line)) throw new Error('Invalid HTTP header');
    const key = line.slice(0, colon).toLowerCase();
    if (!/^[a-z0-9!#$%&'*+.^_`|~-]+$/.test(key)) throw new Error('Invalid HTTP header name');
    const value = line.slice(colon + 1).trim();
    if (Object.keys(result.headers).includes(key) && (key === 'content-length' || key === 'transfer-encoding')) throw new Error('Ambiguous HTTP framing');
    result.headers[key] = value;
  }
  const length = result.headers['content-length'];
  const transfer = result.headers['transfer-encoding'];
  if (length !== undefined && transfer !== undefined) throw new Error('Ambiguous HTTP framing');
  if (length !== undefined) {
    if (!/^\d+$/.test(length) || !Number.isSafeInteger(Number(length))) throw new Error('Invalid Content-Length');
    result.contentLength = Number(length);
  }
  if (transfer !== undefined) {
    if (transfer.toLowerCase() !== 'chunked') throw new Error('Unsupported transfer encoding');
    result.chunked = true;
  }
  return result;
}

export class HttpBodyDecoder {
  private buffered: Uint8Array = new Uint8Array(0);
  private remaining: number;
  private chunkRemaining: number = -1;
  private needsCrlf: boolean = false;
  private trailers: boolean = false;
  private chunked: boolean;
  done: boolean = false;
  received: number = 0;

  constructor(head: HttpHead) {
    this.remaining = head.contentLength;
    this.chunked = head.chunked;
    this.done = !head.chunked && head.contentLength === 0;
  }

  push(bytes: Uint8Array): Uint8Array[] {
    if (this.done) {
      if (bytes.length) throw new Error('Unexpected bytes after HTTP body');
      return [];
    }
    if (!this.chunked) {
      if (bytes.length > this.remaining) throw new Error('Body exceeds Content-Length');
      this.remaining -= bytes.length; this.received += bytes.length; this.done = this.remaining === 0;
      return bytes.length ? [bytes] : [];
    }
    this.buffered = concatBytes(this.buffered, bytes);
    const output: Uint8Array[] = [];
    while (this.buffered.length) {
      if (this.trailers) {
        if (this.buffered.length >= 2 && this.buffered[0] === 13 && this.buffered[1] === 10) {
          this.buffered = this.buffered.slice(2); this.done = true;
        } else {
          const end = headerEnd(this.buffered);
          if (end < 0) { if (this.buffered.length > 32768) throw new Error('Trailers too large'); break; }
          this.buffered = this.buffered.slice(end + 4); this.done = true;
        }
        if (this.buffered.length) throw new Error('Unexpected bytes after chunked body');
        break;
      }
      if (this.needsCrlf) {
        if (this.buffered.length < 2) break;
        if (this.buffered[0] !== 13 || this.buffered[1] !== 10) throw new Error('Invalid chunk terminator');
        this.buffered = this.buffered.slice(2); this.needsCrlf = false;
      }
      if (this.chunkRemaining < 0) {
        let end = -1;
        for (let i = 0; i + 1 < this.buffered.length; i++) if (this.buffered[i] === 13 && this.buffered[i + 1] === 10) { end = i; break; }
        if (end < 0) { if (this.buffered.length > 1024) throw new Error('Chunk size line too long'); break; }
        const value = ascii(this.buffered.slice(0, end)).split(';')[0];
        if (!/^[0-9a-fA-F]+$/.test(value) || !Number.isSafeInteger(parseInt(value, 16))) throw new Error('Invalid chunk size');
        this.chunkRemaining = parseInt(value, 16); this.buffered = this.buffered.slice(end + 2);
        if (this.chunkRemaining === 0) { this.trailers = true; continue; }
      }
      if (!this.buffered.length) break;
      const count = Math.min(this.buffered.length, this.chunkRemaining);
      output.push(this.buffered.slice(0, count)); this.buffered = this.buffered.slice(count);
      this.received += count; this.chunkRemaining -= count;
      if (this.chunkRemaining === 0) { this.needsCrlf = true; this.chunkRemaining = -1; }
    }
    return output;
  }
}

export function safeRelativePath(name: string): string {
  if (!name || name.length > 1024 || name.includes('\0') || /^[\/\\]/.test(name) || /^[a-zA-Z]:/.test(name)) throw new Error('Invalid file path');
  const parts = name.replace(/\\/g, '/').split('/');
  if (parts.some((part: string) => !part || part === '.' || part === '..')) throw new Error('Unsafe file path');
  return parts.map((part: string) => part.replace(/[<>:"|?*\x00-\x1f]/g, '_')).join('/');
}

export function queryValue(target: string, name: string): string {
  const query = target.split('?')[1] || '';
  for (const part of query.split('&')) {
    const index = part.indexOf('=');
    if (index >= 0 && decodeURIComponent(part.slice(0, index)) === name) return decodeURIComponent(part.slice(index + 1).replace(/\+/g, ' '));
  }
  return '';
}

export function htmlEscape(value: string): string {
  return value.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

export function uniqueName(name: string, occupied: string[]): string {
  const slash = name.lastIndexOf('/'); const dot = name.lastIndexOf('.');
  const stem = dot > slash + 1 ? name.slice(0, dot) : name;
  const extension = dot > slash + 1 ? name.slice(dot) : '';
  let candidate = name; let counter = 1;
  while (occupied.includes(candidate)) candidate = `${stem} (${counter++})${extension}`;
  return candidate;
}
