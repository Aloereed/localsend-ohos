import { AppStore, HistoryEntry, formatSize } from '../model/AppStore';

@Component
export struct LibraryView {
  @ObjectLink store: AppStore;
  @Prop messagesOnly: boolean = true;
  @State query: string = '';

  entries(): HistoryEntry[] {
    return this.store.history.filter((entry: HistoryEntry) =>
      (!this.messagesOnly || !!entry.text) && `${entry.name} ${entry.text} ${entry.peer}`.toLowerCase().includes(this.query.toLowerCase()));
  }

  build() {
    Column({ space: 16 }) {
      Search({ value: this.query, placeholder: this.messagesOnly ? '搜索文字、链接、设备' : '搜索文件或设备' })
        .onChange((value: string) => this.query = value)
      if (this.entries().length === 0) {
        Column({ space: 12 }) {
          Text(this.query ? '没有匹配的记录' : this.messagesOnly ? '还没有消息' : '还没有传输记录')
            .fontSize(21).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
          Text('文字和文件的旅程，留在你的设备里。').fontSize(14).fontColor($r('sys.color.font_secondary'))
        }.padding({ top: 56, bottom: 56 }).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24)
      }
      ForEach(this.entries(), (entry: HistoryEntry) => {
        Column({ space: 12 }) {
          Row() {
            Text(entry.peer || '本机').fontWeight(FontWeight.Medium).fontSize(15).layoutWeight(1).fontColor($r('sys.color.font_primary'))
            Text(entry.direction === 'receive' ? '接收' : '发送').fontSize(12).fontColor(this.store.settings.accent)
          }.width('100%')
          Text(entry.text || entry.name).fontSize(16).lineHeight(24).copyOption(CopyOptions.LocalDevice)
            .width('100%').fontColor($r('sys.color.font_primary'))
          Text(`${new Date(entry.time).toLocaleString()} · ${formatSize(entry.size)}`)
            .fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
          Row({ space: 12 }) {
            if (entry.text) {
              Button('复制').onClick(() => this.store.copy(entry.text)).fontColor(this.store.settings.accent).backgroundColor($r('sys.color.comp_background_tertiary'))
              Button('再次发送').onClick(() => this.store.addText(entry.text)).fontColor(this.store.settings.accent).backgroundColor($r('sys.color.comp_background_tertiary'))
            } else if (entry.path) {
              Button('打开').onClick(() => this.store.openFile(entry)).fontColor(this.store.settings.accent).backgroundColor($r('sys.color.comp_background_tertiary'))
              Button('另存为').onClick(() => this.store.exportFile(entry)).fontColor(this.store.settings.accent).backgroundColor($r('sys.color.comp_background_tertiary'))
            }
            Blank()
            Button('删除').onClick(() => {
              AlertDialog.show({ title: '删除这条记录？', message: '不会删除已经保存的文件。',
                primaryButton: { value: '取消', action: () => {} },
                secondaryButton: { value: '删除', action: () => this.store.removeHistory(entry.id) } });
            }).fontColor('#C44747').backgroundColor($r('sys.color.comp_background_tertiary'))
          }.width('100%')
        }.padding(20).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24)
      }, (entry: HistoryEntry) => entry.id)
      if (this.entries().length > 0) {
        Button('清空记录').fontColor('#C44747').backgroundColor($r('sys.color.comp_background_primary')).onClick(() => {
          AlertDialog.show({ title: '清空记录？', message: '此操作无法撤销，已保存的文件不受影响。',
            primaryButton: { value: '取消', action: () => {} },
            secondaryButton: { value: '清空', action: () => this.store.clearHistory(this.messagesOnly) } });
        })
      }
    }.width('100%')
  }
}
