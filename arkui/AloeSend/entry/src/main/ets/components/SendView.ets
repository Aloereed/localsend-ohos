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
  @State textSheet: boolean = false;
  @State text: string = '';
  @State addressSheet: boolean = false;
  @State address: string = '';
  @State renameSheet: boolean = false;
  @State renameId: string = '';
  @State renameText: string = '';
  @State targets: string[] = [];
  @State chooseSheet: boolean = false;
  private pendingPeer: Peer | undefined = undefined;

  beginSend(peer: Peer): void {
    if (this.store.settings.sendMode === 'multiple') {
      const key = `${peer.ip}:${peer.port}`;
      this.targets = this.targets.includes(key) ? this.targets.filter((item: string) => item !== key) : [...this.targets, key];
      return;
    }
    if (!this.store.files.length) { this.pendingPeer = peer; this.chooseSheet = true; return; }
    this.onSend(peer);
  }

  async chooseForPeer(kind: string): Promise<void> {
    this.chooseSheet = false;
    if (kind === 'text') { this.textSheet = true; return; }
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
      Button(this.store.t('文件')).width('100%').height(48).backgroundColor(this.store.settings.accent).onClick(() => this.chooseForPeer('file'))
      Button(this.store.t('照片与视频')).width('100%').height(48).backgroundColor(this.store.settings.accent).onClick(() => this.chooseForPeer('photo'))
      Button(this.store.t('文字或链接')).width('100%').height(48).backgroundColor(this.store.settings.accent).onClick(() => this.chooseForPeer('text'))
    }.padding(24).width('100%')
  }

  @Builder
  action(label: string, symbol: string, kind: string) {
    Column({ space: 8 }) {
      AppIcon({ name: kind, iconSize: 28, tint: this.store.settings.accent })
      Text(label).fontSize(13).fontColor($r('sys.color.font_primary'))
    }.layoutWeight(1).constraintSize({ minHeight: 96 }).padding({ top: 20, bottom: 20 }).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24)
      .onClick(() => {
        if (kind === 'text') this.textSheet = true;
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
      Button(this.store.t('加入发送清单')).width('100%').height(48).enabled(this.text.trim().length > 0)
        .backgroundColor(this.store.settings.accent).onClick(() => {
          this.store.addText(this.text); this.text = ''; this.textSheet = false;
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
      Button(this.store.t('查找设备')).width('100%').height(48).backgroundColor(this.store.settings.accent)
        .enabled(this.address.trim().length > 0).onClick(() => { this.onAddress(this.address); this.addressSheet = false; })
    }.padding(24).width('100%')
  }

  @Builder
  renameEditor() {
    Column({ space: 20 }) {
      Text(this.store.t('重命名发送文件')).fontSize(23).fontWeight(FontWeight.Medium)
      Text(this.store.t('只改变接收方看到的名称，不修改原文件。')).fontColor($r('sys.color.font_secondary'))
      TextInput({ text: this.renameText }).onChange((value: string) => this.renameText = value)
      Button(this.store.t('保存')).width('100%').height(48).backgroundColor(this.store.settings.accent)
        .onClick(() => { this.store.renameFile(this.renameId, this.renameText); this.renameSheet = false; })
    }.padding(24).width('100%')
  }

  @Builder
  peerCard(peer: Peer) {
    Row({ space: 14 }) {
      Stack() { AppIcon({ name: peer.deviceType === 'mobile' ? 'mobile' : 'desktop', iconSize: 27, tint: this.store.settings.accent }) }
        .width(48).height(56).borderRadius(17).backgroundColor($r('sys.color.comp_background_tertiary')).onClick(() => this.onDetails(peer))
      Column({ space: 5 }) {
        Text(peer.alias || peer.ip).fontSize(17).fontWeight(FontWeight.Medium).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor($r('sys.color.font_primary'))
        Text(`${peer.ip}:${peer.port}`).fontSize(12).fontColor($r('sys.color.font_secondary'))
        Text(`${peer.protocol === 'https' ? this.store.t('加密连接') : this.store.t('未加密')}${this.store.isFavorite(peer) ? this.store.t(' · 已收藏') : ''}`).fontSize(11).fontColor($r('sys.color.font_secondary'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1).onClick(() => this.onDetails(peer))
      Button(this.store.settings.sendMode === 'multiple' ? (this.targets.includes(`${peer.ip}:${peer.port}`) ? this.store.t('已选') : this.store.t('选择')) : this.store.t('发送'))
        .height(44).constraintSize({ minWidth: 64 }).backgroundColor(this.store.settings.accent).onClick(() => this.beginSend(peer))
    }.padding(18).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(22)
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        this.action(this.store.t('文件'), '▤', 'file')
        this.action(this.store.t('照片'), '▧', 'photo')
        this.action(this.store.t('文件夹'), '▱', 'folder')
      }.width('100%')
      Row({ space: 10 }) {
        this.action(this.store.t('文字 / 链接'), 'Aa', 'text')
        this.action(this.store.t('剪贴板'), '▣', 'clipboard')
      }.width('100%')
      if (this.store.busy) { LoadingProgress().width(32).height(32) }
      Row() {
        Text(this.store.tf('已选 {0} 项', [String(this.store.files.length)])).fontSize(17).fontWeight(FontWeight.Medium).layoutWeight(1).fontColor($r('sys.color.font_primary'))
        Text(formatSize(this.store.files.reduce((sum: number, file: ShareFile) => sum + file.size, 0))).fontSize(13).fontColor($r('sys.color.font_secondary'))
        if (this.store.files.length > 0) {
          Button(this.store.t('清空')).fontColor(this.store.settings.accent).backgroundColor(Color.Transparent).onClick(() => this.store.files = [])
        }
      }.width('100%').margin({ top: 10 })
      ForEach(this.store.files, (file: ShareFile) => {
        Row({ space: 12 }) {
          if (file.mime.startsWith('image/') && file.uri) {
            Image(file.uri).width(48).height(48).objectFit(ImageFit.Cover).borderRadius(12)
          } else {
            AppIcon({ name: file.text ? 'text' : 'file', iconSize: 28, tint: this.store.settings.accent })
          }
          Column({ space: 5 }) {
            Text(file.name).fontSize(15).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor($r('sys.color.font_primary'))
            Text(`${formatSize(file.size)} · ${file.text ? this.store.t('文字') : file.mime}`).fontSize(12).fontColor($r('sys.color.font_secondary'))
          }.alignItems(HorizontalAlign.Start).layoutWeight(1).onClick(() => {
            if (!file.text) { this.renameId = file.id; this.renameText = file.name; this.renameSheet = true; }
          })
          Button('×').fontSize(22).backgroundColor(Color.Transparent).fontColor($r('sys.color.font_secondary'))
            .onClick(() => this.store.removeFile(file.id)).accessibilityText(this.store.tf('移除 {0}', [file.name]))
        }.padding(16).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(20)
      }, (file: ShareFile) => `${file.id}:${file.name}`)
      Row() {
        Text(this.store.t('附近的设备')).fontSize(19).fontWeight(FontWeight.Medium).layoutWeight(1).fontColor($r('sys.color.font_primary'))
        Button(this.store.t('刷新')).backgroundColor(Color.Transparent).fontColor(this.store.settings.accent).onClick(() => this.onDiscover())
      }.width('100%').margin({ top: 16 })
      Row() {
        Text(this.store.t('发送方式')).layoutWeight(1).fontSize(14).fontColor($r('sys.color.font_secondary'))
        Select([{ value: this.store.t('单台设备') }, { value: this.store.t('多台设备') }]).selected(this.store.settings.sendMode === 'multiple' ? 1 : 0)
          .onSelect((index: number) => { this.store.settings.sendMode = index === 1 ? 'multiple' : 'single'; this.store.save(); })
      }.width('100%')
      if (this.store.peers.length === 0) {
        EmptyState({ icon: 'search', title: this.store.t('寻找另一台设备'), description: this.store.t('在对方设备打开 LocalSend，并连接同一网络。也可以通过 IP 地址直接添加。'), accent: this.store.settings.accent })
      }
      ForEach(this.store.peers, (peer: Peer) => { this.peerCard(peer) }, (peer: Peer) => `${peer.ip}:${peer.port}:${peer.alias}:${peer.protocol}`)
      if (this.store.favorites.length > 0) {
        Text(this.store.t('收藏设备')).fontSize(19).fontWeight(FontWeight.Medium).width('100%').fontColor($r('sys.color.font_primary')).margin({ top: 12 })
        ForEach(this.store.favorites, (peer: Peer) => { this.peerCard(peer) }, (peer: Peer) => `${peer.ip}:${peer.port}:${peer.alias}:${peer.protocol}`)
      }
      Row({ space: 12 }) {
        Button(this.store.t('通过地址添加')).layoutWeight(1).height(46).backgroundColor($r('sys.color.comp_background_primary')).fontColor(this.store.settings.accent)
          .onClick(() => this.addressSheet = true)
        Button(this.store.t('通过链接分享')).layoutWeight(1).height(46).backgroundColor($r('sys.color.comp_background_primary')).fontColor(this.store.settings.accent)
          .onClick(() => this.onWebShare())
      }.width('100%').margin({ top: 8 })
      if (this.store.settings.sendMode === 'multiple') {
        Button(this.store.tf('发送给 {0} 台设备', [String(this.targets.length)])).width('100%').height(48).backgroundColor(this.store.settings.accent)
          .enabled(this.targets.length > 0 && this.store.files.length > 0).onClick(() => this.sendSelected())
      }
    }.width('100%')
      .bindSheet($$this.textSheet, this.textEditor(), { height: SheetSize.MEDIUM, showClose: true })
      .bindSheet($$this.addressSheet, this.addressEditor(), { height: SheetSize.MEDIUM, showClose: true })
      .bindSheet($$this.renameSheet, this.renameEditor(), { height: SheetSize.MEDIUM, showClose: true })
      .bindSheet($$this.chooseSheet, this.chooseEditor(), { height: SheetSize.MEDIUM, showClose: true })
  }
}
