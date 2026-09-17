import { socket, connection } from '@kit.NetworkKit';
import * as native from 'libaloetls.so';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { AppStore, appStore, Peer, ShareFile, HistoryEntry, TransferView, TransferFile, samePeer } from '../model/AppStore';
import { HttpHead, queryValue, safeRelativePath, uniqueName } from './Protocol';
import { NativeConnection, BodySink, JsonSink } from './NativeServer';
import { TlsIdentity } from './TlsIdentity';
import { Cancellation, request, exchange, encodeText, decodeText, ChunkWriter, BodyProducer, HttpReply, PeerIdentityError, discoveryPortOpen } from './Transport';
import { parseAddress, LocalInterface, ignoredInterface, sameSubnet, ipv4, ipv6 } from './Addresses';
import { DiscoveryMulticast } from './DiscoveryMulticast';
import { DiscoveryScan } from './DiscoveryScan';
import { fileChecksum } from './FileChecksum';
import { storageError } from '../platform/StorageError';
import { batchReceiveNames, receiveName } from '../model/ReceiveNames';
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
  sha256?: string;
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
  attempts: Record<string, number> = {};
  resolve: (accepted: boolean) => void = () => {};
  accepted: boolean = false;
  cancelled: boolean = false;
  expired: boolean = false;
  lastActivity: number = Date.now();
  uploads: NativeConnection[] = [];
  cleaning: Set<string> = new Set();
  stopNotification: Promise<void> = Promise.resolve();
}

class SendSessionRef {
  peer: Peer;
  remoteId: string;
  legacy: boolean;
  constructor(peer: Peer, remoteId: string, legacy: boolean = false) { this.peer = peer; this.remoteId = remoteId; this.legacy = legacy; }
}

class RetryContext {
  remoteExpired: boolean = false;
  accepted: PrepareReply | undefined = undefined;
  legacy: boolean = false;
  peer: Peer;
  files: ShareFile[];
  keepSelection: boolean;
  constructor(peer: Peer, files: ShareFile[], keepSelection: boolean) { this.peer = peer; this.files = files; this.keepSelection = keepSelection; }
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
    if (this.service.store.settings.verifyChecksums && (this.fileInfo.sha256 || this.fileInfo.hash)) this.hash = cryptoFramework.createMd('SHA256');
    if (this.session.cancelled || this.channel.closed) { await this.session.stopNotification; throw new Error('接收已取消'); }
    if (this.session.view.status !== 'transferring' || this.session.view.activeBytes < 0) {
      this.session.view.activeStarted = Date.now(); this.session.view.activeBytes = 0;
    }
    this.view.status = 'transferring'; this.view.error = ''; this.view.transferred = 0;
    this.session.view.status = 'transferring'; this.session.view.error = ''; this.session.view.finished = 0;
    this.session.lastActivity = Date.now();
    this.service.store.updateTransfer(this.session.view);
  }

  async write(bytes: Uint8Array): Promise<void> {
    this.pendingWrite = this.writeBytes(bytes);
    try { await this.pendingWrite; }
    catch (error) { throw new Error(this.service.store.t(storageError(error as Error))); }
  }

  private async writeBytes(bytes: Uint8Array): Promise<void> {
    if (this.finished || this.session.cancelled) { await this.session.stopNotification; throw new Error('接收已取消'); }
    if (this.received + bytes.length > this.fileInfo.size) throw new Error('文件超出声明长度');
    let offset = 0;
    while (offset < bytes.length) {
      if (this.session.cancelled) { await this.session.stopNotification; throw new Error('接收已取消'); }
      let written = 0;
      try { written = await fs.write(this.output!.fd, bytes.slice(offset).buffer as ArrayBuffer); }
      catch (error) { this.channel.failureStatus = 500; throw error as Error; }
      if (written <= 0) { this.channel.failureStatus = 500; throw new Error('文件写入失败'); }
      offset += written;
    }
    await this.hash?.update({ data: bytes });
    if (this.session.cancelled) { await this.session.stopNotification; throw new Error('接收已取消'); }
    this.received += bytes.length; this.view.transferred = this.received;
    this.session.view.activeBytes += bytes.length;
    if (this.received === bytes.length) this.service.store.log(`已收到首段文件数据（${this.channel.encrypted ? 'HTTPS' : 'HTTP'}）`);
    this.session.lastActivity = Date.now();
    if (Date.now() - this.lastUpdate > 100) { this.service.store.updateTransfer(this.session.view); this.lastUpdate = Date.now(); }
  }

  async finish(): Promise<void> {
    if (this.session.cancelled) { await this.session.stopNotification; throw new Error('接收已取消'); }
    if (this.received !== this.fileInfo.size) throw new Error('文件未完整接收');
    if (this.hash) {
      const hash = (await this.hash.digest()).data.reduce((value: string, byte: number) => value + byte.toString(16).padStart(2, '0'), '');
      if (hash !== (this.fileInfo.sha256 || this.fileInfo.hash!).toLowerCase()) {
        this.channel.failureStatus = this.fileInfo.sha256 ? 422 : 500; throw new Error('文件校验和不匹配');
      }
    }
    try { if (this.output) { await fs.close(this.output); this.output = undefined; } }
    catch (error) { this.channel.failureStatus = 500; throw new Error(this.service.store.t(storageError(error as Error))); }
    if (this.session.cancelled) { await this.session.stopNotification; throw new Error('接收已取消'); }
    try { await fs.rename(`${this.path}.part`, this.path); }
    catch (error) { this.channel.failureStatus = 500; throw new Error(this.service.store.t(storageError(error as Error))); }
    this.finished = true; this.view.status = 'complete'; this.view.path = this.path;
    const entry = new HistoryEntry(); entry.name = this.view.name; entry.peer = this.session.peer.alias;
    entry.size = this.received; entry.path = this.path; entry.peerInfo = this.session.peer;
    if (this.fileInfo.preview && this.fileInfo.fileType === 'text/plain' && this.received <= 400000) entry.text = await fs.readText(this.path);
    await this.service.store.completeIncomingHistory(entry, this.session.view, this.view);
    await this.service.store.saveReceivedCopy(entry, this.session.view.destination, this.session.id);
    this.service.finishReceiveFile(this.session);
    await this.channel.respond(200);
  }

  async abort(): Promise<void> {
    if (this.finished) return;
    this.finished = true;
    // Release the session before asynchronous disk cleanup. A blocked write
    // must not keep the receive entry point busy or leave other files running.
    if (!this.session.cancelled) this.view.error = this.channel.failureReason || '文件接收中断';
    const recoverable = (this.channel.failureStatus === 500 || this.channel.failureStatus === 422 || this.channel.transportInterrupted) && !this.session.cancelled;
    if (recoverable) {
      this.session.cleaning.add(this.view.id); this.view.status = 'error';
      if (!this.session.view.files.some((file: TransferFile) => file.status === 'transferring')) {
        this.session.view.status = 'error'; this.session.view.error = this.view.error; this.session.view.finished = Date.now();
      }
      this.service.store.updateTransfer(this.session.view);
    }
    if (!recoverable) this.service.failReceive(this.session, this.channel.failureReason || '文件接收中断', this.channel);
    // A response/EOF can move Flutter out of its sending state before /cancel
    // arrives. Keep the upload alive until the control request has completed.
    if (!recoverable) await this.session.stopNotification;
    await this.pendingWrite.catch(() => {});
    if (this.output) { await fs.close(this.output).catch(() => {}); this.output = undefined; }
    if (this.path) await fs.unlink(`${this.path}.part`).catch(() => {});
    this.session.cleaning.delete(this.view.id);
    if (recoverable) await this.service.failReceiveFile(this.session, this.view, this.channel);
  }
}

