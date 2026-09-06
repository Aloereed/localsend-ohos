import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct Index {
  @State tab: number = 0;
  @State alias: string = '我的鸿蒙设备';
  @State quickSave: boolean = false;
  @State saveHistory: boolean = true;
  private storage: preferences.Preferences | undefined = undefined;

  async aboutToAppear(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.storage = await preferences.getPreferences(context, 'aloesend');
    this.alias = await this.storage.get('alias', '我的鸿蒙设备') as string;
    this.quickSave = await this.storage.get('quickSave', false) as boolean;
    this.saveHistory = await this.storage.get('saveHistory', true) as boolean;
  }

  async persist(key: string, value: preferences.ValueType): Promise<void> {
    await this.storage?.put(key, value);
    await this.storage?.flush();
  }

  @Builder
  heading(title: string, subtitle: string) {
    Column({ space: 8 }) {
      Text(title).fontSize(32).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
      Text(subtitle).fontSize(14).fontColor($r('sys.color.font_secondary'))
    }.alignItems(HorizontalAlign.Start).width('100%').padding({ top: 24, bottom: 24 })
  }

  @Builder
  info(title: string, description: string) {
    Column({ space: 10 }) {
      Text(title).fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
      Text(description).fontSize(14).lineHeight(23).fontColor($r('sys.color.font_secondary'))
    }.alignItems(HorizontalAlign.Start).width('100%').padding(24)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24).margin({ bottom: 16 })
  }

  @Builder
  receive() {
    this.heading('接收', '靠近一点，分享多一点')
    Column({ space: 16 }) {
      Text('A').fontSize(38).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        .width(88).height(88).textAlign(TextAlign.Center).backgroundColor('#168A75').borderRadius(28)
      Text(this.alias).fontSize(24).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
      Text('让文件，自由抵达').fontSize(14).fontColor($r('sys.color.font_secondary'))
    }.width('100%').padding(32).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(28).margin({ bottom: 24 })
    this.info('01  连接同一网络', '手机与电脑连接同一个 Wi-Fi，无需上传云端。')
    this.info('02  选择这台设备', '在另一台设备的 LocalSend 中选择你的设备。')
    this.info('03  确认接收', '查看文件内容后确认，文件留在你的设备上。')
  }

  @Builder
  send() {
    this.heading('发送', '跨越设备，传递心意')
    this.info('选择要分享的内容', '文件、照片、文件夹或一句话。原生选择与传输服务将在后续里程碑接入。')
    this.info('附近的设备', '发现服务尚未接入，此版本不会显示模拟设备。')
  }

  @Builder
  messages() {
    this.heading('消息', '让每一句话都有来处')
    this.info('还没有消息', '设备之间分享的文字和链接将在这里保留。')
  }

  @Builder
  settings() {
    this.heading('设置', '按你的习惯，恰到好处')
    Column({ space: 16 }) {
      Text('设备名称').fontSize(16).width('100%').fontColor($r('sys.color.font_primary'))
      TextInput({ text: this.alias, placeholder: '给设备起个名字' }).maxLength(40)
        .onChange((value: string) => { this.alias = value; })
        .onSubmit(() => { this.alias = this.alias.trim() || '我的鸿蒙设备'; this.persist('alias', this.alias); })
      Row() {
        Text('自动接收').layoutWeight(1).fontColor($r('sys.color.font_primary'))
        Toggle({ type: ToggleType.Switch, isOn: this.quickSave }).selectedColor('#168A75')
          .onChange((value: boolean) => { this.quickSave = value; this.persist('quickSave', value); })
      }.width('100%')
      Row() {
        Text('保留传输历史').layoutWeight(1).fontColor($r('sys.color.font_primary'))
        Toggle({ type: ToggleType.Switch, isOn: this.saveHistory }).selectedColor('#168A75')
          .onChange((value: boolean) => { this.saveHistory = value; this.persist('saveHistory', value); })
      }.width('100%')
    }.padding(24).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24).margin({ bottom: 20 })
    this.info('AloeSend · 原生鸿蒙', '本地连接 · 无需账号 · 不经云端\nArkUI 迁移里程碑 1')
  }

  @Builder
  tabItem(title: string, mark: string, index: number) {
    Column({ space: 4 }) {
      Text(mark).fontSize(23).fontColor(this.tab === index ? '#168A75' : $r('sys.color.font_secondary'))
      Text(title).fontSize(11).fontColor(this.tab === index ? '#168A75' : $r('sys.color.font_secondary'))
    }.width('100%').height(56).justifyContent(FlexAlign.Center)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.tab }) {
      TabContent() {
        Scroll() { Column() { this.receive() }.padding({ left: 24, right: 24, bottom: 28 }).constraintSize({ maxWidth: 720 }).width('100%') }
          .width('100%').height('100%').align(Alignment.Top)
      }.tabBar(this.tabItem('接收', '↓', 0))
      TabContent() {
        Scroll() { Column() { this.send() }.padding({ left: 24, right: 24, bottom: 28 }).constraintSize({ maxWidth: 720 }).width('100%') }
          .width('100%').height('100%').align(Alignment.Top)
      }.tabBar(this.tabItem('发送', '↑', 1))
      TabContent() {
        Scroll() { Column() { this.messages() }.padding({ left: 24, right: 24, bottom: 28 }).constraintSize({ maxWidth: 720 }).width('100%') }
          .width('100%').height('100%').align(Alignment.Top)
      }.tabBar(this.tabItem('消息', '≋', 2))
      TabContent() {
        Scroll() { Column() { this.settings() }.padding({ left: 24, right: 24, bottom: 28 }).constraintSize({ maxWidth: 720 }).width('100%') }
          .width('100%').height('100%').align(Alignment.Top)
      }.tabBar(this.tabItem('设置', '⚙', 3))
    }.barHeight(68).animationDuration(240).onChange((index: number) => { this.tab = index; })
      .backgroundColor($r('sys.color.background_primary')).width('100%').height('100%')
  }
}