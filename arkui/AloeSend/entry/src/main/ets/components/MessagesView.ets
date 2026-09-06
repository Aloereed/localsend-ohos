import { AppStore, HistoryEntry, Peer, ShareFile, formatSize } from '../model/AppStore';
import { Conversation, conversationList, inConversation } from '../model/Conversations';
import { localSend } from '../network/LocalSendService';
import { AppIcon } from './AppIcon';
import { EmptyState } from './EmptyState';
import { util } from '@kit.ArkTS';

@Component
export struct MessagesView {
  @ObjectLink store: AppStore;
  @Link detailOpen: boolean;
  @State peer: Peer = new Peer();
  @State query: string = '';
  @State draft: string = '';
  @State sending: boolean = false;
  onTransfers: () => void = () => {};

  open(peer: Peer): void {
    this.peer = this.store.peers.find((item: Peer) => peer.fingerprint ? item.fingerprint === peer.fingerprint : item.alias === peer.alias) || peer;
    this.query = ''; this.draft = ''; this.detailOpen = true;
  }

  entries(): HistoryEntry[] {
    return this.store.history.filter((entry: HistoryEntry) => inConversation(entry, this.peer) &&
      `${entry.name} ${entry.text}`.toLowerCase().includes(this.query.toLowerCase())).slice().reverse();
  }

  async sendText(): Promise<void> {
    if (!this.draft.trim() || this.sending || !this.peer.ip) return;
    const file = new ShareFile(); file.name = 'message.txt'; file.text = this.draft;
    file.mime = 'text/plain'; file.size = new util.TextEncoder().encodeInto(file.text).length;
    this.sending = true;
    try {
      await localSend.send(this.peer, [file]);
      if (this.store.transfers.find((item) => item.files.some((sent) => sent.id === file.id))?.status === 'complete') this.draft = '';
      else this.store.notice = '消息未发送，草稿已保留。可在传输任务中查看原因';
    } finally { this.sending = false; }
  }

  async attach(): Promise<void> {
    if (!this.peer.ip || this.sending) return;
    const before = this.store.files.map((file: ShareFile) => file.id);
    await this.store.selectFiles('file');
    const selected = this.store.files.filter((file: ShareFile) => !before.includes(file.id));
    if (!selected.length) return;
    this.sending = true;
    try { await localSend.send(this.peer, selected); }
    finally { this.sending = false; }
  }

  clearConversation(): void {
    this.getUIContext().showAlertDialog({ title: '清空这段会话？', message: '删除本机的会话记录，已接收文件保留。',
      primaryButton: { value: '取消', action: () => {} }, secondaryButton: { value: '清空', action: () => {
        this.store.history = this.store.history.filter((entry: HistoryEntry) => !inConversation(entry, this.peer)); this.store.save();
      } } });
  }

