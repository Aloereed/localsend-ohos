import { AppStore, ShareFile, WebAccessRequest, formatSize } from '../model/AppStore';
import { webShare } from '../network/WebShareService';

@Component
export struct WebShareView {
  @ObjectLink @Watch('checkShare') store: AppStore;
  @State encrypted: boolean = false;
  @State presenting: boolean = false;
  @State presentationMode: string = 'qr';

  checkShare(): void { if (!this.store.webUrl) this.presenting = false; }

  @Builder
  presentation() {
    Stack() {
    Column({ space: 20 }) {
      Row() {
        Text(this.store.t('通过链接分享')).fontSize(22).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).layoutWeight(1)
        Button('×').width(44).height(44).fontSize(24).fontColor($r('sys.color.font_primary')).backgroundColor(this.store.controlSurface)
          .accessibilityText(this.store.t('关闭')).onClick(() => this.presenting = false)
      }.width('100%')
      Scroll() {
        Column({ space: 24 }) {
          if (this.presentationMode === 'qr' && this.store.webUrl) {
            QRCode(this.store.webUrl).width('80%').aspectRatio(1).constraintSize({ maxWidth: 380, maxHeight: 380 })
              .color('#101318').backgroundColor('#FFFFFF').padding(16).borderRadius(24)
          }
          Text(this.store.webUrl).direction(Direction.Ltr).fontSize(this.presentationMode === 'qr' ? 17 : 36).lineHeight(this.presentationMode === 'qr' ? 26 : 48)
            .fontColor($r('sys.color.font_primary')).width('100%').textAlign(TextAlign.Center).wordBreak(WordBreak.BREAK_ALL).copyOption(CopyOptions.LocalDevice)
          if (this.store.settings.pin) {
            Text(`${this.store.t('上传 PIN')} · ${this.store.settings.pin}`).fontSize(24).fontColor(this.store.accentText)
          }
          Text(this.store.t('请让对方连接同一网络')).fontSize(15).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
        }.width('100%').padding({ top: 24, bottom: 24 })
      }.width('100%').layoutWeight(1)
      if (this.store.webRequests.length > 0) {
        Button(this.store.tf('{0} 个浏览器下载请求 · 点击查看', [String(this.store.webRequests.length)]))
          .width('100%').height(48).fontColor(this.store.accentText).backgroundColor(this.store.controlSurface).onClick(() => this.presenting = false)
      }
      Button(this.store.t('复制链接')).width('100%').height(48).backgroundColor(this.store.accentFill).onClick(() => this.store.copy(this.store.webUrl))
    }.width('100%').height('100%').direction(this.store.rtl ? Direction.Rtl : Direction.Ltr).padding(24).constraintSize({ maxWidth: 720 })
    }.width('100%').height('100%').direction(this.store.rtl ? Direction.Rtl : Direction.Ltr).backgroundColor(this.store.canvasColor)
  }

  build() {
    Column({ space: 20 }) {
      if (!this.store.webUrl) {
        Column({ space: 14 }) {
          Text(this.store.t('让浏览器也能加入')).fontSize(24).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
          Text(this.store.t('无需安装应用。通过同一网络里的浏览器，下载你选择的内容，也能向这台设备发送文件和文字。'))
            .fontSize(14).lineHeight(24).fontColor($r('sys.color.font_secondary'))
          Text(this.store.tf('将分享当前清单中的 {0} 项内容', [String(this.store.files.length)])).fontSize(14).fontColor(this.store.accentText)
          Row() {
            Text(this.store.t('HTTPS 加密')).layoutWeight(1).fontColor($r('sys.color.font_primary'))
            Toggle({ type: ToggleType.Switch, isOn: this.encrypted }).selectedColor(this.store.accentFill).onChange((value: boolean) => this.encrypted = value)
          }.width('100%')
          Text(this.encrypted ? this.store.t('使用本机自签名证书，浏览器会要求确认。') : this.store.t('HTTP 浏览器模式不加密，仅在可信网络中使用。LocalSend 设备之间的加密传输不受影响。'))
            .fontSize(12).lineHeight(20).fontColor($r('sys.color.font_secondary'))
          Button(this.store.t('开始分享')).width('100%').height(48).backgroundColor(this.store.accentFill)
            .enabled(!this.store.webStarting).onClick(() => webShare.start(this.encrypted))
        }.padding(24).width('100%').direction(this.store.rtl ? Direction.Rtl : Direction.Ltr).backgroundColor(this.store.surfaceColor).borderRadius(28)
      } else {
        Column({ space: 18 }) {
          Text(this.store.t('扫码或打开链接')).fontSize(23).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
          QRCode(this.store.webUrl).width(200).height(200).color('#15271F').backgroundColor('#FFFFFF').padding(10).borderRadius(16)
          Text(this.store.webUrl).direction(Direction.Ltr).fontSize(14).fontColor(this.store.accentText).copyOption(CopyOptions.LocalDevice).textAlign(TextAlign.Center)
          Text(this.store.t('链接有效期 1 小时；停止分享后立即失效。')).fontSize(12).fontColor($r('sys.color.font_secondary'))
          Button(this.store.t('复制链接')).width('100%').height(46).backgroundColor(this.store.accentFill).onClick(() => this.store.copy(this.store.webUrl))
          Row({ space: 12 }) {
            Button(this.store.t('放大二维码')).layoutWeight(1).height(44).fontColor(this.store.accentText).backgroundColor(this.store.controlSurface)
              .onClick(() => { this.presentationMode = 'qr'; this.presenting = true; })
            Button(this.store.t('大字链接')).layoutWeight(1).height(44).fontColor(this.store.accentText).backgroundColor(this.store.controlSurface)
              .onClick(() => { this.presentationMode = 'link'; this.presenting = true; })
          }.width('100%')
          Row() {
            Text(this.store.t('自动允许浏览器下载')).layoutWeight(1).fontSize(14).fontColor($r('sys.color.font_primary'))
            Toggle({ type: ToggleType.Switch, isOn: this.store.settings.webAutoAccept }).selectedColor(this.store.accentFill)
              .onChange((value: boolean) => { this.store.settings.webAutoAccept = value; this.store.save(); })
          }.width('100%')
          Button(this.store.t('停止分享')).width('100%').height(46).backgroundColor(this.store.controlSurface).fontColor(this.store.dangerText)
            .onClick(() => webShare.stop())
        }.padding(24).width('100%').direction(this.store.rtl ? Direction.Rtl : Direction.Ltr).backgroundColor(this.store.surfaceColor).borderRadius(28)
        ForEach(this.store.webRequests, (request: WebAccessRequest) => {
          Column({ space: 12 }) {
            Text(this.store.tf('{0} 请求下载', [request.ip])).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
            Text(request.fileName).fontSize(14).fontColor($r('sys.color.font_secondary'))
            Row({ space: 12 }) {
              Button(this.store.t('拒绝')).layoutWeight(1).onClick(() => webShare.respond(request.id, false))
              Button(this.store.t('允许')).layoutWeight(1).backgroundColor(this.store.accentFill).onClick(() => webShare.respond(request.id, true))
            }.width('100%')
          }.padding(24).width('100%').direction(this.store.rtl ? Direction.Rtl : Direction.Ltr).backgroundColor(this.store.surfaceColor).borderRadius(24)
        }, (request: WebAccessRequest) => request.id)
        ForEach(this.store.webFiles, (file: ShareFile) => {
          Row() {
            Text(file.name).fontSize(15).layoutWeight(1).maxLines(2).fontColor($r('sys.color.font_primary'))
            Text(formatSize(file.size)).fontSize(12).fontColor($r('sys.color.font_secondary'))
          }.padding(18).width('100%').backgroundColor(this.store.surfaceColor).borderRadius(20)
        }, (file: ShareFile) => file.id)
      }
    }.width('100%').bindContentCover($$this.presenting, this.presentation(), {
      modalTransition: this.store.settings.animations ? ModalTransition.DEFAULT : ModalTransition.NONE
    })
  }
}
