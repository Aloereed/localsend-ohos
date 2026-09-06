import { AppStore } from '../model/AppStore';
import { common } from '@kit.AbilityKit';

@Component
export struct PrivacyView {
  @ObjectLink store: AppStore;
  @Prop firstLaunch: boolean = false;
  @Prop accepting: boolean = false;
  onAccept: () => void = () => {};

  @Builder
  section(title: string, body: string) {
    Column({ space: 8 }) {
      Text(this.store.t(title)).fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).width('100%')
      Text(this.store.t(body)).fontSize(15).lineHeight(24).fontColor($r('sys.color.font_secondary')).width('100%')
    }.width('100%').padding({ top: 12, bottom: 12 })
  }

  build() {
    Column({ space: 16 }) {
      Scroll() {
        Column({ space: 8 }) {
          if (this.firstLaunch) {
            Image($r('app.media.aloesend_logo')).width(88).height(88).objectFit(ImageFit.Contain).margin({ top: 24, bottom: 16 })
          }
          Text(this.store.t('隐私优先，本地优先')).fontSize(28).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary')).width('100%')
          Text(this.store.t('AloeSend 基于 LocalSend 构建，专注于局域网传输。')).fontSize(15).lineHeight(24).fontColor($r('sys.color.font_secondary')).width('100%')
          this.section('设备之间直接传输', 'AloeSend 不要求账号，不将文件上传至云端。内容通过本地网络在发送方和接收方之间传输。')
          this.section('本地记录', '设备名称、收藏、设置与传输历史只保存在本机。你可以关闭记录或清空历史。清空历史不会删除已接收的文件。')
          this.section('数据使用', '不为广告、行为分析或用户画像收集数据。设备名称和标识用于局域网发现与连接，传输内容只发送给你选择的设备。')
          this.section('系统权限', '文件、照片和剪贴板仅在你主动选择相关操作时访问。接收请求默认需要确认，请仅在可信网络上启用自动接收。')
          this.section('下载目录', '同意后通过系统对话框申请下载目录权限。拒绝目录授权仍可接收到应用内，并在历史中另存为。传输期间会申请系统后台传输任务。')
          this.section('系统与第三方', '操作系统、设备制造商和其他应用可能依据各自规则处理数据，请同时查阅它们的隐私政策。')
          this.section('政策更新', '更新后的隐私说明会在应用内展示。你可以随时从设置重新阅读。')
          Text('aloechat@aloereed.com').fontSize(15).fontColor(this.store.accentText).copyOption(CopyOptions.LocalDevice).width('100%').padding({ top: 12, bottom: 24 })
        }.width('100%')
      }.layoutWeight(1).width('100%').align(Alignment.Top)
      if (this.firstLaunch) {
        Row({ space: 12 }) {
          Button(this.store.t('不同意并退出')).layoutWeight(1).height(48).fontColor(this.store.accentText).backgroundColor(this.store.controlSurface)
            .enabled(!this.accepting).onClick(() => {
              const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
              context.terminateSelf().catch((error: Error) => this.store.fail('退出应用失败', error));
            })
          Button(this.store.t('同意并继续')).layoutWeight(1).height(48).backgroundColor(this.store.accentFill)
            .enabled(!this.accepting).onClick(() => this.onAccept())
        }.width('100%')
      }
    }.width('100%').height('100%').padding(24).constraintSize({ maxWidth: 720 })
  }
}
