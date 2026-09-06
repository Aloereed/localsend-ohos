import { common } from '@kit.AbilityKit';
import { AppStore, appStore, Peer } from '../model/AppStore';
import { SettingsView } from '../components/SettingsView';
import { SendView } from '../components/SendView';
import { LibraryView } from '../components/LibraryView';
import { TransferList } from '../components/TransferList';
import { localSend } from '../network/LocalSendService';
import { WebShareView } from '../components/WebShareView';
import { PeerDetailView } from '../components/PeerDetailView';
import { AppIcon } from '../components/AppIcon';
import { MessagesView } from '../components/MessagesView';

@Entry
@Component
struct Index {
  @State store: AppStore = appStore;
  @State tab: number = 0;
  @State route: string = '';
  @State pinText: string = '';
  @State selectedPeer: Peer = new Peer();
  @State windowWidth: number = 400;
  @State messageDetail: boolean = false;

  async aboutToAppear(): Promise<void> {
    await this.store.init(this.getUIContext().getHostContext() as common.UIAbilityContext);
    this.store.onTransferCompleted = () => {
      if (!this.store.settings.autoFinish) return;
      setTimeout(() => {
        if (this.route === 'transfers' && this.store.batchRemaining === 0 &&
          !this.store.transfers.some((item) => item.status === 'waiting' || item.status === 'transferring')) this.route = '';
      }, 1200);
    };
    await localSend.start();
  }

  onBackPress(): boolean {
    if (this.route) { this.route = ''; return true; }
    if (this.tab === 2 && this.messageDetail) { this.messageDetail = false; return true; }
    if (this.tab !== 0) { this.tab = 0; return true; }
    return false;
  }

  title(): string {
    if (this.route === 'peer') return this.store.t('设备详情');
    if (this.route === 'transfers') return this.store.t('传输任务');
    if (this.route === 'history') return this.store.t('接收历史');
    if (this.route === 'diagnostics') return this.store.t('连接诊断');
    if (this.route === 'help') return this.store.t('使用帮助');
    if (this.route === 'privacy') return this.store.t('隐私政策');
    if (this.route === 'licenses') return this.store.t('开源许可');
    if (this.route === 'changelog') return this.store.t('更新记录');
    if (this.route === 'web') return this.store.t('通过链接分享');
    return this.store.t('关于 AloeSend');
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
    this.heading(this.store.t('接收'), this.store.t('靠近一点，分享多一点'))
    Column({ space: 16 }) {
      Stack() { AppIcon({ name: 'receive', iconSize: 40, tint: Color.White }) }
        .width(88).height(88).backgroundColor(this.store.settings.accent).borderRadius(30).margin({ top: 8, bottom: 8 })
      Text(this.store.settings.alias).fontSize(26).fontWeight(FontWeight.Medium).maxLines(2).textAlign(TextAlign.Center).fontColor($r('sys.color.font_primary'))
      Row({ space: 7 }) {
        Circle().width(6).height(6).fill(this.store.serverStatus.startsWith('已就绪') ? this.store.settings.accent : '#B88632')
        Text(this.store.settings.visible ? this.store.t(this.store.serverStatus) : this.store.t('当前已隐藏，可通过地址连接')).fontSize(13).fontColor($r('sys.color.font_secondary'))
      }.padding({ left: 14, right: 14, top: 8, bottom: 8 }).backgroundColor($r('sys.color.comp_background_tertiary')).borderRadius(18)
      ForEach(this.store.localIps, (ip: string) => {
        Text(`${ip}:${this.store.settings.port}`).fontSize(13).fontColor($r('sys.color.font_secondary')).copyOption(CopyOptions.LocalDevice)
      })
    }.width('100%').padding(32).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(28).margin({ bottom: 24 })
    Row({ space: 12 }) {
      Button(this.store.t('接收历史')).layoutWeight(1).height(48).backgroundColor($r('sys.color.comp_background_primary')).fontColor(this.store.settings.accent)
        .onClick(() => this.route = 'history')
      Button(this.store.t('接收设置')).layoutWeight(1).height(48).backgroundColor($r('sys.color.comp_background_primary')).fontColor(this.store.settings.accent)
        .onClick(() => this.tab = 3)
    }.width('100%').margin({ bottom: 24 })
    Button(this.store.t('查看传输任务')).backgroundColor(this.store.settings.accent).onClick(() => this.route = 'transfers').margin({ bottom: 20 })
    this.info(this.store.t('同一网络，自由分享'), this.store.t('保持双方的 LocalSend 打开，连接同一 Wi-Fi。收到请求时，先查看内容，再决定是否接收。'))
    this.info(this.store.t('文件留在你手中'), this.store.t('接收后可在历史中打开或另存为。文字和链接在消息页集中查看。'))
  }

