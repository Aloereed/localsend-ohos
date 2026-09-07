import { Peer } from './AppStore';
import { peerKey } from './Conversations';

export function selectedSendTargets(keys: string[], nearby: Peer[], favorites: Peer[]): Peer[] {
  const selected = new Set<string>(keys);
  const resolved = new Map<string, Peer>();
  // Prefer the current discovered endpoint; saved favorites remain available offline.
  for (const peer of [...nearby, ...favorites]) {
    const key = peerKey(peer);
    if (peer.ip && selected.has(key) && !resolved.has(key)) resolved.set(key, peer);
  }
  return Array.from(resolved.values());
}
