import { preferences } from '@kit.ArkData';
import { common, ConfigurationConstant, abilityAccessCtrl } from '@kit.AbilityKit';
import { picker, fileIo as fs, fileUri, fileShare } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';
import { pasteboard, deviceInfo, BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { backgroundKeeper } from '../platform/BackgroundKeeper';
import { uiText, resolvedLanguage, isRtlLanguage } from './Locale';
import { flutterCount } from './DynamicLocale';
import { readableColor, presetAccent } from './Colors';
import { LocalInterface, ipv4, ipv6, multicastAddress } from '../network/Addresses';
import { safeRelativePath } from '../network/Protocol';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { ensureDirectory } from '../platform/Directories';
import { publicParentUri } from '../platform/FileLocation';
import { importFlutterData } from '../platform/FlutterImport';
import { checkDownloadFolder, downloadFolderFiles } from '../platform/DownloadFolders';
import { directoryIdentity } from '../platform/DirectoryIdentity';

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
  customAlias: boolean = false;
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
  error: string = '';
  transferId: string = '';
  peerInfo: Peer | undefined = undefined;
}

export function historyStatus(entry: HistoryEntry): string {
  if (entry.status === 'waiting' || entry.status === 'pendingIncoming') return '等待确认';
  if (entry.status === 'transferring' || entry.status === 'sending' || entry.status === 'receiving') return entry.direction === 'send' ? '发送中…' : '接收中…';
  if (entry.status === 'error' || entry.status === 'failed') return '传输失败';
  if (entry.status === 'cancelled' || entry.status === 'canceled') return '已取消';
  if (entry.status === 'declined') return '已拒绝';
  if (entry.status === 'skipped') return '已跳过';
  return entry.direction === 'send' ? '已发送' : '已接收';
}

export class TransferFile {
  originalName: string = '';
  error: string = '';
  retryTransferId: string = '';
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
  selectionClosed: boolean = false;
  retrying: boolean = false;
  retryTransferId: string = '';
  offerGallerySave: boolean = false;
  id: string = '';
  storageNotice: string = '';
  peer: string = '';
  direction: string = 'send';
  status: string = 'waiting';
  error: string = '';
  files: TransferFile[] = [];
  started: number = Date.now();
  activeStarted: number = 0;
  activeBytes: number = -1;
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
  themePreset: string = 'localsend';
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
  safeTopPx: number = 0;
  safeBottomPx: number = 0;
  onThemeChanged: () => void = () => {};
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
  selecting: boolean = false;
  selectionCancelled: boolean = false;
  selectionReadCount: number = 0;
  private selectionCount: number = 0;
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
  pendingPinInvalid: boolean = false;
  webUrl: string = '';
  webStarting: boolean = false;
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
  onPickDownloadDirectory: (path: string, purpose: string) => Promise<string> = async () => '';
  downloadAccess: boolean = false;
  context: common.UIAbilityContext | undefined = undefined;
  private storage: preferences.Preferences | undefined = undefined;
  private persistence: Promise<void> = Promise.resolve();

