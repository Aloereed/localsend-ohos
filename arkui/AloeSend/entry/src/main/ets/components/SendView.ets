import { AppStore, ShareFile, Peer, formatSize } from '../model/AppStore';
import { AppIcon } from './AppIcon';
import { EmptyState } from './EmptyState';

@Component
export struct SendView {
  @ObjectLink store: AppStore;
  onSend: (peer: Peer) => void = () => {};
  onDiscover: () => void = () => {};
  onAddress: (address: string) => void = () => {};
  onWebShare: () => void = () => {};
  onDetails: (peer: Peer) => void = () => {};
  onSendMany: (peers: Peer[]) => void = () => {};
  @State sheetVisible: boolean = false;
  @State sheetKind: string = '';
  @State text: string = '';
  @State address: string = '';
  @State renameId: string = '';
  @State renameText: string = '';
  @State targets: string[] = [];
  @State textId: string = '';
  @State fileLimit: number = 6;
  private pendingPeer: Peer | undefined = undefined;

  openSheet(kind: string, peer: Peer | undefined = undefined): void {
    this.pendingPeer = peer; this.sheetKind = kind; this.sheetVisible = true;
  }

  @Builder
  sheetContent() {
    if (this.sheetKind === 'text') { this.textEditor() }
    else if (this.sheetKind === 'address') { this.addressEditor() }
    else if (this.sheetKind === 'rename') { this.renameEditor() }
    else { this.chooseEditor() }
  }

  beginSend(peer: Peer): void {
    if (this.store.settings.sendMode === 'multiple') {
      const key = `${peer.ip}:${peer.port}`;
      this.targets = this.targets.includes(key) ? this.targets.filter((item: string) => item !== key) : [...this.targets, key];
      return;
    }
    if (!this.store.files.length) { this.openSheet('choose', peer); return; }
    this.onSend(peer);
  }

  async chooseForPeer(kind: string): Promise<void> {
    if (kind === 'text') { this.textId = ''; this.text = ''; this.sheetKind = 'text'; return; }
    this.sheetVisible = false;
    await this.store.selectFiles(kind);
    if (this.store.files.length && this.pendingPeer) this.onSend(this.pendingPeer);
    this.pendingPeer = undefined;
  }

  sendSelected(): void {
    const peers: Peer[] = [];
    for (const peer of [...this.store.peers, ...this.store.favorites]) {
      if (this.targets.includes(`${peer.ip}:${peer.port}`) && !peers.some((item: Peer) => item.ip === peer.ip && item.port === peer.port)) peers.push(peer);
    }
    this.onSendMany(peers);
  }

  @Builder
  chooseEditor() {
    Column({ space: 16 }) {
      Text(this.store.t('先选择要分享的内容')).fontSize(23).fontWeight(FontWeight.Medium)
      Text(this.store.t('选择后直接发送到这台设备。')).fontSize(14).fontColor($r('sys.color.font_secondary'))
      Button(this.store.t('文件')).width('100%').height(48).backgroundColor(this.store.accentFill).onClick(() => this.chooseForPeer('file'))
      Button(this.store.t('照片与视频')).width('100%').height(48).backgroundColor(this.store.accentFill).onClick(() => this.chooseForPeer('photo'))
      Button(this.store.t('文字或链接')).width('100%').height(48).backgroundColor(this.store.accentFill).onClick(() => this.chooseForPeer('text'))
    }.padding(24).width('100%')
  }

  @Builder
  action(label: string, symbol: string, kind: string) {
    Column({ space: 8 }) {
      AppIcon({ name: kind, iconSize: 28, tint: this.store.accentText })
      Text(this.store.t(label)).fontSize(13).fontColor($r('sys.color.font_primary'))
    }.width(104).constraintSize({ minHeight: 96 }).padding({ top: 20, bottom: 20 }).backgroundColor(this.store.surfaceColor).borderRadius(24)
      .border({ width: 0.5, color: this.store.hairlineColor })
      .onClick(() => {
        this.pendingPeer = undefined;
        if (kind === 'text') { this.textId = ''; this.text = ''; this.openSheet('text'); }
        else if (kind === 'clipboard') this.store.paste();
        else this.store.selectFiles(kind);
      }).enabled(!this.store.busy).accessibilityText(this.store.tf('选择{0}', [label])).accessibilityLevel('yes')
  }