  @Builder
  details() {
    if (this.route === 'peer') { PeerDetailView({ store: this.store, peer: this.selectedPeer, onSend: () => { localSend.send(this.selectedPeer); this.route = 'transfers'; } }) }
    else if (this.route === 'transfers') { TransferList({ store: this.store }) }
    else if (this.route === 'history') { LibraryView({ store: this.store, messagesOnly: false }) }
    else if (this.route === 'diagnostics') {
      this.info(this.store.t('接收服务'), this.store.serverStatus)
      this.info(this.store.t('本机证书指纹'), this.store.settings.fingerprint)
      Button(this.store.t('重启接收服务')).backgroundColor(this.store.settings.accent).onClick(() => localSend.restart())
      this.info(this.store.t('本机地址'), this.store.localIps.length ? this.store.localIps.join('\n') : this.store.t('尚未读取到网络地址'))
      this.info(this.store.t('连接参数'), this.store.tf('端口 {0}\n组播 {1}\n协议 LocalSend 2.1', [String(this.store.settings.port), this.store.settings.multicast]))
      Button(this.store.t('复制诊断信息')).backgroundColor(this.store.settings.accent).onClick(() => this.store.copy(this.store.logs.join('\n')))
      ForEach(this.store.logs, (line: string) => {
        Text(line).fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%').padding(10).copyOption(CopyOptions.LocalDevice)
      })
    } else if (this.route === 'help') {
      this.info(this.store.t('找不到设备？'), this.store.t('确认两台设备连接同一个局域网，关闭路由器的 AP 隔离。允许 LocalSend 通过防火墙，确保 TCP 与 UDP 53317 端口可用。也可通过地址直接添加设备。'))
      this.info(this.store.t('接收的文件在哪里？'), this.store.t('接收文件保存在应用目录。前往接收历史，选择“另存为”，通过系统文件选择器保存到你选择的位置。'))
      this.info(this.store.t('文字与文件'), this.store.t('发送页可以选择文件、图片、文件夹，以及文字或剪贴板内容。选择后点击目标设备。文件重命名只影响对方收到的名称。'))
    } else if (this.route === 'privacy') {
      this.info(this.store.t('设备之间直接传输'), this.store.t('AloeSend 不要求账号，不将文件上传至云端。内容通过本地网络在发送方和接收方之间传输。'))
      this.info(this.store.t('本地记录'), this.store.t('设备名称、收藏、设置与传输历史只保存在本机。你可以关闭记录或清空历史。清空历史不会删除已接收的文件。'))
      this.info(this.store.t('系统权限'), this.store.t('文件、照片和剪贴板仅在你主动选择相关操作时访问。接收请求默认需要确认，请仅在可信网络上启用自动接收。'))
    } else if (this.route === 'licenses') {
      this.info('LocalSend / AloeSend', this.store.t('基于 LocalSend 项目，遵循 Apache License 2.0。\nhttps://github.com/localsend/localsend\nhttps://github.com/Aloereed/localsend-ohos'))
      this.info(this.store.t('原生实现'), this.store.t('ArkUI 界面和 ArkTS 平台服务使用 HarmonyOS SDK。原项目第三方版权声明保留在仓库对应依赖中。'))
    } else if (this.route === 'changelog') {
      this.info(this.store.t('原生迁移 · M2'), this.store.t('系统文件与照片选择、文件夹选择、文字和剪贴板、选择清单、重命名、历史与消息搜索、另存为、主题与接收设置。'))
      this.info(this.store.t('原生迁移 · M1'), this.store.t('四个原生页面、鸿蒙浅深色资源、本地偏好存储、可追溯的未签名里程碑构建。'))
    } else if (this.route === 'web') {
      WebShareView({ store: this.store })
    } else {
      this.info('AloeSend', this.store.t('为鸿蒙重新设计的本地分享体验。\n跨越设备，传递心意。\n原生 ArkUI · 无需账号 · 不经云端'))
      this.info(this.store.t('感谢开源社区'), this.store.t('LocalSend 和所有贡献者，让跨平台分享成为可能。\n源码：github.com/Aloereed/localsend-ohos'))
    }
  }

  @Builder
  tabItem(title: string, mark: string, index: number) {
    Column({ space: 4 }) {
      Stack() { AppIcon({ name: ['receive', 'send', 'message', 'settings'][index], iconSize: 23,
        tint: this.tab === index ? this.store.settings.accent : $r('sys.color.font_secondary') }) }
        .width(58).height(32).borderRadius(18).backgroundColor(this.tab === index ? $r('sys.color.comp_background_tertiary') : Color.Transparent)
      Text(title).fontSize(12).fontWeight(this.tab === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.tab === index ? this.store.settings.accent : $r('sys.color.font_secondary'))
    }.width('100%').height(this.windowWidth >= 840 ? 80 : 64).justifyContent(FlexAlign.Center).accessibilityText(title)
  }

