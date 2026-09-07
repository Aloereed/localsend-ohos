import { socket, connection } from '@kit.NetworkKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { AppStore, appStore, Peer, ShareFile, HistoryEntry, TransferView, TransferFile, samePeer } from '../model/AppStore';
import { HttpHead, queryValue, safeRelativePath, uniqueName } from './Protocol';
import { NativeConnection, BodySink, JsonSink } from './NativeServer';
import { TlsIdentity } from './TlsIdentity';
import { Cancellation, request, exchange, encodeText, decodeText, ChunkWriter } from './Transport';
import { parseAddress, LocalInterface, ignoredInterface, sameSubnet } from './Addresses';
import { batchReceiveNames } from '../model/ReceiveNames';
import { SecureServer, SecureConnection } from './SecureServer';
import { ensureDirectory } from '../platform/Directories';

export interface DeviceInfo {
  alias: string;
  version: string;
  deviceModel: string;
  deviceType: string;
  fingerprint: string;
  port: number;
  protocol: string;
  download: boolean;
  announce?: boolean;
}


export interface FileInfo {
  id: string;
  fileName: string;
  size: number;
  fileType: string;
  preview?: string;
  hash?: string;
}

interface PrepareRequest { info: DeviceInfo; files: Record<string, FileInfo>; }
interface PrepareReply { sessionId: string; files: Record<string, string>; }

class ReceiveSession {
  legacy: boolean = false;
  id: string = util.generateRandomUUID();
  ip: string = '';
  peer: Peer = new Peer();
  view: TransferView = new TransferView();
  files: Record<string, FileInfo> = {};
  tokens: Record<string, string> = {};
  resolve: (accepted: boolean) => void = () => {};
  accepted: boolean = false;
  cancelled: boolean = false;
  expired: boolean = false;
  lastActivity: number = Date.now();
  uploads: NativeConnection[] = [];
  stopNotification: Promise<void> = Promise.resolve();
}

class SendSessionRef {
  peer: Peer;
  remoteId: string;
  legacy: boolean;
  constructor(peer: Peer, remoteId: string, legacy: boolean = false) { this.peer = peer; this.remoteId = remoteId; this.legacy = legacy; }
}

class RetryContext {
  peer: Peer;
  files: ShareFile[];
  constructor(peer: Peer, files: ShareFile[]) { this.peer = peer; this.files = files; }
}

class PinFailures {
  count: number = 0;
  expires: number = Date.now() + 300000;
}

class UploadSink implements BodySink {
  private service: LocalSendService;
  private session: ReceiveSession;
  private fileInfo: FileInfo;
  private view: TransferFile;
  private channel: NativeConnection;
  private output: fs.File | undefined = undefined;
  private path: string = '';
  private received: number = 0;
  private lastUpdate: number = 0;
  private hash: cryptoFramework.Md | undefined = undefined;
  private finished: boolean = false;
  private pendingWrite: Promise<void> = Promise.resolve();

  constructor(service: LocalSendService, session: ReceiveSession, fileInfo: FileInfo, view: TransferFile, channel: NativeConnection) {
    this.service = service; this.session = session; this.fileInfo = fileInfo; this.view = view; this.channel = channel;
  }

