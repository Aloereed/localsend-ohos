import { AbilityConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { appStore } from '../model/AppStore';
import { receiveSystemShare } from '../platform/IncomingShare';
import { localSend } from '../network/LocalSendService';
import { webShare } from '../network/WebShareService';
import { ScreenKeeper } from '../platform/ScreenKeeper';

export default class EntryAbility extends UIAbility {
  private pendingWants: Want[] = [];
  private foreground: boolean = true;
  private screenKeeper: ScreenKeeper | undefined = undefined;
  private windowGeneration: number = 0;
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
      if (want.action === 'ohos.want.action.sendData' || want.action === 'ohos.want.action.viewData') this.pendingWants.push(want);
      return;
    }
    await receiveSystemShare(want, appStore);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    const generation = ++this.windowGeneration;
    windowStage.getMainWindow().then((mainWindow: window.Window) => {
      if (generation !== this.windowGeneration) return;
      this.screenKeeper = new ScreenKeeper((enabled: boolean) => mainWindow.setWindowKeepScreenOn(enabled), (message: string) => appStore.log(message));
      this.screenKeeper.sync(this.foreground && appStore.transfers.some((item) => item.status === 'transferring'));
    }).catch((error: Error) => appStore.log(`读取主窗口失败：${error.message}`));
    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) appStore.log(`加载主界面失败：${error.message}`);
    });
  }

  onForeground(): void {
    this.foreground = true;
    this.screenKeeper?.sync(appStore.transfers.some((item) => item.status === 'transferring'));
    appStore.log('应用已回到前台');
    appStore.init(this.context).then(async (): Promise<void> => { if (appStore.ready && appStore.privacyAccepted) await localSend.discover(false); }).catch((error: Error) => appStore.log(error.message));
  }
  onConfigurationUpdate(configuration: Configuration): void { appStore.refreshSystemTheme(); }
  onBackground(): void {
    this.foreground = false; this.screenKeeper?.sync(false);
    appStore.log('应用进入后台；长时任务申请结果请查看传输日志');
  }
  onWindowStageDestroy(): void { this.windowGeneration++; this.screenKeeper?.sync(false); this.screenKeeper = undefined; }
  onDestroy(): void { this.foreground = false; this.windowGeneration++; this.screenKeeper?.sync(false); webShare.stop(); localSend.stop(); }
}
