import { AppStore } from '../model/AppStore';
import { localSend } from '../network/LocalSendService';
import { LengthMetrics } from '@kit.ArkUI';

@Component
export struct SettingsView {
  @ObjectLink store: AppStore;
  onNavigate: (route: string) => void = () => {};
  @State alias: string = '';
  @State port: string = '';
  @State group: string = '';
  @State pin: string = '';
  @State timeout: string = '';
  @State model: string = '';

  aboutToAppear(): void {
    this.alias = this.store.settings.alias;
    this.port = String(this.store.settings.port);
    this.group = this.store.settings.multicast;
    this.pin = this.store.settings.pin;
    this.timeout = String(this.store.settings.discoveryTimeout); this.model = this.store.settings.deviceModel;
  }

  @Builder
  title(text: string) {
    Text(text).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
      .width('100%').padding({ left: 8, top: 22, bottom: 10 })
  }

  @Builder
  link(text: string, detail: string, destination: string) {
    Row({ space: 10 }) {
      Text(text).fontSize(16).fontColor($r('sys.color.font_primary')).layoutWeight(1)
      Text(detail).fontSize(13).fontColor($r('sys.color.font_secondary'))
      Text('›').fontSize(24).fontColor($r('sys.color.font_secondary'))
    }.padding(18).width('100%').constraintSize({ minHeight: 58 }).onClick(() => this.onNavigate(destination))
      .accessibilityText(`${text} ${detail}`)
  }

