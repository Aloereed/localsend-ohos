import { HistoryEntry, Peer, samePeer, historyStatus, normalizedFingerprint } from './AppStore';

export class MessageBatch {
  key: string = '';
  entries: HistoryEntry[] = [];
  time: number = 0;
  size: number = 0;
  completed: number = 0;
}

export function messageKey(entry: HistoryEntry): string {
  if (entry.text) return `message:${entry.id}`;
  const imported = /^flutter:message:([^:]+):[^:]+$/.exec(entry.id);
  const transfer = entry.transferId || (imported ? `flutter:${imported[1]}` : '');
  return transfer ? `${peerKey(historyPeer(entry))}:${entry.direction}:${transfer}` : `message:${entry.id}`;
}

// Group before filtering or paginating: a search match must keep the complete
// batch visible, and one transfer must not split across history pages.
export function messageBatches(entries: HistoryEntry[], query: string = ''): MessageBatch[] {
  const groups: Map<string, MessageBatch> = new Map();
  for (const entry of entries) {
    const key = messageKey(entry); let batch = groups.get(key);
    if (!batch) { batch = new MessageBatch(); batch.key = key; batch.time = entry.time; groups.set(key, batch); }
    batch.entries.push(entry); batch.time = Math.min(batch.time, entry.time); batch.size += entry.size;
    if (!entry.status || entry.status === 'complete') batch.completed++;
  }
  const search = query.trim().toLowerCase();
  return Array.from(groups.values()).filter((batch: MessageBatch) => !search || batch.entries.some((entry: HistoryEntry) =>
    `${entry.name} ${entry.text}`.toLowerCase().includes(search))).sort((a: MessageBatch, b: MessageBatch) => a.time - b.time);
}

export function batchStatus(batch: MessageBatch): string {
  const entries = batch.entries;
  if (!entries.length) return '';
  const active = entries.find((entry: HistoryEntry) => ['transferring', 'sending', 'receiving'].includes(entry.status));
  if (active) return historyStatus(active);
  if (entries.some((entry: HistoryEntry) => ['waiting', 'pendingIncoming'].includes(entry.status))) return '等待确认';
  if (batch.completed > 0 && batch.completed < entries.length) return '部分完成';
  const failed = entries.find((entry: HistoryEntry) => ['error', 'failed'].includes(entry.status)) ||
    entries.find((entry: HistoryEntry) => ['cancelled', 'canceled'].includes(entry.status)) ||
    entries.find((entry: HistoryEntry) => entry.status === 'declined');
  return historyStatus(failed || entries[0]);
}

export function conversationTargets(nearby: Peer[], favorites: Peer[], query: string = ''): Peer[] {
  const targets = nearby.slice();
  for (const peer of favorites) {
    if (!targets.some((target: Peer) => samePeer(target, peer))) targets.push(peer);
  }
  const search = query.trim().toLowerCase();
  return targets.filter((peer: Peer) => `${peer.alias} ${peer.ip}`.toLowerCase().includes(search));
}

export function currentConversationPeer(peer: Peer, nearby: Peer[]): Peer {
  // Keep the conversation/draft key stable while refreshing its live endpoint.
  return nearby.find((candidate: Peer) => !!candidate.ip && peerKey(candidate) === peerKey(peer)) || peer;
}

export class Conversation {
  key: string = '';
  peer: Peer = new Peer();
  last: HistoryEntry = new HistoryEntry();
  count: number = 0;
}

export class ConversationUpdates {
  private key: string = '';
  private known: Set<string> = new Set();

  reset(history: HistoryEntry[], peer: Peer): void {
    this.key = peerKey(peer);
    this.known = new Set(history.filter((entry: HistoryEntry) => inConversation(entry, peer)).map((entry: HistoryEntry) => messageKey(entry)));
  }

  observe(history: HistoryEntry[], peer: Peer): number {
    if (this.key !== peerKey(peer)) { this.reset(history, peer); return 0; }
    const entries = history.filter((entry: HistoryEntry) => inConversation(entry, peer));
    const count = new Set(entries.filter((entry: HistoryEntry) => entry.direction === 'receive' && !this.known.has(messageKey(entry))).map((entry: HistoryEntry) => messageKey(entry))).size;
    this.known = new Set(entries.map((entry: HistoryEntry) => messageKey(entry)));
    return count;
  }
}

export function peerKey(peer: Peer): string {
  return peer.fingerprint ? `identity:${normalizedFingerprint(peer.fingerprint)}` : peer.ip ? `address:${peer.ip}:${peer.port}` : `alias:${peer.alias}`;
}

export function historyPeer(entry: HistoryEntry): Peer {
  if (entry.peerInfo) return entry.peerInfo;
  const peer = new Peer(); peer.alias = entry.peer; return peer;
}

export function conversationList(history: HistoryEntry[], query: string = ''): Conversation[] {
  const groups: Map<string, Conversation> = new Map();
  const matches: Set<string> = new Set();
  const messages: Set<string> = new Set();
  const search = query.trim().toLowerCase();
  for (const entry of history) {
    const peer = historyPeer(entry); const key = peerKey(peer);
    if (!search || `${peer.alias} ${entry.name} ${entry.text}`.toLowerCase().includes(search)) matches.add(key);
    let group = groups.get(key);
    if (!group) { group = new Conversation(); group.key = key; group.peer = peer; group.last = entry; groups.set(key, group); }
    if (entry.time > group.last.time) { group.last = entry; group.peer = peer; }
    const message = `${key}:${messageKey(entry)}`;
    if (!messages.has(message)) { group.count++; messages.add(message); }
  }
  return Array.from(groups.values()).filter((group: Conversation) => matches.has(group.key)).sort((a: Conversation, b: Conversation) => b.last.time - a.last.time);
}

export function inConversation(entry: HistoryEntry, peer: Peer): boolean {
  const oldPeer = historyPeer(entry);
  return peerKey(oldPeer) === peerKey(peer) || (!oldPeer.ip && !oldPeer.fingerprint && oldPeer.alias === peer.alias);
}
