import { Peer } from '../model/AppStore';
import { LocalInterface, ipv4, sameSubnet } from './Addresses';
import { Cancellation, PeerIdentityError } from './Transport';

// Match upstream's bounded /24 fallback, intersected with the real subnet.
// Never walk an entire /8 or probe another interface's own address.
export function discoveryTargets(interfaces: LocalInterface[]): string[] {
  const targets: Set<string> = new Set();
  const groups: string[][] = [];
  const own = interfaces.map((local: LocalInterface) => local.ip);
  for (const local of interfaces) {
    if (local.ignored || !ipv4(local.ip) || local.ip.startsWith('127.') || local.ip === '0.0.0.0' || local.prefixLength < 1 || local.prefixLength > 32) continue;
    const parts = local.ip.split('.');
    const group: string[] = [];
    const divisor = Math.pow(2, 32 - local.prefixLength);
    for (let host = 0; host <= 255; host++) {
      const ip = `${parts[0]}.${parts[1]}.${parts[2]}.${host}`;
      if (own.includes(ip) || !sameSubnet(local.ip, ip, local.prefixLength)) continue;
      const value = ip.split('.').reduce((sum: number, part: string) => sum * 256 + Number(part), 0);
      if (local.prefixLength < 31 && (value % divisor === 0 || value % divisor === divisor - 1)) continue;
      if (!targets.has(ip)) { targets.add(ip); group.push(ip); }
    }
    // Nearby DHCP leases are useful early candidates; still visit every host.
    const ownHost = Number(parts[3]);
    group.sort((a: string, b: string) => Math.abs(Number(a.split('.')[3]) - ownHost) - Math.abs(Number(b.split('.')[3]) - ownHost));
    groups.push(group);
  }
  const interleaved: string[] = [];
  for (let index = 0; index < 256; index++) {
    for (const group of groups) if (index < group.length) interleaved.push(group[index]);
  }
  return interleaved;
}

export class DiscoveryScan {
  private pending: Promise<void> | undefined = undefined;
  private tokens: Set<Cancellation> = new Set();
  private generation: number = 0;
  private lastRun: number = 0;
  private topology: string = '';
  private remaining: string[] = [];
  private deferred: string[] = [];
  private fastPass: boolean = true;
  private revision: number = 0;
  private monitor: number = -1;
  private waits: Map<number, () => void> = new Map();

  run(interfaces: LocalInterface[], port: number, known: Peer[], probe: (peer: Peer, token: Cancellation) => Promise<void>, manual: boolean,
    canRun: () => boolean = () => true, preferred: string[] = [],
    portOpen?: (peer: Peer, token: Cancellation) => Promise<boolean>): Promise<void> {
    if (this.pending) return this.pending;
    if (!canRun()) return Promise.resolve();
    const all = discoveryTargets(interfaces);
    const topology = `${port}:${all.join(',')}`;
    if (topology !== this.topology) { this.topology = topology; this.remaining = []; this.deferred = []; this.fastPass = true; this.lastRun = 0; this.revision++; }
    if (!manual && this.lastRun && Date.now() - this.lastRun < (this.remaining.length ? 10000 : 60000)) return Promise.resolve();
    // Hints only change order. They neither add off-network targets nor pin an
    // old identity to a DHCP address; every endpoint must answer again.
    const first = Array.from(new Set(preferred.filter((ip: string) => all.includes(ip))));
    const targets = !manual && this.remaining.length ? this.remaining.slice() : first.concat(all.filter((ip: string) => !first.includes(ip)));
    if (!targets.length) return Promise.resolve();
    const generation = this.generation; this.lastRun = Date.now();
    const revision = this.revision;
    const retry: string[] = [];
    const limit = manual ? targets.length : Math.min(16, targets.length);
    const deadline = manual ? Number.POSITIVE_INFINITY : Date.now() + 6000;
    this.monitor = setInterval(() => {
      if (!canRun() || Date.now() >= deadline) this.cancel(false);
    }, 100);
    let index = 0;
    const worker = async (): Promise<void> => {
      while (generation === this.generation && index < limit) {
        if (!canRun() || Date.now() >= deadline) { this.cancel(false); return; }
        const ip = targets[index++];
        const pinned = known.find((peer: Peer) => peer.ip === ip && peer.port === port && !!peer.fingerprint);
        if (portOpen && this.fastPass && !manual && !pinned && !first.includes(ip)) {
          const candidate = new Peer(); candidate.ip = ip; candidate.port = port;
          const token = new Cancellation(); this.tokens.add(token);
          let open = false;
          try { open = await portOpen(candidate, token); }
          catch (_) { /* A failed quick check gets the normal-timeout pass. */ }
          finally { this.tokens.delete(token); }
          if (generation !== this.generation) { retry.push(ip); return; }
          await this.wait(100);
          if (generation !== this.generation) { retry.push(ip); return; }
          if (!open) { this.deferred.push(ip); continue; }
        }
        const protocols = pinned ? [pinned.protocol] : ['https', 'http'];
        for (const protocol of protocols) {
          if (generation !== this.generation) { retry.push(ip); return; }
          const peer = pinned ? JSON.parse(JSON.stringify(pinned)) as Peer : new Peer();
          peer.ip = ip; peer.port = port; peer.protocol = protocol;
          const token = new Cancellation(); this.tokens.add(token);
          let done = false;
          try { await probe(peer, token); done = true; }
          catch (error) { if (error instanceof PeerIdentityError || token.cancelled) done = true; }
          finally { this.tokens.delete(token); }
          if (generation !== this.generation) { retry.push(ip); return; }
          // Yield to UI/file work even when a whole subnet rejects immediately.
          await this.wait(manual ? 25 : 100);
          if (done) break;
        }
      }
    };
    const work: Promise<void>[] = [];
    for (let i = 0; i < Math.min(manual ? 4 : 2, limit); i++) work.push(worker());
    const operation = Promise.all(work).then((): void => {}).finally(() => {
      if (this.monitor !== -1) clearInterval(this.monitor); this.monitor = -1;
      if (revision === this.revision) {
        this.lastRun = Date.now();
        if (!manual) {
          this.remaining = targets.slice(index).concat(retry);
          if (!this.remaining.length) {
            this.remaining = this.deferred; this.deferred = [];
            this.fastPass = !this.remaining.length;
          }
        } else if (generation === this.generation) { this.remaining = []; this.deferred = []; this.fastPass = true; }
      }
      this.pending = undefined;
    });
    this.pending = operation; return operation;
  }

  private wait(delay: number): Promise<void> {
    return new Promise<void>((resolve) => {
      const id = setTimeout(() => { this.waits.delete(id); resolve(); }, delay);
      this.waits.set(id, resolve);
    });
  }

  cancel(reset: boolean = true): void {
    this.generation++;
    if (reset) { this.revision++; this.lastRun = 0; this.remaining = []; this.deferred = []; this.fastPass = true; this.topology = ''; }
    if (this.monitor !== -1) clearInterval(this.monitor); this.monitor = -1;
    for (const token of this.tokens) token.cancel();
    this.tokens.clear();
    for (const entry of this.waits.entries()) { clearTimeout(entry[0]); entry[1](); }
    this.waits.clear();
  }
}