  build() {
    Column() {
      if (this.store.error || this.store.notice) {
        Row({ space: 12 }) {
          Text(this.store.t(this.store.error || this.store.notice)).fontSize(13).layoutWeight(1).fontColor($r('sys.color.font_primary'))
          Button('×').backgroundColor(Color.Transparent).fontColor($r('sys.color.font_primary')).onClick(() => { this.store.error = ''; this.store.notice = ''; })
        }.padding({ left: 20, right: 12, top: 8, bottom: 8 }).width('100%').backgroundColor($r('sys.color.comp_background_tertiary'))
      }
      if (this.store.webRequests.length > 0 && this.route !== 'web') {
        Button(this.store.tf('{0} 个浏览器下载请求 · 点击查看', [String(this.store.webRequests.length)])).width('100%').height(48)
          .backgroundColor(this.store.settings.accent).onClick(() => this.route = 'web')
      }
      if (this.store.incomingShare) {
        Button(this.store.t('内容已就绪 · 前往发送')).width('100%').height(48).backgroundColor(this.store.settings.accent)
          .onClick(() => { this.store.incomingShare = false; this.route = ''; this.tab = 1; })
      }
      if (this.store.pendingPin) {
        Column({ space: 12 }) {
          Text(this.store.t('请输入对方设备的接收 PIN')).fontSize(18).fontColor($r('sys.color.font_primary'))
          TextInput({ text: this.pinText, placeholder: 'PIN' }).type(InputType.Number).maxLength(12).onChange((value: string) => this.pinText = value)
          Row({ space: 12 }) {
            Button(this.store.t('取消')).onClick(() => localSend.submitPin(''))
            Button(this.store.t('确认')).backgroundColor(this.store.settings.accent).onClick(() => { localSend.submitPin(this.pinText); this.pinText = ''; })
          }
        }.padding(24).width('100%')
      }
      if (this.store.pendingReceive) {
        Scroll() {
          Column() {
            this.heading(this.store.t('收到分享请求'), this.store.t('查看内容，再决定是否接收'))
            TransferList({ store: this.store, pendingOnly: true })
          }.padding(24).constraintSize({ maxWidth: 720 }).width('100%')
        }.layoutWeight(1).width('100%')
      } else if (this.route) {
        Row() {
          Button(this.store.t('‹ 返回')).backgroundColor(Color.Transparent).fontColor(this.store.settings.accent).onClick(() => this.route = '')
          Text(this.title()).fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).layoutWeight(1)
        }.width('100%').padding(12)
        Scroll() { Column() { this.details() }.padding(24).constraintSize({ maxWidth: 720 }).width('100%') }.layoutWeight(1).width('100%').align(Alignment.Top)
      } else {
        Tabs({ barPosition: this.windowWidth >= 840 ? BarPosition.Start : BarPosition.End, index: this.tab }) {
          TabContent() {
            Scroll() { Column() { this.receive() }.padding({ left: 24, right: 24, bottom: 28 }).constraintSize({ maxWidth: 720 }).width('100%') }.width('100%').height('100%').align(Alignment.Top)
          }.tabBar(this.tabItem(this.store.t('接收'), '↓', 0))
          TabContent() {
            Scroll() {
              Column() {
                this.heading(this.store.t('发送'), this.store.t('跨越设备，传递心意'))
                SendView({ store: this.store, onSend: (peer: Peer) => { localSend.send(peer); this.route = 'transfers'; },
                  onDiscover: () => { localSend.discover(); },
                  onAddress: (address: string) => { localSend.addAddress(address); }, onWebShare: () => this.route = 'web', onDetails: (peer: Peer) => { this.selectedPeer = peer; this.route = 'peer'; }, onSendMany: (peers: Peer[]) => { localSend.sendMany(peers); this.route = 'transfers'; } })
              }.padding({ left: 24, right: 24, bottom: 28 }).constraintSize({ maxWidth: 720 }).width('100%')
            }.width('100%').height('100%').align(Alignment.Top)
          }.tabBar(this.tabItem(this.store.t('发送'), '↑', 1))
          TabContent() {
            MessagesView({ store: this.store, detailOpen: $messageDetail, onTransfers: () => this.route = 'transfers' })
          }.tabBar(this.tabItem(this.store.t('消息'), '≋', 2))
          TabContent() {
            Scroll() { Column() { this.heading(this.store.t('设置'), this.store.t('按你的习惯，恰到好处')); SettingsView({ store: this.store, onNavigate: (route: string) => this.route = route }) }.padding({ left: 24, right: 24, bottom: 28 }).constraintSize({ maxWidth: 720 }).width('100%') }.width('100%').height('100%').align(Alignment.Top)
          }.tabBar(this.tabItem(this.store.t('设置'), '⚙', 3))
        }.vertical(this.windowWidth >= 840).barWidth(this.windowWidth >= 840 ? 96 : '100%').barHeight(this.windowWidth >= 840 ? '100%' : 76)
          .animationDuration(this.store.settings.animations ? 240 : 0).onChange((index: number) => this.tab = index).layoutWeight(1)
      }
    }.backgroundColor($r('sys.color.background_primary')).width('100%').height('100%')
      .onAreaChange((oldArea: Area, newArea: Area) => this.windowWidth = Number(newArea.width))
  }
}
