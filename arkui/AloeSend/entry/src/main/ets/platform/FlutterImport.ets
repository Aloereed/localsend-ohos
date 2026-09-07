import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { Peer, HistoryEntry, samePeer } from '../model/AppStore';

const LIST_PREFIX = 'VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu';
const MARKER = 'flutter_import_v1';

interface FlutterFavorite { id: string; fingerprint: string; ip: string; port: number; alias: string; customAlias?: boolean; }
interface FlutterReceive { id: string; fileName: string; fileType: string; path?: string; savedToGallery?: boolean; isMessage?: boolean; fileSize: number; senderAlias: string; timestamp: string; }
interface FlutterPeer { conversationId?: string; fingerprint?: string; alias: string; ip?: string; port?: number; deviceType?: string; }
interface FlutterItem { id: string; fileName: string; fileType: string; size: number; path?: string; savedToGallery?: boolean; errorMessage?: string; }
interface FlutterMessage { id: string; conversationId: string; peer: FlutterPeer; direction: string; kind: string; state: string; text?: string; items: FlutterItem[]; createdAt: string; updatedAt: string; }

export class FlutterImportReport {
  favorites: number = 0;
  history: number = 0;
  messages: number = 0;
  skipped: string[] = [];
}

export function decodeFlutterList(value: preferences.ValueType): string[] {
  if (Array.isArray(value)) {
    const list = value as string[];
    if (list.some((row: string) => typeof row !== 'string')) throw new Error('Flutter 列表格式无法识别');
    return list;
  }
  if (typeof value !== 'string' || !value) return [];
  let text = value;
  if (text.startsWith(LIST_PREFIX)) {
    const bytes = new util.Base64Helper().decodeSync(text.slice(LIST_PREFIX.length));
    text = new util.TextDecoder('utf-8').decodeToString(bytes);
  }
  const list = JSON.parse(text) as string[];
  if (!Array.isArray(list) || list.some((row: string) => typeof row !== 'string')) throw new Error('Flutter 列表格式无法识别');
  return list;
}

function date(value: string): number { const parsed = Date.parse(value); if (!Number.isFinite(parsed)) throw new Error('Invalid date'); return parsed; }
function validId(id: string): void { if (typeof id !== 'string' || !id) throw new Error('Missing record ID'); }
function fileLocation(entry: HistoryEntry, path: string | undefined, gallery: boolean): void {
  entry.path = typeof path === 'string' ? path : '';
  if (gallery) entry.galleryPath = entry.path;
  if (entry.path.startsWith('/storage/Users/currentUser/Download/') || entry.path.startsWith('file://docs/')) entry.exportedPath = entry.path;
}

function peerFrom(value: FlutterPeer, https: boolean): Peer {
  const peer = new Peer(); peer.alias = value.alias || ''; peer.fingerprint = value.fingerprint || '';
  peer.ip = value.ip || ''; peer.port = value.port || 53317; peer.protocol = https ? 'https' : 'http';
  peer.deviceType = value.deviceType || 'mobile'; return peer;
}

