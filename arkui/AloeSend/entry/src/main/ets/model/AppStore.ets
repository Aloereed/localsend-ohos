import { preferences } from '@kit.ArkData';
import { common, ConfigurationConstant, abilityAccessCtrl } from '@kit.AbilityKit';
import { picker, fileIo as fs, fileUri, fileShare } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';
import { pasteboard, deviceInfo } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { backgroundKeeper } from '../platform/BackgroundKeeper';
import { uiText } from './Locale';
import { readableColor } from './Colors';
import { LocalInterface } from '../network/Addresses';
import { safeRelativePath } from '../network/Protocol';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { ensureDirectory } from '../platform/Directories';
import { publicParentUri } from '../platform/FileLocation';

export class ShareFile {
  id: string = util.generateRandomUUID();
  name: string = '';
  uri: string = '';
  size: number = 0;
  mime: string = 'application/octet-stream';
  text: string = '';
}

export class MessageDraft {
  text: string = '';
  files: ShareFile[] = [];
}

export class Peer {
  version: string = '2.1';
  alias: string = '';
  ip: string = '';
  port: number = 53317;
  protocol: string = 'http';
  fingerprint: string = '';
  deviceModel: string = '';
  deviceType: string = 'desktop';
  lastSeen: number = Date.now();
}

export function samePeer(a: Peer, b: Peer): boolean {
  if (a.fingerprint && b.fingerprint) return a.fingerprint === b.fingerprint;
  return !!a.ip && a.ip === b.ip && a.port === b.port;
}

export class HistoryEntry {
  id: string = util.generateRandomUUID();
  name: string = '';
  peer: string = '';
  direction: string = 'receive';
  time: number = Date.now();
  size: number = 0;
  path: string = '';
  exportedPath: string = '';
  galleryPath: string = '';
  text: string = '';
  status: string = 'complete';
  peerInfo: Peer | undefined = undefined;
}

export class TransferFile {
  id: string = '';
  path: string = '';
  name: string = '';
  size: number = 0;
  transferred: number = 0;
  status: string = 'waiting';
  selected: boolean = true;
  preview: string = '';
}

export class NetworkLogEntry {
  id: string = util.generateRandomUUID();
  time: number = Date.now();
  category: string = '';
  message: string = '';
}

export class TransferView {
  id: string = '';
  peer: string = '';
  direction: string = 'send';
  status: string = 'waiting';
  error: string = '';
  files: TransferFile[] = [];
  started: number = Date.now();
  activeStarted: number = 0;
  finished: number = 0;
  encrypted: boolean = true;
  peerInfo: Peer | undefined = undefined;
  destination: string = '';
}

export class WebAccessRequest {
  id: string = '';
  ip: string = '';
  fileName: string = '';
}

export class AppSettings {
  alias: string = '我的鸿蒙设备';
  fingerprint: string = util.generateRandomUUID();
  theme: string = 'system';
  language: string = 'zh';
  accent: string = '#168A75';
  quickSave: boolean = false;
  favoriteQuickSave: boolean = false;
  saveHistory: boolean = true;
  autoFinish: boolean = true;
  openMessagesOnReceive: boolean = false;
  offerGallerySave: boolean = false;
  animations: boolean = true;
  reduceEffects: boolean = false;
  pureBlack: boolean = false;
  visible: boolean = true;
  pin: string = '';
  port: number = 53317;
  multicast: string = '224.0.0.167';
  destination: string = '';
  destinationMode: string = 'private';
  deviceModel: string = 'HarmonyOS';
  deviceType: string = 'mobile';
  sendMode: string = 'single';
  advanced: boolean = false;
  https: boolean = true;
  discoveryTimeout: number = 1500;
  networkFilter: string = 'none';
  networkPatterns: string[] = [];
  webAutoAccept: boolean = false;
}

