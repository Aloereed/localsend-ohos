import { AppStore, Peer } from '../model/AppStore';
import { localSend } from '../network/LocalSendService';
import { AppIcon } from './AppIcon';

@Component
export struct PeerDetailView {
  @ObjectLink store: AppStore;
  @Prop peer: Peer = new Peer();
  @State alias: string = '';
  @State address: string = '';
  @State port: string = '';
  @State choosing: boolean = false;
  @State textMode: boolean = false;
  @State text: string = '';
  onSend: () => void = () => {};
  onMessage: () => void = () => {};
  onUpdate: (peer: Peer) => void = () => {};

  aboutToAppear(): void {
    this.alias = this.peer.alias; this.address = this.peer.ip; this.port = String(this.peer.port);
  }

  saveFavorite(): void {
    try {
      const updated = this.store.updateFavorite(this.peer, this.alias, this.address, this.port);
      this.peer = updated; this.alias = updated.alias; this.address = updated.ip; this.port = String(updated.port);
      this.onUpdate(updated); this.store.notice = this.store.t('收藏设备已更新');
    } catch (error) { this.store.fail('更新收藏失败', error as Error); }
  }

  async choose(kind: string): Promise<void> {
    if (kind === 'text') { this.textMode = true; return; }
    this.choosing = false;
    const selected = kind === 'clipboard' ? await this.store.paste() : await this.store.selectFiles(kind);
    if (selected) { this.choosing = false; this.onSend(); }
  }

  @Builder
  contentPicker() {
    Column({ space: 16 }) {
      Text(this.store.t(this.textMode ? '发送文字或链接' : '先选择要分享的内容')).fontSize(23).fontWeight(FontWeight.Medium)
      if (this.textMode) {
        TextArea({ text: this.text, placeholder: this.store.t('写点什么，或粘贴一个链接…') }).height(200).maxLength(100000)
          .onChange((value: string) => this.text = value)
        Button(this.store.t('发送')).width('100%').height(48).backgroundColor(this.store.accentFill).enabled(this.text.trim().length > 0)
          .onClick(() => { this.store.addText(this.text); this.text = ''; this.choosing = false; this.onSend(); })
      } else {
        Button(this.store.t('文件')).width('100%').height(48).backgroundColor(this.store.accentFill).onClick(() => this.choose('file'))
        Button(this.store.t('照片与视频')).width('100%').height(48).backgroundColor(this.store.accentFill).onClick(() => this.choose('photo'))
        Button(this.store.t('文件夹')).width('100%').height(48).backgroundColor(this.store.accentFill).onClick(() => this.choose('folder'))
        Button(this.store.t('文字或链接')).width('100%').height(48).backgroundColor(this.store.accentFill).onClick(() => this.choose('text'))
        Button(this.store.t('剪贴板')).width('100%').height(48).backgroundColor(this.store.accentFill).onClick(() => this.choose('clipboard'))
      }
    }.padding(24).width('100%').direction(this.store.rtl ? Direction.Rtl : Direction.Ltr)
  }

  build() {
    Column({ space: 20 }) {
      Column({ space: 16 }) {
        Stack() { AppIcon({ name: this.peer.deviceType === 'mobile' ? 'mobile' : 'desktop', iconSize: 40, tint: this.store.accentText }) }
          .width(88).height(88).backgroundColor(this.store.controlSurface).borderRadius(28)
        Text(this.peer.alias).fontSize(26).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        Text(this.peer.deviceModel || this.store.t('LocalSend 设备')).fontSize(14).fontColor($r('sys.color.font_secondary'))
        Text(`${this.peer.protocol}://${this.peer.ip}:${this.peer.port}`).direction(Direction.Ltr).fontSize(14).fontColor(this.store.accentText).copyOption(CopyOptions.LocalDevice)
        Button(this.store.t('发送到这台设备')).width('100%').height(48).backgroundColor(this.store.accentFill).onClick(() => {
          if (this.store.files.length) this.onSend(); else { this.textMode = false; this.choosing = true; }
        })
        Button(this.store.t('消息')).width('100%').height(46).backgroundColor(this.store.controlSurface)
          .fontColor(this.store.accentText).onClick(() => this.onMessage())
        Button(this.store.isFavorite(this.peer) ? this.store.t('取消收藏') : this.store.t('收藏设备')).width('100%').height(46)
          .backgroundColor(this.store.controlSurface).fontColor(this.store.accentText).onClick(() => this.store.toggleFavorite(this.peer))
      }.padding(28).width('100%').backgroundColor(this.store.surfaceColor).borderRadius(28)
      if (this.store.isFavorite(this.peer)) {
        Column({ space: 12 }) {
          Text(this.store.t('收藏备注')).fontSize(16).fontColor($r('sys.color.font_primary')).width('100%')
          TextInput({ text: this.alias }).maxLength(40).onChange((value: string) => this.alias = value)
          Text(this.store.t('IP 地址')).fontSize(14).fontColor($r('sys.color.font_secondary')).width('100%')
          TextInput({ text: this.address, placeholder: '192.168.1.10' }).direction(Direction.Ltr)
            .onChange((value: string) => this.address = value)
          Text(this.store.t('端口')).fontSize(14).fontColor($r('sys.color.font_secondary')).width('100%')
          TextInput({ text: this.port, placeholder: '53317' }).direction(Direction.Ltr).type(InputType.Number).maxLength(5)
            .onChange((value: string) => this.port = value)
          Text(this.store.t('修改地址不会改变已保存的设备指纹。')).fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
          Button(this.store.t('保存收藏')).backgroundColor(this.store.accentFill).onClick(() => this.saveFavorite())
        }.padding(24).width('100%').direction(this.store.rtl ? Direction.Rtl : Direction.Ltr).backgroundColor(this.store.surfaceColor).borderRadius(24)
      }
      Column({ space: 12 }) {
        Text(this.store.t('连接身份')).fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).width('100%')
        Text(this.peer.protocol === 'https' ? this.store.t('TLS 加密传输。首次连接请与对方核对完整指纹；指纹变更会阻止已收藏设备的发送。') : this.store.t('此设备使用 HTTP，传输内容不加密。'))
          .fontSize(14).lineHeight(23).fontColor($r('sys.color.font_secondary'))
        if (this.peer.fingerprint) {
          Text(this.peer.fingerprint).direction(Direction.Ltr).fontFamily('monospace').fontSize(13).fontColor(this.store.accentText).copyOption(CopyOptions.LocalDevice)
          Button(this.store.t('复制指纹')).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText).onClick(() => this.store.copy(this.peer.fingerprint))
        }
        Button(this.store.t('检查连接')).backgroundColor(this.store.accentFill).onClick(() => {
          localSend.probe(this.peer).then(() => this.store.notice = this.store.t('连接正常')).catch((e: Error) => this.store.fail(this.store.t('连接失败'), e));
        })
      }.padding(24).width('100%').direction(this.store.rtl ? Direction.Rtl : Direction.Ltr).backgroundColor(this.store.surfaceColor).borderRadius(24)
    }.width('100%').bindSheet($$this.choosing, this.contentPicker(), { height: SheetSize.FIT_CONTENT, showClose: true })
  }
}
