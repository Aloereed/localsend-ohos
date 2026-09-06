import { AppStore, HistoryEntry, Peer, ShareFile, MessageDraft, formatSize, samePeer } from '../model/AppStore';
import { Conversation, conversationList, inConversation, peerKey } from '../model/Conversations';
import { localSend } from '../network/LocalSendService';
import { AppIcon } from './AppIcon';
import { EmptyState } from './EmptyState';
import { util } from '@kit.ArkTS';
import { FileDetailsView } from './FileDetailsView';

@Component
export struct MessagesView {
  @ObjectLink @Watch('consumeTarget') store: AppStore;
  @Link detailOpen: boolean;
  @State peer: Peer = new Peer();
  @State query: string = '';
  @State draft: string = '';
  @State sending: boolean = false;
  @State showDetails: boolean = false;
  @State detailEntry: HistoryEntry = new HistoryEntry();
  @State visibleCount: number = 40;
  @State attachments: ShareFile[] = [];
  @State detailsKind: string = 'file';
  private messageScroller: Scroller = new Scroller();
  onTransfers: () => void = () => {};

  aboutToAppear(): void { this.consumeTarget(); }
  consumeTarget(): void {
    const target = this.store.messageTarget;
    if (target) { this.store.messageTarget = undefined; this.open(target); }
  }

  @Builder
  detailsSheet() {
    if (this.detailsKind === 'attachments') {
      Column({ space: 16 }) {
        Text(this.store.t('待发送附件')).fontSize(23).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).width('100%')
        Text(this.store.t('点击发送后，文字和附件会一起发出。')).fontSize(13).fontColor($r('sys.color.font_secondary')).width('100%')
        Scroll() {
          Column({ space: 12 }) {
            ForEach(this.attachments, (file: ShareFile) => {
              Row({ space: 12 }) {
                AppIcon({ name: file.mime.startsWith('image/') ? 'photo' : 'file', iconSize: 24, tint: this.store.accentText })
                Column({ space: 4 }) {
                  Text(file.name).fontSize(15).maxLines(2).fontColor($r('sys.color.font_primary'))
                  Text(formatSize(file.size)).fontSize(12).fontColor($r('sys.color.font_secondary'))
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Button('×').width(44).height(44).fontColor(this.store.dangerText).backgroundColor(Color.Transparent).enabled(!this.sending)
                  .accessibilityText(this.store.tf('移除 {0}', [file.name])).onClick(() => { this.attachments = this.attachments.filter((item: ShareFile) => item.id !== file.id); this.rememberDraft(); })
              }.padding(12).width('100%').backgroundColor($r('sys.color.comp_background_tertiary')).borderRadius(18)
            }, (file: ShareFile) => file.id)
          }.width('100%')
        }.layoutWeight(1).width('100%')
        Button(this.store.t('完成')).width('100%').height(48).backgroundColor(this.store.accentFill).onClick(() => this.showDetails = false)
      }.padding(24).height('100%').width('100%')
    } else { FileDetailsView({ store: this.store, entry: this.detailEntry }) }
  }

  openDetails(entry: HistoryEntry): void { this.detailsKind = 'file'; this.detailEntry = entry; this.showDetails = true; }

  rememberDraft(): void {
    const value = new MessageDraft(); value.text = this.draft; value.files = this.attachments;
    this.store.messageDrafts.set(peerKey(this.peer), value);
  }

  open(peer: Peer): void {
    this.peer = this.store.peers.find((item: Peer) => samePeer(item, peer)) || peer;
    const saved = this.store.messageDrafts.get(peerKey(this.peer));
    this.query = ''; this.draft = saved?.text || ''; this.attachments = saved?.files || []; this.visibleCount = 40; this.detailOpen = true;
    this.scrollToLatest();
  }

  scrollToLatest(): void {
    setTimeout(() => { if (this.detailOpen) this.messageScroller.scrollEdge(Edge.Bottom, { velocity: 0 }); }, 100);
  }

  entries(): HistoryEntry[] {
    return this.store.history.filter((entry: HistoryEntry) => inConversation(entry, this.peer) &&
      `${entry.name} ${entry.text}`.toLowerCase().includes(this.query.toLowerCase())).slice().reverse();
  }

  async sendText(): Promise<void> {
    if ((!this.draft.trim() && !this.attachments.length) || this.sending || !this.peer.ip) return;
    const files = this.attachments.slice(); const targetKey = peerKey(this.peer);
    if (this.draft.trim()) {
      const file = new ShareFile(); file.name = 'message.txt'; file.text = this.draft;
      file.mime = 'text/plain'; file.size = new util.TextEncoder().encodeInto(file.text).length; files.push(file);
    }
    this.sending = true;
    try {
      await localSend.send(this.peer, files);
      if (this.store.transfers.find((item) => item.files.some((sent) => sent.id === files[0].id))?.status === 'complete') {
        this.store.messageDrafts.delete(targetKey);
        if (peerKey(this.peer) === targetKey) { this.draft = ''; this.attachments = []; this.scrollToLatest(); }
      }
      else this.store.notice = this.store.t('消息未发送，草稿已保留。可在传输任务中查看原因');
    } finally { this.sending = false; }
  }

