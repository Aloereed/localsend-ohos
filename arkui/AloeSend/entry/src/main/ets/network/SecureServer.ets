import { socket } from '@kit.NetworkKit';
import * as tls from 'libaloetls.so';

// TLS records stay binary all the way through the application-owned engine.
// This avoids the OS TLSSocketServer binary-to-C-string crash on affected devices.
export class SecureConnection {
  onMessage: (info: socket.SocketMessageInfo) => void = () => {};
  onClose: () => void = () => {};
  onError: (error: Error) => void = () => {};
  private tcp: socket.TCPSocketConnection;
  private id: number;
  private closed: boolean = false;
  private incoming: Promise<void> = Promise.resolve();
  private outgoing: Promise<void> = Promise.resolve();
  private queued: number = 0;
  private handshakeTimer: number = -1;
  onDispose: () => void = () => {};

  constructor(tcp: socket.TCPSocketConnection, server: number) {
    this.tcp = tcp; this.id = tls.createSession(server);
    this.handshakeTimer = setTimeout(() => this.fail(new Error('TLS 握手超时')), 30000);
    tcp.on('message', (info: socket.SocketMessageInfo) => {
      if (this.closed) return;
      this.queued += info.message.byteLength;
      if (this.queued > 2097152) { this.fail(new Error('TLS 输入队列已满')); return; }
      this.incoming = this.incoming.then(async () => {
        try {
          if (this.closed) return;
          const result = tls.feed(this.id, info.message);
          await this.flush(result.wire);
          if (result.plain.byteLength && !this.closed) {
            clearTimeout(this.handshakeTimer); this.handshakeTimer = -1;
            this.onMessage({ message: result.plain, remoteInfo: info.remoteInfo });
          }
          if (result.closed) await this.close();
        } finally { this.queued -= info.message.byteLength; }
      }).catch((error: Error) => this.fail(error));
    });
    tcp.on('close', () => this.dispose());
    tcp.on('error', (error) => this.fail(new Error(`TLS TCP ${error.code}`)));
  }

  private flush(bytes: ArrayBuffer): Promise<void> {
    if (!bytes.byteLength) return Promise.resolve();
    this.outgoing = this.outgoing.then(async () => {
      if (this.closed) throw new Error('TLS 连接已关闭');
      await this.tcp.send({ data: bytes });
    });
    return this.outgoing;
  }

  async send(bytes: ArrayBuffer): Promise<void> {
    if (this.closed) throw new Error('TLS 连接已关闭');
    await this.flush(tls.write(this.id, bytes).wire);
  }

  private fail(error: Error): void {
    if (this.closed) return;
    this.onError(error); this.close().catch(() => {});
  }

  private dispose(): void {
    if (this.closed) return;
    this.closed = true;
    if (this.handshakeTimer !== -1) clearTimeout(this.handshakeTimer);
    tls.closeSession(this.id); this.onClose(); this.onDispose();
  }

  async close(): Promise<void> { this.dispose(); await this.tcp.close().catch(() => {}); }
}

export class SecureServer {
  private tcp: socket.TCPSocketServer | undefined = undefined;
  private id: number = -1;
  private clients: Set<SecureConnection> = new Set();

  async listen(address: socket.NetAddress, certificate: string, key: string,
    connected: (client: SecureConnection) => void, failed: (error: Error) => void): Promise<void> {
    this.id = tls.createServer(certificate, key);
    try {
      this.tcp = socket.constructTCPSocketServerInstance();
      await this.tcp.listen(address);
      this.tcp.on('connect', (tcp: socket.TCPSocketConnection) => {
        try {
          if (this.clients.size >= 32) { tcp.close().catch(() => {}); return; }
          const client = new SecureConnection(tcp, this.id); this.clients.add(client);
          client.onDispose = () => this.clients.delete(client); connected(client);
        } catch (error) { tcp.close().catch(() => {}); failed(error as Error); }
      });
      this.tcp.on('error', (error) => failed(new Error(`TCP ${error.code}`)));
    } catch (error) { await this.close(); throw error as Error; }
  }

  async close(): Promise<void> {
    for (const client of Array.from(this.clients)) await client.close();
    await this.tcp?.close().catch(() => {}); this.tcp = undefined;
    if (this.id !== -1) { tls.closeServer(this.id); this.id = -1; }
  }
}
