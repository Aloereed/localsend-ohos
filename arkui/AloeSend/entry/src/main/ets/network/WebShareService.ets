import { socket } from '@kit.NetworkKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { AppStore, appStore, ShareFile, WebAccessRequest, TransferView, TransferFile, HistoryEntry } from '../model/AppStore';
import { HttpHead, queryValue } from './Protocol';
import { NativeConnection, BodySink, JsonSink } from './NativeServer';
import { LocalSendService, localSend } from './LocalSendService';
import { TlsIdentity } from './TlsIdentity';
import { encodeText } from './Transport';
import { webPage } from './WebPage';

export class WebShareService {
  private store: AppStore;
  private protocol: LocalSendService;
  private tcp: socket.TCPSocketServer | undefined = undefined;
  private tls: socket.TLSSocketServer | undefined = undefined;
  private channels: NativeConnection[] = [];
  private token: string = '';
  private encrypted: boolean = false;
  private expiresAt: number = 0;
  private pending: Map<string, (value: boolean) => void> = new Map();
  private files: ShareFile[] = [];
  private downloads: Map<string, NativeConnection> = new Map();
  private expiryTimer: number = -1;
  private starting: boolean = false;

  constructor(store: AppStore, protocol: LocalSendService) { this.store = store; this.protocol = protocol; }

  async start(encrypted: boolean = false): Promise<void> {
    if (this.starting) return;
    this.starting = true;
    try {
      await this.stop();
      this.encrypted = encrypted; this.token = util.generateRandomUUID(); this.expiresAt = Date.now() + 3600000;
      this.files = this.store.files.slice(); this.store.webFiles = this.files;
      const port = this.store.settings.port < 65535 ? this.store.settings.port + 1 : this.store.settings.port - 1;
      const address: socket.NetAddress = { address: '0.0.0.0', port: port, family: 1 };
      if (encrypted) {
        const identity = new TlsIdentity(); await identity.load(this.store);
        this.tls = socket.constructTLSSocketServerInstance();
        await this.tls.listen({ address: address, secureOptions: { cert: identity.certificate, key: identity.privateKey } });
        this.tls.on('connect', (client: socket.TLSSocketConnection) => this.channel().attachTls(client));
      } else {
        this.tcp = socket.constructTCPSocketServerInstance();
        await this.tcp.listen(address);
        this.tcp.on('connect', (client: socket.TCPSocketConnection) => this.channel().attachTcp(client));
      }
      const host = this.store.localIps[0];
      if (!host) { await this.stop(); throw new Error('请先连接可用的局域网'); }
      this.store.webUrl = `${encrypted ? 'https' : 'http'}://${host}:${port}/s/${this.token}/`;
      this.expiryTimer = setTimeout(() => { this.stop(); this.store.notice = '分享链接已到期，可以重新开始分享'; }, 3600000);
      this.store.log('浏览器分享已启动，链接有效期 1 小时');
    } catch (e) { await this.stop(); this.store.fail('启动浏览器分享失败', e as Error); }
    finally { this.starting = false; }
  }

  async stop(): Promise<void> {
    if (this.expiryTimer !== -1) { clearTimeout(this.expiryTimer); this.expiryTimer = -1; }
    this.token = ''; this.store.webUrl = ''; this.store.webFiles = [];
    for (const resolve of this.pending.values()) resolve(false); this.pending.clear(); this.store.webRequests = [];
    for (const channel of this.channels) channel.close(); this.channels = [];
    await this.tcp?.close().catch(() => {}); this.tcp = undefined;
    await this.tls?.close().catch(() => {}); this.tls = undefined;
  }

  respond(id: string, accepted: boolean): void { this.pending.get(id)?.(accepted); }
  cancel(id: string): boolean {
    const channel = this.downloads.get(id);
    if (!channel) return false;
    channel.close(); return true;
  }

  private channel(): NativeConnection {
    this.channels = this.channels.filter((channel: NativeConnection) => !channel.closed);
    const channel = new NativeConnection((client: NativeConnection, head: HttpHead) => this.handle(client, head));
    channel.onError = (message: string) => this.store.log(`浏览器分享：${message}`); this.channels.push(channel);
    if (this.channels.length > 24) channel.close();
    return channel;
  }