export class LocalSendService {
  store: AppStore;
  private identity: TlsIdentity = new TlsIdentity();
  private identityLoading: Promise<void> | undefined = undefined;

  private async ensureIdentity(): Promise<void> {
    if (this.identity.fingerprint) return;
    if (!this.identityLoading) this.identityLoading = this.identity.load(this.store);
    try { await this.identityLoading; } finally { this.identityLoading = undefined; }
  }

  private async request(peer: Peer, method: string, path: string, body: string = '', token: Cancellation = new Cancellation(), timeoutMs: number = 120000): Promise<HttpReply> {
    if (peer.protocol === 'https') await this.ensureIdentity();
    return request(peer, method, path, body, token, timeoutMs, this.identity);
  }

  private async exchange(peer: Peer, method: string, path: string, size: number, produce: BodyProducer, token: Cancellation): Promise<HttpReply> {
    if (peer.protocol === 'https') await this.ensureIdentity();
    return exchange(peer, method, path, size, produce, token, 120000, this.identity);
  }
  private multicast: DiscoveryMulticast = new DiscoveryMulticast((message: socket.SocketMessageInfo) => this.discovered(message),
    (message: string) => this.store.log(message));
  private scan: DiscoveryScan = new DiscoveryScan();
  private discoveryGeneration: number = 0;
  private discoveryNetworks: string = '';
  private discoveryFallback: number = -1;
  private lastDiscoveryRebind: number = 0;
  private discoveryQuietUntil: number = 0;
  private discoveryTokens: Set<Cancellation> = new Set();
  private registering: Set<string> = new Set();
  private registrationRetries: Map<string, Peer> = new Map();
  private lastRegistrationRetry: number = 0;
  private tcp6: socket.TCPSocketServer | undefined = undefined;
  private tls6: SecureServer | undefined = undefined;
  private ipv6Starting: Promise<void> | undefined = undefined;
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

  constructor(store: AppStore) {
    this.store = store;
    this.store.onSelectionActivity = (active: boolean): void => {
      if (active) {
        this.scan.cancel(false);
        if (this.discoveryFallback !== -1) clearTimeout(this.discoveryFallback);
        this.discoveryFallback = -1;
      } else {
        // Leave time for the picker dismissal and selected-file UI to render.
        this.discoveryQuietUntil = Date.now() + 3000;
      }
    };
  }

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

  resetDiscovery(): Promise<void> {
    return this.scheduleLifecycle(async (): Promise<void> => {
      if (!this.running || !this.scanAvailable() || this.store.webUrl) return;
      await this.stopNow();
      this.store.peers = [];
      this.store.peerEndpoints = [];
      try { await this.store.clearDiscoveryAddresses(); }
      catch (error) { this.store.log(`清除发现缓存失败：${(error as Error).message}`); }
      this.store.log('开始无缓存发现');
      await this.startNow();
    });
  }

