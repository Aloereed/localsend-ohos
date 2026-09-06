import { socket, connection } from '@kit.NetworkKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { AppStore, appStore, Peer, ShareFile, HistoryEntry, TransferView, TransferFile } from '../model/AppStore';
import { HttpHead, queryValue, safeRelativePath, uniqueName } from './Protocol';
import { NativeConnection, BodySink, JsonSink } from './NativeServer';
import { TlsIdentity } from './TlsIdentity';
import { Cancellation, request, exchange, encodeText, decodeText, ChunkWriter } from './Transport';

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
  id: string = util.generateRandomUUID();
  ip: string = '';
  peer: Peer = new Peer();
  view: TransferView = new TransferView();
  files: Record<string, FileInfo> = {};
  tokens: Record<string, string> = {};
  resolve: (accepted: boolean) => void = () => {};
  accepted: boolean = false;
  cancelled: boolean = false;
  uploads: NativeConnection[] = [];
}

class SendSessionRef {
  peer: Peer;
  remoteId: string;
  constructor(peer: Peer, remoteId: string) { this.peer = peer; this.remoteId = remoteId; }
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

  constructor(service: LocalSendService, session: ReceiveSession, fileInfo: FileInfo, view: TransferFile, channel: NativeConnection) {
    this.service = service; this.session = session; this.fileInfo = fileInfo; this.view = view; this.channel = channel;
  }

  async init(): Promise<void> {
    const root = `${this.service.store.context!.filesDir}/received/${this.session.id}`;
    this.path = `${root}/${safeRelativePath(this.view.name)}`;
    await fs.mkdir(this.path.slice(0, this.path.lastIndexOf('/')), true);
    this.output = await fs.open(`${this.path}.part`, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    if (this.fileInfo.hash) this.hash = cryptoFramework.createMd('SHA256');
    this.view.status = 'transferring'; this.session.view.status = 'transferring';
    this.service.store.updateTransfer(this.session.view);
  }

  async write(bytes: Uint8Array): Promise<void> {
    if (this.session.cancelled) throw new Error('接收已取消');
    if (this.received + bytes.length > this.fileInfo.size) throw new Error('文件超出声明长度');
    let offset = 0;
    while (offset < bytes.length) {
      const written = await fs.write(this.output!.fd, bytes.slice(offset).buffer as ArrayBuffer);
      if (written <= 0) throw new Error('文件写入失败');
      offset += written;
    }
    await this.hash?.update({ data: bytes });
    this.received += bytes.length; this.view.transferred = this.received;
    if (Date.now() - this.lastUpdate > 100) { this.service.store.updateTransfer(this.session.view); this.lastUpdate = Date.now(); }
  }

  async finish(): Promise<void> {
    if (this.session.cancelled || this.received !== this.fileInfo.size) throw new Error('文件未完整接收');
    if (this.hash) {
      const hash = (await this.hash.digest()).data.reduce((value: string, byte: number) => value + byte.toString(16).padStart(2, '0'), '');
      if (hash !== this.fileInfo.hash!.toLowerCase()) throw new Error('文件校验和不匹配');
    }
    if (this.output) { await fs.close(this.output); this.output = undefined; }
    await fs.rename(`${this.path}.part`, this.path);
    this.finished = true; this.view.status = 'complete';
    const entry = new HistoryEntry(); entry.name = this.view.name; entry.peer = this.session.peer.alias;
    entry.size = this.received; entry.path = this.path;
    await this.service.store.addHistory(entry);
    this.service.finishReceiveFile(this.session);
    await this.channel.respond(200);
  }

  async abort(): Promise<void> {
    if (this.finished) return;
    this.finished = true;
    if (this.output) { await fs.close(this.output).catch(() => {}); this.output = undefined; }
    if (this.path) await fs.unlink(`${this.path}.part`).catch(() => {});
    this.view.status = this.session.cancelled ? 'cancelled' : 'error'; this.session.view.status = this.view.status;
    this.session.view.error = this.session.cancelled ? '' : '文件接收中断'; this.service.store.updateTransfer(this.session.view);
  }
}

export class LocalSendService {
  store: AppStore;
  private identity: TlsIdentity = new TlsIdentity();
  private udp: socket.MulticastSocket | undefined = undefined;
  private tcp: socket.TCPSocketServer | undefined = undefined;
  private tls: socket.TLSSocketServer | undefined = undefined;
  private channels: NativeConnection[] = [];
  private receiving: ReceiveSession | undefined = undefined;
  private sending: Map<string, Cancellation> = new Map();
  private sendSessions: Map<string, SendSessionRef> = new Map();
  private pinResolver: ((pin: string) => void) | undefined = undefined;
  private timer: number = -1;
  private running: boolean = false;
  private starting: boolean = false;
  private pinAttempts: Map<string, number> = new Map();

