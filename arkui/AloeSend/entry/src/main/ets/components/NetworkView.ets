import { AppStore } from '../model/AppStore';
import { localSend } from '../network/LocalSendService';
import { LocalInterface } from '../network/Addresses';

@Component
export struct NetworkView {
  @ObjectLink store: AppStore;
  @State mode: string = 'none';
  @State patterns: string = '';

  aboutToAppear(): void {
    this.mode = this.store.settings.networkFilter; this.patterns = this.store.settings.networkPatterns.join('\n');
    localSend.readAddresses().catch((error: Error) => this.store.fail(this.store.t('读取网络接口失败'), error));
  }

  async save(): Promise<void> {
    const patterns = this.patterns.split(/[\n,;]+/).map((value: string) => value.trim()).filter((value: string) => !!value);
    if (patterns.some((value: string) => !/^[a-zA-Z0-9.:_%*-]+$/.test(value))) {
      this.store.error = this.store.t('规则仅支持 IP 地址和星号通配符'); return;
    }
    this.store.settings.networkFilter = this.mode; this.store.settings.networkPatterns = patterns;
    await this.store.save(); await localSend.readAddresses();
    this.store.peers = []; await localSend.discover(); this.store.notice = this.store.t('发现规则已生效');
  }

  build() {
    Column({ space: 18 }) {
      Text(this.store.t('筛选用于自动发现和地址展示的网络。手动添加设备和接收服务不会被这些规则限制。'))
        .fontSize(14).lineHeight(23).fontColor($r('sys.color.font_secondary')).width('100%')
      Column({ space: 16 }) {
        Row() {
          Text(this.store.t('发现范围')).fontSize(16).layoutWeight(1).fontColor($r('sys.color.font_primary'))
          Select([{ value: this.store.t('全部网络') }, { value: this.store.t('仅包含') }, { value: this.store.t('排除') }])
            .selected(this.mode === 'allow' ? 1 : this.mode === 'deny' ? 2 : 0)
            .value(this.store.t(this.mode === 'allow' ? '仅包含' : this.mode === 'deny' ? '排除' : '全部网络'))
            .onSelect((index: number) => this.mode = ['none', 'allow', 'deny'][index])
        }.width('100%')
        if (this.mode !== 'none') {
          TextArea({ text: this.patterns, placeholder: '192.168.1.*\n10.0.*.*' }).height(150)
            .onChange((value: string) => this.patterns = value)
          Text(this.store.t('每行一条规则，星号匹配一个地址段。白名单为空时不会发现设备。'))
            .fontSize(12).lineHeight(20).fontColor($r('sys.color.font_secondary'))
        }
        Button(this.store.t('应用发现规则')).width('100%').height(48).backgroundColor(this.store.accentFill)
          .onClick(() => this.save().catch((error: Error) => this.store.fail(this.store.t('应用规则失败'), error)))
      }.padding(22).width('100%').backgroundColor(this.store.surfaceColor).borderRadius(26)
      Row() {
        Text(this.store.t('当前网络接口')).fontSize(19).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).layoutWeight(1)
        Button(this.store.t('刷新')).backgroundColor(Color.Transparent).fontColor(this.store.accentText)
          .onClick(() => localSend.readAddresses().catch((error: Error) => this.store.fail(this.store.t('读取网络接口失败'), error)))
      }.width('100%')
      ForEach(this.store.interfaces, (local: LocalInterface) => {
        Column({ space: 8 }) {
          Row() {
            Text(local.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).layoutWeight(1)
            Text(this.store.t(local.ignored ? '已排除' : '已启用')).fontSize(12).fontColor($r('sys.color.font_secondary'))
          }.width('100%')
          Text(`${local.ip}/${local.prefixLength}`).fontSize(14).fontColor(this.store.accentText).copyOption(CopyOptions.LocalDevice).width('100%')
          Button(this.store.t('加入规则')).fontSize(13).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText).onClick(() => {
            this.patterns = this.patterns ? `${this.patterns}\n${local.ip}` : local.ip;
            if (this.mode === 'none') this.mode = 'allow';
          })
        }.padding(20).width('100%').backgroundColor(this.store.surfaceColor).borderRadius(24)
      }, (local: LocalInterface) => `${local.name}:${local.ip}:${local.ignored}`)
      if (!this.store.interfaces.length) {
        Text(this.store.t('尚未读取到网络地址')).fontSize(14).fontColor($r('sys.color.font_secondary')).padding(24)
      }
    }.width('100%')
  }
}
