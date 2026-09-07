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
import { DiagnosticsView } from '../components/DiagnosticsView';
import { FloatingNavigation } from '../components/FloatingNavigation';
import { PinRequestView } from '../components/PinRequestView';
import { deviceInfo } from '@kit.BasicServicesKit';
import { HdsTabs, HdsTabsController, SystemMaterialParams } from '@kit.UIDesignKit';

@Entry
@Component
struct Index {
  @State store: AppStore = appStore;
  @State tab: number = 0;
  @State route: string = '';
  @State selectedPeer: Peer = new Peer();
  @State windowWidth: number = 400;
  @State messageDetail: boolean = false;
  @State legalText: string = '';
  @State creditsText: string = '';
  @State directoryVisible: boolean = false;
  @State directoryInitial: string = '';
  @State directoryPurpose: string = 'save';
  @State acceptingPrivacy: boolean = false;
  @State systemFloatingTabs: boolean = false;
  private directoryResolver: ((path: string) => void) | undefined = undefined;
  private tabsController: TabsController = new TabsController();
  private systemTabsController: HdsTabsController | undefined = undefined;

  async aboutToAppear(): Promise<void> {
    await this.initializePage();
  }

  async initializePage(): Promise<void> {
    if (deviceInfo.sdkApiVersion >= 23 && canIUse('SystemCapability.UIDesign.HDSComponent.Core')) {
      this.systemTabsController = new HdsTabsController(); this.systemFloatingTabs = true;
    }
    await this.store.init(this.getUIContext().getHostContext() as common.UIAbilityContext);
    if (!this.store.ready) return;
    this.store.onReceiveStarted = () => { this.route = 'transfers'; };
    this.store.onPickDownloadDirectory = (path: string, purpose: string) => new Promise<string>((resolve) => {
      this.directoryResolver?.(''); this.directoryResolver = resolve;
      this.directoryInitial = path; this.directoryPurpose = purpose; this.directoryVisible = true;
    });
    this.store.onTransferCompleted = (transfer: TransferView) => {
      if (transfer.direction === 'receive' && transfer.peerInfo && this.store.settings.openMessagesOnReceive) {
        if (this.route === 'transfers') localSend.finishCompletedSelections();
        this.store.messageTarget = transfer.peerInfo; this.selectTab(2); this.route = '';
      }
      if (!this.store.settings.autoFinish) return;
      setTimeout(() => {
        if (this.route === 'transfers' && this.store.batchRemaining === 0 &&
          !this.store.transfers.some((item) => item.status === 'waiting' || item.status === 'transferring')) {
          localSend.finishCompletedSelections(); this.route = '';
        }
      }, 1200);
    };
    if (this.store.privacyAccepted) await this.startServices();
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.resourceManager.getRawFileContent('LICENSE.txt').then((bytes: Uint8Array) => this.legalText = new util.TextDecoder().decodeToString(bytes)).catch(() => {});
    context.resourceManager.getRawFileContent('CREDITS.txt').then((bytes: Uint8Array) => this.creditsText = new util.TextDecoder().decodeToString(bytes)).catch(() => {});
  }

  async startServices(): Promise<void> {
    if (!this.store.ready || !this.store.privacyAccepted) return;
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
    if (this.store.pendingPin) { localSend.cancel(this.store.pendingPin); return true; }
    if (this.route) {
      if (this.route === 'transfers') localSend.finishCompletedSelections();
      this.route = this.route === 'license-full' ? 'licenses' : this.route === 'credits' ? 'about' : ''; return true;
    }
    if (this.tab === 2 && this.messageDetail) { this.messageDetail = false; return true; }
    if (this.tab !== 0) { this.selectTab(0); return true; }
    return false;
  }

  closeDirectory(path: string): void {
    const resolve = this.directoryResolver; this.directoryResolver = undefined;
    this.directoryVisible = false; resolve?.(path);
  }

  selectTab(index: number): void {
    this.tab = index;
    if (this.systemFloatingTabs) this.systemTabsController?.changeIndex(index);
    else this.tabsController.changeIndex(index);
  }

  systemMaterial(): SystemMaterialParams {
    // MaterialType.ADAPTIVE (100), MaterialLevel.ADAPTIVE (10). Keep the new
    // hdsMaterial runtime module out of API 22 startup; HdsTabs itself is API 20.
    return { materialType: this.store.settings.reduceEffects ? 0 : 100, materialLevel: 10 };
  }

