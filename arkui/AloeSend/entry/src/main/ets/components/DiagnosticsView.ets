import { AppStore, NetworkLogEntry } from '../model/AppStore';
import { localSend } from '../network/LocalSendService';

@Component
export struct DiagnosticsView {
  @ObjectLink store: AppStore;
  @State category: number = 0;
  @State query: string = '';
  @State limit: number = 50;
  @State showCertificate: boolean = false;

  resetCertificate(): void {
    this.getUIContext().showAlertDialog({ title: this.store.t('重新生成本机证书？'),
      message: this.store.t('设备指纹会改变，其他设备可能需要重新收藏或确认本机。已保存文件不受影响。'),
      primaryButton: { value: this.store.t('取消'), action: () => {} },
      secondaryButton: { value: this.store.t('重新生成'), action: () => { localSend.resetIdentity(); } } });
  }

  restoreSettings(): void {
    this.getUIContext().showAlertDialog({ title: this.store.t('恢复默认设置？'),
      message: this.store.t('恢复名称、外观、接收策略和网络偏好。收藏、历史、文件、证书及已同意的隐私选择保留。网络设置需重启服务后生效。'),
      primaryButton: { value: this.store.t('取消'), action: () => {} },
      secondaryButton: { value: this.store.t('恢复'), action: () => { this.store.restoreSettings(); } } });
  }

  lines(): string[] {
    const source = this.category === 0 ? this.store.logs : this.store.networkLogs.filter((entry: NetworkLogEntry) =>
      entry.category === (this.category === 1 ? 'discovery' : 'http')).map((entry: NetworkLogEntry) => `${new Date(entry.time).toLocaleTimeString()}  ${entry.message}`);
    const search = this.query.trim().toLowerCase();
    return source.filter((line: string) => line.toLowerCase().includes(search));
  }

  summary(): string {
    return `AloeSend · ArkUI\n${this.store.serverStatus}\nLocalSend 2.1 · ${this.store.listenerHttps ? 'HTTPS / Mbed TLS 3.6.7' : 'HTTP'}\n` +
      `Port: ${this.store.listenerPort}\nMulticast: ${this.store.listenerMulticast}\nIP: ${this.store.localIps.join(', ')}\n` +
      `SHA-256: ${this.store.settings.fingerprint}\nDownload access: ${this.store.downloadAccess}\n\n${this.lines().join('\n')}`;
  }

  clear(): void {
    if (this.category === 0) this.store.logs = [];
    else this.store.networkLogs = this.store.networkLogs.filter((entry: NetworkLogEntry) => entry.category !== (this.category === 1 ? 'discovery' : 'http'));
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        Text(this.store.t(this.store.serverStatus)).fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).width('100%')
        Text(`LocalSend 2.1 · ${this.store.listenerHttps ? 'HTTPS / Mbed TLS 3.6.7' : 'HTTP'}`).fontSize(14).fontColor($r('sys.color.font_secondary')).width('100%')
        Text(`${this.store.localIps.join('\n')}\n${this.store.listenerPort} · ${this.store.listenerMulticast}`).fontSize(14).fontColor($r('sys.color.font_secondary')).width('100%').copyOption(CopyOptions.LocalDevice)
        Text(this.store.t('本机证书指纹')).fontSize(13).fontColor($r('sys.color.font_secondary')).width('100%')
        Text(this.store.settings.fingerprint).fontSize(13).fontColor($r('sys.color.font_primary')).width('100%').copyOption(CopyOptions.LocalDevice)
        Row({ space: 10 }) {
          Button(this.store.t('查看证书')).layoutWeight(1).height(44).fontColor(this.store.accentText).backgroundColor(this.store.controlSurface)
            .enabled(!!localSend.certificate()).onClick(() => this.showCertificate = !this.showCertificate)
          Button(this.store.t('重新生成')).layoutWeight(1).height(44).fontColor(this.store.dangerText).backgroundColor(this.store.controlSurface)
            .enabled(!this.store.activeTransfers && !this.store.webUrl && !this.store.webStarting && !this.store.identityResetting).onClick(() => this.resetCertificate())
        }.width('100%')
        if (this.showCertificate) {
          Text(localSend.certificate()).fontSize(12).lineHeight(19).fontColor($r('sys.color.font_secondary')).width('100%').copyOption(CopyOptions.LocalDevice)
        }
        Row({ space: 10 }) {
          Button(this.store.t('刷新附近设备')).layoutWeight(1).height(44).fontColor(this.store.accentText).backgroundColor(this.store.controlSurface).onClick(() => localSend.discover())
          Button(this.store.t('重新启动')).layoutWeight(1).height(44).fontColor(this.store.accentText).backgroundColor(this.store.controlSurface).enabled(!this.store.activeTransfers).onClick(() => localSend.restart())
        }.width('100%')
      }.padding(20).width('100%').backgroundColor(this.store.surfaceColor).borderRadius(24)
      Select([{ value: this.store.t('运行日志') }, { value: this.store.t('发现日志') }, { value: 'HTTP' }]).selected(this.category)
        .value(this.category === 0 ? this.store.t('运行日志') : this.category === 1 ? this.store.t('发现日志') : 'HTTP')
        .onSelect((index: number) => { this.category = index; this.limit = 50; })
      Search({ value: this.query, placeholder: this.store.t('搜索日志') }).onChange((value: string) => { this.query = value; this.limit = 50; })
      Row({ space: 12 }) {
        Button(this.store.t('复制诊断信息')).layoutWeight(1).height(44).fontColor(this.store.accentText).backgroundColor(this.store.controlSurface).onClick(() => this.store.copy(this.summary()))
        Button(this.store.t('清空')).height(44).fontColor(this.store.dangerText).backgroundColor(this.store.controlSurface).onClick(() => this.clear())
      }.width('100%')
      if (this.lines().length === 0) { Text(this.store.t('暂无日志')).fontSize(14).fontColor($r('sys.color.font_secondary')).padding(24) }
      ForEach(this.lines().slice(0, this.limit), (line: string) => {
        Text(line).fontSize(13).lineHeight(21).fontColor($r('sys.color.font_primary')).width('100%').copyOption(CopyOptions.LocalDevice)
      })
      if (this.lines().length > this.limit) {
        Button(this.store.t('查看更多')).height(44).fontColor(this.store.accentText).backgroundColor(this.store.controlSurface).onClick(() => this.limit += 50)
      }
      Button(this.store.t('恢复默认设置')).width('100%').height(48).fontColor(this.store.dangerText).backgroundColor(this.store.controlSurface)
        .enabled(!this.store.activeTransfers && !this.store.webUrl && !this.store.webStarting && !this.store.identityResetting).onClick(() => this.restoreSettings())
    }.width('100%')
  }
}