  @Builder
  bubble(entry: HistoryEntry) {
    Row() {
      if (entry.direction === 'send') { Blank().width(32) }
      Column({ space: 10 }) {
        if (entry.text) {
          Text(entry.text).fontSize(16).lineHeight(24).fontColor($r('sys.color.font_primary')).copyOption(CopyOptions.LocalDevice).width('100%')
        } else {
          Row({ space: 12 }) {
            AppIcon({ name: 'file', iconSize: 26, tint: this.store.settings.accent })
            Column({ space: 5 }) {
              Text(entry.name).fontSize(15).maxLines(3).fontColor($r('sys.color.font_primary'))
              Text(formatSize(entry.size)).fontSize(12).fontColor($r('sys.color.font_secondary'))
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.width('100%').onClick(() => this.store.openFile(entry))
        }
        Row() {
          Text(`${new Date(entry.time).toLocaleTimeString()} · ${entry.direction === 'send' ? '已发送' : '已接收'}`)
            .fontSize(11).fontColor($r('sys.color.font_secondary')).layoutWeight(1)
          Button('更多').fontSize(12).height(30).backgroundColor(Color.Transparent).fontColor(this.store.settings.accent)
            .bindMenu([
              { value: entry.text ? '复制文字' : '打开文件', action: () => { if (entry.text) this.store.copy(entry.text); else this.store.openFile(entry); } },
              { value: '系统分享', action: () => this.store.shareEntry(entry) },
              { value: '再次发送', action: () => this.store.resend(entry) },
              { value: '删除记录', action: () => this.store.removeHistory(entry.id) }
            ])
        }.width('100%')
      }.padding(18).layoutWeight(1).borderRadius(22)
        .backgroundColor(entry.direction === 'send' ? $r('sys.color.comp_background_tertiary') : $r('sys.color.comp_background_primary'))
        .border({ width: entry.direction === 'send' ? 1 : 0, color: this.store.settings.accent })
      if (entry.direction !== 'send') { Blank().width(32) }
    }.width('100%')
  }

  build() {
    Column({ space: 12 }) {
      if (this.detailOpen) {
        Row({ space: 10 }) {
          Button() { AppIcon({ name: 'back', iconSize: 22, tint: this.store.settings.accent }) }
            .width(44).height(44).backgroundColor(Color.Transparent).onClick(() => this.detailOpen = false).accessibilityText('返回会话列表')
          Column({ space: 4 }) {
            Text(this.peer.alias).fontSize(21).fontWeight(FontWeight.Medium).maxLines(1).fontColor($r('sys.color.font_primary'))
            Text(this.peer.ip ? `${this.peer.protocol === 'https' ? '加密连接' : '未加密'} · ${this.peer.ip}` : '等待设备上线后即可回复')
              .fontSize(12).fontColor($r('sys.color.font_secondary'))
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Button('管理').fontSize(13).backgroundColor(Color.Transparent).fontColor(this.store.settings.accent).bindMenu([
            { value: '传输任务', action: () => this.onTransfers() }, { value: '清空会话', action: () => this.clearConversation() }
          ])
        }.width('100%')
        Search({ value: this.query, placeholder: '搜索这段会话' }).onChange((value: string) => this.query = value)
        Scroll() {
          Column({ space: 12 }) {
            if (this.entries().length === 0) {
              EmptyState({ icon: 'message', title: this.query ? '没有匹配的消息' : '从一句问候开始', description: '文字和文件直接送达这台设备。', accent: this.store.settings.accent })
            }
            ForEach(this.entries(), (entry: HistoryEntry) => { this.bubble(entry) }, (entry: HistoryEntry) => entry.id)
          }.width('100%').padding({ top: 8, bottom: 16 })
        }.width('100%').layoutWeight(1).align(Alignment.Bottom)
        Column({ space: 10 }) {
          TextArea({ text: this.draft, placeholder: this.peer.ip ? '写消息，或粘贴链接…' : '设备上线后可回复' })
            .height(80).maxLength(100000).onChange((value: string) => this.draft = value)
          Row({ space: 12 }) {
            Button('添加文件').height(44).backgroundColor($r('sys.color.comp_background_tertiary')).fontColor(this.store.settings.accent)
              .enabled(!!this.peer.ip && !this.sending).onClick(() => this.attach())
            Blank()
            Button(this.sending ? '发送中…' : '发送').height(44).constraintSize({ minWidth: 88 }).backgroundColor(this.store.settings.accent)
              .enabled(!!this.peer.ip && !!this.draft.trim() && !this.sending).onClick(() => this.sendText())
          }.width('100%')
        }.padding(14).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24)
      } else {
        Text('消息').fontSize(32).fontWeight(FontWeight.Bold).width('100%').fontColor($r('sys.color.font_primary')).margin({ top: 16 })
        Text('选择一台设备，继续你们的对话').fontSize(14).width('100%').fontColor($r('sys.color.font_secondary'))
        Search({ value: this.query, placeholder: '搜索会话、文字或文件' }).onChange((value: string) => this.query = value)
        Scroll() {
          Column({ space: 12 }) {
            if (conversationList(this.store.history).length === 0) {
              EmptyState({ icon: 'message', title: '还没有会话', description: '选择下方设备发起会话，或等待另一台设备给你发来消息。', accent: this.store.settings.accent })
            }
            ForEach(conversationList(this.store.history).filter((group: Conversation) =>
              `${group.peer.alias} ${group.last.text} ${group.last.name}`.toLowerCase().includes(this.query.toLowerCase())), (group: Conversation) => {
              Row({ space: 14 }) {
                AppIcon({ name: group.peer.deviceType === 'mobile' ? 'mobile' : 'desktop', iconSize: 28, tint: this.store.settings.accent })
                Column({ space: 7 }) {
                  Text(group.peer.alias).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
                  Text(group.last.text || group.last.name).fontSize(13).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor($r('sys.color.font_secondary'))
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text(String(group.count)).fontSize(12).fontColor($r('sys.color.font_secondary'))
              }.padding(20).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24).onClick(() => this.open(group.peer))
            }, (group: Conversation) => `${group.key}:${group.last.id}:${group.count}:${group.peer.alias}`)
            Text('发起新会话').fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).width('100%').margin({ top: 12 })
            ForEach(this.store.peers, (peer: Peer) => {
              Row({ space: 14 }) {
                AppIcon({ name: 'message', iconSize: 24, tint: this.store.settings.accent })
                Text(peer.alias).fontSize(16).layoutWeight(1).fontColor($r('sys.color.font_primary'))
                Text('开始').fontSize(13).fontColor(this.store.settings.accent)
              }.padding(18).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(22).onClick(() => this.open(peer))
            }, (peer: Peer) => `${peer.ip}:${peer.port}`)
            if (this.store.peers.length === 0) {
              Text('附近暂时没有设备，请确认双方连接同一网络。').fontSize(13).lineHeight(22).fontColor($r('sys.color.font_secondary'))
              Button('刷新附近设备').backgroundColor(Color.Transparent).fontColor(this.store.settings.accent).onClick(() => localSend.discover())
            }
          }.width('100%').padding({ bottom: 24 })
        }.width('100%').layoutWeight(1).align(Alignment.Top)
      }
    }.width('100%').height('100%').padding({ left: 24, right: 24, top: 8, bottom: 12 }).constraintSize({ maxWidth: 720 })
  }
}