  private persist<T>(operation: () => Promise<T>): Promise<T> {
    const pending = this.persistence.then(operation);
    this.persistence = pending.then(() => {}, () => {});
    return pending;
  }
  private persistentHistory: Set<string> = new Set();
  private initialization: Promise<void> | undefined = undefined;
  initializationError: string = '';
  flutterImportSummary: string = '';

  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.ready) return;
    if (!this.initialization) this.initialization = this.load(context);
    const pending = this.initialization;
    await pending;
    if (!this.ready && this.initialization === pending) this.initialization = undefined;
  }

  private async load(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    this.initializationError = '';
    try {
      this.storage = await preferences.getPreferences(context, 'aloesend-native-v1');
      const imported = await importFlutterData(context, this.storage);
      this.privacyAccepted = (await this.storage.get('privacy_policy_accepted', false)) === true;
      const saved = await this.storage.get('settings', '') as string;
      if (saved) {
        const previous = JSON.parse(saved) as AppSettings;
        // Before presets existed, the stored accent was the user's theme.
        if (!previous.themePreset) previous.themePreset = 'custom';
        const merged = new AppSettings();
        if (previous.alias !== undefined) merged.alias = previous.alias;
        if (previous.fingerprint !== undefined) merged.fingerprint = previous.fingerprint;
        if (previous.theme !== undefined) merged.theme = previous.theme;
        if (previous.language !== undefined) merged.language = previous.language;
        if (previous.accent !== undefined) merged.accent = previous.accent;
        if (previous.themePreset !== undefined) merged.themePreset = previous.themePreset;
        if (previous.quickSave !== undefined) merged.quickSave = previous.quickSave;
        if (previous.favoriteQuickSave !== undefined) merged.favoriteQuickSave = previous.favoriteQuickSave;
        if (previous.saveHistory !== undefined) merged.saveHistory = previous.saveHistory;
        if (previous.autoFinish !== undefined) merged.autoFinish = previous.autoFinish;
        if (previous.openMessagesOnReceive !== undefined) merged.openMessagesOnReceive = previous.openMessagesOnReceive;
        if (previous.offerGallerySave !== undefined) merged.offerGallerySave = previous.offerGallerySave;
        if (previous.animations !== undefined) merged.animations = previous.animations;
        if (previous.reduceEffects !== undefined) merged.reduceEffects = previous.reduceEffects;
        if (previous.pureBlack !== undefined) merged.pureBlack = previous.pureBlack;
        if (previous.visible !== undefined) merged.visible = previous.visible;
        if (previous.pin !== undefined) merged.pin = previous.pin;
        if (previous.port !== undefined) merged.port = previous.port;
        if (previous.multicast !== undefined) merged.multicast = previous.multicast;
        if (previous.destination !== undefined) merged.destination = previous.destination;
        if (previous.destinationMode !== undefined) merged.destinationMode = previous.destinationMode;
        if (previous.deviceModel !== undefined) merged.deviceModel = previous.deviceModel;
        if (previous.deviceType !== undefined) merged.deviceType = previous.deviceType;
        if (previous.sendMode !== undefined) merged.sendMode = previous.sendMode;
        if (previous.advanced !== undefined) merged.advanced = previous.advanced;
        if (previous.https !== undefined) merged.https = previous.https;
        if (previous.discoveryTimeout !== undefined) merged.discoveryTimeout = previous.discoveryTimeout;
        if (previous.networkFilter !== undefined) merged.networkFilter = previous.networkFilter;
        if (previous.networkPatterns !== undefined) merged.networkPatterns = previous.networkPatterns;
        if (previous.webAutoAccept !== undefined) merged.webAutoAccept = previous.webAutoAccept;
        this.settings = merged;
      }
      // Settings written by earlier builds bypassed the current form validation.
      // Recover only invalid network fields; retain identity and user choices.
      const defaults = new AppSettings();
      if (!Number.isInteger(this.settings.port) || this.settings.port < 1024 || this.settings.port > 65535) {
        this.settings.port = defaults.port;
      }
      if (!Number.isInteger(this.settings.discoveryTimeout) || this.settings.discoveryTimeout < 500 || this.settings.discoveryTimeout > 30000) {
        this.settings.discoveryTimeout = defaults.discoveryTimeout;
      }
      try { this.settings.multicast = multicastAddress(this.settings.multicast); }
      catch (_) { this.settings.multicast = defaults.multicast; }
      if (!['system', 'localsend', 'oled', 'yaru', 'custom'].includes(this.settings.themePreset)) this.settings.themePreset = 'custom';
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
      if (imported.favorites || imported.history || imported.messages || imported.skipped.length) {
        this.flutterImportSummary = this.tf('已导入 Flutter：{0} 个收藏、{1} 条历史、{2} 条消息；未识别 {3} 条（原数据保留）', [String(imported.favorites), String(imported.history), String(imported.messages), String(imported.skipped.length)]);
        this.log(`Flutter 导入：收藏 ${imported.favorites}，历史 ${imported.history}，消息 ${imported.messages}，未识别 ${imported.skipped.length}`);
      }
      this.favorites = JSON.parse(await this.storage.get('favorites', '[]') as string) as Peer[];
      // Earlier native versions did not distinguish saved remarks from device names.
      for (const favorite of this.favorites) {
        if (typeof favorite.customAlias !== 'boolean') favorite.customAlias = true;
      }
      this.history = JSON.parse(await this.storage.get('history', '[]') as string) as HistoryEntry[];
      let interrupted = false;
      for (const entry of this.history) {
        if (entry.transferId && ['waiting', 'transferring', 'sending', 'receiving'].includes(entry.status)) {
          entry.status = 'error'; entry.error = '应用已退出，传输未完成'; interrupted = true;
        }
      }
      this.persistentHistory = new Set(this.history.map((entry: HistoryEntry) => entry.id));
      if (interrupted) await this.save();
      this.applyTheme();
      this.ready = true;
      this.log('原生状态层已初始化');
    } catch (e) { this.initializationError = (e as Error).message || String(e); this.fail('读取设置失败', e as Error); }
  }

  log(message: string): void {
    this.logs = [`${new Date().toLocaleTimeString()}  ${message}`, ...this.logs].slice(0, 300);
    console.info(`[AloeSend] ${message}`);
  }

  networkLog(category: string, message: string): void {
    const entry = new NetworkLogEntry(); entry.category = category;
    entry.message = message.replace(/[\r\n\t]/g, ' ').slice(0, 500);
    this.networkLogs = [entry, ...this.networkLogs].slice(0, 300);
  }

  diagnosticSummary(lines: string[]): string {
    let version = 'unknown'; let platform = 'unknown';
    try { version = this.context?.resourceManager.getStringByNameSync('build_version') || 'unknown'; } catch (_) {}
    try { platform = `API ${deviceInfo.sdkApiVersion} · ${deviceInfo.productModel}`; } catch (_) {}
    const waiting = this.transfers.filter((item: TransferView) => item.status === 'waiting').length;
    const active = this.transfers.filter((item: TransferView) => item.status === 'transferring').length;
    return `AloeSend ${version} · ArkUI\n${new Date().toISOString()}\n${platform}\n${this.serverStatus}\n` +
      `LocalSend 2.1 · ${this.listenerHttps ? 'HTTPS / Mbed TLS 3.6.7' : 'HTTP'}\n` +
      `Port: ${this.listenerPort}\nMulticast: ${this.listenerMulticast}\nIP: ${this.localIps.join(', ')}\n` +
      `SHA-256: ${this.settings.fingerprint}\nDownload access: ${this.downloadAccess}\n` +
      `Waiting: ${waiting} · Active: ${active} · Queue: ${this.batchRemaining}\n\n${lines.join('\n')}`;
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

  async restoreSettings(): Promise<boolean> {
    if (this.activeTransfers || this.identityResetting || this.webUrl || this.webStarting) {
      this.notice = '请先结束传输并停止浏览器分享'; return false;
    }
    if (!this.storage) return false;
    const storage = this.storage;
    return this.persist(async (): Promise<boolean> => {
    if (this.activeTransfers || this.identityResetting || this.webUrl || this.webStarting) {
      this.notice = '请先结束传输并停止浏览器分享'; return false;
    }
    const previous = JSON.stringify(this.settings);
    const defaults = new AppSettings(); defaults.fingerprint = this.settings.fingerprint;
    if (this.downloadAccess) { defaults.destinationMode = 'download'; defaults.destination = this.downloadDirectory; }
    try {
      await storage.put('settings', JSON.stringify(defaults));
      await storage.flush();
      this.settings = defaults; this.galleryQueue = []; this.applyTheme();
      this.notice = this.listenerRunning ? '默认设置已恢复，网络设置重启服务后生效' : '默认设置已恢复';
      return true;
    } catch (error) {
      await storage.put('settings', previous).then(() => storage.flush()).catch(() => {});
      this.fail('恢复设置失败', error as Error); return false;
    }
    });
  }

  t(text: string): string { return uiText(text, this.settings.language); }
  get rtl(): boolean { return isRtlLanguage(this.settings.language); }
  systemAccent: string = '#3478F6';
  get accent(): string { return presetAccent(this.settings.themePreset, this.settings.accent, this.systemAccent); }
  get dark(): boolean { return this.settings.theme === 'dark' || (this.settings.theme === 'system' && this.systemDark); }
  get blackSurface(): boolean { return this.dark && (this.settings.pureBlack || this.settings.themePreset === 'oled'); }
  get canvasColor(): string {
    if (this.blackSurface) return '#000000';
    if (this.settings.themePreset === 'yaru') return this.dark ? '#252525' : '#FFFFFF';
    return this.dark ? '#101318' : '#F3F5F9';
  }
  get surfaceColor(): string {
    if (this.settings.themePreset === 'oled' && this.dark) return '#000000';
    if (this.settings.themePreset === 'yaru') return this.dark ? '#2B2B2B' : '#FFFFFF';
    return this.settings.reduceEffects ? this.dark ? '#242931' : '#FFFFFF' : this.dark ? '#F0242931' : '#EFFFFFFF';
  }
  get controlSurface(): string { return this.dark ? '#343A43' : '#E9EEF5'; }
  get glassColor(): string { return this.settings.reduceEffects ? this.dark ? '#2A3038' : '#FFFFFF' : this.dark ? '#D02A3038' : '#CFFFFFFF'; }
  get hairlineColor(): string { return this.dark ? '#24FFFFFF' : '#BFFFFFFF'; }
  get ambientColor(): string { return this.settings.reduceEffects || this.blackSurface || this.settings.themePreset === 'yaru' ? this.canvasColor : this.dark ? '#17283B' : '#E2EBF9'; }
  get accentText(): string { return readableColor(this.accent, this.controlSurface); }
  get accentFill(): string { return readableColor(this.accent, '#FFFFFF'); }
  get dangerText(): string { return readableColor('#C44747', this.controlSurface); }

  refreshSystemTheme(): void {
    try { this.systemDark = this.context?.resourceManager.getConfigurationSync().colorMode === 0; }
    catch (_) { /* A host test context may not expose native resource configuration. */ }
    try {
      const color = this.context?.resourceManager.getColorSync($r('sys.color.brand'));
      if (color !== undefined) this.systemAccent = '#' + (color & 0xFFFFFF).toString(16).padStart(6, '0').toUpperCase();
    } catch (_) { /* Keep the last known system accent if unavailable. */ }
    this.onThemeChanged();
  }
  tf(text: string, values: string[]): string {
    if ((text === '已选 {0} 项' || text === '已选 {0} 项 · {1}') && values.length >= (text.endsWith('{1}') ? 2 : 1)) {
      const selected = flutterCount('receivePage.filesCard.selected', this.settings.language, values[0]);
      return text.endsWith('{1}') ? selected + ' · ' + values[1] : selected;
    }
    return this.t(text).replace(/\{(\d+)\}/g, (placeholder: string, index: string) => {
      const position = Number(index);
      return position < values.length ? values[position] : placeholder;
    });
  }

  updateTransfer(transfer: TransferView): void {
    const wasActive = this.transfers.some((item: TransferView) => item.status === 'transferring');
    const previous = this.transfers.find((item: TransferView) => item.id === transfer.id);
    if (!transfer.activeStarted && transfer.status === 'transferring') transfer.activeStarted = Date.now();
    const snapshot = JSON.parse(JSON.stringify(transfer)) as TransferView;
    const updated = previous ? this.transfers.map((item: TransferView) => item.id === transfer.id ? snapshot : item) : [snapshot, ...this.transfers];
    // Finished rows may age out, but live tasks must retain progress and cancel.
    const liveCount = updated.filter((item: TransferView) => item.status === 'waiting' || item.status === 'transferring').length;
    let finishedSlots = Math.max(0, 30 - liveCount);
    this.transfers = updated.filter((item: TransferView) => {
      if (item.status === 'waiting' || item.status === 'transferring') return true;
      return finishedSlots-- > 0;
    });
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

  async save(): Promise<boolean> {
    if (!this.storage) return false;
    try {
      // Replacing the settings object also notifies @Observed consumers.
      this.settings = JSON.parse(JSON.stringify(this.settings)) as AppSettings;
      await this.persist(async () => {
        const settings = JSON.stringify(this.settings);
        const favorites = JSON.stringify(this.favorites);
        const history = JSON.stringify(this.history.filter((entry: HistoryEntry) => this.persistentHistory.has(entry.id)));
        await this.storage?.put('settings', settings);
        await this.storage?.put('favorites', favorites);
        await this.storage?.put('history', history);
        await this.storage?.flush();
      });
      return true;
    } catch (e) { this.fail('保存设置失败', e as Error); return false; }
  }

  applyTheme(): void {
    const mode = this.settings.theme === 'dark' ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK :
      this.settings.theme === 'light' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    this.context?.getApplicationContext().setColorMode(mode);
    this.refreshSystemTheme();
  }

  async selectFiles(kind: string): Promise<boolean> {
    if (!this.context || this.busy) return false;
    this.beginSelection();
    try {
      if (kind === 'folder' && !canIUse('SystemCapability.FileManagement.UserFileService.FolderSelection')) {
        return await this.selectDownloadFolder();
      }
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
        try { uris = await new picker.DocumentViewPicker(this.context).select(options); }
        catch (error) {
          // Some system versions advertise the capability but reject FOLDER
          // when launching the picker. An unsupported operation gets the same
          // Download picker as a device without that capability.
          if (kind !== 'folder' || (error as BusinessError).code !== 801) throw error as Error;
          return await this.selectDownloadFolder();
        }
      }
      const additions: ShareFile[] = [];
      for (const uri of uris) {
        this.checkSelection();
        if (kind === 'folder') additions.push(...await this.folderSelection(uri, '', [], () => this.checkSelection(), () => this.recordSelectedFile()));
        else { additions.push(await this.readShareFile(uri)); this.recordSelectedFile(); }
      }
      this.checkSelection();
      return this.appendSelection(additions);
    } catch (e) { if (!this.selectionCancelled) this.fail('选择内容失败', e as Error); return false; }
    finally { this.endSelection(); }
  }

  private beginSelection(): void {
    this.busy = true; this.selecting = true; this.selectionCancelled = false;
    this.selectionCount = 0; this.selectionReadCount = 0;
  }

  cancelSelection(): void { if (this.selecting) this.selectionCancelled = true; }

  private checkSelection(): void { if (this.selectionCancelled) throw new Error('Selection cancelled'); }

  private recordSelectedFile(): void {
    this.checkSelection(); this.selectionCount++;
    if (this.selectionCount === 1 || this.selectionCount % 25 === 0) this.selectionReadCount = this.selectionCount;
  }

  private endSelection(): void {
    this.selectionReadCount = this.selectionCount; this.selecting = false; this.busy = false;
    if (this.selectionCancelled) this.notice = this.t('已取消读取，原清单保留');
  }

  private async selectDownloadFolder(): Promise<boolean> {
    const path = await this.pickDownloadFolder('send');
    this.checkSelection();
    if (!path) return false;
    const selected = await downloadFolderFiles(this.downloadDirectory, path, () => this.checkSelection());
    const additions: ShareFile[] = [];
    for (const file of selected) {
      this.checkSelection();
      if (!this.files.some((item: ShareFile) => item.uri === file.path)) additions.push(await this.readShareFile(file.path, file.name));
      this.recordSelectedFile();
    }
    // Publish only after all files can be read; a failed directory must not
    // leave a partially added tree in the user's send selection.
    if (!selected.length) this.notice = '这个文件夹没有可发送的文件';
    return this.appendSelection(additions);
  }

  private appendSelection(files: ShareFile[]): boolean {
    const uris = new Set<string>(this.files.map((file: ShareFile) => file.uri));
    const additions = files.filter((file: ShareFile) => {
      if (uris.has(file.uri)) return false;
      uris.add(file.uri); return true;
    });
    if (!additions.length) return false;
    this.files = [...this.files, ...additions]; return true;
  }

  async selectAttachments(kind: string): Promise<ShareFile[]> {
    if (!this.context || this.busy) return [];
    this.beginSelection();
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
      for (const uri of uris) { this.checkSelection(); files.push(await this.readShareFile(uri)); this.recordSelectedFile(); }
      this.checkSelection();
      return files;
    } catch (e) { if (!this.selectionCancelled) this.fail('选择内容失败', e as Error); return []; }
    finally { this.endSelection(); }
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
    this.appendSelection(await this.folderSelection(uri, prefix));
  }

  private async folderSelection(uri: string, prefix: string, ancestors: string[] = [], checkpoint: () => void = () => {}, onFile: () => void = () => {}): Promise<ShareFile[]> {
    checkpoint();
    const identity = await directoryIdentity(uri);
    if (ancestors.includes(identity)) return [];
    const branch = [...ancestors, identity];
    const rootName = prefix || new fileUri.FileUri(uri).name;
    const names = await fs.listFile(uri);
    const files: ShareFile[] = [];
    for (const name of names) {
      checkpoint();
      const childUri = `${uri}/${name}`;
      const stat = await fs.stat(childUri);
      if (stat.isDirectory()) files.push(...await this.folderSelection(childUri, `${rootName}/${name}`, branch, checkpoint, onFile));
      else { files.push(await this.readShareFile(childUri, `${rootName}/${name}`)); onFile(); }
    }
    return files;
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

  async paste(): Promise<boolean> {
    try {
      if (!this.context) return false;
      const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(this.context, ['ohos.permission.READ_PASTEBOARD']);
      if (result.authResults.some((value: number) => value !== 0)) { this.notice = '未授予剪贴板读取权限'; return false; }
      const data = await pasteboard.getSystemPasteboard().getData();
      const text = data.getPrimaryText();
      if (text.trim()) { this.addText(text); return true; }
      this.notice = '剪贴板中没有可发送的文字'; return false;
    } catch (e) { this.fail('读取剪贴板失败', e as Error); return false; }
  }

  async copy(text: string): Promise<void> {
    try {
      await pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text));
      this.notice = '已复制';
    } catch (e) { this.fail('复制失败', e as Error); }
  }

  removeFile(id: string): void { this.files = this.files.filter((file: ShareFile) => file.id !== id); }

  renameFile(id: string, name: string): boolean {
    const source = this.files.find((file: ShareFile) => file.id === id);
    if (!source) return false;
    const trimmed = name.trim();
    if (!trimmed || /[\\/:*?"<>|\x00-\x1f]/.test(trimmed) || trimmed === '.' || trimmed === '..') {
      this.error = '请输入不包含路径分隔符的文件名'; return false;
    }
    this.files = this.files.map((file: ShareFile) => {
      if (file.id !== id) return file;
      const renamed = JSON.parse(JSON.stringify(file)) as ShareFile;
      renamed.name = file.name.slice(0, file.name.lastIndexOf('/') + 1) + trimmed; return renamed;
    });
    this.error = ''; return true;
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

  updateFavorite(peer: Peer, alias: string, address: string, portText: string): Peer {
    const index = this.favorites.findIndex((item: Peer) => samePeer(item, peer));
    if (index < 0) throw new Error('此设备已不在收藏中');
    const ip = address.trim().replace(/^\[([^\]]+)\]$/, '$1');
    if (!ipv4(ip) && !ipv6(ip)) throw new Error('请输入有效 IP 地址');
    const port = Number(portText.trim());
    if (!/^\d+$/.test(portText.trim()) || !Number.isInteger(port) || port < 1 || port > 65535) throw new Error('端口无效');
    if (this.favorites.some((item: Peer, itemIndex: number) => itemIndex !== index && item.ip === ip && item.port === port)) {
      throw new Error('此地址已被另一台收藏设备使用');
    }
    const updated = JSON.parse(JSON.stringify(this.favorites[index])) as Peer;
    updated.alias = alias.trim() || updated.alias;
    updated.customAlias = updated.customAlias || updated.alias !== this.favorites[index].alias;
    updated.ip = ip; updated.port = port;
    // Keep the saved identity and protocol when editing an offline endpoint.
    this.favorites = this.favorites.map((item: Peer, itemIndex: number) => itemIndex === index ? updated : item);
    this.save();
    return updated;
  }

  async addHistory(entry: HistoryEntry, offerGallerySave: boolean = this.settings.offerGallerySave): Promise<void> {
    this.history = [entry, ...this.history];
    if (offerGallerySave && entry.direction === 'receive' && entry.path && this.isMedia(entry)) {
      this.galleryQueue = [...this.galleryQueue, entry];
    }
    if (this.settings.saveHistory) this.persistentHistory.add(entry.id);
    this.persistentHistory = new Set(this.history.filter((item: HistoryEntry) => this.persistentHistory.has(item.id)).map((item: HistoryEntry) => item.id));
    await this.save();
  }

  async updateOutgoingHistory(transfer: TransferView, files: ShareFile[], create: boolean = false, declined: boolean = false): Promise<void> {
    const updates: Map<string, HistoryEntry> = new Map();
    const existingEntries = new Map(this.history.map((entry: HistoryEntry): [string, HistoryEntry] => [entry.id, entry]));
    const transferFiles = new Map(transfer.files.map((file: TransferFile): [string, TransferFile] => [file.id, file]));
    const additions: HistoryEntry[] = [];
    for (const file of files) {
      const id = `send:${transfer.id}:${file.id}`;
      const existing = existingEntries.get(id);
      // Deleting a message while it is being sent must remain effective.
      if (!existing && !create) continue;
      const entry = existing ? JSON.parse(JSON.stringify(existing)) as HistoryEntry : new HistoryEntry();
      entry.id = id; entry.transferId = transfer.id; entry.name = file.name;
      entry.peer = transfer.peer; entry.peerInfo = transfer.peerInfo; entry.direction = 'send';
      entry.time = transfer.started; entry.size = file.size; entry.text = file.text; entry.path = file.uri;
      entry.status = transferFiles.get(file.id)?.status || transfer.status;
      if (declined && entry.status === 'error') entry.status = 'declined';
      entry.error = entry.status === 'error' || entry.status === 'declined' || entry.status === 'cancelled' ?
        (transferFiles.get(file.id)?.error || transfer.error) : '';
      updates.set(id, entry);
      if (!existing) {
        additions.push(entry);
        if (this.settings.saveHistory) this.persistentHistory.add(id);
      }
    }
    this.history = [...additions.reverse(), ...this.history.map((entry: HistoryEntry) => updates.get(entry.id) || entry)];
    await this.save();
  }

  async updateIncomingHistory(transfer: TransferView, create: boolean = false): Promise<void> {
    const existingEntries = new Map(this.history.map((entry: HistoryEntry): [string, HistoryEntry] => [entry.id, entry]));
    const updates: Map<string, HistoryEntry> = new Map(); const additions: HistoryEntry[] = [];
    for (const file of transfer.files) {
      const id = `receive:${transfer.id}:${file.id}`; const existing = existingEntries.get(id);
      if (!existing && !create) continue;
      const entry = existing ? JSON.parse(JSON.stringify(existing)) as HistoryEntry : new HistoryEntry();
      entry.id = id; entry.transferId = transfer.id; entry.name = file.name; entry.time = transfer.started;
      entry.direction = 'receive'; entry.peer = transfer.peer; entry.peerInfo = transfer.peerInfo; entry.size = file.size;
      if (!existing) entry.text = file.preview;
      entry.status = file.status;
      if (file.status !== 'complete') {
        if (!file.selected && transfer.status !== 'waiting') entry.status = 'skipped';
        else if (['cancelled', 'declined'].includes(transfer.status)) entry.status = transfer.status;
      }
      // Paths become available only after checksum verification and rename.
      entry.path = file.status === 'complete' ? file.path : '';
      entry.error = ['error', 'cancelled', 'declined'].includes(entry.status) ? (file.error || transfer.error) : '';
      updates.set(id, entry);
      if (!existing) { additions.push(entry); if (this.settings.saveHistory) this.persistentHistory.add(id); }
    }
    this.history = [...additions.reverse(), ...this.history.map((entry: HistoryEntry) => updates.get(entry.id) || entry)];
    await this.save();
  }

  async completeIncomingHistory(entry: HistoryEntry, transfer: TransferView, file: TransferFile): Promise<void> {
    entry.id = `receive:${transfer.id}:${file.id}`; entry.transferId = transfer.id; entry.time = transfer.started;
    entry.status = 'complete';
    const existing = this.history.find((item: HistoryEntry) => item.id === entry.id);
    if (existing) this.history = this.history.map((item: HistoryEntry) => item.id === entry.id ? entry : item);
    if (transfer.offerGallerySave && entry.path && this.isMedia(entry)) this.galleryQueue = [...this.galleryQueue, entry];
    await this.save();
  }

  removeHistory(id: string): void {
    this.removeHistories([id]);
  }

  removeHistories(ids: string[]): void {
    const removed = new Set(ids);
    this.history = this.history.filter((item: HistoryEntry) => !removed.has(item.id));
    for (const id of ids) this.persistentHistory.delete(id);
    this.save();
  }

  clearHistory(messagesOnly: boolean): void {
    this.history = messagesOnly ? this.history.filter((item: HistoryEntry) => !item.text) : [];
    this.save();
  }

  async exportFile(entry: HistoryEntry): Promise<void> {
    if (!this.context || (!entry.path && !entry.exportedPath)) return;
    try {
      const sourcePath = await this.readableFilePath(entry);
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [entry.name.split('/').pop() || entry.name];
      if (this.settings.destination) options.defaultFilePathUri = this.settings.destination;
      const destinations = await new picker.DocumentViewPicker(this.context).save(options);
      if (!destinations.length) return;
      const source = await fs.open(sourcePath, fs.OpenMode.READ_ONLY);
      try {
        const destination = await fs.open(destinations[0], fs.OpenMode.READ_WRITE);
        try { await fs.copyFile(source.fd, destination.fd); }
        finally { await fs.close(destination); }
      } finally { await fs.close(source); }
      this.updateHistoryLocation(entry, destinations[0]); await this.save();
      this.notice = '文件已保存到所选位置';
    } catch (e) { this.fail('保存文件失败', e as Error); }
  }

  async openFile(entry: HistoryEntry): Promise<void> {
    if (!this.context || (!entry.path && !entry.exportedPath)) return;
    try {
      const sourcePath = await this.readableFilePath(entry);
      await this.context.startAbility({ action: 'ohos.want.action.viewData', uri: sourcePath.startsWith('file://') ? sourcePath : fileUri.getUriFromPath(sourcePath), type: mimeForName(entry.name), flags: 1 });
    } catch (e) { this.fail('打开文件失败，可尝试另存为', e as Error); }
  }

  async readableFilePath(entry: HistoryEntry): Promise<string> {
    const candidates = [entry.path, entry.exportedPath].filter((path: string) => !!path);
    for (const path of Array.from(new Set(candidates))) {
      try {
        const file = await fs.open(path, fs.OpenMode.READ_ONLY);
        await fs.close(file); return path;
      } catch (_) { /* Try the recorded exported copy if the original is unavailable. */ }
    }
    throw new Error(this.t('文件和另存副本均不可用，请检查是否已移动或删除'));
  }

  async openSelectedFile(file: ShareFile): Promise<void> {
    if (!file.uri) return;
    try {
      await this.context?.startAbility({ action: 'ohos.want.action.viewData',
        uri: file.uri.startsWith('file://') ? file.uri : fileUri.getUriFromPath(file.uri),
        type: file.mime, flags: 1 });
    } catch (e) { this.fail('打开所选文件失败', e as Error); }
  }

  folderUri(entry: HistoryEntry): string {
    return publicParentUri(entry.exportedPath) || publicParentUri(entry.path);
  }

  updateHistoryLocation(entry: HistoryEntry, location: string, gallery: boolean = false): void {
    if (gallery) entry.galleryPath = location; else entry.exportedPath = location;
    this.history = this.history.map((item: HistoryEntry) => {
      if (item.id !== entry.id) return item;
      const current = JSON.parse(JSON.stringify(item)) as HistoryEntry;
      if (gallery) current.galleryPath = location; else current.exportedPath = location;
      return current;
    });
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
    return this.pickDownloadFolder('save');
  }

  async pickDownloadFolder(purpose: string): Promise<string> {
    if (!this.context) return '';
    if (!this.downloadAccess) await this.ensureDownloadAccess();
    if (!this.downloadAccess) return '';
    const current = this.settings.destination;
    const selected = await this.onPickDownloadDirectory(current === this.downloadDirectory || current.startsWith(`${this.downloadDirectory}/`) ? current : this.downloadDirectory, purpose);
    if (selected) await checkDownloadFolder(this.downloadDirectory, selected);
    return selected;
  }

  async saveReceivedCopy(entry: HistoryEntry, sessionDestination: string | undefined = undefined, sessionId: string = ''): Promise<void> {
    const destination = sessionDestination === undefined ? (this.settings.destinationMode !== 'private' ? this.settings.destination : '') : sessionDestination;
    if (!destination || !entry.path) return;
    try {
      const download = destination === this.downloadDirectory || destination.startsWith(`${this.downloadDirectory}/`);
      if (download && entry.path.startsWith(`${destination}/`)) { this.updateHistoryLocation(entry, entry.path); await this.save(); return; }
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
      this.updateHistoryLocation(entry, path); await this.save();
    } catch (e) { this.fail('文件已接收，但另存到所选目录失败', e as Error); }
  }

  isMedia(entry: HistoryEntry): boolean {
    const mime = mimeForName(entry.name); return mime.startsWith('image/') || mime.startsWith('video/');
  }

  async saveToGallery(entries: HistoryEntry[]): Promise<void> {
    if (!this.context || this.savingToGallery) return;
    const media = entries.filter((entry: HistoryEntry) => (!!entry.path || !!entry.exportedPath) && this.isMedia(entry)).slice(0, 100);
    if (!media.length) return;
    this.savingToGallery = true;
    let helper: photoAccessHelper.PhotoAccessHelper | undefined = undefined;
    let saved = 0;
    try {
      const sources: string[] = [];
      for (const entry of media) {
        const path = await this.readableFilePath(entry);
        sources.push(path.startsWith('file://') ? path : fileUri.getUriFromPath(path));
      }
      helper = photoAccessHelper.getPhotoAccessHelper(this.context);
      const configs: photoAccessHelper.PhotoCreationConfig[] = media.map((entry: HistoryEntry): photoAccessHelper.PhotoCreationConfig => {
        const name = entry.name.split('/').pop() || entry.name; const dot = name.lastIndexOf('.');
        return { title: name.slice(0, dot), fileNameExtension: name.slice(dot + 1),
          photoType: mimeForName(name).startsWith('video/') ? photoAccessHelper.PhotoType.VIDEO : photoAccessHelper.PhotoType.IMAGE };
      });
      const destinations = await helper.showAssetsCreationDialog(sources, configs);
      for (let index = 0; index < Math.min(destinations.length, media.length); index++) {
        if (!destinations[index]) continue;
        const source = await fs.open(sources[index], fs.OpenMode.READ_ONLY);
        try {
          const destination = await fs.open(destinations[index], fs.OpenMode.READ_WRITE);
          try { await fs.copyFile(source.fd, destination.fd); }
          finally { await fs.close(destination); }
        } finally { await fs.close(source); }
        this.updateHistoryLocation(media[index], destinations[index], true); saved++;
        this.galleryQueue = this.galleryQueue.filter((entry: HistoryEntry) => entry.id !== media[index].id);
      }
      if (saved) this.notice = this.tf('已保存 {0} 项到相册', [String(saved)]);
    } catch (e) {
      this.fail(saved ? this.tf('已保存 {0} 项，其余文件未保存到相册', [String(saved)]) : '保存到相册失败，应用内文件仍保留', e as Error);
    } finally {
      if (saved) await this.save();
      await helper?.release().catch(() => {}); this.savingToGallery = false;
    }
  }

  async shareEntry(entry: HistoryEntry): Promise<void> {
    if (!this.context || (!entry.text && !entry.path && !entry.exportedPath)) return;
    try {
      const path = entry.text ? '' : await this.readableFilePath(entry);
      const record: systemShare.SharedRecord = entry.text ? { utd: 'general.plain-text', content: entry.text } :
        { utd: mimeForName(entry.name).startsWith('image/') ? 'general.image' : mimeForName(entry.name).startsWith('video/') ? 'general.video' : 'general.file',
          uri: path.startsWith('file://') ? path : fileUri.getUriFromPath(path), title: entry.name };
      const controller = new systemShare.ShareController(new systemShare.SharedData(record));
      await controller.show(this.context, { previewMode: systemShare.SharePreviewMode.DETAIL });
    } catch (e) { this.fail('打开系统分享失败', e as Error); }
  }

  async resend(entry: HistoryEntry): Promise<void> {
    await this.resendEntries([entry]);
  }

  async resendEntries(entries: HistoryEntry[]): Promise<boolean> {
    if (!entries.length || this.busy) return false;
    this.busy = true;
    try {
      const additions: ShareFile[] = []; const uris: Set<string> = new Set();
      for (const entry of entries) {
        if (entry.text) {
          const file = new ShareFile(); file.name = entry.name || entry.text.slice(0, 70); file.text = entry.text;
          file.mime = 'text/plain'; file.size = new util.TextEncoder().encodeInto(entry.text).length; additions.push(file);
        } else if (entry.path || entry.exportedPath) {
          const path = await this.readableFilePath(entry);
          const uri = path.startsWith('file://') ? path : fileUri.getUriFromPath(path);
          if (!uris.has(uri)) { additions.push(await this.readShareFile(uri, entry.name)); uris.add(uri); }
        } else { this.notice = '请重新选择原文件'; return false; }
      }
      // Read every source before publishing. Existing selection and drafts
      // remain intact if any file was removed or its permission expired.
      this.files = [...this.files, ...additions.filter((file: ShareFile) => !!file.text || !this.files.some((selected: ShareFile) => selected.uri === file.uri))];
      this.incomingShare = true; return true;
    } catch (e) { this.fail('原文件已不可用', e as Error); return false; }
    finally { this.busy = false; }
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
    const names = resolvedLanguage(this.settings.language).startsWith('zh') ? ['芦荟', '薄荷', '竹影', '青柠', '雪松'] : ['Aloe', 'Mint', 'Bamboo', 'Lime', 'Cedar'];
    return `${names[Math.floor(Math.random() * names.length)]} ${Math.floor(1000 + Math.random() * 9000)}`;
  }
}

export const appStore: AppStore = new AppStore();

