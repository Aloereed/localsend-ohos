import { socket } from '@kit.NetworkKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { AppStore, appStore, ShareFile, WebAccessRequest, TransferView, TransferFile, HistoryEntry } from '../model/AppStore';
import { HttpHead, queryValue } from './Protocol';
import { NativeConnection, BodySink, JsonSink } from './NativeServer';
import { LocalSendService, localSend } from './LocalSendService';
import { TlsIdentity } from './TlsIdentity';
import { encodeText } from './Transport';
import { webPage } from './WebPage';
import { ZipDownload } from './ZipDownload';
import { SecureServer, SecureConnection } from './SecureServer';
import { ipv4, ipv6 } from './Addresses';
import { readWebTemplate, writeWebTemplate, installWebTemplate, renderWebTemplate, exampleWebTemplate } from './WebTemplate';

export class WebShareService {
  private store: AppStore;
  private protocol: LocalSendService;
  private tcp: socket.TCPSocketServer | undefined = undefined;
  private tls: SecureServer | undefined = undefined;
  private tcp6: socket.TCPSocketServer | undefined = undefined;
  private tls6: SecureServer | undefined = undefined;
  private channels: NativeConnection[] = [];
  private token: string = '';
  private encrypted: boolean = false;
  private template: string = '';
  private expiresAt: number = 0;
  private pending: Map<string, (value: boolean) => void> = new Map();
  private files: ShareFile[] = [];
  private downloads: Map<string, NativeConnection> = new Map();
  private expiryTimer: number = -1;
  private lifecycle: Promise<void> = Promise.resolve();

  constructor(store: AppStore, protocol: LocalSendService) { this.store = store; this.protocol = protocol; }

  async refreshTemplate(): Promise<void> {
    if (this.store.context) this.store.webTemplateConfigured = await fs.access(`${this.store.context.filesDir}/web-template.html`);
  }

  async configureTemplate(action: string): Promise<void> {
    if (!this.store.context || this.store.webUrl || this.store.webStarting || this.store.webTemplateBusy) return;
    this.store.webTemplateBusy = true;
    const path = `${this.store.context.filesDir}/web-template.html`;
    try {
      if (action === 'import') {
        const options = new picker.DocumentSelectOptions(); options.maxSelectNumber = 1; options.selectMode = picker.DocumentSelectMode.FILE;
        const selected = await new picker.DocumentViewPicker(this.store.context).select(options);
        if (!selected.length) return;
        await installWebTemplate(selected[0], path);
      } else if (action === 'export') {
        const options = new picker.DocumentSaveOptions(); options.newFileNames = ['AloeSend-web-template.html'];
        const selected = await new picker.DocumentViewPicker(this.store.context).save(options);
        if (!selected.length) return;
        await writeWebTemplate(selected[0], await fs.access(path) ? await readWebTemplate(path) : exampleWebTemplate);
      } else if (action === 'reset') {
        if (await fs.access(path)) await fs.unlink(path);
      }
      await this.refreshTemplate(); this.store.notice = '网页模板设置已更新';
    } catch (error) { this.store.fail('网页模板操作失败', error as Error); }
    finally { this.store.webTemplateBusy = false; }
  }

  async start(encrypted: boolean = false): Promise<void> {
    if (this.store.identityResetting) { this.store.notice = '正在重置证书，请稍后'; return; }
    if (this.store.webStarting || this.store.webTemplateBusy) return;
    this.store.webStarting = true;
    try { await this.scheduleLifecycle(() => this.startNow(encrypted)); }
    finally { this.store.webStarting = false; }
  }

  private scheduleLifecycle(action: () => Promise<void>): Promise<void> {
    const operation = this.lifecycle.then(action);
    this.lifecycle = operation.catch(() => {});
    return operation;
  }

  stop(): Promise<void> { return this.scheduleLifecycle(() => this.stopNow()); }

