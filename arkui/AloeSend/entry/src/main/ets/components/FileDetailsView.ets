import { AppStore, HistoryEntry, formatSize, mimeForName, historyStatus } from '../model/AppStore';
import { AppIcon } from './AppIcon';
import { fileUri } from '@kit.CoreFileKit';

@Component
export struct FileDetailsView {
  @ObjectLink store: AppStore;
  @Prop @Watch('refreshPreview') entry: HistoryEntry = new HistoryEntry();
  @State previewPath: string = '';
  private previewRequest: number = 0;

  aboutToAppear(): void { this.refreshPreview(); }
  aboutToDisappear(): void { this.previewRequest++; }

  async refreshPreview(): Promise<void> {
    const request = ++this.previewRequest;
    const entry = this.current();
    this.previewPath = '';
    if (!mimeForName(entry.name).startsWith('image/')) return;
    try {
      const path = await this.store.readableFilePath(entry);
      if (request === this.previewRequest) {
        this.previewPath = path.startsWith('file://') ? path : fileUri.getUriFromPath(path);
      }
    } catch (_) { /* Unavailable files retain their details and file icon. */ }
  }

  async exportCurrent(): Promise<void> {
    const request = this.previewRequest;
    await this.store.exportFile(this.current());
    if (request === this.previewRequest) await this.refreshPreview();
  }

  current(): HistoryEntry {
    return this.store.history.find((item: HistoryEntry) => item.id === this.entry.id) || this.entry;
  }

  value(label: string): string {
    const entry = this.current();
    if (label === '名称') return entry.name;
    if (label === '大小与类型') return `${formatSize(entry.size)} · ${mimeForName(entry.name)}`;
    if (label === '设备') return entry.peer;
    if (label === '时间') return new Date(entry.time).toLocaleString();
    if (label === '状态') return this.store.t(historyStatus(entry));
    if (label === '失败原因') return this.store.t(entry.error);
    if (label === '文字') return entry.text;
    if (label === '已另存到') return entry.exportedPath;
    if (label === '相册副本') return entry.galleryPath;
    return entry.path;
  }

  @Builder
  field(label: string) {
    Column({ space: 6 }) {
      Text(this.store.t(label)).fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
      Text(this.value(label)).fontSize(15).lineHeight(22).fontColor($r('sys.color.font_primary')).width('100%').copyOption(CopyOptions.LocalDevice)
        .direction(['文件位置', '已另存到', '相册副本', '大小与类型'].includes(label) ? Direction.Ltr : Direction.Auto)
    }.width('100%').padding({ top: 8, bottom: 8 })
  }

  build() {
    Column({ space: 16 }) {
      Text(this.store.t('文件详情')).fontSize(23).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).width('100%')
      Scroll() {
        Column({ space: 10 }) {
          if (this.previewPath) {
            Image(this.previewPath).width('100%').height(260).objectFit(ImageFit.Contain).borderRadius(18)
              .accessibilityText(this.current().name).onError(() => { this.previewPath = ''; })
          } else {
            AppIcon({ name: this.current().text ? 'text' : 'file', iconSize: 48, tint: this.store.accentText })
          }
          this.field('名称')
          this.field('大小与类型')
          this.field('设备')
          this.field('时间')
          this.field('状态')
          if (this.current().error) { this.field('失败原因') }
          if (this.current().text) { this.field('文字') }
          if (this.current().exportedPath) { this.field('已另存到') }
          if (this.current().galleryPath) { this.field('相册副本') }
          if (this.current().path) { this.field('文件位置') }
      if (this.current().path || this.current().exportedPath) {
        Row({ space: 12 }) {
          Button(this.store.t('打开')).layoutWeight(1).height(48).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText)
            .onClick(() => this.store.openFile(this.current()))
          if (this.store.folderUri(this.current())) {
            Button(this.store.t('所在文件夹')).layoutWeight(1).height(48).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText)
              .onClick(() => this.store.revealFile(this.current()))
          }
        }.width('100%')
      }
      if ((this.current().path || this.current().exportedPath) && this.store.isMedia(this.current())) {
        Button(this.store.t('保存到相册')).width('100%').height(48).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText)
          .enabled(!this.store.savingToGallery).onClick(() => this.store.saveToGallery([this.current()]))
      }
      if (/^https?:\/\/\S+$/i.test(this.current().text.trim())) {
        Button(this.store.t('打开链接')).width('100%').height(48).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText)
          .onClick(() => this.store.openUrl(this.current().text.trim()))
      }
      if (this.current().text || this.current().path || this.current().exportedPath) { Row({ space: 12 }) {
        Button(this.store.t('分享')).layoutWeight(1).height(48).backgroundColor(this.store.accentFill).onClick(() => this.store.shareEntry(this.current()))
        if (this.current().path || this.current().exportedPath) {
          Button(this.store.t('另存为')).layoutWeight(1).height(48).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText).onClick(() => this.exportCurrent())
        }
      }.width('100%') }
        }.width('100%').padding({ bottom: 20 })
      }.width('100%').layoutWeight(1)
    }.width('100%').height('100%').direction(this.store.rtl ? Direction.Rtl : Direction.Ltr).padding(24)
  }
}
