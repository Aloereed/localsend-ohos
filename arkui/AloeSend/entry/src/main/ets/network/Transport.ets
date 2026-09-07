import { NativeClient } from './NativeClient';
import { util } from '@kit.ArkTS';
import { Peer } from '../model/AppStore';
import { HttpHead, HttpBodyDecoder, concatBytes, headerEnd, parseHttpHead } from './Protocol';
import { sha256 } from './TlsIdentity';

export function encodeText(value: string): Uint8Array { return new util.TextEncoder().encodeInto(value); }
export function decodeText(bytes: Uint8Array): string { return new util.TextDecoder('utf-8').decodeToString(bytes); }

export class Cancellation {
  cancelled: boolean = false;
  reason: string = '传输已取消';
  close: () => void = () => {};
  cancel(reason: string = '传输已取消'): void { this.reason = reason; this.cancelled = true; this.close(); }
  check(): void { if (this.cancelled) throw new Error(this.reason); }
}

export class HttpReply {
  status: number = 0;
  body: string = '';
  fingerprint: string = '';
}

export class PeerIdentityError extends Error {}

export type ChunkWriter = (bytes: Uint8Array) => Promise<void>;
export type BodyProducer = (write: ChunkWriter) => Promise<void>;

export async function request(peer: Peer, method: string, path: string, body: string = '', token: Cancellation = new Cancellation(), timeoutMs: number = 120000): Promise<HttpReply> {
  const bytes = encodeText(body);
  return exchange(peer, method, path, bytes.length, async (write: ChunkWriter) => { if (bytes.length) await write(bytes); }, token, timeoutMs);
}

export async function exchange(peer: Peer, method: string, path: string, size: number, produce: BodyProducer, token: Cancellation, timeoutMs: number = 120000): Promise<HttpReply> {
  token.check();
  const client = new NativeClient();
  let finished = false;
  let headerBytes = new Uint8Array(0);
  let bodyBytes = new Uint8Array(0);
  let head: HttpHead | undefined = undefined;
  let decoder: HttpBodyDecoder | undefined = undefined;
  let fingerprint = '';
  let timeout: number = -1;
  const pendingWrites: Set<(error: Error) => void> = new Set();
  const close = (): void => {
    if (timeout !== -1) clearTimeout(timeout);
    for (const reject of pendingWrites) reject(new Error(token.cancelled ? token.reason : '连接已结束'));
    pendingWrites.clear();
    client.close();
  };
  return new Promise<HttpReply>((resolve, reject) => {
    const fail = (error: Error): void => { if (!finished) { finished = true; close(); reject(error); } };
    const touch = (): void => {
      if (timeout !== -1) clearTimeout(timeout);
      timeout = setTimeout(() => fail(new Error('等待设备响应超时')), timeoutMs);
    };
    const complete = (): void => {
      if (finished || !head || !decoder?.done) return;
      const reply = new HttpReply(); reply.status = head.status; reply.body = decodeText(bodyBytes); reply.fingerprint = fingerprint;
      finished = true; close(); resolve(reply);
    };
    const consume = (incoming: Uint8Array): void => {
      if (finished) return;
      touch();
      try {
        let bytes = incoming;
        if (!head) {
          headerBytes = concatBytes(headerBytes, bytes);
          const end = headerEnd(headerBytes);
          if (end < 0) { if (headerBytes.length > 32768) throw new Error('设备响应头过大'); return; }
          head = parseHttpHead(headerBytes.slice(0, end));
          if (!head.status) throw new Error('设备返回了无效响应');
          decoder = new HttpBodyDecoder(head); bytes = headerBytes.slice(end + 4); headerBytes = new Uint8Array(0);
        }
        for (const piece of decoder!.push(bytes)) {
          if (bodyBytes.length + piece.length > 4194304) throw new Error('设备响应超过限制');
          bodyBytes = concatBytes(bodyBytes, piece);
        }
        complete();
      } catch (e) { fail(e as Error); }
    };
    token.close = () => fail(new Error(token.reason));
    const start = async (): Promise<void> => {
      touch();
      client.onMessage = (bytes: Uint8Array) => consume(bytes);
      client.onError = (error: Error) => fail(error);
      client.onClose = () => { if (!finished) fail(new Error('设备提前关闭了连接')); };
      await client.connect(peer.ip, peer.port, peer.protocol === 'https');
      if (finished) { close(); return; }
      if (peer.protocol === 'https') {
        // Self-signed certificates are pinned before application bytes are sent
        // or response bytes are accepted, including handshake-coalesced data.
        fingerprint = await sha256(client.certificate());
        if (peer.fingerprint && fingerprint !== peer.fingerprint.toLowerCase().replace(/:/g, '')) throw new PeerIdentityError('设备证书指纹已改变，请确认设备身份后重新添加');
      }
      if (finished) { close(); return; }
      client.startReading();
      token.check();
      const write: ChunkWriter = async (bytes: Uint8Array): Promise<void> => {
        token.check(); if (finished) throw new Error('连接已结束'); touch();
        await new Promise<void>((resolve, reject) => {
          pendingWrites.add(reject);
          const sent = client.send(bytes);
          sent.then(() => { pendingWrites.delete(reject); resolve(); }, (error: Error) => { pendingWrites.delete(reject); reject(error); });
        });
      };
      const host = peer.ip.includes(':') ? `[${peer.ip}]` : peer.ip;
      await write(encodeText(`${method} ${path} HTTP/1.1\r\nHost: ${host}:${peer.port}\r\nContent-Type: application/json\r\nContent-Length: ${size}\r\nConnection: close\r\n\r\n`));
      await produce(write);
    };
    start().catch((error: Error) => fail(error));
  });
}