  constructor(store: AppStore) { this.store = store; }

  info(announce: boolean = false): DeviceInfo {
    return { alias: this.store.settings.alias, version: '2.1', deviceModel: 'HarmonyOS', deviceType: 'mobile',
      fingerprint: this.store.settings.fingerprint, port: this.store.settings.port,
      protocol: this.store.settings.https ? 'https' : 'http', download: false, announce: announce };
  }

  async start(): Promise<void> {
    if (this.running || this.starting || !this.store.ready) return;
    this.starting = true; this.store.serverStatus = '正在启动接收服务';
    try {
      if (this.store.settings.https) await this.identity.load(this.store);
      const address: socket.NetAddress = { address: '0.0.0.0', port: this.store.settings.port, family: 1 };
      if (this.store.settings.https) {
        this.tls = socket.constructTLSSocketServerInstance();
        this.tls.on('connect', (client: socket.TLSSocketConnection) => {
          const channel = this.newChannel(); channel.attachTls(client);
        });
        this.tls.on('error', (error) => { this.store.serverStatus = `接收服务错误 ${error.code}`; this.store.log(this.store.serverStatus); });
        await this.tls.listen({ address: address, secureOptions: { cert: this.identity.certificate, key: this.identity.privateKey } });
      } else {
        this.tcp = socket.constructTCPSocketServerInstance();
        this.tcp.on('connect', (client: socket.TCPSocketConnection) => { const channel = this.newChannel(); channel.attachTcp(client); });
        this.tcp.on('error', (error) => { this.store.serverStatus = `接收服务错误 ${error.code}`; this.store.log(this.store.serverStatus); });
        await this.tcp.listen(address);
      }
      this.running = true;
      this.store.serverStatus = this.store.settings.https ? '已就绪 · 加密传输' : '已就绪 · 未加密';
      await this.readAddresses();
      try {
        this.udp = socket.constructMulticastSocketInstance();
        await this.udp.bind(address);
        await this.udp.setExtraOptions({ reuseAddress: true });
        this.udp.on('message', (message: socket.SocketMessageInfo) => this.discovered(message));
        this.udp.on('error', (error) => this.store.log(`组播错误 ${error.code}`));
        await this.udp.addMembership({ address: this.store.settings.multicast, port: this.store.settings.port, family: 1 });
        await this.udp.setMulticastTTL(1);
        await this.announce();
      } catch (e) { this.store.log(`组播不可用，可通过地址连接：${(e as Error).message}`); }
      this.timer = setInterval(() => { this.announce().catch(() => {}); }, 30000);
      this.store.log('LocalSend 接收服务启动');
    } catch (e) { this.store.fail('接收服务启动失败', e as Error); this.store.serverStatus = '启动失败'; await this.stop(); }
    finally { this.starting = false; }
  }

  async stop(): Promise<void> {
    this.running = false;
    if (this.timer !== -1) { clearInterval(this.timer); this.timer = -1; }
    if (this.receiving) this.cancel(this.receiving.id);
    for (const channel of this.channels) channel.close(); this.channels = [];
    await this.udp?.close().catch(() => {}); this.udp = undefined;
    await this.tcp?.close().catch(() => {}); this.tcp = undefined;
    await this.tls?.close().catch(() => {}); this.tls = undefined;
    this.store.serverStatus = '接收服务已停止';
  }

  async restart(): Promise<void> { await this.stop(); await this.start(); }

