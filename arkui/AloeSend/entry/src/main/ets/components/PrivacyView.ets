import { AppStore } from '../model/AppStore';
import { common } from '@kit.AbilityKit';
import { PrivacyPolicy, PolicySection, PolicyBullet, policy_zh, policy_en } from '../model/PrivacyPolicy';
import { resolvedLanguage } from '../model/Locale';

@Component
export struct PrivacyView {
  @ObjectLink store: AppStore;
  @Prop firstLaunch: boolean = false;
  @Prop accepting: boolean = false;
  onAccept: () => void = () => {};

  policy(): PrivacyPolicy { return resolvedLanguage(this.store.settings.language).startsWith('zh') ? policy_zh : policy_en; }

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
          Text(this.policy().heroTitle).fontSize(28).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary')).width('100%')
          Text(this.policy().heroSubtitle).fontSize(15).lineHeight(24).fontColor($r('sys.color.font_secondary')).width('100%')
          Text(this.policy().lastUpdated).fontSize(13).fontColor($r('sys.color.font_secondary')).width('100%')
          Text(this.policy().effectiveDate).fontSize(13).fontColor($r('sys.color.font_secondary')).width('100%')
          ForEach(this.policy().highlights, (highlight: string) => {
            Text(highlight).fontSize(14).fontColor(this.store.accentText).width('100%')
          }, (highlight: string) => highlight)
          ForEach(this.policy().sections, (section: PolicySection) => {
            Column({ space: 10 }) {
              Text(section.title).fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).width('100%')
              ForEach(section.paragraphs, (paragraph: string) => {
                Text(paragraph).fontSize(15).lineHeight(24).fontColor($r('sys.color.font_secondary')).width('100%').copyOption(CopyOptions.LocalDevice)
              }, (paragraph: string) => paragraph)
              ForEach(section.bullets, (bullet: PolicyBullet) => {
                Text(`${bullet.label} ${bullet.body}`).fontSize(15).lineHeight(24).fontColor($r('sys.color.font_secondary')).width('100%').copyOption(CopyOptions.LocalDevice)
              }, (bullet: PolicyBullet) => bullet.label)
            }.width('100%').padding({ top: 16, bottom: 8 })
          }, (section: PolicySection) => section.title)
          Text(this.policy().contactTitle).fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).width('100%')
          Text(this.policy().contactSubtitle).fontSize(15).lineHeight(24).fontColor($r('sys.color.font_secondary')).width('100%')
          Text(this.policy().contactEmail).fontSize(15).fontColor(this.store.accentText).copyOption(CopyOptions.LocalDevice).width('100%').padding({ top: 12, bottom: 12 })
          Text(this.policy().company).fontSize(13).fontColor($r('sys.color.font_secondary')).width('100%').padding({ bottom: 24 })
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
