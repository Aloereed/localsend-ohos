import { socket } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { Peer } from '../model/AppStore';
import { HttpHead, HttpBodyDecoder, concatBytes, headerEnd, parseHttpHead } from './Protocol';
import { sha256 } from './TlsIdentity';

export function encodeText(value: string): Uint8Array { return new util.TextEncoder().encodeInto(value); }
export function decodeText(bytes: Uint8Array): string { return new util.TextDecoder('utf-8').decodeToString(bytes); }

export class Cancellation {
  cancelled: boolean = false;
  close: () => void = () => {};
  cancel(): void { this.cancelled = true; this.close(); }
  check(): void { if (this.cancelled) throw new Error('传输已取消'); }
}

export class HttpReply {
  status: number = 0;
  body: string = '';
  fingerprint: string = '';
}

export type ChunkWriter = (bytes: Uint8Array) => Promise<void>;
export type BodyProducer = (write: ChunkWriter) => Promise<void>;

export async function request(peer: Peer, method: string, path: string, body: string = '', token: Cancellation = new Cancellation(), timeoutMs: number = 120000): Promise<HttpReply> {
  const bytes = encodeText(body);
  return exchange(peer, method, path, bytes.length, async (write: ChunkWriter) => { if (bytes.length) await write(bytes); }, token, timeoutMs);
}

export async function exchange(peer: Peer, method: string, path: string, size: number, produce: BodyProducer, token: Cancellation, timeoutMs: number = 120000): Promise<HttpReply> {
  token.check();
  const tcp = peer.protocol === 'https' ? undefined : socket.constructTCPSocketInstance();
  const tls = peer.protocol === 'https' ? socket.constructTLSSocketInstance() : undefined;
  let finished = false;
  let headerBytes = new Uint8Array(0);
  let bodyBytes = new Uint8Array(0);
  let head: HttpHead | undefined = undefined;
  let decoder: HttpBodyDecoder | undefined = undefined;
  let fingerprint = '';
  let timeout: number = -1;
  const close = (): void => {
    if (timeout !== -1) clearTimeout(timeout);
    if (tcp) tcp.close().catch(() => {});
    if (tls) tls.close().catch(() => {});
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
    token.close = () => fail(new Error('传输已取消'));
    if (tcp) {
      tcp.on('message', (message: socket.SocketMessageInfo) => consume(new Uint8Array(message.message)));
      tcp.on('error', (error) => fail(new Error(`网络错误 ${error.code}`)));
      tcp.on('close', () => { if (!finished) fail(new Error('设备提前关闭了连接')); });
    }
    if (tls) {
      tls.on('message', (message: socket.SocketMessageInfo) => consume(new Uint8Array(message.message)));
      tls.on('error', (error) => fail(new Error(`TLS 网络错误 ${error.code}`)));
      tls.on('close', () => { if (!finished) fail(new Error('设备提前关闭了连接')); });
    }
    const start = async (): Promise<void> => {
      touch();
      const address: socket.NetAddress = { address: peer.ip, port: peer.port, family: peer.ip.includes(':') ? 2 : 1 };
      if (tcp) await tcp.connect({ address: address, timeout: 5000 });
      if (tls) {
        // LocalSend uses self-signed certificates. Check the advertised/persisted
        // fingerprint explicitly before sending any application request bytes.
        await tls.connect({ address: address, secureOptions: {}, skipRemoteValidation: true });
        const cert = await tls.getRemoteCertificate();
        let raw = cert.data;
        if (raw.length && raw[0] === 45) raw = new util.Base64Helper().decodeSync(decodeText(raw).replace(/-----[^-]+-----/g, '').replace(/\s/g, ''));
        fingerprint = await sha256(raw);
        if (peer.fingerprint && fingerprint !== peer.fingerprint.toLowerCase().replace(/:/g, '')) throw new Error('设备证书指纹已改变，请确认设备身份后重新添加');
      }
      token.check();
      const write: ChunkWriter = async (bytes: Uint8Array): Promise<void> => {
        token.check(); if (finished) throw new Error('连接已结束'); touch();
        if (tcp) await tcp.send({ data: bytes.buffer as ArrayBuffer });
        if (tls) await tls.send(bytes.buffer as ArrayBuffer);
      };
      const host = peer.ip.includes(':') ? `[${peer.ip}]` : peer.ip;
      await write(encodeText(`${method} ${path} HTTP/1.1\r\nHost: ${host}:${peer.port}\r\nContent-Type: application/json\r\nContent-Length: ${size}\r\nConnection: close\r\n\r\n`));
      await produce(write);
    };
    start().catch((error: Error) => fail(error));
  });
}