  @Builder
  directorySheet() {
    DownloadDirectoryPicker({ store: this.store, initialPath: this.directoryInitial, purpose: this.directoryPurpose, onChoose: (path: string) => this.closeDirectory(path) })
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
  info(title: string, description: string, source: string = '') {
    Column({ space: 10 }) {
      Text(this.store.t(title)).fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
      Text(this.store.t(source === 'license' ? this.legalText || '正在读取…' : source === 'credits' ? this.creditsText || '正在读取…' : description))
        .fontSize(14).lineHeight(24).fontColor($r('sys.color.font_secondary')).copyOption(CopyOptions.LocalDevice)
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
        Image($r('app.media.aloesend_logo')).width(112).height(112).objectFit(ImageFit.Contain).accessibilityLevel('no')
      }.width(208).height(208).borderRadius(104).clip(true).margin({ top: 4, bottom: 6 })
      Text(this.store.settings.alias).fontSize(28).fontWeight(FontWeight.Medium).maxLines(2).textAlign(TextAlign.Center).fontColor($r('sys.color.font_primary'))
      Row({ space: 7 }) {
        Circle().width(6).height(6).fill(this.store.serverStatus.startsWith('已就绪') ? this.store.accentText : '#B88632')
        Text(this.store.settings.visible ? this.store.t(this.store.serverStatus) : this.store.t('当前已隐藏，可通过地址连接')).fontSize(13).fontColor($r('sys.color.font_secondary'))
      }.padding({ left: 14, right: 14, top: 8, bottom: 8 }).backgroundColor(this.store.glassColor).borderRadius(20)
      ForEach(this.store.localIps, (ip: string) => {
        Text(`${ip}:${this.store.listenerPort}`).direction(Direction.Ltr).fontSize(13).fontColor($r('sys.color.font_secondary')).copyOption(CopyOptions.LocalDevice)
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
      AppIcon({ name: 'forward', rtl: this.store.rtl, iconSize: 22, tint: $r('sys.color.font_secondary') })
    }.width('100%').padding({ left: 22, right: 20, top: 20, bottom: 20 })
      .onClick(() => { if (route === 'settings') this.selectTab(3); else this.route = route; })
      .accessibilityText(this.store.t(title))
  }

  @Builder
  backButton() {
    Button() {
      Row({ space: 6 }) {
        AppIcon({ name: 'back', rtl: this.store.rtl, iconSize: 22, tint: this.store.accentText })
        Text(this.store.t('返回')).fontSize(16).fontColor(this.store.accentText)
      }.padding({ left: 8, right: 8 })
    }.constraintSize({ minWidth: 48, minHeight: 48 }).backgroundColor(Color.Transparent)
      .accessibilityText(this.store.t('返回'))
      .onClick(() => this.onBackPress())
  }

  @Builder
  details() {
    if (this.route === 'license-full') {
      this.info('Apache License 2.0', '', 'license')
    } else if (this.route === 'credits') {
      this.info('感谢每一位贡献者', '', 'credits')
    } else if (this.route === 'donate') {
      this.info('支持开源项目', '你可以自愿支持 LocalSend 的持续开发。所有文件分享功能均可免费使用。')
      Button('GitHub Sponsors').width('100%').height(48).backgroundColor(this.store.accentFill).onClick(() => this.store.openUrl('https://github.com/sponsors/Tienisto'))
      Button('Ko-fi').width('100%').height(48).margin({ top: 16 }).fontColor(this.store.accentText).backgroundColor(this.store.surfaceColor).onClick(() => this.store.openUrl('https://ko-fi.com/tienisto'))
    } else if (this.route === 'network') { NetworkView({ store: this.store }) }
    else if (this.route === 'peer') { PeerDetailView({ store: this.store, peer: this.selectedPeer,
      onUpdate: (peer: Peer) => this.selectedPeer = peer,
      onSend: () => { localSend.send(this.selectedPeer); this.route = 'transfers'; },
      onMessage: () => { this.store.messageTarget = this.selectedPeer; this.route = ''; this.selectTab(2); } }) }
    else if (this.route === 'transfers') { TransferList({ store: this.store }) }
    else if (this.route === 'history') { LibraryView({ store: this.store, messagesOnly: false }) }
    else if (this.route === 'diagnostics') {
      DiagnosticsView({ store: this.store })
    } else if (this.route === 'help') {
      this.info('找不到设备？', '确认两台设备连接同一个局域网，关闭路由器的 AP 隔离。允许 LocalSend 通过防火墙，确保 TCP 与 UDP 53317 端口可用。也可通过地址直接添加设备。')
      this.info('接收的文件在哪里？', '允许下载目录授权后，默认保存到 Download/com.aloereed.aloesend。未授权时保存在应用内，可从接收历史另存为。')
      this.info('文字与文件', '发送页可以选择文件、图片、文件夹，以及文字或剪贴板内容。选择后点击目标设备。文件重命名只影响对方收到的名称。')
      this.info('目录暂时不可用', '下载目录不能写入时，本次接收会改用应用内目录并提示你。请在接收历史的文件详情中查看实际位置，需要时选择另存为。')
      this.info('传输与后台', '前台传输会保持亮屏，结束后恢复正常熄屏。进入后台后会申请系统长时任务；申请结果可在连接诊断查看。')
      this.info('排查连接问题', '在设置的连接诊断中查看本机地址、服务状态和发现日志，可搜索并复制诊断信息。修改端口、组播或加密选项后，空闲时重启服务即可生效。')
      Button(this.store.t('连接诊断')).width('100%').height(48).fontColor(this.store.accentText).backgroundColor(this.store.controlSurface).onClick(() => this.route = 'diagnostics')
    } else if (this.route === 'licenses') {
      this.info('LocalSend / AloeSend', '基于 LocalSend 项目，遵循 Apache License 2.0。\nhttps://github.com/localsend/localsend\nhttps://github.com/Aloereed/localsend-ohos')
      this.info('原生实现', 'ArkUI 界面和 ArkTS 平台服务使用 HarmonyOS SDK。原项目第三方版权声明保留在仓库对应依赖中。')
      this.info('Mbed TLS 3.6.7', 'Apache License 2.0\nhttps://github.com/Mbed-TLS/mbedtls')
      Button(this.store.t('阅读完整许可')).width('100%').height(48).backgroundColor(this.store.accentFill).onClick(() => this.route = 'license-full')
    } else if (this.route === 'changelog') {
      Text($r('app.string.build_version')).fontSize(15).fontColor($r('sys.color.font_secondary')).width('100%').margin({ bottom: 20 })
      this.info('接收与保存', '改进大文件接收、进度更新和断开后的错误反馈。修复下载目录重复创建问题；目录不可用时改用应用内保存，并显示实际位置。')
      this.info('外观与操作', '保留原版图标，采用鸿蒙原生导航与分层材质。修复开关、选择器和动态文字更新，新增轻量效果与纯黑背景，发送类型支持单行滑动。')
      this.info('消息与分享', '支持会话搜索、附件、收藏设备发起会话和新消息提示。文件详情可打开、另存、分享或查看所在目录；浏览器分享支持放大二维码与大字链接。')
      this.info('首次使用与排查', '恢复首次隐私说明，完善下载目录授权、传输亮屏、连接日志、证书管理和默认设置恢复。')
    } else if (this.route === 'web') {
      WebShareView({ store: this.store })
    } else {
      Image($r('app.media.aloesend_logo')).width(104).height(104).objectFit(ImageFit.Contain).margin({ bottom: 24 })
      this.info('AloeSend', '为鸿蒙重新设计的本地分享体验。\n跨越设备，传递心意。\n原生 ArkUI · 无需账号 · 不经云端')
      Text($r('app.string.build_version')).fontSize(14).fontColor($r('sys.color.font_secondary')).margin({ bottom: 24 })
      this.info('感谢开源社区', 'LocalSend 和所有贡献者，让跨平台分享成为可能。\n源码：github.com/Aloereed/localsend-ohos')
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
    }.width('100%').height(64).justifyContent(FlexAlign.Center).accessibilityText(this.store.t(title))
      .accessibilitySelected(this.tab === index).onClick(() => this.selectTab(index))
  }

  @Builder
  tabPages() {
    TabContent() {
      Scroll() { Column() { this.receive() }.padding({ left: 24, right: 24, bottom: 116 }).constraintSize({ maxWidth: 720 }).width('100%') }.width('100%').height('100%').align(Alignment.Top)
    }.tabBar(this.tabItem('接收', '↓', 0))
    TabContent() {
      Scroll() {
        Column() {
          this.heading('发送', '选择内容，再选择设备')
          SendView({ store: this.store, onSend: (peer: Peer) => { localSend.send(peer); this.route = 'transfers'; },
            onDiscover: () => { localSend.discover(); },
            onAddress: (address: string) => { localSend.addAddress(address); }, onWebShare: () => this.route = 'web', onDetails: (peer: Peer) => { this.selectedPeer = peer; this.route = 'peer'; }, onSendMany: (peers: Peer[]) => { localSend.sendMany(peers); this.route = 'transfers'; } })
        }.padding({ left: 24, right: 24, bottom: 116 }).constraintSize({ maxWidth: 720 }).width('100%')
      }.width('100%').height('100%').align(Alignment.Top)
    }.tabBar(this.tabItem('发送', '↑', 1))
    TabContent() {
      MessagesView({ store: this.store, detailOpen: $messageDetail, onTransfers: () => this.route = 'transfers' }).padding({ bottom: this.messageDetail ? 0 : 104 })
    }.tabBar(this.tabItem('消息', '≋', 2))
    TabContent() {
      Scroll() { Column() { this.heading('设置', ''); SettingsView({ store: this.store, onNavigate: (route: string) => this.route = route }) }.padding({ left: 24, right: 24, bottom: 116 }).constraintSize({ maxWidth: 720 }).width('100%') }.width('100%').height('100%').align(Alignment.Top)
    }.tabBar(this.tabItem('设置', '⚙', 3))
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
    if (!this.store.ready) {
      if (this.store.initializationError) {
        Column({ space: 18 }) {
          Text(this.store.t('暂时无法读取应用数据')).fontSize(22).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
          Text(this.store.t('重试不会删除设置或收到的文件。')).fontSize(15).fontColor($r('sys.color.font_secondary'))
          Text(this.store.initializationError).fontSize(12).fontColor($r('sys.color.font_secondary')).copyOption(CopyOptions.LocalDevice)
          Button(this.store.t('重新读取')).height(48).backgroundColor(this.store.accentFill).onClick(() => this.initializePage())
        }.padding(28).constraintSize({ maxWidth: 520 }).margin({ top: 100 })
      } else {
        LoadingProgress().width(48).height(48).margin({ top: 120 })
      }
    } else if (!this.store.privacyAccepted) {
      PrivacyView({ store: this.store, firstLaunch: true, accepting: this.acceptingPrivacy, onAccept: () => this.acceptPrivacy() })
    } else {
    Column() {
      if (this.store.selecting) {
        Row({ space: 12 }) {
          LoadingProgress().width(24).height(24)
          Text(this.store.selectionCancelled ? this.store.t('正在停止读取…') : this.store.tf('正在读取内容 · {0} 个文件', [String(this.store.selectionReadCount)]))
            .fontSize(14).fontColor($r('sys.color.font_primary')).layoutWeight(1)
          Button(this.store.t('取消')).height(44).fontColor(this.store.accentText).backgroundColor(Color.Transparent)
            .enabled(!this.store.selectionCancelled).onClick(() => this.store.cancelSelection())
        }.width('100%').padding(12).backgroundColor(this.store.controlSurface)
      }
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
          .onClick(() => { this.store.incomingShare = false; this.route = ''; this.selectTab(1); })
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
        PinRequestView({ store: this.store })
      }
      if (this.store.pendingReceive) {
        ReceiveRequestView({ store: this.store }).layoutWeight(1)
      } else if (this.route === 'privacy') {
        Row() { this.backButton() }.width('100%')
        PrivacyView({ store: this.store }).layoutWeight(1)
      } else if (this.route) {
        Row() {
          this.backButton()
          Text(this.title()).fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).layoutWeight(1)
        }.width('100%').padding({ left: 8, right: 20, top: 10, bottom: 10 })
          .backgroundColor(this.store.glassColor).backgroundBlurStyle(this.store.settings.reduceEffects ? BlurStyle.NONE : BlurStyle.COMPONENT_THIN)
        Scroll() { Column() { this.details() }.padding(24).constraintSize({ maxWidth: 720 }).width('100%') }.layoutWeight(1).width('100%').align(Alignment.Top)
      } else {
        Stack({ alignContent: Alignment.Bottom }) {
        if (this.systemFloatingTabs) {
          HdsTabs({ barPosition: BarPosition.End, index: this.tab, controller: this.systemTabsController }) {
            this.tabPages()
          }.barOverlap(true).vertical(false).barMode(BarMode.Fixed)
            .barFloatingStyle({ barWidth: { smallWidth: '92%', mediumWidth: 420, largeWidth: 520 },
              barSideMargin: 16, barBottomMargin: 16, systemMaterialEffect: this.systemMaterial(), thermoCtrl: true })
            .barHeight(this.tab === 2 && this.messageDetail ? 0 : 74).width('100%').height('100%')
            .animationDuration(this.store.settings.animations ? 280 : 0).onChange((index: number) => this.tab = index)
        } else {
        Tabs({ barPosition: BarPosition.End, index: this.tab, controller: this.tabsController }) {
          this.tabPages()
        }.barHeight(0).width('100%').height('100%')
          .animationDuration(this.store.settings.animations ? 280 : 0).onChange((index: number) => this.tab = index)
        if (this.tab !== 2 || !this.messageDetail) {
          FloatingNavigation({ store: this.store, selected: this.tab, onSelect: (index: number) => this.selectTab(index) })
            .width('92%').constraintSize({ maxWidth: 520 }).margin({ bottom: 16 })
        }
        }
        }.layoutWeight(1).width('100%')
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
      .direction(this.store.rtl ? Direction.Rtl : Direction.Ltr)
      .width('100%').height('100%')
      .onAreaChange((oldArea: Area, newArea: Area) => this.windowWidth = Number(newArea.width))
      .bindSheet($$this.directoryVisible, this.directorySheet(), { height: SheetSize.LARGE, showClose: true, keyboardAvoidMode: SheetKeyboardAvoidMode.RESIZE_ONLY, onDisappear: () => this.closeDirectory('') })
  }
}
