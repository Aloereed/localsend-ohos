import { common, wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';

// Serialize platform calls: a transfer may finish while start is still pending.
export class BackgroundKeeper {
  private desired: boolean = false;
  private active: boolean = false;
  private updating: boolean = false;
  private failed: boolean = false;

  async sync(needed: boolean, context: common.UIAbilityContext, log: (message: string) => void): Promise<void> {
    this.desired = needed;
    if (!needed) this.failed = false;
    if (this.updating || this.failed) return;
    this.updating = true;
    try {
      while (this.active !== this.desired) {
        if (this.desired) {
          const agent = await wantAgent.getWantAgent({ wants: [{ bundleName: 'com.aloereed.aloesend', abilityName: 'EntryAbility' }],
            actionType: wantAgent.OperationType.START_ABILITY, requestCode: 10,
            actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG] });
          await backgroundTaskManager.startBackgroundRunning(context, backgroundTaskManager.BackgroundMode.DATA_TRANSFER, agent);
          this.active = true;
          log('已申请系统后台传输任务');
        } else {
          await backgroundTaskManager.stopBackgroundRunning(context);
          this.active = false;
        }
      }
    } catch (e) {
      this.failed = true;
      log(`后台传输申请失败，请保持应用在前台：${(e as Error).message}`);
    } finally { this.updating = false; }
  }
}

export const backgroundKeeper: BackgroundKeeper = new BackgroundKeeper();