  private async startNow(): Promise<void> {
    if (this.store.identityResetting || this.paused || this.running || this.starting || !this.store.ready) return;
    this.starting = true; this.store.serverStatus = '正在启动接收服务';
    this.store.listenerPort = this.store.settings.port; this.store.listenerHttps = this.store.settings.https;
    this.store.listenerMulticast = this.store.settings.multicast;
    try {
      await this.ensureIdentity();
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
      await this.startIpv6();
      await this.multicast.sync(this.store.interfaces, this.store.listenerMulticast, this.store.listenerPort, !!this.tcp6 || !!this.tls6);
      this.lastDiscoveryRebind = Date.now();
      await this.announce();
      // The first multicast can precede Wi-Fi readiness or another peer's listener.
      // Retry without requiring a tap and refresh addresses on subsequent scans.
      this.discoveryRetries = [800, 2500, 6000].map((delay: number) =>
        setTimeout(() => { if (this.running) this.discover(false).catch((error: Error) => this.store.log(`自动发现：${error.message}`)); }, delay));
      this.timer = setInterval(() => {
        this.checkReceiveIdle();
        this.discover(false).catch((error: Error) => this.store.log(`自动发现：${error.message}`));
      }, 15000);
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
    this.lastDiscoveryRebind = 0;
    if (this.receiving && ['waiting', 'transferring', 'error'].includes(this.receiving.view.status)) this.cancel(this.receiving.id);
    for (const id of Array.from(this.sendSessions.keys())) { if (!this.sending.has(id)) this.cancel(id); }
    for (const channel of this.channels) channel.close(); this.channels = [];
    this.discoveryGeneration++;
    if (this.discoveryFallback !== -1) clearTimeout(this.discoveryFallback);
    this.discoveryFallback = -1; this.scan.cancel();
    for (const token of this.discoveryTokens) token.cancel();
    this.discoveryTokens.clear(); this.registering.clear(); this.registrationRetries.clear();
    await this.multicast.close();
    await this.ipv6Starting;
    await this.tcp6?.close().catch(() => {}); this.tcp6 = undefined;
    await this.tls6?.close().catch(() => {}); this.tls6 = undefined;
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

  private async startIpv6(): Promise<void> {
    if (this.tcp6 || this.tls6) return;
    if (!this.ipv6Starting) this.ipv6Starting = this.startIpv6Now();
    try { await this.ipv6Starting; } finally { this.ipv6Starting = undefined; }
  }

  private async startIpv6Now(): Promise<void> {
    const address: socket.NetAddress = { address: '::', port: this.store.listenerPort, family: 2 };
    try {
      if (this.store.listenerHttps) {
        this.tls6 = new SecureServer();
        await this.tls6.listen(address, this.identity.certificate, this.identity.privateKey,
          (client: SecureConnection) => this.newChannel().attachTls(client), (error: Error) => this.store.log(`IPv6 接收：${error.message}`));
      } else {
        this.tcp6 = socket.constructTCPSocketServerInstance();
        await this.tcp6.listen(address);
        this.tcp6.on('connect', (client: socket.TCPSocketConnection) => this.newChannel().attachTcp(client));
        this.tcp6.on('error', (error) => this.store.log(`IPv6 接收错误 ${error.code}`));
      }
      this.store.log('IPv6 接收已就绪');
    } catch (error) {
      await this.tcp6?.close().catch(() => {}); this.tcp6 = undefined;
      await this.tls6?.close().catch(() => {}); this.tls6 = undefined;
      this.store.log(`IPv6 接收不可用，保留 IPv4：${(error as Error).message}`);
    }
  }

  private async discoverPeer(peer: Peer): Promise<void> {
    if (this.discoveryTokens.size >= 16) return;
    const token = new Cancellation(); this.discoveryTokens.add(token);
    try { await this.probe(peer, token); }
    finally { this.discoveryTokens.delete(token); }
  }

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
    const interfaces: LocalInterface[] = [];
    let read = false;
    try {
    for (const net of await connection.getAllNets()) {
      try {
      const props = await connection.getConnectionProperties(net);
      for (const link of props.linkAddresses) {
        const ip = link.address.address;
        const local = new LocalInterface(); local.name = props.interfaceName; local.ip = ip; local.prefixLength = link.prefixLength;
        interfaces.push(local);
      }
      } catch (error) { this.store.log(`读取单个网络失败：${(error as Error).message}`); }
    }
    read = true;
    } catch (error) { this.store.log(`读取连接网络失败：${(error as Error).message}`); }
    // Tethering/downstream interfaces may have no NetHandle. Enumerate OS links
    // as well so hotspot discovery does not depend on an upstream Wi-Fi network.
    try {
      for (const link of native.networkInterfaces()) {
        const existing = interfaces.find((local: LocalInterface) => local.name === link.name && local.ip.split('%')[0] === link.ip.split('%')[0]);
        if (existing) {
          if (link.ip.includes('%')) existing.ip = link.ip;
          if (link.prefixLength > 0) existing.prefixLength = link.prefixLength;
        } else {
          const local = new LocalInterface(); local.name = link.name; local.ip = link.ip; local.prefixLength = link.prefixLength;
          interfaces.push(local);
        }
      }
      read = true;
    } catch (error) { this.store.log(`读取系统网卡失败：${(error as Error).message}`); }
    if (!read) throw new Error('无法读取本机网络');
    const usable = interfaces.filter((local: LocalInterface) =>
      (ipv4(local.ip) && !local.ip.startsWith('127.') && !local.ip.startsWith('0.') && Number(local.ip.split('.')[0]) < 224) ||
      (ipv6(local.ip) && local.ip !== '::' && local.ip !== '::1' && !local.ip.toLowerCase().startsWith('ff')));
    for (const local of usable) {
      const ips = usable.filter((item: LocalInterface) => item.name === local.name).map((item: LocalInterface) => item.ip);
      local.ignored = ignoredInterface(ips, this.store.settings.networkFilter, this.store.settings.networkPatterns);
    }
    this.store.interfaces = usable;
    this.store.localIps = Array.from(new Set(usable.filter((local: LocalInterface) => !local.ignored && ipv4(local.ip)).map((local: LocalInterface) => local.ip)));
  }

  async announce(): Promise<void> {
    if (!this.store.settings.visible || !this.running) return;
    if (this.store.settings.networkFilter !== 'none' && !this.store.interfaces.some((local: LocalInterface) => !local.ignored)) return;
    this.multicast.send(encodeText(JSON.stringify(this.info(true))));
  }

  async discover(notify: boolean = true, rebind: boolean = false): Promise<void> {
    if (this.store.selecting || (!notify && Date.now() < this.discoveryQuietUntil)) return;
    if (this.paused) {
      if (notify) this.store.notice = '接收服务已暂停，请在设置中启动';
      return;
    }
    if (!this.running) await this.start();
    if (!this.running) return;
    let generation = this.discoveryGeneration;
    await this.readAddresses().catch((error: Error) => this.store.log(`读取发现网络失败：${error.message}`));
    if (!this.running || generation !== this.discoveryGeneration) return;
    const networks = this.store.interfaces.map((local: LocalInterface) => `${local.name}:${local.ip}/${local.prefixLength}:${local.ignored}`).sort().join('|');
    if (networks !== this.discoveryNetworks) {
      this.discoveryNetworks = networks; generation = ++this.discoveryGeneration;
      this.scan.cancel();
      if (this.discoveryFallback !== -1) clearTimeout(this.discoveryFallback);
      this.discoveryFallback = -1;
      for (const token of this.discoveryTokens) token.cancel();
      this.discoveryTokens.clear(); this.registering.clear(); this.registrationRetries.clear();
    }
    if (this.store.interfaces.some((local: LocalInterface) => !local.ignored && local.ip.includes(':'))) await this.startIpv6();
    if (!this.running || generation !== this.discoveryGeneration) return;
    // Some Wi-Fi transitions silently drop multicast membership without changing
    // the IP or closing the socket. Refresh discovery listeners periodically.
    const renew = rebind || Date.now() - this.lastDiscoveryRebind >= 60000;
    await this.multicast.sync(this.store.interfaces, this.store.listenerMulticast, this.store.listenerPort, !!this.tcp6 || !!this.tls6, renew);
    if (renew) this.lastDiscoveryRebind = Date.now();
    if (!this.running || generation !== this.discoveryGeneration) return;
    await this.announce().catch((e: Error) => {
      if (notify) this.store.fail('发现设备失败', e); else this.store.log(`自动发现：${e.message}`);
    });
    if (notify) this.store.notice = '已发送发现请求';
    this.store.networkLog('discovery', `发现广播 · ${this.store.localIps.join(', ')}`);
    for (const peer of this.store.favorites) this.discoverPeer(peer).catch(() => {});
    if (this.scanAvailable() && Date.now() - this.lastRegistrationRetry >= 15000) {
      this.lastRegistrationRetry = Date.now();
      for (const peer of Array.from(this.registrationRetries.values()).slice(0, 2)) this.answerAnnouncement(peer, true);
    }
    if (this.discoveryFallback === -1) {
      this.discoveryFallback = setTimeout(() => {
        this.discoveryFallback = -1;
        if (!this.running || generation !== this.discoveryGeneration || !this.scanAvailable()) return;
        // One responding device says nothing about missing peers. DiscoveryScan
        // runs short, paced batches and retains its position while busy.
        this.scan.run(this.store.interfaces, this.store.listenerPort, this.store.favorites,
          async (peer: Peer, token: Cancellation): Promise<void> => {
            if (!this.scanAvailable()) { this.scan.cancel(false); token.check(); }
            await this.probe(peer, token);
          }, notify, () => this.running && this.scanAvailable(),
          this.store.discoveryAddresses.filter((address: string) => address.endsWith(`:${this.store.listenerPort}`))
            .map((address: string) => address.slice(0, address.lastIndexOf(':'))),
          (peer: Peer, token: Cancellation): Promise<boolean> => this.scanPortOpen(peer, token))
          .catch((error: Error) => this.store.log(`子网发现：${error.message}`));
      }, 1500);
    }
  }

  private scanAvailable(): boolean {
    return !this.store.busy && !this.store.selecting && !this.store.activeTransfers &&
      !this.store.transfers.some((item: TransferView) => item.hashing) &&
      !this.store.webStarting && !this.store.webTemplateBusy && this.store.webRequests.length === 0 &&
      Date.now() >= this.discoveryQuietUntil;
  }

  private async scanPortOpen(peer: Peer, token: Cancellation): Promise<boolean> {
    if (!this.scanAvailable()) { this.scan.cancel(false); token.check(); }
    return discoveryPortOpen(peer, token);
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
      // v2.2 announcements need not carry the legacy v2.0 announce flag.
      if ((info.announce === true || (info.announce === undefined && Number(info.version) >= 2.2)) && this.store.settings.visible && this.running) {
        this.answerAnnouncement(peer);
      }
    } catch (_) { /* Ignore malformed UDP datagrams from unrelated applications. */ }
  }

