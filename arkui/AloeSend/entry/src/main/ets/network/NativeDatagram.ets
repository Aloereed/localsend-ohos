import { socket } from '@kit.NetworkKit';
import * as native from 'libaloetls.so';
import { encodeText } from './Transport';

export class NativeDatagram {
  private id: number = -1;
  private closing: Promise<void> | undefined = undefined;
  private stopped: () => void = () => {};

  async listen(address: socket.NetAddress, group: string, receive: (info: socket.SocketMessageInfo) => void): Promise<void> {
    this.id = native.udpListen(address.address, address.port || 53317, group, (event: native.UdpEvent) => {
      if (event.kind === 'stopped') { this.id = -1; this.stopped(); return; }
      if (this.closing) return;
      receive({ message: event.data, remoteInfo: { address: event.ip, port: event.port, family: 'IPv4', size: event.data.byteLength } });
    });
  }

  async send(options: socket.UDPSendOptions): Promise<void> {
    if (this.id < 0 || this.closing) throw new Error('设备发现已停止');
    const bytes = typeof options.data === 'string' ? encodeText(options.data).buffer as ArrayBuffer : options.data as ArrayBuffer;
    native.udpSend(this.id, options.address.address, options.address.port || 53317, bytes);
  }

  close(): Promise<void> {
    if (this.closing) return this.closing;
    if (this.id < 0) return Promise.resolve();
    this.closing = new Promise<void>((resolve) => { this.stopped = resolve; });
    native.udpClose(this.id); return this.closing;
  }
}
