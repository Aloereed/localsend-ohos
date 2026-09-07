import { intl } from '@kit.LocalizationKit';
import { flutterTemplates } from './FlutterTemplates';
import { resolvedLanguage } from './Locale';

export function flutterCount(key: string, language: string, count: string): string {
  const values: Record<string, string> = {};
  values['n'] = count;
  return flutterText(key, language, values);
}

export function flutterText(key: string, language: string, values: Record<string, string>): string {
  const template = flutterTemplates[resolvedLanguage(language)]?.[key];
  if (!template) throw new Error('Unknown Flutter template: ' + key);
  for (const name of template.parameters) {
    if (values[name] === undefined) throw new Error('Missing template parameter: ' + name);
  }
  let category = 'other';
  if (template.plural) {
    const number = Number(values[template.plural]);
    if (!Number.isFinite(number)) throw new Error('Invalid plural number');
    category = new intl.PluralRules(template.locale.replace(/_/g, '-')).select(number);
  }
  return (template.forms[category] ?? template.forms['other']).replace(/\u0001(\w+)\u0002/g,
    (_placeholder: string, name: string) => values[name]);
}
