import { AppStore, HistoryEntry, formatSize, historyStatus } from '../model/AppStore';
import { EmptyState } from './EmptyState';
import { AppIcon } from './AppIcon';
import { LengthMetrics } from '@kit.ArkUI';
import { FileDetailsView } from './FileDetailsView';

@Component
export struct LibraryView {
  @ObjectLink store: AppStore;
  @Prop messagesOnly: boolean = true;
  @State query: string = '';
  @State preview: HistoryEntry = new HistoryEntry();
  @State showPreview: boolean = false;
  @State visibleCount: number = 30;

  @Builder
  previewSheet() {
    FileDetailsView({ store: this.store, entry: this.preview })
  }

  entries(): HistoryEntry[] {
    return this.store.history.filter((entry: HistoryEntry) =>
      (!this.messagesOnly || !!entry.text) && `${entry.name} ${entry.text} ${entry.peer}`.toLowerCase().includes(this.query.toLowerCase()));
  }

  build() {
    Column({ space: 16 }) {
      Search({ value: this.query, placeholder: this.messagesOnly ? this.store.t('搜索文字、链接、设备') : this.store.t('搜索文件或设备') })
        .onChange((value: string) => { this.query = value; this.visibleCount = 30; })
      if (this.entries().length === 0) {
        EmptyState({ icon: this.messagesOnly ? 'message' : 'history', title: this.query ? this.store.t('没有匹配的记录') : this.messagesOnly ? this.store.t('还没有消息') : this.store.t('还没有传输记录'),
          description: this.query ? this.store.t('试试文件名、文字内容或设备名称。') : this.store.t('收到的文字、链接和文件会整理在这里，仅保存在你的设备中。'), accent: this.store.accentText })
      }
      ForEach(this.entries().slice(0, this.visibleCount), (entry: HistoryEntry) => {
        Column({ space: 12 }) {
          Row() {
            AppIcon({ name: entry.direction === 'receive' ? 'receive' : 'send', iconSize: 18, tint: this.store.accentText })
            Text(entry.peer || this.store.t('本机')).fontWeight(FontWeight.Medium).fontSize(15).layoutWeight(1).fontColor($r('sys.color.font_primary'))
            Text(entry.direction === 'receive' ? this.store.t('接收') : this.store.t('发送')).fontSize(12).fontColor(this.store.accentText)
          }.width('100%')
          Text(entry.text || entry.name).fontSize(16).lineHeight(24).maxLines(6).textOverflow({ overflow: TextOverflow.Ellipsis }).copyOption(CopyOptions.LocalDevice)
            .width('100%').fontColor($r('sys.color.font_primary'))
          Text(`${new Date(entry.time).toLocaleString()} · ${formatSize(entry.size)} · ${this.store.t(historyStatus(entry))}`)
            .fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(10) } }) {
            Button(this.store.t('详情')).onClick(() => { this.preview = entry; this.showPreview = true; })
              .fontColor(this.store.accentText).backgroundColor(this.store.controlSurface)
            if (entry.text) {
              Button(this.store.t('复制')).onClick(() => this.store.copy(entry.text)).fontColor(this.store.accentText).backgroundColor(this.store.controlSurface)
            } else if (entry.path) {
              Button(this.store.t('打开')).onClick(() => {
                if (/\.(png|jpe?g|gif|webp|heic)$/i.test(entry.name)) { this.preview = entry; this.showPreview = true; }
                else this.store.openFile(entry);
              }).fontColor(this.store.accentText).backgroundColor(this.store.controlSurface)
              Button(this.store.t('另存为')).onClick(() => this.store.exportFile(entry)).fontColor(this.store.accentText).backgroundColor(this.store.controlSurface)
            }
            if (entry.text || entry.path) {
              Button(this.store.t('再次发送')).onClick(() => this.store.resend(entry)).fontColor(this.store.accentText).backgroundColor(this.store.controlSurface)
              Button(this.store.t('分享')).onClick(() => this.store.shareEntry(entry)).fontColor(this.store.accentText).backgroundColor(this.store.controlSurface)
            }
            Button(this.store.t('删除')).onClick(() => {
              this.getUIContext().showAlertDialog({ title: this.store.t('删除这条记录？'), message: this.store.t('不会删除已经保存的文件。'),
                primaryButton: { value: this.store.t('取消'), action: () => {} },
                secondaryButton: { value: this.store.t('删除'), action: () => this.store.removeHistory(entry.id) } });
            }).fontColor(this.store.dangerText).backgroundColor(this.store.controlSurface)
          }.width('100%')
        }.padding(20).width('100%').backgroundColor(this.store.surfaceColor).borderRadius(24)
      }, (entry: HistoryEntry) => `${entry.id}:${entry.status}:${entry.error || ''}`)
      if (this.entries().length > this.visibleCount) {
        Button(this.store.tf('继续查看 · 还有 {0} 项', [String(this.entries().length - this.visibleCount)]))
          .width('100%').height(48).backgroundColor(this.store.surfaceColor).fontColor(this.store.accentText).onClick(() => this.visibleCount += 30)
      }
      if (this.entries().length > 0) {
        Button(this.store.t('清空记录')).fontColor(this.store.dangerText).backgroundColor(this.store.surfaceColor).onClick(() => {
          this.getUIContext().showAlertDialog({ title: this.store.t('清空记录？'), message: this.store.t('此操作无法撤销，已保存的文件不受影响。'),
            primaryButton: { value: this.store.t('取消'), action: () => {} },
            secondaryButton: { value: this.store.t('清空'), action: () => this.store.clearHistory(this.messagesOnly) } });
        })
      }
    }.width('100%').bindSheet($$this.showPreview, this.previewSheet(), { height: SheetSize.LARGE, showClose: true })
  }
}
