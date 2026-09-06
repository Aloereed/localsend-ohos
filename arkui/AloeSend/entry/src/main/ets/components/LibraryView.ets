import { AppStore, HistoryEntry, formatSize } from '../model/AppStore';
import { EmptyState } from './EmptyState';
import { AppIcon } from './AppIcon';
import { LengthMetrics } from '@kit.ArkUI';

@Component
export struct LibraryView {
  @ObjectLink store: AppStore;
  @Prop messagesOnly: boolean = true;
  @State query: string = '';
  @State preview: HistoryEntry = new HistoryEntry();
  @State showPreview: boolean = false;

  @Builder
  previewSheet() {
    Column({ space: 18 }) {
      Text(this.preview.name).fontSize(20).fontWeight(FontWeight.Medium).maxLines(2).fontColor($r('sys.color.font_primary'))
      Image(this.preview.path.startsWith('file://') ? this.preview.path : `file://${this.preview.path}`)
        .width('100%').layoutWeight(1).objectFit(ImageFit.Contain)
      Row({ space: 12 }) {
        Button(this.store.t('分享')).layoutWeight(1).onClick(() => this.store.shareEntry(this.preview)).backgroundColor(this.store.accentFill)
        Button(this.store.t('另存为')).layoutWeight(1).onClick(() => this.store.exportFile(this.preview)).backgroundColor(this.store.accentFill)
      }.width('100%')
    }.padding(24).width('100%').height('100%')
  }

  entries(): HistoryEntry[] {
    return this.store.history.filter((entry: HistoryEntry) =>
      (!this.messagesOnly || !!entry.text) && `${entry.name} ${entry.text} ${entry.peer}`.toLowerCase().includes(this.query.toLowerCase()));
  }

  build() {
    Column({ space: 16 }) {
      Search({ value: this.query, placeholder: this.messagesOnly ? this.store.t('搜索文字、链接、设备') : this.store.t('搜索文件或设备') })
        .onChange((value: string) => this.query = value)
      if (this.entries().length === 0) {
        EmptyState({ icon: this.messagesOnly ? 'message' : 'history', title: this.query ? this.store.t('没有匹配的记录') : this.messagesOnly ? this.store.t('还没有消息') : this.store.t('还没有传输记录'),
          description: this.query ? this.store.t('试试文件名、文字内容或设备名称。') : this.store.t('收到的文字、链接和文件会整理在这里，仅保存在你的设备中。'), accent: this.store.accentText })
      }
      ForEach(this.entries(), (entry: HistoryEntry) => {
        Column({ space: 12 }) {
          Row() {
            AppIcon({ name: entry.direction === 'receive' ? 'receive' : 'send', iconSize: 18, tint: this.store.accentText })
            Text(entry.peer || this.store.t('本机')).fontWeight(FontWeight.Medium).fontSize(15).layoutWeight(1).fontColor($r('sys.color.font_primary'))
            Text(entry.direction === 'receive' ? this.store.t('接收') : this.store.t('发送')).fontSize(12).fontColor(this.store.accentText)
          }.width('100%')
          Text(entry.text || entry.name).fontSize(16).lineHeight(24).copyOption(CopyOptions.LocalDevice)
            .width('100%').fontColor($r('sys.color.font_primary'))
          Text(`${new Date(entry.time).toLocaleString()} · ${formatSize(entry.size)}`)
            .fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(10) } }) {
            if (entry.text) {
              Button(this.store.t('复制')).onClick(() => this.store.copy(entry.text)).fontColor(this.store.accentText).backgroundColor($r('sys.color.comp_background_tertiary'))
            } else if (entry.path) {
              Button(this.store.t('打开')).onClick(() => {
                if (/\.(png|jpe?g|gif|webp|heic)$/i.test(entry.name)) { this.preview = entry; this.showPreview = true; }
                else this.store.openFile(entry);
              }).fontColor(this.store.accentText).backgroundColor($r('sys.color.comp_background_tertiary'))
              Button(this.store.t('另存为')).onClick(() => this.store.exportFile(entry)).fontColor(this.store.accentText).backgroundColor($r('sys.color.comp_background_tertiary'))
            }
            Button(this.store.t('再次发送')).onClick(() => this.store.resend(entry)).fontColor(this.store.accentText).backgroundColor($r('sys.color.comp_background_tertiary'))
            if (entry.text || entry.path) {
              Button(this.store.t('分享')).onClick(() => this.store.shareEntry(entry)).fontColor(this.store.accentText).backgroundColor($r('sys.color.comp_background_tertiary'))
            }
            Button(this.store.t('删除')).onClick(() => {
              AlertDialog.show({ title: this.store.t('删除这条记录？'), message: this.store.t('不会删除已经保存的文件。'),
                primaryButton: { value: this.store.t('取消'), action: () => {} },
                secondaryButton: { value: this.store.t('删除'), action: () => this.store.removeHistory(entry.id) } });
            }).fontColor(this.store.dangerText).backgroundColor($r('sys.color.comp_background_tertiary'))
          }.width('100%')
        }.padding(20).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24)
      }, (entry: HistoryEntry) => entry.id)
      if (this.entries().length > 0) {
        Button(this.store.t('清空记录')).fontColor(this.store.dangerText).backgroundColor($r('sys.color.comp_background_primary')).onClick(() => {
          AlertDialog.show({ title: this.store.t('清空记录？'), message: this.store.t('此操作无法撤销，已保存的文件不受影响。'),
            primaryButton: { value: this.store.t('取消'), action: () => {} },
            secondaryButton: { value: this.store.t('清空'), action: () => this.store.clearHistory(this.messagesOnly) } });
        })
      }
    }.width('100%').bindSheet($$this.showPreview, this.previewSheet(), { height: SheetSize.LARGE, showClose: true })
  }
}
