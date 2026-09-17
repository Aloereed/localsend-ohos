import { socket } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { Peer } from '../model/AppStore';
import { HttpHead, HttpBodyDecoder, concatBytes, headerEnd, parseHttpHead } from './Protocol';
import { sha256, TlsIdentity } from './TlsIdentity';

export function encodeText(value: string): Uint8Array {
  // Empty HTTP requests need an actual zero-length buffer, independently of
  // native encoder behavior for empty input.
  if (value === '') return new Uint8Array(0);
  const bytes = new util.TextEncoder().encodeInto(value);
  if (!bytes || !bytes.length) throw new Error('文字编码失败');
  return bytes;
}
export function decodeText(bytes: Uint8Array): string {
  return bytes.length ? new util.TextDecoder('utf-8').decodeToString(bytes) : '';
}

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

// Check only whether a listener exists. Do not spend TLS work on empty hosts or
// send plaintext application data to a possibly encrypted LocalSend endpoint.
export function discoveryPortOpen(peer: Peer, token: Cancellation, timeoutMs: number = 350): Promise<boolean> {
  token.check();
  const tcp = socket.constructTCPSocketInstance();
  return new Promise<boolean>((resolve, reject) => {
    let finished = false;
    const finish = (open: boolean): void => {
      if (finished) return;
      finished = true; clearTimeout(timer); tcp.close().catch(() => {});
      if (token.cancelled) reject(new Error(token.reason)); else resolve(open);
    };
    const timer = setTimeout(() => finish(false), timeoutMs);
    token.close = () => finish(false);
    const start = async (): Promise<void> => {
      const family = peer.ip.includes(':') ? 2 : 1;
      await tcp.bind({ address: family === 2 ? '::' : '0.0.0.0', port: 0, family: family });
      if (finished) { await tcp.close().catch(() => {}); return; }
      tcp.on('error', () => finish(false));
      tcp.on('close', () => finish(false));
      await tcp.connect({ address: { address: peer.ip, port: peer.port, family: family }, timeout: timeoutMs });
      if (finished) { await tcp.close().catch(() => {}); return; }
      finish(true);
    };
    start().catch(() => finish(false));
  });
}

export type ChunkWriter = (bytes: Uint8Array) => Promise<void>;
export type BodyProducer = (write: ChunkWriter) => Promise<void>;

export async function request(peer: Peer, method: string, path: string, body: string = '', token: Cancellation = new Cancellation(), timeoutMs: number = 120000, identity?: TlsIdentity): Promise<HttpReply> {
  const bytes = encodeText(body);
  return exchange(peer, method, path, bytes.length, async (write: ChunkWriter) => { if (bytes.length) await write(bytes); }, token, timeoutMs, identity);
}

export async function exchange(peer: Peer, method: string, path: string, size: number, produce: BodyProducer, token: Cancellation, timeoutMs: number = 120000, identity?: TlsIdentity): Promise<HttpReply> {
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
  const pendingWrites: Set<(error: Error) => void> = new Set();
  const close = (): void => {
    if (timeout !== -1) clearTimeout(timeout);
    for (const reject of pendingWrites) reject(new Error(token.cancelled ? token.reason : '连接已结束'));
    pendingWrites.clear();
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
    token.close = () => fail(new Error(token.reason));
    const start = async (): Promise<void> => {
      touch();
      const address: socket.NetAddress = { address: peer.ip, port: peer.port, family: peer.ip.includes(':') ? 2 : 1 };
      const local: socket.NetAddress = { address: peer.ip.includes(':') ? '::' : '0.0.0.0', port: 0, family: address.family };
      // TLSSocket event subscription requires a successful bind on HarmonyOS.
      // Explicit ephemeral binding also makes IPv4/IPv6 selection unambiguous.
      if (tcp) await tcp.bind(local);
      if (tls) await tls.bind(local);
      if (finished) { close(); return; }
      token.check();
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
      if (tcp) await tcp.connect({ address: address, timeout: Math.min(5000, timeoutMs) });
      if (finished) { close(); return; }
      if (tls) {
        // LocalSend uses self-signed certificates. Check the advertised/persisted
        // fingerprint explicitly before sending any application request bytes.
        // LocalSend 1.18+ requires proof of the sender's identity during TLS.
        // Use the same certificate whose fingerprint is advertised by the service.
        const secureOptions: socket.TLSSecureOptions = identity ? { cert: identity.certificate, key: identity.privateKey } : {};
        await tls.connect({ address: address, secureOptions: secureOptions, skipRemoteValidation: true });
        if (finished) { close(); return; }
        const cert = await tls.getRemoteCertificate();
        if (!cert || !cert.data || !cert.data.length) throw new PeerIdentityError('无法读取设备证书，请重试连接');
        let raw = cert.data;
        if (raw.length && raw[0] === 45) raw = new util.Base64Helper().decodeSync(decodeText(raw).replace(/-----[^-]+-----/g, '').replace(/\s/g, ''));
        if (!raw || !raw.length) throw new PeerIdentityError('无法读取设备证书，请重试连接');
        fingerprint = await sha256(raw);
        if (peer.fingerprint && fingerprint !== peer.fingerprint.toLowerCase().replace(/:/g, '')) throw new PeerIdentityError('设备证书指纹已改变，请确认设备身份后重新添加');
      }
      token.check();
      if (finished) { close(); return; }
      const write: ChunkWriter = async (bytes: Uint8Array): Promise<void> => {
        token.check(); if (finished) throw new Error('连接已结束'); touch();
        await new Promise<void>((resolve, reject) => {
          pendingWrites.add(reject);
          const sent = tcp ? tcp.send({ data: bytes.buffer as ArrayBuffer }) : tls!.send(bytes.buffer as ArrayBuffer);
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
