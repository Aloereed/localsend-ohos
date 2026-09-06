import { AbilityConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { appStore } from '../model/AppStore';
import { receiveSystemShare } from '../platform/IncomingShare';
import { localSend } from '../network/LocalSendService';
import { webShare } from '../network/WebShareService';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.importWant(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.importWant(want);
  }

  private async importWant(want: Want): Promise<void> {
    await appStore.init(this.context);
    await receiveSystemShare(want, appStore);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) appStore.log(`加载主界面失败：${error.message}`);
    });
  }

  onForeground(): void {
    appStore.log('应用已回到前台');
    appStore.init(this.context).then(() => localSend.discover(false)).catch((error: Error) => appStore.log(error.message));
  }
  onConfigurationUpdate(configuration: Configuration): void { appStore.refreshSystemTheme(); }
  onBackground(): void { appStore.log('应用进入后台，活跃传输由系统长时任务保护'); }
  onDestroy(): void { webShare.stop(); localSend.stop(); }
}
