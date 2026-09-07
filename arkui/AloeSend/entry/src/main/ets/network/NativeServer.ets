import { socket } from '@kit.NetworkKit';
import { HttpHead, HttpBodyDecoder, concatBytes, headerEnd, parseHttpHead } from './Protocol';
import { encodeText } from './Transport';
import { SecureConnection } from './SecureServer';

export interface BodySink {
  write(bytes: Uint8Array): Promise<void>;
  finish(): Promise<void>;
  abort(): Promise<void>;
}

export type RequestHandler = (connection: NativeConnection, head: HttpHead) => Promise<BodySink>;

export class NativeConnection {
  ip: string = '';
  encrypted: boolean = false;
  closed: boolean = false;
  failureReason: string = '';
  private tcp: socket.TCPSocketConnection | undefined = undefined;
  private tls: SecureConnection | undefined = undefined;
  private headBytes: Uint8Array = new Uint8Array(0);
  private decoder: HttpBodyDecoder | undefined = undefined;
  private sink: BodySink | undefined = undefined;
  private pending: Uint8Array[] = [];
  private draining: boolean = false;
  private queuedBytes: number = 0;
  private timeout: number = -1;
  private handler: RequestHandler;
  private responded: boolean = false;
  private completed: boolean = false;
  private consumed: (() => void)[] = [];
  onError: (message: string) => void = () => {};
  onClosed: () => void = () => {};

  constructor(handler: RequestHandler) { this.handler = handler; }

  attachTcp(tcp: socket.TCPSocketConnection): void {
    if (this.closed) { tcp.close().catch(() => {}); return; }
    this.tcp = tcp;
    tcp.on('message', (info: socket.SocketMessageInfo) => { this.ip = info.remoteInfo.address; this.enqueue(new Uint8Array(info.message)); });
    tcp.on('close', () => this.disconnected());
    tcp.on('error', (error) => this.fail(new Error(`TCP ${error.code}`)));
    this.touch();
  }

  attachTls(tls: SecureConnection): void {
    if (this.closed) { tls.close().catch(() => {}); return; }
    this.tls = tls; this.encrypted = true;
    tls.onMessage = (info: socket.SocketMessageInfo) => { this.ip = info.remoteInfo.address; return this.enqueue(new Uint8Array(info.message)); };
    tls.onClose = () => this.disconnected();
    tls.onError = (error: Error) => this.fail(error);
    this.touch();
  }

  private touch(): void {
    if (this.timeout !== -1) clearTimeout(this.timeout);
    this.timeout = setTimeout(() => this.fail(new Error('接收连接超时')), 180000);
  }

  private enqueue(bytes: Uint8Array): Promise<void> {
    if (this.closed || this.responded) return Promise.resolve();
    this.touch(); this.queuedBytes += bytes.length;
    if (this.queuedBytes > 33554432) { this.fail(new Error('写入速度不足，接收缓冲区已满')); return Promise.resolve(); }
    const consumed = new Promise<void>((resolve) => this.consumed.push(resolve));
    this.pending.push(bytes);
    if (!this.draining) this.drain().catch((error: Error) => this.fail(error));
    return consumed;
  }

  private acknowledge(): void {
    const consumed = this.consumed; this.consumed = [];
    for (const resolve of consumed) resolve();
  }

  private async drain(): Promise<void> {
    this.draining = true;
    try {
      while (this.pending.length && !this.closed && !this.responded) {
        // Coalesce packets already waiting for disk I/O. One async write per
        // 16 KiB TLS record otherwise lets high-speed senders outrun the queue.
        let count = 0; let size = 0;
        while (count < this.pending.length && size < 1048576) size += this.pending[count++].length;
        const chunks = this.pending.splice(0, count);
        let bytes = chunks[0];
        if (chunks.length > 1) {
          bytes = new Uint8Array(size); let offset = 0;
          for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
        }
        try { await this.consume(bytes); } finally { this.queuedBytes -= size; }
      }
    } finally {
      this.draining = false;
      this.acknowledge();
      if (this.closed || this.responded) { this.pending = []; this.queuedBytes = 0; }
    }
  }

