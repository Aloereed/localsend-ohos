import { common } from '@kit.AbilityKit';
import { AppStore, appStore, Peer, TransferView } from '../model/AppStore';
import { SettingsView } from '../components/SettingsView';
import { SendView } from '../components/SendView';
import { LibraryView } from '../components/LibraryView';
import { TransferList } from '../components/TransferList';
import { localSend } from '../network/LocalSendService';
import { WebShareView } from '../components/WebShareView';
import { PeerDetailView } from '../components/PeerDetailView';
import { AppIcon } from '../components/AppIcon';
import { MessagesView } from '../components/MessagesView';
import { NetworkView } from '../components/NetworkView';
import { util } from '@kit.ArkTS';
import { ReceiveRequestView } from '../components/ReceiveRequestView';
import { DownloadDirectoryPicker } from '../components/DownloadDirectoryPicker';
import { PrivacyView } from '../components/PrivacyView';

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
  @State legalText: string = '';
  @State creditsText: string = '';
  @State directoryVisible: boolean = false;
  @State directoryInitial: string = '';
  @State acceptingPrivacy: boolean = false;
  private directoryResolver: ((path: string) => void) | undefined = undefined;

  async aboutToAppear(): Promise<void> {
    await this.store.init(this.getUIContext().getHostContext() as common.UIAbilityContext);
    this.store.onReceiveStarted = () => { this.route = 'transfers'; };
    this.store.onPickDownloadDirectory = (path: string) => new Promise<string>((resolve) => {
      this.directoryResolver?.(''); this.directoryResolver = resolve;
      this.directoryInitial = path; this.directoryVisible = true;
    });
    this.store.onTransferCompleted = (transfer: TransferView) => {
      if (transfer.direction === 'receive' && transfer.peerInfo && this.store.settings.openMessagesOnReceive) {
        this.store.messageTarget = transfer.peerInfo; this.tab = 2; this.route = '';
      }
      if (!this.store.settings.autoFinish) return;
      setTimeout(() => {
        if (this.route === 'transfers' && this.store.batchRemaining === 0 &&
          !this.store.transfers.some((item) => item.status === 'waiting' || item.status === 'transferring')) this.route = '';
      }, 1200);
    };
    if (this.store.privacyAccepted) await this.startServices();
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.resourceManager.getRawFileContent('LICENSE.txt').then((bytes: Uint8Array) => this.legalText = new util.TextDecoder().decodeToString(bytes)).catch(() => {});
    context.resourceManager.getRawFileContent('CREDITS.txt').then((bytes: Uint8Array) => this.creditsText = new util.TextDecoder().decodeToString(bytes)).catch(() => {});
  }

  async startServices(): Promise<void> {
    if (!this.store.privacyAccepted) return;
    await localSend.start();
    await this.store.ensureDownloadAccess();
    await this.store.onPrivacyAccepted();
  }

  async acceptPrivacy(): Promise<void> {
    if (this.acceptingPrivacy) return;
    this.acceptingPrivacy = true;
    try { if (await this.store.acceptPrivacy()) await this.startServices(); }
    catch (error) { this.store.fail('启动应用失败', error as Error); }
    finally { this.acceptingPrivacy = false; }
  }

  onBackPress(): boolean {
    if (this.directoryVisible) { this.closeDirectory(''); return true; }
    if (this.route) { this.route = this.route === 'license-full' ? 'licenses' : this.route === 'credits' ? 'about' : ''; return true; }
    if (this.tab === 2 && this.messageDetail) { this.messageDetail = false; return true; }
    if (this.tab !== 0) { this.tab = 0; return true; }
    return false;
  }

  closeDirectory(path: string): void {
    const resolve = this.directoryResolver; this.directoryResolver = undefined;
    this.directoryVisible = false; resolve?.(path);
  }

  @Builder
  directorySheet() {
    DownloadDirectoryPicker({ store: this.store, initialPath: this.directoryInitial, onChoose: (path: string) => this.closeDirectory(path) })
  }

  title(): string {
    if (this.route === 'donate') return this.store.t('支持开源项目');
    if (this.route === 'credits') return this.store.t('贡献者与翻译者');
    if (this.route === 'license-full') return 'Apache License 2.0';
    if (this.route === 'network') return this.store.t('网络接口');
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
    Column({ space: 6 }) {
      Text(this.store.t(title)).fontSize(30).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
      if (subtitle) { Text(this.store.t(subtitle)).fontSize(13).fontColor($r('sys.color.font_secondary')) }
    }.alignItems(HorizontalAlign.Start).width('100%').padding({ top: 28, bottom: 22 })
  }

  @Builder
  info(title: string, description: string) {
    Column({ space: 10 }) {
      Text(title).fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
      Text(description).fontSize(14).lineHeight(24).fontColor($r('sys.color.font_secondary')).copyOption(CopyOptions.LocalDevice)
    }.alignItems(HorizontalAlign.Start).width('100%').padding(24)
      .backgroundColor(this.store.surfaceColor).borderRadius(24).margin({ bottom: 16 })
  }

  @Builder
  receive() {
    this.heading('接收', '')
    Column({ space: 14 }) {
      Stack() {
        Circle().width(192).height(192).fill(Color.Transparent).stroke(this.store.hairlineColor).strokeWidth(1)
        Circle().width(158).height(158).fill(this.store.glassColor)
          .shadow({ radius: this.store.settings.reduceEffects ? 0 : 26, color: this.store.dark ? '#28000000' : '#18314665', offsetY: 10 })
        Image($r('app.media.aloesend_logo')).width(112).height(112).objectFit(ImageFit.Contain).accessibilityLevel('no')
      }.width(208).height(208).margin({ top: 4, bottom: 6 })
        .radialGradient({ center: ['50%', '50%'], radius: 104, colors: [[this.store.ambientColor, 0], [Color.Transparent, 1]] })
      Text(this.store.settings.alias).fontSize(28).fontWeight(FontWeight.Medium).maxLines(2).textAlign(TextAlign.Center).fontColor($r('sys.color.font_primary'))
      Row({ space: 7 }) {
        Circle().width(6).height(6).fill(this.store.serverStatus.startsWith('已就绪') ? this.store.settings.accent : '#B88632')
        Text(this.store.settings.visible ? this.store.t(this.store.serverStatus) : this.store.t('当前已隐藏，可通过地址连接')).fontSize(13).fontColor($r('sys.color.font_secondary'))
      }.padding({ left: 14, right: 14, top: 8, bottom: 8 }).backgroundColor(this.store.glassColor).borderRadius(20)
      ForEach(this.store.localIps, (ip: string) => {
        Text(`${ip}:${this.store.listenerPort}`).fontSize(13).fontColor($r('sys.color.font_secondary')).copyOption(CopyOptions.LocalDevice)
      })
    }.width('100%').padding({ left: 20, right: 20, bottom: 32 })
    Column() {
      this.receiveShortcut('接收历史', 'history', 'history')
      Divider().color(this.store.controlSurface).margin({ left: 60 }).width('80%')
      this.receiveShortcut('查看传输任务', 'receive', 'transfers')
      Divider().color(this.store.controlSurface).margin({ left: 60 }).width('80%')
      this.receiveShortcut('接收设置', 'settings', 'settings')
    }.width('100%').backgroundColor(this.store.surfaceColor).borderRadius(24)
      .border({ width: 0.5, color: this.store.hairlineColor })
    Text(this.store.t('保持双方的 LocalSend 打开，连接同一 Wi-Fi。收到请求时，先查看内容，再决定是否接收。'))
      .fontSize(13).lineHeight(21).textAlign(TextAlign.Center).fontColor($r('sys.color.font_secondary')).width('100%').padding({ top: 22, left: 16, right: 16, bottom: 24 })
  }

  @Builder
  receiveShortcut(title: string, icon: string, route: string) {
    Row({ space: 16 }) {
      AppIcon({ name: icon, iconSize: 24, tint: this.store.accentText })
      Text(this.store.t(title)).fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).layoutWeight(1)
      Text('›').fontSize(24).fontColor($r('sys.color.font_secondary'))
    }.width('100%').padding({ left: 22, right: 20, top: 20, bottom: 20 })
      .onClick(() => { if (route === 'settings') this.tab = 3; else this.route = route; })
      .accessibilityText(this.store.t(title))
  }

  @Builder
  details() {
    if (this.route === 'license-full') {
      this.info('Apache License 2.0', this.legalText || this.store.t('正在读取…'))
    } else if (this.route === 'credits') {
      this.info(this.store.t('感谢每一位贡献者'), this.creditsText || this.store.t('正在读取…'))
    } else if (this.route === 'donate') {
      this.info(this.store.t('支持开源项目'), this.store.t('你可以自愿支持 LocalSend 的持续开发。所有文件分享功能均可免费使用。'))
      Button('GitHub Sponsors').width('100%').height(48).backgroundColor(this.store.accentFill).onClick(() => this.store.openUrl('https://github.com/sponsors/Tienisto'))
      Button('Ko-fi').width('100%').height(48).margin({ top: 16 }).fontColor(this.store.accentText).backgroundColor(this.store.surfaceColor).onClick(() => this.store.openUrl('https://ko-fi.com/tienisto'))
    } else if (this.route === 'network') { NetworkView({ store: this.store }) }
    else if (this.route === 'peer') { PeerDetailView({ store: this.store, peer: this.selectedPeer,
      onSend: () => { localSend.send(this.selectedPeer); this.route = 'transfers'; },
      onMessage: () => { this.store.messageTarget = this.selectedPeer; this.route = ''; this.tab = 2; } }) }
    else if (this.route === 'transfers') { TransferList({ store: this.store }) }
    else if (this.route === 'history') { LibraryView({ store: this.store, messagesOnly: false }) }
    else if (this.route === 'diagnostics') {
      this.info(this.store.t('接收服务'), this.store.t(this.store.serverStatus))
      this.info(this.store.t('本机证书指纹'), this.store.settings.fingerprint)
      Button(this.store.t('重启接收服务')).backgroundColor(this.store.accentFill).enabled(!this.store.activeTransfers).onClick(() => localSend.restart())
      this.info(this.store.t('本机地址'), this.store.localIps.length ? this.store.localIps.join('\n') : this.store.t('尚未读取到网络地址'))
      this.info(this.store.t('当前监听'), this.store.tf('端口 {0}\n组播 {1}\n协议 LocalSend 2.1', [String(this.store.listenerPort), this.store.listenerMulticast]))
      Button(this.store.t('复制诊断信息')).backgroundColor(this.store.accentFill).onClick(() => this.store.copy(this.store.logs.join('\n')))
      ForEach(this.store.logs, (line: string) => {
        Text(line).fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%').padding(10).copyOption(CopyOptions.LocalDevice)
      })
    } else if (this.route === 'help') {
      this.info(this.store.t('找不到设备？'), this.store.t('确认两台设备连接同一个局域网，关闭路由器的 AP 隔离。允许 LocalSend 通过防火墙，确保 TCP 与 UDP 53317 端口可用。也可通过地址直接添加设备。'))
      this.info(this.store.t('接收的文件在哪里？'), this.store.t('允许下载目录授权后，默认保存到 Download/com.aloereed.aloesend。未授权时保存在应用内，可从接收历史另存为。'))
      this.info(this.store.t('文字与文件'), this.store.t('发送页可以选择文件、图片、文件夹，以及文字或剪贴板内容。选择后点击目标设备。文件重命名只影响对方收到的名称。'))
    } else if (this.route === 'licenses') {
      this.info('LocalSend / AloeSend', this.store.t('基于 LocalSend 项目，遵循 Apache License 2.0。\nhttps://github.com/localsend/localsend\nhttps://github.com/Aloereed/localsend-ohos'))
      this.info(this.store.t('原生实现'), this.store.t('ArkUI 界面和 ArkTS 平台服务使用 HarmonyOS SDK。原项目第三方版权声明保留在仓库对应依赖中。'))
      this.info('Mbed TLS 3.6.7', 'Apache License 2.0\nhttps://github.com/Mbed-TLS/mbedtls')
      Button(this.store.t('阅读完整许可')).width('100%').height(48).backgroundColor(this.store.accentFill).onClick(() => this.route = 'license-full')
    } else if (this.route === 'changelog') {
      this.info('M20', this.store.t('接收后打开进度页；替换系统 TLS 接收实现；大文件批量写入；恢复原版下载目录授权与保存路径。'))
      this.info('M19', this.store.t('恢复原版 Logo 与图标；修复开关回弹；自动发现设备；提示自动关闭；发送类型单行滑动。'))
      this.info(this.store.t('原生迁移 · M2'), this.store.t('系统文件与照片选择、文件夹选择、文字和剪贴板、选择清单、重命名、历史与消息搜索、另存为、主题与接收设置。'))
      this.info(this.store.t('原生迁移 · M1'), this.store.t('四个原生页面、鸿蒙浅深色资源、本地偏好存储、可追溯的未签名里程碑构建。'))
    } else if (this.route === 'web') {
      WebShareView({ store: this.store })
    } else {
      Image($r('app.media.aloesend_logo')).width(104).height(104).objectFit(ImageFit.Contain).margin({ bottom: 24 })
      this.info('AloeSend', this.store.t('为鸿蒙重新设计的本地分享体验。\n跨越设备，传递心意。\n原生 ArkUI · 无需账号 · 不经云端'))
      Text($r('app.string.build_version')).fontSize(14).fontColor($r('sys.color.font_secondary')).margin({ bottom: 24 })
      this.info(this.store.t('感谢开源社区'), this.store.t('LocalSend 和所有贡献者，让跨平台分享成为可能。\n源码：github.com/Aloereed/localsend-ohos'))
      Button(this.store.t('贡献者与翻译者')).width('100%').height(48).backgroundColor(this.store.surfaceColor).fontColor(this.store.accentText).onClick(() => this.route = 'credits')
      Row({ space: 12 }) {
        Button(this.store.t('源代码')).layoutWeight(1).height(48).backgroundColor(this.store.accentFill).onClick(() => this.store.openUrl('https://github.com/Aloereed/localsend-ohos'))
        Button(this.store.t('报告问题')).layoutWeight(1).height(48).backgroundColor(this.store.accentFill).onClick(() => this.store.openUrl('https://github.com/Aloereed/localsend-ohos/issues'))
      }.width('100%').margin({ top: 16 })
    }
  }

  @Builder
  tabItem(title: string, mark: string, index: number) {
    Column({ space: 4 }) {
      AppIcon({ name: ['receive', 'send', 'message', 'settings'][index], iconSize: 25,
        tint: this.tab === index ? this.store.accentText : $r('sys.color.font_secondary') })
      Text(this.store.t(title)).fontSize(12).fontWeight(this.tab === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.tab === index ? this.store.accentText : $r('sys.color.font_secondary'))
    }.width('100%').height(this.windowWidth >= 840 ? 88 : 64).justifyContent(FlexAlign.Center).accessibilityText(this.store.t(title))
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
    if (!this.store.ready) {
      LoadingProgress().width(48).height(48).margin({ top: 120 })
    } else if (!this.store.privacyAccepted) {
      PrivacyView({ store: this.store, firstLaunch: true, accepting: this.acceptingPrivacy, onAccept: () => this.acceptPrivacy() })
    } else {
    Column() {
      if (this.store.networkPending && !this.store.pendingReceive) {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text(this.store.t('网络设置待生效')).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
            Text(this.store.t('当前连接继续使用原设置。空闲时重启即可应用新设置。')).fontSize(12).fontColor($r('sys.color.font_secondary'))
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Button(this.store.t('重新启动')).fontSize(13).backgroundColor(this.store.accentFill).enabled(!this.store.activeTransfers).onClick(() => localSend.restart())
        }.padding(16).width('100%').backgroundColor(this.store.controlSurface)
      }
      if (this.store.webRequests.length > 0 && this.route !== 'web') {
        Button(this.store.tf('{0} 个浏览器下载请求 · 点击查看', [String(this.store.webRequests.length)])).width('100%').height(48)
          .backgroundColor(this.store.accentFill).onClick(() => this.route = 'web')
      }
      if (this.store.incomingShare) {
        Button(this.store.t('内容已就绪 · 前往发送')).width('100%').height(48).backgroundColor(this.store.accentFill)
          .onClick(() => { this.store.incomingShare = false; this.route = ''; this.tab = 1; })
      }
      if (this.store.galleryQueue.length > 0 && !this.store.pendingReceive) {
        Row({ space: 8 }) {
          Button(this.store.tf('{0} 项照片和视频 · 保存到相册', [String(this.store.galleryQueue.length)]))
            .layoutWeight(1).height(48).backgroundColor(this.store.accentFill).enabled(!this.store.savingToGallery)
            .onClick(() => this.store.saveToGallery(this.store.galleryQueue))
          Button('×').width(44).height(44).fontColor(this.store.accentText).backgroundColor(Color.Transparent)
            .accessibilityText(this.store.t('稍后再说')).onClick(() => this.store.galleryQueue = [])
        }.padding({ left: 16, right: 16 }).width('100%')
      }
      if (this.store.pendingPin) {
        Column({ space: 12 }) {
          Text(this.store.t('请输入对方设备的接收 PIN')).fontSize(18).fontColor($r('sys.color.font_primary'))
          TextInput({ text: this.pinText, placeholder: 'PIN' }).type(InputType.Number).maxLength(12).onChange((value: string) => this.pinText = value)
          Row({ space: 12 }) {
            Button(this.store.t('取消')).onClick(() => localSend.submitPin(''))
            Button(this.store.t('确认')).backgroundColor(this.store.accentFill).onClick(() => { localSend.submitPin(this.pinText); this.pinText = ''; })
          }
        }.padding(24).width('100%')
      }
      if (this.store.pendingReceive) {
        ReceiveRequestView({ store: this.store }).layoutWeight(1)
      } else if (this.route === 'privacy') {
        Button(this.store.t('‹ 返回')).backgroundColor(Color.Transparent).fontColor(this.store.accentText)
          .alignSelf(ItemAlign.Start).onClick(() => this.route = '')
        PrivacyView({ store: this.store }).layoutWeight(1)
      } else if (this.route) {
        Row() {
          Button(this.store.t('‹ 返回')).backgroundColor(Color.Transparent).fontColor(this.store.accentText)
            .onClick(() => this.route = this.route === 'license-full' ? 'licenses' : this.route === 'credits' ? 'about' : '')
          Text(this.title()).fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).layoutWeight(1)
        }.width('100%').padding({ left: 8, right: 20, top: 10, bottom: 10 })
          .backgroundColor(this.store.glassColor).backgroundBlurStyle(this.store.settings.reduceEffects ? BlurStyle.NONE : BlurStyle.COMPONENT_THIN)
        Scroll() { Column() { this.details() }.padding(24).constraintSize({ maxWidth: 720 }).width('100%') }.layoutWeight(1).width('100%').align(Alignment.Top)
      } else {
        Tabs({ barPosition: this.windowWidth >= 840 ? BarPosition.Start : BarPosition.End, index: this.tab }) {
          TabContent() {
            Scroll() { Column() { this.receive() }.padding({ left: 24, right: 24, bottom: 28 }).constraintSize({ maxWidth: 720 }).width('100%') }.width('100%').height('100%').align(Alignment.Top)
          }.tabBar(this.tabItem('接收', '↓', 0))
          TabContent() {
            Scroll() {
              Column() {
                this.heading('发送', '选择内容，再选择设备')
                SendView({ store: this.store, onSend: (peer: Peer) => { localSend.send(peer); this.route = 'transfers'; },
                  onDiscover: () => { localSend.discover(); },
                  onAddress: (address: string) => { localSend.addAddress(address); }, onWebShare: () => this.route = 'web', onDetails: (peer: Peer) => { this.selectedPeer = peer; this.route = 'peer'; }, onSendMany: (peers: Peer[]) => { localSend.sendMany(peers); this.route = 'transfers'; } })
              }.padding({ left: 24, right: 24, bottom: 28 }).constraintSize({ maxWidth: 720 }).width('100%')
            }.width('100%').height('100%').align(Alignment.Top)
          }.tabBar(this.tabItem('发送', '↑', 1))
          TabContent() {
            MessagesView({ store: this.store, detailOpen: $messageDetail, onTransfers: () => this.route = 'transfers' })
          }.tabBar(this.tabItem('消息', '≋', 2))
          TabContent() {
            Scroll() { Column() { this.heading('设置', ''); SettingsView({ store: this.store, onNavigate: (route: string) => this.route = route }) }.padding({ left: 24, right: 24, bottom: 28 }).constraintSize({ maxWidth: 720 }).width('100%') }.width('100%').height('100%').align(Alignment.Top)
          }.tabBar(this.tabItem('设置', '⚙', 3))
        }.vertical(this.windowWidth >= 840).barWidth(this.windowWidth >= 840 ? 96 : '100%').barHeight(this.windowWidth >= 840 ? '100%' : 76)
          .barBackgroundColor(this.store.glassColor).barBackgroundBlurStyle(this.store.settings.reduceEffects ? BlurStyle.NONE : BlurStyle.COMPONENT_THIN)
          .animationDuration(this.store.settings.animations ? 280 : 0).onChange((index: number) => this.tab = index).layoutWeight(1)
      }
    }.width('100%').height('100%')
    }
    if (this.store.error || this.store.notice) {
      Row({ space: 12 }) {
        Text(this.store.error ? '!' : '✓').fontSize(18).fontWeight(FontWeight.Medium)
          .fontColor(this.store.error ? this.store.dangerText : this.store.accentText)
        Text(this.store.t(this.store.error || this.store.notice)).fontSize(14).lineHeight(21).layoutWeight(1).fontColor($r('sys.color.font_primary'))
        Button('×').width(40).height(40).fontSize(21).backgroundColor(Color.Transparent).fontColor($r('sys.color.font_secondary'))
          .accessibilityText(this.store.t('关闭')).onClick(() => { this.store.error = ''; this.store.notice = ''; })
      }.padding({ left: 20, right: 8, top: 8, bottom: 8 }).width('92%').constraintSize({ maxWidth: 560 })
        .backgroundColor(this.store.glassColor).backgroundBlurStyle(this.store.settings.reduceEffects ? BlurStyle.NONE : BlurStyle.COMPONENT_REGULAR)
        .borderRadius(24).border({ width: 0.5, color: this.store.hairlineColor })
        .shadow({ radius: this.store.settings.reduceEffects ? 0 : 20, color: this.store.dark ? '#40000000' : '#18314665', offsetY: 6 }).margin({ top: 12 })
    }
    }.linearGradient({ angle: 155, colors: [[this.store.ambientColor, 0], [this.store.canvasColor, 0.38], [this.store.canvasColor, 1]] })
      .width('100%').height('100%')
      .onAreaChange((oldArea: Area, newArea: Area) => this.windowWidth = Number(newArea.width))
      .bindSheet($$this.directoryVisible, this.directorySheet(), { height: SheetSize.LARGE, showClose: true, onDisappear: () => this.closeDirectory('') })
  }
}
