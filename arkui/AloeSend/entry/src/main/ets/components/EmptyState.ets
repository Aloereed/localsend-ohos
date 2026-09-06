import { AppIcon } from './AppIcon';

@Component
export struct EmptyState {
  @Prop icon: string = 'message';
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop accent: string = '#168A75';

  build() {
    Column({ space: 14 }) {
      Stack() { AppIcon({ name: this.icon, iconSize: 32, tint: this.accent }) }
        .width(64).height(64).borderRadius(22).backgroundColor($r('sys.color.comp_background_tertiary')).margin({ bottom: 6 })
      Text(this.title).fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).textAlign(TextAlign.Center)
      Text(this.description).fontSize(14).lineHeight(22).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center).constraintSize({ maxWidth: 360 })
    }.width('100%').padding({ top: 36, bottom: 36, left: 24, right: 24 })
      .backgroundColor(Color.Transparent)
  }
}
