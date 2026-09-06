import { AppStore, TransferView, TransferFile, formatSize } from '../model/AppStore';
import { localSend } from '../network/LocalSendService';
import { webShare } from '../network/WebShareService';
import { AppIcon } from './AppIcon';

@Component
export struct TransferList {
  @ObjectLink store: AppStore;
  @Prop pendingOnly: boolean = false;
  @State renameSheet: boolean = false;
  @State renameId: string = '';
  @State renameText: string = '';

  @Builder
  renameEditor() {
    Column({ space: 18 }) {
      Text(this.store.t('接收时重命名')).fontSize(22).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
      TextInput({ text: this.renameText }).onChange((value: string) => this.renameText = value)
      Text(this.store.t('仅影响本次接收的文件名称。')).fontSize(13).fontColor($r('sys.color.font_secondary'))
      Button(this.store.t('保存名称')).width('100%').height(48).backgroundColor(this.store.accentFill).onClick(() => {
        if (localSend.renameReceive(this.renameId, this.renameText)) this.renameSheet = false;
      })
    }.width('100%').padding(24)
  }

  statusLabel(status: string): string {
    if (status === 'waiting') return this.store.t('等待确认');
    if (status === 'transferring') return this.store.t('正在传输');
    if (status === 'complete') return this.store.t('传输完成');
    if (status === 'declined') return this.store.t('已拒绝');
    if (status === 'cancelled') return this.store.t('已取消');
    if (status === 'skipped') return this.store.t('已跳过');
    return this.store.t('传输未完成');
  }

  total(transfer: TransferView): number { return transfer.files.reduce((sum: number, file: TransferFile) => sum + file.size, 0); }
  done(transfer: TransferView): number { return transfer.files.reduce((sum: number, file: TransferFile) => sum + file.transferred, 0); }
  rate(transfer: TransferView): string {
    const seconds = Math.max(1, ((transfer.finished || Date.now()) - transfer.started) / 1000);
    const speed = this.done(transfer) / seconds;
    const remaining = speed > 0 ? Math.ceil((this.total(transfer) - this.done(transfer)) / speed) : 0;
    return `${formatSize(Math.round(speed))}/s${remaining > 0 ? this.store.tf(' · 剩余 {0}', [`${Math.floor(remaining / 60)}:${String(remaining % 60).padStart(2, '0')}`]) : ''}`;
  }