  private answerAnnouncement(peer: Peer, retry: boolean = false): void {
    if (!this.running || !this.store.settings.visible) return;
    const key = `${peer.ip}:${peer.port}:${peer.fingerprint}`;
    if (this.registering.has(key) || this.registering.size >= 16) return;
    this.registering.add(key); this.registrationRetries.delete(key);
    const generation = this.discoveryGeneration;
    const token = new Cancellation(); this.discoveryTokens.add(token);
    // A failed startup handshake must not depend on another UDP announcement.
    // Retry only a bounded number of known endpoints, yielding to foreground work.
    const monitor = retry ? setInterval(() => { if (!this.scanAvailable()) token.cancel(); }, 100) : -1;
    this.register(peer, token).catch((error: Error) => {
      this.store.log(`设备握手 ${peer.ip}:${peer.port}：${error.message}`);
      if (this.running && generation === this.discoveryGeneration && !(error instanceof PeerIdentityError) && this.registrationRetries.size < 16) {
        this.registrationRetries.set(key, peer);
      }
    }).finally(() => {
      if (monitor !== -1) clearInterval(monitor);
      this.discoveryTokens.delete(token);
      if (generation === this.discoveryGeneration) this.registering.delete(key);
    });
  }

  private peerFrom(info: DeviceInfo, ip: string): Peer {
    const peer = new Peer(); peer.alias = String(info.alias || ip).slice(0, 100); peer.ip = ip;
    peer.version = info.version || '1.0';
    peer.port = Number.isInteger(info.port) && info.port > 0 && info.port <= 65535 ? info.port : 53317;
    peer.protocol = info.protocol === 'http' ? 'http' : 'https'; peer.fingerprint = info.fingerprint || '';
    peer.deviceModel = info.deviceModel || ''; peer.deviceType = info.deviceType || 'desktop'; return peer;
  }

  private upsertPeer(peer: Peer, verified: boolean = false): void {
    if (peer.fingerprint.toLowerCase() === this.store.settings.fingerprint.toLowerCase()) return;
    // Retain endpoints so changing display mode never needs another discovery.
    this.store.peerEndpoints = [peer, ...this.store.peerEndpoints.filter((item: Peer) => item.ip !== peer.ip || item.port !== peer.port)].slice(0, 100);
    this.store.peers = [peer, ...this.store.peers.filter((item: Peer) => !samePeer(item, peer) && (item.ip !== peer.ip || item.port !== peer.port))].slice(0, 100);
    let favoritesChanged = false;
    if (verified) {
      if (ipv4(peer.ip)) this.store.rememberDiscoveryAddress(`${peer.ip}:${peer.port}`);
      this.store.favorites = this.store.favorites.map((item: Peer) => {
        if (!samePeer(item, peer) || (item.protocol === 'https' && peer.protocol !== 'https')) return item;
        const alias = item.customAlias !== false ? item.alias : peer.alias;
        if (item.ip === peer.ip && item.port === peer.port && item.protocol === peer.protocol && item.alias === alias) return item;
        const updated = JSON.parse(JSON.stringify(peer)) as Peer;
        updated.alias = alias; updated.customAlias = item.customAlias !== false;
        favoritesChanged = true; return updated;
      });
      if (favoritesChanged) this.store.save();
    }
  }

  private async register(peer: Peer, cancellation: Cancellation = new Cancellation()): Promise<void> {
    const started = Date.now();
    await this.ensureIdentity();
    let result: HttpReply;
    try {
      result = await this.request(peer, 'POST', `/api/localsend/${peer.version === '1.0' ? 'v1' : 'v2'}/register`, JSON.stringify(this.info()), cancellation, this.store.settings.discoveryTimeout);
      if (result.status === 404 && peer.version !== '1.0') {
        result = await this.request(peer, 'POST', '/api/localsend/v1/register', JSON.stringify(this.info()), cancellation, this.store.settings.discoveryTimeout);
      }
    } catch (error) {
      if (peer.protocol !== 'http' || (error as Error).message !== '设备提前关闭了连接') throw error as Error;
      const secure = await this.verifyHttpsPeer(peer, cancellation);
      if (this.store.settings.visible) await this.register(secure, cancellation); return;
    }
    cancellation.check();
    if (result.status !== 200) throw new Error(`设备返回 ${result.status}`);
    if (result.status === 200) {
      const info = JSON.parse(result.body) as DeviceInfo;
      if (!info || typeof info.alias !== 'string' || (!result.fingerprint && !info.fingerprint)) throw new Error('设备返回了无效响应');
      const known = this.peerFrom(info, peer.ip); known.port = peer.port; known.protocol = peer.protocol;
      if (result.fingerprint) known.fingerprint = result.fingerprint;
      this.upsertPeer(known, !!result.fingerprint || known.protocol === 'http');
      const message = `主动注册成功 · ${known.alias} · ${known.ip}:${known.port} · ${known.protocol} · ${Date.now() - started} ms`;
      this.store.networkLog('discovery', message); this.store.log(message);
    }
  }

  async probe(peer: Peer, cancellation: Cancellation = new Cancellation()): Promise<void> {
    // Registration exchanges both identities in one connection (also on 1.18).
    // Hidden devices retain read-only discovery and do not announce themselves.
    if (this.store.settings.visible) { await this.register(peer, cancellation); return; }
    let reply: HttpReply;
    try {
      reply = await this.request(peer, 'GET', '/api/localsend/v2/info', '', cancellation, this.store.settings.discoveryTimeout);
    } catch (error) {
      if (peer.protocol !== 'http' || (error as Error).message !== '设备提前关闭了连接') throw error as Error;
      const secure = await this.verifyHttpsPeer(peer, cancellation);
      if (this.store.settings.visible) await this.register(secure, cancellation); return;
    }
    if (reply.status === 404) reply = await this.request(peer, 'GET', '/api/localsend/v1/info', '', cancellation, this.store.settings.discoveryTimeout);
    cancellation.check();
    if (reply.status !== 200) throw new Error(`设备返回 ${reply.status}`);
    const info = JSON.parse(reply.body) as DeviceInfo;
    if (!info || typeof info.alias !== 'string' || (!reply.fingerprint && !info.fingerprint)) throw new Error('设备返回了无效响应');
    const known = this.peerFrom(info, peer.ip); known.port = peer.port; known.protocol = peer.protocol;
    if (reply.fingerprint) known.fingerprint = reply.fingerprint;
    this.upsertPeer(known, !!reply.fingerprint || known.protocol === 'http');
    if (this.store.settings.visible) await this.register(known, cancellation);
  }

