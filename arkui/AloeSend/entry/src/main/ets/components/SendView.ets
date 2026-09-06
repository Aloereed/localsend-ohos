import { AppStore, ShareFile, Peer, formatSize } from '../model/AppStore';

@Component
export struct SendView {
  @ObjectLink store: AppStore;
  onSend: (peer: Peer) => void = () => {};
  onDiscover: () => void = () => {};
  onAddress: (address: string) => void = () => {};
  onWebShare: () => void = () => {};
  @State textSheet: boolean = false;
  @State text: string = '';
  @State addressSheet: boolean = false;
  @State address: string = '';
  @State renameSheet: boolean = false;
  @State renameId: string = '';
  @State renameText: string = '';

  @Builder
  action(label: string, symbol: string, kind: string) {
    Column({ space: 8 }) {
      Text(symbol).fontSize(25).fontColor(this.store.settings.accent)
      Text(label).fontSize(13).fontColor($r('sys.color.font_primary'))
    }.layoutWeight(1).padding({ top: 20, bottom: 20 }).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(20)
      .onClick(() => {
        if (kind === 'text') this.textSheet = true;
        else if (kind === 'clipboard') this.store.paste();
        else this.store.selectFiles(kind);
      }).accessibilityText(`选择${label}`)
  }

  @Builder
  textEditor() {
    Column({ space: 20 }) {
      Text('发送文字或链接').fontSize(23).fontWeight(FontWeight.Medium)
      TextArea({ text: this.text, placeholder: '写点什么，或粘贴一个链接…' }).height(200).maxLength(100000)
        .onChange((value: string) => this.text = value)
      Button('加入发送清单').width('100%').height(48).enabled(this.text.trim().length > 0)
        .backgroundColor(this.store.settings.accent).onClick(() => {
          this.store.addText(this.text); this.text = ''; this.textSheet = false;
        })
    }.padding(24).width('100%')
  }

  @Builder
  addressEditor() {
    Column({ space: 20 }) {
      Text('通过地址添加').fontSize(23).fontWeight(FontWeight.Medium)
      Text('输入另一台设备的 IP 地址，可附带端口。').fontColor($r('sys.color.font_secondary'))
      TextInput({ text: this.address, placeholder: '192.168.1.10:53317' }).onChange((value: string) => this.address = value)
      Button('查找设备').width('100%').height(48).backgroundColor(this.store.settings.accent)
        .enabled(this.address.trim().length > 0).onClick(() => { this.onAddress(this.address); this.addressSheet = false; })
    }.padding(24).width('100%')
  }

  @Builder
  renameEditor() {
    Column({ space: 20 }) {
      Text('重命名发送文件').fontSize(23).fontWeight(FontWeight.Medium)
      Text('只改变接收方看到的名称，不修改原文件。').fontColor($r('sys.color.font_secondary'))
      TextInput({ text: this.renameText }).onChange((value: string) => this.renameText = value)
      Button('保存').width('100%').height(48).backgroundColor(this.store.settings.accent)
        .onClick(() => { this.store.renameFile(this.renameId, this.renameText); this.renameSheet = false; })
    }.padding(24).width('100%')
  }

