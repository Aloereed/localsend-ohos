import { AbilityConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { appStore } from '../model/AppStore';
import { receiveSystemShare } from '../platform/IncomingShare';
import { localSend } from '../network/LocalSendService';
import { webShare } from '../network/WebShareService';

export default class EntryAbility extends UIAbility {
  private pendingWants: Want[] = [];
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
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
    if (!appStore.privacyAccepted) {
      if (want.action === 'ohos.want.action.sendData' || want.action === 'ohos.want.action.viewData') this.pendingWants.push(want);
      return;
    }
    await receiveSystemShare(want, appStore);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) appStore.log(`加载主界面失败：${error.message}`);
    });
  }

  onForeground(): void {
    appStore.log('应用已回到前台');
    appStore.init(this.context).then(async (): Promise<void> => { if (appStore.privacyAccepted) await localSend.discover(false); }).catch((error: Error) => appStore.log(error.message));
  }
  onConfigurationUpdate(configuration: Configuration): void { appStore.refreshSystemTheme(); }
  onBackground(): void { appStore.log('应用进入后台；长时任务申请结果请查看传输日志'); }
  onDestroy(): void { webShare.stop(); localSend.stop(); }
}