  build() {
    Column({ space: 18 }) {
      if (this.store.batchRemaining > 0) {
        Row() {
          Text(this.store.tf('队列剩余 {0} 台设备', [String(this.store.batchRemaining)])).layoutWeight(1).fontColor($r('sys.color.font_primary'))
          Button(this.store.t('停止队列')).fontColor(this.store.dangerText).backgroundColor($r('sys.color.comp_background_tertiary')).onClick(() => localSend.cancelAll())
        }.padding(16).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(20)
      }
      if (this.store.transfers.length === 0) {
        Text(this.store.t('暂无传输任务')).fontSize(18).fontColor($r('sys.color.font_secondary')).padding(40)
      }
      ForEach(this.store.transfers.filter((transfer: TransferView) => !this.pendingOnly || transfer.id === this.store.pendingReceive), (transfer: TransferView) => {
        Column({ space: 16 }) {
          Row() {
            AppIcon({ name: transfer.direction === 'receive' ? 'receive' : 'send', iconSize: 30, tint: this.store.accentText })
            Column({ space: 6 }) {
              Text(transfer.peer).fontSize(23).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
              Text(`${this.statusLabel(transfer.status)} · ${transfer.encrypted ? this.store.t('TLS 加密') : this.store.t('未加密')}`)
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
          if (transfer.error) { Text(this.store.t(transfer.error)).fontColor(this.store.dangerText).fontSize(14).width('100%') }
          if (transfer.id === this.store.pendingReceive) {
            Row({ space: 10 }) {
              Text(this.store.tf('共 {0} 项 · {1}', [String(transfer.files.length), formatSize(this.total(transfer))])).layoutWeight(1).fontSize(13).fontColor($r('sys.color.font_secondary'))
              Button(this.store.t('全选')).backgroundColor(Color.Transparent).fontColor(this.store.accentText).onClick(() => localSend.selectAllReceive('all'))
              Button(this.store.t('反选')).backgroundColor(Color.Transparent).fontColor(this.store.accentText).onClick(() => localSend.selectAllReceive('invert'))
            }.width('100%')
          }
          ForEach(transfer.files, (file: TransferFile) => {
            Row({ space: 10 }) {
              if (transfer.id === this.store.pendingReceive) {
                Checkbox().select(file.selected).selectedColor(this.store.settings.accent)
                  .onChange((selected: boolean) => localSend.selectReceiveFile(file.id, selected))
              }
              Column({ space: 5 }) {
                Text(file.name).fontSize(15).maxLines(2).fontColor($r('sys.color.font_primary'))
                if (file.preview) {
                  Text(file.preview).fontSize(16).lineHeight(23).maxLines(10).fontColor($r('sys.color.font_primary')).copyOption(CopyOptions.LocalDevice)
                }
                Text(`${formatSize(file.size)} · ${this.statusLabel(file.status)}`).fontSize(12).fontColor($r('sys.color.font_secondary'))
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              if (file.status === 'complete') { Text('✓').fontColor(this.store.accentText).fontSize(20) }
              if (transfer.id === this.store.pendingReceive && !file.preview) {
                Button(this.store.t('改名')).fontSize(12).fontColor(this.store.accentText).backgroundColor(Color.Transparent)
                  .onClick(() => { this.renameId = file.id; this.renameText = file.name; this.renameSheet = true; })
              }
            }.width('100%').padding({ top: 8, bottom: 8 })
          }, (file: TransferFile) => file.id)
          if (transfer.id === this.store.pendingReceive) {
            Column({ space: 8 }) {
              Text(this.store.t('本次保存位置')).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).width('100%')
              Text(transfer.destination || this.store.t('应用内安全保存')).fontSize(12).maxLines(3).fontColor($r('sys.color.font_secondary')).width('100%')
              Button(this.store.t('更改本次目录')).backgroundColor(Color.Transparent).fontColor(this.store.accentText).onClick(() => localSend.chooseReceiveDestination())
            }.width('100%')
            Text(this.store.t('只接收你信任的内容。文件保存在本机，可在历史中另存为。')).fontSize(13).fontColor($r('sys.color.font_secondary'))
            Row({ space: 12 }) {
              Button(this.store.t('拒绝')).layoutWeight(1).height(48).backgroundColor($r('sys.color.comp_background_tertiary')).fontColor($r('sys.color.font_primary'))
                .onClick(() => localSend.acceptReceive(false))
              Button(this.store.t('接收所选')).layoutWeight(1).height(48).backgroundColor(this.store.accentFill)
                .enabled(transfer.files.some((file: TransferFile) => file.selected)).onClick(() => localSend.acceptReceive(true))
            }.width('100%')
          } else if (transfer.status === 'waiting' || transfer.status === 'transferring') {
            Button(this.store.t('取消传输')).fontColor(this.store.dangerText).backgroundColor($r('sys.color.comp_background_tertiary')).onClick(() => { if (!webShare.cancel(transfer.id)) localSend.cancel(transfer.id); })
          } else if (transfer.direction === 'send' && (transfer.status === 'error' || transfer.status === 'cancelled')) {
            Button(this.store.t('重试未完成文件')).backgroundColor(this.store.accentFill).onClick(() => localSend.retry(transfer.id))
          }
        }.padding(24).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(28)
      }, (transfer: TransferView) => JSON.stringify(transfer))
    }.width('100%').bindSheet($$this.renameSheet, this.renameEditor(), { height: SheetSize.MEDIUM, showClose: true })
  }
}