export function formatSize(bytes: number): string {
  if (bytes < 1000) return `${bytes} B`;
  if (bytes < 1000000) return `${(bytes / 1000).toFixed(1)} KB`;
  if (bytes < 1000000000) return `${(bytes / 1000000).toFixed(1)} MB`;
  return `${(bytes / 1000000000).toFixed(2)} GB`;
}

export function mimeForName(name: string): string {
  const ext = name.toLowerCase().split('.').pop() || '';
  if (ext === 'jpg' || ext === 'jpeg') return 'image/jpeg';
  if (ext === 'png') return 'image/png';
  if (ext === 'gif') return 'image/gif';
  if (ext === 'webp') return 'image/webp';
  if (ext === 'heic') return 'image/heic';
  if (ext === 'mp4') return 'video/mp4';
  if (ext === 'mp3') return 'audio/mpeg';
  if (ext === 'pdf') return 'application/pdf';
  if (ext === 'txt') return 'text/plain';
  return 'application/octet-stream';
}

@Observed
export class AppStore {
  readonly downloadDirectory: string = '/storage/Users/currentUser/Download/com.aloereed.aloesend';
  settings: AppSettings = new AppSettings();
  files: ShareFile[] = [];
  peers: Peer[] = [];
  favorites: Peer[] = [];
  history: HistoryEntry[] = [];
  logs: string[] = [];
  networkLogs: NetworkLogEntry[] = [];
  private errorText: string = '';
  private noticeText: string = '';
  private errorTimer: number = -1;
  private noticeTimer: number = -1;

  get error(): string { return this.errorText; }
  set error(value: string) {
    if (this.errorTimer !== -1) clearTimeout(this.errorTimer);
    this.errorText = value;
    this.errorTimer = value ? setTimeout(() => { this.errorText = ''; this.errorTimer = -1; }, 8000) : -1;
  }

