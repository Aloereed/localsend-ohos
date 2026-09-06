import { common } from '@kit.AbilityKit';
import { AppStore, appStore, Peer } from '../model/AppStore';
import { SettingsView } from '../components/SettingsView';
import { SendView } from '../components/SendView';
import { LibraryView } from '../components/LibraryView';

@Entry
@Component
struct Index {
  @State store: AppStore = appStore;
  @State tab: number = 0;
  @State route: string = '';

  async aboutToAppear(): Promise<void> {
    await this.store.init(this.getUIContext().getHostContext() as common.UIAbilityContext);
  }

  onBackPress(): boolean {
    if (this.route) { this.route = ''; return true; }
    if (this.tab !== 0) { this.tab = 0; return true; }
    return false;
  }

  title(): string {
    if (this.route === 'history') return '接收历史';
    if (this.route === 'diagnostics') return '连接诊断';
    if (this.route === 'help') return '使用帮助';
    if (this.route === 'privacy') return '隐私政策';
    if (this.route === 'licenses') return '开源许可';
    if (this.route === 'changelog') return '更新记录';
    if (this.route === 'web') return '通过链接分享';
    return '关于 AloeSend';
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
      Text(description).fontSize(14).lineHeight(24).fontColor($r('sys.color.font_secondary')).copyOption(CopyOptions.LocalDevice)
    }.alignItems(HorizontalAlign.Start).width('100%').padding(24)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24).margin({ bottom: 16 })
  }

  @Builder
  receive() {
    this.heading('接收', '靠近一点，分享多一点')
    Column({ space: 16 }) {
      Text('A').fontSize(38).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        .width(88).height(88).textAlign(TextAlign.Center).backgroundColor(this.store.settings.accent).borderRadius(28)
      Text(this.store.settings.alias).fontSize(24).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
      Text(this.store.serverStatus).fontSize(14).fontColor($r('sys.color.font_secondary'))
      ForEach(this.store.localIps, (ip: string) => {
        Text(`${ip}:${this.store.settings.port}`).fontSize(13).fontColor($r('sys.color.font_secondary')).copyOption(CopyOptions.LocalDevice)
      })
    }.width('100%').padding(32).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(28).margin({ bottom: 24 })
    Row({ space: 12 }) {
      Button('接收历史').layoutWeight(1).height(48).backgroundColor($r('sys.color.comp_background_primary')).fontColor(this.store.settings.accent)
        .onClick(() => this.route = 'history')
      Button('接收设置').layoutWeight(1).height(48).backgroundColor($r('sys.color.comp_background_primary')).fontColor(this.store.settings.accent)
        .onClick(() => this.tab = 3)
    }.width('100%').margin({ bottom: 24 })
    this.info('同一网络，自由分享', '保持双方的 LocalSend 打开，连接同一 Wi-Fi。收到请求时，先查看内容，再决定是否接收。')
    this.info('文件留在你手中', '接收后可在历史中打开或另存为。文字和链接在消息页集中查看。')
  }

  @Builder
  details() {
    if (this.route === 'history') { LibraryView({ store: this.store, messagesOnly: false }) }
    else if (this.route === 'diagnostics') {
      this.info('接收服务', this.store.serverStatus)
      this.info('本机地址', this.store.localIps.length ? this.store.localIps.join('\n') : '尚未读取到网络地址')
      this.info('连接参数', `端口 ${this.store.settings.port}\n组播 ${this.store.settings.multicast}\n协议 LocalSend 2.1`)
      Button('复制诊断信息').backgroundColor(this.store.settings.accent).onClick(() => this.store.copy(this.store.logs.join('\n')))
      ForEach(this.store.logs, (line: string) => {
        Text(line).fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%').padding(10).copyOption(CopyOptions.LocalDevice)
      })
    } else if (this.route === 'help') {
      this.info('找不到设备？', '确认两台设备连接同一个局域网，关闭路由器的 AP 隔离。允许 LocalSend 通过防火墙，确保 TCP 与 UDP 53317 端口可用。也可通过地址直接添加设备。')
      this.info('接收的文件在哪里？', '接收文件保存在应用目录。前往接收历史，选择“另存为”，通过系统文件选择器保存到你选择的位置。')
      this.info('文字与文件', '发送页可以选择文件、图片、文件夹，以及文字或剪贴板内容。选择后点击目标设备。文件重命名只影响对方收到的名称。')
    } else if (this.route === 'privacy') {
      this.info('设备之间直接传输', 'AloeSend 不要求账号，不将文件上传至云端。内容通过本地网络在发送方和接收方之间传输。')
      this.info('本地记录', '设备名称、收藏、设置与传输历史只保存在本机。你可以关闭记录或清空历史。清空历史不会删除已接收的文件。')
      this.info('系统权限', '文件、照片和剪贴板仅在你主动选择相关操作时访问。接收请求默认需要确认，请仅在可信网络上启用自动接收。')
    } else if (this.route === 'licenses') {
      this.info('LocalSend / AloeSend', '基于 LocalSend 项目，遵循 Apache License 2.0。\nhttps://github.com/localsend/localsend\nhttps://github.com/Aloereed/localsend-ohos')
      this.info('原生实现', 'ArkUI 界面和 ArkTS 平台服务使用 HarmonyOS SDK。原项目第三方版权声明保留在仓库对应依赖中。')
    } else if (this.route === 'changelog') {
      this.info('原生迁移 · M2', '系统文件与照片选择、文件夹选择、文字和剪贴板、选择清单、重命名、历史与消息搜索、另存为、主题与接收设置。')
      this.info('原生迁移 · M1', '四个原生页面、鸿蒙浅深色资源、本地偏好存储、可追溯的未签名里程碑构建。')
    } else if (this.route === 'web') {
      this.info('让浏览器也能加入', '浏览器分享服务正在接入。服务启动后，这里会显示真实的局域网链接与二维码。')
    } else {
      this.info('AloeSend', '为鸿蒙重新设计的本地分享体验。\n跨越设备，传递心意。\n原生 ArkUI · 无需账号 · 不经云端')
      this.info('感谢开源社区', 'LocalSend 和所有贡献者，让跨平台分享成为可能。\n源码：github.com/Aloereed/localsend-ohos')
    }
  }

  @Builder
  tabItem(title: string, mark: string, index: number) {
    Column({ space: 4 }) {
      Text(mark).fontSize(23).fontColor(this.tab === index ? this.store.settings.accent : $r('sys.color.font_secondary'))
      Text(title).fontSize(11).fontColor(this.tab === index ? this.store.settings.accent : $r('sys.color.font_secondary'))
    }.width('100%').height(56).justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      if (this.store.error || this.store.notice) {
        Row({ space: 12 }) {
          Text(this.store.error || this.store.notice).fontSize(13).layoutWeight(1).fontColor($r('sys.color.font_primary'))
          Button('×').backgroundColor(Color.Transparent).fontColor($r('sys.color.font_primary')).onClick(() => { this.store.error = ''; this.store.notice = ''; })
        }.padding({ left: 20, right: 12, top: 8, bottom: 8 }).width('100%').backgroundColor($r('sys.color.comp_background_tertiary'))
      }
      if (this.route) {
        Row() {
          Button('‹ 返回').backgroundColor(Color.Transparent).fontColor(this.store.settings.accent).onClick(() => this.route = '')
          Text(this.title()).fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).layoutWeight(1)
        }.width('100%').padding(12)
        Scroll() { Column() { this.details() }.padding(24).constraintSize({ maxWidth: 720 }).width('100%') }.layoutWeight(1).width('100%').align(Alignment.Top)
      } else {
        Tabs({ barPosition: BarPosition.End, index: this.tab }) {
          TabContent() {
            Scroll() { Column() { this.receive() }.padding({ left: 24, right: 24, bottom: 28 }).constraintSize({ maxWidth: 720 }).width('100%') }.width('100%').height('100%').align(Alignment.Top)
          }.tabBar(this.tabItem('接收', '↓', 0))
          TabContent() {
            Scroll() {
              Column() {
                this.heading('发送', '跨越设备，传递心意')
                SendView({ store: this.store, onSend: (peer: Peer) => { this.store.notice = '传输服务尚未接入'; },
                  onDiscover: () => { this.store.notice = '发现服务尚未接入'; },
                  onAddress: (address: string) => { this.store.notice = '发现服务尚未接入'; }, onWebShare: () => this.route = 'web' })
              }.padding({ left: 24, right: 24, bottom: 28 }).constraintSize({ maxWidth: 720 }).width('100%')
            }.width('100%').height('100%').align(Alignment.Top)
          }.tabBar(this.tabItem('发送', '↑', 1))
          TabContent() {
            Scroll() { Column() { this.heading('消息', '让每一句话都有来处'); LibraryView({ store: this.store }) }.padding({ left: 24, right: 24, bottom: 28 }).constraintSize({ maxWidth: 720 }).width('100%') }.width('100%').height('100%').align(Alignment.Top)
          }.tabBar(this.tabItem('消息', '≋', 2))
          TabContent() {
            Scroll() { Column() { this.heading('设置', '按你的习惯，恰到好处'); SettingsView({ store: this.store, onNavigate: (route: string) => this.route = route }) }.padding({ left: 24, right: 24, bottom: 28 }).constraintSize({ maxWidth: 720 }).width('100%') }.width('100%').height('100%').align(Alignment.Top)
          }.tabBar(this.tabItem('设置', '⚙', 3))
        }.barHeight(68).animationDuration(this.store.settings.animations ? 240 : 0).onChange((index: number) => this.tab = index).layoutWeight(1)
      }
    }.backgroundColor($r('sys.color.background_primary')).width('100%').height('100%')
  }
}