import { AppStore, TransferView, TransferFile, HistoryEntry, formatSize } from '../model/AppStore';
import { localSend } from '../network/LocalSendService';
import { webShare } from '../network/WebShareService';
import { AppIcon } from './AppIcon';
import { transferTotal, transferredBytes, remainingSeconds } from '../model/TransferMetrics';

@Component
export struct TransferList {
  @ObjectLink store: AppStore;
  @Prop pendingOnly: boolean = false;
  @Prop consentActions: boolean = true;
  @State fileLimit: number = 30;
  @State renameSheet: boolean = false;
  @State renameId: string = '';
  @State renameText: string = '';
  @State batchEdit: boolean = false;
  @State batchMode: string = 'counter';
  @State prefix: string = '';
  @State padZero: boolean = false;
  @State sortFirst: boolean = false;

  current(id: string): TransferView {
    return this.store.transfers.find((transfer: TransferView) => transfer.id === id) || new TransferView();
  }

  currentFile(transferId: string, fileId: string): TransferFile {
    return this.current(transferId).files.find((file: TransferFile) => file.id === fileId) || new TransferFile();
  }

  @Builder
  renameEditor() {
    Scroll() {
      Column() {
    if (this.batchEdit) {
      Column({ space: 16 }) {
        Text(this.store.t('批量重命名')).fontSize(23).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        Text(this.store.t('只修改选中的文件，保留文件夹层级和扩展名。')).fontSize(13).fontColor($r('sys.color.font_secondary'))
        Select([{ value: this.store.t('连续编号') }, { value: this.store.t('随机名称') }]).selected(this.batchMode === 'counter' ? 0 : 1)
          .value(this.store.t(this.batchMode === 'counter' ? '连续编号' : '随机名称'))
          .onSelect((index: number) => this.batchMode = index === 0 ? 'counter' : 'random')
        if (this.batchMode === 'counter') {
          TextInput({ text: this.prefix, placeholder: this.store.t('文件名前缀（可留空）') }).maxLength(100).onChange((value: string) => this.prefix = value)
          Row() {
            Text(this.store.t('编号补零')).layoutWeight(1).fontColor($r('sys.color.font_primary'))
            Toggle({ type: ToggleType.Switch, isOn: this.padZero }).selectedColor(this.store.accentFill).onChange((value: boolean) => this.padZero = value)
          }.width('100%')
          Row() {
            Text(this.store.t('按名称排序后编号')).layoutWeight(1).fontColor($r('sys.color.font_primary'))
            Toggle({ type: ToggleType.Switch, isOn: this.sortFirst }).selectedColor(this.store.accentFill).onChange((value: boolean) => this.sortFirst = value)
          }.width('100%')
        }
        Button(this.store.t('应用到所选文件')).width('100%').height(48).backgroundColor(this.store.accentFill).onClick(() => {
          if (localSend.batchRenameReceive(this.batchMode, this.prefix, this.padZero, this.sortFirst)) this.renameSheet = false;
        })
      }.padding(24).width('100%').direction(this.store.rtl ? Direction.Rtl : Direction.Ltr)
    } else {
    Column({ space: 18 }) {
      Text(this.store.t('接收时重命名')).fontSize(22).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
      TextInput({ text: this.renameText }).onChange((value: string) => this.renameText = value)
      Text(this.store.t('仅影响本次接收的文件名称。')).fontSize(13).fontColor($r('sys.color.font_secondary'))
      Button(this.store.t('保存名称')).width('100%').height(48).backgroundColor(this.store.accentFill).onClick(() => {
        if (localSend.renameReceive(this.renameId, this.renameText)) this.renameSheet = false;
      })
    }.width('100%').padding(24).direction(this.store.rtl ? Direction.Rtl : Direction.Ltr)
    }
      }.width('100%')
    }.width('100%').height('100%').align(Alignment.Top).direction(this.store.rtl ? Direction.Rtl : Direction.Ltr)
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

  total(transfer: TransferView): number { return transferTotal(transfer); }
  done(transfer: TransferView): number { return transferredBytes(transfer); }
  percent(transfer: TransferView): number {
    if (transfer.status === 'complete') return 100;
    return Math.max(0, Math.min(100, this.done(transfer) * 100 / Math.max(1, this.total(transfer))));
  }
  openReceived(transferId: string, fileId: string): void {
    const file = this.currentFile(transferId, fileId);
    if (file.status !== 'complete' || !file.path) return;
    const entry = new HistoryEntry(); entry.name = file.name; entry.path = file.path;
    this.store.openFile(entry);
  }
  rate(transfer: TransferView): string {
    const seconds = Math.max(1, ((transfer.finished || Date.now()) - (transfer.activeStarted || transfer.started)) / 1000);
    const speed = this.done(transfer) / seconds;
    const remaining = remainingSeconds(transfer, speed);
    return `${formatSize(Math.round(speed))}/s${remaining > 0 ? this.store.tf(' · 剩余 {0}', [`${Math.floor(remaining / 60)}:${String(remaining % 60).padStart(2, '0')}`]) : ''}`;
  }

  build() {
    Column({ space: 18 }) {
      if (this.store.batchRemaining > 0) {
        Row() {
          Text(this.store.tf('队列剩余 {0} 台设备', [String(this.store.batchRemaining)])).layoutWeight(1).fontColor($r('sys.color.font_primary'))
          Button(this.store.t('停止队列')).fontColor(this.store.dangerText).backgroundColor(this.store.controlSurface).onClick(() => localSend.cancelAll())
        }.padding(16).width('100%').backgroundColor(this.store.surfaceColor).borderRadius(20)
      }
      if (this.store.transfers.length === 0) {
        Text(this.store.t('暂无传输任务')).fontSize(18).fontColor($r('sys.color.font_secondary')).padding(40)
      }
      ForEach(this.store.transfers.filter((transfer: TransferView) => !this.pendingOnly || transfer.id === this.store.pendingReceive), (transfer: TransferView) => {
        Column({ space: 16 }) {
          Row() {
            AppIcon({ name: this.current(transfer.id).direction === 'receive' ? 'receive' : 'send', iconSize: 30, tint: this.store.accentText })
            Column({ space: 6 }) {
              Text(this.current(transfer.id).peer).fontSize(23).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
              Text(`${this.statusLabel(this.current(transfer.id).status)} · ${this.current(transfer.id).encrypted ? this.store.t('TLS 加密') : this.store.t('未加密')}`)
                .fontSize(13).fontColor($r('sys.color.font_secondary'))
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.width('100%')
          if (this.current(transfer.id).status === 'transferring' || this.current(transfer.id).status === 'complete') {
            Row({ space: 12 }) {
              Text(`${Math.floor(this.percent(this.current(transfer.id)))}%`)
                .fontSize(36).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).layoutWeight(1)
              Text(this.rate(this.current(transfer.id))).fontSize(12).fontColor($r('sys.color.font_secondary'))
            }.width('100%').alignItems(VerticalAlign.Bottom)
            Progress({ value: this.percent(this.current(transfer.id)), total: 100, type: ProgressType.Linear })
              .color(this.store.accentText).backgroundColor(this.store.controlSurface)
              .style({ strokeWidth: 6, enableSmoothEffect: this.store.settings.animations }).width('100%')
            if (this.current(transfer.id).direction === 'receive' && this.current(transfer.id).status === 'transferring' && this.done(this.current(transfer.id)) === 0) {
              Text(this.store.t('已确认，等待发送方传输…')).fontSize(13).fontColor($r('sys.color.font_secondary')).width('100%')
            }
            Row() {
              Text(`${formatSize(this.done(this.current(transfer.id)))} / ${formatSize(this.total(this.current(transfer.id)))}`).layoutWeight(1).fontSize(12).fontColor($r('sys.color.font_secondary'))
            }.width('100%')
          }
          if (this.current(transfer.id).error) { Text(this.store.t(this.current(transfer.id).error)).fontColor(this.store.dangerText).fontSize(14).width('100%') }
          if (this.current(transfer.id).storageNotice) { Text(this.store.t(this.current(transfer.id).storageNotice)).fontColor(this.store.accentText).fontSize(14).width('100%') }
          if (transfer.id === this.store.pendingReceive) {
            Row({ space: 12 }) {
              Column({ space: 5 }) {
                Text(this.store.t('本次接收提示保存到相册')).fontSize(15).fontColor($r('sys.color.font_primary'))
                Text(this.store.t('仅影响本次图片和视频，完成后通过系统确认保存')).fontSize(12).fontColor($r('sys.color.font_secondary'))
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Toggle({ type: ToggleType.Switch, isOn: this.current(transfer.id).offerGallerySave })
                .selectedColor(this.store.accentFill).onChange((value: boolean) => {
                  if (value !== this.current(transfer.id).offerGallerySave) localSend.setReceiveGalleryOffer(value);
                }).accessibilityText(this.store.t('本次接收提示保存到相册'))
            }.width('100%')
            Flex({ wrap: FlexWrap.Wrap }) {
              Button(this.store.t('批量重命名')).fontSize(13).backgroundColor(Color.Transparent).fontColor(this.store.accentText)
                .onClick(() => { this.batchEdit = true; this.renameSheet = true; })
              Button(this.store.t('恢复选择和名称')).fontSize(13).backgroundColor(Color.Transparent).fontColor(this.store.accentText).onClick(() => localSend.resetReceiveNames())
            }.width('100%')
            Row({ space: 10 }) {
              Text(this.store.tf('共 {0} 项 · {1}', [String(this.current(transfer.id).files.length), formatSize(this.total(this.current(transfer.id)))])).layoutWeight(1).fontSize(13).fontColor($r('sys.color.font_secondary'))
              Button(this.store.t('全选')).backgroundColor(Color.Transparent).fontColor(this.store.accentText).onClick(() => localSend.selectAllReceive('all'))
              Button(this.store.t('反选')).backgroundColor(Color.Transparent).fontColor(this.store.accentText).onClick(() => localSend.selectAllReceive('invert'))
            }.width('100%')
          }
          ForEach(this.current(transfer.id).files.slice(0, this.fileLimit), (file: TransferFile) => {
            Row({ space: 10 }) {
              if (transfer.id === this.store.pendingReceive) {
                Checkbox().select(this.currentFile(transfer.id, file.id).selected).selectedColor(this.store.accentFill)
                  .onChange((selected: boolean) => localSend.selectReceiveFile(file.id, selected))
              }
              Column({ space: 5 }) {
                Text(this.currentFile(transfer.id, file.id).name).fontSize(15).maxLines(2).fontColor($r('sys.color.font_primary'))
                if (this.currentFile(transfer.id, file.id).preview) {
                  Text(this.currentFile(transfer.id, file.id).preview).fontSize(16).lineHeight(23).maxLines(10).fontColor($r('sys.color.font_primary')).copyOption(CopyOptions.LocalDevice)
                }
                Text(`${formatSize(this.currentFile(transfer.id, file.id).size)} · ${this.statusLabel(this.currentFile(transfer.id, file.id).status)}`).fontSize(12).fontColor($r('sys.color.font_secondary'))
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              if (this.currentFile(transfer.id, file.id).status === 'complete' && this.currentFile(transfer.id, file.id).path) {
                Button(this.store.t('打开')).height(44).fontSize(13).fontColor(this.store.accentText).backgroundColor(this.store.controlSurface)
                  .onClick(() => this.openReceived(transfer.id, file.id))
              } else if (this.currentFile(transfer.id, file.id).status === 'complete') { Text('✓').fontColor(this.store.accentText).fontSize(20) }
              if (transfer.id === this.store.pendingReceive && !this.currentFile(transfer.id, file.id).preview) {
                Button(this.store.t('改名')).fontSize(12).fontColor(this.store.accentText).backgroundColor(Color.Transparent)
                  .onClick(() => { this.batchEdit = false; this.renameId = file.id; this.renameText = this.currentFile(transfer.id, file.id).name; this.renameSheet = true; })
              }
            }.width('100%').padding({ top: 8, bottom: 8 })
          }, (file: TransferFile) => file.id)
          if (this.current(transfer.id).files.length > this.fileLimit) {
            Button(this.store.tf('继续查看 · 还有 {0} 项', [String(this.current(transfer.id).files.length - this.fileLimit)]))
              .width('100%').height(44).fontColor(this.store.accentText).backgroundColor(this.store.controlSurface)
              .onClick(() => this.fileLimit += 50)
          }
          if (transfer.id === this.store.pendingReceive) {
            Column({ space: 8 }) {
              Text(this.store.t('本次保存位置')).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).width('100%')
              Text(this.current(transfer.id).destination || this.store.t('应用内安全保存')).fontSize(12).maxLines(3).fontColor($r('sys.color.font_secondary')).width('100%')
              Button(this.store.t('更改本次目录')).backgroundColor(Color.Transparent).fontColor(this.store.accentText).onClick(() => localSend.chooseReceiveDestination())
            }.width('100%')
            Text(this.store.t('只接收你信任的内容。文件保存在本机，可在历史中另存为。')).fontSize(13).fontColor($r('sys.color.font_secondary'))
            if (this.consentActions) { Row({ space: 12 }) {
              Button(this.store.t('拒绝')).layoutWeight(1).height(48).backgroundColor(this.store.controlSurface).fontColor($r('sys.color.font_primary'))
                .onClick(() => localSend.acceptReceive(false))
              Button(this.store.t('接收所选')).layoutWeight(1).height(48).backgroundColor(this.store.accentFill)
                .enabled(this.current(transfer.id).files.some((file: TransferFile) => this.currentFile(transfer.id, file.id).selected)).onClick(() => localSend.acceptReceive(true))
            }.width('100%') }
          } else if (this.current(transfer.id).status === 'waiting' || this.current(transfer.id).status === 'transferring') {
            Button(this.store.t('取消传输')).fontColor(this.store.dangerText).backgroundColor(this.store.controlSurface).onClick(() => { if (!webShare.cancel(transfer.id)) localSend.cancel(transfer.id); })
          } else if (this.current(transfer.id).direction === 'send' && (this.current(transfer.id).status === 'error' || this.current(transfer.id).status === 'cancelled')) {
            Button(this.store.t('重试未完成文件')).backgroundColor(this.store.accentFill).onClick(() => localSend.retry(transfer.id))
          }
        }.padding(24).width('100%').direction(this.store.rtl ? Direction.Rtl : Direction.Ltr).backgroundColor(this.store.surfaceColor).borderRadius(28)
      }, (transfer: TransferView) => transfer.id)
    }.width('100%').bindSheet($$this.renameSheet, this.renameEditor(), { height: this.batchEdit ? SheetSize.LARGE : SheetSize.MEDIUM, showClose: true, keyboardAvoidMode: SheetKeyboardAvoidMode.RESIZE_ONLY })
  }
}
