import { AppStore } from '../model/AppStore';
import { LanguageChoice, languageChoices, filterLanguages } from '../model/LanguageChoices';
import { resolvedLanguage } from '../model/Locale';
import { AppIcon } from './AppIcon';

@Component
export struct LanguagePicker {
  @ObjectLink store: AppStore;
  @State query: string = '';
  @State choices: LanguageChoice[] = [];
  onChoose: () => void = () => {};
  aboutToAppear(): void { this.choices = languageChoices(this.store.settings.language); }
  choose(id: string): void { this.store.settings.language = id; this.store.save(); this.onChoose(); }
  selected(id: string): boolean { return this.store.settings.language !== 'system' && resolvedLanguage(this.store.settings.language) === id; }

  build() {
    Column({ space: 16 }) {
      Text(this.store.t('语言')).fontSize(23).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).width('100%')
      Row() {
        Text(this.store.t('跟随系统')).fontSize(16).fontColor($r('sys.color.font_primary')).layoutWeight(1)
        if (this.store.settings.language === 'system') { AppIcon({ name: 'check', iconSize: 22, tint: this.store.accentText }) }
      }.width('100%').padding(16).constraintSize({ minHeight: 56 }).backgroundColor(this.store.controlSurface).borderRadius(18)
        .onClick(() => this.choose('system')).accessibilitySelected(this.store.settings.language === 'system')
      Search({ value: this.query, placeholder: this.store.t('搜索语言名称或代码') }).onChange((value: string) => this.query = value)
      Scroll() {
        Column() {
          ForEach(filterLanguages(this.choices, this.query), (choice: LanguageChoice) => {
            Row({ space: 12 }) {
              Column({ space: 5 }) {
                Text(choice.name).fontSize(17).maxLines(2).fontColor($r('sys.color.font_primary'))
                Text(choice.detail && choice.detail !== choice.name ? `${choice.detail} · ${choice.id}` : choice.id)
                  .fontSize(12).fontColor($r('sys.color.font_secondary'))
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              if (this.selected(choice.id)) { AppIcon({ name: 'check', iconSize: 22, tint: this.store.accentText }) }
            }.width('100%').padding({ top: 14, bottom: 14, left: 12, right: 12 }).constraintSize({ minHeight: 66 })
              .backgroundColor(this.selected(choice.id) ? this.store.controlSurface : Color.Transparent).borderRadius(16)
              .onClick(() => this.choose(choice.id)).accessibilityText(`${choice.name} ${choice.detail}`).accessibilitySelected(this.selected(choice.id))
          }, (choice: LanguageChoice) => choice.id)
          if (filterLanguages(this.choices, this.query).length === 0) {
            Text(this.store.t('没有匹配的语言')).fontSize(15).fontColor($r('sys.color.font_secondary')).padding(28)
          }
        }.width('100%')
      }.width('100%').layoutWeight(1)
    }.padding(24).width('100%').height('100%').direction(this.store.rtl ? Direction.Rtl : Direction.Ltr)
  }
}