  @Builder
  toggle(title: string, detail: string, enabled: boolean, key: string) {
    Row({ space: 12 }) {
      Column({ space: 5 }) {
        Text(title).fontSize(16).fontColor($r('sys.color.font_primary'))
        Text(detail).fontSize(12).fontColor($r('sys.color.font_secondary'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: enabled }).selectedColor(this.store.settings.accent)
        .onChange((value: boolean) => {
          if (key === 'quickSave') this.store.settings.quickSave = value;
          if (key === 'favorites') this.store.settings.favoriteQuickSave = value;
          if (key === 'history') this.store.settings.saveHistory = value;
          if (key === 'finish') this.store.settings.autoFinish = value;
          if (key === 'messages') this.store.settings.openMessagesOnReceive = value;
          if (key === 'gallery') { this.store.settings.offerGallerySave = value; if (!value) this.store.galleryQueue = []; }
          if (key === 'animation') this.store.settings.animations = value;
          if (key === 'visible') this.store.settings.visible = value;
          if (key === 'advanced') this.store.settings.advanced = value;
          if (key === 'https') this.store.settings.https = value;
          this.store.save();
          if (key === 'visible') localSend.announce();
          if (key === 'https') this.store.notice = this.store.t('加密设置已保存，请在没有传输时重启服务');
        }).accessibilityText(title)
    }.padding(18).width('100%')
  }

  saveNetwork(): void {
    const port = Number(this.port);
    const timeout = Number(this.timeout);
    if (!Number.isInteger(timeout) || timeout < 500 || timeout > 30000) { this.store.error = this.store.t('发现超时范围为 500–30000 毫秒'); return; }
    if (!Number.isInteger(port) || port < 1024 || port > 65535) { this.store.error = this.store.t('端口范围为 1024–65535'); return; }
    const parts = this.group.split('.').map((part: string) => Number(part));
    if (parts.length !== 4 || parts.some((part: number) => !Number.isInteger(part) || part < 0 || part > 255) || parts[0] < 224 || parts[0] > 239) {
      this.store.error = this.store.t('请输入有效的 IPv4 组播地址'); return;
    }
    this.store.settings.port = port;
    this.store.settings.multicast = this.group;
    this.store.settings.discoveryTimeout = timeout; this.store.settings.deviceModel = this.model.trim() || 'HarmonyOS';
    this.store.save();
    this.store.notice = this.store.t('网络设置已保存，重启接收服务后生效');
  }

  build() {
    Column() {
      this.title(this.store.t('设备'))
      Column({ space: 12 }) {
        Text(this.store.t('设备名称')).fontSize(14).fontColor($r('sys.color.font_secondary')).width('100%')
        TextInput({ text: this.alias, placeholder: this.store.t('设备名称') }).maxLength(40).onChange((value: string) => this.alias = value)
        Row({ space: 8 }) {
          Button(this.store.t('随机名称')).fontSize(13).backgroundColor($r('sys.color.comp_background_tertiary')).fontColor(this.store.accentText)
            .onClick(() => this.alias = this.store.randomAlias())
          Button(this.store.t('使用机型名称')).fontSize(13).backgroundColor($r('sys.color.comp_background_tertiary')).fontColor(this.store.accentText)
            .onClick(() => this.alias = this.store.systemDeviceName())
        }.width('100%')
        Button(this.store.t('保存名称')).type(ButtonType.Capsule).backgroundColor(this.store.accentFill).onClick(() => {
          this.store.settings.alias = this.alias.trim() || this.store.t('我的鸿蒙设备');
          this.store.save(); localSend.announce(); this.store.notice = this.store.t('设备名称已保存');
        })
      }.padding(20).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24)
      this.title(this.store.t('外观'))
      Column() {
        Row() {
          Text(this.store.t('语言')).layoutWeight(1).fontColor($r('sys.color.font_primary'))
          Select([{ value: this.store.t('跟随系统') }, { value: '简体中文' }, { value: 'English' }])
            .selected(this.store.settings.language === 'system' ? 0 : this.store.settings.language === 'en' ? 2 : 1)
            .value(this.store.settings.language === 'system' ? this.store.t('跟随系统') : this.store.settings.language === 'en' ? 'English' : '简体中文')
            .onSelect((index: number) => { this.store.settings.language = ['system', 'zh', 'en'][index]; this.store.save(); })
        }.padding(18).width('100%')
        Row() {
          Text(this.store.t('深浅模式')).layoutWeight(1).fontColor($r('sys.color.font_primary'))
          Select([{ value: this.store.t('跟随系统') }, { value: this.store.t('浅色') }, { value: this.store.t('深色') }])
            .selected(this.store.settings.theme === 'light' ? 1 : this.store.settings.theme === 'dark' ? 2 : 0)
            .value(this.store.t(this.store.settings.theme === 'light' ? '浅色' : this.store.settings.theme === 'dark' ? '深色' : '跟随系统'))
            .onSelect((index: number) => {
              this.store.settings.theme = ['system', 'light', 'dark'][index];
              this.store.applyTheme(); this.store.save();
            })
        }.padding(18).width('100%')
        Column({ space: 10 }) {
          Text(this.store.t('主题颜色')).width('100%').fontColor($r('sys.color.font_primary'))
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(6) } }) {
            ForEach(['#168A75', '#2473E8', '#7454C9', '#BB5C36', '#BD4F78'], (color: string) => {
              Button() {
                Circle().width(28).height(28).fill(color)
                  .stroke(this.store.settings.accent === color ? $r('sys.color.font_primary') : Color.Transparent).strokeWidth(2)
              }.width(44).height(44).backgroundColor(Color.Transparent)
                .onClick(() => { this.store.settings.accent = color; this.store.save(); }).accessibilityText(this.store.tf('主题色 {0}', [color]))
            })
          }.width('100%')
        }.padding(18).width('100%')
        this.toggle(this.store.t('界面动画'), this.store.t('自然流畅的页面过渡'), this.store.settings.animations, 'animation')
      }.width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24)
      this.title(this.store.t('接收'))
      Column() {
        this.toggle(this.store.t('允许发现'), this.store.t('在同一网络中显示本设备'), this.store.settings.visible, 'visible')
        this.toggle(this.store.t('自动接收'), this.store.t('信任当前网络时使用，无需逐次确认'), this.store.settings.quickSave, 'quickSave')
        this.toggle(this.store.t('仅收藏设备自动接收'), this.store.t('其他设备仍需手动确认'), this.store.settings.favoriteQuickSave, 'favorites')
        this.toggle(this.store.t('保留历史'), this.store.t('记录仅保存在当前设备'), this.store.settings.saveHistory, 'history')
        this.toggle(this.store.t('自动完成'), this.store.t('成功传输后结束会话'), this.store.settings.autoFinish, 'finish')
        this.toggle(this.store.t('接收后打开消息'), this.store.t('文件或文字收到后切换到对应会话'), this.store.settings.openMessagesOnReceive, 'messages')
        this.toggle(this.store.t('接收后提示保存到相册'), this.store.t('图片和视频接收完成后，通过系统确认保存到相册'), this.store.settings.offerGallerySave, 'gallery')
        Column({ space: 12 }) {
          Text(this.store.t('文件保存位置')).fontSize(16).fontColor($r('sys.color.font_primary')).width('100%')
          Text(this.store.settings.destinationMode === 'folder' ? this.store.settings.destination : this.store.t('应用内安全保存，可在接收历史中打开、分享或另存为'))
            .fontSize(13).lineHeight(20).fontColor($r('sys.color.font_secondary')).width('100%').maxLines(3)
          Row({ space: 10 }) {
            Button(this.store.t('选择保存目录')).backgroundColor($r('sys.color.comp_background_tertiary')).fontColor(this.store.accentText).onClick(() => this.store.chooseDestination())
            if (this.store.settings.destinationMode === 'folder') {
              Button(this.store.t('恢复默认')).backgroundColor(Color.Transparent).fontColor(this.store.accentText).onClick(() => {
                this.store.settings.destinationMode = 'private'; this.store.settings.destination = ''; this.store.save();
              })
            }
          }.width('100%')
        }.padding(18)
        this.link(this.store.t('接收历史'), '', 'history')
        Column({ space: 10 }) {
          Text(this.store.t('接收 PIN')).fontSize(14).fontColor($r('sys.color.font_secondary')).width('100%')
          TextInput({ text: this.pin, placeholder: this.store.t('留空表示不设 PIN') }).type(InputType.Number).maxLength(12)
            .onChange((value: string) => this.pin = value)
          Button(this.store.t('保存 PIN')).onClick(() => {
            this.store.settings.pin = this.pin; this.store.save(); this.store.notice = this.store.t('接收 PIN 已更新');
          }).backgroundColor(this.store.accentFill)
        }.padding(18)
      }.width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24)
      this.title(this.store.t('网络'))
      Column() {
        this.link(this.store.t('连接诊断'), this.store.t(this.store.serverStatus), 'diagnostics')
        this.link(this.store.t('网络接口'), this.store.t(this.store.settings.networkFilter === 'none' ? '全部网络' : '已筛选'), 'network')
        this.toggle(this.store.t('高级设置'), this.store.t('端口与组播地址'), this.store.settings.advanced, 'advanced')
        if (this.store.settings.advanced) {
          this.toggle(this.store.t('HTTPS 加密传输'), this.store.t('建议保持开启；修改后需重启接收服务'), this.store.settings.https, 'https')
          Column({ space: 12 }) {
            Text(this.store.t('设备型号')).fontSize(14).fontColor($r('sys.color.font_secondary')).width('100%')
            TextInput({ text: this.model, placeholder: 'HarmonyOS' }).maxLength(80).onChange((value: string) => this.model = value)
            Text(this.store.t('发现超时（毫秒）')).fontSize(14).fontColor($r('sys.color.font_secondary')).width('100%')
            TextInput({ text: this.timeout, placeholder: '1500' }).type(InputType.Number).onChange((value: string) => this.timeout = value)
            TextInput({ text: this.port, placeholder: this.store.t('端口 53317') }).type(InputType.Number).onChange((value: string) => this.port = value)
            TextInput({ text: this.group, placeholder: this.store.t('组播地址') }).onChange((value: string) => this.group = value)
            Button(this.store.t('保存网络设置')).backgroundColor(this.store.accentFill).onClick(() => this.saveNetwork())
            Button(this.store.t('重启接收服务')).backgroundColor($r('sys.color.comp_background_tertiary')).fontColor(this.store.accentText)
              .enabled(!this.store.activeTransfers)
              .onClick(() => localSend.restart())
            Row() {
              Text(this.store.t('设备类型')).layoutWeight(1).fontColor($r('sys.color.font_primary'))
              Select([{ value: this.store.t('手机 / 平板') }, { value: this.store.t('电脑') }, { value: this.store.t('无界面设备') }])
                .selected(this.store.settings.deviceType === 'desktop' ? 1 : this.store.settings.deviceType === 'headless' ? 2 : 0)
                .value(this.store.t(this.store.settings.deviceType === 'desktop' ? '电脑' : this.store.settings.deviceType === 'headless' ? '无界面设备' : '手机 / 平板'))
                .onSelect((index: number) => { this.store.settings.deviceType = ['mobile', 'desktop', 'headless'][index]; this.store.save(); localSend.announce(); })
            }.width('100%')
          }.padding(18)
        }
      }.width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24)
      this.title(this.store.t('帮助与支持'))
      Column() {
        this.link(this.store.t('使用帮助'), '', 'help')
        this.link(this.store.t('隐私政策'), '', 'privacy')
        this.link(this.store.t('开源许可'), '', 'licenses')
        this.link(this.store.t('更新记录'), '', 'changelog')
        this.link(this.store.t('关于 AloeSend'), this.store.t('原生鸿蒙'), 'about')
        this.link(this.store.t('支持开源项目'), '', 'donate')
      }.width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24)
    }.width('100%')
  }
}
