import { preferences } from '@kit.ArkData';
import { common, ConfigurationConstant, abilityAccessCtrl } from '@kit.AbilityKit';
import { picker, fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';

export class ShareFile {
  id: string = util.generateRandomUUID();
  name: string = '';
  uri: string = '';
  size: number = 0;
  mime: string = 'application/octet-stream';
  text: string = '';
}

export class Peer {
  alias: string = '';
  ip: string = '';
  port: number = 53317;
  protocol: string = 'http';
  fingerprint: string = '';
  deviceModel: string = '';
  deviceType: string = 'desktop';
  lastSeen: number = Date.now();
}

export class HistoryEntry {
  id: string = util.generateRandomUUID();
  name: string = '';
  peer: string = '';
  direction: string = 'receive';
  time: number = Date.now();
  size: number = 0;
  path: string = '';
  text: string = '';
  status: string = 'complete';
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
  animations: boolean = true;
  visible: boolean = true;
  pin: string = '';
  port: number = 53317;
  multicast: string = '224.0.0.167';
  destination: string = '';
  sendMode: string = 'single';
  advanced: boolean = false;
  discoveryTimeout: number = 1500;
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
  settings: AppSettings = new AppSettings();
  files: ShareFile[] = [];
  peers: Peer[] = [];
  favorites: Peer[] = [];
  history: HistoryEntry[] = [];
  logs: string[] = [];
  error: string = '';
  notice: string = '';
  busy: boolean = false;
  ready: boolean = false;
  serverStatus: string = '未启动';
  localIps: string[] = [];
  context: common.UIAbilityContext | undefined = undefined;
  private storage: preferences.Preferences | undefined = undefined;

  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.ready) return;
    this.context = context;
    try {
      this.storage = await preferences.getPreferences(context, 'aloesend-native-v1');
      const saved = await this.storage.get('settings', '') as string;
      if (saved) this.settings = JSON.parse(saved) as AppSettings;
      this.favorites = JSON.parse(await this.storage.get('favorites', '[]') as string) as Peer[];
      this.history = JSON.parse(await this.storage.get('history', '[]') as string) as HistoryEntry[];
      this.applyTheme();
      this.ready = true;
      this.log('原生状态层已初始化');
    } catch (e) { this.fail('读取设置失败', e as Error); }
  }

  log(message: string): void {
    this.logs = [`${new Date().toLocaleTimeString()}  ${message}`, ...this.logs].slice(0, 300);
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
      await this.storage?.put('history', JSON.stringify(this.history));
      await this.storage?.flush();
    } catch (e) { this.fail('保存设置失败', e as Error); }
  }

  applyTheme(): void {
    const mode = this.settings.theme === 'dark' ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK :
      this.settings.theme === 'light' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    this.context?.getApplicationContext().setColorMode(mode);
  }

  async selectFiles(kind: string): Promise<void> {
    if (!this.context) return;
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
        options.maxSelectNumber = 100;
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

  async addUri(uri: string, relativeName: string = ''): Promise<void> {
    if (this.files.some((item: ShareFile) => item.uri === uri)) return;
    const file = new ShareFile();
    file.uri = uri;
    file.name = relativeName || new fileUri.FileUri(uri).name;
    const opened = await fs.open(uri, fs.OpenMode.READ_ONLY);
    try { file.size = (await fs.stat(opened.fd)).size; }
    finally { await fs.close(opened); }
    file.mime = mimeForName(file.name);
    this.files = [...this.files, file];
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
    this.files = this.files.map((file: ShareFile) => { if (file.id === id) file.name = trimmed; return file; });
  }

  isFavorite(peer: Peer): boolean { return this.favorites.some((item: Peer) => item.ip === peer.ip && item.port === peer.port); }

  toggleFavorite(peer: Peer): void {
    this.favorites = this.isFavorite(peer) ? this.favorites.filter((item: Peer) => item.ip !== peer.ip || item.port !== peer.port) : [...this.favorites, peer];
    this.save();
  }

  async addHistory(entry: HistoryEntry): Promise<void> {
    if (!this.settings.saveHistory) return;
    this.history = [entry, ...this.history].slice(0, 1000);
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
      options.newFileNames = [entry.name];
      const destinations = await new picker.DocumentViewPicker(this.context).save(options);
      if (!destinations.length) return;
      const source = await fs.open(entry.path, fs.OpenMode.READ_ONLY);
      try {
        const destination = await fs.open(destinations[0], fs.OpenMode.READ_WRITE);
        try { await fs.copyFile(source.fd, destination.fd); }
        finally { await fs.close(destination); }
      } finally { await fs.close(source); }
      this.notice = '文件已保存到所选位置';
    } catch (e) { this.fail('保存文件失败', e as Error); }
  }

  async openFile(entry: HistoryEntry): Promise<void> {
    if (!entry.path) return;
    try {
      await this.context?.startAbility({ action: 'ohos.want.action.viewData', uri: fileUri.getUriFromPath(entry.path), type: mimeForName(entry.name), flags: 1 });
    } catch (e) { this.fail('打开文件失败，可尝试另存为', e as Error); }
  }
}

export const appStore: AppStore = new AppStore();