  async init(): Promise<void> {
    const destination = this.session.view.destination;
    const downloads = this.service.store.downloadDirectory;
    const direct = destination === downloads || destination.startsWith(`${downloads}/`);
    const root = direct ? destination : `${this.service.store.context!.filesDir}/received/${this.session.id}`;
    this.path = `${root}/${safeRelativePath(this.view.name)}`;
    try {
    if (direct) {
      const original = this.path; let suffix = 1;
      while (await fs.access(this.path) || await fs.access(`${this.path}.part`)) {
        const dot = original.lastIndexOf('.'); const split = dot > original.lastIndexOf('/') ? dot : original.length;
        this.path = `${original.slice(0, split)} (${suffix++})${original.slice(split)}`;
      }
    }
      await ensureDirectory(this.path.slice(0, this.path.lastIndexOf('/')));
      this.output = await fs.open(`${this.path}.part`, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    } catch (error) {
      if (!direct) throw error as Error;
      // A previously granted public folder may be unavailable on this launch.
      // No bytes have been written yet, so the entire session can use private storage.
      this.path = `${this.service.store.context!.filesDir}/received/${this.session.id}/${safeRelativePath(this.view.name)}`;
      await ensureDirectory(this.path.slice(0, this.path.lastIndexOf('/')));
      this.output = await fs.open(`${this.path}.part`, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      this.session.view.destination = '';
      this.session.view.storageNotice = '下载目录暂不可用，已改用应用内保存，可从历史另存为';
      this.service.store.notice = this.session.view.storageNotice;
      this.service.store.log(`下载目录写入失败，改用应用内目录：${(error as Error).message}`);
    }
    if (this.fileInfo.hash) this.hash = cryptoFramework.createMd('SHA256');
    if (this.session.cancelled || this.channel.closed) { await this.session.stopNotification; throw new Error('接收已取消'); }
    this.view.status = 'transferring'; this.session.view.status = 'transferring';
    this.session.lastActivity = Date.now();
    this.service.store.updateTransfer(this.session.view);
  }

  async write(bytes: Uint8Array): Promise<void> {
    this.pendingWrite = this.writeBytes(bytes);
    await this.pendingWrite;
  }

  private async writeBytes(bytes: Uint8Array): Promise<void> {
    if (this.finished || this.session.cancelled) { await this.session.stopNotification; throw new Error('接收已取消'); }
    if (this.received + bytes.length > this.fileInfo.size) throw new Error('文件超出声明长度');
    let offset = 0;
    while (offset < bytes.length) {
      if (this.session.cancelled) { await this.session.stopNotification; throw new Error('接收已取消'); }
      const written = await fs.write(this.output!.fd, bytes.slice(offset).buffer as ArrayBuffer);
      if (written <= 0) throw new Error('文件写入失败');
      offset += written;
    }
    await this.hash?.update({ data: bytes });
    if (this.session.cancelled) { await this.session.stopNotification; throw new Error('接收已取消'); }
    this.received += bytes.length; this.view.transferred = this.received;
    if (this.received === bytes.length) this.service.store.log(`已收到首段文件数据（${this.channel.encrypted ? 'HTTPS' : 'HTTP'}）`);
    this.session.lastActivity = Date.now();
    if (Date.now() - this.lastUpdate > 100) { this.service.store.updateTransfer(this.session.view); this.lastUpdate = Date.now(); }
  }

  async finish(): Promise<void> {
    if (this.session.cancelled) { await this.session.stopNotification; throw new Error('接收已取消'); }
    if (this.received !== this.fileInfo.size) throw new Error('文件未完整接收');
    if (this.hash) {
      const hash = (await this.hash.digest()).data.reduce((value: string, byte: number) => value + byte.toString(16).padStart(2, '0'), '');
      if (hash !== this.fileInfo.hash!.toLowerCase()) throw new Error('文件校验和不匹配');
    }
    if (this.output) { await fs.close(this.output); this.output = undefined; }
    if (this.session.cancelled) { await this.session.stopNotification; throw new Error('接收已取消'); }
    await fs.rename(`${this.path}.part`, this.path);
    this.finished = true; this.view.status = 'complete'; this.view.path = this.path;
    const entry = new HistoryEntry(); entry.name = this.view.name; entry.peer = this.session.peer.alias;
    entry.size = this.received; entry.path = this.path; entry.peerInfo = this.session.peer;
    if (this.fileInfo.preview && this.fileInfo.fileType === 'text/plain' && this.received <= 400000) entry.text = await fs.readText(this.path);
    await this.service.store.addHistory(entry, this.session.view.offerGallerySave);
    await this.service.store.saveReceivedCopy(entry, this.session.view.destination, this.session.id);
    this.service.finishReceiveFile(this.session);
    await this.channel.respond(200);
  }

  async abort(): Promise<void> {
    if (this.finished) return;
    this.finished = true;
    // Release the session before asynchronous disk cleanup. A blocked write
    // must not keep the receive entry point busy or leave other files running.
    this.service.failReceive(this.session, this.channel.failureReason || '文件接收中断', this.channel);
    await this.pendingWrite.catch(() => {});
    if (this.output) { await fs.close(this.output).catch(() => {}); this.output = undefined; }
    if (this.path) await fs.unlink(`${this.path}.part`).catch(() => {});
  }
}

export class LocalSendService {
  store: AppStore;
  private identity: TlsIdentity = new TlsIdentity();
  private udp: socket.MulticastSocket | undefined = undefined;
  private tcp: socket.TCPSocketServer | undefined = undefined;
  private tls: SecureServer | undefined = undefined;
  private channels: NativeConnection[] = [];
  private receiving: ReceiveSession | undefined = undefined;
  private sending: Map<string, Cancellation> = new Map();
  private sendSessions: Map<string, SendSessionRef> = new Map();
  private retryContexts: Map<string, RetryContext> = new Map();
  private batchCancelled: boolean = false;
  private pinResolver: ((pin: string) => void) | undefined = undefined;
  private timer: number = -1;
  private discoveryRetries: number[] = [];
  private running: boolean = false;
  private starting: boolean = false;
  private paused: boolean = false;
  private lifecycle: Promise<void> = Promise.resolve();
  private pinAttempts: Map<string, PinFailures> = new Map();

  constructor(store: AppStore) { this.store = store; }

  info(announce: boolean = false): DeviceInfo {
    return { alias: this.store.settings.alias, version: '2.1', deviceModel: this.store.settings.deviceModel, deviceType: this.store.settings.deviceType,
      fingerprint: this.store.settings.fingerprint, port: this.running || this.starting ? this.store.listenerPort : this.store.settings.port,
      protocol: (this.running || this.starting ? this.store.listenerHttps : this.store.settings.https) ? 'https' : 'http', download: false, announce: announce };
  }

  private scheduleLifecycle(action: () => Promise<void>): Promise<void> {
    const operation = this.lifecycle.then(action);
    this.lifecycle = operation.catch(() => {});
    return operation;
  }

  start(): Promise<void> { return this.scheduleLifecycle(() => this.startNow()); }
  stop(): Promise<void> { return this.scheduleLifecycle(() => this.stopNow()); }
  restart(): Promise<void> { return this.scheduleLifecycle(() => this.restartNow()); }
  pause(): Promise<void> { return this.scheduleLifecycle(() => this.pauseNow()); }
  resume(): Promise<void> { return this.scheduleLifecycle(() => this.resumeNow()); }
  resetIdentity(): Promise<void> { return this.scheduleLifecycle(() => this.resetIdentityNow()); }

  private async startNow(): Promise<void> {
    if (this.store.identityResetting || this.paused || this.running || this.starting || !this.store.ready) return;
    this.starting = true; this.store.serverStatus = '正在启动接收服务';
    this.store.listenerPort = this.store.settings.port; this.store.listenerHttps = this.store.settings.https;
    this.store.listenerMulticast = this.store.settings.multicast;
    try {
      if (this.store.listenerHttps) await this.identity.load(this.store);
      const address: socket.NetAddress = { address: '0.0.0.0', port: this.store.listenerPort, family: 1 };
      if (this.store.listenerHttps) {
        this.tls = new SecureServer();
        await this.tls.listen(address, this.identity.certificate, this.identity.privateKey, (client: SecureConnection) => {
          const channel = this.newChannel(); channel.attachTls(client);
        }, (error: Error) => { this.store.serverStatus = `接收服务错误 ${error.message}`; this.store.log(this.store.serverStatus); });
      } else {
        this.tcp = socket.constructTCPSocketServerInstance();
        await this.tcp.listen(address);
        this.tcp.on('connect', (client: socket.TCPSocketConnection) => { const channel = this.newChannel(); channel.attachTcp(client); });
        this.tcp.on('error', (error) => { this.store.serverStatus = `接收服务错误 ${error.code}`; this.store.log(this.store.serverStatus); });
      }
      this.running = true;
      this.store.listenerRunning = true;
      this.store.serverStatus = this.store.listenerHttps ? '已就绪 · 加密传输' : '已就绪 · 未加密';
      await this.readAddresses().catch((e: Error) => this.store.log(`读取本机地址失败，可尝试手动连接：${e.message}`));
      try {
        this.udp = socket.constructMulticastSocketInstance();
        await this.udp.bind(address);
        await this.udp.setExtraOptions({ reuseAddress: true });
        this.udp.on('message', (message: socket.SocketMessageInfo) => this.discovered(message));
        this.udp.on('error', (error) => this.store.log(`组播错误 ${error.code}`));
        await this.udp.addMembership({ address: this.store.listenerMulticast, port: this.store.listenerPort, family: 1 });
        await this.udp.setMulticastTTL(1);
        await this.announce();
      } catch (e) { this.store.log(`组播不可用，可通过地址连接：${(e as Error).message}`); }
      // The first multicast can precede Wi-Fi readiness or another peer's listener.
      // Retry without requiring a tap and refresh addresses on subsequent scans.
      this.discoveryRetries = [800, 2500, 6000].map((delay: number) =>
        setTimeout(() => { if (this.running) this.discover(false); }, delay));
      this.timer = setInterval(() => { this.checkReceiveIdle(); this.discover(false); }, 15000);
      this.store.log('LocalSend 接收服务启动');
    } catch (e) { this.store.fail('接收服务启动失败', e as Error); await this.stopNow(); this.store.serverStatus = '启动失败'; }
    finally { this.starting = false; }
  }

  private async stopNow(): Promise<void> {
    this.running = false;
    this.store.listenerRunning = false;
    if (this.timer !== -1) { clearInterval(this.timer); this.timer = -1; }
    for (const retry of this.discoveryRetries) clearTimeout(retry);
    this.discoveryRetries = [];
    if (this.receiving && (this.receiving.view.status === 'waiting' || this.receiving.view.status === 'transferring')) this.cancel(this.receiving.id);
    for (const channel of this.channels) channel.close(); this.channels = [];
    await this.udp?.close().catch(() => {}); this.udp = undefined;
    await this.tcp?.close().catch(() => {}); this.tcp = undefined;
    await this.tls?.close().catch(() => {}); this.tls = undefined;
    this.store.serverStatus = '接收服务已停止';
  }

  private async restartNow(): Promise<void> {
    if (this.store.identityResetting) return;
    if (this.starting) return;
    if (this.store.activeTransfers) { this.store.notice = '请等待当前传输结束后重启服务'; return; }
    this.paused = false; await this.stopNow(); await this.startNow();
  }

  private async pauseNow(): Promise<void> {
    if (this.store.identityResetting) return;
    if (this.starting) return;
    if (this.store.activeTransfers) { this.store.notice = '请等待当前传输结束后停止服务'; return; }
    this.paused = true; await this.stopNow();
  }

  private async resumeNow(): Promise<void> {
    if (this.store.identityResetting) return;
    this.paused = false; await this.startNow();
  }

  private async resetIdentityNow(): Promise<void> {
    if (this.store.identityResetting || this.starting || this.store.activeTransfers || this.store.webUrl || this.store.webStarting) {
      this.store.notice = '请先结束传输并停止浏览器分享'; return;
    }
    const resume = !this.paused;
    this.store.identityResetting = true;
    this.paused = true;
    try { await this.stopNow(); await this.identity.reset(this.store); this.store.notice = '本机证书已重新生成'; }
    catch (error) { this.store.fail('重置证书失败', error as Error); }
    finally { this.store.identityResetting = false; if (resume) { this.paused = false; await this.startNow(); } }
  }

  certificate(): string { return this.identity.certificate; }

  setReceiveGalleryOffer(value: boolean): void {
    if (!this.receiving || this.receiving.accepted || this.receiving.cancelled) return;
    this.receiving.view.offerGallerySave = value;
    this.store.updateTransfer(this.receiving.view);
  }

  private newChannel(): NativeConnection {
    this.channels = this.channels.filter((channel: NativeConnection) => !channel.closed);
    const channel = new NativeConnection((connection: NativeConnection, head: HttpHead) => this.handle(connection, head));
    channel.onError = (message: string) => this.store.log(`接收：${message}`);
    this.channels.push(channel);
    if (this.channels.length > 32) channel.close();
    return channel;
  }

  async readAddresses(): Promise<void> {
    const addresses: string[] = [];
    const interfaces: LocalInterface[] = [];
    for (const net of await connection.getAllNets()) {
      const props = await connection.getConnectionProperties(net);
      const ignored = ignoredInterface(props.linkAddresses.map((link: connection.LinkAddress) => link.address.address), this.store.settings.networkFilter, this.store.settings.networkPatterns);
      for (const link of props.linkAddresses) {
        const ip = link.address.address;
        const local = new LocalInterface(); local.name = props.interfaceName; local.ip = ip; local.prefixLength = link.prefixLength; local.ignored = ignored;
        if (ip && !ip.startsWith('127.') && ip !== '::1') interfaces.push(local);
        if (!ignored && ip && !ip.startsWith('127.') && !ip.includes(':') && !addresses.includes(ip)) addresses.push(ip);
      }
    }
    this.store.localIps = addresses;
    this.store.interfaces = interfaces;
  }

  async announce(): Promise<void> {
    if (!this.store.settings.visible || !this.running) return;
    if (this.store.settings.networkFilter !== 'none' && !this.store.localIps.length) return;
    await this.udp?.send({ data: JSON.stringify(this.info(true)), address: { address: this.store.listenerMulticast, port: this.store.listenerPort, family: 1 } });
  }

  async discover(notify: boolean = true): Promise<void> {
    if (this.paused) {
      if (notify) this.store.notice = '接收服务已暂停，请在设置中启动';
      return;
    }
    if (!this.running) await this.start();
    await this.readAddresses().catch(() => {});
    await this.announce().catch((e: Error) => {
      if (notify) this.store.fail('发现设备失败', e); else this.store.log(`自动发现：${e.message}`);
    });
    if (notify) this.store.notice = '已发送发现请求';
    this.store.networkLog('discovery', `发现广播 · ${this.store.localIps.join(', ')}`);
    for (const peer of this.store.favorites) this.probe(peer).catch(() => {});
  }

  private discovered(message: socket.SocketMessageInfo): void {
    if (message.message.byteLength > 16384) return;
    if (this.store.settings.networkFilter !== 'none' && !this.store.interfaces.some((local: LocalInterface) =>
      !local.ignored && sameSubnet(local.ip, message.remoteInfo.address, local.prefixLength))) return;
    try {
      const info = JSON.parse(decodeText(new Uint8Array(message.message))) as DeviceInfo;
      if (!info || typeof info.alias !== 'string' || typeof info.fingerprint !== 'string' || info.fingerprint === this.store.settings.fingerprint) return;
      const peer = this.peerFrom(info, message.remoteInfo.address);
      this.store.networkLog('discovery', `${peer.alias} · ${peer.ip}:${peer.port} · ${peer.protocol}`);
      this.upsertPeer(peer);
      if (info.announce && this.store.settings.visible) this.register(peer).catch((e: Error) => this.store.log(`设备握手：${e.message}`));
    } catch (_) { /* Ignore malformed UDP datagrams from unrelated applications. */ }
  }

  private peerFrom(info: DeviceInfo, ip: string): Peer {
    const peer = new Peer(); peer.alias = String(info.alias || ip).slice(0, 100); peer.ip = ip;
    peer.version = info.version || '1.0';
    peer.port = Number.isInteger(info.port) && info.port > 0 && info.port <= 65535 ? info.port : 53317;
    peer.protocol = info.protocol === 'http' ? 'http' : 'https'; peer.fingerprint = info.fingerprint || '';
    peer.deviceModel = info.deviceModel || ''; peer.deviceType = info.deviceType || 'desktop'; return peer;
  }

  private upsertPeer(peer: Peer, verified: boolean = false): void {
    if (peer.fingerprint === this.store.settings.fingerprint) return;
    this.store.peers = [peer, ...this.store.peers.filter((item: Peer) => !samePeer(item, peer) && (item.ip !== peer.ip || item.port !== peer.port))].slice(0, 100);
    if (verified && this.store.favorites.some((item: Peer) => samePeer(item, peer) && (item.ip !== peer.ip || item.port !== peer.port || item.protocol !== peer.protocol))) {
      this.store.favorites = this.store.favorites.map((item: Peer) => {
        if (!samePeer(item, peer)) return item;
        const updated = JSON.parse(JSON.stringify(peer)) as Peer; updated.alias = item.alias; return updated;
      });
      this.store.save();
    }
  }

  private async register(peer: Peer): Promise<void> {
    const result = await request(peer, 'POST', `/api/localsend/${peer.version === '1.0' ? 'v1' : 'v2'}/register`, JSON.stringify(this.info()), new Cancellation(), this.store.settings.discoveryTimeout);
    if (result.status === 200) {
      const info = JSON.parse(result.body) as DeviceInfo;
      const known = this.peerFrom(info, peer.ip); known.port = peer.port; known.protocol = peer.protocol;
      if (result.fingerprint) known.fingerprint = result.fingerprint;
      this.upsertPeer(known, !!result.fingerprint);
    }
  }

  async probe(peer: Peer): Promise<void> {
    let reply = await request(peer, 'GET', '/api/localsend/v2/info', '', new Cancellation(), this.store.settings.discoveryTimeout);
    if (reply.status === 404) reply = await request(peer, 'GET', '/api/localsend/v1/info', '', new Cancellation(), this.store.settings.discoveryTimeout);
    if (reply.status !== 200) throw new Error(`设备返回 ${reply.status}`);
    const info = JSON.parse(reply.body) as DeviceInfo;
    const known = this.peerFrom(info, peer.ip); known.port = peer.port; known.protocol = peer.protocol;
    if (reply.fingerprint) known.fingerprint = reply.fingerprint;
    this.upsertPeer(known, !!reply.fingerprint);
    if (this.store.settings.visible) await this.register(known);
  }

  async addAddress(address: string): Promise<void> {
    try {
      const parsed = parseAddress(address);
      const peer = new Peer(); peer.ip = parsed.ip; peer.port = parsed.port; peer.protocol = parsed.protocol;
      try { await this.probe(peer); }
      catch (e) { if (parsed.explicitProtocol) throw e as Error; peer.protocol = 'http'; await this.probe(peer); }
      this.store.notice = '设备已添加';
    } catch (e) { this.store.fail('添加设备失败', e as Error); }
  }

  private async handle(channel: NativeConnection, head: HttpHead): Promise<BodySink> {
    const path = head.target.split('?')[0];
    // Only protocol route names: never record PINs, tokens, query strings or bodies.
    const route = /^\/api\/localsend\/v[12]\/(info|register|prepare-upload|send-request|upload|send|cancel)$/.test(path) ? path : '(unknown route)';
    this.store.networkLog('http', `${head.method} ${route} ← ${channel.ip}`);
    if ((/^\/api\/localsend\/v[12]\/upload$/.test(path) || path === '/api/localsend/v1/send') && head.method === 'POST') return this.openUpload(channel, head);
    return new JsonSink(async (bytes: Uint8Array): Promise<void> => {
      if (/^\/api\/localsend\/v[12]\/info$/.test(path) && head.method === 'GET') await channel.respond(200, JSON.stringify(this.info()));
      else if (/^\/api\/localsend\/v[12]\/register$/.test(path) && head.method === 'POST') {
        const info = JSON.parse(decodeText(bytes)) as DeviceInfo;
        if (!info || typeof info.alias !== 'string') { await channel.respond(400); return; }
        this.upsertPeer(this.peerFrom(info, channel.ip)); await channel.respond(200, JSON.stringify(this.info()));
      } else if ((/^\/api\/localsend\/v[12]\/prepare-upload$/.test(path) || path === '/api/localsend/v1/send-request') && head.method === 'POST') await this.prepare(channel, head, bytes);
      else if (/^\/api\/localsend\/v[12]\/cancel$/.test(path) && head.method === 'POST') {
        const id = queryValue(head.target, 'sessionId');
        await channel.respond(this.cancelByPeer(channel.ip, id, path.includes('/v1/')) ? 200 : 403);
      } else await channel.respond(404);
    });
  }

  async handleBrowserRequest(channel: NativeConnection, head: HttpHead): Promise<BodySink> {
    return this.handle(channel, head);
  }

  private async prepare(channel: NativeConnection, head: HttpHead, bytes: Uint8Array): Promise<void> {
    if (this.receiving && !['complete', 'error', 'cancelled', 'declined'].includes(this.receiving.view.status)) { await channel.respond(409); return; }
    if (this.store.settings.pin) {
      const savedAttempts = this.pinAttempts.get(channel.ip);
      const attempts = savedAttempts && savedAttempts.expires > Date.now() ? savedAttempts : new PinFailures();
      if (attempts.count >= 3) { await channel.respond(429); return; }
      const pin = queryValue(head.target, 'pin');
      if (pin !== this.store.settings.pin) {
        if (pin) { attempts.count++; this.pinAttempts.set(channel.ip, attempts); }
        for (const address of this.pinAttempts.keys()) { if (this.pinAttempts.get(address)!.expires < Date.now()) this.pinAttempts.delete(address); }
        await channel.respond(401); return;
      }
      this.pinAttempts.delete(channel.ip);
    }
    const payload = JSON.parse(decodeText(bytes)) as PrepareRequest;
    if (!payload?.info || typeof payload.info.alias !== 'string' || !payload.files || typeof payload.files !== 'object') { await channel.respond(400); return; }
    const ids = Object.keys(payload.files);
    if (!ids.length || ids.length > 10000) { await channel.respond(400); return; }
    const session = new ReceiveSession(); session.ip = channel.ip; session.peer = this.peerFrom(payload.info, channel.ip);
    session.legacy = head.target.includes('/v1/');
    session.files = payload.files; session.view.id = session.id; session.view.peer = session.peer.alias;
    session.view.direction = 'receive'; session.view.encrypted = channel.encrypted;
    session.view.peerInfo = session.peer;
    session.view.destination = this.store.settings.destinationMode !== 'private' ? this.store.settings.destination : '';
    session.view.offerGallerySave = this.store.settings.offerGallerySave;
    for (const id of ids) {
      const file = payload.files[id];
      if (!file || typeof file.fileName !== 'string' || !Number.isSafeInteger(file.size) || file.size < 0 || file.id !== id) throw new Error('文件信息无效');
      const view = new TransferFile(); view.id = id;
      view.name = uniqueName(safeRelativePath(file.fileName), session.view.files.map((item: TransferFile) => item.name)); view.size = file.size;
      if (file.preview && file.fileType === 'text/plain') { view.name = file.fileName.slice(0, 100); view.preview = file.preview.slice(0, 100000); }
      session.view.files.push(view);
    }
    this.receiving = session; this.store.updateTransfer(session.view); this.upsertPeer(session.peer);
    channel.onClosed = () => {
      if (!session.accepted) { session.cancelled = true; session.resolve(false); }
    };
    let automatic = this.store.settings.quickSave;
    if (!automatic && this.store.settings.favoriteQuickSave && channel.encrypted && session.peer.protocol === 'https' &&
      this.store.favorites.some((peer: Peer) => !!peer.fingerprint && peer.fingerprint === session.peer.fingerprint)) {
      // A fingerprint in JSON is only a claim. Prove possession of the matching
      // TLS identity at the sender address before bypassing receive consent.
      try { automatic = (await request(session.peer, 'GET', '/api/localsend/v2/info')).status === 200; }
      catch (_) { this.store.log('收藏身份验证失败，转为手动确认'); }
    }
    if (channel.closed || session.cancelled) {
      session.view.status = 'cancelled'; this.store.updateTransfer(session.view); return;
    }
    if (!automatic) {
      this.store.pendingReceive = session.id;
      const accepted = await new Promise<boolean>((resolve) => {
        const timer = setTimeout(() => resolve(false), 120000);
        session.resolve = (value: boolean) => { clearTimeout(timer); resolve(value); };
      });
      if (this.store.pendingReceive === session.id) this.store.pendingReceive = '';
      if (!accepted || session.cancelled || channel.closed) { session.view.status = session.cancelled || channel.closed ? 'cancelled' : 'declined'; this.store.updateTransfer(session.view); await channel.respond(403); return; }
    }
    session.accepted = true;
    const selected = session.view.files.filter((file: TransferFile) => file.selected);
    if (!selected.length) { session.view.status = 'declined'; this.store.updateTransfer(session.view); await channel.respond(403); return; }
    if (!session.legacy && selected.every((file: TransferFile) => !!session.files[file.id].preview && session.files[file.id].fileType === 'text/plain')) {
      for (const file of selected) {
        const entry = new HistoryEntry(); entry.name = file.name; entry.text = session.files[file.id].preview!;
        entry.peer = session.peer.alias; entry.peerInfo = session.peer; entry.size = encodeText(entry.text).length;
        await this.store.addHistory(entry); file.status = 'complete'; file.transferred = file.size;
      }
      session.view.status = 'complete'; session.view.finished = Date.now(); this.store.updateTransfer(session.view); await channel.respond(204); return;
    }
    const tokens: Record<string, string> = {};
    for (const file of selected) tokens[file.id] = util.generateRandomUUID();
    session.tokens = tokens; session.lastActivity = Date.now(); session.view.status = 'transferring'; this.store.updateTransfer(session.view);
    const response: PrepareReply = { sessionId: session.id, files: tokens };
    this.store.log(`已确认接收 ${selected.length} 项，正在发送上传凭据`);
    await channel.respond(200, JSON.stringify(head.target.includes('/v1/') ? tokens : response));
    this.store.log('上传凭据已发送，等待文件连接');
  }

  acceptReceive(accepted: boolean): void { this.receiving?.resolve(accepted); }

  async chooseReceiveDestination(): Promise<void> {
    const session = this.receiving; if (!session || session.accepted) return;
    try {
      const directory = await this.store.pickDestination();
      if (directory && this.receiving === session && !session.accepted) { session.view.destination = directory; this.store.updateTransfer(session.view); }
    } catch (e) { this.store.fail('选择本次接收目录失败', e as Error); }
  }

  selectReceiveFile(id: string, selected: boolean): void {
    const file = this.receiving?.view.files.find((item: TransferFile) => item.id === id);
    if (file && this.receiving) { file.selected = selected; this.store.updateTransfer(this.receiving.view); }
  }

  selectAllReceive(mode: string): void {
    if (!this.receiving || this.receiving.accepted) return;
    for (const file of this.receiving.view.files) file.selected = mode === 'all' ? true : mode === 'none' ? false : !file.selected;
    this.store.updateTransfer(this.receiving.view);
  }

  resetReceiveNames(): void {
    const session = this.receiving; if (!session || session.accepted) return;
    const occupied: string[] = [];
    for (const file of session.view.files) {
      file.name = uniqueName(safeRelativePath(session.files[file.id].fileName), occupied); occupied.push(file.name);
    }
    this.store.updateTransfer(session.view);
  }

  batchRenameReceive(mode: string, prefix: string, padZero: boolean, sortFirst: boolean): boolean {
    const session = this.receiving; if (!session || session.accepted) return false;
    try {
      session.view.files = batchReceiveNames(session.view.files, mode, prefix, padZero, sortFirst);
      this.store.updateTransfer(session.view); return true;
    } catch (e) { this.store.fail('批量重命名失败', e as Error); return false; }
  }

  renameReceive(id: string, name: string): boolean {
    if (!this.receiving || this.receiving.accepted) return false;
    const file = this.receiving.view.files.find((item: TransferFile) => item.id === id);
    if (!file) return false;
    try {
      const safe = safeRelativePath(name.trim());
      file.name = uniqueName(safe, this.receiving.view.files.filter((item: TransferFile) => item.id !== id).map((item: TransferFile) => item.name));
      this.store.updateTransfer(this.receiving.view); return true;
    } catch (e) { this.store.fail('文件名无效', e as Error); return false; }
  }

  private async openUpload(channel: NativeConnection, head: HttpHead): Promise<BodySink> {
    this.store.log(`文件上传连接已到达（${channel.encrypted ? 'HTTPS' : 'HTTP'}）`);
    const session = this.receiving;
    const id = queryValue(head.target, 'sessionId') || (head.target.includes('/v1/') ? session?.id : '');
    const fileId = queryValue(head.target, 'fileId'); const token = queryValue(head.target, 'token');
    if (!session || !session.accepted || session.cancelled || session.ip !== channel.ip || session.id !== id || !token || session.tokens[fileId] !== token) {
      await channel.respond(403); return new JsonSink(async () => {});
    }
    const info = session.files[fileId]; const view = session.view.files.find((file: TransferFile) => file.id === fileId);
    if (!info || !view || !['waiting', 'error'].includes(view.status) || (!head.chunked && head.contentLength !== info.size)) {
      await channel.respond(400); return new JsonSink(async () => {});
    }
    const sink = new UploadSink(this, session, info, view, channel);
    view.status = 'transferring'; session.uploads.push(channel);
    try {
      await sink.init();
      if (session.cancelled || channel.closed) throw new Error('接收已取消');
      return sink;
    } catch (error) {
      channel.failureReason = (error as Error).message;
      await sink.abort(); throw error as Error;
    }
  }

  finishReceiveFile(session: ReceiveSession): void {
    session.lastActivity = Date.now();
    if (session.cancelled) return;
    if (session.view.files.filter((file: TransferFile) => file.selected).every((file: TransferFile) => file.status === 'complete')) {
      session.view.status = 'complete'; session.view.finished = Date.now(); this.store.notice = session.view.storageNotice || `已收到 ${session.peer.alias} 的文件`;
    }
    this.store.updateTransfer(session.view);
  }

  checkReceiveIdle(): void {
    const session = this.receiving;
    if (!session || !session.accepted || session.cancelled || session.view.status !== 'transferring') return;
    if (Date.now() - session.lastActivity < 180000 || session.uploads.some((channel: NativeConnection) => !channel.closed)) return;
    session.expired = true;
    this.endReceive(session, 'error', '发送方长时间未继续传输，请让对方重试', true);
  }

  failReceive(session: ReceiveSession, message: string, channel: NativeConnection): void {
    this.endReceive(session, 'error', message, true, channel);
  }

  private endReceive(session: ReceiveSession, status: string, message: string, notifyPeer: boolean,
    respondingChannel?: NativeConnection): void {
    if (session.cancelled || session.view.status === 'complete' || session.view.status === 'declined') return;
    session.cancelled = true; session.tokens = {}; session.resolve(false);
    session.view.status = status; session.view.error = message; session.view.finished = Date.now();
    for (const file of session.view.files) {
      if (file.selected && (file.status === 'waiting' || file.status === 'transferring')) file.status = status;
    }
    if (this.store.pendingReceive === session.id) this.store.pendingReceive = '';
    this.store.updateTransfer(session.view);
    if (notifyPeer && session.accepted) session.stopNotification = this.notifyCancel(session.peer, session.id, session.legacy);
    // Give the control request priority over a socket EOF. Flutter only accepts
    // receiver cancellation while its send session is still active.
    session.stopNotification.then(() => {
      for (const channel of session.uploads) { if (channel !== respondingChannel) channel.close(); }
    });
  }

  private notifyCancel(peer: Peer, sessionId: string, legacy: boolean): Promise<void> {
    const path = legacy ? '/api/localsend/v1/cancel' : `/api/localsend/v2/cancel?sessionId=${encodeURIComponent(sessionId)}`;
    return request(peer, 'POST', path, '', new Cancellation(), 1000).then((reply) => {
      this.store.log(reply.status === 200 ? '对方已确认终止传输' : `终止通知未被对方接受：HTTP ${reply.status}`);
    }).catch((error: Error) => this.store.log(`终止通知发送失败：${error.message}`));
  }

  private cancelByPeer(ip: string, remoteId: string, legacy: boolean): boolean {
    const session = this.receiving;
    if (session && session.ip === ip && !session.cancelled && (session.view.status === 'waiting' || session.view.status === 'transferring') &&
      (legacy ? session.legacy : session.id === remoteId || (!session.accepted && !remoteId))) {
      this.cancel(session.id, false); return true;
    }
    const matching: string[] = [];
    for (const entry of this.sendSessions.entries()) {
      if (entry[1].peer.ip === ip && (legacy ? entry[1].legacy : !!remoteId && entry[1].remoteId === remoteId)) matching.push(entry[0]);
    }
    if (matching.length !== 1) return false;
    const id = matching[0]; const cancellation = this.sending.get(id);
    if (!cancellation) return false;
    cancellation.cancel('对方终止了传输');
    const transfer = this.store.transfers.find((item: TransferView) => item.id === id);
    if (transfer) {
      transfer.status = 'cancelled'; transfer.error = '对方终止了传输'; transfer.finished = Date.now();
      for (const file of transfer.files) { if (file.status === 'waiting' || file.status === 'transferring') file.status = 'cancelled'; }
      this.store.updateTransfer(transfer);
    }
    return true;
  }

  cancel(id: string, notifyPeer: boolean = true): void {
    this.sending.get(id)?.cancel();
    if (this.store.pendingPin === id) this.submitPin('');
    const sending = this.sendSessions.get(id);
    if (sending && notifyPeer) this.notifyCancel(sending.peer, sending.remoteId, sending.legacy);
    if (this.receiving?.id === id) {
      this.endReceive(this.receiving, 'cancelled', '', notifyPeer);
    }
  }

  submitPin(pin: string): void { this.pinResolver?.(pin); this.pinResolver = undefined; this.store.pendingPin = ''; }

  async send(peer: Peer, selectedFiles: ShareFile[] = this.store.files): Promise<void> {
    if (this.store.identityResetting) { this.store.notice = '正在重置证书，请稍后'; return; }
    if (!selectedFiles.length) { this.store.notice = '请先选择文件或输入文字'; return; }
    if (this.sending.size >= 4) { this.store.notice = '已有 4 项发送任务，请等待完成后再发送'; return; }
    const files = selectedFiles.slice(); const transfer = new TransferView(); transfer.id = util.generateRandomUUID();
    this.retryContexts.set(transfer.id, new RetryContext(peer, files));
    if (this.retryContexts.size > 40) {
      for (const id of this.retryContexts.keys()) { if (!this.sending.has(id)) { this.retryContexts.delete(id); break; } }
    }
    transfer.peer = peer.alias; transfer.encrypted = peer.protocol === 'https';
    transfer.peerInfo = peer;
    const fileInfos: Record<string, FileInfo> = {};
    for (const file of files) {
      const view = new TransferFile(); view.id = file.id; view.name = file.name; view.size = file.size; transfer.files.push(view);
      const info: FileInfo = { id: file.id, fileName: file.text ? 'message.txt' : file.name, size: file.size, fileType: file.mime };
      if (file.text) info.preview = file.text;
      fileInfos[file.id] = info;
    }
    this.store.updateTransfer(transfer);
    const cancellation = new Cancellation(); this.sending.set(transfer.id, cancellation);
    let declined = false;
    try {
      await this.store.updateOutgoingHistory(transfer, files, true);
      cancellation.check();
      const favorite = this.store.favorites.find((item: Peer) => item.ip === peer.ip && item.port === peer.port);
      if (favorite?.fingerprint && favorite.fingerprint !== peer.fingerprint) throw new Error('收藏设备的身份已改变，请核对后重新收藏');
      const payload: PrepareRequest = { info: this.info(), files: fileInfos };
      let legacy = peer.version === '1.0';
      let preparePath = legacy ? '/api/localsend/v1/send-request' : '/api/localsend/v2/prepare-upload';
      let response = await request(peer, 'POST', preparePath, JSON.stringify(payload), cancellation);
      if (response.status === 404 && !legacy) {
        legacy = true; preparePath = '/api/localsend/v1/send-request';
        response = await request(peer, 'POST', preparePath, JSON.stringify(payload), cancellation);
      }
      while (response.status === 401) {
        if (this.store.pendingPin && this.store.pendingPin !== transfer.id) throw new Error('请先完成另一项传输的 PIN 确认，再重试此任务');
        this.store.pendingPin = transfer.id;
        const pin = await new Promise<string>((resolve) => { this.pinResolver = resolve; });
        if (!pin) { cancellation.cancel(); cancellation.check(); }
        response = await request(peer, 'POST', `${preparePath}?pin=${encodeURIComponent(pin)}`, JSON.stringify(payload), cancellation);
      }
      cancellation.check();
      if (response.status === 204) {
        for (const file of transfer.files) {
          const source = files.find((item: ShareFile) => item.id === file.id)!;
          file.status = source.text ? 'complete' : 'skipped'; file.transferred = source.text ? file.size : 0;
        }
      } else {
        if (response.status !== 200) {
          declined = response.status === 403;
          throw new Error(declined ? '对方拒绝了传输' : response.status === 409 ? '对方正在传输，请稍后重试' : response.status === 429 ? 'PIN 尝试次数过多' : `设备返回 ${response.status}`);
        }
        const prepared: PrepareReply = legacy ? { sessionId: 'legacy', files: JSON.parse(response.body) as Record<string, string> } : JSON.parse(response.body) as PrepareReply;
        if (!prepared.sessionId || !prepared.files) throw new Error('设备返回了无效传输会话');
        this.sendSessions.set(transfer.id, new SendSessionRef(peer, prepared.sessionId, legacy));
        transfer.status = 'transferring'; this.store.updateTransfer(transfer);
        for (const file of files) {
          cancellation.check(); const view = transfer.files.find((item: TransferFile) => item.id === file.id)!;
          const token = prepared.files[file.id];
          if (!token) { view.status = 'skipped'; this.store.updateTransfer(transfer); continue; }
          view.status = 'transferring'; this.store.updateTransfer(transfer);
          await this.store.updateOutgoingHistory(transfer, files);
          cancellation.check();
          let lastUpdate = 0;
          const uploadPath = legacy ? `/api/localsend/v1/send?fileId=${encodeURIComponent(file.id)}&token=${encodeURIComponent(token)}` :
            `/api/localsend/v2/upload?sessionId=${encodeURIComponent(prepared.sessionId)}&fileId=${encodeURIComponent(file.id)}&token=${encodeURIComponent(token)}`;
          const upload = await exchange(peer, 'POST', uploadPath, file.size,
            async (write: ChunkWriter): Promise<void> => {
              if (file.text) { await write(encodeText(file.text)); view.transferred = file.size; return; }
              const source = await fs.open(file.uri, fs.OpenMode.READ_ONLY);
              try {
                let count = 0;
                while (count < file.size) {
                  cancellation.check(); const buffer = new ArrayBuffer(Math.min(65536, file.size - count));
                  const read = await fs.read(source.fd, buffer);
                  if (read <= 0) throw new Error('源文件读取不完整');
                  await write(new Uint8Array(buffer).slice(0, read)); count += read; view.transferred = count;
                  if (Date.now() - lastUpdate > 100) { this.store.updateTransfer(transfer); lastUpdate = Date.now(); }
                }
              } finally { await fs.close(source); }
            }, cancellation);
          cancellation.check();
          if (upload.status !== 200) throw new Error(`文件发送失败 ${upload.status}`);
          view.status = 'complete'; view.transferred = file.size; this.store.updateTransfer(transfer);
          await this.store.updateOutgoingHistory(transfer, files);
        }
      }
      cancellation.check();
      transfer.status = 'complete'; transfer.finished = Date.now(); this.store.notice = `已发送到 ${peer.alias}`;
    } catch (e) {
      const remote = this.sendSessions.get(transfer.id);
      if (remote && !cancellation.cancelled) this.notifyCancel(remote.peer, remote.remoteId, remote.legacy);
      transfer.status = cancellation.cancelled ? 'cancelled' : 'error'; transfer.error = (e as Error).message; transfer.finished = Date.now();
      for (const file of transfer.files) { if (file.status === 'transferring' || file.status === 'waiting') file.status = transfer.status; }
      this.store.log(`发送：${transfer.error}`);
    } finally {
      this.sending.delete(transfer.id); this.sendSessions.delete(transfer.id); this.store.updateTransfer(transfer);
      await this.store.updateOutgoingHistory(transfer, files, false, declined);
    }
  }

  async sendMany(peers: Peer[]): Promise<void> {
    if (this.store.identityResetting) { this.store.notice = '正在重置证书，请稍后'; return; }
    if (this.store.batchRemaining > 0) { this.store.notice = '已有多设备发送任务'; return; }
    const files = this.store.files.slice();
    if (!files.length) { this.store.notice = '请先选择发送内容'; return; }
    this.batchCancelled = false; this.store.batchRemaining = peers.length;
    try {
      for (const peer of peers) {
        if (this.batchCancelled) break;
        await this.send(peer, files); this.store.batchRemaining--;
      }
    } finally { this.store.batchRemaining = 0; }
  }

  cancelAll(): void {
    this.batchCancelled = true;
    for (const id of this.sending.keys()) this.cancel(id);
  }

  async retry(id: string): Promise<void> {
    const context = this.retryContexts.get(id);
    const previous = this.store.transfers.find((transfer: TransferView) => transfer.id === id);
    if (!context || !previous) { this.store.notice = '请重新选择原文件后发送'; return; }
    const incomplete = previous.files.filter((file: TransferFile) => file.status !== 'complete' && file.status !== 'skipped').map((file: TransferFile) => file.id);
    await this.send(context.peer, context.files.filter((file: ShareFile) => incomplete.includes(file.id)));
  }
}

export const localSend: LocalSendService = new LocalSendService(appStore);