  async attach(kind: string): Promise<void> {
    if (!this.peer.ip || this.sending) return;
    const target = peerKey(this.peer);
    const selected = await this.store.selectAttachments(kind);
    const saved = this.store.messageDrafts.get(target) || new MessageDraft();
    saved.files = [...saved.files, ...selected.filter((file: ShareFile) => !saved.files.some((item: ShareFile) => item.uri === file.uri))];
    this.store.messageDrafts.set(target, saved);
    if (peerKey(this.peer) === target) this.attachments = saved.files;
  }

  clearConversation(): void {
    this.getUIContext().showAlertDialog({ title: this.store.t('清空这段会话？'), message: this.store.t('删除本机的会话记录，已接收文件保留。'),
      primaryButton: { value: this.store.t('取消'), action: () => {} }, secondaryButton: { value: this.store.t('清空'), action: () => {
        this.store.history = this.store.history.filter((entry: HistoryEntry) => !inConversation(entry, this.peer)); this.store.save();
      } } });
  }

  @Builder
  bubble(entry: HistoryEntry) {
    Row() {
      if (entry.direction === 'send') { Blank().width(32) }
      Column({ space: 10 }) {
        if (entry.text) {
          Text(entry.text).fontSize(16).lineHeight(24).maxLines(20).textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor($r('sys.color.font_primary')).copyOption(CopyOptions.LocalDevice).width('100%')
          if (entry.text.length > 160 || entry.text.split('\n').length > 6) {
            Button(this.store.t('阅读全文')).height(36).fontSize(13).fontColor(this.store.accentText).backgroundColor(Color.Transparent)
              .onClick(() => this.openDetails(entry))
          }
          if (/^https?:\/\/\S+$/i.test(entry.text.trim())) {
            Button(this.store.t('打开链接')).height(40).fontSize(13).fontColor(this.store.accentText).backgroundColor(Color.Transparent).onClick(() => this.store.openUrl(entry.text.trim()))
          }
        } else {
          Row({ space: 12 }) {
            AppIcon({ name: 'file', iconSize: 26, tint: this.store.accentText })
            Column({ space: 5 }) {
              Text(entry.name).fontSize(15).maxLines(3).fontColor($r('sys.color.font_primary'))
              Text(formatSize(entry.size)).fontSize(12).fontColor($r('sys.color.font_secondary'))
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.width('100%').onClick(() => this.store.openFile(entry))
        }
        Row() {
          Text(`${new Date(entry.time).toLocaleTimeString()} · ${entry.direction === 'send' ? this.store.t('已发送') : this.store.t('已接收')}`)
            .fontSize(11).fontColor($r('sys.color.font_secondary')).layoutWeight(1)
          Button(this.store.t('更多')).fontSize(12).height(30).backgroundColor(Color.Transparent).fontColor(this.store.accentText)
            .bindMenu([
              { value: this.store.t('详情'), action: () => this.openDetails(entry) },
              { value: entry.text ? this.store.t('复制文字') : this.store.t('打开文件'), action: () => { if (entry.text) this.store.copy(entry.text); else this.store.openFile(entry); } },
              { value: this.store.t('系统分享'), action: () => this.store.shareEntry(entry) },
              { value: this.store.t('再次发送'), action: () => this.store.resend(entry) },
              { value: this.store.t('删除记录'), action: () => this.store.removeHistory(entry.id) }
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
          Button() { AppIcon({ name: 'back', iconSize: 22, tint: this.store.accentText }) }
            .width(44).height(44).backgroundColor(Color.Transparent).onClick(() => this.detailOpen = false).accessibilityText(this.store.t('返回会话列表'))
          Column({ space: 4 }) {
            Text(this.peer.alias).fontSize(21).fontWeight(FontWeight.Medium).maxLines(1).fontColor($r('sys.color.font_primary'))
            Text(this.peer.ip ? `${this.peer.protocol === 'https' ? this.store.t('加密连接') : this.store.t('未加密')} · ${this.peer.ip}` : this.store.t('等待设备上线后即可回复'))
              .fontSize(12).fontColor($r('sys.color.font_secondary'))
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Button(this.store.t('管理')).fontSize(13).backgroundColor(Color.Transparent).fontColor(this.store.accentText).bindMenu([
            { value: this.store.t('传输任务'), action: () => this.onTransfers() }, { value: this.store.t('清空会话'), action: () => this.clearConversation() }
          ])
        }.width('100%')
        Search({ value: this.query, placeholder: this.store.t('搜索这段会话') }).onChange((value: string) => { this.query = value; this.visibleCount = 40; })
        Scroll(this.messageScroller) {
          Column({ space: 12 }) {
            if (this.entries().length > this.visibleCount) {
              Button(this.store.t('查看更早的消息')).height(44).fontColor(this.store.accentText).backgroundColor(Color.Transparent)
                .onClick(() => this.visibleCount += 40)
            }
            if (this.entries().length === 0) {
              EmptyState({ icon: 'message', title: this.query ? this.store.t('没有匹配的消息') : this.store.t('从一句问候开始'), description: this.store.t('文字和文件直接送达这台设备。'), accent: this.store.accentText })
            }
            ForEach(this.entries().slice(-this.visibleCount), (entry: HistoryEntry) => { this.bubble(entry) }, (entry: HistoryEntry) => entry.id)
          }.width('100%').padding({ top: 8, bottom: 16 })
        }.width('100%').layoutWeight(1).align(Alignment.Bottom)
        Column({ space: 10 }) {
          if (this.attachments.length > 0) {
            Button(this.store.tf('{0} 个附件 · 查看与编辑', [String(this.attachments.length)]))
              .width('100%').height(40).fontColor(this.store.accentText).backgroundColor($r('sys.color.comp_background_tertiary'))
              .onClick(() => { this.detailsKind = 'attachments'; this.showDetails = true; })
          }
          TextArea({ text: this.draft, placeholder: this.peer.ip ? this.store.t('写消息，或粘贴链接…') : this.store.t('设备上线后可回复') })
            .height(80).maxLength(100000).enabled(!this.sending).onChange((value: string) => { this.draft = value; this.rememberDraft(); })
          Row({ space: 12 }) {
            Button(this.store.t('添加文件')).height(44).backgroundColor($r('sys.color.comp_background_tertiary')).fontColor(this.store.accentText)
              .enabled(!!this.peer.ip && !this.sending && !this.store.busy).bindMenu([
                { value: this.store.t('文件'), action: () => this.attach('file') }, { value: this.store.t('照片与视频'), action: () => this.attach('photo') }
              ])
            Blank()
            Button(this.sending ? this.store.t('发送中…') : this.store.t('发送')).height(44).constraintSize({ minWidth: 88 }).backgroundColor(this.store.accentFill)
              .enabled(!!this.peer.ip && (!!this.draft.trim() || this.attachments.length > 0) && !this.sending).onClick(() => this.sendText())
          }.width('100%')
        }.padding(14).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24)
      } else {
        Text(this.store.t('消息')).fontSize(32).fontWeight(FontWeight.Bold).width('100%').fontColor($r('sys.color.font_primary')).margin({ top: 16 })
        Text(this.store.t('选择一台设备，继续你们的对话')).fontSize(14).width('100%').fontColor($r('sys.color.font_secondary'))
        Search({ value: this.query, placeholder: this.store.t('搜索会话、文字或文件') }).onChange((value: string) => this.query = value)
        Scroll() {
          Column({ space: 12 }) {
            if (conversationList(this.store.history).length === 0) {
              EmptyState({ icon: 'message', title: this.store.t('还没有会话'), description: this.store.t('选择下方设备发起会话，或等待另一台设备给你发来消息。'), accent: this.store.accentText })
            }
            if (this.query && conversationList(this.store.history, this.query).length === 0) {
              EmptyState({ icon: 'search', title: this.store.t('没有匹配的会话'), description: this.store.t('换个关键词，搜索设备、文字或文件名。'), accent: this.store.accentText })
            }
            ForEach(conversationList(this.store.history, this.query), (group: Conversation) => {
              Row({ space: 14 }) {
                AppIcon({ name: group.peer.deviceType === 'mobile' ? 'mobile' : 'desktop', iconSize: 28, tint: this.store.accentText })
                Column({ space: 7 }) {
                  Text(group.peer.alias).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
                  Text(group.last.text || group.last.name).fontSize(13).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor($r('sys.color.font_secondary'))
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text(String(group.count)).fontSize(12).fontColor($r('sys.color.font_secondary'))
              }.padding(20).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(24).onClick(() => this.open(group.peer))
            }, (group: Conversation) => `${group.key}:${group.last.id}:${group.count}:${group.peer.alias}`)
            Text(this.store.t('发起新会话')).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).width('100%').margin({ top: 12 })
            ForEach(this.store.peers, (peer: Peer) => {
              Row({ space: 14 }) {
                AppIcon({ name: 'message', iconSize: 24, tint: this.store.accentText })
                Text(peer.alias).fontSize(16).layoutWeight(1).fontColor($r('sys.color.font_primary'))
                Text(this.store.t('开始')).fontSize(13).fontColor(this.store.accentText)
              }.padding(18).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(22).onClick(() => this.open(peer))
            }, (peer: Peer) => `${peer.ip}:${peer.port}`)
            if (this.store.peers.length === 0) {
              Text(this.store.t('附近暂时没有设备，请确认双方连接同一网络。')).fontSize(13).lineHeight(22).fontColor($r('sys.color.font_secondary'))
              Button(this.store.t('刷新附近设备')).backgroundColor(Color.Transparent).fontColor(this.store.accentText).onClick(() => localSend.discover())
            }
          }.width('100%').padding({ bottom: 24 })
        }.width('100%').layoutWeight(1).align(Alignment.Top)
      }
    }.width('100%').height('100%').padding({ left: 24, right: 24, top: 8, bottom: 12 }).constraintSize({ maxWidth: 720 })
      .bindSheet($$this.showDetails, this.detailsSheet(), { height: SheetSize.LARGE, showClose: true })
  }
}
