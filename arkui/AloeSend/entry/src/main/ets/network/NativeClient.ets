import * as native from 'libaloetls.so';
import { PullSocket } from './PullSocket';

// All socket I/O uses the C++ nonblocking transport. ArkTS owns protocol state
// and grants one receive credit after processing each native 64 KiB chunk.
export class NativeClient {
  onMessage: (bytes: Uint8Array) => void = () => {};
  onError: (error: Error) => void = () => {};
  onClose: () => void = () => {};
  private tcp: PullSocket | undefined = undefined;
  private session: number = -1;
  private closed: boolean = false;
  private ready: boolean = false;
  private reading: boolean = false;
  private pending: Uint8Array = new Uint8Array(0);
  private outgoing: Promise<void> = Promise.resolve();
  private connected: () => void = () => {};
  private rejected: (error: Error) => void = () => {};

  connect(ip: string, port: number, encrypted: boolean): Promise<void> {
    if (this.closed || this.tcp) return Promise.reject(new Error('连接已结束或已启动'));
    return new Promise<void>((resolve, reject) => {
      this.connected = resolve; this.rejected = reject;
      try {
        if (encrypted) this.session = native.createClient();
        const tcp = new PullSocket(-1, ip); this.tcp = tcp;
        tcp.onMessage((info) => { this.feed(new Uint8Array(info.message)).catch((error: Error) => this.fail(error)); });
        tcp.onError((error: Error) => this.fail(error));
        tcp.onClose(() => {
          if (this.closed) return;
          this.close(); this.onClose();
        });
        tcp.id = native.tcpConnect(ip, port, (event: native.TcpEvent) => {
          if (this.closed) return;
          if (event.kind === 'connect') {
            if (encrypted) this.feed(new Uint8Array(0)).catch((error: Error) => this.fail(error));
            else { this.ready = true; this.connected(); }
          } else tcp.deliver(event);
        });
      } catch (error) { this.fail(error as Error); }
    });
  }

  certificate(): Uint8Array {
    if (this.closed || !this.ready || this.session < 0) throw new Error('TLS 握手尚未完成');
    return new Uint8Array(native.peerCertificate(this.session));
  }

  startReading(): void {
    if (this.closed || !this.ready) return;
    this.reading = true;
    if (this.pending.length) {
      const bytes = this.pending; this.pending = new Uint8Array(0); this.onMessage(bytes);
    }
    if (!this.closed) this.tcp?.resume();
  }

  private async feed(bytes: Uint8Array): Promise<void> {
    if (this.closed) return;
    if (this.session < 0) {
      if (this.reading) this.onMessage(bytes);
    } else {
      const result = native.feed(this.session, bytes.buffer as ArrayBuffer);
      if (result.wire.byteLength) await this.flush(result.wire);
      if (this.closed) return;
      if (result.plain.byteLength) {
        if (this.reading) this.onMessage(new Uint8Array(result.plain));
        else this.pending = new Uint8Array(result.plain);
      }
      if (this.closed) return;
      if (result.closed) { this.close(); this.onClose(); return; }
      if (result.ready && !this.ready) { this.ready = true; this.connected(); }
    }
    // Pause at handshake completion until Transport has checked the fingerprint.
    if (!this.closed && (!this.ready || this.reading)) this.tcp?.resume();
  }

  private flush(bytes: ArrayBuffer): Promise<void> {
    this.outgoing = this.outgoing.then(async (): Promise<void> => {
      if (this.closed || !this.tcp) throw new Error('连接已结束');
      await this.tcp.send({ data: bytes });
    });
    return this.outgoing;
  }

  async send(bytes: Uint8Array): Promise<void> {
    if (this.closed || !this.ready) throw new Error('连接已结束或尚未就绪');
    const buffer = bytes.slice().buffer as ArrayBuffer;
    await this.flush(this.session < 0 ? buffer : native.write(this.session, buffer).wire);
  }

  private fail(error: Error): void {
    if (this.closed) return;
    this.rejected(error); this.close(); this.onError(error);
  }

  close(): void {
    if (this.closed) return;
    this.closed = true; this.pending = new Uint8Array(0);
    this.rejected(new Error('连接已结束'));
    this.tcp?.close().catch(() => {});
    if (this.session >= 0) { native.closeSession(this.session); this.session = -1; }
  }
}
