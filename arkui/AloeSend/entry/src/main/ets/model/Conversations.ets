import { HistoryEntry, Peer } from './AppStore';

export class Conversation {
  key: string = '';
  peer: Peer = new Peer();
  last: HistoryEntry = new HistoryEntry();
  count: number = 0;
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
