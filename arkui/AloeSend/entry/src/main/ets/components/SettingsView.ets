import { AppStore, AppSettings } from '../model/AppStore';
import { flutterText } from '../model/DynamicLocale';
import { multicastAddress } from '../network/Addresses';
import { localSend } from '../network/LocalSendService';
import { LengthMetrics } from '@kit.ArkUI';
import { flutterLanguages } from '../model/FlutterLocales';
import { resolvedLanguage } from '../model/Locale';
import { LanguagePicker } from './LanguagePicker';
import { AppIcon } from './AppIcon';
import { normalizeColor, colorChannel, changeColorChannel } from '../model/Colors';

@Component
export struct SettingsView {
  private defaults: AppSettings = new AppSettings();

  networkHint(port: boolean): string {
    const values: Record<string, string> = {};
    values[port ? 'defaultPort' : 'defaultMulticast'] = port ? String(this.defaults.port) : this.defaults.multicast;
    return flutterText(port ? 'settingsTab.network.portWarning' : 'settingsTab.network.multicastGroupWarning', this.store.settings.language, values);
  }
  @ObjectLink store: AppStore;
  onNavigate: (route: string) => void = () => {};

  languageOptions(): SelectOption[] { return [{ value: this.store.t('跟随系统') }, ...flutterLanguages.map((item): SelectOption => ({ value: item.name }))]; }
  languageIndex(): number { return this.store.settings.language === 'system' ? 0 : flutterLanguages.findIndex((item) => item.id === resolvedLanguage(this.store.settings.language)) + 1; }
  languageName(): string { return this.languageOptions()[this.languageIndex()].value as string; }
  @State alias: string = '';
  @State port: string = '';
  @State group: string = '';
  @State pin: string = '';
  @State timeout: string = '';
  @State model: string = '';
  @State languageVisible: boolean = false;
  @State colorDraft: string = '#168A75';
  @State colorPickerVisible: boolean = false;

