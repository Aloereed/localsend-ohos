import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { decodeFlutterList } from './FlutterImport';
import { multicastAddress } from '../network/Addresses';
import { resolvedLanguage } from '../model/Locale';
import { flutterLanguages } from '../model/FlutterLocales';

const MARKER = 'flutter_settings_import_v1';
const ABSENT = '__aloesend_missing_preference__';

function filterList(value: preferences.ValueType): string[] {
  if ((!Array.isArray(value) && typeof value !== 'string') || value === '') throw new Error('invalid filter list');
  return decodeFlutterList(value);
}

export class FlutterSettingsReport {
  imported: string[] = [];
  preserved: string[] = [];
  skipped: string[] = [];
}

// Separate marker from history import: existing native installations also run
// this migration. Existing native keys always win unless the user imports again.
export async function importFlutterSettings(context: common.UIAbilityContext, target: preferences.Preferences,
  overwrite: boolean = false, current: string = ''): Promise<FlutterSettingsReport> {
  const previousMarker = await target.get(MARKER, '') as string;
  if (!overwrite && previousMarker) return JSON.parse(previousMarker) as FlutterSettingsReport;
  const previous = await target.get('settings', '') as string;
  const settings = JSON.parse(current || previous || '{}') as Record<string, preferences.ValueType>;
  const source = await preferences.getPreferences(context.getApplicationContext(), 'FlutterSharedPreferences');
  const report = new FlutterSettingsReport();
  const assign = (key: string, value: preferences.ValueType): void => {
    if (!overwrite && settings[key] !== undefined) { report.preserved.push(key); return; }
    settings[key] = value; report.imported.push(key);
  };
  const read = async (key: string): Promise<preferences.ValueType> => source.get('flutter.ls_' + key, ABSENT);
  const bools: string[][] = [
    ['quick_save', 'quickSave'], ['quick_save_from_favorites', 'favoriteQuickSave'], ['save_to_history', 'saveHistory'],
    ['auto_finish', 'autoFinish'], ['save_to_gallery', 'offerGallerySave'], ['enable_animations', 'animations'],
    ['lightweight_effects', 'reduceEffects'], ['https', 'https'], ['advanced_settings', 'advanced'],
    ['share_via_link_auto_accept', 'webAutoAccept'], ['open_message_tab_on_incoming_files', 'openMessagesOnReceive']
  ];
  for (const pair of bools) {
    const value = await read(pair[0]);
    if (value === ABSENT) continue;
    if (typeof value === 'boolean') assign(pair[1], value); else report.skipped.push(pair[0]);
  }
  const enums: string[][] = [['theme', 'theme', 'system', 'light', 'dark'],
    ['color', 'themePreset', 'system', 'localsend', 'oled', 'yaru'],
    ['send_mode', 'sendMode', 'single', 'multiple', 'link'], ['device_type', 'deviceType', 'mobile', 'desktop', 'headless']];
  for (const row of enums) {
    const value = await read(row[0]);
    if (value === ABSENT) continue;
    if (typeof value === 'string' && row.slice(2).includes(value)) assign(row[1], value); else report.skipped.push(row[0]);
  }
  for (const row of [['alias', 'alias'], ['device_model', 'deviceModel'], ['receive_pin', 'pin']]) {
    const value = await read(row[0]);
    if (value === ABSENT) continue;
    if (typeof value === 'string' && !/[\u0000-\u001f\u007f]/.test(value) &&
      (row[0] === 'receive_pin' || (value.trim().length > 0 && value.length <= 100))) assign(row[1], value);
    else report.skipped.push(row[0]);
  }
  for (const row of [['port', 'port'], ['timeout', 'discoveryTimeout']]) {
    const value = await read(row[0]);
    if (value === ABSENT) continue;
    const isPort = row[0] === 'port';
    if (typeof value === 'number' && Number.isInteger(value) && value >= (isPort ? 1024 : 500) && value <= (isPort ? 65535 : 30000)) assign(row[1], value);
    else report.skipped.push(row[0]);
  }
  const group = await read('multicast_group');
  if (group !== ABSENT) {
    try { if (typeof group !== 'string') throw new Error('type'); assign('multicast', multicastAddress(group)); }
    catch (_) { report.skipped.push('multicast_group'); }
  }
  const locale = await read('locale');
  if (locale !== ABSENT) {
    if (typeof locale === 'string' && (locale === 'system' || flutterLanguages.some((item) =>
      item.id.toLowerCase().split('-')[0] === locale.replace(/_/g, '-').toLowerCase().split('-')[0]))) {
      assign('language', locale === 'system' ? 'system' : resolvedLanguage(locale));
    } else report.skipped.push('locale');
  }
  const destination = await read('destination');
  if (destination !== ABSENT) {
    if (typeof destination === 'string' && (destination.startsWith('/storage/') || destination.startsWith('file://')) &&
      !/[\u0000-\u001f\u007f]/.test(destination) && !destination.split('/').includes('..')) {
      if (overwrite || (settings.destination === undefined && settings.destinationMode === undefined)) {
        assign('destination', destination); assign('destinationMode', 'folder');
      } else report.preserved.push('destination');
    } else report.skipped.push('destination');
  }
  const white = await read('network_whitelist'); const black = await read('network_blacklist');
  if (white !== ABSENT || black !== ABSENT) {
    try {
      // Native currently supports one filter mode. Do not silently weaken a
      // Flutter configuration which applies both lists together.
      if (white !== ABSENT && black !== ABSENT && filterList(black).length) throw new Error('combined filters');
      const patterns = filterList(white !== ABSENT ? white : black);
      if (patterns.length > 256 || patterns.some((item: string) => !item || item.length > 256 || !/^[a-zA-Z0-9.:_%*-]+$/.test(item))) throw new Error('invalid filters');
      if (overwrite || (settings.networkFilter === undefined && settings.networkPatterns === undefined)) {
        assign('networkFilter', white !== ABSENT ? 'allow' : 'deny'); assign('networkPatterns', patterns);
      } else report.preserved.push('networkFilter');
    } catch (_) { report.skipped.push('network_filter'); }
  }
  // Flutter omits default preferences. Reconstruct defaults that differ from
  // native ones only when an actual Flutter installation is identifiable.
  const version = await read('version');
  if (typeof version === 'number' || report.imported.length || report.preserved.length) {
    if (locale === ABSENT) assign('language', 'system');
    for (const row of [['auto_finish', 'autoFinish'], ['save_to_gallery', 'offerGallerySave'], ['lightweight_effects', 'reduceEffects']]) {
      if (await read(row[0]) === ABSENT) assign(row[1], row[0] !== 'auto_finish');
    }
  }
  if (!report.imported.length && !report.preserved.length && !report.skipped.length) return report;
  try {
    if (report.imported.length) await target.put('settings', JSON.stringify(settings));
    await target.put(MARKER, JSON.stringify(report)); await target.flush();
  } catch (error) {
    await target.put('settings', previous); await target.put(MARKER, previousMarker);
    await target.flush().catch(() => {}); throw error as Error;
  }
  return report;
}
