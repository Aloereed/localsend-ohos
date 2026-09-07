import { AppStore } from '../model/AppStore';
import { AppIcon } from './AppIcon';

@Component
export struct FloatingNavigation {
  @ObjectLink store: AppStore;
  @Prop selected: number = 0;
  onSelect: (index: number) => void = () => {};

  title(index: number): string { return ['接收', '发送', '消息', '设置'][index]; }
  icon(index: number): string { return ['receive', 'send', 'message', 'settings'][index]; }

  build() {
    Row({ space: 4 }) {
      ForEach([0, 1, 2, 3], (index: number) => {
        Column({ space: 4 }) {
          AppIcon({ name: this.icon(index), iconSize: 25,
            tint: this.selected === index ? this.store.accentText : this.store.dark ? '#D8E1EA' : '#354555' })
          Text(this.store.t(this.title(index))).fontSize(12).fontWeight(this.selected === index ? FontWeight.Medium : FontWeight.Normal)
            .maxLines(1).fontColor(this.selected === index ? this.store.accentText : $r('sys.color.font_secondary'))
        }.height(58).layoutWeight(1).justifyContent(FlexAlign.Center).borderRadius(29)
          .backgroundColor(this.selected === index ? this.store.dark ? '#405D7C99' : '#66FFFFFF' : Color.Transparent)
          .border({ width: this.selected === index ? 0.7 : 0, color: this.store.dark ? '#557D9AAF' : '#D9FFFFFF' })
          .scale({ x: this.selected === index ? 1 : 0.97, y: this.selected === index ? 1 : 0.97 })
          .animation({ duration: this.store.settings.animations ? 220 : 0, curve: Curve.EaseOut })
          .onClick(() => this.onSelect(index)).accessibilityText(this.store.t(this.title(index))).accessibilitySelected(this.selected === index)
      }, (index: number) => String(index))
    }.padding(7).width('100%').height(74).borderRadius(37)
      .backgroundEffect({ radius: this.store.settings.reduceEffects ? 0 : 30, saturation: 1.5, brightness: this.store.dark ? 0.94 : 1.04,
        color: this.store.settings.reduceEffects ? this.store.dark ? '#242C36' : '#F5F8FB' : this.store.dark ? '#80202B38' : '#70EDF3F9' })
      .linearGradient({ angle: 145, colors: [[this.store.dark ? '#207EA5C5' : '#77FFFFFF', 0], [Color.Transparent, 0.43], [this.store.dark ? '#1832516A' : '#30B6D5EA', 1]] })
      .border({ width: 0.8, color: this.store.dark ? '#668599AC' : '#D9FFFFFF' })
      .shadow({ radius: this.store.settings.reduceEffects ? 0 : 22, color: this.store.dark ? '#66000000' : '#25344960', offsetY: 9 })
  }
}
