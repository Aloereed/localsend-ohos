import { AppStore, TransferView, TransferFile, formatSize } from '../model/AppStore';
import { localSend } from '../network/LocalSendService';

@Component
export struct TransferList {
  @ObjectLink store: AppStore;
  @Prop pendingOnly: boolean = false;

  statusLabel(status: string): string {
    if (status === 'waiting') return '等待确认';
    if (status === 'transferring') return '正在传输';
    if (status === 'complete') return '传输完成';
    if (status === 'declined') return '已拒绝';
    if (status === 'cancelled') return '已取消';
    if (status === 'skipped') return '已跳过';
    return '传输未完成';
  }

  total(transfer: TransferView): number { return transfer.files.reduce((sum: number, file: TransferFile) => sum + file.size, 0); }
  done(transfer: TransferView): number { return transfer.files.reduce((sum: number, file: TransferFile) => sum + file.transferred, 0); }
  rate(transfer: TransferView): string {
    const seconds = Math.max(1, ((transfer.finished || Date.now()) - transfer.started) / 1000);
    const speed = this.done(transfer) / seconds;
    const remaining = speed > 0 ? Math.ceil((this.total(transfer) - this.done(transfer)) / speed) : 0;
    return `${formatSize(Math.round(speed))}/s${remaining > 0 ? ` · 剩余 ${Math.floor(remaining / 60)}:${String(remaining % 60).padStart(2, '0')}` : ''}`;
  }

  build() {
    Column({ space: 18 }) {
      if (this.store.transfers.length === 0) {
        Text('暂无传输任务').fontSize(18).fontColor($r('sys.color.font_secondary')).padding(40)
      }
      ForEach(this.store.transfers.filter((transfer: TransferView) => !this.pendingOnly || transfer.id === this.store.pendingReceive), (transfer: TransferView) => {
        Column({ space: 16 }) {
          Row() {
            Text(transfer.direction === 'receive' ? '↓' : '↑').fontSize(30).fontColor(this.store.settings.accent).width(44)
            Column({ space: 6 }) {
              Text(transfer.peer).fontSize(23).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
              Text(`${this.statusLabel(transfer.status)} · ${transfer.encrypted ? 'TLS 加密' : '未加密'}`)
                .fontSize(13).fontColor($r('sys.color.font_secondary'))
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.width('100%')
          if (transfer.status === 'transferring' || transfer.status === 'complete') {
            Progress({ value: this.done(transfer), total: Math.max(1, this.total(transfer)), type: ProgressType.Linear })
              .color(this.store.settings.accent).width('100%')
            Row() {
              Text(`${formatSize(this.done(transfer))} / ${formatSize(this.total(transfer))}`).layoutWeight(1).fontSize(12).fontColor($r('sys.color.font_secondary'))
              Text(this.rate(transfer)).fontSize(12).fontColor($r('sys.color.font_secondary'))
            }.width('100%')
          }
          if (transfer.error) { Text(transfer.error).fontColor('#C44747').fontSize(14).width('100%') }
          ForEach(transfer.files, (file: TransferFile) => {
            Row({ space: 10 }) {
              if (transfer.id === this.store.pendingReceive) {
                Checkbox().select(file.selected).selectedColor(this.store.settings.accent)
                  .onChange((selected: boolean) => localSend.selectReceiveFile(file.id, selected))
              }
              Column({ space: 5 }) {
                Text(file.name).fontSize(15).maxLines(2).fontColor($r('sys.color.font_primary'))
                Text(`${formatSize(file.size)} · ${this.statusLabel(file.status)}`).fontSize(12).fontColor($r('sys.color.font_secondary'))
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              if (file.status === 'complete') { Text('✓').fontColor(this.store.settings.accent).fontSize(20) }
            }.width('100%').padding({ top: 8, bottom: 8 })
          }, (file: TransferFile) => file.id)
          if (transfer.id === this.store.pendingReceive) {
            Text('只接收你信任的内容。文件保存在本机，可在历史中另存为。').fontSize(13).fontColor($r('sys.color.font_secondary'))
            Row({ space: 12 }) {
              Button('拒绝').layoutWeight(1).height(48).backgroundColor($r('sys.color.comp_background_tertiary')).fontColor($r('sys.color.font_primary'))
                .onClick(() => localSend.acceptReceive(false))
              Button('接收所选').layoutWeight(1).height(48).backgroundColor(this.store.settings.accent)
                .enabled(transfer.files.some((file: TransferFile) => file.selected)).onClick(() => localSend.acceptReceive(true))
            }.width('100%')
          } else if (transfer.status === 'waiting' || transfer.status === 'transferring') {
            Button('取消传输').fontColor('#C44747').backgroundColor($r('sys.color.comp_background_tertiary')).onClick(() => localSend.cancel(transfer.id))
          }
        }.padding(24).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(28)
      }, (transfer: TransferView) => transfer.id)
    }.width('100%')
  }
}