  private async startNow(encrypted: boolean): Promise<void> {
    try {
      await this.stopNow();
      this.template = '';
      if (this.store.context) {
        const path = `${this.store.context.filesDir}/web-template.html`;
        if (await fs.access(path)) this.template = await readWebTemplate(path);
      }
      this.encrypted = encrypted; this.token = util.generateRandomUUID(); this.expiresAt = Date.now() + 3600000;
      this.files = this.store.files.slice(); this.store.webFiles = this.files;
      const port = this.store.settings.port < 65535 ? this.store.settings.port + 1 : this.store.settings.port - 1;
      const address: socket.NetAddress = { address: '0.0.0.0', port: port, family: 1 };
      const identity = new TlsIdentity();
      if (encrypted) await identity.load(this.store);
      try {
      if (encrypted) {
        this.tls = new SecureServer();
        await this.tls.listen(address, identity.certificate, identity.privateKey,
          (client: SecureConnection) => this.channel().attachTls(client), (error: Error) => this.store.log(error.message));
      } else {
        this.tcp = socket.constructTCPSocketServerInstance();
        await this.tcp.listen(address);
        this.tcp.on('connect', (client: socket.TCPSocketConnection) => this.channel().attachTcp(client));
      }
      } catch (error) {
        await this.tcp?.close().catch(() => {}); this.tcp = undefined;
        await this.tls?.close().catch(() => {}); this.tls = undefined;
        this.store.log(`IPv4 浏览器分享：${(error as Error).message}`);
      }
      try {
        const address6: socket.NetAddress = { address: '::', port: port, family: 2 };
        if (encrypted) {
          this.tls6 = new SecureServer();
          await this.tls6.listen(address6, identity.certificate, identity.privateKey,
            (client: SecureConnection) => this.channel().attachTls(client), (error: Error) => this.store.log(error.message));
        } else {
          this.tcp6 = socket.constructTCPSocketServerInstance(); await this.tcp6.listen(address6);
          this.tcp6.on('connect', (client: socket.TCPSocketConnection) => this.channel().attachTcp(client));
        }
      } catch (error) {
        await this.tcp6?.close().catch(() => {}); this.tcp6 = undefined;
        await this.tls6?.close().catch(() => {}); this.tls6 = undefined;
        this.store.log(`IPv6 浏览器分享：${(error as Error).message}`);
      }
      const candidates = [...this.store.localIps, ...this.store.interfaces.filter((item) => !item.ignored).map((item) => item.ip)];
      const host = candidates.find((ip: string) => ipv4(ip) && (!!this.tcp || !!this.tls)) ||
        candidates.find((ip: string) => ipv6(ip) && !ip.includes('%') && !/^fe[89ab]/i.test(ip) && (!!this.tcp6 || !!this.tls6));
      if (!host) throw new Error('请先连接可用的局域网');
      this.store.webUrl = `${encrypted ? 'https' : 'http'}://${ipv6(host) ? '[' + host + ']' : host}:${port}/s/${this.token}/`;
      this.expiryTimer = setTimeout(() => { this.stop(); this.store.notice = '分享链接已到期，可以重新开始分享'; }, 3600000);
      this.store.log('浏览器分享已启动，链接有效期 1 小时');
    } catch (e) { await this.stopNow(); this.store.fail('启动浏览器分享失败', e as Error); }
  }

  private async stopNow(): Promise<void> {
    if (this.expiryTimer !== -1) { clearTimeout(this.expiryTimer); this.expiryTimer = -1; }
    this.token = ''; this.store.webUrl = ''; this.store.webFiles = [];
    for (const resolve of this.pending.values()) resolve(false); this.pending.clear(); this.store.webRequests = [];
    for (const channel of this.channels) channel.close(); this.channels = [];
    await this.tcp?.close().catch(() => {}); this.tcp = undefined;
    await this.tls?.close().catch(() => {}); this.tls = undefined;
    await this.tcp6?.close().catch(() => {}); this.tcp6 = undefined;
    await this.tls6?.close().catch(() => {}); this.tls6 = undefined;
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
        await channel.respond(200, renderWebTemplate(this.template, webPage(this.store.settings.alias, this.files, language, this.store.accent), this.store.settings.alias), 'text/html; charset=utf-8'); return;
      }
      if (relative === 'logo.png' && this.store.context) {
        const bytes = await this.store.context.resourceManager.getRawFileContent('logo.png');
        await channel.beginResponse(200, bytes.byteLength, 'image/png');
        await channel.send(bytes); channel.close(); return;
      }
      if (relative === 'archive.zip') {
        const files = this.files.filter((file: ShareFile) => !file.text);
        if (!files.length) { await channel.respond(404); return; }
        const archive = new ZipDownload(files);
        const file = new ShareFile(); file.name = `AloeSend-${files.length}.zip`; file.size = archive.size; file.mime = 'application/zip';
        await this.download(channel, file, archive); return;
      }
      if (relative.startsWith('file/')) {
        const id = decodeURIComponent(relative.slice(5)); const file = this.files.find((item: ShareFile) => item.id === id);
        if (file) { await this.download(channel, file); return; }
      }
      await channel.respond(404);
    });
  }

  private async download(channel: NativeConnection, file: ShareFile, archive?: ZipDownload): Promise<void> {
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
      if (archive) {
        let lastUpdate = 0;
        await archive.send(async (bytes: Uint8Array): Promise<void> => {
          if (channel.closed) throw new Error('下载已取消');
          await channel.send(bytes); item.transferred += bytes.length;
          if (Date.now() - lastUpdate > 100) { this.store.updateTransfer(transfer); lastUpdate = Date.now(); }
        });
      } else if (file.text) await channel.send(encodeText(file.text));
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