  get notice(): string { return this.noticeText; }
  set notice(value: string) {
    if (this.noticeTimer !== -1) clearTimeout(this.noticeTimer);
    this.noticeText = value;
    this.noticeTimer = value ? setTimeout(() => { this.noticeText = ''; this.noticeTimer = -1; }, 3500) : -1;
  }
  busy: boolean = false;
  ready: boolean = false;
  privacyAccepted: boolean = false;
  identityResetting: boolean = false;
  onPrivacyAccepted: () => Promise<void> = async () => {};
  serverStatus: string = '未启动';
  listenerRunning: boolean = false;
  listenerPort: number = 53317;
  listenerHttps: boolean = true;
  listenerMulticast: string = '224.0.0.167';
  localIps: string[] = [];
  interfaces: LocalInterface[] = [];
  transfers: TransferView[] = [];
  pendingReceive: string = '';
  pendingPin: string = '';
  webUrl: string = '';
  webRequests: WebAccessRequest[] = [];
  webFiles: ShareFile[] = [];
  batchRemaining: number = 0;
  incomingShare: boolean = false;
  systemDark: boolean = false;
  messageTarget: Peer | undefined = undefined;
  galleryQueue: HistoryEntry[] = [];
  savingToGallery: boolean = false;
  messageDrafts: Map<string, MessageDraft> = new Map();
  onTransferCompleted: (transfer: TransferView) => void = () => {};
  onReceiveStarted: (transfer: TransferView) => void = () => {};
  onTransferActivity: (active: boolean) => void = () => {};
  onPickDownloadDirectory: (path: string) => Promise<string> = async () => '';
  downloadAccess: boolean = false;
  context: common.UIAbilityContext | undefined = undefined;
  private storage: preferences.Preferences | undefined = undefined;
  private persistentHistory: Set<string> = new Set();
  private initialization: Promise<void> | undefined = undefined;

  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.ready) return;
    if (!this.initialization) this.initialization = this.load(context);
    await this.initialization;
  }

  private async load(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    try {
      this.storage = await preferences.getPreferences(context, 'aloesend-native-v1');
      this.privacyAccepted = (await this.storage.get('privacy_policy_accepted', false)) === true;
      const saved = await this.storage.get('settings', '') as string;
      if (saved) this.settings = JSON.parse(saved) as AppSettings;
      if (!this.settings.destinationMode) this.settings.destinationMode = 'private';
      if (!this.settings.deviceModel) this.settings.deviceModel = 'HarmonyOS';
      if (!this.settings.deviceType) this.settings.deviceType = 'mobile';
      if (!this.settings.networkFilter) this.settings.networkFilter = 'none';
      if (!this.settings.networkPatterns) this.settings.networkPatterns = [];
      // Older native milestones did not persist this field. Missing must never
      // silently downgrade an existing installation to clear-text transport.
      if (typeof this.settings.https !== 'boolean') this.settings.https = true;
      if (typeof this.settings.openMessagesOnReceive !== 'boolean') this.settings.openMessagesOnReceive = false;
      if (typeof this.settings.offerGallerySave !== 'boolean') this.settings.offerGallerySave = false;
      if (typeof this.settings.reduceEffects !== 'boolean') this.settings.reduceEffects = false;
      if (typeof this.settings.pureBlack !== 'boolean') this.settings.pureBlack = false;
      this.favorites = JSON.parse(await this.storage.get('favorites', '[]') as string) as Peer[];
      this.history = JSON.parse(await this.storage.get('history', '[]') as string) as HistoryEntry[];
      this.persistentHistory = new Set(this.history.map((entry: HistoryEntry) => entry.id));
      this.applyTheme();
      this.ready = true;
      this.log('原生状态层已初始化');
    } catch (e) { this.fail('读取设置失败', e as Error); }
  }

  log(message: string): void {
    this.logs = [`${new Date().toLocaleTimeString()}  ${message}`, ...this.logs].slice(0, 300);
  }

  networkLog(category: string, message: string): void {
    const entry = new NetworkLogEntry(); entry.category = category;
    entry.message = message.replace(/[\r\n\t]/g, ' ').slice(0, 500);
    this.networkLogs = [entry, ...this.networkLogs].slice(0, 300);
  }

  async acceptPrivacy(): Promise<boolean> {
    if (this.privacyAccepted) return true;
    if (!this.storage) return false;
    try {
      await this.storage.put('privacy_policy_accepted', true);
      await this.storage.flush();
      this.privacyAccepted = true;
      return true;
    } catch (e) { this.fail('保存隐私选择失败，请重试', e as Error); return false; }
  }

  t(text: string): string { return uiText(text, this.settings.language); }
  get dark(): boolean { return this.settings.theme === 'dark' || (this.settings.theme === 'system' && this.systemDark); }
  get canvasColor(): string { return this.dark ? this.settings.pureBlack ? '#000000' : '#101318' : '#F3F5F9'; }
  get surfaceColor(): string { return this.settings.reduceEffects ? this.dark ? '#242931' : '#FFFFFF' : this.dark ? '#F0242931' : '#EFFFFFFF'; }
  get controlSurface(): string { return this.dark ? '#343A43' : '#E9EEF5'; }
  get glassColor(): string { return this.settings.reduceEffects ? this.dark ? '#2A3038' : '#FFFFFF' : this.dark ? '#D02A3038' : '#CFFFFFFF'; }
  get hairlineColor(): string { return this.dark ? '#24FFFFFF' : '#BFFFFFFF'; }
  get ambientColor(): string { return this.settings.reduceEffects || (this.dark && this.settings.pureBlack) ? this.canvasColor : this.dark ? '#17283B' : '#E2EBF9'; }
  get accentText(): string { return readableColor(this.settings.accent, this.controlSurface); }
  get accentFill(): string { return readableColor(this.settings.accent, '#FFFFFF'); }
  get dangerText(): string { return readableColor('#C44747', this.controlSurface); }

  refreshSystemTheme(): void {
    try { this.systemDark = this.context?.resourceManager.getConfigurationSync().colorMode === 0; }
    catch (_) { /* A host test context may not expose native resource configuration. */ }
  }
  tf(text: string, values: string[]): string {
    let translated = this.t(text);
    for (let index = 0; index < values.length; index++) translated = translated.replace(`{${index}}`, values[index]);
    return translated;
  }

  updateTransfer(transfer: TransferView): void {
    const wasActive = this.transfers.some((item: TransferView) => item.status === 'transferring');
    const previous = this.transfers.find((item: TransferView) => item.id === transfer.id);
    if (!transfer.activeStarted && transfer.status === 'transferring') transfer.activeStarted = Date.now();
    const snapshot = JSON.parse(JSON.stringify(transfer)) as TransferView;
    this.transfers = previous ? this.transfers.map((item: TransferView) => item.id === transfer.id ? snapshot : item) : [snapshot, ...this.transfers].slice(0, 30);
    const active = this.transfers.some((item: TransferView) => item.status === 'transferring');
    if (active !== wasActive) this.onTransferActivity(active);
    if (this.context) backgroundKeeper.sync(active, this.context,
      (message: string) => this.log(message));
    if (transfer.status === 'complete' && previous?.status !== 'complete') this.onTransferCompleted(transfer);
    if (transfer.direction === 'receive' && transfer.status === 'transferring' && previous?.status !== 'transferring') this.onReceiveStarted(transfer);
  }

  fail(title: string, error: Error): void {
    this.error = `${title}：${error.message || String(error)}`;
    this.log(this.error);
  }

  async save(): Promise<void> {
    try {
      // Replacing the settings object also notifies @Observed consumers.
      this.settings = JSON.parse(JSON.stringify(this.settings)) as AppSettings;
      await this.storage?.put('settings', JSON.stringify(this.settings));
      await this.storage?.put('favorites', JSON.stringify(this.favorites));
      await this.storage?.put('history', JSON.stringify(this.history.filter((entry: HistoryEntry) => this.persistentHistory.has(entry.id))));
      await this.storage?.flush();
    } catch (e) { this.fail('保存设置失败', e as Error); }
  }

  applyTheme(): void {
    const mode = this.settings.theme === 'dark' ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK :
      this.settings.theme === 'light' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    this.context?.getApplicationContext().setColorMode(mode);
    this.refreshSystemTheme();
  }

  async selectFiles(kind: string): Promise<void> {
    if (!this.context) return;
    if (kind === 'folder' && !canIUse('SystemCapability.FileManagement.UserFileService.FolderSelection')) {
      this.notice = '此设备不支持选择整个文件夹，可多选文件，或选择压缩包发送'; kind = 'file';
    }
    this.busy = true;
    try {
      let uris: string[] = [];
      if (kind === 'photo') {
        const options = new picker.PhotoSelectOptions();
        options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_VIDEO_TYPE;
        options.maxSelectNumber = 100;
        const result = await new picker.PhotoViewPicker(this.context).select(options);
        uris = result.photoUris;
      } else {
        const options = new picker.DocumentSelectOptions();
        options.maxSelectNumber = kind === 'folder' ? 1 : 100;
        options.selectMode = kind === 'folder' ? picker.DocumentSelectMode.FOLDER : picker.DocumentSelectMode.FILE;
        uris = await new picker.DocumentViewPicker(this.context).select(options);
      }
      for (const uri of uris) {
        if (kind === 'folder') await this.addFolder(uri, '');
        else await this.addUri(uri);
      }
    } catch (e) { this.fail('选择内容失败', e as Error); }
    finally { this.busy = false; }
  }

  async selectAttachments(kind: string): Promise<ShareFile[]> {
    if (!this.context || this.busy) return [];
    this.busy = true;
    try {
      let uris: string[];
      if (kind === 'photo') {
        const options = new picker.PhotoSelectOptions(); options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_VIDEO_TYPE; options.maxSelectNumber = 100;
        uris = (await new picker.PhotoViewPicker(this.context).select(options)).photoUris;
      } else {
        const options = new picker.DocumentSelectOptions(); options.maxSelectNumber = 100; options.selectMode = picker.DocumentSelectMode.FILE;
        uris = await new picker.DocumentViewPicker(this.context).select(options);
      }
      const files: ShareFile[] = [];
      for (const uri of uris) files.push(await this.readShareFile(uri));
      return files;
    } catch (e) { this.fail('选择内容失败', e as Error); return []; }
    finally { this.busy = false; }
  }

  private async readShareFile(uri: string, relativeName: string = ''): Promise<ShareFile> {
    const file = new ShareFile();
    file.uri = uri;
    file.name = relativeName || new fileUri.FileUri(uri).name;
    const opened = await fs.open(uri, fs.OpenMode.READ_ONLY);
    try { file.size = (await fs.stat(opened.fd)).size; }
    finally { await fs.close(opened); }
    file.mime = mimeForName(file.name);
    return file;
  }

  async addUri(uri: string, relativeName: string = ''): Promise<void> {
    if (this.files.some((item: ShareFile) => item.uri === uri)) return;
    const file = await this.readShareFile(uri, relativeName);
    if (!this.files.some((item: ShareFile) => item.uri === uri)) this.files = [...this.files, file];
  }

  async addFolder(uri: string, prefix: string): Promise<void> {
    const rootName = prefix || new fileUri.FileUri(uri).name;
    const names = await fs.listFile(uri);
    for (const name of names) {
      const childUri = `${uri}/${name}`;
      const stat = await fs.stat(childUri);
      if (stat.isDirectory()) await this.addFolder(childUri, `${rootName}/${name}`);
      else await this.addUri(childUri, `${rootName}/${name}`);
    }
  }

  addText(text: string): void {
    if (!text.trim()) return;
    const file = new ShareFile();
    file.name = text.trim().slice(0, 70);
    file.text = text;
    file.mime = 'text/plain';
    file.size = new util.TextEncoder().encodeInto(text).length;
    this.files = [...this.files, file];
    this.notice = '文字已加入发送清单';
  }

  editText(id: string, text: string): void {
    if (!text.trim()) return;
    this.files = this.files.map((file: ShareFile) => {
      if (file.id !== id || !file.text) return file;
      const edited = JSON.parse(JSON.stringify(file)) as ShareFile;
      edited.text = text; edited.name = text.trim().slice(0, 70); edited.size = new util.TextEncoder().encodeInto(text).length;
      return edited;
    });
  }

  async paste(): Promise<void> {
    try {
      if (!this.context) return;
      const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(this.context, ['ohos.permission.READ_PASTEBOARD']);
      if (result.authResults.some((value: number) => value !== 0)) { this.notice = '未授予剪贴板读取权限'; return; }
      const data = await pasteboard.getSystemPasteboard().getData();
      const text = data.getPrimaryText();
      if (text) this.addText(text);
      else this.notice = '剪贴板中没有可发送的文字';
    } catch (e) { this.fail('读取剪贴板失败', e as Error); }
  }

  async copy(text: string): Promise<void> {
    try {
      await pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text));
      this.notice = '已复制';
    } catch (e) { this.fail('复制失败', e as Error); }
  }

  removeFile(id: string): void { this.files = this.files.filter((file: ShareFile) => file.id !== id); }

  renameFile(id: string, name: string): void {
    const trimmed = name.trim();
    if (!trimmed || /[\\/:*?"<>|]/.test(trimmed) || trimmed === '.' || trimmed === '..') {
      this.error = '请输入不包含路径分隔符的文件名'; return;
    }
    this.files = this.files.map((file: ShareFile) => {
      if (file.id !== id) return file;
      const renamed = JSON.parse(JSON.stringify(file)) as ShareFile;
      renamed.name = trimmed; return renamed;
    });
  }

  get networkPending(): boolean {
    return this.listenerRunning && (this.settings.port !== this.listenerPort || this.settings.https !== this.listenerHttps || this.settings.multicast !== this.listenerMulticast);
  }

  get activeTransfers(): boolean {
    return this.batchRemaining > 0 || this.transfers.some((item: TransferView) => item.status === 'waiting' || item.status === 'transferring');
  }

  isFavorite(peer: Peer): boolean { return this.favorites.some((item: Peer) => samePeer(item, peer)); }

  toggleFavorite(peer: Peer): void {
    this.favorites = this.isFavorite(peer) ? this.favorites.filter((item: Peer) => !samePeer(item, peer)) : [...this.favorites, peer];
    this.save();
  }

  async addHistory(entry: HistoryEntry): Promise<void> {
    this.history = [entry, ...this.history].slice(0, 1000);
    if (this.settings.offerGallerySave && entry.direction === 'receive' && entry.path && this.isMedia(entry)) {
      this.galleryQueue = [...this.galleryQueue, entry];
    }
    if (this.settings.saveHistory) this.persistentHistory.add(entry.id);
    this.persistentHistory = new Set(this.history.filter((item: HistoryEntry) => this.persistentHistory.has(item.id)).map((item: HistoryEntry) => item.id));
    await this.save();
  }

  removeHistory(id: string): void {
    this.history = this.history.filter((item: HistoryEntry) => item.id !== id);
    this.save();
  }

  clearHistory(messagesOnly: boolean): void {
    this.history = messagesOnly ? this.history.filter((item: HistoryEntry) => !item.text) : [];
    this.save();
  }

  async exportFile(entry: HistoryEntry): Promise<void> {
    if (!this.context || !entry.path) return;
    try {
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [entry.name.split('/').pop() || entry.name];
      if (this.settings.destination) options.defaultFilePathUri = this.settings.destination;
      const destinations = await new picker.DocumentViewPicker(this.context).save(options);
      if (!destinations.length) return;
      const source = await fs.open(entry.path, fs.OpenMode.READ_ONLY);
      try {
        const destination = await fs.open(destinations[0], fs.OpenMode.READ_WRITE);
        try { await fs.copyFile(source.fd, destination.fd); }
        finally { await fs.close(destination); }
      } finally { await fs.close(source); }
      entry.exportedPath = destinations[0]; await this.save();
      this.notice = '文件已保存到所选位置';
    } catch (e) { this.fail('保存文件失败', e as Error); }
  }

  async openFile(entry: HistoryEntry): Promise<void> {
    if (!entry.path) return;
    try {
      await this.context?.startAbility({ action: 'ohos.want.action.viewData', uri: entry.path.startsWith('file://') ? entry.path : fileUri.getUriFromPath(entry.path), type: mimeForName(entry.name), flags: 1 });
    } catch (e) { this.fail('打开文件失败，可尝试另存为', e as Error); }
  }

  folderUri(entry: HistoryEntry): string {
    return publicParentUri(entry.exportedPath) || publicParentUri(entry.path);
  }

  async revealFile(entry: HistoryEntry): Promise<void> {
    const uri = this.folderUri(entry); if (!uri || !this.context) return;
    try {
      await this.context.startAbility({ bundleName: 'com.huawei.hmos.filemanager', abilityName: 'MainAbility', parameters: { fileUri: uri } });
    } catch (e) { this.fail('无法打开所在文件夹，可复制文件位置', e as Error); }
  }

  async chooseDestination(): Promise<void> {
    try {
      const destination = await this.pickDestination(); if (!destination) return;
      this.settings.destination = destination; this.settings.destinationMode = 'folder'; await this.save();
      this.notice = '接收文件将保存到所选目录';
    } catch (e) { this.fail('设置目录失败，仍可在历史中另存为', e as Error); }
  }

  async ensureDownloadAccess(): Promise<void> {
    if (!this.context) return;
    try {
      // Match the Flutter DownloadPlugin: DOWNLOAD grants this application's
      // Download/<bundleName> directory, not an arbitrary folder-picker URI.
      const options = new picker.DocumentSaveOptions(); options.pickerMode = picker.DocumentPickerMode.DOWNLOAD;
      const result = await new picker.DocumentViewPicker(this.context).save(options);
      if (!result.length) {
        this.downloadAccess = false;
        if (this.settings.destinationMode === 'download') { this.settings.destinationMode = 'private'; this.settings.destination = ''; await this.save(); }
        return;
      }
      await ensureDirectory(this.downloadDirectory);
      const probePath = `${this.downloadDirectory}/.access-${util.generateRandomUUID()}`;
      const probe = await fs.open(probePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      await fs.close(probe); await fs.unlink(probePath);
      this.downloadAccess = true;
      if (this.settings.destinationMode !== 'folder') {
        this.settings.destinationMode = 'download'; this.settings.destination = this.downloadDirectory; await this.save();
      }
    } catch (error) {
      this.downloadAccess = false;
      if (this.settings.destinationMode === 'download') { this.settings.destinationMode = 'private'; this.settings.destination = ''; await this.save(); }
      this.fail('下载目录授权未完成，文件仍保存在应用内', error as Error);
    }
  }

  async pickDestination(): Promise<string> {
    if (!this.context) return '';
    if (!this.downloadAccess) await this.ensureDownloadAccess();
    if (!this.downloadAccess) return '';
    const current = this.settings.destination;
    return this.onPickDownloadDirectory(current === this.downloadDirectory || current.startsWith(`${this.downloadDirectory}/`) ? current : this.downloadDirectory);
  }

  async saveReceivedCopy(entry: HistoryEntry, sessionDestination: string | undefined = undefined, sessionId: string = ''): Promise<void> {
    const destination = sessionDestination === undefined ? (this.settings.destinationMode !== 'private' ? this.settings.destination : '') : sessionDestination;
    if (!destination || !entry.path) return;
    try {
      const download = destination === this.downloadDirectory || destination.startsWith(`${this.downloadDirectory}/`);
      if (download && entry.path.startsWith(`${destination}/`)) { entry.exportedPath = entry.path; await this.save(); return; }
      if (!download) await fileShare.activatePermission([{ uri: destination, operationMode: fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE }]);
      // A unique per-transfer directory prevents overwriting unrelated user files.
      let path = download ? `${destination}/${safeRelativePath(entry.name)}` : `${destination}/AloeSend-${sessionId || entry.id}/${safeRelativePath(entry.name)}`;
      const original = path; let suffix = 1;
      while (download && await fs.access(path)) {
        const dot = original.lastIndexOf('.'); const split = dot > original.lastIndexOf('/') ? dot : original.length;
        path = `${original.slice(0, split)} (${suffix++})${original.slice(split)}`;
      }
      await ensureDirectory(path.slice(0, path.lastIndexOf('/')));
      const output = await fs.open(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      try {
        const input = await fs.open(entry.path, fs.OpenMode.READ_ONLY);
        try { await fs.copyFile(input.fd, output.fd); }
        finally { await fs.close(input); }
      } finally { await fs.close(output); }
      entry.exportedPath = path; await this.save();
    } catch (e) { this.fail('文件已接收，但另存到所选目录失败', e as Error); }
  }

  isMedia(entry: HistoryEntry): boolean {
    const mime = mimeForName(entry.name); return mime.startsWith('image/') || mime.startsWith('video/');
  }

  async saveToGallery(entries: HistoryEntry[]): Promise<void> {
    if (!this.context || this.savingToGallery) return;
    const media = entries.filter((entry: HistoryEntry) => !!entry.path && this.isMedia(entry)).slice(0, 100);
    if (!media.length) return;
    this.savingToGallery = true;
    let helper: photoAccessHelper.PhotoAccessHelper | undefined = undefined;
    try {
      helper = photoAccessHelper.getPhotoAccessHelper(this.context);
      const sources = media.map((entry: HistoryEntry) => entry.path.startsWith('file://') ? entry.path : fileUri.getUriFromPath(entry.path));
      const configs: photoAccessHelper.PhotoCreationConfig[] = media.map((entry: HistoryEntry): photoAccessHelper.PhotoCreationConfig => {
        const name = entry.name.split('/').pop() || entry.name; const dot = name.lastIndexOf('.');
        return { title: name.slice(0, dot), fileNameExtension: name.slice(dot + 1),
          photoType: mimeForName(name).startsWith('video/') ? photoAccessHelper.PhotoType.VIDEO : photoAccessHelper.PhotoType.IMAGE };
      });
      const destinations = await helper.showAssetsCreationDialog(sources, configs);
      let saved = 0;
      for (let index = 0; index < Math.min(destinations.length, media.length); index++) {
        if (!destinations[index]) continue;
        const source = await fs.open(sources[index], fs.OpenMode.READ_ONLY);
        try {
          const destination = await fs.open(destinations[index], fs.OpenMode.READ_WRITE);
          try { await fs.copyFile(source.fd, destination.fd); }
          finally { await fs.close(destination); }
        } finally { await fs.close(source); }
        media[index].galleryPath = destinations[index]; saved++;
        this.galleryQueue = this.galleryQueue.filter((entry: HistoryEntry) => entry.id !== media[index].id);
      }
      if (saved) { await this.save(); this.notice = this.tf('已保存 {0} 项到相册', [String(saved)]); }
    } catch (e) { this.fail('保存到相册失败，应用内文件仍保留', e as Error); }
    finally { await helper?.release().catch(() => {}); this.savingToGallery = false; }
  }

  async shareEntry(entry: HistoryEntry): Promise<void> {
    if (!this.context) return;
    try {
      const record: systemShare.SharedRecord = entry.text ? { utd: 'general.plain-text', content: entry.text } :
        { utd: mimeForName(entry.name).startsWith('image/') ? 'general.image' : mimeForName(entry.name).startsWith('video/') ? 'general.video' : 'general.file',
          uri: entry.path.startsWith('file://') ? entry.path : fileUri.getUriFromPath(entry.path), title: entry.name };
      const controller = new systemShare.ShareController(new systemShare.SharedData(record));
      await controller.show(this.context, { previewMode: systemShare.SharePreviewMode.DETAIL });
    } catch (e) { this.fail('打开系统分享失败', e as Error); }
  }

  async resend(entry: HistoryEntry): Promise<void> {
    try {
      if (entry.text) this.addText(entry.text);
      else if (entry.path) await this.addUri(entry.path.startsWith('file://') ? entry.path : fileUri.getUriFromPath(entry.path), entry.name);
      else { this.notice = '请重新选择原文件'; return; }
      this.incomingShare = true;
    } catch (e) { this.fail('原文件已不可用', e as Error); }
  }

  async openUrl(url: string): Promise<void> {
    if (!/^https?:\/\//i.test(url)) return;
    try { await this.context?.startAbility({ action: 'ohos.want.action.viewData', uri: url }); }
    catch (e) { this.fail('打开链接失败', e as Error); }
  }

  systemDeviceName(): string {
    try { return deviceInfo.marketName || deviceInfo.productModel || 'HarmonyOS'; }
    catch (_) { return 'HarmonyOS'; }
  }

  randomAlias(): string {
    const names = this.settings.language === 'en' ? ['Aloe', 'Mint', 'Bamboo', 'Lime', 'Cedar'] : ['芦荟', '薄荷', '竹影', '青柠', '雪松'];
    return `${names[Math.floor(Math.random() * names.length)]} ${Math.floor(1000 + Math.random() * 9000)}`;
  }
}

export const appStore: AppStore = new AppStore();
