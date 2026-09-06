import { AppStore, ShareFile, WebAccessRequest, formatSize } from '../model/AppStore';
import { webShare } from '../network/WebShareService';

@Component
export struct WebShareView {
  @ObjectLink store: AppStore;
  @State encrypted: boolean = false;

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
            Toggle({ type: ToggleType.Switch, isOn: this.encrypted }).selectedColor(this.store.settings.accent).onChange((value: boolean) => this.encrypted = value)
          }.width('100%')
          Text(this.encrypted ? this.store.t('使用本机自签名证书，浏览器会要求确认。') : this.store.t('HTTP 浏览器模式不加密，仅在可信网络中使用。LocalSend 设备之间的加密传输不受影响。'))
            .fontSize(12).lineHeight(20).fontColor($r('sys.color.font_secondary'))
          Button(this.store.t('开始分享')).width('100%').height(48).backgroundColor(this.store.accentFill).onClick(() => webShare.start(this.encrypted))
        }.padding(24).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(28)
      } else {
        Column({ space: 18 }) {
          Text(this.store.t('扫码或打开链接')).fontSize(23).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
          QRCode(this.store.webUrl).width(200).height(200).color('#15271F').backgroundColor('#FFFFFF').padding(10).borderRadius(16)
          Text(this.store.webUrl).fontSize(14).fontColor(this.store.accentText).copyOption(CopyOptions.LocalDevice).textAlign(TextAlign.Center)
          Text(this.store.t('链接有效期 1 小时；停止分享后立即失效。')).fontSize(12).fontColor($r('sys.color.font_secondary'))
          Button(this.store.t('复制链接')).width('100%').height(46).backgroundColor(this.store.accentFill).onClick(() => this.store.copy(this.store.webUrl))
          Row() {
            Text(this.store.t('自动允许浏览器下载')).layoutWeight(1).fontSize(14).fontColor($r('sys.color.font_primary'))
            Toggle({ type: ToggleType.Switch, isOn: this.store.settings.webAutoAccept }).selectedColor(this.store.settings.accent)
              .onChange((value: boolean) => { this.store.settings.webAutoAccept = value; this.store.save(); })
          }.width('100%')
          Button(this.store.t('停止分享')).width('100%').height(46).backgroundColor($r('sys.color.comp_background_tertiary')).fontColor(this.store.dangerText)
            .onClick(() => webShare.stop())
        }.padding(24).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(28)
        ForEach(this.store.webRequests, (request: WebAccessRequest) => {
          Column({ space: 12 }) {
            Text(this.store.tf('{0} 请求下载', [request.ip])).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
            Text(request.fileName).fontSize(14).fontColor($r('sys.color.font_secondary'))
            Row({ space: 12 }) {
              Button(this.store.t('拒绝')).layoutWeight(1).onClick(() => webShare.respond(request.id, false))
              Button(this.store.t('允许')).layoutWeight(1).backgroundColor(this.store.accentFill).onClick(() => webShare.respond(request.id, true))
            }.width('100%')
          }.padding(24).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24)
        }, (request: WebAccessRequest) => request.id)
        ForEach(this.store.webFiles, (file: ShareFile) => {
          Row() {
            Text(file.name).fontSize(15).layoutWeight(1).maxLines(2).fontColor($r('sys.color.font_primary'))
            Text(formatSize(file.size)).fontSize(12).fontColor($r('sys.color.font_secondary'))
          }.padding(18).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(20)
        }, (file: ShareFile) => file.id)
      }
    }.width('100%')
  }
}