  private async verifyHttpsPeer(peer: Peer, cancellation: Cancellation): Promise<Peer> {
    const secure = JSON.parse(JSON.stringify(peer)) as Peer; secure.protocol = 'https';
    let reply = await this.request(secure, 'GET', '/api/localsend/v2/info', '', cancellation, this.store.settings.discoveryTimeout);
    if (reply.status === 404) reply = await this.request(secure, 'GET', '/api/localsend/v1/info', '', cancellation, this.store.settings.discoveryTimeout);
    cancellation.check();
    if (reply.status !== 200) throw new Error(`设备返回 ${reply.status}`);
    const info = JSON.parse(reply.body) as DeviceInfo;
    if (!info || typeof info.alias !== 'string' || !reply.fingerprint) throw new Error('设备返回了无效响应');
    cancellation.check();
    const known = this.peerFrom(info, peer.ip);
    known.port = peer.port; known.protocol = 'https'; known.fingerprint = reply.fingerprint;
    this.upsertPeer(known, true);
    this.store.networkLog('discovery', `${known.alias} · ${known.ip}:${known.port} · HTTPS 已验证，更新旧 HTTP 记录`);
    return known;
  }

  async addAddress(address: string): Promise<void> {
    try {
      const parsed = parseAddress(address);
      const peer = new Peer(); peer.ip = parsed.ip; peer.port = parsed.port; peer.protocol = parsed.protocol;
      try { await this.probe(peer); }
      catch (e) {
        if (parsed.explicitProtocol || e instanceof PeerIdentityError) throw e as Error;
        this.store.log(`地址探测 HTTPS 失败：${(e as Error).message}`);
        peer.protocol = 'http'; await this.probe(peer);
      }
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
        this.upsertPeer(this.peerFrom(info, channel.ip));
        await channel.respond(200, JSON.stringify(this.info()));
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
      if (file.sha256 !== undefined && (typeof file.sha256 !== 'string' || !/^[a-fA-F0-9]{64}$/.test(file.sha256))) throw new Error('文件校验和无效');
      const view = new TransferFile(); view.id = id; view.originalName = file.fileName;
      view.name = uniqueName(safeRelativePath(file.fileName), session.view.files.map((item: TransferFile) => item.name)); view.size = file.size;
      if (file.preview && file.fileType === 'text/plain') { view.name = file.fileName.slice(0, 100); view.preview = file.preview.slice(0, 100000); }
      session.view.files.push(view);
    }
    this.receiving = session; this.store.updateTransfer(session.view); this.upsertPeer(session.peer);
    this.store.updateIncomingHistory(session.view, true);
    channel.onClosed = () => {
      if (!session.accepted) {
        session.cancelled = true; session.resolve(false);
        if (session.view.status === 'waiting') {
          session.view.status = 'cancelled'; session.view.finished = Date.now();
          this.store.updateTransfer(session.view); this.store.updateIncomingHistory(session.view);
        }
      }
    };
    let automatic = this.store.settings.quickSave;
    if (!automatic && this.store.settings.favoriteQuickSave && channel.encrypted && session.peer.protocol === 'https' &&
      this.store.favorites.some((peer: Peer) => !!peer.fingerprint && peer.fingerprint === session.peer.fingerprint)) {
      // A fingerprint in JSON is only a claim. Prove possession of the matching
      // TLS identity at the sender address before bypassing receive consent.
      try { automatic = (await this.request(session.peer, 'GET', '/api/localsend/v2/info')).status === 200; }
      catch (_) { this.store.log('收藏身份验证失败，转为手动确认'); }
    }
    if (channel.closed || session.cancelled) {
      session.view.status = 'cancelled'; session.view.finished = Date.now();
      for (const file of session.view.files) { if (file.status === 'waiting') file.status = 'cancelled'; }
      this.store.updateTransfer(session.view); await this.store.updateIncomingHistory(session.view); return;
    }
    if (!automatic) {
      this.store.pendingReceive = session.id;
      const accepted = await new Promise<boolean>((resolve) => {
        const timer = setTimeout(() => resolve(false), 120000);
        session.resolve = (value: boolean) => { clearTimeout(timer); resolve(value); };
      });
      if (this.store.pendingReceive === session.id) this.store.pendingReceive = '';
      if (!accepted || session.cancelled || channel.closed) {
        session.view.status = session.cancelled || channel.closed ? 'cancelled' : 'declined'; session.view.finished = Date.now();
        for (const file of session.view.files) {
          if (file.status === 'waiting') file.status = file.selected ? session.view.status : 'skipped';
        }
        this.store.updateTransfer(session.view); await this.store.updateIncomingHistory(session.view); await channel.respond(403); return;
      }
    }
    session.accepted = true;
    const selected = session.view.files.filter((file: TransferFile) => file.selected);
    if (!selected.length) {
      session.view.status = 'declined'; session.view.finished = Date.now();
      for (const file of session.view.files) file.status = 'skipped';
      this.store.updateTransfer(session.view); await this.store.updateIncomingHistory(session.view); await channel.respond(403); return;
    }
    if (!session.legacy && selected.every((file: TransferFile) => !!session.files[file.id].preview && session.files[file.id].fileType === 'text/plain')) {
      for (const file of selected) {
        const entry = new HistoryEntry(); entry.name = file.name; entry.text = session.files[file.id].preview!;
        entry.peer = session.peer.alias; entry.peerInfo = session.peer; entry.size = encodeText(entry.text).length;
        file.status = 'complete'; file.transferred = file.size;
        await this.store.completeIncomingHistory(entry, session.view, file);
      }
      session.view.status = 'complete'; session.view.finished = Date.now(); this.store.updateTransfer(session.view);
      await this.store.updateIncomingHistory(session.view); await channel.respond(204); return;
    }
    const tokens: Record<string, string> = {};
    for (const file of selected) tokens[file.id] = util.generateRandomUUID();
    session.tokens = tokens; session.lastActivity = Date.now(); session.view.status = 'transferring'; this.store.updateTransfer(session.view);
    await this.store.updateIncomingHistory(session.view);
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
    if (!this.receiving || this.receiving.accepted) return;
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
      file.selected = true;
    }
    this.store.updateTransfer(session.view);
  }

  batchRenameReceive(mode: string, prefix: string, padZero: boolean, sortFirst: boolean, sessionId: string = ''): boolean {
    const session = this.receiving; if (!session || session.accepted) return false;
    if (sessionId && session.id !== sessionId) return false;
    try {
      session.view.files = batchReceiveNames(session.view.files, mode, prefix, padZero, sortFirst);
      this.store.updateTransfer(session.view); return true;
    } catch (e) { this.store.fail('批量重命名失败', e as Error); return false; }
  }

  renameReceive(id: string, name: string, sessionId: string = ''): boolean {
    if (!this.receiving || this.receiving.accepted) return false;
    if (sessionId && this.receiving.id !== sessionId) return false;
    const file = this.receiving.view.files.find((item: TransferFile) => item.id === id);
    if (!file) return false;
    try {
      const safe = receiveName(name, this.receiving.files[id].fileName);
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
    if (info?.sha256 && (session.attempts[fileId] || 0) >= 3) {
      await channel.respond(403); return new JsonSink(async () => {});
    }
    if (!info || !view || session.cleaning.has(fileId) || !['waiting', 'error'].includes(view.status) || (!head.chunked && head.contentLength !== info.size)) {
      await channel.respond(400); return new JsonSink(async () => {});
    }
    const sink = new UploadSink(this, session, info, view, channel);
    session.attempts[fileId] = (session.attempts[fileId] || 0) + 1;
    view.status = 'transferring'; session.uploads.push(channel);
    try {
      await this.store.updateIncomingHistory(session.view);
      await sink.init();
      if (session.cancelled || channel.closed) throw new Error('接收已取消');
      return sink;
    } catch (error) {
      const failure = new Error(this.store.t(storageError(error as Error)));
      if (!session.cancelled && !channel.closed) channel.failureStatus = 500;
      channel.failureReason = failure.message;
      await sink.abort(); throw failure;
    }
  }

  finishReceiveFile(session: ReceiveSession): void {
    session.lastActivity = Date.now();
    if (session.cancelled) return;
    const selected = session.view.files.filter((file: TransferFile) => file.selected);
    if (selected.every((file: TransferFile) => file.status === 'complete' || file.status === 'error')) {
      const failed = selected.find((file: TransferFile) => file.status === 'error');
      session.view.status = failed ? 'error' : 'complete'; session.view.error = failed ? failed.error : '';
      session.view.finished = Date.now();
      if (!failed) this.store.notice = session.view.storageNotice || `已收到 ${session.peer.alias} 的文件`;
    }
    this.store.updateTransfer(session.view);
    this.store.updateIncomingHistory(session.view);
  }

  async failReceiveFile(session: ReceiveSession, file: TransferFile, channel: NativeConnection): Promise<void> {
    if (session.cancelled) return;
    file.status = 'error'; file.path = '';
    session.lastActivity = Date.now();
    if (!session.view.files.some((item: TransferFile) => item.status === 'transferring')) {
      session.view.status = 'error'; session.view.error = file.error; session.view.finished = Date.now();
    }
    this.store.updateTransfer(session.view);
    await this.store.updateIncomingHistory(session.view);
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
    const fileFailed = session.view.files.some((file: TransferFile) => !!file.error);
    for (const file of session.view.files) {
      if (file.selected && (file.status === 'waiting' || file.status === 'transferring')) {
        if (!file.error) {
          file.error = fileFailed ? (file.status === 'waiting' ? '任务已停止，此文件尚未开始传输' : '任务已停止，此文件接收未完成') : message;
        }
        file.status = status;
      }
    }
    if (this.store.pendingReceive === session.id) this.store.pendingReceive = '';
    this.store.updateTransfer(session.view);
    this.store.updateIncomingHistory(session.view);
    if (notifyPeer && session.accepted) session.stopNotification = this.notifyCancel(session.peer, session.id, session.legacy);
    // Give the control request priority over a socket EOF. Flutter only accepts
    // receiver cancellation while its send session is still active.
    session.stopNotification.then(() => {
      for (const channel of session.uploads) { if (channel !== respondingChannel) channel.close(); }
    });
  }

  private async notifyCancel(peer: Peer, sessionId: string, legacy: boolean): Promise<void> {
    const path = legacy ? '/api/localsend/v1/cancel' : `/api/localsend/v2/cancel?sessionId=${encodeURIComponent(sessionId)}`;
    // A new TLS handshake can take more than one second on a busy receiver.
    // Retry transport failures once, preserving protocol, identity and session.
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const reply = await this.request(peer, 'POST', path, '', new Cancellation(), 4000);
        if (reply.status === 200) { this.store.log('对方已确认终止传输'); return; }
        this.store.log(`终止通知未被对方接受：HTTP ${reply.status}`);
        break;
      } catch (error) {
        this.store.log(`终止通知发送失败：${(error as Error).message}`);
        if (error instanceof PeerIdentityError || legacy) break;
      }
    }
    this.store.notice = this.store.t('本端已停止，但未收到对方的终止确认。若 Windows 端仍在发送，请在对方取消任务；切换过加密设置时请退出并重新打开 LocalSend。');
  }

  private cancelByPeer(ip: string, remoteId: string, legacy: boolean): boolean {
    const session = this.receiving;
    if (session && session.ip === ip && !session.cancelled && ['waiting', 'transferring', 'error'].includes(session.view.status) &&
      (legacy ? session.legacy : session.id === remoteId || (!session.accepted && !remoteId))) {
      this.cancel(session.id, false); return true;
    }
    const matching: string[] = [];
    for (const entry of this.sendSessions.entries()) {
      if (entry[1].peer.ip === ip && (legacy ? entry[1].legacy : !!remoteId && entry[1].remoteId === remoteId)) matching.push(entry[0]);
    }
    if (matching.length !== 1) return false;
    const id = matching[0]; const cancellation = this.sending.get(id);
    cancellation?.cancel('对方终止了传输');
    const context = this.retryContexts.get(id); if (context) context.accepted = undefined;
    this.sendSessions.delete(id);
    const transfer = this.store.transfers.find((item: TransferView) => item.id === id);
    if (transfer) {
      transfer.status = 'cancelled'; transfer.error = '对方终止了传输'; transfer.finished = Date.now();
      for (const file of transfer.files) { if (file.status === 'waiting' || file.status === 'transferring') file.status = 'cancelled'; }
      this.store.updateTransfer(transfer);
      if (context) this.store.updateOutgoingHistory(transfer, context.files);
    }
    return true;
  }

  cancel(id: string, notifyPeer: boolean = true): void {
    this.sending.get(id)?.cancel();
    const context = this.retryContexts.get(id); if (context) context.accepted = undefined;
    if (this.store.pendingPin === id) this.submitPin('');
    const sending = this.sendSessions.get(id);
    if (sending && notifyPeer) this.notifyCancel(sending.peer, sending.remoteId, sending.legacy);
    this.sendSessions.delete(id);
    if (this.receiving?.id === id) {
      this.endReceive(this.receiving, 'cancelled', '', notifyPeer);
    }
  }

  submitPin(pin: string): void { this.pinResolver?.(pin); this.pinResolver = undefined; this.store.pendingPin = ''; this.store.pendingPinInvalid = false; }

  async send(peer: Peer, selectedFiles: ShareFile[] = this.store.files, keepSelection: boolean = false, resumeId: string = ''): Promise<string> {
    if (this.store.identityResetting) { this.store.notice = '正在重置证书，请稍后'; return ''; }
    if (!selectedFiles.length) { this.store.notice = '请先选择文件或输入文字'; return ''; }
    if (this.sending.size >= 4) { this.store.notice = '已有 4 项发送任务，请等待完成后再发送'; return ''; }
    const resumed = resumeId ? this.retryContexts.get(resumeId) : undefined;
    const existing = resumeId ? this.store.transfers.find((item: TransferView) => item.id === resumeId) : undefined;
    if (resumeId && (!existing || !resumed?.accepted || this.sending.has(resumeId))) return '';
    const files = selectedFiles.slice(); const transfer = existing || new TransferView();
    if (!existing) transfer.id = util.generateRandomUUID();
    const context = resumed || new RetryContext(peer, files, keepSelection || this.store.settings.sendMode === 'multiple');
    context.remoteExpired = false;
    this.retryContexts.set(transfer.id, context);
    transfer.error = ''; transfer.finished = 0;
    if (this.retryContexts.size > 40) {
      for (const id of this.retryContexts.keys()) {
        if (!this.sending.has(id) && id !== transfer.id) {
          const remote = this.sendSessions.get(id);
          if (remote) this.notifyCancel(remote.peer, remote.remoteId, remote.legacy);
          this.sendSessions.delete(id); this.retryContexts.delete(id); break;
        }
      }
    }
    transfer.peer = peer.alias; transfer.encrypted = peer.protocol === 'https';
    transfer.peerInfo = peer;
    const fileInfos: Record<string, FileInfo> = {};
    for (const file of files) {
      if (!existing) {
        const view = new TransferFile(); view.id = file.id; view.name = file.name; view.size = file.size; transfer.files.push(view);
      }
      const info: FileInfo = { id: file.id, fileName: file.text ? 'message.txt' : file.name, size: file.size, fileType: file.mime };
      if (file.text) info.preview = file.text;
      fileInfos[file.id] = info;
    }
    this.store.updateTransfer(transfer);
    const cancellation = new Cancellation(); this.sending.set(transfer.id, cancellation);
    let declined = false;
    try {
      await this.ensureIdentity();
      await this.store.updateOutgoingHistory(transfer, files, true);
      cancellation.check();
      const favorite = this.store.favorites.find((item: Peer) => item.ip === peer.ip && item.port === peer.port);
      if (favorite?.fingerprint && favorite.fingerprint !== peer.fingerprint) throw new Error('收藏设备的身份已改变，请核对后重新收藏');
      const payload: PrepareRequest = { info: this.info(), files: fileInfos };
      if (this.store.settings.createChecksums && !resumed?.accepted) {
        transfer.hashing = true; transfer.hashedBytes = 0; this.store.updateTransfer(transfer);
        let completed = 0; let lastProgress = 0;
        try {
          for (const file of files) {
            try {
            fileInfos[file.id].sha256 = await fileChecksum(file.uri, file.size, file.text, cancellation, (bytes: number) => {
              transfer.hashedBytes = completed + bytes;
              if (Date.now() - lastProgress > 100) { lastProgress = Date.now(); this.store.updateTransfer(transfer); }
            });
            } catch (error) {
              cancellation.check();
              this.store.log(`无法计算文件校验和，继续发送请求：${file.name} · ${(error as Error).message}`);
            }
            completed += file.size;
            transfer.hashedBytes = completed;
          }
        } finally { transfer.hashing = false; this.store.updateTransfer(transfer); }
      }
      let legacy = resumed ? resumed.legacy : peer.version === '1.0';
      let preparePath = legacy ? '/api/localsend/v1/send-request' : '/api/localsend/v2/prepare-upload';
      let response = new HttpReply();
      if (resumed?.accepted) {
        response.status = 200; response.body = JSON.stringify(legacy ? resumed.accepted.files : resumed.accepted);
      } else {
        try { response = await this.request(peer, 'POST', preparePath, JSON.stringify(payload), cancellation); }
        catch (error) {
          // A stale HTTP advertisement can point at an HTTPS-only listener.
          // Verify with a read-only TLS request before repeating the offer;
          // never downgrade HTTPS or retry an upload body.
          if (peer.protocol !== 'http' || (error as Error).message !== '设备提前关闭了连接') throw error as Error;
          peer = await this.verifyHttpsPeer(peer, cancellation);
          context.peer = peer; transfer.peerInfo = peer; transfer.encrypted = true;
          legacy = peer.version === '1.0'; context.legacy = legacy;
          preparePath = legacy ? '/api/localsend/v1/send-request' : '/api/localsend/v2/prepare-upload';
          response = await this.request(peer, 'POST', preparePath, JSON.stringify(payload), cancellation);
        }
      }
      if (response.status === 404 && !legacy) {
        legacy = true; preparePath = '/api/localsend/v1/send-request';
        response = await this.request(peer, 'POST', preparePath, JSON.stringify(payload), cancellation);
      }
      let pinSubmitted = false;
      while (response.status === 401) {
        if (this.store.pendingPin && this.store.pendingPin !== transfer.id) throw new Error('请先完成另一项传输的 PIN 确认，再重试此任务');
        this.store.pendingPin = transfer.id;
        this.store.pendingPinInvalid = pinSubmitted;
        const pin = await new Promise<string>((resolve) => { this.pinResolver = resolve; });
        if (!pin) { cancellation.cancel(); cancellation.check(); }
        pinSubmitted = true;
        response = await this.request(peer, 'POST', `${preparePath}?pin=${encodeURIComponent(pin)}`, JSON.stringify(payload), cancellation);
      }
      cancellation.check();
      if (response.status === 204) {
        for (const file of transfer.files) {
          const source = files.find((item: ShareFile) => item.id === file.id)!;
          file.status = source.text ? 'complete' : 'skipped'; file.transferred = source.text ? file.size : 0;
          file.selected = file.status !== 'skipped';
        }
      } else {
        if (response.status !== 200) {
          declined = response.status === 403;
          throw new Error(declined ? '对方拒绝了传输' : response.status === 409 ? '对方正在传输，请稍后重试' : response.status === 429 ? 'PIN 尝试次数过多' : `设备返回 ${response.status}`);
        }
        const prepared: PrepareReply = legacy ? { sessionId: 'legacy', files: JSON.parse(response.body) as Record<string, string> } : JSON.parse(response.body) as PrepareReply;
        if (!prepared.sessionId || !prepared.files) throw new Error('设备返回了无效传输会话');
        for (const entry of this.sendSessions.entries()) {
          if (entry[0] !== transfer.id && !this.sending.has(entry[0]) && samePeer(entry[1].peer, peer)) {
            const old = this.retryContexts.get(entry[0]); if (old) old.accepted = undefined;
            this.sendSessions.delete(entry[0]);
          }
        }
        context.accepted = prepared; context.legacy = legacy;
        // Freeze the accepted subset before publishing progress, as Flutter does.
        for (const view of transfer.files) {
          view.selected = !!prepared.files[view.id];
          if (!view.selected) view.status = 'skipped';
        }
        this.sendSessions.set(transfer.id, new SendSessionRef(peer, prepared.sessionId, legacy));
        transfer.activeStarted = Date.now(); transfer.activeBytes = 0;
        transfer.status = 'transferring'; this.store.updateTransfer(transfer);
        for (const file of files) {
          cancellation.check(); const view = transfer.files.find((item: TransferFile) => item.id === file.id)!;
          const token = prepared.files[file.id];
          if (!token) { view.status = 'skipped'; this.store.updateTransfer(transfer); continue; }
          view.status = 'transferring'; view.error = ''; view.transferred = 0; this.store.updateTransfer(transfer);
          await this.store.updateOutgoingHistory(transfer, files);
          cancellation.check();
          try {
          let lastUpdate = 0;
          const uploadPath = legacy ? `/api/localsend/v1/send?fileId=${encodeURIComponent(file.id)}&token=${encodeURIComponent(token)}` :
            `/api/localsend/v2/upload?sessionId=${encodeURIComponent(prepared.sessionId)}&fileId=${encodeURIComponent(file.id)}&token=${encodeURIComponent(token)}`;
          let upload = new HttpReply();
          for (let attempt = 0; attempt < 3; attempt++) {
          view.transferred = 0;
          upload = await this.exchange(peer, 'POST', uploadPath, file.size,
            async (write: ChunkWriter): Promise<void> => {
              if (file.text) { await write(encodeText(file.text)); view.transferred = file.size; transfer.activeBytes += file.size; return; }
              const source = await fs.open(file.uri, fs.OpenMode.READ_ONLY);
              try {
                let count = 0;
                while (count < file.size) {
                  cancellation.check(); const buffer = new ArrayBuffer(Math.min(65536, file.size - count));
                  const read = await fs.read(source.fd, buffer);
                  if (read <= 0) throw new Error('源文件读取不完整');
                  await write(new Uint8Array(buffer).slice(0, read)); count += read; view.transferred = count; transfer.activeBytes += read;
                  if (Date.now() - lastUpdate > 100) { this.store.updateTransfer(transfer); lastUpdate = Date.now(); }
                }
              } finally { await fs.close(source); }
            }, cancellation);
          if (upload.status !== 422) break;
          cancellation.check();
          }
          cancellation.check();
          if (upload.status === 500 || upload.status === 422) {
            // A receiver's per-file failure does not invalidate the accepted
            // batch. Continue other files unless its cancel callback says stop.
            view.status = 'error'; view.error = upload.status === 422 ? this.store.t('文件校验和不匹配') : `文件发送失败 ${upload.status}`;
            this.store.updateTransfer(transfer);
            await this.store.updateOutgoingHistory(transfer, files);
            continue;
          }
          if (upload.status !== 200) {
            context.remoteExpired = upload.status === 403 || upload.status === 404;
            throw new Error(`文件发送失败 ${upload.status}`);
          }
          view.status = 'complete'; view.transferred = file.size; this.store.updateTransfer(transfer);
          await this.store.updateOutgoingHistory(transfer, files);
          } catch (error) {
            cancellation.check();
            if (error instanceof PeerIdentityError || context.remoteExpired) throw error as Error;
            view.status = 'error'; view.error = (error as Error).message;
            this.store.updateTransfer(transfer);
            await this.store.updateOutgoingHistory(transfer, files);
          }
        }
      }
      cancellation.check();
      const failed = transfer.files.find((file: TransferFile) => file.status === 'error');
      transfer.status = failed ? 'error' : 'complete'; transfer.error = failed ? failed.error : '';
      transfer.finished = Date.now();
      if (failed) this.store.log(`发送：${transfer.error}`);
      else this.store.notice = `已发送到 ${peer.alias}`;
    } catch (e) {
      context.accepted = undefined;
      const remote = this.sendSessions.get(transfer.id);
      if (remote && !cancellation.cancelled && !context.remoteExpired) this.notifyCancel(remote.peer, remote.remoteId, remote.legacy);
      transfer.status = cancellation.cancelled ? 'cancelled' : declined ? 'declined' : 'error'; transfer.error = (e as Error).message; transfer.finished = Date.now();
      const interruptedFile = transfer.files.some((file: TransferFile) => file.status === 'transferring');
      for (const file of transfer.files) {
        if (file.status === 'transferring' || file.status === 'waiting') {
          file.error = interruptedFile && file.status === 'waiting' ? '任务已停止，此文件尚未开始传输' : transfer.error;
          file.status = transfer.status;
        }
      }
      this.store.log(`发送：${transfer.error}`);
    } finally {
      this.sending.delete(transfer.id);
      if (transfer.status !== 'error' || !context.accepted) { context.accepted = undefined; this.sendSessions.delete(transfer.id); }
      this.store.updateTransfer(transfer);
      await this.store.updateOutgoingHistory(transfer, files, false, declined);
    }
    return transfer.id;
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
        await this.send(peer, files, true); this.store.batchRemaining--;
      }
    } finally { this.store.batchRemaining = 0; }
  }

  cancelAll(): void {
    this.batchCancelled = true;
    for (const id of this.sending.keys()) this.cancel(id);
  }

  finishCompletedSelections(): void {
    for (const transfer of this.store.transfers.slice()) {
      if (transfer.direction !== 'send' || transfer.status !== 'complete' || transfer.selectionClosed) continue;
      const context = this.retryContexts.get(transfer.id);
      if (!context) continue;
      if (!context.keepSelection) {
        const sent = new Map(context.files.map((file: ShareFile): [string, ShareFile] => [file.id, file]));
        this.store.files = this.store.files.filter((file: ShareFile) => {
          const original = sent.get(file.id);
          return !original || file.name !== original.name || file.uri !== original.uri || file.size !== original.size ||
            file.mime !== original.mime || file.text !== original.text;
        });
      }
      transfer.selectionClosed = true; this.store.updateTransfer(transfer);
    }
  }

  async retry(id: string, fileId: string = ''): Promise<void> {
    const context = this.retryContexts.get(id);
    const previous = this.store.transfers.find((transfer: TransferView) => transfer.id === id);
    if (!context || !previous) { this.store.notice = '请重新选择原文件后发送'; return; }
    if (previous.retrying || previous.retryTransferId || previous.direction !== 'send' ||
      (previous.status !== 'error' && previous.status !== 'cancelled')) return;
    const incomplete = previous.files.filter((file: TransferFile) => file.status !== 'complete' && file.status !== 'skipped' &&
      !file.retryTransferId && (!fileId || file.id === fileId)).map((file: TransferFile) => file.id);
    let files = context.files.filter((file: ShareFile) => incomplete.includes(file.id));
    if (!files.length) return;
    previous.retrying = true; this.store.updateTransfer(previous);
    try {
      let source = previous;
      if (context.accepted && previous.status === 'error') {
        await this.send(context.peer, files, context.keepSelection, id);
        const current = this.store.transfers.find((transfer: TransferView) => transfer.id === id);
        if (!context.remoteExpired || !current || current.status !== 'error') return;
        source = current;
        files = files.filter((file: ShareFile) => current.files.some((view: TransferFile) => view.id === file.id &&
          view.status !== 'complete' && view.status !== 'skipped'));
        if (!files.length) return;
      }
      const next = await this.send(context.peer, files, context.keepSelection);
      if (next) {
        for (const file of source.files) { if (files.some((item: ShareFile) => item.id === file.id)) file.retryTransferId = next; }
        if (source.files.every((file: TransferFile) => file.status === 'complete' || file.status === 'skipped' || !!file.retryTransferId)) {
          source.retryTransferId = next;
        }
        if (this.store.transfers.some((transfer: TransferView) => transfer.id === id)) this.store.updateTransfer(source);
      }
    }
    finally {
      const current = this.store.transfers.find((transfer: TransferView) => transfer.id === id);
      if (current) current.retrying = false;
      // Do not resurrect an old row evicted by the bounded transfer list.
      if (current) this.store.updateTransfer(current);
    }
  }
}

export const localSend: LocalSendService = new LocalSendService(appStore);