  @Builder
  textEditor() {
    Column({ space: 20 }) {
      Text(this.store.t('发送文字或链接')).fontSize(23).fontWeight(FontWeight.Medium)
      TextArea({ text: this.text, placeholder: this.store.t('写点什么，或粘贴一个链接…') }).height(200).maxLength(100000)
        .onChange((value: string) => this.text = value)
      Button(this.store.t(this.textId ? '保存修改' : '加入发送清单')).width('100%').height(48).enabled(this.text.trim().length > 0)
        .backgroundColor(this.store.accentFill).onClick(() => {
          if (this.textId) this.store.editText(this.textId, this.text); else this.store.addText(this.text);
          this.text = ''; this.textId = ''; this.sheetVisible = false;
          if (this.pendingPeer) { this.onSend(this.pendingPeer); this.pendingPeer = undefined; }
        })
    }.padding(24).width('100%')
  }

  @Builder
  addressEditor() {
    Column({ space: 20 }) {
      Text(this.store.t('通过地址添加')).fontSize(23).fontWeight(FontWeight.Medium)
      Text(this.store.t('输入另一台设备的 IP 地址，可附带端口。')).fontColor($r('sys.color.font_secondary'))
      TextInput({ text: this.address, placeholder: '192.168.1.10:53317' }).onChange((value: string) => this.address = value)
      Button(this.store.t('查找设备')).width('100%').height(48).backgroundColor(this.store.accentFill)
        .enabled(this.address.trim().length > 0).onClick(() => { this.onAddress(this.address); this.sheetVisible = false; })
    }.padding(24).width('100%')
  }

  @Builder
  renameEditor() {
    Column({ space: 20 }) {
      Text(this.store.t('重命名发送文件')).fontSize(23).fontWeight(FontWeight.Medium)
      Text(this.store.t('只改变接收方看到的名称，不修改原文件。')).fontColor($r('sys.color.font_secondary'))
      TextInput({ text: this.renameText }).onChange((value: string) => this.renameText = value)
      Button(this.store.t('保存')).width('100%').height(48).backgroundColor(this.store.accentFill)
        .onClick(() => { this.store.renameFile(this.renameId, this.renameText); if (!this.store.error) this.sheetVisible = false; })
    }.padding(24).width('100%')
  }