  @Builder
  peerCard(peer: Peer) {
    Row({ space: 14 }) {
      Text(peer.deviceType === 'mobile' ? '▯' : '▣').fontSize(30).fontColor(this.store.settings.accent).width(44)
      Column({ space: 5 }) {
        Text(peer.alias || peer.ip).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        Text(`${peer.ip}:${peer.port}`).fontSize(12).fontColor($r('sys.color.font_secondary'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1).onClick(() => this.onSend(peer))
      Button(this.store.isFavorite(peer) ? '★' : '☆').fontColor(this.store.settings.accent)
        .backgroundColor(Color.Transparent).onClick(() => this.store.toggleFavorite(peer)).accessibilityText('收藏设备')
      Button('发送').backgroundColor(this.store.settings.accent).onClick(() => this.onSend(peer))
    }.padding(18).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(22)
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        this.action('文件', '▤', 'file')
        this.action('照片', '▧', 'photo')
        this.action('文件夹', '▱', 'folder')
      }.width('100%')
      Row({ space: 10 }) {
        this.action('文字 / 链接', 'Aa', 'text')
        this.action('剪贴板', '▣', 'clipboard')
      }.width('100%')
      if (this.store.busy) { LoadingProgress().width(32).height(32) }
      Row() {
        Text(`已选 ${this.store.files.length} 项`).fontSize(17).fontWeight(FontWeight.Medium).layoutWeight(1).fontColor($r('sys.color.font_primary'))
        Text(formatSize(this.store.files.reduce((sum: number, file: ShareFile) => sum + file.size, 0))).fontSize(13).fontColor($r('sys.color.font_secondary'))
        if (this.store.files.length > 0) {
          Button('清空').fontColor(this.store.settings.accent).backgroundColor(Color.Transparent).onClick(() => this.store.files = [])
        }
      }.width('100%').margin({ top: 10 })
      ForEach(this.store.files, (file: ShareFile) => {
        Row({ space: 12 }) {
          Text(file.text ? 'Aa' : file.mime.startsWith('image/') ? '▧' : '▤').fontSize(25).fontColor(this.store.settings.accent).width(34)
          Column({ space: 5 }) {
            Text(file.name).fontSize(15).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor($r('sys.color.font_primary'))
            Text(`${formatSize(file.size)} · ${file.text ? '文字' : file.mime}`).fontSize(12).fontColor($r('sys.color.font_secondary'))
          }.alignItems(HorizontalAlign.Start).layoutWeight(1).onClick(() => {
            if (!file.text) { this.renameId = file.id; this.renameText = file.name; this.renameSheet = true; }
          })
          Button('×').fontSize(22).backgroundColor(Color.Transparent).fontColor($r('sys.color.font_secondary'))
            .onClick(() => this.store.removeFile(file.id)).accessibilityText(`移除 ${file.name}`)
        }.padding(16).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(20)
      }, (file: ShareFile) => file.id)
      Row() {
        Text('附近的设备').fontSize(19).fontWeight(FontWeight.Medium).layoutWeight(1).fontColor($r('sys.color.font_primary'))
        Button('刷新').backgroundColor(Color.Transparent).fontColor(this.store.settings.accent).onClick(() => this.onDiscover())
      }.width('100%').margin({ top: 16 })
      if (this.store.peers.length === 0) {
        Column({ space: 12 }) {
          Text('等待发现附近设备').fontSize(17).fontColor($r('sys.color.font_primary'))
          Text('保持对方的 LocalSend 打开，并连接同一网络。').fontSize(13).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
        }.width('100%').padding(28).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24)
      }
      ForEach(this.store.peers, (peer: Peer) => { this.peerCard(peer) }, (peer: Peer) => `${peer.ip}:${peer.port}`)
      if (this.store.favorites.length > 0) {
        Text('收藏设备').fontSize(19).fontWeight(FontWeight.Medium).width('100%').fontColor($r('sys.color.font_primary')).margin({ top: 12 })
        ForEach(this.store.favorites, (peer: Peer) => { this.peerCard(peer) }, (peer: Peer) => `${peer.ip}:${peer.port}`)
      }
      Row({ space: 12 }) {
        Button('通过地址添加').layoutWeight(1).height(46).backgroundColor($r('sys.color.comp_background_primary')).fontColor(this.store.settings.accent)
          .onClick(() => this.addressSheet = true)
        Button('通过链接分享').layoutWeight(1).height(46).backgroundColor($r('sys.color.comp_background_primary')).fontColor(this.store.settings.accent)
          .onClick(() => this.onWebShare())
      }.width('100%').margin({ top: 8 })
    }.width('100%')
      .bindSheet($$this.textSheet, this.textEditor(), { height: SheetSize.MEDIUM, showClose: true })
      .bindSheet($$this.addressSheet, this.addressEditor(), { height: SheetSize.MEDIUM, showClose: true })
      .bindSheet($$this.renameSheet, this.renameEditor(), { height: SheetSize.MEDIUM, showClose: true })
  }
}
