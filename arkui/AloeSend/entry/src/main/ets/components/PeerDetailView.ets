import { AppStore, Peer } from '../model/AppStore';
import { localSend } from '../network/LocalSendService';

@Component
export struct PeerDetailView {
  @ObjectLink store: AppStore;
  @Prop peer: Peer = new Peer();
  @State alias: string = '';
  onSend: () => void = () => {};

  aboutToAppear(): void { this.alias = this.peer.alias; }

  build() {
    Column({ space: 20 }) {
      Column({ space: 16 }) {
        Text(this.peer.deviceType === 'mobile' ? '▯' : '▣').fontSize(52).fontColor(this.store.settings.accent)
        Text(this.peer.alias).fontSize(26).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        Text(this.peer.deviceModel || 'LocalSend 设备').fontSize(14).fontColor($r('sys.color.font_secondary'))
        Text(`${this.peer.protocol}://${this.peer.ip}:${this.peer.port}`).fontSize(14).fontColor(this.store.settings.accent).copyOption(CopyOptions.LocalDevice)
        Button('发送到这台设备').width('100%').height(48).backgroundColor(this.store.settings.accent).onClick(() => this.onSend())
        Button(this.store.isFavorite(this.peer) ? '取消收藏' : '收藏设备').width('100%').height(46)
          .backgroundColor($r('sys.color.comp_background_tertiary')).fontColor(this.store.settings.accent).onClick(() => this.store.toggleFavorite(this.peer))
      }.padding(28).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(28)
      if (this.store.isFavorite(this.peer)) {
        Column({ space: 12 }) {
          Text('收藏备注').fontSize(16).fontColor($r('sys.color.font_primary')).width('100%')
          TextInput({ text: this.alias }).maxLength(40).onChange((value: string) => this.alias = value)
          Button('保存备注').backgroundColor(this.store.settings.accent).onClick(() => {
            this.store.favorites = this.store.favorites.map((item: Peer) => {
              if (item.ip === this.peer.ip && item.port === this.peer.port) item.alias = this.alias.trim() || item.alias;
              return item;
            }); this.store.save(); this.store.notice = '收藏备注已保存';
          })
        }.padding(24).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24)
      }
      Column({ space: 12 }) {
        Text('连接身份').fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).width('100%')
        Text(this.peer.protocol === 'https' ? 'TLS 加密传输。首次连接请与对方核对完整指纹；指纹变更会阻止已收藏设备的发送。' : '此设备使用 HTTP，传输内容不加密。')
          .fontSize(14).lineHeight(23).fontColor($r('sys.color.font_secondary'))
        if (this.peer.fingerprint) {
          Text(this.peer.fingerprint).fontFamily('monospace').fontSize(13).fontColor(this.store.settings.accent).copyOption(CopyOptions.LocalDevice)
          Button('复制指纹').backgroundColor($r('sys.color.comp_background_tertiary')).fontColor(this.store.settings.accent).onClick(() => this.store.copy(this.peer.fingerprint))
        }
        Button('检查连接').backgroundColor(this.store.settings.accent).onClick(() => {
          localSend.probe(this.peer).then(() => this.store.notice = '连接正常').catch((e: Error) => this.store.fail('连接失败', e));
        })
      }.padding(24).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24)
    }.width('100%')
  }
}