export async function importFlutterData(context: common.UIAbilityContext, target: preferences.Preferences): Promise<FlutterImportReport> {
  const completed = await target.get(MARKER, '') as string;
  if (completed) return JSON.parse(completed) as FlutterImportReport;
  // Same bundle and entry module retain Flutter's application preferences on an upgrade.
  const source = await preferences.getPreferences(context.getApplicationContext(), 'FlutterSharedPreferences');
  const favoritesRaw = decodeFlutterList(await source.get('flutter.ls_favorites', ''));
  const historyRaw = decodeFlutterList(await source.get('flutter.ls_receive_history', ''));
  const messagesRaw = decodeFlutterList(await source.get('flutter.ls_message_history', ''));
  const https = (await source.get('flutter.ls_https', true)) !== false;
  const previousFavorites = await target.get('favorites', '[]') as string;
  const previousHistory = await target.get('history', '[]') as string;
  const favorites = JSON.parse(previousFavorites) as Peer[];
  const history = JSON.parse(previousHistory) as HistoryEntry[];
  const report = new FlutterImportReport();
  const imported: Map<string, HistoryEntry> = new Map();
  for (let i = 0; i < favoritesRaw.length; i++) {
    try {
      const old = JSON.parse(favoritesRaw[i]) as FlutterFavorite; validId(old.id);
      if (typeof old.alias !== 'string' || typeof old.ip !== 'string' || !Number.isInteger(old.port) || old.port < 1 || old.port > 65535) throw new Error('Invalid favorite');
      const snapshot: FlutterPeer = { alias: old.alias, fingerprint: old.fingerprint, ip: old.ip, port: old.port };
      const peer = peerFrom(snapshot, https);
      if (!favorites.some((item: Peer) => samePeer(item, peer))) { favorites.push(peer); report.favorites++; }
    } catch (_) { report.skipped.push(`favorites[${i}]`); }
  }
  for (let i = 0; i < historyRaw.length; i++) {
    try {
      const old = JSON.parse(historyRaw[i]) as FlutterReceive; validId(old.id);
      if (typeof old.fileName !== 'string' || typeof old.senderAlias !== 'string') throw new Error('Invalid history');
      const entry = new HistoryEntry(); entry.id = `flutter:history:${old.id}`; entry.name = old.fileName;
      entry.peer = old.senderAlias; entry.time = date(old.timestamp); entry.size = old.fileSize || 0;
      entry.text = old.isMessage === true ? old.fileName : ''; fileLocation(entry, old.path, old.savedToGallery === true);
      imported.set(old.id, entry); report.history++;
    } catch (_) { report.skipped.push(`history[${i}]`); }
  }
  for (let i = 0; i < messagesRaw.length; i++) {
    try {
      const old = JSON.parse(messagesRaw[i]) as FlutterMessage; validId(old.id);
      if (!old.peer || typeof old.peer.alias !== 'string' || !Array.isArray(old.items)) throw new Error('Invalid message');
      const peer = peerFrom(old.peer, https); const time = date(old.createdAt);
      const state = old.state === 'completed' ? 'complete' : old.state === 'canceled' ? 'cancelled' : old.state === 'declined' ? 'declined' : 'error';
      const entries: HistoryEntry[] = [];
      const replaced: string[] = [];
      if (old.kind === 'text') {
        const entry = new HistoryEntry(); entry.id = `flutter:message:${old.id}`; entry.text = old.text || ''; entry.name = entry.text.slice(0, 70);
        entry.size = new util.TextEncoder().encodeInto(entry.text).length; entries.push(entry);
        // Flutter's automatic migration reuses the receive entry ID.
        if (old.direction === 'incoming' && imported.has(old.id)) { entry.id = imported.get(old.id)!.id; replaced.push(old.id); }
      } else {
        for (const item of old.items) {
          validId(item.id); if (typeof item.fileName !== 'string') throw new Error('Invalid transfer item');
          const entry = new HistoryEntry(); entry.id = `flutter:message:${old.id}:${item.id}`; entry.name = item.fileName; entry.size = item.size || 0;
          fileLocation(entry, item.path, item.savedToGallery === true); entries.push(entry);
          if (old.direction === 'incoming') {
            const priorId = imported.has(`${old.id}:${item.id}`) ? `${old.id}:${item.id}` : old.id === item.id ? item.id : '';
            if (priorId) { entry.id = imported.get(priorId)!.id; replaced.push(priorId); }
          }
        }
        if (!entries.length) { const entry = new HistoryEntry(); entry.id = `flutter:message:${old.id}`; entry.name = '文件传输'; entries.push(entry); }
      }
      for (const key of replaced) imported.delete(key);
      for (const entry of entries) {
        entry.peer = peer.alias; entry.peerInfo = peer; entry.time = time; entry.direction = old.direction === 'outgoing' ? 'send' : 'receive'; entry.status = state;
        imported.set(entry.id, entry);
      }
      report.messages++;
    } catch (_) { report.skipped.push(`messages[${i}]`); }
  }
  const ids = new Set(history.map((item: HistoryEntry) => item.id));
  for (const entry of imported.values()) { if (!ids.has(entry.id)) { history.push(entry); ids.add(entry.id); } }
  history.sort((a: HistoryEntry, b: HistoryEntry) => b.time - a.time);
  // One preference flush commits all three keys; on failure restore the cache too.
  // The Flutter preference file is never modified or deleted.
  try {
    await target.put('favorites', JSON.stringify(favorites)); await target.put('history', JSON.stringify(history));
    await target.put(MARKER, JSON.stringify(report)); await target.flush();
  } catch (error) {
    await target.put('favorites', previousFavorites); await target.put('history', previousHistory); await target.put(MARKER, '');
    await target.flush().catch(() => {}); throw error as Error;
  }
  return report;
}
