import { downloadSubfolders, insideDownloadFolder } from '../platform/DownloadFolders';
import { AppStore } from '../model/AppStore';
import { AppIcon } from './AppIcon';

@Component
export struct DownloadDirectoryPicker {
  @ObjectLink store: AppStore;
  @Prop initialPath: string = '';
  @Prop purpose: string = 'save';
  @State path: string = '';
  @State folders: string[] = [];
  @State loading: boolean = false;
  @State error: string = '';
  @State limit: number = 50;
  @State query: string = '';
  onChoose: (path: string) => void = () => {};
  private generation: number = 0;
  private folderScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const root = this.store.downloadDirectory;
    this.load(insideDownloadFolder(root, this.initialPath) ? this.initialPath : root);
  }
  aboutToDisappear(): void { this.generation++; }

  matchingFolders(): string[] {
    const query = this.query.trim().toLocaleLowerCase();
    return query ? this.folders.filter((name: string) => name.toLocaleLowerCase().includes(query)) : this.folders;
  }

  async load(path: string): Promise<void> {
    const root = this.store.downloadDirectory;
    if (!insideDownloadFolder(root, path)) return;
    const generation = ++this.generation;
    this.path = path; this.loading = true; this.error = ''; this.folders = []; this.limit = 50; this.query = '';
    try {
      const folders = await downloadSubfolders(root, path);
      if (generation === this.generation) {
        this.folders = folders;
        this.folderScroller.scrollTo({ xOffset: 0, yOffset: 0 });
      }
    } catch (error) { if (generation === this.generation) this.error = (error as Error).message; }
    finally { if (generation === this.generation) this.loading = false; }
  }

  build() {
    Column({ space: 16 }) {
      Text(this.store.t(this.purpose === 'send' ? '选择要发送的文件夹' : '选择保存目录')).fontSize(23).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).width('100%')
      Text(this.path === this.store.downloadDirectory ? 'Download/com.aloereed.aloesend' : this.path.slice(this.store.downloadDirectory.length + 1))
        .direction(Direction.Ltr).fontSize(14).maxLines(3).fontColor($r('sys.color.font_secondary')).width('100%')
      if (this.path !== this.store.downloadDirectory) {
        Button(this.store.t('上一级')).backgroundColor(Color.Transparent).fontColor(this.store.accentText)
          .onClick(() => this.load(this.path.slice(0, this.path.lastIndexOf('/'))))
      }
      Search({ value: this.query, placeholder: this.store.t('搜索当前目录的文件夹') })
        .width('100%').enabled(!this.loading && !this.error)
        .onChange((value: string) => {
          this.query = value; this.limit = 50;
          this.folderScroller.scrollTo({ xOffset: 0, yOffset: 0 });
        })
        .accessibilityText(this.store.t('搜索当前目录的文件夹'))
      Scroll(this.folderScroller) {
        Column({ space: 10 }) {
          if (this.loading) { LoadingProgress().width(36).height(36) }
          if (this.error) {
            Text(this.store.t(this.error)).fontColor(this.store.dangerText).fontSize(14)
            Button(this.store.t('重新读取')).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText).onClick(() => this.load(this.path))
          }
          if (!this.loading && !this.error && this.matchingFolders().length === 0) {
            Text(this.store.t(this.query.trim() ? '没有匹配的文件夹' : '没有子文件夹')).fontColor($r('sys.color.font_secondary')).fontSize(15).padding(24)
          }
          ForEach(this.matchingFolders().slice(0, this.limit), (name: string) => {
            Row({ space: 14 }) {
              AppIcon({ name: 'folder', iconSize: 26, tint: this.store.accentText })
              Text(name).fontSize(16).maxLines(2).fontColor($r('sys.color.font_primary')).layoutWeight(1)
              AppIcon({ name: 'forward', rtl: this.store.rtl, iconSize: 22, tint: $r('sys.color.font_secondary') })
            }.width('100%').padding(18).backgroundColor(this.store.controlSurface).borderRadius(18)
              .onClick(() => this.load(`${this.path}/${name}`)).accessibilityText(name)
          }, (name: string) => `${this.path}/${name}`)
          if (this.matchingFolders().length > this.limit) {
            Button(this.store.t('显示更多')).backgroundColor(Color.Transparent).fontColor(this.store.accentText).onClick(() => this.limit += 50)
          }
        }.width('100%')
      }.width('100%').layoutWeight(1).align(Alignment.Top)
      Button(this.store.t(this.purpose === 'send' ? '添加此文件夹' : '选择此文件夹')).height(50).width('100%').backgroundColor(this.store.accentFill)
        .enabled(!this.loading && !this.error).onClick(() => this.onChoose(this.path))
    }.padding(24).width('100%').direction(this.store.rtl ? Direction.Rtl : Direction.Ltr).height('100%')
  }
}
