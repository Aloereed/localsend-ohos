import { socket } from '@kit.NetworkKit';
import * as native from 'libaloetls.so';

// One native read is issued only when the consumer has finished its previous
// chunk. The operating system's TCP window then provides real backpressure.
export class PullSocket {
  id: number;
  ip: string;
  private closed: boolean = false;
  private message: (info: socket.SocketMessageInfo) => void = () => {};
  private disconnected: () => void = () => {};
  private failed: (error: Error) => void = () => {};

  constructor(id: number, ip: string) { this.id = id; this.ip = ip; }
  onMessage(callback: (info: socket.SocketMessageInfo) => void): void { this.message = callback; }
  onClose(callback: () => void): void { this.disconnected = callback; }
  onError(callback: (error: Error) => void): void { this.failed = callback; }
  resume(): void { if (!this.closed) native.tcpRead(this.id); }
  deliver(event: native.TcpEvent): void {
    if (this.closed) return;
    if (event.kind === 'message') this.message({ message: event.data,
      remoteInfo: { address: this.ip, family: this.ip.includes(':') ? 'IPv6' : 'IPv4', port: 0, size: event.data.byteLength } });
    else if (event.kind === 'error') this.failed(new Error(event.error));
    else if (event.kind === 'close') { this.closed = true; native.tcpClose(this.id); this.disconnected(); }
  }
  async send(options: socket.TCPSendOptions): Promise<void> {
    if (this.closed) throw new Error('TCP 连接已关闭');
    await native.tcpSend(this.id, options.data as ArrayBuffer);
  }
  async close(): Promise<void> {
    if (this.closed) return;
    this.closed = true; native.tcpClose(this.id); this.disconnected();
  }
}

export class PullServer {
  private id: number = -1;
  private peers: Map<number, PullSocket> = new Map();
  private connected: (peer: PullSocket) => void = () => {};
  private stopped: () => void = () => {};
  private closing: Promise<void> | undefined = undefined;
  async listen(address: socket.NetAddress, connected: (peer: PullSocket) => void): Promise<void> {
    this.connected = connected;
    this.id = native.tcpListen(address.address, address.port || 53317, (event: native.TcpEvent) => {
      if (event.kind === 'stopped') { this.id = -1; this.stopped(); return; }
      if (event.kind === 'connect') {
        const peer = new PullSocket(event.id, event.ip);
        if (this.closing) { peer.close(); return; }
        this.peers.set(event.id, peer); this.connected(peer);
      } else {
        this.peers.get(event.id)?.deliver(event);
        if (event.kind === 'close') this.peers.delete(event.id);
      }
    });
  }
  close(): Promise<void> {
    if (this.closing) return this.closing;
    if (this.id === -1) return Promise.resolve();
    this.closing = new Promise<void>((resolve) => { this.stopped = resolve; });
    for (const peer of this.peers.values()) peer.close();
    this.peers.clear(); native.tcpStop(this.id); return this.closing;
  }
}
