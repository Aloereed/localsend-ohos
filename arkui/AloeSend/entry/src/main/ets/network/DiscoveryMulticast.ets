import * as native from 'libaloetls.so';
import { socket } from '@kit.NetworkKit';
import { LocalInterface, ipv4 } from './Addresses';

class DiscoveryChannel {
  key: string = '';
  id: number = -1;
  active: boolean = true;
  stopped: Promise<void> = Promise.resolve();
  resolve: () => void = () => {};
}

export class DiscoveryMulticast {
  private channels: DiscoveryChannel[] = [];
  private serial: Promise<void> = Promise.resolve();
  private generation: number = 0;
  private receive: (message: socket.SocketMessageInfo) => void;
  private log: (message: string) => void;

  constructor(receive: (message: socket.SocketMessageInfo) => void, log: (message: string) => void) {
    this.receive = receive; this.log = log;
  }

  sync(interfaces: LocalInterface[], group: string, port: number, ipv6Ready: boolean, force: boolean = false): Promise<void> {
    const generation = this.generation;
    const desired: Map<string, string[]> = new Map();
    for (const local of interfaces) {
      if (local.ignored) continue;
      if (ipv4(local.ip) && !local.ip.startsWith('127.') && local.ip !== '0.0.0.0') {
        desired.set(`${group}:${port}:${local.ip}`, [group, local.ip]);
      } else if (ipv6Ready && local.ip.includes(':') && local.ip !== '::1' && local.ip !== '::' && local.name) {
        // Only advertise IPv6 after its receive listener has successfully bound.
        desired.set(`v6:${port}:${local.name}`, ['ff12::fd3a:e420', local.name]);
      }
    }
    const operation = this.serial.then(async (): Promise<void> => {
      if (generation !== this.generation) return;
      const removed = this.channels.filter((channel: DiscoveryChannel) => force || !channel.active || !desired.has(channel.key));
      this.channels = this.channels.filter((channel: DiscoveryChannel) => !removed.includes(channel));
      await Promise.all(removed.map((channel: DiscoveryChannel) => this.stop(channel)));
      if (generation !== this.generation) return;
      for (const entry of desired.entries()) {
        if (this.channels.some((channel: DiscoveryChannel) => channel.key === entry[0] && channel.active)) continue;
        const channel = new DiscoveryChannel(); channel.key = entry[0];
        channel.stopped = new Promise<void>((resolve) => { channel.resolve = resolve; });
        try {
          channel.id = native.multicastOpen(entry[1][0], port, entry[1][1], (event: native.MulticastEvent) => {
            if (event.kind === 'stopped') {
              channel.active = false; channel.id = -1; channel.resolve();
              if (event.error) this.log(`${channel.key}：${event.error}`);
              return;
            }
            if (!channel.active || generation !== this.generation) return;
            this.receive({ message: event.data, remoteInfo: { address: event.ip, port: event.port,
              family: event.ip.includes(':') ? 'IPv6' : 'IPv4', size: event.data.byteLength } });
          });
          this.channels.push(channel); this.log(`组播已加入 ${channel.key}`);
        } catch (error) { channel.resolve(); this.log(`组播加入失败 ${channel.key}：${(error as Error).message}`); }
      }
    });
    this.serial = operation.catch(() => {}); return operation;
  }

  send(bytes: Uint8Array): void {
    for (const channel of this.channels) {
      if (!channel.active) continue;
      try { native.multicastSend(channel.id, bytes.buffer as ArrayBuffer); }
      catch (error) {
        this.log(`组播发送失败 ${channel.key}：${(error as Error).message}`);
        this.stop(channel).catch(() => {});
      }
    }
  }

  private stop(channel: DiscoveryChannel): Promise<void> {
    channel.active = false;
    if (channel.id !== -1) native.multicastStop(channel.id);
    return channel.stopped;
  }

  close(): Promise<void> {
    this.generation++;
    for (const channel of this.channels) channel.active = false;
    const operation = this.serial.then(async (): Promise<void> => {
      const channels = this.channels; this.channels = [];
      await Promise.all(channels.map((channel: DiscoveryChannel) => this.stop(channel)));
    });
    this.serial = operation.catch(() => {}); return operation;
  }
}
