// Keep the final window state correct when a transfer ends during an async call.
export class ScreenKeeper {
  private desired: boolean = false;
  private applied: boolean = false;
  private pending: Promise<void> = Promise.resolve();

  private apply: (enabled: boolean) => Promise<void>;
  private log: (message: string) => void;
  constructor(apply: (enabled: boolean) => Promise<void>, log: (message: string) => void) {
    this.apply = apply; this.log = log;
  }

  sync(enabled: boolean): Promise<void> {
    this.desired = enabled;
    this.pending = this.pending.then(async () => {
      try {
        while (this.applied !== this.desired) {
          const target = this.desired;
          await this.apply(target);
          this.applied = target;
        }
      } catch (error) { this.log(`保持亮屏设置失败：${(error as Error).message}`); }
    });
    return this.pending;
  }
}
