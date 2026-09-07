import { socket } from '@kit.NetworkKit';
import * as tls from 'libaloetls.so';
import { PullSocket, PullServer } from './PullSocket';

// TLS records stay binary all the way through the application-owned engine.
// This avoids the OS TLSSocketServer binary-to-C-string crash on affected devices.
export class SecureConnection {
  onMessage: (info: socket.SocketMessageInfo) => Promise<void> = async () => {};
  onClose: () => void = () => {};
  onError: (error: Error) => void = () => {};
  private tcp: PullSocket;
  private id: number;
  private closed: boolean = false;
  private outgoing: Promise<void> = Promise.resolve();
  private incoming: Promise<void> = Promise.resolve();
  private handshakeTimer: number = -1;
  private closing: Promise<void> | undefined = undefined;
  private peerClosed: Promise<void> = Promise.resolve();
  private peerEnded: () => void = () => {};
  onDispose: () => void = () => {};

  constructor(tcp: PullSocket, server: number) {
    this.peerClosed = new Promise<void>((resolve) => { this.peerEnded = resolve; });
    this.tcp = tcp; this.id = tls.createSession(server);
    this.handshakeTimer = setTimeout(() => this.fail(new Error('TLS 握手超时')), 30000);
    tcp.onMessage((info: socket.SocketMessageInfo) => {
      if (this.closed) return;
      // After close_notify, drain in-flight ciphertext without delivering it to
      // HTTP or disk. Closing TCP with unread input can reset an early response.
      if (this.closing) { this.tcp.resume(); return; }
      this.incoming = this.incoming.then(async () => {
        // PullSocket supplies one chunk per acknowledgement. Awaiting disk I/O
        // here stops native recv, so TCP slows the sender instead of accumulating
        // an unbounded event queue in ArkTS. Split any coalesced input as well.
        for (let offset = 0; offset < info.message.byteLength && !this.closed; offset += 65536) {
          const result = tls.feed(this.id, info.message.slice(offset, offset + 65536));
          if (result.wire.byteLength) await this.flush(result.wire);
          if (result.plain.byteLength && !this.closed) {
            clearTimeout(this.handshakeTimer); this.handshakeTimer = -1;
            await this.onMessage({ message: result.plain, remoteInfo: info.remoteInfo });
          }
          if (result.closed) await this.close();
        }
        if (!this.closed) this.tcp.resume();
      }).catch((error: Error) => this.fail(error));
    });
    tcp.onClose(() => { this.peerEnded(); this.dispose(); });
    tcp.onError((error: Error) => this.fail(error));
    tcp.resume();
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

  close(): Promise<void> {
    if (this.closing) return this.closing;
    this.closing = this.finishClose(); return this.closing;
  }

  private async finishClose(): Promise<void> {
    if (this.closed) return;
    // A TCP EOF is not a TLS close_notify. Complete the TLS shutdown before
    // releasing the socket so strict clients can finish their HTTP response.
    let timer: number = -1;
    try {
      const wire = tls.shutdown(this.id);
      const drained = this.flush(wire).then(async () => {
        if (!this.closed) { this.tcp.resume(); await this.peerClosed; }
      });
      await Promise.race([drained, new Promise<void>((resolve) => { timer = setTimeout(resolve, 1000); })]);
    } catch (_) { /* Broken channels still have to release their native state. */ }
    finally {
      if (timer !== -1) clearTimeout(timer);
      this.dispose(); await this.tcp.close().catch(() => {});
    }
  }
}

export class SecureServer {
  private stopping: boolean = false;
  private tcp: PullServer | undefined = undefined;
  private id: number = -1;
  private clients: Set<SecureConnection> = new Set();

  async listen(address: socket.NetAddress, certificate: string, key: string,
    connected: (client: SecureConnection) => void, failed: (error: Error) => void): Promise<void> {
    this.stopping = false;
    this.id = tls.createServer(certificate, key);
    try {
      this.tcp = new PullServer();
      await this.tcp.listen(address, (tcp: PullSocket) => {
        try {
          if (this.stopping || this.clients.size >= 32) { tcp.close().catch(() => {}); return; }
          const client = new SecureConnection(tcp, this.id); this.clients.add(client);
          client.onDispose = () => this.clients.delete(client); connected(client);
        } catch (error) { tcp.close().catch(() => {}); failed(error as Error); }
      });
    } catch (error) { await this.close(); throw error as Error; }
  }

  async close(): Promise<void> {
    this.stopping = true;
    await Promise.all(Array.from(this.clients).map((client: SecureConnection) => client.close()));
    await this.tcp?.close().catch(() => {}); this.tcp = undefined;
    if (this.id !== -1) { tls.closeServer(this.id); this.id = -1; }
  }
}