  private newChannel(): NativeConnection {
    this.channels = this.channels.filter((channel: NativeConnection) => !channel.closed);
    const channel = new NativeConnection((connection: NativeConnection, head: HttpHead) => this.handle(connection, head));
    channel.onError = (message: string) => this.store.log(`接收：${message}`);
    this.channels.push(channel);
    if (this.channels.length > 32) channel.close();
    return channel;
  }

  private async readAddresses(): Promise<void> {
    const addresses: string[] = [];
    for (const net of await connection.getAllNets()) {
      const props = await connection.getConnectionProperties(net);
      for (const link of props.linkAddresses) {
        const ip = link.address.address;
        if (ip && !ip.startsWith('127.') && !ip.includes(':') && !addresses.includes(ip)) addresses.push(ip);
      }
    }
    this.store.localIps = addresses;
  }

  async announce(): Promise<void> {
    if (!this.store.settings.visible || !this.running) return;
    await this.udp?.send({ data: JSON.stringify(this.info(true)), address: { address: this.store.settings.multicast, port: this.store.settings.port, family: 1 } });
  }

  async discover(): Promise<void> {
    if (!this.running) await this.start();
    await this.readAddresses().catch(() => {});
    await this.announce().catch((e: Error) => this.store.fail('发现设备失败', e));
    this.store.notice = '已发送发现请求';
    for (const peer of this.store.favorites) this.probe(peer).catch(() => {});
  }

  private discovered(message: socket.SocketMessageInfo): void {
    if (message.message.byteLength > 16384) return;
    try {
      const info = JSON.parse(decodeText(new Uint8Array(message.message))) as DeviceInfo;
      if (!info || typeof info.alias !== 'string' || typeof info.fingerprint !== 'string' || info.fingerprint === this.store.settings.fingerprint) return;
      const peer = this.peerFrom(info, message.remoteInfo.address);
      this.upsertPeer(peer);
      if (info.announce && this.store.settings.visible) this.register(peer).catch((e: Error) => this.store.log(`设备握手：${e.message}`));
    } catch (_) { /* Ignore malformed UDP datagrams from unrelated applications. */ }
  }

  private peerFrom(info: DeviceInfo, ip: string): Peer {
    const peer = new Peer(); peer.alias = String(info.alias || ip).slice(0, 100); peer.ip = ip;
    peer.port = Number.isInteger(info.port) && info.port > 0 && info.port <= 65535 ? info.port : 53317;
    peer.protocol = info.protocol === 'http' ? 'http' : 'https'; peer.fingerprint = info.fingerprint || '';
    peer.deviceModel = info.deviceModel || ''; peer.deviceType = info.deviceType || 'desktop'; return peer;
  }

  private upsertPeer(peer: Peer): void {
    if (peer.fingerprint === this.store.settings.fingerprint) return;
    this.store.peers = [peer, ...this.store.peers.filter((item: Peer) => item.ip !== peer.ip || item.port !== peer.port)].slice(0, 100);
  }

  private async register(peer: Peer): Promise<void> {
    const result = await request(peer, 'POST', '/api/localsend/v2/register', JSON.stringify(this.info()));
    if (result.status === 200) {
      const info = JSON.parse(result.body) as DeviceInfo;
      const known = this.peerFrom(info, peer.ip); known.port = peer.port; known.protocol = peer.protocol;
      if (result.fingerprint) known.fingerprint = result.fingerprint;
      this.upsertPeer(known);
    }
  }

  async probe(peer: Peer): Promise<void> {
    let reply = await request(peer, 'GET', '/api/localsend/v2/info');
    if (reply.status === 404) reply = await request(peer, 'GET', '/api/localsend/v1/info');
    if (reply.status !== 200) throw new Error(`设备返回 ${reply.status}`);
    const info = JSON.parse(reply.body) as DeviceInfo;
    const known = this.peerFrom(info, peer.ip); known.port = peer.port; known.protocol = peer.protocol;
    if (reply.fingerprint) known.fingerprint = reply.fingerprint;
    this.upsertPeer(known);
    if (this.store.settings.visible) await this.register(known);
  }

