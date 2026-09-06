import { AppStore, HistoryEntry, formatSize, mimeForName } from '../model/AppStore';
import { AppIcon } from './AppIcon';

@Component
export struct FileDetailsView {
  @ObjectLink store: AppStore;
  @Prop entry: HistoryEntry = new HistoryEntry();

  @Builder
  field(label: string, value: string) {
    Column({ space: 6 }) {
      Text(this.store.t(label)).fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
      Text(value).fontSize(15).lineHeight(22).fontColor($r('sys.color.font_primary')).width('100%').copyOption(CopyOptions.LocalDevice)
    }.width('100%').padding({ top: 8, bottom: 8 })
  }

  build() {
    Column({ space: 16 }) {
      Text(this.store.t('文件详情')).fontSize(23).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).width('100%')
      Scroll() {
        Column({ space: 10 }) {
          if (this.entry.path && mimeForName(this.entry.name).startsWith('image/')) {
            Image(this.entry.path.startsWith('file://') ? this.entry.path : `file://${this.entry.path}`).width('100%').height(260).objectFit(ImageFit.Contain).borderRadius(18)
          } else {
            AppIcon({ name: this.entry.text ? 'text' : 'file', iconSize: 48, tint: this.store.accentText })
          }
          this.field('名称', this.entry.name)
          this.field('大小与类型', `${formatSize(this.entry.size)} · ${mimeForName(this.entry.name)}`)
          this.field('设备', this.entry.peer)
          this.field('时间', new Date(this.entry.time).toLocaleString())
          if (this.entry.text) { this.field('文字', this.entry.text) }
          if (this.entry.exportedPath) { this.field('已另存到', this.entry.exportedPath) }
          if (this.entry.galleryPath) { this.field('相册副本', this.entry.galleryPath) }
          if (this.entry.path) { this.field('文件位置', this.entry.path) }
        }.width('100%').padding({ bottom: 20 })
      }.width('100%').layoutWeight(1)
      if (this.entry.path) {
        Row({ space: 12 }) {
          Button(this.store.t('打开')).layoutWeight(1).height(48).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText)
            .onClick(() => this.store.openFile(this.entry))
          if (this.store.folderUri(this.entry)) {
            Button(this.store.t('所在文件夹')).layoutWeight(1).height(48).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText)
              .onClick(() => this.store.revealFile(this.entry))
          }
        }.width('100%')
      }
      if (this.entry.path && this.store.isMedia(this.entry)) {
        Button(this.store.t('保存到相册')).width('100%').height(48).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText)
          .enabled(!this.store.savingToGallery).onClick(() => this.store.saveToGallery([this.entry]))
      }
      if (/^https?:\/\/\S+$/i.test(this.entry.text.trim())) {
        Button(this.store.t('打开链接')).width('100%').height(48).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText)
          .onClick(() => this.store.openUrl(this.entry.text.trim()))
      }
      Row({ space: 12 }) {
        Button(this.store.t('分享')).layoutWeight(1).height(48).backgroundColor(this.store.accentFill).onClick(() => this.store.shareEntry(this.entry))
        if (this.entry.path) {
          Button(this.store.t('另存为')).layoutWeight(1).height(48).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText).onClick(() => this.store.exportFile(this.entry))
        }
      }.width('100%')
    }.width('100%').height('100%').padding(24)
  }
}