  @Builder
  colorPicker() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Circle().width(48).height(48).fill(normalizeColor(this.colorDraft) || this.store.settings.accent)
        TextInput({ text: this.colorDraft, placeholder: '#168A75' }).layoutWeight(1).maxLength(7)
          .onChange((value: string) => this.colorDraft = value).accessibilityText(this.store.t('十六进制颜色'))
      }.width('100%')
      ForEach([0, 1, 2], (index: number) => {
        Row({ space: 12 }) {
          Text(['R', 'G', 'B'][index]).fontColor($r('sys.color.font_primary')).width(24)
          Slider({ value: colorChannel(this.colorDraft, index), min: 0, max: 255, step: 1 }).layoutWeight(1)
            .selectedColor(['#D64545', '#258A4A', '#3478F6'][index])
            .onChange((value: number) => this.colorDraft = changeColorChannel(this.colorDraft, index, value))
            .accessibilityText(this.store.t(['红色分量', '绿色分量', '蓝色分量'][index]))
          Text(String(colorChannel(this.colorDraft, index))).width(36).fontColor($r('sys.color.font_secondary'))
        }.width('100%')
      })
      Row({ space: 12 }) {
        Button(this.store.t('取消')).onClick(() => this.colorPickerVisible = false)
        Button(this.store.t('应用颜色')).enabled(!!normalizeColor(this.colorDraft)).onClick(async () => {
          this.store.settings.accent = normalizeColor(this.colorDraft); this.store.settings.themePreset = 'custom';
          if (await this.store.save()) this.colorPickerVisible = false;
        })
      }
    }.width('100%')
  }

  importSettings(): void {
    this.getUIContext().showAlertDialog({ title: this.store.t('从旧版本导入设置'),
      message: this.store.t('将用旧版保存的设置覆盖本端对应选项，包括名称、主题、接收和网络设置。收藏、历史、消息和本机证书保持不变。'),
      primaryButton: { value: this.store.t('取消'), action: () => {} },
      secondaryButton: { value: this.store.t('导入'), action: () => {
        this.store.inheritFlutterSettings().then((changed: boolean) => { if (changed) this.aboutToAppear(); });
      } }
    });
  }

  @Builder
  languageSheet() { LanguagePicker({ store: this.store, onChoose: () => this.languageVisible = false }) }

  aboutToAppear(): void {
    this.alias = this.store.settings.alias;
    this.port = String(this.store.settings.port);
    this.group = this.store.settings.multicast;
    this.pin = this.store.settings.pin;
    this.timeout = String(this.store.settings.discoveryTimeout); this.model = this.store.settings.deviceModel;
  }

  @Builder
  title(text: string) {
    Text(this.store.t(text)).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
      .width('100%').padding({ left: 8, top: 22, bottom: 10 })
  }

  @Builder
  link(text: string, detail: string, destination: string) {
    Row({ space: 10 }) {
      Column({ space: 5 }) {
        Text(this.store.t(text)).fontSize(16).fontColor($r('sys.color.font_primary')).width('100%')
        if (this.linkDetail(detail, destination)) {
          Text(this.linkDetail(detail, destination)).fontSize(13).lineHeight(20)
            .fontColor($r('sys.color.font_secondary')).width('100%')
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      AppIcon({ name: 'forward', rtl: this.store.rtl, iconSize: 22, tint: $r('sys.color.font_secondary') })
    }.padding(18).width('100%').constraintSize({ minHeight: 58 }).onClick(() => {
      if (destination === 'qq-group') this.store.openFeedbackGroup();
      else this.onNavigate(destination);
    })
      .accessibilityText(`${this.store.t(text)} ${this.linkDetail(detail, destination)}`)
  }

  linkDetail(detail: string, destination: string): string {
    if (destination === 'diagnostics') return this.store.t(this.store.serverStatus);
    if (destination === 'network') return this.store.t(this.store.settings.networkFilter === 'none' ? '全部网络' : '已筛选');
    return this.store.t(detail);
  }

  toggleValue(key: string): boolean {
    const settings = this.store.settings;
    if (key === 'quickSave') return settings.quickSave;
    if (key === 'favorites') return settings.favoriteQuickSave;
    if (key === 'createChecksums') return settings.createChecksums;
    if (key === 'showAddressTags') return settings.showAddressTags;
    if (key === 'verifyChecksums') return settings.verifyChecksums;
    if (key === 'history') return settings.saveHistory;
    if (key === 'finish') return settings.autoFinish;
    if (key === 'messages') return settings.openMessagesOnReceive;
    if (key === 'gallery') return settings.offerGallerySave;
    if (key === 'animation') return settings.animations;
    if (key === 'effects') return settings.reduceEffects;
    if (key === 'black') return settings.pureBlack || settings.themePreset === 'oled';
    if (key === 'visible') return settings.visible;
    if (key === 'advanced') return settings.advanced;
    return settings.https;
  }

  @Builder
  toggle(title: string, detail: string, key: string) {
    Row({ space: 12 }) {
      Column({ space: 5 }) {
        Text(this.store.t(title)).fontSize(16).fontColor($r('sys.color.font_primary'))
        Text(this.store.t(detail)).fontSize(12).fontColor($r('sys.color.font_secondary'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.toggleValue(key) }).selectedColor(this.store.accentFill)
        .enabled(key !== 'black' || this.store.settings.themePreset !== 'oled')
        .onChange(async (value: boolean) => {
          if (value === this.toggleValue(key)) return;
          if (key === 'quickSave') this.store.settings.quickSave = value;
          if (key === 'favorites') this.store.settings.favoriteQuickSave = value;
          if (key === 'createChecksums') this.store.settings.createChecksums = value;
          if (key === 'showAddressTags') this.store.settings.showAddressTags = value;
          if (key === 'verifyChecksums') this.store.settings.verifyChecksums = value;
          if (key === 'history') this.store.settings.saveHistory = value;
          if (key === 'finish') this.store.settings.autoFinish = value;
          if (key === 'messages') this.store.settings.openMessagesOnReceive = value;
          if (key === 'gallery') { this.store.settings.offerGallerySave = value; if (!value) this.store.galleryQueue = []; }
          if (key === 'animation') this.store.settings.animations = value;
          if (key === 'effects') this.store.settings.reduceEffects = value;
          if (key === 'black') this.store.settings.pureBlack = value;
          if (key === 'visible') this.store.settings.visible = value;
          if (key === 'advanced') this.store.settings.advanced = value;
          if (key === 'https') this.store.settings.https = value;
          const saved = await this.store.save();
          if (key === 'visible') localSend.announce();
          if (key === 'https' && saved) this.store.notice = this.store.t('加密设置已保存。重启本端服务后，请完全退出并重新打开 Windows 端 LocalSend，避免传输停在 0%。');
        }).accessibilityText(this.store.t(title))
    }.padding(18).width('100%')
  }

  async saveNetwork(): Promise<void> {
    const port = Number(this.port);
    const timeout = Number(this.timeout);
    if (!/^\d+$/.test(this.timeout.trim()) || !Number.isInteger(timeout) || timeout < 500 || timeout > 30000) { this.store.error = this.store.t('发现超时范围为 500–30000 毫秒'); return; }
    if (!/^\d+$/.test(this.port.trim()) || !Number.isInteger(port) || port < 1024 || port > 65535) { this.store.error = this.store.t('端口范围为 1024–65535'); return; }
    let group = '';
    try { group = multicastAddress(this.group); } catch (_) {
      this.store.error = this.store.t('请输入有效的 IPv4 组播地址'); return;
    }
    this.store.error = '';
    this.store.settings.port = port;
    this.store.settings.multicast = group; this.group = group;
    this.store.settings.discoveryTimeout = timeout; this.store.settings.deviceModel = this.model.trim() || 'HarmonyOS';
    if (await this.store.save()) this.store.notice = this.store.t('网络设置已保存，重启接收服务后生效');
  }

  build() {
    Column() {
      this.title('设备')
      Column({ space: 12 }) {
        Text(this.store.t('设备名称')).fontSize(14).fontColor($r('sys.color.font_secondary')).width('100%')
        TextInput({ text: this.alias, placeholder: this.store.t('设备名称') }).maxLength(40).onChange((value: string) => this.alias = value)
        Row({ space: 8 }) {
          Button(this.store.t('随机名称')).fontSize(13).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText)
            .onClick(() => this.alias = this.store.randomAlias())
          Button(this.store.t('使用机型名称')).fontSize(13).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText)
            .onClick(() => this.alias = this.store.systemDeviceName())
        }.width('100%')
        Button(this.store.t('保存名称')).type(ButtonType.Capsule).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText).onClick(async () => {
          this.store.settings.alias = this.alias.trim() || this.store.t('我的鸿蒙设备');
          if (await this.store.save()) { localSend.announce(); this.store.notice = this.store.t('设备名称已保存'); }
        })
      }.padding(20).width('100%').backgroundColor(this.store.surfaceColor).borderRadius(24)
      this.title('外观')
      Column() {
        Row() {
          Text(this.store.t('语言')).layoutWeight(1).fontColor($r('sys.color.font_primary'))
          Text(this.languageName()).fontSize(14).maxLines(2).fontColor($r('sys.color.font_secondary')).layoutWeight(2).textAlign(TextAlign.End)
          AppIcon({ name: 'forward', rtl: this.store.rtl, iconSize: 22, tint: $r('sys.color.font_secondary') })
        }.padding(18).width('100%').constraintSize({ minHeight: 60 }).onClick(() => this.languageVisible = true)
        if (!['zh', 'en'].includes(resolvedLanguage(this.store.settings.language))) {
          Text(this.store.t('部分原生界面说明暂以英文显示')).fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%').padding({ left: 18, right: 18, bottom: 12 })
        }
        Row() {
          Text(this.store.t('深浅模式')).layoutWeight(1).fontColor($r('sys.color.font_primary'))
          Select([{ value: this.store.t('跟随系统') }, { value: this.store.t('浅色') }, { value: this.store.t('深色') }])
            .selected(this.store.settings.theme === 'light' ? 1 : this.store.settings.theme === 'dark' ? 2 : 0)
            .value(this.store.t(this.store.settings.theme === 'light' ? '浅色' : this.store.settings.theme === 'dark' ? '深色' : '跟随系统'))
            .onSelect((index: number) => {
              this.store.settings.theme = ['system', 'light', 'dark'][index];
              this.store.applyTheme(); this.store.save();
            })
        }.padding(18).width('100%')
        Column({ space: 10 }) {
          Text(this.store.t('主题预设')).width('100%').fontColor($r('sys.color.font_primary'))
          Select([{ value: this.store.t('系统配色') }, { value: 'AloeSend' }, { value: 'OLED' }, { value: 'Yaru' }, { value: this.store.t('自定义颜色') }])
            .selected(['system', 'localsend', 'oled', 'yaru', 'custom'].indexOf(this.store.settings.themePreset))
            .value(this.store.t(this.store.settings.themePreset === 'system' ? '系统配色' : this.store.settings.themePreset === 'localsend' ? 'AloeSend' :
              this.store.settings.themePreset === 'oled' ? 'OLED' : this.store.settings.themePreset === 'yaru' ? 'Yaru' : '自定义颜色'))
            .onSelect((index: number) => { this.store.settings.themePreset = ['system', 'localsend', 'oled', 'yaru', 'custom'][index]; this.store.save(); })
          Text(this.store.t('主题颜色')).width('100%').fontColor($r('sys.color.font_secondary')).fontSize(13)
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(6) } }) {
            ForEach(['#168A75', '#2473E8', '#7454C9', '#BB5C36', '#BD4F78'], (color: string) => {
              Button() {
                Circle().width(28).height(28).fill(color)
                  .stroke(this.store.settings.themePreset === 'custom' && this.store.settings.accent === color ? $r('sys.color.font_primary') : Color.Transparent).strokeWidth(2)
              }.width(44).height(44).backgroundColor(Color.Transparent)
                .onClick(() => { this.store.settings.themePreset = 'custom'; this.store.settings.accent = color; this.store.save(); }).accessibilityText(this.store.tf('主题色 {0}', [color]))
            })
          }.width('100%')
          Button(this.store.t('自定义取色')).onClick(() => {
            this.colorDraft = this.store.settings.accent; this.colorPickerVisible = !this.colorPickerVisible;
          })
          if (this.colorPickerVisible) { this.colorPicker() }
        }.padding(18).width('100%')
        this.toggle('界面动画', '自然流畅的页面过渡', 'animation')
        this.toggle('使用 #尾号区分地址', '开启时按地址显示；关闭时按设备指纹合并多个地址', 'showAddressTags')
        this.toggle('轻量效果', '关闭背景模糊，使用实色表面', 'effects')
        this.toggle('OLED 纯黑背景', '深色模式下使用纯黑背景', 'black')
      }.width('100%').backgroundColor(this.store.surfaceColor).borderRadius(24)
      this.title('接收')
      Column() {
        this.toggle('允许发现', '在同一网络中显示本设备', 'visible')
        this.toggle('自动接收', '信任当前网络时使用，无需逐次确认', 'quickSave')
        this.toggle('发送校验和', '发送前计算 SHA-256，供接收方检查文件完整性', 'createChecksums')
        this.toggle('验证校验和', '接收后检查 SHA-256，不匹配的文件不会标记为成功', 'verifyChecksums')
        this.toggle('仅收藏设备自动接收', '其他设备仍需手动确认', 'favorites')
        this.toggle('保留历史', '记录仅保存在当前设备', 'history')
        this.toggle('自动完成', '成功传输后结束会话', 'finish')
        this.toggle('接收后打开消息', '文件或文字收到后切换到对应会话', 'messages')
        this.toggle('接收后提示保存到相册', '图片和视频接收完成后，通过系统确认保存到相册', 'gallery')
        Column({ space: 12 }) {
          Text(this.store.t('文件保存位置')).fontSize(16).fontColor($r('sys.color.font_primary')).width('100%')
          Text(this.store.settings.destinationMode !== 'private' ? this.store.settings.destination : this.store.t('应用内安全保存，可在接收历史中打开、分享或另存为'))
            .fontSize(13).lineHeight(20).fontColor($r('sys.color.font_secondary')).width('100%').maxLines(3)
          Row({ space: 10 }) {
            Button(this.store.t('选择保存目录')).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText).onClick(() => this.store.chooseDestination())
            if (this.store.settings.destinationMode === 'folder') {
              Button(this.store.t('恢复默认')).backgroundColor(Color.Transparent).fontColor(this.store.accentText).onClick(() => {
                this.store.settings.destinationMode = 'download'; this.store.settings.destination = this.store.downloadDirectory;
                this.store.ensureDownloadAccess(); this.store.save();
              })
            }
          }.width('100%')
        }.padding(18)
        this.link('接收历史', '', 'history')
        Column({ space: 10 }) {
          Text(this.store.t('接收 PIN')).fontSize(14).fontColor($r('sys.color.font_secondary')).width('100%')
          TextInput({ text: this.pin, placeholder: this.store.t('留空表示不设 PIN') }).type(InputType.Password).showPasswordIcon(true).direction(Direction.Ltr)
            .onChange((value: string) => this.pin = value)
          Button(this.store.t('保存 PIN')).onClick(async () => {
            this.store.settings.pin = this.pin;
            if (await this.store.save()) this.store.notice = this.store.t('接收 PIN 已更新');
          }).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText)
        }.padding(18)
      }.width('100%').backgroundColor(this.store.surfaceColor).borderRadius(24)
      this.title('网络')
      Column() {
        Column({ space: 12 }) {
          Text(this.store.t(this.store.serverStatus)).fontSize(14).fontColor($r('sys.color.font_secondary')).width('100%')
          Row({ space: 12 }) {
            Button(this.store.t(this.store.listenerRunning ? '重启接收服务' : '启动接收服务')).layoutWeight(1).height(46)
              .backgroundColor(this.store.controlSurface).fontColor(this.store.accentText).enabled(!this.store.activeTransfers && !this.store.serverStatus.startsWith('正在启动'))
              .onClick(() => { if (this.store.listenerRunning) localSend.restart(); else localSend.resume(); })
            Button(this.store.t('停止服务')).height(46).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText)
              .enabled(this.store.listenerRunning && !this.store.activeTransfers).onClick(() => localSend.pause())
          }.width('100%')
        }.padding(18).width('100%')
        this.link('连接诊断', this.store.t(this.store.serverStatus), 'diagnostics')
        this.link('网络接口', this.store.t(this.store.settings.networkFilter === 'none' ? '全部网络' : '已筛选'), 'network')
        this.toggle('高级设置', '端口与组播地址', 'advanced')
        if (this.store.settings.advanced) {
          this.toggle('HTTPS 加密传输', '建议保持开启；修改后需重启接收服务', 'https')
          Text(this.store.t('切换加密后，Windows 端 LocalSend 可能仍使用旧连接，导致进度停在 0%。请重启本端接收服务，并在 Windows 系统托盘退出 LocalSend 后重新打开。'))
            .fontSize(13).lineHeight(21).fontColor($r('sys.color.font_secondary')).width('100%').padding({ left: 18, right: 18, bottom: 16 })
          Column({ space: 12 }) {
            Text(this.store.t('设备型号')).fontSize(14).fontColor($r('sys.color.font_secondary')).width('100%')
            TextInput({ text: this.model, placeholder: 'HarmonyOS' }).maxLength(80).onChange((value: string) => this.model = value)
            Text(this.store.t('发现超时（毫秒）')).fontSize(14).fontColor($r('sys.color.font_secondary')).width('100%')
            TextInput({ text: this.timeout, placeholder: '1500' }).type(InputType.Number).onChange((value: string) => this.timeout = value)
            TextInput({ text: this.port, placeholder: this.store.t('端口 53317') }).type(InputType.Number).onChange((value: string) => this.port = value)
            if (this.port.trim() && Number(this.port) !== this.defaults.port) {
              Text(this.networkHint(true)).fontSize(12).lineHeight(20).fontColor($r('sys.color.font_secondary')).width('100%')
            }
            TextInput({ text: this.group, placeholder: this.store.t('组播地址') }).onChange((value: string) => this.group = value)
            if (this.group.trim() && this.group.trim() !== this.defaults.multicast) {
              Text(this.networkHint(false)).fontSize(12).lineHeight(20).fontColor($r('sys.color.font_secondary')).width('100%')
            }
            if (Number(this.port) !== this.defaults.port || this.group !== this.defaults.multicast) {
              Button(this.store.t('恢复默认')).height(44).backgroundColor(Color.Transparent).fontColor(this.store.accentText)
                .onClick(() => { this.port = String(this.defaults.port); this.group = this.defaults.multicast; })
            }
            Button(this.store.t('保存网络设置')).backgroundColor(this.store.controlSurface).fontColor(this.store.accentText).onClick(() => this.saveNetwork())
            Row() {
              Text(this.store.t('设备类型')).layoutWeight(1).fontColor($r('sys.color.font_primary'))
              Select([{ value: this.store.t('手机 / 平板') }, { value: this.store.t('电脑') }, { value: this.store.t('无界面设备') }])
                .selected(this.store.settings.deviceType === 'desktop' ? 1 : this.store.settings.deviceType === 'headless' ? 2 : 0)
                .value(this.store.t(this.store.settings.deviceType === 'desktop' ? '电脑' : this.store.settings.deviceType === 'headless' ? '无界面设备' : '手机 / 平板'))
                .onSelect((index: number) => { this.store.settings.deviceType = ['mobile', 'desktop', 'headless'][index]; this.store.save(); localSend.announce(); })
            }.width('100%')
          }.padding(18)
        }
      }.width('100%').backgroundColor(this.store.surfaceColor).borderRadius(24)
      this.title('帮助与支持')
      Column() {
        Button(this.store.t('从旧版本导入设置')).width('100%').height(48).backgroundColor(Color.Transparent)
          .fontColor(this.store.accentText).enabled(!this.store.activeTransfers && !this.store.webUrl && !this.store.webStarting && !this.store.identityResetting)
          .onClick(() => this.importSettings())
        Text(this.store.flutterSettingsSummary || this.store.t('首次升级自动继承；已有本端设置会保留，可在此重新导入。'))
          .fontSize(13).lineHeight(20).fontColor($r('sys.color.font_secondary')).padding({ left: 18, right: 18, bottom: 14 }).width('100%')
        this.link('使用帮助', '', 'help')
        this.link('隐私政策', '', 'privacy')
        this.link('开源许可', '', 'licenses')
        this.link('更新记录', '', 'changelog')
        this.link('关于 AloeSend', '原生鸿蒙', 'about')
        this.link('支持作者', '', 'donate')
        this.link('进群吐槽', '', 'qq-group')
      }.width('100%').backgroundColor(this.store.surfaceColor).borderRadius(24)
    }.width('100%').bindSheet($$this.languageVisible, this.languageSheet(), { height: SheetSize.LARGE, showClose: true, keyboardAvoidMode: SheetKeyboardAvoidMode.RESIZE_ONLY })
  }
}
