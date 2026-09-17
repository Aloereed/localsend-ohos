import { AbilityConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { appStore } from '../model/AppStore';
import { receiveSystemShare, isIncomingWant } from '../platform/IncomingShare';
import { localSend } from '../network/LocalSendService';
import { webShare } from '../network/WebShareService';
import { ScreenKeeper } from '../platform/ScreenKeeper';

export default class EntryAbility extends UIAbility {
  private pendingWants: Want[] = [];
  private foreground: boolean = true;
  private screenKeeper: ScreenKeeper | undefined = undefined;
  private windowGeneration: number = 0;
  private mainWindow: window.Window | undefined = undefined;

  private syncSystemBars(): void {
    // The gesture indicator is a separate system bar; navigationBarColor does
    // not control it. Reapply after content load and returning from other apps.
    this.mainWindow?.setSpecificSystemBarEnabled('navigationIndicator', false)
      .catch((error: Error) => appStore.log(`设置手势条失败：${error.message}`));
    // Also paint the window behind the gesture area during layout transitions.
    // A transparent navigation bar alone can expose the system's default fill.
    try { this.mainWindow?.setWindowBackgroundColor(appStore.canvasColor); }
    catch (error) { appStore.log(`设置窗口背景失败：${(error as Error).message}`); }
    this.mainWindow?.setWindowSystemBarProperties({ statusBarColor: '#00000000', navigationBarColor: '#00000000',
      statusBarContentColor: appStore.dark ? '#FFFFFF' : '#182431',
      navigationBarContentColor: appStore.dark ? '#FFFFFF' : '#182431'
    }).catch((error: Error) => appStore.log(`设置系统栏失败：${error.message}`));
  }

  private syncSafeArea(): void {
    if (!this.mainWindow) return;
    try {
      const system = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const cutout = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      const navigation = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      appStore.safeTopPx = Math.max(system.topRect.height, cutout.topRect.height);
      appStore.safeBottomPx = Math.max(system.bottomRect.height, navigation.bottomRect.height, cutout.bottomRect.height);
    } catch (error) { appStore.log(`读取系统栏避让区域失败：${(error as Error).message}`); }
  }
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    appStore.onTransferActivity = (active: boolean) => { this.screenKeeper?.sync(active && this.foreground); };
    appStore.onPrivacyAccepted = async () => {
      const pending = this.pendingWants; this.pendingWants = [];
      for (const item of pending) await receiveSystemShare(item, appStore);
    };
    this.importWant(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.importWant(want);
  }

  private async importWant(want: Want): Promise<void> {
    await appStore.init(this.context);
    if (!appStore.ready || !appStore.privacyAccepted) {
      if (isIncomingWant(want)) this.pendingWants.push(want);
      return;
    }
    await receiveSystemShare(want, appStore);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    const generation = ++this.windowGeneration;
    windowStage.getMainWindow().then(async (mainWindow: window.Window) => {
      if (generation !== this.windowGeneration) return;
      this.mainWindow = mainWindow;
      appStore.onThemeChanged = () => this.syncSystemBars();
      await mainWindow.setWindowLayoutFullScreen(true);
      if (generation !== this.windowGeneration) return;
      this.syncSystemBars(); this.syncSafeArea();
      mainWindow.on('avoidAreaChange', () => this.syncSafeArea());
      this.screenKeeper = new ScreenKeeper((enabled: boolean) => mainWindow.setWindowKeepScreenOn(enabled), (message: string) => appStore.log(message));
      this.screenKeeper.sync(this.foreground && appStore.transfers.some((item) => item.status === 'transferring'));
    }).catch((error: Error) => appStore.log(`读取主窗口失败：${error.message}`));
    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) appStore.log(`加载主界面失败：${error.message}`);
      else if (generation === this.windowGeneration) { this.syncSystemBars(); this.syncSafeArea(); }
    });
  }

  onForeground(): void {
    this.foreground = true;
    this.syncSystemBars(); this.syncSafeArea();
    this.screenKeeper?.sync(appStore.transfers.some((item) => item.status === 'transferring'));
    appStore.log('应用已回到前台');
    appStore.init(this.context).then(async (): Promise<void> => { if (appStore.ready && appStore.privacyAccepted) await localSend.discover(false, true); }).catch((error: Error) => appStore.log(error.message));
  }
  onConfigurationUpdate(configuration: Configuration): void { appStore.refreshSystemTheme(); }
  onBackground(): void {
    this.foreground = false; this.screenKeeper?.sync(false);
    appStore.log('应用进入后台；长时任务申请结果请查看传输日志');
  }
  onWindowStageDestroy(): void {
    this.windowGeneration++; this.screenKeeper?.sync(false); this.screenKeeper = undefined;
    this.mainWindow?.off('avoidAreaChange'); this.mainWindow = undefined; appStore.onThemeChanged = () => {};
  }
  onDestroy(): void { this.foreground = false; this.windowGeneration++; this.screenKeeper?.sync(false); webShare.stop(); localSend.stop(); }
}