  @Builder
  peerCard(peer: Peer) {
    Row({ space: 14 }) {
      Stack() { AppIcon({ name: peer.deviceType === 'mobile' ? 'mobile' : 'desktop', iconSize: 27, tint: this.store.accentText }) }
        .width(48).height(56).borderRadius(17).backgroundColor(this.store.controlSurface).onClick(() => this.onDetails(peer))
      Column({ space: 5 }) {
        Text(peer.alias || peer.ip).fontSize(17).fontWeight(FontWeight.Medium).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor($r('sys.color.font_primary'))
        Text(`${peer.ip}:${peer.port}`).fontSize(12).fontColor($r('sys.color.font_secondary'))
        Text(`${peer.protocol === 'https' ? this.store.t('加密连接') : this.store.t('未加密')}${this.store.isFavorite(peer) ? this.store.t(' · 已收藏') : ''}`).fontSize(11).fontColor($r('sys.color.font_secondary'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1).onClick(() => this.onDetails(peer))
      Button(this.store.settings.sendMode === 'multiple' ? (this.targets.includes(`${peer.ip}:${peer.port}`) ? this.store.t('已选') : this.store.t('选择')) : this.store.t('发送'))
        .height(44).constraintSize({ minWidth: 64 }).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText).onClick(() => this.beginSend(peer))
    }.padding(18).width('100%').backgroundColor(this.store.surfaceColor).borderRadius(22)
  }

  build() {
    Column({ space: 14 }) {
      Scroll() {
        Row({ space: 10 }) {
        this.action('文件', '▤', 'file')
        this.action('照片', '▧', 'photo')
        this.action('文件夹', '▱', 'folder')
        this.action('文字 / 链接', 'Aa', 'text')
        this.action('剪贴板', '▣', 'clipboard')
        }
      }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      if (this.store.busy) { LoadingProgress().width(32).height(32) }
      if (this.store.files.length > 0) { Row() {
        Text(this.store.tf('已选 {0} 项', [String(this.store.files.length)])).fontSize(17).fontWeight(FontWeight.Medium).layoutWeight(1).fontColor($r('sys.color.font_primary'))
        Text(formatSize(this.store.files.reduce((sum: number, file: ShareFile) => sum + file.size, 0))).fontSize(13).fontColor($r('sys.color.font_secondary'))
        if (this.store.files.length > 0) {
          Button(this.store.t('清空')).fontColor(this.store.accentText).backgroundColor(Color.Transparent).onClick(() => this.store.files = [])
        }
      }.width('100%').margin({ top: 10 }) }
      ForEach(this.store.files.slice(0, this.fileLimit), (file: ShareFile) => {
        Row({ space: 12 }) {
          if (file.mime.startsWith('image/') && file.uri) {
            Image(file.uri).width(48).height(48).objectFit(ImageFit.Cover).borderRadius(12)
          } else {
            AppIcon({ name: file.text ? 'text' : 'file', iconSize: 28, tint: this.store.accentText })
          }
          Column({ space: 5 }) {
            Text(file.name).fontSize(15).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor($r('sys.color.font_primary'))
            Text(`${formatSize(file.size)} · ${file.text ? this.store.t('文字') : file.mime}`).fontSize(12).fontColor($r('sys.color.font_secondary'))
          }.alignItems(HorizontalAlign.Start).layoutWeight(1).onClick(() => {
            if (!file.text) { this.store.error = ''; this.renameId = file.id; this.renameText = file.name; this.openSheet('rename'); }
            else { this.textId = file.id; this.text = file.text; this.openSheet('text'); }
          })
          Button('×').fontSize(22).backgroundColor(Color.Transparent).fontColor($r('sys.color.font_secondary'))
            .onClick(() => this.store.removeFile(file.id)).accessibilityText(this.store.tf('移除 {0}', [file.name]))
        }.padding(16).width('100%').backgroundColor(this.store.surfaceColor).borderRadius(20)
      }, (file: ShareFile) => `${file.id}:${file.name}:${file.size}`)
      if (this.store.files.length > this.fileLimit) {
        Button(this.store.tf('继续查看 · 还有 {0} 项', [String(this.store.files.length - this.fileLimit)]))
          .width('100%').height(44).backgroundColor(Color.Transparent).fontColor(this.store.accentText).onClick(() => this.fileLimit += 30)
      }
      if (this.fileLimit > 6 && this.store.files.length > 6) {
        Button(this.store.t('收起清单')).fontColor(this.store.accentText).backgroundColor(Color.Transparent).onClick(() => this.fileLimit = 6)
      }
      Text(this.store.t('附近的设备')).fontSize(19).fontWeight(FontWeight.Medium).width('100%').fontColor($r('sys.color.font_primary')).margin({ top: 16 })
      Row() {
        Select([{ value: this.store.t('单台设备') }, { value: this.store.t('多台设备') }]).selected(this.store.settings.sendMode === 'multiple' ? 1 : 0)
          .value(this.store.t(this.store.settings.sendMode === 'multiple' ? '多台设备' : '单台设备'))
          .font({ size: 13 }).accessibilityText(this.store.t('发送方式'))
          .onSelect((index: number) => { this.store.settings.sendMode = index === 1 ? 'multiple' : 'single'; this.store.save(); })
        Blank()
        Button(this.store.t('刷新')).fontSize(13).backgroundColor(Color.Transparent).fontColor(this.store.accentText).onClick(() => this.onDiscover())
      }.width('100%')
      if (this.store.peers.length === 0) {
        EmptyState({ icon: 'search', title: this.store.t('寻找另一台设备'), description: this.store.t('在对方设备打开 LocalSend，并连接同一网络。也可以通过 IP 地址直接添加。'), accent: this.store.accentText })
      }
      ForEach(this.store.peers, (peer: Peer) => { this.peerCard(peer) }, (peer: Peer) => `${peer.ip}:${peer.port}:${peer.alias}:${peer.protocol}`)
      if (this.store.favorites.length > 0) {
        Text(this.store.t('收藏设备')).fontSize(19).fontWeight(FontWeight.Medium).width('100%').fontColor($r('sys.color.font_primary')).margin({ top: 12 })
        ForEach(this.store.favorites, (peer: Peer) => { this.peerCard(peer) }, (peer: Peer) => `${peer.ip}:${peer.port}:${peer.alias}:${peer.protocol}`)
      }
      Row({ space: 12 }) {
        Button(this.store.t('通过地址添加')).layoutWeight(1).height(46).backgroundColor(this.store.surfaceColor).fontColor(this.store.accentText)
          .onClick(() => this.openSheet('address'))
        Button(this.store.t('通过链接分享')).layoutWeight(1).height(46).backgroundColor(this.store.surfaceColor).fontColor(this.store.accentText)
          .onClick(() => this.onWebShare())
      }.width('100%').margin({ top: 8 })
      if (this.store.settings.sendMode === 'multiple') {
        Button(this.store.tf('发送给 {0} 台设备', [String(this.targets.length)])).width('100%').height(48).backgroundColor(this.store.accentFill)
          .enabled(this.targets.length > 0 && this.store.files.length > 0).onClick(() => this.sendSelected())
      }
    }.width('100%')
      .bindSheet($$this.sheetVisible, this.sheetContent(), { height: this.sheetKind === 'text' ? SheetSize.LARGE : SheetSize.MEDIUM, showClose: true })
  }
}
