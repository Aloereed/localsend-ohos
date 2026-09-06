import { HistoryEntry, Peer, samePeer } from './AppStore';

export function conversationTargets(nearby: Peer[], favorites: Peer[], query: string = ''): Peer[] {
  const targets = nearby.slice();
  for (const peer of favorites) {
    if (!targets.some((target: Peer) => samePeer(target, peer))) targets.push(peer);
  }
  const search = query.trim().toLowerCase();
  return targets.filter((peer: Peer) => `${peer.alias} ${peer.ip}`.toLowerCase().includes(search));
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
    this.known = new Set(history.filter((entry: HistoryEntry) => inConversation(entry, peer)).map((entry: HistoryEntry) => entry.id));
  }

  observe(history: HistoryEntry[], peer: Peer): number {
    if (this.key !== peerKey(peer)) { this.reset(history, peer); return 0; }
    const entries = history.filter((entry: HistoryEntry) => inConversation(entry, peer));
    const count = entries.filter((entry: HistoryEntry) => entry.direction === 'receive' && !this.known.has(entry.id)).length;
    this.known = new Set(entries.map((entry: HistoryEntry) => entry.id));
    return count;
  }
}

export function peerKey(peer: Peer): string {
  return peer.fingerprint ? `identity:${peer.fingerprint}` : peer.ip ? `address:${peer.ip}:${peer.port}` : `alias:${peer.alias}`;
}

export function historyPeer(entry: HistoryEntry): Peer {
  if (entry.peerInfo) return entry.peerInfo;
  const peer = new Peer(); peer.alias = entry.peer; return peer;
}

export function conversationList(history: HistoryEntry[], query: string = ''): Conversation[] {
  const groups: Map<string, Conversation> = new Map();
  const matches: Set<string> = new Set();
  const search = query.trim().toLowerCase();
  for (const entry of history) {
    const peer = historyPeer(entry); const key = peerKey(peer);
    if (!search || `${peer.alias} ${entry.name} ${entry.text}`.toLowerCase().includes(search)) matches.add(key);
    let group = groups.get(key);
    if (!group) { group = new Conversation(); group.key = key; group.peer = peer; group.last = entry; groups.set(key, group); }
    if (entry.time > group.last.time) { group.last = entry; group.peer = peer; }
    group.count++;
  }
  return Array.from(groups.values()).filter((group: Conversation) => matches.has(group.key)).sort((a: Conversation, b: Conversation) => b.last.time - a.last.time);
}

export function inConversation(entry: HistoryEntry, peer: Peer): boolean {
  const oldPeer = historyPeer(entry);
  return peerKey(oldPeer) === peerKey(peer) || (!oldPeer.ip && !oldPeer.fingerprint && oldPeer.alias === peer.alias);
}
