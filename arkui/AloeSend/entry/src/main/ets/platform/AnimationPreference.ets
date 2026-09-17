import { accessibility } from '@kit.AccessibilityKit';
import { deviceInfo, settings } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';

export async function initialAnimations(context: common.UIAbilityContext): Promise<boolean> {
  try {
    if (deviceInfo.sdkApiVersion >= 23) return !await accessibility.isAnimationReduceEnabled();
  } catch (_) { /* Older system implementations may not expose this capability. */ }
  try {
    const scale = await settings.getValue(context, settings.display.ANIMATOR_DURATION_SCALE);
    if (scale.trim() !== '' && Number(scale) === 0) return false;
  } catch (_) { /* Keep the application default if the preference cannot be read. */ }
  return true;
}
