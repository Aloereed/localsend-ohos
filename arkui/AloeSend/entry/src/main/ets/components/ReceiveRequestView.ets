import { AppStore, TransferView, TransferFile, formatSize } from '../model/AppStore';
import { localSend } from '../network/LocalSendService';
import { TransferList } from './TransferList';

@Component
export struct ReceiveRequestView {
  @ObjectLink store: AppStore;

  selected(): TransferFile[] {
    const transfer = this.store.transfers.find((item: TransferView) => item.id === this.store.pendingReceive);
    return transfer ? transfer.files.filter((file: TransferFile) => file.selected) : [];
  }

  build() {
    Column() {
      Column({ space: 6 }) {
        Text(this.store.t('收到分享请求')).fontSize(28).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        Text(this.store.t('查看内容，再决定是否接收')).fontSize(14).fontColor($r('sys.color.font_secondary'))
      }.alignItems(HorizontalAlign.Start).width('100%').padding({ left: 24, right: 24, top: 24, bottom: 16 })
      Scroll() {
        TransferList({ store: this.store, pendingOnly: true, consentActions: false })
      }.width('100%').layoutWeight(1).padding({ left: 24, right: 24 }).align(Alignment.Top)
      Column({ space: 12 }) {
        if (this.selected().length === 0) {
          Text(this.store.t('当前还没有选择要接收的文件。')).fontSize(14)
            .fontColor($r('sys.color.font_secondary')).width('100%')
        }
        Text(this.store.tf('已选 {0} 项 · {1}', [String(this.selected().length), formatSize(this.selected().reduce((sum: number, file: TransferFile) => sum + file.size, 0))]))
          .fontSize(13).fontColor($r('sys.color.font_secondary')).width('100%')
        Row({ space: 12 }) {
          Button(this.store.t('拒绝')).layoutWeight(1).height(50).fontColor($r('sys.color.font_primary'))
            .backgroundColor(this.store.controlSurface).onClick(() => localSend.acceptReceive(false))
          Button(this.store.t('接收所选')).layoutWeight(1).height(50).backgroundColor(this.store.accentFill)
            .enabled(this.selected().length > 0).onClick(() => localSend.acceptReceive(true))
        }.width('100%')
      }.padding(24).width('100%').backgroundColor(this.store.surfaceColor)
    }.width('100%').height('100%').constraintSize({ maxWidth: 720 })
  }
}