  async addAddress(address: string): Promise<void> {
    try {
      const clean = address.trim(); const parts = clean.replace(/^https?:\/\//, '').replace(/\/$/, '').split(':');
      if (!/^\d{1,3}(\.\d{1,3}){3}$/.test(parts[0]) || parts[0].split('.').some((part: string) => Number(part) > 255)) throw new Error('请输入有效 IPv4 地址');
      const peer = new Peer(); peer.ip = parts[0]; peer.port = parts[1] ? Number(parts[1]) : 53317;
      if (!Number.isInteger(peer.port) || peer.port < 1 || peer.port > 65535) throw new Error('端口无效');
      peer.protocol = clean.startsWith('http://') ? 'http' : 'https';
      try { await this.probe(peer); }
      catch (e) { if (clean.startsWith('https://') || peer.protocol === 'http') throw e as Error; peer.protocol = 'http'; await this.probe(peer); }
      this.store.notice = '设备已添加';
    } catch (e) { this.store.fail('添加设备失败', e as Error); }
  }

  private async handle(channel: NativeConnection, head: HttpHead): Promise<BodySink> {
    const path = head.target.split('?')[0];
    if (path.endsWith('/upload') && head.method === 'POST') return this.openUpload(channel, head);
    return new JsonSink(async (bytes: Uint8Array): Promise<void> => {
      if (/^\/api\/localsend\/v[12]\/info$/.test(path) && head.method === 'GET') await channel.respond(200, JSON.stringify(this.info()));
      else if (/^\/api\/localsend\/v[12]\/register$/.test(path) && head.method === 'POST') {
        const info = JSON.parse(decodeText(bytes)) as DeviceInfo;
        if (!info || typeof info.alias !== 'string') { await channel.respond(400); return; }
        this.upsertPeer(this.peerFrom(info, channel.ip)); await channel.respond(200, JSON.stringify(this.info()));
      } else if (/^\/api\/localsend\/v[12]\/prepare-upload$/.test(path) && head.method === 'POST') await this.prepare(channel, head, bytes);
      else if (/^\/api\/localsend\/v[12]\/cancel$/.test(path) && head.method === 'POST') {
        const id = queryValue(head.target, 'sessionId');
        if (this.receiving?.id === id && this.receiving.ip === channel.ip) this.cancel(id);
        await channel.respond(200);
      } else await channel.respond(404);
    });
  }

  private async prepare(channel: NativeConnection, head: HttpHead, bytes: Uint8Array): Promise<void> {
    if (this.receiving && !['complete', 'error', 'cancelled', 'declined'].includes(this.receiving.view.status)) { await channel.respond(409); return; }
    if (this.store.settings.pin) {
      const attempts = this.pinAttempts.get(channel.ip) || 0;
      if (attempts >= 3) { await channel.respond(429); return; }
      const pin = queryValue(head.target, 'pin');
      if (pin !== this.store.settings.pin) { if (pin) this.pinAttempts.set(channel.ip, attempts + 1); await channel.respond(401); return; }
      this.pinAttempts.delete(channel.ip);
    }
    const payload = JSON.parse(decodeText(bytes)) as PrepareRequest;
    if (!payload?.info || typeof payload.info.alias !== 'string' || !payload.files || typeof payload.files !== 'object') { await channel.respond(400); return; }
    const ids = Object.keys(payload.files);
    if (!ids.length || ids.length > 10000) { await channel.respond(400); return; }
    const session = new ReceiveSession(); session.ip = channel.ip; session.peer = this.peerFrom(payload.info, channel.ip);
    session.files = payload.files; session.view.id = session.id; session.view.peer = session.peer.alias;
    session.view.direction = 'receive'; session.view.encrypted = channel.encrypted;
    for (const id of ids) {
      const file = payload.files[id];
      if (!file || typeof file.fileName !== 'string' || !Number.isSafeInteger(file.size) || file.size < 0 || file.id !== id) throw new Error('文件信息无效');
      const view = new TransferFile(); view.id = id;
      view.name = uniqueName(safeRelativePath(file.fileName), session.view.files.map((item: TransferFile) => item.name)); view.size = file.size;
      if (file.preview && file.fileType === 'text/plain') view.name = file.fileName.slice(0, 100);
      session.view.files.push(view);
    }
    this.receiving = session; this.store.updateTransfer(session.view); this.upsertPeer(session.peer);
    let automatic = this.store.settings.quickSave;
    if (!automatic && this.store.settings.favoriteQuickSave && channel.encrypted && session.peer.protocol === 'https' &&
      this.store.favorites.some((peer: Peer) => !!peer.fingerprint && peer.fingerprint === session.peer.fingerprint)) {
      // A fingerprint in JSON is only a claim. Prove possession of the matching
      // TLS identity at the sender address before bypassing receive consent.
      try { automatic = (await request(session.peer, 'GET', '/api/localsend/v2/info')).status === 200; }
      catch (_) { this.store.log('收藏身份验证失败，转为手动确认'); }
    }
    if (!automatic) {
      this.store.pendingReceive = session.id;
      const accepted = await new Promise<boolean>((resolve) => {
        const timer = setTimeout(() => resolve(false), 120000);
        session.resolve = (value: boolean) => { clearTimeout(timer); resolve(value); };
      });
      this.store.pendingReceive = '';
      if (!accepted || session.cancelled || channel.closed) { session.view.status = 'declined'; this.store.updateTransfer(session.view); await channel.respond(403); return; }
    }
    session.accepted = true;
    const selected = session.view.files.filter((file: TransferFile) => file.selected);
    if (!selected.length) { session.view.status = 'declined'; this.store.updateTransfer(session.view); await channel.respond(403); return; }
    if (selected.every((file: TransferFile) => !!session.files[file.id].preview && session.files[file.id].fileType === 'text/plain')) {
      for (const file of selected) {
        const entry = new HistoryEntry(); entry.name = file.name; entry.text = session.files[file.id].preview!;
        entry.peer = session.peer.alias; entry.size = encodeText(entry.text).length;
        await this.store.addHistory(entry); file.status = 'complete'; file.transferred = file.size;
      }
      session.view.status = 'complete'; session.view.finished = Date.now(); this.store.updateTransfer(session.view); await channel.respond(204); return;
    }
    const tokens: Record<string, string> = {};
    for (const file of selected) tokens[file.id] = util.generateRandomUUID();
    session.tokens = tokens; session.view.status = 'transferring'; this.store.updateTransfer(session.view);
    const response: PrepareReply = { sessionId: session.id, files: tokens };
    await channel.respond(200, JSON.stringify(head.target.includes('/v1/') ? tokens : response));
  }

  acceptReceive(accepted: boolean): void { this.receiving?.resolve(accepted); }

  selectReceiveFile(id: string, selected: boolean): void {
    const file = this.receiving?.view.files.find((item: TransferFile) => item.id === id);
    if (file && this.receiving) { file.selected = selected; this.store.updateTransfer(this.receiving.view); }
  }

  private async openUpload(channel: NativeConnection, head: HttpHead): Promise<BodySink> {
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
    const sink = new UploadSink(this, session, info, view, channel); await sink.init(); session.uploads.push(channel); return sink;
  }

  finishReceiveFile(session: ReceiveSession): void {
    if (session.view.files.filter((file: TransferFile) => file.selected).every((file: TransferFile) => file.status === 'complete')) {
      session.view.status = 'complete'; session.view.finished = Date.now(); this.store.notice = `已收到 ${session.peer.alias} 的文件`;
    }
    this.store.updateTransfer(session.view);
  }

  cancel(id: string): void {
    this.sending.get(id)?.cancel();
    if (this.store.pendingPin === id) this.submitPin('');
    const sending = this.sendSessions.get(id);
    if (sending) request(sending.peer, 'POST', `/api/localsend/v2/cancel?sessionId=${encodeURIComponent(sending.remoteId)}`).catch(() => {});
    if (this.receiving?.id === id) {
      this.receiving.cancelled = true; this.receiving.resolve(false); this.receiving.view.status = 'cancelled';
      this.store.pendingReceive = ''; this.store.updateTransfer(this.receiving.view);
      for (const channel of this.receiving.uploads) channel.close();
    }
  }

  submitPin(pin: string): void { this.pinResolver?.(pin); this.pinResolver = undefined; this.store.pendingPin = ''; }

  async send(peer: Peer): Promise<void> {
    if (!this.store.files.length) { this.store.notice = '请先选择文件或输入文字'; return; }
    const files = this.store.files.slice(); const transfer = new TransferView(); transfer.id = util.generateRandomUUID();
    transfer.peer = peer.alias; transfer.encrypted = peer.protocol === 'https';
    const fileInfos: Record<string, FileInfo> = {};
    for (const file of files) {
      const view = new TransferFile(); view.id = file.id; view.name = file.name; view.size = file.size; transfer.files.push(view);
      const info: FileInfo = { id: file.id, fileName: file.text ? 'message.txt' : file.name, size: file.size, fileType: file.mime };
      if (file.text) info.preview = file.text;
      fileInfos[file.id] = info;
    }
    this.store.updateTransfer(transfer);
    const cancellation = new Cancellation(); this.sending.set(transfer.id, cancellation);
    try {
      const favorite = this.store.favorites.find((item: Peer) => item.ip === peer.ip && item.port === peer.port);
      if (favorite?.fingerprint && favorite.fingerprint !== peer.fingerprint) throw new Error('收藏设备的身份已改变，请核对后重新收藏');
      const payload: PrepareRequest = { info: this.info(), files: fileInfos };
      let response = await request(peer, 'POST', '/api/localsend/v2/prepare-upload', JSON.stringify(payload), cancellation);
      while (response.status === 401) {
        this.store.pendingPin = transfer.id;
        const pin = await new Promise<string>((resolve) => { this.pinResolver = resolve; });
        if (!pin) { cancellation.cancel(); cancellation.check(); }
        response = await request(peer, 'POST', `/api/localsend/v2/prepare-upload?pin=${encodeURIComponent(pin)}`, JSON.stringify(payload), cancellation);
      }
      if (response.status === 204) {
        for (const file of files) { if (file.text) await this.sentHistory(file, peer); }
        for (const file of transfer.files) {
          const source = files.find((item: ShareFile) => item.id === file.id)!;
          file.status = source.text ? 'complete' : 'skipped'; file.transferred = source.text ? file.size : 0;
        }
      } else {
        if (response.status !== 200) throw new Error(response.status === 403 ? '对方拒绝了传输' : response.status === 409 ? '对方正在传输，请稍后重试' : response.status === 429 ? 'PIN 尝试次数过多' : `设备返回 ${response.status}`);
        const prepared = JSON.parse(response.body) as PrepareReply;
        if (!prepared.sessionId || !prepared.files) throw new Error('设备返回了无效传输会话');
        this.sendSessions.set(transfer.id, new SendSessionRef(peer, prepared.sessionId));
        transfer.status = 'transferring'; this.store.updateTransfer(transfer);
        for (const file of files) {
          cancellation.check(); const view = transfer.files.find((item: TransferFile) => item.id === file.id)!;
          const token = prepared.files[file.id];
          if (!token) { view.status = 'skipped'; this.store.updateTransfer(transfer); continue; }
          view.status = 'transferring'; this.store.updateTransfer(transfer);
          let lastUpdate = 0;
          const upload = await exchange(peer, 'POST', `/api/localsend/v2/upload?sessionId=${encodeURIComponent(prepared.sessionId)}&fileId=${encodeURIComponent(file.id)}&token=${encodeURIComponent(token)}`, file.size,
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
          if (upload.status !== 200) throw new Error(`文件发送失败 ${upload.status}`);
          view.status = 'complete'; view.transferred = file.size; this.store.updateTransfer(transfer); await this.sentHistory(file, peer);
        }
      }
      transfer.status = 'complete'; transfer.finished = Date.now(); this.store.notice = `已发送到 ${peer.alias}`;
    } catch (e) {
      transfer.status = cancellation.cancelled ? 'cancelled' : 'error'; transfer.error = (e as Error).message;
      this.store.log(`发送：${transfer.error}`);
    } finally { this.sending.delete(transfer.id); this.sendSessions.delete(transfer.id); this.store.updateTransfer(transfer); }
  }

  private async sentHistory(file: ShareFile, peer: Peer): Promise<void> {
    const entry = new HistoryEntry(); entry.name = file.name; entry.peer = peer.alias; entry.direction = 'send'; entry.size = file.size; entry.text = file.text;
    await this.store.addHistory(entry);
  }
}

export const localSend: LocalSendService = new LocalSendService(appStore);