  private async consume(incoming: Uint8Array): Promise<void> {
    let bytes = incoming;
    if (!this.decoder) {
      this.headBytes = concatBytes(this.headBytes, bytes);
      const end = headerEnd(this.headBytes);
      if (end < 0) { if (this.headBytes.length > 32768) throw new Error('请求头过大'); return; }
      const head = parseHttpHead(this.headBytes.slice(0, end));
      if (!head.method) throw new Error('无效请求');
      this.decoder = new HttpBodyDecoder(head);
      bytes = this.headBytes.slice(end + 4); this.headBytes = new Uint8Array(0);
      this.sink = await this.handler(this, head);
      if (this.closed) { await this.sink.abort(); return; }
    }
    if (this.responded) return;
    for (const piece of this.decoder.push(bytes)) await this.sink!.write(piece);
    if (this.decoder.done && !this.completed) { this.completed = true; await this.sink!.finish(); }
  }

  async send(bytes: Uint8Array): Promise<void> {
    if (this.closed) throw new Error('连接已关闭');
    this.touch();
    if (this.tcp) await this.tcp.send({ data: bytes.buffer as ArrayBuffer });
    if (this.tls) await this.tls.send(bytes.buffer as ArrayBuffer);
  }

  async beginResponse(status: number, size: number, mime: string = 'application/json; charset=utf-8', extraHeaders: string = ''): Promise<void> {
    if (this.responded) return;
    this.responded = true;
    await this.send(encodeText(`HTTP/1.1 ${status} ${status >= 400 ? 'Error' : 'OK'}\r\nContent-Type: ${mime}\r\nContent-Length: ${size}\r\nConnection: close\r\nX-Content-Type-Options: nosniff\r\n${extraHeaders}\r\n`));
  }

  async respond(status: number, body: string = '{}', mime: string = 'application/json; charset=utf-8'): Promise<void> {
    if (this.responded || this.closed) return;
    const bytes = status === 204 ? new Uint8Array(0) : encodeText(body);
    await this.beginResponse(status, bytes.length, mime);
    if (bytes.length) await this.send(bytes);
    this.close();
  }

  close(): void {
    if (this.closed) return;
    this.closed = true;
    this.pending = [];
    this.acknowledge();
    this.onClosed();
    if (!this.completed) this.sink?.abort().catch(() => {});
    if (this.timeout !== -1) clearTimeout(this.timeout);
    this.tcp?.close().catch(() => {}); this.tls?.close().catch(() => {});
  }

  private disconnected(): void {
    const wasClosed = this.closed;
    if (!this.failureReason && !this.completed) this.failureReason = '发送方已断开连接';
    if (!this.closed && !this.completed) this.sink?.abort().catch(() => {});
    this.closed = true;
    this.acknowledge();
    if (!wasClosed) this.onClosed();
    if (this.timeout !== -1) clearTimeout(this.timeout);
  }

  private fail(error: Error): void {
    if (this.closed) return;
    this.failureReason = error.message;
    this.onError(error.message);
    this.sink?.abort().catch(() => {});
    if (this.responded) { this.close(); return; }
    this.respond(400, JSON.stringify({ message: error.message })).catch(() => this.close());
  }
}

export class JsonSink implements BodySink {
  private data: Uint8Array = new Uint8Array(0);
  private callback: (bytes: Uint8Array) => Promise<void>;
  constructor(callback: (bytes: Uint8Array) => Promise<void>) { this.callback = callback; }
  async write(bytes: Uint8Array): Promise<void> {
    if (this.data.length + bytes.length > 1048576) throw new Error('请求内容超过 1 MiB');
    this.data = concatBytes(this.data, bytes);
  }
  async finish(): Promise<void> { await this.callback(this.data); }
  async abort(): Promise<void> {}
}
