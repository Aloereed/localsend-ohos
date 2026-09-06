import { AppStore, HistoryEntry, formatSize, mimeForName } from '../model/AppStore';
import { AppIcon } from './AppIcon';

@Component
export struct FileDetailsView {
  @ObjectLink store: AppStore;
  @Prop entry: HistoryEntry = new HistoryEntry();

  current(): HistoryEntry {
    return this.store.history.find((item: HistoryEntry) => item.id === this.entry.id) || this.entry;
  }

  value(label: string): string {
    const entry = this.current();
    if (label === '名称') return entry.name;
    if (label === '大小与类型') return `${formatSize(entry.size)} · ${mimeForName(entry.name)}`;
    if (label === '设备') return entry.peer;
    if (label === '时间') return new Date(entry.time).toLocaleString();
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
    }.width('100%').padding({ top: 8, bottom: 8 })
  }

  build() {
    Column({ space: 16 }) {
      Text(this.store.t('文件详情')).fontSize(23).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).width('100%')
      Scroll() {
        Column({ space: 10 }) {
          if (this.current().path && mimeForName(this.current().name).startsWith('image/')) {
            Image(this.current().path.startsWith('file://') ? this.current().path : `file://${this.current().path}`).width('100%').height(260).objectFit(ImageFit.Contain).borderRadius(18)
          } else {
            AppIcon({ name: this.current().text ? 'text' : 'file', iconSize: 48, tint: this.store.accentText })
          }
          this.field('名称')
          this.field('大小与类型')
          this.field('设备')
          this.field('时间')
          if (this.current().text) { this.field('文字') }
          if (this.current().exportedPath) { this.field('已另存到') }
          if (this.current().galleryPath) { this.field('相册副本') }
          if (this.current().path) { this.field('文件位置') }
        }.width('100%').padding({ bottom: 20 })
      }.width('100%').layoutWeight(1)
      if (this.current().path) {
        Row({ space: 12 }) {
          Button(this.store.t('打开')).layoutWeight(1).height(48).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText)
            .onClick(() => this.store.openFile(this.current()))
          if (this.store.folderUri(this.current())) {
            Button(this.store.t('所在文件夹')).layoutWeight(1).height(48).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText)
              .onClick(() => this.store.revealFile(this.current()))
          }
        }.width('100%')
      }
      if (this.current().path && this.store.isMedia(this.current())) {
        Button(this.store.t('保存到相册')).width('100%').height(48).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText)
          .enabled(!this.store.savingToGallery).onClick(() => this.store.saveToGallery([this.current()]))
      }
      if (/^https?:\/\/\S+$/i.test(this.current().text.trim())) {
        Button(this.store.t('打开链接')).width('100%').height(48).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText)
          .onClick(() => this.store.openUrl(this.current().text.trim()))
      }
      Row({ space: 12 }) {
        Button(this.store.t('分享')).layoutWeight(1).height(48).backgroundColor(this.store.accentFill).onClick(() => this.store.shareEntry(this.current()))
        if (this.current().path) {
          Button(this.store.t('另存为')).layoutWeight(1).height(48).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText).onClick(() => this.store.exportFile(this.current()))
        }
      }.width('100%')
    }.width('100%').height('100%').padding(24)
  }
}
