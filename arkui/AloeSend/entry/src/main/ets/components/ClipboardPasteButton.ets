import { AppStore } from '../model/AppStore';

@Component
export struct ClipboardPasteButton {
  @ObjectLink store: AppStore;
  @Prop compact: boolean = false;
  onPasted: () => void = () => {};

  build() {
    PasteButton({ icon: PasteIconStyle.LINES, text: PasteDescription.PASTE, buttonType: ButtonType.Normal })
      .layoutDirection(this.compact ? SecurityComponentLayoutDirection.VERTICAL : SecurityComponentLayoutDirection.HORIZONTAL)
      .width(this.compact ? 104 : '100%').height(this.compact ? 96 : 48)
      .iconSize(this.compact ? 28 : 20).fontSize(this.compact ? 13 : 16)
      .fontColor(this.compact ? this.store.accentText : '#FFFFFF')
      .iconColor(this.compact ? this.store.accentText : '#FFFFFF')
      .backgroundColor(this.compact ? this.store.surfaceColor : this.store.accentFill)
      .borderRadius(24).enabled(!this.store.busy)
      .onClick((event: ClickEvent, result: PasteButtonOnClickResult) => {
        if (result !== PasteButtonOnClickResult.SUCCESS) { this.store.notice = '未授予剪贴板读取权限'; return; }
        this.store.paste(true).then((selected: boolean) => { if (selected) this.onPasted(); });
      })
  }
}
