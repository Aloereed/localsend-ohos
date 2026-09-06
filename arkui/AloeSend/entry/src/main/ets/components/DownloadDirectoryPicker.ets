import { fileIo as fs } from '@kit.CoreFileKit';
import { AppStore } from '../model/AppStore';
import { AppIcon } from './AppIcon';

@Component
export struct DownloadDirectoryPicker {
  @ObjectLink store: AppStore;
  @Prop initialPath: string = '';
  @State path: string = '';
  @State folders: string[] = [];
  @State loading: boolean = false;
  @State error: string = '';
  @State limit: number = 50;
  onChoose: (path: string) => void = () => {};
  private generation: number = 0;

  aboutToAppear(): void { this.load(this.initialPath || this.store.downloadDirectory); }
  aboutToDisappear(): void { this.generation++; }

  async load(path: string): Promise<void> {
    const root = this.store.downloadDirectory;
    if (path !== root && !path.startsWith(`${root}/`)) return;
    if (path.split('/').some((part: string) => part === '..' || part === '.')) return;
    const generation = ++this.generation;
    this.path = path; this.loading = true; this.error = ''; this.folders = []; this.limit = 50;
    try {
      const names = await fs.listFile(path);
      const folders: string[] = [];
      for (const name of names) {
        if (name.startsWith('.') || name.includes('/')) continue;
        if ((await fs.stat(`${path}/${name}`)).isDirectory()) folders.push(name);
        if (generation !== this.generation) return;
      }
      if (generation === this.generation) this.folders = folders.sort();
    } catch (error) { if (generation === this.generation) this.error = (error as Error).message; }
    finally { if (generation === this.generation) this.loading = false; }
  }

  build() {
    Column({ space: 16 }) {
      Text(this.store.t('选择保存目录')).fontSize(23).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).width('100%')
      Text(this.path === this.store.downloadDirectory ? 'Download/com.aloereed.aloesend' : this.path.slice(this.store.downloadDirectory.length + 1))
        .fontSize(14).maxLines(3).fontColor($r('sys.color.font_secondary')).width('100%')
      if (this.path !== this.store.downloadDirectory) {
        Button(this.store.t('上一级')).backgroundColor(Color.Transparent).fontColor(this.store.accentText)
          .onClick(() => this.load(this.path.slice(0, this.path.lastIndexOf('/'))))
      }
      Scroll() {
        Column({ space: 10 }) {
          if (this.loading) { LoadingProgress().width(36).height(36) }
          if (this.error) { Text(this.error).fontColor(this.store.dangerText).fontSize(14) }
          if (!this.loading && !this.error && this.folders.length === 0) {
            Text(this.store.t('没有子文件夹')).fontColor($r('sys.color.font_secondary')).fontSize(15).padding(24)
          }
          ForEach(this.folders.slice(0, this.limit), (name: string) => {
            Row({ space: 14 }) {
              AppIcon({ name: 'folder', iconSize: 26, tint: this.store.accentText })
              Text(name).fontSize(16).maxLines(2).fontColor($r('sys.color.font_primary')).layoutWeight(1)
              Text('›').fontSize(24).fontColor($r('sys.color.font_secondary'))
            }.width('100%').padding(18).backgroundColor(this.store.controlSurface).borderRadius(18)
              .onClick(() => this.load(`${this.path}/${name}`)).accessibilityText(name)
          }, (name: string) => `${this.path}/${name}`)
          if (this.folders.length > this.limit) {
            Button(this.store.t('显示更多')).backgroundColor(Color.Transparent).fontColor(this.store.accentText).onClick(() => this.limit += 50)
          }
        }.width('100%')
      }.width('100%').layoutWeight(1).align(Alignment.Top)
      Button(this.store.t('选择此文件夹')).height(50).width('100%').backgroundColor(this.store.accentFill)
        .enabled(!this.loading && !this.error).onClick(() => this.onChoose(this.path))
    }.padding(24).width('100%').height('100%')
  }
}
