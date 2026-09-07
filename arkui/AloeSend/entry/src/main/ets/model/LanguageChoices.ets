import { i18n } from '@kit.LocalizationKit';
import { flutterLanguages } from './FlutterLocales';
import { resolvedLanguage } from './Locale';

export class LanguageChoice {
  id: string = '';
  name: string = '';
  detail: string = '';
  search: string = '';
}

export function languageChoices(language: string): LanguageChoice[] {
  const display = resolvedLanguage(language);
  return flutterLanguages.map((item) => {
    const choice = new LanguageChoice(); choice.id = item.id; choice.name = item.name;
    const tag = item.id === 'zh' ? 'zh-CN' : item.id;
    let english = '';
    try {
      choice.detail = i18n.System.getDisplayLanguage(tag, display === 'zh' ? 'zh-CN' : display, true);
      english = i18n.System.getDisplayLanguage(tag, 'en', true);
    } catch (_) { /* Native names and locale codes remain usable without ICU names. */ }
    choice.search = `${choice.name} ${choice.detail} ${english} ${tag} ${item.id === 'zh' ? 'zh-Hans' : ''}`.toLowerCase();
    return choice;
  });
}

export function filterLanguages(choices: LanguageChoice[], query: string): LanguageChoice[] {
  const words = query.trim().toLowerCase().replace(/_/g, '-').split(/\s+/).filter((word: string) => !!word);
  return choices.filter((choice: LanguageChoice) => words.every((word: string) => choice.search.includes(word)));
}
