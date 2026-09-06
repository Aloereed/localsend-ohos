import { AppStore } from '../model/AppStore';

@Component
export struct SettingsView {
  @ObjectLink store: AppStore;
  onNavigate: (route: string) => void = () => {};
  @State alias: string = '';
  @State port: string = '';
  @State group: string = '';
  @State pin: string = '';

  aboutToAppear(): void {
    this.alias = this.store.settings.alias;
    this.port = String(this.store.settings.port);
    this.group = this.store.settings.multicast;
    this.pin = this.store.settings.pin;
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
          if (key === 'animation') this.store.settings.animations = value;
          if (key === 'visible') this.store.settings.visible = value;
          if (key === 'advanced') this.store.settings.advanced = value;
          this.store.save();
        }).accessibilityText(title)
    }.padding(18).width('100%')
  }

  saveNetwork(): void {
    const port = Number(this.port);
    if (!Number.isInteger(port) || port < 1024 || port > 65535) { this.store.error = '端口范围为 1024–65535'; return; }
    const parts = this.group.split('.').map((part: string) => Number(part));
    if (parts.length !== 4 || parts.some((part: number) => !Number.isInteger(part) || part < 0 || part > 255) || parts[0] < 224 || parts[0] > 239) {
      this.store.error = '请输入有效的 IPv4 组播地址'; return;
    }
    this.store.settings.port = port;
    this.store.settings.multicast = this.group;
    this.store.save();
    this.store.notice = '网络设置已保存，重启接收服务后生效';
  }

  build() {
    Column() {
      this.title('设备')
      Column({ space: 12 }) {
        Text('设备名称').fontSize(14).fontColor($r('sys.color.font_secondary')).width('100%')
        TextInput({ text: this.alias, placeholder: '设备名称' }).maxLength(40).onChange((value: string) => this.alias = value)
        Button('保存名称').type(ButtonType.Capsule).backgroundColor(this.store.settings.accent).onClick(() => {
          this.store.settings.alias = this.alias.trim() || '我的鸿蒙设备';
          this.store.save(); this.store.notice = '设备名称已保存';
        })
      }.padding(20).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24)
      this.title('外观')
      Column() {
        Row() {
          Text('深浅模式').layoutWeight(1).fontColor($r('sys.color.font_primary'))
          Select([{ value: '跟随系统' }, { value: '浅色' }, { value: '深色' }])
            .selected(this.store.settings.theme === 'light' ? 1 : this.store.settings.theme === 'dark' ? 2 : 0)
            .onSelect((index: number) => {
              this.store.settings.theme = ['system', 'light', 'dark'][index];
              this.store.applyTheme(); this.store.save();
            })
        }.padding(18).width('100%')
        Row({ space: 12 }) {
          Text('主题颜色').layoutWeight(1).fontColor($r('sys.color.font_primary'))
          ForEach(['#168A75', '#2473E8', '#7454C9', '#BB5C36', '#BD4F78'], (color: string) => {
            Button('').width(28).height(28).backgroundColor(color)
              .border({ width: this.store.settings.accent === color ? 3 : 0, color: $r('sys.color.font_primary') })
              .onClick(() => { this.store.settings.accent = color; this.store.save(); }).accessibilityText(`主题色 ${color}`)
          })
        }.padding(18).width('100%')
        this.toggle('界面动画', '自然流畅的页面过渡', this.store.settings.animations, 'animation')
      }.width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24)
      this.title('接收')
      Column() {
        this.toggle('允许发现', '在同一网络中显示本设备', this.store.settings.visible, 'visible')
        this.toggle('自动接收', '信任当前网络时使用，无需逐次确认', this.store.settings.quickSave, 'quickSave')
        this.toggle('仅收藏设备自动接收', '其他设备仍需手动确认', this.store.settings.favoriteQuickSave, 'favorites')
        this.toggle('保留历史', '记录仅保存在当前设备', this.store.settings.saveHistory, 'history')
        this.toggle('自动完成', '成功传输后结束会话', this.store.settings.autoFinish, 'finish')
        this.link('接收历史', '', 'history')
        Column({ space: 10 }) {
          Text('接收 PIN').fontSize(14).fontColor($r('sys.color.font_secondary')).width('100%')
          TextInput({ text: this.pin, placeholder: '留空表示不设 PIN' }).type(InputType.Number).maxLength(12)
            .onChange((value: string) => this.pin = value)
          Button('保存 PIN').onClick(() => {
            this.store.settings.pin = this.pin; this.store.save(); this.store.notice = '接收 PIN 已更新';
          }).backgroundColor(this.store.settings.accent)
        }.padding(18)
      }.width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24)
      this.title('网络')
      Column() {
        this.link('连接诊断', this.store.serverStatus, 'diagnostics')
        this.toggle('高级设置', '端口与组播地址', this.store.settings.advanced, 'advanced')
        if (this.store.settings.advanced) {
          Column({ space: 12 }) {
            TextInput({ text: this.port, placeholder: '端口 53317' }).type(InputType.Number).onChange((value: string) => this.port = value)
            TextInput({ text: this.group, placeholder: '组播地址' }).onChange((value: string) => this.group = value)
            Button('保存网络设置').backgroundColor(this.store.settings.accent).onClick(() => this.saveNetwork())
          }.padding(18)
        }
      }.width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24)
      this.title('帮助与支持')
      Column() {
        this.link('使用帮助', '', 'help')
        this.link('隐私政策', '', 'privacy')
        this.link('开源许可', '', 'licenses')
        this.link('更新记录', '', 'changelog')
        this.link('关于 AloeSend', '原生鸿蒙', 'about')
      }.width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24)
    }.width('100%')
  }
}
