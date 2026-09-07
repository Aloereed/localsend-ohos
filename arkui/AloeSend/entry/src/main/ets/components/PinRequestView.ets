import { AppStore } from '../model/AppStore';
import { localSend } from '../network/LocalSendService';

@Component
export struct PinRequestView {
  @ObjectLink store: AppStore;
  @State pin: string = '';

  submit(): void {
    if (!this.pin) return;
    localSend.submitPin(this.pin); this.pin = '';
  }

  build() {
    Column({ space: 12 }) {
      Text(this.store.t('请输入对方设备的接收 PIN')).fontSize(18).fontColor($r('sys.color.font_primary'))
      TextInput({ text: this.pin, placeholder: 'PIN' }).type(InputType.Password).showPasswordIcon(true)
        .direction(Direction.Ltr).enterKeyType(EnterKeyType.Done).defaultFocus(true)
        .accessibilityText(this.store.t('接收 PIN')).onChange((value: string) => this.pin = value)
        .onSubmit(() => this.submit())
      if (this.store.pendingPinInvalid) {
        Text(this.store.t('PIN 不正确，请重新输入')).fontSize(13).fontColor(this.store.dangerText)
      }
      Row({ space: 12 }) {
        Button(this.store.t('取消')).layoutWeight(1).height(44).backgroundColor(this.store.controlSurface).fontColor($r('sys.color.font_primary'))
          .onClick(() => { this.pin = ''; localSend.submitPin(''); })
        Button(this.store.t('确认')).layoutWeight(1).height(44).backgroundColor(this.store.accentFill)
          .enabled(this.pin.length > 0).onClick(() => this.submit())
      }.width('100%')
    }.padding(24).width('100%').direction(this.store.rtl ? Direction.Rtl : Direction.Ltr)
  }
}