  private async handle(channel: NativeConnection, head: HttpHead): Promise<BodySink> {
    const prefix = `/s/${this.token}/`;
    if (!this.token || Date.now() > this.expiresAt || !head.target.startsWith(prefix)) {
      await channel.respond(404); return new JsonSink(async () => {});
    }
    const origin = head.headers['origin']; const host = head.headers['host'];
    if (head.method === 'POST' && origin && origin !== `${this.encrypted ? 'https' : 'http'}://${host}`) {
      await channel.respond(403); return new JsonSink(async () => {});
    }
    const relative = head.target.slice(prefix.length);
    if (relative.startsWith('api/localsend/v2/') && head.method === 'POST') {
      head.target = `/${relative}`;
      return this.protocol.handleBrowserRequest(channel, head);
    }
    return new JsonSink(async (): Promise<void> => {
      if (head.method !== 'GET') { await channel.respond(405); return; }
      if (!relative.split('?')[0]) {
        const language = queryValue(head.target, 'lang') || this.store.settings.language;
        await channel.respond(200, webPage(this.store.settings.alias, this.files, language, this.store.settings.accent), 'text/html; charset=utf-8'); return;
      }
      if (relative === 'logo.png' && this.store.context) {
        const bytes = await this.store.context.resourceManager.getRawFileContent('logo.png');
        await channel.beginResponse(200, bytes.byteLength, 'image/png');
        await channel.send(bytes); channel.close(); return;
      }
      if (relative.startsWith('file/')) {
        const id = decodeURIComponent(relative.slice(5)); const file = this.files.find((item: ShareFile) => item.id === id);
        if (file) { await this.download(channel, file); return; }
      }
      await channel.respond(404);
    });
  }

  private async download(channel: NativeConnection, file: ShareFile): Promise<void> {
    if (!this.store.settings.webAutoAccept) {
      const offer = new WebAccessRequest(); offer.id = util.generateRandomUUID(); offer.ip = channel.ip; offer.fileName = file.name;
      this.store.webRequests = [...this.store.webRequests, offer];
      const accepted = await new Promise<boolean>((resolve) => {
        const timer = setTimeout(() => resolve(false), 120000);
        this.pending.set(offer.id, (value: boolean) => { clearTimeout(timer); resolve(value); });
        channel.onClosed = () => this.pending.get(offer.id)?.(false);
      });
      this.pending.delete(offer.id); this.store.webRequests = this.store.webRequests.filter((item: WebAccessRequest) => item.id !== offer.id);
      if (!accepted) { await channel.respond(403, '下载未获批准', 'text/plain; charset=utf-8'); return; }
    }
    if (channel.closed) return;
    const transfer = new TransferView(); transfer.id = util.generateRandomUUID(); transfer.peer = `浏览器 ${channel.ip}`;
    transfer.encrypted = this.encrypted; transfer.status = 'transferring';
    const item = new TransferFile(); item.id = file.id; item.name = file.name; item.size = file.size; item.status = 'transferring'; transfer.files = [item];
    this.store.updateTransfer(transfer);
    this.downloads.set(transfer.id, channel);
    try {
      await channel.beginResponse(200, file.size, file.mime, `Content-Disposition: attachment; filename*=UTF-8''${encodeURIComponent(file.name)}\r\nCache-Control: no-store\r\n`);
      if (file.text) await channel.send(encodeText(file.text));
      else {
        const source = await fs.open(file.uri, fs.OpenMode.READ_ONLY);
        try {
          let count = 0; let lastUpdate = 0;
          while (count < file.size) {
            const buffer = new ArrayBuffer(Math.min(65536, file.size - count));
            const read = await fs.read(source.fd, buffer); if (read <= 0) throw new Error('读取源文件失败');
            await channel.send(new Uint8Array(buffer).slice(0, read)); count += read; item.transferred = count;
            if (Date.now() - lastUpdate > 100) { this.store.updateTransfer(transfer); lastUpdate = Date.now(); }
          }
        } finally { await fs.close(source); }
      }
      item.status = 'complete'; item.transferred = file.size; transfer.status = 'complete'; transfer.finished = Date.now();
      const entry = new HistoryEntry(); entry.name = file.name; entry.size = file.size; entry.peer = transfer.peer; entry.direction = 'send'; entry.text = file.text;
      await this.store.addHistory(entry);
    } catch (e) { transfer.status = channel.closed ? 'cancelled' : 'error'; item.status = transfer.status; transfer.error = (e as Error).message; }
    finally { this.downloads.delete(transfer.id); channel.close(); this.store.updateTransfer(transfer); }
  }
}

export const webShare: WebShareService = new WebShareService(appStore, localSend);
